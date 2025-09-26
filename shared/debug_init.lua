-- DO NOT MAKE CHANGES TO THIS FILE
if not BCCStashesDebug then
    ---@class BCCStashesDebugLib
    ---@field Info fun(message: string)
    ---@field Error fun(message: string)
    ---@field Warning fun(message: string)
    ---@field Success fun(message: string)
    ---@field DevModeActive boolean
    BCCStashesDebug = {}

    BCCStashesDebug.DevModeActive = Config and Config.devMode and Config.devMode.active or false

    -- No-op function
    local function noop() end

    -- Function to create loggers
    local function createLogger(prefix, color)
        if BCCStashesDebug.DevModeActive then
            return function(message)
                print(('^%d[%s] ^3%s^0'):format(color, prefix, message))
            end
        else
            return noop
        end
    end

    -- Create loggers with appropriate colors
    BCCStashesDebug.Info = createLogger("INFO", 5)    -- Purple
    BCCStashesDebug.Error = createLogger("ERROR", 1)  -- Red
    BCCStashesDebug.Warning = createLogger("WARNING", 3) -- Yellow
    BCCStashesDebug.Success = createLogger("SUCCESS", 2) -- Green
end
