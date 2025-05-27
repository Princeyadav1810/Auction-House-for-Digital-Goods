// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title DigitalAuction
 * @dev Smart contract for auctioning digital goods
 */
contract DigitalAuction {
    struct Auction {
        uint256 id;
        address payable seller;
        string digitalItemURI;
        string digitalItemDescription;
        uint256 startingPrice;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        bool ended;
        bool cancelled;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256[]) public userBids;
    mapping(address => uint256) public pendingReturns;
    uint256 public auctionCounter;

    // Events
    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string digitalItemURI, uint256 startingPrice, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 amount);
    event AuctionCancelled(uint256 indexed auctionId);
    event BidWithdrawn(address indexed bidder, uint256 amount);

    function createAuction(
        string memory _digitalItemURI,
        string memory _digitalItemDescription,
        uint256 _startingPrice,
        uint256 _durationInMinutes
    ) external {
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_durationInMinutes > 0, "Duration must be greater than 0");

        uint256 auctionId = auctionCounter++;
        uint256 endTime = block.timestamp + (_durationInMinutes * 1 minutes);

        auctions[auctionId] = Auction({
            id: auctionId,
            seller: payable(msg.sender),
            digitalItemURI: _digitalItemURI,
            digitalItemDescription: _digitalItemDescription,
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: payable(address(0)),
            endTime: endTime,
            ended: false,
            cancelled: false
        });

        emit AuctionCreated(auctionId, msg.sender, _digitalItemURI, _startingPrice, endTime);
    }

    function placeBid(uint256 _auctionId) external payable {
        Auction storage auction = auctions[_auctionId];

        require(block.timestamp < auction.endTime, "Auction has ended");
        require(!auction.ended, "Auction already finalized");
        require(!auction.cancelled, "Auction has been cancelled");
        require(msg.sender != auction.seller, "Seller cannot bid on their own auction");

        uint256 currentBid = msg.value;

        if (auction.highestBid == 0) {
            require(currentBid >= auction.startingPrice, "Bid must be at least the starting price");
        } else {
            require(currentBid > auction.highestBid, "Bid must be higher than current highest bid");
            // Instead of immediately refunding, add to pendingReturns for safe withdrawal
            pendingReturns[auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = currentBid;
        auction.highestBidder = payable(msg.sender);
        userBids[msg.sender].push(_auctionId);

        emit BidPlaced(_auctionId, msg.sender, currentBid);
    }

    function endAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];

        require(block.timestamp >= auction.endTime, "Auction has not ended yet");
        require(!auction.ended, "Auction already finalized");
        require(!auction.cancelled, "Auction has been cancelled");
        require(msg.sender == auction.seller || msg.sender == auction.highestBidder, "Only seller or highest bidder can end auction");

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            auction.seller.transfer(auction.highestBid);
            emit AuctionEnded(_auctionId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    function cancelAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender == auction.seller, "Only seller can cancel auction");
        require(!auction.ended, "Cannot cancel ended auction");
        require(auction.highestBid == 0, "Cannot cancel after receiving bids");

        auction.cancelled = true;
        auction.ended = true;

        emit AuctionCancelled(_auctionId);
    }

    // NEW: Withdraw previous bids safely
    function withdrawBid() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        // Reset before transfer to prevent re-entrancy
        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdraw failed");

        emit BidWithdrawn(msg.sender, amount);
    }

    // NEW: View auction details by ID
    function getAuctionDetails(uint256 _auctionId) external view returns (
        address seller,
        string memory uri,
        string memory description,
        uint256 startingPrice,
        uint256 highestBid,
        address highestBidder,
        uint256 endTime,
        bool ended,
        bool cancelled
    ) {
        Auction storage a = auctions[_auctionId];
        return (
            a.seller,
            a.digitalItemURI,
            a.digitalItemDescription,
            a.startingPrice,
            a.highestBid,
            a.highestBidder,
            a.endTime,
            a.ended,
            a.cancelled
        );
    }

    // NEW: View all auctions a user has bid on
    function getUserBids(address user) external view returns (uint256[] memory) {
        return userBids[user];
    }

    // NEW: Get contract balance (total ETH held)
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
