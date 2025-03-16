-- Template Engine for LuneAPI
-- A lightweight template rendering system inspired by Jinja2

local Parser = require('luneapi.template.parser')
local Renderer = require('luneapi.template.renderer')
local lfs = pcall(require, "lfs") and require("lfs") or nil

local Template = {}

-- Template directory for includes (accessible to other modules)
Template._template_dir = nil

-- Default error handling function
local function default_error_handler(err)
    print("Template error: " .. tostring(err))
    return "<!-- Template error: " .. tostring(err) .. " -->"
end

-- Current error handler
local error_handler = default_error_handler

-- Helper function to normalize directory path
local function normalize_path(path)
    -- Replace backslashes with forward slashes
    path = path:gsub("\\", "/")
    
    -- Remove trailing slash if present
    if path:sub(-1) == "/" then
        path = path:sub(1, -2)
    end
    
    return path
end

-- Helper function to check if a directory exists
local function directory_exists(path)
    if lfs then
        local attr = lfs.attributes(path)
        return attr and attr.mode == "directory"
    else
        -- Fallback if lfs is not available
        local f = io.open(path .. "/.directory_check", "w")
        if f then
            f:close()
            os.remove(path .. "/.directory_check")
            return true
        end
        return false
    end
end

-- Load and compile a template from a file
-- @param file_path Path to template file
-- @return Compiled template object
function Template.load_file(file_path)
    -- Check if template directory is set
    if not Template._template_dir and file_path:match("/") then
        -- Try to extract directory from file path
        local dir = file_path:match("^(.+)/[^/]+$")
        if dir then
            Template.set_template_dir(dir)
        end
    end
    
    local file, err = io.open(file_path, "r")
    if not file then
        return error_handler("Failed to load template file: " .. tostring(err))
    end
    
    local content = file:read("*a")
    file:close()
    
    return Template.compile(content)
end

-- Compile a template string
-- @param template_str Template string
-- @return Compiled template object
function Template.compile(template_str)
    local parsed, parse_error
    
    -- Try to parse the template
    if not template_str then
        return error_handler("Cannot compile nil template string")
    end
    
    local success, result = pcall(Parser.parse, template_str)
    if not success then
        return error_handler("Error parsing template: " .. result)
    end
    
    parsed = result
    
    -- Return a template object with a render method
    return {
        render = function(context)
            local success, result = pcall(Renderer.render, parsed, context or {})
            if not success then
                return error_handler("Error rendering template: " .. result)
            end
            return result
        end
    }
end

-- Render a template string directly with context
-- @param template_str Template string
-- @param context Data context for rendering
-- @return Rendered string
function Template.render(template_str, context)
    local template = Template.compile(template_str)
    if type(template) == "string" then
        -- Error already handled and returned as string
        return template
    end
    return template.render(context or {})
end

-- Render a template file directly with context
-- @param file_path Path to template file
-- @param context Data context for rendering
-- @return Rendered string
function Template.render_file(file_path, context)
    local template = Template.load_file(file_path)
    if type(template) == "string" then
        -- Error already handled and returned as string
        return template
    end
    return template.render(context or {})
end

-- Set template directory (for includes)
-- @param dir Directory path
function Template.set_template_dir(dir)
    if not dir then
        error_handler("Cannot set template directory to nil")
        return false
    end
    
    -- Normalize the path
    dir = normalize_path(dir)
    
    -- Check if directory exists
    if not directory_exists(dir) then
        local message = "Template directory does not exist: " .. dir
        print("Warning: " .. message)
        -- Don't fail completely, allow the directory to be set even if it doesn't exist yet
    end
    
    Template._template_dir = dir
    Renderer.set_template_dir(dir)
    return true
end

-- Get the current template directory
function Template.get_template_dir()
    return Template._template_dir
end

-- Set custom error handler
-- @param handler Function that takes an error message and returns a string
function Template.set_error_handler(handler)
    if type(handler) == "function" then
        error_handler = handler
    else
        error_handler = default_error_handler
    end
end

-- Reset error handler to default
function Template.reset_error_handler()
    error_handler = default_error_handler
end

-- Add a custom filter function
-- @param name Filter name
-- @param filter_func Filter function
function Template.add_filter(name, filter_func)
    return Renderer.add_filter(name, filter_func)
end

return Template 