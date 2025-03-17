-- Example usage of the simplified jsonify module

-- Import the simplified jsonify module
local jsonify = require('luneapi.jsonify')

print("Simplified LuneAPI JSON Serializer Example")
print("=======================================\n")

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
    }
}

-- Stringify (serialize to JSON)
print("Stringify a Lua table:")
local json_str = jsonify.stringify(user)
print(json_str)
print()

-- Pretty print
print("Pretty print a JSON string:")
local pretty_json = jsonify.pretty(user)
print(pretty_json)
print()

-- Parse (deserialize from JSON)
print("Parse a JSON string:")
local json_input = [[
{
  "name": "Bob Johnson",
  "age": 32,
  "email": "bob@example.com",
  "roles": ["user"]
}
]]
print("Input JSON:")
print(json_input)
print("\nParsed Lua table:")
local lua_table = jsonify.parse(json_input)
print("Name: " .. lua_table.name)
print("Age: " .. lua_table.age)
print("Email: " .. lua_table.email)
print("Role: " .. lua_table.roles[1])
print()

-- Schema validation
print("Schema validation:")
local schema = {
    type = "table",
    properties = {
        name = { type = "string", required = true },
        age = { type = "number" },
        email = { type = "string" }
    },
    required_fields = {"name", "email"}
}

local valid_data = {
    name = "John Doe",
    email = "john@example.com"
}

local invalid_data = {
    name = "Jane Doe"
    -- missing email
}

print("Validating valid data:")
local success, error_msg = pcall(function()
    jsonify.validate(valid_data, schema)
end)

if success then
    print("✓ Validation passed")
else
    print("✗ Validation failed: " .. error_msg)
end

print("\nValidating invalid data:")
success, error_msg = pcall(function()
    jsonify.validate(invalid_data, schema)
end)

if success then
    print("✓ Validation passed")
else
    print("✗ Validation failed: " .. error_msg)
end 