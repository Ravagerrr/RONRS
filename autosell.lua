--[[
    AUTOSELL MODULE
    Auto-sell Monitor
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
    UI.log("🤖 Auto-Sell: ON", "info")
    
    task.spawn(function()
        while M.isMonitoring do
            -- Check if auto-sell is still enabled in config (check more frequently)
            if not Config.AutoSellEnabled then
                M.isMonitoring = false
                UI.log("🤖 Auto-Sell: OFF", "warning")
                break
            end
            
            UI.updateAutoSell()
            
            if not State.isRunning then
                local totalAvail = Helpers.getTotalAvailableFlow()
                
                if totalAvail >= Config.AutoSellThreshold then
                    -- Check again right before starting trade
                    if not Config.AutoSellEnabled then
                        M.isMonitoring = false
                        UI.log("🤖 Auto-Sell: OFF", "warning")
                        break
                    end
                    
                    local triggered = {}
                    for _, res in ipairs(Helpers.getEnabledResources()) do
                        local avail = Helpers.getAvailableFlow(res)
                        if avail >= Config.MinAmount then
                            local icon = res.name == "ConsumerGoods" and "🛒" or "⚡"
                            table.insert(triggered, string.format("%s%.1f", icon, avail))
                        end
                    end
                    
                    UI.log(string.format("🤖 TRIGGERED: %s", table.concat(triggered, " ")), "success")
                    M.triggers = M.triggers + 1
                    
                    task.spawn(Trading.run)
                    
                    while State.isRunning do 
                        -- Check auto-sell state even while trade is running
                        if not Config.AutoSellEnabled then
                            Trading.stop()  -- Use Trading module's stop function
                            M.isMonitoring = false
                            UI.log("🤖 Auto-Sell disabled - stopping trade", "warning")
                            break
                        end
                        task.wait(0.5) 
                    end
                end
            end
            
            task.wait(Config.AutoSellCheckInterval)
        end
        
        UI.log("🤖 Auto-Sell: OFF", "warning")
        UI.updateAutoSell()
    end)
end

function M.stop()
    M.isMonitoring = false
    -- Also stop any running trade
    State.isRunning = false
    UI.updateAutoSell()
end

return M
