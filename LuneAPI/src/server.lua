-- HTTP server logic for LuneAPI
-- Simplified implementation using direct sockets

local socket = require("socket")
local Router = require('luneapi.router')
local Middleware = require('luneapi.middleware')
local URLParser = require('luneapi.url_parser')
local config = require('luneapi.config')

-- Define the Server table
local Server = {}
Server.__index = Server

-- DEBUG FLAG - Set to false for production, true for development
local DEBUG_MODE = false

-- Utility function to check if a value is in a table
local function contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- Debug utility for printing tables
local function debug_print_table(t, indent)
    if not DEBUG_MODE then return end
    
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(spaces .. k .. " = {")
            debug_print_table(v, indent + 1)
            print(spaces .. "}")
        else
            print(spaces .. k .. " = " .. tostring(v))
        end
    end
end

-- Parse HTTP headers from raw request
local function parse_headers(raw_request)
    local headers = {}
    local lines = {}
    
    -- Split request into lines
    for line in string.gmatch(raw_request, "[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- Parse first line (request line)
    local method, path, protocol = string.match(lines[1] or "", "^(%S+)%s+(%S+)%s+(%S+)")
    headers["method"] = method
    headers["path"] = path
    headers["protocol"] = protocol
    
    -- Parse remaining headers
    for i = 2, #lines do
        local name, value = string.match(lines[i], "^([^:]+):%s*(.+)")
        if name and value then
            headers[string.lower(name)] = value
        end
    end
    
    return headers
end

-- Send HTTP response
local function send_response(client, status, headers, body)
    body = body or ""
    
    -- Ensure headers table exists
    headers = headers or {}
    
    -- Stringify status code
    local status_code = tostring(status or 200)
    local status_text = {
        ["200"] = "OK",
        ["201"] = "Created",
        ["204"] = "No Content",
        ["301"] = "Moved Permanently",
        ["302"] = "Found",
        ["303"] = "See Other",
        ["304"] = "Not Modified",
        ["307"] = "Temporary Redirect",
        ["308"] = "Permanent Redirect",
        ["400"] = "Bad Request",
        ["401"] = "Unauthorized",
        ["403"] = "Forbidden",
        ["404"] = "Not Found",
        ["500"] = "Internal Server Error"
    }
    
    -- Build response
    local response = string.format("HTTP/1.1 %s %s\r\n", status_code, status_text[status_code] or "Unknown")
    
    -- Set default content type if not set
    if not headers["content-type"] and not headers["Content-Type"] then
        headers["Content-Type"] = "text/html; charset=utf-8"
    end
    
    -- Set content length
    headers["Content-Length"] = #body
    
    -- Add headers
    for name, value in pairs(headers) do
        response = response .. string.format("%s: %s\r\n", name, value)
    end
    
    -- Add empty line to separate headers from body
    response = response .. "\r\n"
    
    -- Add body
    if body and #body > 0 then
        response = response .. body
    end
    
    -- Send the response
    client:send(response)
    
    return true
end

-- Handle redirect responses
local function handle_redirect(client, url, status_code)
    status_code = status_code or 302
    
    if DEBUG_MODE then
        print("REDIRECT: Redirecting to " .. url .. " with status " .. status_code)
    end
    
    -- Create a response body with HTML and JavaScript redirect
    local body = string.format(
        '<html><body><h1>Redirecting to %s</h1><p><a href="%s">Click here if not redirected automatically</a></p><script>window.location.href="%s";</script></body></html>',
        url, url, url
    )
    
    -- Set headers
    local headers = {
        ["Location"] = url,
        ["Content-Type"] = "text/html; charset=utf-8",
        ["Connection"] = "close"
    }
    
    -- Send the response
    return send_response(client, status_code, headers, body)
end

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
    
    return instance
end

function Server:add_route(method, path, handler)
    self.router:add_route(method, path, handler)
end

function Server:add_middleware(middleware)
    self.middleware:use(middleware)
end

function Server:run(host, port)
    -- Override host and port if provided
    if host then self.host = host end
    if port then self.port = port end
    
    print("Starting server on " .. self.host .. ":" .. self.port)
    
    -- Create server socket
    local server = assert(socket.bind(self.host, self.port))
    server:settimeout(0.1)  -- Non-blocking with short timeout
    
    print("Server is now running. Press Ctrl+C to stop.")
    
    -- Set up the server to keep running
    local running = true
    
    -- Handle signals to allow clean shutdown
    local ok, signal = pcall(require, "posix.signal")
    if ok then
        signal.signal(signal.SIGINT, function()
            print("\nReceived interrupt signal. Shutting down...")
            running = false
            server:close()
        end)
        if DEBUG_MODE then
            print("Signal handlers registered for clean shutdown")
        end
    end
    
    -- Main server loop
    while running do
        -- Accept new client
        local client, err = server:accept()
        
        if client then
            client:settimeout(1)  -- Short timeout for receiving data
            
            local ok, err = pcall(function()
                -- Read the request headers
                local request_data = ""
                local line, err
                
                -- Read first line
                line, err = client:receive("*l")
                if not line then
                    if DEBUG_MODE then
                        print("Failed to read request: " .. (err or "unknown error"))
                    end
                    return
                end
                
                request_data = request_data .. line .. "\r\n"
                
                -- Read headers until empty line
                while true do
                    line, err = client:receive("*l")
                    if not line or line == "" then break end
                    request_data = request_data .. line .. "\r\n"
                end
                
                if DEBUG_MODE then
                    print("\n====== START REQUEST DIAGNOSTICS ======")
                    print("Received new connection from client")
                    print("Raw request: " .. request_data)
                end
                
                -- Parse the request
                local headers = parse_headers(request_data)
                
                if not headers.method or not headers.path then
                    if DEBUG_MODE then
                        print("Invalid request: missing method or path")
                    end
                    send_response(client, 400, {}, "Bad Request: Invalid HTTP format")
                    client:close()
                    return
                end
                
                -- Initialize request object
                local request = {
                    method = headers.method,
                    path = headers.path,
                    headers = headers,
                    query_params = {},
                    params = {},
                    _client = client -- Store client for direct access
                }
                
                -- Parse URL to get query parameters
                if request.path and request.path ~= "" then
                    -- Parse the URL to extract components including query params
                    local url_info = URLParser.parse(request.path)
                    if url_info then
                        request.url_info = url_info
                        
                        -- If query parameters exist, add them to the request
                        if url_info.query_params then
                            request.query_params = url_info.query_params
                        end
                        
                        -- Also ensure we have the normalized path
                        if url_info.path then
                            request.path = url_info.path
                        end
                    end
                end
                
                -- Initialize response object
                local response = {
                    statusCode = 200,
                    headers = { ["Content-Type"] = "text/html" },
                    body = ""
                }
                
                -- Add response methods
                response.send = function(self, body)
                    self.body = body
                    return self
                end
                
                response.status = function(self, code)
                    self.statusCode = code
                    return self
                end
                
                response.header = function(self, name, value)
                    self.headers[name] = value
                    return self
                end
                
                -- Add redirect method
                response.redirect = function(self, url, status_code)
                    status_code = status_code or 302
                    
                    if DEBUG_MODE then
                        print("REDIRECT: Redirecting to " .. url .. " with status " .. status_code)
                    end
                    
                    -- Set the response status and headers for redirect
                    self.statusCode = status_code
                    self.headers["Location"] = url
                    
                    -- Create a body with JavaScript redirect
                    self.body = string.format(
                        '<html><body><h1>Redirecting to %s</h1><p><a href="%s">Click here if not redirected automatically</a></p><script>window.location.href="%s";</script></body></html>',
                        url, url, url
                    )
                    
                    return self
                end
                
                -- Special case for redirect test
                if request.path and request.path:match("^/test%-redirect") then
                    local target = request.query_params.to or "/hello"
                    local status = tonumber(request.query_params.status) or 302
                    
                    if DEBUG_MODE then
                        print("REDIRECT TEST: Redirecting to " .. target .. " (status " .. status .. ")")
                    end
                    
                    handle_redirect(client, target, status)
                    client:close()
                    return
                end
                
                -- Execute middleware
                local middleware_ok = true
                pcall(function()
                    middleware_ok = self.middleware:execute_all(request, response)
                end)
                
                if not middleware_ok then
                    if DEBUG_MODE then
                        print("Middleware rejected request")
                    end
                    send_response(client, 403, {}, "Forbidden")
                    client:close()
                    return
                end
                
                -- Resolve route
                if DEBUG_MODE then
                    print("RESOLVING ROUTE: " .. request.method .. " " .. request.path)
                end
                local status, headers, body = self.router:resolve(request.method, request.path, request, response)
                
                -- Set defaults if resolution failed
                status = status or 500
                headers = headers or { ["Content-Type"] = "text/plain" }
                body = body or "Internal Server Error"
                
                -- Handle redirects
                if status >= 300 and status < 400 and headers['Location'] then
                    if DEBUG_MODE then
                        print("ROUTER RESOLVED REDIRECT: " .. headers['Location'] .. " (status " .. status .. ")")
                    end
                    handle_redirect(client, headers['Location'], status)
                else
                    -- Send regular response
                    send_response(client, status, headers, body)
                end
                
                if DEBUG_MODE then
                    print("RESPONSE SENT: Status=" .. tostring(status))
                    print("==== END REQUEST ====")
                end
            end)
            
            if not ok then
                if DEBUG_MODE then
                    print("ERROR in request handler: " .. tostring(err))
                else
                    -- Keep only a minimal error message for production
                    print("Server error: " .. tostring(err))
                end
                -- Send error response
                send_response(client, 500, {}, "Internal Server Error")
            end
            
            -- Close client connection
            client:close()
        elseif err ~= "timeout" then
            -- Keep this error message as it's important for diagnosing server issues
            print("Server accept error: " .. tostring(err))
        end
    end
    
    print("Server has been shut down")
end

-- Simplified version of socket_redirect for direct socket handling
function Server:socket_redirect(client, location, status_code)
    return handle_redirect(client, location, status_code)
end

return Server 