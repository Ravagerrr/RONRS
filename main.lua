--[[
    Electronics Trade Hub v3 - Modular Edition
    Execute this script to load all modules
]]

local BASE_URL = "https://raw.githubusercontent.com/YourUsername/YourRepo/main/"

-- Load modules in order (dependencies first)
local Config = loadstring(game:HttpGet(BASE_URL .. "config.lua"))()
local Helpers = loadstring(game:HttpGet(BASE_URL .. "helpers.lua"))()
local UI = loadstring(game:HttpGet(BASE_URL .. "ui.lua"))()
local Trading = loadstring(game:HttpGet(BASE_URL .. "trading.lua"))()
local AutoSell = loadstring(game:HttpGet(BASE_URL .. "autosell.lua"))()

-- Initialize with shared state
local State = {
    isRunning = false,
    isPaused = false,
    retryQueue = {},
    countryRetryState = {},
    Stats = {
        Success = 0,
        Skipped = 0,
        Failed = 0,
        FlowProtected = 0,
    }
}

-- Pass dependencies to modules
Helpers.init(Config)
UI.init(Config, State, Helpers, Trading, AutoSell)
Trading.init(Config, State, Helpers, UI)
AutoSell.init(Config, State, Helpers, Trading, UI)

-- Start
UI.createWindow()

if Config.AutoSellEnabled then
    task.wait(1)
    AutoSell.start()
end

Rayfield:LoadConfiguration()
