// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Merkle} from "murky/Merkle.sol";
import {DropKit} from "src/DropKit.sol";
import {TransparentUpgradeableProxy} from "openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Storage, DropConfig, DropVars, Recipient} from "src/Storage.sol";
import {IDropKit} from "../../src/interfaces/IDropKit.sol";

contract BaseTest is Test {
    DropKit internal dropKit;
    IDropKit internal iDropKit;
    Merkle internal merkle;
    ProxyAdmin internal proxyAdmin;
    TransparentUpgradeableProxy internal proxy;

    // Accounts
    address GOV = makeAddr("GOV");
    address DROP_CREATOR = makeAddr("DROP CREATOR");
    address ALICE = makeAddr("ALICE");
    address BOB = makeAddr("BOB");
    address CHAD = makeAddr("CHAD");

    // Amounts
    uint256 totalDropAmount = 1000e18;
    uint256 aliceAmount = 600e18;
    uint256 bobAmount = 300e18;
    uint256 chadAmount = 100e18;

    bytes32[] hashedMerkleItems;
    bytes32 merkleRoot;

    string tokenName = "TestToken";
    string tokenSymbol = "TT";
    uint256 defaultActivationDeadline = 365 days;
    uint256 defaultStartTime = block.timestamp + 1 days;
    uint256 defaultDuration = 30 days;
    uint256 earlyExitPenalty = 2e17; // 20%

    function setUp() public virtual {
        merkle = new Merkle();
        // deploy DropKit implementation
        dropKit = new DropKit();
        // deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin(address(this));

        vm.startPrank(GOV);

        // encode initializer call for DropKit
        bytes memory initData = abi.encodeWithSelector(
            IDropKit.initialize.selector,
            GOV,
            0.1e17, // minEarlyExitPenalty
            2 ether, // creationPrice
            365 days, // activationDeadline
            0.1e17 // adminPenaltyFee
        );

        // deploy the TransparentUpgradeableProxy
        proxy = new TransparentUpgradeableProxy(address(dropKit), address(proxyAdmin), initData);

        // interact with the proxy via the interface
        iDropKit = IDropKit(address(proxy));

        // Give some ETH to Alice to simulate usage
        vm.deal(DROP_CREATOR, 10 ether);

        // Build Merkle proof and claim data
        _buildHashedMerkleItems();
        _buildMerkleRootFromHashedMerkleItems();

        vm.stopPrank();
    }

    function _buildHashedMerkleItems() internal {
        hashedMerkleItems = new bytes32[](3);

        hashedMerkleItems[0] = keccak256(abi.encodePacked(ALICE, aliceAmount));
        hashedMerkleItems[1] = keccak256(abi.encodePacked(BOB, bobAmount));
        hashedMerkleItems[2] = keccak256(abi.encodePacked(CHAD, chadAmount));
    }

    function _buildMerkleRootFromHashedMerkleItems() internal {
        merkleRoot = merkle.getRoot(hashedMerkleItems);
    }

    // get merkle proof for a specific user
    function getMerkleProof(address user, uint256 amount) internal view returns (bytes32[] memory) {
        bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        uint256 index = type(uint256).max;

        // Find the index of the leaf in our hashedMerkleItems
        for (uint256 i = 0; i < hashedMerkleItems.length; i++) {
            if (hashedMerkleItems[i] == leaf) {
                index = i;
                break;
            }
        }

        require(index != type(uint256).max, "User not in merkle tree");
        return merkle.getProof(hashedMerkleItems, index);
    }

    // verify a merkle proof
    function verifyMerkleProof(address user, uint256 amount, bytes32[] memory proof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        return merkle.verifyProof(merkleRoot, proof, leaf);
    }
}
