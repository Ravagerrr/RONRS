--[[
    CONFIG MODULE
    Edit this file to change settings
]]

return {
    -- Trading
    BuyPrice = 102000,
    MaxAmount = 5,
    MinAmount = 0.001,
    WaitTime = 0.5,
    
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
