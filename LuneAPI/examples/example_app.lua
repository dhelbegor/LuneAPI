local LuneAPI = require('luneapi.core')

-- Create a new server instance using the core module's new function
local app = LuneAPI.new()

-- Add a simple middleware to log incoming requests
local function logger_middleware(req, res)
    -- Only log the method and path - keep this minimal
    print(string.format("[%s] %s %s", os.date("%H:%M:%S"), req.method, req.path))
    return true  -- continue to next middleware/route handler
end

-- Add middleware to app
app.middleware:use(logger_middleware)

-- Define the home route
app:add_route('GET', '/', function(req, res)
    res:header('Content-Type', 'text/html')
    
    local html = [[
    <!DOCTYPE html>
    <html>
    <head>
        <title>LuneAPI Example</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; padding: 20px; max-width: 800px; margin: 0 auto; }
            h1 { color: #333; }
            a { color: #0066cc; text-decoration: none; }
            a:hover { text-decoration: underline; }
            .route { background: #f5f5f5; padding: 10px; margin-bottom: 10px; border-radius: 4px; }
            code { background: #eee; padding: 2px 4px; border-radius: 3px; }
        </style>
    </head>
    <body>
        <h1>Welcome to LuneAPI!</h1>
        <p>Your server is running successfully. Try these routes:</p>
        
        <div class="route">
            <h3><a href="/hello">/hello</a></h3>
            <p>A simple hello message</p>
        </div>
        
        <div class="route">
            <h3><a href="/user/123">/user/:id</a></h3>
            <p>Shows user information with the ID parameter</p>
        </div>
        
        <div class="route">
            <h3><a href="/products/electronics/phones">/products/:category/:subcategory</a></h3>
            <p>Shows products with category and subcategory parameters</p>
        </div>
        
        <div class="route">
            <h3><a href="/files/documents/reports/annual/2023.pdf">/files/*</a></h3>
            <p>Wildcard route that matches any path under /files/</p>
        </div>
        
        <div class="route">
            <h3><a href="/api/status">/api/status</a></h3>
            <p>API status endpoint (returns JSON)</p>
        </div>
        
        <div class="route">
            <h3><a href="/redirect-demo">/redirect-demo</a></h3>
            <p>Demonstrates how redirection works</p>
        </div>
    </body>
    </html>
    ]]
    
    return res:send(html)
end)

-- A simple hello world route
app:add_route('GET', '/hello', function(req, res)
    return res:header('Content-Type', 'text/plain'):send('Hello, World!')
end)

-- Route with a parameter
app:add_route('GET', '/user/:id', function(req, res)
    local id = req.params and req.params.id or "unknown"
    
    local html = [[
    <!DOCTYPE html>
    <html>
    <head>
        <title>User Profile</title>
        <style>
            body { font-family: Arial, sans-serif; padding: 20px; }
            .user-card { background: #f5f5f5; padding: 20px; border-radius: 5px; max-width: 500px; }
            h1 { color: #333; }
        </style>
    </head>
    <body>
        <div class="user-card">
            <h1>User Profile</h1>
            <p><strong>User ID:</strong> ]] .. id .. [[</p>
            <p><strong>Route:</strong> /user/:id</p>
            <p><em>This is a sample user profile page using route parameters.</em></p>
            <p><a href="/">Back to Home</a></p>
        </div>
    </body>
    </html>
    ]]
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- Route with multiple parameters
app:add_route('GET', '/products/:category/:subcategory', function(req, res)
    local category = req.params and req.params.category or "unknown"
    local subcategory = req.params and req.params.subcategory or "unknown"
    
    local html = [[
    <!DOCTYPE html>
    <html>
    <head>
        <title>Products</title>
        <style>
            body { font-family: Arial, sans-serif; padding: 20px; }
            .product-list { background: #f5f5f5; padding: 20px; border-radius: 5px; max-width: 600px; }
            h1 { color: #333; }
        </style>
    </head>
    <body>
        <div class="product-list">
            <h1>Products: ]] .. category .. [[ / ]] .. subcategory .. [[</h1>
            <p><strong>Category:</strong> ]] .. category .. [[</p>
            <p><strong>Subcategory:</strong> ]] .. subcategory .. [[</p>
            <p><strong>Route:</strong> /products/:category/:subcategory</p>
            <p><em>This is a sample product listing page using multiple route parameters.</em></p>
            <p><a href="/">Back to Home</a></p>
        </div>
    </body>
    </html>
    ]]
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- Wildcard route
app:add_route('GET', '/files/*', function(req, res)
    local path = req.path or "/files/unknown"
    
    local html = [[
    <!DOCTYPE html>
    <html>
    <head>
        <title>File System</title>
        <style>
            body { font-family: Arial, sans-serif; padding: 20px; }
            .file-info { background: #f5f5f5; padding: 20px; border-radius: 5px; max-width: 600px; }
            h1 { color: #333; }
        </style>
    </head>
    <body>
        <div class="file-info">
            <h1>File System</h1>
            <p><strong>Requested Path:</strong> ]] .. path .. [[</p>
            <p><strong>Route:</strong> /files/*</p>
            <p><em>This is a sample file system page using wildcard routing.</em></p>
            <p><a href="/">Back to Home</a></p>
        </div>
    </body>
    </html>
    ]]
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- JSON API endpoint
app:add_route('GET', '/api/status', function(req, res)
    local status = {
        status = "operational",
        version = "1.0.0",
        timestamp = os.time()
    }
    
    local json = require('cjson').encode(status)
    return res:header('Content-Type', 'application/json'):send(json)
end)

-- Redirect demonstration
app:add_route('GET', '/redirect-demo', function(req, res)
    return res:redirect('/hello')
end)

-- Start the server on port 8080
app:listen(8080, function()
    print('LuneAPI server started successfully')
    print('Server is running at http://localhost:8080')
end)