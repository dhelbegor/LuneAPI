local config = require('luneapi.config')

local Logger = {}
Logger.__index = Logger

local log_levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

function Logger:new()
    local instance = setmetatable({}, self)
    instance.level = log_levels[config.logging.level] or log_levels.INFO
    instance.file = config.logging.file
    return instance
end

function Logger:log(level, message)
    if log_levels[level] >= self.level then
        local log_message = string.format("[%s] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, message)
        if self.file then
            local file = io.open(self.file, "a")
            if file then
                file:write(log_message .. "\n")
                file:close()
            end
        else
            print(log_message)
        end
    end
end

function Logger:debug(message)
    self:log("DEBUG", message)
end

function Logger:info(message)
    self:log("INFO", message)
end

function Logger:warn(message)
    self:log("WARN", message)
end

function Logger:error(message)
    self:log("ERROR", message)
end

return Logger 