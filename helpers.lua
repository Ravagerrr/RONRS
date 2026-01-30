--[[
    HELPERS MODULE
    Utility functions for trade calculations
]]

local M = {}

local Players = game:GetService("Players")
local CountryData = workspace:WaitForChild("CountryData")
local LocalPlayer = Players.LocalPlayer

-- Dynamic country detection (refreshes each call)
M.myCountryName = nil
M.myCountry = nil

function M.refreshMyCountry()
    -- Try to get country from attribute
    local name = LocalPlayer:GetAttribute("Country")
    
    -- If no attribute, try to find it another way
    if not name then
        -- Some games store it differently
        for _, country in ipairs(CountryData:GetChildren()) do
            local owner = country:GetAttribute("Owner")
            if owner == LocalPlayer.UserId or owner == LocalPlayer.Name then
                name = country.Name
                break
            end
        end
    end
    
    if name then
        M.myCountryName = name
        M.myCountry = CountryData:FindFirstChild(name)
    end
    
    return M.myCountry ~= nil
end

-- Initialize on load
M.refreshMyCountry()

-- Player cache for skip checks
local playerCountryCache = {}
local cacheTime = 0

function M.refreshPlayerCache()
    if tick() - cacheTime < 10 then return end
    playerCountryCache = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local c = player:GetAttribute("Country")
        if c then playerCountryCache[c] = true end
    end
    cacheTime = tick()
end

function M.isPlayerCountry(country)
    M.refreshPlayerCache()
    return playerCountryCache[country.Name] == true
end

function M.getMyFlow()
    -- Refresh country detection each time
    if not M.myCountry then
        M.refreshMyCountry()
    end
    if not M.myCountry then return 0 end
    
    local r = M.myCountry:FindFirstChild("Resources")
    if not r then return 0 end
    local e = r:FindFirstChild("Electronics")
    if not e then return 0 end
    local f = e:FindFirstChild("Flow")
    return f and f.Value or 0
end

function M.getAvailableFlow()
    local Config = M.Config or {SmartSellReserve = 1}
    return math.max(0, M.getMyFlow() - Config.SmartSellReserve)
end

function M.getMyBuyers()
    if not M.myCountry then
        M.refreshMyCountry()
    end
    if not M.myCountry then return {} end
    
    local r = M.myCountry:FindFirstChild("Resources")
    if not r then return {} end
    local e = r:FindFirstChild("Electronics")
    if not e then return {} end
    local t = e:FindFirstChild("Trade")
    if not t then return {} end
    
    local buyers = {}
    for _, obj in ipairs(t:GetChildren()) do
        if obj:IsA("Vector3Value") and obj.Value.X < -0.01 then
            if obj.Name ~= M.myCountryName then
                buyers[obj.Name] = math.abs(obj.Value.X)
            end
        end
    end
    return buyers
end

function M.getTotalSelling()
    local total = 0
    for _, amt in pairs(M.getMyBuyers()) do
        total = total + amt
    end
    return total
end

function M.getBuyerCount()
    local count = 0
    for _ in pairs(M.getMyBuyers()) do
        count = count + 1
    end
    return count
end

function M.getCountryFlow(country)
    local r = country:FindFirstChild("Resources")
    if not r then return 0 end
    local e = r:FindFirstChild("Electronics")
    if not e then return 0 end
    local f = e:FindFirstChild("Flow")
    return f and f.Value or 0
end

function M.getRevenue(country)
    local eco = country:FindFirstChild("Economy")
    if not eco then return 0 end
    local rev = eco:FindFirstChild("Revenue")
    if not rev then return 0 end
    return rev:GetAttribute("Total") or 0
end

function M.canTrade(country)
    local eco = country:FindFirstChild("Economy")
    if not eco then return false, "No Economy" end
    local rev = eco:FindFirstChild("Revenue")
    local bal = eco:FindFirstChild("Balance")
    if not rev or not bal then return false, "No Revenue/Balance" end
    if bal.Value <= 0 then return false, "Negative Balance" end
    
    local res = country:FindFirstChild("Resources")
    if not res then return false, "No Resources" end
    local elec = res:FindFirstChild("Electronics")
    if not elec then return false, "No Electronics" end
    local trade = elec:FindFirstChild("Trade")
    if not trade then return false, "No Trade" end
    
    return true, nil
end

function M.getTradingPartners(country)
    local r = country:FindFirstChild("Resources")
    if not r then return {} end
    local e = r:FindFirstChild("Electronics")
    if not e then return {} end
    local t = e:FindFirstChild("Trade")
    if not t then return {} end
    
    local partners = {}
    for _, obj in ipairs(t:GetChildren()) do
        if obj:IsA("Vector3Value") then
            table.insert(partners, obj)
        end
    end
    return partners
end

function M.getPriceTiers(country)
    local revenue = M.getRevenue(country)
    if revenue >= 1000000 then
        return {1.0, 0.7, 0.5, 0.3}
    elseif revenue >= 500000 then
        return {0.7, 0.5, 0.3}
    elseif revenue >= 200000 then
        return {0.5, 0.3}
    else
        return {0.3}
    end
end

function M.getSortedCountries()
    local countries = CountryData:GetChildren()
    table.sort(countries, function(a, b)
        return M.getRevenue(a) > M.getRevenue(b)
    end)
    return countries
end

return M
