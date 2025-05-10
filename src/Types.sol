// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Drop settings that will not change once set
struct DropConfig {
    address dropCreator;
    address token;
    string tokenName; // bottom
    string tokenSymbol;
    bytes32 merkleRoot;
    uint256 earlyExitPenalty;
    uint256 startTimestamp;
    uint256 vestingDuration;
}

// Drop variables that will change frequently
struct DropVars {
    uint256 totalAssets;
    uint256 totalShares;
    uint256 totalSharesActivated;
    uint256 dropKitFees;
}

struct Recipient {
    uint256 sharesDropped;
    uint256 sharesRemaining;
    bool hasActivatedDrop;
}
