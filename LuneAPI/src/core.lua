-- Core framework logic for LuneAPI

-- This file will contain the main logic for the microframework. 

local Server = require('luneapi.server')
local config = require('luneapi.config')
local Template = require('luneapi.template')

local Core = {}
Core.__index = Core

function Core.new()
    local instance = {}
    setmetatable(instance, { __index = Core })
    instance.server = Server:new(config.server.host, config.server.port)
    
    -- Expose the server's middleware for direct access
    instance.middleware = instance.server.middleware
    
    -- Expose the template engine
    instance.template = Template
    
    -- Explicitly add HTTP methods to the instance
    instance.get = function(self, path, handler)
        self:add_route('GET', path, handler)
    end
    
    instance.post = function(self, path, handler)
        self:add_route('POST', path, handler)
    end
    
    instance.put = function(self, path, handler)
        self:add_route('PUT', path, handler)
    end
    
    instance.delete = function(self, path, handler)
        self:add_route('DELETE', path, handler)
    end
    
    instance.route = function(self, method, path, handler)
        self:add_route(method, path, handler)
    end
    
    instance.add_route = function(self, method, path, handler)
        self.server:add_route(method, path, handler)
    end
    
    instance.run = function(self)
        print("Starting server on " .. config.server.host .. ":" .. config.server.port)
        self.server:run()
    end
    
    instance.listen = function(self, port, callback)
        if port then
            config.server.port = port
        end
        
        if callback and type(callback) == "function" then
            callback()
        end
        
        self:run()
    end
    
    -- Add a helper method for rendering templates directly in response
    instance.render = function(self, template_path, context)
        -- If template_dir isn't set yet, use a default
        if not Template._template_dir then
            Template.set_template_dir("./templates")
        end
        
        return Template.render_file(template_path, context)
    end
    
    -- Set template directory
    instance.set_template_dir = function(self, dir)
        Template.set_template_dir(dir)
    end
    
    -- Debug prints
    print("Core.new - instance:", instance)
    print("Core.new - get method:", instance.get)
    
    return instance
end

function Core:add_route(method, path, handler)
    self.server:add_route(method, path, handler)
end

function Core:get(path, handler)
    self:add_route('GET', path, handler)
end

function Core:route(method, path, handler)
    self:add_route(method, path, handler)
end

function Core:post(path, handler)
    self:route('POST', path, handler)
end

function Core:put(path, handler)
    self:route('PUT', path, handler)
end

function Core:delete(path, handler)
    self:route('DELETE', path, handler)
end

function Core:run()
    print("Starting server on " .. config.server.host .. ":" .. config.server.port)
    self.server:run()
end

-- Set the template directory for the template engine
function Core:set_template_dir(dir)
    self.template.set_template_dir(dir)
end

-- Render a template with context
function Core:render(template_path, context)
    -- If template_dir isn't set yet, use a default
    if not self.template._template_dir then
        self.template.set_template_dir("./templates")
    end
    
    return self.template.render_file(template_path, context)
end

return Core 