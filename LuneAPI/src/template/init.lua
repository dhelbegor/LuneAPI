-- Template Engine for LuneAPI
-- A lightweight template rendering system inspired by Jinja2

local Parser = require('luneapi.template.parser')
local Renderer = require('luneapi.template.renderer')

local Template = {}

-- Load and compile a template from a file
-- @param file_path Path to template file
-- @return Compiled template object
function Template.load_file(file_path)
    local file, err = io.open(file_path, "r")
    if not file then
        error("Failed to load template file: " .. tostring(err))
    end
    
    local content = file:read("*a")
    file:close()
    
    return Template.compile(content)
end

-- Compile a template string
-- @param template_str Template string
-- @return Compiled template object
function Template.compile(template_str)
    local parsed = Parser.parse(template_str)
    
    -- Return a template object with a render method
    return {
        render = function(context)
            return Renderer.render(parsed, context or {})
        end
    }
end

-- Render a template string directly with context
-- @param template_str Template string
-- @param context Data context for rendering
-- @return Rendered string
function Template.render(template_str, context)
    local template = Template.compile(template_str)
    return template.render(context or {})
end

-- Render a template file directly with context
-- @param file_path Path to template file
-- @param context Data context for rendering
-- @return Rendered string
function Template.render_file(file_path, context)
    local template = Template.load_file(file_path)
    return template.render(context or {})
end

-- Set template directory (for includes)
function Template.set_template_dir(dir)
    Renderer.set_template_dir(dir)
end

-- Add a custom filter function
-- @param name Filter name
-- @param filter_func Filter function
function Template.add_filter(name, filter_func)
    Renderer.add_filter(name, filter_func)
end

return Template 