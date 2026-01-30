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
            enabled = true,
            priority = 1,  -- Lower = Higher priority
        },
        {
            name = "Electronics",
            gameName = "Electronics",
            buyPrice = 102000,
            enabled = true,
            priority = 2,
        },
    },
    
    -- Trading
    MaxAmount = 5,
    MinAmount = 0.001,
    WaitTime = 0.5,          -- Cooldown between trades
    ResourceDelay = 0.3,      -- Extra delay when switching resources
    
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
    
    -- Auto-Sell
    AutoSellEnabled = true,
    AutoSellThreshold = 5,
    AutoSellCheckInterval = 3,
}
