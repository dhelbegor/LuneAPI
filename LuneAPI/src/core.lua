-- Core framework logic for LuneAPI

-- This file will contain the main logic for the microframework. 

local Server = require('server')
local config = require('config')

local Core = {}
Core.__index = Core

function Core:new()
    local instance = setmetatable({}, self)
    instance.server = Server:new(config.server.host, config.server.port)
    return instance
end

function Core:add_route(method, path, handler)
    self.server:add_route(method, path, handler)
end

function Core:run()
    print("Starting server on " .. config.server.host .. ":" .. config.server.port)
    self.server:run()
end

return Core 