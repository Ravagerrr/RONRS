--[[
    WAR MONITOR MODULE
    Detects when countries are justifying war against you
    
    War justifications appear in: workspace.CountryData.[OtherCountry].Diplomacy.Actions.[YourCountry]
    If your country appears in another country's Actions folder, they are justifying war against you.
    When they finish justifying (disappear from Actions), they can declare war at any moment.
]]

local M = {}
local Config, State, Helpers, UI

-- Services
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

M.isMonitoring = false
M.knownJustifications = {}  -- Countries currently justifying war
M.readyToDeclare = {}       -- Countries that finished justifying and can declare at any moment

function M.init(cfg, state, helpers, ui)
    Config = cfg
    State = state
    Helpers = helpers
    UI = ui
end

-- Play alert sound
local function playAlertSound()
    pcall(function()
        -- Create a sound and play it
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://9116367462"  -- Alert/warning sound
        sound.Volume = 1
        sound.Parent = SoundService
        sound:Play()
        -- Clean up after playing
        task.delay(3, function()
            if sound then sound:Destroy() end
        end)
    end)
end

-- Send a Roblox notification with sound
local function sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5
        })
    end)
    -- Play alert sound
    playAlertSound()
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
        if not M.knownJustifications[countryName] and not M.readyToDeclare[countryName] then
            -- New justification detected!
            M.knownJustifications[countryName] = true
            
            local message = string.format("%s is justifying war against you!", countryName)
            UI.log(message, "warning")
            
            -- Send a Roblox notification with sound
            sendNotification("WAR ALERT", countryName .. " is justifying war!", 10)
        end
    end
    
    -- Check for countries that finished justifying (can now declare war at any moment)
    local currentSet = {}
    for _, name in ipairs(currentJustifications) do
        currentSet[name] = true
    end
    
    for countryName, _ in pairs(M.knownJustifications) do
        if not currentSet[countryName] then
            -- Country finished justifying - they can now declare war!
            M.knownJustifications[countryName] = nil
            M.readyToDeclare[countryName] = true
            
            local message = string.format("%s can now declare war at any moment!", countryName)
            UI.log(message, "warning")
            
            -- Send urgent notification with sound
            sendNotification("WAR READY", countryName .. " can declare war!", 15)
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

-- Get count of countries ready to declare war
function M.getReadyToDecareCount()
    local count = 0
    for _ in pairs(M.readyToDeclare) do
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

-- Get list of countries ready to declare war
function M.getReadyToDeclare()
    local list = {}
    for countryName, _ in pairs(M.readyToDeclare) do
        table.insert(list, countryName)
    end
    return list
end

-- Clear a country from ready-to-declare list (e.g., after war starts or threat passes)
function M.clearReadyToDeclare(countryName)
    if M.readyToDeclare[countryName] then
        M.readyToDeclare[countryName] = nil
        UI.log(string.format("Cleared %s from war threat list", countryName), "info")
    end
end

function M.start()
    if M.isMonitoring then return end
    M.isMonitoring = true
    Config.WarMonitorEnabled = true
    UI.log("War Monitor: ON", "info")
    
    -- Clear known justifications on start to re-check everything
    -- Keep readyToDeclare so we don't lose track of imminent threats
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
