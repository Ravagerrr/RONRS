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


[12:02:24] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:02:24] Trade cycle started
[12:02:24] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:24] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:24] Trade cycle started
[12:02:24] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:23] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:23] Trade cycle started
[12:02:23] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:23] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:22] Trade cycle started
[12:02:22] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:22] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:22] Trade cycle started
[12:02:22] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:22] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:21] Trade cycle started
[12:02:21] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:21] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:21] Trade cycle started
[12:02:21] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:20] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:20] Trade cycle started
[12:02:20] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:20] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:19] Trade cycle started
[12:02:19] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:19] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:19] Trade cycle started
[12:02:19] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:19] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:18] Trade cycle started
[12:02:18] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:18] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:18] Trade cycle started
[12:02:18] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:17] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:17] Trade cycle started
[12:02:17] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:17] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:17] Trade cycle started
[12:02:17] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:16] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:16] Trade cycle started
[12:02:16] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:16] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:15] Trade cycle started
[12:02:15] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:15] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:15] Trade cycle started
[12:02:15] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:15] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:14] Trade cycle started
[12:02:14] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:14] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:14] Trade cycle started
[12:02:14] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:13] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:13] Trade cycle started
[12:02:13] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:13] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:12] Trade cycle started
[12:02:12] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:12] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:12] Trade cycle started
[12:02:12] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:12] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:11] Trade cycle started
[12:02:11] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:11] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:11] Trade cycle started
[12:02:11] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:10] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:10] Trade cycle started
[12:02:10] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:10] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:10] Trade cycle started
[12:02:10] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:09] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:02:09] Trade cycle started
[12:02:09] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:09] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:02:08] Trade cycle started
[12:02:08] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:08] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:08] Trade cycle started
[12:02:08] TRIGGERED: Consumer Goods 41.2 Electronics 295.5
[12:02:08] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:07] Trade cycle started
[12:02:07] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:07] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:07] Trade cycle started
[12:02:07] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:06] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:06] Trade cycle started
[12:02:06] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:06] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:05] Trade cycle started
[12:02:05] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:05] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:05] Trade cycle started
[12:02:05] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:05] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:04] Trade cycle started
[12:02:04] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:04] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:04] Trade cycle started
[12:02:04] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:04] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:03] Trade cycle started
[12:02:03] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:03] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:03] Trade cycle started
[12:02:03] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:02] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:02] Trade cycle started
[12:02:02] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:02] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:02:01] Trade cycle started
[12:02:01] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:01] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:02:01] Trade cycle started
[12:02:01] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:01] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:00] Trade cycle started
[12:02:00] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:00] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:02:00] Trade cycle started
[12:02:00] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:02:00] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:01:59] Trade cycle started
[12:01:59] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:59] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:01:59] Trade cycle started
[12:01:59] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:58] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:01:58] Trade cycle started
[12:01:58] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:58] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:01:58] Trade cycle started
[12:01:58] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:57] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:01:57] Trade cycle started
[12:01:57] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:57] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:56] Trade cycle started
[12:01:56] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:56] Done in 0.3s | OK:0 Skip:480 Fail:0
[12:01:56] Trade cycle started
[12:01:56] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:56] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:55] Trade cycle started
[12:01:55] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:55] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:55] Trade cycle started
[12:01:55] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:55] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:54] Trade cycle started
[12:01:54] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:54] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:54] Trade cycle started
[12:01:54] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:53] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:53] Trade cycle started
[12:01:53] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:53] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:52] Trade cycle started
[12:01:52] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:52] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:52] Trade cycle started
[12:01:52] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:52] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:51] Trade cycle started
[12:01:51] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:51] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:51] Trade cycle started
[12:01:51] TRIGGERED: Consumer Goods 31.6 Electronics 291.6
[12:01:50] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:50] Trade cycle started
[12:01:50] TRIGGERED: Consumer Goods 31.5 Electronics 291.6
[12:01:50] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:50] Trade cycle started
[12:01:50] TRIGGERED: Consumer Goods 31.5 Electronics 291.6
[12:01:49] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:49] Trade cycle started
[12:01:49] TRIGGERED: Consumer Goods 31.5 Electronics 291.6
[12:01:49] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:48] Trade cycle started
[12:01:48] TRIGGERED: Consumer Goods 31.5 Electronics 291.6
[12:01:48] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:48] Trade cycle started
[12:01:48] TRIGGERED: Consumer Goods 31.5 Electronics 291.6
[12:01:48] Done in 0.4s | OK:0 Skip:480 Fail:0
[12:01:47] Trade cycle started
[12:01:47] TRIGGERED: Consumer Goods 31.5 Electronics 291.6
[12:01:47] [FLOW Q] Completed 1 queued trades
[12:01:47] [FLOW Q] Complete: Consumer Goods Slovakia
[12:01:47] [FLOW Q] OK +0.46 Consumer Goods to Slovakia
[12:01:47] [FLOW Q] Trying 0.46 Consumer Goods to Slovakia
[12:01:47] Done in 6.2s | OK:7 Skip:473 Fail:0
[12:01:46] [133/240] OK Consumer Goods Sri Lanka
[12:01:46] [133/240] Consumer Goods Sri Lanka | 0.56 @ 1.0x ($82400/u) | Flow:-1.76 Rev:$186006 Cost:$46502
[12:01:45] [122/240] OK Consumer Goods Rwanda
[12:01:45] [122/240] Consumer Goods Rwanda | 0.61 @ 1.0x ($82400/u) | Flow:-1.72 Rev:$201826 Cost:$50456
[12:01:44] [113/240] OK Consumer Goods Chad
[12:01:44] [113/240] Consumer Goods Chad | 0.67 @ 1.0x ($82400/u) | Flow:-2.11 Rev:$221108 Cost:$55277
[12:01:43] [100/240] OK Consumer Goods Finland
[12:01:43] [100/240] Consumer Goods Finland | 0.79 @ 1.0x ($82400/u) | Flow:-2.69 Rev:$259515 Cost:$64879
[12:01:42] [88/240] OK Consumer Goods Azerbaijan
[12:01:42] [88/240] Consumer Goods Azerbaijan | 0.94 @ 1.0x ($82400/u) | Flow:-3.48 Rev:$308300 Cost:$77075
[12:01:42] [75/240] OK Consumer Goods Belarus
[12:01:41] [75/240] Consumer Goods Belarus | 1.15 @ 1.0x ($82400/u) | Flow:-5.10 Rev:$377871 Cost:$94468
[12:01:41] [49/240] OK Consumer Goods Ghana
[12:01:41] [49/240] Consumer Goods Ghana | 1.99 @ 1.0x ($82400/u) | Flow:-6.02 Rev:$586036 Cost:$164090
[12:01:40] Trade cycle started
[12:01:40] TRIGGERED: Consumer Goods 38.6 Electronics 291.6
[12:01:40] [FLOW Q] Failed: Consumer Goods Slovakia
[12:01:39] [FLOW Q] Trying 0.46 Consumer Goods to Slovakia
[12:01:39] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:39] Trade cycle started
[12:01:39] TRIGGERED: Electronics 256.8
[12:01:39] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:39] Trade cycle started
[12:01:39] TRIGGERED: Electronics 256.8
[12:01:38] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:38] Trade cycle started
[12:01:38] TRIGGERED: Electronics 256.8
[12:01:38] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:38] Trade cycle started
[12:01:38] TRIGGERED: Electronics 256.8
[12:01:38] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:38] Trade cycle started
[12:01:38] TRIGGERED: Electronics 256.8
[12:01:37] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:37] Trade cycle started
[12:01:37] TRIGGERED: Electronics 256.8
[12:01:37] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:37] Trade cycle started
[12:01:37] TRIGGERED: Electronics 256.8
[12:01:37] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:36] Trade cycle started
[12:01:36] TRIGGERED: Electronics 256.8
[12:01:36] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:36] Trade cycle started
[12:01:36] TRIGGERED: Electronics 256.8
[12:01:36] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:36] Trade cycle started
[12:01:36] TRIGGERED: Electronics 256.8
[12:01:35] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:35] Trade cycle started
[12:01:35] TRIGGERED: Electronics 256.8
[12:01:35] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:35] Trade cycle started
[12:01:35] TRIGGERED: Electronics 256.8
[12:01:35] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:34] Trade cycle started
[12:01:34] TRIGGERED: Electronics 256.8
[12:01:34] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:34] Trade cycle started
[12:01:34] TRIGGERED: Electronics 256.8
[12:01:34] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:34] Trade cycle started
[12:01:34] TRIGGERED: Electronics 256.8
[12:01:33] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:33] Trade cycle started
[12:01:33] TRIGGERED: Electronics 256.8
[12:01:33] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:33] Trade cycle started
[12:01:33] TRIGGERED: Electronics 256.8
[12:01:33] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:32] Trade cycle started
[12:01:32] TRIGGERED: Electronics 256.8
[12:01:32] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:32] Trade cycle started
[12:01:32] TRIGGERED: Electronics 256.8
[12:01:32] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:32] Trade cycle started
[12:01:32] TRIGGERED: Electronics 256.8
[12:01:31] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:31] Trade cycle started
[12:01:31] TRIGGERED: Electronics 256.8
[12:01:31] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:31] Trade cycle started
[12:01:31] TRIGGERED: Electronics 256.8
[12:01:31] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:30] Trade cycle started
[12:01:30] TRIGGERED: Electronics 256.8
[12:01:30] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:01:30] Trade cycle started
[12:01:30] TRIGGERED: Electronics 256.8
[12:01:30] Done in 52.1s | OK:54 Skip:302 Fail:0
[12:01:30] RETRY: 5
[12:01:29] [FLOW Q] Queued 0.46 Consumer Goods to Slovakia (expires in 30s)
[12:01:29] [121/240] OK Consumer Goods Slovakia
[12:01:29] [121/240] Consumer Goods Slovakia | 0.17 @ 1.0x ($82400/u) | Flow:-1.10 Rev:$207468 Cost:$13952
[12:01:28] [120/240] OK Consumer Goods Liberia
[12:01:28] [120/240] Consumer Goods Liberia | 0.64 @ 1.0x ($82400/u) | Flow:-1.37 Rev:$211101 Cost:$52775
[12:01:27] [119/240] OK Consumer Goods Nicaragua
[12:01:27] [119/240] Consumer Goods Nicaragua | 0.64 @ 1.0x ($82400/u) | Flow:-2.15 Rev:$212161 Cost:$53040
[12:01:26] [118/240] OK Consumer Goods Denmark
[12:01:26] [118/240] Consumer Goods Denmark | 0.65 @ 1.0x ($82400/u) | Flow:-2.02 Rev:$212948 Cost:$53237
[12:01:26] [117/240] OK Consumer Goods Albania
[12:01:25] [117/240] Consumer Goods Albania | 0.65 @ 1.0x ($82400/u) | Flow:-2.05 Rev:$213321 Cost:$53330
[12:01:25] [116/240] OK Consumer Goods Oman
[12:01:25] [116/240] Consumer Goods Oman | 0.65 @ 1.0x ($82400/u) | Flow:-1.83 Rev:$213944 Cost:$53486
[12:01:24] [115/240] OK Consumer Goods Panama
[12:01:24] [115/240] Consumer Goods Panama | 0.65 @ 1.0x ($82400/u) | Flow:-1.94 Rev:$214557 Cost:$53639
[12:01:23] [114/240] OK Consumer Goods Honduras
[12:01:23] [114/240] Consumer Goods Honduras | 0.66 @ 1.0x ($82400/u) | Flow:-2.28 Rev:$217759 Cost:$54440
[12:01:23] [113/240] RETRY Consumer Goods Chad (will try 0.5x)
[12:01:22] [113/240] Consumer Goods Chad | 0.67 @ 1.0x ($82400/u) | Flow:-2.11 Rev:$220970 Cost:$55243
[12:01:21] [112/240] OK Consumer Goods Nepal
[12:01:21] [112/240] Consumer Goods Nepal | 0.68 @ 1.0x ($82400/u) | Flow:-2.48 Rev:$224615 Cost:$56154
[12:01:20] [111/240] OK Consumer Goods Jamaica
[12:01:20] [111/240] Consumer Goods Jamaica | 0.68 @ 1.0x ($82400/u) | Flow:-1.98 Rev:$225325 Cost:$56331
[12:01:19] [110/240] OK Consumer Goods Costa Rica
[12:01:19] [110/240] Consumer Goods Costa Rica | 0.69 @ 1.0x ($82400/u) | Flow:-2.26 Rev:$226712 Cost:$56678
[12:01:19] [109/240] OK Consumer Goods Georgia
[12:01:18] [109/240] Consumer Goods Georgia | 0.71 @ 1.0x ($82400/u) | Flow:-1.94 Rev:$234121 Cost:$58530
[12:01:18] [108/240] OK Consumer Goods Burkina Faso
[12:01:18] [108/240] Consumer Goods Burkina Faso | 0.73 @ 1.0x ($82400/u) | Flow:-2.49 Rev:$239415 Cost:$59854
[12:01:17] [107/240] OK Consumer Goods Cambodia
[12:01:17] [107/240] Consumer Goods Cambodia | 0.73 @ 1.0x ($82400/u) | Flow:-2.48 Rev:$241156 Cost:$60289
[12:01:16] [106/240] OK Consumer Goods Serbia
[12:01:16] [106/240] Consumer Goods Serbia | 0.74 @ 1.0x ($82400/u) | Flow:-2.56 Rev:$243420 Cost:$60855
[12:01:15] [105/240] OK Consumer Goods El Salvador
[12:01:15] [105/240] Consumer Goods El Salvador | 0.74 @ 1.0x ($82400/u) | Flow:-2.62 Rev:$245142 Cost:$61285
[12:01:14] [104/240] OK Consumer Goods Norway
[12:01:14] [104/240] Consumer Goods Norway | 0.76 @ 1.0x ($82400/u) | Flow:-2.37 Rev:$251185 Cost:$62796
[12:01:13] [103/240] OK Consumer Goods Guatemala
[12:01:13] [103/240] Consumer Goods Guatemala | 0.77 @ 1.0x ($82400/u) | Flow:-3.06 Rev:$253503 Cost:$63376
[12:01:13] [102/240] OK Consumer Goods Republic of Congo
[12:01:12] [102/240] Consumer Goods Republic of Congo | 0.78 @ 1.0x ($82400/u) | Flow:-2.57 Rev:$255651 Cost:$63913
[12:01:12] [101/240] OK Consumer Goods Uruguay
[12:01:12] [101/240] Consumer Goods Uruguay | 0.78 @ 1.0x ($82400/u) | Flow:-2.84 Rev:$256263 Cost:$64066
[12:01:12] [100/240] RETRY Consumer Goods Finland (will try 0.5x)
[12:01:10] [100/240] Consumer Goods Finland | 0.79 @ 1.0x ($82400/u) | Flow:-2.68 Rev:$259242 Cost:$64810
[12:01:10] [99/240] OK Consumer Goods Jordan
[12:01:10] [99/240] Consumer Goods Jordan | 0.80 @ 1.0x ($82400/u) | Flow:-3.26 Rev:$263739 Cost:$65935
[12:01:09] [98/240] OK Consumer Goods Qatar
[12:01:09] [98/240] Consumer Goods Qatar | 0.80 @ 1.0x ($82400/u) | Flow:-1.54 Rev:$264842 Cost:$66210
[12:01:08] [97/240] OK Consumer Goods Mali
[12:01:08] [97/240] Consumer Goods Mali | 0.81 @ 1.0x ($82400/u) | Flow:-2.95 Rev:$268116 Cost:$67029
[12:01:07] [96/240] OK Consumer Goods Czech Republic
[12:01:07] [96/240] Consumer Goods Czech Republic | 0.82 @ 1.0x ($82400/u) | Flow:-3.14 Rev:$271163 Cost:$67791
[12:01:06] [95/240] OK Consumer Goods Lebanon
[12:01:06] [95/240] Consumer Goods Lebanon | 0.83 @ 1.0x ($82400/u) | Flow:-3.06 Rev:$274413 Cost:$68603
[12:01:06] [94/240] OK Consumer Goods Haiti
[12:01:05] [94/240] Consumer Goods Haiti | 0.84 @ 1.0x ($82400/u) | Flow:-2.98 Rev:$275419 Cost:$68855
[12:01:04] [93/240] OK Consumer Goods Niger
[12:01:04] [93/240] Consumer Goods Niger | 0.84 @ 1.0x ($82400/u) | Flow:-2.11 Rev:$275963 Cost:$68991
[12:01:03] [92/240] OK Consumer Goods Turkmenistan
[12:01:03] [92/240] Consumer Goods Turkmenistan | 0.85 @ 1.0x ($82400/u) | Flow:-1.88 Rev:$281635 Cost:$70409
[12:01:02] [91/240] OK Consumer Goods Togo
[12:01:02] [91/240] Consumer Goods Togo | 0.87 @ 1.0x ($82400/u) | Flow:-1.99 Rev:$285249 Cost:$71312
[12:01:02] [90/240] OK Consumer Goods New Zealand
[12:01:01] [90/240] Consumer Goods New Zealand | 0.89 @ 1.0x ($82400/u) | Flow:-4.52 Rev:$293055 Cost:$73264
[12:01:01] [89/240] OK Consumer Goods Paraguay
[12:01:01] [89/240] Consumer Goods Paraguay | 0.93 @ 1.0x ($82400/u) | Flow:-3.81 Rev:$305095 Cost:$76274
[12:01:01] [88/240] RETRY Consumer Goods Azerbaijan (will try 0.5x)
[12:00:59] [88/240] Consumer Goods Azerbaijan | 0.93 @ 1.0x ($82400/u) | Flow:-3.47 Rev:$307819 Cost:$76955
[12:00:59] [87/240] OK Consumer Goods Kyrgyzstan
[12:00:59] [87/240] Consumer Goods Kyrgyzstan | 0.94 @ 1.0x ($82400/u) | Flow:-2.10 Rev:$310586 Cost:$77646
[12:00:58] [86/240] OK Consumer Goods Kuwait
[12:00:58] [86/240] Consumer Goods Kuwait | 0.94 @ 1.0x ($82400/u) | Flow:-2.46 Rev:$310976 Cost:$77744
[12:00:57] [85/240] OK Consumer Goods Mongolia
[12:00:57] [85/240] Consumer Goods Mongolia | 0.94 @ 1.0x ($82400/u) | Flow:-2.13 Rev:$311397 Cost:$77849
[12:00:56] [84/240] OK Consumer Goods Madagascar
[12:00:56] [84/240] Consumer Goods Madagascar | 0.96 @ 1.0x ($82400/u) | Flow:-3.39 Rev:$314821 Cost:$78705
[12:00:55] [83/240] OK Consumer Goods Hungary
[12:00:55] [83/240] Consumer Goods Hungary | 0.96 @ 1.0x ($82400/u) | Flow:-4.07 Rev:$317449 Cost:$79362
[12:00:54] [82/240] OK Consumer Goods Uganda
[12:00:54] [82/240] Consumer Goods Uganda | 0.97 @ 1.0x ($82400/u) | Flow:-4.10 Rev:$319594 Cost:$79898
[12:00:53] [81/240] OK Consumer Goods Somalia
[12:00:53] [81/240] Consumer Goods Somalia | 0.98 @ 1.0x ($82400/u) | Flow:-3.45 Rev:$323809 Cost:$80952
[12:00:53] [80/240] OK Consumer Goods Israel
[12:00:52] [80/240] Consumer Goods Israel | 1.00 @ 1.0x ($82400/u) | Flow:-5.49 Rev:$329729 Cost:$82432
[12:00:52] [79/240] OK Consumer Goods Belgium
[12:00:51] [79/240] Consumer Goods Belgium | 1.05 @ 1.0x ($82400/u) | Flow:-4.90 Rev:$345055 Cost:$86264
[12:00:51] [78/240] OK Consumer Goods United Arab Emirates
[12:00:51] [78/240] Consumer Goods United Arab Emirates | 1.06 @ 1.0x ($82400/u) | Flow:-4.00 Rev:$350932 Cost:$87733
[12:00:50] [77/240] OK Consumer Goods Cuba
[12:00:50] [77/240] Consumer Goods Cuba | 1.07 @ 1.0x ($82400/u) | Flow:-6.19 Rev:$352466 Cost:$88116
[12:00:49] [76/240] OK Consumer Goods Bulgaria
[12:00:49] [76/240] Consumer Goods Bulgaria | 1.12 @ 1.0x ($82400/u) | Flow:-3.40 Rev:$370383 Cost:$92596
[12:00:49] [75/240] RETRY Consumer Goods Belarus (will try 0.5x)
[12:00:48] [75/240] Consumer Goods Belarus | 1.14 @ 1.0x ($82400/u) | Flow:-5.09 Rev:$377090 Cost:$94272
[12:00:47] [74/240] OK Consumer Goods Switzerland
[12:00:47] [74/240] Consumer Goods Switzerland | 1.17 @ 1.0x ($82400/u) | Flow:-4.84 Rev:$387109 Cost:$96777
[12:00:46] [73/240] OK Consumer Goods Lesotho
[12:00:46] [73/240] Consumer Goods Lesotho | 0.58 @ 1.0x ($82400/u) | Flow:-0.58 Rev:$388616 Cost:$47547
[12:00:46] [72/240] OK Consumer Goods Mozambique
[12:00:45] [72/240] Consumer Goods Mozambique | 1.18 @ 1.0x ($82400/u) | Flow:-5.07 Rev:$388831 Cost:$97208
[12:00:45] [71/240] OK Consumer Goods Guinea
[12:00:45] [71/240] Consumer Goods Guinea | 1.18 @ 1.0x ($82400/u) | Flow:-3.03 Rev:$389609 Cost:$97402
[12:00:44] [70/240] OK Consumer Goods Dominican Republic
[12:00:44] [70/240] Consumer Goods Dominican Republic | 1.21 @ 1.0x ($82400/u) | Flow:-5.97 Rev:$399637 Cost:$99909
[12:00:43] [69/240] OK Consumer Goods Sweden
[12:00:43] [69/240] Consumer Goods Sweden | 1.26 @ 1.0x ($82400/u) | Flow:-4.00 Rev:$414055 Cost:$103514
[12:00:42] [68/240] OK Consumer Goods Austria
[12:00:42] [68/240] Consumer Goods Austria | 1.27 @ 1.0x ($82400/u) | Flow:-3.79 Rev:$417278 Cost:$104320
[12:00:41] [67/240] OK Consumer Goods Yemen
[12:00:41] [67/240] Consumer Goods Yemen | 1.28 @ 1.0x ($82400/u) | Flow:-6.43 Rev:$420988 Cost:$105247
[12:00:41] [66/240] OK Consumer Goods Zambia
[12:00:40] [66/240] Consumer Goods Zambia | 1.32 @ 1.0x ($82400/u) | Flow:-4.13 Rev:$434433 Cost:$108608
[12:00:40] [65/240] OK Consumer Goods Portugal
[12:00:39] [65/240] Consumer Goods Portugal | 1.32 @ 1.0x ($82400/u) | Flow:-6.34 Rev:$434912 Cost:$108728
[12:00:39] [64/240] OK Consumer Goods Greece
[12:00:39] [64/240] Consumer Goods Greece | 1.38 @ 1.0x ($82400/u) | Flow:-6.43 Rev:$453533 Cost:$113383
[12:00:39] [49/240] RETRY Consumer Goods Ghana (will try 0.5x)
[12:00:38] [49/240] Consumer Goods Ghana | 1.99 @ 1.0x ($82400/u) | Flow:-6.01 Rev:$584594 Cost:$163686
[12:00:38] Trade cycle started
[12:00:38] TRIGGERED: Consumer Goods 37.8 Electronics 252.9
[12:00:38] [FLOW Q] Completed 1 queued trades
[12:00:38] [FLOW Q] Complete: Consumer Goods Singapore
[12:00:38] [FLOW Q] OK +0.83 Consumer Goods to Singapore
[12:00:37] [FLOW Q] Trying 0.83 Consumer Goods to Singapore
[12:00:37] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:37] Trade cycle started
[12:00:37] TRIGGERED: Electronics 218.1
[12:00:37] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:37] Trade cycle started
[12:00:37] TRIGGERED: Electronics 218.1
[12:00:36] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:36] Trade cycle started
[12:00:36] TRIGGERED: Electronics 218.1
[12:00:36] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:36] Trade cycle started
[12:00:36] TRIGGERED: Electronics 218.1
[12:00:36] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:35] Trade cycle started
[12:00:35] TRIGGERED: Electronics 218.1
[12:00:35] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:35] Trade cycle started
[12:00:35] TRIGGERED: Electronics 218.1
[12:00:35] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:35] Trade cycle started
[12:00:35] TRIGGERED: Electronics 218.1
[12:00:34] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:34] Trade cycle started
[12:00:34] TRIGGERED: Electronics 218.1
[12:00:34] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:34] Trade cycle started
[12:00:34] TRIGGERED: Electronics 218.1
[12:00:34] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:33] Trade cycle started
[12:00:33] TRIGGERED: Electronics 218.1
[12:00:33] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:33] Trade cycle started
[12:00:33] TRIGGERED: Electronics 218.1
[12:00:33] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:33] Trade cycle started
[12:00:33] TRIGGERED: Electronics 218.1
[12:00:33] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:32] Trade cycle started
[12:00:32] TRIGGERED: Electronics 218.1
[12:00:32] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:32] Trade cycle started
[12:00:32] TRIGGERED: Electronics 218.1
[12:00:32] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:32] Trade cycle started
[12:00:32] TRIGGERED: Electronics 218.1
[12:00:31] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:31] Trade cycle started
[12:00:31] TRIGGERED: Electronics 218.1
[12:00:31] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:31] Trade cycle started
[12:00:31] TRIGGERED: Electronics 218.1
[12:00:31] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:30] Trade cycle started
[12:00:30] TRIGGERED: Electronics 218.1
[12:00:30] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:30] Trade cycle started
[12:00:30] TRIGGERED: Electronics 218.1
[12:00:30] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:30] Trade cycle started
[12:00:30] TRIGGERED: Electronics 218.1
[12:00:30] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:29] Trade cycle started
[12:00:29] TRIGGERED: Electronics 218.1
[12:00:29] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:29] Trade cycle started
[12:00:29] TRIGGERED: Electronics 218.1
[12:00:29] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:29] Trade cycle started
[12:00:29] TRIGGERED: Electronics 218.1
[12:00:28] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:28] Trade cycle started
[12:00:28] TRIGGERED: Electronics 218.1
[12:00:28] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:28] Trade cycle started
[12:00:28] TRIGGERED: Electronics 218.1
[12:00:28] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:28] Trade cycle started
[12:00:28] TRIGGERED: Electronics 218.1
[12:00:27] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:27] Trade cycle started
[12:00:27] TRIGGERED: Electronics 218.1
[12:00:27] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:27] Trade cycle started
[12:00:27] TRIGGERED: Electronics 218.1
[12:00:27] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:26] Trade cycle started
[12:00:26] TRIGGERED: Electronics 218.1
[12:00:26] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:26] Trade cycle started
[12:00:26] TRIGGERED: Electronics 218.1
[12:00:26] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:26] Trade cycle started
[12:00:26] TRIGGERED: Electronics 218.1
[12:00:25] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:25] Trade cycle started
[12:00:25] TRIGGERED: Electronics 218.1
[12:00:25] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:25] Trade cycle started
[12:00:25] TRIGGERED: Electronics 218.1
[12:00:25] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:25] Trade cycle started
[12:00:25] TRIGGERED: Electronics 218.1
[12:00:24] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:24] Trade cycle started
[12:00:24] TRIGGERED: Electronics 218.1
[12:00:24] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:24] Trade cycle started
[12:00:24] TRIGGERED: Electronics 218.1
[12:00:24] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:23] Trade cycle started
[12:00:23] TRIGGERED: Electronics 218.1
[12:00:23] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:23] Trade cycle started
[12:00:23] TRIGGERED: Electronics 218.1
[12:00:23] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:23] Trade cycle started
[12:00:23] TRIGGERED: Electronics 218.1
[12:00:22] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:22] Trade cycle started
[12:00:22] TRIGGERED: Electronics 218.1
[12:00:22] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:22] Trade cycle started
[12:00:22] TRIGGERED: Electronics 218.1
[12:00:21] Done in 6.3s | OK:6 Skip:296 Fail:0
[12:00:21] RETRY: 1
[12:00:21] [FLOW Q] Queued 0.83 Consumer Goods to Singapore (expires in 30s)
[12:00:21] [63/240] OK Consumer Goods Singapore
[12:00:20] [63/240] Consumer Goods Singapore | 0.58 @ 1.0x ($82400/u) | Flow:-5.47 Rev:$464890 Cost:$47596
[12:00:20] [62/240] OK Consumer Goods Tanzania
[12:00:20] [62/240] Consumer Goods Tanzania | 1.41 @ 1.0x ($82400/u) | Flow:-8.69 Rev:$466060 Cost:$116515
[12:00:19] [61/240] OK Consumer Goods Ecuador
[12:00:19] [61/240] Consumer Goods Ecuador | 1.43 @ 1.0x ($82400/u) | Flow:-7.39 Rev:$472570 Cost:$118142
[12:00:18] [60/240] OK Consumer Goods Cameroon
[12:00:18] [60/240] Consumer Goods Cameroon | 1.44 @ 1.0x ($82400/u) | Flow:-7.72 Rev:$473594 Cost:$118398
[12:00:17] [55/240] OK Consumer Goods Ethiopia
[12:00:17] [55/240] Consumer Goods Ethiopia | 1.77 @ 1.0x ($82400/u) | Flow:-7.88 Rev:$519758 Cost:$145532
[12:00:16] [52/240] OK Consumer Goods Tajikistan
[12:00:16] [52/240] Consumer Goods Tajikistan | 1.87 @ 1.0x ($82400/u) | Flow:-2.54 Rev:$551255 Cost:$154351
[12:00:16] [49/240] RETRY Consumer Goods Ghana (will try 0.5x)
[12:00:15] [49/240] Consumer Goods Ghana | 1.98 @ 1.0x ($82400/u) | Flow:-6.00 Rev:$584071 Cost:$163540
[12:00:15] Trade cycle started
[12:00:15] TRIGGERED: Consumer Goods 8.3 Electronics 218.1
[12:00:15] [FLOW Q] Completed 1 queued trades
[12:00:15] [FLOW Q] Complete: Consumer Goods Cote d'Ivoire
[12:00:15] [FLOW Q] OK +1.31 Consumer Goods to Cote d'Ivoire
[12:00:15] [FLOW Q] Trying 1.31 Consumer Goods to Cote d'Ivoire
[12:00:15] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:14] Trade cycle started
[12:00:14] TRIGGERED: Electronics 214.3
[12:00:14] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:14] Trade cycle started
[12:00:14] TRIGGERED: Electronics 214.3
[12:00:14] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:14] Trade cycle started
[12:00:14] TRIGGERED: Electronics 214.3
[12:00:13] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:13] Trade cycle started
[12:00:13] TRIGGERED: Electronics 214.3
[12:00:13] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:13] Trade cycle started
[12:00:13] TRIGGERED: Electronics 214.3
[12:00:13] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:13] Trade cycle started
[12:00:13] TRIGGERED: Electronics 214.3
[12:00:12] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:12] Trade cycle started
[12:00:12] TRIGGERED: Electronics 214.3
[12:00:12] Done in 0.1s | OK:0 Skip:240 Fail:0
[12:00:12] Trade cycle started
[12:00:12] TRIGGERED: Electronics 214.3
[12:00:12] Done in 0.1s | OK:0 Skip:240 Fail:0
[12:00:11] Trade cycle started
[12:00:11] TRIGGERED: Electronics 214.3
[12:00:11] Done in 0.1s | OK:0 Skip:240 Fail:0
[12:00:11] Trade cycle started
[12:00:11] TRIGGERED: Electronics 214.3
[12:00:11] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:11] Trade cycle started
[12:00:11] TRIGGERED: Electronics 214.3
[12:00:11] Done in 0.1s | OK:0 Skip:240 Fail:0
[12:00:10] Trade cycle started
[12:00:10] TRIGGERED: Electronics 214.3
[12:00:10] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:10] Trade cycle started
[12:00:10] TRIGGERED: Electronics 214.3
[12:00:10] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:10] Trade cycle started
[12:00:10] TRIGGERED: Electronics 214.3
[12:00:09] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:09] Trade cycle started
[12:00:09] TRIGGERED: Electronics 214.3
[12:00:09] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:09] Trade cycle started
[12:00:09] TRIGGERED: Electronics 214.3
[12:00:09] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:09] Trade cycle started
[12:00:09] TRIGGERED: Electronics 214.3
[12:00:08] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:08] Trade cycle started
[12:00:08] TRIGGERED: Electronics 214.3
[12:00:08] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:08] Trade cycle started
[12:00:08] TRIGGERED: Electronics 214.3
[12:00:08] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:07] Trade cycle started
[12:00:07] TRIGGERED: Electronics 214.3
[12:00:07] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:07] Trade cycle started
[12:00:07] TRIGGERED: Electronics 214.3
[12:00:07] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:07] Trade cycle started
[12:00:07] TRIGGERED: Electronics 214.3
[12:00:06] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:06] Trade cycle started
[12:00:06] TRIGGERED: Electronics 214.3
[12:00:06] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:06] Trade cycle started
[12:00:06] TRIGGERED: Electronics 214.3
[12:00:06] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:06] Trade cycle started
[12:00:06] TRIGGERED: Electronics 214.3
[12:00:05] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:05] Trade cycle started
[12:00:05] TRIGGERED: Electronics 214.3
[12:00:05] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:05] Trade cycle started
[12:00:05] TRIGGERED: Electronics 214.3
[12:00:05] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:04] Trade cycle started
[12:00:04] TRIGGERED: Electronics 214.3
[12:00:04] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:04] Trade cycle started
[12:00:04] TRIGGERED: Electronics 214.3
[12:00:04] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:04] Trade cycle started
[12:00:04] TRIGGERED: Electronics 214.3
[12:00:03] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:03] Trade cycle started
[12:00:03] TRIGGERED: Electronics 214.3
[12:00:03] Done in 0.1s | OK:0 Skip:240 Fail:0
[12:00:03] Trade cycle started
[12:00:03] TRIGGERED: Electronics 214.3
[12:00:03] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:03] Trade cycle started
[12:00:03] TRIGGERED: Electronics 214.3
[12:00:02] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:02] Trade cycle started
[12:00:02] TRIGGERED: Electronics 214.3
[12:00:02] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:02] Trade cycle started
[12:00:02] TRIGGERED: Electronics 214.3
[12:00:02] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:01] Trade cycle started
[12:00:01] TRIGGERED: Electronics 214.3
[12:00:01] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:01] Trade cycle started
[12:00:01] TRIGGERED: Electronics 214.3
[12:00:01] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:01] Trade cycle started
[12:00:01] TRIGGERED: Electronics 214.3
[12:00:00] Done in 0.1s | OK:0 Skip:240 Fail:0
[12:00:00] Trade cycle started
[12:00:00] TRIGGERED: Electronics 214.3
[12:00:00] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:00] Trade cycle started
[12:00:00] TRIGGERED: Electronics 214.3
[12:00:00] Done in 0.2s | OK:0 Skip:240 Fail:0
[12:00:00] Trade cycle started
[12:00:00] TRIGGERED: Electronics 214.3
[11:59:59] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:59] Trade cycle started
[11:59:59] TRIGGERED: Electronics 214.3
[11:59:59] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:59] Trade cycle started
[11:59:59] TRIGGERED: Electronics 214.3
[11:59:59] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:58] Trade cycle started
[11:59:58] TRIGGERED: Electronics 214.3
[11:59:58] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:58] Trade cycle started
[11:59:58] TRIGGERED: Electronics 214.3
[11:59:58] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:58] Trade cycle started
[11:59:58] TRIGGERED: Electronics 214.3
[11:59:57] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:57] Trade cycle started
[11:59:57] TRIGGERED: Electronics 214.3
[11:59:57] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:57] Trade cycle started
[11:59:57] TRIGGERED: Electronics 214.3
[11:59:57] Done in 15.3s | OK:14 Skip:282 Fail:0
[11:59:57] RETRY: 3
[11:59:56] [FLOW Q] Queued 1.31 Consumer Goods to Cote d'Ivoire (expires in 30s)
[11:59:56] [59/240] OK Consumer Goods Cote d'Ivoire
[11:59:56] [59/240] Consumer Goods Cote d'Ivoire | 0.21 @ 1.0x ($82400/u) | Flow:-6.92 Rev:$498510 Cost:$16962
[11:59:55] [58/240] OK Consumer Goods Romania
[11:59:55] [58/240] Consumer Goods Romania | 1.75 @ 1.0x ($82400/u) | Flow:-8.19 Rev:$514088 Cost:$143945
[11:59:54] [57/240] OK Consumer Goods North Korea
[11:59:54] [57/240] Consumer Goods North Korea | 1.75 @ 1.0x ($82400/u) | Flow:-10.33 Rev:$515428 Cost:$144320
[11:59:53] [56/240] OK Consumer Goods Kenya
[11:59:53] [56/240] Consumer Goods Kenya | 1.76 @ 1.0x ($82400/u) | Flow:-6.87 Rev:$518760 Cost:$145253
[11:59:53] [55/240] RETRY Consumer Goods Ethiopia (will try 0.5x)
[11:59:52] [55/240] Consumer Goods Ethiopia | 1.76 @ 1.0x ($82400/u) | Flow:-7.87 Rev:$519168 Cost:$145367
[11:59:51] [54/240] OK Consumer Goods Senegal
[11:59:51] [54/240] Consumer Goods Senegal | 1.80 @ 1.0x ($82400/u) | Flow:-4.04 Rev:$528302 Cost:$147925
[11:59:50] [53/240] OK Consumer Goods Afghanistan
[11:59:50] [53/240] Consumer Goods Afghanistan | 1.84 @ 1.0x ($82400/u) | Flow:-8.04 Rev:$541383 Cost:$151587
[11:59:50] [52/240] RETRY Consumer Goods Tajikistan (will try 0.5x)
[11:59:49] [52/240] Consumer Goods Tajikistan | 1.87 @ 1.0x ($82400/u) | Flow:-2.53 Rev:$550830 Cost:$154232
[11:59:48] [51/240] OK Consumer Goods Bolivia
[11:59:48] [51/240] Consumer Goods Bolivia | 1.91 @ 1.0x ($82400/u) | Flow:-7.10 Rev:$561521 Cost:$157226
[11:59:48] [50/240] OK Consumer Goods Netherlands
[11:59:47] [50/240] Consumer Goods Netherlands | 1.93 @ 1.0x ($82400/u) | Flow:-6.11 Rev:$568347 Cost:$159137
[11:59:47] [49/240] RETRY Consumer Goods Ghana (will try 0.5x)
[11:59:46] [49/240] Consumer Goods Ghana | 1.98 @ 1.0x ($82400/u) | Flow:-5.99 Rev:$583286 Cost:$163320
[11:59:46] [48/240] OK Consumer Goods Hong Kong
[11:59:45] [48/240] Consumer Goods Hong Kong | 2.06 @ 1.0x ($82400/u) | Flow:-7.59 Rev:$606040 Cost:$169691
[11:59:45] [47/240] OK Consumer Goods Sierra Leone
[11:59:45] [47/240] Consumer Goods Sierra Leone | 1.39 @ 1.0x ($82400/u) | Flow:-1.39 Rev:$613801 Cost:$114545
[11:59:44] [46/240] OK Consumer Goods Burma
[11:59:44] [46/240] Consumer Goods Burma | 2.15 @ 1.0x ($82400/u) | Flow:-11.03 Rev:$633763 Cost:$177454
[11:59:43] [43/240] OK Consumer Goods Angola
[11:59:43] [43/240] Consumer Goods Angola | 2.35 @ 1.0x ($82400/u) | Flow:-8.30 Rev:$692267 Cost:$193835
[11:59:42] [39/240] OK Consumer Goods Thailand
[11:59:42] [39/240] Consumer Goods Thailand | 3.08 @ 1.0x ($82400/u) | Flow:-14.84 Rev:$905762 Cost:$253613
[11:59:41] [36/240] OK Consumer Goods Kazakhstan
[11:59:41] [36/240] Consumer Goods Kazakhstan | 3.96 @ 1.0x ($82400/u) | Flow:-8.22 Rev:$1019598 Cost:$326271
[11:59:41] Trade cycle started
[11:59:41] TRIGGERED: Consumer Goods 28.0 Electronics 214.3
[11:59:41] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:41] Trade cycle started
[11:59:41] TRIGGERED: Electronics 179.5
[11:59:41] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:41] Trade cycle started
[11:59:41] TRIGGERED: Electronics 179.5
[11:59:40] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:40] Trade cycle started
[11:59:40] TRIGGERED: Electronics 179.5
[11:59:40] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:40] Trade cycle started
[11:59:40] TRIGGERED: Electronics 179.5
[11:59:40] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:39] Trade cycle started
[11:59:39] TRIGGERED: Electronics 179.5
[11:59:39] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:39] Trade cycle started
[11:59:39] TRIGGERED: Electronics 179.5
[11:59:39] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:39] Trade cycle started
[11:59:39] TRIGGERED: Electronics 179.5
[11:59:39] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:38] Trade cycle started
[11:59:38] TRIGGERED: Electronics 179.5
[11:59:38] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:38] Trade cycle started
[11:59:38] TRIGGERED: Electronics 179.5
[11:59:38] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:38] Trade cycle started
[11:59:38] TRIGGERED: Electronics 179.5
[11:59:37] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:37] Trade cycle started
[11:59:37] TRIGGERED: Electronics 179.5
[11:59:37] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:37] Trade cycle started
[11:59:37] TRIGGERED: Electronics 179.5
[11:59:37] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:37] Trade cycle started
[11:59:37] TRIGGERED: Electronics 179.5
[11:59:36] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:36] Trade cycle started
[11:59:36] TRIGGERED: Electronics 179.5
[11:59:36] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:36] Trade cycle started
[11:59:36] TRIGGERED: Electronics 179.5
[11:59:36] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:36] Trade cycle started
[11:59:36] TRIGGERED: Electronics 179.5
[11:59:35] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:35] Trade cycle started
[11:59:35] TRIGGERED: Electronics 179.5
[11:59:35] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:35] Trade cycle started
[11:59:35] TRIGGERED: Electronics 179.5
[11:59:35] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:34] Trade cycle started
[11:59:34] TRIGGERED: Electronics 179.5
[11:59:34] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:34] Trade cycle started
[11:59:34] TRIGGERED: Electronics 179.5
[11:59:34] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:34] Trade cycle started
[11:59:34] TRIGGERED: Electronics 179.5
[11:59:34] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:33] Trade cycle started
[11:59:33] TRIGGERED: Electronics 179.5
[11:59:33] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:33] Trade cycle started
[11:59:33] TRIGGERED: Electronics 179.5
[11:59:33] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:33] Trade cycle started
[11:59:33] TRIGGERED: Electronics 179.5
[11:59:32] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:32] Trade cycle started
[11:59:32] TRIGGERED: Electronics 179.5
[11:59:32] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:32] Trade cycle started
[11:59:32] TRIGGERED: Electronics 179.5
[11:59:32] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:31] Trade cycle started
[11:59:31] TRIGGERED: Electronics 179.5
[11:59:31] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:31] Trade cycle started
[11:59:31] TRIGGERED: Electronics 179.5
[11:59:31] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:31] Trade cycle started
[11:59:31] TRIGGERED: Electronics 179.5
[11:59:30] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:30] Trade cycle started
[11:59:30] TRIGGERED: Electronics 179.5
[11:59:30] [FLOW Q] Expired: Consumer Goods Uzbekistan
[11:59:30] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:30] Trade cycle started
[11:59:30] TRIGGERED: Electronics 179.5
[11:59:30] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:30] Trade cycle started
[11:59:30] TRIGGERED: Electronics 179.5
[11:59:29] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:29] Trade cycle started
[11:59:29] TRIGGERED: Electronics 179.5
[11:59:29] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:29] Trade cycle started
[11:59:29] TRIGGERED: Electronics 179.5
[11:59:29] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:28] Trade cycle started
[11:59:28] TRIGGERED: Electronics 179.5
[11:59:28] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:28] Trade cycle started
[11:59:28] TRIGGERED: Electronics 179.5
[11:59:28] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:28] Trade cycle started
[11:59:28] TRIGGERED: Electronics 179.5
[11:59:28] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:27] Trade cycle started
[11:59:27] TRIGGERED: Electronics 179.5
[11:59:27] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:27] Trade cycle started
[11:59:27] TRIGGERED: Electronics 179.5
[11:59:27] Done in 0.1s | OK:0 Skip:240 Fail:0
[11:59:27] Trade cycle started
[11:59:27] TRIGGERED: Electronics 179.5
[11:59:26] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:26] Trade cycle started
[11:59:26] TRIGGERED: Electronics 179.5
[11:59:26] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:26] Trade cycle started
[11:59:26] TRIGGERED: Electronics 179.5
[11:59:26] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:26] Trade cycle started
[11:59:26] TRIGGERED: Electronics 179.5
[11:59:25] Done in 0.2s | OK:0 Skip:240 Fail:0
[11:59:25] Trade cycle started
[11:59:25] TRIGGERED: Electronics 179.5
[11:59:25] Done in 2.2s | OK:1 Skip:274 Fail:0
[11:59:25] RETRY: 1
[11:59:25] [36/240] RETRY Consumer Goods Kazakhstan (will try 0.5x)
[11:59:24] [36/240] Consumer Goods Kazakhstan | 2.28 @ 1.0x ($82400/u) | Flow:-8.21 Rev:$1018946 Cost:$187749
[11:59:23] [18/240] OK Consumer Goods Nigeria
[11:59:23] [18/240] Consumer Goods Nigeria | 7.37 @ 1.0x ($82400/u) | Flow:-41.90 Rev:$1898398 Cost:$607487
[11:59:23] Trade cycle started
[11:59:23] TRIGGERED: Consumer Goods 9.7 Electronics 179.5
[11:59:23] [FLOW Q] Failed: Consumer Goods Uzbekistan
[11:59:22] [FLOW Q] Trying 0.45 Consumer Goods to Uzbekistan
[11:59:21] Done in 3.8s | OK:0 Skip:239 Fail:1
[11:59:21] [1/1] FAIL Electronics Morocco
[11:59:19] [1/1] Electronics Morocco | 0.04 @ 0.5x ($51000/u) | Flow:0.00 Rev:$10409 Cost:$2082
[11:59:19] RETRY: 1
[11:59:19] [238/240] RETRY Electronics Morocco (will try 0.5x)
[11:59:18] [238/240] Electronics Morocco | 0.02 @ 1.0x ($102000/u) | Flow:0.00 Rev:$10409 Cost:$2082
[11:59:17] Trade cycle started
[11:59:17] TRIGGERED: Electronics 175.6
[11:59:17] Done in 2.3s | OK:0 Skip:239 Fail:1
[11:59:17] [1/1] FAIL Electronics Morocco
[11:59:16] [1/1] Electronics Morocco | 0.04 @ 0.5x ($51000/u) | Flow:0.00 Rev:$10409 Cost:$2082
[11:59:16] RETRY: 1
[11:59:16] [238/240] RETRY Electronics Morocco (will try 0.5x)
[11:59:15] [238/240] Electronics Morocco | 0.02 @ 1.0x ($102000/u) | Flow:0.00 Rev:$10409 Cost:$2082
[11:59:14] Trade cycle started
[11:59:14] TRIGGERED: Electronics 175.6
[11:59:14] Done in 2.3s | OK:0 Skip:239 Fail:1
[11:59:14] [1/1] FAIL Electronics Morocco
[11:59:13] [1/1] Electronics Morocco | 0.06 @ 0.5x ($51000/u) | Flow:0.00 Rev:$14282 Cost:$2856
[11:59:13] RETRY: 1
[11:59:13] [238/240] RETRY Electronics Morocco (will try 0.5x)
[11:59:12] [238/240] Electronics Morocco | 0.03 @ 1.0x ($102000/u) | Flow:0.00 Rev:$14282 Cost:$2856
[11:59:11] Trade cycle started
[11:59:11] TRIGGERED: Electronics 175.6
[11:59:11] Done in 2.3s | OK:0 Skip:239 Fail:1
[11:59:11] [1/1] FAIL Electronics Morocco
[11:59:10] [1/1] Electronics Morocco | 0.06 @ 0.5x ($51000/u) | Flow:0.00 Rev:$14282 Cost:$2856
[11:59:10] RETRY: 1
[11:59:10] [238/240] RETRY Electronics Morocco (will try 0.5x)
[11:59:09] [238/240] Electronics Morocco | 0.03 @ 1.0x ($102000/u) | Flow:0.00 Rev:$14282 Cost:$2856
[11:59:09] Trade cycle started
[11:59:09] TRIGGERED: Electronics 175.6
[11:59:08] Done in 2.3s | OK:0 Skip:239 Fail:1
[11:59:08] [1/1] FAIL Electronics Morocco
[11:59:07] [1/1] Electronics Morocco | 0.19 @ 0.5x ($51000/u) | Flow:0.00 Rev:$48434 Cost:$9687
[11:59:07] RETRY: 1
[11:59:07] [238/240] RETRY Electronics Morocco (will try 0.5x)
[11:59:06] [238/240] Electronics Morocco | 0.09 @ 1.0x ($102000/u) | Flow:0.00 Rev:$48434 Cost:$9687
[11:59:06] Trade cycle started
[11:59:06] TRIGGERED: Electronics 175.6
[11:59:05] Done in 2.3s | OK:0 Skip:239 Fail:1
[11:59:05] [1/1] FAIL Electronics Morocco
[11:59:04] [1/1] Electronics Morocco | 0.19 @ 0.5x ($51000/u) | Flow:0.00 Rev:$48434 Cost:$9687
[11:59:04] RETRY: 1
[11:59:04] [238/240] RETRY Electronics Morocco (will try 0.5x)
[11:59:03] [238/240] Electronics Morocco | 0.09 @ 1.0x ($102000/u) | Flow:0.00 Rev:$48434 Cost:$9687
[11:59:03] Trade cycle started
[11:59:03] TRIGGERED: Electronics 175.6
[11:59:02] Done in 16.9s | OK:11 Skip:269 Fail:1
[11:59:02] [5/6] FAIL Electronics Morocco
[11:59:01] [5/6] Electronics Morocco | 0.56 @ 0.5x ($51000/u) | Flow:0.00 Rev:$114175 Cost:$28544
[11:59:01] RETRY: 6
[11:59:00] [FLOW Q] Queued 0.45 Consumer Goods to Uzbekistan (expires in 30s)
[11:59:00] [46/240] OK Consumer Goods Uzbekistan
[11:59:00] [46/240] Consumer Goods Uzbekistan | 1.75 @ 1.0x ($82400/u) | Flow:-9.89 Rev:$647034 Cost:$143790
[11:58:59] [45/240] OK Consumer Goods Syria
[11:58:59] [45/240] Consumer Goods Syria | 2.32 @ 1.0x ($82400/u) | Flow:-9.81 Rev:$681781 Cost:$190899
[11:58:59] [44/240] RETRY Consumer Goods Angola (will try 0.5x)
[11:58:58] [44/240] Consumer Goods Angola | 2.35 @ 1.0x ($82400/u) | Flow:-8.28 Rev:$690966 Cost:$193470
[11:58:57] [43/240] OK Consumer Goods Sudan
[11:58:57] [43/240] Consumer Goods Sudan | 2.53 @ 1.0x ($82400/u) | Flow:-12.28 Rev:$743316 Cost:$208128
[11:58:57] [42/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:56] [42/240] Electronics Morocco | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$114175 Cost:$28544
[11:58:56] [42/240] RETRY Consumer Goods Morocco (will try 0.5x)
[11:58:55] [42/240] Consumer Goods Morocco | 1.75 @ 1.0x ($82400/u) | Flow:-4.15 Rev:$516082 Cost:$144503
[11:58:54] [41/240] OK Consumer Goods Poland
[11:58:54] [41/240] Consumer Goods Poland | 2.67 @ 1.0x ($82400/u) | Flow:-12.86 Rev:$786094 Cost:$220106
[11:58:54] [40/240] OK Consumer Goods Malaysia
[11:58:53] [40/240] Consumer Goods Malaysia | 2.73 @ 1.0x ($82400/u) | Flow:-15.16 Rev:$802750 Cost:$224770
[11:58:53] [39/240] RETRY Consumer Goods Thailand (will try 0.5x)
[11:58:52] [39/240] Consumer Goods Thailand | 3.07 @ 1.0x ($82400/u) | Flow:-14.80 Rev:$903761 Cost:$253053
[11:58:52] [38/240] OK Consumer Goods Iraq
[11:58:52] [38/240] Consumer Goods Iraq | 3.34 @ 1.0x ($82400/u) | Flow:-16.61 Rev:$981875 Cost:$274925
[11:58:51] [37/240] OK Consumer Goods Chile
[11:58:51] [37/240] Consumer Goods Chile | 3.95 @ 1.0x ($82400/u) | Flow:-13.61 Rev:$1016683 Cost:$325339
[11:58:51] [36/240] RETRY Consumer Goods Kazakhstan (will try 0.5x)
[11:58:49] [36/240] Consumer Goods Kazakhstan | 3.95 @ 1.0x ($82400/u) | Flow:-8.20 Rev:$1017968 Cost:$325750
[11:58:49] [35/240] OK Consumer Goods Venezuela
[11:58:49] [35/240] Consumer Goods Venezuela | 4.00 @ 1.0x ($82400/u) | Flow:-18.13 Rev:$1029376 Cost:$329400
[11:58:48] [34/240] OK Consumer Goods Australia
[11:58:48] [34/240] Consumer Goods Australia | 4.22 @ 1.0x ($82400/u) | Flow:-20.27 Rev:$1086348 Cost:$347631
[11:58:47] [33/240] OK Consumer Goods Peru
[11:58:47] [33/240] Consumer Goods Peru | 4.44 @ 1.0x ($82400/u) | Flow:-18.02 Rev:$1144304 Cost:$366177
[11:58:46] [32/240] OK Consumer Goods Zimbabwe
[11:58:46] [32/240] Consumer Goods Zimbabwe | 3.78 @ 1.0x ($82400/u) | Flow:-3.78 Rev:$1145229 Cost:$311838
[11:58:46] [18/240] RETRY Consumer Goods Nigeria (will try 0.5x)
[11:58:45] [18/240] Consumer Goods Nigeria | 7.36 @ 1.0x ($82400/u) | Flow:-41.84 Rev:$1895781 Cost:$606650
[11:58:45] Trade cycle started
[11:58:45] TRIGGERED: Consumer Goods 34.8 Electronics 175.6
[11:58:45] [FLOW Q] Completed 1 queued trades
[11:58:45] [FLOW Q] Complete: Consumer Goods Taiwan
[11:58:45] [FLOW Q] OK +3.85 Consumer Goods to Taiwan
[11:58:45] [FLOW Q] Trying 3.85 Consumer Goods to Taiwan
[11:58:44] Done in 2.3s | OK:0 Skip:239 Fail:1
[11:58:44] [1/1] FAIL Electronics Morocco
[11:58:43] [1/1] Electronics Morocco | 4.44 @ 0.5x ($51000/u) | Flow:0.00 Rev:$809193 Cost:$226574
[11:58:43] RETRY: 1
[11:58:43] [40/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:42] [40/240] Electronics Morocco | 2.22 @ 1.0x ($102000/u) | Flow:0.00 Rev:$809193 Cost:$226574
[11:58:42] Trade cycle started
[11:58:42] TRIGGERED: Electronics 140.8
[11:58:42] Done in 2.2s | OK:0 Skip:239 Fail:1
[11:58:42] [1/1] FAIL Electronics Morocco
[11:58:40] [1/1] Electronics Morocco | 4.44 @ 0.5x ($51000/u) | Flow:0.00 Rev:$809193 Cost:$226574
[11:58:40] RETRY: 1
[11:58:40] [40/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:39] [40/240] Electronics Morocco | 2.22 @ 1.0x ($102000/u) | Flow:0.00 Rev:$809193 Cost:$226574
[11:58:39] Trade cycle started
[11:58:39] TRIGGERED: Electronics 140.8
[11:58:39] Done in 2.3s | OK:0 Skip:239 Fail:1
[11:58:39] [1/1] FAIL Electronics Morocco
[11:58:38] [1/1] Electronics Morocco | 4.59 @ 0.5x ($51000/u) | Flow:0.00 Rev:$836865 Cost:$234322
[11:58:38] RETRY: 1
[11:58:38] [40/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:37] [40/240] Electronics Morocco | 2.30 @ 1.0x ($102000/u) | Flow:0.00 Rev:$836865 Cost:$234322
[11:58:37] Trade cycle started
[11:58:37] TRIGGERED: Electronics 140.8
[11:58:36] Done in 2.2s | OK:0 Skip:239 Fail:1
[11:58:36] [1/1] FAIL Electronics Morocco
[11:58:35] [1/1] Electronics Morocco | 4.59 @ 0.5x ($51000/u) | Flow:0.00 Rev:$836865 Cost:$234322
[11:58:35] RETRY: 1
[11:58:35] [40/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:34] [40/240] Electronics Morocco | 2.30 @ 1.0x ($102000/u) | Flow:0.00 Rev:$836865 Cost:$234322
[11:58:34] Trade cycle started
[11:58:34] TRIGGERED: Electronics 140.8
[11:58:33] Done in 2.2s | OK:0 Skip:239 Fail:1
[11:58:33] [1/1] FAIL Electronics Morocco
[11:58:32] [1/1] Electronics Morocco | 4.61 @ 0.5x ($51000/u) | Flow:0.00 Rev:$840396 Cost:$235311
[11:58:32] RETRY: 1
[11:58:32] [40/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:31] [40/240] Electronics Morocco | 2.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$840396 Cost:$235311
[11:58:31] Trade cycle started
[11:58:31] TRIGGERED: Electronics 140.8
[11:58:30] Done in 2.2s | OK:0 Skip:239 Fail:1
[11:58:30] [1/1] FAIL Electronics Morocco
[11:58:29] [1/1] Electronics Morocco | 4.61 @ 0.5x ($51000/u) | Flow:0.00 Rev:$840396 Cost:$235311
[11:58:29] RETRY: 1
[11:58:29] [40/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:28] [40/240] Electronics Morocco | 2.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$840396 Cost:$235311
[11:58:28] Trade cycle started
[11:58:28] TRIGGERED: Electronics 140.8
[11:58:28] Done in 2.3s | OK:0 Skip:239 Fail:1
[11:58:28] [1/1] FAIL Electronics Morocco
[11:58:27] [1/1] Electronics Morocco | 4.78 @ 0.5x ($51000/u) | Flow:0.00 Rev:$870576 Cost:$243761
[11:58:27] RETRY: 1
[11:58:27] [40/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:25] [40/240] Electronics Morocco | 2.39 @ 1.0x ($102000/u) | Flow:0.00 Rev:$870576 Cost:$243761
[11:58:25] Trade cycle started
[11:58:25] TRIGGERED: Electronics 140.8
[11:58:25] Done in 5.3s | OK:2 Skip:267 Fail:1
[11:58:25] [2/2] FAIL Electronics Morocco
[11:58:24] [2/2] Electronics Morocco | 4.78 @ 0.5x ($51000/u) | Flow:0.00 Rev:$870576 Cost:$243761
[11:58:24] RETRY: 2
[11:58:24] [40/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:22] [40/240] Electronics Morocco | 2.39 @ 1.0x ($102000/u) | Flow:0.00 Rev:$870576 Cost:$243761
[11:58:22] [FLOW Q] Queued 3.85 Consumer Goods to Taiwan (expires in 30s)
[11:58:22] [31/240] OK Consumer Goods Taiwan
[11:58:21] [31/240] Consumer Goods Taiwan | 0.92 @ 1.0x ($82400/u) | Flow:-22.25 Rev:$1227282 Cost:$75894
[11:58:21] [30/240] OK Consumer Goods Democratic Republic of the Congo
[11:58:21] [30/240] Consumer Goods Democratic Republic of the Congo | 5.04 @ 1.0x ($82400/u) | Flow:-20.63 Rev:$1297588 Cost:$415228
[11:58:21] [18/240] RETRY Consumer Goods Nigeria (will try 0.5x)
[11:58:19] [18/240] Consumer Goods Nigeria | 5.96 @ 1.0x ($82400/u) | Flow:-41.78 Rev:$1893602 Cost:$491123
[11:58:19] Trade cycle started
[11:58:19] TRIGGERED: Consumer Goods 6.0 Electronics 140.8
[11:58:19] Done in 6.0s | OK:3 Skip:323 Fail:1
[11:58:19] [3/3] OK Consumer Goods Belize
[11:58:19] [3/3] Consumer Goods Belize | 0.15 @ 0.5x ($41200/u) | Flow:-0.15 Rev:$106449 Cost:$6202
[11:58:19] [2/3] FAIL Electronics Morocco
[11:58:18] [2/3] Electronics Morocco | 4.86 @ 0.5x ($51000/u) | Flow:0.00 Rev:$884679 Cost:$247710
[11:58:18] [1/3] OK Electronics Iran
[11:58:17] [1/3] Electronics Iran | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$2014098 Cost:$255000
[11:58:17] RETRY: 3
[11:58:17] [186/240] RETRY Consumer Goods Belize (will try 0.5x)
[11:58:16] [186/240] Consumer Goods Belize | 0.15 @ 1.0x ($82400/u) | Flow:-0.15 Rev:$106449 Cost:$12404
[11:58:16] [153/240] OK Electronics South Sudan
[11:58:15] [153/240] Electronics South Sudan | 0.35 @ 1.0x ($102000/u) | Flow:0.00 Rev:$141504 Cost:$35376
[11:58:15] [39/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:14] [39/240] Electronics Morocco | 2.57 @ 1.0x ($102000/u) | Flow:0.00 Rev:$938013 Cost:$262644
[11:58:14] [16/240] RETRY Electronics Iran (will try 0.5x)
[11:58:13] [16/240] Electronics Iran | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2013615 Cost:$510000
[11:58:13] Trade cycle started
[11:58:13] TRIGGERED: Electronics 142.3
[11:58:13] Done in 10.6s | OK:5 Skip:232 Fail:3
[11:58:13] [5/5] OK Electronics Cayman Islands
[11:58:13] [5/5] Electronics Cayman Islands | 0.51 @ 0.5x ($51000/u) | Flow:0.00 Rev:$104724 Cost:$26181
[11:58:13] [4/5] FAIL Electronics South Sudan
[11:58:12] [4/5] Electronics South Sudan | 0.69 @ 0.5x ($51000/u) | Flow:0.00 Rev:$141504 Cost:$35376
[11:58:12] [3/5] OK Electronics Cambodia
[11:58:11] [3/5] Electronics Cambodia | 1.18 @ 0.5x ($51000/u) | Flow:0.00 Rev:$239848 Cost:$59962
[11:58:11] [2/5] FAIL Electronics Morocco
[11:58:10] [2/5] Electronics Morocco | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$938013 Cost:$255000
[11:58:10] [1/5] FAIL Electronics Iran
[11:58:09] [1/5] Electronics Iran | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$2013133 Cost:$255000
[11:58:09] RETRY: 5
[11:58:09] [217/240] OK Electronics Bonaire
[11:58:09] [217/240] Electronics Bonaire | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101414 Cost:$25354
[11:58:09] [191/240] RETRY Electronics Cayman Islands (will try 0.5x)
[11:58:08] [191/240] Electronics Cayman Islands | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$104723 Cost:$26181
[11:58:07] [170/240] OK Electronics Reunion
[11:58:07] [170/240] Electronics Reunion | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$114780 Cost:$28695
[11:58:07] [153/240] RETRY Electronics South Sudan (will try 0.5x)
[11:58:06] [153/240] Electronics South Sudan | 0.35 @ 1.0x ($102000/u) | Flow:0.00 Rev:$141493 Cost:$35373
[11:58:06] [132/240] OK Electronics Croatia
[11:58:05] [132/240] Electronics Croatia | 0.46 @ 1.0x ($102000/u) | Flow:0.00 Rev:$188011 Cost:$47003
[11:58:05] [108/240] RETRY Electronics Cambodia (will try 0.5x)
[11:58:04] [108/240] Electronics Cambodia | 0.59 @ 1.0x ($102000/u) | Flow:0.00 Rev:$239767 Cost:$59942
[11:58:04] [38/240] RETRY Electronics Morocco (will try 0.5x)
[11:58:03] [38/240] Electronics Morocco | 2.69 @ 1.0x ($102000/u) | Flow:0.00 Rev:$980385 Cost:$274508
[11:58:03] [16/240] RETRY Electronics Iran (will try 0.5x)
[11:58:02] [16/240] Electronics Iran | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2012650 Cost:$510000
[11:58:02] Trade cycle started
[11:58:02] TRIGGERED: Electronics 145.0
[11:58:02] [FLOW Q] Expired: Consumer Goods Bangladesh
[11:58:02] Done in 65.6s | OK:53 Skip:321 Fail:7
[11:58:02] [18/18] OK Electronics Falkland Islands
[11:58:01] [18/18] Electronics Falkland Islands | 0.49 @ 0.5x ($51000/u) | Flow:0.00 Rev:$100188 Cost:$25047
[11:58:01] [17/18] FAIL Electronics Bonaire
[11:58:00] [17/18] Electronics Bonaire | 0.50 @ 0.5x ($51000/u) | Flow:0.00 Rev:$101414 Cost:$25354
[11:58:00] [16/18] OK Electronics Saint Vincent And The Grenadines
[11:58:00] [16/18] Electronics Saint Vincent And The Grenadines | 0.51 @ 0.5x ($51000/u) | Flow:0.00 Rev:$103466 Cost:$25866
[11:58:00] [15/18] FAIL Electronics Cayman Islands
[11:57:59] [15/18] Electronics Cayman Islands | 0.51 @ 0.5x ($51000/u) | Flow:0.00 Rev:$104721 Cost:$26180
[11:57:59] [13/18] OK Electronics Curacao
[11:57:59] [13/18] Electronics Curacao | 0.54 @ 0.5x ($51000/u) | Flow:0.00 Rev:$110270 Cost:$27568
[11:57:59] [12/18] FAIL Electronics Reunion
[11:57:57] [12/18] Electronics Reunion | 0.56 @ 0.5x ($51000/u) | Flow:0.00 Rev:$114771 Cost:$28693
[11:57:57] [11/18] OK Electronics Malta
[11:57:57] [11/18] Electronics Malta | 0.62 @ 0.5x ($51000/u) | Flow:0.00 Rev:$125750 Cost:$31438
[11:57:57] [10/18] FAIL Electronics South Sudan
[11:57:56] [10/18] Electronics South Sudan | 0.69 @ 0.5x ($51000/u) | Flow:0.00 Rev:$141469 Cost:$35367
[11:57:56] [9/18] OK Electronics Burundi
[11:57:56] [9/18] Electronics Burundi | 0.87 @ 0.5x ($51000/u) | Flow:0.00 Rev:$177765 Cost:$44441
[11:57:56] [7/18] FAIL Electronics Croatia
[11:57:55] [7/18] Electronics Croatia | 0.92 @ 0.5x ($51000/u) | Flow:0.00 Rev:$187961 Cost:$46990
[11:57:55] [6/18] OK Electronics Rwanda
[11:57:54] [6/18] Electronics Rwanda | 0.98 @ 0.5x ($51000/u) | Flow:0.00 Rev:$200628 Cost:$50157
[11:57:54] [5/18] FAIL Electronics Cambodia
[11:57:53] [5/18] Electronics Cambodia | 1.18 @ 0.5x ($51000/u) | Flow:0.00 Rev:$239727 Cost:$59932
[11:57:53] [4/18] OK Electronics Cameroon
[11:57:53] [4/18] Electronics Cameroon | 2.31 @ 0.5x ($51000/u) | Flow:0.00 Rev:$471018 Cost:$117754
[11:57:53] [2/18] FAIL Electronics Iran
[11:57:52] [2/18] Electronics Iran | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$2011684 Cost:$255000
[11:57:52] [1/18] OK Consumer Goods Russia
[11:57:52] [1/18] Consumer Goods Russia | 30.32 @ 0.5x ($41200/u) | Flow:-83.38 Rev:$3903078 Cost:$1248985
[11:57:52] RETRY: 18
[11:57:52] [234/240] RETRY Electronics Falkland Islands (will try 0.5x)
[11:57:51] [234/240] Electronics Falkland Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100187 Cost:$25047
[11:57:50] [225/240] OK Electronics Saint Barthelemy
[11:57:50] [225/240] Electronics Saint Barthelemy | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100702 Cost:$25176
[11:57:50] [217/240] RETRY Electronics Bonaire (will try 0.5x)
[11:57:49] [217/240] Electronics Bonaire | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101413 Cost:$25353
[11:57:49] [209/240] OK Electronics Mayotte
[11:57:49] [209/240] Electronics Mayotte | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102244 Cost:$25561
[11:57:49] [199/240] RETRY Electronics Saint Vincent And The Grenadines (will try 0.5x)
[11:57:48] [199/240] Electronics Saint Vincent And The Grenadines | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103464 Cost:$25866
[11:57:48] [191/240] RETRY Electronics Cayman Islands (will try 0.5x)
[11:57:47] [191/240] Electronics Cayman Islands | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$104717 Cost:$26179
[11:57:47] [186/240] RETRY Consumer Goods Belize (will try 0.5x)
[11:57:46] [186/240] Consumer Goods Belize | 0.11 @ 1.0x ($82400/u) | Flow:-0.15 Rev:$106437 Cost:$8986
[11:57:45] [181/240] OK Electronics Bhutan
[11:57:45] [181/240] Electronics Bhutan | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$107958 Cost:$26990
[11:57:45] [177/240] RETRY Electronics Curacao (will try 0.5x)
[11:57:44] [177/240] Electronics Curacao | 0.27 @ 1.0x ($102000/u) | Flow:0.00 Rev:$110264 Cost:$27566
[11:57:44] [173/240] OK Electronics Barbados
[11:57:43] [173/240] Electronics Barbados | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$113361 Cost:$28340
[11:57:43] [170/240] RETRY Electronics Reunion (will try 0.5x)
[11:57:42] [170/240] Electronics Reunion | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$114762 Cost:$28690
[11:57:42] [166/240] OK Electronics Equatorial Guinea
[11:57:42] [166/240] Electronics Equatorial Guinea | 0.29 @ 1.0x ($102000/u) | Flow:0.00 Rev:$119135 Cost:$29784
[11:57:42] [162/240] RETRY Electronics Malta (will try 0.5x)
[11:57:41] [162/240] Electronics Malta | 0.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$125727 Cost:$31432
[11:57:40] [157/240] OK Electronics Guinea-Bissau
[11:57:40] [157/240] Electronics Guinea-Bissau | 0.32 @ 1.0x ($102000/u) | Flow:0.00 Rev:$131623 Cost:$32906
[11:57:40] [153/240] RETRY Electronics South Sudan (will try 0.5x)
[11:57:39] [153/240] Electronics South Sudan | 0.35 @ 1.0x ($102000/u) | Flow:0.00 Rev:$141433 Cost:$35358
[11:57:39] [148/240] OK Electronics Laos
[11:57:39] [148/240] Electronics Laos | 0.39 @ 1.0x ($102000/u) | Flow:0.00 Rev:$158295 Cost:$39574
[11:57:38] [146/240] OK Consumer Goods Guyana
[11:57:38] [146/240] Consumer Goods Guyana | 0.41 @ 1.0x ($82400/u) | Flow:-0.41 Rev:$165518 Cost:$33414
[11:57:37] [141/240] RETRY Electronics Burundi (will try 0.5x)
[11:57:36] [141/240] Electronics Burundi | 0.44 @ 1.0x ($102000/u) | Flow:0.00 Rev:$177725 Cost:$44431
[11:57:36] [141/240] OK Consumer Goods Burundi
[11:57:36] [141/240] Consumer Goods Burundi | 0.54 @ 1.0x ($82400/u) | Flow:-0.65 Rev:$177713 Cost:$44428
[11:57:35] [140/240] OK Consumer Goods Timor-Leste
[11:57:35] [140/240] Consumer Goods Timor-Leste | 0.25 @ 1.0x ($82400/u) | Flow:-0.25 Rev:$181018 Cost:$20232
[11:57:34] [139/240] OK Consumer Goods Lithuania
[11:57:34] [139/240] Consumer Goods Lithuania | 0.55 @ 1.0x ($82400/u) | Flow:-1.43 Rev:$181311 Cost:$45328
[11:57:33] [138/240] OK Consumer Goods Namibia
[11:57:33] [138/240] Consumer Goods Namibia | 0.55 @ 1.0x ($82400/u) | Flow:-0.76 Rev:$182351 Cost:$45588
[11:57:33] [137/240] OK Consumer Goods Macedonia
[11:57:32] [137/240] Consumer Goods Macedonia | 0.55 @ 1.0x ($82400/u) | Flow:-1.01 Rev:$182390 Cost:$45598
[11:57:31] [136/240] OK Consumer Goods Bahrain
[11:57:31] [136/240] Consumer Goods Bahrain | 0.55 @ 1.0x ($82400/u) | Flow:-0.59 Rev:$182401 Cost:$45600
[11:57:31] [135/240] OK Consumer Goods Mauritania
[11:57:30] [135/240] Consumer Goods Mauritania | 0.56 @ 1.0x ($82400/u) | Flow:-1.37 Rev:$183879 Cost:$45970
[11:57:30] [134/240] RETRY Consumer Goods Sri Lanka (will try 0.5x)
[11:57:29] [134/240] Consumer Goods Sri Lanka | 0.56 @ 1.0x ($82400/u) | Flow:-1.74 Rev:$184905 Cost:$46226
[11:57:29] [133/240] OK Consumer Goods Central African Republic
[11:57:29] [133/240] Consumer Goods Central African Republic | 0.57 @ 1.0x ($82400/u) | Flow:-1.53 Rev:$187794 Cost:$46948
[11:57:28] [132/240] RETRY Electronics Croatia (will try 0.5x)
[11:57:27] [132/240] Electronics Croatia | 0.46 @ 1.0x ($102000/u) | Flow:0.00 Rev:$187835 Cost:$46959
[11:57:27] [132/240] OK Consumer Goods Croatia
[11:57:27] [132/240] Consumer Goods Croatia | 0.57 @ 1.0x ($82400/u) | Flow:-1.63 Rev:$187835 Cost:$46959
[11:57:25] [131/240] OK Consumer Goods Benin
[11:57:25] [131/240] Consumer Goods Benin | 0.58 @ 1.0x ($82400/u) | Flow:-1.98 Rev:$190094 Cost:$47524
[11:57:24] [130/240] OK Consumer Goods Armenia
[11:57:24] [130/240] Consumer Goods Armenia | 0.58 @ 1.0x ($82400/u) | Flow:-1.50 Rev:$191029 Cost:$47757
[11:57:23] [129/240] OK Consumer Goods Bosnia And Herzegovina
[11:57:23] [129/240] Consumer Goods Bosnia And Herzegovina | 0.59 @ 1.0x ($82400/u) | Flow:-1.78 Rev:$193342 Cost:$48336
[11:57:22] [128/240] OK Consumer Goods Palestine
[11:57:22] [128/240] Consumer Goods Palestine | 0.59 @ 1.0x ($82400/u) | Flow:-1.97 Rev:$195204 Cost:$48801
[11:57:21] [127/240] OK Consumer Goods Brunei
[11:57:21] [127/240] Consumer Goods Brunei | 0.31 @ 1.0x ($82400/u) | Flow:-0.31 Rev:$195202 Cost:$25582
[11:57:20] [126/240] OK Consumer Goods Eritrea
[11:57:20] [126/240] Consumer Goods Eritrea | 0.59 @ 1.0x ($82400/u) | Flow:-1.38 Rev:$196044 Cost:$49011
[11:57:20] [125/240] OK Consumer Goods Ireland
[11:57:19] [125/240] Consumer Goods Ireland | 0.60 @ 1.0x ($82400/u) | Flow:-1.71 Rev:$197893 Cost:$49473
[11:57:19] [124/240] OK Consumer Goods Malawi
[11:57:19] [124/240] Consumer Goods Malawi | 0.61 @ 1.0x ($82400/u) | Flow:-1.94 Rev:$200109 Cost:$50027
[11:57:19] [123/240] RETRY Electronics Rwanda (will try 0.5x)
[11:57:18] [123/240] Electronics Rwanda | 0.49 @ 1.0x ($102000/u) | Flow:0.00 Rev:$200424 Cost:$50106
[11:57:17] [117/240] OK Electronics Oman
[11:57:17] [117/240] Electronics Oman | 0.52 @ 1.0x ($102000/u) | Flow:0.00 Rev:$212520 Cost:$53130
[11:57:17] [108/240] RETRY Electronics Cambodia (will try 0.5x)
[11:57:16] [108/240] Electronics Cambodia | 0.59 @ 1.0x ($102000/u) | Flow:0.00 Rev:$239442 Cost:$59860
[11:57:16] [87/240] OK Electronics Kyrgyzstan
[11:57:15] [87/240] Electronics Kyrgyzstan | 0.76 @ 1.0x ($102000/u) | Flow:0.00 Rev:$309203 Cost:$77301
[11:57:15] [61/240] RETRY Electronics Cameroon (will try 0.5x)
[11:57:14] [61/240] Electronics Cameroon | 1.15 @ 1.0x ($102000/u) | Flow:0.00 Rev:$470298 Cost:$117574
[11:57:14] [37/240] OK Electronics Kazakhstan
[11:57:14] [37/240] Electronics Kazakhstan | 3.19 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1015372 Cost:$324919
[11:57:13] [FLOW Q] Queued 4.71 Consumer Goods to Bangladesh (expires in 30s)
[11:57:13] [27/240] OK Consumer Goods Bangladesh
[11:57:13] [27/240] Consumer Goods Bangladesh | 1.14 @ 1.0x ($82400/u) | Flow:-23.41 Rev:$1507678 Cost:$94022
[11:57:12] [24/240] OK Consumer Goods Vietnam
[11:57:12] [24/240] Consumer Goods Vietnam | 6.33 @ 1.0x ($82400/u) | Flow:-26.18 Rev:$1628815 Cost:$521221
[11:57:11] [23/240] OK Consumer Goods Argentina
[11:57:11] [23/240] Consumer Goods Argentina | 6.54 @ 1.0x ($82400/u) | Flow:-29.33 Rev:$1682768 Cost:$538486
[11:57:11] [22/240] OK Consumer Goods South Korea
[11:57:10] [22/240] Consumer Goods South Korea | 6.67 @ 1.0x ($82400/u) | Flow:-33.65 Rev:$1717903 Cost:$549729
[11:57:10] [21/240] OK Consumer Goods Italy
[11:57:10] [21/240] Consumer Goods Italy | 6.86 @ 1.0x ($82400/u) | Flow:-23.21 Rev:$1766738 Cost:$565356
[11:57:09] [20/240] OK Consumer Goods Saudi Arabia
[11:57:09] [20/240] Consumer Goods Saudi Arabia | 7.16 @ 1.0x ($82400/u) | Flow:-19.02 Rev:$1842643 Cost:$589646
[11:57:08] [19/240] OK Consumer Goods Spain
[11:57:08] [19/240] Consumer Goods Spain | 7.28 @ 1.0x ($82400/u) | Flow:-24.43 Rev:$1874902 Cost:$599969
[11:57:08] [18/240] RETRY Consumer Goods Nigeria (will try 0.5x)
[11:57:07] [18/240] Consumer Goods Nigeria | 7.33 @ 1.0x ($82400/u) | Flow:-41.65 Rev:$1887948 Cost:$604143
[11:57:06] [17/240] OK Consumer Goods Egypt
[11:57:06] [17/240] Consumer Goods Egypt | 7.61 @ 1.0x ($82400/u) | Flow:-29.68 Rev:$1958312 Cost:$626660
[11:57:06] [16/240] RETRY Electronics Iran (will try 0.5x)
[11:57:05] [16/240] Electronics Iran | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2007828 Cost:$510000
[11:57:04] [16/240] OK Consumer Goods Iran
[11:57:04] [16/240] Consumer Goods Iran | 7.80 @ 1.0x ($82400/u) | Flow:-33.62 Rev:$2007828 Cost:$642505
[11:57:03] [15/240] OK Consumer Goods Turkey
[11:57:03] [15/240] Consumer Goods Turkey | 8.06 @ 1.0x ($82400/u) | Flow:-38.08 Rev:$2076314 Cost:$664420
[11:57:03] [14/240] OK Consumer Goods Pakistan
[11:57:02] [14/240] Consumer Goods Pakistan | 8.26 @ 1.0x ($82400/u) | Flow:-42.91 Rev:$2128102 Cost:$680993
[11:57:02] [13/240] OK Consumer Goods France
[11:57:01] [13/240] Consumer Goods France | 8.44 @ 1.0x ($82400/u) | Flow:-25.97 Rev:$2174036 Cost:$695692
[11:57:01] [12/240] OK Consumer Goods South Africa
[11:57:01] [12/240] Consumer Goods South Africa | 8.75 @ 1.0x ($82400/u) | Flow:-23.19 Rev:$2253163 Cost:$721012
[11:57:00] [11/240] OK Consumer Goods United Kingdom
[11:57:00] [11/240] Consumer Goods United Kingdom | 9.78 @ 1.0x ($82400/u) | Flow:-32.15 Rev:$2518580 Cost:$805946
[11:56:59] [10/240] OK Consumer Goods Germany
[11:56:59] [10/240] Consumer Goods Germany | 9.81 @ 1.0x ($82400/u) | Flow:-35.32 Rev:$2525739 Cost:$808236
[11:56:58] [9/240] OK Consumer Goods Indonesia
[11:56:58] [9/240] Consumer Goods Indonesia | 10.17 @ 1.0x ($82400/u) | Flow:-49.71 Rev:$2617877 Cost:$837721
[11:56:57] [8/240] OK Consumer Goods Mexico
[11:56:57] [8/240] Consumer Goods Mexico | 13.70 @ 1.0x ($82400/u) | Flow:-69.70 Rev:$3527411 Cost:$1128772
[11:56:57] [7/240] RETRY Consumer Goods Russia (will try 0.5x)
[11:56:56] [7/240] Consumer Goods Russia | 15.13 @ 1.0x ($82400/u) | Flow:-83.22 Rev:$3896489 Cost:$1246876
[11:56:56] Trade cycle started
[11:56:56] TRIGGERED: Consumer Goods 134.4 Electronics 115.9
[11:56:56] [FLOW Q] Expired: Consumer Goods Philippines
[11:56:56] [FLOW Q] Expired: Consumer Goods Canada
[11:56:56] [FLOW Q] Expired: Consumer Goods Japan
[11:56:55] Done in 153.6s | OK:105 Skip:217 Fail:27
[11:56:55] [1/1] FAIL Consumer Goods Bangladesh
[11:56:54] [1/1] Consumer Goods Bangladesh | 11.70 @ 0.5x ($41200/u) | Flow:-23.38 Rev:$1506170 Cost:$481974
[11:56:54] [54/54] OK Electronics Niue
[11:56:54] [54/54] Electronics Niue | 0.49 @ 0.5x ($51000/u) | Flow:0.00 Rev:$100118 Cost:$25030
[11:56:54] [53/54] FAIL Electronics Falkland Islands
[11:56:53] [53/54] Electronics Falkland Islands | 0.49 @ 0.5x ($51000/u) | Flow:0.00 Rev:$100186 Cost:$25046
[11:56:53] [52/54] OK Electronics Cook Islands
[11:56:53] [52/54] Electronics Cook Islands | 0.49 @ 0.5x ($51000/u) | Flow:0.00 Rev:$100383 Cost:$25096
[11:56:53] [51/54] FAIL Electronics Saint Barthelemy
[11:56:52] [51/54] Electronics Saint Barthelemy | 0.49 @ 0.5x ($51000/u) | Flow:0.00 Rev:$100700 Cost:$25175
[11:56:52] [50/54] OK Electronics Faroe Islands
[11:56:51] [50/54] Electronics Faroe Islands | 0.50 @ 0.5x ($51000/u) | Flow:0.00 Rev:$101010 Cost:$25252
[11:56:51] [49/54] FAIL Electronics Bonaire
[11:56:50] [49/54] Electronics Bonaire | 0.50 @ 0.5x ($51000/u) | Flow:0.00 Rev:$101408 Cost:$25352
[11:56:50] [48/54] OK Electronics Marshall Islands
[11:56:49] [48/54] Electronics Marshall Islands | 0.50 @ 0.5x ($51000/u) | Flow:0.00 Rev:$101773 Cost:$25443
[11:56:49] [47/54] FAIL Electronics Mayotte
[11:56:48] [47/54] Electronics Mayotte | 0.50 @ 0.5x ($51000/u) | Flow:0.00 Rev:$102236 Cost:$25559
[11:56:48] [46/54] OK Electronics Saint Lucia
[11:56:48] [46/54] Electronics Saint Lucia | 0.50 @ 0.5x ($51000/u) | Flow:0.00 Rev:$102650 Cost:$25662
[11:56:48] [45/54] FAIL Electronics Saint Vincent And The Grenadines
[11:56:47] [45/54] Electronics Saint Vincent And The Grenadines | 0.51 @ 0.5x ($51000/u) | Flow:0.00 Rev:$103452 Cost:$25863
[11:56:47] [44/54] OK Electronics Andorra
[11:56:47] [44/54] Electronics Andorra | 0.51 @ 0.5x ($51000/u) | Flow:0.00 Rev:$103768 Cost:$25942
[11:56:47] [43/54] FAIL Electronics Cayman Islands
[11:56:46] [43/54] Electronics Cayman Islands | 0.51 @ 0.5x ($51000/u) | Flow:0.00 Rev:$104703 Cost:$26176
[11:56:46] [42/54] OK Electronics French Guiana
[11:56:46] [42/54] Electronics French Guiana | 0.52 @ 0.5x ($51000/u) | Flow:0.00 Rev:$106308 Cost:$26577
[11:56:46] [41/54] FAIL Consumer Goods Belize
[11:56:44] [41/54] Consumer Goods Belize | 0.15 @ 0.5x ($41200/u) | Flow:-0.15 Rev:$106418 Cost:$6172
[11:56:44] [40/54] OK Electronics Luxembourg
[11:56:44] [40/54] Electronics Luxembourg | 0.53 @ 0.5x ($51000/u) | Flow:0.00 Rev:$107736 Cost:$26934
[11:56:44] [39/54] FAIL Electronics Bhutan
[11:56:43] [39/54] Electronics Bhutan | 0.53 @ 0.5x ($51000/u) | Flow:0.00 Rev:$107931 Cost:$26983
[11:56:43] [38/54] OK Electronics French Polynesia
[11:56:43] [38/54] Electronics French Polynesia | 0.54 @ 0.5x ($51000/u) | Flow:0.00 Rev:$109177 Cost:$27294
[11:56:43] [37/54] FAIL Electronics Curacao
[11:56:41] [37/54] Electronics Curacao | 0.54 @ 0.5x ($51000/u) | Flow:0.00 Rev:$110230 Cost:$27557
[11:56:41] [36/54] OK Electronics Gambia
[11:56:41] [36/54] Electronics Gambia | 0.55 @ 0.5x ($51000/u) | Flow:0.00 Rev:$112847 Cost:$28212
[11:56:41] [35/54] FAIL Electronics Barbados
[11:56:40] [35/54] Electronics Barbados | 0.56 @ 0.5x ($51000/u) | Flow:0.00 Rev:$113317 Cost:$28329
[11:56:40] [34/54] OK Electronics Iceland
[11:56:40] [34/54] Electronics Iceland | 0.56 @ 0.5x ($51000/u) | Flow:0.00 Rev:$113474 Cost:$28369
[11:56:40] [33/54] FAIL Electronics Reunion
[11:56:39] [33/54] Electronics Reunion | 0.56 @ 0.5x ($51000/u) | Flow:0.00 Rev:$114714 Cost:$28678
[11:56:39] [32/54] OK Electronics Martinique
[11:56:38] [32/54] Electronics Martinique | 0.58 @ 0.5x ($51000/u) | Flow:0.00 Rev:$117689 Cost:$29422
[11:56:38] [31/54] FAIL Electronics Equatorial Guinea
[11:56:37] [31/54] Electronics Equatorial Guinea | 0.58 @ 0.5x ($51000/u) | Flow:0.00 Rev:$119068 Cost:$29767
[11:56:37] [30/54] OK Electronics Eswatini
[11:56:37] [30/54] Electronics Eswatini | 0.59 @ 0.5x ($51000/u) | Flow:0.00 Rev:$120750 Cost:$30188
[11:56:37] [29/54] FAIL Electronics Malta
[11:56:36] [29/54] Electronics Malta | 0.62 @ 0.5x ($51000/u) | Flow:0.00 Rev:$125643 Cost:$31411
[11:56:36] [28/54] OK Electronics Liechtenstein
[11:56:36] [28/54] Electronics Liechtenstein | 0.63 @ 0.5x ($51000/u) | Flow:0.00 Rev:$127847 Cost:$31962
[11:56:36] [27/54] FAIL Electronics Guinea-Bissau
[11:56:35] [27/54] Electronics Guinea-Bissau | 0.64 @ 0.5x ($51000/u) | Flow:0.00 Rev:$131520 Cost:$32880
[11:56:35] [26/54] OK Electronics Macau
[11:56:34] [26/54] Electronics Macau | 0.68 @ 0.5x ($51000/u) | Flow:0.00 Rev:$139598 Cost:$34900
[11:56:34] [25/54] FAIL Electronics South Sudan
[11:56:33] [25/54] Electronics South Sudan | 0.69 @ 0.5x ($51000/u) | Flow:0.00 Rev:$141302 Cost:$35326
[11:56:33] [24/54] OK Electronics Suriname
[11:56:32] [24/54] Electronics Suriname | 0.75 @ 0.5x ($51000/u) | Flow:0.00 Rev:$153109 Cost:$38277
[11:56:32] [23/54] FAIL Electronics Laos
[11:56:31] [23/54] Electronics Laos | 0.77 @ 0.5x ($51000/u) | Flow:0.00 Rev:$157952 Cost:$39488
[11:56:31] [22/54] OK Consumer Goods Gabon
[11:56:31] [22/54] Consumer Goods Gabon | 0.96 @ 0.5x ($41200/u) | Flow:-1.00 Rev:$158428 Cost:$39607
[11:56:31] [21/54] FAIL Consumer Goods Guyana
[11:56:30] [21/54] Consumer Goods Guyana | 0.40 @ 0.5x ($41200/u) | Flow:-0.40 Rev:$165405 Cost:$16648
[11:56:30] [20/54] OK Electronics Latvia
[11:56:30] [20/54] Electronics Latvia | 0.82 @ 0.5x ($51000/u) | Flow:0.00 Rev:$168291 Cost:$42073
[11:56:30] [19/54] FAIL Electronics Burundi
[11:56:29] [19/54] Electronics Burundi | 0.87 @ 0.5x ($51000/u) | Flow:0.00 Rev:$177569 Cost:$44392
[11:56:29] [18/54] OK Electronics Bahrain
[11:56:28] [18/54] Electronics Bahrain | 0.89 @ 0.5x ($51000/u) | Flow:0.00 Rev:$182234 Cost:$45558
[11:56:28] [17/54] FAIL Electronics Croatia
[11:56:27] [17/54] Electronics Croatia | 0.92 @ 0.5x ($51000/u) | Flow:0.00 Rev:$187583 Cost:$46896
[11:56:27] [16/54] OK Electronics Eritrea
[11:56:27] [16/54] Electronics Eritrea | 0.96 @ 0.5x ($51000/u) | Flow:0.00 Rev:$195833 Cost:$48958
[11:56:27] [15/54] FAIL Electronics Rwanda
[11:56:26] [15/54] Electronics Rwanda | 0.98 @ 0.5x ($51000/u) | Flow:0.00 Rev:$200164 Cost:$50041
[11:56:26] [14/54] OK Electronics Denmark
[11:56:26] [14/54] Electronics Denmark | 1.04 @ 0.5x ($51000/u) | Flow:0.00 Rev:$211228 Cost:$52807
[11:56:26] [13/54] FAIL Electronics Oman
[11:56:25] [13/54] Electronics Oman | 1.04 @ 0.5x ($51000/u) | Flow:0.00 Rev:$212231 Cost:$53058
[11:56:25] [12/54] OK Electronics Jamaica
[11:56:25] [12/54] Electronics Jamaica | 1.10 @ 0.5x ($51000/u) | Flow:0.00 Rev:$223591 Cost:$55898
[11:56:25] [11/54] FAIL Electronics Cambodia
[11:56:24] [11/54] Electronics Cambodia | 1.17 @ 0.5x ($51000/u) | Flow:0.00 Rev:$239078 Cost:$59770
[11:56:24] [10/54] OK Electronics Jordan
[11:56:23] [10/54] Electronics Jordan | 1.28 @ 0.5x ($51000/u) | Flow:0.00 Rev:$261431 Cost:$65358
[11:56:23] [9/54] FAIL Electronics Kyrgyzstan
[11:56:22] [9/54] Electronics Kyrgyzstan | 1.51 @ 0.5x ($51000/u) | Flow:0.00 Rev:$308887 Cost:$77222
[11:56:22] [8/54] OK Electronics Bulgaria
[11:56:22] [8/54] Electronics Bulgaria | 1.80 @ 0.5x ($51000/u) | Flow:0.00 Rev:$367399 Cost:$91850
[11:56:22] [7/54] FAIL Electronics Cameroon
[11:56:21] [7/54] Electronics Cameroon | 2.30 @ 0.5x ($51000/u) | Flow:0.00 Rev:$469275 Cost:$117319
[11:56:21] [6/54] OK Electronics Burma
[11:56:21] [6/54] Electronics Burma | 3.45 @ 0.5x ($51000/u) | Flow:0.00 Rev:$628597 Cost:$176007
[11:56:21] [5/54] FAIL Electronics Kazakhstan
[11:56:20] [5/54] Electronics Kazakhstan | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$1013751 Cost:$255000
[11:56:20] [FLOW Q] Queued 3.11 Consumer Goods to Philippines (expires in 30s)
[11:56:20] [3/54] OK Consumer Goods Philippines
[11:56:20] [3/54] Consumer Goods Philippines | 9.35 @ 0.5x ($41200/u) | Flow:-28.54 Rev:$1604168 Cost:$385181
[11:56:20] [2/54] FAIL Electronics Iran
[11:56:18] [2/54] Electronics Iran | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$2003977 Cost:$255000
[11:56:18] [1/54] OK Consumer Goods India
[11:56:18] [1/54] Consumer Goods India | 171.79 @ 0.5x ($41200/u) | Flow:-207.78 Rev:$18625694 Cost:$7077764
[11:56:18] RETRY: 54
[11:56:18] [238/240] RETRY Electronics Niue (will try 0.5x)
[11:56:17] [238/240] Electronics Niue | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100118 Cost:$25030
[11:56:17] [236/240] OK Electronics Saba
[11:56:17] [236/240] Electronics Saba | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100138 Cost:$25034
[11:56:17] [234/240] RETRY Electronics Falkland Islands (will try 0.5x)
[11:56:16] [234/240] Electronics Falkland Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100186 Cost:$25046
[11:56:15] [232/240] OK Electronics Montserrat
[11:56:15] [232/240] Electronics Montserrat | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100317 Cost:$25079
[11:56:15] [230/240] RETRY Electronics Cook Islands (will try 0.5x)
[11:56:14] [230/240] Electronics Cook Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100382 Cost:$25096
[11:56:14] [228/240] OK Electronics Rapa Nui
[11:56:13] [228/240] Electronics Rapa Nui | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100545 Cost:$25136
[11:56:13] [226/240] RETRY Electronics Saint Barthelemy (will try 0.5x)
[11:56:12] [226/240] Electronics Saint Barthelemy | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100698 Cost:$25174
[11:56:12] [224/240] OK Electronics Tuvalu
[11:56:12] [224/240] Electronics Tuvalu | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100815 Cost:$25204
[11:56:12] [222/240] RETRY Electronics Faroe Islands (will try 0.5x)
[11:56:11] [222/240] Electronics Faroe Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101008 Cost:$25252
[11:56:10] [220/240] OK Electronics Palau
[11:56:10] [220/240] Electronics Palau | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101078 Cost:$25270
[11:56:10] [218/240] RETRY Electronics Bonaire (will try 0.5x)
[11:56:09] [218/240] Electronics Bonaire | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101404 Cost:$25351
[11:56:09] [216/240] OK Electronics Dominica
[11:56:08] [216/240] Electronics Dominica | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101628 Cost:$25407
[11:56:08] [214/240] RETRY Electronics Marshall Islands (will try 0.5x)
[11:56:07] [214/240] Electronics Marshall Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101769 Cost:$25442
[11:56:07] [212/240] OK Electronics Kiribati
[11:56:07] [212/240] Electronics Kiribati | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102005 Cost:$25501
[11:56:07] [210/240] RETRY Electronics Mayotte (will try 0.5x)
[11:56:06] [210/240] Electronics Mayotte | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102232 Cost:$25558
[11:56:05] [208/240] OK Electronics Saint Martin
[11:56:05] [208/240] Electronics Saint Martin | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102375 Cost:$25594
[11:56:05] [206/240] OK Electronics Monaco
[11:56:04] [206/240] Electronics Monaco | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102532 Cost:$25633
[11:56:04] [204/240] RETRY Electronics Saint Lucia (will try 0.5x)
[11:56:03] [204/240] Electronics Saint Lucia | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102644 Cost:$25661
[11:56:03] [202/240] OK Electronics Sint Maarten
[11:56:03] [202/240] Electronics Sint Maarten | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102888 Cost:$25722
[11:56:03] [200/240] RETRY Electronics Saint Vincent And The Grenadines (will try 0.5x)
[11:56:01] [200/240] Electronics Saint Vincent And The Grenadines | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103444 Cost:$25861
[11:56:01] [198/240] OK Electronics Vanuatu
[11:56:01] [198/240] Electronics Vanuatu | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103626 Cost:$25906
[11:56:01] [196/240] RETRY Electronics Andorra (will try 0.5x)
[11:56:00] [196/240] Electronics Andorra | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103759 Cost:$25940
[11:55:59] [194/240] OK Electronics Samoa
[11:55:59] [194/240] Electronics Samoa | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$104307 Cost:$26077
[11:55:59] [192/240] RETRY Electronics Cayman Islands (will try 0.5x)
[11:55:58] [192/240] Electronics Cayman Islands | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$104691 Cost:$26173
[11:55:58] [190/240] OK Electronics Solomon Islands
[11:55:58] [190/240] Electronics Solomon Islands | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$105565 Cost:$26391
[11:55:57] [188/240] RETRY Electronics French Guiana (will try 0.5x)
[11:55:56] [188/240] Electronics French Guiana | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$106292 Cost:$26573
[11:55:56] [188/240] OK Consumer Goods French Guiana
[11:55:56] [188/240] Consumer Goods French Guiana | 0.11 @ 1.0x ($82400/u) | Flow:-0.11 Rev:$106292 Cost:$9434
[11:55:56] [187/240] RETRY Consumer Goods Belize (will try 0.5x)
[11:55:55] [187/240] Consumer Goods Belize | 0.15 @ 1.0x ($82400/u) | Flow:-0.15 Rev:$106400 Cost:$12310
[11:55:54] [186/240] OK Electronics New Caledonia
[11:55:54] [186/240] Electronics New Caledonia | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$106471 Cost:$26618
[11:55:53] [185/240] OK Consumer Goods Jersey
[11:55:53] [185/240] Consumer Goods Jersey | 0.11 @ 1.0x ($82400/u) | Flow:-0.11 Rev:$107180 Cost:$8874
[11:55:53] [184/240] RETRY Electronics Luxembourg (will try 0.5x)
[11:55:52] [184/240] Electronics Luxembourg | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$107715 Cost:$26929
[11:55:51] [184/240] OK Consumer Goods Luxembourg
[11:55:51] [184/240] Consumer Goods Luxembourg | 0.12 @ 1.0x ($82400/u) | Flow:-0.12 Rev:$107715 Cost:$9751
[11:55:51] [183/240] OK Consumer Goods Maldives
[11:55:50] [183/240] Consumer Goods Maldives | 0.12 @ 1.0x ($82400/u) | Flow:-0.12 Rev:$107849 Cost:$9701
[11:55:50] [182/240] RETRY Electronics Bhutan (will try 0.5x)
[11:55:49] [182/240] Electronics Bhutan | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$107909 Cost:$26977
[11:55:49] [182/240] OK Consumer Goods Bhutan
[11:55:48] [182/240] Consumer Goods Bhutan | 0.13 @ 1.0x ($82400/u) | Flow:-0.13 Rev:$107909 Cost:$10641
[11:55:48] [181/240] OK Consumer Goods Guam
[11:55:48] [181/240] Consumer Goods Guam | 0.13 @ 1.0x ($82400/u) | Flow:-0.13 Rev:$108508 Cost:$10516
[11:55:47] [180/240] RETRY Electronics French Polynesia (will try 0.5x)
[11:55:46] [180/240] Electronics French Polynesia | 0.27 @ 1.0x ($102000/u) | Flow:0.00 Rev:$109150 Cost:$27288
[11:55:46] [180/240] OK Consumer Goods French Polynesia
[11:55:46] [180/240] Consumer Goods French Polynesia | 0.14 @ 1.0x ($82400/u) | Flow:-0.14 Rev:$109150 Cost:$11309
[11:55:45] [179/240] OK Consumer Goods Guadeloupe
[11:55:45] [179/240] Consumer Goods Guadeloupe | 0.15 @ 1.0x ($82400/u) | Flow:-0.15 Rev:$110109 Cost:$12495
[11:55:45] [178/240] RETRY Electronics Curacao (will try 0.5x)
[11:55:44] [178/240] Electronics Curacao | 0.27 @ 1.0x ($102000/u) | Flow:0.00 Rev:$110199 Cost:$27550
[11:55:43] [178/240] OK Consumer Goods Curacao
[11:55:43] [178/240] Consumer Goods Curacao | 0.15 @ 1.0x ($82400/u) | Flow:-0.15 Rev:$110199 Cost:$12606
[11:55:42] [177/240] OK Consumer Goods Cabo Verde
[11:55:42] [177/240] Consumer Goods Cabo Verde | 0.19 @ 1.0x ($82400/u) | Flow:-0.19 Rev:$110812 Cost:$15783
[11:55:42] [176/240] RETRY Electronics Gambia (will try 0.5x)
[11:55:41] [176/240] Electronics Gambia | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$112806 Cost:$28202
[11:55:40] [176/240] OK Consumer Goods Gambia
[11:55:40] [176/240] Consumer Goods Gambia | 0.29 @ 1.0x ($82400/u) | Flow:-0.29 Rev:$112806 Cost:$23911
[11:55:40] [175/240] OK Consumer Goods Gibraltar
[11:55:39] [175/240] Consumer Goods Gibraltar | 0.19 @ 1.0x ($82400/u) | Flow:-0.19 Rev:$112992 Cost:$16058
[11:55:39] [174/240] RETRY Electronics Barbados (will try 0.5x)
[11:55:38] [174/240] Electronics Barbados | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$113274 Cost:$28319
[11:55:38] [174/240] OK Consumer Goods Barbados
[11:55:38] [174/240] Consumer Goods Barbados | 0.20 @ 1.0x ($82400/u) | Flow:-0.20 Rev:$113274 Cost:$16407
[11:55:37] [173/240] RETRY Electronics Iceland (will try 0.5x)
[11:55:36] [173/240] Electronics Iceland | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$113429 Cost:$28357
[11:55:36] [173/240] OK Consumer Goods Iceland
[11:55:36] [173/240] Consumer Goods Iceland | 0.22 @ 1.0x ($82400/u) | Flow:-0.22 Rev:$113429 Cost:$18152
[11:55:35] [171/240] RETRY Electronics Reunion (will try 0.5x)
[11:55:34] [171/240] Electronics Reunion | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$114662 Cost:$28666
[11:55:34] [171/240] OK Consumer Goods Reunion
[11:55:34] [171/240] Consumer Goods Reunion | 0.23 @ 1.0x ($82400/u) | Flow:-0.23 Rev:$114662 Cost:$19332
[11:55:33] [170/240] OK Consumer Goods Montenegro
[11:55:33] [170/240] Consumer Goods Montenegro | 0.33 @ 1.0x ($82400/u) | Flow:-0.33 Rev:$117449 Cost:$27601
[11:55:32] [169/240] RETRY Electronics Martinique (will try 0.5x)
[11:55:31] [169/240] Electronics Martinique | 0.29 @ 1.0x ($102000/u) | Flow:0.00 Rev:$117631 Cost:$29408
[11:55:31] [169/240] OK Consumer Goods Martinique
[11:55:31] [169/240] Consumer Goods Martinique | 0.26 @ 1.0x ($82400/u) | Flow:-0.26 Rev:$117631 Cost:$21792
[11:55:30] [168/240] OK Consumer Goods Fiji
[11:55:30] [168/240] Consumer Goods Fiji | 0.31 @ 1.0x ($82400/u) | Flow:-0.31 Rev:$118533 Cost:$25520
[11:55:29] [167/240] RETRY Electronics Equatorial Guinea (will try 0.5x)
[11:55:28] [167/240] Electronics Equatorial Guinea | 0.29 @ 1.0x ($102000/u) | Flow:0.00 Rev:$119002 Cost:$29750
[11:55:28] [167/240] OK Consumer Goods Equatorial Guinea
[11:55:28] [167/240] Consumer Goods Equatorial Guinea | 0.36 @ 1.0x ($82400/u) | Flow:-0.37 Rev:$119002 Cost:$29750
[11:55:27] [166/240] OK Consumer Goods Bahamas
[11:55:27] [166/240] Consumer Goods Bahamas | 0.32 @ 1.0x ($82400/u) | Flow:-0.32 Rev:$119090 Cost:$26292
[11:55:27] [165/240] RETRY Electronics Eswatini (will try 0.5x)
[11:55:26] [165/240] Electronics Eswatini | 0.30 @ 1.0x ($102000/u) | Flow:0.00 Rev:$120712 Cost:$30178
[11:55:25] [165/240] OK Consumer Goods Eswatini
[11:55:25] [165/240] Consumer Goods Eswatini | 0.23 @ 1.0x ($82400/u) | Flow:-0.23 Rev:$120712 Cost:$19038
[11:55:24] [164/240] OK Consumer Goods Comoros
[11:55:24] [164/240] Consumer Goods Comoros | 0.37 @ 1.0x ($82400/u) | Flow:-0.44 Rev:$121158 Cost:$30290
[11:55:23] [163/240] RETRY Electronics Malta (will try 0.5x)
[11:55:22] [163/240] Electronics Malta | 0.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$125545 Cost:$31386
[11:55:22] [163/240] OK Consumer Goods Malta
[11:55:22] [163/240] Consumer Goods Malta | 0.38 @ 1.0x ($82400/u) | Flow:-0.38 Rev:$125545 Cost:$31386
[11:55:21] [162/240] OK Consumer Goods Kosovo
[11:55:21] [162/240] Consumer Goods Kosovo | 0.38 @ 1.0x ($82400/u) | Flow:-0.51 Rev:$126167 Cost:$31542
[11:55:21] [161/240] RETRY Electronics Liechtenstein (will try 0.5x)
[11:55:20] [161/240] Electronics Liechtenstein | 0.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$127834 Cost:$31958
[11:55:20] [160/240] OK Electronics Greenland
[11:55:19] [160/240] Electronics Greenland | 0.32 @ 1.0x ($102000/u) | Flow:0.00 Rev:$128775 Cost:$32194
[11:55:19] [159/240] OK Consumer Goods Cyprus
[11:55:18] [159/240] Consumer Goods Cyprus | 0.40 @ 1.0x ($82400/u) | Flow:-0.60 Rev:$130714 Cost:$32678
[11:55:18] [158/240] RETRY Electronics Guinea-Bissau (will try 0.5x)
[11:55:17] [158/240] Electronics Guinea-Bissau | 0.32 @ 1.0x ($102000/u) | Flow:0.00 Rev:$131389 Cost:$32847
[11:55:17] [158/240] OK Consumer Goods Guinea-Bissau
[11:55:16] [158/240] Consumer Goods Guinea-Bissau | 0.40 @ 1.0x ($82400/u) | Flow:-0.51 Rev:$131389 Cost:$32847
[11:55:16] [157/240] OK Consumer Goods Slovenia
[11:55:15] [157/240] Consumer Goods Slovenia | 0.41 @ 1.0x ($82400/u) | Flow:-0.58 Rev:$134249 Cost:$33562
[11:55:15] [156/240] RETRY Electronics Macau (will try 0.5x)
[11:55:14] [156/240] Electronics Macau | 0.34 @ 1.0x ($102000/u) | Flow:0.00 Rev:$139435 Cost:$34859
[11:55:14] [156/240] OK Consumer Goods Macau
[11:55:14] [156/240] Consumer Goods Macau | 0.42 @ 1.0x ($82400/u) | Flow:-0.59 Rev:$139435 Cost:$34859
[11:55:13] [155/240] OK Consumer Goods Estonia
[11:55:13] [155/240] Consumer Goods Estonia | 0.42 @ 1.0x ($82400/u) | Flow:-0.73 Rev:$140049 Cost:$35012
[11:55:12] [154/240] RETRY Electronics South Sudan (will try 0.5x)
[11:55:11] [154/240] Electronics South Sudan | 0.35 @ 1.0x ($102000/u) | Flow:0.00 Rev:$141125 Cost:$35281
[11:55:11] [154/240] OK Consumer Goods South Sudan
[11:55:11] [154/240] Consumer Goods South Sudan | 0.43 @ 1.0x ($82400/u) | Flow:-0.85 Rev:$141125 Cost:$35281
[11:55:10] [153/240] OK Consumer Goods Papua New Guinea
[11:55:10] [153/240] Consumer Goods Papua New Guinea | 0.43 @ 1.0x ($82400/u) | Flow:-0.84 Rev:$142843 Cost:$35711
[11:55:09] [152/240] OK Consumer Goods Trinidad And Tobago
[11:55:09] [152/240] Consumer Goods Trinidad And Tobago | 0.46 @ 1.0x ($82400/u) | Flow:-0.50 Rev:$150461 Cost:$37615
[11:55:09] [151/240] RETRY Electronics Suriname (will try 0.5x)
[11:55:08] [151/240] Electronics Suriname | 0.38 @ 1.0x ($102000/u) | Flow:0.00 Rev:$153001 Cost:$38250
[11:55:07] [151/240] OK Consumer Goods Suriname
[11:55:06] [151/240] Consumer Goods Suriname | 0.33 @ 1.0x ($82400/u) | Flow:-0.33 Rev:$152993 Cost:$27042
[11:55:06] [150/240] OK Consumer Goods Mauritius
[11:55:05] [150/240] Consumer Goods Mauritius | 0.47 @ 1.0x ($82400/u) | Flow:-0.93 Rev:$153707 Cost:$38427
[11:55:05] [149/240] RETRY Electronics Laos (will try 0.5x)
[11:55:04] [149/240] Electronics Laos | 0.39 @ 1.0x ($102000/u) | Flow:0.00 Rev:$157516 Cost:$39379
[11:55:04] [149/240] OK Consumer Goods Laos
[11:55:03] [149/240] Consumer Goods Laos | 0.48 @ 1.0x ($82400/u) | Flow:-1.26 Rev:$157516 Cost:$39379
[11:55:03] [148/240] RETRY Consumer Goods Gabon (will try 0.5x)
[11:55:02] [148/240] Consumer Goods Gabon | 0.48 @ 1.0x ($82400/u) | Flow:-1.00 Rev:$158171 Cost:$39543
[11:55:02] [147/240] OK Electronics Guyana
[11:55:02] [147/240] Electronics Guyana | 0.41 @ 1.0x ($102000/u) | Flow:0.00 Rev:$165262 Cost:$41316
[11:55:02] [147/240] RETRY Consumer Goods Guyana (will try 0.5x)
[11:55:01] [147/240] Consumer Goods Guyana | 0.40 @ 1.0x ($82400/u) | Flow:-0.40 Rev:$165253 Cost:$33138
[11:55:00] [146/240] OK Consumer Goods Moldova
[11:55:00] [146/240] Consumer Goods Moldova | 0.51 @ 1.0x ($82400/u) | Flow:-1.12 Rev:$167031 Cost:$41758
[11:54:59] [145/240] OK Consumer Goods Djibouti
[11:54:59] [145/240] Consumer Goods Djibouti | 0.51 @ 1.0x ($82400/u) | Flow:-1.05 Rev:$167770 Cost:$41942
[11:54:59] [144/240] RETRY Electronics Latvia (will try 0.5x)
[11:54:58] [144/240] Electronics Latvia | 0.41 @ 1.0x ($102000/u) | Flow:0.00 Rev:$167973 Cost:$41993
[11:54:57] [144/240] OK Consumer Goods Latvia
[11:54:57] [144/240] Consumer Goods Latvia | 0.51 @ 1.0x ($82400/u) | Flow:-1.13 Rev:$167973 Cost:$41993
[11:54:56] [143/240] OK Consumer Goods Botswana
[11:54:56] [143/240] Consumer Goods Botswana | 0.53 @ 1.0x ($82400/u) | Flow:-0.75 Rev:$173573 Cost:$43393
[11:54:56] [142/240] RETRY Electronics Burundi (will try 0.5x)
[11:54:55] [142/240] Electronics Burundi | 0.43 @ 1.0x ($102000/u) | Flow:0.00 Rev:$177350 Cost:$44338
[11:54:55] [140/240] OK Electronics Timor-Leste
[11:54:55] [140/240] Electronics Timor-Leste | 0.44 @ 1.0x ($102000/u) | Flow:0.00 Rev:$180807 Cost:$45202
[11:54:55] [137/240] RETRY Electronics Bahrain (will try 0.5x)
[11:54:54] [137/240] Electronics Bahrain | 0.45 @ 1.0x ($102000/u) | Flow:0.00 Rev:$181976 Cost:$45494
[11:54:53] [135/240] OK Electronics Sri Lanka
[11:54:53] [135/240] Electronics Sri Lanka | 0.45 @ 1.0x ($102000/u) | Flow:0.00 Rev:$184268 Cost:$46067
[11:54:53] [133/240] RETRY Electronics Croatia (will try 0.5x)
[11:54:52] [133/240] Electronics Croatia | 0.46 @ 1.0x ($102000/u) | Flow:0.00 Rev:$187155 Cost:$46789
[11:54:52] [130/240] OK Electronics Bosnia And Herzegovina
[11:54:51] [130/240] Electronics Bosnia And Herzegovina | 0.47 @ 1.0x ($102000/u) | Flow:0.00 Rev:$192650 Cost:$48162
[11:54:51] [127/240] RETRY Electronics Eritrea (will try 0.5x)
[11:54:50] [127/240] Electronics Eritrea | 0.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$195435 Cost:$48859
[11:54:50] [126/240] OK Electronics Ireland
[11:54:50] [126/240] Electronics Ireland | 0.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$197153 Cost:$49288
[11:54:50] [124/240] RETRY Electronics Rwanda (will try 0.5x)
[11:54:49] [124/240] Electronics Rwanda | 0.49 @ 1.0x ($102000/u) | Flow:0.00 Rev:$199674 Cost:$49918
[11:54:49] [122/240] OK Electronics Liberia
[11:54:48] [122/240] Electronics Liberia | 0.51 @ 1.0x ($102000/u) | Flow:0.00 Rev:$209106 Cost:$52276
[11:54:48] [120/240] RETRY Electronics Denmark (will try 0.5x)
[11:54:47] [120/240] Electronics Denmark | 0.52 @ 1.0x ($102000/u) | Flow:0.00 Rev:$210682 Cost:$52670
[11:54:47] [119/240] OK Electronics Albania
[11:54:47] [119/240] Electronics Albania | 0.52 @ 1.0x ($102000/u) | Flow:0.00 Rev:$211042 Cost:$52761
[11:54:47] [118/240] RETRY Electronics Oman (will try 0.5x)
[11:54:46] [118/240] Electronics Oman | 0.52 @ 1.0x ($102000/u) | Flow:0.00 Rev:$211686 Cost:$52922
[11:54:45] [116/240] OK Electronics Honduras
[11:54:45] [116/240] Electronics Honduras | 0.53 @ 1.0x ($102000/u) | Flow:0.00 Rev:$215410 Cost:$53852
[11:54:45] [113/240] RETRY Electronics Jamaica (will try 0.5x)
[11:54:44] [113/240] Electronics Jamaica | 0.55 @ 1.0x ($102000/u) | Flow:0.00 Rev:$222996 Cost:$55749
[11:54:44] [111/240] OK Electronics Georgia
[11:54:44] [111/240] Electronics Georgia | 0.57 @ 1.0x ($102000/u) | Flow:0.00 Rev:$231644 Cost:$57911
[11:54:44] [109/240] RETRY Electronics Cambodia (will try 0.5x)
[11:54:42] [109/240] Electronics Cambodia | 0.58 @ 1.0x ($102000/u) | Flow:0.00 Rev:$238352 Cost:$59588
[11:54:42] [105/240] OK Electronics Guatemala
[11:54:42] [105/240] Electronics Guatemala | 0.61 @ 1.0x ($102000/u) | Flow:0.00 Rev:$250505 Cost:$62626
[11:54:42] [101/240] RETRY Electronics Jordan (will try 0.5x)
[11:54:41] [101/240] Electronics Jordan | 0.64 @ 1.0x ($102000/u) | Flow:0.00 Rev:$260608 Cost:$65152
[11:54:41] [94/240] OK Electronics Turkmenistan
[11:54:40] [94/240] Electronics Turkmenistan | 0.68 @ 1.0x ($102000/u) | Flow:0.00 Rev:$278781 Cost:$69695
[11:54:40] [87/240] RETRY Electronics Kyrgyzstan (will try 0.5x)
[11:54:39] [87/240] Electronics Kyrgyzstan | 0.76 @ 1.0x ($102000/u) | Flow:0.00 Rev:$308257 Cost:$77064
[11:54:39] [85/240] OK Electronics Hungary
[11:54:39] [85/240] Electronics Hungary | 0.77 @ 1.0x ($102000/u) | Flow:0.00 Rev:$313397 Cost:$78349
[11:54:39] [78/240] RETRY Electronics Bulgaria (will try 0.5x)
[11:54:38] [78/240] Electronics Bulgaria | 0.90 @ 1.0x ($102000/u) | Flow:0.00 Rev:$366202 Cost:$91550
[11:54:37] [74/240] OK Electronics Guinea
[11:54:37] [74/240] Electronics Guinea | 0.94 @ 1.0x ($102000/u) | Flow:0.00 Rev:$385120 Cost:$96280
[11:54:37] [62/240] RETRY Electronics Cameroon (will try 0.5x)
[11:54:36] [62/240] Electronics Cameroon | 1.15 @ 1.0x ($102000/u) | Flow:0.00 Rev:$467438 Cost:$116860
[11:54:36] [54/240] OK Electronics Tajikistan
[11:54:36] [54/240] Electronics Tajikistan | 1.50 @ 1.0x ($102000/u) | Flow:0.00 Rev:$546203 Cost:$152937
[11:54:36] [48/240] RETRY Electronics Burma (will try 0.5x)
[11:54:34] [48/240] Electronics Burma | 1.72 @ 1.0x ($102000/u) | Flow:0.00 Rev:$626031 Cost:$175289
[11:54:34] [41/240] OK Electronics Algeria
[11:54:34] [41/240] Electronics Algeria | 2.23 @ 1.0x ($102000/u) | Flow:0.00 Rev:$810971 Cost:$227072
[11:54:34] [37/240] RETRY Electronics Kazakhstan (will try 0.5x)
[11:54:33] [37/240] Electronics Kazakhstan | 3.17 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1010685 Cost:$323419
[11:54:33] [33/240] OK Electronics Peru
[11:54:32] [33/240] Electronics Peru | 3.55 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1131579 Cost:$362105
[11:54:32] [FLOW Q] Queued 3.66 Consumer Goods to Canada (expires in 30s)
[11:54:32] [29/240] OK Consumer Goods Canada
[11:54:31] [29/240] Consumer Goods Canada | 1.65 @ 1.0x ($82400/u) | Flow:-23.71 Rev:$1367605 Cost:$136321
[11:54:31] [28/240] OK Consumer Goods Colombia
[11:54:31] [28/240] Consumer Goods Colombia | 5.74 @ 1.0x ($82400/u) | Flow:-27.43 Rev:$1477034 Cost:$472651
[11:54:31] [27/240] RETRY Consumer Goods Bangladesh (will try 0.5x)
[11:54:30] [27/240] Consumer Goods Bangladesh | 5.81 @ 1.0x ($82400/u) | Flow:-23.23 Rev:$1496782 Cost:$478970
[11:54:29] [26/240] OK Consumer Goods Ukraine
[11:54:29] [26/240] Consumer Goods Ukraine | 5.94 @ 1.0x ($82400/u) | Flow:-19.55 Rev:$1529158 Cost:$489331
[11:54:29] [25/240] RETRY Consumer Goods Philippines (will try 0.5x)
[11:54:28] [25/240] Consumer Goods Philippines | 6.20 @ 1.0x ($82400/u) | Flow:-28.40 Rev:$1596708 Cost:$510947
[11:54:27] [24/240] OK Electronics Vietnam
[11:54:27] [24/240] Electronics Vietnam | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1616085 Cost:$510000
[11:54:27] [16/240] RETRY Electronics Iran (will try 0.5x)
[11:54:26] [16/240] Electronics Iran | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1994384 Cost:$510000
[11:54:25] [8/240] OK Electronics Mexico
[11:54:25] [8/240] Electronics Mexico | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$3506653 Cost:$510000
[11:54:24] [FLOW Q] Queued 47.02 Consumer Goods to Japan (expires in 30s)
[11:54:24] [6/240] OK Consumer Goods Japan
[11:54:24] [6/240] Consumer Goods Japan | 2.56 @ 1.0x ($82400/u) | Flow:-92.56 Rev:$10751908 Cost:$211038
[11:54:24] [5/240] OK Consumer Goods Brazil
[11:54:23] [5/240] Consumer Goods Brazil | 52.37 @ 1.0x ($82400/u) | Flow:-127.82 Rev:$11355812 Cost:$4315209
[11:54:23] [3/240] RETRY Consumer Goods India (will try 0.5x)
[11:54:22] [3/240] Consumer Goods India | 54.93 @ 1.0x ($82400/u) | Flow:-207.34 Rev:$18586941 Cost:$4526246
[11:54:22] [2/240] OK Electronics United States
[11:54:22] [2/240] Electronics United States | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$23723212 Cost:$510000
[11:54:22] Trade cycle started
[11:54:22] TRIGGERED: Consumer Goods 54.9 Electronics 115.0
[11:54:22] [FLOW Q] Expired: Consumer Goods China
[11:53:08] [AutoBuy] Titanium: Bought 2.00
[11:53:08] [AutoBuy] OK 2.00 Titanium from China
[11:53:08] [AutoBuy] Buying 2.00 Titanium from China @ 1.0x (seller flow: 13.44)
[11:53:08] [AutoBuy] Titanium flow: -1.00, target: 1.00, need: 2.00
[11:52:57] [AutoBuy] Chromium: Bought 3.00
[11:52:57] [AutoBuy] OK 3.00 Chromium from Zimbabwe
[11:52:56] [AutoBuy] Buying 3.00 Chromium from Zimbabwe @ 1.0x (seller flow: 28.16)
[11:52:56] [AutoBuy] Chromium need: 3.00 (factory: 2.00, flow: 0.00, target: 1.00)
[11:52:45] [AutoBuy] Aluminum: Bought 3.00
[11:52:45] [AutoBuy] OK 3.00 Aluminum from Kazakhstan
[11:52:45] [AutoBuy] Buying 3.00 Aluminum from Kazakhstan @ 1.0x (seller flow: 11.00)
[11:52:45] [AutoBuy] Aluminum need: 3.00 (factory: 2.00, flow: 0.00, target: 1.00)
[11:52:23] [AutoBuy] Phosphate: Bought 3.50
[11:52:23] [AutoBuy] OK 3.50 Phosphate from Egypt
[11:52:23] [AutoBuy] Buying 3.50 Phosphate from Egypt @ 1.0x (seller flow: 9.00)
[11:52:23] [AutoBuy] Failed Phosphate from Tunisia, trying next
[11:52:22] [AutoBuy] Buying 3.50 Phosphate from Tunisia @ 1.0x (seller flow: 11.11)
[11:52:22] [AutoBuy] Phosphate flow: -2.50, target: 1.00, need: 3.50
[11:51:31] [AutoBuy] Phosphate: Bought 3.50
[11:51:31] [AutoBuy] OK 3.50 Phosphate from Tunisia
[11:51:31] [AutoBuy] Buying 3.50 Phosphate from Tunisia @ 1.0x (seller flow: 11.11)
[11:51:31] [AutoBuy] Phosphate need: 3.50 (factory: 3.50, flow: 1.00, target: 1.00)
[11:51:27] Done in 2.1s | OK:2 Skip:1 Fail:0
[11:51:27] RETRY: 1
[11:51:27] [FLOW Q] Queued 72.79 Consumer Goods to China (expires in 30s)
[11:51:27] [4/240] OK Consumer Goods China
[11:51:27] [4/240] Consumer Goods China | 3.87 @ 1.0x ($82400/u) | Flow:-361.30 Rev:$16622661 Cost:$319026
[11:51:27] [2/240] RETRY Consumer Goods India (will try 0.5x)
[11:51:26] [2/240] Consumer Goods India | 3.87 @ 1.0x ($82400/u) | Flow:-206.66 Rev:$18526780 Cost:$319026
[11:51:26] [1/240] OK Consumer Goods United States
[11:51:25] [1/240] Consumer Goods United States | 109.17 @ 1.0x ($82400/u) | Flow:-262.20 Rev:$23672422 Cost:$8995520
[11:51:25] Trade cycle started
[11:51:25] TRIGGERED: Consumer Goods 113.0
[11:51:25] [FLOW Q] Expired: Electronics El Salvador
[11:51:09] [AutoBuy] Phosphate: Bought 4.50
[11:51:09] [AutoBuy] OK 4.50 Phosphate from Kazakhstan
[11:51:09] [AutoBuy] Buying 4.50 Phosphate from Kazakhstan @ 1.0x (seller flow: 12.67)
[11:51:09] [AutoBuy] Phosphate need: 4.50 (factory: 3.50, flow: 0.00, target: 1.00)
[11:50:31] Done in 175.9s | OK:107 Skip:51 Fail:16
[11:50:31] [FLOW Q] Queued 1.08 Electronics to El Salvador (expires in 30s)
[11:50:31] [31/97] OK Electronics El Salvador
[11:50:30] [31/97] Electronics El Salvador | 0.10 @ 0.5x ($51000/u) | Flow:0.00 Rev:$240480 Cost:$5127
[11:50:30] [30/97] FAIL Electronics Guatemala
[11:50:29] [30/97] Electronics Guatemala | 0.10 @ 0.5x ($51000/u) | Flow:0.00 Rev:$248618 Cost:$5127
[11:50:29] [29/97] OK Electronics Uruguay
[11:50:29] [29/97] Electronics Uruguay | 1.23 @ 0.5x ($51000/u) | Flow:0.00 Rev:$251227 Cost:$62807
[11:50:29] [28/97] FAIL Electronics Jordan
[11:50:28] [28/97] Electronics Jordan | 1.24 @ 0.5x ($51000/u) | Flow:0.00 Rev:$258570 Cost:$63422
[11:50:28] [27/97] OK Electronics Czech Republic
[11:50:28] [27/97] Electronics Czech Republic | 1.30 @ 0.5x ($51000/u) | Flow:0.00 Rev:$265758 Cost:$66440
[11:50:28] [26/97] FAIL Electronics Turkmenistan
[11:50:27] [26/97] Electronics Turkmenistan | 1.36 @ 0.5x ($51000/u) | Flow:0.00 Rev:$276893 Cost:$69223
[11:50:27] [25/97] OK Electronics Azerbaijan
[11:50:27] [25/97] Electronics Azerbaijan | 1.48 @ 0.5x ($51000/u) | Flow:0.00 Rev:$301255 Cost:$75314
[11:50:27] [24/97] FAIL Electronics Hungary
[11:50:25] [24/97] Electronics Hungary | 1.52 @ 0.5x ($51000/u) | Flow:0.00 Rev:$310678 Cost:$77670
[11:50:25] [23/97] OK Electronics Cuba
[11:50:25] [23/97] Electronics Cuba | 1.66 @ 0.5x ($51000/u) | Flow:0.00 Rev:$339220 Cost:$84805
[11:50:25] [22/97] FAIL Electronics Bulgaria
[11:50:24] [22/97] Electronics Bulgaria | 1.78 @ 0.5x ($51000/u) | Flow:0.00 Rev:$363456 Cost:$90864
[11:50:24] [21/97] OK Electronics Switzerland
[11:50:24] [21/97] Electronics Switzerland | 1.86 @ 0.5x ($51000/u) | Flow:0.00 Rev:$378544 Cost:$94636
[11:50:24] [20/97] FAIL Electronics Guinea
[11:50:23] [20/97] Electronics Guinea | 1.87 @ 0.5x ($51000/u) | Flow:0.00 Rev:$382060 Cost:$95515
[11:50:23] [19/97] OK Electronics Portugal
[11:50:23] [19/97] Electronics Portugal | 2.08 @ 0.5x ($51000/u) | Flow:0.00 Rev:$424724 Cost:$106181
[11:50:23] [18/97] FAIL Electronics Cameroon
[11:50:22] [18/97] Electronics Cameroon | 2.27 @ 0.5x ($51000/u) | Flow:0.00 Rev:$462884 Cost:$115721
[11:50:22] [17/97] OK Electronics Kenya
[11:50:21] [17/97] Electronics Kenya | 2.78 @ 0.5x ($51000/u) | Flow:0.00 Rev:$507021 Cost:$141966
[11:50:21] [16/97] FAIL Electronics Tajikistan
[11:50:20] [16/97] Electronics Tajikistan | 2.98 @ 0.5x ($51000/u) | Flow:0.00 Rev:$542468 Cost:$151891
[11:50:20] [15/97] OK Electronics Hong Kong
[11:50:20] [15/97] Electronics Hong Kong | 3.25 @ 0.5x ($51000/u) | Flow:0.00 Rev:$591777 Cost:$165698
[11:50:20] [14/97] FAIL Electronics Burma
[11:50:19] [14/97] Electronics Burma | 3.40 @ 0.5x ($51000/u) | Flow:0.00 Rev:$619671 Cost:$173508
[11:50:19] [13/97] OK Electronics Syria
[11:50:19] [13/97] Electronics Syria | 3.66 @ 0.5x ($51000/u) | Flow:0.00 Rev:$667447 Cost:$186885
[11:50:19] [12/97] FAIL Electronics Kazakhstan
[11:50:18] [AutoBuy] Tungsten: Bought 3.00
[11:50:18] [AutoBuy] OK 3.00 Tungsten from Russia
[11:50:18] [12/97] Electronics Kazakhstan | 4.19 @ 0.5x ($51000/u) | Flow:0.00 Rev:$763072 Cost:$213660
[11:50:18] [11/97] FAIL Electronics Algeria
[11:50:18] [AutoBuy] Buying 3.00 Tungsten from Russia @ 1.0x (seller flow: 14.56)
[11:50:18] [AutoBuy] Tungsten need: 3.00 (factory: 2.00, flow: 0.00, target: 1.00)
[11:50:17] [11/97] Electronics Algeria | 4.40 @ 0.5x ($51000/u) | Flow:0.00 Rev:$802073 Cost:$224580
[11:50:17] [10/97] OK Electronics Australia
[11:50:17] [10/97] Electronics Australia | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$1065567 Cost:$255000
[11:50:17] [9/97] FAIL Electronics Peru
[11:50:15] [9/97] Electronics Peru | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$1118998 Cost:$255000
[11:50:15] [8/97] OK Electronics Colombia
[11:50:15] [8/97] Electronics Colombia | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$1460953 Cost:$255000
[11:50:15] [7/97] FAIL Electronics Vietnam
[11:50:14] [7/97] Electronics Vietnam | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$1596244 Cost:$255000
[11:50:14] [6/97] OK Electronics Egypt
[11:50:14] [6/97] Electronics Egypt | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$1809852 Cost:$255000
[11:50:14] [5/97] FAIL Electronics Iran
[11:50:13] [5/97] Electronics Iran | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$1973438 Cost:$255000
[11:50:13] [4/97] OK Electronics South Africa
[11:50:13] [4/97] Electronics South Africa | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$2217647 Cost:$255000
[11:50:13] [3/97] FAIL Electronics Mexico
[11:50:12] [3/97] Electronics Mexico | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$3472262 Cost:$255000
[11:50:12] [2/97] OK Electronics Japan
[11:50:12] [2/97] Electronics Japan | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$10654439 Cost:$255000
[11:50:11] [1/97] FAIL Electronics United States
[11:50:10] [1/97] Electronics United States | 5.00 @ 0.5x ($51000/u) | Flow:0.00 Rev:$23649519 Cost:$255000
[11:50:10] RETRY: 97
[11:50:10] [240/240] OK Electronics Tokelau
[11:50:10] [240/240] Electronics Tokelau | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100105 Cost:$25026
[11:50:10] [239/240] RETRY Electronics Niue (will try 0.5x)
[11:50:09] [239/240] Electronics Niue | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100113 Cost:$25028
[11:50:09] [238/240] OK Electronics Norfolk Island
[11:50:08] [238/240] Electronics Norfolk Island | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100122 Cost:$25030
[11:50:08] [237/240] RETRY Electronics Saba (will try 0.5x)
[11:50:07] [237/240] Electronics Saba | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100134 Cost:$25034
[11:50:07] [236/240] OK Electronics Antarctica
[11:50:07] [236/240] Electronics Antarctica | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100154 Cost:$25038
[11:50:07] [235/240] RETRY Electronics Falkland Islands (will try 0.5x)
[11:50:06] [235/240] Electronics Falkland Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100179 Cost:$25045
[11:50:05] [234/240] OK Electronics Sint Eustatius
[11:50:05] [234/240] Electronics Sint Eustatius | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100214 Cost:$25054
[11:50:05] [233/240] RETRY Electronics Montserrat (will try 0.5x)
[11:50:04] [233/240] Electronics Montserrat | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100308 Cost:$25077
[11:50:04] [232/240] OK Electronics Saint Helena
[11:50:03] [232/240] Electronics Saint Helena | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100313 Cost:$25078
[11:50:03] [231/240] RETRY Electronics Cook Islands (will try 0.5x)
[11:50:02] [231/240] Electronics Cook Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100373 Cost:$25093
[11:50:02] [230/240] OK Electronics Saint Pierre and Miquelon
[11:50:02] [230/240] Electronics Saint Pierre and Miquelon | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100410 Cost:$25102
[11:50:02] [229/240] RETRY Electronics Rapa Nui (will try 0.5x)
[11:50:01] [229/240] Electronics Rapa Nui | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100532 Cost:$25133
[11:50:00] [228/240] OK Electronics Wallis and Futuna
[11:50:00] [228/240] Electronics Wallis and Futuna | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100571 Cost:$25143
[11:50:00] [227/240] RETRY Electronics Saint Barthelemy (will try 0.5x)
[11:49:59] [227/240] Electronics Saint Barthelemy | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100680 Cost:$25170
[11:49:59] [226/240] OK Electronics Nauru
[11:49:59] [226/240] Electronics Nauru | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100732 Cost:$25183
[11:49:59] [225/240] RETRY Electronics Tuvalu (will try 0.5x)
[11:49:58] [225/240] Electronics Tuvalu | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100797 Cost:$25199
[11:49:57] [224/240] OK Electronics American Samoa
[11:49:57] [224/240] Electronics American Samoa | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100859 Cost:$25215
[11:49:57] [223/240] RETRY Electronics Faroe Islands (will try 0.5x)
[11:49:56] [223/240] Electronics Faroe Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$100986 Cost:$25246
[11:49:56] [222/240] OK Electronics Anguilla
[11:49:55] [222/240] Electronics Anguilla | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101007 Cost:$25252
[11:49:55] [221/240] RETRY Electronics Palau (will try 0.5x)
[11:49:54] [221/240] Electronics Palau | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101054 Cost:$25264
[11:49:54] [220/240] OK Electronics Turks And Caicos Islands
[11:49:54] [220/240] Electronics Turks And Caicos Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101369 Cost:$25342
[11:49:54] [219/240] RETRY Electronics Bonaire (will try 0.5x)
[11:49:53] [219/240] Electronics Bonaire | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101373 Cost:$25343
[11:49:52] [218/240] OK Electronics Micronesia
[11:49:52] [218/240] Electronics Micronesia | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101398 Cost:$25350
[11:49:52] [217/240] RETRY Electronics Dominica (will try 0.5x)
[11:49:52] Factory building complete: 2/2 built
[11:49:51] Built Fertilizer Factory in Awjilah (pop: 6762)
[11:49:51] Built Fertilizer Factory in Qaminis (pop: 5502)
[11:49:51] Building 2 Fertilizer Factory...
[11:49:51] [217/240] Electronics Dominica | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101593 Cost:$25398
[11:49:51] [216/240] OK Electronics British Virgin Islands
[11:49:50] [216/240] Electronics British Virgin Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101649 Cost:$25412
[11:49:50] [215/240] RETRY Electronics Marshall Islands (will try 0.5x)
[11:49:49] [215/240] Electronics Marshall Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101733 Cost:$25433
[11:49:49] [214/240] OK Electronics Saint Kitts And Nevis
[11:49:49] [214/240] Electronics Saint Kitts And Nevis | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101950 Cost:$25488
[11:49:49] [213/240] RETRY Electronics Kiribati (will try 0.5x)
[11:49:48] [213/240] Electronics Kiribati | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$101965 Cost:$25491
[11:49:47] [212/240] OK Electronics San Marino
[11:49:47] [212/240] Electronics San Marino | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102017 Cost:$25504
[11:49:47] [211/240] RETRY Electronics Mayotte (will try 0.5x)
[11:49:46] [211/240] Electronics Mayotte | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102187 Cost:$25547
[11:49:46] [210/240] OK Electronics Seychelles
[11:49:46] [210/240] Electronics Seychelles | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102292 Cost:$25573
[11:49:46] [209/240] RETRY Electronics Saint Martin (will try 0.5x)
[11:49:45] Factory building complete: 1/1 built
[11:49:45] Built Fertilizer Factory in Qaminis (pop: 5500)
[11:49:45] Building 1 Fertilizer Factory...
[11:49:45] [209/240] Electronics Saint Martin | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102326 Cost:$25582
[11:49:44] [208/240] OK Electronics Isle Of Man
[11:49:44] [208/240] Electronics Isle Of Man | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102445 Cost:$25611
[11:49:44] [207/240] RETRY Electronics Monaco (will try 0.5x)
[11:49:43] [207/240] Electronics Monaco | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102479 Cost:$25620
[11:49:43] [206/240] OK Electronics Antigua And Barbuda
[11:49:42] [206/240] Electronics Antigua And Barbuda | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102489 Cost:$25622
[11:49:42] [205/240] RETRY Electronics Saint Lucia (will try 0.5x)
[11:49:41] [205/240] Electronics Saint Lucia | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102590 Cost:$25648
[11:49:41] [204/240] OK Electronics Grenada
[11:49:41] [204/240] Electronics Grenada | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102631 Cost:$25658
[11:49:41] [203/240] RETRY Electronics Sint Maarten (will try 0.5x)
[11:49:40] [203/240] Electronics Sint Maarten | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$102830 Cost:$25707
[11:49:39] [202/240] OK Electronics Tonga
[11:49:39] [202/240] Electronics Tonga | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103210 Cost:$25803
[11:49:39] [201/240] RETRY Electronics Saint Vincent And The Grenadines (will try 0.5x)
[11:49:38] [201/240] Electronics Saint Vincent And The Grenadines | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103372 Cost:$25843
[11:49:38] [200/240] OK Electronics Northern Mariana Islands
[11:49:38] [200/240] Electronics Northern Mariana Islands | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103476 Cost:$25869
[11:49:38] [199/240] RETRY Electronics Vanuatu (will try 0.5x)
[11:49:37] [199/240] Electronics Vanuatu | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103552 Cost:$25888
[11:49:36] [198/240] OK Electronics Bermuda
[11:49:36] [198/240] Electronics Bermuda | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103566 Cost:$25892
[11:49:36] [197/240] RETRY Electronics Andorra (will try 0.5x)
[11:49:35] [197/240] Electronics Andorra | 0.25 @ 1.0x ($102000/u) | Flow:0.00 Rev:$103682 Cost:$25920
[11:49:35] [196/240] OK Electronics United States Virgin Islands
[11:49:34] [196/240] Electronics United States Virgin Islands | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$104055 Cost:$26014
[11:49:34] [195/240] RETRY Electronics Samoa (will try 0.5x)
[11:49:33] [195/240] Electronics Samoa | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$104220 Cost:$26055
[11:49:33] [194/240] OK Electronics Guernsey
[11:49:33] [194/240] Electronics Guernsey | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$104279 Cost:$26070
[11:49:33] [193/240] RETRY Electronics Cayman Islands (will try 0.5x)
[11:49:32] [193/240] Electronics Cayman Islands | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$104595 Cost:$26149
[11:49:31] [192/240] OK Electronics Aruba
[11:49:31] [192/240] Electronics Aruba | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$104686 Cost:$26172
[11:49:31] [191/240] RETRY Electronics Solomon Islands (will try 0.5x)
[11:49:30] [191/240] Electronics Solomon Islands | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$105451 Cost:$26363
[11:49:30] [190/240] OK Electronics Sao Tome And Principe
[11:49:30] [190/240] Electronics Sao Tome And Principe | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$106119 Cost:$26530
[11:49:30] [189/240] RETRY Electronics French Guiana (will try 0.5x)
[11:49:29] [189/240] Electronics French Guiana | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$106167 Cost:$26542
[11:49:28] [188/240] OK Electronics Belize
[11:49:28] [188/240] Electronics Belize | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$106271 Cost:$26568
[11:49:28] [187/240] RETRY Electronics New Caledonia (will try 0.5x)
[11:49:27] [187/240] Electronics New Caledonia | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$106337 Cost:$26584
[11:49:27] [186/240] OK Electronics Jersey
[11:49:27] [186/240] Electronics Jersey | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$107032 Cost:$26758
[11:49:27] [185/240] RETRY Electronics Luxembourg (will try 0.5x)
[11:49:26] [185/240] Electronics Luxembourg | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$107560 Cost:$26890
[11:49:25] [184/240] OK Electronics Maldives
[11:49:25] [184/240] Electronics Maldives | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$107690 Cost:$26922
[11:49:25] [183/240] RETRY Electronics Bhutan (will try 0.5x)
[11:49:24] [183/240] Electronics Bhutan | 0.26 @ 1.0x ($102000/u) | Flow:0.00 Rev:$107746 Cost:$26936
[11:49:24] [182/240] OK Electronics Guam
[11:49:23] [182/240] Electronics Guam | 0.27 @ 1.0x ($102000/u) | Flow:0.00 Rev:$108336 Cost:$27084
[11:49:23] [181/240] RETRY Electronics French Polynesia (will try 0.5x)
[11:49:22] [181/240] Electronics French Polynesia | 0.27 @ 1.0x ($102000/u) | Flow:0.00 Rev:$108968 Cost:$27242
[11:49:22] [180/240] OK Electronics Guadeloupe
[11:49:22] [180/240] Electronics Guadeloupe | 0.27 @ 1.0x ($102000/u) | Flow:0.00 Rev:$109906 Cost:$27476
[11:49:22] [179/240] RETRY Electronics Curacao (will try 0.5x)
[11:49:21] [179/240] Electronics Curacao | 0.27 @ 1.0x ($102000/u) | Flow:0.00 Rev:$109994 Cost:$27498
[11:49:20] [178/240] OK Electronics Cabo Verde
[11:49:20] [178/240] Electronics Cabo Verde | 0.27 @ 1.0x ($102000/u) | Flow:0.00 Rev:$110598 Cost:$27650
[11:49:20] [177/240] RETRY Electronics Gambia (will try 0.5x)
[11:49:19] [177/240] Electronics Gambia | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$112556 Cost:$28139
[11:49:19] [176/240] OK Electronics Gibraltar
[11:49:18] [176/240] Electronics Gibraltar | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$112735 Cost:$28184
[11:49:18] [175/240] RETRY Electronics Barbados (will try 0.5x)
[11:49:17] [175/240] Electronics Barbados | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$113012 Cost:$28253
[11:49:17] [174/240] RETRY Electronics Iceland (will try 0.5x)
[11:49:17] [AutoBuy] Iron: Bought 3.89
[11:49:17] [AutoBuy] OK 3.89 Iron from United States
[11:49:17] [AutoBuy] Buying 3.89 Iron from United States @ 1.0x (seller flow: 26.60)
[11:49:17] [AutoBuy] Failed Iron from Russia, trying next
[11:49:16] [174/240] Electronics Iceland | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$113158 Cost:$28290
[11:49:16] [173/240] OK Electronics Christmas Island
[11:49:16] [AutoBuy] Buying 3.89 Iron from Russia @ 1.0x (seller flow: 28.22)
[11:49:16] [AutoBuy] Iron flow: -2.89, target: 1.00, need: 3.89
[11:49:15] [173/240] Electronics Christmas Island | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$114234 Cost:$28558
[11:49:15] [172/240] RETRY Electronics Reunion (will try 0.5x)
[11:49:14] [172/240] Electronics Reunion | 0.28 @ 1.0x ($102000/u) | Flow:0.00 Rev:$114373 Cost:$28593
[11:49:14] [171/240] OK Electronics Montenegro
[11:49:14] [171/240] Electronics Montenegro | 0.29 @ 1.0x ($102000/u) | Flow:0.00 Rev:$117112 Cost:$29278
[11:49:14] [170/240] RETRY Electronics Martinique (will try 0.5x)
[11:49:13] [170/240] Electronics Martinique | 0.29 @ 1.0x ($102000/u) | Flow:0.00 Rev:$117284 Cost:$29321
[11:49:12] [169/240] OK Electronics Fiji
[11:49:12] [169/240] Electronics Fiji | 0.29 @ 1.0x ($102000/u) | Flow:0.00 Rev:$118178 Cost:$29544
[11:49:12] [168/240] RETRY Electronics Equatorial Guinea (will try 0.5x)
[11:49:11] [168/240] Electronics Equatorial Guinea | 0.29 @ 1.0x ($102000/u) | Flow:0.00 Rev:$118639 Cost:$29660
[11:49:11] [167/240] OK Electronics Bahamas
[11:49:11] [167/240] Electronics Bahamas | 0.29 @ 1.0x ($102000/u) | Flow:0.00 Rev:$118709 Cost:$29677
[11:49:11] [166/240] RETRY Electronics Eswatini (will try 0.5x)
[11:49:10] [166/240] Electronics Eswatini | 0.30 @ 1.0x ($102000/u) | Flow:0.00 Rev:$120505 Cost:$30126
[11:49:09] [165/240] OK Electronics Comoros
[11:49:09] [165/240] Electronics Comoros | 0.30 @ 1.0x ($102000/u) | Flow:0.00 Rev:$120761 Cost:$30190
[11:49:09] [164/240] RETRY Electronics Malta (will try 0.5x)
[11:49:08] [164/240] Electronics Malta | 0.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$125050 Cost:$31263
[11:49:08] [163/240] OK Electronics Kosovo
[11:49:08] [163/240] Electronics Kosovo | 0.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$125674 Cost:$31418
[11:49:08] [162/240] RETRY Electronics Liechtenstein (will try 0.5x)
[11:49:06] [162/240] Electronics Liechtenstein | 0.31 @ 1.0x ($102000/u) | Flow:0.00 Rev:$127770 Cost:$31942
[11:49:06] [161/240] RETRY Electronics Greenland (will try 0.5x)
[11:49:06] [AutoBuy] Titanium: Bought 1.20
[11:49:06] [AutoBuy] OK 1.20 Titanium from Australia
[11:49:06] [AutoBuy] Buying 1.20 Titanium from Australia @ 1.0x (seller flow: 9.44)
[11:49:06] [AutoBuy] Failed Titanium from China, trying next
[11:49:05] [161/240] Electronics Greenland | 0.32 @ 1.0x ($102000/u) | Flow:0.00 Rev:$128719 Cost:$32180
[11:49:05] [160/240] OK Electronics Cyprus
[11:49:05] [AutoBuy] Buying 1.20 Titanium from China @ 1.0x (seller flow: 13.44)
[11:49:05] [AutoBuy] Titanium need: 1.20 (factory: 0.20, flow: 0.00, target: 1.00)
[11:49:05] [160/240] Electronics Cyprus | 0.32 @ 1.0x ($102000/u) | Flow:0.00 Rev:$130130 Cost:$32533
[11:49:05] [159/240] RETRY Electronics Guinea-Bissau (will try 0.5x)
[11:49:04] [159/240] Electronics Guinea-Bissau | 0.32 @ 1.0x ($102000/u) | Flow:0.00 Rev:$130778 Cost:$32694
[11:49:03] [158/240] OK Electronics Slovenia
[11:49:03] [158/240] Electronics Slovenia | 0.33 @ 1.0x ($102000/u) | Flow:0.00 Rev:$133596 Cost:$33399
[11:49:03] [157/240] RETRY Electronics Macau (will try 0.5x)
[11:49:02] [157/240] Electronics Macau | 0.34 @ 1.0x ($102000/u) | Flow:0.00 Rev:$138672 Cost:$34668
[11:49:02] [156/240] OK Electronics Estonia
[11:49:01] [156/240] Electronics Estonia | 0.34 @ 1.0x ($102000/u) | Flow:0.00 Rev:$139284 Cost:$34821
[11:49:01] [155/240] RETRY Electronics South Sudan (will try 0.5x)
[11:49:00] [155/240] Electronics South Sudan | 0.34 @ 1.0x ($102000/u) | Flow:0.00 Rev:$140366 Cost:$35092
[11:49:00] [154/240] OK Electronics Papua New Guinea
[11:49:00] [154/240] Electronics Papua New Guinea | 0.35 @ 1.0x ($102000/u) | Flow:0.00 Rev:$142030 Cost:$35508
[11:49:00] [153/240] OK Electronics Trinidad And Tobago
[11:48:59] [153/240] Electronics Trinidad And Tobago | 0.37 @ 1.0x ($102000/u) | Flow:0.00 Rev:$149824 Cost:$37456
[11:48:59] [152/240] RETRY Electronics Suriname (will try 0.5x)
[11:48:58] [152/240] Electronics Suriname | 0.37 @ 1.0x ($102000/u) | Flow:0.00 Rev:$152498 Cost:$38124
[11:48:58] [151/240] OK Electronics Mauritius
[11:48:57] [151/240] Electronics Mauritius | 0.37 @ 1.0x ($102000/u) | Flow:0.00 Rev:$152701 Cost:$38175
[11:48:57] [150/240] RETRY Electronics Laos (will try 0.5x)
[11:48:56] [150/240] Electronics Laos | 0.38 @ 1.0x ($102000/u) | Flow:0.00 Rev:$155477 Cost:$38869
[11:48:56] [149/240] OK Electronics Gabon
[11:48:56] [149/240] Electronics Gabon | 0.38 @ 1.0x ($102000/u) | Flow:0.00 Rev:$157070 Cost:$39268
[11:48:56] [148/240] RETRY Electronics Guyana (will try 0.5x)
[11:48:55] [148/240] Electronics Guyana | 0.40 @ 1.0x ($102000/u) | Flow:0.00 Rev:$164653 Cost:$41163
[11:48:54] [147/240] OK Electronics Moldova
[11:48:54] [147/240] Electronics Moldova | 0.41 @ 1.0x ($102000/u) | Flow:0.00 Rev:$165797 Cost:$41449
[11:48:54] [146/240] OK Electronics Djibouti
[11:48:53] [146/240] Electronics Djibouti | 0.41 @ 1.0x ($102000/u) | Flow:0.00 Rev:$166481 Cost:$41620
[11:48:53] [145/240] RETRY Electronics Latvia (will try 0.5x)
[11:48:52] [145/240] Electronics Latvia | 0.41 @ 1.0x ($102000/u) | Flow:0.00 Rev:$166695 Cost:$41674
[11:48:52] [144/240] OK Electronics Botswana
[11:48:52] [144/240] Electronics Botswana | 0.42 @ 1.0x ($102000/u) | Flow:0.00 Rev:$172593 Cost:$43148
[11:48:52] [143/240] RETRY Electronics Burundi (will try 0.5x)
[11:48:51] [143/240] Electronics Burundi | 0.43 @ 1.0x ($102000/u) | Flow:0.00 Rev:$176531 Cost:$44133
[11:48:50] [142/240] OK Electronics Lithuania
[11:48:50] [142/240] Electronics Lithuania | 0.44 @ 1.0x ($102000/u) | Flow:0.00 Rev:$179207 Cost:$44802
[11:48:50] [141/240] RETRY Electronics Timor-Leste (will try 0.5x)
[11:48:49] [141/240] Electronics Timor-Leste | 0.44 @ 1.0x ($102000/u) | Flow:0.00 Rev:$180331 Cost:$45083
[11:48:49] [140/240] OK Electronics Macedonia
[11:48:48] [140/240] Electronics Macedonia | 0.44 @ 1.0x ($102000/u) | Flow:0.00 Rev:$180709 Cost:$45177
[11:48:48] [139/240] OK Electronics Namibia
[11:48:47] [139/240] Electronics Namibia | 0.44 @ 1.0x ($102000/u) | Flow:0.00 Rev:$180989 Cost:$45247
[11:48:47] [138/240] RETRY Electronics Bahrain (will try 0.5x)
[11:48:46] [138/240] Electronics Bahrain | 0.44 @ 1.0x ($102000/u) | Flow:0.00 Rev:$181002 Cost:$45250
[11:48:46] [137/240] OK Electronics Mauritania
[11:48:46] [137/240] Electronics Mauritania | 0.45 @ 1.0x ($102000/u) | Flow:0.00 Rev:$181649 Cost:$45412
[11:48:46] [136/240] RETRY Electronics Sri Lanka (will try 0.5x)
[11:48:45] [136/240] Electronics Sri Lanka | 0.45 @ 1.0x ($102000/u) | Flow:0.00 Rev:$182747 Cost:$45687
[11:48:44] [135/240] OK Electronics Central African Republic
[11:48:44] [135/240] Electronics Central African Republic | 0.45 @ 1.0x ($102000/u) | Flow:0.00 Rev:$185464 Cost:$46366
[11:48:44] [134/240] RETRY Electronics Croatia (will try 0.5x)
[11:48:43] [134/240] Electronics Croatia | 0.45 @ 1.0x ($102000/u) | Flow:0.00 Rev:$185537 Cost:$46384
[11:48:43] [133/240] OK Electronics Benin
[11:48:43] [133/240] Electronics Benin | 0.46 @ 1.0x ($102000/u) | Flow:0.00 Rev:$187798 Cost:$46950
[11:48:42] [132/240] OK Electronics Armenia
[11:48:42] [132/240] Electronics Armenia | 0.46 @ 1.0x ($102000/u) | Flow:0.00 Rev:$188604 Cost:$47151
[11:48:42] [131/240] RETRY Electronics Bosnia And Herzegovina (will try 0.5x)
[11:48:41] [131/240] Electronics Bosnia And Herzegovina | 0.47 @ 1.0x ($102000/u) | Flow:0.00 Rev:$190914 Cost:$47728
[11:48:40] [130/240] OK Electronics Palestine
[11:48:40] [130/240] Electronics Palestine | 0.47 @ 1.0x ($102000/u) | Flow:0.00 Rev:$192752 Cost:$48188
[11:48:40] [129/240] RETRY Electronics Eritrea (will try 0.5x)
[11:48:39] [129/240] Electronics Eritrea | 0.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$193909 Cost:$48477
[11:48:39] [128/240] OK Electronics Brunei
[11:48:38] [128/240] Electronics Brunei | 0.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$194300 Cost:$48575
[11:48:38] [127/240] RETRY Electronics Ireland (will try 0.5x)
[11:48:37] [127/240] Electronics Ireland | 0.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$195299 Cost:$48825
[11:48:37] Factory building complete: 1/1 built
[11:48:37] [126/240] OK Electronics Malawi
[11:48:37] Built Aircraft Manufactory in Qaminis (pop: 5474)
[11:48:37] Building 1 Aircraft Manufactory...
[11:48:37] [126/240] Electronics Malawi | 0.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$197502 Cost:$49376
[11:48:37] [125/240] RETRY Electronics Rwanda (will try 0.5x)
[11:48:36] [125/240] Electronics Rwanda | 0.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$197793 Cost:$49448
[11:48:35] [124/240] OK Electronics Slovakia
[11:48:35] [124/240] Electronics Slovakia | 0.50 @ 1.0x ($102000/u) | Flow:0.00 Rev:$204508 Cost:$51127
[11:48:35] [123/240] RETRY Electronics Liberia (will try 0.5x)
[11:48:34] [123/240] Electronics Liberia | 0.51 @ 1.0x ($102000/u) | Flow:0.00 Rev:$207287 Cost:$51822
[11:48:34] [122/240] OK Electronics Nicaragua
[11:48:34] [122/240] Electronics Nicaragua | 0.51 @ 1.0x ($102000/u) | Flow:0.00 Rev:$207844 Cost:$51961
[11:48:34] [121/240] RETRY Electronics Denmark (will try 0.5x)
[11:48:33] [121/240] Electronics Denmark | 0.51 @ 1.0x ($102000/u) | Flow:0.00 Rev:$208584 Cost:$52146
[11:48:33] [120/240] RETRY Electronics Albania (will try 0.5x)
[11:48:32] [AutoBuy] Copper: Bought 2.00
[11:48:32] [AutoBuy] OK 2.00 Copper from Zambia
[11:48:32] [AutoBuy] Buying 2.00 Copper from Zambia @ 1.0x (seller flow: 10.22)
[11:48:32] [AutoBuy] Failed Copper from Kazakhstan, trying next
[11:48:32] [120/240] Electronics Albania | 0.51 @ 1.0x ($102000/u) | Flow:0.00 Rev:$208931 Cost:$52233
[11:48:32] [119/240] RETRY Electronics Oman (will try 0.5x)
[11:48:31] [AutoBuy] Buying 2.00 Copper from Kazakhstan @ 1.0x (seller flow: 18.00)
[11:48:31] [AutoBuy] Copper flow: -1.00, target: 1.00, need: 2.00
[11:48:31] [AutoBuy] Gold: Bought 2.00
[11:48:31] [AutoBuy] OK 2.00 Gold from South Africa
[11:48:31] [AutoBuy] Buying 2.00 Gold from South Africa @ 1.0x (seller flow: 15.56)
[11:48:31] [AutoBuy] Gold flow: -1.00, target: 1.00, need: 2.00
[11:48:30] [119/240] Electronics Oman | 0.51 @ 1.0x ($102000/u) | Flow:0.00 Rev:$209567 Cost:$52392
[11:48:30] [118/240] OK Electronics Panama
[11:48:30] [118/240] Electronics Panama | 0.51 @ 1.0x ($102000/u) | Flow:0.00 Rev:$210066 Cost:$52516
[11:48:30] [117/240] RETRY Electronics Honduras (will try 0.5x)
[11:48:29] [117/240] Electronics Honduras | 0.52 @ 1.0x ($102000/u) | Flow:0.00 Rev:$213205 Cost:$53301
[11:48:29] [116/240] OK Electronics Chad
[11:48:28] [116/240] Electronics Chad | 0.53 @ 1.0x ($102000/u) | Flow:0.00 Rev:$216313 Cost:$54078
[11:48:28] [115/240] RETRY Electronics Kyrgyzstan (will try 0.5x)
[11:48:27] [115/240] Electronics Kyrgyzstan | 0.75 @ 1.0x ($102000/u) | Flow:0.00 Rev:$305971 Cost:$76493
[11:48:27] [114/240] OK Electronics Nepal
[11:48:27] [114/240] Electronics Nepal | 0.54 @ 1.0x ($102000/u) | Flow:0.00 Rev:$219852 Cost:$54963
[11:48:27] [113/240] RETRY Electronics Jamaica (will try 0.5x)
[11:48:26] [113/240] Electronics Jamaica | 0.54 @ 1.0x ($102000/u) | Flow:0.00 Rev:$220838 Cost:$55210
[11:48:25] [112/240] OK Electronics Costa Rica
[11:48:25] [112/240] Electronics Costa Rica | 0.54 @ 1.0x ($102000/u) | Flow:0.00 Rev:$221790 Cost:$55448
[11:48:25] [111/240] RETRY Electronics Georgia (will try 0.5x)
[11:48:24] [111/240] Electronics Georgia | 0.56 @ 1.0x ($102000/u) | Flow:0.00 Rev:$229320 Cost:$57330
[11:48:24] [110/240] OK Electronics Burkina Faso
[11:48:24] [110/240] Electronics Burkina Faso | 0.57 @ 1.0x ($102000/u) | Flow:0.00 Rev:$233999 Cost:$58500
[11:48:24] [109/240] RETRY Electronics Cambodia (will try 0.5x)
[11:48:23] [109/240] Electronics Cambodia | 0.58 @ 1.0x ($102000/u) | Flow:0.00 Rev:$235679 Cost:$58920
[11:48:22] [108/240] OK Electronics Serbia
[11:48:22] [108/240] Electronics Serbia | 0.58 @ 1.0x ($102000/u) | Flow:0.00 Rev:$237951 Cost:$59488
[11:48:22] [107/240] RETRY Electronics El Salvador (will try 0.5x)
[11:48:21] [107/240] Electronics El Salvador | 0.59 @ 1.0x ($102000/u) | Flow:0.00 Rev:$239547 Cost:$59887
[11:48:21] [106/240] OK Electronics Norway
[11:48:20] [106/240] Electronics Norway | 0.60 @ 1.0x ($102000/u) | Flow:0.00 Rev:$245406 Cost:$61352
[11:48:20] [105/240] RETRY Electronics Guatemala (will try 0.5x)
[11:48:19] [105/240] Electronics Guatemala | 0.61 @ 1.0x ($102000/u) | Flow:0.00 Rev:$247603 Cost:$61901
[11:48:19] [104/240] OK Electronics Republic of Congo
[11:48:19] [104/240] Electronics Republic of Congo | 0.61 @ 1.0x ($102000/u) | Flow:0.00 Rev:$249640 Cost:$62410
[11:48:19] [103/240] RETRY Electronics Uruguay (will try 0.5x)
[11:48:18] [103/240] Electronics Uruguay | 0.61 @ 1.0x ($102000/u) | Flow:0.00 Rev:$250177 Cost:$62544
[11:48:17] [102/240] OK Electronics Finland
[11:48:17] [102/240] Electronics Finland | 0.62 @ 1.0x ($102000/u) | Flow:0.00 Rev:$253154 Cost:$63288
[11:48:17] [101/240] RETRY Electronics Jordan (will try 0.5x)
[11:48:16] [101/240] Electronics Jordan | 0.63 @ 1.0x ($102000/u) | Flow:0.00 Rev:$257538 Cost:$64384
[11:48:16] [100/240] OK Electronics Qatar
[11:48:16] [100/240] Electronics Qatar | 0.64 @ 1.0x ($102000/u) | Flow:0.00 Rev:$259583 Cost:$64896
[11:48:16] [98/240] RETRY Electronics Czech Republic (will try 0.5x)
[11:48:15] [98/240] Electronics Czech Republic | 0.65 @ 1.0x ($102000/u) | Flow:0.00 Rev:$264677 Cost:$66169
[11:48:14] [96/240] OK Electronics Haiti
[11:48:14] [96/240] Electronics Haiti | 0.66 @ 1.0x ($102000/u) | Flow:0.00 Rev:$268633 Cost:$67158
[11:48:14] [94/240] RETRY Electronics Turkmenistan (will try 0.5x)
[11:48:13] [94/240] Electronics Turkmenistan | 0.68 @ 1.0x ($102000/u) | Flow:0.00 Rev:$275897 Cost:$68974
[11:48:13] [92/240] OK Electronics New Zealand
[11:48:12] [92/240] Electronics New Zealand | 0.70 @ 1.0x ($102000/u) | Flow:0.00 Rev:$285878 Cost:$71470
[11:48:12] [90/240] RETRY Electronics Azerbaijan (will try 0.5x)
[11:48:11] [90/240] Electronics Azerbaijan | 0.73 @ 1.0x ($102000/u) | Flow:0.00 Rev:$299863 Cost:$74966
[11:48:11] [88/240] OK Electronics Mongolia
[11:48:11] [88/240] Electronics Mongolia | 0.75 @ 1.0x ($102000/u) | Flow:0.00 Rev:$304648 Cost:$76162
[11:48:11] [86/240] RETRY Electronics Hungary (will try 0.5x)
[11:48:10] [86/240] Electronics Hungary | 0.76 @ 1.0x ($102000/u) | Flow:0.00 Rev:$309241 Cost:$77310
[11:48:09] [84/240] OK Electronics Somalia
[11:48:09] [84/240] Electronics Somalia | 0.78 @ 1.0x ($102000/u) | Flow:0.00 Rev:$316587 Cost:$79147
[11:48:09] [82/240] RETRY Electronics Cuba (will try 0.5x)
[11:48:08] [82/240] Electronics Cuba | 0.82 @ 1.0x ($102000/u) | Flow:0.00 Rev:$335699 Cost:$83925
[11:48:07] [80/240] OK Electronics United Arab Emirates
[11:48:07] [80/240] Electronics United Arab Emirates | 0.84 @ 1.0x ($102000/u) | Flow:0.00 Rev:$342828 Cost:$85707
[11:48:07] [78/240] RETRY Electronics Bulgaria (will try 0.5x)
[11:48:06] [78/240] Electronics Bulgaria | 0.89 @ 1.0x ($102000/u) | Flow:0.00 Rev:$361913 Cost:$90478
[11:48:06] [76/240] RETRY Electronics Switzerland (will try 0.5x)
[11:48:06] [AutoBuy] Copper: Bought 2.00
[11:48:06] [AutoBuy] OK 2.00 Copper from Chile
[11:48:06] [AutoBuy] Buying 2.00 Copper from Chile @ 1.0x (seller flow: 17.22)
[11:48:06] [AutoBuy] Failed Copper from Kazakhstan, trying next
[11:48:05] [76/240] Electronics Switzerland | 0.92 @ 1.0x ($102000/u) | Flow:0.00 Rev:$376616 Cost:$94154
[11:48:05] [74/240] RETRY Electronics Guinea (will try 0.5x)
[11:48:05] [AutoBuy] Buying 2.00 Copper from Kazakhstan @ 1.0x (seller flow: 18.00)
[11:48:05] [AutoBuy] Copper flow: -1.00, target: 1.00, need: 2.00
[11:48:05] [AutoBuy] Gold: Bought 2.00
[11:48:05] [AutoBuy] OK 2.00 Gold from Kyrgyzstan
[11:48:05] [AutoBuy] Buying 2.00 Gold from Kyrgyzstan @ 1.0x (seller flow: 10.00)
[11:48:05] [AutoBuy] Failed Gold from Russia, trying next
[11:48:04] [74/240] Electronics Guinea | 0.93 @ 1.0x ($102000/u) | Flow:0.00 Rev:$380448 Cost:$95112
[11:48:04] [71/240] OK Electronics Tunisia
[11:48:04] [AutoBuy] Buying 2.00 Gold from Russia @ 1.0x (seller flow: 11.44)
[11:48:04] [71/240] Electronics Tunisia | 0.98 @ 1.0x ($102000/u) | Flow:0.00 Rev:$401857 Cost:$100464
[11:48:04] [AutoBuy] Failed Gold from South Africa, trying next
[11:48:03] [69/240] OK Electronics Austria
[11:48:03] [AutoBuy] Buying 2.00 Gold from South Africa @ 1.0x (seller flow: 15.56)
[11:48:03] [AutoBuy] Gold flow: -1.00, target: 1.00, need: 2.00
[11:48:03] [69/240] Electronics Austria | 1.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$406153 Cost:$101538
[11:48:03] [67/240] RETRY Electronics Portugal (will try 0.5x)
[11:48:02] [67/240] Electronics Portugal | 1.04 @ 1.0x ($102000/u) | Flow:0.00 Rev:$422432 Cost:$105608
[11:48:01] [64/240] OK Electronics Tanzania
[11:48:01] [64/240] Electronics Tanzania | 1.11 @ 1.0x ($102000/u) | Flow:0.00 Rev:$453332 Cost:$113333
[11:48:01] [62/240] RETRY Electronics Cameroon (will try 0.5x)
[11:48:00] [62/240] Electronics Cameroon | 1.13 @ 1.0x ($102000/u) | Flow:0.00 Rev:$460378 Cost:$115094
[11:48:00] [60/240] OK Electronics North Korea
[11:47:59] [60/240] Electronics North Korea | 1.20 @ 1.0x ($102000/u) | Flow:0.00 Rev:$490919 Cost:$122730
[11:47:59] [58/240] RETRY Electronics Kenya (will try 0.5x)
[11:47:58] [58/240] Electronics Kenya | 1.38 @ 1.0x ($102000/u) | Flow:0.00 Rev:$504162 Cost:$141165
[11:47:58] [56/240] OK Electronics Senegal
[11:47:58] [56/240] Electronics Senegal | 1.41 @ 1.0x ($102000/u) | Flow:0.00 Rev:$514820 Cost:$144150
[11:47:58] [54/240] RETRY Electronics Tajikistan (will try 0.5x)
[11:47:57] [54/240] Electronics Tajikistan | 1.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$540333 Cost:$151293
[11:47:57] [52/240] OK Electronics Netherlands
[11:47:56] [52/240] Electronics Netherlands | 1.52 @ 1.0x ($102000/u) | Flow:0.00 Rev:$552893 Cost:$154810
[11:47:56] [50/240] RETRY Electronics Hong Kong (will try 0.5x)
[11:47:55] [50/240] Electronics Hong Kong | 1.61 @ 1.0x ($102000/u) | Flow:0.00 Rev:$588097 Cost:$164667
[11:47:55] [48/240] RETRY Electronics Burma (will try 0.5x)
[11:47:55] [AutoBuy] Copper: Bought 2.00
[11:47:55] [AutoBuy] OK 2.00 Copper from China
[11:47:55] [AutoBuy] Buying 2.00 Copper from China @ 1.0x (seller flow: 13.89)
[11:47:55] Factory building complete: 1/1 built
[11:47:55] [AutoBuy] Failed Copper from Chile, trying next
[11:47:54] Built Aircraft Manufactory in Qaminis (pop: 5458)
[11:47:54] Building 1 Aircraft Manufactory...
[11:47:54] [48/240] Electronics Burma | 1.69 @ 1.0x ($102000/u) | Flow:0.00 Rev:$616030 Cost:$172488
[11:47:54] [46/240] RETRY Electronics Syria (will try 0.5x)
[11:47:54] [AutoBuy] Buying 2.00 Copper from Chile @ 1.0x (seller flow: 17.22)
[11:47:54] [AutoBuy] Failed Copper from Kazakhstan, trying next
[11:47:53] [46/240] Electronics Syria | 1.82 @ 1.0x ($102000/u) | Flow:0.00 Rev:$663415 Cost:$185756
[11:47:53] [44/240] RETRY Electronics Kazakhstan (will try 0.5x)
[11:47:53] [AutoBuy] Buying 2.00 Copper from Kazakhstan @ 1.0x (seller flow: 18.00)
[11:47:53] [AutoBuy] Copper flow: -1.00, target: 1.00, need: 2.00
[11:47:53] [AutoBuy] Gold: Bought 2.00
[11:47:53] [AutoBuy] OK 2.00 Gold from Kazakhstan
[11:47:53] Factory building complete: 1/1 built
[11:47:53] [AutoBuy] Buying 2.00 Gold from Kazakhstan @ 1.0x (seller flow: 12.11)
[11:47:52] [AutoBuy] Failed Gold from South Africa, trying next
[11:47:52] Built Fertilizer Factory in Qaminis (pop: 5458)
[11:47:52] Building 1 Fertilizer Factory...
[11:47:52] [44/240] Electronics Kazakhstan | 1.85 @ 1.0x ($102000/u) | Flow:0.00 Rev:$672554 Cost:$188315
[11:47:52] [42/240] OK Electronics Poland
[11:47:52] [AutoBuy] Buying 2.00 Gold from South Africa @ 1.0x (seller flow: 15.56)
[11:47:52] [AutoBuy] Gold flow: -1.00, target: 1.00, need: 2.00
[11:47:51] [42/240] Electronics Poland | 2.10 @ 1.0x ($102000/u) | Flow:0.00 Rev:$764822 Cost:$214150
[11:47:51] [40/240] RETRY Electronics Algeria (will try 0.5x)
[11:47:51] Factory building complete: 1/1 built
[11:47:50] Built Motor Factory in Qaminis (pop: 5458)
[11:47:50] Building 1 Motor Factory...
[11:47:50] [40/240] Electronics Algeria | 2.19 @ 1.0x ($102000/u) | Flow:0.00 Rev:$797094 Cost:$223186
[11:47:50] [38/240] OK Electronics Chile
[11:47:50] [38/240] Electronics Chile | 2.53 @ 1.0x ($102000/u) | Flow:0.00 Rev:$922902 Cost:$258413
[11:47:50] [36/240] RETRY Electronics Australia (will try 0.5x)
[11:47:49] [36/240] Electronics Australia | 2.64 @ 1.0x ($102000/u) | Flow:0.00 Rev:$961727 Cost:$269284
[11:47:48] [33/240] OK Electronics Morocco
[11:47:48] [33/240] Electronics Morocco | 3.20 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1019199 Cost:$326144
[11:47:48] [32/240] RETRY Electronics Peru (will try 0.5x)
[11:47:47] [32/240] Electronics Peru | 3.49 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1111798 Cost:$355775
[11:47:47] Factory building complete: 1/1 built
[11:47:47] [30/240] OK Electronics Taiwan
[11:47:47] Built Steel Manufactory in Qaminis (pop: 5456)
[11:47:47] Building 1 Steel Manufactory...
[11:47:47] [30/240] Electronics Taiwan | 3.75 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1194525 Cost:$382248
[11:47:47] [28/240] RETRY Electronics Colombia (will try 0.5x)
[11:47:46] [28/240] Electronics Colombia | 4.55 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1451388 Cost:$464444
[11:47:45] [26/240] OK Electronics Ukraine
[11:47:45] [26/240] Electronics Ukraine | 4.71 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1502359 Cost:$480755
[11:47:45] [24/240] RETRY Electronics Vietnam (will try 0.5x)
[11:47:44] [24/240] Electronics Vietnam | 4.97 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1583689 Cost:$506780
[11:47:44] [22/240] OK Electronics South Korea
[11:47:43] [22/240] Electronics South Korea | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1677052 Cost:$510000
[11:47:43] [20/240] RETRY Electronics Egypt (will try 0.5x)
[11:47:42] [20/240] Electronics Egypt | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1797896 Cost:$510000
[11:47:42] [18/240] OK Electronics Spain
[11:47:42] [18/240] Electronics Spain | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1826639 Cost:$510000
[11:47:42] [16/240] RETRY Electronics Iran (will try 0.5x)
[11:47:41] [16/240] Electronics Iran | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1960683 Cost:$510000
[11:47:40] [14/240] OK Electronics Pakistan
[11:47:40] [14/240] Electronics Pakistan | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2079722 Cost:$510000
[11:47:40] [12/240] RETRY Electronics South Africa (will try 0.5x)
[11:47:39] Factory building complete: 10/10 built
[11:47:39] Built Electronics Factory in Marzuq (pop: 55875)
[11:47:39] [12/240] Electronics South Africa | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2117400 Cost:$510000
[11:47:39] Built Electronics Factory in Birak (pop: 46097)
[11:47:39] [10/240] OK Electronics Germany
[11:47:38] Built Electronics Factory in Shahhat (pop: 45687)
[11:47:38] [10/240] Electronics Germany | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2463534 Cost:$510000
[11:47:38] [8/240] RETRY Electronics Mexico (will try 0.5x)
[11:47:38] Built Electronics Factory in Mizdah (pop: 26523)
[11:47:38] Built Electronics Factory in Ghat (pop: 24718)
[11:47:38] Built Electronics Factory in Al Jawf (pop: 24503)
[11:47:37] [8/240] Electronics Mexico | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$3451755 Cost:$510000
[11:47:37] [5/240] RETRY Electronics Japan (will try 0.5x)
[11:47:37] Built Electronics Factory in Hun (pop: 19196)
[11:47:37] [AutoBuy] Copper: Bought 4.00
[11:47:37] [AutoBuy] OK 4.00 Copper from Russia
[11:47:37] [AutoBuy] Buying 4.00 Copper from Russia @ 1.0x (seller flow: 14.44)
[11:47:37] Built Electronics Factory in Ghadamis (pop: 6727)
[11:47:37] [AutoBuy] Failed Copper from Chile, trying next
[11:47:37] Built Electronics Factory in Awjilah (pop: 6714)
[11:47:36] [5/240] Electronics Japan | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$10596226 Cost:$510000
[11:47:36] Built Electronics Factory in Qaminis (pop: 5452)
[11:47:36] Building 10 Electronics Factory...
[11:47:36] [3/240] OK Electronics China
[11:47:36] [AutoBuy] Buying 4.00 Copper from Chile @ 1.0x (seller flow: 17.22)
[11:47:36] [3/240] Electronics China | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$16454539 Cost:$510000
[11:47:36] [1/240] RETRY Electronics United States (will try 0.5x)
[11:47:36] [AutoBuy] Failed Copper from Kazakhstan, trying next
[11:47:35] [AutoBuy] Buying 4.00 Copper from Kazakhstan @ 1.0x (seller flow: 18.00)
[11:47:35] [AutoBuy] Copper flow: -3.00, target: 1.00, need: 4.00
[11:47:35] [AutoBuy] Gold: Bought 4.00
[11:47:35] [AutoBuy] OK 4.00 Gold from Canada
[11:47:35] [1/240] Electronics United States | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$23487005 Cost:$510000
[11:47:35] Trade cycle started
[11:47:35] TRIGGERED: Electronics 47.8
[11:47:35] [AutoBuy] Buying 4.00 Gold from Canada @ 1.0x (seller flow: 16.56)
[11:47:35] [AutoBuy] Gold flow: -3.00, target: 1.00, need: 4.00
[11:47:28] Factory building complete: 10/10 built
[11:47:27] Built Electronics Factory in Marzuq (pop: 55845)
[11:47:27] Built Electronics Factory in Birak (pop: 46084)
[11:47:27] Built Electronics Factory in Shahhat (pop: 45661)
[11:47:27] Built Electronics Factory in Mizdah (pop: 26499)
[11:47:26] Built Electronics Factory in Ghat (pop: 24697)
[11:47:26] Built Electronics Factory in Al Jawf (pop: 24482)
[11:47:26] Built Electronics Factory in Hun (pop: 19178)
[11:47:25] Built Electronics Factory in Ghadamis (pop: 6723)
[11:47:25] [FLOW Q] Expired: Electronics Mali
[11:47:25] Built Electronics Factory in Awjilah (pop: 6710)
[11:47:25] [FLOW Q] Failed: Electronics Mali
[11:47:25] Built Electronics Factory in Qaminis (pop: 5450)
[11:47:25] Building 10 Electronics Factory...
[11:47:24] [FLOW Q] Trying 0.32 Electronics to Mali
[11:47:24] [FLOW Q] Failed: Electronics Mali
[11:47:23] [FLOW Q] Trying 0.28 Electronics to Mali
[11:47:22] [FLOW Q] Failed: Electronics Mali
[11:47:21] [FLOW Q] Trying 0.28 Electronics to Mali
[11:47:21] [FLOW Q] Failed: Electronics Mali
[11:47:20] [FLOW Q] Trying 0.28 Electronics to Mali
[11:47:20] [FLOW Q] Failed: Electronics Mali
[11:47:19] [FLOW Q] Trying 0.28 Electronics to Mali
[11:47:18] [FLOW Q] Failed: Electronics Mali
[11:47:17] [FLOW Q] Trying 0.24 Electronics to Mali
[11:47:17] [FLOW Q] Failed: Electronics Mali
[11:47:16] [FLOW Q] Trying 0.24 Electronics to Mali
[11:47:16] [FLOW Q] Failed: Electronics Mali
[11:47:15] Factory building complete: 10/10 built
[11:47:15] [FLOW Q] Trying 0.24 Electronics to Mali
[11:47:15] Built Electronics Factory in Marzuq (pop: 55800)
[11:47:15] [FLOW Q] Failed: Electronics Mali
[11:47:14] Built Electronics Factory in Birak (pop: 46045)
[11:47:14] Built Electronics Factory in Shahhat (pop: 45622)
[11:47:14] Built Electronics Factory in Mizdah (pop: 26483)
[11:47:14] [FLOW Q] Trying 0.24 Electronics to Mali
[11:47:13] Built Electronics Factory in Ghat (pop: 24683)
[11:47:13] [FLOW Q] Failed: Electronics Mali
[11:47:13] Built Electronics Factory in Al Jawf (pop: 24468)
[11:47:13] Built Electronics Factory in Hun (pop: 19166)
[11:47:13] Built Electronics Factory in Ghadamis (pop: 6719)
[11:47:12] [FLOW Q] Trying 0.24 Electronics to Mali
[11:47:12] Built Electronics Factory in Awjilah (pop: 6706)
[11:47:12] Built Electronics Factory in Qaminis (pop: 5444)
[11:47:12] Building 10 Electronics Factory...
[11:47:12] [FLOW Q] Failed: Electronics Mali
[11:47:11] [FLOW Q] Trying 0.11 Electronics to Mali
[11:47:11] [FLOW Q] Failed: Electronics Mali
[11:47:10] [FLOW Q] Trying 0.11 Electronics to Mali
[11:47:09] [FLOW Q] Failed: Electronics Mali
[11:47:08] [FLOW Q] Trying 0.11 Electronics to Mali
[11:47:08] [FLOW Q] Failed: Electronics Mali
[11:47:07] [FLOW Q] Trying 0.11 Electronics to Mali
[11:47:07] [FLOW Q] Failed: Electronics Mali
[11:47:06] [FLOW Q] Trying 0.07 Electronics to Mali
[11:47:06] [FLOW Q] Failed: Electronics Mali
[11:47:04] [FLOW Q] Trying 0.07 Electronics to Mali
[11:47:04] [FLOW Q] Failed: Electronics Mali
[11:47:03] [FLOW Q] Trying 0.07 Electronics to Mali
[11:47:03] [FLOW Q] Failed: Electronics Mali
[11:47:02] [FLOW Q] Trying 0.07 Electronics to Mali
[11:47:02] [FLOW Q] Failed: Electronics Mali
[11:47:01] [FLOW Q] Trying 0.04 Electronics to Mali
[11:47:00] [FLOW Q] Failed: Electronics Mali
[11:46:59] [FLOW Q] Trying 0.04 Electronics to Mali
[11:46:59] [FLOW Q] Failed: Electronics Mali
[11:46:58] [FLOW Q] Trying 0.04 Electronics to Mali
[11:46:58] [FLOW Q] Failed: Electronics Mali
[11:46:57] [FLOW Q] Trying 0.04 Electronics to Mali
[11:46:57] [FLOW Q] Failed: Electronics Mali
[11:46:56] [FLOW Q] Trying 0.04 Electronics to Mali
[11:46:55] Done in 78.4s | OK:50 Skip:1 Fail:0
[11:46:55] RETRY: 48
[11:46:55] [FLOW Q] Queued 0.44 Electronics to Mali (expires in 30s)
[11:46:55] [99/240] OK Electronics Mali
[11:46:55] [99/240] Electronics Mali | 0.20 @ 1.0x ($102000/u) | Flow:0.00 Rev:$260946 Cost:$20474
[11:46:55] [98/240] RETRY Electronics Czech Republic (will try 0.5x)
[11:46:53] [98/240] Electronics Czech Republic | 0.20 @ 1.0x ($102000/u) | Flow:0.00 Rev:$263977 Cost:$20474
[11:46:53] [97/240] OK Electronics Lebanon
[11:46:53] [97/240] Electronics Lebanon | 0.65 @ 1.0x ($102000/u) | Flow:0.00 Rev:$266975 Cost:$66744
[11:46:53] [96/240] RETRY Electronics Haiti (will try 0.5x)
[11:46:52] [96/240] Electronics Haiti | 0.66 @ 1.0x ($102000/u) | Flow:0.00 Rev:$267949 Cost:$66987
[11:46:52] [95/240] OK Electronics Niger
[11:46:51] [95/240] Electronics Niger | 0.66 @ 1.0x ($102000/u) | Flow:0.00 Rev:$269966 Cost:$67492
[11:46:51] [94/240] RETRY Electronics Turkmenistan (will try 0.5x)
[11:46:50] [94/240] Electronics Turkmenistan | 0.67 @ 1.0x ($102000/u) | Flow:0.00 Rev:$275319 Cost:$68830
[11:46:50] [93/240] OK Electronics Togo
[11:46:50] [93/240] Electronics Togo | 0.68 @ 1.0x ($102000/u) | Flow:0.00 Rev:$278631 Cost:$69658
[11:46:50] [92/240] RETRY Electronics New Zealand (will try 0.5x)
[11:46:49] Factory building complete: 10/10 built
[11:46:49] Built Electronics Factory in Marzuq (pop: 55740)
[11:46:49] Built Electronics Factory in Birak (pop: 45993)
[11:46:48] [92/240] Electronics New Zealand | 0.70 @ 1.0x ($102000/u) | Flow:0.00 Rev:$285103 Cost:$71276
[11:46:48] Built Electronics Factory in Shahhat (pop: 45570)
[11:46:48] [91/240] OK Electronics Paraguay
[11:46:48] Built Electronics Factory in Mizdah (pop: 26443)
[11:46:48] [91/240] Electronics Paraguay | 0.73 @ 1.0x ($102000/u) | Flow:0.00 Rev:$296379 Cost:$74095
[11:46:48] [90/240] RETRY Electronics Azerbaijan (will try 0.5x)
[11:46:48] Built Electronics Factory in Ghat (pop: 24655)
[11:46:47] Built Electronics Factory in Al Jawf (pop: 24433)
[11:46:47] Built Electronics Factory in Hun (pop: 19142)
[11:46:47] [90/240] Electronics Azerbaijan | 0.73 @ 1.0x ($102000/u) | Flow:0.00 Rev:$298999 Cost:$74750
[11:46:47] Built Electronics Factory in Ghadamis (pop: 6711)
[11:46:47] [89/240] OK Electronics Kuwait
[11:46:46] Built Electronics Factory in Awjilah (pop: 6696)
[11:46:46] [89/240] Electronics Kuwait | 0.74 @ 1.0x ($102000/u) | Flow:0.00 Rev:$302810 Cost:$75702
[11:46:46] [88/240] RETRY Electronics Mongolia (will try 0.5x)
[11:46:46] Built Electronics Factory in Qaminis (pop: 5434)
[11:46:46] Building 10 Electronics Factory...
[11:46:45] [88/240] Electronics Mongolia | 0.74 @ 1.0x ($102000/u) | Flow:0.00 Rev:$303914 Cost:$75978
[11:46:45] [87/240] OK Electronics Madagascar
[11:46:45] [87/240] Electronics Madagascar | 0.75 @ 1.0x ($102000/u) | Flow:0.00 Rev:$305785 Cost:$76446
[11:46:45] [86/240] RETRY Electronics Hungary (will try 0.5x)
[11:46:44] [86/240] Electronics Hungary | 0.76 @ 1.0x ($102000/u) | Flow:0.00 Rev:$308289 Cost:$77072
[11:46:43] [85/240] OK Electronics Uganda
[11:46:43] [85/240] Electronics Uganda | 0.76 @ 1.0x ($102000/u) | Flow:0.00 Rev:$310412 Cost:$77603
[11:46:43] [84/240] RETRY Electronics Somalia (will try 0.5x)
[11:46:42] [84/240] Electronics Somalia | 0.77 @ 1.0x ($102000/u) | Flow:0.00 Rev:$315743 Cost:$78936
[11:46:42] [83/240] OK Electronics Israel
[11:46:42] [83/240] Electronics Israel | 0.78 @ 1.0x ($102000/u) | Flow:0.00 Rev:$320038 Cost:$80010
[11:46:42] [82/240] RETRY Electronics Cuba (will try 0.5x)
[11:46:41] [82/240] Electronics Cuba | 0.82 @ 1.0x ($102000/u) | Flow:0.00 Rev:$333471 Cost:$83368
[11:46:40] [81/240] OK Electronics Belgium
[11:46:40] [81/240] Electronics Belgium | 0.82 @ 1.0x ($102000/u) | Flow:0.00 Rev:$334898 Cost:$83724
[11:46:40] [80/240] RETRY Electronics United Arab Emirates (will try 0.5x)
[11:46:39] [80/240] Electronics United Arab Emirates | 0.84 @ 1.0x ($102000/u) | Flow:0.00 Rev:$341947 Cost:$85487
[11:46:39] [79/240] OK Electronics Zambia
[11:46:39] Factory building complete: 10/10 built
[11:46:38] [79/240] Electronics Zambia | 0.87 @ 1.0x ($102000/u) | Flow:0.00 Rev:$356912 Cost:$89228
[11:46:38] [78/240] RETRY Electronics Bulgaria (will try 0.5x)
[11:46:38] Built Electronics Factory in Marzuq (pop: 55710)
[11:46:38] Built Electronics Factory in Birak (pop: 45967)
[11:46:38] Built Electronics Factory in Shahhat (pop: 45544)
[11:46:37] [78/240] Electronics Bulgaria | 0.88 @ 1.0x ($102000/u) | Flow:0.00 Rev:$360929 Cost:$90232
[11:46:37] Built Electronics Factory in Mizdah (pop: 26427)
[11:46:37] [77/240] OK Electronics Belarus
[11:46:37] Built Electronics Factory in Ghat (pop: 24641)
[11:46:37] [77/240] Electronics Belarus | 0.90 @ 1.0x ($102000/u) | Flow:0.00 Rev:$365633 Cost:$91408
[11:46:37] [76/240] RETRY Electronics Switzerland (will try 0.5x)
[11:46:37] Built Electronics Factory in Al Jawf (pop: 24419)
[11:46:36] Built Electronics Factory in Hun (pop: 19124)
[11:46:36] Built Electronics Factory in Ghadamis (pop: 6705)
[11:46:36] [76/240] Electronics Switzerland | 0.92 @ 1.0x ($102000/u) | Flow:0.00 Rev:$375389 Cost:$93847
[11:46:36] Built Electronics Factory in Awjilah (pop: 6694)
[11:46:35] [75/240] OK Electronics Mozambique
[11:46:35] Built Electronics Factory in Qaminis (pop: 5430)
[11:46:35] Building 10 Electronics Factory...
[11:46:35] [75/240] Electronics Mozambique | 0.92 @ 1.0x ($102000/u) | Flow:0.00 Rev:$376931 Cost:$94233
[11:46:35] [74/240] RETRY Electronics Guinea (will try 0.5x)
[11:46:34] [74/240] Electronics Guinea | 0.93 @ 1.0x ($102000/u) | Flow:0.00 Rev:$379378 Cost:$94844
[11:46:34] [73/240] OK Electronics Lesotho
[11:46:34] [73/240] Electronics Lesotho | 0.94 @ 1.0x ($102000/u) | Flow:0.00 Rev:$384870 Cost:$96218
[11:46:33] [72/240] OK Electronics Dominican Republic
[11:46:33] [72/240] Electronics Dominican Republic | 0.95 @ 1.0x ($102000/u) | Flow:0.00 Rev:$387200 Cost:$96800
[11:46:33] [71/240] RETRY Electronics Tunisia (will try 0.5x)
[11:46:32] [71/240] Electronics Tunisia | 0.98 @ 1.0x ($102000/u) | Flow:0.00 Rev:$400403 Cost:$100101
[11:46:32] [70/240] OK Electronics Sweden
[11:46:31] [70/240] Electronics Sweden | 0.98 @ 1.0x ($102000/u) | Flow:0.00 Rev:$401281 Cost:$100320
[11:46:31] [69/240] RETRY Electronics Austria (will try 0.5x)
[11:46:30] [69/240] Electronics Austria | 0.99 @ 1.0x ($102000/u) | Flow:0.00 Rev:$404853 Cost:$101213
[11:46:30] [68/240] OK Electronics Yemen
[11:46:30] [68/240] Electronics Yemen | 1.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$407771 Cost:$101943
[11:46:30] [67/240] RETRY Electronics Portugal (will try 0.5x)
[11:46:28] [67/240] Electronics Portugal | 1.03 @ 1.0x ($102000/u) | Flow:0.00 Rev:$420972 Cost:$105243
[11:46:28] [66/240] OK Electronics Greece
[11:46:28] [66/240] Electronics Greece | 1.08 @ 1.0x ($102000/u) | Flow:0.00 Rev:$438749 Cost:$109687
[11:46:28] [65/240] OK Electronics Singapore
[11:46:27] [65/240] Electronics Singapore | 1.10 @ 1.0x ($102000/u) | Flow:0.00 Rev:$449522 Cost:$112380
[11:46:27] [64/240] RETRY Electronics Tanzania (will try 0.5x)
[11:46:26] [64/240] Electronics Tanzania | 1.11 @ 1.0x ($102000/u) | Flow:0.00 Rev:$451698 Cost:$112924
[11:46:26] [63/240] OK Electronics Ecuador
[11:46:25] [63/240] Electronics Ecuador | 1.12 @ 1.0x ($102000/u) | Flow:0.00 Rev:$457674 Cost:$114418
[11:46:25] [62/240] RETRY Electronics Cameroon (will try 0.5x)
[11:46:24] [62/240] Electronics Cameroon | 1.12 @ 1.0x ($102000/u) | Flow:0.00 Rev:$458685 Cost:$114671
[11:46:24] [60/240] OK Electronics Cote d'Ivoire
[11:46:24] [60/240] Electronics Cote d'Ivoire | 1.18 @ 1.0x ($102000/u) | Flow:0.00 Rev:$483311 Cost:$120828
[11:46:24] [59/240] RETRY Electronics North Korea (will try 0.5x)
[11:46:23] [59/240] Electronics North Korea | 1.19 @ 1.0x ($102000/u) | Flow:0.00 Rev:$487024 Cost:$121756
[11:46:22] [58/240] OK Electronics Romania
[11:46:22] [58/240] Electronics Romania | 1.22 @ 1.0x ($102000/u) | Flow:0.00 Rev:$497988 Cost:$124497
[11:46:22] [57/240] RETRY Electronics Kenya (will try 0.5x)
[11:46:21] [57/240] Electronics Kenya | 1.38 @ 1.0x ($102000/u) | Flow:0.00 Rev:$502117 Cost:$140593
[11:46:21] [56/240] OK Electronics Ethiopia
[11:46:21] [56/240] Electronics Ethiopia | 1.38 @ 1.0x ($102000/u) | Flow:0.00 Rev:$502655 Cost:$140743
[11:46:21] [55/240] RETRY Electronics Senegal (will try 0.5x)
[11:46:20] [55/240] Electronics Senegal | 1.41 @ 1.0x ($102000/u) | Flow:0.00 Rev:$512919 Cost:$143617
[11:46:19] [54/240] OK Electronics Afghanistan
[11:46:19] [54/240] Electronics Afghanistan | 1.44 @ 1.0x ($102000/u) | Flow:0.00 Rev:$524015 Cost:$146724
[11:46:19] [53/240] RETRY Electronics Tajikistan (will try 0.5x)
[11:46:18] Factory building complete: 10/10 built
[11:46:18] [53/240] Electronics Tajikistan | 1.48 @ 1.0x ($102000/u) | Flow:0.00 Rev:$538945 Cost:$150905
[11:46:18] Built Electronics Factory in Marzuq (pop: 55650)
[11:46:18] [52/240] OK Electronics Bolivia
[11:46:17] [52/240] Electronics Bolivia | 1.49 @ 1.0x ($102000/u) | Flow:0.00 Rev:$543883 Cost:$152287
[11:46:17] [51/240] RETRY Electronics Netherlands (will try 0.5x)
[11:46:17] Built Electronics Factory in Birak (pop: 45915)
[11:46:17] Built Electronics Factory in Shahhat (pop: 45492)
[11:46:17] Built Electronics Factory in Mizdah (pop: 26405)
[11:46:16] Built Electronics Factory in Ghat (pop: 24613)
[11:46:16] [51/240] Electronics Netherlands | 1.51 @ 1.0x ($102000/u) | Flow:0.00 Rev:$550852 Cost:$154239
[11:46:16] Built Electronics Factory in Al Jawf (pop: 24398)
[11:46:16] [50/240] OK Electronics Ghana
[11:46:16] [50/240] Electronics Ghana | 1.55 @ 1.0x ($102000/u) | Flow:0.00 Rev:$564973 Cost:$158192
[11:46:16] [49/240] RETRY Electronics Hong Kong (will try 0.5x)
[11:46:16] Built Electronics Factory in Hun (pop: 19106)
[11:46:16] Built Electronics Factory in Ghadamis (pop: 6699)
[11:46:15] Built Electronics Factory in Awjilah (pop: 6686)
[11:46:15] Built Electronics Factory in Qaminis (pop: 5424)
[11:46:15] Building 10 Electronics Factory...
[11:46:15] [49/240] Electronics Hong Kong | 1.61 @ 1.0x ($102000/u) | Flow:0.00 Rev:$585565 Cost:$163958
[11:46:14] [48/240] OK Electronics Sierra Leone
[11:46:14] [48/240] Electronics Sierra Leone | 1.66 @ 1.0x ($102000/u) | Flow:0.00 Rev:$603255 Cost:$168911
[11:46:14] [47/240] RETRY Electronics Burma (will try 0.5x)
[11:46:13] [47/240] Electronics Burma | 1.68 @ 1.0x ($102000/u) | Flow:0.00 Rev:$613523 Cost:$171786
[11:46:13] [46/240] OK Electronics Uzbekistan
[11:46:13] [46/240] Electronics Uzbekistan | 1.72 @ 1.0x ($102000/u) | Flow:0.00 Rev:$627149 Cost:$175602
[11:46:13] [45/240] RETRY Electronics Syria (will try 0.5x)
[11:46:12] [45/240] Electronics Syria | 1.81 @ 1.0x ($102000/u) | Flow:0.00 Rev:$660642 Cost:$184980
[11:46:11] [44/240] OK Electronics Angola
[11:46:11] [44/240] Electronics Angola | 1.84 @ 1.0x ($102000/u) | Flow:0.00 Rev:$669425 Cost:$187439
[11:46:11] [43/240] RETRY Electronics Kazakhstan (will try 0.5x)
[11:46:10] [43/240] Electronics Kazakhstan | 1.84 @ 1.0x ($102000/u) | Flow:0.00 Rev:$669557 Cost:$187476
[11:46:10] [42/240] OK Electronics Sudan
[11:46:10] [42/240] Electronics Sudan | 1.98 @ 1.0x ($102000/u) | Flow:0.00 Rev:$719591 Cost:$201485
[11:46:10] [41/240] RETRY Electronics Poland (will try 0.5x)
[11:46:08] [41/240] Electronics Poland | 2.09 @ 1.0x ($102000/u) | Flow:0.00 Rev:$761606 Cost:$213250
[11:46:08] [40/240] OK Electronics Malaysia
[11:46:08] [40/240] Electronics Malaysia | 2.14 @ 1.0x ($102000/u) | Flow:0.00 Rev:$778268 Cost:$217915
[11:46:08] [39/240] RETRY Electronics Algeria (will try 0.5x)
[11:46:07] [39/240] Electronics Algeria | 2.18 @ 1.0x ($102000/u) | Flow:0.00 Rev:$793664 Cost:$222226
[11:46:07] [38/240] OK Electronics Thailand
[11:46:06] [38/240] Electronics Thailand | 2.40 @ 1.0x ($102000/u) | Flow:0.00 Rev:$874322 Cost:$244810
[11:46:06] [37/240] RETRY Electronics Chile (will try 0.5x)
[11:46:05] [37/240] Electronics Chile | 2.52 @ 1.0x ($102000/u) | Flow:0.00 Rev:$918884 Cost:$257288
[11:46:05] [36/240] OK Electronics Iraq
[11:46:05] [36/240] Electronics Iraq | 2.61 @ 1.0x ($102000/u) | Flow:0.00 Rev:$950268 Cost:$266075
[11:46:05] [35/240] RETRY Electronics Australia (will try 0.5x)
[11:46:04] [35/240] Electronics Australia | 2.63 @ 1.0x ($102000/u) | Flow:0.00 Rev:$957421 Cost:$268078
[11:46:03] [34/240] OK Electronics Venezuela
[11:46:03] [34/240] Electronics Venezuela | 2.74 @ 1.0x ($102000/u) | Flow:0.00 Rev:$996568 Cost:$279039
[11:46:03] [33/240] RETRY Electronics Morocco (will try 0.5x)
[11:46:02] [33/240] Electronics Morocco | 3.18 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1014934 Cost:$324779
[11:46:02] [32/240] OK Electronics Zimbabwe
[11:46:02] [32/240] Electronics Zimbabwe | 3.19 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1015231 Cost:$324874
[11:46:02] [31/240] RETRY Electronics Peru (will try 0.5x)
[11:46:01] [31/240] Electronics Peru | 3.47 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1106567 Cost:$354101
[11:46:00] [30/240] OK Electronics Canada
[11:46:00] [30/240] Electronics Canada | 3.67 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1169429 Cost:$374217
[11:46:00] [29/240] RETRY Electronics Taiwan (will try 0.5x)
[11:45:59] [29/240] Electronics Taiwan | 3.73 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1188715 Cost:$380389
[11:45:59] [28/240] OK Electronics Democratic Republic of the Congo
[11:45:58] [28/240] Electronics Democratic Republic of the Congo | 3.94 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1256192 Cost:$401981
[11:45:58] [27/240] RETRY Electronics Colombia (will try 0.5x)
[11:45:57] [27/240] Electronics Colombia | 4.53 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1444693 Cost:$462302
[11:45:57] [26/240] OK Electronics Bangladesh
[11:45:57] [26/240] Electronics Bangladesh | 4.59 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1463087 Cost:$468188
[11:45:57] [25/240] RETRY Electronics Ukraine (will try 0.5x)
[11:45:56] [25/240] Electronics Ukraine | 4.69 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1495360 Cost:$478515
[11:45:55] [24/240] OK Electronics Philippines
[11:45:55] [24/240] Electronics Philippines | 4.90 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1561439 Cost:$499660
[11:45:55] [23/240] RETRY Electronics Vietnam (will try 0.5x)
[11:45:54] [23/240] Electronics Vietnam | 4.94 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1574650 Cost:$503888
[11:45:54] [22/240] OK Electronics Argentina
[11:45:54] [22/240] Electronics Argentina | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1633948 Cost:$510000
[11:45:54] [21/240] RETRY Electronics South Korea (will try 0.5x)
[11:45:53] [21/240] Electronics South Korea | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1668992 Cost:$510000
[11:45:52] [20/240] OK Electronics Italy
[11:45:52] [20/240] Electronics Italy | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1713345 Cost:$510000
[11:45:52] [19/240] RETRY Electronics Egypt (will try 0.5x)
[11:45:51] [19/240] Electronics Egypt | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1789087 Cost:$510000
[11:45:51] [18/240] OK Electronics Saudi Arabia
[11:45:50] [18/240] Electronics Saudi Arabia | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1790156 Cost:$510000
[11:45:50] [17/240] RETRY Electronics Spain (will try 0.5x)
[11:45:49] [17/240] Electronics Spain | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1817138 Cost:$510000
[11:45:49] [16/240] OK Electronics Nigeria
[11:45:49] [16/240] Electronics Nigeria | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1836892 Cost:$510000
[11:45:49] [15/240] RETRY Electronics Iran (will try 0.5x)
[11:45:48] [15/240] Electronics Iran | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$1950814 Cost:$510000
[11:45:48] [14/240] OK Electronics Turkey
[11:45:47] [14/240] Electronics Turkey | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2018430 Cost:$510000
[11:45:47] [13/240] RETRY Electronics Pakistan (will try 0.5x)
[11:45:46] [13/240] Electronics Pakistan | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2070166 Cost:$510000
[11:45:46] [12/240] OK Electronics France
[11:45:46] [12/240] Electronics France | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2106207 Cost:$510000
[11:45:46] [11/240] RETRY Electronics South Africa (will try 0.5x)
[11:45:45] [11/240] Electronics South Africa | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2107564 Cost:$510000
[11:45:44] [10/240] OK Electronics United Kingdom
[11:45:44] [10/240] Electronics United Kingdom | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2442289 Cost:$510000
[11:45:44] [9/240] RETRY Electronics Germany (will try 0.5x)
[11:45:43] [9/240] Electronics Germany | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2451140 Cost:$510000
[11:45:43] [8/240] OK Electronics Indonesia
[11:45:43] [8/240] Electronics Indonesia | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$2547277 Cost:$510000
[11:45:43] [7/240] RETRY Electronics Mexico (will try 0.5x)
[11:45:41] [7/240] Electronics Mexico | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$3435867 Cost:$510000
[11:45:41] [6/240] OK Electronics Russia
[11:45:41] [6/240] Electronics Russia | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$3444650 Cost:$510000
[11:45:41] [5/240] RETRY Electronics Japan (will try 0.5x)
[11:45:40] [5/240] Electronics Japan | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$10551084 Cost:$510000
[11:45:40] [4/240] OK Electronics Brazil
[11:45:39] [4/240] Electronics Brazil | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$11177770 Cost:$510000
[11:45:39] [3/240] RETRY Electronics China (will try 0.5x)
[11:45:38] [3/240] Electronics China | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$16398440 Cost:$510000
[11:45:38] [2/240] OK Electronics India
[11:45:38] [2/240] Electronics India | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$18406075 Cost:$510000
[11:45:38] [1/240] RETRY Electronics United States (will try 0.5x)
[11:45:37] [1/240] Electronics United States | 5.00 @ 1.0x ($102000/u) | Flow:0.00 Rev:$23452749 Cost:$510000
[11:45:37] Trade cycle started
[11:45:37] TRIGGERED: Electronics 116.8
[11:45:26] [AutoBuy] Copper: Bought 11.00
[11:45:26] [AutoBuy] OK 11.00 Copper from United States
[11:45:25] [AutoBuy] Buying 11.00 Copper from United States @ 1.0x (seller flow: 18.22)
[11:45:25] [AutoBuy] Copper need: 11.00 (factory: 10.00, flow: 0.00, target: 1.00)
[11:45:14] [AutoBuy] Gold: Bought 11.00
[11:45:14] [AutoBuy] OK 11.00 Gold from Zimbabwe
[11:45:14] [AutoBuy] Buying 11.00 Gold from Zimbabwe @ 1.0x (seller flow: 26.67)
[11:45:14] [AutoBuy] Gold need: 11.00 (factory: 10.00, flow: 0.00, target: 1.00)
[11:43:59] Factory building complete: 10/1 built
[11:43:58] Built Electronics Factory in Marzuq (pop: 55266)
[11:43:58] Built Electronics Factory in Birak (pop: 45603)
[11:43:58] Built Electronics Factory in Shahhat (pop: 45169)
[11:43:57] Built Electronics Factory in Mizdah (pop: 26211)
[11:43:57] Built Electronics Factory in Ghat (pop: 24438)
[11:43:57] Built Electronics Factory in Al Jawf (pop: 24223)
[11:43:56] Built Electronics Factory in Hun (pop: 18956)
[11:43:56] Built Electronics Factory in Ghadamis (pop: 6649)
[11:43:56] Built Electronics Factory in Awjilah (pop: 6636)
[11:43:55] Built Electronics Factory in Qaminis (pop: 5374)
[11:43:55] Building 10 Electronics Factory...
[11:43:25] War Monitor: ON
[11:43:25] Auto-Buy: ON
[11:43:25] Auto-Sell: ON
[11:43:24] Country: Libya
[11:43:24] Trade Hub v2.1.1 loaded
