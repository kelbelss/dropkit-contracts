// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

struct Config {
    address token;
    bytes32 merkleRoot;
    uint256 totalAmount;
    uint256 minEarlyExitPenalty;
    uint256 startDate;
    uint256 vestingPeriod;
}
