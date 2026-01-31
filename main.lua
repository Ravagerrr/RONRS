--[[
    Trade Hub v4.2.005 - Multi-Resource
    Auto-start, simplified controls
]]

local BASE_URL = "https://raw.githubusercontent.com/Ravagerrr/RONRS/refs/heads/main/"

local function loadModule(name)
    local url = BASE_URL .. name .. ".lua"
    print("[Loader] " .. name)
    
    local success, result = pcall(function()
        local content = game:HttpGet(url)
        if content:find("404") or #content < 20 then
            error("404 or empty")
        end
        local func, err = loadstring(content)
        if not func then error(tostring(err)) end
        return func()
    end)
    
    if success then
        print("[OK] " .. name)
        return result
    else
        warn("[FAIL] " .. name .. ": " .. tostring(result))
        return nil
    end
end

print("══════════════════════════")
print("  Trade Hub v4.2.005")
print("══════════════════════════")

local Config = loadModule("config")
local Helpers = loadModule("helpers")
local UI = loadModule("ui")
local Trading = loadModule("trading")
local AutoSell = loadModule("autosell")

if not (Config and Helpers and UI and Trading and AutoSell) then
    error("Module load failed!")
end

-- Shared state
local State = {
    isRunning = false,
    retryQueue = {},
    Stats = {Success = 0, Skipped = 0, Failed = 0, ByResource = {}}
}

-- Initialize
Helpers.init(Config)
UI.init(Config, State, Helpers, Trading, AutoSell)
Trading.init(Config, State, Helpers, UI)
AutoSell.init(Config, State, Helpers, Trading, UI)

-- Create UI
UI.createWindow()

-- Auto-start if enabled
if Config.AutoSellEnabled then
    task.wait(1)
    AutoSell.start()
end

print("[Ready]")
