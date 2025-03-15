// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract DropKit {
    // Events, errors, constants files

    // VARIABLES
    uint256 public minEarlyExitPenaltyAllowed;
    uint256 public creationPrice;
    uint256 public claimDeadline;
    uint256 public totalFees;

    struct Config {
        address token;
        bytes32 merkleRoot;
        uint256 totalAmount;
        uint256 minEarlyExitPenalty;
        uint256 startDate;
        uint256 vestingPeriod;
    }

    constructor() {}

    // ADMIN
    function setMinEarlyExitPenaltyAllowed(uint256 newMinEarlyExitPenaltyAllowed) public {}
    function setCreationPrice(uint256 newCreationPrice) public {}
    function setClaimDeadline(uint256 newClaimDeadline) public {} // one year
    function claimFees(address token) public {}

    // DROPPER
    function createDrop(
        address token,
        bytes32 merkleRoot,
        uint256 totalAmount,
        uint256 minEarlyExitPenalty,
        uint256 startDate,
        uint256 vestingPeriod
    ) public returns (uint256 dropID) {}

    function withdrawUnclaimedTokens(uint256 _dropID) public {} // only after a year

    // RECIPIENT
    function claimAirdrop(uint256 _dropID, bytes32[] memory merkleProof) public {}
    function startVesting(uint256 _dropID, address recipient, uint256 amount, bytes32[] memory merkleProof) public {}
    function withdrawVestedTokens(uint256 _dropID) public {}
}
