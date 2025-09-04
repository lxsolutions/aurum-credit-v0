


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IOracleRouter} from "./interfaces/IOracleRouter.sol";
import {MathUtils} from "./libraries/MathUtils.sol";

/**
 * @title Vault
 * @notice Multi-collateral vault for gold-unit lending
 * @dev Manages collateral deposits, loan issuance, and liquidations
 */
contract Vault is IVault, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant MAX_LTV = 8000; // 80% in basis points
    uint256 public constant LIQUIDATION_THRESHOLD = 8500; // 85% in basis points
    uint256 public constant INTEREST_RATE_PER_SECOND = 317097919; // ~10% APY (1e18 precision)

    // State variables
    IOracleRouter public oracleRouter;
    address public loanToken; // ozt-denominated loan token
    
    mapping(address => mapping(address => uint256)) public collateralBalances; // user => token => amount
    mapping(address => CollateralConfig) public collateralConfigs; // token => config
    mapping(uint256 => Loan) public loans; // loanId => loan
    mapping(address => uint256[]) public userLoans; // user => loanIds
    
    uint256 private nextLoanId = 1;
    address[] private supportedCollaterals;

    struct CollateralConfig {
        bool enabled;
        uint256 haircut; // Basis points (10000 = 100%)
        uint256 debtCeiling;
        uint256 totalDeposits;
    }

    modifier onlySupportedCollateral(address token) {
        require(collateralConfigs[token].enabled, "Vault: Unsupported collateral");
        _;
    }

    modifier onlyValidLoan(uint256 loanId) {
        require(loanId > 0 && loanId < nextLoanId, "Vault: Invalid loan ID");
        require(!loans[loanId].liquidated, "Vault: Loan liquidated");
        _;
    }

    constructor(address _oracleRouter, address _loanToken) Ownable(msg.sender) {
        oracleRouter = IOracleRouter(_oracleRouter);
        loanToken = _loanToken;
    }

    /**
     * @notice Deposit collateral into the vault
     * @param token Address of the collateral token
     * @param amount Amount to deposit
     */
    function depositCollateral(address token, uint256 amount) 
        external 
        nonReentrant 
        onlySupportedCollateral(token) 
    {
        require(amount > 0, "Vault: Amount must be > 0");
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[msg.sender][token] += amount;
        collateralConfigs[token].totalDeposits += amount;

        emit CollateralDeposited(msg.sender, token, amount);
    }

    /**
     * @notice Withdraw collateral from the vault
     * @param token Address of the collateral token
     * @param amount Amount to withdraw
     */
    function withdrawCollateral(address token, uint256 amount) 
        external 
        nonReentrant 
        onlySupportedCollateral(token) 
    {
        require(amount > 0, "Vault: Amount must be > 0");
        require(collateralBalances[msg.sender][token] >= amount, "Vault: Insufficient collateral");
        
        // Check LTV after withdrawal
        uint256 currentLTV = _calculateUserLTV(msg.sender);
        uint256 newLTV = _calculateLTVAfterWithdrawal(msg.sender, token, amount);
        require(newLTV <= MAX_LTV, "Vault: Withdrawal would exceed LTV limit");

        collateralBalances[msg.sender][token] -= amount;
        collateralConfigs[token].totalDeposits -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    /**
     * @notice Open a new loan denominated in ozt
     * @param oztAmount Amount of ozt to borrow
     * @return loanId ID of the created loan
     */
    function openLoan(uint256 oztAmount) external nonReentrant returns (uint256) {
        require(oztAmount > 0, "Vault: Loan amount must be > 0");
        
        uint256 collateralValueOzt = getCollateralValueOzt(msg.sender);
        uint256 ltv = MathUtils.calculateLTV(oztAmount, collateralValueOzt);
        require(ltv <= MAX_LTV, "Vault: LTV exceeds maximum");

        uint256 loanId = nextLoanId++;
        loans[loanId] = Loan({
            id: loanId,
            borrower: msg.sender,
            principalOzt: oztAmount,
            interestOzt: 0,
            createdAt: block.timestamp,
            lastAccrued: block.timestamp,
            liquidated: false
        });
        
        userLoans[msg.sender].push(loanId);
        
        // Mint loan tokens to user (simplified - would integrate with Loan contract)
        // ILoanToken(loanToken).mint(msg.sender, oztAmount);

        emit LoanOpened(msg.sender, loanId, oztAmount);
        return loanId;
    }

    /**
     * @notice Repay a loan
     * @param loanId ID of the loan to repay
     * @param oztAmount Amount of ozt to repay
     */
    function repayLoan(uint256 loanId, uint256 oztAmount) 
        external 
        nonReentrant 
        onlyValidLoan(loanId) 
    {
        Loan storage loan = loans[loanId];
        require(msg.sender == loan.borrower, "Vault: Only borrower can repay");

        _accrueInterest(loanId);
        
        uint256 totalOwed = loan.principalOzt + loan.interestOzt;
        require(oztAmount <= totalOwed, "Vault: Repayment exceeds debt");

        if (oztAmount == totalOwed) {
            // Full repayment
            loan.principalOzt = 0;
            loan.interestOzt = 0;
        } else if (oztAmount > loan.interestOzt) {
            // Partial repayment covering interest and some principal
            uint256 principalRepayment = oztAmount - loan.interestOzt;
            loan.interestOzt = 0;
            loan.principalOzt -= principalRepayment;
        } else {
            // Partial interest repayment
            loan.interestOzt -= oztAmount;
        }

        // Burn loan tokens from user (simplified)
        // ILoanToken(loanToken).burn(msg.sender, oztAmount);

        emit LoanRepaid(msg.sender, loanId, oztAmount);
    }

    /**
     * @notice Liquidate an underwater loan
     * @param loanId ID of the loan to liquidate
     */
    function liquidateLoan(uint256 loanId) external nonReentrant onlyValidLoan(loanId) {
        Loan storage loan = loans[loanId];
        
        uint256 ltv = getLoanLTV(loanId);
        require(ltv >= LIQUIDATION_THRESHOLD, "Vault: Loan not underwater");

        _accrueInterest(loanId);
        uint256 totalDebtOzt = loan.principalOzt + loan.interestOzt;
        
        // Start auction process (simplified - would integrate with AuctionHouse)
        loan.liquidated = true;
        
        emit LiquidationStarted(loanId, msg.sender);
        
        // Simulate auction completion
        emit LiquidationCompleted(loanId, msg.sender, totalDebtOzt);
    }

    /**
     * @notice Get collateral value in ozt for a user
     * @param user Address of the user
     * @return valueOzt Total collateral value in ozt
     */
    function getCollateralValueOzt(address user) public view returns (uint256) {
        uint256 totalValueOzt;
        
        for (uint256 i = 0; i < supportedCollaterals.length; i++) {
            address token = supportedCollaterals[i];
            CollateralConfig memory config = collateralConfigs[token];
            
            if (config.enabled) {
                uint256 balance = collateralBalances[user][token];
                if (balance > 0) {
                    uint256 valueUsd = balance * oracleRouter.getPrice(token); // Simplified
                    uint256 valueOzt = valueUsd / oracleRouter.getXauPrice();
                    totalValueOzt += MathUtils.safeDiv(MathUtils.safeMul(valueOzt, config.haircut), MathUtils.BASIS_POINTS);
                }
            }
        }
        
        return totalValueOzt;
    }

    /**
     * @notice Get LTV for a specific loan
     * @param loanId ID of the loan
     * @return ltv Loan-to-value ratio in basis points
     */
    function getLoanLTV(uint256 loanId) public view onlyValidLoan(loanId) returns (uint256) {
        Loan memory loan = loans[loanId];
        _accrueInterestView(loanId);
        
        uint256 collateralValueOzt = getCollateralValueOzt(loan.borrower);
        uint256 totalDebtOzt = loan.principalOzt + loan.interestOzt;
        
        if (collateralValueOzt == 0) return type(uint256).max;
        return MathUtils.calculateLTV(totalDebtOzt, collateralValueOzt);
    }

    /**
     * @notice Get loan health factor
     * @param loanId ID of the loan
     * @return health Health factor (higher is better)
     */
    function getLoanHealth(uint256 loanId) public view onlyValidLoan(loanId) returns (uint256) {
        uint256 ltv = getLoanLTV(loanId);
        if (ltv == 0) return type(uint256).max;
        return MathUtils.calculateHealthFactor(ltv, LIQUIDATION_THRESHOLD);
    }

    /**
     * @notice Get user's loan IDs
     * @param user Address of the user
     * @return loanIds Array of loan IDs
     */
    function getUserLoans(address user) public view returns (uint256[] memory) {
        return userLoans[user];
    }

    /**
     * @notice Get supported collateral tokens
     * @return tokens Array of supported token addresses
     */
    function getSupportedCollaterals() public view returns (address[] memory) {
        return supportedCollaterals;
    }

    // Admin functions
    function addCollateralType(
        address token, 
        uint256 haircut, 
        uint256 debtCeiling
    ) external onlyOwner {
        require(!collateralConfigs[token].enabled, "Vault: Collateral already added");
        require(haircut <= MathUtils.BASIS_POINTS, "Vault: Invalid haircut");
        
        collateralConfigs[token] = CollateralConfig({
            enabled: true,
            haircut: haircut,
            debtCeiling: debtCeiling,
            totalDeposits: 0
        });
        
        supportedCollaterals.push(token);
    }

    function updateCollateralConfig(
        address token,
        uint256 haircut,
        uint256 debtCeiling
    ) external onlyOwner onlySupportedCollateral(token) {
        require(haircut <= MathUtils.BASIS_POINTS, "Vault: Invalid haircut");
        
        collateralConfigs[token].haircut = haircut;
        collateralConfigs[token].debtCeiling = debtCeiling;
    }

    // Internal functions
    function _accrueInterest(uint256 loanId) internal {
        Loan storage loan = loans[loanId];
        uint256 timeElapsed = block.timestamp - loan.lastAccrued;
        
        if (timeElapsed > 0) {
            uint256 interest = MathUtils.calculateInterest(loan.principalOzt, INTEREST_RATE_PER_SECOND, timeElapsed);
            loan.interestOzt += interest;
            loan.lastAccrued = block.timestamp;
        }
    }

    function _accrueInterestView(uint256 loanId) internal view {
        Loan memory loan = loans[loanId];
        uint256 timeElapsed = block.timestamp - loan.lastAccrued;
        
        if (timeElapsed > 0) {
            uint256 interest = MathUtils.calculateInterest(loan.principalOzt, INTEREST_RATE_PER_SECOND, timeElapsed);
            loan.interestOzt += interest;
        }
    }

    function _calculateUserLTV(address user) internal view returns (uint256) {
        uint256 totalDebtOzt = _getUserTotalDebtOzt(user);
        uint256 collateralValueOzt = getCollateralValueOzt(user);
        
        if (collateralValueOzt == 0) return 0;
        return MathUtils.calculateLTV(totalDebtOzt, collateralValueOzt);
    }

    function _calculateLTVAfterWithdrawal(
        address user, 
        address token, 
        uint256 amount
    ) internal view returns (uint256) {
        uint256 currentCollateralValueOzt = getCollateralValueOzt(user);
        
        // Calculate new collateral value after withdrawal
        CollateralConfig memory config = collateralConfigs[token];
        uint256 valueUsd = amount * oracleRouter.getPrice(token);
        uint256 valueOzt = valueUsd / oracleRouter.getXauPrice();
        uint256 haircutValueOzt = MathUtils.safeDiv(MathUtils.safeMul(valueOzt, config.haircut), MathUtils.BASIS_POINTS);
        
        uint256 newCollateralValueOzt = currentCollateralValueOzt - haircutValueOzt;
        uint256 totalDebtOzt = _getUserTotalDebtOzt(user);
        
        if (newCollateralValueOzt == 0) return type(uint256).max;
        return MathUtils.calculateLTV(totalDebtOzt, newCollateralValueOzt);
    }

    function _getUserTotalDebtOzt(address user) internal view returns (uint256) {
        uint256 totalDebt;
        uint256[] memory userLoanIds = userLoans[user];
        
        for (uint256 i = 0; i < userLoanIds.length; i++) {
            uint256 loanId = userLoanIds[i];
            if (!loans[loanId].liquidated) {
                _accrueInterestView(loanId);
                totalDebt += loans[loanId].principalOzt + loans[loanId].interestOzt;
            }
        }
        
        return totalDebt;
    }
}


