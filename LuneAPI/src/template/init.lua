-- Template Engine for LuneAPI
-- Inspired by Jinja2, provides templating capabilities
-- Encapsulates template loading, compiling, and rendering functionality

local Parser = require('luneapi.template.parser')
local Renderer = require('luneapi.template.renderer')
local lfs = pcall(require, "lfs") and require("lfs") or nil

local Template = {}
Template.__index = Template

-- Default error handling function
local function default_error_handler(err)
    print("Template error: " .. tostring(err))
    return "<!-- Template error: " .. tostring(err) .. " -->"
end

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

-- Helper function to extract directory and filename from a path
local function split_path(file_path)
    local dir, file
    
    if file_path:match("/") then
        dir = file_path:match("^(.+)/[^/]+$")
        file = file_path:match("^.+/([^/]+)$")
    else
        dir = "."
        file = file_path
    end
    
    return dir, file
end

-- Create a new Template instance
-- @param template_path (optional) Path to a template file or template string
-- @param is_string (optional) Boolean indicating if template_path is actually a template string
-- @return Template instance
function Template.new(template_path, is_string)
    local self = setmetatable({}, Template)
    
    -- Initialize instance variables
    self._template_dir = nil
    self._error_handler = default_error_handler
    self._compiled = nil
    self._template_string = nil
    self._template_path = nil
    
    -- If template_path is provided, load or compile it
    if template_path then
        if is_string then
            self:set_template_string(template_path)
        else
            self:load_template(template_path)
        end
    end
    
    return self
end

-- Load a template from file
-- @param file_path Path to template file
-- @return self (for method chaining)
function Template:load_template(file_path)
    self._template_path = file_path
    
    -- Check if template directory is not set but can be extracted from file path
    if not self._template_dir and file_path:match("/") then
        local dir = file_path:match("^(.+)/[^/]+$")
        if dir then
            self:set_template_dir(dir)
        end
    end
    
    local file, err = io.open(file_path, "r")
    if not file then
        self._error = self._error_handler("Failed to load template file: " .. tostring(err))
        return self
    end
    
    local content = file:read("*a")
    file:close()
    
    self._template_string = content
    self:compile()
    
    return self
end

-- Set a template from string
-- @param template_str Template string
-- @return self (for method chaining)
function Template:set_template_string(template_str)
    if not template_str then
        self._error = self._error_handler("Cannot set nil template string")
        return self
    end
    
    self._template_string = template_str
    self._template_path = nil
    self:compile()
    
    return self
end

-- Compile the template
-- @return self (for method chaining)
function Template:compile()
    if not self._template_string then
        self._error = self._error_handler("No template to compile")
        return self
    end
    
    local success, result = pcall(Parser.parse, self._template_string)
    if not success then
        self._error = self._error_handler("Error parsing template: " .. result)
        return self
    end
    
    self._compiled = result
    return self
end

-- Render the template with the given context
-- @param context Data context for rendering
-- @param template_name (optional) Template filename relative to template_dir
-- @return Rendered string or error message
function Template:render(context, template_name)
    -- If a template_name is provided, load that template first
    if template_name and self._template_dir then
        local template_path = self._template_dir .. "/" .. template_name
        local success, err = self:load_template(template_path)
        if self._error then
            return self._error
        end
    end
    
    -- If there was an error in previous steps, return the error
    if self._error then
        return self._error
    end
    
    -- If not compiled yet, try to compile
    if not self._compiled then
        self:compile()
        if self._error then
            return self._error
        end
    end
    
    -- Now render the template
    local success, result = pcall(Renderer.render, self._compiled, context or {})
    if not success then
        return self._error_handler("Error rendering template: " .. result)
    end
    
    return result
end

-- Set template directory (for includes)
-- @param dir Directory path
-- @return self (for method chaining)
function Template:set_template_dir(dir)
    if not dir then
        self._error = self._error_handler("Cannot set template directory to nil")
        return self
    end
    
    -- Normalize the path
    dir = normalize_path(dir)
    
    -- Check if directory exists
    if not directory_exists(dir) then
        local message = "Template directory does not exist: " .. dir
        print("Warning: " .. message)
        -- Don't fail completely, allow the directory to be set even if it doesn't exist yet
    end
    
    self._template_dir = dir
    Renderer.set_template_dir(dir)
    return self
end

-- Get the current template directory
-- @return Template directory path
function Template:get_template_dir()
    return self._template_dir
end

-- Set custom error handler
-- @param handler Function that takes an error message and returns a string
-- @return self (for method chaining)
function Template:set_error_handler(handler)
    if type(handler) == "function" then
        self._error_handler = handler
    else
        self._error_handler = default_error_handler
    end
    return self
end

-- Reset error handler to default
-- @return self (for method chaining)
function Template:reset_error_handler()
    self._error_handler = default_error_handler
    return self
end

-- Add a custom filter function
-- @param name Filter name
-- @param filter_func Filter function
-- @return success boolean
function Template:add_filter(name, filter_func)
    if type(name) ~= "string" or type(filter_func) ~= "function" then
        return false
    end
    return Renderer.add_filter(name, filter_func)
end

-- Static convenience method to render a template file directly
-- @param file_path Path to template file
-- @param context Data context for rendering
-- @return Rendered string
function Template.render_file(file_path, context)
    local template = Template.new(file_path)
    return template:render(context)
end

-- Static convenience method to render a template string directly
-- @param template_str Template string
-- @param context Data context for rendering
-- @return Rendered string
function Template.render_string(template_str, context)
    local template = Template.new(template_str, true)
    return template:render(context)
end

-- Static convenience method to render a template by name from a given directory
-- @param file_path Full path to the template file
-- @param context Data context for rendering
-- @return Rendered string
function Template.render_template(file_path, context)
    -- Extract directory and filename from the path
    local dir, file = split_path(file_path)
    
    local template = Template.new()
    template:set_template_dir(dir)
    return template:render(context, file)
end

return Template 