--[[
    WAR MONITOR MODULE
    Detects when countries are justifying war against you
    
    War justifications appear in: workspace.CountryData.[YourCountry].Diplomacy.Actions.[EnemyCountry]
    If any country appears in the Actions folder, they are justifying war against you.
]]

local M = {}
local Config, State, Helpers, UI

-- Services
local StarterGui = game:GetService("StarterGui")

M.isMonitoring = false
M.knownJustifications = {}  -- Track known justifications to avoid repeat notifications

function M.init(cfg, state, helpers, ui)
    Config = cfg
    State = state
    Helpers = helpers
    UI = ui
end

-- Send a Roblox notification
local function sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5
        })
    end)
end

-- Check for new war justifications
function M.checkJustifications()
    -- Refresh country in case player switched
    Helpers.refreshMyCountry()
    
    -- Skip if no country selected
    if not Helpers.hasCountry() then
        return
    end
    
    local currentJustifications = Helpers.getWarJustifications()
    
    -- Check for new justifications (countries we haven't seen before)
    for _, countryName in ipairs(currentJustifications) do
        if not M.knownJustifications[countryName] then
            -- New justification detected!
            M.knownJustifications[countryName] = true
            
            local message = string.format("%s is justifying war against you!", countryName)
            UI.log(message, "warning")
            
            -- Send a Roblox notification
            sendNotification("WAR ALERT", countryName .. " is justifying war!", 10)
        end
    end
    
    -- Clean up justifications that are no longer active
    -- (Country finished justifying or cancelled)
    local currentSet = {}
    for _, name in ipairs(currentJustifications) do
        currentSet[name] = true
    end
    
    for countryName, _ in pairs(M.knownJustifications) do
        if not currentSet[countryName] then
            M.knownJustifications[countryName] = nil
            UI.log(string.format("%s stopped justifying war", countryName), "info")
        end
    end
end

-- Get count of active war justifications
function M.getJustificationCount()
    local count = 0
    for _ in pairs(M.knownJustifications) do
        count = count + 1
    end
    return count
end

-- Get list of countries currently justifying war
function M.getActiveJustifications()
    local list = {}
    for countryName, _ in pairs(M.knownJustifications) do
        table.insert(list, countryName)
    end
    return list
end

function M.start()
    if M.isMonitoring then return end
    M.isMonitoring = true
    Config.WarMonitorEnabled = true
    UI.log("War Monitor: ON", "info")
    
    -- Clear known justifications on start to re-check everything
    M.knownJustifications = {}
    
    task.spawn(function()
        -- Small delay to let config stabilize
        task.wait(0.2)
        
        while M.isMonitoring do
            if not Config.WarMonitorEnabled then
                M.isMonitoring = false
                UI.log("War Monitor: OFF", "warning")
                break
            end
            
            M.checkJustifications()
            
            task.wait(Config.WarMonitorCheckInterval)
        end
    end)
end

function M.stop()
    M.isMonitoring = false
end

return M
