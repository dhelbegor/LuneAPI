-- Example usage of the Serializer module

-- Import the Serializer class
local SerializerClass = require('luneapi.jsonify.serializer')

-- Create a new Serializer instance
local serializer = SerializerClass.new()

print("LuneAPI JSON Serializer Example")
print("==============================\n")

-- Example Lua table
local user = {
    name = "Alice Smith",
    age = 28,
    email = "alice@example.com",
    active = true,
    roles = {"admin", "editor", "user"},
    settings = {
        notifications = true,
        theme = "dark",
        font_size = 14
    },
    last_login = os.time()
}

print("1. Serializing a Lua table to JSON")
print("--------------------------------")
local json_str = serializer:serialize(user)
print(json_str)
print()

print("2. Pretty printing JSON")
print("---------------------")
local pretty_json = serializer:pretty_print(user)
print(pretty_json)
print()

print("3. Deserializing JSON to a Lua table")
print("----------------------------------")
local json_input = [[
{
  "name": "Bob Johnson",
  "age": 32,
  "email": "bob@example.com",
  "active": false,
  "roles": ["user", "subscriber"],
  "settings": {
    "notifications": false,
    "theme": "light",
    "font_size": 12
  }
}
]]
print("Input JSON:")
print(json_input)
print("\nDeserialized Lua table:")
local lua_table = serializer:deserialize(json_input)
print("Name: " .. lua_table.name)
print("Age: " .. lua_table.age)
print("Email: " .. lua_table.email)
print("Active: " .. tostring(lua_table.active))
print("Roles: " .. table.concat(lua_table.roles, ", "))
print("Theme: " .. lua_table.settings.theme)
print()

print("4. Schema Validation")
print("------------------")

-- Define a schema for user objects
local user_schema = {
    type = "table",
    properties = {
        name = { type = "string", required = true },
        age = { type = "number", min = 0, max = 120 },
        email = { type = "string", pattern = "^[%w.]+@[%w.]+%.[%a]+$" },
        active = { type = "boolean" },
        roles = { 
            type = "array", 
            items = { type = "string" }
        },
        settings = {
            type = "table",
            properties = {
                notifications = { type = "boolean" },
                theme = { type = "string" },
                font_size = { type = "number" }
            }
        }
    },
    required_fields = {"name", "email"}
}

-- Valid data
print("Validating valid data:")
local valid_user = {
    name = "Charlie Brown",
    age = 25,
    email = "charlie@example.com",
    roles = {"user"},
    settings = {
        theme = "system",
        font_size = 16
    }
}

local success, error_msg = pcall(function()
    serializer:validate(valid_user, user_schema)
end)

if success then
    print("✓ Validation passed")
else
    print("✗ Validation failed: " .. error_msg)
end
print()

-- Invalid data (missing required field)
print("Validating invalid data (missing email):")
local invalid_user1 = {
    name = "David Miller",
    age = 40
}

success, error_msg = pcall(function()
    serializer:validate(invalid_user1, user_schema)
end)

if success then
    print("✓ Validation passed")
else
    print("✗ Validation failed: " .. error_msg)
end
print()

-- Invalid data (wrong type)
print("Validating invalid data (age is not a number):")
local invalid_user2 = {
    name = "Eve Wilson",
    age = "thirty",
    email = "eve@example.com"
}

success, error_msg = pcall(function()
    serializer:validate(invalid_user2, user_schema)
end)

if success then
    print("✓ Validation passed")
else
    print("✗ Validation failed: " .. error_msg)
end
print()

-- Invalid data (pattern mismatch)
print("Validating invalid data (email pattern mismatch):")
local invalid_user3 = {
    name = "Frank Thomas",
    age = 50,
    email = "invalid-email"
}

success, error_msg = pcall(function()
    serializer:validate(invalid_user3, user_schema)
end)

if success then
    print("✓ Validation passed")
else
    print("✗ Validation failed: " .. error_msg)
end
print()

print("5. Error Handling")
print("---------------")

-- Malformed JSON
print("Handling malformed JSON:")
local malformed_json = [[
{
  "name": "Invalid JSON,
  "age": 45
}
]]

success, error_msg = pcall(function()
    serializer:deserialize(malformed_json)
end)

if success then
    print("✓ Deserialization successful (unexpected)")
else
    print("✗ Deserialization failed (expected): " .. error_msg)
end
print()

-- Unsupported data type
print("Handling unsupported data types:")
local function test_function() end

success, error_msg = pcall(function()
    serializer:serialize({func = test_function})
end)

if success then
    print("✓ Serialization successful (unexpected)")
else
    print("✗ Serialization failed (expected): " .. error_msg)
end
print()

print("6. Performance Test")
print("-----------------")
local large_table = {}
for i = 1, 1000 do
    large_table[i] = {
        id = i,
        value = "Item " .. i,
        timestamp = os.time()
    }
end

print("Serializing 1000 items...")
local start_time = os.clock()
local large_json = serializer:serialize(large_table)
local end_time = os.clock()
print(string.format("Serialization completed in %.4f seconds", end_time - start_time))
print(string.format("JSON size: %d bytes", #large_json))
print()

print("All examples completed successfully!") 