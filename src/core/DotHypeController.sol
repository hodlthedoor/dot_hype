// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
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
        if (_priceOracle == address(0)) revert OracleNotSet();

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
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        uint256 nonce = nonces[owner]++;

        // Verify EIP-712 signature
        bytes32 structHash = keccak256(
            abi.encode(REGISTRATION_TYPEHASH, keccak256(bytes(name)), owner, duration, maxPrice, deadline, nonce)
        );
        bytes32 hash = _hashTypedDataV4(structHash);

        // Recover signer and check
        address recoveredSigner = ECDSA.recover(hash, signature);
        if (recoveredSigner != signer) {
            revert InvalidSigner();
        }

        return true;
    }

    /**
     * @dev Process a registration payment
     * @param price The price to pay
     * @return The processed payment amount
     */
    function _processPayment(uint256 price) internal returns (uint256) {
        // Check if payment is sufficient
        if (msg.value < price) {
            revert InsufficientPayment(price, msg.value);
        }

        // Forward payment to the recipient
        if (price > 0 && paymentRecipient != address(0)) {
            (bool success,) = paymentRecipient.call{value: price}("");
            if (!success) {
                revert FundsTransferFailed();
            }
        }

        // Refund excess payment
        if (msg.value > price) {
            (bool success,) = payable(msg.sender).call{value: msg.value - price}("");
            if (!success) {
                revert FundsTransferFailed();
            }
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
        // Verify signature
        _verifySignature(name, owner, duration, maxPrice, deadline, signature);

        // Calculate price
        uint256 price = calculatePrice(name, duration);

        // Check if price is acceptable
        if (price > maxPrice) {
            revert InsufficientPayment(price, maxPrice);
        }

        // Process payment
        _processPayment(price);

        // Register domain
        (tokenId, expiry) = registry.register(name, owner, duration);

        emit DomainRegistered(name, owner, duration, price);
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
        if (priceIndex == 0) {
            revert InvalidCharacterCount(charCount);
        }

        // Get annual price in USD (1e18 = $1)
        uint256 annualPrice = annualPrices[priceIndex];

        // Check if price is set
        if (annualPrice == 0) {
            revert PricingNotSet();
        }

        // Calculate USD price based on duration (proportional to 365 days)
        uint256 usdPrice = (annualPrice * duration) / 365 days;

        // Convert USD price to HYPE tokens using the oracle
        price = priceOracle.usdToHype(usdPrice);

        return price;
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
        if (charCount < 1 || charCount > 5) {
            revert InvalidCharacterCount(charCount);
        }

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
        if (_priceOracle == address(0)) revert OracleNotSet();
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
        if (!success) {
            revert WithdrawalFailed();
        }

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
     * @dev Receive function
     */
    receive() external payable {}
}
