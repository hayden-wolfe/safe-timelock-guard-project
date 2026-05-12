# Project Walkthrough — Timelock Guard for Safe Smart Accounts

> A concrete, day-by-day plan to deliver the proposal in three weeks.
> Cross-references the rubric so nothing scoring points falls off the radar.

---

## 0. Rubric scoreboard (where points come from)

| Section | Pts | Where it's earned in this plan |
|---|---|---|
| 1. Technical Implementation & Contribution Quality | 25 | Week 2 implementation + tests |
| 2. Engagement with Open Source Project | 15 | Issue comment in Week 1, draft PR in Week 3 |
| 3. Evaluation & Validation | 15 | Tests + gas benchmarks + Sepolia deploy in Weeks 2–3 |
| 4. Final Report | 15 | Drafted across all weeks, finalized Week 3 |
| 5. GitHub Activity & Repo Organization | 10 | **Frequent commits across all 3 weeks** + clean README |
| 6. Team Collaboration & Contribution | 5 | Solo: write a clear scope/effort statement in the report |
| 7. Self-Recorded Video | 5 | Recorded Week 3 |
| **Total** | **90** | |

**The single biggest mistake to avoid:** dumping all commits at the end. Commit *something* at least every couple of days, even if it's docs or design notes. The "progressive work" criterion (6 pts) is binary in practice.

---

## Week 1 — Understand & design (current week)

**Outcome:** A finalized design document, a working dev environment, and the first comment posted on Issue #1065 to flag intent.

### Day 1 — Setup ✅ (largely done by this walkthrough)

- [x] Clone `safe-fndn/safe-smart-account` locally.
- [x] Read Issue #1065 and the OpenZeppelin `TimelockController` for reference.
- [x] Read `Safe.sol::execTransaction` flow and `ITransactionGuard` interface.
- [x] Read existing example guards (`OnlyOwnersGuard`, `DelegateCallTransactionGuard`, `BaseGuard`).
- [x] `npm install` and run a single guard test as a smoke test.
- [x] Draft `DESIGN.md`.
- [x] **Create GitHub repo** (`hayden-wolfe/timelock-guard`) for the project deliverables. This is the URL that goes at the top of the final report.
- [x] **Fork** `safe-fndn/safe-smart-account` on GitHub. Your contract changes will live on a branch in this fork.

### Day 2–3 — Engage upstream

- [x] Post a brief comment on [Issue #1065](https://github.com/safe-fndn/safe-smart-account/issues/1065) — something like:
  > "Hi — I'm planning to take a stab at this as part of a university course project. My current sketch: a `BaseTransactionGuard` with a separate `scheduleTransaction(...)` entry-point (since reverting in `checkTransaction` would roll back any state the guard wrote). Would maintainers be open to a PR along these lines? Happy to align on API."
- This earns "Evidence of real interaction with the codebase" (rubric 2.3, up to 5 pts) even if maintainers don't respond before the deadline.

### Day 4–5 — Lock in the design ✅

- [x] Read the current `DESIGN.md`.
- [x] Finalized design decisions (see `DESIGN.md §5`):
  - `MIN_DELAY = 30s` for Sepolia/tests, `MAX_DELAY = 30 days` — documented in §5.1
  - No `IModuleGuard` support — out of scope for v1 (§5.2)
  - Any authorized canceller may cancel any scheduled tx (§5.3)
  - Hash-only storage (`uint256 readyAt`), not full tx data (§5.4)
  - On-chain canceller ACL, not signature-based cancellation (§5.5)
  - `setUp` reverts if already configured; use `updateDelay` to change (§5.6)
  - Schedule entry preserved on failed execution (§5.7)
- [x] Added Optimism TimelockGuard comparison (see `DESIGN.md §6`)
- [x] Contract skeleton committed to `hayden-wolfe/safe-modules` feat/timelock-guard

### Day 6–7 — Buffer + first benchmark ✅

- [x] Ran `npm run benchmark` on safe-smart-account v1.5.0. Saved to `report/gas-baseline.md`.
  - Key baseline: 1-owner Safe ETH transfer = **58,142 gas** (no guard); with guard = **63,975 gas** (+5,833 overhead)
  - Estimated TimelockGuard overhead: **~8,000–10,000 gas** per `execTransaction`; `scheduleTransaction` ~60,000–80,000 gas
- [x] Project README already complete from Day 1.

**Week 1 commit goal:** at least one commit per day in your project repo, even if small.

---

## Week 2 — Implement & test

**Outcome:** A complete `TimelockGuard.sol` with full unit + integration tests passing locally.

### Day 8–9 — Implement the contract

Following `DESIGN.md`:

1. Create `safe-smart-account/contracts/examples/guards/TimelockGuard.sol` on your fork branch.
2. Copy the structure of `OnlyOwnersGuard.sol` for stylistic consistency (SPDX, pragma, imports, `fallback()` pattern).
3. Implement in this order to keep each step testable:
   a. Storage + immutables + constructor (`MIN_DELAY`, `MAX_DELAY`).
   b. Configuration functions (`setUp`, `updateDelay`, `setCanceller`) with `msg.sender == safe` checks.
   c. `scheduleTransaction` — the trickiest piece. Use `ISafe(safe).getTransactionHash(...)` and `ISafe(safe).checkSignatures(address(this), txHash, signatures)`.
   d. `cancel`.
   e. `checkTransaction` and `checkAfterExecution`.
   f. `supportsInterface` (just delegate to `BaseTransactionGuard`).
   g. View functions.

Run `npm run lint:sol` and `npm run fmt:sol` before each commit — the upstream uses solhint + prettier and PRs get auto-rejected on lint failures.

### Day 10–12 — Tests

1. Create `safe-smart-account/test/guards/TimelockGuard.spec.ts`. Use `test/guards/DelegateCallTransactionGuard.spec.ts` as a template — it already shows the `getSafe`, `executeContractCallWithSigners`, fixture pattern you need.
2. Cover every bullet in §4.1 and §4.2 of `DESIGN.md`.
3. Use `time.increase(delay)` from `@nomicfoundation/hardhat-network-helpers` to fast-forward past the delay in tests.
4. Aim for **>90% line coverage** for `TimelockGuard.sol`. Run `npm run coverage` and screenshot the result for the report.

### Day 13–14 — Hardening

- [x] Run the full repo test suite. No workspace-level `test` script exists; each module runs independently. Results: `timelock-guard` 45/45, `allowances` 34/34. `recovery` has no test script (pure TS library). `4337` has a pre-existing broken local build (`safe-4337-local-bundler` missing `dist/`) unrelated to this change.
- [ ] Fuzz a few invariants (optional — skipped; Foundry not set up in this workspace).
- [x] NatSpec added to every external function. Configuration and lifecycle functions have full `@notice`/`@dev`/`@param`/`@return`. Guard hooks (`checkTransaction`, `checkAfterExecution`) use `@dev` only — appropriate since they are protocol-internal hooks called by the Safe, not user entry points. `fallback()` has an inline comment but no formal NatSpec block.
- [x] Updated `safe-modules/README.md` to list Timelock Guard in the Modules section. Also added **Canceller management** and **Security considerations** sections to `modules/timelock-guard/README.md`.

**Week 2 commit goal:** 3–5 commits per day during implementation. Small commits per logical step (add storage, add setUp, add tests for setUp, etc.) demonstrate progressive work.

---

## Week 3 — Validate, deploy, document, ship

**Outcome:** Sepolia deployment, gas data, demo video, final report, draft PR.

### Day 15–16 — Sepolia deployment

- [ ] Get Sepolia ETH from a faucet (e.g., https://sepolia-faucet.pk910.de/).
- [ ] Set `MNEMONIC` and `INFURA_KEY` in `safe-smart-account/.env`.
- [ ] Write a small standalone deploy script (`scripts/deploy-timelock-guard.ts`):
  1. Deploy `TimelockGuard` with `MIN_DELAY=30, MAX_DELAY=30 days`.
  2. Deploy a fresh 1-of-1 `SafeProxy` for testing.
  3. Call `setUp(60)` (60-second delay).
  4. Call `setGuard(timelockGuard)`.
  5. Schedule a tiny test tx (e.g. send 0.0001 ETH to your own address).
  6. Wait ~70 seconds.
  7. Execute it.
  8. Print all transaction hashes.
- [ ] Verify the contract on Sepolia Etherscan (`npx hardhat verify --network sepolia <address> <constructor args>`).
- [ ] Save all tx hashes and Etherscan links in `report/sepolia-evidence.md`.

### Day 17 — Gas benchmarks

- [ ] Add a benchmark file `benchmark/Safe.TimelockGuard.spec.ts` modeled on the existing `Safe.MultiSend.spec.ts` etc.
- [ ] Measure:
  - `scheduleTransaction` cost (one-time per tx)
  - `execTransaction` overhead with vs without TimelockGuard
- [ ] Save results as a Markdown table in `report/gas-results.md`.

### Day 18 — Demo video

5 minutes max. Suggested outline:

1. (30s) Problem — UI attack on Bybit-style multisigs, motivation for delay.
2. (60s) High-level design — schedule, cancel, execute, who can do what.
3. (90s) Code tour — show `TimelockGuard.sol` and one or two key tests.
4. (90s) Live demo — run the Sepolia deploy script, show Etherscan links.
5. (30s) Summary + link to draft PR.

Record with QuickTime or Loom. Upload to YouTube (unlisted is fine) and embed in the project repo's README.

### Day 19 — Final report

10 pages max, PDF or DOCX. **Public GitHub repo URL at the top.** Suggested structure:

1. Introduction — what & why (½ page)
2. Background — Safe Smart Accounts, guards, the Bybit-style attack model (1 page)
3. Methodology — design decisions, why "schedule then execute" pattern, alternatives considered (2–3 pages, lean on `DESIGN.md`)
4. Implementation — code walkthrough with snippets (2 pages)
5. Evaluation — test coverage screenshot, gas benchmark table, Sepolia evidence (2 pages)
6. Discussion — limitations, future work, what would need to happen for upstream merge (1 page)
7. Conclusion (½ page)
8. References — Safe docs, OZ TimelockController, EIP-712, the Bybit incident write-up

### Day 20 — Draft PR

- [ ] On your `safe-modules` fork branch, push the final commit.
- [ ] Open a **draft PR** against `safe-fndn/safe-modules:main` titled something like:
  > `feat(modules): add TimelockGuard — configurable transaction delay for Safe Smart Accounts`
- [ ] PR body: short summary, design highlights, comparison with the Optimism guard, test results, gas numbers, and a link to your demo video.
- [ ] Check the CLA box in the PR template (the CLA Assistant bot will prompt you to sign via GitHub on PR open — takes ~15 seconds).
- [ ] Add the PR URL to your project README and the report.

### Day 21 — Buffer / polish

- [ ] Re-read the report top-to-bottom.
- [ ] Verify every README link works.
- [ ] Make sure the **last commit before the deadline is the graded state** (rubric note).

---

## Quick reference: commands you'll use repeatedly

```bash
# From repo root (safe-modules/) — workspace-level
pnpm install                      # install all workspace deps

# Inside safe-modules/modules/timelock-guard/
pnpm build                        # compile
pnpm test                         # run tests
pnpm coverage                     # line coverage
pnpm lint                         # solhint + eslint
pnpm fmt                          # prettier (run before committing)
```

## Files & links you'll come back to

- Issue (closed, referenced for context): https://github.com/safe-fndn/safe-smart-account/issues/1065
- PR target: https://github.com/safe-fndn/safe-modules
- Your fork branch: https://github.com/hayden-wolfe/safe-modules/tree/feat/timelock-guard
- `Safe.sol::execTransaction` (reference): [`safe-smart-account/contracts/Safe.sol:140`](../../safe-smart-account/contracts/Safe.sol#L140)
- `ITransactionGuard` definition: [`safe-smart-account/contracts/base/GuardManager.sol:15`](../../safe-smart-account/contracts/base/GuardManager.sol#L15)
- Allowances module (structure template): [`safe-modules/modules/allowances/`](../../safe-modules/modules/allowances/)
- Optimism guard (comparison baseline): https://github.com/ethereum-optimism/optimism/blob/main/packages/contracts-bedrock/src/safe/TimelockGuard.sol
- Reference design: [OpenZeppelin TimelockController](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol)
