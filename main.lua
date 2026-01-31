--[[
    Trade Hub v4.2.015 - Multi-Resource
    Auto-start, simplified controls
    
    VERSION HISTORY:
    v4.2.015 - Auto-Buy now detects factory consumption (Electronics Factory, etc.) and buys required materials
    v4.2.014 - Trade verification now uses retry polling (5 attempts x 0.2s) for reliable detection
    v4.2.013 - Auto-Buy no longer buys when no city deficit and flow >= 0 (fixes random Titanium buying)
    v4.2.012 - Auto-Buy now correctly subtracts current flow from city deficit before buying
    v4.2.011 - Auto-Buy reads city Resources attributes for deficits (e.g., Iron = -4)
    v4.2.010 - Auto-Buy now checks factory counts instead of flow (fixes game trickling flow values)
    v4.2.009 - Faster check intervals (0.5s default) for real-time detection
    v4.2.008 - Auto-Buy targets +0.1 surplus flow, only buys when not in debt
    v4.2.007 - Added Auto-Buy feature for resource flow protection
    v4.2.006 - Added MaxRevenueSpendingPercent to prevent trade rejections
    
    REMINDER: Update version number in main.lua and ui.lua for each change
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
print("  Trade Hub v4.2.014")
print("══════════════════════════")

local Config = loadModule("config")
local Helpers = loadModule("helpers")
local UI = loadModule("ui")
local Trading = loadModule("trading")
local AutoSell = loadModule("autosell")
local AutoBuyer = loadModule("autobuyer")

if not (Config and Helpers and UI and Trading and AutoSell and AutoBuyer) then
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
UI.init(Config, State, Helpers, Trading, AutoSell, AutoBuyer)
Trading.init(Config, State, Helpers, UI)
AutoSell.init(Config, State, Helpers, Trading, UI)
AutoBuyer.init(Config, State, Helpers, UI)

-- Create UI (auto-start is handled in UI after config is loaded)
UI.createWindow()

print("[Ready]")
