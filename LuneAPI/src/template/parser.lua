-- Template Parser for LuneAPI
-- Parses template syntax into a structured format for rendering

local Parser = {}

-- Tag patterns
local VAR_PATTERN = "{{%s*(.-)%s*}}"         -- {{ variable }}
local BLOCK_START_PATTERN = "{%%%s*(%S+)%s*(.-)%s*%%}" -- {% tag arguments %}
local BLOCK_END_PATTERN = "{%%%s*end(%S*)%s*%%}" -- {% endtag %}
local COMMENT_PATTERN = "{#%s*(.-)%s*#}"    -- {# comment #}

-- Parse a template string into a structured format
-- @param template_str Template string
-- @return Table representation of the parsed template
function Parser.parse(template_str)
    local result = {}
    local position = 1
    local length = template_str:len()
    
    -- Helper to add text node
    local function add_text(text)
        if text and text ~= "" then
            table.insert(result, { type = "text", value = text })
        end
    end
    
    -- Helper for parsing block arguments
    local function parse_args(args_str)
        local args = {}
        
        -- Parse for loops: "item in items"
        local var, collection = args_str:match("(%S+)%s+in%s+(%S+)")
        if var and collection then
            return { var = var, collection = collection }
        end
        
        -- Parse if conditions
        return args_str:gsub("^%s*", ""):gsub("%s*$", "")
    end
    
    -- Parse block content recursively
    local function parse_block(end_tag)
        local block_content = {}
        local block_pos = 1
        
        while block_pos <= #result do
            if result[block_pos].type == "block_start" and 
               result[block_pos].name == end_tag:gsub("^end", "") then
                -- Found a nested block of the same type
                local nested_content = parse_block("end" .. result[block_pos].name)
                
                -- Add the nested block content to current block
                result[block_pos].content = nested_content
                result[block_pos].type = "block"
                
                -- Remove processed nodes from result
                local to_remove = #nested_content + 1  -- +1 for the end tag
                for i = 1, to_remove do
                    table.remove(result, block_pos + 1)
                end
            elseif result[block_pos].type == "block_end" and 
                   result[block_pos].name == end_tag then
                -- Found our end tag, extract all content up to this point
                for i = 1, block_pos - 1 do
                    table.insert(block_content, result[1])
                    table.remove(result, 1)
                end
                
                -- Remove the end tag
                table.remove(result, 1)
                return block_content
            else
                -- Move to next node
                block_pos = block_pos + 1
            end
        end
        
        error("Missing end tag: " .. end_tag)
    end
    
    -- Process the template string
    while position <= length do
        -- Try to match variable
        local var_start, var_end, var = template_str:find(VAR_PATTERN, position)
        
        -- Try to match block start
        local block_start, block_end, block_name, block_args = template_str:find(BLOCK_START_PATTERN, position)
        
        -- Try to match block end
        local end_start, end_end, end_tag = template_str:find(BLOCK_END_PATTERN, position)
        
        -- Try to match comment
        local comment_start, comment_end = template_str:find(COMMENT_PATTERN, position)
        
        -- Determine what comes first
        local first_start = math.min(
            var_start or math.huge, 
            block_start or math.huge,
            end_start or math.huge,
            comment_start or math.huge
        )
        
        if first_start == math.huge then
            -- No more tags, add the rest as text
            add_text(template_str:sub(position))
            break
        end
        
        -- Add text before the tag
        add_text(template_str:sub(position, first_start - 1))
        
        if first_start == var_start then
            -- Process variable
            table.insert(result, { type = "variable", name = var })
            position = var_end + 1
        elseif first_start == block_start then
            -- Process block start
            table.insert(result, { 
                type = "block_start", 
                name = block_name, 
                args = parse_args(block_args or "") 
            })
            position = block_end + 1
        elseif first_start == end_start then
            -- Process block end
            table.insert(result, { type = "block_end", name = end_tag })
            position = end_end + 1
        elseif first_start == comment_start then
            -- Skip comments
            position = comment_end + 1
        end
    end
    
    -- Process blocks
    local i = 1
    while i <= #result do
        if result[i].type == "block_start" then
            local block_name = result[i].name
            local end_tag = "end" .. block_name
            
            -- Parse block content
            local content = parse_block(end_tag)
            
            -- Update the block node
            result[i].type = "block"
            result[i].content = content
        end
        i = i + 1
    end
    
    return result
end

return Parser 