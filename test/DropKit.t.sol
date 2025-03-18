// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {BaseTest} from "./base/BaseTest.t.sol";
import {DropKit} from "../src/DropKit.sol";
import {Storage, Config} from "../src/Storage.sol";
import {MockToken} from "./MockERC20.sol";

contract TestDropKit is BaseTest {
    uint256 dropID;
    MockToken mockToken;

    function setUp() public override {
        super.setUp();
        mockToken = new MockToken("Mock Token", "MT");
        mockToken.mint(DROP_CREATOR, totalDropAmount);
    }

    function test_DropKit_createDrop() public {
        vm.startPrank(DROP_CREATOR);

        // Approve dropkit contract to transfer creator tokens
        mockToken.approve(address(dropKit), totalDropAmount);

        // Create a drop
        dropID = dropKit.createDrop{value: 2 ether}(
            address(mockToken), merkleRoot, totalDropAmount, 10, defaultStartTime, 30 days
        );

        vm.stopPrank();

        // Check drop details
        (address token, bytes32 root, uint256 total, uint256 penalty, uint256 start, uint256 duration) =
            dropKit.drops(dropID);

        assertEq(token, address(mockToken));
        assertEq(root, merkleRoot);
        assertEq(total, totalDropAmount);
        assertEq(penalty, 10);
        assertEq(start, defaultStartTime);
        assertEq(duration, 30 days);

        assertEq(mockToken.balanceOf(address(dropKit)), totalDropAmount);
    }

    function test_DropKit_claimAirdrop() public {
        // Create a drop
        vm.startPrank(DROP_CREATOR);
        // Approve dropkit contract to transfer creator tokens
        mockToken.approve(address(dropKit), totalDropAmount);
        dropID = dropKit.createDrop{value: 2 ether}(
            address(mockToken), merkleRoot, totalDropAmount, 10, defaultStartTime, 30 days
        );
        vm.stopPrank();
        vm.warp(defaultStartTime);

        // Claim airdrop and pull merkleProof
        vm.startPrank(BOB);

        bytes32[] memory proof = getMerkleProof(address(BOB), bobAmount);

        dropKit.claimAirdrop(dropID, bobAmount, proof);
        vm.stopPrank();

        // console.log("ALICE: ", address(ALICE).balance);

        assertEq(mockToken.balanceOf(address(BOB)), bobAmount);
        assertEq(mockToken.balanceOf(address(dropKit)), totalDropAmount - bobAmount);
    }
}
