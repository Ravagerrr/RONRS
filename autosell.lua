--[[
    AUTOSELL MODULE
    Monitors flow and triggers trades when threshold reached
]]

local M = {}
local Config, State, Helpers, UI, Trading

M.isMonitoring = false

function M.init(cfg, state, helpers, ui, trading)
    Config = cfg
    State = state
    Helpers = helpers
    UI = ui
    Trading = trading
end

function M.start()
    if M.isMonitoring then return end
    M.isMonitoring = true
    
    UI.log("[*] Auto-Sell: STARTED", "info")
    
    task.spawn(function()
        while M.isMonitoring do
            task.wait(5)
            
            if State.isRunning then
                -- Don't interfere with active trading
                continue
            end
            
            local availableFlow = Helpers.getAvailableFlow()
            
            if availableFlow >= Config.AutoSellThreshold then
                UI.log(string.format("[*] Auto-Sell: Triggered (%.2f available)", availableFlow), "info")
                Trading.run()
            end
        end
    end)
end

function M.stop()
    M.isMonitoring = false
    UI.log("[*] Auto-Sell: STOPPED", "info")
end

return M
