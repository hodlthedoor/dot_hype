// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IDotHypeRegistry.sol";
import "../interfaces/IReverseResolver.sol";

// ENS resolver interfaces
import "../../lib/ens-contracts/contracts/resolvers/profiles/IAddrResolver.sol";
import "../../lib/ens-contracts/contracts/resolvers/profiles/IAddressResolver.sol";
import "../../lib/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import "../../lib/ens-contracts/contracts/resolvers/profiles/IContentHashResolver.sol";
import "../../lib/ens-contracts/contracts/resolvers/ResolverBase.sol";

/**
 * @title DotHypeResolver
 * @dev Resolver contract for DotHype domains
 * Implements ENS compatible resolution interfaces
 */
contract DotHypeResolver is
    Ownable,
    ResolverBase,
    IAddrResolver,
    IAddressResolver,
    ITextResolver,
    IContentHashResolver,
    IReverseResolver
{
    // Custom errors
    error NotAuthorized(address caller, bytes32 node);
    error InvalidNode(bytes32 node);
    error RecordNotFound(bytes32 node, string recordType);
    error DomainExpired(bytes32 node, uint256 expiry);

    // Reference to the DotHype registry (immutable for gas savings and security)
    IDotHypeRegistry public immutable registry;

    // Event for version changes
    event VersionChanged(bytes32 indexed node, uint256 newVersion);

    // Mapping from node to record version
    mapping(bytes32 => uint256) private _recordVersions;

    // Storage for domain records with versioning
    mapping(bytes32 => mapping(uint256 => address)) private _addresses;
    mapping(bytes32 => mapping(uint256 => mapping(uint256 => bytes))) private _coinAddresses;
    mapping(bytes32 => mapping(uint256 => mapping(string => string))) private _textRecords;
    mapping(bytes32 => mapping(uint256 => bytes)) private _contentHashes;

    // Simple reverse resolution mapping
    mapping(address => bytes32) private _reverseRecords; // address => domain node

    /**
     * @dev Modifier to ensure domain is active (not expired)
     * @param node The namehash of the domain
     */
    modifier onlyActive(bytes32 node) {
        try registry.expiryOf(uint256(node)) returns (uint256 expiry) {
            if (block.timestamp > expiry) {
                revert DomainExpired(node, expiry);
            }
            _;
        } catch {
            revert InvalidNode(node);
        }
    }

    /**
     * @dev Constructor
     * @param _owner Initial owner of the contract
     * @param _registry Address of the DotHype registry
     */
    constructor(address _owner, address _registry) Ownable(_owner) {
        registry = IDotHypeRegistry(_registry);
    }

    /**
     * @dev Returns the current version of records for a node
     * @param node The namehash of the domain
     * @return The current version
     */
    function recordVersion(bytes32 node) public view returns (uint256) {
        return _recordVersions[node];
    }

    /**
     * @dev Increments the version for a domain's records, effectively clearing all records
     * @param node The namehash of the domain
     */
    function clearRecords(bytes32 node) public virtual override authorised(node) onlyActive(node) {
        _recordVersions[node]++;
        emit VersionChanged(node, _recordVersions[node]);
    }

    /**
     * @dev Checks if a domain is active (not expired)
     * @param node The namehash of the domain
     * @return True if the domain is active and can be resolved
     */
    function isActive(bytes32 node) public view returns (bool) {
        try registry.expiryOf(uint256(node)) returns (uint256 expiry) {
            return block.timestamp <= expiry;
        } catch {
            return false;
        }
    }

    /**
     * @dev Returns the address associated with a domain
     * @param node The namehash of the domain
     * @return The associated address
     */
    function addr(bytes32 node) public view virtual override returns (address payable) {
        if (!isActive(node)) {
            return payable(address(0));
        }
        return payable(_addresses[node][_recordVersions[node]]);
    }

    /**
     * @dev Sets the address associated with a domain
     * @param node The namehash of the domain
     * @param a The address to set
     */
    function setAddr(bytes32 node, address a) public virtual authorised(node) onlyActive(node) {
        uint256 version = _recordVersions[node];
        _addresses[node][version] = a;
        emit AddrChanged(node, a);
    }

    /**
     * @dev Returns the address associated with a domain for a specific coin type
     * @param node The namehash of the domain
     * @param coinType The coin type as per SLIP-0044
     * @return The associated address
     */
    function addr(bytes32 node, uint256 coinType) public view virtual override returns (bytes memory) {
        if (!isActive(node)) {
            return "";
        }
        return _coinAddresses[node][_recordVersions[node]][coinType];
    }

    /**
     * @dev Sets the address associated with a domain for a specific coin type
     * @param node The namehash of the domain
     * @param coinType The coin type as per SLIP-0044
     * @param a The address to set
     */
    function setAddr(bytes32 node, uint256 coinType, bytes memory a) public virtual authorised(node) onlyActive(node) {
        uint256 version = _recordVersions[node];
        _coinAddresses[node][version][coinType] = a;
        emit AddressChanged(node, coinType, a);
    }

    /**
     * @dev Returns the text data associated with a domain
     * @param node The namehash of the domain
     * @param key The text record key
     * @return The associated text value
     */
    function text(bytes32 node, string calldata key) public view virtual override returns (string memory) {
        if (!isActive(node)) {
            return "";
        }
        return _textRecords[node][_recordVersions[node]][key];
    }

    /**
     * @dev Sets the text data associated with a domain
     * @param node The namehash of the domain
     * @param key The text record key
     * @param value The text record value
     */
    function setText(bytes32 node, string calldata key, string calldata value)
        public
        virtual
        authorised(node)
        onlyActive(node)
    {
        uint256 version = _recordVersions[node];
        _textRecords[node][version][key] = value;
        emit TextChanged(node, key, key, value);
    }

    /**
     * @dev Returns the content hash associated with a domain
     * @param node The namehash of the domain
     * @return The associated content hash
     */
    function contenthash(bytes32 node) public view virtual override returns (bytes memory) {
        if (!isActive(node)) {
            return "";
        }
        return _contentHashes[node][_recordVersions[node]];
    }

    /**
     * @dev Sets the content hash associated with a domain
     * @param node The namehash of the domain
     * @param hash The content hash to set
     */
    function setContenthash(bytes32 node, bytes calldata hash) public virtual authorised(node) onlyActive(node) {
        uint256 version = _recordVersions[node];
        _contentHashes[node][version] = hash;
        emit ContenthashChanged(node, hash);
    }

    /**
     * @dev Gets the domain node that an address points to (reverse resolution)
     * @param addr The address to lookup
     * @return The domain node the address is associated with
     */
    function getNode(address addr) public view override returns (bytes32) {
        return _reverseRecords[addr];
    }

    /**
     * @dev Sets the domain node for an address (reverse resolution)
     * Can only be called by the owner of the address
     * @param node The node to associate with the sender's address
     */
    function setReverseRecord(bytes32 node) public override {
        // Only the domain owner can set a reverse record pointing to their domain
        address domainOwner;
        try IERC721(address(registry)).ownerOf(uint256(node)) returns (address owner) {
            domainOwner = owner;
        } catch {
            revert InvalidNode(node);
        }

        // Sender must own the domain they're pointing to
        require(msg.sender == domainOwner, "Not domain owner");

        // Set the reverse record
        _reverseRecords[msg.sender] = node;
        emit ReverseResolutionSet(msg.sender, node);
    }

    /**
     * @dev Clears the reverse record for the sender's address
     */
    function clearReverseRecord() public override {
        _reverseRecords[msg.sender] = bytes32(0);
        emit ReverseResolutionCleared(msg.sender);
    }

    /**
     * @dev Gets the domain name for an address through reverse resolution
     * @param addr The address to lookup
     * @return The domain name associated with the address, or empty string if not set
     */
    function reverseLookup(address addr) public view override returns (string memory) {
        bytes32 node = _reverseRecords[addr];

        // Return empty if no reverse record or domain is expired
        if (node == bytes32(0) || !isActive(node)) {
            return "";
        }

        // Return the domain name
        try registry.tokenIdToName(uint256(node)) returns (string memory domainName) {
            return string(abi.encodePacked(domainName, ".hype"));
        } catch {
            return "";
        }
    }

    /**
     * @dev Gets the domain name for an address through reverse resolution (alias for reverseLookup)
     * Also checks if the address matches the address record in the resolver
     * @param addr The address to lookup
     * @return The domain name associated with the address, or empty string if not set or address doesn't match
     */
    function getName(address addr) public view override returns (string memory) {
        bytes32 node = _reverseRecords[addr];

        // Return empty if no reverse record or domain is expired
        if (node == bytes32(0) || !isActive(node)) {
            return "";
        }

        // Check that the address record matches the lookup address
        address registeredAddress = _addresses[node][_recordVersions[node]];
        if (registeredAddress != addr) {
            return ""; // Address doesn't match the resolver record
        }

        // Return the domain name
        try registry.tokenIdToName(uint256(node)) returns (string memory domainName) {
            return string(abi.encodePacked(domainName, ".hype"));
        } catch {
            return "";
        }
    }

    /**
     * @dev Gets a specific value for an address through reverse resolution
     * Also checks if the address matches the address record in the resolver
     * @param addr The address to lookup
     * @param key The text record key to retrieve
     * @return The text record value associated with the key for the address's domain, or empty if address doesn't match
     */
    function getValue(address addr, string calldata key) public view override returns (string memory) {
        bytes32 node = _reverseRecords[addr];

        // Return empty if no reverse record or domain is expired
        if (node == bytes32(0) || !isActive(node)) {
            return "";
        }

        // Check that the address record matches the lookup address
        address registeredAddress = _addresses[node][_recordVersions[node]];
        if (registeredAddress != addr) {
            return ""; // Address doesn't match the resolver record
        }

        // Return the text record value
        return _textRecords[node][_recordVersions[node]][key];
    }

    /**
     * @dev Checks if an address has a reverse record
     * Also checks if the address matches the address record in the resolver
     * @param addr The address to check
     * @return True if the address has a valid, non-expired reverse record and matches the resolver record
     */
    function hasRecord(address addr) public view override returns (bool) {
        bytes32 node = _reverseRecords[addr];

        // Return false if no reverse record or domain is expired
        if (node == bytes32(0) || !isActive(node)) {
            return false;
        }

        // Check that the address record matches the lookup address
        address registeredAddress = _addresses[node][_recordVersions[node]];
        return registeredAddress == addr;
    }

    /**
     * @dev Checks if the resolver supports a specific interface
     * This overrides the ResolverBase implementation
     * @param interfaceID The interface identifier
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IAddrResolver).interfaceId || interfaceID == type(IAddressResolver).interfaceId
            || interfaceID == type(ITextResolver).interfaceId || interfaceID == type(IContentHashResolver).interfaceId
            || interfaceID == type(IReverseResolver).interfaceId || super.supportsInterface(interfaceID);
    }

    /**
     * @dev Overrides the authorised function in ResolverBase
     * Checks if the sender is authorized to update the record
     * @param node The namehash of the domain
     */
    function isAuthorised(bytes32 node) internal view override returns (bool) {
        try IERC721(address(registry)).ownerOf(uint256(node)) returns (address domainOwner) {
            return msg.sender == domainOwner;
        } catch {
            // If the token doesn't exist, no one is authorized
            return false;
        }
    }
}
