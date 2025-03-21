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
            address(mockToken), merkleRoot, totalDropAmount, 2e17, defaultStartTime, 30 days
        );

        vm.stopPrank();

        // Check drop details
        (address token, bytes32 root, uint256 total, uint256 penalty, uint256 start, uint256 duration) =
            dropKit.drops(dropID);

        assertEq(token, address(mockToken));
        assertEq(root, merkleRoot);
        assertEq(total, totalDropAmount);
        assertEq(penalty, 2e17);
        assertEq(start, defaultStartTime);
        assertEq(duration, 30 days);

        assertEq(mockToken.balanceOf(address(dropKit)), totalDropAmount);
    }

    function test_DropKit_activateDrop() public {
        // Create a drop
        vm.startPrank(DROP_CREATOR);
        // Approve dropkit contract to transfer creator tokens
        mockToken.approve(address(dropKit), totalDropAmount);
        dropID = dropKit.createDrop{value: 2 ether}(
            address(mockToken), merkleRoot, totalDropAmount, 2e17, defaultStartTime, 30 days
        );
        vm.stopPrank();
        vm.warp(defaultStartTime);

        // pull merkleProof
        vm.startPrank(BOB);
        bytes32[] memory proof = getMerkleProof(address(BOB), bobAmount);

        // activate drop
        dropKit.activateDrop(dropID, bobAmount, proof);
        vm.stopPrank();

        // Check recipient details are set
        (uint256 totalAmountDropped, uint256 totalAmountRemaining, bool hasActivatedDrop, bool hasWithdrawnFullDrop) =
            dropKit.recipients(address(BOB), dropID);

        assertEq(totalAmountDropped, bobAmount);
        assertEq(totalAmountRemaining, bobAmount);
        assertEq(hasActivatedDrop, true);
        assertEq(hasWithdrawnFullDrop, false);
    }

    function test_DropKit_withdrawAirdropTokens() public {
        // Create a drop
        vm.startPrank(DROP_CREATOR);
        // Approve dropkit contract to transfer creator tokens
        mockToken.approve(address(dropKit), totalDropAmount);
        dropID = dropKit.createDrop{value: 2 ether}(
            address(mockToken), merkleRoot, totalDropAmount, 2e17, defaultStartTime, 100 days
        );
        vm.stopPrank();
        vm.warp(defaultStartTime);

        // pull merkleProof
        vm.startPrank(BOB);
        bytes32[] memory proof = getMerkleProof(address(BOB), bobAmount);

        // activate drop
        dropKit.activateDrop(dropID, bobAmount, proof);
        // vm.stopPrank();

        vm.warp(defaultStartTime + 80 days);
        // total is 1000e18, bob has 300e18

        // withdraw airdrop tokens
        dropKit.withdrawAirdropTokens(dropID, bobAmount);

        vm.stopPrank();

        // Check recipient details
        (uint256 totalAmountDropped, uint256 totalAmountRemaining, bool hasActivatedDrop, bool hasWithdrawnFullDrop) =
            dropKit.recipients(address(BOB), dropID);

        assertEq(totalAmountDropped, bobAmount);
        assertEq(totalAmountRemaining, 0);
        console.log("Bob's balance is: ", mockToken.balanceOf(address(BOB)));
        assertEq(hasActivatedDrop, true);
        assertEq(hasWithdrawnFullDrop, true);
        console.log("dropkit balance", mockToken.balanceOf(address(dropKit)));
    }
}
