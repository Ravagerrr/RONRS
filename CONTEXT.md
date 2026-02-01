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
| `ui.lua` | Rayfield UI, logging |
| `TRADE_ANALYSIS.md` | Detailed analysis documentation |
| `CONTEXT.md` | **THIS FILE** - read first, update last |

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
