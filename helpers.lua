--[[
    HELPERS MODULE
    Multi-Resource Support
]]

local M = {}
local Config

-- Services
local Players = game:GetService("Players")
local CountryData = workspace:WaitForChild("CountryData")
local LocalPlayer = Players.LocalPlayer

-- Player cache
local playerCache = {}
local cacheTime = 0

-- Your country
M.myCountryName = LocalPlayer:GetAttribute("Country")
M.myCountry = M.myCountryName and CountryData:FindFirstChild(M.myCountryName)

function M.init(cfg)
    Config = cfg
end

-- Get enabled resources sorted by priority
function M.getEnabledResources()
    local enabled = {}
    for _, res in ipairs(Config.Resources) do
        if res.enabled then
            table.insert(enabled, res)
        end
    end
    table.sort(enabled, function(a, b) return a.priority < b.priority end)
    return enabled
end

function M.getResourceByName(name)
    for _, res in ipairs(Config.Resources) do
        if res.name == name then return res end
    end
    return nil
end

function M.refreshPlayerCache()
    if tick() - cacheTime < 10 then return end
    playerCache = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p:GetAttribute("Country")
        if c then playerCache[c] = true end
    end
    cacheTime = tick()
end

function M.isPlayerCountry(name)
    if not Config.SkipPlayerCountries then return false end
    M.refreshPlayerCache()
    return playerCache[name] == true
end

-- Get resource folder for a specific resource
function M.getResourceFolder(country, resourceGameName)
    if not country then return nil end
    local r = country:FindFirstChild("Resources")
    if not r then return nil end
    return r:FindFirstChild(resourceGameName)
end

-- Get flow for specific resource
function M.getFlow(resource)
    local res = M.getResourceFolder(M.myCountry, resource.gameName)
    if not res then return 0 end
    local f = res:FindFirstChild("Flow")
    return f and f.Value or 0
end

-- Get available flow for specific resource
function M.getAvailableFlow(resource)
    if not Config.SmartSell then return 999999 end
    return math.max(0, M.getFlow(resource) - Config.SmartSellReserve)
end

-- Get total flow across all enabled resources
function M.getTotalFlow()
    local total = 0
    for _, res in ipairs(M.getEnabledResources()) do
        total = total + M.getFlow(res)
    end
    return total
end

-- Get total available flow across all enabled resources
function M.getTotalAvailableFlow()
    local total = 0
    for _, res in ipairs(M.getEnabledResources()) do
        total = total + M.getAvailableFlow(res)
    end
    return total
end

-- Get buyers for specific resource
function M.getBuyers(resource)
    local res = M.getResourceFolder(M.myCountry, resource.gameName)
    if not res then return {} end
    local t = res:FindFirstChild("Trade")
    if not t then return {} end
    
    local buyers = {}
    for _, obj in ipairs(t:GetChildren()) do
        if obj:IsA("Vector3Value") and obj.Value.X < -0.01 and obj.Name ~= M.myCountryName then
            buyers[obj.Name] = math.abs(obj.Value.X)
        end
    end
    return buyers
end

-- Get total selling for specific resource
function M.getTotalSelling(resource)
    local total = 0
    for _, amt in pairs(M.getBuyers(resource)) do
        total = total + amt
    end
    return total
end

-- Get buyer count for specific resource
function M.getBuyerCount(resource)
    local count = 0
    for _ in pairs(M.getBuyers(resource)) do
        count = count + 1
    end
    return count
end

-- Get all buyers across all resources
function M.getAllBuyers()
    local allBuyers = {}
    for _, res in ipairs(M.getEnabledResources()) do
        allBuyers[res.name] = M.getBuyers(res)
    end
    return allBuyers
end

-- Get trade count for specific resource on a country
function M.getTradeCount(country, resourceGameName)
    local res = M.getResourceFolder(country, resourceGameName)
    if not res then return 0 end
    local t = res:FindFirstChild("Trade")
    if not t then return 0 end
    
    local count = 0
    for _, obj in ipairs(t:GetChildren()) do
        if obj:IsA("Vector3Value") then count = count + 1 end
    end
    return count
end

-- Get country data for specific resource
function M.getCountryResourceData(country, resource)
    local data = {valid = false, revenue = 0, balance = 0, flow = 0, buyAmount = 0, hasSell = false}
    
    local eco = country:FindFirstChild("Economy")
    if not eco then return data end
    local rev, bal = eco:FindFirstChild("Revenue"), eco:FindFirstChild("Balance")
    if not rev or not bal then return data end
    
    local res = M.getResourceFolder(country, resource.gameName)
    if not res then return data end
    local trade = res:FindFirstChild("Trade")
    if not trade then return data end
    
    data.valid = true
    data.revenue = rev:GetAttribute("Total") or 0
    data.balance = bal.Value or 0
    data.flow = res:FindFirstChild("Flow") and res.Flow.Value or 0
    
    for _, obj in ipairs(trade:GetChildren()) do
        if obj:IsA("Vector3Value") then
            if obj.Value.X > 0.01 then data.buyAmount = data.buyAmount + obj.Value.X
            elseif obj.Value.X < -0.01 then data.hasSell = true end
        end
    end
    return data
end

function M.getPriceTier(revenue)
    if revenue >= 1000000 then return 1.0
    elseif revenue >= 500000 then return 0.7
    elseif revenue >= 200000 then return 0.5
    else return 0.3 end
end

function M.getNextPriceTier(current)
    if current >= 1.0 then return 0.7
    elseif current >= 0.7 then return 0.5
    elseif current >= 0.5 then return 0.3
    else return nil end
end

function M.getCountries()
    local countries = CountryData:GetChildren()
    table.sort(countries, function(a, b)
        local aRev = a:FindFirstChild("Economy") and a.Economy:FindFirstChild("Revenue") and a.Economy.Revenue:GetAttribute("Total") or 0
        local bRev = b:FindFirstChild("Economy") and b.Economy:FindFirstChild("Revenue") and b.Economy.Revenue:GetAttribute("Total") or 0
        return aRev > bRev
    end)
    return countries
end

-- Get my country's balance (for debt check)
function M.getMyBalance()
    if not M.myCountry then return 0 end
    local eco = M.myCountry:FindFirstChild("Economy")
    if not eco then return 0 end
    local bal = eco:FindFirstChild("Balance")
    if not bal then return 0 end
    return bal.Value or 0
end

-- Check if player is in debt
function M.isInDebt()
    return M.getMyBalance() < 0
end

-- Get all cities controlled by the player's country
function M.getControlledCities()
    local cities = {}
    if not M.myCountryName then return cities end
    
    local baseplate = workspace:FindFirstChild("Baseplate")
    if not baseplate then return cities end
    
    local citiesFolder = baseplate:FindFirstChild("Cities")
    if not citiesFolder then return cities end
    
    local countryFolder = citiesFolder:FindFirstChild(M.myCountryName)
    if not countryFolder then return cities end
    
    for _, city in ipairs(countryFolder:GetChildren()) do
        table.insert(cities, city)
    end
    
    return cities
end

-- Count factories of a specific type across all controlled cities
function M.countFactories(factoryType)
    local count = 0
    local cities = M.getControlledCities()
    
    for _, city in ipairs(cities) do
        local buildings = city:FindFirstChild("Buildings")
        if buildings then
            local factory = buildings:FindFirstChild(factoryType)
            if factory then
                count = count + 1
            end
        end
    end
    
    return count
end

-- Get all factory counts across controlled cities
function M.getAllFactoryCounts()
    local factoryCounts = {}
    local cities = M.getControlledCities()
    
    for _, city in ipairs(cities) do
        local buildings = city:FindFirstChild("Buildings")
        if buildings then
            for _, building in ipairs(buildings:GetChildren()) do
                local name = building.Name
                factoryCounts[name] = (factoryCounts[name] or 0) + 1
            end
        end
    end
    
    return factoryCounts
end

-- Calculate total resource requirements based on factory counts
function M.getFactoryResourceRequirements()
    local requirements = {}
    local factoryCounts = M.getAllFactoryCounts()
    
    for factoryType, count in pairs(factoryCounts) do
        local factoryReqs = Config.FactoryRequirements[factoryType]
        if factoryReqs then
            for _, req in ipairs(factoryReqs) do
                local resourceName = req.resource
                local amountPerFactory = req.amount
                requirements[resourceName] = (requirements[resourceName] or 0) + (count * amountPerFactory)
            end
        else
            -- Log unknown factory types to help identify missing config entries
            print(string.format("[Helpers] Unknown factory type: %s (count: %d) - not in FactoryRequirements config", factoryType, count))
        end
    end
    
    return requirements
end

-- Get required amount for a specific resource based on factories
function M.getRequiredResourceAmount(resourceGameName)
    local requirements = M.getFactoryResourceRequirements()
    return requirements[resourceGameName] or 0
end

-- Check if we need to buy a resource based on factory requirements
-- Returns: needed amount (positive if we need to buy, 0 or negative if we have enough)
function M.getResourceDeficit(resourceGameName)
    local requiredAmount = M.getRequiredResourceAmount(resourceGameName)
    if requiredAmount <= 0 then
        return 0 -- No factories need this resource
    end
    
    -- Get current resource flow (production)
    local res = M.getResourceFolder(M.myCountry, resourceGameName)
    if not res then return requiredAmount end -- No resource folder, need full amount
    
    local flowObj = res:FindFirstChild("Flow")
    local currentFlow = flowObj and flowObj.Value or 0
    
    -- Deficit = what factories need minus what we're producing
    -- Positive means we need more, negative means we have surplus
    return requiredAmount - currentFlow
end

return M
