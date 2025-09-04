



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ILoan
 * @notice Interface for ozt-denominated loan token
 */
interface ILoan is IERC20 {
    // Events
    event LoanMinted(address indexed to, uint256 amount);
    event LoanBurned(address indexed from, uint256 amount);
    event InterestAccrued(uint256 totalInterest);
    event InterestDistributed(address indexed to, uint256 amount);

    // Functions
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function accrueInterest() external;
    function distributeInterest(address to) external;
    
    // View functions
    function getTotalDebt() external view returns (uint256);
    function getPrincipalSupply() external view returns (uint256);
    function getInterestSupply() external view returns (uint256);
    function getInterestRate() external view returns (uint256);
    function getLastAccrualTime() external view returns (uint256);
}



