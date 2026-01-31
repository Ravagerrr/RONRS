--[[
    CONFIG MODULE
    Multi-Resource Trading
]]

return {
    -- Factory Requirements (resource consumption per factory per 5 days)
    -- Used to calculate actual resource needs based on factory counts
    FactoryRequirements = {
        ["Electronics Factory"] = {
            {resource = "Gold", amount = 2},
            {resource = "Copper", amount = 2},
        },
        ["Steel Factory"] = {
            {resource = "Iron", amount = 4},
            {resource = "Titanium", amount = 0.2},
        },
        ["Motor Factory"] = {
            {resource = "Steel", amount = 1},
            {resource = "Tungsten", amount = 2},
        },
        ["Fertilizer Factory"] = {
            {resource = "Phosphate", amount = 3.5},
        },
        ["Civilian Factory"] = {
            {resource = "Electronics", amount = 3},
            {resource = "Motor Parts", amount = 2.5},
            {resource = "Fertilizer", amount = 2.5},
        },
        ["Aircraft Factory"] = {
            {resource = "Aluminum", amount = 2},
            {resource = "Chromium", amount = 2},
            {resource = "Titanium", amount = 2},
        },
        ["Uranium Enricher"] = {
            {resource = "Uranium", amount = 20},
        },
    },
    
    -- Resource Settings
    Resources = {
        {
            name = "ConsumerGoods",
            gameName = "Consumer Goods",
            buyPrice = 82400,
            hasCap = false,        -- NO CAP - revenue only
            capAmount = nil,
            enabled = true,
            priority = 1,
        },
        {
            name = "Electronics",
            gameName = "Electronics",
            buyPrice = 102000,
            hasCap = true,         -- HAS CAP
            capAmount = 5,         -- Max 5
            enabled = true,
            priority = 2,
        },
    },
    
    -- Trading
    MinAmount = 0.001,
    WaitTime = 0.5,
    ResourceDelay = 0.3,
    
    -- Retry
    RetryEnabled = true,
    MaxRetryPasses = 2,
    
    -- Filters
    SkipPlayerCountries = true,
    SkipExistingBuyers = true,
    SkipProducingCountries = true,
    SkipOwnCountry = true,
    
    -- Flow Protection
    SmartSell = true,
    SmartSellReserve = 1,
    
    -- Revenue Spending Limit
    -- Countries won't spend more than this percentage of their revenue on a single trade
    -- 0.6 means 60% - prevents rejection when cost is too close to total revenue
    -- Valid range: 0.0 to 1.0 (0% to 100%). Recommended: 0.5-0.7 for better acceptance rates
    MaxRevenueSpendingPercent = 0.6,
    
    -- Auto-Sell
    AutoSellEnabled = true,
    AutoSellThreshold = 5,
    AutoSellCheckInterval = 0.5,  -- Fast real-time detection
    
    -- Auto-Buy (Flow Protection)
    -- Automatically buys resources when your country's flow goes negative
    AutoBuyEnabled = true,
    AutoBuyCheckInterval = 0.5,  -- Fast real-time detection
    AutoBuyTargetSurplus = 0.1,  -- Target flow surplus (buys to +0.1 instead of 0)
    AutoBuyRequireNoDebt = true,  -- Only auto-buy when not in debt (balance > 0)
    AutoBuyResources = {
        {name = "Tungsten", gameName = "Tungsten", enabled = true},
        {name = "Titanium", gameName = "Titanium", enabled = true},
        {name = "Phosphate", gameName = "Phosphate", enabled = true},
        {name = "Iron", gameName = "Iron", enabled = true},
        {name = "Gold", gameName = "Gold", enabled = true},
        {name = "Copper", gameName = "Copper", enabled = true},
    },
}
