// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract Errors {
    error TestError();
    error InsufficientPayment();
    error InvalidStartDate();
    error EarlyExitPenaltyTooLow();
    error EarlyExitPenaltyTooHigh();
    error FeeNotTransferred();
    error DropExpired();
    error AlreadyClaimed();
    error NotEligibleForAirdrop();
}
