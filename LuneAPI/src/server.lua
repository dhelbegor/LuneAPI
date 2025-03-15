-- HTTP server logic for LuneAPI

-- This file will handle incoming connections and delegate requests to the router. 

local http_server = require('http.server')
local http_headers = require('http.headers')
local Router = require('router')
local Middleware = require('middleware')
local config = require('config')

local Server = {}
Server.__index = Server

function Server:new(host, port)
    local instance = setmetatable({}, self)
    instance.host = host or config.server.host
    instance.port = port or config.server.port
    instance.router = Router:new()
    instance.middleware = Middleware:new()
    
    -- Load middleware from config
    for _, mw in ipairs(config.middleware) do
        instance:add_middleware(mw)
    end
    
    instance.server = http_server.listen({
        host = instance.host,
        port = instance.port,
        onstream = function(server, stream)
            local req_headers = assert(stream:get_headers())
            local method = req_headers:get(':method')
            local path = req_headers:get(':path')
            
            -- Create request and response objects
            local request = { method = method, path = path }
            local response = {}
            
            -- Execute middleware
            if not instance.middleware:execute_all(request, response) then
                local res_headers = http_headers.new()
                res_headers:append(':status', '403')
                res_headers:append('content-type', 'text/plain')
                assert(stream:write_headers(res_headers, false))
                assert(stream:write_chunk('Forbidden', true))
                return
            end
            
            -- Dispatch request to the router
            local status, headers, body = instance.router:resolve(method, path)
            
            local res_headers = http_headers.new()
            res_headers:append(':status', tostring(status))
            res_headers:append('content-type', 'text/plain')
            assert(stream:write_headers(res_headers, false))
            assert(stream:write_chunk(body, true))
        end,
    })
    return instance
end

function Server:add_route(method, path, handler)
    self.router:add_route(method, path, handler)
end

function Server:add_middleware(middleware)
    self.middleware:use(middleware)
end

function Server:handle_request(method, path)
    -- Placeholder for routing logic
    return 200, {}, 'Hello, World!'
end

function Server:run()
    self.server:loop()
end

return Server 