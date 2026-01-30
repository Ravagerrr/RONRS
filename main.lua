--[[
    Electronics Trade Hub v3 - Modular Edition
    With correct GitHub URL format
]]

local BASE_URL = "https://raw.githubusercontent.com/Ravagerrr/RONRS/refs/heads/main/"

-- Safe loader function
local function loadModule(name)
    local url = BASE_URL .. name .. ".lua"
    print("[Loader] Loading: " .. name)
    
    local success, result = pcall(function()
        local content = game:HttpGet(url)
        
        if content:find("404") or #content < 20 then
            error("Got 404 or empty response")
        end
        
        print("[Loader] Got " .. name .. " (" .. #content .. " chars)")
        
        local func, err = loadstring(content)
        if not func then
            error("Loadstring failed: " .. tostring(err))
        end
        
        return func()
    end)
    
    if success then
        print("[Loader] ✓ Loaded: " .. name)
        return result
    else
        warn("[Loader] ✗ FAILED: " .. name .. " - " .. tostring(result))
        return nil
    end
end

-- Load modules
print("═══════════════════════════════════")
print("  Loading Electronics Trade Hub")
print("═══════════════════════════════════")

local Config = loadModule("config")
if not Config then error("Config failed to load!") end

local Helpers = loadModule("helpers")
if not Helpers then error("Helpers failed to load!") end

local UI = loadModule("ui")
if not UI then error("UI failed to load!") end

local Trading = loadModule("trading")
if not Trading then error("Trading failed to load!") end

local AutoSell = loadModule("autosell")
if not AutoSell then error("AutoSell failed to load!") end

print("═══════════════════════════════════")
print("  All modules loaded!")
print("═══════════════════════════════════")

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
print("[Init] Initializing Helpers...")
Helpers.init(Config)

print("[Init] Initializing UI...")
UI.init(Config, State, Helpers, Trading, AutoSell)

print("[Init] Initializing Trading...")
Trading.init(Config, State, Helpers, UI)

print("[Init] Initializing AutoSell...")
AutoSell.init(Config, State, Helpers, Trading, UI)

-- Start
print("[Init] Creating window...")
UI.createWindow()

if Config.AutoSellEnabled then
    task.wait(1)
    AutoSell.start()
end

print("[Init] Done!")
