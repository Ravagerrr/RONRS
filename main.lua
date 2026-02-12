--[[
    Trade Hub v2.1.1 - Bug Fixes & Improvements
    Cleaner navigation, less redundancy
]]

-- Cleanup previous instance before re-injection
-- This prevents lag from accumulating loops and UI elements
if _G.TradeHubCleanup then
    print("[Cleanup] Cleaning up previous instance...")
    pcall(_G.TradeHubCleanup)
    _G.TradeHubCleanup = nil
end

-- BASE_URL Configuration
-- To test a fork or different branch, set _G.RONRS_BASE_URL before executing:
-- Example for fork: _G.RONRS_BASE_URL = "https://raw.githubusercontent.com/YourUsername/RONRS/main/"
-- Example for branch: _G.RONRS_BASE_URL = "https://raw.githubusercontent.com/Ravagerrr/RONRS/your-branch/"
local BASE_URL = _G.RONRS_BASE_URL or "https://raw.githubusercontent.com/Ravagerrr/RONRS/main/"

-- Log which source we're loading from (helps debug fork issues)
print("[Source] " .. BASE_URL)

local function loadModule(name)
    local url = BASE_URL .. name .. ".lua"
    print("[Loader] " .. name)
    
    -- Check if loadstring is available
    if not loadstring then
        warn("[FAIL] " .. name .. ": loadstring is not available in this executor")
        return nil
    end
    
    local success, result = pcall(function()
        local content = game:HttpGet(url)
        if not content or type(content) ~= "string" then
            error("HttpGet returned " .. tostring(type(content)) .. " instead of string")
        end
        if content:find("404") or #content < 20 then
            error("404 or empty (length: " .. #content .. ")")
        end
        local func, err = loadstring(content)
        if not func then 
            error("loadstring failed: " .. tostring(err)) 
        end
        local execSuccess, execResult = pcall(func)
        if not execSuccess then
            error("module execution failed: " .. tostring(execResult))
        end
        return execResult
    end)
    
    if success then
        print("[OK] " .. name)
        return result
    else
        warn("[FAIL] " .. name .. ": " .. tostring(result))
        return nil
    end
end

print("Trade Hub v2.1.1")

local Config = loadModule("config")
local Helpers = loadModule("helpers")
local UI = loadModule("ui")
local Trading = loadModule("trading")
local AutoSell = loadModule("autosell")
local AutoBuyer = loadModule("autobuyer")
local WarMonitor = loadModule("warmonitor")

if not (Config and Helpers and UI and Trading and AutoSell and AutoBuyer and WarMonitor) then
    error("Module load failed!")
end

-- Shared state
local State = {
    isRunning = false,
    retryQueue = {},
    flowQueue = {},  -- Queue for trades limited by flow protection
    Stats = {Success = 0, Skipped = 0, Failed = 0, ByResource = {}}
}

-- Initialize
Helpers.init(Config)
UI.init(Config, State, Helpers, Trading, AutoSell, AutoBuyer, WarMonitor)
Trading.init(Config, State, Helpers, UI)
AutoSell.init(Config, State, Helpers, Trading, UI)
AutoBuyer.init(Config, State, Helpers, UI)
WarMonitor.init(Config, State, Helpers, UI)

-- Create UI (auto-start is handled in UI after config is loaded)
local Window = UI.createWindow()

-- Register cleanup function for next injection
_G.TradeHubCleanup = function()
    print("[Cleanup] Stopping automation...")
    -- Stop running processes
    State.isRunning = false
    if AutoSell then AutoSell.stop() end
    if AutoBuyer then AutoBuyer.stop() end
    if WarMonitor then WarMonitor.stop() end
    
    print("[Cleanup] Destroying UI...")
    -- Destroy Rayfield window
    if UI.cleanup then
        UI.cleanup()
    end
end

print("[Ready]")
