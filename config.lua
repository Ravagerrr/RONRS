--[[
    CONFIG MODULE
    Multi-Resource Trading
]]

return {
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
    -- MaxRetryPasses: 2 retries needed for full sequence (0.5 -> 0.2 -> 0.1)
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
    
    -- Debug
    -- Enable to log detailed country info at start of each trade run
    DebugLogging = true,
    
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
    AutoBuyStopAtPositiveFlow = 1,  -- Stop auto-buying when flow reaches this positive value (e.g., 1 means stop when flow >= 1)
    AutoBuyResources = {
        {name = "Tungsten", gameName = "Tungsten", enabled = true},
        {name = "Titanium", gameName = "Titanium", enabled = true},
        {name = "Phosphate", gameName = "Phosphate", enabled = true},
        {name = "Iron", gameName = "Iron", enabled = true},
        {name = "Gold", gameName = "Gold", enabled = true},
        {name = "Copper", gameName = "Copper", enabled = true},
    },
}
