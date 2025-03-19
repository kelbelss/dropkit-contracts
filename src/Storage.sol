// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Events} from "./Events.sol";
import {Errors} from "./Errors.sol";
import {Config, Recipient} from "./Types.sol";
import {Constants} from "./Constants.sol";

abstract contract Storage is Events, Errors, Constants {
    uint256 public minEarlyExitPenaltyAllowed;
    uint256 public creationPrice;
    uint256 public claimDeadline;
    uint256 public totalFees;
    uint256 public dropCount;

    // mappings
    mapping(uint256 dropID => Config) public drops;
    mapping(uint256 dropID => address) public dropCreator;
    mapping(address recipient => Recipient) public recipients;
}
