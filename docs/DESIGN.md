# TimelockGuard — Design Document

**Project:** Timelock Guard: A Transaction Delay for Safe Smart Accounts

**Target repo:** [safe-fndn/safe-modules](https://github.com/safe-fndn/safe-modules) — contributed as `modules/timelock-guard/`
*(Originally proposed for [safe-fndn/safe-smart-account](https://github.com/safe-fndn/safe-smart-account); maintainer nlordell redirected to safe-modules in [#1065](https://github.com/safe-fndn/safe-smart-account/issues/1065).)*

**Issue:** [#1065](https://github.com/safe-fndn/safe-smart-account/issues/1065)

**Author:** Hayden Wolfe

---

## 1. Goal

Implement a Safe `ITransactionGuard` that enforces a configurable delay between when an N/M-signed transaction is approved and when it can be executed, **without modifying the core Safe contracts** and without breaking the standard `execTransaction` user flow.

## 2. Background — how Safe guards work

`Safe.execTransaction(...)` performs the following sequence (see [`Safe.sol:140-230`](../../safe-smart-account/contracts/Safe.sol#L140)):

1. Computes `txHash = getTransactionHash(..., nonce++)` — note the **post-increment** of nonce.
2. Calls `checkSignatures(msg.sender, txHash, signatures)` — reverts on insufficient signatures.
3. If a guard is set, calls `guard.checkTransaction(...)` with all tx params — reverts here will revert the whole `execTransaction`.
4. Executes the call.
5. If a guard is set, calls `guard.checkAfterExecution(txHash, success)`.

Because `checkTransaction` is invoked **after** the nonce post-increment, inside the guard `ISafe(msg.sender).nonce() - 1` returns the nonce that was used to compute the current `txHash`.

## 3. Design

### 3.1 Lifecycle

A transaction goes through three states inside the guard:

| State | Meaning | Mapping value |
|---|---|---|
| **Unscheduled** | Not registered with the guard | `schedules[safe][txHash] == 0` |
| **Pending** | Scheduled, delay not yet elapsed | `schedules[safe][txHash] > block.timestamp` |
| **Ready** | Scheduled, delay elapsed | `0 < schedules[safe][txHash] <= block.timestamp` |

After successful execution, `checkAfterExecution` deletes the entry, returning the slot to `Unscheduled`.

### 3.2 Why a separate `scheduleTransaction` function (not first-call-records)

A naive design ("first call records and reverts; second call executes") does not work: when `checkTransaction` reverts, all state changes in that call frame — including the guard's own — are rolled back by the EVM. So scheduling must happen in a separate transaction that does *not* revert.

### 3.3 Public API

```solidity
// ─── Configuration (callable only by the Safe itself, via execTransaction) ───
function setUp(uint256 delay) external;
function updateDelay(uint256 newDelay) external;
function setCanceller(address canceller, bool enabled) external;

// ─── Lifecycle ───
function scheduleTransaction(
    address safe,
    address to,
    uint256 value,
    bytes calldata data,
    Enum.Operation operation,
    uint256 safeTxGas,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address payable refundReceiver,
    uint256 nonce,
    bytes calldata signatures
) external returns (bytes32 txHash, uint256 readyAt);

function cancel(address safe, bytes32 txHash) external;

// ─── Guard hooks (called by Safe) ───
function checkTransaction(...) external override;       // reverts unless tx is Ready
function checkAfterExecution(bytes32 txHash, bool) external override;  // clears schedule

// ─── Views ───
function getDelay(address safe) external view returns (uint256);
function getReadyAt(address safe, bytes32 txHash) external view returns (uint256);
function isCanceller(address safe, address account) external view returns (bool);
```

### 3.4 Storage layout

```solidity
uint256 public immutable MIN_DELAY;     // floor — set in constructor
uint256 public immutable MAX_DELAY;     // ceiling — sanity bound

mapping(address safe => uint256) private _delays;
mapping(address safe => mapping(bytes32 txHash => uint256 readyAt)) private _schedules;
mapping(address safe => mapping(address canceller => bool)) private _cancellers;
```

### 3.5 Authorization model

| Function | Authorized caller |
|---|---|
| `setUp` / `updateDelay` / `setCanceller` | `msg.sender == safe` (i.e., called via `safe.execTransaction`) |
| `scheduleTransaction` | Anyone who can present valid threshold signatures over the tx hash |
| `cancel` | The Safe itself **or** an address with `_cancellers[safe][account] == true` |
| `checkTransaction` / `checkAfterExecution` | Any address (validates `msg.sender` is the Safe context implicitly via storage lookup) |

Signatures inside `scheduleTransaction` are verified by delegating to `ISafe(safe).checkSignatures(address(this), txHash, signatures)`. The `executor` parameter passed to `checkSignatures` only matters for `v == 1` (approved-hash) signatures; passing `address(this)` ensures that the timelock contract is never an owner whose presence would auto-approve.

### 3.6 Bootstrapping (chicken-and-egg)

Once the guard is installed, `setUp` cannot be called via `execTransaction` because the guard would block it (timelock not yet configured → `scheduleTransaction` reverts).

**Recommended setup order:**

1. **Before installing the guard:** owners execute `safe.execTransaction(timelockGuard, 0, abi.encodeCall(TimelockGuard.setUp, (delay)))` to set the per-safe delay. Since the guard is not yet active, no timelock applies.
2. **Then install:** owners execute `safe.execTransaction(safe, 0, abi.encodeCall(GuardManager.setGuard, (address(timelockGuard))))`. After this transaction completes, every subsequent `execTransaction` is timelocked.

Alternatively, both calls can be batched via Safe's MultiSend.

### 3.7 Bootstrapping — alternative considered

Allowing the first `execTransaction` after install to bypass the timelock was rejected: it creates a window where a single transaction set up by an attacker could disable the guard or change the delay. Forcing setup *before* install is safer.

### 3.8 Edge cases

| Concern | Handling |
|---|---|
| Same `txHash` scheduled twice | Second call reverts (`AlreadyScheduled`) — preserves first scheduling time |
| `gasPrice`/refund parameters changed at execution | `txHash` differs → not found in `_schedules` → reverts (Safe's own signature check would also fail) |
| Delay change mid-flight | Already-pending transactions retain their original `readyAt`; new schedules use the new delay |
| Removing the guard | `setGuard(0)` is itself a Safe transaction → must be timelocked → no instant disable |
| Replay across Safes | Mapping keyed by `safe` address; same `txHash` on different Safes is independent |
| `nonce` being skipped | Allowed: scheduling for `nonce >= safe.nonce()` is permitted; stale schedules are harmless and can be `cancel`led |
| Module transactions | Out of scope for v1 — guard implements only `ITransactionGuard`, not `IModuleGuard` |
| `MIN_DELAY` of 0 | Constructor enforces `MIN_DELAY > 0`. A test build can deploy with a small min (e.g. 30s); production deployments should use a meaningful floor |

### 3.9 Events

```solidity
event TimelockSetUp(address indexed safe, uint256 delay);
event DelayUpdated(address indexed safe, uint256 oldDelay, uint256 newDelay);
event CancellerUpdated(address indexed safe, address indexed account, bool enabled);
event TransactionScheduled(
    address indexed safe,
    bytes32 indexed txHash,
    address to,
    uint256 value,
    bytes data,
    Enum.Operation operation,
    uint256 nonce,
    uint256 readyAt
);
event TransactionExecuted(address indexed safe, bytes32 indexed txHash);
event TransactionCancelled(address indexed safe, bytes32 indexed txHash, address indexed canceller);
```

### 3.10 Custom errors

```solidity
error NotSafe();
error NotAuthorizedCanceller();
error DelayBelowMinimum(uint256 provided, uint256 min);
error DelayAboveMaximum(uint256 provided, uint256 max);
error TimelockNotConfigured(address safe);
error AlreadyScheduled(bytes32 txHash);
error NotScheduled(bytes32 txHash);
error DelayNotElapsed(uint256 readyAt, uint256 nowTs);
error NonceInThePast(uint256 provided, uint256 current);
```

## 4. Test plan

### 4.1 Unit tests (Hardhat, mocha/chai)

- Configuration
  - `setUp` reverts when called by non-Safe
  - `setUp` reverts on delay outside `[MIN_DELAY, MAX_DELAY]`
  - `updateDelay` works only when called by the Safe
  - `setCanceller` enable/disable
- Scheduling
  - Reverts when timelock not configured for the Safe
  - Reverts on stale `nonce` (`nonce < safe.nonce()`)
  - Reverts on bad signatures
  - Successfully schedules and emits event with correct `readyAt`
  - Double-scheduling reverts
- Cancellation
  - Safe can cancel
  - Authorized canceller can cancel
  - Random address cannot cancel
  - Cancelling a non-scheduled tx reverts
- Guard hooks
  - `checkTransaction` reverts if not scheduled
  - `checkTransaction` reverts if delay not elapsed
  - `checkTransaction` succeeds when scheduled and ready
  - `checkAfterExecution` clears the schedule
  - `supportsInterface(ITransactionGuard.interfaceId)` returns true

### 4.2 Integration tests (with real Safe)

- Full happy path: `setUp` → `setGuard` → `scheduleTransaction` → wait → `execTransaction` succeeds; receipt shows transferred ETH/token
- Full happy path with non-zero `value` and ETH transfer
- Cancel mid-flight blocks subsequent `execTransaction`
- Trying to remove the guard via `setGuard(0)` is itself timelocked
- Concurrent schedules with different nonces

### 4.3 Gas benchmarks

Capture for the README and the report:

- Cost of `scheduleTransaction`
- Overhead added to `execTransaction` by `checkTransaction` + `checkAfterExecution`
- Comparison: Safe execTransaction with no guard vs. with TimelockGuard installed

### 4.4 Sepolia validation

- Deploy `TimelockGuard` and a fresh 1-of-1 `SafeProxy`.
- End-to-end: setup → schedule → execute (after delay) → verify on Etherscan.
- End-to-end: setup → schedule → cancel → verify cancel event.

## 5. Finalized design decisions

All open questions from the draft are now resolved. These choices are locked in for implementation.

### 5.1 Delay bounds

| Parameter | Value | Rationale |
|---|---|---|
| `MIN_DELAY` (constructor arg) | `30` seconds for Sepolia/tests; `300` seconds recommended for production | 30s makes automated tests fast. The constructor arg lets each deployment choose. The SafeState delay set via `setUp` must be ≥ `MIN_DELAY`. |
| `MAX_DELAY` (constructor arg) | `2_592_000` seconds (30 days) | Prevents misconfiguration that would permanently lock a Safe. 30 days matches OZ TimelockController's practical upper bound. |

Per-Safe delays configured via `setUp` / `updateDelay` are validated to lie within `[MIN_DELAY, MAX_DELAY]` at the time of the call.

### 5.2 Module guard support

**Decision: No.** `TimelockGuard` implements only `ITransactionGuard` (not `IModuleGuard`). Module transactions bypass the owner threshold by design, and applying a separate timelock to them would require a different security model. Out of scope for v1.

### 5.3 Canceller authorization

**Decision: Any authorized canceller may cancel any scheduled transaction for their Safe.** Cancellers are trusted addresses designated by the Safe itself (via `setCanceller`). Restricting to "own-scheduled-only" adds complexity with no practical security benefit — the Safe already controls who becomes a canceller.

### 5.4 Storage strategy: hash-only vs full tx data

**Decision: Hash-only.** `_schedules[safe][txHash] = readyAt`. Only the `readyAt` timestamp is stored on-chain; the full transaction parameters are emitted in the `TransactionScheduled` event and can always be re-derived by anyone watching the chain.

The alternative (storing full tx data in enumerable sets, as the Optimism guard does) costs ~5–10× more gas per schedule and adds significant contract complexity. For an auditable guard, event-based visibility is sufficient.

### 5.5 Cancellation mechanism: on-chain ACL vs signature-based

**Decision: On-chain canceller ACL.** Any address in `_cancellers[safe]` can call `cancel(safe, txHash)` directly. The Optimism guard uses a "signCancellation" off-chain approach with dynamic thresholds (see §6), which is more sophisticated but also more complex to implement and audit. For v1, a simple address allowlist is clearer and easier to reason about.

### 5.6 setUp re-initialization guard

**Decision: `setUp` reverts if already configured.** If `_delays[msg.sender] != 0`, `setUp` reverts. Use `updateDelay` to change an existing delay. This prevents accidental re-initialization and makes the state machine explicit: `Unset → Configured` is a one-way transition; `Configured → Reconfigured` goes through `updateDelay` (which is itself timelocked once the guard is active).

### 5.7 Behavior on failed execution

**Decision: Schedule entry is preserved on failure.** In `checkAfterExecution`, only delete `_schedules[msg.sender][txHash]` when `success == true`. If the inner call fails (e.g., out of gas, revert from the target), the schedule stays. Since Safe increments its nonce even on failure, the owners must re-sign and re-schedule using the new nonce — the existing schedule entry will never be hit again and can be cancelled manually. This avoids any state ambiguity.

---

## 6. Comparison with Optimism TimelockGuard

The Safe maintainer referenced the [Optimism Foundation's TimelockGuard](https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-bedrock/src/safe/TimelockGuard.sol) (audited by Spearbit) as an existing implementation. This section documents how the two designs relate, and justifies the choices made for this contribution.

### 6.1 Structural overview

| Dimension | This implementation | Optimism guard |
|---|---|---|
| Lifecycle entry-point | `scheduleTransaction(safe, ...params, signatures)` — external, permissionless with valid sigs | `scheduleTransaction(...)` — similar; stores full `ExecTransactionParams` struct |
| Storage per tx | `uint256 readyAt` (hash-only) | Full `ScheduledTransaction` struct with all params in an enumerable set |
| Cancellation mechanism | On-chain call by any address in `_cancellers[safe]` | Off-chain `signCancellation` — generates signatures that can be presented by anyone; no privileged canceller role |
| Cancellation threshold | Static — any one canceller address can cancel | Dynamic — starts at 1 signature, increases after consecutive cancellations (anti-griefing) |
| Delay reconfiguration | `updateDelay(newDelay)` — must go through execTransaction (timelocked) | `configureTimelockGuard(delay)` — similarly guarded |
| Emergency reset | `cancel(safe, txHash)` per-transaction | Config nonce increment — atomically invalidates all pending transactions |
| Multi-Safe support | Single contract, all state keyed by `safe` address | One guard instance per Safe |
| Safe version requirement | Any Safe with guard support (≥ 1.3.0) | Hardcoded to Safe 1.4.1 |
| Solidity target | 0.8.x (custom errors, named mapping params) | 0.8.x |

### 6.2 Key differences explained

**Hash-only vs full data storage.** Storing the full `ExecTransactionParams` struct enables the Optimism guard to enumerate pending transactions and reconstruct them without event logs. This is useful for protocol dashboards and dispute resolution. This implementation trades that convenience for significantly lower gas cost (one `SSTORE` vs many) and simpler auditability. For general-purpose use, the `TransactionScheduled` event provides sufficient off-chain visibility.

**Dynamic cancellation threshold vs static ACL.** The Optimism guard's escalating threshold protects against a single compromised canceller performing a denial-of-service (cancel every scheduled transaction indefinitely). After N consecutive cancellations, M signatures are required to cancel the next one. This implementation's static ACL is simpler and appropriate when the Safe's owner set is the canceller — a compromised canceller would be replaced via a (timelocked) `setCanceller` call. For high-stakes protocol treasuries, the dynamic threshold is the stronger design; for general use, the ACL is more operationally tractable.

**Config nonce reset.** The Optimism guard allows owners to invalidate all pending transactions at once by incrementing a configuration nonce. This is a useful emergency escape hatch. This implementation omits it because individual `cancel` calls achieve the same result without the added complexity of a nonce-per-config scheme. Future work could add a `cancelAll()` function.

**Safe version pinning.** The Optimism guard verifies `safe.VERSION() == "1.4.1"` at configuration time. This is appropriate for their specific deployment context (they control which Safe version they use) but would make the guard unusable on Safe 1.5.x or future versions. This implementation is version-agnostic — it only requires the `ITransactionGuard` interface, which has been stable since Safe 1.3.0.

### 6.3 What this implementation adds

- A single deployed contract can serve any number of Safes simultaneously (lower deployment cost for adopters).
- Version-agnostic compatibility — works with any Safe that supports guards.
- Explicit `setUp`/`updateDelay`/`setCanceller` surface makes the configuration lifecycle readable.
- Simpler codebase — easier to audit, appropriate for the `safe-modules` examples collection.

---

## 7. Open questions / future work

- Should the guard support module transactions (extend `BaseGuard`)?
- Should there be a global pause / emergency-cancel role?
- Dynamic cancellation threshold (as in Optimism guard) for high-value deployments?
- `cancelAll()` via config nonce (as in Optimism guard) for emergency resets?
- Predecessor chaining (à la OZ TimelockController) for sequenced operations?

These are intentionally out of scope for v1 to keep the surface small and reviewable.
