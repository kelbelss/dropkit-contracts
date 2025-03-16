// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Storage} from "./Storage.sol";
import {Config} from "./Types.sol";
import {IDropKit} from "./interfaces/IDropKit.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

// need constants?

contract DropKit is IDropKit, Storage, Ownable {
    using SafeTransferLib for address;

    // will be imported soon
    uint256 constant MAX_EARLY_EXIT_PENALTY_ALLOWED = 10000;

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
        // MON - needs to account for creationFees and 10% penalty fees?
    }

    // DROPPER
    function createDrop(
        address token,
        bytes32 merkleRoot,
        uint256 totalAmount,
        uint256 earlyExitPenalty,
        uint256 startDate,
        uint256 vestingPeriod
    ) public payable returns (uint256 dropID) {
        // assume the dropper is using their own token

        // maybe check if msg.value is MON?

        // Require payment for drop creation
        require(msg.value >= creationPrice, InsufficientPayment());

        // Check that the start date is in the future
        require(startDate >= block.timestamp, InvalidStartDate());

        // Check early exit penalty
        require(earlyExitPenalty >= minEarlyExitPenaltyAllowed, EarlyExitPenaltyTooLow());
        require(earlyExitPenalty <= MAX_EARLY_EXIT_PENALTY_ALLOWED, EarlyExitPenaltyTooHigh());

        // create a new drop
        Config memory config = Config({
            token: token,
            merkleRoot: merkleRoot,
            totalAmount: totalAmount,
            earlyExitPenalty: earlyExitPenalty,
            startDate: startDate,
            vestingPeriod: vestingPeriod
        });

        // drop ID settings

        dropID = nextDropID;
        drops[dropID] = config;
        dropCreator[dropID] = msg.sender;
        dropClaimedAmount[dropID] = 0;
        nextDropID++;

        totalFees += creationPrice;

        // refund excess MON sent accidently
        // if (msg.value > creationPrice) {
        //     payable(msg.sender).transfer(msg.value - creationPrice);
        // }

        // emit event
        emit DropCreated(dropID, token, totalAmount);

        return dropID;
    }

    function withdrawUnclaimedTokens(uint256 _dropID) public {} // only after a year

    // RECIPIENT
    function claimAirdrop(uint256 _dropID, bytes32[] memory merkleProof) public {}
    function startVesting(uint256 _dropID, address recipient, uint256 amount, bytes32[] memory merkleProof) public {}
    function withdrawVestedTokens(uint256 _dropID) public {}
}
