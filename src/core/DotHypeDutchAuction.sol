// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./DotHypeController.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title DotHypeDutchAuction
 * @dev Extension of DotHypeController that implements Dutch auction functionality
 * Dutch auctions start at a higher price and decrease linearly over time
 * Domain prices include both the auction premium and the base registration fee
 */
contract DotHypeDutchAuction is DotHypeController {
    using ECDSA for bytes32;

    error AuctionNotActive();
    error InvalidBatchId();
    error DomainNotInAuction();
    error DomainAlreadyInAuction();
    error InvalidAuctionConfig();
    error AuctionAlreadyStarted();

    bytes32 private constant DUTCH_AUCTION_REGISTRATION_TYPEHASH = keccak256(
        "DutchAuctionRegistration(string name,address owner,uint256 duration,uint256 maxPrice,uint256 deadline,uint256 nonce)"
    );

    struct DutchAuctionConfig {
        uint256 startPrice;
        uint256 endPrice;
        uint256 auctionDuration;
        uint256 startTime;
        bool isActive;
    }

    mapping(uint256 => DutchAuctionConfig) public auctionBatches;
    mapping(bytes32 => uint256) public domainToBatchId;
    uint256 public nextBatchId = 1;
    mapping(uint256 => bytes32[]) public batchDomains;

    event DutchAuctionBatchCreated(
        uint256 indexed batchId, uint256 startPrice, uint256 endPrice, uint256 duration, uint256 startTime
    );
    event DomainAddedToAuctionBatch(uint256 indexed batchId, bytes32 indexed nameHash, string name);
    event DutchAuctionPurchase(
        string name, address owner, uint256 duration, uint256 basePrice, uint256 auctionPrice, uint256 totalPrice
    );

    /**
     * @dev Constructor
     * @param _registry Address of the registry contract
     * @param _signer Address authorized to sign minting requests
     * @param _priceOracle Address of the price oracle for USD conversion
     * @param _owner Initial owner of the contract
     */
    constructor(address _registry, address _signer, address _priceOracle, address _owner)
        DotHypeController(_registry, _signer, _priceOracle, _owner)
    {}

    /**
     * @dev Create a new Dutch auction batch
     * @param domains Array of domain names to include in this auction
     * @param startPrice Starting price in USD (1e18 = $1)
     * @param endPrice Ending price in USD (typically 0)
     * @param auctionDuration Duration of the auction in seconds
     * @param startTime Timestamp when the auction starts (use 0 for immediate start)
     * @return batchId The ID of the created auction batch
     */
    function createDutchAuctionBatch(
        string[] calldata domains,
        uint256 startPrice,
        uint256 endPrice,
        uint256 auctionDuration,
        uint256 startTime
    ) external onlyOwner returns (uint256 batchId) {
        if (startPrice <= endPrice) {
            revert InvalidAuctionConfig();
        }
        if (auctionDuration == 0) {
            revert InvalidAuctionConfig();
        }

        if (startTime == 0) {
            startTime = block.timestamp;
        } else if (startTime < block.timestamp) {
            revert InvalidAuctionConfig();
        }

        batchId = nextBatchId++;

        auctionBatches[batchId] = DutchAuctionConfig({
            startPrice: startPrice,
            endPrice: endPrice,
            auctionDuration: auctionDuration,
            startTime: startTime,
            isActive: true
        });

        for (uint256 i = 0; i < domains.length; i++) {
            _addDomainToAuction(batchId, domains[i]);
        }

        emit DutchAuctionBatchCreated(batchId, startPrice, endPrice, auctionDuration, startTime);

        return batchId;
    }

    /**
     * @dev Internal function to add a domain to an auction batch
     * @param batchId The ID of the auction batch
     * @param name The domain name to add
     */
    function _addDomainToAuction(uint256 batchId, string memory name) internal {
        bytes32 nameHash = keccak256(bytes(name));

        if (domainToBatchId[nameHash] != 0) {
            revert DomainAlreadyInAuction();
        }

        domainToBatchId[nameHash] = batchId;
        batchDomains[batchId].push(nameHash);

        emit DomainAddedToAuctionBatch(batchId, nameHash, name);
    }

    /**
     * @dev Calculate current Dutch auction price for a domain
     * @param name Domain name
     * @param duration Registration duration in seconds
     * @return basePrice The base registration price for the domain length
     * @return auctionPrice The current auction price component
     * @return totalPrice The total price (base + auction)
     */
    function calculateDutchAuctionPrice(string memory name, uint256 duration)
        public
        view
        returns (uint256 basePrice, uint256 auctionPrice, uint256 totalPrice)
    {
        bytes32 nameHash = keccak256(bytes(name));
        uint256 batchId = domainToBatchId[nameHash];

        basePrice = super.calculatePrice(name, duration);

        if (batchId == 0 || !auctionBatches[batchId].isActive) {
            return (basePrice, 0, basePrice);
        }

        DutchAuctionConfig memory config = auctionBatches[batchId];

        if (block.timestamp < config.startTime) {
            uint256 maxAuctionUsdPrice = config.startPrice;
            auctionPrice = priceOracle.usdToHype(maxAuctionUsdPrice);
            totalPrice = basePrice + auctionPrice;
            return (basePrice, auctionPrice, totalPrice);
        }

        uint256 auctionEndTime = config.startTime + config.auctionDuration;
        if (block.timestamp >= auctionEndTime) {
            uint256 minAuctionUsdPrice = config.endPrice;
            auctionPrice = priceOracle.usdToHype(minAuctionUsdPrice);
            totalPrice = basePrice + auctionPrice;
            return (basePrice, auctionPrice, totalPrice);
        }

        uint256 elapsed = block.timestamp - config.startTime;
        uint256 priceDrop = config.startPrice - config.endPrice;
        uint256 currentUsdPrice = config.startPrice - (priceDrop * elapsed / config.auctionDuration);

        auctionPrice = priceOracle.usdToHype(currentUsdPrice);
        totalPrice = basePrice + auctionPrice;

        return (basePrice, auctionPrice, totalPrice);
    }

    /**
     * @dev Verify a signature for Dutch auction domain registration
     * @param name Domain name to register (without .hype)
     * @param owner Address that will own the domain
     * @param duration Registration duration in seconds
     * @param maxPrice Maximum price willing to pay (to prevent front-running)
     * @param deadline Timestamp after which signature expires
     * @param signature EIP-712 signature authorizing the registration
     * @return True if signature is valid
     */
    function _verifyDutchAuctionSignature(
        string calldata name,
        address owner,
        uint256 duration,
        uint256 maxPrice,
        uint256 deadline,
        bytes calldata signature
    ) internal returns (bool) {
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        uint256 nonce = nonces[owner]++;

        bytes32 structHash = keccak256(
            abi.encode(
                DUTCH_AUCTION_REGISTRATION_TYPEHASH, keccak256(bytes(name)), owner, duration, maxPrice, deadline, nonce
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);

        address recoveredSigner = ECDSA.recover(hash, signature);
        require (recoveredSigner == signer, InvalidSigner());

        return true;
    }

    /**
     * @dev Check if a domain is in an active auction
     * @param name Domain name to check
     * @return isInAuction Whether the domain is in an active auction
     * @return batchId The batch ID the domain is in (0 if not in auction)
     */
    function isDomainInAuction(string memory name) public view returns (bool isInAuction, uint256 batchId) {
        bytes32 nameHash = keccak256(bytes(name));
        batchId = domainToBatchId[nameHash];

        if (batchId == 0) {
            return (false, 0);
        }

        isInAuction = auctionBatches[batchId].isActive;
        return (isInAuction, batchId);
    }

    /**
     * @dev Internal function to handle Dutch auction domain registration
     * @param name Domain name to register
     * @param owner Address that will own the domain
     * @param duration Registration duration in seconds
     * @param maxPrice Maximum price willing to pay
     * @return tokenId The token ID of the registered domain
     * @return expiry The expiry timestamp of the registration
     */
    function _registerDutchAuctionDomain(
        string memory name,
        address owner,
        uint256 duration,
        uint256 maxPrice
    ) internal returns (uint256 tokenId, uint256 expiry) {
        (uint256 basePrice, uint256 auctionPrice, uint256 totalPrice) = calculateDutchAuctionPrice(name, duration);

        (bool isInAuction, uint256 batchId) = isDomainInAuction(name);
        if (!isInAuction) {
            revert DomainNotInAuction();
        }

        if (totalPrice > maxPrice) {
            revert InsufficientPayment(totalPrice, maxPrice);
        }

        bytes32 nameHash = keccak256(bytes(name));
        address reservedFor = reservedNames[nameHash];
        if (reservedFor != address(0) && reservedFor != owner) {
            revert NameIsReserved(nameHash, reservedFor);
        }

        _processPayment(totalPrice);

        (tokenId, expiry) = registry.register(name, owner, duration);

        domainToBatchId[nameHash] = 0;

        emit DutchAuctionPurchase(name, owner, duration, basePrice, auctionPrice, totalPrice);
        emit DomainRegistered(name, owner, duration, totalPrice);

        return (tokenId, expiry);
    }

    /**
     * @dev Register a domain from a Dutch auction with signature-based authorization
     * @param name Domain name to register (without .hype)
     * @param owner Address that will own the domain
     * @param duration Registration duration in seconds
     * @param maxPrice Maximum price willing to pay (to prevent front-running)
     * @param deadline Timestamp after which signature expires
     * @param signature EIP-712 signature authorizing the registration
     */
    function registerDutchAuctionWithSignature(
        string calldata name,
        address owner,
        uint256 duration,
        uint256 maxPrice,
        uint256 deadline,
        bytes calldata signature
    ) external payable returns (uint256 tokenId, uint256 expiry) {
        _verifyDutchAuctionSignature(name, owner, duration, maxPrice, deadline, signature);
        return _registerDutchAuctionDomain(name, owner, duration, maxPrice);
    }

    /**
     * @dev Direct purchase of a domain from a Dutch auction (without signature verification)
     * @param name Domain name to register (without .hype)
     * @param duration Registration duration in seconds
     * @param maxPrice Maximum price willing to pay
     */
    function purchaseDutchAuction(string calldata name, uint256 duration, uint256 maxPrice)
        external
        payable
        onlyOwner
        returns (uint256 tokenId, uint256 expiry)
    {
        return _registerDutchAuctionDomain(name, msg.sender, duration, maxPrice);
    }

    /**
     * @dev Get current auction status and details
     * @param batchId The auction batch ID to check
     * @return config The auction configuration
     * @return currentPrice Current Dutch auction price in USD
     * @return timeRemaining Time remaining in the auction in seconds
     * @return isActive Whether the auction is currently active
     * @return hasStarted Whether the auction has started
     * @return isComplete Whether the auction is complete
     */
    function getAuctionStatus(uint256 batchId)
        external
        view
        returns (
            DutchAuctionConfig memory config,
            uint256 currentPrice,
            uint256 timeRemaining,
            bool isActive,
            bool hasStarted,
            bool isComplete
        )
    {
        if (batchId == 0 || batchId >= nextBatchId) {
            revert InvalidBatchId();
        }

        config = auctionBatches[batchId];
        isActive = config.isActive;
        hasStarted = block.timestamp >= config.startTime;

        uint256 auctionEndTime = config.startTime + config.auctionDuration;
        isComplete = block.timestamp >= auctionEndTime;

        timeRemaining = isComplete ? 0 : auctionEndTime - block.timestamp;

        if (!hasStarted) {
            currentPrice = config.startPrice;
        } else if (isComplete) {
            currentPrice = config.endPrice;
        } else {
            uint256 elapsed = block.timestamp - config.startTime;
            uint256 priceDrop = config.startPrice - config.endPrice;
            currentPrice = config.startPrice - (priceDrop * elapsed / config.auctionDuration);
        }

        return (config, currentPrice, timeRemaining, isActive, hasStarted, isComplete);
    }

    /**
     * @dev Get the domains in a specific auction batch
     * @param batchId The ID of the auction batch
     * @return domains Array of name hashes in this batch
     */
    function getBatchDomains(uint256 batchId) external view returns (bytes32[] memory) {
        if (batchId == 0 || batchId >= nextBatchId) {
            revert InvalidBatchId();
        }

        return batchDomains[batchId];
    }
}
