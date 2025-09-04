











// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOracle} from "../interfaces/IOracle.sol";

/**
 * @title MockOracle
 * @notice Mock price oracle for testing
 * @dev Simulates Chainlink-style oracle responses
 */
contract MockOracle is IOracle {
    uint256 public price;
    uint256 public timestamp;
    uint8 public _decimals;
    string public _description;
    uint256 public _version;

    constructor(uint8 decimals_, string memory description_) {
        _decimals = decimals_;
        _description = description_;
        _version = 1;
        timestamp = block.timestamp;
    }

    function setPrice(uint256 newPrice) external {
        price = newPrice;
        timestamp = block.timestamp;
    }

    function latestAnswer() external view returns (int256) {
        return int256(price);
    }

    function latestTimestamp() external view returns (uint256) {
        return timestamp;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function version() external view returns (uint256) {
        return _version;
    }

    function getRoundData(uint80)
        external
        pure
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        revert("MockOracle: getRoundData not implemented");
    }

    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (
            0,
            int256(price),
            block.timestamp,
            timestamp,
            0
        );
    }
}









