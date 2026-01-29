--[[
    HELPERS MODULE
    Utility functions for trading
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

function M.getMyFlow()
    if not M.myCountry then return 0 end
    local r = M.myCountry:FindFirstChild("Resources")
    if not r then return 0 end
    local e = r:FindFirstChild("Electronics")
    if not e then return 0 end
    local f = e:FindFirstChild("Flow")
    return f and f.Value or 0
end

function M.getAvailableFlow()
    if not Config.SmartSell then return 999999 end
    return math.max(0, M.getMyFlow() - Config.SmartSellReserve)
end

function M.getMyBuyers()
    if not M.myCountry then return {} end
    local r = M.myCountry:FindFirstChild("Resources")
    if not r then return {} end
    local e = r:FindFirstChild("Electronics")
    if not e then return {} end
    local t = e:FindFirstChild("Trade")
    if not t then return {} end
    
    local buyers = {}
    for _, obj in ipairs(t:GetChildren()) do
        if obj:IsA("Vector3Value") and obj.Value.X < -0.01 and obj.Name ~= M.myCountryName then
            buyers[obj.Name] = math.abs(obj.Value.X)
        end
    end
    return buyers
end

function M.getTradeCount(country)
    local r = country:FindFirstChild("Resources")
    if not r then return 0 end
    local e = r:FindFirstChild("Electronics")
    if not e then return 0 end
    local t = e:FindFirstChild("Trade")
    if not t then return 0 end
    
    local count = 0
    for _, obj in ipairs(t:GetChildren()) do
        if obj:IsA("Vector3Value") then count = count + 1 end
    end
    return count
end

function M.getCountryData(country)
    local data = {valid = false, revenue = 0, balance = 0, flow = 0, buyAmount = 0, hasSell = false}
    
    local eco = country:FindFirstChild("Economy")
    if not eco then return data end
    local rev, bal = eco:FindFirstChild("Revenue"), eco:FindFirstChild("Balance")
    if not rev or not bal then return data end
    
    local res = country:FindFirstChild("Resources")
    if not res then return data end
    local elec = res:FindFirstChild("Electronics")
    if not elec then return data end
    local trade = elec:FindFirstChild("Trade")
    if not trade then return data end
    
    data.valid = true
    data.revenue = rev:GetAttribute("Total") or 0
    data.balance = bal.Value or 0
    data.flow = elec:FindFirstChild("Flow") and elec.Flow.Value or 0
    
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

return M
