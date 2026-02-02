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
    
    -- Fire the trade request once
    -- If it fails, the queue-based retry system handles re-attempting after other countries
    -- This respects the game's ~10 second cooldown between trades with the same country
    pcall(function()
        ManageAlliance:FireServer(country.Name, "ResourceTrade", {resource.gameName, "Sell", amount, price, "Trade"})
    end)
    
    -- Poll to verify trade was registered
    local maxPolls = 5
    local pollInterval = 0.2
    
    for poll = 1, maxPolls do
        task.wait(pollInterval)
        
        local afterAmount = Helpers.getSellingAmountTo(resource.gameName, country.Name)
        if afterAmount > beforeAmount then
            return true
        end
    end
    
    -- Trade not verified - will be queued for retry at lower price tier
    -- The queue processes other countries first, naturally respecting the cooldown
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
    
    -- Check if we're already selling this resource to this country (prevents duplicate trades on retry)
    -- This checks OUR trade folder, not theirs, for reliable detection
    local alreadySelling = Helpers.getSellingAmountTo(resource.gameName, name)
    if alreadySelling > 0 then return false, false, "Already Trading" end
    
    local data = Helpers.getCountryResourceData(country, resource)
    if not data.valid then return false, false, "Invalid" end
    if data.revenue <= 0 or data.balance <= 0 then return false, false, "No Revenue" end
    if data.hasSell then return false, false, "Already Selling" end
    if Config.SkipProducingCountries and data.flow > 0 then return false, false, "Producing" end
    
    -- Skip countries with no meaningful demand (flow >= MinDemandFlow threshold)
    -- Countries need actual negative flow (consumption) to want to buy resources
    -- This prevents attempting trades to countries with zero or near-zero flow
    -- EXCEPTION: Capped resources (like Electronics) bypass this check because countries
    -- will buy up to their cap regardless of flow. They don't "consume" Electronics naturally.
    if not resource.hasCap and data.flow >= (Config.MinDemandFlow or 0) then return false, false, "No Demand" end
    
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
    
    -- Get dynamic spending limit based on country revenue (bigger countries = more lenient)
    local maxSpendingPercent = Helpers.getMaxSpendingPercent(data.revenue)
    
    -- Calculate affordable based on ACTUAL price they pay
    -- Apply dynamic revenue spending limit to prevent rejection
    local maxAffordable = (data.revenue * maxSpendingPercent) / actualPricePerUnit
    
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
    
    -- Track if this trade is flow-limited (wanted more than we could sell)
    local isFlowLimited = remaining > avail and (remaining - amount) >= Config.MinAmount
    local flowLimitedAmount = remaining - amount  -- Amount we wanted but couldn't sell due to flow
    
    if not retryState then retryState = {} end
    retryState[resName .. "_price"] = price
    
    local totalCost = amount * actualPricePerUnit
    local costPercent = (totalCost / data.revenue) * 100
    
    -- Enhanced debug log for algorithm analysis
    -- Format: TRADE|Country|Rank|Resource|PriceTier|Amount|Cost%|Revenue|Result
    -- This format makes it easy to track each country's journey through price tiers
    -- Example: TRADE|Slovakia|140|Cons|1.0x|1.31|4.85%|$221855|FAIL
    --          TRADE|Slovakia|140|Cons|0.5x|1.31|2.43%|$221855|OK
    -- ^ Shows Slovakia (rank 140) failed 1.0x but succeeded at 0.5x
    
    UI.log(string.format("[%d/%d] %s %s | %.2f @ %.1fx ($%.0f/u) | Flow:%.2f Rev:$%.0f Cost:$%.0f", 
        i, total, resource.gameName, name, amount, price, actualPricePerUnit, data.flow, data.revenue, totalCost), "info")
    
    if attemptTrade(country, configResource, amount, price) then
        UI.log(string.format("[%d/%d] OK %s %s", i, total, resource.gameName, name), "success")
        
        -- If trade was flow-limited, queue the remaining amount for later
        if isFlowLimited and Config.FlowQueueEnabled then
            M.queueFlowLimitedTrade(country, configResource, flowLimitedAmount, price, data)
        end
        
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

-- Queue a flow-limited trade for later processing
-- Called when a trade succeeded but was limited by available flow
function M.queueFlowLimitedTrade(country, resource, remainingAmount, price, countryData)
    if not Config.FlowQueueEnabled then return end
    if remainingAmount < Config.MinAmount then return end
    
    local name = country.Name
    local resName = resource.name
    
    -- Create unique key for this country+resource combination
    local key = name .. "_" .. resName
    
    -- Initialize flow queue if needed
    if not State.flowQueue then State.flowQueue = {} end
    
    -- Add or update the queued trade
    State.flowQueue[key] = {
        country = country,
        countryName = name,
        resource = resource,
        remainingAmount = remainingAmount,
        price = price,
        countryData = countryData,
        queuedAt = tick(),
        expiresAt = Config.FlowQueueTimeout > 0 and (tick() + Config.FlowQueueTimeout) or nil
    }
    
    UI.log(string.format("[FLOW Q] Queued %.2f %s to %s (expires in %ds)", 
        remainingAmount, resource.gameName, name, Config.FlowQueueTimeout), "info")
end

-- Process the flow queue - attempt to complete queued trades when flow becomes available
-- Returns number of successful trades
function M.processFlowQueue()
    if not Config.FlowQueueEnabled then return 0 end
    if not State.flowQueue then State.flowQueue = {} return 0 end
    
    local now = tick()
    local successCount = 0
    local toRemove = {}
    
    -- Start blocking AlertPopup during flow queue processing
    Helpers.startScriptTrade()
    
    for key, item in pairs(State.flowQueue) do
        -- Check if expired
        if item.expiresAt and now > item.expiresAt then
            UI.log(string.format("[FLOW Q] Expired: %s %s", item.resource.gameName, item.countryName), "warning")
            table.insert(toRemove, key)
            continue
        end
        
        -- Check if we have enough flow now
        local avail = Helpers.getAvailableFlow(item.resource)
        if avail < Config.MinAmount then continue end
        
        -- Check if country resource config is still enabled
        local configResource = Helpers.getResourceByName(item.resource.name)
        if not configResource or not configResource.enabled then
            table.insert(toRemove, key)
            continue
        end
        
        -- Re-check that we're still selling to this country (trade wasn't cancelled)
        local currentSelling = Helpers.getSellingAmountTo(item.resource.gameName, item.countryName)
        if currentSelling <= 0 then
            -- Original trade was cancelled, remove from queue
            UI.log(string.format("[FLOW Q] Original trade cancelled: %s %s", item.resource.gameName, item.countryName), "warning")
            table.insert(toRemove, key)
            continue
        end
        
        -- Re-check the country's current capacity (account for trades set up since queuing)
        -- This prevents trying to sell more than the country can accept
        local countryData = Helpers.getCountryResourceData(item.country, item.resource)
        local sellAmount
        
        if configResource.hasCap then
            -- For capped resources (like Electronics), check remaining capacity
            local maxCapacity = configResource.capAmount or 5
            local remainingCapacity = math.max(0, maxCapacity - countryData.buyAmount)
            
            if remainingCapacity < Config.MinAmount then
                -- Country has reached cap from other trades, remove from queue
                UI.log(string.format("[FLOW Q] %s reached cap for %s, removing", item.countryName, item.resource.gameName), "info")
                table.insert(toRemove, key)
                continue
            end
            
            -- Calculate sell amount considering remaining amount, available flow, AND remaining capacity
            sellAmount = math.min(item.remainingAmount, avail, remainingCapacity)
        else
            -- For uncapped resources, just consider remaining amount and available flow
            sellAmount = math.min(item.remainingAmount, avail)
        end
        
        if sellAmount < Config.MinAmount then continue end
        
        -- Attempt the trade
        UI.log(string.format("[FLOW Q] Trying %.2f %s to %s", sellAmount, item.resource.gameName, item.countryName), "info")
        
        local beforeAmount = Helpers.getSellingAmountTo(item.resource.gameName, item.countryName)
        
        pcall(function()
            local ManageAlliance = workspace:WaitForChild("GameManager"):WaitForChild("ManageAlliance")
            ManageAlliance:FireServer(item.countryName, "ResourceTrade", {item.resource.gameName, "Sell", sellAmount, item.price, "Trade"})
        end)
        
        -- Poll to verify trade was registered
        local maxPolls = 5
        local pollInterval = 0.2
        local success = false
        
        for poll = 1, maxPolls do
            task.wait(pollInterval)
            local afterAmount = Helpers.getSellingAmountTo(item.resource.gameName, item.countryName)
            if afterAmount > beforeAmount then
                success = true
                break
            end
        end
        
        if success then
            successCount = successCount + 1
            item.remainingAmount = item.remainingAmount - sellAmount
            
            UI.log(string.format("[FLOW Q] OK +%.2f %s to %s", sellAmount, item.resource.gameName, item.countryName), "success")
            
            -- If fully completed, remove from queue
            if item.remainingAmount < Config.MinAmount then
                UI.log(string.format("[FLOW Q] Complete: %s %s", item.resource.gameName, item.countryName), "success")
                table.insert(toRemove, key)
            else
                -- Reset expiry timer since we made progress
                if Config.FlowQueueTimeout > 0 then
                    item.expiresAt = tick() + Config.FlowQueueTimeout
                end
            end
        else
            UI.log(string.format("[FLOW Q] Failed: %s %s", item.resource.gameName, item.countryName), "warning")
        end
    end
    
    -- Remove completed/expired entries
    for _, key in ipairs(toRemove) do
        State.flowQueue[key] = nil
    end
    
    -- Stop blocking AlertPopup after flow queue processing
    Helpers.stopScriptTrade()
    
    return successCount
end

-- Get count of items in flow queue
function M.getFlowQueueCount()
    if not State.flowQueue then return 0 end
    local count = 0
    for _ in pairs(State.flowQueue) do count = count + 1 end
    return count
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
    
    -- Start blocking AlertPopup during script trades
    Helpers.startScriptTrade()
    
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
    
    -- Count AI countries (exclude own country and player countries)
    -- This is used to detect when we're already trading with ALL AI countries
    local aiCountryCount = 0
    for _, country in ipairs(countries) do
        if not (Config.SkipOwnCountry and country == Helpers.myCountry) and
           not Helpers.isPlayerCountry(country.Name) then
            aiCountryCount = aiCountryCount + 1
        end
    end
    
    -- Track which resources are already maxed out (trading with all AI countries)
    -- Consumer Goods uses a 100% aced algo - trades always succeed when calculated correctly
    -- If we're already trading with all AI countries for a resource, skip it entirely
    local resourcesMaxedOut = {}
    for _, res in ipairs(enabledResources) do
        local currentBuyers = Helpers.getBuyerCount(res)
        if currentBuyers >= aiCountryCount and aiCountryCount > 0 then
            resourcesMaxedOut[res.name] = true
            UI.log(string.format("%s: Already trading with all %d AI countries - skipping", res.gameName, aiCountryCount), "success")
        end
    end
    
    -- If ALL resources are maxed out, skip the entire trade run
    local allMaxedOut = true
    for _, res in ipairs(enabledResources) do
        if not resourcesMaxedOut[res.name] then
            allMaxedOut = false
            break
        end
    end
    if allMaxedOut then
        UI.log("=== All resources maxed out - nothing to trade ===", "success")
        Helpers.stopScriptTrade()  -- Ensure flag is cleared on early exit
        State.isRunning = false
        return
    end
    
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
                local maxSpendingPercent = Helpers.getMaxSpendingPercent(data.revenue)
                local maxAffordable = 0
                if actualPricePerUnit > 0 then
                    maxAffordable = (data.revenue * maxSpendingPercent) / actualPricePerUnit
                end
                
                UI.log(string.format("  %s:", res.gameName), "info")
                UI.log(string.format("    Revenue: $%.0f | Balance: $%.0f", data.revenue, data.balance), "info")
                UI.log(string.format("    Flow: %.2f | BuyAmount: %.2f | HasSell: %s", data.flow, data.buyAmount, tostring(data.hasSell)), "info")
                UI.log(string.format("    PriceTier: %s | PricePerUnit: $%.0f", tierStr, actualPricePerUnit), "info")
                UI.log(string.format("    MaxSpend: $%.0f (%.0f%% of rev) | MaxAffordable: %.2f", 
                    data.revenue * maxSpendingPercent, maxSpendingPercent * 100, maxAffordable), "info")
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
            
            -- Skip resources that are already maxed out (trading with all AI countries)
            if resourcesMaxedOut[resource.name] then continue end
            
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
    
    -- Stop blocking AlertPopup after script trades complete
    Helpers.stopScriptTrade()
    
    State.isRunning = false
    UI.updateStats()
end

function M.stop()
    State.isRunning = false
    -- Ensure AlertPopup blocking is disabled when stop() is called externally (e.g., emergency stop)
    -- Normal completion already calls stopScriptTrade() at line 570
    Helpers.stopScriptTrade()
end

return M
