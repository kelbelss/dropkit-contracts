// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Merkle} from "murky/Merkle.sol";
import {DropKit} from "src/DropKit.sol";
import {Storage, Config} from "src/Storage.sol";

contract BaseTest is Test {
    DropKit dropKit;
    Merkle merkle;

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

    uint256 defaultClaimDeadline = 365 days;
    uint256 defaultStartTime = block.timestamp + 1 days;

    function setUp() public virtual {
        merkle = new Merkle();

        // Deploy and set up GOV functions
        vm.startPrank(GOV);
        dropKit = new DropKit();
        vm.deal(DROP_CREATOR, 10 ether);
        dropKit.setClaimDeadline(defaultClaimDeadline);
        dropKit.setCreationPrice(2 ether);
        dropKit.setMinEarlyExitPenalty(1e17);
        vm.stopPrank();

        // Build Merkle proof and claim data
        _buildHashedMerkleItems();
        _buildMerkleRootFromHashedMerkleItems();
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
