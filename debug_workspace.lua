--[[
    DEBUG WORKSPACE SCRIPT (Simple UI - No Rayfield)
    Prints key game structures relevant to auto-buy debugging
    
    This version does NOT use Rayfield to avoid conflicts with existing UI.
    Uses a simple native Roblox ScreenGui instead.
    
    FIXED: Previous version froze game - now only explores relevant paths
    and yields frequently to prevent freezing.
    
    This script ONLY explores:
    - CountryData (for resources and economy)
    - GameManager (for trade functions)  
    - Baseplate (for cities, buildings, factories)
]]

-- Create simple native UI (no Rayfield)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remove existing debug UI if any
local existingGui = PlayerGui:FindFirstChild("DebugWorkspaceUI")
if existingGui then
    existingGui:Destroy()
end

-- Create new ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DebugWorkspaceUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Main frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 500)
MainFrame.Position = UDim2.new(0, 10, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

-- Corner rounding
local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = MainFrame

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -40, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Debug Workspace"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -28, 0, 2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 12
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 4)
CloseBtnCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Scrolling frame for logs
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Size = UDim2.new(1, -10, 1, -40)
ScrollFrame.Position = UDim2.new(0, 5, 0, 35)
ScrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 6
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.Parent = MainFrame

local ScrollCorner = Instance.new("UICorner")
ScrollCorner.CornerRadius = UDim.new(0, 6)
ScrollCorner.Parent = ScrollFrame

-- Text label for logs
local LogText = Instance.new("TextLabel")
LogText.Name = "LogText"
LogText.Size = UDim2.new(1, -10, 0, 0)
LogText.Position = UDim2.new(0, 5, 0, 0)
LogText.BackgroundTransparency = 1
LogText.Text = ""
LogText.TextColor3 = Color3.fromRGB(200, 200, 200)
LogText.TextSize = 11
LogText.Font = Enum.Font.Code
LogText.TextXAlignment = Enum.TextXAlignment.Left
LogText.TextYAlignment = Enum.TextYAlignment.Top
LogText.TextWrapped = true
LogText.AutomaticSize = Enum.AutomaticSize.Y
LogText.RichText = true
LogText.Parent = ScrollFrame

-- Log storage
local debugLogs = {}

-- Function to add log and update UI
local function debugLog(msg, color)
    table.insert(debugLogs, msg)
    -- Keep only last 100 lines
    while #debugLogs > 100 do
        table.remove(debugLogs, 1)
    end
    -- Update UI
    LogText.Text = table.concat(debugLogs, "\n")
    -- Auto-scroll to bottom
    ScrollFrame.CanvasPosition = Vector2.new(0, ScrollFrame.AbsoluteCanvasSize.Y)
    -- Also print to console
    print(msg)
    task.wait() -- Yield after each log
end

-- Yield counter to prevent freezing
local yieldCounter = 0
local YIELD_EVERY = 20

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

-- Get player's country and check their data (LocalPlayer already defined at top)
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
