--[[
    DEBUG WORKSPACE SCRIPT (Lightweight Version with UI)
    Prints key game structures relevant to auto-buy debugging
    
    FIXED: Previous version froze game - now only explores relevant paths
    and yields frequently to prevent freezing.
    
    This script ONLY explores:
    - CountryData (for resources and economy)
    - GameManager (for trade functions)  
    - Baseplate (for cities, buildings, factories)
    
    It does NOT explore player characters, terrain, or other irrelevant objects.
    
    OUTPUT: Displays results in a Rayfield UI window for easy viewing.
]]

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create debug window
local Window = Rayfield:CreateWindow({
    Name = "Debug Workspace",
    LoadingTitle = "Loading Debug...",
    ConfigurationSaving = {Enabled = false}
})

local DebugTab = Window:CreateTab("Debug Output", 4483362458)
DebugTab:CreateSection("Status")

-- Log storage
local debugLogs = {}
local logParagraph = nil

-- Create log paragraph
logParagraph = DebugTab:CreateParagraph({
    Title = "Debug Output",
    Content = "Starting debug..."
})

-- Function to add log and update UI
local function debugLog(msg)
    table.insert(debugLogs, msg)
    -- Keep only last 50 lines to prevent UI from getting too long
    while #debugLogs > 50 do
        table.remove(debugLogs, 1)
    end
    -- Update UI
    local content = table.concat(debugLogs, "\n")
    pcall(function()
        logParagraph:Set({Title = "Debug Output", Content = content})
    end)
    -- Also print to console
    print(msg)
    task.wait() -- Yield after each log to keep UI responsive
end

-- Yield counter to prevent freezing
local yieldCounter = 0
local YIELD_EVERY = 20  -- Yield every N items (more frequent for UI updates)

local function maybeYield()
    yieldCounter = yieldCounter + 1
    if yieldCounter >= YIELD_EVERY then
        yieldCounter = 0
        task.wait()
    end
end

local function getAttributesString(instance)
    local attrs = instance:GetAttributes()
    local parts = {}
    for name, value in pairs(attrs) do
        local valStr
        if type(value) == "string" then
            valStr = string.format('"%s"', value)
        elseif type(value) == "boolean" then
            valStr = tostring(value)
        elseif type(value) == "number" then
            valStr = string.format("%.4g", value)
        else
            valStr = tostring(value)
        end
        table.insert(parts, string.format("%s=%s", name, valStr))
    end
    if #parts > 0 then
        return " {" .. table.concat(parts, ", ") .. "}"
    end
    return ""
end

local function getValueString(instance)
    -- Try to get Value property for ValueBase instances
    local success, value = pcall(function()
        return instance.Value
    end)
    if success and value ~= nil then
        if type(value) == "string" then
            return string.format(' Value="%s"', value)
        elseif type(value) == "boolean" then
            return string.format(' Value=%s', tostring(value))
        elseif type(value) == "number" then
            return string.format(' Value=%.4g', value)
        elseif typeof(value) == "Vector3" then
            return string.format(' Value=Vector3(%.4g, %.4g, %.4g)', value.X, value.Y, value.Z)
        elseif typeof(value) == "CFrame" then
            return string.format(' Value=CFrame(...)')
        else
            return string.format(' Value=%s', tostring(value))
        end
    end
    return ""
end

local function printInstance(instance, depth)
    maybeYield()
    local indent = string.rep("| ", depth)
    local className = instance.ClassName
    local name = instance.Name
    local attrs = getAttributesString(instance)
    local valueStr = getValueString(instance)
    
    debugLog(string.format("%s[%d] %s \"%s\"%s%s", indent, depth, className, name, valueStr, attrs))
end

local function exploreRecursive(instance, depth, maxDepth)
    if depth > maxDepth then
        local childCount = #instance:GetChildren()
        if childCount > 0 then
            local indent = string.rep("| ", depth)
            debugLog(string.format("%s... (%d more children, max depth reached)", indent, childCount))
        end
        return
    end
    
    printInstance(instance, depth)
    
    local children = instance:GetChildren()
    for _, child in ipairs(children) do
        exploreRecursive(child, depth + 1, maxDepth)
    end
end

-- Explore only specific paths that matter for auto-buy
local function exploreRelevantPath(path, maxDepth)
    local current = workspace
    local parts = string.split(path, ".")
    
    for i, part in ipairs(parts) do
        if part ~= "workspace" then
            current = current:FindFirstChild(part)
            if not current then
                debugLog(string.format("[NOT FOUND] %s (stopped at %s)", path, part))
                return
            end
        end
    end
    
    debugLog(string.format("\n=== %s ===", path))
    exploreRecursive(current, 0, maxDepth)
    task.wait() -- Yield after each section
end

-- Main execution
debugLog("═══════════════════════════════════")
debugLog("  DEBUG WORKSPACE")
debugLog("═══════════════════════════════════")
debugLog("")

-- Also specifically look for key paths relevant to auto-buying
debugLog("")
debugLog("=== KEY PATHS FOR AUTO-BUY ===")
debugLog("")
task.wait()

-- Check CountryData
local CountryData = workspace:FindFirstChild("CountryData")
if CountryData then
    debugLog("[OK] workspace.CountryData exists")
    debugLog(string.format("     %d countries", #CountryData:GetChildren()))
else
    debugLog("[MISSING] workspace.CountryData NOT FOUND")
end
task.wait()

-- Check GameManager
local GameManager = workspace:FindFirstChild("GameManager")
if GameManager then
    debugLog("[OK] workspace.GameManager exists")
    local ManageAlliance = GameManager:FindFirstChild("ManageAlliance")
    if ManageAlliance then
        debugLog("[OK] ManageAlliance exists")
    else
        debugLog("[MISSING] ManageAlliance NOT FOUND")
    end
else
    debugLog("[MISSING] workspace.GameManager NOT FOUND")
end
task.wait()

-- Check Baseplate structure (for cities and factories)
local Baseplate = workspace:FindFirstChild("Baseplate")
if Baseplate then
    debugLog("[OK] workspace.Baseplate exists")
    
    local Cities = Baseplate:FindFirstChild("Cities")
    if Cities then
        debugLog("[OK] Baseplate.Cities exists")
        for _, country in ipairs(Cities:GetChildren()) do
            maybeYield()
            debugLog(string.format("  %s (%d cities)", country.Name, #country:GetChildren()))
        end
    else
        debugLog("[MISSING] Baseplate.Cities NOT FOUND")
    end
    task.wait()
    
    local Buildings = Baseplate:FindFirstChild("Buildings")
    if Buildings then
        debugLog("[OK] Baseplate.Buildings exists")
        for _, country in ipairs(Buildings:GetChildren()) do
            maybeYield()
            debugLog(string.format("  %s (%d buildings)", country.Name, #country:GetChildren()))
        end
    else
        debugLog("[INFO] Baseplate.Buildings not found")
    end
    task.wait()
    
    local Factories = Baseplate:FindFirstChild("Factories")
    if Factories then
        debugLog("[OK] Baseplate.Factories exists")
        for _, country in ipairs(Factories:GetChildren()) do
            maybeYield()
            debugLog(string.format("  %s (%d factories)", country.Name, #country:GetChildren()))
        end
    else
        debugLog("[INFO] Baseplate.Factories not found")
    end
else
    debugLog("[MISSING] workspace.Baseplate NOT FOUND")
end
task.wait()

-- Get player's country and check their data
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local myCountryName = LocalPlayer and LocalPlayer:GetAttribute("Country")

if myCountryName then
    debugLog("")
    debugLog(string.format("=== YOUR COUNTRY: %s ===", myCountryName))
    task.wait()
    
    if CountryData then
        local myCountry = CountryData:FindFirstChild(myCountryName)
        if myCountry then
            debugLog("[OK] Your country data found")
            
            -- Check for factories in country data
            local Factories = myCountry:FindFirstChild("Factories")
            if Factories then
                debugLog("[OK] Factories in CountryData:")
                for _, factory in ipairs(Factories:GetChildren()) do
                    maybeYield()
                    local factoryType = factory:GetAttribute("FactoryType") or factory:GetAttribute("Type") or factory.Name
                    debugLog(string.format("  %s (Type: %s)", factory.Name, factoryType))
                end
            else
                debugLog("[INFO] No Factories folder in CountryData")
            end
            task.wait()
            
            local Buildings = myCountry:FindFirstChild("Buildings")
            if Buildings then
                debugLog("[OK] Buildings in CountryData:")
                for _, building in ipairs(Buildings:GetChildren()) do
                    maybeYield()
                    local buildingType = building:GetAttribute("Type") or building.Name
                    debugLog(string.format("  %s (Type: %s)", building.Name, buildingType))
                end
            else
                debugLog("[INFO] No Buildings folder in CountryData")
            end
            task.wait()
            
            -- Check resources
            local Resources = myCountry:FindFirstChild("Resources")
            if Resources then
                debugLog("[OK] Resources:")
                for _, res in ipairs(Resources:GetChildren()) do
                    maybeYield()
                    local flow = res:FindFirstChild("Flow")
                    local flowVal = flow and flow.Value or 0
                    debugLog(string.format("  %s (Flow: %.2f)", res.Name, flowVal))
                end
            end
        else
            debugLog("[MISSING] Your country not in CountryData")
        end
    end
    task.wait()
    
    -- Check Baseplate for your factories
    if Baseplate then
        local Buildings = Baseplate:FindFirstChild("Buildings")
        if Buildings then
            local myBuildings = Buildings:FindFirstChild(myCountryName)
            if myBuildings then
                debugLog("")
                debugLog(string.format("[OK] Baseplate Buildings for %s:", myCountryName))
                for _, building in ipairs(myBuildings:GetChildren()) do
                    maybeYield()
                    debugLog(string.format("  \"%s\" (%s)", building.Name, building.ClassName))
                    local attrs = building:GetAttributes()
                    for attrName, attrVal in pairs(attrs) do
                        debugLog(string.format("    %s=%s", attrName, tostring(attrVal)))
                    end
                end
            end
        end
        task.wait()
        
        local Factories = Baseplate:FindFirstChild("Factories")
        if Factories then
            local myFactories = Factories:FindFirstChild(myCountryName)
            if myFactories then
                debugLog("")
                debugLog(string.format("[OK] Baseplate Factories for %s:", myCountryName))
                for _, factory in ipairs(myFactories:GetChildren()) do
                    maybeYield()
                    debugLog(string.format("  \"%s\" (%s)", factory.Name, factory.ClassName))
                    local attrs = factory:GetAttributes()
                    for attrName, attrVal in pairs(attrs) do
                        debugLog(string.format("    %s=%s", attrName, tostring(attrVal)))
                    end
                end
            end
        end
    end
else
    debugLog("[WARNING] No country assigned yet")
end

debugLog("")
debugLog("═══════════════════════════════════")
debugLog("  DEBUG COMPLETE")
debugLog("═══════════════════════════════════")
