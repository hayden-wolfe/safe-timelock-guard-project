# Gas Results — TimelockGuard

Captured during the Week 2 test run (`pnpm test` inside
`safe-modules/modules/timelock-guard/`).
Hardhat automatically prints a gas table at the end of every test run because
`hardhat.config.ts` contains `gasReporter: { enabled: true }`.
To reproduce: run `pnpm test` in that directory and read the bottom table.

Compiler: solc 0.8.27, optimizer enabled, 200 runs, viaIR.
Network: Hardhat local (no gas price).

---

## Method costs

| Contract       | Method                | Min gas | Max gas | Avg gas |
|----------------|-----------------------|---------|---------|---------|
| TimelockGuard  | `scheduleTransaction` | 76,674  | 78,207  | 76,865  |
| TimelockGuard  | `cancel`              | 27,014  | 27,026  | 27,023  |
| TimelockGuard  | `setUp`               | 45,355  | 45,367  | 45,358  |

`updateDelay` and `setCanceller` were not called enough times to appear in the
reporter table, but each performs a single SSTORE (warm slot after setUp) and
emits one event — expected cost: ~25,000–30,000 gas.

## Deployment cost

| Contract      | Gas     |
|---------------|---------|
| TimelockGuard | 807,545 |

## execTransaction overhead (from Week 1 baseline)

These numbers come from the existing Safe benchmark (`npm run benchmark` in
`safe-smart-account/`, recorded in `gas-baseline.md`).

| Configuration                          | execTransaction gas | Guard overhead |
|----------------------------------------|---------------------|----------------|
| 1-owner Safe, ETH transfer, no guard   | 58,142              | —              |
| 1-owner Safe, ETH transfer, with guard | 63,975              | +5,833         |

The existing example guard (used in the baseline benchmark) adds ~5,833 gas per
execTransaction. The TimelockGuard does more work in `checkTransaction`
(two external calls to `ISafe.nonce()` and `ISafe.getTransactionHash()`, plus
one cold SLOAD and a timestamp compare) and more in `checkAfterExecution`
(conditional SSTORE delete + event). Estimated TimelockGuard overhead:

| Phase                     | Est. gas |
|---------------------------|----------|
| `checkTransaction`        | ~5,000   |
| `checkAfterExecution`     | ~3,000   |
| **Total per execTransaction** | **~8,000** |

Exact numbers will be measured in the Week 3 Sepolia benchmark
(`benchmark/Safe.TimelockGuard.spec.ts`).

---

## Key takeaways for the report

- `scheduleTransaction` costs ~77k gas — roughly 1.3× a simple ETH transfer
  from an EOA. This is a one-time cost per transaction.
- `execTransaction` overhead with TimelockGuard installed is estimated at
  ~8k gas vs the baseline of no guard. This aligns with the design goal of
  keeping the guard cheap to operate once a tx is scheduled.
- The guard contract itself deploys for ~808k gas (~0.8% of the Hardhat
  block limit), which is reasonable for a multi-Safe singleton.
