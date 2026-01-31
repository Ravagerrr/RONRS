--[[
    AUTOBUYER MODULE
    Auto-buy Monitor for Resource Flow Protection
    
    v4.2.016: Added Fertilizer Factory (Phosphate), Motor Factory (Tungsten), 
              Electronics Factory (Gold). Removed city deficit logic - now only
              checks factory consumption and negative flow.
    v4.2.015: Added factory detection - now detects Electronics Factory, etc.
              and auto-buys materials they consume.
    v4.2.013: Fixed random buying when no city deficit exists - now only buys if flow is negative.
    v4.2.012: Fixed deficit calculation to subtract current flow from city deficit.
              Added detailed debug prints throughout the buying process.
    v4.2.011: Reads resource deficits directly from city Resources attributes.
    
    Now checks factory consumption and falls back to flow-based check.
    Only buys if: 1) Factory needs the resource, or 2) Flow is negative.
]]

local M = {}
local Config, State, Helpers, UI

local ManageAlliance = workspace:WaitForChild("GameManager"):WaitForChild("ManageAlliance")

M.isMonitoring = false
M.purchases = 0

function M.init(cfg, state, helpers, ui)
    Config = cfg
    State = state
    Helpers = helpers
    UI = ui
end

-- Get flow for a specific auto-buy resource
local function getAutoBuyResourceFlow(resourceGameName)
    if not Helpers.myCountry then return 0 end
    local res = Helpers.getResourceFolder(Helpers.myCountry, resourceGameName)
    if not res then return 0 end
    local f = res:FindFirstChild("Flow")
    return f and f.Value or 0
end

-- Find AI NPC countries that can sell a resource (positive flow producers)
-- AI NPCs don't have selling restrictions - can buy as much as needed, even put them in deficit
local function findSellingCountries(resourceGameName)
    local sellers = {}
    local CountryData = workspace:WaitForChild("CountryData")
    
    print(string.format("[AutoBuy] Searching for %s sellers...", resourceGameName))
    
    for _, country in ipairs(CountryData:GetChildren()) do
        if country == Helpers.myCountry then continue end
        if Helpers.isPlayerCountry(country.Name) then continue end
        
        local res = Helpers.getResourceFolder(country, resourceGameName)
        if not res then continue end
        
        local flowObj = res:FindFirstChild("Flow")
        local flow = flowObj and flowObj.Value or 0
        
        -- Only consider countries with positive flow (producers)
        if flow <= 0 then continue end
        
        local trade = res:FindFirstChild("Trade")
        if not trade then continue end
        
        -- Check if they're already selling to us
        local alreadySellingToUs = false
        for _, obj in ipairs(trade:GetChildren()) do
            if obj:IsA("Vector3Value") then
                if obj.Value.X < -0.01 and obj.Name == Helpers.myCountryName then
                    alreadySellingToUs = true
                    break
                end
            end
        end
        
        if alreadySellingToUs then 
            print(string.format("[AutoBuy] %s already selling %s to us, skipping", country.Name, resourceGameName))
            continue 
        end
        
        -- Get country revenue for reference (not used for price - AI NPCs always use 1.0x)
        local eco = country:FindFirstChild("Economy")
        local revenue = 0
        if eco then
            local rev = eco:FindFirstChild("Revenue")
            if rev then
                revenue = rev:GetAttribute("Total") or 0
            end
        end
        
        -- AI NPCs can sell as much as their flow allows - no restrictions
        -- Can even put them in deficit if needed
        print(string.format("[AutoBuy] Found seller: %s (flow: %.2f, revenue: $%.0f)", country.Name, flow, revenue))
        
        table.insert(sellers, {
            country = country,
            name = country.Name,
            flow = flow,
            revenue = revenue
        })
    end
    
    -- Sort by flow (highest first) - prefer countries with most production
    table.sort(sellers, function(a, b) return a.flow > b.flow end)
    
    print(string.format("[AutoBuy] Found %d potential sellers for %s", #sellers, resourceGameName))
    
    return sellers
end

-- Attempt to buy from a country
local function attemptBuy(seller, resourceGameName, amount, price)
    pcall(function()
        ManageAlliance:FireServer(seller.name, "ResourceTrade", {resourceGameName, "Buy", amount, price, "Trade"})
    end)
    
    task.wait(Config.WaitTime)
    
    -- Verify the trade was accepted
    local res = Helpers.getResourceFolder(Helpers.myCountry, resourceGameName)
    if not res then return false end
    local trade = res:FindFirstChild("Trade")
    if not trade then return false end
    
    for _, obj in ipairs(trade:GetChildren()) do
        if obj:IsA("Vector3Value") and obj.Name == seller.name and obj.Value.X > 0 then
            return true
        end
    end
    return false
end

-- Check and buy for a single resource
local function checkAndBuyResource(resource)
    print(string.format("[AutoBuy] ========== Checking %s ==========", resource.gameName))
    
    local flowBefore = getAutoBuyResourceFlow(resource.gameName)
    print(string.format("[AutoBuy] %s | Current Flow: %.2f", resource.gameName, flowBefore))
    
    -- Stop auto-buying if flow is already at or above the positive threshold
    -- This prevents buying when we're already in a positive flow state
    -- Fallback to 1 as safety measure if config is not properly loaded
    local stopThreshold = Config.AutoBuyStopAtPositiveFlow or 1
    if flowBefore >= stopThreshold then
        print(string.format("[AutoBuy] %s | Flow %.2f >= stop threshold %.2f, SKIPPING (positive flow reached)", resource.gameName, flowBefore, stopThreshold))
        return false, "Positive Flow"
    end
    
    -- Calculate target: we want flow to be at least AutoBuyTargetSurplus (e.g., 0.1)
    local targetFlow = Config.AutoBuyTargetSurplus
    print(string.format("[AutoBuy] %s | Target Surplus: %.2f", resource.gameName, targetFlow))
    
    -- Check factory resource consumption - detects factories that consume resources
    -- e.g., Electronics Factory consumes Titanium, Copper, and Gold
    local factoryConsumption = Helpers.getFactoryConsumption(resource.gameName)
    print(string.format("[AutoBuy] %s | Factory Consumption: %.2f", resource.gameName, factoryConsumption))
    
    -- If factories need this resource, we need to buy
    -- Otherwise fall back to flow-based check
    local neededAmount = 0
    
    if factoryConsumption > 0 then
        -- Factory consumption: what factories need minus our current production
        -- If we have positive flow (production), it offsets the factory need
        -- Only buy the difference that isn't covered by our own production
        local positiveFlow = math.max(0, flowBefore)
        -- Subtract our production from factory needs: e.g., factories need 100, we produce 50, so we only need to buy 50
        local actualDeficit = math.max(0, factoryConsumption - positiveFlow)
        neededAmount = actualDeficit + targetFlow
        
        print(string.format("[AutoBuy] %s | Calculation: FactoryNeed(%.2f) - PositiveFlow(%.2f) = ActualDeficit(%.2f)", 
            resource.gameName, factoryConsumption, positiveFlow, actualDeficit))
        print(string.format("[AutoBuy] %s | Final Need: ActualDeficit(%.2f) + TargetSurplus(%.2f) = %.2f", 
            resource.gameName, actualDeficit, targetFlow, neededAmount))
    else
        -- Fallback to flow-based check if no factory consumption exists
        -- Only trigger if flow is NEGATIVE (actively consuming the resource)
        -- If flow is >= 0 and no factory need detected, we don't need this resource
        print(string.format("[AutoBuy] %s | No factory need detected, checking flow", resource.gameName))
        if flowBefore >= 0 then
            print(string.format("[AutoBuy] %s | Flow %.2f >= 0 and no factory need, SKIPPING", resource.gameName, flowBefore))
            return false, "No Need"
        end
        -- Flow is negative - we're consuming more than producing
        -- Buy enough to bring flow to target surplus
        neededAmount = targetFlow - flowBefore  -- e.g., 0.1 - (-5) = 5.1
        print(string.format("[AutoBuy] %s | Negative flow %.2f, need: %.2f to reach target %.2f", resource.gameName, flowBefore, neededAmount, targetFlow))
    end
    
    if neededAmount <= 0 then
        print(string.format("[AutoBuy] %s | Needed amount %.2f <= 0, SKIPPING", resource.gameName, neededAmount))
        return false, "No Deficit"
    end
    
    if neededAmount < Config.MinAmount then
        print(string.format("[AutoBuy] %s | Need %.2f < MinAmount %.3f, SKIPPING", resource.gameName, neededAmount, Config.MinAmount))
        return false, "Already Buying"
    end
    
    -- Print status before buying
    print(string.format("[AutoBuy] %s | >>> WILL BUY: Need %.2f units <<<", resource.gameName, neededAmount))
    if factoryConsumption > 0 then
        UI.log(string.format("[AutoBuy] %s need: %.2f (factory: %.2f, flow: %.2f)", 
            resource.gameName, neededAmount, factoryConsumption, flowBefore), "info")
    else
        UI.log(string.format("[AutoBuy] %s flow: %.2f, target: %.2f, need: %.2f", resource.gameName, flowBefore, targetFlow, neededAmount), "info")
    end
    
    -- Find AI NPC countries selling this resource
    local sellers = findSellingCountries(resource.gameName)
    print(string.format("[AutoBuy] %s | Found %d potential sellers", resource.gameName, #sellers))
    if #sellers == 0 then
        print(string.format("[AutoBuy] %s | No sellers found, ABORTING", resource.gameName))
        UI.log(string.format("[AutoBuy] No sellers for %s", resource.gameName), "warning")
        return false, "No Sellers"
    end
    
    local boughtTotal = 0
    local remainingNeed = neededAmount  -- Track remaining need during loop (neededAmount preserved for final summary)
    
    print(string.format("[AutoBuy] %s | Starting purchase loop, need %.2f", resource.gameName, remainingNeed))
    
    for idx, seller in ipairs(sellers) do
        -- Check if auto-buy was disabled mid-operation
        if not M.isMonitoring or not Config.AutoBuyEnabled then
            print(string.format("[AutoBuy] %s | Auto-buy disabled, stopping", resource.gameName))
            break
        end
        
        if remainingNeed <= 0 then 
            print(string.format("[AutoBuy] %s | Remaining need %.2f <= 0, DONE", resource.gameName, remainingNeed))
            break 
        end
        
        -- AI NPCs can sell as much as needed - buy what we need up to their flow
        -- Can even put them in deficit if needed
        local buyAmount = math.min(remainingNeed, seller.flow)
        print(string.format("[AutoBuy] %s | Seller #%d: %s | SellerFlow=%.2f, RemainingNeed=%.2f, BuyAmount=%.2f", 
            resource.gameName, idx, seller.name, seller.flow, remainingNeed, buyAmount))
        
        if buyAmount < Config.MinAmount then 
            print(string.format("[AutoBuy] %s | %s buyAmount %.2f < MinAmount, skipping seller", resource.gameName, seller.name, buyAmount))
            continue 
        end
        
        -- AI NPCs ALWAYS use 1.0x price - they don't accept discounts when selling
        local price = 1.0
        
        print(string.format("[AutoBuy] %s | Attempting: %.2f from %s @ %.1fx", resource.gameName, buyAmount, seller.name, price))
        UI.log(string.format("[AutoBuy] Buying %.2f %s from %s @ %.1fx", 
            buyAmount, resource.gameName, seller.name, price), "info")
        
        if attemptBuy(seller, resource.gameName, buyAmount, price) then
            local flowAfter = getAutoBuyResourceFlow(resource.gameName)
            boughtTotal = boughtTotal + buyAmount
            remainingNeed = remainingNeed - buyAmount
            M.purchases = M.purchases + 1
            
            print(string.format("[AutoBuy] %s | SUCCESS from %s: +%.2f | Total bought: %.2f | Remaining: %.2f | Flow: %.2f -> %.2f", 
                resource.gameName, seller.name, buyAmount, boughtTotal, remainingNeed, flowBefore, flowAfter))
            UI.log(string.format("[AutoBuy] OK %s from %s", resource.gameName, seller.name), "success")
        else
            -- AI NPCs don't accept flexibility - if 1.0x fails, move to next seller
            print(string.format("[AutoBuy] %s | FAILED from %s @ %.1fx, trying next", resource.gameName, seller.name, price))
            UI.log(string.format("[AutoBuy] Failed %s from %s, trying next", resource.gameName, seller.name), "warning")
        end
        
        task.wait(Config.ResourceDelay)
    end
    
    print(string.format("[AutoBuy] %s | ========== COMPLETE: Bought %.2f / Needed %.2f ==========", resource.gameName, boughtTotal, neededAmount))
    
    if boughtTotal > 0 then
        return true, string.format("Bought %.2f", boughtTotal)
    end
    print(string.format("[AutoBuy] %s | No purchases completed", resource.gameName))
    return false, "Failed"
end

-- Get enabled auto-buy resources
function M.getEnabledResources()
    local enabled = {}
    for _, res in ipairs(Config.AutoBuyResources) do
        if res.enabled then
            table.insert(enabled, res)
        end
    end
    return enabled
end

-- Run auto-buy check for all resources
function M.runCheck()
    -- Check if we're in debt and debt restriction is enabled
    if Config.AutoBuyRequireNoDebt and Helpers.isInDebt() then
        -- Skip auto-buy when in debt
        return
    end
    
    local enabledResources = M.getEnabledResources()
    
    for _, resource in ipairs(enabledResources) do
        if not M.isMonitoring then break end
        
        local success, reason = checkAndBuyResource(resource)
        if success then
            UI.log(string.format("[AutoBuy] %s: %s", resource.gameName, reason), "success")
        end
    end
end

function M.start()
    if M.isMonitoring then return end
    M.isMonitoring = true
    UI.log("Auto-Buy: ON", "info")
    
    task.spawn(function()
        while M.isMonitoring do
            if not Config.AutoBuyEnabled then
                M.isMonitoring = false
                UI.log("Auto-Buy: OFF", "warning")
                break
            end
            
            UI.updateAutoBuy()
            
            -- Only run if we're not currently in a sell cycle
            if not State.isRunning then
                M.runCheck()
            end
            
            task.wait(Config.AutoBuyCheckInterval)
        end
        
        UI.log("Auto-Buy: OFF", "warning")
        UI.updateAutoBuy()
    end)
end

function M.stop()
    M.isMonitoring = false
    UI.updateAutoBuy()
end

return M
