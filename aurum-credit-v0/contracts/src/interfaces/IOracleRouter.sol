


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOracleRouter
 * @notice Interface for the oracle router that provides price feeds
 */
interface IOracleRouter {
    // Events
    event PriceUpdated(address indexed token, uint256 price);
    event XauPriceUpdated(uint256 price);
    event OracleAdded(address indexed token, address oracle);
    event OracleRemoved(address indexed token);

    // Structs
    struct OracleConfig {
        address oracle;
        uint256 deviationThreshold; // Basis points
        uint256 stalenessThreshold; // Seconds
        uint256 heartbeat; // Seconds
    }

    // Functions
    function updatePrice(address token) external returns (uint256);
    function updateXauPrice() external returns (uint256);
    function addOracle(address token, address oracle, uint256 deviationThreshold, uint256 stalenessThreshold) external;
    function removeOracle(address token) external;

    // View functions
    function getPrice(address token) external view returns (uint256);
    function getXauPrice() external view returns (uint256);
    function getPriceWithValidation(address token) external view returns (uint256, bool);
    function getXauPriceWithValidation() external view returns (uint256, bool);
    function isPriceValid(address token) external view returns (bool);
    function isXauPriceValid() external view returns (bool);
    function getOracles() external view returns (address[] memory);
}


