





// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAuctionHouse} from "./interfaces/IAuctionHouse.sol";
import {IVault} from "./interfaces/IVault.sol";
import {MathUtils} from "./libraries/MathUtils.sol";

/**
 * @title AuctionHouse
 * @notice Dutch auction system for liquidating underwater loans
 * @dev Manages descending price auctions for collateral liquidation
 */
contract AuctionHouse is IAuctionHouse, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant AUCTION_DURATION = 86400; // 24 hours
    uint256 public constant PRICE_DECAY_RATE = 5787; // ~50% price drop per day (1e18 precision)
    uint256 public constant MIN_BID_INCREMENT = 100; // 1% in basis points

    // State variables
    IVault public vault;
    mapping(uint256 => Auction) public auctions;
    uint256[] public activeAuctions;
    uint256 private nextAuctionId = 1;

    modifier onlyVault() {
        require(msg.sender == address(vault), "AuctionHouse: Only vault can call");
        _;
    }

    modifier onlyActiveAuction(uint256 auctionId) {
        require(auctionId > 0 && auctionId < nextAuctionId, "AuctionHouse: Invalid auction ID");
        require(!auctions[auctionId].settled, "AuctionHouse: Auction settled");
        require(!auctions[auctionId].cancelled, "AuctionHouse: Auction cancelled");
        _;
    }

    constructor(address _vault) Ownable(msg.sender) {
        vault = IVault(_vault);
    }

    /**
     * @notice Start a new Dutch auction for liquidated collateral
     * @param loanId ID of the loan being liquidated
     * @param collateralToken Address of the collateral token
     * @param collateralAmount Amount of collateral to auction
     * @return auctionId ID of the created auction
     */
    function startAuction(
        uint256 loanId,
        address collateralToken,
        uint256 collateralAmount
    ) external onlyVault returns (uint256) {
        require(collateralAmount > 0, "AuctionHouse: Amount must be > 0");
        
        // Get current price from oracle (simplified)
        uint256 startingPrice = _calculateStartingPrice(collateralToken, collateralAmount);
        
        uint256 auctionId = nextAuctionId++;
        auctions[auctionId] = Auction({
            id: auctionId,
            loanId: loanId,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            startingPrice: startingPrice,
            currentPrice: startingPrice,
            startTime: block.timestamp,
            duration: AUCTION_DURATION,
            highestBidder: address(0),
            highestBid: 0,
            settled: false,
            cancelled: false
        });
        
        activeAuctions.push(auctionId);
        
        emit AuctionStarted(auctionId, loanId, collateralAmount, startingPrice);
        return auctionId;
    }

    /**
     * @notice Place a bid on an active auction
     * @param auctionId ID of the auction
     * @param bidAmount Bid amount in payment token
     */
    function placeBid(uint256 auctionId, uint256 bidAmount) 
        external 
        nonReentrant 
        onlyActiveAuction(auctionId) 
    {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp < auction.startTime + auction.duration, "AuctionHouse: Auction ended");
        
        uint256 currentPrice = getAuctionPrice(auctionId);
        require(bidAmount >= currentPrice, "AuctionHouse: Bid below current price");
        
        // Check minimum bid increment
        if (auction.highestBid > 0) {
            uint256 minBid = auction.highestBid + MathUtils.safeDiv(MathUtils.safeMul(auction.highestBid, MIN_BID_INCREMENT), 10000);
            require(bidAmount >= minBid, "AuctionHouse: Bid increment too small");
        }
        
        // Refund previous highest bidder
        if (auction.highestBidder != address(0)) {
            IERC20(auction.collateralToken).safeTransfer(auction.highestBidder, auction.highestBid);
        }
        
        // Transfer new bid
        IERC20(auction.collateralToken).safeTransferFrom(msg.sender, address(this), bidAmount);
        
        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;
        auction.currentPrice = bidAmount;
        
        emit AuctionBid(auctionId, msg.sender, bidAmount);
    }

    /**
     * @notice Settle a completed auction
     * @param auctionId ID of the auction to settle
     */
    function settleAuction(uint256 auctionId) external nonReentrant onlyActiveAuction(auctionId) {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp >= auction.startTime + auction.duration, "AuctionHouse: Auction not ended");
        require(auction.highestBidder != address(0), "AuctionHouse: No bids");
        
        auction.settled = true;
        _removeActiveAuction(auctionId);
        
        // Transfer collateral to winner
        IERC20(auction.collateralToken).safeTransfer(auction.highestBidder, auction.collateralAmount);
        
        emit AuctionSettled(auctionId, auction.highestBidder, auction.highestBid);
    }

    /**
     * @notice Cancel an auction
     * @param auctionId ID of the auction to cancel
     */
    function cancelAuction(uint256 auctionId) external onlyOwner onlyActiveAuction(auctionId) {
        Auction storage auction = auctions[auctionId];
        auction.cancelled = true;
        _removeActiveAuction(auctionId);
        
        // Refund highest bidder if any
        if (auction.highestBidder != address(0)) {
            IERC20(auction.collateralToken).safeTransfer(auction.highestBidder, auction.highestBid);
        }
        
        emit AuctionCancelled(auctionId);
    }

    /**
     * @notice Get auction details
     * @param auctionId ID of the auction
     * @return auction Auction details
     */
    function getAuction(uint256 auctionId) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    /**
     * @notice Get list of active auction IDs
     * @return auctionIds Array of active auction IDs
     */
    function getActiveAuctions() external view returns (uint256[] memory) {
        return activeAuctions;
    }

    /**
     * @notice Get current price for an auction
     * @param auctionId ID of the auction
     * @return price Current auction price
     */
    function getAuctionPrice(uint256 auctionId) public view returns (uint256) {
        Auction memory auction = auctions[auctionId];
        
        if (auction.settled || auction.cancelled) {
            return 0;
        }
        
        if (auction.highestBid > 0) {
            return auction.highestBid;
        }
        
        return _calculateCurrentPrice(auction);
    }

    /**
     * @notice Check if an auction is active
     * @param auctionId ID of the auction
     * @return isActive Whether the auction is active
     */
    function isAuctionActive(uint256 auctionId) external view returns (bool) {
        if (auctionId == 0 || auctionId >= nextAuctionId) {
            return false;
        }
        
        Auction memory auction = auctions[auctionId];
        return !auction.settled && !auction.cancelled && block.timestamp < auction.startTime + auction.duration;
    }

    // Internal functions
    function _calculateStartingPrice(address collateralToken, uint256 collateralAmount) internal pure returns (uint256) {
        // Simplified - would use oracle price in production
        // For now, assume 1:1 price for demonstration
        return collateralAmount;
    }

    function _calculateCurrentPrice(Auction memory auction) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - auction.startTime;
        if (timeElapsed >= auction.duration) {
            return 0;
        }
        
        return MathUtils.calculateAuctionPrice(auction.startingPrice, PRICE_DECAY_RATE, timeElapsed, auction.duration);
    }

    function _removeActiveAuction(uint256 auctionId) internal {
        for (uint256 i = 0; i < activeAuctions.length; i++) {
            if (activeAuctions[i] == auctionId) {
                activeAuctions[i] = activeAuctions[activeAuctions.length - 1];
                activeAuctions.pop();
                break;
            }
        }
    }
}





