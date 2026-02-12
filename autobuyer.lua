--[[
    AUTOBUYER MODULE v1.6
    Auto-buy Monitor for Resource Flow Protection
    
    Checks factory consumption and falls back to flow-based check.
    Only buys if: 1) Factory needs the resource, or 2) Flow is negative.
]]

local M = {}
local Config, State, Helpers, UI

-- Lazy-load ManageAlliance to avoid nil errors during module load
local ManageAlliance = nil
local function getManageAlliance()
    if not ManageAlliance then
        local GameManager = workspace:FindFirstChild("GameManager")
        if GameManager then
            ManageAlliance = GameManager:FindFirstChild("ManageAlliance")
        end
    end
    return ManageAlliance
end

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
        table.insert(sellers, {
            country = country,
            name = country.Name,
            flow = flow,
            revenue = revenue
        })
    end
    
    -- Sort by flow (highest first) - prefer countries with most production
    table.sort(sellers, function(a, b) return a.flow > b.flow end)
    
    return sellers
end

-- Get current trade amount with a specific seller (0 if no trade exists)
local function getCurrentTradeAmount(resourceGameName, sellerName)
    local res = Helpers.getResourceFolder(Helpers.myCountry, resourceGameName)
    if not res then return 0 end
    local trade = res:FindFirstChild("Trade")
    if not trade then return 0 end
    
    for _, obj in ipairs(trade:GetChildren()) do
        if obj:IsA("Vector3Value") and obj.Name == sellerName and obj.Value.X > 0 then
            return obj.Value.X
        end
    end
    return 0
end

-- Attempt to buy from a country
-- Returns the actual amount bought (difference from before), or 0 if failed
local function attemptBuy(seller, resourceGameName, amount, price)
    -- Record trade amount BEFORE the request
    local beforeAmount = getCurrentTradeAmount(resourceGameName, seller.name)
    
    pcall(function()
        local alliance = getManageAlliance()
        if alliance then
            alliance:FireServer(seller.name, "ResourceTrade", {resourceGameName, "Buy", amount, price, "Trade"})
        end
    end)
    
    -- Fast polling: check frequently for trade verification
    -- Configurable via Config.AutoBuyPollInterval and Config.AutoBuyMaxPolls
    local maxPolls = Config.AutoBuyMaxPolls or 3
    local pollInterval = Config.AutoBuyPollInterval or 0.1
    
    for poll = 1, maxPolls do
        task.wait(pollInterval)
        
        -- Get trade amount AFTER the request
        local afterAmount = getCurrentTradeAmount(resourceGameName, seller.name)
        
        -- Check if trade amount increased
        if afterAmount > beforeAmount then
            -- Return the DIFFERENCE (how much we actually bought this time)
            return afterAmount - beforeAmount
        end
    end
    
    return 0  -- Failed - no trade increase detected
end

-- Check and buy for a single resource
local function checkAndBuyResource(resource)
    local flowBefore = getAutoBuyResourceFlow(resource.gameName)
    
    -- Stop auto-buying if flow is already at or above the positive threshold
    -- This prevents buying when we're already in a positive flow state
    -- Fallback to 1 as safety measure if config is not properly loaded
    local stopThreshold = Config.AutoBuyStopAtPositiveFlow or 1
    if flowBefore >= stopThreshold then
        return false, "Positive Flow"
    end
    
    -- Calculate target: we want flow to be at least AutoBuyTargetSurplus (e.g., 0.1)
    local targetFlow = Config.AutoBuyTargetSurplus or 0.1
    
    -- Check factory resource consumption - detects factories that consume resources
    -- e.g., Electronics Factory consumes Titanium, Copper, and Gold
    local factoryConsumption = Helpers.getFactoryConsumption(resource.gameName)
    
    -- SIMPLIFIED LOGIC:
    -- Flow already reflects: production - consumption + incoming trades
    -- So if flow is negative or below target, we need to buy more
    -- If factories are consuming and flow is below target, buy to reach target
    
    local neededAmount = 0
    
    if factoryConsumption > 0 then
        -- Factory mode: factory is non-operational and needs resources
        -- factoryConsumption = how much the factory needs to become operational
        -- We need to buy: factoryConsumption + targetFlow - flowBefore
        -- Example: factory needs 10, flow = 0, target = 1 → need = 10 + 1 - 0 = 11
        -- Example: factory needs 10, flow = -2, target = 1 → need = 10 + 1 - (-2) = 13
        neededAmount = factoryConsumption + targetFlow - flowBefore
    else
        -- Fallback to flow-based check if no factory consumption exists
        -- Only trigger if flow is NEGATIVE (actively consuming the resource)
        -- If flow is >= 0 and no factory need detected, we don't need this resource
        if flowBefore >= 0 then
            return false, "No Need"
        end
        -- Flow is negative - we're consuming more than producing
        -- Buy enough to bring flow to target surplus
        neededAmount = targetFlow - flowBefore  -- e.g., 0.1 - (-5) = 5.1
    end
    
    if neededAmount <= 0 then
        return false, "No Deficit"
    end
    
    if neededAmount < Config.MinAmount then
        return false, "Needed amount too small"
    end
    
    -- Log to UI when actually buying
    if factoryConsumption > 0 then
        UI.log(string.format("[AutoBuy] %s need: %.2f (factory: %.2f, flow: %.2f, target: %.2f)", 
            resource.gameName, neededAmount, factoryConsumption, flowBefore, targetFlow), "info")
    else
        UI.log(string.format("[AutoBuy] %s flow: %.2f, target: %.2f, need: %.2f", resource.gameName, flowBefore, targetFlow, neededAmount), "info")
    end
    
    -- Find AI NPC countries selling this resource
    local sellers = findSellingCountries(resource.gameName)
    if #sellers == 0 then
        UI.log(string.format("[AutoBuy] No sellers for %s", resource.gameName), "warning")
        return false, "No Sellers"
    end
    
    local boughtTotal = 0
    local remainingNeed = neededAmount  -- Track remaining need during loop (neededAmount preserved for final summary)
    
    -- Start blocking AlertPopup during script trades
    Helpers.startScriptTrade()
    
    for idx, seller in ipairs(sellers) do
        -- Check if auto-buy was disabled mid-operation
        if not M.isMonitoring or not Config.AutoBuyEnabled then
            break
        end
        
        if remainingNeed <= 0 then 
            break 
        end
        
        -- Limit buy amount to the seller's available flow
        -- This prevents failed trades when requesting more than seller can provide
        local buyAmount = math.min(remainingNeed, seller.flow)
        
        if buyAmount < Config.MinAmount then 
            continue 
        end
        
        -- AI NPCs ALWAYS use 1.0x price - they don't accept discounts when selling
        local price = 1.0
        
        UI.log(string.format("[AutoBuy] Buying %.2f %s from %s @ %.1fx (seller flow: %.2f)", 
            buyAmount, resource.gameName, seller.name, price, seller.flow), "info")
        
        -- attemptBuy now returns ACTUAL amount bought (not just true/false)
        local actualBought = attemptBuy(seller, resource.gameName, buyAmount, price)
        
        if actualBought > 0 then
            boughtTotal = boughtTotal + actualBought
            remainingNeed = remainingNeed - actualBought
            M.purchases = M.purchases + 1
            
            -- Log actual amount vs requested
            if actualBought < buyAmount then
                UI.log(string.format("[AutoBuy] Partial: got %.2f/%.2f %s from %s", 
                    actualBought, buyAmount, resource.gameName, seller.name), "warning")
                -- DON'T break - continue to next seller to get remaining amount
            else
                UI.log(string.format("[AutoBuy] OK %.2f %s from %s", 
                    actualBought, resource.gameName, seller.name), "success")
                -- If we still need more, continue to next seller
                if remainingNeed > 0 then
                    continue
                end
                -- Full amount received, exit loop
                break
            end
        else
            -- AI NPCs don't accept flexibility - if 1.0x fails, move to next seller
            UI.log(string.format("[AutoBuy] Failed %s from %s, trying next", resource.gameName, seller.name), "warning")
        end
        
        -- Delay between seller attempts (configurable, default 0.2s for fast buying)
        task.wait(Config.AutoBuyRetryDelay or 0.2)
    end
    
    -- Stop blocking AlertPopup after script trades complete
    Helpers.stopScriptTrade()
    
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
    -- Refresh country in case player switched or just selected one
    Helpers.refreshMyCountry()
    
    -- Skip if no country selected
    if not Helpers.hasCountry() then
        return
    end
    
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
    Config.AutoBuyEnabled = true  -- Ensure config matches our state
    UI.log("Auto-Buy: ON", "info")
    
    task.spawn(function()
        -- Small delay to let config stabilize after start (prevents race condition with Rayfield)
        task.wait(0.2)
        
        while M.isMonitoring do
            if not Config.AutoBuyEnabled then
                M.isMonitoring = false
                UI.log("Auto-Buy: OFF", "warning")
                break
            end
            
            UI.updateAutoBuy()
            
            -- Factory material purchases are PRIORITY - run even during sell cycles
            -- This ensures factories never run out of materials due to long sell cycles
            -- The sell cycle uses "Sell" trades, auto-buy uses "Buy" trades - they don't conflict
            M.runCheck()
            
            task.wait(Config.AutoBuyCheckInterval)
        end
        
        UI.updateAutoBuy()
    end)
end

function M.stop()
    M.isMonitoring = false
    -- Ensure AlertPopup blocking is disabled when auto-buy stops
    Helpers.stopScriptTrade()
    UI.updateAutoBuy()
end

return M
