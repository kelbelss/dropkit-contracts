// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract Events {
    event TestEvent();
    event DropCreated(
        uint256 indexed dropID,
        address indexed token,
        uint256 totalAmount,
        uint256 earlyExitPenalty,
        uint256 startTimestamp,
        uint256 vestingDuration
    );
    event DropClaimed(uint256 indexed dropID, address indexed token, address indexed recipient, uint256 amount);
}
