-- LuneAPI Framework main entry point

local Core = require('luneapi.core')

-- Export the template engine separately for direct use
Core.Template = require('luneapi.template')

return Core 