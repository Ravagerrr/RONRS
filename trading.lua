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

local function attemptTrade(country, resource, amount, price)
    local before = Helpers.getTradeCount(country, resource.gameName)
    
    pcall(function()
        ManageAlliance:FireServer(country.Name, "ResourceTrade", {resource.gameName, "Sell", amount, price, "Trade"})
    end)
    
    task.wait(Config.WaitTime)
    return Helpers.getTradeCount(country, resource.gameName) > before
end

function M.processCountryResource(country, resource, i, total, buyers, retryState)
    -- STOP CHECK
    if not State.isRunning then return false, false, "Stopped" end
    
    -- Check if resource is still enabled
    if not resource.enabled then return false, false, "Disabled" end
    
    local name = country.Name
    local resName = resource.name
    local isRetry = retryState and retryState[resName]
    local prefix = isRetry and "🔄" or ""
    local icon = resName == "ConsumerGoods" and "🛒" or "⚡"
    
    -- Flow check
    local avail = Helpers.getAvailableFlow(resource)
    if Config.SmartSell and avail < Config.MinAmount then
        return false, false, "No Flow"
    end
    
    -- Skip checks
    if Config.SkipOwnCountry and country == Helpers.myCountry then return false, false, "Own" end
    if Helpers.isPlayerCountry(name) then return false, false, "Player" end
    
    local resourceBuyers = buyers[resName] or {}
    if Config.SkipExistingBuyers and resourceBuyers[name] then return false, false, "Buyer" end
    
    local data = Helpers.getCountryResourceData(country, resource)
    if not data.valid then return false, false, "Invalid" end
    if data.revenue <= 0 or data.balance <= 0 then return false, false, "No Revenue" end
    if data.hasSell then return false, false, "Already Selling" end
    if Config.SkipProducingCountries and data.flow > 0 then return false, false, "Producing" end
    
    -- Calculate amount - DIFFERENT LOGIC FOR CAPPED VS UNCAPPED
    local affordable
    if resource.hasCap then
        -- Electronics: cap at capAmount (5)
        affordable = math.min(resource.capAmount, data.revenue / resource.buyPrice)
    else
        -- Consumer Goods: NO CAP, only limited by revenue
        affordable = data.revenue / resource.buyPrice
    end
    
    if affordable < Config.MinAmount then return false, false, "Insufficient" end
    
    local remaining = affordable - data.buyAmount
    if remaining < Config.MinAmount then return false, false, "Max Capacity" end
    
    -- Cap to available flow
    local amount = math.min(remaining, avail)
    if amount < Config.MinAmount then return false, false, "Flow Protection" end
    
    -- Price tier
    local price = Helpers.getPriceTier(data.revenue)
    
    if isRetry and retryState[resName .. "_price"] then
        price = Helpers.getNextPriceTier(retryState[resName .. "_price"])
        if not price then return false, false, "No Buyers" end
    end
    
    if not retryState then retryState = {} end
    retryState[resName .. "_price"] = price
    
    UI.log(string.format("[%d/%d] %s%s %s | %.2f @ %.1fx", i, total, prefix, icon, name, amount, price), "info")
    
    if attemptTrade(country, resource, amount, price) then
        UI.log(string.format("[%d/%d] %s✓ %s", i, total, icon, name), "success")
        return true, false, nil
    else
        local nextPrice = Helpers.getNextPriceTier(price)
        if Config.RetryEnabled and nextPrice and not isRetry then
            return false, true, "Queued"
        end
        return false, false, "No Buyers"
    end
end

function M.run()
    if State.isRunning then return end
    State.isRunning = true
    State.retryQueue = {}
    State.Stats = {
        Success = 0, 
        Skipped = 0, 
        Failed = 0, 
        ByResource = {}
    }
    
    for _, res in ipairs(Helpers.getEnabledResources()) do
        State.Stats.ByResource[res.name] = {Success = 0, Skipped = 0, Failed = 0}
    end
    
    local startTime = tick()
    
    UI.log("═══ Trade Started ═══", "info")
    for _, res in ipairs(Helpers.getEnabledResources()) do
        local icon = res.name == "ConsumerGoods" and "🛒" or "⚡"
        local capInfo = res.hasCap and string.format("Cap: %d", res.capAmount) or "No Cap"
        UI.log(string.format("%s %s: %.2f avail | %s", icon, res.gameName, Helpers.getAvailableFlow(res), capInfo), "info")
    end
    
    local countries = Helpers.getCountries()
    local allBuyers = Helpers.getAllBuyers()
    Helpers.refreshPlayerCache()
    
    local totalCountries = #countries
    
    -- Main pass
    for i, country in ipairs(countries) do
        -- STOP CHECK - exits immediately
        if not State.isRunning then 
            UI.log("⛔ STOPPED by user", "warning")
            break 
        end
        
        UI.updateProgress(i, totalCountries)
        
        local countryRetryState = {}
        local tradedThisCountry = false
        
        -- Get fresh list of enabled resources each iteration
        local enabledResources = Helpers.getEnabledResources()
        
        for _, resource in ipairs(enabledResources) do
            -- STOP CHECK
            if not State.isRunning then break end
            
            -- Check resource still enabled
            if not resource.enabled then continue end
            
            local avail = Helpers.getAvailableFlow(resource)
            if avail < Config.MinAmount then continue end
            
            local ok, err = pcall(function()
                local success, retry, reason = M.processCountryResource(
                    country, resource, i, totalCountries, allBuyers, countryRetryState
                )
                
                if success then
                    State.Stats.Success = State.Stats.Success + 1
                    State.Stats.ByResource[resource.name].Success = State.Stats.ByResource[resource.name].Success + 1
                    tradedThisCountry = true
                    
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
            end
            
            if tradedThisCountry then
                task.wait(Config.ResourceDelay)
            end
        end
    end
    
    -- Retry pass
    if Config.RetryEnabled and #State.retryQueue > 0 and State.isRunning then
        UI.log(string.format("🔄 RETRY: %d", #State.retryQueue), "info")
        
        for pass = 1, Config.MaxRetryPasses do
            if #State.retryQueue == 0 or not State.isRunning then break end
            
            local queue = State.retryQueue
            State.retryQueue = {}
            
            for idx, item in ipairs(queue) do
                if not State.isRunning then break end
                if not item.resource.enabled then continue end
                
                local avail = Helpers.getAvailableFlow(item.resource)
                if avail < Config.MinAmount then
                    if pass < Config.MaxRetryPasses then
                        table.insert(State.retryQueue, item)
                    end
                    continue
                end
                
                item.retryState[item.resource.name] = true
                
                local ok = pcall(function()
                    local success, retry = M.processCountryResource(
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
                    end
                    
                    UI.updateStats()
                end)
                
                if not ok then State.Stats.Failed = State.Stats.Failed + 1 end
            end
        end
    end
    
    -- Summary
    local elapsed = tick() - startTime
    UI.log("═══ Complete ═══", "info")
    UI.log(string.format("%.1fs | ✓%d ⊘%d ✗%d",
