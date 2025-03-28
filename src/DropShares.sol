// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Storage} from "./Storage.sol";

/// @title DropShares
/// @author
/// @notice The logic and functions related to the ERC-4626 style vault shares of drops.
abstract contract DropShares is Storage {
    // ------------------------------------------------------------ //
    //                     EXTERNAL FUNCTIONS                       //
    // ------------------------------------------------------------ //

    /// @notice Returns the name of a drop, given its ID.
    function name(uint256 dropID) public view returns (string memory) {
        return dropConfigs[dropID].tokenName; // TODO - check?
    }

    /// @notice Returns the symbol of a drop, given its ID.
    function symbol(uint256 dropID) public view returns (string memory) {
        return dropConfigs[dropID].tokenSymbol; // TODO - check?
    }

    function decimals() public pure returns (uint8) {
        // TODO revert in createDrop if token decimals != 18. Only 18 decimals supported
        return 18;
    }

    /// @notice Returns the address of the underlying ERC20 token of a drop, given its ID.
    function asset(uint256 dropID) public view returns (address) {
        return dropConfigs[dropID].token;
    }

    /// @notice Returns an account's total (vested and unvested) balance of shares in a drop.
    function balanceOf(uint256 dropID, address account) public view returns (uint256) {
        return recipients[dropID][account].sharesRemaining;
    }

    /// @notice Returns the total supply of shares of a drop.
    function totalSupply(uint256 dropID) public view returns (uint256) {
        return dropVars[dropID].totalShares;
    }

    /// @notice Returns the total amount of the underlying ERC20 token held by a drop.
    function totalAssets(uint256 dropID) public view returns (uint256) {
        return dropVars[dropID].totalAssets;
    }

    /// @notice Converts an amount of a drop's underlying ERC20 token to its shares.
    function convertToShares(uint256 dropID, uint256 amount) public view returns (uint256) {
        return _convertToShares(dropID, amount);
    }

    /// @notice Converts an amount of a drop's shares to its underlying ERC20 token.
    function convertToAsset(uint256 dropID, uint256 shares) public view returns (uint256) {
        return _convertToAsset(dropID, shares);
    }

    /// @notice Returns the maximum amount of the underlying ERC20 token that can be withdrawn by an account. Takes early exit penalty into account.
    function maxWithdraw(uint256 dropID, address account) public view returns (uint256) {
        // TODO
    }

    // ------------------------------------------------------------ //
    //                     INTERNAL FUNCTIONS                       //
    // ------------------------------------------------------------ //

    function _convertToShares(uint256 dropID, uint256 amount) internal view returns (uint256) {
        // TODO account for 0 and decimals
        return (amount * dropVars[dropID].totalShares) / dropVars[dropID].totalAssets;
    }

    function _convertToAsset(uint256 dropID, uint256 shares) internal view returns (uint256) {
        // TODO account for 0 and decimals
        return (shares * dropVars[dropID].totalAssets) / dropVars[dropID].totalShares;
    }
}
