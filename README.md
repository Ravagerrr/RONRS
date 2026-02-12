# RONRS - Rise of Nations Resource Script

Automates trading and resource management for the Roblox game **Rise of Nations**.  
The script focuses on safe, repeatable trade behavior with retries, flow protection, and fast auto-buying to keep factories running.

## ✨ Highlights
- **Auto-Sell** surplus flow with smart flow reserve protection.
- **Auto-Buy** factory materials when flow goes negative.
- **Retry queue** for trade cooldowns (works with the game’s ~10s trade cooldown).
- **Flow queue** to finish partially limited trades later when flow is available.
- **Logging dashboard** with real-time status and copyable logs.

## 🚀 Quick Start

### Loadstring (Recommended - Always Fresh)
Copy and paste this into your executor for live updates with cache-busting:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Ravagerrr/RONRS/main/main.lua?t=" .. tostring(tick())))()
```

### Debug Loadstring (If Getting Errors)
If you're getting "attempt to call a nil value" errors, use this version to see what's failing:

```lua
local url = "https://raw.githubusercontent.com/Ravagerrr/RONRS/main/main.lua?t=" .. tostring(tick())
print("[RONRS] Fetching: " .. url)

local success, content = pcall(function()
    return game:HttpGet(url)
end)

if not success then
    warn("[RONRS] HttpGet failed: " .. tostring(content))
    return
end

if not content or type(content) ~= "string" then
    warn("[RONRS] Invalid response: " .. tostring(type(content)))
    return
end

if #content < 100 then
    warn("[RONRS] Response too short (" .. #content .. " chars): " .. content:sub(1, 200))
    return
end

print("[RONRS] Fetched " .. #content .. " characters, loading...")

local loader, loadErr = loadstring(content)
if not loader then
    warn("[RONRS] loadstring failed: " .. tostring(loadErr))
    return
end

local execSuccess, execErr = pcall(loader)
if not execSuccess then
    warn("[RONRS] Execution failed: " .. tostring(execErr))
end
```

### Alternative: Simple Loadstring (May Cache)
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Ravagerrr/RONRS/main/main.lua"))()
```

### Fork/Branch Testing
If testing a fork or different branch, set the base URL **and** use it in the loadstring:
```lua
-- Replace YourUsername with the fork owner's username
-- Replace branch-name with the branch (e.g., "main" or "feature-branch")
_G.RONRS_BASE_URL = "https://raw.githubusercontent.com/YourUsername/RONRS/branch-name/"
loadstring(game:HttpGet(_G.RONRS_BASE_URL .. "main.lua?t=" .. tostring(tick())))()
```

**Important:** The `_G.RONRS_BASE_URL` must be set **before** the loadstring runs, AND the loadstring URL should also point to the same fork/branch to load `main.lua` from there.

**Example for testing a PR branch:**
```lua
_G.RONRS_BASE_URL = "https://raw.githubusercontent.com/Ravagerrr/RONRS/copilot/fix-nil-value-error-again/"
loadstring(game:HttpGet(_G.RONRS_BASE_URL .. "main.lua?t=" .. tostring(tick())))()
```

The UI loads automatically with default settings and starts Auto-Sell / Auto-Buy (if enabled).

## ⚙️ Configuration (config.lua)
Most options are configurable in **`config.lua`**.  
Key settings:

### Auto-Sell
- `AutoSellEnabled` – enable/disable auto-sell
- `AutoSellThreshold` – total available flow required to trigger selling
- `SmartSell` / `SmartSellReserve` – keep some flow in reserve

### Auto-Buy
- `AutoBuyEnabled` – enable/disable auto-buy
- `AutoBuyTargetSurplus` – buy until flow reaches this target
- `AutoBuyCheckInterval` – polling interval

### Trading Behavior
- `MinAmount` – minimum trade amount
- `RetryEnabled` – enable tiered retries (1.0x → 0.5x → 0.1x)
- `FlowQueueEnabled` – queue flow-limited trades and retry later

## 🧭 Trading Strategy
Default strategy is **maximize price**, then retry lower tiers if rejected:

1. Try **1.0x**  
2. Retry at **0.5x**  
3. Retry at **0.1x**  

Retry attempts are delayed by processing other countries to respect game cooldowns.

## 🗂️ Key Files
| File | Purpose |
|------|---------|
| `main.lua` | Entry point / loader |
| `trading.lua` | Trade execution, retry logic |
| `helpers.lua` | Pricing, country data, flow helpers |
| `autosell.lua` | Auto-sell trigger loop |
| `autobuyer.lua` | Auto-buy logic |
| `ui.lua` | UI layout and logs |
| `TRADE_ANALYSIS.md` | Debug analysis notes |

## 📈 Debug & Analysis
To analyze trade acceptance, collect `TRADE|` logs and review **`TRADE_ANALYSIS.md`** for details.

## 🔧 Troubleshooting

### "attempt to call a nil value" Error
This error usually means one of:
1. **Repository is private** - Private GitHub repos return 404 for raw file URLs. Make the repository **public** for loadstring to work.
2. **`game:HttpGet` is blocked or unavailable** - Your executor may not support HTTP requests, or Roblox is blocking the GitHub URL.
3. **`loadstring` is not available** - Some executors don't have loadstring.
4. **The fetch returned an error page instead of code** - GitHub might be rate-limiting or returning a 404.

**Solution:** Use the "Debug Loadstring" version above to see exactly what's failing. If it shows "404: Not Found", the repository is likely private.

### 404: Not Found
If the debug loadstring shows `404: Not Found`:
1. **Make sure the repository is PUBLIC** - Go to GitHub repo Settings → Danger Zone → Change visibility → Make public
2. **Check the URL is correct** - Branch name should be exact (e.g., `main` not `master`)
3. **Wait a few minutes** - GitHub can take time to propagate visibility changes

### No UI Showing
If the script runs but no UI appears:
1. **Rayfield failed to load** - The Rayfield UI library from `sirius.menu` may be down.
2. **UI was destroyed** - Re-inject the script.

### Script Stops Working After a While
The game may have kicked you or the script hit an error. Check your executor's console for error messages.

---

If you want improvements to strategy or pricing tiers, share your recent `TRADE|` output and I can adjust the algorithm.
