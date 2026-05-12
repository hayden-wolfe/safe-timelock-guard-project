# Gas Baseline — safe-smart-account v1.5.0 (no TimelockGuard)

Captured Week 1 via `npm run benchmark` in `safe-smart-account/` (Hardhat local network).
These numbers are the "before" baseline for the Week 3 comparison.

Command: `npm run benchmark`
Commit: `d7de455` (upstream/main at time of measurement)

---

## Results

### Safe creation

| Configuration | Gas |
|---|---|
| 1-owner Safe + fallback handler | 166,375 |
| 2-owner Safe + fallback handler | 189,886 |
| 3-owner Safe + fallback handler | 213,385 |
| 5-owner Safe + fallback handler | 260,407 |

### Proxy creation

| Configuration | Gas |
|---|---|
| EOA (baseline) | 105,303 |
| 1-owner Safe | 135,923 |
| 1-owner Safe **with guard** | 141,828 |
| 2-of-2 Safe | 142,975 |
| 3-of-3 Safe | 150,075 |
| 3-of-5 Safe | 150,075 |

### ERC-20 transfer (`execTransaction`)

| Configuration | Gas | Guard overhead vs no-guard |
|---|---|---|
| EOA (baseline) | 51,800 | — |
| 1-owner Safe, no guard | 82,396 | — |
| 1-owner Safe, **with guard** | 88,265 | +5,869 |
| 2-of-2 Safe | 89,471 | — |
| 3-of-3 Safe | 96,548 | — |
| 3-of-5 Safe | 96,524 | — |

### Ether transfer (`execTransaction`)

| Configuration | Gas | Guard overhead vs no-guard |
|---|---|---|
| EOA (baseline) | 21,000 | — |
| 1-owner Safe, no guard | 58,142 | — |
| 1-owner Safe, **with guard** | 63,975 | +5,833 |
| 2-of-2 Safe | 65,193 | — |
| 3-of-3 Safe | 72,293 | — |
| 3-of-5 Safe | 72,281 | — |

### ERC-20 MultiSend (multiple transfers)

| Configuration | Gas | Guard overhead vs no-guard |
|---|---|---|
| 1-owner Safe, no guard | 92,595 | — |
| 1-owner Safe, **with guard** | 98,663 | +6,068 |
| 2-of-2 Safe | 99,674 | — |
| 3-of-3 Safe | 106,740 | — |

### ERC-1155 transfer

| Configuration | Gas | Guard overhead vs no-guard |
|---|---|---|
| EOA | 57,234 | — |
| 1-owner Safe, no guard | 87,903 | — |
| 1-owner Safe, **with guard** | 93,833 | +5,930 |
| 2-of-2 Safe | 94,978 | — |
| 3-of-3 Safe | 102,045 | — |

---

## Key takeaway for Week 3

The existing Safe example guard (whichever one is used in the benchmark) adds approximately **5,800–6,100 gas** to `execTransaction` (checkTransaction + checkAfterExecution combined).

The TimelockGuard's `checkTransaction` will add on top of this baseline:
- One cold SLOAD for `_schedules[safe][txHash]` (≈ 2,100 gas first access)
- One timestamp comparison (negligible)
- A warm SLOAD for `_delays[safe]` if we check it there (≈ 100 gas)

Estimated TimelockGuard overhead vs no-guard: **roughly 8,000–10,000 gas per execTransaction**.
`checkAfterExecution` also does one SSTORE (delete = setting to 0, refund applies).
`scheduleTransaction` will cost **roughly 60,000–80,000 gas** (one SSTORE + signature verification).

These are rough estimates; Week 3 measurements will be exact.
