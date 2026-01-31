--[[
    DEBUG WORKSPACE SCRIPT (Lightweight Version)
    Prints key game structures relevant to auto-buy debugging
    
    FIXED: Previous version froze game - now only explores relevant paths
    and yields frequently to prevent freezing.
    
    This script ONLY explores:
    - CountryData (for resources and economy)
    - GameManager (for trade functions)  
    - Baseplate (for cities, buildings, factories)
    
    It does NOT explore player characters, terrain, or other irrelevant objects.
]]

-- Yield counter to prevent freezing
local yieldCounter = 0
local YIELD_EVERY = 50  -- Yield every N items

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
    
    print(string.format("%s[%d] %s \"%s\"%s%s", indent, depth, className, name, valueStr, attrs))
end

local function exploreRecursive(instance, depth, maxDepth)
    if depth > maxDepth then
        local childCount = #instance:GetChildren()
        if childCount > 0 then
            local indent = string.rep("| ", depth)
            print(string.format("%s... (%d more children, max depth reached)", indent, childCount))
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
                print(string.format("[NOT FOUND] %s (stopped at %s)", path, part))
                return
            end
        end
    end
    
    print(string.format("\n=== %s ===", path))
    exploreRecursive(current, 0, maxDepth)
    task.wait() -- Yield after each section
end

-- Main execution
print("═══════════════════════════════════════════════════════════════")
print("  DEBUG WORKSPACE - Lightweight Version")
print("  (Only explores game-relevant paths to prevent freezing)")
print("═══════════════════════════════════════════════════════════════")
print("")

-- Also specifically look for key paths relevant to auto-buying
print("")
print("=== KEY PATHS FOR AUTO-BUY DEBUGGING ===")
print("")
task.wait()

-- Check CountryData
local CountryData = workspace:FindFirstChild("CountryData")
if CountryData then
    print("[OK] workspace.CountryData exists")
    print(string.format("     Children: %d countries", #CountryData:GetChildren()))
else
    print("[MISSING] workspace.CountryData NOT FOUND")
end
task.wait()

-- Check GameManager
local GameManager = workspace:FindFirstChild("GameManager")
if GameManager then
    print("[OK] workspace.GameManager exists")
    local ManageAlliance = GameManager:FindFirstChild("ManageAlliance")
    if ManageAlliance then
        print("[OK] workspace.GameManager.ManageAlliance exists")
    else
        print("[MISSING] workspace.GameManager.ManageAlliance NOT FOUND")
    end
else
    print("[MISSING] workspace.GameManager NOT FOUND")
end
task.wait()

-- Check Baseplate structure (for cities and factories)
local Baseplate = workspace:FindFirstChild("Baseplate")
if Baseplate then
    print("[OK] workspace.Baseplate exists")
    
    local Cities = Baseplate:FindFirstChild("Cities")
    if Cities then
        print("[OK] workspace.Baseplate.Cities exists")
        for _, country in ipairs(Cities:GetChildren()) do
            maybeYield()
            print(string.format("     Country folder: %s (%d cities)", country.Name, #country:GetChildren()))
        end
    else
        print("[MISSING] workspace.Baseplate.Cities NOT FOUND")
    end
    task.wait()
    
    local Buildings = Baseplate:FindFirstChild("Buildings")
    if Buildings then
        print("[OK] workspace.Baseplate.Buildings exists")
        for _, country in ipairs(Buildings:GetChildren()) do
            maybeYield()
            print(string.format("     Country buildings: %s (%d buildings)", country.Name, #country:GetChildren()))
        end
    else
        print("[INFO] workspace.Baseplate.Buildings not found (factories may be elsewhere)")
    end
    task.wait()
    
    local Factories = Baseplate:FindFirstChild("Factories")
    if Factories then
        print("[OK] workspace.Baseplate.Factories exists")
        for _, country in ipairs(Factories:GetChildren()) do
            maybeYield()
            print(string.format("     Country factories: %s (%d factories)", country.Name, #country:GetChildren()))
        end
    else
        print("[INFO] workspace.Baseplate.Factories not found (factories may be elsewhere)")
    end
else
    print("[MISSING] workspace.Baseplate NOT FOUND")
end
task.wait()

-- Get player's country and check their data
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local myCountryName = LocalPlayer and LocalPlayer:GetAttribute("Country")

if myCountryName then
    print("")
    print(string.format("=== YOUR COUNTRY: %s ===", myCountryName))
    task.wait()
    
    if CountryData then
        local myCountry = CountryData:FindFirstChild(myCountryName)
        if myCountry then
            print("[OK] Your country data found")
            
            -- Check for factories in country data
            local Factories = myCountry:FindFirstChild("Factories")
            if Factories then
                print("[OK] Factories folder in CountryData")
                for _, factory in ipairs(Factories:GetChildren()) do
                    maybeYield()
                    local factoryType = factory:GetAttribute("FactoryType") or factory:GetAttribute("Type") or factory.Name
                    print(string.format("     Factory: %s (Type: %s)", factory.Name, factoryType))
                end
            else
                print("[INFO] No Factories folder in your CountryData")
            end
            task.wait()
            
            local Buildings = myCountry:FindFirstChild("Buildings")
            if Buildings then
                print("[OK] Buildings folder in CountryData")
                for _, building in ipairs(Buildings:GetChildren()) do
                    maybeYield()
                    local buildingType = building:GetAttribute("Type") or building.Name
                    print(string.format("     Building: %s (Type: %s)", building.Name, buildingType))
                end
            else
                print("[INFO] No Buildings folder in your CountryData")
            end
            task.wait()
            
            -- Check resources
            local Resources = myCountry:FindFirstChild("Resources")
            if Resources then
                print("[OK] Resources folder found")
                for _, res in ipairs(Resources:GetChildren()) do
                    maybeYield()
                    local flow = res:FindFirstChild("Flow")
                    local flowVal = flow and flow.Value or 0
                    print(string.format("     Resource: %s (Flow: %.2f)", res.Name, flowVal))
                end
            end
        else
            print("[MISSING] Your country not found in CountryData")
        end
    end
    task.wait()
    
    -- Check Baseplate for your factories
    if Baseplate then
        local Buildings = Baseplate:FindFirstChild("Buildings")
        if Buildings then
            local myBuildings = Buildings:FindFirstChild(myCountryName)
            if myBuildings then
                print("")
                print(string.format("[OK] Your buildings in Baseplate.Buildings.%s:", myCountryName))
                for _, building in ipairs(myBuildings:GetChildren()) do
                    maybeYield()
                    print(string.format("     Building: \"%s\" (Class: %s)", building.Name, building.ClassName))
                    local attrs = building:GetAttributes()
                    for attrName, attrVal in pairs(attrs) do
                        print(string.format("       Attr: %s = %s", attrName, tostring(attrVal)))
                    end
                end
            end
        end
        task.wait()
        
        local Factories = Baseplate:FindFirstChild("Factories")
        if Factories then
            local myFactories = Factories:FindFirstChild(myCountryName)
            if myFactories then
                print("")
                print(string.format("[OK] Your factories in Baseplate.Factories.%s:", myCountryName))
                for _, factory in ipairs(myFactories:GetChildren()) do
                    maybeYield()
                    print(string.format("     Factory: \"%s\" (Class: %s)", factory.Name, factory.ClassName))
                    local attrs = factory:GetAttributes()
                    for attrName, attrVal in pairs(attrs) do
                        print(string.format("       Attr: %s = %s", attrName, tostring(attrVal)))
                    end
                end
            end
        end
    end
else
    print("[WARNING] No country assigned to player yet")
end

print("")
print("═══════════════════════════════════════════════════════════════")
print("  DEBUG COMPLETE - COPY OUTPUT ABOVE FOR DEBUGGING")
print("═══════════════════════════════════════════════════════════════")
