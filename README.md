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
loadstring(game:HttpGet("https://raw.githubusercontent.com/Ravagerrr/RONRS/refs/heads/main/main.lua?t=" .. tostring(tick())))()
```

### Alternative: Simple Loadstring (May Cache)
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Ravagerrr/RONRS/refs/heads/main/main.lua"))()
```

### Fork/Branch Testing
If testing a fork or different branch, set the base URL before running the loadstring:
```lua
_G.RONRS_BASE_URL = "https://raw.githubusercontent.com/YourUsername/RONRS/refs/heads/main/"
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

---

If you want improvements to strategy or pricing tiers, share your recent `TRADE|` output and I can adjust the algorithm.
