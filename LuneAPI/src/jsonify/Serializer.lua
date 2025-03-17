--[[
    Serializer.lua
    A Lua module for serializing Lua tables to JSON and deserializing JSON to Lua tables
    with schema validation support.
]]

local Serializer = {}
Serializer.__index = Serializer

-- Constants
local TYPE_MISMATCH = "Type mismatch: expected %s, got %s"
local MISSING_FIELD = "Missing required field: %s"
local INVALID_JSON = "Invalid JSON: %s"
local MAX_RECURSION_DEPTH = 100

-- Create a new Serializer instance
function Serializer.new()
    local self = setmetatable({}, Serializer)
    return self
end

-- Helper functions
local function is_array(tbl)
    -- Check if table is an array (sequential numeric keys starting from 1)
    if type(tbl) ~= "table" then return false end
    
    local count = 0
    local max_index = 0
    
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
            return false
        end
        count = count + 1
        max_index = k > max_index and k or max_index
    end
    
    return count > 0 and count == max_index
end

local function escape_string(str)
    -- Escape special characters in strings for JSON
    local escaped = str:gsub('\\', '\\\\')
                      :gsub('"', '\\"')
                      :gsub('\n', '\\n')
                      :gsub('\r', '\\r')
                      :gsub('\t', '\\t')
                      :gsub('\b', '\\b')
                      :gsub('\f', '\\f')
    return escaped
end

-- Main serialization function
function Serializer:serialize(value, depth)
    depth = depth or 0
    
    -- Check for recursion limit
    if depth > MAX_RECURSION_DEPTH then
        error("Serialization depth limit exceeded. Possible circular reference.")
    end
    
    local value_type = type(value)
    
    -- Handle different types
    if value_type == "nil" then
        return "null"
    elseif value_type == "boolean" then
        return value and "true" or "false"
    elseif value_type == "number" then
        -- Handle NaN and Infinity which are not supported in JSON
        if value ~= value then -- NaN check
            return "null"
        elseif value == math.huge then
            return "null"
        elseif value == -math.huge then
            return "null"
        end
        return tostring(value)
    elseif value_type == "string" then
        return '"' .. escape_string(value) .. '"'
    elseif value_type == "table" then
        -- Handle arrays vs objects
        if is_array(value) then
            -- Array
            local items = {}
            for i, v in ipairs(value) do
                items[i] = self:serialize(v, depth + 1)
            end
            return "[" .. table.concat(items, ",") .. "]"
        else
            -- Object
            local items = {}
            for k, v in pairs(value) do
                -- Skip non-string keys and nil values
                if type(k) == "string" and v ~= nil then
                    local pair = '"' .. escape_string(k) .. '":' .. self:serialize(v, depth + 1)
                    table.insert(items, pair)
                elseif type(k) == "number" and math.floor(k) == k and v ~= nil then
                    -- Allow numeric keys for mixed tables
                    local pair = '"' .. tostring(k) .. '":' .. self:serialize(v, depth + 1)
                    table.insert(items, pair)
                end
            end
            return "{" .. table.concat(items, ",") .. "}"
        end
    else
        error("Unsupported data type: " .. value_type)
    end
end

-- Deserialization (JSON parsing)
function Serializer:deserialize(json_str)
    if type(json_str) ~= "string" then
        error("Expected string for deserialization")
    end
    
    -- Remove whitespace
    json_str = json_str:gsub("^%s*(.-)%s*$", "%1")
    
    -- State variables for the parser
    local index = 1
    local str_len = #json_str
    
    -- Helper function to consume whitespace
    local function skip_whitespace()
        local s, e = json_str:find("^[ \t\r\n]+", index)
        if s then
            index = e + 1
        end
    end
    
    -- Forward declarations for recursive parsers
    local parse_value, parse_string, parse_number, parse_object, parse_array
    
    -- Parse JSON string
    parse_string = function()
        local start_index = index
        index = index + 1 -- Skip opening quote
        
        local result = ""
        local escape = false
        
        while index <= str_len do
            local c = json_str:sub(index, index)
            
            if escape then
                -- Handle escaped character
                if c == '"' or c == '\\' or c == '/' then
                    result = result .. c
                elseif c == 'b' then
                    result = result .. '\b'
                elseif c == 'f' then
                    result = result .. '\f'
                elseif c == 'n' then
                    result = result .. '\n'
                elseif c == 'r' then
                    result = result .. '\r'
                elseif c == 't' then
                    result = result .. '\t'
                elseif c == 'u' then
                    -- Unicode escape sequence (4 hex digits)
                    if index + 4 > str_len then
                        error(string.format(INVALID_JSON, "Incomplete Unicode escape sequence"))
                    end
                    
                    local hex = json_str:sub(index + 1, index + 4)
                    if not hex:match("^%x%x%x%x$") then
                        error(string.format(INVALID_JSON, "Invalid Unicode escape sequence"))
                    end
                    
                    -- Convert hex to character (basic support, doesn't handle all Unicode cases)
                    local code = tonumber(hex, 16)
                    result = result .. string.char(code)
                    index = index + 4
                else
                    error(string.format(INVALID_JSON, "Invalid escape sequence: \\" .. c))
                end
                
                escape = false
            elseif c == '\\' then
                escape = true
            elseif c == '"' then
                index = index + 1
                return result
            else
                result = result .. c
            end
            
            index = index + 1
        end
        
        error(string.format(INVALID_JSON, "Unterminated string starting at position " .. start_index))
    end
    
    -- Parse JSON number
    parse_number = function()
        local s, e, num = json_str:find("^(-?%d+%.?%d*[eE]?[+-]?%d*)", index)
        if s then
            index = e + 1
            return tonumber(num)
        else
            error(string.format(INVALID_JSON, "Invalid number at position " .. index))
        end
    end
    
    -- Parse JSON object
    parse_object = function()
        local obj = {}
        index = index + 1 -- Skip opening brace
        
        skip_whitespace()
        
        -- Empty object check
        if json_str:sub(index, index) == "}" then
            index = index + 1
            return obj
        end
        
        while index <= str_len do
            skip_whitespace()
            
            -- Expect a string key
            if json_str:sub(index, index) ~= '"' then
                error(string.format(INVALID_JSON, "Expected string key at position " .. index))
            end
            
            local key = parse_string()
            
            skip_whitespace()
            
            -- Expect colon
            if json_str:sub(index, index) ~= ":" then
                error(string.format(INVALID_JSON, "Expected ':' at position " .. index))
            end
            index = index + 1
            
            skip_whitespace()
            
            -- Parse value
            local value = parse_value()
            obj[key] = value
            
            skip_whitespace()
            
            -- Expect comma or closing brace
            local c = json_str:sub(index, index)
            if c == "}" then
                index = index + 1
                return obj
            elseif c == "," then
                index = index + 1
                skip_whitespace()
            else
                error(string.format(INVALID_JSON, "Expected ',' or '}' at position " .. index))
            end
        end
        
        error(string.format(INVALID_JSON, "Unterminated object"))
    end
    
    -- Parse JSON array
    parse_array = function()
        local arr = {}
        index = index + 1 -- Skip opening bracket
        
        skip_whitespace()
        
        -- Empty array check
        if json_str:sub(index, index) == "]" then
            index = index + 1
            return arr
        end
        
        while index <= str_len do
            skip_whitespace()
            
            -- Parse value
            local value = parse_value()
            table.insert(arr, value)
            
            skip_whitespace()
            
            -- Expect comma or closing bracket
            local c = json_str:sub(index, index)
            if c == "]" then
                index = index + 1
                return arr
            elseif c == "," then
                index = index + 1
                skip_whitespace()
            else
                error(string.format(INVALID_JSON, "Expected ',' or ']' at position " .. index))
            end
        end
        
        error(string.format(INVALID_JSON, "Unterminated array"))
    end
    
    -- Parse any JSON value
    parse_value = function()
        skip_whitespace()
        
        if index > str_len then
            error(string.format(INVALID_JSON, "Unexpected end of input"))
        end
        
        local c = json_str:sub(index, index)
        
        if c == '"' then
            return parse_string()
        elseif c == '{' then
            return parse_object()
        elseif c == '[' then
            return parse_array()
        elseif c == 't' then
            if json_str:sub(index, index + 3) == "true" then
                index = index + 4
                return true
            else
                error(string.format(INVALID_JSON, "Invalid literal at position " .. index))
            end
        elseif c == 'f' then
            if json_str:sub(index, index + 4) == "false" then
                index = index + 5
                return false
            else
                error(string.format(INVALID_JSON, "Invalid literal at position " .. index))
            end
        elseif c == 'n' then
            if json_str:sub(index, index + 3) == "null" then
                index = index + 4
                return nil
            else
                error(string.format(INVALID_JSON, "Invalid literal at position " .. index))
            end
        elseif c == '-' or (c >= '0' and c <= '9') then
            return parse_number()
        else
            error(string.format(INVALID_JSON, "Unexpected character '" .. c .. "' at position " .. index))
        end
    end
    
    -- Start parsing from the root value
    local result = parse_value()
    
    -- Check if there's any unparsed content
    skip_whitespace()
    if index <= str_len then
        error(string.format(INVALID_JSON, "Unexpected data after JSON at position " .. index))
    end
    
    return result
end

-- Schema validation
function Serializer:validate(data, schema, path)
    path = path or ""
    
    -- Check for nil data
    if data == nil then
        if schema.required == true then
            error(string.format(MISSING_FIELD, path))
        else
            return true -- Not required, so nil is acceptable
        end
    end
    
    -- Check type
    if schema.type then
        local data_type = type(data)
        
        -- Special case for arrays
        if schema.type == "array" and data_type == "table" then
            if not is_array(data) then
                error(string.format(TYPE_MISMATCH, "array", "object"))
            end
            
            -- Validate array items if specified
            if schema.items and #data > 0 then
                for i, item in ipairs(data) do
                    local item_path = path .. "[" .. i .. "]"
                    self:validate(item, schema.items, item_path)
                end
            end
        -- Regular type checking
        elseif schema.type ~= data_type then
            error(string.format(TYPE_MISMATCH, schema.type, data_type))
        end
    end
    
    -- Validate object properties
    if schema.properties and type(data) == "table" then
        for prop_name, prop_schema in pairs(schema.properties) do
            local prop_path = path == "" and prop_name or path .. "." .. prop_name
            local prop_value = data[prop_name]
            
            self:validate(prop_value, prop_schema, prop_path)
        end
        
        -- Check for required fields
        if schema.required_fields then
            for _, field in ipairs(schema.required_fields) do
                if data[field] == nil then
                    local field_path = path == "" and field or path .. "." .. field
                    error(string.format(MISSING_FIELD, field_path))
                end
            end
        end
    end
    
    -- Apply additional validation rules as needed
    if schema.pattern and type(data) == "string" then
        if not data:match(schema.pattern) then
            error("String does not match pattern at " .. path)
        end
    end
    
    if schema.min_length and type(data) == "string" then
        if #data < schema.min_length then
            error("String length too short at " .. path)
        end
    end
    
    if schema.max_length and type(data) == "string" then
        if #data > schema.max_length then
            error("String length too long at " .. path)
        end
    end
    
    if schema.min and type(data) == "number" then
        if data < schema.min then
            error("Number too small at " .. path)
        end
    end
    
    if schema.max and type(data) == "number" then
        if data > schema.max then
            error("Number too large at " .. path)
        end
    end
    
    return true
end

-- Format the serialized JSON string with indentation
function Serializer:pretty_print(json_str, indent_char, indent_count)
    indent_char = indent_char or "  "
    indent_count = indent_count or 1
    
    -- If input is a table, serialize it first
    if type(json_str) == "table" then
        json_str = self:serialize(json_str)
    end
    
    local result = ""
    local in_string = false
    local in_escape = false
    local indent_level = 0
    
    for i = 1, #json_str do
        local c = json_str:sub(i, i)
        
        if in_string then
            result = result .. c
            if in_escape then
                in_escape = false
            elseif c == '\\' then
                in_escape = true
            elseif c == '"' then
                in_string = false
            end
        else
            if c == '"' then
                result = result .. c
                in_string = true
            elseif c == '{' or c == '[' then
                result = result .. c
                indent_level = indent_level + 1
                result = result .. "\n" .. string.rep(indent_char, indent_level * indent_count)
            elseif c == '}' or c == ']' then
                indent_level = indent_level - 1
                result = result .. "\n" .. string.rep(indent_char, indent_level * indent_count) .. c
            elseif c == ',' then
                result = result .. c .. "\n" .. string.rep(indent_char, indent_level * indent_count)
            elseif c == ':' then
                result = result .. c .. " "
            elseif c ~= ' ' and c ~= '\t' and c ~= '\r' and c ~= '\n' then
                result = result .. c
            end
        end
    end
    
    return result
end

return Serializer 