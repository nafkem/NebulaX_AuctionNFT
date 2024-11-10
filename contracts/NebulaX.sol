// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./chainlink.sol";
import "./Counters.sol";

contract NebulaX is ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    IERC20 public nativeToken;
    AggregatorV3Interface internal priceFeed;
    Counters.Counter private _listingIds;
    Counters.Counter private _tokenIds;
    Counters.Counter private _auctionIds;

    uint256 public AuctionId;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingWithdrawals; // Fixed undeclared identifier
    mapping(uint256 => address) private _creators;
    // State Variables
   
    Counters.Counter private _auctionCounter;    
    uint256 public listingFee = 1 * 10 ** 18;

    uint256 durationInMinutes = 1; // Desired auction duration in minutes
    uint256 durationInSeconds = durationInMinutes * 60; // Convert to seconds

    mapping(address => bool) public authorizedAddresses; // List of authorized addresses
    
    mapping(address => uint256) public creatorDIDs; // Simulated DID checks
    mapping(address => bool) public kycVerified; // KYC verification tracking
    mapping(uint256 => uint256) public likes; // Mapping to track likes on each auction
    mapping(uint256 => mapping(address => bool)) public hasLiked;

    struct Listing {
        uint256 tokenId;
        address creator;
        uint256 price;
        string tokenURI;
        bool isActive;
    }

    struct Auction {
        uint256 tokenId;
        uint256 auctionId;
        uint256 minBid;
        uint256 highestBid;
        address highestBidder;
        address creator;
        string tokenURI;
        uint256 endTime;
        bool isActive;
    }

    // Event declarations
     event AddressAuthorized(address indexed user); // Event for when an address is authorized
    event ListingCreated(uint256 indexed tokenId, uint256 price, address indexed creator);
    event ListingUpdated(uint256 indexed tokenId, uint256 price);
    event ListingSold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event AuctionCreated(uint256 auctionId, uint256 tokenId, uint256 minBid, uint256 endTime, address creator);
    event NewHighestBid(uint256 indexed auctionId, uint256 bidAmount, address indexed bidder);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 finalBid);
    event TipSent(address indexed tipper, address indexed creator, uint256 amount);
    event KYCVerified(address indexed user);

    constructor(address _nativeToken) ERC721("NebulaXNFT", "NXNFT")Ownable(msg.sender) {
        nativeToken = IERC20(_nativeToken);
        priceFeed = AggregatorV3Interface(0x3ec8593F930EA45ea58c968260e6e9FF53FC934f);
    }

    modifier onlyCreator(uint256 _tokenId) {
        require(_creators[_tokenId] == msg.sender, "Not the creator");
        _;
    }
    // Modifier to allow only KYC-verified and authorized addresses
modifier onlyVerifiedAndAuthorized(address user, uint256 DID) {
    require(kycVerified[user], "User must be KYC verified");
    require(authorizedAddresses[user], "User must be authorized");
    _;
}

function verifyKYC(address user, uint256 DID) external nonReentrant {
    require(user != address(0), "Invalid address");
    require(!kycVerified[user], "User is already KYC verified");
    
    // Mark the user as KYC verified
    kycVerified[user] = true;
    emit KYCVerified(user);
}

function authorizeAddress(address user, uint256 DID) external {
    require(kycVerified[user], "User must be KYC verified to authorize");
    require(!authorizedAddresses[user], "Address is already authorized");
    
    // Mark the address as authorized
    authorizedAddresses[user] = true;
    emit AddressAuthorized(user);
}


function verify(address user, uint256 DID) external view returns (bool isValid) {
    isValid = authorizedAddresses[user];
}

function restrictedFunction(address user, uint256 DID) external onlyVerifiedAndAuthorized(user, DID) {
    // Function logic for verified and authorized users
}

    receive() external payable {
        revert("This contract does not accept Ether");
    }

    fallback() external payable {
        revert("This contract does not accept Ether");
    }

       // Modifier to check if the caller is NOT the creator of the token
    modifier onlyNonCreator(uint256 tokenId) {
        require(_creators[tokenId] != msg.sender, "Caller is the creator");
        _;
    }

    modifier isKYCVerified() {
        require(kycVerified[msg.sender], "KYC not verified");
        _;
    }

    function mintAndListNFT(string memory _tokenURI, uint256 _price) external returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);

        _creators[newTokenId] = msg.sender;
        createListing(newTokenId, _price);

        return newTokenId;
    }

    function createListing(uint256 _tokenId, uint256 _price) public nonReentrant  {
        require(ownerOf(_tokenId) == msg.sender, "Not the owner");
        require(_price > 0, "Price must be greater than zero");

        _listingIds.increment();
        uint256 listingId = _listingIds.current();

        listings[listingId] = Listing({
            tokenId: _tokenId,
            creator: msg.sender,
            price: _price,
            tokenURI: tokenURI(_tokenId),
            isActive: true
        });

        emit ListingCreated(_tokenId, _price, msg.sender);
    }

    function updateListing(uint256 _tokenId, uint256 _newPrice) external nonReentrant  {
        Listing storage listing = listings[_tokenId];
        require(listing.isActive, "Listing is not active");
        require(_newPrice > 0, "Price must be greater than zero");

        listing.price = _newPrice;
        emit ListingUpdated(_tokenId, _newPrice);
    }

    function buyNFT(uint256 _tokenId) external nonReentrant {
        Listing storage listing = listings[_tokenId];
        require(listing.isActive, "Listing is not active");

        uint256 fee = (listing.price * 1) / 100;
        uint256 creatorAmount = listing.price - fee;

        require(nativeToken.transferFrom(msg.sender, listing.creator, creatorAmount), "Payment failed to creator");
        require(nativeToken.transferFrom(msg.sender, owner(), fee), "Payment failed to platform");

        _transfer(listing.creator, msg.sender, _tokenId);
        listing.isActive = false;

        emit ListingSold(_tokenId, msg.sender, listing.price);
    }

    function createAuction(uint256 _tokenId, uint256 _minBid, uint256 _durationInMinutes) external  {
        require(_minBid > 0, "Minimum bid must be greater than zero");
        require(_durationInMinutes > 0, "Duration must be greater than zero");

        uint256 durationInSeconds = _durationInMinutes * 60;
        uint256 endTime = block.timestamp + durationInSeconds;

        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();

        auctions[auctionId] = Auction({
            auctionId: auctionId,
            tokenId: _tokenId,
            creator: msg.sender,
            highestBid: 0,
            highestBidder: address(0),
            endTime: endTime,
            isActive: true,
            tokenURI: tokenURI(_tokenId),
            minBid: _minBid
        });

        emit AuctionCreated(auctionId, _tokenId, _minBid, endTime, msg.sender);
    }

    function placeBid(uint256 _auctionId, uint256 _bidAmount) external nonReentrant {
        Auction storage auction = auctions[_auctionId];
        require(auction.isActive, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(_bidAmount > auction.highestBid, "Bid must be higher than the current highest bid");

        if (auction.highestBidder != address(0)) {
            pendingWithdrawals[auction.highestBidder] += auction.highestBid;
        }

        require(nativeToken.transferFrom(msg.sender, address(this), _bidAmount), "Bid transfer failed");

        auction.highestBidder = msg.sender;
        auction.highestBid = _bidAmount;
        emit NewHighestBid(_auctionId, _bidAmount, msg.sender);
    }

    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;
        require(nativeToken.transfer(msg.sender, amount), "Transfer failed");
    }

    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.isActive, "Auction is already ended");
        require(block.timestamp >= auction.endTime, "Auction has not ended yet");

        auction.isActive = false;

        uint256 fee = (auction.highestBid * 1) / 100;
        uint256 creatorAmount = auction.highestBid - fee;

        require(nativeToken.transfer(auction.creator, creatorAmount), "Payment to creator failed");
        require(nativeToken.transfer(owner(), fee), "Payment to platform failed");

        emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);
    }

    function getListedItems() external view returns (Listing[] memory) {
        uint256 totalListings = _listingIds.current();
        uint256 listedCount = 0;

        for (uint256 i = 1; i <= totalListings; i++) {
            if (listings[i].isActive) {
                listedCount++;
            }
        }

        Listing[] memory listedItems = new Listing[](listedCount);
        uint256 index = 0;

        for (uint256 i = 1; i <= totalListings; i++) {
            if (listings[i].isActive) {
                listedItems[index] = listings[i];
                index++;
            }
        }

        return listedItems;
    }

    function getAuctionItems() external view returns (Auction[] memory) {
        uint256 totalAuctions = _auctionIds.current();
        uint256 activeCount = 0;

        for (uint256 i = 1; i <= totalAuctions; i++) {
            if (auctions[i].isActive) {
                activeCount++;
            }
        }

        Auction[] memory activeAuctions = new Auction[](activeCount);
        uint256 index = 0;

        for (uint256 i = 1; i <= totalAuctions; i++) {
            if (auctions[i].isActive) {
                activeAuctions[index] = auctions[i];
                index++;
            }
        }

        return activeAuctions;
    }
}