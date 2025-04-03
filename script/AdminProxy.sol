// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// EXAMPLE FOR DEPLOYMENT SCRIPT
contract DeployProxyAdmin {
    ProxyAdmin public proxyAdminInstance;

    // In a deployment script, you would simply deploy ProxyAdmin directly.
    // The deployer address becomes the owner of the ProxyAdmin instance.
    constructor() {
        proxyAdminInstance = new ProxyAdmin(msg.sender);
        // Now, msg.sender is the owner of proxyAdminInstance
        // You can transfer ownership later using proxyAdminInstance.transferOwnership(newOwner)
    }

    function getProxyAdminAddress() external view returns (address) {
        return address(proxyAdminInstance);
    }
}
