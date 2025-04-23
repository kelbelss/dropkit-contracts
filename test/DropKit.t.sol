// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {BaseTest} from "./base/BaseTest.t.sol";
import {DropKit} from "../src/DropKit.sol";
import {Storage, DropConfig, DropVars, Recipient} from "../src/Storage.sol";
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
        mockToken.approve(address(iDropKit), totalDropAmount);

        // Create a drop
        dropID = iDropKit.createDrop{value: 2 ether}(
            address(mockToken),
            tokenName,
            tokenSymbol,
            merkleRoot,
            earlyExitPenalty,
            defaultStartTime,
            defaultDuration,
            totalDropAmount
        );

        vm.stopPrank();

        // Check drop details
        (
            address creator,
            address token,
            string memory name,
            string memory symbol,
            bytes32 root,
            uint256 penalty,
            uint256 start,
            uint256 duration
        ) = DropKit(address(proxy)).dropConfigs(dropID);

        assertEq(creator, DROP_CREATOR);
        assertEq(token, address(mockToken));
        assertEq(name, tokenName);
        assertEq(symbol, tokenSymbol);
        assertEq(root, merkleRoot);
        assertEq(penalty, earlyExitPenalty);
        assertEq(start, defaultStartTime);
        assertEq(duration, defaultDuration);

        assertEq(mockToken.balanceOf(address(iDropKit)), totalDropAmount);
    }

    function test_DropKit_activateDrop() public {
        // Create a drop
        vm.startPrank(DROP_CREATOR);
        // Approve dropkit contract to transfer creator tokens
        mockToken.approve(address(iDropKit), totalDropAmount);
        // Create a drop
        dropID = iDropKit.createDrop{value: 2 ether}(
            address(mockToken),
            tokenName,
            tokenSymbol,
            merkleRoot,
            earlyExitPenalty,
            defaultStartTime,
            defaultDuration,
            totalDropAmount
        );
        vm.stopPrank();
        vm.warp(defaultStartTime);

        // pull merkleProof
        vm.startPrank(BOB);
        bytes32[] memory proof = getMerkleProof(address(BOB), bobAmount);

        // activate drop
        iDropKit.activateDrop(dropID, bobAmount, proof);
        vm.stopPrank();

        // Check recipient details are set
        (uint256 totalAmountDropped, uint256 totalAmountRemaining, bool hasActivatedDrop) =
            DropKit(address(proxy)).recipients(dropID, address(BOB));
        assertEq(totalAmountDropped, bobAmount);
        assertEq(totalAmountRemaining, bobAmount);
        assertEq(hasActivatedDrop, true);
    }

    function test_DropKit_withdrawAirdropTokens() public {
        // Create a drop
        vm.startPrank(DROP_CREATOR);
        // Approve dropkit contract to transfer creator tokens
        mockToken.approve(address(iDropKit), totalDropAmount);
        // Create a drop
        dropID = iDropKit.createDrop{value: 2 ether}(
            address(mockToken),
            tokenName,
            tokenSymbol,
            merkleRoot,
            earlyExitPenalty,
            defaultStartTime,
            100 days,
            totalDropAmount
        );
        vm.stopPrank();
        vm.warp(defaultStartTime);

        // pull merkleProof
        vm.startPrank(BOB);
        bytes32[] memory proof = getMerkleProof(address(BOB), bobAmount);

        // activate drop
        iDropKit.activateDrop(dropID, bobAmount, proof);
        // vm.stopPrank();

        vm.warp(defaultStartTime + 100 days);
        // total is 1000e18, bob has 300e18

        // withdraw airdrop tokens
        uint256 withdrawnAmount = iDropKit.withdraw(dropID, bobAmount);

        vm.stopPrank();

        // Check recipient details
        (uint256 totalAmountDropped, uint256 totalAmountRemaining, bool hasActivatedDrop) =
            DropKit(address(proxy)).recipients(dropID, address(BOB));

        assertEq(totalAmountDropped, bobAmount);
        assertEq(totalAmountRemaining, 0);
        assertEq(hasActivatedDrop, true);

        (,,, uint256 dropKitFees) = DropKit(address(proxy)).dropVars(dropID);

        console.log("DropKit fees collected are:", dropKitFees);
        console.log("Bob's token balance is: ", mockToken.balanceOf(address(BOB)));
        console.log("Proxy's token balance", mockToken.balanceOf(address(iDropKit)));
        console.log("DropKit fees collected are:", dropKitFees);

        assertEq(withdrawnAmount, bobAmount, "withdraw() return value mismatch");
        assertEq(mockToken.balanceOf(address(BOB)), bobAmount, "Bob final token balance mismatch");
        assertEq(dropKitFees, 0, "Admin fees should be 0 with no penalty");
    }
}
