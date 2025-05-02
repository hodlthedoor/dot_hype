// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../interfaces/IDotHypeRegistry.sol";
import "../interfaces/IPriceOracle.sol";

/**
 * @title DotHypeController
 * @dev Controller contract for managing domain registration and renewal
 * Implements EIP-712 typed data signature-based minting to prevent front-running
 * Prices are always in USD, converted to HYPE tokens via price oracle
 */
contract DotHypeController is Ownable, EIP712 {
    using ECDSA for bytes32;

    // Custom errors
    error SignatureExpired();
    error InvalidSignature();
    error InvalidSigner();
    error InsufficientPayment(uint256 required, uint256 provided);
    error WithdrawalFailed();
    error PricingNotSet();
    error InvalidCharacterCount(uint256 count);
    error CharacterLengthNotAvailable(uint256 count);
    error InvalidPriceConfig();
    error OracleNotSet();
    error FundsTransferFailed();
    error NameIsReserved(bytes32 nameHash, address reservedFor);
    error NotReserved(string name);
    error NotAuthorized(address caller, bytes32 nameHash);
    error InvalidMerkleProof();
    error MerkleRootNotSet();
    error AlreadyMinted(address minter);

    // Registration params struct to avoid stack too deep errors
    struct RegistrationParams {
        string name;
        address owner;
        uint256 duration;
        uint256 maxPrice;
        uint256 deadline;
        bytes signature;
    }

    // Registry contract
    IDotHypeRegistry public registry;

    // Signer address authorized to sign registration requests
    address public signer;

    // Annual prices array, indexed by character length
    // Index 0: not used
    // Index 1: 1-character domains - price in USD (1e18 = $1)
    // Index 2: 2-character domains - price in USD
    // Index 3: 3-character domains - price in USD
    // Index 4: 4-character domains - price in USD
    // Index 5: 5+ character domains - price in USD
    uint256[6] public annualPrices;

    // Price oracle for USD pricing
    IPriceOracle public priceOracle;

    // Payment recipient
    address public paymentRecipient;

    // Reserved names mapping: nameHash => reserved for address
    mapping(bytes32 => address) public reservedNames;

    // Merkle root for allowlist
    bytes32 public merkleRoot;
    
    // Tracking which addresses have used their merkle proofs
    mapping(address => bool) public hasUsedMerkleProof;

    // EIP-712 type hash
    bytes32 private constant REGISTRATION_TYPEHASH = keccak256(
        "Registration(string name,address owner,uint256 duration,uint256 maxPrice,uint256 deadline,uint256 nonce)"
    );

    // Nonce mapping per address to prevent replay attacks
    mapping(address => uint256) public nonces;

    // Events
    event DomainRegistered(string name, address owner, uint256 duration, uint256 price);
    event DomainRenewed(uint256 tokenId, uint256 duration, uint256 price);
    event SignerUpdated(address newSigner);
    event AnnualPriceUpdated(uint256 charCount, uint256 price);
    event PaymentRecipientUpdated(address recipient);
    event Withdrawn(address recipient, uint256 amount);
    event PriceOracleUpdated(address oracle);
    event NameReserved(bytes32 indexed nameHash, address indexed reservedFor);
    event NameReservationRemoved(bytes32 indexed nameHash);
    event ReservedNameRegistered(string name, address owner, uint256 duration);
    event MerkleRootUpdated(bytes32 merkleRoot);
    event MerkleProofRegistration(string name, address owner, uint256 duration);

    /**
     * @dev Constructor
     * @param _registry Address of the registry contract
     * @param _signer Address authorized to sign minting requests
     * @param _priceOracle Address of the price oracle for USD conversion
     * @param _owner Initial owner of the contract
     */
    constructor(address _registry, address _signer, address _priceOracle, address _owner)
        Ownable(_owner)
        EIP712("DotHypeController", "1")
    {
        require(_priceOracle != address(0), OracleNotSet());

        registry = IDotHypeRegistry(_registry);
        signer = _signer;
        priceOracle = IPriceOracle(_priceOracle);
        paymentRecipient = _owner; // Default payment recipient is the owner
    }

    /**
     * @dev Verify a signature for domain registration
     * @param name Domain name to register (without .hype)
     * @param owner Address that will own the domain
     * @param duration Registration duration in seconds
     * @param maxPrice Maximum price willing to pay (to prevent front-running)
     * @param deadline Timestamp after which signature expires
     * @param signature EIP-712 signature authorizing the registration
     * @return True if signature is valid
     */
    function _verifySignature(
        string calldata name,
        address owner,
        uint256 duration,
        uint256 maxPrice,
        uint256 deadline,
        bytes calldata signature
    ) internal returns (bool) {
        // Check if signature is expired
        require(block.timestamp <= deadline, SignatureExpired());

        uint256 nonce = nonces[owner]++;

        // Verify EIP-712 signature
        bytes32 structHash = keccak256(
            abi.encode(REGISTRATION_TYPEHASH, keccak256(bytes(name)), owner, duration, maxPrice, deadline, nonce)
        );
        bytes32 hash = _hashTypedDataV4(structHash);

        // Recover signer and check
        address recoveredSigner = ECDSA.recover(hash, signature);
        require(recoveredSigner == signer, InvalidSigner());

        return true;
    }

    /**
     * @dev Process a registration payment
     * @param price The price to pay
     * @return The processed payment amount
     */
    function _processPayment(uint256 price) internal returns (uint256) {
        // Check if payment is sufficient
        require(msg.value >= price, InsufficientPayment(price, msg.value));

        // Forward payment to the recipient
        if (price > 0 && paymentRecipient != address(0)) {
            (bool success,) = paymentRecipient.call{value: price}("");
            require(success, FundsTransferFailed());
        }

        // Refund excess payment
        if (msg.value > price) {
            (bool success,) = payable(msg.sender).call{value: msg.value - price}("");
            require(success, FundsTransferFailed());
        }

        return price;
    }

    /**
     * @dev Register a domain with EIP-712 signature-based authorization
     * @param name Domain name to register (without .hype)
     * @param owner Address that will own the domain
     * @param duration Registration duration in seconds
     * @param maxPrice Maximum price willing to pay (to prevent front-running)
     * @param deadline Timestamp after which signature expires
     * @param signature EIP-712 signature authorizing the registration
     */
    function registerWithSignature(
        string calldata name,
        address owner,
        uint256 duration,
        uint256 maxPrice,
        uint256 deadline,
        bytes calldata signature
    ) external payable returns (uint256 tokenId, uint256 expiry) {
        // Check if name is reserved
        bytes32 nameHash = keccak256(bytes(name));
        address reservedFor = reservedNames[nameHash];
        if (reservedFor != address(0) && reservedFor != owner) {
            revert NameIsReserved(nameHash, reservedFor);
        }

        // Verify signature
        _verifySignature(name, owner, duration, maxPrice, deadline, signature);

        // Calculate price
        uint256 price = calculatePrice(name, duration);

        // Check if domain has max price (effectively unavailable)
        if (price == type(uint256).max) {
            revert CharacterLengthNotAvailable(bytes(name).length);
        }

        // Check if price is acceptable
        require(price <= maxPrice, InsufficientPayment(price, maxPrice));

        // Process payment
        _processPayment(price);

        // Register domain
        (tokenId, expiry) = registry.register(name, owner, duration);

        emit DomainRegistered(name, owner, duration, price);
    }

    /**
     * @dev Register a reserved domain
     * @param name Domain name to register (without .hype)
     * @param duration Registration duration in seconds
     */
    function registerReserved(string calldata name, uint256 duration)
        external
        payable
        returns (uint256 tokenId, uint256 expiry)
    {
        bytes32 nameHash = keccak256(bytes(name));
        address reservedFor = reservedNames[nameHash];

        // Check if the name is reserved for the sender
        if (reservedFor == address(0)) {
            revert NotReserved(name);
        }
        if (reservedFor != msg.sender) {
            revert NotAuthorized(msg.sender, nameHash);
        }

        // Calculate price
        uint256 price = calculatePrice(name, duration);

        // Process payment
        _processPayment(price);

        // Register domain
        (tokenId, expiry) = registry.register(name, msg.sender, duration);

        // Clear the reservation by setting it to address(0)
        reservedNames[nameHash] = address(0);

        emit ReservedNameRegistered(name, msg.sender, duration);
        emit NameReservationRemoved(nameHash);
    }

    /**
     * @dev Renew a domain - anyone can renew any domain
     * @param tokenId Token ID of the domain to renew
     * @param duration Renewal duration in seconds
     */
    function renew(uint256 tokenId, uint256 duration) external payable returns (uint256 expiry) {
        // Calculate price
        string memory name = registry.tokenIdToName(tokenId);
        uint256 price = calculatePrice(name, duration);

        // Process payment
        _processPayment(price);

        // Renew domain
        expiry = registry.renew(tokenId, duration);

        emit DomainRenewed(tokenId, duration, price);
    }

    /**
     * @dev Get the next nonce for an address
     * @param owner The address to get the nonce for
     * @return The next nonce for this address
     */
    function getNextNonce(address owner) external view returns (uint256) {
        return nonces[owner];
    }

    /**
     * @dev Calculate price for domain registration or renewal
     * @param name Domain name
     * @param duration Registration/renewal duration in seconds
     * @return price Final price in HYPE tokens
     */
    function calculatePrice(string memory name, uint256 duration) public view returns (uint256 price) {
        bytes memory nameBytes = bytes(name);
        uint256 charCount = nameBytes.length;

        // Get price index (1-5, with 5 used for all longer names)
        uint256 priceIndex = charCount < 5 ? charCount : 5;

        // Make sure price index is valid (greater than 0)
        require(priceIndex > 0, InvalidCharacterCount(charCount));

        // Get annual price in USD (1e18 = $1)
        uint256 annualPrice = annualPrices[priceIndex];

        // Check if price is set
        require(annualPrice > 0, PricingNotSet());

        // Handle special case for effectively unavailable domains (type(uint256).max)
        if (annualPrice == type(uint256).max) {
            return type(uint256).max;
        }

        // Calculate USD price based on duration (proportional to 365 days)
        uint256 usdPrice = (annualPrice * duration) / 365 days;

        // Convert USD price to HYPE tokens using the oracle
        price = priceOracle.usdToHype(usdPrice);

        return price;
    }

    /**
     * @dev Set a name reservation
     * @param name Domain name to reserve (without .hype)
     * @param reservedFor Address that can register the reserved name (use address(0) to remove reservation)
     */
    function setReservation(string calldata name, address reservedFor) external onlyOwner {
        bytes32 nameHash = keccak256(bytes(name));
        reservedNames[nameHash] = reservedFor;
        
        if (reservedFor == address(0)) {
            emit NameReservationRemoved(nameHash);
        } else {
            emit NameReserved(nameHash, reservedFor);
        }
    }

    /**
     * @dev Set multiple name reservations at once
     * @param names Array of domain names to reserve (without .hype)
     * @param reservedAddresses Array of addresses that can register the reserved names (use address(0) to remove reservation)
     */
    function setBatchReservations(string[] calldata names, address[] calldata reservedAddresses) external onlyOwner {
        require(names.length == reservedAddresses.length, "Array lengths mismatch");

        for (uint256 i = 0; i < names.length; i++) {
            bytes32 nameHash = keccak256(bytes(names[i]));
            reservedNames[nameHash] = reservedAddresses[i];
            
            if (reservedAddresses[i] == address(0)) {
                emit NameReservationRemoved(nameHash);
            } else {
                emit NameReserved(nameHash, reservedAddresses[i]);
            }
        }
    }

    /**
     * @dev Check if a name is reserved and for whom
     * @param name Domain name to check (without .hype)
     * @return isReserved Whether the name is reserved
     * @return reservedFor Address the name is reserved for (address(0) if not reserved)
     */
    function checkReservation(string calldata name) external view returns (bool isReserved, address reservedFor) {
        bytes32 nameHash = keccak256(bytes(name));
        reservedFor = reservedNames[nameHash];
        isReserved = reservedFor != address(0);
        return (isReserved, reservedFor);
    }

    /**
     * @dev Update signer address
     * @param _signer New signer address
     */
    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
        emit SignerUpdated(_signer);
    }

    /**
     * @dev Set annual price for a specific character count
     * @param charCount Character count (1-5, with 5 representing 5+ characters)
     * @param annualPrice Annual price in USD (1e18 = $1)
     */
    function setAnnualPrice(uint256 charCount, uint256 annualPrice) external onlyOwner {
        // Ensure charCount is within valid range (1-5)
        require(charCount >= 1 && charCount <= 5, InvalidCharacterCount(charCount));

        // Set the price
        annualPrices[charCount] = annualPrice;

        emit AnnualPriceUpdated(charCount, annualPrice);
    }

    /**
     * @dev Set all annual prices at once
     * @param prices Array of 5 prices in USD (1e18 = $1)
     *               [1-char, 2-char, 3-char, 4-char, 5+ char]
     */
    function setAllAnnualPrices(uint256[5] calldata prices) external onlyOwner {
        for (uint256 i = 0; i < 5; i++) {
            annualPrices[i + 1] = prices[i];
            emit AnnualPriceUpdated(i + 1, prices[i]);
        }
    }

    /**
     * @dev Set payment recipient address
     * @param _paymentRecipient Address to receive all payments
     */
    function setPaymentRecipient(address _paymentRecipient) external onlyOwner {
        paymentRecipient = _paymentRecipient;
        emit PaymentRecipientUpdated(_paymentRecipient);
    }

    /**
     * @dev Set the price oracle address
     * @param _priceOracle Address of the price oracle contract
     */
    function setPriceOracle(address _priceOracle) external onlyOwner {
        require(_priceOracle != address(0), OracleNotSet());
        priceOracle = IPriceOracle(_priceOracle);
        emit PriceOracleUpdated(_priceOracle);
    }

    /**
     * @dev Withdraw contract balance if any remains
     * @param recipient Address to receive funds
     */
    function withdraw(address recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) return;

        (bool success,) = recipient.call{value: balance}("");
        require(success, WithdrawalFailed());

        emit Withdrawn(recipient, balance);
    }

    /**
     * @dev Update registry address
     * @param _registry New registry address
     */
    function setRegistry(address _registry) external onlyOwner {
        registry = IDotHypeRegistry(_registry);
    }

    /**
     * @dev Set the merkle root for the allowlist
     * @param _merkleRoot New merkle root
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /**
     * @dev Register a domain using a merkle proof to verify allowlist inclusion
     * @param name Domain name to register (without .hype)
     * @param duration Registration duration in seconds
     * @param merkleProof Merkle proof verifying the sender is in the allowlist
     */
    function registerWithMerkleProof(
        string calldata name,
        uint256 duration,
        bytes32[] calldata merkleProof
    ) external payable returns (uint256 tokenId, uint256 expiry) {
        // Check if merkle root is set
        if (merkleRoot == bytes32(0)) {
            revert MerkleRootNotSet();
        }
        
        // Check if address has already used their merkle proof
        if (hasUsedMerkleProof[msg.sender]) {
            revert AlreadyMinted(msg.sender);
        }

        // Verify the merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        // Check if name is reserved
        bytes32 nameHash = keccak256(bytes(name));
        address reservedFor = reservedNames[nameHash];
        if (reservedFor != address(0) && reservedFor != msg.sender) {
            revert NameIsReserved(nameHash, reservedFor);
        }

        // Calculate price
        uint256 price = calculatePrice(name, duration);

        // Check if domain has max price (effectively unavailable)
        if (price == type(uint256).max) {
            revert CharacterLengthNotAvailable(bytes(name).length);
        }

        // Process payment
        _processPayment(price);

        // Register domain
        (tokenId, expiry) = registry.register(name, msg.sender, duration);
        
        // Mark that this address has used their merkle proof
        hasUsedMerkleProof[msg.sender] = true;

        emit MerkleProofRegistration(name, msg.sender, duration);
        emit DomainRegistered(name, msg.sender, duration, price);
    }

    /**
     * @dev Check if an address has already minted using their merkle proof
     * @param user Address to check
     * @return True if the address has already minted
     */
    function hasAddressUsedMerkleProof(address user) external view returns (bool) {
        return hasUsedMerkleProof[user];
    }

    /**
     * @dev Reset merkle proof usage for addresses (admin only)
     * @param users Array of addresses to reset
     */
    function resetMerkleProofUsage(address[] calldata users) external onlyOwner {
        for (uint i = 0; i < users.length; i++) {
            hasUsedMerkleProof[users[i]] = false;
        }
    }

    /**
     * @dev Receive function
     */
    receive() external payable {}
}
