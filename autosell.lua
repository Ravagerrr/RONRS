--[[
    AUTOSELL MODULE
    Multi-Resource Auto-sell Monitor
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
    UI.log("🤖 Auto-Sell: STARTED (Multi-Resource)", "info")
    
    task.spawn(function()
        while M.isMonitoring and Config.AutoSellEnabled do
            UI.updateAutoSell()
            
            if not State.isRunning then
                -- Check total available flow across all enabled resources
                local totalAvail = Helpers.getTotalAvailableFlow()
                
                if totalAvail >= Config.AutoSellThreshold then
                    -- Log which resources triggered
                    local triggered = {}
                    for _, res in ipairs(Helpers.getEnabledResources()) do
                        local avail = Helpers.getAvailableFlow(res)
                        if avail >= Config.MinAmount then
                            local icon = res.name == "ConsumerGoods" and "🛒" or "⚡"
                            table.insert(triggered, string.format("%s%.2f", icon, avail))
                        end
                    end
                    
                    UI.log(string.format("🤖 TRIGGERED: %s (Total: %.2f)", 
                        table.concat(triggered, " "), totalAvail), "success")
                    
                    M.triggers = M.triggers + 1
                    task.spawn(Trading.run)
                    
                    -- Wait for trading to finish
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
