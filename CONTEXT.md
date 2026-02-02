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
| `ui.lua` | Rayfield UI v2.0 - Dashboard, Resources, Automation, Settings, Logs |
| `main.lua` | Entry point, module loader |
| `TRADE_ANALYSIS.md` | Detailed analysis documentation |
| `CONTEXT.md` | **THIS FILE** - read first, update last |

### UI v2.0 Tab Structure
1. **Dashboard** - Status overview (country, state, auto-sell/buy), resource flow, emergency stop
2. **Resources** - Sell resource toggles + Buy resource toggles (all in one place)
3. **Automation** - Auto-Sell settings + Auto-Buy settings (enable, thresholds, intervals)
4. **Settings** - Flow protection, timing, trade filters
5. **Logs** - Activity log with copy/clear buttons

---

## 🔧 How the Code Works

### Trade Flow
1. `autosell.lua` detects surplus flow → triggers `trading.run()`
2. `trading.run()` iterates through countries sorted by revenue
3. For each country, `processCountryResource()` calculates amount and price
4. `attemptTrade()` fires the trade and verifies acceptance
5. Failed trades get queued for retry at lower price tier

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
