-- Template Renderer for LuneAPI
-- Renders parsed templates with context data

local Renderer = {}

-- Template directory for includes
local template_dir = nil

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
    
    -- Format a number with comma as thousands separator
    number_format = function(val, decimals)
        decimals = decimals or 0
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
        return val
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
        return tostring(val or "")
            :gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub('"', "&quot;")
            :gsub("'", "&#39;")
    end
}

-- Helper function to get nested value from context
local function get_value(context, var_name)
    if var_name == "" then return nil end
    
    -- Handle nested properties (e.g., user.name)
    local parts = {}
    for part in var_name:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    
    local value = context
    for _, part in ipairs(parts) do
        -- Handle array indexing (e.g., items[1])
        local name, index = part:match("^([^%[]+)%[(%d+)%]$")
        if name and index then
            value = value[name]
            if type(value) == "table" then
                value = value[tonumber(index)]
            else
                return nil
            end
        else
            -- Regular property access
            if type(value) == "table" then
                value = value[part]
            else
                return nil
            end
        end
        
        -- If value becomes nil, stop traversing
        if value == nil then return nil end
    end
    
    return value
end

-- Function to evaluate conditions for if blocks
local function evaluate_condition(condition, context)
    -- Handle empty condition (truthy check on variable)
    if condition:match("^%s*$") then
        return false
    end
    
    -- Handle negation (not var)
    local negated = false
    if condition:match("^%s*not%s+") then
        negated = true
        condition = condition:gsub("^%s*not%s+", "")
    end
    
    -- Handle equality (var == value)
    local left, op, right = condition:match("([^=!<>]-)%s*([=!<>][=]?)%s*(.+)")
    if left and op and right then
        -- Get left value from context
        local left_val = get_value(context, left:gsub("^%s*", ""):gsub("%s*$", ""))
        
        -- Parse right value (might be a literal or a variable)
        local right_val
        if right:match('^".*"$') or right:match("^'.*'$") then
            -- String literal
            right_val = right:sub(2, -2)
        elseif right:match("^%d+%.?%d*$") then
            -- Number literal
            right_val = tonumber(right)
        else
            -- Try as a variable
            right_val = get_value(context, right:gsub("^%s*", ""):gsub("%s*$", ""))
        end
        
        -- Compare values based on operator
        local result
        if op == "==" then
            result = left_val == right_val
        elseif op == "!=" then
            result = left_val ~= right_val
        elseif op == ">" then
            result = left_val > right_val
        elseif op == ">=" then
            result = left_val >= right_val
        elseif op == "<" then
            result = left_val < right_val
        elseif op == "<=" then
            result = left_val <= right_val
        end
        
        return negated and not result or result
    end
    
    -- Simple variable check
    local var_value = get_value(context, condition:gsub("^%s*", ""):gsub("%s*$", ""))
    
    -- Handle boolean values and nil
    if type(var_value) == "boolean" then
        return negated and not var_value or var_value
    end
    
    -- Check if the value exists and is not false/nil
    local result = var_value ~= nil and var_value ~= false
    return negated and not result or result
end

-- Apply filters to a value (e.g., {{ name|upper|truncate(20) }})
local function apply_filters(value, filter_str)
    if not filter_str or filter_str == "" then
        return value
    end
    
    -- Split into individual filters
    for filter_expr in filter_str:gmatch("([^|]+)") do
        -- Extract filter name and arguments
        local filter_name, args = filter_expr:match("^%s*([%w_]+)%s*%(?(.-)%)?%s*$")
        
        if filter_name and filters[filter_name] then
            -- Parse arguments if any
            local filter_args = {value}
            if args and args ~= "" then
                for arg in args:gmatch("([^,]+)") do
                    -- Handle string literals
                    if arg:match('^".*"$') or arg:match("^'.*'$") then
                        table.insert(filter_args, arg:sub(2, -2))
                    -- Handle numbers
                    elseif arg:match("^%d+%.?%d*$") then
                        table.insert(filter_args, tonumber(arg))
                    -- Handle other values (as strings)
                    else
                        table.insert(filter_args, arg:gsub("^%s*", ""):gsub("%s*$", ""))
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
    -- Split variable name and filters
    local var_name, filter_str = var_expr:match("^%s*([^|]+)(.*)$")
    if not var_name then
        return ""
    end
    
    -- Get value from context
    local value = get_value(context, var_name:gsub("^%s*", ""):gsub("%s*$", ""))
    
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

-- Render a parsed template with context data
-- @param parsed Parsed template data from Parser.parse
-- @param context Data context for rendering
-- @return Rendered string
function Renderer.render(parsed, context)
    local output = {}
    
    for _, node in ipairs(parsed) do
        if node.type == "text" then
            -- Render text node directly
            table.insert(output, node.value)
        
        elseif node.type == "variable" then
            -- Process variable with filters
            table.insert(output, process_variable(node.name, context))
        
        elseif node.type == "block" then
            if node.name == "if" then
                -- Process if block
                if evaluate_condition(node.args, context) then
                    -- Condition is true, render content
                    table.insert(output, Renderer.render(node.content, context))
                end
            
            elseif node.name == "for" then
                -- Process for loop
                local var_name = node.args.var
                local collection_name = node.args.collection
                local collection = get_value(context, collection_name)
                
                if type(collection) == "table" then
                    -- Iterate over the collection
                    for i, item in ipairs(collection) do
                        -- Create a new context for the loop iteration
                        local loop_context = {}
                        for k, v in pairs(context) do
                            loop_context[k] = v
                        end
                        
                        -- Add the loop variable and loop metadata
                        loop_context[var_name] = item
                        loop_context.loop = {
                            index = i,
                            index0 = i - 1,
                            first = i == 1,
                            last = i == #collection,
                            length = #collection
                        }
                        
                        -- Render the loop content with the loop context
                        table.insert(output, Renderer.render(node.content, loop_context))
                    end
                end
            
            elseif node.name == "include" then
                -- Process include
                local template_name = node.args:gsub("^%s*", ""):gsub("%s*$", "")
                
                -- Remove quotes if present
                if template_name:match('^".*"$') or template_name:match("^'.*'$") then
                    template_name = template_name:sub(2, -2)
                end
                
                if template_dir then
                    local file_path = template_dir .. "/" .. template_name
                    
                    local file, err = io.open(file_path, "r")
                    if file then
                        local content = file:read("*a")
                        file:close()
                        
                        -- Parse and render the included template
                        local Parser = require('luneapi.template.parser')
                        local included = Parser.parse(content)
                        table.insert(output, Renderer.render(included, context))
                    else
                        table.insert(output, "<!-- Include failed: " .. file_path .. " -->")
                    end
                else
                    table.insert(output, "<!-- Include failed: template_dir not set -->")
                end
            end
        end
    end
    
    return table.concat(output)
end

-- Set the template directory for includes
-- @param dir Directory path
function Renderer.set_template_dir(dir)
    template_dir = dir
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

return Renderer 