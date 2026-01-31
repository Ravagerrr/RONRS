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

-- Check if we are currently selling a resource to a specific country
-- Returns the amount being sold, or 0 if no trade exists
function M.getSellingAmountTo(resourceGameName, countryName)
    local res = M.getResourceFolder(M.myCountry, resourceGameName)
    if not res then return 0 end
    local t = res:FindFirstChild("Trade")
    if not t then return 0 end
    
    local tradeEntry = t:FindFirstChild(countryName)
    if tradeEntry and tradeEntry:IsA("Vector3Value") and tradeEntry.Value.X < -0.01 then
        return math.abs(tradeEntry.Value.X)
    end
    return 0
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
    -- Start all countries at 1.0x (full price) to maximize revenue
    return 1.0
end

function M.getNextPriceTier(current)
    -- Retry sequence: 1.0 -> 0.5 -> 0.1 -> nil
    if current >= 1.0 then return 0.5
    elseif current >= 0.5 then return 0.1
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

-- Get total resource deficit across all controlled cities
-- Reads from workspace.Baseplate.Cities.[Country].[City].Resources attributes
-- The game stores deficits directly as attributes (e.g., Iron = -4 means we need 4 more Iron)
function M.getTotalCityResourceDeficit(resourceGameName)
    local totalDeficit = 0
    local cities = M.getControlledCities()
    
    for _, city in ipairs(cities) do
        local resources = city:FindFirstChild("Resources")
        if resources then
            -- The game stores the deficit as an attribute on the Resources folder
            -- Negative values mean we need that resource (deficit)
            local deficit = resources:GetAttribute(resourceGameName)
            if deficit and deficit < 0 then
                -- Deficit is negative in the game, so we convert to positive "need" amount
                totalDeficit = totalDeficit + math.abs(deficit)
            end
        end
    end
    
    return totalDeficit
end

-- Get all resource deficits across all controlled cities
function M.getAllCityResourceDeficits()
    local deficits = {}
    local cities = M.getControlledCities()
    
    for _, city in ipairs(cities) do
        local resources = city:FindFirstChild("Resources")
        if resources then
            -- Get all attributes from the Resources folder
            -- GetAttributes() returns a dictionary {name = value}, use pairs() to iterate
            for attrName, value in pairs(resources:GetAttributes()) do
                if value and type(value) == "number" and value < 0 then
                    -- Negative values are deficits
                    deficits[attrName] = (deficits[attrName] or 0) + math.abs(value)
                end
            end
        end
    end
    
    return deficits
end

-- Check if we need to buy a resource based on city resource deficits
-- Returns: deficit amount (positive if we need to buy, 0 if no deficit)
function M.getResourceDeficit(resourceGameName)
    return M.getTotalCityResourceDeficit(resourceGameName)
end

-- Factory consumption rates per factory type (FALLBACK ONLY)
-- Maps factory type names to resources they consume and the rate per factory
-- 
-- NOTE: These are fallback rates used ONLY if factory doesn't have Operational_Reason attribute.
-- The preferred method reads actual demands from factory's Operational_Reason attribute.
-- Format: "ResourceName [Need: X]" e.g., "Gold [Need: 2]"
M.FactoryConsumption = {
    ["Electronics Factory"] = {
        ["Titanium"] = 1,
        ["Copper"] = 1,
    },
    ["Consumer Goods Factory"] = {
        ["Iron"] = 1,
        ["Copper"] = 1,
    },
    ["Steel Mill"] = {
        ["Iron"] = 2,
    },
    ["Ammunition Factory"] = {
        ["Iron"] = 1,
        ["Copper"] = 1,
    },
    ["Weapons Factory"] = {
        ["Iron"] = 2,
        ["Titanium"] = 1,
    },
    ["Fertilizer Factory"] = {
        ["Phosphate"] = 1,
    },
    ["Advanced Electronics Factory"] = {
        ["Tungsten"] = 1,
        ["Copper"] = 1,
    },
    ["Military Equipment Factory"] = {
        ["Tungsten"] = 1,
        ["Iron"] = 1,
    },
}

-- Parse factory Operational_Reason attribute to extract resource demands
-- Format: "ResourceName [Need: X]" e.g., "Gold [Need: 2]", "Titanium [Need: 5]"
-- Returns: table mapping resourceName to amount needed, or nil if not parseable
function M.parseOperationalReason(operationalReason)
    if not operationalReason or type(operationalReason) ~= "string" then
        return nil
    end
    
    -- Pattern: "ResourceName [Need: X]"
    -- Use non-greedy (.-) to capture resource name up to the bracket
    local resourceName, amount = string.match(operationalReason, "^(.-)%s*%[Need:%s*(%d+)%]")
    
    if resourceName and amount and resourceName ~= "" then
        return {
            [resourceName] = tonumber(amount)
        }
    end
    
    return nil
end

-- Get resource demands from a factory's attributes
-- Reads Operational_Reason attribute to get actual demand
-- Falls back to hardcoded FactoryConsumption if attribute not found
function M.getFactoryDemands(factory)
    if not factory.instance then
        return M.FactoryConsumption[factory.name] or {}
    end
    
    -- Try to read Operational_Reason attribute
    local operationalReason = factory.instance:GetAttribute("Operational_Reason")
    local parsedDemands = M.parseOperationalReason(operationalReason)
    
    if parsedDemands then
        return parsedDemands
    end
    
    -- Fallback to hardcoded consumption rates
    return M.FactoryConsumption[factory.name] or {}
end

-- Get all factories owned by the player's country
-- Searches in workspace.Baseplate.Cities.[Country].[City].Buildings for each controlled city
-- This function dynamically scans all cities each time it's called to detect newly built factories
function M.getFactories()
    local factories = {}
    if not M.myCountryName then return factories end
    
    -- Get all controlled cities and check each city's Buildings folder
    -- Path: workspace.Baseplate.Cities.[Country].[City].Buildings
    local cities = M.getControlledCities()
    
    for _, city in ipairs(cities) do
        local buildingsFolder = city:FindFirstChild("Buildings")
        if buildingsFolder then
            -- Check each building in the city's Buildings folder
            for _, obj in ipairs(buildingsFolder:GetChildren()) do
                -- Check if this is a factory we recognize
                local factoryType = obj.Name
                -- Also check for FactoryType attribute
                local typeAttr = obj:GetAttribute("FactoryType") or obj:GetAttribute("Type")
                if typeAttr then
                    factoryType = typeAttr
                end
                
                if M.FactoryConsumption[factoryType] then
                    table.insert(factories, {
                        name = factoryType,
                        instance = obj,
                        city = city.Name,
                    })
                else
                    -- Try partial matching for factory names (e.g., "Electronics Factory 1")
                    -- Use pattern anchoring to match from the start of the string
                    for knownFactory, _ in pairs(M.FactoryConsumption) do
                        -- Match full factory name at start (e.g., "Electronics Factory" in "Electronics Factory 1")
                        -- or match factory type without " Factory" suffix (e.g., "Electronics" in "Electronics 1")
                        local shortName = knownFactory:gsub(" Factory", ""):gsub(" Mill", "")
                        if string.find(obj.Name, "^" .. knownFactory) or string.find(obj.Name, "^" .. shortName) then
                            table.insert(factories, {
                                name = knownFactory,
                                instance = obj,
                                city = city.Name,
                            })
                            break
                        end
                    end
                end
            end
        end
    end
    
    return factories
end

-- Count factories by type
function M.getFactoryCounts()
    local counts = {}
    local factories = M.getFactories()
    
    for _, factory in ipairs(factories) do
        counts[factory.name] = (counts[factory.name] or 0) + 1
    end
    
    return counts
end

-- Calculate total resource consumption from all factories
-- Returns: table mapping resourceGameName to consumption amount
-- Reads actual demands from factory Operational_Reason attributes when available
function M.getFactoryResourceConsumption()
    local consumption = {}
    local factories = M.getFactories()
    
    -- Check each factory individually to read its actual demands
    for _, factory in ipairs(factories) do
        local demands = M.getFactoryDemands(factory)
        for resourceName, amount in pairs(demands) do
            consumption[resourceName] = (consumption[resourceName] or 0) + amount
        end
    end
    
    return consumption
end

-- Get factory consumption for a specific resource
-- Returns: consumption amount (positive number, represents how much is consumed)
function M.getFactoryConsumption(resourceGameName)
    local consumption = M.getFactoryResourceConsumption()
    return consumption[resourceGameName] or 0
end

-- Get total deficit including both city deficits AND factory consumption
-- This is the complete picture of what resources we need
function M.getTotalResourceNeed(resourceGameName)
    local cityDeficit = M.getTotalCityResourceDeficit(resourceGameName)
    local factoryConsumption = M.getFactoryConsumption(resourceGameName)
    return cityDeficit + factoryConsumption
end

return M
