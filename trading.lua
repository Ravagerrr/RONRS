--[[
    TRADING MODULE
    Core trading logic
]]

local M = {}
local Config, State, Helpers, UI

local ManageAlliance = workspace:WaitForChild("GameManager"):WaitForChild("ManageAlliance")

function M.init(cfg, state, helpers, ui)
    Config = cfg
    State = state
    Helpers = helpers
    UI = ui
end

local function attemptTrade(country, amount, price)
    local before = Helpers.getTradeCount(country)
    pcall(function()
        ManageAlliance:FireServer(country.Name, "ResourceTrade", {"Electronics", "Sell", amount, price, "Trade"})
    end)
    task.wait(Config.WaitTime)
    return Helpers.getTradeCount(country) > before
end

function M.processCountry(country, i, total, buyers, isRetry)
    local name = country.Name
    local prefix = isRetry and "🔄" or ""
    
    -- Flow check
    local avail = Helpers.getAvailableFlow()
    if Config.SmartSell and avail < Config.MinAmount then
        State.Stats.FlowProtected = State.Stats.FlowProtected + 1
        UI.log(string.format("[%d/%d] 🛡️ FLOW STOP", i, total), "warning")
        return false, false, "Flow Protection"
    end
    
    -- Skip checks
    if Config.SkipOwnCountry and country == Helpers.myCountry then return false, false, "Own" end
    if Config.SkipExistingBuyers and buyers[name] then return false, false, "Buyer" end
    if Helpers.isPlayerCountry(name) then return false, false, "Player" end
    
    local data = Helpers.getCountryData(country)
    if not data.valid then return false, false, "Invalid" end
    if data.revenue <= 0 or data.balance <= 0 then return false, false, "No Revenue" end
    if data.hasSell then return false, false, "Already Selling" end
    if Config.SkipProducingCountries and data.flow > 0 then return false, false, "Producing" end
    
    -- Calculate amount
    local affordable = math.min(Config.MaxAmount, data.revenue / Config.BuyPrice)
    if affordable < Config.MinAmount then return false, false, "Insufficient" end
    local remaining = affordable - data.buyAmount
    if remaining < Config.MinAmount then return false, false, "Max Capacity" end
    
    -- Cap to flow
    avail = Helpers.getAvailableFlow()
    local amount = math.min(remaining, avail)
    if amount < Config.MinAmount then
        State.Stats.FlowProtected = State.Stats.FlowProtected + 1
        return false, false, "Flow Protection"
    end
    
    -- Get price
    local price = Helpers.getPriceTier(data.revenue)
    if isRetry and State.countryRetryState[name] then
        price = Helpers.getNextPriceTier(State.countryRetryState[name])
        if not price then return false, false, "No Buyers" end
    end
    State.countryRetryState[name] = price
    
    UI.log(string.format("[%d/%d] %s🔄 %s | %.2f @ %.1fx", i, total, prefix, name, amount, price), "info")
    
    if attemptTrade(country, amount, price) then
        UI.log(string.format("[%d/%d] %s✓ %s", i, total, prefix, name), "success")
        return true, false, nil
    else
        local next = Helpers.getNextPriceTier(price)
        if Config.RetryEnabled and next and not isRetry then
            return false, true, "Queued"
        end
        UI.log(string.format("[%d/%d] %s✗ %s", i, total, prefix, name), "error")
        return false, false, "No Buyers"
    end
end

function M.run()
    if State.isRunning then return end
    State.isRunning = true
    State.isPaused = false
    State.retryQueue = {}
    State.countryRetryState = {}
    State.Stats = {Success = 0, Skipped = 0, Failed = 0, FlowProtected = 0}
    
    local startTime = tick()
    local initFlow = Helpers.getMyFlow()
    
    UI.log("═══ Trade Run Started ═══", "info")
    UI.log(string.format("Flow: %.2f | Avail: %.2f", initFlow, Helpers.getAvailableFlow()), "info")
    
    local countries = Helpers.getCountries()
    local buyers = Helpers.getMyBuyers()
    Helpers.refreshPlayerCache()
    
    local flowStop = false
    
    -- Main pass
    for i, country in ipairs(countries) do
        if not State.isRunning then break end
        while State.isPaused do task.wait(0.5) end
        if Config.SmartSell and Helpers.getAvailableFlow() < Config.MinAmount then
            UI.log("🛡️ No more flow", "warning")
            flowStop = true
            break
        end
        
        UI.updateProgress(i, #countries)
        
        local ok, err = pcall(function()
            local success, retry, reason = M.processCountry(country, i, #countries, buyers, false)
            if success then State.Stats.Success = State.Stats.Success + 1
            elseif retry then table.insert(State.retryQueue, country)
            else State.Stats.Skipped = State.Stats.Skipped + 1 end
            if reason == "Flow Protection" then flowStop = true end
            UI.updateStats()
        end)
        
        if not ok then State.Stats.Failed = State.Stats.Failed + 1 end
        if flowStop then break end
    end
    
    -- Retry pass
    if Config.RetryEnabled and #State.retryQueue > 0 and not flowStop then
        UI.log(string.format("🔄 RETRY: %d", #State.retryQueue), "info")
        
        for pass = 1, Config.MaxRetryPasses do
            if #State.retryQueue == 0 or Helpers.getAvailableFlow() < Config.MinAmount then break end
            
            local queue = State.retryQueue
            State.retryQueue = {}
            
            for i, country in ipairs(queue) do
                if not State.isRunning or Helpers.getAvailableFlow() < Config.MinAmount then break end
                
                pcall(function()
                    local success, retry = M.processCountry(country, i, #queue, buyers, true)
                    if success then State.Stats.Success = State.Stats.Success + 1
                    elseif retry and pass < Config.MaxRetryPasses then table.insert(State.retryQueue, country)
                    else State.Stats.Failed = State.Stats.Failed + 1 end
                    UI.updateStats()
                end)
            end
        end
    end
    
    -- Summary
    local elapsed = tick() - startTime
    UI.log("═══ Complete ═══", "info")
    UI.log(string.format("%.1fs | ✓%d ⊘%d ✗%d 🛡️%d", elapsed, State.Stats.Success, State.Stats.Skipped, State.Stats.Failed, State.Stats.FlowProtected), "info")
    UI.log(string.format("Flow: %.2f → %.2f", initFlow, Helpers.getMyFlow()), "info")
    
    State.isRunning = false
    UI.updateStats()
end

return M
