package = "luneapi"
version = "scm-1"
source = {
    url = "git@github.com:dhelbegor/LuneAPI.git"
description = {
    summary = "A micro-framework for Lua, similar to Flask.",
    detailed = [[
        LuneAPI is a simple and modular micro-framework for Lua, designed to handle HTTP requests, define routes, and deploy as a Lua package.
    ]],
    homepage = "https://github.com/dhelbegor/LuneAPI",
    license = "MIT"
}
dependencies = {
    "lua >= 5.1",
    "lua-cjson"
}
build = {
    type = "builtin",
    modules = {
        ["luneapi"] = "LuneAPI/src/init.lua",
        ["luneapi.core"] = "LuneAPI/src/core.lua",
        ["luneapi.server"] = "LuneAPI/src/server.lua",
        ["luneapi.router"] = "LuneAPI/src/router.lua",
        ["luneapi.middleware"] = "LuneAPI/src/middleware.lua",
        ["luneapi.utils"] = "LuneAPI/src/utils.lua",
        ["luneapi.config"] = "LuneAPI/src/config.lua",
        ["luneapi.url_parser"] = "LuneAPI/src/url_parser.lua",
        ["luneapi.logger"] = "LuneAPI/src/logger.lua",
        ["luneapi.template.init"] = "LuneAPI/src/template/init.lua",
        ["luneapi.template.parser"] = "LuneAPI/src/template/parser.lua",
        ["luneapi.template.renderer"] = "LuneAPI/src/template/renderer.lua",
        ["luneapi.jsonify"] = "LuneAPI/src/jsonify/init.lua",
         ["luneapi.jsonify.serializer"] = "LuneAPI/src/jsonify/Serializer.lua"
    }
}