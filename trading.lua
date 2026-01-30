--[[
    TRADING MODULE
    Multi-Resource with Priority System
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

-- Attempt single trade
local function attemptTrade(country, resource, amount, price)
    local before = Helpers.getTradeCount(country, resource.gameName)
    
    pcall(function()
        ManageAlliance:FireServer(country.Name, "ResourceTrade", {resource.gameName, "Sell", amount, price, "Trade"})
    end)
    
    task.wait(Config.WaitTime)
    return Helpers.getTradeCount(country, resource.gameName) > before
end

-- Process a single country for a specific resource
function M.processCountryResource(country, resource, i, total, buyers, retryState)
    local name = country.Name
    local resName = resource.name
    local isRetry = retryState and retryState[resName]
    local prefix = isRetry and "🔄" or ""
    local icon = resName == "ConsumerGoods" and "🛒" or "⚡"
    
    -- Flow check for this resource
    local avail = Helpers.getAvailableFlow(resource)
    if Config.SmartSell and avail < Config.MinAmount then
        return false, false, "No Flow"
    end
    
    -- Skip checks
    if Config.SkipOwnCountry and country == Helpers.myCountry then return false, false, "Own" end
    if Helpers.isPlayerCountry(name) then return false, false, "Player" end
    
    -- Check if already buying this resource from us
    local resourceBuyers = buyers[resName] or {}
    if Config.SkipExistingBuyers and resourceBuyers[name] then return false, false, "Buyer" end
    
    -- Get country data for this resource
    local data = Helpers.getCountryResourceData(country, resource)
    if not data.valid then return false, false, "Invalid" end
    if data.revenue <= 0 or data.balance <= 0 then return false, false, "No Revenue" end
    if data.hasSell then return false, false, "Already Selling" end
    if Config.SkipProducingCountries and data.flow > 0 then return false, false, "Producing" end
    
    -- Calculate amount based on resource-specific rules
    -- Use the resource's maxAmount (999 for CG = effectively unlimited, 5 for Electronics)
    local maxForResource = resource.maxAmount or 999
    local affordable = math.min(maxForResource, data.revenue / resource.buyPrice)
    
    if affordable < Config.MinAmount then return false, false, "Insufficient" end
    
    -- Subtract what they're already buying
    local remaining = affordable - data.buyAmount
    if remaining < Config.MinAmount then return false, false, "Max Capacity" end
    
    -- Cap to available flow
    local amount = math.min(remaining, avail)
    if amount < Config.MinAmount then return false, false, "Flow Protection" end
    
    -- Get price tier
    local price = Helpers.getPriceTier(data.revenue)
    
    -- If retry, use lower price
    if isRetry and retryState[resName .. "_price"] then
        price = Helpers.getNextPriceTier(retryState[resName .. "_price"])
        if not price then return false, false, "No Buyers" end
    end
    
    -- Store price for potential retry
    if not retryState then retryState = {} end
    retryState[resName .. "_price"] = price
    
    UI.log(string.format("[%d/%d] %s%s %s | %.2f @ %.1fx", i, total, prefix, icon, name, amount, price), "info")
    
    if attemptTrade(country, resource, amount, price) then
        UI.log(string.format("[%d/%d] %s✓ %s %s", i, total, icon, name, resource.gameName), "success")
        return true, false, nil
    else
        -- Check if we can retry with lower price
        local nextPrice = Helpers.getNextPriceTier(price)
        if Config.RetryEnabled and nextPrice and not isRetry then
            return false, true, "Queued"
        end
        return false, false, "No Buyers"
    end
end

-- Main trading run
function M.run()
    if State.isRunning then return end
    State.isRunning = true
    State.isPaused = false
    State.retryQueue = {}
    State.Stats = {
        Success = 0, 
        Skipped = 0, 
        Failed = 0, 
        FlowProtected = 0,
        ByResource = {}
    }
    
    -- Initialize per-resource stats
    for _, res in ipairs(Helpers.getEnabledResources()) do
        State.Stats.ByResource[res.name] = {Success = 0, Skipped = 0, Failed = 0}
    end
    
    local startTime = tick()
    local enabledResources = Helpers.getEnabledResources()
    
    -- Log initial state
    UI.log("═══ Multi-Resource Trade Started ═══", "info")
    for _, res in ipairs(enabledResources) do
        local icon = res.name == "ConsumerGoods" and "🛒" or "⚡"
        local capInfo = res.maxAmount >= 999 and "No Cap" or string.format("Max %d", res.maxAmount)
        UI.log(string.format("%s %s: Flow %.2f | Avail %.2f | %s", 
            icon, res.gameName, Helpers.getFlow(res), Helpers.getAvailableFlow(res), capInfo), "info")
    end
    
    local countries = Helpers.getCountries()
    local allBuyers = Helpers.getAllBuyers()
    Helpers.refreshPlayerCache()
    
    local totalCountries = #countries
    
    -- Main pass: For each country, try all resources in priority order
    for i, country in ipairs(countries) do
        if not State.isRunning then break end
        while State.isPaused do task.wait(0.5) end
        
        UI.updateProgress(i, totalCountries)
        
        local countryRetryState = {}
        local tradedThisCountry = false
        
        -- Try each resource in priority order
        for _, resource in ipairs(enabledResources) do
            if not State.isRunning then break end
            
            -- Check if we have flow for this resource
            local avail = Helpers.getAvailableFlow(resource)
            if avail < Config.MinAmount then
                continue
            end
            
            local ok, err = pcall(function()
                local success, retry, reason = M.processCountryResource(
                    country, resource, i, totalCountries, allBuyers, countryRetryState
                )
                
                if success then
                    State.Stats.Success = State.Stats.Success + 1
                    State.Stats.ByResource[resource.name].Success = State.Stats.ByResource[resource.name].Success + 1
                    tradedThisCountry = true
                    
                    -- Update buyers cache
                    if not allBuyers[resource.name] then allBuyers[resource.name] = {} end
                    allBuyers[resource.name][country.Name] = true
                    
                elseif retry then
                    table.insert(State.retryQueue, {
                        country = country,
                        resource = resource,
                        retryState = countryRetryState
                    })
                else
                    State.Stats.Skipped = State.Stats.Skipped + 1
                    State.Stats.ByResource[resource.name].Skipped = State.Stats.ByResource[resource.name].Skipped + 1
                end
                
                UI.updateStats()
            end)
            
            if not ok then
                State.Stats.Failed = State.Stats.Failed + 1
                warn("[Trading] Error: " .. tostring(err))
            end
            
            -- Delay between resource attempts
            if tradedThisCountry then
                task.wait(Config.ResourceDelay)
            end
        end
    end
    
    -- Retry pass
    if Config.RetryEnabled and #State.retryQueue > 0 then
        UI.log(string.format("🔄 RETRY QUEUE: %d items", #State.retryQueue), "info")
        
        for pass = 1, Config.MaxRetryPasses do
            if #State.retryQueue == 0 then break end
            if not State.isRunning then break end
            
            UI.log(string.format("🔄 Retry Pass %d/%d", pass, Config.MaxRetryPasses), "info")
            
            local queue = State.retryQueue
            State.retryQueue = {}
            
            for idx, item in ipairs(queue) do
                if not State.isRunning then break end
                
                local avail = Helpers.getAvailableFlow(item.resource)
                if avail < Config.MinAmount then
                    if pass < Config.MaxRetryPasses then
                        table.insert(State.retryQueue, item)
                    end
                    continue
                end
                
                item.retryState[item.resource.name] = true
                
                local ok, err = pcall(function()
                    local success, retry, reason = M.processCountryResource(
                        item.country, item.resource, idx, #queue, allBuyers, item.retryState
                    )
                    
                    if success then
                        State.Stats.Success = State.Stats.Success + 1
                        State.Stats.ByResource[item.resource.name].Success = 
                            State.Stats.ByResource[item.resource.name].Success + 1
                    elseif retry and pass < Config.MaxRetryPasses then
                        table.insert(State.retryQueue, item)
                    else
                        State.Stats.Failed = State.Stats.Failed + 1
                        State.Stats.ByResource[item.resource.name].Failed = 
                            State.Stats.ByResource[item.resource.name].Failed + 1
                    end
                    
                    UI.updateStats()
                end)
                
                if not ok then
                    State.Stats.Failed = State.Stats.Failed + 1
                end
            end
        end
    end
    
    -- Summary
    local elapsed = tick() - startTime
    UI.log("═══ Complete ═══", "info")
    UI.log(string.format("⏱️ %.1fs | ✓%d ⊘%d ✗%d", 
        elapsed, State.Stats.Success, State.Stats.Skipped, State.Stats.Failed), "info")
    
    for _, res in ipairs(enabledResources) do
        local stats = State.Stats.ByResource[res.name]
        local icon = res.name == "ConsumerGoods" and "🛒" or "⚡"
        UI.log(string.format("%s %s: ✓%d ⊘%d | Flow: %.2f", 
            icon, res.gameName, stats.Success, stats.Skipped, Helpers.getFlow(res)), "info")
    end
    
    State.isRunning = false
    UI.updateStats()
end

return M
