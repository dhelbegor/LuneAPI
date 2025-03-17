--[[
    jsonify module
    A simplified interface to the JSON serializer
]]

local Serializer = require('luneapi.jsonify.serializer')

local jsonify = {}

-- Create a single serializer instance
local serializer = Serializer.new()

-- Simplified interface functions

-- Convert a Lua table to a JSON string
function jsonify.stringify(value)
    return serializer:serialize(value)
end

-- Convert a Lua table to a pretty-printed JSON string
function jsonify.pretty(value)
    return serializer:pretty_print(value)
end

-- Convert a JSON string to a Lua table
function jsonify.parse(json_str)
    return serializer:deserialize(json_str)
end

-- Validate a Lua table against a schema
function jsonify.validate(data, schema)
    return serializer:validate(data, schema)
end

-- Create a new serializer instance if needed
function jsonify.new()
    return Serializer.new()
end

return jsonify 