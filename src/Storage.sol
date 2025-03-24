// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Events} from "./Events.sol";
import {Errors} from "./Errors.sol";
import {DropConfig, DropVars, Recipient} from "./Types.sol";
import {Constants} from "./Constants.sol";

abstract contract Storage is Events, Errors, Constants {
    uint256 public minEarlyExitPenalty;
    uint256 public creationPrice;
    uint256 public activationDeadline;
    uint256 public totalFees;
    uint256 public dropCount;

    mapping(uint256 dropID => DropConfig) public dropConfigs;
    mapping(uint256 dropID => DropVars) public dropVars;
    mapping(uint256 dropID => address) public dropCreator; // TODO should probably be in DropConfig
    mapping(uint256 dropID => mapping(address recipient => Recipient)) public recipients;
}
