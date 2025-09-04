








// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";

/**
 * @title MockWBTC
 * @notice Mock Wrapped Bitcoin token for testing
 */
contract MockWBTC is MockERC20 {
    constructor() MockERC20("Wrapped Bitcoin", "WBTC", 8) {}
}








