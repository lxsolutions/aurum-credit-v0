

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IVault
 * @notice Interface for the multi-collateral vault
 */
interface IVault {
    // Events
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event LoanOpened(address indexed user, uint256 loanId, uint256 oztAmount);
    event LoanRepaid(address indexed user, uint256 loanId, uint256 oztAmount);
    event LiquidationStarted(uint256 indexed loanId, address indexed liquidator);
    event LiquidationCompleted(uint256 indexed loanId, address indexed liquidator, uint256 recoveredAmount);

    // Structs
    struct Collateral {
        address token;
        uint256 amount;
        uint256 haircut; // Basis points (10000 = 100%)
    }

    struct Loan {
        uint256 id;
        address borrower;
        uint256 principalOzt;
        uint256 interestOzt;
        uint256 createdAt;
        uint256 lastAccrued;
        bool liquidated;
    }

    // Functions
    function depositCollateral(address token, uint256 amount) external;
    function withdrawCollateral(address token, uint256 amount) external;
    function openLoan(uint256 oztAmount) external returns (uint256);
    function repayLoan(uint256 loanId, uint256 oztAmount) external;
    function liquidateLoan(uint256 loanId) external;
    
    // View functions
    function getCollateralValueOzt(address user) external view returns (uint256);
    function getLoanLTV(uint256 loanId) external view returns (uint256);
    function getLoanHealth(uint256 loanId) external view returns (uint256);
    function getUserLoans(address user) external view returns (uint256[] memory);
    function getSupportedCollaterals() external view returns (address[] memory);
}

