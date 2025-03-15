-- Middleware processing for LuneAPI

-- This file will implement a basic middleware system. 

local Middleware = {}
Middleware.__index = Middleware

function Middleware:new()
    local instance = setmetatable({}, self)
    instance.middlewares = {}
    return instance
end

function Middleware:use(middleware)
    table.insert(self.middlewares, middleware)
end

function Middleware:execute_all(request, response)
    for _, middleware in ipairs(self.middlewares) do
        local continue = middleware(request, response)
        if not continue then
            return false
        end
    end
    return true
end

return Middleware 