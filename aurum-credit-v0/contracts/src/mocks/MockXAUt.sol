







// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";

/**
 * @title MockXAUt
 * @notice Mock Tether Gold token for testing
 */
contract MockXAUt is MockERC20 {
    constructor() MockERC20("Tether Gold", "XAUt", 6) {}
}








