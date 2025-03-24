// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

struct Config {
    address token;
    bytes32 merkleRoot;
    uint256 totalAmount;
    uint256 earlyExitPenalty;
    uint256 startTimestamp;
    uint256 vestingDuration;
}

struct Recipient {
    uint256 totalAmountDropped;
    uint256 totalAmountRemaining;
    bool hasActivatedDrop;
}
