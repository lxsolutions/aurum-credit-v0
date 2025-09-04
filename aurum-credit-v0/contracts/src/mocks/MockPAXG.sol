






// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";

/**
 * @title MockPAXG
 * @notice Mock PAX Gold token for testing
 */
contract MockPAXG is MockERC20 {
    constructor() MockERC20("Paxos Gold", "PAXG", 18) {}
}







