-- Configuration settings for LuneAPI

-- This file will store configuration settings for the framework. 

local config = {}

-- Server settings
config.server = {
    host = 'localhost',
    port = 8080
}

-- Logging settings
config.logging = {
    level = 'INFO',
    file = 'logs/server.log'
}

-- Request settings
config.request = {
    timeout = 30  -- in seconds
}

-- Security settings
config.security = {
    enable_cors = true,
    allowed_origins = {'*'}  -- Allow all origins
}

-- Miscellaneous
config.debug = false

-- Middleware settings
config.middleware = {
    function(request, response)
        -- Example middleware: Logging
        print("Middleware: Received request", request.method, request.path)
        return true
    end,
    -- Add more middleware functions here
}

return config 