




// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IInsuranceFund
 * @notice Interface for protocol insurance fund
 */
interface IInsuranceFund {
    // Events
    event FundsDeposited(address indexed from, address indexed token, uint256 amount);
    event FundsWithdrawn(address indexed to, address indexed token, uint256 amount);
    event ClaimPaid(address indexed to, address indexed token, uint256 amount);
    event FeeCollected(address indexed from, address indexed token, uint256 amount);

    // Functions
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount) external;
    function payClaim(address to, address token, uint256 amount) external;
    function collectFee(address from, address token, uint256 amount) external;
    
    // View functions
    function getBalance(address token) external view returns (uint256);
    function getTotalAssets() external view returns (uint256);
    function getClaimableAmount(address token) external view returns (uint256);
    function isSufficientCoverage() external view returns (bool);
}




