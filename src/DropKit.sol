// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Storage} from "./Storage.sol";
import {Config} from "./Types.sol";
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
    function claimAirdrop(uint256 dropID, uint256 amount, bytes32[] memory merkleProof) public {
        Config memory config = drops[dropID];

        // TODO: who is allowed to claim this? only msg.sender?

        // Check if the drop is active
        require(block.timestamp >= config.startTimestamp, AirdropNotStarted());
        require(block.timestamp < config.startTimestamp + claimDeadline, DropExpired());

        // Check if the recipient has already claimed
        require(!hasClaimed[dropID][msg.sender], AlreadyClaimed());

        // Check if the recipient is in the merkle tree
        // TODO:
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));

        require(MerkleProofLib.verify(merkleProof, config.merkleRoot, leaf), NotEligibleForAirdrop());

        // update the claimed amount mapping and claimed status
        dropClaimedAmount[dropID] += amount;

        hasClaimed[dropID][msg.sender] = true;

        // transfer tokens to the recipient
        // TODO: calculate penalty amount and add to this function
        config.token.safeTransfer(msg.sender, amount);

        emit DropClaimed(dropID, config.token, msg.sender, amount);
    }

    // TODO: track each recipients amount? UsersAllocation function and mapping?
    // TODO: add a mapping to keep track of funds a user has already claimed

    function calculatePenalty(uint256 userAmount) external pure returns (uint256 penalty) {
        Config memory config = drops[dropID];

        // needs if/else - chkeck if vestingPeriod has passed first

        // uint256 vestedPeriod = (block.timestamp - config.startTimestamp) / config.vestingDuration;
        uint256 vestPeriod = config.startTimestamp + config.vestingDuration;

        if (block.timestamp > vestPeriod) {
            // fully vested - no penalty applies;
            return 0;
        }
        // partially vested - calculate penalty 20% of unvested tokens
        uint256 timeSinceStart = block.timestamp - config.startTimestamp;

        uint256 unvestedPortion = (config.vestingDuration - timeElapsed) * SCALE / config.vestingDuration;

        // Calculate the unvested amount
        uint256 unvestedAmount = (userAmount * unvestedPortion) / SCALE;

        // applies to claiming all tokens when some are still unvested
        penalty = (unvestedAmount * config.earlyExitPenalty) / 100;

        // TODO: Edits need to be done when calculateVestedAmount and userAllocation functions are added
    }

    // TODO: We need a calculateVestedAmount function to manage calculations
    // TODO: We need a UsersAllocation function to manage user funds and calculations

    function startVesting(uint256 _dropID, address recipient, uint256 amount, bytes32[] memory merkleProof) public {}
    function withdrawVestedTokens(uint256 _dropID) public {}
}
