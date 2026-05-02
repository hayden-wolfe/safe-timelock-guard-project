# Timelock Guard for Safe Smart Accounts

**Blockchains & Cryptocurrencies** Spring 2026

**Hayden Wolfe**.

## What this is

An implementation of a Safe `ITransactionGuard` that adds a configurable delay between when a multisig transaction is approved and when it can be executed — addressing [safe-fndn/safe-smart-account#1065](https://github.com/safe-fndn/safe-smart-account/issues/1065).

The guard is intended to be upstreamed as a new example contract in `safe-smart-account/contracts/examples/guards/`.

## Repo layout

```
timelock-guard-project/
├── README.md                  ← you are here
├── docs/
│   ├── DESIGN.md              ← contract design (storage, API, lifecycle, edge cases)
│   └── WALKTHROUGH.md         ← week-by-week project plan
├── contracts/                 ← (mirror of the contract pushed to the safe-smart-account fork)
├── test/                      ← (mirror of the tests pushed to the safe-smart-account fork)
└── report/                    ← gas results, Sepolia evidence, final report drafts
```

The actual contract development happens on a fork of `safe-fndn/safe-smart-account`; this repo holds the project deliverables (design docs, report, demo video link, evidence).

## Status

- [x] Week 1: design + dev environment
- [ ] Week 2: implementation + tests
- [ ] Week 3: Sepolia deploy, gas benchmarks, demo video, draft PR

## Links

- Upstream issue: https://github.com/safe-fndn/safe-smart-account/issues/1065
- Upstream repo: https://github.com/safe-fndn/safe-smart-account
- Fork branch (contract lives here): _to be added_
- Draft PR: _to be added_
- Demo video: _to be added_
