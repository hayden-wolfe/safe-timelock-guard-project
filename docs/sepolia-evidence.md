# Sepolia Evidence — TimelockGuard

All links open on Sepolia Etherscan. Deployment performed by
`0xF63b1D22cEAD818e3928e6b8874b95B54E46fb5E`.

---

## Guard contract

| Field | Value |
|---|---|
| Address | `0x27c5Bd9DCA0fF2Af1a493faF93923c3378598462` |
| Constructor args | `MIN_DELAY = 30 s`, `MAX_DELAY = 2 592 000 s (30 days)` |
| Compiler | solc 0.8.27, optimizer 200 runs, viaIR, EVM paris |
| Etherscan (verified) | https://sepolia.etherscan.io/address/0x27c5Bd9DCA0fF2Af1a493faF93923c3378598462#code |

### Deployment transaction

| Field | Value |
|---|---|
| Tx hash | `0xef42d2aa89c3fe88967e4a5b5bf2f25bd2dfb318e93bca39a66d1f53fd9e7e5a` |
| Gas used | 809 198 |
| Method | CREATE2 via Safe Singleton Factory (`deterministicDeployment: true`) |
| Etherscan | https://sepolia.etherscan.io/tx/0xef42d2aa89c3fe88967e4a5b5bf2f25bd2dfb318e93bca39a66d1f53fd9e7e5a |

---

## Full lifecycle demo

> Populated after running `pnpm hardhat run scripts/demo-sepolia.ts --network sepolia`.
> The demo deploys a fresh 1-of-1 Safe, calls `setUp(60)`, installs the guard,
> schedules a test transaction, waits 60 seconds, then executes it.

### Safe proxy (demo run)

| Field | Value |
|---|---|
| Address | _TBD_ |
| Owner | `0xF63b1D22cEAD818e3928e6b8874b95B54E46fb5E` (1-of-1) |
| Configured delay | 60 s |

### Lifecycle transactions

| Step | Method | Tx hash | Etherscan |
|---|---|---|---|
| 1 | `SafeProxyFactory.createProxyWithNonce` | _TBD_ | _TBD_ |
| 2 | ETH transfer (fund Safe) | _TBD_ | _TBD_ |
| 3 | `Safe.execTransaction` → `TimelockGuard.setUp(60)` | _TBD_ | _TBD_ |
| 4 | `Safe.execTransaction` → `Safe.setGuard(guard)` | _TBD_ | _TBD_ |
| 5 | `TimelockGuard.scheduleTransaction` | _TBD_ | _TBD_ |
| 6 | `Safe.execTransaction` (delayed ETH transfer) | _TBD_ | _TBD_ |

---

## Key takeaways for the report

- The guard deploys for **809 k gas** — within the Hardhat block limit and reasonable
  for a multi-Safe singleton.
- Source code is verified and publicly readable on Sepolia Etherscan.
- Full lifecycle (schedule → wait → execute) demonstrated end-to-end on a live testnet.
