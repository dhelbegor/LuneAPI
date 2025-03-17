-- Example RESTful API using LuneAPI and jsonify
local LuneAPI = require('luneapi.core')
local jsonify = require('luneapi.jsonify')

-- Create a new app instance
local app = LuneAPI.new()

-- In-memory database for users
local users = {
    {
        id = 1,
        name = "John Doe",
        email = "john@example.com",
        age = 32,
        roles = {"admin", "user"},
        active = true,
        created_at = os.time()
    },
    {
        id = 2,
        name = "Jane Smith",
        email = "jane@example.com",
        age = 28,
        roles = {"user"},
        active = true,
        created_at = os.time()
    },
    {
        id = 3,
        name = "Bob Johnson",
        email = "bob@example.com",
        age = 45,
        roles = {"manager", "user"},
        active = false,
        created_at = os.time()
    }
}

-- Get next available ID
local function get_next_id()
    local max_id = 0
    for _, user in ipairs(users) do
        if user.id > max_id then
            max_id = user.id
        end
    end
    return max_id + 1
end

-- Find user by ID
local function find_user_by_id(id)
    for index, user in ipairs(users) do
        if user.id == id then
            return user, index
        end
    end
    return nil
end

-- User schema for validation
local user_schema = {
    type = "table",
    properties = {
        name = { type = "string", required = true, min_length = 3 },
        email = { type = "string", required = true, pattern = "^[%w.]+@[%w.]+%.[%a]+$" },
        age = { type = "number", min = 18, max = 120 },
        roles = { type = "array", items = { type = "string" } },
        active = { type = "boolean" }
    },
    required_fields = {"name", "email"}
}

-- JSON Response Helper
local function json_response(res, data, status)
    status = status or 200
    return res:status(status)
        :header('Content-Type', 'application/json')
        :send(jsonify.stringify(data))
end

-- Error Response Helper
local function error_response(res, message, status)
    status = status or 400
    return json_response(res, { error = message }, status)
end

-- JSON parsing middleware
local json_middleware = function(req, res, next)
    if req.method == "POST" or req.method == "PUT" then
        if req.headers["content-type"] and req.headers["content-type"]:match("application/json") then
            local body = req.body
            
            -- Skip if empty body
            if not body or body == "" then
                req.json = {}
                return next()
            end
            
            -- Try to parse JSON
            local success, result = pcall(function()
                return jsonify.parse(body)
            end)
            
            if success and type(result) == "table" then
                req.json = result
                next()
            else
                return error_response(res, "Invalid JSON in request body", 400)
            end
        else
            req.json = {}
            next()
        end
    else
        next()
    end
end

-- Add JSON parsing middleware
app.middleware:use(json_middleware)

-- GET /api/users - List all users
app:get('/api/users', function(req, res)
    return json_response(res, users)
end)

-- GET /api/users/:id - Get specific user
app:get('/api/users/:id', function(req, res)
    local id = tonumber(req.params.id)
    if not id then
        return error_response(res, "Invalid user ID", 400)
    end
    
    local user = find_user_by_id(id)
    if not user then
        return error_response(res, "User not found", 404)
    end
    
    return json_response(res, user)
end)

-- POST /api/users - Create new user
app:post('/api/users', function(req, res)
    local new_user = req.json
    
    -- Validate user data
    local success, error_msg = pcall(function()
        jsonify.validate(new_user, user_schema)
    end)
    
    if not success then
        return error_response(res, "Validation error: " .. error_msg, 400)
    end
    
    -- Check for duplicate email
    for _, user in ipairs(users) do
        if user.email == new_user.email then
            return error_response(res, "Email already in use", 409)
        end
    end
    
    -- Add metadata and insert
    new_user.id = get_next_id()
    new_user.created_at = os.time()
    table.insert(users, new_user)
    
    return json_response(res, new_user, 201)
end)

-- PUT /api/users/:id - Update user
app:put('/api/users/:id', function(req, res)
    local id = tonumber(req.params.id)
    if not id then
        return error_response(res, "Invalid user ID", 400)
    end
    
    local update_data = req.json
    
    -- Find user
    local user, index = find_user_by_id(id)
    if not user then
        return error_response(res, "User not found", 404)
    end
    
    -- Validate update data
    local success, error_msg = pcall(function()
        jsonify.validate(update_data, user_schema)
    end)
    
    if not success then
        return error_response(res, "Validation error: " .. error_msg, 400)
    end
    
    -- Check email uniqueness if changing
    if update_data.email and update_data.email ~= user.email then
        for _, other_user in ipairs(users) do
            if other_user.id ~= id and other_user.email == update_data.email then
                return error_response(res, "Email already in use", 409)
            end
        end
    end
    
    -- Update user data
    for key, value in pairs(update_data) do
        user[key] = value
    end
    
    -- Add updated_at timestamp
    user.updated_at = os.time()
    
    -- Update in "database"
    users[index] = user
    
    return json_response(res, user)
end)

-- DELETE /api/users/:id - Delete user
app:delete('/api/users/:id', function(req, res)
    local id = tonumber(req.params.id)
    if not id then
        return error_response(res, "Invalid user ID", 400)
    end
    
    -- Find user
    local user, index = find_user_by_id(id)
    if not user then
        return error_response(res, "User not found", 404)
    end
    
    -- Remove from "database"
    table.remove(users, index)
    
    return json_response(res, { success = true, message = "User deleted" })
end)

-- GET /api/stats - Get API statistics
app:get('/api/stats', function(req, res)
    local stats = {
        user_count = #users,
        active_users = 0,
        inactive_users = 0,
        roles = {},
        youngest_user = { age = math.huge },
        oldest_user = { age = 0 },
        averages = {
            age = 0
        }
    }
    
    -- Calculate statistics
    local total_age = 0
    
    for _, user in ipairs(users) do
        -- Count active/inactive
        if user.active then
            stats.active_users = stats.active_users + 1
        else
            stats.inactive_users = stats.inactive_users + 1
        end
        
        -- Count roles
        if user.roles then
            for _, role in ipairs(user.roles) do
                stats.roles[role] = (stats.roles[role] or 0) + 1
            end
        end
        
        -- Track age stats
        if user.age then
            total_age = total_age + user.age
            
            if user.age < stats.youngest_user.age then
                stats.youngest_user = {
                    id = user.id,
                    name = user.name,
                    age = user.age
                }
            end
            
            if user.age > stats.oldest_user.age then
                stats.oldest_user = {
                    id = user.id,
                    name = user.name,
                    age = user.age
                }
            end
        end
    end
    
    -- Calculate averages
    if #users > 0 then
        stats.averages.age = total_age / #users
    end
    
    return json_response(res, stats)
end)

-- Simple HTML page to display the API info with links to test it
app:get('/', function(req, res)
    local html = [[
<!DOCTYPE html>
<html>
<head>
    <title>LuneAPI REST Example</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        h1, h2 {
            color: #2c3e50;
        }
        .endpoint {
            background-color: #f8f9fa;
            border-left: 4px solid #2c3e50;
            margin-bottom: 20px;
            padding: 15px;
        }
        .method {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 4px;
            color: white;
            font-weight: bold;
            margin-right: 10px;
        }
        .get { background-color: #61affe; }
        .post { background-color: #49cc90; }
        .put { background-color: #fca130; }
        .delete { background-color: #f93e3e; }
        pre {
            background-color: #272822;
            color: #f8f8f2;
            padding: 10px;
            border-radius: 4px;
            overflow-x: auto;
        }
        .description {
            margin-top: 10px;
        }
        .footer {
            margin-top: 40px;
            color: #7f8c8d;
            font-size: 0.9em;
            text-align: center;
        }
    </style>
</head>
<body>
    <h1>LuneAPI REST API Example with jsonify</h1>
    <p>This page demonstrates a RESTful API built with LuneAPI and the jsonify serialization module.</p>
    
    <h2>API Endpoints</h2>
    
    <div class="endpoint">
        <span class="method get">GET</span> <strong>/api/users</strong>
        <div class="description">
            Returns a list of all users.
            <div><a href="/api/users" target="_blank">Test this endpoint</a></div>
        </div>
    </div>
    
    <div class="endpoint">
        <span class="method get">GET</span> <strong>/api/users/:id</strong>
        <div class="description">
            Returns a single user by ID.
            <div><a href="/api/users/1" target="_blank">Test with user ID 1</a></div>
        </div>
    </div>
    
    <div class="endpoint">
        <span class="method post">POST</span> <strong>/api/users</strong>
        <div class="description">
            Creates a new user.
            <pre>
{
  "name": "New User",
  "email": "new@example.com",
  "age": 30,
  "roles": ["user"],
  "active": true
}
            </pre>
        </div>
    </div>
    
    <div class="endpoint">
        <span class="method put">PUT</span> <strong>/api/users/:id</strong>
        <div class="description">
            Updates an existing user.
            <pre>
{
  "name": "Updated Name",
  "email": "updated@example.com",
  "age": 35
}
            </pre>
        </div>
    </div>
    
    <div class="endpoint">
        <span class="method delete">DELETE</span> <strong>/api/users/:id</strong>
        <div class="description">
            Deletes a user by ID.
        </div>
    </div>
    
    <div class="endpoint">
        <span class="method get">GET</span> <strong>/api/stats</strong>
        <div class="description">
            Returns statistics about the users.
            <div><a href="/api/stats" target="_blank">Test this endpoint</a></div>
        </div>
    </div>
    
    <h2>Testing with curl</h2>
    
    <pre>
# Get all users
curl http://localhost:8080/api/users

# Get specific user
curl http://localhost:8080/api/users/1

# Create new user
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","age":33,"roles":["user"],"active":true}'

# Update user
curl -X PUT http://localhost:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Name","email":"john@example.com"}'

# Delete user
curl -X DELETE http://localhost:8080/api/users/3
    </pre>
    
    <div class="footer">
        Powered by LuneAPI and jsonify serialization module
    </div>
</body>
</html>
    ]]
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- Start the server
app:listen(8080, function()
    print("API Example is running at http://localhost:8080")
    print("Available endpoints:")
    print("  GET    /api/users")
    print("  GET    /api/users/:id")
    print("  POST   /api/users")
    print("  PUT    /api/users/:id")
    print("  DELETE /api/users/:id")
    print("  GET    /api/stats")
end) 