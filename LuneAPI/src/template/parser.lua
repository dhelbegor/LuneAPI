-- Template Parser for LuneAPI
-- Parses template files into a structure that can be used by the renderer

local Parser = {}

-- Tags that don't need a closing tag
local SELF_CLOSING_TAGS = {
    ["include"] = true,
    ["extends"] = true,
    ["import"] = true,
    ["set"] = true
}

-- Parse a template string
-- @param template_str The template string to parse
-- @return A parsed template structure
function Parser.parse(template_str)
    if not template_str then
        return {}
    end
    
    local tokens = {}
    local pos = 1
    local len = #template_str
    local inside_pre = false
    
    -- Main parsing loop - first tokenize everything
    while pos <= len do
        -- Check for pre tags (to skip processing inside them)
        local pre_start = template_str:find("<pre", pos)
        local pre_end = template_str:find("</pre>", pos)
        
        -- Handle entering/exiting pre tags
        if pre_start and (not pre_end or pre_start < pre_end) and not inside_pre then
            -- Add text before pre tag
            if pre_start > pos then
                table.insert(tokens, {
                    type = "text",
                    value = template_str:sub(pos, pre_start - 1)
                })
            end
            
            -- Find the end of the pre opening tag
            local pre_tag_end = template_str:find(">", pre_start)
            if pre_tag_end then
                inside_pre = true
                
                -- Add the pre opening tag as text
                table.insert(tokens, {
                    type = "text",
                    value = template_str:sub(pre_start, pre_tag_end)
                })
                
                pos = pre_tag_end + 1
            else
                -- Malformed pre tag, treat as text
                table.insert(tokens, {
                    type = "text",
                    value = template_str:sub(pre_start, pre_start + 3)
                })
                pos = pre_start + 4
            end
            
            -- Continue to next iteration
            goto continue
        elseif pre_end and inside_pre then
            -- Add everything inside pre tag as plain text
            table.insert(tokens, {
                type = "text",
                value = template_str:sub(pos, pre_end + 5)
            })
            
            inside_pre = false
            pos = pre_end + 6
            
            -- Continue to next iteration
            goto continue
        end
        
        -- If we're inside a pre tag, continue to the end or next check
        if inside_pre then
            local next_check_pos = pre_end or len + 1
            table.insert(tokens, {
                type = "text",
                value = template_str:sub(pos, next_check_pos - 1)
            })
            pos = next_check_pos
            goto continue
        end
        
        -- Regular template tag processing for content not in pre tags
        -- Look for opening tags
        local var_start = template_str:find("{{", pos)
        local block_start = template_str:find("{%%", pos)
        
        -- Determine which tag comes first
        local start_pos, tag_type
        if var_start and block_start then
            if var_start < block_start then
                start_pos = var_start
                tag_type = "variable"
            else
                start_pos = block_start
                tag_type = "block"
            end
        elseif var_start then
            start_pos = var_start
            tag_type = "variable"
        elseif block_start then
            start_pos = block_start
            tag_type = "block"
        else
            -- No more tags, add the rest as text
            if pos <= len then
                table.insert(tokens, {
                    type = "text",
                    value = template_str:sub(pos)
                })
            end
            break
        end
        
        -- Add text before the tag
        if start_pos > pos then
            table.insert(tokens, {
                type = "text",
                value = template_str:sub(pos, start_pos - 1)
            })
        end
        
        -- Process the tag
        if tag_type == "variable" then
            -- Variable tag {{ var }}
            local var_end = template_str:find("}}", start_pos)
            if var_end then
                -- Extract variable name
                local var_name = template_str:sub(start_pos + 2, var_end - 1):gsub("^%s*(.-)%s*$", "%1")
                table.insert(tokens, {
                    type = "variable",
                    value = var_name
                })
                
                pos = var_end + 2
            else
                -- Unclosed variable tag, treat as text
                table.insert(tokens, {
                    type = "text",
                    value = template_str:sub(start_pos, start_pos + 1)
                })
                pos = start_pos + 2
            end
        else
            -- Block tag {% tag %}
            local block_end = template_str:find("%%}", start_pos)
            if block_end then
                -- Extract block content
                local block_content = template_str:sub(start_pos + 2, block_end - 1):gsub("^%s*(.-)%s*$", "%1")
                
                -- Parse the block tag
                local tag_name, args
                if block_content:match("^end") then
                    -- Closing tag
                    tag_name = block_content:match("^end%s*(%w*)")
                    if not tag_name or tag_name == "" then
                        tag_name = "end"
                    end
                    
                    table.insert(tokens, {
                        type = "block_end",
                        value = tag_name
                    })
                elseif block_content == "else" then
                    -- Else tag
                    table.insert(tokens, {
                        type = "else"
                    })
                else
                    -- Opening tag or self-closing
                    tag_name, args = block_content:match("^(%w+)%s*(.*)")
                    if tag_name then
                        local token_type = "block_start"
                        if SELF_CLOSING_TAGS[tag_name] then
                            token_type = "block"
                        end
                        
                        table.insert(tokens, {
                            type = token_type,
                            name = tag_name,
                            value = tag_name,
                            args = args or ""
                        })
                    else
                        -- Invalid block tag, treat as text
                        table.insert(tokens, {
                            type = "text",
                            value = template_str:sub(start_pos, block_end + 1)
                        })
                    end
                end
                
                pos = block_end + 2
            else
                -- Unclosed block tag, treat as text
                table.insert(tokens, {
                    type = "text",
                    value = template_str:sub(start_pos, start_pos + 1)
                })
                pos = start_pos + 2
            end
        end
        
        -- Continue label for skipping parts of the loop
        ::continue::
    end
    
    -- Now build the nested structure from tokens
    local result = {}
    local sections = {}  -- Stack for tracking open sections
    
    local i = 1
    while i <= #tokens do
        local token = tokens[i]
        
        if token.type == "block_start" then
            -- Start a new block
            local block = {
                type = "block",
                name = token.name,
                value = token.value,
                args = token.args,
                content = {},
                else_content = nil
            }
            
            -- Add to current section or result
            if #sections > 0 then
                local current = sections[#sections]
                if current.in_else then
                    table.insert(current.block.else_content, block)
                else
                    table.insert(current.block.content, block)
                end
            else
                table.insert(result, block)
            end
            
            -- Push onto section stack
            table.insert(sections, {block = block, in_else = false})
            
        elseif token.type == "block_end" then
            -- Close a block
            if #sections == 0 then
                -- No open block, add as text with warning
                table.insert(result, {
                    type = "text",
                    value = "<!-- Error: Unmatched closing tag: " .. token.value .. " -->"
                })
            else
                -- Pop the section
                table.remove(sections)
            end
            
        elseif token.type == "else" then
            -- Handle else tag
            if #sections > 0 then
                local current = sections[#sections]
                current.in_else = true
                current.block.else_content = current.block.else_content or {}
            else
                -- Stray else tag, add as text
                table.insert(result, {
                    type = "text",
                    value = "<!-- Error: Unmatched else tag -->"
                })
            end
            
        elseif token.type == "block" then
            -- Self-closing block
            if #sections > 0 then
                local current = sections[#sections]
                if current.in_else then
                    table.insert(current.block.else_content, token)
                else
                    table.insert(current.block.content, token)
                end
            else
                table.insert(result, token)
            end
            
        else
            -- Regular token (text, variable)
            if #sections > 0 then
                local current = sections[#sections]
                if current.in_else then
                    table.insert(current.block.else_content, token)
                else
                    table.insert(current.block.content, token)
                end
            else
                table.insert(result, token)
            end
        end
        
        i = i + 1
    end
    
    -- Handle unclosed sections
    while #sections > 0 do
        local section = table.remove(sections)
        local warning = "<!-- Warning: Unclosed block: " .. section.block.name .. " -->"
        
        table.insert(section.block.content, {
            type = "text",
            value = warning
        })
    end
    
    return result
end

return Parser 