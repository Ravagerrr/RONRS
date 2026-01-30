--[[
    UI MODULE
    Multi-Resource Interface
]]

local M = {}
local Config, State, Helpers, Trading, AutoSell

-- Load Rayfield
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
        M.Elements.LogParagraph:Set({Title = "📋 Logs", Content = text ~= "" and text or "Ready"})
    end)
end

function M.updateStats()
    pcall(function()
        -- Update per-resource stats
        for _, res in ipairs(Helpers.getEnabledResources()) do
            local flow = Helpers.getFlow(res)
            local avail = Helpers.getAvailableFlow(res)
            local selling = Helpers.getTotalSelling(res)
            local buyers = Helpers.getBuyerCount(res)
            
            local label = M.Elements[res.name .. "Label"]
            if label then
                local icon = res.name == "ConsumerGoods" and "🛒" or "⚡"
                label:Set(string.format("%s %s: %.2f (%.2f avail) | Selling %.2f to %d", 
                    icon, res.gameName, flow, avail, selling, buyers))
            end
        end
        
        -- Update general stats
        if M.Elements.SuccessLabel then 
            M.Elements.SuccessLabel:Set(string.format("✓ Success: %d", State.Stats.Success)) 
        end
        if M.Elements.SkippedLabel then 
            M.Elements.SkippedLabel:Set(string.format("⊘ Skipped: %d", State.Stats.Skipped)) 
        end
        if M.Elements.FailedLabel then 
            M.Elements.FailedLabel:Set(string.format("✗ Failed: %d", State.Stats.Failed)) 
        end
        if M.Elements.QueueLabel then 
            M.Elements.QueueLabel:Set(string.format("📋 Queue: %d", #State.retryQueue)) 
        end
    end)
end

function M.updateProgress(current, total)
    if M.Elements.ProgressLabel then
        pcall(function() M.Elements.ProgressLabel:Set(string.format("Progress: %d/%d", current, total)) end)
    end
end

function M.updateAutoSell()
    if not M.Elements.AutoSellLabel then return end
    pcall(function()
        if AutoSell and AutoSell.isMonitoring then
            local totalAvail = Helpers.getTotalAvailableFlow()
            M.Elements.AutoSellLabel:Set(string.format("✓ Monitoring (%.2f total avail) [%d triggers]", 
                totalAvail, AutoSell.triggers))
        else
            M.Elements.AutoSellLabel:Set("⏸ Disabled")
        end
    end)
end

function M.createWindow()
    local Window = Rayfield:CreateWindow({
        Name = "Trade Hub 🔄 v4.0",
        LoadingTitle = "Loading Multi-Resource...",
        ConfigurationSaving = {Enabled = true, FolderName = "ETH", FileName = "cfg_v4"}
    })
    
    -- HOME
    local Home = Window:CreateTab("🏠 Home", 4483362458)
    
    Home:CreateSection("Controls")
    
    Home:CreateButton({Name = "🚀 Start Trading", Callback = function()
        if not State.isRunning then task.spawn(function() Trading.run() end) end
    end})
    
    Home:CreateButton({Name = "🛑 Stop", Callback = function() State.isRunning = false end})
    Home:CreateButton({Name = "⏸️ Pause/Resume", Callback = function() State.isPaused = not State.isPaused end})
    
    Home:CreateSection("Resources")
    
    -- Create label for each resource
    for _, res in ipairs(Config.Resources) do
        local icon = res.name == "ConsumerGoods" and "🛒" or "⚡"
        M.Elements[res.name .. "Label"] = Home:CreateLabel(
            string.format("%s %s: Loading...", icon, res.gameName)
        )
    end
    
    Home:CreateSection("Progress")
    
    M.Elements.ProgressLabel = Home:CreateLabel("Progress: 0/0")
    
    Home:CreateSection("Stats")
    
    M.Elements.SuccessLabel = Home:CreateLabel("✓ Success: 0")
    M.Elements.SkippedLabel = Home:CreateLabel("⊘ Skipped: 0")
    M.Elements.FailedLabel = Home:CreateLabel("✗ Failed: 0")
    M.Elements.QueueLabel = Home:CreateLabel("📋 Queue: 0")
    
    Home:CreateSection("Auto-Sell")
    
    M.Elements.AutoSellLabel = Home:CreateLabel("⏸ Auto-Sell")
    
    -- RESOURCES TAB
    local Resources = Window:CreateTab("📦 Resources", 4483362458)
    
    Resources:CreateSection("Enable/Disable Resources")
    
    for i, res in ipairs(Config.Resources) do
        local icon = res.name == "ConsumerGoods" and "🛒" or "⚡"
        Resources:CreateToggle({
            Name = string.format("%s %s ($%d)", icon, res.gameName, res.buyPrice),
            CurrentValue = res.enabled,
            Callback = function(v) 
                Config.Resources[i].enabled = v 
                M.log(string.format("%s %s: %s", icon, res.gameName, v and "ENABLED" or "DISABLED"), "info")
            end
        })
    end
    
    Resources:CreateSection("Priority Info")
    Resources:CreateParagraph({
        Title = "Priority Order",
        Content = "🛒 Consumer Goods (Priority 1)\n⚡ Electronics (Priority 2)\n\nHigher priority resources are traded first for each country."
    })
    
    -- SETTINGS
    local Settings = Window:CreateTab("⚙️ Settings", 4483362458)
    
    Settings:CreateSection("Timing")
    
    Settings:CreateSlider({
        Name = "Wait Time (Server Cooldown)", 
        Range = {0.3, 2}, 
        Increment = 0.1, 
        CurrentValue = Config.WaitTime,
        Callback = function(v) Config.WaitTime = v end
    })
    
    Settings:CreateSlider({
        Name = "Resource Switch Delay", 
        Range = {0.1, 1}, 
        Increment = 0.1, 
        CurrentValue = Config.ResourceDelay,
        Callback = function(v) Config.ResourceDelay = v end
    })
    
    Settings:CreateSection("Trading")
    
    Settings:CreateSlider({
        Name = "Max Amount per Trade", 
        Range = {0.1, 10}, 
        Increment = 0.1, 
        CurrentValue = Config.MaxAmount,
        Callback = function(v) Config.MaxAmount = v end
    })
    
    Settings:CreateSection("Flow Protection")
    
    Settings:CreateToggle({
        Name = "🛡️ Smart Sell (Keep Reserve)", 
        CurrentValue = Config.SmartSell,
        Callback = function(v) Config.SmartSell = v end
    })
    
    Settings:CreateSlider({
        Name = "Flow Reserve (per resource)", 
        Range = {0, 20}, 
        Increment = 0.5, 
        CurrentValue = Config.SmartSellReserve,
        Callback = function(v) Config.SmartSellReserve = v end
    })
    
    Settings:CreateSection("Filters")
    
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
    
    Settings:CreateSection("Retry System")
    
    Settings:CreateToggle({
        Name = "Enable Retry Queue", 
        CurrentValue = Config.RetryEnabled,
        Callback = function(v) Config.RetryEnabled = v end
    })
    
    Settings:CreateSlider({
        Name = "Max Retry Passes", 
        Range = {1, 5}, 
        Increment = 1, 
        CurrentValue = Config.MaxRetryPasses,
        Callback = function(v) Config.MaxRetryPasses = v end
    })
    
    Settings:CreateSection("Auto-Sell")
    
    Settings:CreateToggle({
        Name = "🤖 Enable Auto-Sell Monitor", 
        CurrentValue = Config.AutoSellEnabled,
        Callback = function(v) 
            Config.AutoSellEnabled = v
            if v then AutoSell.start() else AutoSell.stop() end 
        end
    })
    
    Settings:CreateSlider({
        Name = "Auto-Sell Threshold (Total Flow)", 
        Range = {1, 20}, 
        Increment = 0.5, 
        CurrentValue = Config.AutoSellThreshold,
        Callback = function(v) Config.AutoSellThreshold = v end
    })
    
    Settings:CreateSlider({
        Name = "Check Interval (seconds)", 
        Range = {1, 10}, 
        Increment = 1, 
        CurrentValue = Config.AutoSellCheckInterval,
        Callback = function(v) Config.AutoSellCheckInterval = v end
    })
    
    -- LOGS
    local Logs = Window:CreateTab("📜 Logs", 4483362458)
    M.Elements.LogParagraph = Logs:CreateParagraph({Title = "📋 Logs", Content = "Ready"})
    Logs:CreateButton({Name = "📋 Copy All", Callback = function() 
        if #M.Logs > 0 then setclipboard(table.concat(M.Logs, "\n")) end 
    end})
    Logs:CreateButton({Name = "🗑️ Clear", Callback = function() M.Logs = {} M.updateLogs() end})
    
    -- INFO
    local Info = Window:CreateTab("ℹ️ Info", 4483362458)
    Info:CreateParagraph({
        Title = "Trade Hub v4.0", 
        Content = "Multi-Resource Edition\n\nSupports simultaneous trading of:\n🛒 Consumer Goods ($82,400) - Priority 1\n⚡ Electronics ($102,000) - Priority 2\n\nConsumer Goods always trades first!"
    })
    
    if Helpers.myCountryName then
        Info:CreateLabel("🏴 Country: " .. Helpers.myCountryName)
    else
        Info:CreateLabel("⚠️ No country selected")
    end
    
    -- Initial log
    M.log("═══ Trade Hub v4.0 Ready ═══", "info")
    if Helpers.myCountryName then
        M.log(string.format("🏴 %s", Helpers.myCountryName), "info")
        for _, res in ipairs(Helpers.getEnabledResources()) do
            local icon = res.name == "ConsumerGoods" and "🛒" or "⚡"
            M.log(string.format("%s %s: %.2f flow", icon, res.gameName, Helpers.getFlow(res)), "info")
        end
    end
    
    M.updateStats()
    
    -- Auto-refresh loop
    task.spawn(function()
        while true do
            task.wait(2)
            M.updateStats()
            M.updateAutoSell()
        end
    end)
    
    Rayfield:LoadConfiguration()
    
    return Window
end

return M
