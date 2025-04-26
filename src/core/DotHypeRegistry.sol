// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IDotHypeRegistry.sol";
import "../interfaces/IDotHypeMetadata.sol";

/**
 * @title DotHypeRegistry
 * @dev ERC721 token for .hype domain names with registry functionality
 */
contract DotHypeRegistry is ERC721, Ownable, IDotHypeRegistry {
    using Strings for uint256;

    // Custom errors
    error NameNotAvailable(string name);
    error DurationTooShort(uint256 provided, uint256 minimum);
    error TokenNotRegistered(uint256 tokenId);
    error NameNotValid(string name);
    error NameExpired(string name, uint256 expiry);
    error NotAuthorized(address caller, uint256 tokenId);
    error InvalidLength(string name);
    error DomainExpired(uint256 tokenId, uint256 expiry);

    // Name registration data
    struct NameRecord {
        string name;
        uint256 expiry;
    }

    // Mapping from tokenId to name record
    mapping(uint256 => NameRecord) private _records;
    
    // Grace period after expiration (in seconds)
    uint256 public constant GRACE_PERIOD = 30 days;
    
    // Minimum registration duration
    uint256 public constant MIN_REGISTRATION_DURATION = 28 days;
    
    // Controller address - the only one that can register/renew names
    address public controller;
    
    // Metadata provider contract
    IDotHypeMetadata public metadataProvider;
    
    // Constants for namehash calculation
    bytes32 constant private EMPTY_NODE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant private TLD_NODE = keccak256(abi.encodePacked(EMPTY_NODE, keccak256(abi.encodePacked("hype"))));

    /**
     * @dev Constructor
     * @param _owner Initial owner of the contract
     * @param _controller Controller address that can register/renew names
     */
    constructor(
        address _owner,
        address _controller
    ) ERC721("DotHype Naming Service", "HYPE") Ownable(_owner) {
        controller = _controller;
    }

    /**
     * @dev Modifier to restrict function access to the controller
     */
    modifier onlyController() {
        require(msg.sender == controller, NotAuthorized(msg.sender, 0));
        _;
    }

    /**
     * @dev Registers a new name
     * @param name The name to register
     * @param owner The address that will own the name
     * @param duration The duration in seconds for the registration
     * @return tokenId The token ID of the registered name
     * @return expiry The timestamp when the registration expires
     */
    function register(
        string calldata name,
        address owner,
        uint256 duration
    ) external override onlyController returns (uint256 tokenId, uint256 expiry) {
        require(available(name), NameNotAvailable(name));
        require(duration >= MIN_REGISTRATION_DURATION, DurationTooShort(duration, MIN_REGISTRATION_DURATION));
        
        // Calculate tokenId from name
        tokenId = nameToTokenId(name);
        expiry = block.timestamp + duration;
        
        // If the token exists but is expired beyond grace period, we need to burn it first
        if (_exists(tokenId) && block.timestamp > _records[tokenId].expiry + GRACE_PERIOD) {
            // Since only the owner can burn, we need to do a forced burn
            // Note: This uses internal ERC721 functions to handle it properly
            _update(address(0), tokenId, _ownerOf(tokenId));
        }
        
        // Store name record
        _records[tokenId] = NameRecord({
            name: name,
            expiry: expiry
        });
        
        // Mint the token
        _mint(owner, tokenId);
        
        emit NameRegistered(tokenId, owner, expiry);
    }

    /**
     * @dev Renews an existing name registration
     * @param tokenId The token ID of the name to renew
     * @param duration The additional duration in seconds
     * @return expiry The new expiry timestamp
     */
    function renew(
        uint256 tokenId,
        uint256 duration
    ) external override onlyController returns (uint256 expiry) {
        require(_exists(tokenId), TokenNotRegistered(tokenId));
        require(duration >= MIN_REGISTRATION_DURATION, DurationTooShort(duration, MIN_REGISTRATION_DURATION));
        
        // Get current expiry
        NameRecord storage record = _records[tokenId];
        
        // Update expiry
        uint256 newExpiry;
        if (block.timestamp > record.expiry) {
            newExpiry = block.timestamp + duration;
        } else {
            newExpiry = record.expiry + duration;
        }
        
        record.expiry = newExpiry;
        expiry = newExpiry;
        
        emit NameRenewed(tokenId, expiry);
    }

    /**
     * @dev Gets the expiry time of a name
     * @param tokenId The token ID of the name to query
     * @return expiry The expiry timestamp
     */
    function expiryOf(uint256 tokenId) external view override returns (uint256 expiry) {
        require(_exists(tokenId), TokenNotRegistered(tokenId));
        return _records[tokenId].expiry;
    }

    /**
     * @dev Checks if a name is available for registration
     * @param name The name to check
     * @return available True if the name is available
     */
    function available(string calldata name) public view override returns (bool) {
        // Check if name is valid
        require(isValidName(name), NameNotValid(name));
        
        // Calculate tokenId
        uint256 tokenId = nameToTokenId(name);
        
        // If token doesn't exist, it's available
        if (!_exists(tokenId)) {
            return true;
        }
        
        // Check if name is expired beyond grace period
        NameRecord storage record = _records[tokenId];
        return block.timestamp > record.expiry + GRACE_PERIOD;
    }

    /**
     * @dev Gets the token ID for a label using the namehash algorithm
     * @param label The label to query (without .hype)
     * @return tokenId The token ID
     */
    function nameToTokenId(string calldata label) public pure override returns (uint256 tokenId) {
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 namehash = keccak256(abi.encodePacked(TLD_NODE, labelhash));
        return uint256(namehash);
    }
    
    /**
     * @dev Gets the name for a token ID
     * @param tokenId The token ID to query
     * @return name The name
     */
    function tokenIdToName(uint256 tokenId) external view override returns (string memory name) {
        require(_exists(tokenId), TokenNotRegistered(tokenId));
        return _records[tokenId].name;
    }
    
    /**
     * @dev Validates a name format
     * @param name The name to validate
     * @return valid True if the name is valid
     */
    function isValidName(string calldata name) public pure returns (bool) {
        bytes memory nameBytes = bytes(name);
        
        // Check length (minimum 1 character, not counting .hype)
        if (nameBytes.length < 1) {
            return false;
        }
        
        // Basic validation - could be enhanced for character restrictions
        return true;
    }
    
    /**
     * @dev Returns the metadata URI for a given token ID
     * @param tokenId The token ID to get metadata for
     * @return The token URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), TokenNotRegistered(tokenId));
        
        // If metadata provider is set, use it
        if (address(metadataProvider) != address(0)) {
            string memory name = _records[tokenId].name;
            return metadataProvider.tokenURI(tokenId, name);
        }
        
        // Otherwise fall back to default implementation
        return super.tokenURI(tokenId);
    }
    
    /**
     * @dev Set a new controller address
     * @param _controller The new controller address
     */
    function setController(address _controller) external onlyOwner {
        controller = _controller;
    }
    
    /**
     * @dev Set a new metadata provider
     * @param _metadataProvider The new metadata provider address
     */
    function setMetadataProvider(address _metadataProvider) external onlyOwner {
        metadataProvider = IDotHypeMetadata(_metadataProvider);
    }
    
    /**
     * @dev Check if a token exists 
     * @param tokenId The token ID to check
     * @return True if the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
    
    /**
     * @dev Check if a domain is active (not expired)
     * @param tokenId The token ID to check
     * @return True if the domain is active
     */
    function isActive(uint256 tokenId) public view returns (bool) {
        if (!_exists(tokenId)) {
            return false;
        }
        
        return block.timestamp <= _records[tokenId].expiry;
    }
    
    /**
     * @dev Override _update to prevent transfers of expired domains
     */
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        // For minting, allow it to proceed
        if (auth == address(0)) {
            return super._update(to, tokenId, auth);
        }
        
        // For controller transfers, allow it to proceed
        if (msg.sender == controller || msg.sender == owner()) {
            return super._update(to, tokenId, auth);
        }
        
        // For normal transfers, check if the domain is expired
        // Prevent transfer if domain has expired
        if (_exists(tokenId) && !isActive(tokenId)) {
            revert DomainExpired(tokenId, _records[tokenId].expiry);
        }
        
        return super._update(to, tokenId, auth);
    }
} 