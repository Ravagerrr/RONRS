# COPILOT CONTEXT - READ THIS FIRST

> **IMPORTANT**: If you are an AI assistant (Claude/Copilot), READ THIS ENTIRE FILE before doing anything else. This file contains accumulated knowledge from previous sessions that you need to continue the work effectively.

> **AT THE END OF EACH SESSION**: Update this file with new findings, decisions, and context before committing. This ensures the next session starts with full context.

---

## 🎯 Project Overview

**Repository**: RONRS - Rise of Nations Resource Script  
**Purpose**: Automated trading script for the Roblox game "Rise of Nations"  
**Language**: Lua (Roblox Luau)

## 📋 Current State (Last Updated: 2026-02-01)

### Active Investigation: Trade Acceptance Mechanics

We're trying to understand WHY some trades get accepted and others fail, even with similar parameters.

**Debug Output Format**:
```
TRADE|Country|Rank|Resource|PriceTier|Amount|Cost%|Revenue|Result
```

Example:
```
TRADE|Slovakia|140|Cons|1.0x|1.31|4.85%|$221855|FAIL
TRADE|Slovakia|140|Cons|0.5x|1.31|2.43%|$221855|OK
```

### Key Findings So Far

1. **Cost percentage is NOT the determining factor**
   - OK trades: 5.14% - 10.80% cost ratio
   - FAIL trades: 4.85% - 10.58% cost ratio
   - Complete overlap = not predictive

2. **Game has ~10 second trade cooldown per country**
   - Can't immediately retry with same country
   - Queue system works because processing other countries takes 10+ seconds

3. **RANKING is unanalyzed** - hypothesis to test:
   - Do high-ranked (powerful) countries reject more?
   - Do low-ranked countries accept higher prices?

4. **Consumer Goods is a 100% aced algorithm**
   - Consumer Goods trades are accepted 100% of the time when price/amount is calculated correctly
   - The algorithm for Consumer Goods has been perfected and AI countries always accept properly calculated trades
   - When already trading with all AI countries, the script stops early (no need to print or attempt trades)

### Current Algorithm

```
1. Try trade at 1.0x (maximum price)
2. If fails → queue for retry at 0.5x
3. Process other countries (~10s passes = cooldown)
4. Retry at 0.5x
5. If fails → queue for retry at 0.1x
6. Final attempt at 0.1x
7. If still fails → permanent fail
```

### Pending Tasks

- [ ] User will run script and paste TRADE| output
- [ ] Analyze ranking correlation with trade acceptance
- [ ] Update algorithm based on findings
- [ ] Potentially create ranking-based price tier selection

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `trading.lua` | Trade execution, attemptTrade(), processCountryResource() |
| `helpers.lua` | getPriceTier(), getNextPriceTier(), getCountryResourceData() |
| `config.lua` | Revenue spending tiers, retry settings |
| `autosell.lua` | Triggers trading when flow exceeds threshold |
| `autobuyer.lua` | Auto-buys resources when needed |
| `warmonitor.lua` | Detects and alerts when countries are justifying war against you |
| `ui.lua` | Rayfield UI v2.0 - Dashboard, Resources, Automation, Settings, Logs |
| `main.lua` | Entry point, module loader |
| `TRADE_ANALYSIS.md` | Detailed analysis documentation |
| `CONTEXT.md` | **THIS FILE** - read first, update last |

### UI v2.0 Tab Structure
1. **Dashboard** - Status overview (country, state, auto-sell/buy/war), war alerts, resource flow, emergency stop
2. **Resources** - Sell resource toggles + Buy resource toggles (all in one place)
3. **Automation** - Auto-Sell settings + Auto-Buy settings + War Monitor settings (enable, thresholds, intervals)
4. **Settings** - Flow protection, timing, trade filters
5. **Logs** - Activity log with copy/clear buttons

---

## 🔧 How the Code Works

### Trade Flow
1. `autosell.lua` detects surplus flow → triggers `trading.run()`
2. **Phase 1 - Evaluate**: `trading.run()` pre-evaluates ALL country+resource pairs (fast, no network calls)
3. **Phase 2 - Sort**: Sorts pending trades by amount DESCENDING (largest bulk orders first)
4. **Phase 3 - Execute**: Executes trades in sorted order, biggest first
5. Failed trades get queued for retry at lower price tier

### Bulk-First Strategy
- **Goal**: When competing with other players, get the largest trades executed first
- **Why**: Small 0.1-unit trades waste time while competitors grab the big orders
- **How**: Pre-evaluate all trades, sort by amount (descending), then execute biggest first
- Evaluation is instant (reads game data only), execution is where time is spent (FireServer + verification)
- Available flow is re-checked before each execution since it may have changed

### Price Tiers
- **1.0x** = Full price ($82,400/unit for Consumer Goods)
- **0.5x** = Half price ($41,200/unit)
- **0.1x** = Minimum price ($8,240/unit)

### Data Available for Each Country
```lua
data.revenue    -- Total revenue
data.ranking    -- Country ranking (1 = most powerful)
data.population -- Population
data.balance    -- Current balance
data.flow       -- Resource flow (negative = consuming)
data.buyAmount  -- Already buying this much
data.hasSell    -- Already has a sell trade
data.tax        -- Tax revenue
```

---

## 📊 Data Submission Instructions

When user pastes TRADE| lines, analyze for:

1. **Ranking patterns** - Do high-ranked countries (1-50) only accept low prices?
2. **Price tier success rates** - What % succeed at 1.0x vs 0.5x vs 0.1x?
3. **Journey patterns** - Which countries need multiple attempts?
4. **The actual game mechanic** - What's really causing acceptance/rejection?

---

## 📝 Session Log

### Session 2026-02-14
- **FEATURE: Bulk-first trade ordering** - Prioritize largest trades over small ones
  - **Problem**: Script was executing trades in country-order (by revenue), which meant some tiny 0.1-unit trades would execute before larger bulk orders, wasting time when competing with other players
  - **Solution**: Split trade execution into 3 phases:
    1. **Evaluate**: Pre-evaluate ALL country+resource pairs instantly (no FireServer calls)
    2. **Sort**: Sort pending trades by amount DESCENDING (largest first)
    3. **Execute**: Fire trades in sorted order, biggest bulk orders first
  - **Refactored**: `processCountryResource()` split into `evaluateCountryResource()` (pure evaluation) and `executeTrade()` (fires the trade). Legacy `processCountryResource()` kept as wrapper for retry system.
  - **Safety**: Available flow is re-checked before each execution since it may have changed during the cycle
  - **Files modified**: trading.lua, CONTEXT.md

### Session 2026-02-02 06:43
- **FEATURE: War Monitor** - Added detection and notification for war justifications
  - **Purpose**: Alert the player when other countries are justifying war against them
  - **How it works**:
    - Monitors `workspace.CountryData.[YourCountry].Diplomacy.Actions` folder
    - Any country appearing in the Actions folder means they're justifying war
    - Sends both UI log messages and Roblox notifications when detected
  - **New files**: `warmonitor.lua` - dedicated monitoring module
  - **Config options**: `WarMonitorEnabled`, `WarMonitorCheckInterval`
  - **UI changes**:
    - Dashboard: Added "War Alert" section showing active justifications
    - Automation tab: Added War Monitor toggle and interval slider
    - Status bar: Now shows War:ON/OFF indicator
  - **Notifications**: Uses `StarterGui:SetCore("SendNotification")` for in-game alerts

### Session 2026-02-02 05:27
- **FIX: Auto-buy makes multiple small trades instead of one big trade** - Fixed verification to track difference
  - **Problem**: When needing 10 copper from a country with 10+ flow, script bought 2, 2, 2, 2, 2 instead of one 10
  - **Root Cause**: `attemptBuy` read the trade entry immediately and got a partial/stale value
    - If a pre-existing trade showed 2, it would return 2 even though we requested 10
    - The verification was checking too quickly before the game updated the trade amount
  - **Fix**:
    1. Added `getCurrentTradeAmount()` helper to get trade amount BEFORE the request
    2. Changed `attemptBuy` to calculate the DIFFERENCE (afterAmount - beforeAmount)
    3. Increased polling: 0.15s × 5 = 0.75s max wait (was 0.1s × 3 = 0.3s)
  - **Result**: Now correctly buys full requested amount in one trade when possible

### Session 2026-02-02 06:40
- **FEATURE: Block AlertPopup during script trades** - Aesthetic improvement to reduce visual spam
  - **Problem**: Fast automated trades cause AlertPopup spam, creating visual clutter
  - **Solution**: 
    1. Added `BlockAlertPopupDuringTrade` config option (default: true)
    2. Added `isScriptTrading` flag and `startScriptTrade()`/`stopScriptTrade()` helpers
    3. Hook AlertPopup.OnClientEvent to block when script is trading
    4. Wrapped trading.lua `run()`, `processFlowQueue()`, and autobuyer.lua buying loop
  - **Files modified**: helpers.lua, config.lua, trading.lua, autobuyer.lua, ui.lua
  - **Result**: Popups blocked only during script trades, manual trades still show popups

### Session 2026-02-02 06:35
- **DOCS: Expanded README** with quick start, configuration overview, and key files

### Session 2026-02-02 04:21
- **FIX: Auto-buy only gets partial amounts, splits across countries** - Now tracks actual bought amount
  - **Problem**: When needing 10 copper, script would buy 2 from 5 different countries instead of continuing from one source
  - **Root Cause**: `attemptBuy` only checked IF a trade existed, not HOW MUCH was bought:
    ```lua
    if obj.Value.X > 0 then return true  -- Only checked existence!
    ```
    So when requesting 10 but only getting 2, it thought it succeeded and exited the loop.
  - **Fix**: 
    1. Changed `attemptBuy` to return actual amount bought (from `obj.Value.X`) instead of just true/false
    2. Updated buying loop to use actual amount and CONTINUE buying if we got less than requested
    3. Only exits loop when full amount is received OR all sellers exhausted
  - **Result**: Script now efficiently continues buying from multiple sellers until the full need is met

### Session 2026-02-02 02:05
- **FIX: Auto-buy trades too slow** - Optimized timing for faster material acquisition
  - **Problem**: User reported trades were working correctly but taking too long between trades
  - **Root Cause**: Auto-buy was using the same `Config.WaitTime` (0.5s flat wait) as selling trades
  - **Fix**: Implemented fast polling for auto-buy verification:
    - Changed from flat 0.5s wait to polling: check every 0.1s up to 3 times (0.3s max)
    - Returns immediately when trade is verified (often after just 0.1-0.2s)
    - Reduced seller retry delay from `Config.ResourceDelay` (0.3s) to hardcoded 0.2s
  - **Result**: Auto-buy is now ~2-3x faster, matching the game's ~0.3s server cooldown

### Session 2026-02-02 01:32
- **FIX: Auto-buy leaves flow at -0.1 instead of +0.1** - Simplified the neededAmount calculation
  - **Problem**: User reported script leaves them at -0.1 flow instead of reaching the +0.1 target
  - **Root Cause**: The calculation was over-complicated and double-counting:
    1. It calculated `neededAmount = factoryConsumption + targetFlow`
    2. Then subtracted `existingIncoming` trades
    3. But **flow already reflects** the net result of production - consumption + incoming trades!
    4. So we were double-counting the incoming trades
  - **Fix**: Simplified to use flow directly:
    - If `factoryConsumption > 0` AND `flowBefore < targetFlow`, then `neededAmount = targetFlow - flowBefore`
    - Example: flow = 0.0, target = 0.1 → neededAmount = 0.1 (exactly what's needed!)
    - Example: flow = -5.0, target = 0.1 → neededAmount = 5.1 (covers deficit + surplus)
  - Removed the `existingIncoming` subtraction since flow already accounts for it
  - Updated log message to show target instead of incoming

### Session 2026-02-02 01:22
- **FIX: Fork testing loads old version** - Made BASE_URL configurable for testing forks
  - **Problem**: When testing a fork, the script still loaded modules from the original repo URL
  - **Root Cause**: `BASE_URL` in main.lua was hardcoded to `https://raw.githubusercontent.com/Ravagerrr/RONRS/refs/heads/main/`
  - **Fix**: Added `_G.RONRS_BASE_URL` override option
    - Set this global variable before executing to load from a different source
    - Example: `_G.RONRS_BASE_URL = "https://raw.githubusercontent.com/YourUsername/RONRS/refs/heads/main/"`
    - Added `[Source]` log line to show which URL is being used
  - **Usage for testing forks**:
    ```lua
    -- Execute this BEFORE running main.lua
    _G.RONRS_BASE_URL = "https://raw.githubusercontent.com/YourFork/RONRS/refs/heads/your-branch/"
    ```

### Session 2026-02-02 01:20
- **FIX: Factory material deficit when auto-sell is running** - Auto-buy was being blocked by sell cycles
  - **Problem**: User reported constant factory material deficit despite auto-buy being enabled
  - **Root Cause**: In `autobuyer.lua` line 305, the `if not State.isRunning` check was blocking auto-buy from running whenever auto-sell was processing countries
  - Auto-sell cycles can take a long time (processing 240 countries), during which NO factory material purchases were happening
  - **Fix**: Removed the `State.isRunning` block from autobuyer
    - Auto-buy now runs ALWAYS, regardless of whether auto-sell is active
    - This makes factory materials PRIORITY - they're purchased even during sell cycles
    - The two systems don't conflict because:
      1. Auto-sell uses "Sell" trades (you selling to other countries)
      2. Auto-buy uses "Buy" trades (you buying from other countries)
    - Updated config.lua with documentation about this priority behavior
  - **Result**: Factories will now receive materials continuously without being blocked by sell operations

### Session 2026-02-01 04:16
- **FIX: Flow queue not accounting for existing trades** - Fixed issue where flow queue didn't check country's current capacity
  - **Problem**: When processing queued trades, the flow queue didn't re-check what the country was already buying
  - **Root Cause**: `processFlowQueue()` calculated `sellAmount` without considering `countryData.buyAmount`
  - For capped resources like Electronics (cap 5), if a country bought more since the trade was queued, the queue would try to sell more than remaining capacity
  - **Fix**: Added capacity re-check in `processFlowQueue()`:
    1. Get fresh `countryData` from `Helpers.getCountryResourceData()`
    2. For capped resources, calculate `remainingCapacity = maxCapacity - countryData.buyAmount`
    3. If capacity is full, remove from queue with log message
    4. Limit `sellAmount` to `math.min(item.remainingAmount, avail, remainingCapacity)`
  - This ensures queued trades account for any trades set up since the original was queued
- Removed old/unrelated "READ FIRST" debug file

### Session 2026-02-01 03:38
- **FIX: Electronics skipping all countries** - Identified root cause and applied fix
  - **Problem**: MinDemandFlow check (flow >= -0.1) was skipping countries with 0 flow
  - **Root Cause**: Electronics (and other capped resources) sell to countries regardless of flow
  - Countries don't naturally "consume" Electronics, so they have 0 flow, causing "No Demand" skip
  - **Fix**: Added `not resource.hasCap` condition to MinDemandFlow check
  - Capped resources (Electronics) now bypass the demand flow check
  - Uncapped resources (Consumer Goods) still require negative flow (actual consumption)
- Updated trading.lua line 86 with the fix

### Session 2026-02-01 02:54
- **UI v2.0 Reorganization** - Complete UI overhaul for better navigation:
  - **Dashboard** - Status overview with combined labels (country, status, auto-sell/buy in one line)
  - **Resources** - All resource toggles in one place (Sell + Buy resources)
  - **Automation** - Auto-Sell & Auto-Buy feature settings (clean separation)
  - **Settings** - Core settings only (Flow Protection, Timing, Filters)
  - **Logs** - Activity log with copy/clear
- Reduced redundancy: Combined 6 status labels into 4 cleaner ones
- Better organization: Resources grouped by function, not scattered across tabs
- Updated version to v2.0

### Session 2026-02-01 02:51
- Added context that Consumer Goods is a 100% aced algo (trades always accepted)
- Implemented early stopping when already trading with all AI countries for a resource
- Script now detects when all AI countries are being traded with and skips unnecessary attempts
- This prevents spam logging and wasted processing cycles

### Session 2026-02-01 02:00-02:37
- Analyzed user's trade logs showing inconsistent acceptance
- Discovered cost% doesn't predict acceptance (complete overlap)
- Discovered game has ~10 second trade cooldown per country
- Implemented: Start at 1.0x, queue-based retry at lower tiers
- Created enhanced debug output with ranking
- Created TRADE_ANALYSIS.md documentation
- **NEXT**: User will run script and provide TRADE| data for ranking analysis

---

## ⚠️ Important Reminders

1. **Always read this file first** when starting a new session
2. **Always update this file** before ending a session
3. **The user's goal**: Maximize revenue while understanding game mechanics
4. **Queue-based retry exists for cooldown** - don't do immediate retries
5. **Start at 1.0x price** - only drop as last resort
6. **TRADE_ANALYSIS.md has detailed documentation** - read if needed

---

## 🔄 How to Update This File

At the end of each session, add:
1. New findings to "Key Findings So Far"
2. Update "Current Algorithm" if changed
3. Update "Pending Tasks" with completed/new items
4. Add new session entry to "Session Log"
5. Any new important reminders

This ensures continuity across sessions even with memory wipe.
