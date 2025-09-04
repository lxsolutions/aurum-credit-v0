






// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IInsuranceFund} from "./interfaces/IInsuranceFund.sol";
import {MathUtils} from "./libraries/MathUtils.sol";

/**
 * @title InsuranceFund
 * @notice Protocol insurance fund for backstopping liquidations and collecting fees
 * @dev Manages protocol fees and provides insurance coverage
 */
contract InsuranceFund is IInsuranceFund, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant MIN_COVERAGE_RATIO = 15000; // 150% in basis points
    uint256 public constant PROTOCOL_FEE = 200; // 2% in basis points

    // State variables
    mapping(address => uint256) public balances;
    mapping(address => uint256) public totalClaims;
    mapping(address => uint256) public totalFees;
    address[] public supportedTokens;

    modifier onlySupportedToken(address token) {
        require(balances[token] > 0 || _isNewToken(token), "InsuranceFund: Unsupported token");
        _;
    }

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Deposit funds into the insurance fund
     * @param token Address of the token to deposit
     * @param amount Amount to deposit
     */
    function deposit(address token, uint256 amount) external nonReentrant onlySupportedToken(token) {
        require(amount > 0, "InsuranceFund: Amount must be > 0");
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        balances[token] += amount;
        
        // Add to supported tokens if new
        if (!_isTokenSupported(token)) {
            supportedTokens.push(token);
        }
        
        emit FundsDeposited(msg.sender, token, amount);
    }

    /**
     * @notice Withdraw funds from the insurance fund (admin only)
     * @param token Address of the token to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "InsuranceFund: Amount must be > 0");
        require(balances[token] >= amount, "InsuranceFund: Insufficient balance");
        require(_canWithdraw(token, amount), "InsuranceFund: Withdrawal would violate coverage ratio");
        
        balances[token] -= amount;
        IERC20(token).safeTransfer(owner(), amount);
        
        emit FundsWithdrawn(owner(), token, amount);
    }

    /**
     * @notice Pay an insurance claim
     * @param to Address to pay the claim to
     * @param token Address of the token to pay
     * @param amount Amount to pay
     */
    function payClaim(address to, address token, uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "InsuranceFund: Amount must be > 0");
        require(balances[token] >= amount, "InsuranceFund: Insufficient balance");
        require(_canPayClaim(token, amount), "InsuranceFund: Claim would violate coverage ratio");
        
        balances[token] -= amount;
        totalClaims[token] += amount;
        IERC20(token).safeTransfer(to, amount);
        
        emit ClaimPaid(to, token, amount);
    }

    /**
     * @notice Collect protocol fees
     * @param from Address paying the fee
     * @param token Address of the token
     * @param amount Amount of fee to collect
     */
    function collectFee(address from, address token, uint256 amount) external nonReentrant onlySupportedToken(token) {
        require(amount > 0, "InsuranceFund: Amount must be > 0");
        
        uint256 feeAmount = MathUtils.safeDiv(MathUtils.safeMul(amount, PROTOCOL_FEE), 10000);
        if (feeAmount > 0) {
            IERC20(token).safeTransferFrom(from, address(this), feeAmount);
            balances[token] += feeAmount;
            totalFees[token] += feeAmount;
            
            // Add to supported tokens if new
            if (!_isTokenSupported(token)) {
                supportedTokens.push(token);
            }
            
            emit FeeCollected(from, token, feeAmount);
        }
    }

    /**
     * @notice Get balance of a specific token
     * @param token Address of the token
     * @return balance Current balance
     */
    function getBalance(address token) external view returns (uint256) {
        return balances[token];
    }

    /**
     * @notice Get total assets across all tokens (simplified - would use oracle pricing)
     * @return total Total assets
     */
    function getTotalAssets() external view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            total += balances[supportedTokens[i]];
        }
        return total;
    }

    /**
     * @notice Get claimable amount for a token considering coverage ratio
     * @param token Address of the token
     * @return claimableAmount Maximum claimable amount
     */
    function getClaimableAmount(address token) external view returns (uint256) {
        uint256 balance = balances[token];
        uint256 maxClaim = MathUtils.safeDiv(MathUtils.safeMul(balance, 10000), MIN_COVERAGE_RATIO);
        return maxClaim > balance ? balance : maxClaim;
    }

    /**
     * @notice Check if the fund has sufficient coverage
     * @return sufficient Whether coverage is sufficient
     */
    function isSufficientCoverage() external view returns (bool) {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            if (!_hasSufficientCoverage(token)) {
                return false;
            }
        }
        return true;
    }

    // Internal functions
    function _isTokenSupported(address token) internal view returns (bool) {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    function _isNewToken(address token) internal pure returns (bool) {
        // Simplified - in production would check if token is whitelisted
        return token != address(0);
    }

    function _hasSufficientCoverage(address token) internal view returns (bool) {
        uint256 balance = balances[token];
        uint256 claims = totalClaims[token];
        
        if (balance == 0) return true;
        return MathUtils.safeDiv(MathUtils.safeMul(balance, 10000), claims + 1) >= MIN_COVERAGE_RATIO;
    }

    function _canWithdraw(address token, uint256 amount) internal view returns (bool) {
        uint256 newBalance = balances[token] - amount;
        uint256 claims = totalClaims[token];
        
        if (newBalance == 0) return true;
        return MathUtils.safeDiv(MathUtils.safeMul(newBalance, 10000), claims + 1) >= MIN_COVERAGE_RATIO;
    }

    function _canPayClaim(address token, uint256 amount) internal view returns (bool) {
        uint256 newBalance = balances[token] - amount;
        uint256 newClaims = totalClaims[token] + amount;
        
        if (newBalance == 0) return true;
        return MathUtils.safeDiv(MathUtils.safeMul(newBalance, 10000), newClaims) >= MIN_COVERAGE_RATIO;
    }
}





