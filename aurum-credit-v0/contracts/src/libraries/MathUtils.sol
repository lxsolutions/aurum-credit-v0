












// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MathUtils
 * @notice Mathematical utilities for Aurum Credit protocol
 * @dev Provides safe math operations and financial calculations
 */
library MathUtils {
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SCALE = 1e18;

    // Safe math functions
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "MathUtils: addition overflow");
        return c;
    }

    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "MathUtils: subtraction underflow");
        return a - b;
    }

    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "MathUtils: multiplication overflow");
        return c;
    }

    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "MathUtils: division by zero");
        return a / b;
    }

    // Financial calculations
    function calculateLTV(
        uint256 debtOzt,
        uint256 collateralValueOzt
    ) internal pure returns (uint256) {
        if (collateralValueOzt == 0) {
            return debtOzt > 0 ? type(uint256).max : 0;
        }
        return (debtOzt * BASIS_POINTS) / collateralValueOzt;
    }

    function calculateCollateralValueOzt(
        uint256 collateralAmount,
        uint256 tokenPrice,
        uint256 xauPrice,
        uint256 haircut
    ) internal pure returns (uint256) {
        uint256 valueUsd = safeMul(collateralAmount, tokenPrice);
        uint256 valueOzt = safeDiv(valueUsd, xauPrice);
        return safeDiv(safeMul(valueOzt, haircut), BASIS_POINTS);
    }

    function calculatePortfolioValueOzt(
        uint256[] memory amounts,
        uint256[] memory prices,
        uint256 xauPrice,
        uint256[] memory haircuts
    ) internal pure returns (uint256) {
        require(amounts.length == prices.length && amounts.length == haircuts.length, 
            "MathUtils: array length mismatch");
        
        uint256 totalValueOzt;
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] > 0) {
                uint256 valueOzt = calculateCollateralValueOzt(
                    amounts[i],
                    prices[i],
                    xauPrice,
                    haircuts[i]
                );
                totalValueOzt = safeAdd(totalValueOzt, valueOzt);
            }
        }
        return totalValueOzt;
    }

    function calculateInterest(
        uint256 principal,
        uint256 ratePerSecond,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        return safeDiv(safeMul(safeMul(principal, ratePerSecond), timeElapsed), SCALE);
    }

    function calculateHealthFactor(
        uint256 ltv,
        uint256 liquidationThreshold
    ) internal pure returns (uint256) {
        if (ltv == 0) return type(uint256).max;
        return safeDiv(safeMul(liquidationThreshold, BASIS_POINTS), ltv);
    }

    function calculateAuctionPrice(
        uint256 startingPrice,
        uint256 decayRate,
        uint256 timeElapsed,
        uint256 duration
    ) internal pure returns (uint256) {
        if (timeElapsed >= duration) {
            return 0;
        }
        
        uint256 priceDecay = safeDiv(safeMul(safeMul(startingPrice, decayRate), timeElapsed), SCALE);
        if (priceDecay > startingPrice) {
            return 0;
        }
        
        return safeSub(startingPrice, priceDecay);
    }

    function calculateDeviation(
        uint256 oldValue,
        uint256 newValue
    ) internal pure returns (uint256) {
        if (oldValue == 0 || newValue == 0) {
            return type(uint256).max;
        }
        
        uint256 difference = oldValue > newValue ? 
            safeSub(oldValue, newValue) : 
            safeSub(newValue, oldValue);
            
        return safeDiv(safeMul(difference, BASIS_POINTS), oldValue);
    }

    function calculateProtocolFee(
        uint256 amount,
        uint256 feeBps
    ) internal pure returns (uint256) {
        return safeDiv(safeMul(amount, feeBps), BASIS_POINTS);
    }
}











