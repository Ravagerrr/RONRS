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

-- Get how much we're already buying of this resource
local function getCurrentBuyAmount(resourceGameName)
    if not Helpers.myCountry then return 0 end
    local res = Helpers.getResourceFolder(Helpers.myCountry, resourceGameName)
    if not res then return 0 end
    local trade = res:FindFirstChild("Trade")
    if not trade then return 0 end
    
    local buyAmount = 0
    for _, obj in ipairs(trade:GetChildren()) do
        if obj:IsA("Vector3Value") and obj.Value.X > 0.01 then
            buyAmount = buyAmount + obj.Value.X
        end
    end
    return buyAmount
end

-- Find countries that are selling a resource (positive flow producers)
local function findSellingCountries(resourceGameName)
    local sellers = {}
    local CountryData = workspace:WaitForChild("CountryData")
    
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
        local totalSelling = 0
        for _, obj in ipairs(trade:GetChildren()) do
            if obj:IsA("Vector3Value") then
                if obj.Value.X < -0.01 then
                    totalSelling = totalSelling + math.abs(obj.Value.X)
                    if obj.Name == Helpers.myCountryName then
                        alreadySellingToUs = true
                    end
                end
            end
        end
        
        if alreadySellingToUs then continue end
        
        -- Calculate available to sell (flow minus what they're already selling)
        local availableToSell = math.max(0, flow - totalSelling)
        if availableToSell < Config.MinAmount then continue end
        
        -- Get country revenue for price calculation
        local eco = country:FindFirstChild("Economy")
        local revenue = 0
        if eco then
            local rev = eco:FindFirstChild("Revenue")
            if rev then
                revenue = rev:GetAttribute("Total") or 0
            end
        end
        
        table.insert(sellers, {
            country = country,
            name = country.Name,
            flow = flow,
            availableToSell = availableToSell,
            revenue = revenue
        })
    end
    
    -- Sort by available amount (highest first)
    table.sort(sellers, function(a, b) return a.availableToSell > b.availableToSell end)
    
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
    local flow = getAutoBuyResourceFlow(resource.gameName)
    
    -- Calculate target: we want flow to be at least AutoBuyTargetSurplus (e.g., 0.1)
    local targetFlow = Config.AutoBuyTargetSurplus
    
    -- If flow is already at or above target, no need to buy
    if flow >= targetFlow then
        return false, "Flow OK"
    end
    
    -- Calculate how much we need to reach the target surplus
    -- e.g., if flow is -0.5 and target is 0.1, we need 0.6
    local deficit = targetFlow - flow
    local currentBuying = getCurrentBuyAmount(resource.gameName)
    
    -- Calculate how much more we need to buy
    local neededAmount = deficit - currentBuying
    if neededAmount < Config.MinAmount then
        return false, "Already Buying"
    end
    
    UI.log(string.format("[AutoBuy] %s flow: %.2f, target: %.2f, need: %.2f", resource.gameName, flow, targetFlow, neededAmount), "info")
    
    -- Find countries selling this resource
    local sellers = findSellingCountries(resource.gameName)
    if #sellers == 0 then
        UI.log(string.format("[AutoBuy] No sellers for %s", resource.gameName), "warning")
        return false, "No Sellers"
    end
    
    local boughtTotal = 0
    
    for _, seller in ipairs(sellers) do
        if neededAmount <= 0 then break end
        
        local buyAmount = math.min(neededAmount, seller.availableToSell)
        if buyAmount < Config.MinAmount then continue end
        
        -- Calculate price tier based on their revenue
        local price = Helpers.getPriceTier(seller.revenue)
        
        UI.log(string.format("[AutoBuy] Buying %.2f %s from %s @ %.1fx", 
            buyAmount, resource.gameName, seller.name, price), "info")
        
        if attemptBuy(seller, resource.gameName, buyAmount, price) then
            UI.log(string.format("[AutoBuy] OK %s from %s", resource.gameName, seller.name), "success")
            boughtTotal = boughtTotal + buyAmount
            neededAmount = neededAmount - buyAmount
            M.purchases = M.purchases + 1
        else
            -- Try lower price tiers
            local nextPrice = Helpers.getNextPriceTier(price)
            while nextPrice do
                UI.log(string.format("[AutoBuy] Retry %s from %s @ %.1fx", resource.gameName, seller.name, nextPrice), "info")
                if attemptBuy(seller, resource.gameName, buyAmount, nextPrice) then
                    UI.log(string.format("[AutoBuy] OK %s from %s", resource.gameName, seller.name), "success")
                    boughtTotal = boughtTotal + buyAmount
                    neededAmount = neededAmount - buyAmount
                    M.purchases = M.purchases + 1
                    break
                end
                nextPrice = Helpers.getNextPriceTier(nextPrice)
            end
        end
        
        task.wait(Config.ResourceDelay)
    end
    
    if boughtTotal > 0 then
        return true, string.format("Bought %.2f", boughtTotal)
    end
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
