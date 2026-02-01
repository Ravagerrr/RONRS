--[[
    TRADING MODULE
    Multi-Resource with Priority System
    FIXED: Trade verification uses retry polling for reliable detection
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
    -- Check our trade folder for existing sales to this country BEFORE the trade
    local beforeAmount = Helpers.getSellingAmountTo(resource.gameName, country.Name)
    
    pcall(function()
        ManageAlliance:FireServer(country.Name, "ResourceTrade", {resource.gameName, "Sell", amount, price, "Trade"})
    end)
    
    -- Poll multiple times to verify trade was registered (server may take time to update)
    local maxAttempts = 5
    local pollInterval = 0.2
    
    for attempt = 1, maxAttempts do
        task.wait(pollInterval)
        
        local afterAmount = Helpers.getSellingAmountTo(resource.gameName, country.Name)
        if afterAmount > beforeAmount then
            return true
        end
    end
    
    -- Trade not verified after all attempts
    return false
end

function M.processCountryResource(country, resource, i, total, buyers, retryState)
    if not State.isRunning then return false, false, "Stopped" end
    
    local name = country.Name
    local resName = resource.name
    
    -- ALWAYS check Config directly for the latest enabled state
    local configResource = Helpers.getResourceByName(resName)
    if not configResource or not configResource.enabled then return false, false, "Disabled" end
    local isRetry = retryState and retryState[resName]
    
    local avail = Helpers.getAvailableFlow(resource)
    if Config.SmartSell and avail < Config.MinAmount then
        return false, false, "No Flow"
    end
    
    if Config.SkipOwnCountry and country == Helpers.myCountry then return false, false, "Own" end
    if Helpers.isPlayerCountry(name) then return false, false, "Player" end
    
    local resourceBuyers = buyers[resName] or {}
    if Config.SkipExistingBuyers and resourceBuyers[name] then return false, false, "Buyer" end
    
    local data = Helpers.getCountryResourceData(country, resource)
    if not data.valid then return false, false, "Invalid" end
    if data.revenue <= 0 or data.balance <= 0 then return false, false, "No Revenue" end
    if data.hasSell then return false, false, "Already Selling" end
    if Config.SkipProducingCountries and data.flow > 0 then return false, false, "Producing" end
    
    -- Skip countries with no meaningful demand (flow >= MinDemandFlow threshold)
    -- Countries need actual negative flow (consumption) to want to buy resources
    -- This prevents attempting trades to countries with zero or near-zero flow
    if data.flow >= (Config.MinDemandFlow or 0) then return false, false, "No Demand" end
    
    -- Get optimal price tier based on what country can afford (smart pricing)
    local price = Helpers.getPriceTier(data.revenue, resource, data)
    
    -- If smart pricing returned nil, country can't afford at any tier
    if not price then return false, false, "Cannot Afford" end
    
    if isRetry and retryState[resName .. "_price"] then
        price = Helpers.getNextPriceTier(retryState[resName .. "_price"])
        if not price then return false, false, "No Buyers" end
    end
    
    -- Calculate ACTUAL price per unit at this tier
    local actualPricePerUnit = resource.buyPrice * price
    
    -- Safety check for division by zero
    if actualPricePerUnit <= 0 then
        return false, false, "Invalid Price"
    end
    
    -- Calculate affordable based on ACTUAL price they pay
    -- Apply revenue spending limit to prevent rejection (countries won't spend 100% of revenue)
    local maxAffordable = (data.revenue * Config.MaxRevenueSpendingPercent) / actualPricePerUnit
    
    local affordable
    if resource.hasCap then
        -- Electronics: cap at capAmount (5), but also check what they can afford at this price
        affordable = math.min(resource.capAmount, maxAffordable)
    else
        -- Consumer Goods: Limited by negative flow (demand) AND what they can afford
        -- If country has negative flow (consuming), that's their max demand
        -- Use absolute value of flow as the max they want to buy
        if data.flow < 0 then
            local maxDemand = math.abs(data.flow)
            affordable = math.min(maxAffordable, maxDemand)
        else
            -- If flow is positive or zero, just use what they can afford
            affordable = maxAffordable
        end
    end
    
    if affordable < Config.MinAmount then return false, false, "Insufficient" end
    
    -- Subtract what they're already buying
    local remaining = affordable - data.buyAmount
    if remaining < Config.MinAmount then return false, false, "Max Capacity" end
    
    -- Cap to available flow
    local amount = math.min(remaining, avail)
    if amount < Config.MinAmount then return false, false, "Flow Protection" end
    
    if not retryState then retryState = {} end
    retryState[resName .. "_price"] = price
    
    local totalCost = amount * actualPricePerUnit
    UI.log(string.format("[%d/%d] %s %s | %.2f @ %.1fx ($%.0f/u) | Flow:%.2f Rev:$%.0f Cost:$%.0f", 
        i, total, resource.gameName, name, amount, price, actualPricePerUnit, data.flow, data.revenue, totalCost), "info")
    
    if attemptTrade(country, configResource, amount, price) then
        UI.log(string.format("[%d/%d] OK %s %s", i, total, resource.gameName, name), "success")
        return true, false, nil
    else
        local nextPrice = Helpers.getNextPriceTier(price)
        if Config.RetryEnabled and nextPrice and not isRetry then
            UI.log(string.format("[%d/%d] RETRY %s %s (will try %.1fx)", i, total, resource.gameName, name, nextPrice), "warning")
            return false, true, "Queued"
        end
        UI.log(string.format("[%d/%d] FAIL %s %s", i, total, resource.gameName, name), "warning")
        return false, false, "No Buyers"
    end
end

function M.run()
    if State.isRunning then return end
    
    -- Refresh country in case player switched or just selected one
    Helpers.refreshMyCountry()
    
    -- Early exit if no country selected
    if not Helpers.hasCountry() then
        UI.log("No country selected, skipping trade run", "warning")
        return
    end
    
    -- Early exit if no resources are enabled
    local enabledResources = Helpers.getEnabledResources()
    if #enabledResources == 0 then
        UI.log("No resources enabled, skipping trade run", "warning")
        return
    end
    
    State.isRunning = true
    State.retryQueue = {}
    State.Stats = {Success = 0, Skipped = 0, Failed = 0, ByResource = {}}
    
    for _, res in ipairs(enabledResources) do
        State.Stats.ByResource[res.name] = {Success = 0, Skipped = 0, Failed = 0}
    end
    
    local startTime = tick()
    
    UI.log("=== Trade Started ===", "info")
    for _, res in ipairs(enabledResources) do
        local capInfo = res.hasCap and string.format("Cap: %d", res.capAmount) or "No Cap"
        UI.log(string.format("%s: %.2f avail | %s", res.gameName, Helpers.getAvailableFlow(res), capInfo), "info")
    end
    
    local countries = Helpers.getCountries()
    local allBuyers = Helpers.getAllBuyers()
    Helpers.refreshPlayerCache()
    
    local totalCountries = #countries
    
    -- DEBUG: Log detailed info for an example country to understand acceptance/rejection
    if Config.DebugLogging and #countries > 0 then
        local debugCountry = countries[1]  -- First country (highest revenue)
        UI.log("=== DEBUG: Example Country ===", "info")
        UI.log(string.format("Country: %s", debugCountry.Name), "info")
        
        for _, res in ipairs(Helpers.getEnabledResources()) do
            local data = Helpers.getCountryResourceData(debugCountry, res)
            if data.valid then
                local priceTier = Helpers.getPriceTier(data.revenue, res, data)
                local tierStr = priceTier and string.format("%.1fx", priceTier) or "N/A (cannot afford)"
                local actualPricePerUnit = priceTier and res.buyPrice * priceTier or 0
                local maxAffordable = 0
                if actualPricePerUnit > 0 then
                    maxAffordable = (data.revenue * Config.MaxRevenueSpendingPercent) / actualPricePerUnit
                end
                
                UI.log(string.format("  %s:", res.gameName), "info")
                UI.log(string.format("    Revenue: $%.0f | Balance: $%.0f", data.revenue, data.balance), "info")
                UI.log(string.format("    Flow: %.2f | BuyAmount: %.2f | HasSell: %s", data.flow, data.buyAmount, tostring(data.hasSell)), "info")
                UI.log(string.format("    PriceTier: %s | PricePerUnit: $%.0f", tierStr, actualPricePerUnit), "info")
                UI.log(string.format("    MaxSpend: $%.0f (%.0f%% of rev) | MaxAffordable: %.2f", 
                    data.revenue * Config.MaxRevenueSpendingPercent, Config.MaxRevenueSpendingPercent * 100, maxAffordable), "info")
            end
        end
        UI.log("=== END DEBUG ===", "info")
    end
    
    for i, country in ipairs(countries) do
        if not State.isRunning then 
            UI.log("STOPPED by user", "warning")
            break 
        end
        
        UI.updateProgress(i, totalCountries)
        
        local countryRetryState = {}
        local tradedThisCountry = false
        
        local enabledResources = Helpers.getEnabledResources()
        
        for _, resource in ipairs(enabledResources) do
            if not State.isRunning then break end
            
            -- CRITICAL: Always get fresh resource from Config, not the snapshot
            local configResource = Helpers.getResourceByName(resource.name)
            if not configResource or not configResource.enabled then 
                continue 
            end
            
            local avail = Helpers.getAvailableFlow(configResource)
            if avail < Config.MinAmount then continue end
            
            local ok, err = pcall(function()
                local success, retry, reason = M.processCountryResource(
                    country, configResource, i, totalCountries, allBuyers, countryRetryState
                )
                
                if success then
                    State.Stats.Success = State.Stats.Success + 1
                    State.Stats.ByResource[configResource.name].Success = State.Stats.ByResource[configResource.name].Success + 1
                    tradedThisCountry = true
                    
                    if not allBuyers[configResource.name] then allBuyers[configResource.name] = {} end
                    allBuyers[configResource.name][country.Name] = true
                elseif retry then
                    table.insert(State.retryQueue, {
                        country = country,
                        resource = configResource,
                        retryState = countryRetryState
                    })
                else
                    State.Stats.Skipped = State.Stats.Skipped + 1
                    State.Stats.ByResource[configResource.name].Skipped = State.Stats.ByResource[configResource.name].Skipped + 1
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
    
    if Config.RetryEnabled and #State.retryQueue > 0 and State.isRunning then
        UI.log(string.format("RETRY: %d", #State.retryQueue), "info")
        
        for pass = 1, Config.MaxRetryPasses do
            if #State.retryQueue == 0 or not State.isRunning then break end
            
            local queue = State.retryQueue
            State.retryQueue = {}
            
            for idx, item in ipairs(queue) do
                if not State.isRunning then break end
                -- Check Config directly to respect real-time toggle changes
                local configResource = Helpers.getResourceByName(item.resource.name)
                if not configResource or not configResource.enabled then continue end
                
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
    
    local elapsed = tick() - startTime
    UI.log("=== Complete ===", "info")
    UI.log(string.format("%.1fs | OK:%d Skip:%d Fail:%d", elapsed, State.Stats.Success, State.Stats.Skipped, State.Stats.Failed), "info")
    
    State.isRunning = false
    UI.updateStats()
end

function M.stop()
    State.isRunning = false
end

return M
