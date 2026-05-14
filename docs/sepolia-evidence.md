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
| Address | `0x4d5C46555a4DB2F47246736b6Ef8B5C362fee738` |
| Owner | `0xF63b1D22cEAD818e3928e6b8874b95B54E46fb5E` (1-of-1) |
| Configured delay | 60 s |

### Lifecycle transactions

| Step | Method | Tx hash | Etherscan |
|---|---|---|---|
| 1 | `SafeProxyFactory.createProxyWithNonce` | `0xaa4de40e9daf5962df8f81167782f1569484048a636f1d85aeddc0269c23559b` | https://sepolia.etherscan.io/tx/0xaa4de40e9daf5962df8f81167782f1569484048a636f1d85aeddc0269c23559b |
| 2 | ETH transfer (fund Safe) | `0x7d1c508add35b149f8d02465ac017060892df9e07992ccf3f8278b1b1cec5ad4` | https://sepolia.etherscan.io/tx/0x7d1c508add35b149f8d02465ac017060892df9e07992ccf3f8278b1b1cec5ad4 |
| 3 | `Safe.execTransaction` → `TimelockGuard.setUp(60)` | `0xd28dc657c7fd82f0c659e7fa4db048f6345fe9bb7df85def2a4b06ec072750b2` | https://sepolia.etherscan.io/tx/0xd28dc657c7fd82f0c659e7fa4db048f6345fe9bb7df85def2a4b06ec072750b2 |
| 4 | `Safe.execTransaction` → `Safe.setGuard(guard)` | `0x13a4decafa51b0213b22c19101dceda0d29b3c2d1292956cf3b93c825929172f` | https://sepolia.etherscan.io/tx/0x13a4decafa51b0213b22c19101dceda0d29b3c2d1292956cf3b93c825929172f |
| 5 | `TimelockGuard.scheduleTransaction` | `0x98c15aeb17851e77de414ec5e5d7f0e2752606b3bf9db619fd1eacb97cf3195b` | https://sepolia.etherscan.io/tx/0x98c15aeb17851e77de414ec5e5d7f0e2752606b3bf9db619fd1eacb97cf3195b |
| 6 | `Safe.execTransaction` (delayed ETH transfer) | `0x3010cf078a90efeaa7230d97bed22f94c8b2e7f5a7d47f411338427b57e14cb9` | https://sepolia.etherscan.io/tx/0x3010cf078a90efeaa7230d97bed22f94c8b2e7f5a7d47f411338427b57e14cb9 |

---

## Key takeaways for the report

- The guard deploys for **809 k gas** — within the Hardhat block limit and reasonable
  for a multi-Safe singleton.
- Source code is verified and publicly readable on Sepolia Etherscan.
- Full lifecycle (schedule → wait → execute) demonstrated end-to-end on a live testnet.
