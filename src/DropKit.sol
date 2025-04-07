// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";

import {DropShares} from "./DropSharesUpgradeable.sol";
import {DropConfig, DropVars, Recipient} from "./Types.sol";
import {IDropKit} from "./interfaces/IDropKit.sol";

// TODO remove
import "forge-std/Test.sol";

/// @title DropKit (Transparent Proxy Implementation)
/// @author kelbels
/// @notice Logic contract for an upgradeable airdrop system using the Transparent Proxy Pattern.
/// @dev Handles ERC20 token drops with vesting. Creation and claim fees are paid in the native chain token.
///      Must be deployed behind a TransparentUpgradeableProxy managed by a ProxyAdmin.
contract DropKit is Initializable, OwnableUpgradeable, IDropKit, DropShares {
    using SafeTransferLib for address;
    using SafeTransferLib for IERC20;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        uint256 _initialMinEarlyExitPenalty,
        uint256 _initialCreationPrice,
        uint256 _initialActivationDeadline,
        uint256 _initialClaimFee,
        uint256 _initialAdminPenaltyFee
    ) public initializer {
        // Use the initializer modifier
        require(initialOwner != address(0), "ZeroAddress");

        // --- Initialize Inherited Contracts ---
        __Ownable_init(initialOwner);
        // IMPORTANT: Call the initializer for DropShares - adjust args
        // __DropShares_init(/* pass args needed by DropShares initializer */);

        setMinEarlyExitPenalty(_initialMinEarlyExitPenalty);
        setCreationPrice(_initialCreationPrice);
        setActivationDeadline(_initialActivationDeadline);
        setClaimFee(_initialClaimFee);
        setAdminPenaltyFee(_initialAdminPenaltyFee);
    }

    // ADMIN FUNCTIONS

    /// @notice Sets the minimum allowed early exit penalty.
    /// @dev Only callable by the contract owner.
    /// @param newMinEarlyExitPenalty The new minimum early exit penalty (scaled by 1e18).
    function setMinEarlyExitPenalty(uint256 newMinEarlyExitPenalty) public override onlyOwner {
        minEarlyExitPenalty = newMinEarlyExitPenalty;
        emit MinEarlyExitPenaltySet(newMinEarlyExitPenalty);
    }

    /// @notice Sets the creation price for airdrops.
    /// @dev Only callable by the contract owner.  This is paid in MON.
    /// @param newCreationPrice The new creation price for airdrops.
    function setCreationPrice(uint256 newCreationPrice) public override onlyOwner {
        creationPrice = newCreationPrice;
        emit CreationPriceSet(newCreationPrice);
    }

    /// @notice Sets the global claim deadline for airdrops.
    /// @dev Only callable by the contract owner.  This is a duration (in seconds) after the airdrop's start timestamp.
    /// @param newActivationDeadline The new claim deadline duration (in seconds).
    function setActivationDeadline(uint256 newActivationDeadline) public override onlyOwner {
        activationDeadline = newActivationDeadline;
        emit ActivationDeadlineSet(newActivationDeadline);
    }

    /// @notice Sets the global claim fee for recipient claims.
    /// @dev Only callable by the contract owner.
    function setClaimFee(uint256 newClaimFee) public override onlyOwner {
        claimFee = newClaimFee;
        emit ClaimFeeSet(newClaimFee);
    }

    function setAdminPenaltyFee(uint256 newAdminPenaltyFee) public override onlyOwner {
        adminPenaltyFee = newAdminPenaltyFee;
    }

    /// @notice Allows the owner to claim fees collected by the contract.
    /// @dev Only callable by the contract owner.
    function withdrawAdminPenaltyFees(uint256 dropID, address recipient) public override onlyOwner {
        // TODO: drop specific - needs to account for 10% penalty fees?

        require(recipient != address(0), "ZeroAddress"); // TODO
        DropVars storage vars = dropVars[dropID];
        address tokenAddr = dropConfigs[dropID].token;

        uint256 feesToWithdraw = vars.dropKitFees;

        require(feesToWithdraw > 0, "NoFeesToWithdraw");

        vars.dropKitFees = 0;

        IERC20(tokenAddr).safeTransfer(recipient, feesToWithdraw);

        emit AdminFeesWithdrawn(dropID, recipient, tokenAddr, feesToWithdraw);
    }

    function withdrawCreationFees(address payable recipient) public payable onlyOwner {
        // TODO: MON - 2 mon per drop created
        require(recipient != address(0), "ZeroAddress"); // TODO
    }

    // DROPPER FUNCTIONS

    function createDrop(
        address token,
        string memory tokenName,
        string memory tokenSymbol,
        bytes32 merkleRoot,
        uint256 earlyExitPenalty,
        uint256 startTimestamp,
        uint256 vestingDuration,
        uint256 totalAmountToDrop
    ) public payable returns (uint256 dropID) {
        // assume the dropper is using their own token

        // TODO implement feature where droppers can create a token
        // TODO maybe check if msg.value is MON?

        // Require payment for drop creation
        require(msg.value == creationPrice, InsufficientPayment());

        // Require token decimals to be 18 - call decimal function on IERC20
        // TODO revert in createDrop if token decimals != 18. Only 18 decimals supported
        // require(decimals == 18, MustHave18Decimals());

        // Check that the start date is in the future
        require(startTimestamp >= block.timestamp, InvalidStartDate());

        // Check early exit penalty
        require(earlyExitPenalty >= minEarlyExitPenalty, EarlyExitPenaltyTooLow());
        require(earlyExitPenalty <= MAX_EARLY_EXIT_PENALTY_ALLOWED, EarlyExitPenaltyTooHigh());

        // transfer token to this contract
        token.safeTransferFrom(msg.sender, address(this), totalAmountToDrop);

        // create a new drop
        DropConfig memory config = DropConfig({
            dropCreator: msg.sender,
            token: token,
            tokenName: tokenName,
            tokenSymbol: tokenSymbol,
            merkleRoot: merkleRoot,
            earlyExitPenalty: earlyExitPenalty,
            startTimestamp: startTimestamp,
            vestingDuration: vestingDuration
        });

        DropVars memory vars = DropVars({
            totalAssets: totalAmountToDrop,
            totalShares: totalAmountToDrop,
            totalSharesActivated: 0,
            dropKitFees: 0
        });

        // drop ID settings
        dropID = ++dropCount;
        dropConfigs[dropID] = config;
        dropVars[dropID] = vars;

        // emit event
        // TODO: update event
        emit DropCreated(dropID, token, totalAmountToDrop, earlyExitPenalty, startTimestamp, vestingDuration);
    }

    // RECIPIENT FUNCTIONS

    /// @notice Activates the airdrop for the calling recipient.
    /// @dev Checks eligibility via Merkle proof and prevents double-claiming.  The airdrop must have started.
    /// @param dropID The ID of the airdrop to activate.
    /// @param amount The amount of tokens the recipient is claiming, must match the amount in the Merkle proof.
    /// @param merkleProof The Merkle proof demonstrating the recipient's eligibility.
    /// @dev Emits a `DropActivated` event.
    function activateDrop(uint256 dropID, uint256 amount, bytes32[] memory merkleProof) public {
        DropConfig memory config = dropConfigs[dropID];
        // storage for changing state?
        Recipient storage recipient = recipients[dropID][msg.sender];

        // Check if the drop is active
        require(block.timestamp >= config.startTimestamp, AirdropNotStarted(config.startTimestamp));
        require(
            block.timestamp < config.startTimestamp + activationDeadline,
            DropExpired(config.startTimestamp + activationDeadline)
        );

        // Check if the recipient has already claimed
        require(!recipient.hasActivatedDrop, AlreadyActivated());

        // Check if the recipient is in the merkle tree
        bool verified = _verifyMerkleProof(dropID, msg.sender, amount, merkleProof);
        require(verified, NotEligibleForAirdrop());

        // update the activated status and amount mapping
        recipient.hasActivatedDrop = true;
        recipient.sharesDropped = amount;
        recipient.sharesRemaining = amount;
        dropVars[dropID].totalSharesActivated += amount;

        emit DropActivated(dropID, config.token, msg.sender, amount);
    }

    function verifyMerkleProof(uint256 dropID, address recipient, uint256 amount, bytes32[] memory merkleProof)
        external
        view
        returns (bool)
    {
        return _verifyMerkleProof(dropID, recipient, amount, merkleProof);
    }

    // Check if the recipient is in the merkle tree
    function _verifyMerkleProof(uint256 dropID, address recipient, uint256 amount, bytes32[] memory merkleProof)
        internal
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(recipient, amount));
        return MerkleProofLib.verify(merkleProof, dropConfigs[dropID].merkleRoot, leaf);
    }

    /// @notice Allows a recipient to withdraw airdrop.
    /// @dev Calculates vested and unvested amounts, applies penalties for early withdrawals of unvested tokens, and transfers the tokens.
    /// @param dropID The ID of the airdrop to withdraw from.
    /// @param sharesRequested The amount of shares the recipient wants to convert to withdraw.
    /// @dev Emits an `AirdropTokensWithdrawn` event.
    function withdraw(uint256 dropID, uint256 sharesRequested) public returns (uint256 assetsWithdrawn) {
        DropConfig memory config = dropConfigs[dropID];
        Recipient storage recipient = recipients[dropID][msg.sender];
        DropVars storage vars = dropVars[dropID];

        // Check if the recipient has not activated or already withdrawn
        require(recipient.hasActivatedDrop, NotActivated());
        require(recipient.sharesRemaining != 0, AlreadyWithdrawn());
        // Check if the recipient has enough funds owed
        require(sharesRequested <= recipient.sharesRemaining, InsufficientFunds());

        // TODO this needs to be converted to the asset value, not the share value
        uint256 sharesWithdrawn = _calculateSharesToWithdraw(dropID, msg.sender, sharesRequested);

        assetsWithdrawn = convertToAsset(dropID, sharesWithdrawn);

        recipient.sharesRemaining -= sharesRequested;
        vars.totalAssets -= assetsWithdrawn;
        vars.totalShares -= sharesRequested;

        // transfer tokens to the recipient
        config.token.safeTransfer(msg.sender, assetsWithdrawn);
        emit AirdropTokensWithdrawn(dropID, msg.sender, sharesWithdrawn); // TODO update event emitted
    }

    // INTERNAL FUNCTIONS

    /// @notice Internal function to handle withdrawal logic, including penalty calculation.
    /// @param dropID The ID of the airdrop.
    /// @param sharesRequested The amount the user wants to withdraw.
    /// @return sharesOut The actual amount withdrawn after penalties are applied.
    function _calculateSharesToWithdraw(uint256 dropID, address recipientAddr, uint256 sharesRequested)
        internal
        returns (uint256 sharesOut)
    {
        Recipient storage recipient = recipients[dropID][recipientAddr];
        DropVars storage vars = dropVars[dropID];

        uint256 totalVestedShares = _getVestedShares(dropID, recipient.sharesDropped);

        // users remaining balance - unvested balance
        uint256 vestedBalanceAvailable = recipient.sharesRemaining - (recipient.sharesDropped - totalVestedShares);

        // if recipient is withdrawing less than/equal to the balance that has vested, ie. no penalty
        if (sharesRequested <= vestedBalanceAvailable) {
            return sharesRequested;
        }

        // if recipient is withdrawing more than the balance that has vested
        uint256 unvestedSharesRequested = sharesRequested - vestedBalanceAvailable;

        uint256 penaltyShares = _getPenaltyShares(dropID, unvestedSharesRequested);

        uint256 adminFeeShares = (penaltyShares * adminPenaltyFee) / SCALE;
        uint256 adminFeeAssets = convertToAsset(dropID, adminFeeShares);

        vars.dropKitFees += adminFeeAssets;
        vars.totalAssets -= adminFeeAssets;

        sharesOut = vestedBalanceAvailable + (unvestedSharesRequested - penaltyShares);

        // make sure amount out is not too much
        assert(sharesOut <= sharesRequested);
    }

    /// @notice Calculates the penalty for withdrawing unvested tokens.
    /// @param dropID The ID of the airdrop.
    /// @param unvestedSharesRequested The amount of unvested tokens being withdrawn.
    /// @return penaltyShares The calculated penalty (scaled by 1e18).
    function _getPenaltyShares(uint256 dropID, uint256 unvestedSharesRequested)
        internal
        view
        returns (uint256 penaltyShares)
    {
        // applies to claiming tokens when some are still unvested
        penaltyShares = (unvestedSharesRequested * dropConfigs[dropID].earlyExitPenalty) / SCALE;
    }

    function _getVestedShares(uint256 dropID, uint256 totalUserShares) internal view returns (uint256 vestedShares) {
        DropConfig memory config = dropConfigs[dropID];

        if (config.vestingDuration == 0) {
            return totalUserShares;
        }

        // calculate time since the start of the vesting duration
        uint256 timeSinceStart = 0;
        if (block.timestamp >= config.startTimestamp) {
            timeSinceStart = block.timestamp - config.startTimestamp;
        }

        // has not started
        if (timeSinceStart == 0) {
            return 0;
        }

        // fully vested
        if (timeSinceStart >= config.vestingDuration) {
            return totalUserShares;
        }

        // calculate the vested amount with percentage
        vestedShares = (totalUserShares * timeSinceStart) / config.vestingDuration;

        // TODO test new logic update
    }

    uint256[50] private __gap;
}
