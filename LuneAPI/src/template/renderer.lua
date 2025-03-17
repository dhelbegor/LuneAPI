-- Template Renderer for LuneAPI
-- Renders parsed templates with context data
--
-- Optimizations:
--   1. Precompiled regex patterns for better performance
--   2. Template caching to avoid repeated file I/O and parsing
--   3. Refactored condition evaluation for better readability and maintenance
--   4. LRU (Least Recently Used) cache management

local Renderer = {}

-- Template directory for includes
local template_dir = nil

-- Maximum include depth to prevent infinite recursion
local MAX_INCLUDE_DEPTH = 10

-- Track includes to prevent circular includes
local include_stack = {}

-- Debug mode (enables additional logging)
local debug_mode = false

-- Template caching to improve performance for frequently accessed templates
local template_cache = {}
local cache_enabled = true
local max_cache_size = 50 -- Maximum number of templates to cache
local cache_hits = 0
local cache_misses = 0

-- Precompiled regex patterns for better performance
local PATTERNS = {
    -- Variable and filter patterns
    variable_filter = "^([^|]+)(.*)$",
    filter_name_args = "^([%w_]+)%s*%(?(.-)%)?$",
    filter_args = "([^,]+)",
    default_filter = "(.+)|default%(([^)]+)%)",
    
    -- Value patterns
    trim_whitespace = "^%s*(.-)%s*$",
    quoted_string = '^".*"$',
    quoted_string_alt = "^'.*'$",
    numeric = "^%d+%.?%d*$",
    
    -- Condition patterns
    not_condition = "^not%s+(.+)$",
    filter_comparison = "([^|]+)|([^%s]+)%s*([=<>!]+)%s*(.+)",
    array_indexing = "^([^%[]+)%[(%d+)%]$",
    
    -- Include patterns
    variable_in_include = "{{.+}}",
    extract_var_name = "{{%s*(.-)%s*}}",
    html_ext = "%.html$",
    tpl_ext = "%.tpl$"
}

-- Default filter for undefined values
local function default_value(val, default)
    if val == nil or val == "" then
        return default
    end
    return val
end

-- Built-in filters
local filters = {
    -- Convert value to uppercase
    upper = function(val)
        return string.upper(tostring(val or ""))
    end,
    
    -- Convert value to lowercase
    lower = function(val)
        return string.lower(tostring(val or ""))
    end,
    
    -- Count items in a table or length of a string
    length = function(val)
        if type(val) == "table" then
            -- Try to use # operator for array-like tables first
            local array_length = #val
            if array_length > 0 then
                return array_length
            end
            
            -- Fall back to counting all keys for non-sequential tables
            local count = 0
            for _ in pairs(val) do
                count = count + 1
            end
            return count
        elseif type(val) == "string" then
            return #val
        end
        return 0
    end,
    
    -- Format a number with comma as thousands separator
    number_format = function(val, decimals)
        decimals = decimals or 0
        if val == nil then return "0" end
        local str = string.format("%." .. decimals .. "f", tonumber(val) or 0)
        local left, right = string.match(str, "^([^.]+)(.*)$")
        left = string.gsub(left, "(%d)(%d%d%d)$", "%1,%2")
        left = string.gsub(left, "(%d)(%d%d%d),", "%1,%2,")
        return left .. (right or "")
    end,
    
    -- Format a date using os.date format
    date_format = function(val, format)
        format = format or "%Y-%m-%d"
        if type(val) == "number" then
            return os.date(format, val)
        end
        return val or ""
    end,
    
    -- Truncate a string to a max length with ellipsis
    truncate = function(val, length, suffix)
        local str = tostring(val or "")
        length = tonumber(length) or 30
        suffix = suffix or "..."
        
        if #str <= length then
            return str
        end
        
        return string.sub(str, 1, length - #suffix) .. suffix
    end,
    
    -- HTML escape
    escape = function(val)
        if val == nil then return "" end
        return tostring(val)
            :gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub('"', "&quot;")
            :gsub("'", "&#39;")
    end,
    
    -- Return default value if input is nil or empty
    default = default_value
}

-- Helper function to get nested value from context
local function get_value(context, var_name)
    if var_name == "" then return nil end
    
    -- Handle built-in values
    if var_name == "_template_dir" then
        return template_dir
    end
    
    -- Check for default filter syntax: var|default("default value")
    local name, default_val = var_name:match(PATTERNS.default_filter)
    if name and default_val then
        -- Remove quotes if present
        if default_val:match(PATTERNS.quoted_string) or default_val:match(PATTERNS.quoted_string_alt) then
            default_val = default_val:sub(2, -2)
        end
        
        local value = get_value(context, name:gsub("^%s*", ""):gsub("%s*$", ""))
        return default_value(value, default_val)
    end
    
    -- Handle nested properties (e.g., user.name)
    local parts = {}
    for part in var_name:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    
    local value = context
    for _, part in ipairs(parts) do
        if type(value) ~= "table" then
            return nil
        end
        
        -- Handle array indexing (e.g., items[1])
        local name, index = part:match(PATTERNS.array_indexing)
        if name and index then
            value = value[name]
            if type(value) == "table" then
                value = value[tonumber(index)]
            else
                return nil
            end
        else
            -- Regular property access
            value = value[part]
        end
        
        -- If value becomes nil, stop traversing
        if value == nil then return nil end
    end
    
    return value
end

-- Helper function to parse a value from a condition
local function parse_condition_value(value_str, context)
    value_str = value_str:gsub(PATTERNS.trim_whitespace, "%1")
    
    -- Handle quoted strings
    if value_str:match(PATTERNS.quoted_string) or value_str:match(PATTERNS.quoted_string_alt) then
        return value_str:sub(2, -2)
    -- Handle numbers
    elseif value_str:match(PATTERNS.numeric) then
        return tonumber(value_str)
    -- Handle context variables
    else
        return get_value(context, value_str)
    end
end

-- Helper function to compare two values based on operator
local function compare_values(left, right, operator)
    -- Convert to numbers for numeric comparison if both can be numbers
    if type(left) ~= "number" and type(tonumber(left)) == "number" and
       type(right) ~= "number" and type(tonumber(right)) == "number" then
        left = tonumber(left)
        right = tonumber(right)
    end
    
    -- Ensure both values are of the same type for comparison
    if type(left) == "number" and type(right) == "number" then
        if operator == "==" then return left == right
        elseif operator == "!=" then return left ~= right
        elseif operator == ">" then return left > right
        elseif operator == "<" then return left < right
        elseif operator == ">=" then return left >= right
        elseif operator == "<=" then return left <= right
        end
    else
        -- Convert to strings for string comparison
        left = tostring(left or "")
        right = tostring(right or "")
        
        if operator == "==" then return left == right
        elseif operator == "!=" then return left ~= right
        elseif operator == ">" then return left > right
        elseif operator == "<" then return left < right
        elseif operator == ">=" then return left >= right
        elseif operator == "<=" then return left <= right
        end
    end
    
    return false
end

-- Try to check if a condition is truthy
local function evaluate_condition(condition, context)
    if type(condition) ~= "string" then
        return false
    end
    
    -- Handle empty condition
    condition = condition:gsub(PATTERNS.trim_whitespace, "%1")
    if condition == "" then
        return false
    end
    
    -- Handle NOT operator: if not condition
    local not_cond = condition:match(PATTERNS.not_condition)
    if not_cond then
        return not evaluate_condition(not_cond, context)
    end
    
    -- Handle simple conditions like: if user
    if not condition:find("[=<>!]") then
        local value = get_value(context, condition)
        -- Check if it's truthy
        return value ~= nil and value ~= false and value ~= 0 and value ~= ""
    end
    
    -- Handle comparison with filter
    local left_var, filter, operator, right = condition:match(PATTERNS.filter_comparison)
    if left_var and filter and operator and right then
        local left_value = get_value(context, left_var:gsub(PATTERNS.trim_whitespace, "%1"))
        
        -- Apply the filter
        if filters[filter] then
            left_value = filters[filter](left_value)
        end
        
        -- Parse right side
        local right_value = parse_condition_value(right, context)
        
        -- Perform comparison
        return compare_values(left_value, right_value, operator)
    end
    
    -- Check for regular comparison operators
    local operators = {
        ["=="] = true,
        ["!="] = true,
        [">="] = true,
        ["<="] = true,
        [">"] = true,
        ["<"] = true
    }
    
    -- Find the operator used in the condition
    local op_used = nil
    for op in pairs(operators) do
        if condition:find(op) then
            -- For > and <, make sure we're not matching >= and <=
            if (op == ">" and not condition:find(">=")) or
               (op == "<" and not condition:find("<=")) or
               op ~= ">" and op ~= "<" then
                op_used = op
                break
            end
        end
    end
    
    if op_used then
        -- Split the condition into left and right parts
        local pattern = "(.-)%s*" .. op_used:gsub("[<>=!]", "%%%1") .. "%s*(.+)"
        local left, right = condition:match(pattern)
        
        if left and right then
            -- Parse both values
            local left_value = parse_condition_value(left, context)
            local right_value = parse_condition_value(right, context)
            
            -- Perform comparison
            return compare_values(left_value, right_value, op_used)
        end
    end
    
    -- Default: get the value and check if it's truthy
    local value = get_value(context, condition)
    return value ~= nil and value ~= false and value ~= 0 and value ~= ""
end

-- Apply filters to a value (e.g., {{ name|upper|truncate(20) }})
local function apply_filters(value, filter_str)
    if not filter_str or filter_str == "" then
        return value
    end
    
    -- Split into individual filters
    for filter_expr in filter_str:gmatch("([^|]+)") do
        filter_expr = filter_expr:gsub(PATTERNS.trim_whitespace, "%1")
        
        -- Extract filter name and arguments
        local filter_name, args = filter_expr:match(PATTERNS.filter_name_args)
        
        if filter_name and filters[filter_name] then
            -- Parse arguments if any
            local filter_args = {value}
            if args and args ~= "" then
                for arg in args:gmatch(PATTERNS.filter_args) do
                    arg = arg:gsub(PATTERNS.trim_whitespace, "%1")
                    
                    -- Handle string literals
                    if arg:match(PATTERNS.quoted_string) or arg:match(PATTERNS.quoted_string_alt) then
                        table.insert(filter_args, arg:sub(2, -2))
                    -- Handle numbers
                    elseif arg:match(PATTERNS.numeric) then
                        table.insert(filter_args, tonumber(arg))
                    -- Handle other values (as strings)
                    else
                        table.insert(filter_args, arg)
                    end
                end
            end
            
            -- Apply the filter
            value = filters[filter_name](unpack(filter_args))
        end
    end
    
    return value
end

-- Process variables in the format "var|filter1|filter2(arg)"
local function process_variable(var_expr, context)
    var_expr = var_expr:gsub(PATTERNS.trim_whitespace, "%1")
    
    -- Split variable name and filters
    local var_name, filter_str = var_expr:match(PATTERNS.variable_filter)
    if not var_name then
        return ""
    end
    
    var_name = var_name:gsub(PATTERNS.trim_whitespace, "%1")
    
    -- Get value from context
    local value = get_value(context, var_name)
    
    -- Apply filters if any
    if filter_str and filter_str ~= "" then
        value = apply_filters(value, filter_str)
    end
    
    -- Convert to string (except nil which becomes empty string)
    if value == nil then
        return ""
    end
    return tostring(value)
end

-- Resolve include file path and handle template variables
local function resolve_include_path(template_name, context)
    if not template_dir then
        return nil, "Template directory not set"
    end
    
    -- Normalize template name
    template_name = template_name:gsub(PATTERNS.trim_whitespace, "%1")
    
    -- Remove quotes if present
    if template_name:match(PATTERNS.quoted_string) or template_name:match(PATTERNS.quoted_string_alt) then
        template_name = template_name:sub(2, -2)
    end
    
    -- Check if the template name is a variable in the context
    if not template_name:find("[./]") and context[template_name] then
        template_name = tostring(context[template_name])
    end
    
    -- If template doesn't have an extension, add .html
    if not template_name:match(PATTERNS.html_ext) and not template_name:match(PATTERNS.tpl_ext) then
        template_name = template_name .. ".html"
    end
    
    -- Build file path
    local file_path = template_dir .. "/" .. template_name
    
    return file_path
end

-- Helper function to get cache statistics
local function get_cache_stats()
    return {
        enabled = cache_enabled,
        size = #template_cache,
        max_size = max_cache_size,
        hits = cache_hits,
        misses = cache_misses,
        hit_ratio = cache_hits > 0 and (cache_hits / (cache_hits + cache_misses)) or 0
    }
end

-- Helper function to clear the template cache
local function clear_cache()
    template_cache = {}
    cache_hits = 0
    cache_misses = 0
    if debug_mode then
        print("Template cache cleared")
    end
end

-- Helper function to add a template to the cache
local function cache_template(path, content)
    if not cache_enabled then
        return
    end
    
    -- Check if cache is full
    if #template_cache >= max_cache_size then
        -- Remove the least recently used template (first one)
        table.remove(template_cache, 1)
        if debug_mode then
            print("Cache full, removed oldest template")
        end
    end
    
    -- Add the template to the cache
    table.insert(template_cache, {
        path = path,
        content = content,
        timestamp = os.time()
    })
    
    if debug_mode then
        print("Template cached: " .. path)
    end
end

-- Helper function to get a template from cache
local function get_cached_template(path)
    if not cache_enabled then
        return nil
    end
    
    for i, entry in ipairs(template_cache) do
        if entry.path == path then
            -- Move this entry to the end (most recently used)
            local cached = table.remove(template_cache, i)
            cached.timestamp = os.time() -- Update timestamp
            table.insert(template_cache, cached)
            
            cache_hits = cache_hits + 1
            if debug_mode then
                print("Cache hit: " .. path)
            end
            
            return cached.content
        end
    end
    
    cache_misses = cache_misses + 1
    if debug_mode then
        print("Cache miss: " .. path)
    end
    
    return nil
end

-- Render an included template with handling for circular dependencies
local function process_include(template_name, context)
    if debug_mode then
        print("Including template: " .. template_name)
    end
    
    -- Check for the template directory
    if not template_dir then
        return "<!-- Include failed: template_dir not set -->"
    end
    
    -- Try to evaluate the template name if it's a variable 
    if template_name:match(PATTERNS.variable_in_include) then
        -- Extract variable name from {{ var }}
        local var_name = template_name:match(PATTERNS.extract_var_name)
        if var_name then
            local value = get_value(context, var_name)
            if value then
                template_name = value
            end
        end
    end
    
    -- Check for circular includes
    for _, included in ipairs(include_stack) do
        if included == template_name then
            return "<!-- Error: Circular include detected for '" .. template_name .. "' -->"
        end
    end
    
    -- Check for maximum include depth
    if #include_stack >= MAX_INCLUDE_DEPTH then
        return "<!-- Error: Maximum include depth exceeded. Possible circular includes. -->"
    end
    
    -- Resolve file path
    local file_path, err = resolve_include_path(template_name, context)
    if not file_path then
        return "<!-- Include error: " .. err .. " -->"
    end
    
    -- Add to include stack
    table.insert(include_stack, template_name)
    
    -- Try to get the parsed template from cache
    local parsed = get_cached_template(file_path)
    
    -- If not found in cache, read from file and cache it
    if not parsed then
        -- Try to open the file
        local file, err = io.open(file_path, "r")
        if not file then
            table.remove(include_stack)
            return "<!-- Include failed: " .. file_path .. " (" .. (err or "unknown error") .. ") -->"
        end
        
        -- Read and parse the template
        local content = file:read("*a")
        file:close()
        
        -- Parse the template
        local Parser = require('luneapi.template.parser')
        parsed = Parser.parse(content)
        
        -- Cache the parsed template
        cache_template(file_path, parsed)
    end
    
    -- Render the template with the context
    local success, result = pcall(function()
        return Renderer.render(parsed, context)
    end)
    
    -- Remove from include stack
    table.remove(include_stack)
    
    if success then
        return result
    else
        return "<!-- Error including template: " .. tostring(result) .. " -->"
    end
end

-- Render a parsed template with context data
-- @param parsed Parsed template data from Parser.parse
-- @param context Data context for rendering
-- @return Rendered string
function Renderer.render(parsed, context)
    if not parsed then 
        return "<!-- Error: Nothing to render, parsed template is nil -->"
    end
    
    context = context or {}
    local output = {}
    
    -- Add some useful context variables
    local now = os.time()
    context.current_year = os.date("%Y", now)
    context.current_date = os.date("%Y-%m-%d", now)
    context._template_dir = template_dir
    
    -- Process each node in the parsed template
    for _, node in ipairs(parsed) do
        if node.type == "text" then
            -- Text node - just add it directly
            table.insert(output, node.value)
            
        elseif node.type == "variable" then
            -- Variable node - evaluate it with filters
            local success, result = pcall(process_variable, node.value, context)
            if success then
                table.insert(output, result)
            else
                table.insert(output, "<!-- Error processing variable: " .. tostring(result) .. " -->")
            end
            
        elseif node.type == "block" then
            if node.name == "if" then
                -- If block
                local success, condition_result = pcall(evaluate_condition, node.args, context)
                
                if success then
                    if condition_result then
                        -- Condition is true, render content
                        local content_result = Renderer.render(node.content, context)
                        table.insert(output, content_result)
                    elseif node.else_content then
                        -- Condition is false, render else content if it exists
                        local else_result = Renderer.render(node.else_content, context)
                        table.insert(output, else_result)
                    end
                else
                    -- Error in condition evaluation
                    table.insert(output, "<!-- Error in if condition: " .. tostring(condition_result) .. " -->")
                end
                
            elseif node.name == "for" then
                -- For loop
                local var_name, collection_name = node.args:match("(%S+)%s+in%s+(%S+)")
                
                if not var_name or not collection_name then
                    table.insert(output, "<!-- Invalid for loop syntax: " .. node.args .. " -->")
                else
                    local collection = get_value(context, collection_name)
                    
                    if type(collection) == "table" and next(collection) ~= nil then
                        -- Iterate through collection
                        for i, item in ipairs(collection) do
                            -- Create a loop context
                            local loop_context = {}
                            for k, v in pairs(context) do
                                loop_context[k] = v
                            end
                            
                            -- Add loop variable and metadata
                            loop_context[var_name] = item
                            loop_context.loop = {
                                index = i,
                                index0 = i - 1,
                                first = (i == 1),
                                last = (i == #collection),
                                length = #collection
                            }
                            
                            -- Render content with loop context
                            local item_result = Renderer.render(node.content, loop_context)
                            table.insert(output, item_result)
                        end
                    elseif node.else_content then
                        -- Empty collection, render else content
                        local else_result = Renderer.render(node.else_content, context)
                        table.insert(output, else_result)
                    end
                end
                
            elseif node.name == "include" then
                -- Include block
                local include_result = process_include(node.args, context)
                table.insert(output, include_result)
                
            else
                -- Unknown block type
                if node.content then
                    -- Render the content anyway
                    local content_result = Renderer.render(node.content, context)
                    table.insert(output, content_result)
                else
                    table.insert(output, "<!-- Unknown block type: " .. node.name .. " -->")
                end
            end
        end
    end
    
    return table.concat(output)
end

-- Clear the include stack (helpful for debugging)
function Renderer.clear_include_stack()
    include_stack = {}
end

-- Set the template directory for includes
-- @param dir Directory path
function Renderer.set_template_dir(dir)
    template_dir = dir
    -- Reset include_stack when setting a new template directory
    include_stack = {}
end

-- Enable or disable debug mode
function Renderer.set_debug_mode(enabled)
    debug_mode = enabled
end

-- Add a custom filter
-- @param name Filter name
-- @param filter_func Filter function
function Renderer.add_filter(name, filter_func)
    if type(name) == "string" and type(filter_func) == "function" then
        filters[name] = filter_func
        return true
    end
    return false
end

-- Get the current template directory
function Renderer.get_template_dir()
    return template_dir
end

-- Public function to render a template file
function Renderer.render_file(file_path, context)
    -- Check if file exists
    local file, err = io.open(file_path, "r")
    if not file then
        return "<!-- Error: Cannot open template file: " .. file_path .. " (" .. (err or "unknown error") .. ") -->"
    end
    
    -- Try to get the parsed template from cache
    local parsed = get_cached_template(file_path)
    
    -- If not found in cache, read from file and cache it
    if not parsed then
        -- Read the template
        local content = file:read("*a")
        file:close()
        
        -- Parse the template
        local Parser = require('luneapi.template.parser')
        parsed = Parser.parse(content)
        
        -- Cache the parsed template
        cache_template(file_path, parsed)
    else
        file:close()
    end
    
    -- Render the template with the context
    return Renderer.render(parsed, context)
end

-- Enable or disable template caching
function Renderer.set_cache_enabled(enabled)
    cache_enabled = enabled
    if not enabled then
        clear_cache()
    end
end

-- Set the maximum cache size
function Renderer.set_max_cache_size(size)
    max_cache_size = size
    -- If new size is smaller than current cache, trim it
    while #template_cache > max_cache_size do
        table.remove(template_cache, 1)
    end
end

-- Clear the template cache
function Renderer.clear_cache()
    clear_cache()
end

-- Get cache statistics
function Renderer.get_cache_stats()
    return get_cache_stats()
end

return Renderer 