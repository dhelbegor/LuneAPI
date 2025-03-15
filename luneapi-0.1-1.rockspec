package = "LuneAPI"
version = "0.1-1"
source = {
    url = "https://example.com/LuneAPI-0.1.tar.gz"  -- Replace with actual source URL
}
description = {
    summary = "A micro-framework for Lua, similar to Flask.",
    detailed = [[
        LuneAPI is a simple and modular micro-framework for Lua, designed to handle HTTP requests, define routes, and deploy as a Lua package.
    ]],
    homepage = "https://example.com/LuneAPI",  -- Replace with actual homepage URL
    license = "MIT"
}
dependencies = {
    "lua >= 5.1",
    "http",
    "lua-cjson"
}
build = {
    type = "builtin",
    modules = {
        ["LuneAPI.src.core"] = "LuneAPI/src/core.lua",
        ["LuneAPI.src.server"] = "LuneAPI/src/server.lua",
        ["LuneAPI.src.router"] = "LuneAPI/src/router.lua",
        ["LuneAPI.src.middleware"] = "LuneAPI/src/middleware.lua",
        ["LuneAPI.src.utils"] = "LuneAPI/src/utils.lua",
        ["LuneAPI.src.config"] = "LuneAPI/src/config.lua",
        ["LuneAPI.src.logger"] = "LuneAPI/src/logger.lua"
    }
} 