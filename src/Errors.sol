// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract Errors {
    error TestError();
    error InsufficientPayment();
    error InvalidStartDate();
    // error  MustHave18Decimals();
    error EarlyExitPenaltyTooLow();
    error EarlyExitPenaltyTooHigh();
    error FeeNotTransferred();
    error AirdropNotStarted(uint256 startTime);
    error DropExpired(uint256 endTime);
    error AlreadyActivated();
    error NotEligibleForAirdrop();
    error NotActivated();
    error AlreadyWithdrawn();
    error InsufficientFunds();
    error VestingPeriodIsComplete();
}
