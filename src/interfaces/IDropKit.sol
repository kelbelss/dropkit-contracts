// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IDropKit {
    /// @notice Sets the minimum allowed early exit penalty.
    /// @param newMinEarlyExitPenalty The new minimum early exit penalty (scaled by 1e18).
    function setMinEarlyExitPenalty(uint256 newMinEarlyExitPenalty) external;

    /// @notice Sets the creation price for airdrops.
    /// @param newCreationPrice The new creation price for airdrops (in native token).
    function setCreationPrice(uint256 newCreationPrice) external;

    /// @notice Sets the global activation deadline duration for airdrops.
    /// @param newActivationDeadline The new activation deadline duration (in seconds).
    function setActivationDeadline(uint256 newActivationDeadline) external;

    /// @notice Sets the global claim fee for recipient claims.
    /// @param newClaimFee The new claim fee.
    function setClaimFee(uint256 newClaimFee) external;

    /// @notice Sets the percentage of the penalty fee that goes to the admin/owner.
    /// @param newAdminPenaltyFee The new admin penalty fee share (scaled by SCALE).
    function setAdminPenaltyFee(uint256 newAdminPenaltyFee) external;

    /// @notice Allows the owner to claim penalty fees collected by the contract for a specific drop.
    /// @param dropID The ID of the drop to withdraw fees from.
    /// @param recipient The address to send the fees to.
    function withdrawAdminPenaltyFees(uint256 dropID, address recipient) external;

    // --- Other Core Functions ---

    /// @notice Allows the owner to withdraw accumulated drop creation fees (paid in native token).
    /// @param recipient The address to send the native tokens to.
    function withdrawCreationFees(address payable recipient) external payable;

    /// @notice Creates a new airdrop.
    /// @param token Address of the ERC20 token being dropped.
    /// @param tokenName Name of the token (for potential display purposes).
    /// @param tokenSymbol Symbol of the token (for potential display purposes).
    /// @param merkleRoot The root hash of the Merkle tree containing eligible recipients and amounts.
    /// @param earlyExitPenalty The penalty rate for withdrawing unvested tokens (scaled by SCALE).
    /// @param startTimestamp The Unix timestamp when the drop starts (vesting begins).
    /// @param vestingDuration The duration (in seconds) over which the tokens vest linearly.
    /// @param totalAmountToDrop The total amount of tokens being deposited for this drop.
    /// @return dropID The ID assigned to the newly created drop.
    function createDrop(
        address token,
        string memory tokenName,
        string memory tokenSymbol,
        bytes32 merkleRoot,
        uint256 earlyExitPenalty,
        uint256 startTimestamp,
        uint256 vestingDuration,
        uint256 totalAmountToDrop
    ) external payable returns (uint256 dropID);

    /// @notice Activates the airdrop for the calling recipient.
    /// @param dropID The ID of the airdrop to activate.
    /// @param amount The amount of tokens the recipient is eligible for (from Merkle leaf).
    /// @param merkleProof The Merkle proof demonstrating the recipient's eligibility.
    function activateDrop(uint256 dropID, uint256 amount, bytes32[] calldata merkleProof) external;

    /// @notice Verifies a Merkle proof for a given recipient and amount without changing state.
    /// @param dropID The ID of the airdrop.
    /// @param recipient The address to check.
    /// @param amount The amount to check.
    /// @param merkleProof The Merkle proof.
    /// @return True if the proof is valid, false otherwise.
    function verifyMerkleProof(uint256 dropID, address recipient, uint256 amount, bytes32[] calldata merkleProof)
        external
        view
        returns (bool);

    /// @notice Allows a recipient to withdraw their vested/unvested airdrop tokens.
    /// @param dropID The ID of the airdrop to withdraw from.
    /// @param sharesRequested The amount of *shares* the recipient wants to withdraw.
    /// @return assetsWithdrawn The amount of *assets* actually transferred after penalties.
    function withdraw(uint256 dropID, uint256 sharesRequested) external returns (uint256 assetsWithdrawn);
}
