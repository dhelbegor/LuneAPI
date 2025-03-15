local LuneAPI = require('luneapi')

-- Create a new LuneAPI application
local app = LuneAPI.new()

-- Define a simple route
app:get('/', function(req, res)
    res:send('Hello, World!')
end)

-- Define another route
app:get('/about', function(req, res)
    res:send('About LuneAPI')
end)

-- Start the server on port 8080
app:listen(8080, function()
    print('LuneAPI app is running on http://localhost:8080')
end) 