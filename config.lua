--[[
    CONFIG MODULE
    All settings in one place
]]

return {
    -- Trading
    BuyPrice = 102000,
    MaxAmount = 5,
    MinAmount = 0.001,
    WaitTime = 0.5,
    
    -- Flow Protection
    SmartSell = true,
    SmartSellReserve = 1,
    
    -- Skip Filters
    SkipPlayerCountries = true,
    SkipExistingBuyers = true,
    SkipProducingCountries = true,
    SkipOwnCountry = true,
    
    -- Retry System
    RetryEnabled = true,
    MaxRetryPasses = 2,
    
    -- Auto-Sell
    AutoSellEnabled = true,
    AutoSellThreshold = 5,
}
