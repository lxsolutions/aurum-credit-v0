




// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILoan} from "./interfaces/ILoan.sol";

/**
 * @title Loan
 * @notice ozt-denominated loan token with interest accrual
 * @dev ERC20 token representing gold ounce denominated loans
 */
contract Loan is ILoan, ERC20, Ownable {
    // Constants
    uint256 public constant INTEREST_RATE_PER_SECOND = 317097919; // ~10% APY (1e18 precision)
    uint256 public constant SCALE = 1e18;

    // State variables
    uint256 public totalPrincipal;
    uint256 public totalInterest;
    uint256 public lastAccrualTime;
    address public vault;

    modifier onlyVault() {
        require(msg.sender == vault, "Loan: Only vault can call");
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {
        lastAccrualTime = block.timestamp;
    }

    /**
     * @notice Set the vault address
     * @param _vault Address of the vault contract
     */
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Loan: Invalid vault address");
        vault = _vault;
    }

    /**
     * @notice Mint new loan tokens
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyVault {
        require(amount > 0, "Loan: Amount must be > 0");
        
        accrueInterest();
        totalPrincipal += amount;
        _mint(to, amount);
        
        emit LoanMinted(to, amount);
    }

    /**
     * @notice Burn loan tokens
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external onlyVault {
        require(amount > 0, "Loan: Amount must be > 0");
        require(balanceOf(from) >= amount, "Loan: Insufficient balance");
        
        accrueInterest();
        totalPrincipal -= amount;
        _burn(from, amount);
        
        emit LoanBurned(from, amount);
    }

    /**
     * @notice Accrue interest on outstanding loans
     */
    function accrueInterest() public {
        uint256 timeElapsed = block.timestamp - lastAccrualTime;
        
        if (timeElapsed > 0 && totalPrincipal > 0) {
            uint256 interest = (totalPrincipal * INTEREST_RATE_PER_SECOND * timeElapsed) / SCALE;
            totalInterest += interest;
            lastAccrualTime = block.timestamp;
            
            emit InterestAccrued(interest);
        }
    }

    /**
     * @notice Distribute accrued interest to recipient
     * @param to Address to distribute interest to
     */
    function distributeInterest(address to) external onlyOwner {
        require(totalInterest > 0, "Loan: No interest to distribute");
        
        uint256 interest = totalInterest;
        totalInterest = 0;
        _mint(to, interest);
        
        emit InterestDistributed(to, interest);
    }

    /**
     * @notice Get total outstanding debt (principal + interest)
     * @return totalDebt Total debt in ozt
     */
    function getTotalDebt() external view returns (uint256) {
        return totalPrincipal + _getAccruedInterest();
    }

    /**
     * @notice Get total principal supply
     * @return principal Total principal
     */
    function getPrincipalSupply() external view returns (uint256) {
        return totalPrincipal;
    }

    /**
     * @notice Get total interest supply
     * @return interest Total interest
     */
    function getInterestSupply() external view returns (uint256) {
        return totalInterest + _getAccruedInterest();
    }

    /**
     * @notice Get current interest rate
     * @return rate Interest rate per second (1e18 precision)
     */
    function getInterestRate() external pure returns (uint256) {
        return INTEREST_RATE_PER_SECOND;
    }

    /**
     * @notice Get last interest accrual time
     * @return time Timestamp of last accrual
     */
    function getLastAccrualTime() external view returns (uint256) {
        return lastAccrualTime;
    }

    // Internal functions
    function _getAccruedInterest() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastAccrualTime;
        
        if (timeElapsed == 0 || totalPrincipal == 0) {
            return 0;
        }
        
        return (totalPrincipal * INTEREST_RATE_PER_SECOND * timeElapsed) / SCALE;
    }

    // Override ERC20 functions to include interest accrual
    function transfer(address to, uint256 amount) public override(IERC20, ERC20) returns (bool) {
        accrueInterest();
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override(IERC20, ERC20) returns (bool) {
        accrueInterest();
        return super.transferFrom(from, to, amount);
    }

    function approve(address spender, uint256 amount) public override(IERC20, ERC20) returns (bool) {
        accrueInterest();
        return super.approve(spender, amount);
    }
}




