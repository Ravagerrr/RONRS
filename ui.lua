--[[
    UI MODULE v2.0
    Reorganized Interface - Clean & Easy to Navigate
    
    Tabs:
    1. Dashboard - Status overview & emergency controls
    2. Resources - All resource toggles (Sell + Buy)
    3. Automation - Auto-Sell & Auto-Buy settings
    4. Settings - Filters, Flow, Timing
    5. Logs - Activity log
]]

local M = {}
local Config, State, Helpers, Trading, AutoSell, AutoBuyer

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

M.Elements = {}
M.Logs = {}
M.Rayfield = Rayfield
M.lastLogUpdate = 0
M.Window = nil
M.isRunning = true  -- Controls the background update loop

function M.init(cfg, state, helpers, trading, autosell, autobuyer)
    Config = cfg
    State = state
    Helpers = helpers
    Trading = trading
    AutoSell = autosell
    AutoBuyer = autobuyer
end

function M.log(msg, msgType)
    local entry = string.format("[%s] %s", os.date("%H:%M:%S"), msg)
    table.insert(M.Logs, 1, entry)
    while #M.Logs > 10000 do table.remove(M.Logs) end
    warn(entry)
    
    local now = tick()
    if now - M.lastLogUpdate > 0.1 then
        M.lastLogUpdate = now
        M.updateLogs()
    end
end

function M.updateLogs()
    if not M.Elements.LogParagraph then return end
    local text = ""
    local displayCount = Config.LogDisplayCount or 100
    for i = 1, math.min(displayCount, #M.Logs) do
        text = text .. M.Logs[i] .. "\n"
    end
    pcall(function()
        M.Elements.LogParagraph:Set({Title = string.format("Logs (%d)", #M.Logs), Content = text ~= "" and text or "Ready"})
    end)
end

function M.updateStats()
    pcall(function()
        -- Update resource stats
        for _, res in ipairs(Config.Resources) do
            local label = M.Elements[res.name .. "Label"]
            if label and res.enabled then
                local avail = Helpers.getAvailableFlow(res)
                local selling = Helpers.getTotalSelling(res)
                local buyers = Helpers.getBuyerCount(res)
                label:Set(string.format("%s: %.1f avail | %.1f to %d buyers", res.gameName, avail, selling, buyers))
            end
        end
        
        -- Update combined status
        if M.Elements.StatusLabel then
            local countryName = Helpers.myCountryName or "None"
            local status = State.isRunning and "RUNNING" or "IDLE"
            local autoSell = (AutoSell and AutoSell.isMonitoring) and "ON" or "OFF"
            local autoBuy = (AutoBuyer and AutoBuyer.isMonitoring) and "ON" or "OFF"
            M.Elements.StatusLabel:Set(string.format("[%s] %s | Sell:%s Buy:%s", status, countryName, autoSell, autoBuy))
        end
        
        if M.Elements.StatsLabel then
            M.Elements.StatsLabel:Set(string.format("Trades: %d OK | %d Skip | %d Fail", 
                State.Stats.Success, State.Stats.Skipped, State.Stats.Failed))
        end
        
        -- Update automation counters
        if M.Elements.AutomationStats then
            local sellTriggers = AutoSell and AutoSell.triggers or 0
            local buyPurchases = AutoBuyer and AutoBuyer.purchases or 0
            M.Elements.AutomationStats:Set(string.format("Sell Triggers: %d | Buy Purchases: %d", sellTriggers, buyPurchases))
        end
    end)
end

function M.updateProgress(current, total)
    if M.Elements.ProgressLabel then
        pcall(function() M.Elements.ProgressLabel:Set(string.format("Progress: %d / %d countries", current, total)) end)
    end
end

function M.updateAutoSell()
    -- Now handled in updateStats()
end

function M.updateAutoBuy()
    -- Now handled in updateStats()
end

function M.updateCountry()
    -- Now handled in updateStats()
    pcall(function()
        Helpers.refreshMyCountry()
    end)
end

function M.createWindow()
    M.isRunning = true  -- Enable background loop for this instance
    
    local Window = Rayfield:CreateWindow({
        Name = "Trade Hub v2.0",
        LoadingTitle = "Loading...",
        ConfigurationSaving = {Enabled = true, FolderName = "ETH", FileName = "cfg_v5"}
    })
    
    -- ══════════════════════════════════════════════════════════════
    -- TAB 1: DASHBOARD - Status overview & emergency controls
    -- ══════════════════════════════════════════════════════════════
    local Dashboard = Window:CreateTab("Dashboard", 4483362458)
    
    Dashboard:CreateSection("Status")
    M.Elements.StatusLabel = Dashboard:CreateLabel("[IDLE] Loading...")
    M.Elements.ProgressLabel = Dashboard:CreateLabel("Progress: 0 / 0 countries")
    M.Elements.StatsLabel = Dashboard:CreateLabel("Trades: 0 OK | 0 Skip | 0 Fail")
    M.Elements.AutomationStats = Dashboard:CreateLabel("Sell Triggers: 0 | Buy Purchases: 0")
    
    Dashboard:CreateSection("Resource Flow")
    for _, res in ipairs(Config.Resources) do
        M.Elements[res.name .. "Label"] = Dashboard:CreateLabel(string.format("%s: Loading...", res.gameName))
    end
    
    Dashboard:CreateSection("Emergency")
    Dashboard:CreateButton({
        Name = "⛔ STOP EVERYTHING",
        Callback = function()
            State.isRunning = false
            AutoSell.stop()
            if AutoBuyer then AutoBuyer.stop() end
            M.log("EMERGENCY STOP", "warning")
        end
    })
    
    -- ══════════════════════════════════════════════════════════════
    -- TAB 2: RESOURCES - All resource toggles in one place
    -- ══════════════════════════════════════════════════════════════
    local Resources = Window:CreateTab("Resources", 4483362458)
    
    Resources:CreateSection("📤 Sell Resources")
    for i, res in ipairs(Config.Resources) do
        local cap = res.hasCap and string.format("Max %d", res.capAmount) or "No Cap"
        Resources:CreateToggle({
            Name = string.format("%s [%s]", res.gameName, cap),
            CurrentValue = res.enabled,
            Callback = function(v) 
                Config.Resources[i].enabled = v 
                M.log(string.format("Sell %s: %s", res.gameName, v and "ON" or "OFF"), "info")
            end
        })
    end
    
    Resources:CreateSection("📥 Buy Resources (Auto-Buy)")
    for i, res in ipairs(Config.AutoBuyResources) do
        Resources:CreateToggle({
            Name = res.gameName,
            CurrentValue = res.enabled,
            Callback = function(v) 
                Config.AutoBuyResources[i].enabled = v 
                M.log(string.format("Buy %s: %s", res.gameName, v and "ON" or "OFF"), "info")
            end
        })
    end
    
    -- ══════════════════════════════════════════════════════════════
    -- TAB 3: AUTOMATION - Auto-Sell & Auto-Buy feature settings
    -- ══════════════════════════════════════════════════════════════
    local Automation = Window:CreateTab("Automation", 4483362458)
    
    Automation:CreateSection("📤 Auto-Sell")
    Automation:CreateToggle({
        Name = "Enable Auto-Sell",
        CurrentValue = Config.AutoSellEnabled,
        Callback = function(v) 
            Config.AutoSellEnabled = v
            if v then AutoSell.start() else AutoSell.stop() end 
        end
    })
    Automation:CreateSlider({
        Name = "Flow Threshold",
        Range = {1, 20},
        Increment = 0.5,
        CurrentValue = Config.AutoSellThreshold,
        Callback = function(v) Config.AutoSellThreshold = v end
    })
    Automation:CreateSlider({
        Name = "Check Interval (s)",
        Range = {0.2, 5},
        Increment = 0.1,
        CurrentValue = Config.AutoSellCheckInterval,
        Callback = function(v) Config.AutoSellCheckInterval = v end
    })
    
    Automation:CreateSection("📥 Auto-Buy")
    Automation:CreateToggle({
        Name = "Enable Auto-Buy",
        CurrentValue = Config.AutoBuyEnabled,
        Callback = function(v) 
            Config.AutoBuyEnabled = v
            if AutoBuyer then
                if v then AutoBuyer.start() else AutoBuyer.stop() end
            end
        end
    })
    Automation:CreateSlider({
        Name = "Check Interval (s)",
        Range = {0.2, 5},
        Increment = 0.1,
        CurrentValue = Config.AutoBuyCheckInterval,
        Callback = function(v) Config.AutoBuyCheckInterval = v end
    })
    
    -- ══════════════════════════════════════════════════════════════
    -- TAB 4: SETTINGS - Filters, Flow, Timing
    -- ══════════════════════════════════════════════════════════════
    local Settings = Window:CreateTab("Settings", 4483362458)
    
    Settings:CreateSection("🛡️ Flow Protection")
    Settings:CreateToggle({
        Name = "Smart Sell (Reserve Flow)",
        CurrentValue = Config.SmartSell,
        Callback = function(v) Config.SmartSell = v end
    })
    Settings:CreateSlider({
        Name = "Reserve Amount",
        Range = {0, 10},
        Increment = 0.5,
        CurrentValue = Config.SmartSellReserve,
        Callback = function(v) Config.SmartSellReserve = v end
    })
    
    Settings:CreateSection("⏱️ Timing")
    Settings:CreateSlider({
        Name = "Trade Cooldown (s)",
        Range = {0.3, 2},
        Increment = 0.1,
        CurrentValue = Config.WaitTime,
        Callback = function(v) Config.WaitTime = v end
    })
    
    Settings:CreateSection("🔍 Trade Filters")
    Settings:CreateToggle({
        Name = "Skip Player Countries",
        CurrentValue = Config.SkipPlayerCountries,
        Callback = function(v) Config.SkipPlayerCountries = v end
    })
    Settings:CreateToggle({
        Name = "Skip Producing Countries",
        CurrentValue = Config.SkipProducingCountries,
        Callback = function(v) Config.SkipProducingCountries = v end
    })
    Settings:CreateToggle({
        Name = "Skip Existing Buyers",
        CurrentValue = Config.SkipExistingBuyers,
        Callback = function(v) Config.SkipExistingBuyers = v end
    })
    
    -- ══════════════════════════════════════════════════════════════
    -- TAB 5: LOGS - Activity log
    -- ══════════════════════════════════════════════════════════════
    local Logs = Window:CreateTab("Logs", 4483362458)
    
    M.Elements.LogParagraph = Logs:CreateParagraph({Title = "Activity Log", Content = "Ready"})
    
    Logs:CreateSection("Actions")
    Logs:CreateButton({
        Name = "📋 Copy Logs",
        Callback = function() 
            if #M.Logs > 0 then setclipboard(table.concat(M.Logs, "\n")) end 
        end
    })
    Logs:CreateButton({
        Name = "🗑️ Clear Logs",
        Callback = function() M.Logs = {} M.updateLogs() end
    })
    
    -- ══════════════════════════════════════════════════════════════
    -- INITIALIZATION
    -- ══════════════════════════════════════════════════════════════
    
    M.log("=== Trade Hub v2.0 ===", "info")
    if Helpers.myCountryName then
        M.log("Country: " .. Helpers.myCountryName, "info")
    else
        M.log("No country selected", "warning")
    end
    
    M.updateStats()
    M.updateCountry()
    
    -- Background update loop
    task.spawn(function()
        while M.isRunning do
            task.wait(1)
            M.updateStats()
            M.updateCountry()
        end
    end)
    
    Rayfield:LoadConfiguration()
    
    -- Auto-start features after config loads
    task.spawn(function()
        task.wait(1)
        if Config.AutoSellEnabled and AutoSell then
            AutoSell.start()
        end
        if Config.AutoBuyEnabled and AutoBuyer then
            AutoBuyer.start()
        end
    end)
    
    M.Window = Window
    return Window
end

-- Cleanup function for re-injection
function M.cleanup()
    -- Stop background loop
    M.isRunning = false
    
    -- Destroy Rayfield window
    if Rayfield and Rayfield.Destroy then
        pcall(function()
            Rayfield:Destroy()
        end)
    end
    
    -- Clear references
    M.Window = nil
    M.Elements = {}
    M.Logs = {}
end

return M
