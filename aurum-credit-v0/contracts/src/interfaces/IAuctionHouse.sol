




// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAuctionHouse
 * @notice Interface for Dutch auction liquidation mechanism
 */
interface IAuctionHouse {
    // Events
    event AuctionStarted(uint256 indexed auctionId, uint256 indexed loanId, uint256 collateralAmount, uint256 startingPrice);
    event AuctionBid(uint256 indexed auctionId, address indexed bidder, uint256 bidAmount);
    event AuctionSettled(uint256 indexed auctionId, address indexed winner, uint256 finalPrice);
    event AuctionCancelled(uint256 indexed auctionId);

    // Structs
    struct Auction {
        uint256 id;
        uint256 loanId;
        address collateralToken;
        uint256 collateralAmount;
        uint256 startingPrice;
        uint256 currentPrice;
        uint256 startTime;
        uint256 duration;
        address highestBidder;
        uint256 highestBid;
        bool settled;
        bool cancelled;
    }

    // Functions
    function startAuction(uint256 loanId, address collateralToken, uint256 collateralAmount) external returns (uint256);
    function placeBid(uint256 auctionId, uint256 bidAmount) external;
    function settleAuction(uint256 auctionId) external;
    function cancelAuction(uint256 auctionId) external;
    
    // View functions
    function getAuction(uint256 auctionId) external view returns (Auction memory);
    function getActiveAuctions() external view returns (uint256[] memory);
    function getAuctionPrice(uint256 auctionId) external view returns (uint256);
    function isAuctionActive(uint256 auctionId) external view returns (bool);
}




