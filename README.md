# Timelock Guard for Safe Smart Accounts

**Blockchains & Cryptocurrencies** Spring 2026

**Hayden Wolfe**.

## What this is

An implementation of a Safe `ITransactionGuard` that adds a configurable delay between when a multisig transaction is approved and when it can be executed — addressing [safe-fndn/safe-smart-account#1065](https://github.com/safe-fndn/safe-smart-account/issues/1065).

The guard is being contributed as a new module to [`safe-fndn/safe-modules`](https://github.com/safe-fndn/safe-modules) — the repository that Safe maintainers directed this type of extension toward.

## Repo layout

```
timelock-guard-project/          ← this repo (project deliverables)
├── README.md                    ← you are here
├── docs/
│   ├── DESIGN.md                ← contract design (storage, API, lifecycle, edge cases)
│   └── WALKTHROUGH.md           ← week-by-week project plan
├── contracts/                   ← design-reference copy of TimelockGuard.sol (non-compiling)
├── test/                        ← (scratch notes; real tests live in the safe-modules fork)
└── report/                      ← gas results, Sepolia evidence, final report drafts

safe-modules/ (fork)             ← separate local clone, separate GitHub repo
└── modules/timelock-guard/      ← real contract + tests + deploy tasks (PR target)
    ├── contracts/TimelockGuard.sol
    ├── test/
    └── tasks/
```

The actual contract development happens on a fork of `safe-fndn/safe-modules`; this repo holds the project deliverables (design docs, report, demo video link, evidence).

## Status

- [x] Week 1: design + dev environment
- [ ] Week 2: implementation + tests
- [ ] Week 3: Sepolia deploy, gas benchmarks, demo video, draft PR

## Links

- Upstream issue: https://github.com/safe-fndn/safe-smart-account/issues/1065
- PR target repo: https://github.com/safe-fndn/safe-modules
- Fork branch (contract lives here): https://github.com/hayden-wolfe/safe-modules/tree/feat/timelock-guard
- Draft PR: _to be added (Week 3)_
- Demo video: _to be added (Week 3)_
