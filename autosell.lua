--[[
    AUTOSELL MODULE
    Auto-sell monitor
]]

local M = {}
local Config, State, Helpers, Trading, UI

M.isMonitoring = false
M.triggers = 0

function M.init(cfg, state, helpers, trading, ui)
    Config = cfg
    State = state
    Helpers = helpers
    Trading = trading
    UI = ui
end

function M.start()
    if M.isMonitoring then return end
    M.isMonitoring = true
    UI.log("🤖 Auto-Sell: STARTED", "info")
    
    task.spawn(function()
        while M.isMonitoring and Config.AutoSellEnabled do
            UI.updateAutoSell()
            
            if not State.isRunning then
                local avail = Helpers.getAvailableFlow()
                if avail > Config.AutoSellThreshold then
                    UI.log(string.format("🤖 TRIGGERED: %.2f > %.2f", avail, Config.AutoSellThreshold), "success")
                    M.triggers = M.triggers + 1
                    task.spawn(Trading.run)
                    while State.isRunning do task.wait(1) end
                end
            end
            
            task.wait(Config.AutoSellCheckInterval)
        end
        UI.log("🤖 Auto-Sell: STOPPED", "warning")
        UI.updateAutoSell()
    end)
end

function M.stop()
    M.isMonitoring = false
    UI.updateAutoSell()
end

return M
