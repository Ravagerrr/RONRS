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

5. **Negative flow is required to buy, but NOT a 1:1 amount cap**
   - AI countries only buy resources they have negative flow for — flow is used as a FILTER
   - But flow does NOT map 1:1 to trade capacity: a country with -200 flow may only take ~100 units
   - Flow is used ONLY to filter out countries with no demand (skip if flow >= MinDemandFlow)
   - The revenue spending limit (maxAffordable) is the real constraint on trade amount

6. **Revenue spending tiers were too conservative**
   - India ($12M+ revenue, flow -200) was only getting ~25 units because spending was capped at 38%
   - Actual game allows large countries to spend 70%+ of revenue on trade
   - Updated tiers: $10M+ → 70%, $5M+ → 60%, $1M+ → 50%, $500K+ → 40%

7. **Retrying at different price CANCELS the existing trade**
   - Game mechanic: when you retry a trade with the same country at a different price tier, the game cancels the original trade
   - This means a successful 25-unit trade at 1.0x gets CANCELLED when we retry at 0.5x
   - Net result: we LOSE revenue instead of gaining more
   - Retry system disabled by default to prevent this

### Current Algorithm

```
1. Pre-evaluate ALL country+resource pairs (no network, instant)
2. Sort by trade amount DESCENDING (largest bulk orders first)
3. Execute trades at 1.0x price (biggest first)
4. Flow used as FILTER only (skip if flow >= -0.1), NOT as amount cap
5. Amount = min(maxAffordable, availableFlow) — flow caps our outgoing supply, not their demand
6. Retry system DISABLED by default (retries cancel existing trades)
```

### Pending Tasks

- [ ] User will run script and paste TRADE| output — calibrate spending tiers with real data
- [ ] Analyze ranking correlation with trade acceptance
- [x] Remove flow-based amount cap — flow doesn't map 1:1 to trade amount
- [x] Increase revenue spending tiers — 38% was far too conservative
- [x] Disable retry system — retries cancel existing trades

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
- **FIX: Trade amount calculation — flow as filter, not amount cap**
  - **Problem**: India with flow -200 only got ~25 Consumer Goods when it should accept ~100
  - **Root Cause 1**: `affordable = math.min(maxAffordable, abs(flow))` used flow as amount cap, but flow doesn't map 1:1 to trade capacity (country with -200 flow takes ~100, not 200)
  - **Root Cause 2**: Revenue spending tiers were too conservative (38% max for $10M+ countries)
  - **Fix**: 
    1. Removed flow-based amount cap — flow used as FILTER only (skip if no negative flow)
    2. Increased spending tiers: $10M+ → 70%, $5M+ → 60%, $1M+ → 50%, $500K+ → 40%
  - **Files modified**: trading.lua, config.lua
- **FIX: Retry system cancels existing trades**
  - **Problem**: When retrying at a lower price tier (e.g., 0.5x after 1.0x fails), the game CANCELS the original trade
  - This means a successful trade gets lost when we attempt a retry
  - **Fix**: Disabled retry system by default (`RetryEnabled = false`)
  - Consumer Goods already succeeds 100% at 1.0x when amount is correctly calculated
  - **Files modified**: config.lua

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


[13:07:24] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:24] Electronics: Already trading with all 238 AI countries - skipping
[13:07:24] Trade cycle started
[13:07:24] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:23] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:23] Electronics: Already trading with all 238 AI countries - skipping
[13:07:23] Trade cycle started
[13:07:23] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:23] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:23] Electronics: Already trading with all 238 AI countries - skipping
[13:07:23] Trade cycle started
[13:07:23] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:22] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:22] Electronics: Already trading with all 238 AI countries - skipping
[13:07:22] Trade cycle started
[13:07:22] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:22] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:22] Electronics: Already trading with all 238 AI countries - skipping
[13:07:22] Trade cycle started
[13:07:22] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:21] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:21] Electronics: Already trading with all 238 AI countries - skipping
[13:07:21] Trade cycle started
[13:07:21] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:21] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:21] Electronics: Already trading with all 238 AI countries - skipping
[13:07:21] Trade cycle started
[13:07:21] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:20] Done in 0.2s | OK:0 Skip:240 Fail:0
[13:07:20] Electronics: Already trading with all 238 AI countries - skipping
[13:07:20] Trade cycle started
[13:07:20] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:20] Done in 0.2s | OK:0 Skip:240 Fail:0
[13:07:20] Electronics: Already trading with all 238 AI countries - skipping
[13:07:20] Trade cycle started
[13:07:20] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:20] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:19] Electronics: Already trading with all 238 AI countries - skipping
[13:07:19] Trade cycle started
[13:07:19] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:19] Done in 0.2s | OK:0 Skip:240 Fail:0
[13:07:19] Electronics: Already trading with all 238 AI countries - skipping
[13:07:19] Trade cycle started
[13:07:19] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:19] Done in 0.2s | OK:0 Skip:240 Fail:0
[13:07:18] Electronics: Already trading with all 238 AI countries - skipping
[13:07:18] Trade cycle started
[13:07:18] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:18] Done in 0.2s | OK:0 Skip:240 Fail:0
[13:07:18] Electronics: Already trading with all 238 AI countries - skipping
[13:07:18] Trade cycle started
[13:07:18] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:18] Done in 0.2s | OK:0 Skip:240 Fail:0
[13:07:17] Electronics: Already trading with all 238 AI countries - skipping
[13:07:17] Trade cycle started
[13:07:17] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:17] Done in 0.2s | OK:0 Skip:240 Fail:0
[13:07:17] Electronics: Already trading with all 238 AI countries - skipping
[13:07:17] Trade cycle started
[13:07:17] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:17] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:17] Electronics: Already trading with all 238 AI countries - skipping
[13:07:17] Trade cycle started
[13:07:17] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:16] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:16] Electronics: Already trading with all 238 AI countries - skipping
[13:07:16] Trade cycle started
[13:07:16] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:16] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:16] Electronics: Already trading with all 238 AI countries - skipping
[13:07:16] Trade cycle started
[13:07:16] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:15] Done in 0.2s | OK:0 Skip:240 Fail:0
[13:07:15] Electronics: Already trading with all 238 AI countries - skipping
[13:07:15] Trade cycle started
[13:07:15] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:15] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:15] Electronics: Already trading with all 238 AI countries - skipping
[13:07:15] Trade cycle started
[13:07:15] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:14] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:14] Electronics: Already trading with all 238 AI countries - skipping
[13:07:14] Trade cycle started
[13:07:14] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:14] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:14] Electronics: Already trading with all 238 AI countries - skipping
[13:07:14] Trade cycle started
[13:07:14] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:14] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:13] Electronics: Already trading with all 238 AI countries - skipping
[13:07:13] Trade cycle started
[13:07:13] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:13] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:13] Electronics: Already trading with all 238 AI countries - skipping
[13:07:13] Trade cycle started
[13:07:13] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:13] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:12] Electronics: Already trading with all 238 AI countries - skipping
[13:07:12] Trade cycle started
[13:07:12] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:12] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:12] Electronics: Already trading with all 238 AI countries - skipping
[13:07:12] Trade cycle started
[13:07:12] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:12] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:11] Electronics: Already trading with all 238 AI countries - skipping
[13:07:11] Trade cycle started
[13:07:11] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:11] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:11] Electronics: Already trading with all 238 AI countries - skipping
[13:07:11] Trade cycle started
[13:07:11] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:11] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:11] Electronics: Already trading with all 238 AI countries - skipping
[13:07:11] Trade cycle started
[13:07:11] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:10] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:10] Electronics: Already trading with all 238 AI countries - skipping
[13:07:10] Trade cycle started
[13:07:10] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:10] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:10] Electronics: Already trading with all 238 AI countries - skipping
[13:07:10] Trade cycle started
[13:07:10] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:09] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:09] Electronics: Already trading with all 238 AI countries - skipping
[13:07:09] Trade cycle started
[13:07:09] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:09] Done in 0.2s | OK:0 Skip:240 Fail:0
[13:07:09] Electronics: Already trading with all 238 AI countries - skipping
[13:07:09] Trade cycle started
[13:07:09] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:08] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:08] Electronics: Already trading with all 238 AI countries - skipping
[13:07:08] Trade cycle started
[13:07:08] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:08] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:08] Electronics: Already trading with all 238 AI countries - skipping
[13:07:08] Trade cycle started
[13:07:08] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:07] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:07] Electronics: Already trading with all 238 AI countries - skipping
[13:07:07] Trade cycle started
[13:07:07] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:07] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:07] Electronics: Already trading with all 238 AI countries - skipping
[13:07:07] Trade cycle started
[13:07:07] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:06] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:06] Electronics: Already trading with all 238 AI countries - skipping
[13:07:06] Trade cycle started
[13:07:06] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:06] Done in 0.3s | OK:0 Skip:240 Fail:0
[13:07:06] Electronics: Already trading with all 238 AI countries - skipping
[13:07:06] Trade cycle started
[13:07:06] TRIGGERED: Consumer Goods 388.2 Electronics 539.3
[13:07:05] Done in 0.8s | OK:1 Skip:239 Fail:0
[13:07:05] [116/240] OK Consumer Goods Chad
[13:07:04] [116/240] Consumer Goods Chad | 0.69 @ 1.0x ($82400/u) | Flow:-2.21 Rev:$226531 Cost:$56633
[13:07:04] Electronics: Already trading with all 238 AI countries - skipping
[13:07:04] Trade cycle started
[13:07:04] TRIGGERED: Consumer Goods 388.9 Electronics 539.3
[13:07:04] Done in 8.9s | OK:8 Skip:471 Fail:1
[13:07:04] [2/2] OK Electronics Kosovo
[13:07:03] [2/2] Electronics Kosovo | 0.63 @ 0.5x ($51000/u) | Flow:0.00 Rev:$127874 Cost:$31968
[13:07:03] [1/2] FAIL Consumer Goods Chad
[13:07:02] [1/2] Consumer Goods Chad | 1.37 @ 0.5x ($41200/u) | Flow:-2.21 Rev:$226494 Cost:$56624
[13:07:02] RETRY: 2
[13:07:02] [223/240] OK Electronics Faroe Islands
[13:07:02] [223/240] Electronics Faroe Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101077 Cost:$25269
[13:07:01] [187/240] OK Consumer Goods New Caledonia
[13:07:01] [187/240] Consumer Goods New Caledonia | 0.10 @ 1.0x ($82400/u) | Flow:-0.10 Rev:$106896 Cost:$8523
[13:07:01] [163/240] RETRY Electronics Kosovo (will try 0.5x)
[13:07:00] [163/240] Electronics Kosovo | 0.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$127866 Cost:$31966
[13:06:59] [131/240] OK Electronics Brunei
[13:06:59] [131/240] Electronics Brunei | 0.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$197217 Cost:$49304
[13:06:59] [116/240] RETRY Consumer Goods Chad (will try 0.5x)
[13:06:58] [116/240] Consumer Goods Chad | 0.69 @ 1.0x ($82400/u) | Flow:-2.21 Rev:$226494 Cost:$56624
[13:06:58] [102/240] OK Electronics Finland
[13:06:57] [102/240] Electronics Finland | 0.65 @ 1.0x ($102000/u) | Flow:0.00 Rev:$266561 Cost:$66640
[13:06:57] [76/240] OK Electronics Switzerland
[13:06:57] [76/240] Electronics Switzerland | 0.98 @ 1.0x ($102000/u) | Flow:0.00 Rev:$400174 Cost:$100044
[13:06:56] [32/240] OK Consumer Goods Peru
[13:06:56] [32/240] Consumer Goods Peru | 4.65 @ 1.0x ($82400/u) | Flow:-18.93 Rev:$1196985 Cost:$383035
[13:06:55] [8/240] OK Consumer Goods Mexico
[13:06:55] [8/240] Consumer Goods Mexico | 14.31 @ 1.0x ($82400/u) | Flow:-72.87 Rev:$3684055 Cost:$1178898
[13:06:55] Trade cycle started
[13:06:55] TRIGGERED: Consumer Goods 408.0 Electronics 542.3
[13:06:54] Done in 63.5s | OK:52 Skip:420 Fail:8
[13:06:54] [15/15] FAIL Electronics Faroe Islands
[13:06:53] [15/15] Electronics Faroe Islands | 0.50 @ 0.5x ($51000/u) | Flow:0.00 Rev:$101077 Cost:$25269
[13:06:53] [14/15] OK Consumer Goods Sao Tome And Principe
[13:06:53] [14/15] Consumer Goods Sao Tome And Principe | 0.10 @ 0.5x ($41200/u) | Flow:-0.10 Rev:$106655 Cost:$4162
[13:06:53] [13/15] FAIL Consumer Goods New Caledonia
[13:06:52] [13/15] Consumer Goods New Caledonia | 0.10 @ 0.5x ($41200/u) | Flow:-0.10 Rev:$106894 Cost:$4260
[13:06:52] [12/15] OK Consumer Goods Iceland
[13:06:51] [12/15] Consumer Goods Iceland | 0.24 @ 0.5x ($41200/u) | Flow:-0.24 Rev:$114323 Cost:$9685
[13:06:51] [11/15] FAIL Electronics Kosovo
[13:06:50] [11/15] Electronics Kosovo | 0.63 @ 0.5x ($51000/u) | Flow:0.00 Rev:$127850 Cost:$31962
[13:06:50] [10/15] OK Electronics Djibouti
[13:06:50] [10/15] Electronics Djibouti | 0.84 @ 0.5x ($51000/u) | Flow:0.00 Rev:$172314 Cost:$43078
[13:06:50] [9/15] FAIL Electronics Brunei
[13:06:49] [9/15] Electronics Brunei | 0.97 @ 0.5x ($51000/u) | Flow:0.00 Rev:$197196 Cost:$49299
[13:06:49] [8/15] OK Consumer Goods Honduras
[13:06:48] [8/15] Consumer Goods Honduras | 1.35 @ 0.5x ($41200/u) | Flow:-2.38 Rev:$223018 Cost:$55754
[13:06:48] [7/15] FAIL Consumer Goods Chad
[13:06:47] [7/15] Consumer Goods Chad | 1.37 @ 0.5x ($41200/u) | Flow:-2.20 Rev:$226422 Cost:$56606
[13:06:47] [6/15] OK Consumer Goods Georgia
[13:06:47] [6/15] Consumer Goods Georgia | 1.45 @ 0.5x ($41200/u) | Flow:-2.03 Rev:$239708 Cost:$59927
[13:06:47] [5/15] FAIL Electronics Finland
[13:06:46] [5/15] Electronics Finland | 1.31 @ 0.5x ($51000/u) | Flow:0.00 Rev:$266466 Cost:$66616
[13:06:46] [4/15] OK Consumer Goods Madagascar
[13:06:45] [4/15] Consumer Goods Madagascar | 1.97 @ 0.5x ($41200/u) | Flow:-3.54 Rev:$324637 Cost:$81159
[13:06:45] [3/15] FAIL Electronics Switzerland
[13:06:44] [3/15] Electronics Switzerland | 1.96 @ 0.5x ($51000/u) | Flow:0.00 Rev:$400007 Cost:$100002
[13:06:44] [2/15] OK Consumer Goods Greece
[13:06:44] [2/15] Consumer Goods Greece | 2.85 @ 0.5x ($41200/u) | Flow:-6.72 Rev:$469883 Cost:$117471
[13:06:44] [1/15] FAIL Consumer Goods Peru
[13:06:43] [1/15] Consumer Goods Peru | 9.29 @ 0.5x ($41200/u) | Flow:-18.92 Rev:$1196389 Cost:$382844
[13:06:43] RETRY: 15
[13:06:43] [239/240] OK Electronics Niue
[13:06:43] [239/240] Electronics Niue | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100131 Cost:$25033
[13:06:43] [223/240] RETRY Electronics Faroe Islands (will try 0.5x)
[13:06:42] [223/240] Electronics Faroe Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101076 Cost:$25269
[13:06:41] [206/240] OK Electronics Antigua And Barbuda
[13:06:41] [206/240] Electronics Antigua And Barbuda | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102715 Cost:$25679
[13:06:41] [190/240] RETRY Consumer Goods Sao Tome And Principe (will try 0.5x)
[13:06:40] [190/240] Consumer Goods Sao Tome And Principe | 0.10 @ 1.0x ($82400/u) | Flow:-0.10 Rev:$106649 Cost:$8316
[13:06:39] [189/240] OK Consumer Goods French Guiana
[13:06:39] [189/240] Consumer Goods French Guiana | 0.12 @ 1.0x ($82400/u) | Flow:-0.12 Rev:$106700 Cost:$10046
[13:06:39] [187/240] RETRY Consumer Goods New Caledonia (will try 0.5x)
[13:06:38] [187/240] Consumer Goods New Caledonia | 0.10 @ 1.0x ($82400/u) | Flow:-0.10 Rev:$106888 Cost:$8513
[13:06:38] [186/240] OK Electronics Jersey
[13:06:37] [186/240] Electronics Jersey | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$107641 Cost:$26910
[13:06:37] [176/240] OK Consumer Goods Gibraltar
[13:06:37] [176/240] Consumer Goods Gibraltar | 0.21 @ 1.0x ($82400/u) | Flow:-0.21 Rev:$113834 Cost:$17099
[13:06:37] [173/240] RETRY Consumer Goods Iceland (will try 0.5x)
[13:06:36] [173/240] Consumer Goods Iceland | 0.23 @ 1.0x ($82400/u) | Flow:-0.23 Rev:$114314 Cost:$19359
[13:06:35] [171/240] OK Electronics Montenegro
[13:06:35] [171/240] Electronics Montenegro | 0.29 @ 1.0x ($102000/u) | Flow:0.00 Rev:$118569 Cost:$29642
[13:06:35] [163/240] RETRY Electronics Kosovo (will try 0.5x)
[13:06:34] [163/240] Electronics Kosovo | 0.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$127826 Cost:$31956
[13:06:34] [154/240] OK Electronics Papua New Guinea
[13:06:33] [154/240] Electronics Papua New Guinea | 0.36 @ 1.0x ($102000/u) | Flow:0.00 Rev:$145628 Cost:$36407
[13:06:33] [146/240] RETRY Electronics Djibouti (will try 0.5x)
[13:06:32] [146/240] Electronics Djibouti | 0.42 @ 1.0x ($102000/u) | Flow:0.00 Rev:$172250 Cost:$43062
[13:06:32] [138/240] OK Electronics Macedonia
[13:06:32] [138/240] Electronics Macedonia | 0.46 @ 1.0x ($102000/u) | Flow:0.00 Rev:$186007 Cost:$46502
[13:06:32] [131/240] RETRY Electronics Brunei (will try 0.5x)
[13:06:31] [131/240] Electronics Brunei | 0.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$197164 Cost:$49291
[13:06:30] [122/240] OK Electronics Nicaragua
[13:06:30] [122/240] Electronics Nicaragua | 0.53 @ 1.0x ($102000/u) | Flow:0.00 Rev:$217083 Cost:$54271
[13:06:30] [117/240] RETRY Consumer Goods Honduras (will try 0.5x)
[13:06:29] [117/240] Consumer Goods Honduras | 0.68 @ 1.0x ($82400/u) | Flow:-2.37 Rev:$222877 Cost:$55719
[13:06:29] [116/240] RETRY Consumer Goods Chad (will try 0.5x)
[13:06:28] [116/240] Consumer Goods Chad | 0.69 @ 1.0x ($82400/u) | Flow:-2.20 Rev:$226276 Cost:$56569
[13:06:27] [115/240] OK Consumer Goods Kyrgyzstan
[13:06:27] [115/240] Consumer Goods Kyrgyzstan | 0.70 @ 1.0x ($82400/u) | Flow:-2.20 Rev:$229754 Cost:$57438
[13:06:27] [114/240] OK Consumer Goods Nepal
[13:06:26] [114/240] Consumer Goods Nepal | 0.70 @ 1.0x ($82400/u) | Flow:-2.59 Rev:$230038 Cost:$57510
[13:06:26] [113/240] OK Consumer Goods Jamaica
[13:06:25] [113/240] Consumer Goods Jamaica | 0.70 @ 1.0x ($82400/u) | Flow:-2.06 Rev:$230443 Cost:$57611
[13:06:25] [112/240] OK Consumer Goods Costa Rica
[13:06:24] [112/240] Consumer Goods Costa Rica | 0.70 @ 1.0x ($82400/u) | Flow:-2.36 Rev:$232297 Cost:$58074
[13:06:24] [111/240] RETRY Consumer Goods Georgia (will try 0.5x)
[13:06:23] [111/240] Consumer Goods Georgia | 0.73 @ 1.0x ($82400/u) | Flow:-2.02 Rev:$239521 Cost:$59880
[13:06:23] [110/240] OK Consumer Goods Burkina Faso
[13:06:22] [110/240] Consumer Goods Burkina Faso | 0.74 @ 1.0x ($82400/u) | Flow:-2.60 Rev:$245514 Cost:$61378
[13:06:22] [109/240] OK Consumer Goods Cambodia
[13:06:22] [109/240] Consumer Goods Cambodia | 0.75 @ 1.0x ($82400/u) | Flow:-2.59 Rev:$247395 Cost:$61849
[13:06:21] [108/240] OK Consumer Goods Serbia
[13:06:21] [108/240] Consumer Goods Serbia | 0.76 @ 1.0x ($82400/u) | Flow:-2.67 Rev:$249659 Cost:$62415
[13:06:20] [107/240] OK Consumer Goods El Salvador
[13:06:20] [107/240] Consumer Goods El Salvador | 0.76 @ 1.0x ($82400/u) | Flow:-2.73 Rev:$251526 Cost:$62882
[13:06:19] [106/240] OK Consumer Goods Norway
[13:06:19] [106/240] Consumer Goods Norway | 0.78 @ 1.0x ($82400/u) | Flow:-2.48 Rev:$257760 Cost:$64440
[13:06:18] [105/240] OK Consumer Goods Guatemala
[13:06:18] [105/240] Consumer Goods Guatemala | 0.79 @ 1.0x ($82400/u) | Flow:-3.19 Rev:$260177 Cost:$65044
[13:06:17] [104/240] OK Consumer Goods Republic of Congo
[13:06:17] [104/240] Consumer Goods Republic of Congo | 0.80 @ 1.0x ($82400/u) | Flow:-2.68 Rev:$262427 Cost:$65607
[13:06:17] [103/240] OK Consumer Goods Uruguay
[13:06:16] [103/240] Consumer Goods Uruguay | 0.80 @ 1.0x ($82400/u) | Flow:-2.96 Rev:$263116 Cost:$65779
[13:06:16] [102/240] RETRY Electronics Finland (will try 0.5x)
[13:06:15] [102/240] Electronics Finland | 0.65 @ 1.0x ($102000/u) | Flow:0.00 Rev:$266180 Cost:$66545
[13:06:15] [102/240] OK Consumer Goods Finland
[13:06:14] [102/240] Consumer Goods Finland | 0.81 @ 1.0x ($82400/u) | Flow:-2.80 Rev:$266180 Cost:$66545
[13:06:14] [101/240] OK Consumer Goods Jordan
[13:06:14] [101/240] Consumer Goods Jordan | 0.82 @ 1.0x ($82400/u) | Flow:-3.40 Rev:$270801 Cost:$67700
[13:06:13] [100/240] OK Consumer Goods Qatar
[13:06:13] [100/240] Consumer Goods Qatar | 0.82 @ 1.0x ($82400/u) | Flow:-1.60 Rev:$270850 Cost:$67712
[13:06:12] [99/240] OK Consumer Goods Mali
[13:06:12] [99/240] Consumer Goods Mali | 0.84 @ 1.0x ($82400/u) | Flow:-3.08 Rev:$275443 Cost:$68861
[13:06:11] [98/240] OK Consumer Goods Czech Republic
[13:06:11] [98/240] Consumer Goods Czech Republic | 0.84 @ 1.0x ($82400/u) | Flow:-3.27 Rev:$278505 Cost:$69626
[13:06:10] [97/240] OK Consumer Goods Lebanon
[13:06:10] [97/240] Consumer Goods Lebanon | 0.86 @ 1.0x ($82400/u) | Flow:-3.19 Rev:$282020 Cost:$70505
[13:06:10] [96/240] OK Consumer Goods Niger
[13:06:09] [96/240] Consumer Goods Niger | 0.86 @ 1.0x ($82400/u) | Flow:-2.20 Rev:$282167 Cost:$70542
[13:06:09] [95/240] OK Consumer Goods Haiti
[13:06:09] [95/240] Consumer Goods Haiti | 0.86 @ 1.0x ($82400/u) | Flow:-3.11 Rev:$283168 Cost:$70792
[13:06:08] [94/240] OK Consumer Goods Turkmenistan
[13:06:08] [94/240] Consumer Goods Turkmenistan | 0.87 @ 1.0x ($82400/u) | Flow:-1.96 Rev:$288184 Cost:$72046
[13:06:07] [93/240] OK Consumer Goods Togo
[13:06:06] [93/240] Consumer Goods Togo | 0.89 @ 1.0x ($82400/u) | Flow:-2.07 Rev:$292026 Cost:$73006
[13:06:06] [92/240] OK Consumer Goods New Zealand
[13:06:06] [92/240] Consumer Goods New Zealand | 0.91 @ 1.0x ($82400/u) | Flow:-4.71 Rev:$301169 Cost:$75292
[13:06:05] [91/240] OK Consumer Goods Paraguay
[13:06:05] [91/240] Consumer Goods Paraguay | 0.95 @ 1.0x ($82400/u) | Flow:-3.97 Rev:$314004 Cost:$78501
[13:06:04] [90/240] OK Consumer Goods Azerbaijan
[13:06:04] [90/240] Consumer Goods Azerbaijan | 0.96 @ 1.0x ($82400/u) | Flow:-3.62 Rev:$316958 Cost:$79240
[13:06:03] [89/240] OK Consumer Goods Mongolia
[13:06:03] [89/240] Consumer Goods Mongolia | 0.97 @ 1.0x ($82400/u) | Flow:-2.22 Rev:$319171 Cost:$79793
[13:06:03] [88/240] OK Consumer Goods Kuwait
[13:06:02] [88/240] Consumer Goods Kuwait | 0.97 @ 1.0x ($82400/u) | Flow:-2.57 Rev:$319447 Cost:$79862
[13:06:02] [87/240] RETRY Consumer Goods Madagascar (will try 0.5x)
[13:06:01] [87/240] Consumer Goods Madagascar | 0.98 @ 1.0x ($82400/u) | Flow:-3.53 Rev:$324122 Cost:$81030
[13:06:01] [86/240] OK Consumer Goods Hungary
[13:06:00] [86/240] Consumer Goods Hungary | 0.99 @ 1.0x ($82400/u) | Flow:-4.25 Rev:$326808 Cost:$81702
[13:06:00] [85/240] OK Consumer Goods Uganda
[13:06:00] [85/240] Consumer Goods Uganda | 1.00 @ 1.0x ($82400/u) | Flow:-4.28 Rev:$329109 Cost:$82277
[13:05:59] [83/240] OK Consumer Goods Israel
[13:05:59] [83/240] Consumer Goods Israel | 1.03 @ 1.0x ($82400/u) | Flow:-5.72 Rev:$339753 Cost:$84938
[13:05:59] [76/240] RETRY Electronics Switzerland (will try 0.5x)
[13:05:58] [76/240] Electronics Switzerland | 0.98 @ 1.0x ($102000/u) | Flow:0.00 Rev:$399339 Cost:$99835
[13:05:57] [74/240] OK Consumer Goods Mozambique
[13:05:57] [74/240] Consumer Goods Mozambique | 1.22 @ 1.0x ($82400/u) | Flow:-5.29 Rev:$401245 Cost:$100311
[13:05:57] [66/240] RETRY Consumer Goods Greece (will try 0.5x)
[13:05:56] [66/240] Consumer Goods Greece | 1.42 @ 1.0x ($82400/u) | Flow:-6.70 Rev:$468939 Cost:$117235
[13:05:55] [51/240] OK Consumer Goods Ghana
[13:05:55] [51/240] Consumer Goods Ghana | 2.05 @ 1.0x ($82400/u) | Flow:-6.26 Rev:$604641 Cost:$169299
[13:05:54] [50/240] OK Consumer Goods Sierra Leone
[13:05:54] [50/240] Consumer Goods Sierra Leone | 1.46 @ 1.0x ($82400/u) | Flow:-1.46 Rev:$626132 Cost:$119956
[13:05:54] [32/240] RETRY Consumer Goods Peru (will try 0.5x)
[13:05:53] [32/240] Consumer Goods Peru | 4.64 @ 1.0x ($82400/u) | Flow:-18.87 Rev:$1193714 Cost:$381988
[13:05:53] [30/240] OK Electronics Taiwan
[13:05:52] [30/240] Electronics Taiwan | 4.02 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1280775 Cost:$409848
[13:05:52] [27/240] OK Consumer Goods Bangladesh
[13:05:52] [27/240] Consumer Goods Bangladesh | 6.13 @ 1.0x ($82400/u) | Flow:-24.59 Rev:$1579466 Cost:$505429
[13:05:51] [8/240] OK Consumer Goods Mexico
[13:05:50] [8/240] Consumer Goods Mexico | 14.27 @ 1.0x ($82400/u) | Flow:-72.69 Rev:$3675309 Cost:$1176099
[13:05:50] Trade cycle started
[13:05:50] TRIGGERED: Consumer Goods 452.4 Electronics 549.5
[13:05:50] War Monitor: ON
[13:05:50] Auto-Buy: ON
[13:05:50] Auto-Sell: ON
[13:05:49] Country: Libya
[13:05:49] Trade Hub v2.1.1 loaded
