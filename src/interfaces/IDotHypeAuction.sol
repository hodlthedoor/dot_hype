// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDotHypeAuction
 * @dev Interface for the DotHype auction contract
 */
interface IDotHypeAuction {
    /**
     * @dev Struct representing an auction
     * @param name The name being auctioned
     * @param startTime The timestamp when the auction starts
     * @param endTime The timestamp when the auction ends
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     * @param winner The address of the auction winner (zero address if no winner yet)
     * @param settled Whether the auction has been settled
     */
    struct Auction {
        string name;
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        uint256 endPrice;
        address winner;
        bool settled;
    }

    /**
     * @dev Emitted when an auction is created
     * @param name The name being auctioned
     * @param startTime The timestamp when the auction starts
     * @param endTime The timestamp when the auction ends
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     */
    event AuctionCreated(
        string indexed name,
        uint256 startTime,
        uint256 endTime,
        uint256 startPrice,
        uint256 endPrice
    );

    /**
     * @dev Emitted when an auction is claimed by a bidder
     * @param name The name that was auctioned
     * @param winner The address of the auction winner
     * @param price The price paid for the name
     */
    event AuctionClaimed(string indexed name, address indexed winner, uint256 price);

    /**
     * @dev Emitted when an auction ends without a winner
     * @param name The name that was auctioned
     */
    event AuctionEnded(string indexed name);

    /**
     * @dev Creates a new Dutch auction for a premium name
     * @param name The name to auction
     * @param startTime The timestamp when the auction starts
     * @param endTime The timestamp when the auction ends
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     */
    function createAuction(
        string calldata name,
        uint256 startTime,
        uint256 endTime,
        uint256 startPrice,
        uint256 endPrice
    ) external;

    /**
     * @dev Places a bid to claim a Dutch auction at the current price
     * @param name The name being auctioned
     */
    function bid(string calldata name) external payable;

    /**
     * @dev Settles an auction after it has ended
     * @param name The name to settle
     */
    function settleAuction(string calldata name) external;

    /**
     * @dev Gets information about an auction
     * @param name The name being auctioned
     * @return The auction details
     */
    function getAuction(string calldata name) external view returns (Auction memory);

    /**
     * @dev Calculates the current price of an auction
     * @param name The name being auctioned
     * @return price The current price
     */
    function getCurrentPrice(string calldata name) external view returns (uint256 price);

    /**
     * @dev Gets the number of active auctions
     * @return count The number of active auctions
     */
    function getActiveAuctionCount() external view returns (uint256 count);

    /**
     * @dev Gets a list of active auctions
     * @param offset The starting index
     * @param limit The maximum number of auctions to return
     * @return activeAuctions The list of active auctions
     */
    function getActiveAuctions(uint256 offset, uint256 limit) external view returns (Auction[] memory activeAuctions);
} 