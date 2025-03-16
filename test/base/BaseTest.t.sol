// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {DropKit} from "../../src/DropKit.sol";

contract BaseTest is Test {
    DropKit dropKit;

    function setUp() public virtual {
        dropKit = new DropKit();
    }
}
