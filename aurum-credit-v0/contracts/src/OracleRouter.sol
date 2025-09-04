



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOracleRouter} from "./interfaces/IOracleRouter.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {MathUtils} from "./libraries/MathUtils.sol";

/**
 * @title OracleRouter
 * @notice Router for price feeds with medianizer and deviation/staleness guards
 * @dev Manages multiple price oracles with validation and fallback mechanisms
 */
contract OracleRouter is IOracleRouter, Ownable {
    // Constants
    uint256 public constant MAX_DEVIATION = 500; // 5% in basis points
    uint256 public constant DEFAULT_STALENESS = 86400; // 24 hours
    uint256 public constant DEFAULT_HEARTBEAT = 3600; // 1 hour

    // State variables
    address public xauOracle;
    mapping(address => OracleConfig) public oracleConfigs;
    mapping(address => uint256) public lastPrices;
    mapping(address => uint256) public lastUpdateTimes;
    address[] public supportedTokens;
    
    uint256 public lastXauPrice;
    uint256 public lastXauUpdateTime;

    modifier onlyValidOracle(address token) {
        require(oracleConfigs[token].oracle != address(0), "OracleRouter: No oracle for token");
        _;
    }

    constructor(address _xauOracle) Ownable(msg.sender) {
        xauOracle = _xauOracle;
    }

    /**
     * @notice Update price for a specific token
     * @param token Address of the token
     * @return price Updated price
     */
    function updatePrice(address token) external onlyValidOracle(token) returns (uint256) {
        OracleConfig memory config = oracleConfigs[token];
        (uint256 price, bool isValid) = _getValidatedPrice(token, config);
        
        require(isValid, "OracleRouter: Price validation failed");
        
        lastPrices[token] = price;
        lastUpdateTimes[token] = block.timestamp;
        
        emit PriceUpdated(token, price);
        return price;
    }

    /**
     * @notice Update XAU price
     * @return price Updated XAU price
     */
    function updateXauPrice() external returns (uint256) {
        require(xauOracle != address(0), "OracleRouter: XAU oracle not set");
        
        (uint256 price, bool isValid) = _getValidatedXauPrice();
        require(isValid, "OracleRouter: XAU price validation failed");
        
        lastXauPrice = price;
        lastXauUpdateTime = block.timestamp;
        
        emit XauPriceUpdated(price);
        return price;
    }

    /**
     * @notice Add a new oracle for a token
     * @param token Address of the token
     * @param oracle Address of the oracle contract
     * @param deviationThreshold Deviation threshold in basis points
     * @param stalenessThreshold Staleness threshold in seconds
     */
    function addOracle(
        address token,
        address oracle,
        uint256 deviationThreshold,
        uint256 stalenessThreshold
    ) external onlyOwner {
        require(oracle != address(0), "OracleRouter: Invalid oracle address");
        require(deviationThreshold <= MAX_DEVIATION, "OracleRouter: Deviation too high");
        require(stalenessThreshold > 0, "OracleRouter: Invalid staleness threshold");

        oracleConfigs[token] = OracleConfig({
            oracle: oracle,
            deviationThreshold: deviationThreshold,
            stalenessThreshold: stalenessThreshold,
            heartbeat: DEFAULT_HEARTBEAT
        });

        // Add to supported tokens if not already present
        bool alreadySupported = false;
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                alreadySupported = true;
                break;
            }
        }
        
        if (!alreadySupported) {
            supportedTokens.push(token);
        }

        emit OracleAdded(token, oracle);
    }

    /**
     * @notice Remove an oracle for a token
     * @param token Address of the token
     */
    function removeOracle(address token) external onlyOwner {
        require(oracleConfigs[token].oracle != address(0), "OracleRouter: Oracle not found");
        
        delete oracleConfigs[token];
        
        // Remove from supported tokens
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }

        emit OracleRemoved(token);
    }

    /**
     * @notice Get current price for a token
     * @param token Address of the token
     * @return price Current price
     */
    function getPrice(address token) external view onlyValidOracle(token) returns (uint256) {
        return lastPrices[token];
    }

    /**
     * @notice Get current XAU price
     * @return price Current XAU price
     */
    function getXauPrice() external view returns (uint256) {
        return lastXauPrice;
    }

    /**
     * @notice Get validated price for a token
     * @param token Address of the token
     * @return price Validated price
     * @return isValid Whether the price is valid
     */
    function getPriceWithValidation(address token) external view onlyValidOracle(token) returns (uint256, bool) {
        OracleConfig memory config = oracleConfigs[token];
        return _getValidatedPrice(token, config);
    }

    /**
     * @notice Get validated XAU price
     * @return price Validated XAU price
     * @return isValid Whether the price is valid
     */
    function getXauPriceWithValidation() external view returns (uint256, bool) {
        return _getValidatedXauPrice();
    }

    /**
     * @notice Check if price for a token is valid
     * @param token Address of the token
     * @return isValid Whether the price is valid
     */
    function isPriceValid(address token) external view onlyValidOracle(token) returns (bool) {
        OracleConfig memory config = oracleConfigs[token];
        (, bool isValid) = _getValidatedPrice(token, config);
        return isValid;
    }

    /**
     * @notice Check if XAU price is valid
     * @return isValid Whether the XAU price is valid
     */
    function isXauPriceValid() external view returns (bool) {
        (, bool isValid) = _getValidatedXauPrice();
        return isValid;
    }

    /**
     * @notice Get list of supported tokens
     * @return tokens Array of supported token addresses
     */
    function getOracles() external view returns (address[] memory) {
        return supportedTokens;
    }

    // Internal functions
    function _getValidatedPrice(address token, OracleConfig memory config) internal view returns (uint256, bool) {
        IOracle oracle = IOracle(config.oracle);
        
        try oracle.latestRoundData() returns (
            uint80 /* roundId */,
            int256 answer,
            uint256 /* startedAt */,
            uint256 updatedAt,
            uint80 /* answeredInRound */
        ) {
            // Check staleness
            if (block.timestamp - updatedAt > config.stalenessThreshold) {
                return (0, false);
            }

            // Check heartbeat
            if (block.timestamp - updatedAt > config.heartbeat) {
                return (0, false);
            }

            uint256 currentPrice = uint256(answer);
            
            // Check deviation if we have a previous price
            if (lastPrices[token] > 0) {
                uint256 deviation = _calculateDeviation(lastPrices[token], currentPrice);
                if (deviation > config.deviationThreshold) {
                    return (0, false);
                }
            }

            return (currentPrice, true);
        } catch {
            return (0, false);
        }
    }

    function _getValidatedXauPrice() internal view returns (uint256, bool) {
        if (xauOracle == address(0)) {
            return (0, false);
        }

        IOracle oracle = IOracle(xauOracle);
        
        try oracle.latestRoundData() returns (
            uint80 /* roundId */,
            int256 answer,
            uint256 /* startedAt */,
            uint256 updatedAt,
            uint80 /* answeredInRound */
        ) {
            // Check staleness
            if (block.timestamp - updatedAt > DEFAULT_STALENESS) {
                return (0, false);
            }

            // Check heartbeat
            if (block.timestamp - updatedAt > DEFAULT_HEARTBEAT) {
                return (0, false);
            }

            uint256 currentPrice = uint256(answer);
            
            // Check deviation if we have a previous price
            if (lastXauPrice > 0) {
                uint256 deviation = _calculateDeviation(lastXauPrice, currentPrice);
                if (deviation > MAX_DEVIATION) {
                    return (0, false);
                }
            }

            return (currentPrice, true);
        } catch {
            return (0, false);
        }
    }

    function _calculateDeviation(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (oldPrice == 0 || newPrice == 0) {
            return type(uint256).max;
        }
        
        uint256 difference = oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;
        return MathUtils.calculateDeviation(oldPrice, newPrice);
    }
}



