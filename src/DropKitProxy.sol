// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DropKit} from "./DropKit.sol";

// EXAMPLE PROXY CONTRACT
// deploy TransparentUpgradeableProxy using a script.
contract DeployDropKitProxy {
    address public dropKitProxyAddress;

    //addresses need to be provided during deployment
    address immutable dropKitV1ImplementationAddress; // Address of deployed DropKit logic contract
    address immutable proxyAdminAddress; // Address of deployed ProxyAdmin contract
    // the initialization parameters for DropKit
    address immutable initialOwner;
    uint256 immutable initialMinEarlyExitPenalty;
    uint256 immutable initialCreationPrice;
    uint256 immutable initialActivationDeadline;
    uint256 immutable initialClaimFee;
    uint256 immutable initialAdminPenaltyFee;

    constructor(
        address _dropKitV1ImplementationAddress,
        address _proxyAdminAddress,
        address _initialOwner,
        uint256 _initialMinEarlyExitPenalty,
        uint256 _initialCreationPrice,
        uint256 _initialActivationDeadline,
        uint256 _initialClaimFee,
        uint256 _initialAdminPenaltyFee
    ) {
        dropKitV1ImplementationAddress = _dropKitV1ImplementationAddress;
        proxyAdminAddress = _proxyAdminAddress;
        initialOwner = _initialOwner;
        initialMinEarlyExitPenalty = _initialMinEarlyExitPenalty;
        initialCreationPrice = _initialCreationPrice;
        initialActivationDeadline = _initialActivationDeadline;
        initialClaimFee = _initialClaimFee;
        initialAdminPenaltyFee = _initialAdminPenaltyFee;

        // --- Encode the initialize() call ---
        // This is the critical part. We need to create the `_data` bytes.
        // The signature matches the initialize function in DropKit
        bytes memory initializationData = abi.encodeWithSignature(
            "initialize(address,uint256,uint256,uint256,uint256,uint256)",
            initialOwner,
            initialMinEarlyExitPenalty,
            initialCreationPrice,
            initialActivationDeadline,
            initialClaimFee,
            initialAdminPenaltyFee
        );

        // --- Deploy the Proxy ---
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            dropKitV1ImplementationAddress, // Initial logic contract address
            proxyAdminAddress, // Admin contract address
            initializationData // Encoded initialize() call
        );

        dropKitProxyAddress = address(proxy);

        // Now, users interact with `dropKitProxyAddress`.
        // You can cast this address to your DropKit interface:
        // DropKit dropKit = DropKit(dropKitProxyAddress);
        // dropKit.createDrop(...); // Call functions on the proxy address
    }
}
