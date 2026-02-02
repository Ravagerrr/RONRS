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
    
    -- Flow Queue: Queue trades when flow is insufficient and retry when flow becomes available
    -- When a trade is limited by flow protection, queue the remaining amount to try later
    FlowQueueEnabled = true,
    FlowQueueTimeout = 30,  -- Seconds before a queued trade expires (0 = never expire)
    
    -- Revenue Spending Limit (Dynamic based on country size)
    -- Bigger countries are more lenient with high cost/revenue ratios
    -- Smaller countries are stricter and reject trades approaching their revenue limit
    -- These values define the spending percentage allowed at different revenue tiers
    MaxRevenueSpendingPercent = 0.35,  -- Default/fallback (used if dynamic calc disabled)
    
    -- Dynamic spending limits based on country revenue
    -- Format: {minRevenue, maxSpendingPercent}
    -- Countries with revenue >= minRevenue can spend up to maxSpendingPercent
    -- Tiers are checked from highest to lowest revenue
    -- CALIBRATED: Brazil ($12.4M revenue) accepted 60 units = 39.8% spending
    -- Using conservative values below actual observed limits for safety margin
    RevenueSpendingTiers = {
        {10000000, 0.38},  -- $10M+ revenue: can spend up to 38%
        {5000000, 0.35},   -- $5M+ revenue: can spend up to 35%
        {1000000, 0.32},   -- $1M+ revenue: can spend up to 32%
        {500000, 0.28},    -- $500K+ revenue: can spend up to 28%
        {100000, 0.25},    -- $100K+ revenue: can spend up to 25%
        {0, 0.20},         -- Below $100K: can spend up to 20%
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
    
    -- Auto-Buy Priority: Factory materials are now ALWAYS prioritized
    -- Auto-buy runs even during sell cycles to prevent factory material shortages
    -- This ensures your factories never run out of materials due to long-running sell operations
    
    AutoBuyResources = {
        {name = "Tungsten", gameName = "Tungsten", enabled = true},
        {name = "Titanium", gameName = "Titanium", enabled = true},
        {name = "Phosphate", gameName = "Phosphate", enabled = true},
        {name = "Iron", gameName = "Iron", enabled = true},
        {name = "Gold", gameName = "Gold", enabled = true},
        {name = "Copper", gameName = "Copper", enabled = true},
    },
}
