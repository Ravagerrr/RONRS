--[[
    TRADING MODULE
    Core trade logic and retry system
]]

local M = {}
local Config, State, Helpers, UI

function M.init(cfg, state, helpers, ui)
    Config = cfg
    State = state
    Helpers = helpers
    UI = ui
end

function M.attemptTrade(country, amount)
    local priceTiers = Helpers.getPriceTiers(country)
    local beforePartners = Helpers.getTradingPartners(country)
    
    for attempt, price in ipairs(priceTiers) do
        local args = {
            country.Name,
            "ResourceTrade",
            {"Electronics", "Sell", amount, price, "Trade"}
        }
        
        local ok, err = pcall(function()
            State.ManageAlliance:FireServer(unpack(args))
        end)
        
        if not ok then
            return false, "FireServer error"
        end
        
        task.wait(Config.WaitTime)
        
        local afterPartners = Helpers.getTradingPartners(country)
        if #afterPartners > #beforePartners then
            return true, price
        end
        
        if attempt < #priceTiers then
            UI.log(string.format("  Retry %s @ %.1fx", country.Name, priceTiers[attempt + 1]), "warning")
            task.wait(0.5)
        end
    end
    
    return false, "No buyers"
end

function M.processCountry(country, index, total)
    -- Skip own country
    if Config.SkipOwnCountry and country.Name == Helpers.myCountryName then
        State.Stats.Skipped = State.Stats.Skipped + 1
        return "skip", "Own country"
    end
    
    -- Skip existing buyers
    local myBuyers = Helpers.getMyBuyers()
    if Config.SkipExistingBuyers and myBuyers[country.Name] then
        State.Stats.Skipped = State.Stats.Skipped + 1
        return "skip", "Already buyer"
    end
    
    -- Check can trade
    local canTrade, reason = Helpers.canTrade(country)
    if not canTrade then
        State.Stats.Skipped = State.Stats.Skipped + 1
        return "skip", reason
    end
    
    -- Skip player countries
    if Config.SkipPlayerCountries and Helpers.isPlayerCountry(country) then
        State.Stats.Skipped = State.Stats.Skipped + 1
        return "skip", "Player owned"
    end
    
    -- Skip producing countries
    local flow = Helpers.getCountryFlow(country)
    if Config.SkipProducingCountries and flow > 0 then
        State.Stats.Skipped = State.Stats.Skipped + 1
        return "skip", "Producing"
    end
    
    -- Calculate amount
    local revenue = Helpers.getRevenue(country)
    local affordable = math.min(Config.MaxAmount, revenue / Config.BuyPrice)
    
    if affordable < Config.MinAmount then
        State.Stats.Skipped = State.Stats.Skipped + 1
        return "skip", "Can't afford"
    end
    
    -- Check available flow BEFORE trading
    local availableFlow = Helpers.getAvailableFlow()
    if Config.SmartSell and availableFlow < Config.MinAmount then
        State.Stats.Skipped = State.Stats.Skipped + 1
        return "skip", "No available flow"
    end
    
    -- Limit trade to available flow
    local tradeAmount = math.min(affordable, availableFlow)
    if tradeAmount < Config.MinAmount then
        State.Stats.Skipped = State.Stats.Skipped + 1
        return "skip", "Trade too small"
    end
    
    -- Attempt trade
    UI.log(string.format("[%d/%d] TRY %s (%.2f)", index, total, country.Name, tradeAmount), "info")
    
    local success, result = M.attemptTrade(country, tradeAmount)
    
    if success then
        State.Stats.Success = State.Stats.Success + 1
        UI.log(string.format("[%d/%d] OK %s @ %.1fx", index, total, country.Name, result), "success")
        return "success"
    else
        -- Add to retry queue
        if Config.RetryEnabled then
            table.insert(State.retryQueue, {country = country, amount = tradeAmount, attempts = 1})
            State.Stats.Failed = State.Stats.Failed + 1
            return "queued", result
        else
            State.Stats.Failed = State.Stats.Failed + 1
            return "fail", result
        end
    end
end

function M.processRetryQueue()
    if #State.retryQueue == 0 then return end
    
    UI.log(string.format("--- Retry Queue: %d countries ---", #State.retryQueue), "info")
    
    local newQueue = {}
    
    for i, item in ipairs(State.retryQueue) do
        if not State.isRunning then break end
        while State.isPaused do task.wait(0.5) end
        
        -- Check flow before retry
        local availableFlow = Helpers.getAvailableFlow()
        if Config.SmartSell and availableFlow < Config.MinAmount then
            UI.log("Retry paused - no flow", "warning")
            table.insert(newQueue, item)
            continue
        end
        
        local tradeAmount = math.min(item.amount, availableFlow)
        local success, result = M.attemptTrade(item.country, tradeAmount)
        
        if success then
            State.Stats.Success = State.Stats.Success + 1
            State.Stats.Failed = State.Stats.Failed - 1
            UI.log(string.format("RETRY OK %s", item.country.Name), "success")
        else
            item.attempts = item.attempts + 1
            if item.attempts < Config.MaxRetryPasses then
                table.insert(newQueue, item)
            else
                UI.log(string.format("RETRY FAIL %s (max attempts)", item.country.Name), "error")
            end
        end
        
        UI.updateStats()
        task.wait(0.5)
    end
    
    State.retryQueue = newQueue
end

function M.run()
    if State.isRunning then
        UI.log("Already running!", "warning")
        return
    end
    
    State.isRunning = true
    State.isPaused = false
    State.Stats = {Success = 0, Skipped = 0, Failed = 0}
    State.retryQueue = {}
    
    local startTime = tick()
    
    UI.log("=== Trade Run Started ===", "info")
    UI.log(string.format("Flow: %.2f | Avail: %.2f", Helpers.getMyFlow(), Helpers.getAvailableFlow()), "info")
    
    -- Check if we have any flow to sell
    local availableFlow = Helpers.getAvailableFlow()
    if availableFlow <= 0 then
        UI.log("[!] No more flow", "warning")
        UI.log("=== Complete ===", "info")
        State.isRunning = false
        return
    end
    
    local countries = Helpers.getSortedCountries()
    local total = #countries
    
    UI.log(string.format("Processing %d countries...", total), "info")
    
    for i, country in ipairs(countries) do
        if not State.isRunning then break end
        while State.isPaused do task.wait(0.5) end
        
        -- Re-check available flow each iteration
        availableFlow = Helpers.getAvailableFlow()
        if Config.SmartSell and availableFlow < Config.MinAmount then
            UI.log(string.format("[!] Flow depleted at %d/%d", i, total), "warning")
            break
        end
        
        UI.updateProgress(i, total)
        
        local result, reason = M.processCountry(country, i, total)
        
        if result == "skip" then
            -- Silent skip, don't spam logs
        elseif result == "queued" then
            UI.log(string.format("  -> Queued for retry (%s)", reason), "warning")
        end
        
        UI.updateStats()
    end
    
    -- Process retry queue
    for pass = 1, Config.MaxRetryPasses do
        if #State.retryQueue == 0 then break end
        if not State.isRunning then break end
        
        UI.log(string.format("--- Retry Pass %d ---", pass), "info")
        M.processRetryQueue()
    end
    
    local elapsed = tick() - startTime
    
    UI.log("=== Complete ===", "info")
    UI.log(string.format("%.1fs | +%d -%d x%d Q%d", 
        elapsed, 
        State.Stats.Success, 
        State.Stats.Skipped, 
        State.Stats.Failed,
        #State.retryQueue), "info")
    UI.log(string.format("Flow: %.2f -> %.2f", Helpers.getMyFlow(), Helpers.getAvailableFlow()), "info")
    
    State.isRunning = false
    UI.updateStats()
end

return M
