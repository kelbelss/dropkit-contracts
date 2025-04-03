// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract Events {
    event TestEvent();
    event MinEarlyExitPenaltySet(uint256 newMinEarlyExitPenalty);
    event CreationPriceSet(uint256 newCreationPrice);
    event ActivationDeadlineSet(uint256 newActivationDeadline);
    event ClaimFeeSet(uint256 newClaimFee);
    event AdminFeesWithdrawn(uint256 dropID, address recipient, address tokenAddr, uint256 feesToWithdraw);
    event DropCreated(
        uint256 indexed dropID,
        address indexed token,
        uint256 totalAmount,
        uint256 earlyExitPenalty,
        uint256 startTimestamp,
        uint256 vestingDuration
    );
    event DropActivated(uint256 indexed dropID, address indexed token, address indexed recipient, uint256 amount);
    event AirdropTokensWithdrawn(uint256 indexed dropID, address indexed recipient, uint256 amountToWithdraw);
}
