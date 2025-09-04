









// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";

/**
 * @title MockUSDC
 * @notice Mock USD Coin token for testing
 */
contract MockUSDC is MockERC20 {
    constructor() MockERC20("USD Coin", "USDC", 6) {}
}









