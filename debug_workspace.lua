--[[
    DEBUG WORKSPACE SCRIPT
    Prints FULL PATHS to everything in workspace
    
    HOW TO USE:
    1. Execute your Trade Hub script first (so Rayfield UI is loaded)
    2. Then execute this script
    3. Paths will be printed to the Trade Hub's Logs tab
    4. Click "Copy" in the Logs tab to copy all paths
    
    OUTPUT FORMAT:
    workspace.Baseplate.Cities.Germany.Berlin
    workspace.CountryData.Germany.Resources.Iron
    etc.
]]

-- Wait for Trade Hub UI to be ready
local UI = nil
local maxWait = 5
local waited = 0

-- Try to find the existing UI module by looking for its Logs array
while waited < maxWait do
    -- Check if _G has UI reference (we'll add this)
    if _G.TradeHubUI then
        UI = _G.TradeHubUI
        break
    end
    task.wait(0.5)
    waited = waited + 0.5
end

-- Fallback: Create our own simple log function if UI not found
local allPaths = {}
local logFunc

if UI and UI.log then
    logFunc = function(msg)
        UI.log(msg, "info")
    end
    logFunc("[Debug] Connected to Trade Hub UI")
else
    -- If Trade Hub not loaded, just print and collect for clipboard
    logFunc = function(msg)
        print(msg)
    end
    print("[Debug] Trade Hub UI not found - printing to console only")
    print("[Debug] Run Trade Hub first, then run this script for UI logging")
end

-- Yield counter
local yieldCounter = 0
local YIELD_EVERY = 50

local function maybeYield()
    yieldCounter = yieldCounter + 1
    if yieldCounter >= YIELD_EVERY then
        yieldCounter = 0
        task.wait()
    end
end

-- Build full path string for an instance
local function getFullPath(instance)
    local parts = {}
    local current = instance
    while current and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return table.concat(parts, ".")
end

-- Recursively collect all paths
local function collectPaths(instance, maxDepth, currentDepth)
    currentDepth = currentDepth or 0
    
    if currentDepth > maxDepth then
        return
    end
    
    maybeYield()
    
    local path = getFullPath(instance)
    table.insert(allPaths, path)
    
    local children = instance:GetChildren()
    for _, child in ipairs(children) do
        collectPaths(child, maxDepth, currentDepth + 1)
    end
end

-- Main execution
logFunc("═══════════════════════════════════")
logFunc("  DEBUG: Collecting workspace paths")
logFunc("═══════════════════════════════════")
task.wait()

-- Configuration - how deep to go
local MAX_DEPTH = 6  -- Adjust if needed (higher = more paths but slower)

logFunc("Max depth: " .. MAX_DEPTH)
logFunc("Collecting paths...")
task.wait()

-- Collect all paths from workspace
collectPaths(workspace, MAX_DEPTH, 0)

logFunc("Found " .. #allPaths .. " paths")
logFunc("")
task.wait()

-- Print all paths to log
for i, path in ipairs(allPaths) do
    maybeYield()
    logFunc(path)
end

logFunc("")
logFunc("═══════════════════════════════════")
logFunc("  COMPLETE: " .. #allPaths .. " paths")
logFunc("═══════════════════════════════════")

-- Copy all paths to clipboard
local pathsText = table.concat(allPaths, "\n")
if setclipboard then
    setclipboard(pathsText)
    logFunc("[COPIED] All paths copied to clipboard!")
else
    logFunc("[INFO] setclipboard not available")
end

-- Also store in _G for manual access
_G.DebugWorkspacePaths = allPaths
logFunc("[INFO] Paths also stored in _G.DebugWorkspacePaths")
