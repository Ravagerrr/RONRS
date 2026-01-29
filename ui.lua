--[[
    UI MODULE
    Rayfield interface
]]

local M = {}
local Config, State, Helpers, Trading, AutoSell

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

M.Elements = {}
M.Logs = {}

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
        local flow, avail = Helpers.getMyFlow(), Helpers.getAvailableFlow()
        if M.Elements.FlowLabel then M.Elements.FlowLabel:Set(string.format("⚡ Flow: %.2f | Avail: %.2f", flow, avail)) end
        if M.Elements.SuccessLabel then M.Elements.SuccessLabel:Set(string.format("✓ Success: %d", State.Stats.Success)) end
        if M.Elements.SkippedLabel then M.Elements.SkippedLabel:Set(string.format("⊘ Skipped: %d", State.Stats.Skipped)) end
        if M.Elements.FailedLabel then M.Elements.FailedLabel:Set(string.format("✗ Failed: %d", State.Stats.Failed)) end
        if M.Elements.QueueLabel then M.Elements.QueueLabel:Set(string.format("📋 Queue: %d", #State.retryQueue)) end
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
        if AutoSell.isMonitoring then
            M.Elements.AutoSellLabel:Set(string.format("✓ Monitoring (%.2f avail)", Helpers.getAvailableFlow()))
        else
            M.Elements.AutoSellLabel:Set("⏸ Disabled")
        end
    end)
end

function M.createWindow()
    local Window = Rayfield:CreateWindow({
        Name = "Electronics Trade Hub ⚡ v3",
        LoadingTitle = "Loading...",
        ConfigurationSaving = {Enabled = true, FolderName = "ETH", FileName = "cfg"}
    })
    
    -- HOME
    local Home = Window:CreateTab("🏠 Home", 4483362458)
    
    Home:CreateButton({Name = "🚀 Start", Callback = function()
        if not State.isRunning then task.spawn(Trading.run) end
    end})
    
    Home:CreateButton({Name = "🛑 Stop", Callback = function() State.isRunning = false end})
    Home:CreateButton({Name = "⏸️ Pause", Callback = function() State.isPaused = not State.isPaused end})
    
    M.Elements.ProgressLabel = Home:CreateLabel("Progress: 0/0")
    M.Elements.FlowLabel = Home:CreateLabel("⚡ Flow: 0 | Avail: 0")
    M.Elements.SuccessLabel = Home:CreateLabel("✓ Success: 0")
    M.Elements.SkippedLabel = Home:CreateLabel("⊘ Skipped: 0")
    M.Elements.FailedLabel = Home:CreateLabel("✗ Failed: 0")
    M.Elements.QueueLabel = Home:CreateLabel("📋 Queue: 0")
    M.Elements.AutoSellLabel = Home:CreateLabel("⏸ Auto-Sell")
    
    -- SETTINGS
    local Settings = Window:CreateTab("⚙️ Settings", 4483362458)
    
    Settings:CreateSlider({Name = "Wait Time", Range = {0.3, 2}, Increment = 0.1, CurrentValue = Config.WaitTime,
        Callback = function(v) Config.WaitTime = v end})
    
    Settings:CreateSlider({Name = "Max Amount", Range = {0.1, 10}, Increment = 0.1, CurrentValue = Config.MaxAmount,
        Callback = function(v) Config.MaxAmount = v end})
    
    Settings:CreateSlider({Name = "Flow Reserve", Range = {0, 20}, Increment = 0.5, CurrentValue = Config.SmartSellReserve,
        Callback = function(v) Config.SmartSellReserve = v end})
    
    Settings:CreateToggle({Name = "🛡️ Smart Sell", CurrentValue = Config.SmartSell,
        Callback = function(v) Config.SmartSell = v end})
    
    Settings:CreateToggle({Name = "Skip Players", CurrentValue = Config.SkipPlayerCountries,
        Callback = function(v) Config.SkipPlayerCountries = v end})
    
    Settings:CreateToggle({Name = "Skip Producing", CurrentValue = Config.SkipProducingCountries,
        Callback = function(v) Config.SkipProducingCountries = v end})
    
    Settings:CreateToggle({Name = "Retry Queue", CurrentValue = Config.RetryEnabled,
        Callback = function(v) Config.RetryEnabled = v end})
    
    Settings:CreateToggle({Name = "🤖 Auto-Sell", CurrentValue = Config.AutoSellEnabled,
        Callback = function(v) Config.AutoSellEnabled = v; if v then AutoSell.start() else AutoSell.stop() end end})
    
    Settings:CreateSlider({Name = "Auto-Sell Threshold", Range = {1, 20}, Increment = 0.5, CurrentValue = Config.AutoSellThreshold,
        Callback = function(v) Config.AutoSellThreshold = v end})
    
    -- LOGS
    local Logs = Window:CreateTab("📜 Logs", 4483362458)
    M.Elements.LogParagraph = Logs:CreateParagraph({Title = "📋 Logs", Content = "Ready"})
    Logs:CreateButton({Name = "📋 Copy", Callback = function() if #M.Logs > 0 then setclipboard(table.concat(M.Logs, "\n")) end end})
    Logs:CreateButton({Name = "🗑️ Clear", Callback = function() M.Logs = {} M.updateLogs() end})
    
    -- INFO
    local Info = Window:CreateTab("ℹ️ Info", 4483362458)
    Info:CreateParagraph({Title = "Electronics Trade Hub v3", Content = "Modular Edition"})
    if Helpers.myCountryName then
        Info:CreateLabel("🏴 " .. Helpers.myCountryName)
    end
    
    M.log("═══ Trade Hub Ready ═══", "info")
    if Helpers.myCountryName then
        M.log(string.format("🏴 %s | Flow: %.2f", Helpers.myCountryName, Helpers.getMyFlow()), "info")
    end
    M.updateStats()
    
    return Window
end

return M
