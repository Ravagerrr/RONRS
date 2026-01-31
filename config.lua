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
