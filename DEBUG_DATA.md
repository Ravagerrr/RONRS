# Trade Debug Data Collection

This document explains the debug data format used to analyze the game's trade acceptance algorithm.

## Debug Log Format

Every trade attempt prints a compact debug line to the console:

```
DBG|Country|Res|Amt|Price|Cost|Rev|Cost%|Tax|Bal|Pop|Rank|Flow
```

### Fields

| Field | Description | Example |
|-------|-------------|---------|
| `Country` | Target country name | `Brazil` |
| `Res` | Resource (first 4 chars) | `Cons` (Consumer Goods), `Elec` (Electronics) |
| `Amt` | Amount being traded | `60.0` |
| `Price` | Price tier multiplier | `1.0x`, `0.5x`, `0.1x` |
| `Cost` | Total cost (Amt × Price × BasePrice) | `$4944000` |
| `Rev` | Country's total revenue | `$12406987` |
| `Cost%` | Cost as percentage of revenue | `39.8%` |
| `Tax` | Revenue from Tax attribute | `$500000` |
| `Bal` | Country's balance | `$50000000` |
| `Pop` | Country's population | `215000000` |
| `Rank` | Country's ranking | `8` |
| `Flow` | Resource flow (negative = consuming) | `-79.0` |

### Result Line

After each trade attempt:
```
DBG|Country|Res|OK    <- Trade accepted
DBG|Country|Res|FAIL  <- Trade rejected
```

## Data Sources

All data comes from workspace paths:

| Field | Path |
|-------|------|
| Revenue | `workspace.CountryData.[Country].Economy.Revenue:GetAttribute("Total")` |
| Tax | `workspace.CountryData.[Country].Economy.Revenue:GetAttribute("Tax")` |
| Balance | `workspace.CountryData.[Country].Economy.Balance.Value` |
| Population | `workspace.CountryData.[Country].Population.Value` |
| Ranking | `workspace.CountryData.[Country].Ranking.Value` |
| Flow | `workspace.CountryData.[Country].Resources.[Resource].Flow.Value` |

## Goal

Collect this data to determine the algorithm that decides trade acceptance:
- Is it purely `Cost% < X%`?
- Does Population/Ranking affect acceptance?
- Does Tax revenue matter?
- Does Balance need to cover the cost?
- Is there a different formula?

## Current Hypothesis

Based on Brazil data: `$12.4M revenue, accepted 60 units = $4.9M = 39.8%`

Countries appear to accept trades up to ~40% of their revenue, regardless of size.

## How to Analyze

1. Run the script and collect debug output
2. Filter for `DBG|` lines
3. Compare OK vs FAIL trades
4. Look for patterns in Cost%, Tax, Balance, Population, Ranking

Example grep:
```
# All trade attempts
grep "DBG|" output.log

# Only successful trades
grep "DBG|.*|OK" output.log

# Only failed trades
grep "DBG|.*|FAIL" output.log
```
