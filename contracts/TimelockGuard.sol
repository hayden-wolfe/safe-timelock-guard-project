// DESIGN REFERENCE ONLY — NOT MEANT TO COMPILE.
// The real implementation is at:
//   safe-modules/modules/timelock-guard/contracts/TimelockGuard.sol
// Imports here use local relative paths from the original safe-smart-account
// target; they have not been updated after the pivot to safe-modules.

// SPDX-License-Identifier: LGPL-3.0-only
/* solhint-disable one-contract-per-file */
pragma solidity >=0.7.0 <0.9.0;

import {BaseTransactionGuard} from "./../../safe-smart-account/contracts/base/GuardManager.sol";
import {ISafe} from "./../../safe-smart-account/contracts/interfaces/ISafe.sol";
import {Enum} from "./../../safe-smart-account/contracts/interfaces/Enum.sol";

/**
 * @title TimelockGuard - Enforces a configurable delay between approval and execution of Safe transactions.
 * @notice Implements addresses Issue safe-fndn/safe-smart-account#1065. A Safe transaction must first be
 *         scheduled via {scheduleTransaction} (which verifies the threshold of owner signatures) and may
 *         only be executed via the standard {ISafe-execTransaction} flow once the configured delay has
 *         elapsed. The delay gives signers a window to detect and {cancel} compromised or malicious
 *         proposals before they take effect.
 * @dev Storage is keyed by the Safe address, so a single deployment serves any number of Safes.
 *      Configuration calls ({setUp}, {updateDelay}, {setCanceller}) require `msg.sender == safe`,
 *      meaning they must themselves be performed via {ISafe-execTransaction} (and therefore are
 *      themselves timelocked once the guard is active — disabling the guard cannot be done instantly).
 *      This guard is an example contract intended to live alongside `OnlyOwnersGuard.sol`.
 *      It implements only {ITransactionGuard}; module transactions are out of scope.
 * @author Hayden Wolfe
 */
contract TimelockGuard is BaseTransactionGuard {
    /// @notice Lower bound on the delay any Safe is allowed to configure. Set at deployment.
    uint256 public immutable MIN_DELAY;

    /// @notice Upper bound on the delay any Safe is allowed to configure. Set at deployment.
    uint256 public immutable MAX_DELAY;

    /// @dev Per-Safe configured delay in seconds. `0` means the timelock has not been set up for this Safe.
    mapping(address => uint256) private _delays;

    /// @dev Per-Safe schedule book: `_schedules[safe][txHash]` is the unix timestamp at which the tx becomes executable.
    mapping(address => mapping(bytes32 => uint256)) private _schedules;

    /// @dev Per-Safe canceller allowlist: addresses that may call {cancel} for that Safe.
    mapping(address => mapping(address => bool)) private _cancellers;

    // ─── Events ───────────────────────────────────────────────────────────────

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

    // ─── Errors ───────────────────────────────────────────────────────────────

    error NotSafe();
    error NotAuthorizedCanceller();
    error DelayBelowMinimum(uint256 provided, uint256 min);
    error DelayAboveMaximum(uint256 provided, uint256 max);
    error TimelockNotConfigured(address safe);
    error AlreadyScheduled(bytes32 txHash);
    error NotScheduled(bytes32 txHash);
    error DelayNotElapsed(uint256 readyAt, uint256 nowTs);
    error NonceInThePast(uint256 provided, uint256 current);

    // ─── Construction ─────────────────────────────────────────────────────────

    /**
     * @param minDelay Minimum delay (seconds) any Safe may configure. Must be > 0.
     * @param maxDelay Maximum delay (seconds) any Safe may configure. Must be >= minDelay.
     */
    constructor(uint256 minDelay, uint256 maxDelay) {
        // TODO: require(minDelay > 0 && maxDelay >= minDelay)
        MIN_DELAY = minDelay;
        MAX_DELAY = maxDelay;
    }

    // solhint-disable-next-line payable-fallback
    fallback() external {
        // We don't revert on fallback to avoid issues in case of a Safe upgrade where
        // the expected check method changes — otherwise the Safe would be locked.
    }

    // ─── Configuration (callable only by the Safe itself, via execTransaction) ─

    /**
     * @notice Initializes the timelock for the calling Safe.
     * @dev Must be called by the Safe via {ISafe-execTransaction} *before* {GuardManager-setGuard}
     *      installs this contract — otherwise the call will itself be subject to the timelock.
     * @param delay Initial delay in seconds. Must lie in `[MIN_DELAY, MAX_DELAY]`.
     */
    function setUp(uint256 delay) external {
        // TODO: require msg.sender is a Safe (or simply require _delays[msg.sender] == 0 to prevent re-init)
        // TODO: validate delay bounds
        // TODO: write _delays[msg.sender] = delay
        // TODO: emit TimelockSetUp
    }

    /**
     * @notice Updates the timelock delay for the calling Safe.
     * @dev Must be called by the Safe itself; the call is therefore timelocked when the guard is active.
     *      Already-pending transactions retain their original `readyAt`.
     * @param newDelay New delay in seconds. Must lie in `[MIN_DELAY, MAX_DELAY]`.
     */
    function updateDelay(uint256 newDelay) external {
        // TODO: require msg.sender is the Safe (and timelock initialized)
        // TODO: validate delay bounds
        // TODO: emit DelayUpdated(msg.sender, old, newDelay)
    }

    /**
     * @notice Adds or removes an address from the calling Safe's canceller allowlist.
     * @dev Must be called by the Safe itself.
     * @param account The address whose canceller status is being changed.
     * @param enabled `true` to grant cancel rights, `false` to revoke.
     */
    function setCanceller(address account, bool enabled) external {
        // TODO: require msg.sender is the Safe
        // TODO: write _cancellers[msg.sender][account] = enabled
        // TODO: emit CancellerUpdated
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    /**
     * @notice Schedules a Safe transaction for delayed execution.
     * @dev Computes the Safe transaction hash and verifies it carries the threshold of owner signatures
     *      via {ISafe-checkSignatures}. Anyone may call this function — it is the signatures, not the
     *      caller, that authorize the schedule. After the configured delay has elapsed, the standard
     *      {ISafe-execTransaction} flow with the same parameters and signatures will succeed.
     *
     *      The transaction parameters mirror {ISafe-execTransaction} verbatim, with `nonce` exposed
     *      explicitly so the caller can schedule for the current or any future nonce of the Safe.
     * @return txHash The Safe transaction hash that was scheduled.
     * @return readyAt The unix timestamp at which the transaction becomes executable.
     */
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
    ) external returns (bytes32 txHash, uint256 readyAt) {
        // TODO: require _delays[safe] != 0 (TimelockNotConfigured)
        // TODO: require nonce >= ISafe(safe).nonce() (NonceInThePast)
        // TODO: txHash = ISafe(safe).getTransactionHash(to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce)
        // TODO: require _schedules[safe][txHash] == 0 (AlreadyScheduled)
        // TODO: ISafe(safe).checkSignatures(address(this), txHash, signatures)
        // TODO: readyAt = block.timestamp + _delays[safe]
        // TODO: _schedules[safe][txHash] = readyAt
        // TODO: emit TransactionScheduled(safe, txHash, to, value, data, operation, nonce, readyAt)
    }

    /**
     * @notice Cancels a previously scheduled transaction.
     * @dev Caller must be either the Safe itself or an address present in the Safe's canceller allowlist.
     */
    function cancel(address safe, bytes32 txHash) external {
        // TODO: require msg.sender == safe || _cancellers[safe][msg.sender] (NotAuthorizedCanceller)
        // TODO: require _schedules[safe][txHash] != 0 (NotScheduled)
        // TODO: delete _schedules[safe][txHash]
        // TODO: emit TransactionCancelled
    }

    // ─── Guard hooks (called by Safe.execTransaction) ─────────────────────────

    /**
     * @inheritdoc BaseTransactionGuard
     * @dev Reverts unless the current Safe transaction was previously scheduled and the delay has elapsed.
     *      `msg.sender` is the Safe; the Safe's nonce was post-incremented before this call, so the
     *      nonce used to compute the current `txHash` is `ISafe(msg.sender).nonce() - 1`.
     */
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        // solhint-disable-next-line no-unused-vars
        address payable refundReceiver,
        bytes memory /* signatures */,
        address /* msgSender */
    ) external view override {
        // TODO: nonce = ISafe(msg.sender).nonce() - 1
        // TODO: txHash = ISafe(msg.sender).getTransactionHash(to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce)
        // TODO: readyAt = _schedules[msg.sender][txHash]
        // TODO: require readyAt != 0 (NotScheduled)
        // TODO: require block.timestamp >= readyAt (DelayNotElapsed)
    }

    /**
     * @inheritdoc BaseTransactionGuard
     * @dev Clears the schedule entry for the just-executed transaction. Skipped if execution failed
     *      so the transaction can be retried (Safe still increments its nonce on failure, however —
     *      so a failed scheduled tx will need to be re-scheduled. TODO: confirm desired semantics.)
     */
    function checkAfterExecution(bytes32 txHash, bool success) external override {
        // TODO: if (success) { delete _schedules[msg.sender][txHash]; emit TransactionExecuted(msg.sender, txHash); }
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function getDelay(address safe) external view returns (uint256) {
        return _delays[safe];
    }

    function getReadyAt(address safe, bytes32 txHash) external view returns (uint256) {
        return _schedules[safe][txHash];
    }

    function isCanceller(address safe, address account) external view returns (bool) {
        return _cancellers[safe][account];
    }
}
