# Trade Analysis Context

This document captures findings from analyzing Consumer Goods trade acceptance patterns in Rise of Nations.

## Session Summary (2026-02-01)

### Goal
Understand the game's trade acceptance mechanics to maximize revenue:
1. Track which countries accept which price tiers
2. Correlate with **ranking** to find patterns
3. Adjust the algorithm based on findings

### Problem Statement
Consumer Goods trades were showing inconsistent acceptance patterns:
- Same countries FAIL then OK at the same price tier on retry
- No clear correlation with cost percentage, revenue, or amount
- **Ranking was not analyzed** - might be the key factor

## Debug Log Format (NEW)

The script now outputs data specifically designed to track each country's journey:

```
TRADE|Country|Rank|Resource|PriceTier|Amount|Cost%|Revenue|Result
```

### Example Output
```
TRADE|Slovakia|140|Cons|1.0x|1.31|4.85%|$221855|FAIL
TRADE|Slovakia|140|Cons|0.5x|1.31|2.43%|$221855|OK
```
This shows: Slovakia (rank 140) failed at 1.0x but succeeded at 0.5x

### Another Example
```
TRADE|United States|1|Cons|1.0x|275.35|9.19%|$24700161|FAIL
TRADE|United States|1|Cons|0.5x|275.35|4.59%|$24700161|FAIL  
TRADE|United States|1|Cons|0.1x|275.35|0.92%|$24700161|OK
```
This shows: USA (rank 1) only accepts 0.1x price

### Fields
| Field | Description |
|-------|-------------|
| Country | Target country name |
| Rank | Country ranking (1=most powerful) |
| Resource | First 4 chars of resource |
| PriceTier | `1.0x`, `0.5x`, or `0.1x` |
| Amount | Units being traded |
| Cost% | Total cost as % of revenue |
| Revenue | Country's total revenue |
| Result | `OK` or `FAIL` |

## How to Submit Data for Analysis

### What to Paste
Just copy all the `TRADE|...` lines from the console output and paste them.

### What I'll Analyze

1. **Ranking patterns** - Do high-ranked countries (1-50) only accept low prices?
2. **Price tier success rates** - What % succeed at 1.0x vs 0.5x vs 0.1x?
3. **Journey patterns** - Which countries need multiple attempts?
4. **The actual game mechanic** - What's really causing acceptance/rejection?

### The format makes it easy to:
- Sort by ranking
- Group by result (OK/FAIL)
- Track each country's journey through price tiers
- Find the pattern that determines acceptance

### Example Analysis Output
After receiving data, I'll provide:
```
=== RANKING ANALYSIS ===
Rank 1-20:   1.0x success: 5%,  0.5x success: 30%, 0.1x success: 95%
Rank 21-50:  1.0x success: 20%, 0.5x success: 60%, 0.1x success: 98%
Rank 51-100: 1.0x success: 45%, 0.5x success: 85%, 0.1x success: 99%
Rank 100+:   1.0x success: 70%, 0.5x success: 95%, 0.1x success: 100%

=== RECOMMENDATION ===
Based on data:
- Rank 1-20: Start at 0.5x (skip 1.0x to save time)
- Rank 21-100: Start at 1.0x (worth trying)
- Rank 100+: Start at 1.0x (high success rate)
```

## Manual Analysis Steps

### Step 1: Run the script and collect output
```bash
# The script prints TRADE| lines to console
# Copy/save the output
```

### Step 2: Filter and sort by ranking
```bash
grep "TRADE|" output.log | sort -t'|' -k2 -n
```

### Step 3: Look for patterns
- Do all rank 1-20 countries only accept 0.1x?
- Do rank 100+ countries accept 0.5x or 1.0x?
- Is there a ranking threshold for each price tier?

### Step 4: Build a ranking-based pricing table
Example hypothesis:
```
Rank 1-50:    Only accepts 0.1x
Rank 51-100:  Accepts 0.5x or lower
Rank 100+:    Accepts 1.0x
```

## Current Algorithm (v1.6)

### Price Tier Strategy
1. **Start at 1.0x** (maximum revenue per unit)
2. If fails → queue retry at **0.5x**
3. If fails → queue retry at **0.1x**
4. If still fails → permanent fail

### Queue-Based Retry
- Failed trades are queued for later processing
- Processing other countries provides ~10 second cooldown
- Cooldown is required by game mechanics between trades with same country

## Key Observations from Initial Data

### 1. Trade Acceptance is NOT Purely Cost-Based
Analysis of 45+ trades showed complete overlap between OK and FAIL cost percentages.

### 2. Game Has ~10 Second Trade Cooldown
Queue-based retry naturally provides this cooldown.

### 3. Ranking - HYPOTHESIS TO TEST
- Higher ranked (lower number) = more powerful = stricter?
- Lower ranked (higher number) = weaker = more desperate for resources?

## Workflow

### Step 1: Run the script
Execute Consumer Goods trading and let it complete a full cycle.

### Step 2: Copy debug output
All lines starting with `TRADE|` contain the analysis data.

### Step 3: Paste to Claude for analysis
I will analyze the data looking for:
- **Ranking patterns**: Do certain rank ranges only accept certain tiers?
- **Revenue patterns**: Does revenue affect acceptance beyond cost%?
- **Price tier patterns**: What's the success rate at each tier?
- **Journey patterns**: Countries that fail 1.0x → succeed 0.5x vs fail both → succeed 0.1x

### Step 4: Update algorithm
Based on findings, we can:
- Skip 1.0x for high-ranked countries (save time)
- Start at 0.5x for mid-ranked countries
- Only use 1.0x for low-ranked countries
- Or discover a completely different pattern

## Files in This Repository

| File | Purpose |
|------|---------|
| `trading.lua` | Trade execution, attemptTrade, processCountryResource |
| `helpers.lua` | getPriceTier, getNextPriceTier, getCountryResourceData |
| `config.lua` | Revenue spending tiers, retry settings |
| `autosell.lua` | Auto-sell trigger when flow exceeds threshold |
| `autobuyer.lua` | Auto-buy when resources are needed |
| `ui.lua` | Rayfield UI, logging, status display |
| `main.lua` | Module loader and initialization |
| `TRADE_ANALYSIS.md` | This context file |

## Revenue Spending Tiers (from config.lua)

Current dynamic limits (may need adjustment based on data):
```lua
{10000000, 0.38},  -- $10M+ revenue: up to 38%
{5000000, 0.35},   -- $5M+ revenue: up to 35%
{1000000, 0.32},   -- $1M+ revenue: up to 32%
{500000, 0.28},    -- $500K+ revenue: up to 28%
{100000, 0.25},    -- $100K+ revenue: up to 25%
{0, 0.20},         -- Below $100K: up to 20%
```

## Version History

- **v1.6**: Multi-resource support, queue-based retry
- **Current session**: Added ranking-aware debug output, context file

## Revenue Spending Tiers (from config.lua)

Current dynamic limits based on revenue:
```lua
{10000000, 0.38},  -- $10M+ revenue: up to 38%
{5000000, 0.35},   -- $5M+ revenue: up to 35%
{1000000, 0.32},   -- $1M+ revenue: up to 32%
{500000, 0.28},    -- $500K+ revenue: up to 28%
{100000, 0.25},    -- $100K+ revenue: up to 25%
{0, 0.20},         -- Below $100K: up to 20%
```

These may need recalibration based on actual data.

## Files Modified

- `trading.lua` - Trade execution logic, attemptTrade function
- `helpers.lua` - getPriceTier, getNextPriceTier, getCountryResourceData
- `config.lua` - Revenue spending tiers, retry settings

## Next Steps

1. Run Consumer Goods trades and collect debug output
2. Filter for ranking patterns: `grep "DBG|" output.log | sort by ranking`
3. Compare OK vs FAIL trades grouped by ranking
4. Update spending tiers based on findings
