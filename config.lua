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
    
    -- Minimum Demand Threshold
    -- Skip countries with flow >= this value (no meaningful demand)
    -- Countries need negative flow (consuming) to actually want to buy
    -- Set to small negative value like -0.1 to ensure real demand exists
    MinDemandFlow = -0.1,
    
    -- Flow Protection
    SmartSell = true,
    SmartSellReserve = 1,
    
    -- Revenue Spending Limit (Dynamic based on country size)
    -- Bigger countries are more lenient with high cost/revenue ratios
    -- Smaller countries are stricter and reject trades approaching their revenue limit
    -- These values define the spending percentage allowed at different revenue tiers
    MaxRevenueSpendingPercent = 0.6,  -- Default/fallback (used if dynamic calc disabled)
    
    -- Dynamic spending limits based on country revenue
    -- Format: {minRevenue, maxSpendingPercent}
    -- Countries with revenue >= minRevenue can spend up to maxSpendingPercent
    -- Tiers are checked from highest to lowest revenue
    -- These values are based on game behavior: larger countries are more lenient
    -- with high cost/revenue ratios, while smaller countries reject trades approaching their limits
    RevenueSpendingTiers = {
        {5000000, 0.85},   -- $5M+ revenue: can spend up to 85%
        {1000000, 0.75},   -- $1M+ revenue: can spend up to 75%
        {500000, 0.65},    -- $500K+ revenue: can spend up to 65%
        {100000, 0.55},    -- $100K+ revenue: can spend up to 55%
        {0, 0.45},         -- Below $100K: can spend up to 45%
    },
    
    -- Debug
    -- Enable to log detailed country info at start of each trade run
    DebugLogging = true,
    
    -- UI Log Settings
    -- Number of log entries to display in the UI (higher = more scrolling)
    LogDisplayCount = 100,
    
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
