// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Storage} from "./Storage.sol";
import {Config, Recipient} from "./Types.sol";
import {IDropKit} from "./interfaces/IDropKit.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";

/// @title DropKit
/// @author kelbels
/// @notice A contract for creating and managing token airdrops with vesting and early withdrawal penalties.
/// @dev This contract allows users (droppers) to create airdrops of ERC20 tokens.  Recipients can claim their
/// tokens according to a vesting schedule.  Early withdrawals are possible but incur a penalty.
contract DropKit is IDropKit, Storage, Ownable {
    using SafeTransferLib for address;

    constructor() Ownable(msg.sender) {}

    // ADMIN FUNCTIONS

    /// @notice Sets the minimum allowed early exit penalty.
    /// @dev Only callable by the contract owner.
    /// @param newMinEarlyExitPenalty The new minimum early exit penalty (scaled by 1e18).
    function setMinEarlyExitPenalty(uint256 newMinEarlyExitPenalty) public onlyOwner {
        minEarlyExitPenalty = newMinEarlyExitPenalty;
    }

    /// @notice Sets the creation price for airdrops.
    /// @dev Only callable by the contract owner.  This is paid in MON.
    /// @param newCreationPrice The new creation price for airdrops.
    function setCreationPrice(uint256 newCreationPrice) public onlyOwner {
        creationPrice = newCreationPrice;
    }

    /// @notice Sets the global claim deadline for airdrops.
    /// @dev Only callable by the contract owner.  This is a duration (in seconds) after the airdrop's start timestamp.
    /// @param newActivationDeadline The new claim deadline duration (in seconds).
    function setActivationDeadline(uint256 newActivationDeadline) public onlyOwner {
        activationDeadline = newActivationDeadline;
    }

    /// @notice Allows the owner to claim fees collected by the contract.
    /// @dev Only callable by the contract owner.
    function claimFees(address token) public payable onlyOwner {
        // TODO: MON - needs to account for creationFees and 10% penalty fees?
    }

    // DROPPER FUNCTIONS

    function createDrop(
        address token,
        bytes32 merkleRoot,
        uint256 totalAmount,
        uint256 earlyExitPenalty,
        uint256 startTimestamp,
        uint256 vestingDuration
    ) public payable returns (uint256 dropID) {
        // assume the dropper is using their own token

        //TODO: maybe check if msg.value is MON?

        // Require payment for drop creation
        require(msg.value == creationPrice, InsufficientPayment());

        // Check that the start date is in the future
        require(startTimestamp >= block.timestamp, InvalidStartDate());

        // Check early exit penalty
        require(earlyExitPenalty >= minEarlyExitPenalty, EarlyExitPenaltyTooLow());
        require(earlyExitPenalty <= MAX_EARLY_EXIT_PENALTY_ALLOWED, EarlyExitPenaltyTooHigh());

        // transfer token to this contract
        token.safeTransferFrom(msg.sender, address(this), totalAmount);

        // create a new drop
        Config memory config = Config({
            token: token,
            merkleRoot: merkleRoot,
            totalAmount: totalAmount,
            earlyExitPenalty: earlyExitPenalty,
            startTimestamp: startTimestamp,
            vestingDuration: vestingDuration
        });

        // drop ID settings
        dropID = ++dropCount;
        drops[dropID] = config;
        dropCreator[dropID] = msg.sender;

        // emit event
        emit DropCreated(dropID, token, totalAmount, earlyExitPenalty, startTimestamp, vestingDuration);
    }

    // RECIPIENT FUNCTIONS

    /// @notice Activates the airdrop for the calling recipient.
    /// @dev Checks eligibility via Merkle proof and prevents double-claiming.  The airdrop must have started.
    /// @param dropID The ID of the airdrop to activate.
    /// @param amount The amount of tokens the recipient is claiming, must match the amount in the Merkle proof.
    /// @param merkleProof The Merkle proof demonstrating the recipient's eligibility.
    /// @dev Emits a `DropActivated` event.
    function activateDrop(uint256 dropID, uint256 amount, bytes32[] memory merkleProof) public {
        Config memory config = drops[dropID];
        // storage for changing state?
        Recipient storage recipient = recipients[dropID][msg.sender];

        // Check if the drop is active
        require(block.timestamp >= config.startTimestamp, AirdropNotStarted(config.startTimestamp));
        require(
            block.timestamp < config.startTimestamp + activationDeadline,
            DropExpired(config.startTimestamp + activationDeadline)
        );

        // Check if the recipient has already claimed
        require(!recipient.hasActivatedDrop, AlreadyActivated());

        // Check if the recipient is in the merkle tree
        bool verified = _verifyMerkleProof(dropID, msg.sender, amount, merkleProof);
        require(verified, NotEligibleForAirdrop());

        // update the activated status and amount mapping
        recipient.hasActivatedDrop = true;
        recipient.totalAmountDropped = amount;
        recipient.totalAmountRemaining = amount;

        emit DropActivated(dropID, config.token, msg.sender, amount);
    }

    function verifyMerkleProof(uint256 dropID, address recipient, uint256 amount, bytes32[] memory merkleProof)
        external
        view
        returns (bool)
    {
        return _verifyMerkleProof(dropID, recipient, amount, merkleProof);
    }

    function _verifyMerkleProof(uint256 dropID, address recipient, uint256 amount, bytes32[] memory merkleProof)
        internal
        view
        returns (bool)
    {
        // Check if the recipient is in the merkle tree
        bytes32 leaf = keccak256(abi.encodePacked(recipient, amount));
        return MerkleProofLib.verify(merkleProof, drops[dropID].merkleRoot, leaf);
    }

    /// @notice Allows a recipient to withdraw airdropped tokens.
    /// @dev Calculates vested and unvested amounts, applies penalties for early withdrawals of unvested tokens, and transfers the tokens.
    /// @param dropID The ID of the airdrop to withdraw from.
    /// @param amountRequested The amount of tokens the recipient wants to withdraw.
    /// @dev Emits an `AirdropTokensWithdrawn` event.
    function withdrawAirdropTokens(uint256 dropID, uint256 amountRequested) public {
        // TODO: calculate penalty amount and add to this function
        Config memory config = drops[dropID];
        // storage for changing state? TODO: who is calling this function if its internal?
        Recipient storage recipient = recipients[dropID][msg.sender];

        // Check if the recipient has not activated or already withdrawn
        require(recipient.hasActivatedDrop, NotActivated());
        require(recipient.totalAmountRemaining != 0, AlreadyWithdrawn());

        uint256 recipientsAmountRemaining = recipient.totalAmountRemaining;

        // Check if the recipient has enough funds owed
        require(amountRequested <= recipientsAmountRemaining, InsufficientFunds());

        uint256 amountOut = _handleWithdrawals(dropID, amountRequested);

        recipient.totalAmountRemaining -= amountOut;

        // transfer tokens to the recipient
        config.token.safeTransfer(msg.sender, amountOut);

        emit AirdropTokensWithdrawn(dropID, msg.sender, amountOut);
    }

    // INTERNAL FUNCTIONS

    /// @notice Internal function to handle withdrawal logic, including penalty calculation.
    /// @param dropID The ID of the airdrop.
    /// @param amountRequested The amount the user wants to withdraw.
    /// @return amountOut The actual amount withdrawn after penalties are applied.
    function _handleWithdrawals(uint256 dropID, uint256 amountRequested) internal returns (uint256 amountOut) {
        Recipient storage recipient = recipients[dropID][msg.sender];

        uint256 userAmount = recipient.totalAmountDropped;
        uint256 userAmountRemaining = recipient.totalAmountRemaining;

        uint256 vestedAmount = _getVestedAmount(dropID, userAmount);

        uint256 unvestedAmount = userAmount - vestedAmount;

        uint256 vestedBalanceAvailable = userAmountRemaining - unvestedAmount;

        // if recipient is withdrawing less than/equal to vested amount, no penalty
        if (amountRequested <= vestedBalanceAvailable) {
            return amountRequested;
        }

        // if recipient is withdrawing more than vested amount
        uint256 unvestedWithdrawalAmount = amountRequested - vestedBalanceAvailable;

        uint256 penalty = _getPenalty(dropID, unvestedWithdrawalAmount);

        recipient.totalAmountRemaining -= penalty;

        amountOut = vestedBalanceAvailable + unvestedWithdrawalAmount - penalty;
        // TODO: refactor this function to be clearer and more gas efficient
    }

    /// @notice Calculates the penalty for withdrawing unvested tokens.
    /// @param dropID The ID of the airdrop.
    /// @param unvestedWithdrawalAmount The amount of unvested tokens being withdrawn.
    /// @return penalty The calculated penalty (scaled by 1e18).
    function _getPenalty(uint256 dropID, uint256 unvestedWithdrawalAmount) internal view returns (uint256 penalty) {
        // applies to claiming tokens when some are still unvested
        penalty = (unvestedWithdrawalAmount * drops[dropID].earlyExitPenalty) / SCALE;
    }

    /// @notice Calculates the amount of tokens that have vested for a recipient.
    /// @param dropID The ID of the airdrop.
    /// @param userAmount The total amount of tokens the user is entitled to.
    /// @return vestedAmount The amount of tokens that have vested.
    function _getVestedAmount(uint256 dropID, uint256 userAmount) internal view returns (uint256 vestedAmount) {
        Config memory config = drops[dropID];

        uint256 vestedTime = _getVestedTime(dropID);

        // percentage calculation for vested portion
        uint256 vestedPortion = (vestedTime * SCALE) / config.vestingDuration;

        // make sure the vested portion doesn't go over 100%
        if (vestedPortion > SCALE) {
            vestedPortion = SCALE;
        }

        // calculate the vested amount with percentage
        vestedAmount = (userAmount * vestedPortion) / SCALE;
    }

    /// @notice Calculates the amount of time that has vested for a given airdrop.
    /// @param dropID The ID of the airdrop.
    /// @return vestedTime The amount of time (in seconds) that has vested.
    function _getVestedTime(uint256 dropID) internal view returns (uint256 vestedTime) {
        Config memory config = drops[dropID];

        uint256 fullVestPeriod = config.startTimestamp + config.vestingDuration;

        // vesting period complete
        if (block.timestamp >= fullVestPeriod) {
            return config.vestingDuration;
        }

        // partially vested - time since the start
        vestedTime = block.timestamp - config.startTimestamp;
    }

    // TODO: track balances
}
