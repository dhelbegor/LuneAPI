-- URL Parser for LuneAPI
-- This module provides URL parsing and manipulation functions
-- Based on neturl: https://github.com/golgote/neturl

local URLParser = {}

-- Parse a URL into its components
-- @param url The URL to parse
-- @return A table with the components {scheme, host, port, path, query, fragment}
function URLParser.parse(url)
    if not url then return nil end
    
    local result = {
        scheme = "",
        host = "",
        port = nil,
        path = "/",
        query = "",
        fragment = "",
        query_params = {}
    }
    
    -- Extract scheme
    local scheme, rest = url:match("^([a-zA-Z][a-zA-Z0-9+.-]*)://(.*)$")
    if scheme then
        result.scheme = scheme:lower()
    else
        rest = url
    end
    
    -- Extract fragment
    local before_fragment, fragment = rest:match("^(.-)#(.*)$")
    if fragment then
        result.fragment = fragment
        rest = before_fragment
    end
    
    -- Extract query
    local before_query, query = rest:match("^(.-)[%?](.*)$")
    if query then
        result.query = query
        result.query_params = URLParser.parse_query(query)
        rest = before_query
    end
    
    -- Extract host, port and path
    local host_port, path = rest:match("^([^/]+)(.*)$")
    if host_port then
        local host, port = host_port:match("^(.+):(%d+)$")
        if host then
            result.host = host
            result.port = tonumber(port)
        else
            result.host = host_port
        end
        
        if path and path ~= "" then
            result.path = path
        end
    else
        -- Only path component
        result.path = rest ~= "" and rest or "/"
    end
    
    -- Ensure path starts with /
    if not result.path:match("^/") then
        result.path = "/" .. result.path
    end
    
    return result
end

-- Parse a query string into a table of key-value pairs
-- @param query The query string to parse (without the ? prefix)
-- @return A table of query parameters
function URLParser.parse_query(query)
    if not query then return {} end
    
    local params = {}
    for pair in query:gmatch("([^&]+)") do
        local key, value = pair:match("^([^=]+)=(.*)$")
        if key then
            -- Decode URL-encoded values
            key = URLParser.decode(key)
            value = URLParser.decode(value or "")
            
            -- Handle array parameters (e.g., key[] or key[index])
            local base_key, index = key:match("^(.+)%[(.*)%]$")
            if base_key then
                if not params[base_key] then
                    params[base_key] = {}
                end
                
                if index and index ~= "" then
                    params[base_key][index] = value
                else
                    table.insert(params[base_key], value)
                end
            else
                params[key] = value
            end
        else
            -- Handle parameter without value
            params[URLParser.decode(pair)] = true
        end
    end
    
    return params
end

-- A more robust implementation of path normalization, adapted from neturl
-- @param path The path to normalize
-- @return The normalized path
function URLParser.normalize_path(path)
    if not path then return "/" end
    
    -- Ensure path starts with /
    if not path:match("^/") then
        path = "/" .. path
    end
    
    -- Replace multiple slashes with a single one
    path = path:gsub("//+", "/")
    
    -- Store if path originally had trailing slash
    local had_trailing_slash = path:sub(-1) == "/"
    
    -- Split path into segments
    local segments = {}
    for segment in path:gmatch("/([^/]*)") do
        if segment == ".." then
            -- Remove the last segment if we can
            if #segments > 0 then
                table.remove(segments)
            end
        elseif segment ~= "." and segment ~= "" then
            -- Skip "." and empty segments, add others
            table.insert(segments, segment)
        end
    end
    
    -- Reconstruct the path
    local result = "/" .. table.concat(segments, "/")
    
    -- Restore trailing slash if it was present and the path isn't just "/"
    if had_trailing_slash and result ~= "/" then
        result = result .. "/"
    end
    
    return result
end

-- removeDotSegments implementation from neturl
-- @param path The path to process
-- @return The processed path
function URLParser.removeDotSegments(path)
    local fields = {}
    if string.len(path) == 0 then
        return ""
    end
    
    local startslash = false
    local endslash = false
    
    if string.sub(path, 1, 1) == "/" then
        startslash = true
    end
    
    if (string.len(path) > 1 or startslash == false) and string.sub(path, -1) == "/" then
        endslash = true
    end
    
    path:gsub('[^/]+', function(c) table.insert(fields, c) end)
    
    local new = {}
    local j = 0
    
    for i,c in ipairs(fields) do
        if c == '..' then
            if j > 0 then
                j = j - 1
            end
        elseif c ~= "." then
            j = j + 1
            new[j] = c
        end
    end
    
    local ret = ""
    if #new > 0 and j > 0 then
        ret = table.concat(new, '/', 1, j)
    else
        ret = ""
    end
    
    if startslash then
        ret = '/'..ret
    end
    
    if endslash then
        ret = ret..'/'
    end
    
    return ret
end

-- Remove trailing slash from path (except for root path /)
-- @param path The path to process
-- @return The path without trailing slash
function URLParser.remove_trailing_slash(path)
    if not path or path == "/" then return "/" end
    
    if path:sub(-1) == "/" then
        return path:sub(1, -2)
    end
    
    return path
end

-- URL-encode a string
-- @param str The string to encode
-- @return The URL-encoded string
function URLParser.encode(str)
    if not str then return "" end
    
    -- Replace special characters with percent-encoded values
    str = str:gsub("([^A-Za-z0-9_%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    
    return str
end

-- URL-decode a string
-- @param str The string to decode
-- @return The URL-decoded string
function URLParser.decode(str)
    if not str then return "" end
    
    -- Replace percent-encoded values with the actual characters
    str = str:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    
    -- Also replace plus signs with spaces (common in query strings)
    str = str:gsub("+", " ")
    
    return str
end

-- Build a query string from parameters
-- @param params Table of query parameters
-- @return Query string (without the ? prefix)
function URLParser.build_query(params)
    if not params or type(params) ~= "table" then
        return ""
    end
    
    local parts = {}
    for key, value in pairs(params) do
        if type(value) == "table" then
            for i, v in ipairs(value) do
                table.insert(parts, URLParser.encode(key .. "[]") .. "=" .. URLParser.encode(v))
            end
        elseif value == true then
            -- For boolean true, just include the key
            table.insert(parts, URLParser.encode(key))
        elseif value ~= nil then
            -- For all other values, include key=value
            table.insert(parts, URLParser.encode(key) .. "=" .. URLParser.encode(tostring(value)))
        end
    end
    
    return table.concat(parts, "&")
end

-- Normalize a url path following common normalization rules
-- @param url The URL or path to normalize
-- @return The normalized URL or path
function URLParser.normalize(url)
    if type(url) == 'string' then
        url = URLParser.parse(url)
    end
    
    if url and url.path then
        -- Use removeDotSegments for more robust normalization
        url.path = URLParser.removeDotSegments(url.path)
        
        -- Normalize multiple slashes
        url.path = url.path:gsub("//+", "/")
    end
    
    return url
end

-- Resolve a relative URL against a base URL
-- @param base_url The base URL
-- @param relative_url The relative URL
-- @return The resolved URL
function URLParser.resolve(base_url, relative_url)
    if type(base_url) == 'string' then
        base_url = URLParser.parse(base_url)
    end
    
    if type(relative_url) == 'string' then
        relative_url = URLParser.parse(relative_url)
    end
    
    if not base_url or not relative_url then
        return nil
    end
    
    if relative_url.scheme then
        -- Absolute URL
        return relative_url
    else
        -- Relative URL, inherit scheme and authority from base
        relative_url.scheme = base_url.scheme
        
        if not relative_url.host or relative_url.host == "" then
            relative_url.host = base_url.host
            relative_url.port = base_url.port
            
            if not relative_url.path or relative_url.path == "" then
                relative_url.path = base_url.path
                
                if not relative_url.query or relative_url.query == "" then
                    relative_url.query = base_url.query
                    relative_url.query_params = base_url.query_params
                end
            else
                if relative_url.path:sub(1, 1) ~= "/" then
                    -- Relative path, resolve against base path
                    local base_dir = base_url.path:match("(.*/)")
                    if not base_dir then base_dir = "/" end
                    relative_url.path = URLParser.removeDotSegments(base_dir .. relative_url.path)
                else
                    -- Absolute path, just normalize it
                    relative_url.path = URLParser.removeDotSegments(relative_url.path)
                end
            end
        end
    end
    
    return relative_url
end

-- Check if a path matches a route pattern
-- @param path The actual path to test
-- @param pattern The route pattern to match against
-- @return Boolean indicating if the path matches the pattern
function URLParser.path_matches(path, pattern)
    -- Simple case: exact match
    if path == pattern then
        return true
    end
    
    -- Normalize both paths first
    local norm_path = URLParser.normalize_path(path)
    local norm_pattern = URLParser.normalize_path(pattern)
    
    -- Simple case after normalization: exact match
    if norm_path == norm_pattern then
        return true
    end
    
    -- Handle trailing slash equivalence for paths (except root)
    -- /users and /users/ should match
    if norm_path ~= "/" and norm_pattern ~= "/" then
        if URLParser.remove_trailing_slash(norm_path) == URLParser.remove_trailing_slash(norm_pattern) then
            return true
        end
    end
    
    -- Check for pattern with parameters
    -- If the pattern doesn't have : or *, it's not a pattern
    if not pattern:find("[:*]") then
        return false
    end
    
    -- Split the path and pattern into segments
    local path_segments = {}
    for segment in norm_path:gmatch("([^/]+)") do
        table.insert(path_segments, segment)
    end
    
    local pattern_segments = {}
    for segment in norm_pattern:gmatch("([^/]+)") do
        table.insert(pattern_segments, segment)
    end
    
    -- Wildcard case - pattern ends with /* and has matching prefix
    if pattern_segments[#pattern_segments] == "*" then
        -- Check if all segments before the * match
        local prefix_match = true
        for i = 1, #pattern_segments - 1 do
            if i > #path_segments or 
               (pattern_segments[i]:sub(1,1) ~= ":" and 
                pattern_segments[i] ~= path_segments[i]) then
                prefix_match = false
                break
            end
        end
        
        -- If the prefix matches and the path is at least as long as the prefix, it's a match
        if prefix_match and #path_segments >= #pattern_segments - 1 then
            return true
        end
    end
    
    -- Dynamic segments - specific named parameters like :id
    if #path_segments == #pattern_segments then
        local params_match = true
        for i = 1, #pattern_segments do
            local p_segment = pattern_segments[i]
            local is_param = p_segment:sub(1,1) == ":"
            
            if not is_param and p_segment ~= path_segments[i] then
                params_match = false
                break
            end
        end
        return params_match
    end
    
    return false
end

-- Build a clean path for browser navigation
-- @param segments Table of path segments
-- @return A properly formatted path
function URLParser.build_path(...)
    local segments = {...}
    local parts = {}
    
    for _, segment in ipairs(segments) do
        if segment then
            -- Remove leading and trailing slashes from segments
            local clean = segment:gsub("^/+", ""):gsub("/+$", "")
            if clean ~= "" then
                table.insert(parts, clean)
            end
        end
    end
    
    return "/" .. table.concat(parts, "/")
end

-- Build a complete URL from its components
-- @param parts A table with the URL components
-- @return The complete URL string
function URLParser.build(parts)
    local url = ""
    
    -- Add scheme
    if parts.scheme and parts.scheme ~= "" then
        url = parts.scheme .. "://"
    end
    
    -- Add authority (host and port)
    if parts.host and parts.host ~= "" then
        url = url .. parts.host
        if parts.port then
            url = url .. ":" .. parts.port
        end
    end
    
    -- Add path
    if parts.path and parts.path ~= "" then
        -- Ensure path starts with /
        if parts.path:sub(1, 1) ~= "/" and (parts.host and parts.host ~= "") then
            url = url .. "/"
        end
        url = url .. parts.path
    end
    
    -- Add query
    if parts.query and parts.query ~= "" then
        url = url .. "?" .. parts.query
    elseif parts.query_params and next(parts.query_params) then
        url = url .. "?" .. URLParser.build_query(parts.query_params)
    end
    
    -- Add fragment
    if parts.fragment and parts.fragment ~= "" then
        url = url .. "#" .. parts.fragment
    end
    
    return url
end

-- Build a full URL from components
-- @param components Table with URL components
-- @return Full URL string
function URLParser.build_url(components)
    if not components then return nil end
    
    local url = ""
    
    -- Add scheme
    if components.scheme and components.scheme ~= "" then
        url = components.scheme .. "://"
    end
    
    -- Add host
    if components.host and components.host ~= "" then
        url = url .. components.host
        
        -- Add port if specified and not the default for the scheme
        if components.port then
            local default_port = (components.scheme == "http" and 80) or
                                (components.scheme == "https" and 443)
            if components.port ~= default_port then
                url = url .. ":" .. components.port
            end
        end
    end
    
    -- Add path
    url = url .. (components.path or "/")
    
    -- Add query
    if components.query and components.query ~= "" then
        url = url .. "?" .. components.query
    elseif components.query_params and next(components.query_params) ~= nil then
        url = url .. "?" .. URLParser.build_query(components.query_params)
    end
    
    -- Add fragment
    if components.fragment and components.fragment ~= "" then
        url = url .. "#" .. components.fragment
    end
    
    return url
end

return URLParser 