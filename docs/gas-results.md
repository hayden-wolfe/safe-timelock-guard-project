# Gas Results — TimelockGuard

Two measurement sources are combined here:

1. **Hardhat local** — `pnpm hardhat run scripts/benchmark.ts` (non-L2 Safe, 1-of-1 owner).
   Apples-to-apples overhead comparison against the Week 1 baseline.
2. **Sepolia testnet** — actual receipts from the lifecycle demo
   (`pnpm hardhat run scripts/demo-sepolia.ts --network sepolia`).
   Uses Safe L2 v1.4.1 which emits additional indexing events per `execTransaction`.

Compiler: solc 0.8.27, optimizer 200 runs, viaIR.

---

## Deployment

| Contract      | Gas (Hardhat) | Gas (Sepolia, CREATE2) |
|---------------|---------------|------------------------|
| TimelockGuard | 807,546       | 809,198                |

The small Sepolia premium reflects a cold-state deployment on a live network.
Deployment uses the Safe Singleton Factory (CREATE2) for a deterministic address.

---

## User-facing operations

### Hardhat local (non-L2 Safe singleton, 1-of-1 owner)

Run with `pnpm hardhat run scripts/benchmark.ts`.

| Operation                                       | Gas used |
|-------------------------------------------------|----------|
| `setUp(delay)` via `Safe.execTransaction`       | 93,109   |
| `setGuard(guard)` via `Safe.execTransaction`    | 74,669   |
| `scheduleTransaction` (ETH transfer, 1-of-1)   | 76,734   |
| `execTransaction` — no guard (ETH transfer)    | 55,766   |
| `execTransaction` — with TimelockGuard         | 69,733   |
| **TimelockGuard overhead per execTransaction** | **13,967** |

Gas reporter values (aggregated over all 45 tests, `pnpm test`):

| Method               | Min gas | Max gas | Avg gas |
|----------------------|---------|---------|---------|
| `scheduleTransaction` | 76,674  | 78,207  | 76,865  |
| `cancel`             | 27,014  | 27,026  | 27,023  |
| `setUp`              | 45,355  | 45,367  | 45,358  |

### Sepolia testnet (Safe L2 v1.4.1, 1-of-1 owner)

Receipts fetched from the lifecycle demo run. Safe L2 emits a
`SafeMultiSigTransaction` event on every `execTransaction`, adding ~8–9 k gas
relative to the non-L2 local baseline.

| Step | Operation | Gas used |
|------|-----------|----------|
| 3 | `setUp(60)` via `Safe.execTransaction` | 101,697 |
| 4 | `setGuard(guard)` via `Safe.execTransaction` | 83,280 |
| 5 | `scheduleTransaction` (ETH transfer) | 70,537 |
| 6 | `execTransaction` (timelocked ETH, with guard) | 78,348 |

---

## execTransaction overhead analysis

| Metric | Gas |
|--------|-----|
| Baseline: 1-owner Safe, ETH transfer, no guard (Hardhat) | 55,766 |
| Baseline: 1-owner Safe, ETH transfer, generic guard (Week 1 benchmark) | 63,975 |
| TimelockGuard: 1-owner Safe, ETH transfer (Hardhat) | 69,733 |
| **TimelockGuard overhead vs no guard** | **+13,967** |
| **TimelockGuard overhead vs generic example guard** | **+5,758** |

The guard's overhead breaks down as:

| Phase | Operation | Est. gas |
|-------|-----------|----------|
| `checkTransaction` | Cold SLOAD (`_schedules[safe][txHash]`) + external call to `getTransactionHash` | ~8,000 |
| `checkAfterExecution` | SSTORE delete (refund applies) + `TransactionExecuted` event | ~6,000 |
| **Total** | | **~14,000** |

This aligns with the measured 13,967 gas. The overhead is roughly 2.4× the
~5,833 gas cost of a simple example guard (which does only comparison logic with
no storage writes).

---

## Context: comparison with Week 1 baseline

The Week 1 upstream benchmark (`npm run benchmark` in `safe-smart-account/`)
measured a 1-owner Safe ETH transfer at **58,142 gas** (no guard). The small
difference vs this benchmark's 55,766 gas is because the upstream benchmark
deploys the Safe with a `CompatibilityFallbackHandler`, while the local
benchmark uses no fallback handler. Both are valid 1-of-1 configurations.

---

## Key takeaways for the report

- **`scheduleTransaction`**: ~77 k gas — a one-time cost per guarded transaction.
  This is ~1.4× a basic EOA ETH transfer (21 k gas), roughly equivalent to a
  simple ERC-20 transfer.
- **`execTransaction` overhead**: ~14 k gas with TimelockGuard vs no guard.
  This is the permanent per-execution cost once a Safe adopts the guard.
- **`cancel`**: ~27 k gas — cheap enough to be exercised freely by monitoring
  infrastructure if a suspicious transaction is scheduled.
- **Deployment**: ~808 k gas (one-time, shared across all Safes as a singleton).
- The overhead is dominated by the cold SLOAD in `checkTransaction` and the
  SSTORE delete in `checkAfterExecution`. Both are unavoidable for any
  guard that uses on-chain storage to enforce a delay.
