--[[
    AUTOBUYER MODULE
    Auto-buy Monitor for Resource Flow Protection
    Automatically buys resources when your country's flow goes negative
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
    local flowBefore = getAutoBuyResourceFlow(resource.gameName)
    
    -- Calculate target: we want flow to be at least AutoBuyTargetSurplus (e.g., 0.1)
    local targetFlow = Config.AutoBuyTargetSurplus
    
    -- If flow is already at or above target, no need to buy
    if flowBefore >= targetFlow then
        print(string.format("[AutoBuy] %s flow %.2f >= target %.2f, skipping", resource.gameName, flowBefore, targetFlow))
        return false, "Flow OK"
    end
    
    -- Calculate how much we need to reach the target surplus
    -- e.g., if flow is -0.5 and target is 0.1, we need 0.6
    -- NOTE: flowBefore already includes the effect of all active buy/sell trades,
    -- so we don't need to subtract currentBuying - that would double-count
    local neededAmount = targetFlow - flowBefore
    
    if neededAmount < Config.MinAmount then
        print(string.format("[AutoBuy] %s already at target (flow: %.2f, needed: %.2f)", resource.gameName, flowBefore, neededAmount))
        return false, "Already Buying"
    end
    
    -- Print flow before buying
    print(string.format("[AutoBuy] %s - Flow BEFORE: %.2f, target: %.2f, neededAmount: %.2f", 
        resource.gameName, flowBefore, targetFlow, neededAmount))
    UI.log(string.format("[AutoBuy] %s flow: %.2f, target: %.2f, need: %.2f", resource.gameName, flowBefore, targetFlow, neededAmount), "info")
    
    -- Find AI NPC countries selling this resource
    local sellers = findSellingCountries(resource.gameName)
    if #sellers == 0 then
        print(string.format("[AutoBuy] No AI NPC sellers found for %s", resource.gameName))
        UI.log(string.format("[AutoBuy] No sellers for %s", resource.gameName), "warning")
        return false, "No Sellers"
    end
    
    local boughtTotal = 0
    
    for _, seller in ipairs(sellers) do
        if neededAmount <= 0 then 
            print(string.format("[AutoBuy] Needed amount fulfilled (%.2f), stopping search", neededAmount))
            break 
        end
        
        -- AI NPCs can sell as much as needed - buy what we need up to their flow
        -- Can even put them in deficit if needed
        local buyAmount = math.min(neededAmount, seller.flow)
        if buyAmount < Config.MinAmount then 
            print(string.format("[AutoBuy] %s has insufficient flow (%.2f), skipping", seller.name, seller.flow))
            continue 
        end
        
        -- AI NPCs ALWAYS use 1.0x price - they don't accept discounts when selling
        local price = 1.0
        
        print(string.format("[AutoBuy] Attempting to buy %.2f %s from %s @ %.1fx (AI NPC - no discount)", 
            buyAmount, resource.gameName, seller.name, price))
        UI.log(string.format("[AutoBuy] Buying %.2f %s from %s @ %.1fx", 
            buyAmount, resource.gameName, seller.name, price), "info")
        
        if attemptBuy(seller, resource.gameName, buyAmount, price) then
            local flowAfter = getAutoBuyResourceFlow(resource.gameName)
            print(string.format("[AutoBuy] SUCCESS: Bought %.2f %s from %s @ %.1fx | Flow: %.2f -> %.2f", 
                buyAmount, resource.gameName, seller.name, price, flowBefore, flowAfter))
            UI.log(string.format("[AutoBuy] OK %s from %s", resource.gameName, seller.name), "success")
            boughtTotal = boughtTotal + buyAmount
            neededAmount = neededAmount - buyAmount
            M.purchases = M.purchases + 1
        else
            -- AI NPCs don't accept flexibility - if 1.0x fails, move to next seller
            print(string.format("[AutoBuy] FAILED: %s rejected purchase @ %.1fx, trying next seller", seller.name, price))
            UI.log(string.format("[AutoBuy] Failed %s from %s, trying next", resource.gameName, seller.name), "warning")
        end
        
        task.wait(Config.ResourceDelay)
    end
    
    if boughtTotal > 0 then
        print(string.format("[AutoBuy] Total bought for %s: %.2f", resource.gameName, boughtTotal))
        return true, string.format("Bought %.2f", boughtTotal)
    end
    print(string.format("[AutoBuy] No purchases made for %s", resource.gameName))
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
