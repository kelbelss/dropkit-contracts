// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Drop settings that will not change once set
struct DropConfig {
    address token;
    bytes32 merkleRoot;
    uint256 earlyExitPenalty;
    uint256 startTimestamp;
    uint256 vestingDuration;
    string name;
    string symbol;
}

// Drop variables that will change frequently
struct DropVars {
    uint256 totalAssets;
    uint256 totalShares;
}

struct Recipient {
    uint256 totalAmountDropped;
    uint256 totalAmountRemaining;
    bool hasActivatedDrop;
}
