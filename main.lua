--[[
    Electronics Trade Hub v3 - Modular Edition
    Main loader script
]]

local BASE_URL = "https://raw.githubusercontent.com/Ravagerrr/RONRS/refs/heads/main/"

-- Shared state
local State = {
    isRunning = false,
    isPaused = false,
    Stats = {Success = 0, Skipped = 0, Failed = 0},
    retryQueue = {},
    ManageAlliance = workspace:WaitForChild("GameManager"):WaitForChild("ManageAlliance")
}

-- Load modules with error handling
local function loadModule(name)
    local url = BASE_URL .. name .. ".lua"
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if success and result then
        print("[Loader] OK: " .. name)
        return result
    else
        warn("[Loader] FAIL: " .. name .. " - " .. tostring(result))
        return nil
    end
end

print("=== Loading Electronics Trade Hub v3 ===")

local Config = loadModule("config")
local Helpers = loadModule("helpers")
local UI = loadModule("ui")
local Trading = loadModule("trading")
local AutoSell = loadModule("autosell")

if not Config or not Helpers or not UI or not Trading or not AutoSell then
    warn("Failed to load one or more modules!")
    return
end

-- Pass Config to Helpers so it knows SmartSellReserve
Helpers.Config = Config

-- Initialize modules
Helpers.refreshMyCountry()
UI.init(Config, State, Helpers, Trading, AutoSell)
Trading.init(Config, State, Helpers, UI)
AutoSell.init(Config, State, Helpers, UI, Trading)

-- Create UI
UI.createWindow()

-- Debug: Show detected country
print("=== Country Detection ===")
print("Country Name: " .. tostring(Helpers.myCountryName))
print("Country Object: " .. tostring(Helpers.myCountry))
print("Flow: " .. tostring(Helpers.getMyFlow()))
print("=========================")

-- Log startup
UI.log("=== Trade Hub v3 Ready ===", "info")
if Helpers.myCountryName then
    UI.log("Country: " .. Helpers.myCountryName, "info")
    UI.log(string.format("Flow: %.2f | Selling: %.2f to %d buyers", 
        Helpers.getMyFlow(), 
        Helpers.getTotalSelling(),
        Helpers.getBuyerCount()), "info")
else
    UI.log("[!] No country detected - select a country first!", "warning")
end

-- Start auto-sell if enabled
if Config.AutoSellEnabled then
    task.wait(2)
    AutoSell.start()
end
