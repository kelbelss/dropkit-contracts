// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Storage} from "./Storage.sol";
import {Config} from "./Types.sol";
import {IDropKit} from "./interfaces/IDropKit.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

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
    function claimAirdrop(uint256 dropID, uint256 amount, bytes32[] memory merkleProof) public {
        Config memory config = drops[dropID];

        // Check if the drop is still active
        require(block.timestamp < config.startTimestamp + claimDeadline, DropExpired());

        // Check if the recipient has already claimed
        // TODO: what would this be if other tokens are vested?
        require(dropClaimedAmount[dropID] == 0, AlreadyClaimed());

        // Check if the recipient is in the merkle tree
        // TODO:
        // bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        // require(merkleProof.verify(leaf, amount), NotEligibleForAirdrop());

        // transfer tokens to the recipient
        // TODO: remove penalty amount
        config.token.safeTransfer(msg.sender, amount);

        // update the claimed amount mapping
        dropClaimedAmount[dropID] = amount;

        emit DropClaimed(dropID, config.token, msg.sender, amount);
    }

    function startVesting(uint256 _dropID, address recipient, uint256 amount, bytes32[] memory merkleProof) public {}
    function withdrawVestedTokens(uint256 _dropID) public {}
}
