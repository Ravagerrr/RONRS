--[[
    Trade Hub v4.0 - Multi-Resource Edition
    Consumer Goods + Electronics with Priority System
]]

local BASE_URL = "https://raw.githubusercontent.com/Ravagerrr/RONRS/refs/heads/main/"

local function loadModule(name)
    local url = BASE_URL .. name .. ".lua"
    print("[Loader] Loading: " .. name)
    
    local success, result = pcall(function()
        local content = game:HttpGet(url)
        if content:find("404") or #content < 20 then
            error("Got 404 or empty response")
        end
        local func, err = loadstring(content)
        if not func then error("Loadstring failed: " .. tostring(err)) end
        return func()
    end)
    
    if success then
        print("[Loader] ✓ " .. name)
        return result
    else
        warn("[Loader] ✗ " .. name .. " - " .. tostring(result))
        return nil
    end
end

print("═══════════════════════════════════════")
print("  Trade Hub v4.0 - Multi-Resource")
print("  🛒 Consumer Goods + ⚡ Electronics")
print("═══════════════════════════════════════")

local Config = loadModule("config")
local Helpers = loadModule("helpers")
local UI = loadModule("ui")
local Trading = loadModule("trading")
local AutoSell = loadModule("autosell")

if not (Config and Helpers and UI and Trading and AutoSell) then
    error("Failed to load modules!")
end

print("═══════════════════════════════════════")

-- Shared state
local State = {
    isRunning = false,
    isPaused = false,
    retryQueue = {},
    Stats = {
        Success = 0,
        Skipped = 0,
        Failed = 0,
        FlowProtected = 0,
        ByResource = {}
    }
}

-- Initialize modules
Helpers.init(Config)
UI.init(Config, State, Helpers, Trading, AutoSell)
Trading.init(Config, State, Helpers, UI)
AutoSell.init(Config, State, Helpers, Trading, UI)

-- Create UI
UI.createWindow()

-- Start auto-sell if enabled
if Config.AutoSellEnabled then
    task.wait(1)
    AutoSell.start()
end

print("[Init] ✓ Ready!")
