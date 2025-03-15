-- Route definitions for LuneAPI

-- This file will map paths to handler functions. 

local Router = {}
Router.__index = Router

function Router:new()
    local instance = setmetatable({}, self)
    instance.routes = {}
    return instance
end

function Router:add_route(method, path, handler)
    self.routes[method] = self.routes[method] or {}
    self.routes[method][path] = handler
end

function Router:resolve(method, path)
    local method_routes = self.routes[method]
    if method_routes then
        local handler = method_routes[path]
        if handler then
            return handler()
        end
    end
    return 404, {}, 'Not Found'
end

return Router 