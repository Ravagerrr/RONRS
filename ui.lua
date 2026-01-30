--[[
    UI MODULE
    Simplified Interface
]]

local M = {}
local Config, State, Helpers, Trading, AutoSell

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

M.Elements = {}
M.Logs = {}
M.Rayfield = Rayfield

function M.init(cfg, state, helpers, trading, autosell)
    Config = cfg
    State = state
    Helpers = helpers
    Trading = trading
    AutoSell = autosell
end

function M.log(msg, msgType)
    local entry = string.format("[%s] %s", os.date("%H:%M:%S"), msg)
    table.insert(M.Logs, 1, entry)
    if #M.Logs > 100 then table.remove(M.Logs) end
    warn(entry)
    M.updateLogs()
end

function M.updateLogs()
    if not M.Elements.LogParagraph then return end
    local text = ""
    for i = 1, math.min(15, #M.Logs) do
        text = text .. M.Logs[i] .. "\n"
    end
    pcall(function()
        M.Elements.LogParagraph:Set({Title = "Logs", Content = text ~= "" and text or "Ready"})
    end)
end

function M.updateStats()
    pcall(function()
        for _, res in ipairs(Config.Resources) do
            local label = M.Elements[res.name .. "Label"]
            if label and res.enabled then
                local avail = Helpers.getAvailableFlow(res)
                local selling = Helpers.getTotalSelling(res)
                local buyers = Helpers.getBuyerCount(res)
                local icon = res.name == "ConsumerGoods" and "CG" or "EL"
                label:Set(string.format("%s %.1f avail | Selling %.1f to %d", icon, avail, selling, buyers))
            end
        end
        
        if M.Elements.StatusLabel then
            local status = State.isRunning and "[RUNNING]" or "[IDLE]"
            M.Elements.StatusLabel:Set(status)
        end
        
        if M.Elements.StatsLabel then
            M.Elements.StatsLabel:Set(string.format("OK:%d Skip:%d Fail:%d", 
                State.Stats.Success, State.Stats.Skipped, State.Stats.Failed))
        end
    end)
end

function M.updateProgress(current, total)
    if M.Elements.ProgressLabel then
        pcall(function() M.Elements.ProgressLabel:Set(string.format("Progress: %d/%d", current, total)) end)
    end
end

function M.updateAutoSell()
    if not M.Elements.AutoSellStatus then return end
    pcall(function()
        if AutoSell and AutoSell.isMonitoring then
            M.Elements.AutoSellStatus:Set(string.format("AutoSell ON | Triggers: %d", AutoSell.triggers))
        else
            M.Elements.AutoSellStatus:Set("AutoSell OFF")
        end
    end)
end

function M.createWindow()
    local Window = Rayfield:CreateWindow({
        Name = "Trade Hub v4.2",
        LoadingTitle = "Loading...",
        ConfigurationSaving = {Enabled = true, FolderName = "ETH", FileName = "cfg_v4"}
    })
    
    local Home = Window:CreateTab("Home", 4483362458)
    
    Home:CreateSection("Status")
    M.Elements.StatusLabel = Home:CreateLabel("[IDLE]")
    M.Elements.ProgressLabel = Home:CreateLabel("Progress: 0/0")
    M.Elements.StatsLabel = Home:CreateLabel("OK:0 Skip:0 Fail:0")
    M.Elements.AutoSellStatus = Home:CreateLabel("AutoSell OFF")
    
    Home:CreateSection("Resources")
    for _, res in ipairs(Config.Resources) do
        local icon = res.name == "ConsumerGoods" and "CG" or "EL"
        M.Elements[res.name .. "Label"] = Home:CreateLabel(string.format("%s Loading...", icon))
    end
    
    Home:CreateSection("Control")
    Home:CreateButton({
        Name = "STOP EVERYTHING",
        Callback = function()
            State.isRunning = false
            AutoSell.stop()
            M.log("EMERGENCY STOP", "warning")
        end
    })
    
    local Resources = Window:CreateTab("Resources", 4483362458)
    Resources:CreateSection("Toggle")
    for i, res in ipairs(Config.Resources) do
        local icon = res.name == "ConsumerGoods" and "CG" or "EL"
        local cap = res.hasCap and string.format("Max %d", res.capAmount) or "No Cap"
        Resources:CreateToggle({
            Name = string.format("%s %s [%s]", icon, res.gameName, cap),
            CurrentValue = res.enabled,
            Callback = function(v) 
                Config.Resources[i].enabled = v 
                M.log(string.format("%s: %s", res.gameName, v and "ON" or "OFF"), "info")
            end
        })
    end
    
    local Settings = Window:CreateTab("Settings", 4483362458)
    
    Settings:CreateSection("Auto-Sell")
    Settings:CreateToggle({
        Name = "Enable Auto-Sell",
        CurrentValue = Config.AutoSellEnabled,
        Callback = function(v) 
            Config.AutoSellEnabled = v
            if v then AutoSell.start() else AutoSell.stop() end 
        end
    })
    Settings:CreateSlider({Name = "Threshold", Range = {1, 20}, Increment = 0.5, CurrentValue = Config.AutoSellThreshold,
        Callback = function(v) Config.AutoSellThreshold = v end})
    Settings:CreateSlider({Name = "Check Interval", Range = {1, 10}, Increment = 1, CurrentValue = Config.AutoSellCheckInterval,
        Callback = function(v) Config.AutoSellCheckInterval = v end})
    
    Settings:CreateSection("Flow")
    Settings:CreateToggle({Name = "Smart Sell", CurrentValue = Config.SmartSell,
        Callback = function(v) Config.SmartSell = v end})
    Settings:CreateSlider({Name = "Reserve", Range = {0, 10}, Increment = 0.5, CurrentValue = Config.SmartSellReserve,
        Callback = function(v) Config.SmartSellReserve = v end})
    
    Settings:CreateSection("Timing")
    Settings:CreateSlider({Name = "Cooldown", Range = {0.3, 2}, Increment = 0.1, CurrentValue = Config.WaitTime,
        Callback = function(v) Config.WaitTime = v end})
    
    Settings:CreateSection("Filters")
    Settings:CreateToggle({Name = "Skip Players", CurrentValue = Config.SkipPlayerCountries,
        Callback = function(v) Config.SkipPlayerCountries = v end})
    Settings:CreateToggle({Name = "Skip Producing", CurrentValue = Config.SkipProducingCountries,
        Callback = function(v) Config.SkipProducingCountries = v end})
    Settings:CreateToggle({Name = "Skip Existing Buyers", CurrentValue = Config.SkipExistingBuyers,
        Callback = function(v) Config.SkipExistingBuyers = v end})
    
    local Logs = Window:CreateTab("Logs", 4483362458)
    M.Elements.LogParagraph = Logs:CreateParagraph({Title = "Logs", Content = "Ready"})
    Logs:CreateButton({Name = "Copy", Callback = function() 
        if #M.Logs > 0 then setclipboard(table.concat(M.Logs, "\n")) end 
    end})
    Logs:CreateButton({Name = "Clear", Callback = function() M.Logs = {} M.updateLogs() end})
    
    M.log("=== Trade Hub v4.2 ===", "info")
    if Helpers.myCountryName then
        M.log("Country: " .. Helpers.myCountryName, "info")
    else
        M.log("No country selected", "warning")
    end
    
    M.updateStats()
    
    task.spawn(function()
        while true do
            task.wait(1)
            M.updateStats()
            M.updateAutoSell()
        end
    end)
    
    Rayfield:LoadConfiguration()
    
    return Window
end

return M
