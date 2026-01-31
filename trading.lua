--[[
    TRADING MODULE
    Multi-Resource with Priority System
    FIXED: Calculate amount based on actual price tier
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
    
    UI.log(string.format("    → Sending trade request to server..."), "info")
    UI.log(string.format("    → Trade count before: %d", before), "info")
    
    pcall(function()
        ManageAlliance:FireServer(country.Name, "ResourceTrade", {resource.gameName, "Sell", amount, price, "Trade"})
    end)
    
    task.wait(Config.WaitTime)
    
    local after = Helpers.getTradeCount(country, resource.gameName)
    UI.log(string.format("    → Trade count after: %d", after), "info")
    
    local success = after > before
    if success then
        UI.log(string.format("    ✓ Trade confirmed! (count increased by %d)", after - before), "success")
    else
        UI.log(string.format("    ✗ Trade not confirmed (count unchanged)"), "warning")
    end
    
    return success
end

function M.processCountryResource(country, resource, i, total, buyers, retryState)
    if not State.isRunning then return false, false, "Stopped" end
    if not resource.enabled then return false, false, "Disabled" end
    
    local name = country.Name
    local resName = resource.name
    local isRetry = retryState and retryState[resName]
    local icon = resName == "ConsumerGoods" and "CG" or "EL"
    
    -- DEBUG: Initial check
    UI.log(string.format("━━━ [%d/%d] %s %s ━━━", i, total, icon, name), "info")
    
    local avail = Helpers.getAvailableFlow(resource)
    UI.log(string.format("  Available Flow: %.2f (Min: %.2f)", avail, Config.MinAmount), "info")
    if Config.SmartSell and avail < Config.MinAmount then
        UI.log(string.format("  ✗ SKIP: Not enough flow available", "warning"))
        return false, false, "No Flow"
    end
    
    if Config.SkipOwnCountry and country == Helpers.myCountry then 
        UI.log("  ✗ SKIP: Own country", "warning")
        return false, false, "Own" 
    end
    if Helpers.isPlayerCountry(name) then 
        UI.log("  ✗ SKIP: Player country", "warning")
        return false, false, "Player" 
    end
    
    local resourceBuyers = buyers[resName] or {}
    if Config.SkipExistingBuyers and resourceBuyers[name] then 
        UI.log("  ✗ SKIP: Already a buyer", "warning")
        return false, false, "Buyer" 
    end
    
    local data = Helpers.getCountryResourceData(country, resource)
    UI.log(string.format("  Revenue: $%.0f | Balance: $%.0f | Flow: %.2f | Buying: %.2f", 
        data.revenue, data.balance, data.flow, data.buyAmount), "info")
    
    if not data.valid then 
        UI.log("  ✗ SKIP: Invalid data", "warning")
        return false, false, "Invalid" 
    end
    if data.revenue <= 0 or data.balance <= 0 then 
        UI.log("  ✗ SKIP: No revenue or balance", "warning")
        return false, false, "No Revenue" 
    end
    if data.hasSell then 
        UI.log("  ✗ SKIP: Already has sell order", "warning")
        return false, false, "Already Selling" 
    end
    if Config.SkipProducingCountries and data.flow > 0 then 
        UI.log("  ✗ SKIP: Producing this resource", "warning")
        return false, false, "Producing" 
    end
    
    -- Get price tier FIRST
    local price = Helpers.getPriceTier(data.revenue)
    UI.log(string.format("  Price Tier: %.1fx (based on revenue $%.0f)", price, data.revenue), "info")
    
    if isRetry and retryState[resName .. "_price"] then
        price = Helpers.getNextPriceTier(retryState[resName .. "_price"])
        if not price then 
            UI.log("  ✗ FAIL: No more price tiers to try", "warning")
            return false, false, "No Buyers" 
        end
        UI.log(string.format("  RETRY with new price tier: %.1fx", price), "info")
    end
    
    -- Calculate ACTUAL price per unit at this tier
    local actualPricePerUnit = resource.buyPrice * price
    UI.log(string.format("  Actual Price/Unit: $%.2f (base: $%.0f × tier: %.1fx)", 
        actualPricePerUnit, resource.buyPrice, price), "info")
    
    -- Calculate affordable based on ACTUAL price they pay
    local affordable
    if resource.hasCap then
        -- Electronics: cap at capAmount (5), use 100% of revenue
        local canAfford = data.revenue / actualPricePerUnit
        affordable = math.min(resource.capAmount, canAfford)
        UI.log(string.format("  Capped Resource (Electronics): Can afford %.2f (100%% rev: $%.0f / $%.2f), cap is %d, using %.2f", 
            canAfford, data.revenue, actualPricePerUnit, resource.capAmount, affordable), "info")
    else
        -- Consumer Goods: NO CAP, only use 80% of revenue to leave room for other expenses
        local usableRevenue = data.revenue * 0.8
        affordable = usableRevenue / actualPricePerUnit
        UI.log(string.format("  Uncapped Resource (Consumer Goods): Can afford %.2f (80%% of rev: $%.0f / $%.2f)", 
            affordable, usableRevenue, actualPricePerUnit), "info")
    end
    
    if affordable < Config.MinAmount then 
        UI.log(string.format("  ✗ SKIP: Affordable amount %.2f < minimum %.2f", affordable, Config.MinAmount), "warning")
        return false, false, "Insufficient" 
    end
    
    -- Subtract what they're already buying
    local remaining = affordable - data.buyAmount
    UI.log(string.format("  Remaining capacity: %.2f (affordable: %.2f - already buying: %.2f)", 
        remaining, affordable, data.buyAmount), "info")
    if remaining < Config.MinAmount then 
        UI.log(string.format("  ✗ SKIP: Remaining %.2f < minimum %.2f", remaining, Config.MinAmount), "warning")
        return false, false, "Max Capacity" 
    end
    
    -- Cap to available flow
    local amount = math.min(remaining, avail)
    UI.log(string.format("  Final amount: %.2f (min of remaining: %.2f, available: %.2f)", 
        amount, remaining, avail), "info")
    if amount < Config.MinAmount then 
        UI.log(string.format("  ✗ SKIP: Final amount %.2f < minimum %.2f (flow protection)", amount, Config.MinAmount), "warning")
        return false, false, "Flow Protection" 
    end
    
    if not retryState then retryState = {} end
    retryState[resName .. "_price"] = price
    
    UI.log(string.format("  ✓ ATTEMPTING TRADE: %.2f units @ %.1fx ($%.2f/u) = $%.2f total", 
        amount, price, actualPricePerUnit, amount * actualPricePerUnit), "success")
    
    if attemptTrade(country, resource, amount, price) then
        UI.log(string.format("  ✓✓ TRADE SUCCESS! %s bought %.2f %s @ %.1fx", 
            name, amount, resName, price), "success")
        return true, false, nil
    else
        UI.log(string.format("  ✗✗ TRADE FAILED - No buyers at %.1fx", price), "warning")
        local nextPrice = Helpers.getNextPriceTier(price)
        if Config.RetryEnabled and nextPrice and not isRetry then
            UI.log(string.format("  → Will retry at next tier: %.1fx", nextPrice), "info")
            return false, true, "Queued"
        end
        UI.log("  No retry available", "warning")
        return false, false, "No Buyers"
    end
end

function M.run()
    if State.isRunning then return end
    State.isRunning = true
    State.retryQueue = {}
    State.Stats = {Success = 0, Skipped = 0, Failed = 0, ByResource = {}}
    
    for _, res in ipairs(Helpers.getEnabledResources()) do
        State.Stats.ByResource[res.name] = {Success = 0, Skipped = 0, Failed = 0}
    end
    
    local startTime = tick()
    
    UI.log("=== Trade Started ===", "info")
    for _, res in ipairs(Helpers.getEnabledResources()) do
        local icon = res.name == "ConsumerGoods" and "CG" or "EL"
        local capInfo = res.hasCap and string.format("Cap: %d", res.capAmount) or "No Cap"
        UI.log(string.format("%s %s: %.2f avail | %s", icon, res.gameName, Helpers.getAvailableFlow(res), capInfo), "info")
    end
    
    local countries = Helpers.getCountries()
    local allBuyers = Helpers.getAllBuyers()
    Helpers.refreshPlayerCache()
    
    local totalCountries = #countries
    
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
    
    if Config.RetryEnabled and #State.retryQueue > 0 and State.isRunning then
        UI.log(string.format("RETRY: %d", #State.retryQueue), "info")
        
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
