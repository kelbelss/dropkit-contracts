// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Storage} from "./Storage.sol";
import {Config, Recipient} from "./Types.sol";
import {IDropKit} from "./interfaces/IDropKit.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";

contract DropKit is IDropKit, Storage, Ownable {
    using SafeTransferLib for address;

    constructor() Ownable(msg.sender) {}

    // ADMIN
    function setMinEarlyExitPenaltyAllowed(uint256 newMinEarlyExitPenaltyAllowed) public onlyOwner {
        minEarlyExitPenaltyAllowed = newMinEarlyExitPenaltyAllowed;
    }

    function setCreationPrice(uint256 newCreationPrice) public onlyOwner {
        creationPrice = newCreationPrice;
    }

    function setClaimDeadline(uint256 newClaimDeadline) public onlyOwner {
        claimDeadline = newClaimDeadline;
    } // one year

    function claimFees(address token) public payable onlyOwner {
        // TODO: MON - needs to account for creationFees and 10% penalty fees?
    }

    // DROPPER
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
        require(earlyExitPenalty >= minEarlyExitPenaltyAllowed, EarlyExitPenaltyTooLow());
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

    function withdrawUnclaimedTokens(uint256 _dropID) public {} // only after a year

    // RECIPIENT
    function activateAirdrop(uint256 dropID, uint256 amount, bytes32[] memory merkleProof) public {
        Config memory config = drops[dropID];
        // storage for changing state?
        Recipient storage recipient = recipients[msg.sender];

        // Check if the drop is active
        require(block.timestamp >= config.startTimestamp, AirdropNotStarted());
        require(block.timestamp < config.startTimestamp + claimDeadline, DropExpired());

        // Check if the recipient has already claimed
        require(!recipient.hasActivatedDrop, AlreadyActivated());

        // Check if the recipient is in the merkle tree
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        require(MerkleProofLib.verify(merkleProof, config.merkleRoot, leaf), NotEligibleForAirdrop());

        // update the activated status and amount mapping
        recipient.hasActivatedDrop = true;
        recipient.totalAmountDropped += amount;
        recipient.totalAmountRemaining += amount;

        emit DropActivated(dropID, config.token, msg.sender, amount);
    }

    function withdrawAirdropTokens(uint256 dropID, uint256 amountToWithdraw) public {
        // TODO: calculate penalty amount and add to this function
        Config memory config = drops[dropID];
        // storage for changing state? TODO: who is calling this function if its internal?
        Recipient storage recipient = recipients[msg.sender];

        // Check if the recipient has not activated or already withdrawn
        require(recipient.hasActivatedDrop, NotActivated());
        require(!recipient.hasWithdrawnFullDrop, AlreadyWithdrawn());

        uint256 recipientsAmountRemaining = recipient.totalAmountRemaining;

        // Check if the recipient has enough funds owed
        require(amountToWithdraw <= recipientsAmountRemaining, InsufficientFunds());

        uint256 withdrawalAmount = handleWithdrawals(dropID, amountToWithdraw);

        if (withdrawalAmount == recipient.totalAmountRemaining) {
            recipient.hasWithdrawnFullDrop = true;
            recipient.totalAmountRemaining -= withdrawalAmount;
        } else {
            recipient.totalAmountRemaining -= withdrawalAmount;
        }

        // transfer tokens to the recipient
        config.token.safeTransfer(msg.sender, withdrawalAmount);

        emit AirdropTokensWithdrawn(dropID, msg.sender, amountToWithdraw);
    }

    function handleWithdrawals(uint256 dropID, uint256 amountToWithdraw) internal returns (uint256 withdrawalAmount) {
        Recipient storage recipient = recipients[msg.sender];

        uint256 userAmount = recipient.totalAmountDropped;
        uint256 userAmountRemaining = recipient.totalAmountRemaining;

        uint256 vestedAmount = getVestedAmount(dropID, userAmount);

        uint256 unvestedAmount = userAmount - vestedAmount;

        uint256 vestedBalanceAvailable = userAmountRemaining - unvestedAmount;

        // if recipient is withdrawing less than/equal to vested amount, no penalty
        if (amountToWithdraw <= vestedBalanceAvailable) {
            return amountToWithdraw;
        }

        // if recipient is withdrawing more than vested amount
        uint256 unvestedWithdrawalAmount = amountToWithdraw - vestedBalanceAvailable;

        uint256 penalty = getPenalty(dropID, unvestedWithdrawalAmount);

        recipient.totalAmountRemaining -= penalty;

        withdrawalAmount = vestedBalanceAvailable + unvestedWithdrawalAmount - penalty;
    }

    function getPenalty(uint256 dropID, uint256 unvestedWithdrawalAmount) internal view returns (uint256 penalty) {
        Config memory config = drops[dropID];

        // applies to claiming tokens when some are still unvested
        penalty = (unvestedWithdrawalAmount * config.earlyExitPenalty) / SCALE;
    }

    function getVestedAmount(uint256 dropID, uint256 userAmount) internal view returns (uint256 vestedAmount) {
        Config memory config = drops[dropID];

        uint256 vestedTime = getVestedTime(dropID);

        // percentage calculation for vested portion
        uint256 vestedPortion = (vestedTime * SCALE) / config.vestingDuration;

        // make sure the vested portion doesn't go over 100%
        if (vestedPortion > SCALE) {
            vestedPortion = SCALE;
        }

        // calculate the vested amount with percentage
        vestedAmount = (userAmount * vestedPortion) / SCALE;
    }

    function getVestedTime(uint256 dropID) internal view returns (uint256 vestedTime) {
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
    // TODO: add ID to recipient struct
}
