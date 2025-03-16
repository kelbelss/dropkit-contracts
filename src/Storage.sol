// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Events} from "./Events.sol";
import {Errors} from "./Errors.sol";

abstract contract Storage is Events, Errors {
    uint256 public minEarlyExitPenaltyAllowed;
    uint256 public creationPrice;
    uint256 public claimDeadline;
    uint256 public totalFees;
}
