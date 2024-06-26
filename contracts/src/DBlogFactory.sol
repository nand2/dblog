// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";
// ENS
import {NameWrapper} from "ens-contracts/wrapper/NameWrapper.sol";
import {ETHRegistrarController} from "ens-contracts/ethregistrar/ETHRegistrarController.sol";
import {BaseRegistrarImplementation} from "ens-contracts/ethregistrar/BaseRegistrarImplementation.sol";
import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";
// EthFs
import {FileStore, File} from "ethfs/FileStore.sol";
// EthStorage
import {TestEthStorageContractKZG} from "storage-contracts-v1/TestEthStorageContractKZG.sol";
// ERC721A
import {ERC721A} from "ERC721A/ERC721A.sol";

import "./DBlogFactoryFrontend.sol";
import "./DBlog.sol";
import "./DBlogFrontend.sol";
import "./DBlogFrontendLibrary.sol";
import "./DBlogFactoryToken.sol";
import "./library/Strings.sol";

contract DBlogFactory is ERC721A {
    DBlogFactoryFrontend public immutable factoryFrontend;
    DBlogFactoryToken public immutable factoryToken;

    DBlog public immutable blogImplementation;
    DBlogFrontend public immutable blogFrontendImplementation;

    DBlogFrontendLibrary public immutable blogFrontendLibrary;

    DBlog[] public blogs;
    mapping(DBlog => uint) public blogToIndex;
    event BlogCreated(uint indexed blogId, address blog, address blogFrontend);

    NameWrapper public ensNameWrapper;
    ETHRegistrarController public ensEthRegistrarController;
    BaseRegistrarImplementation public ensBaseRegistrar;

    // EIP-137 ENS resolver events
    event AddrChanged(bytes32 indexed node, address a);
    // EIP-2304 ENS resolver events
    event AddressChanged(bytes32 indexed node, uint coinType, bytes newAddress);
    uint constant private COIN_TYPE_ETH = 60;

    // EthFs contract
    FileStore public immutable ethFsFileStore;

    // EthStorage contract
    TestEthStorageContractKZG public ethStorage;

    string public topdomain;
    string public domain;
    mapping(bytes32 => DBlog) subdomainNameHashToBlog;

    // The owner of the whole Dblog factory will only be able to : 
    // - Update the factory (web3://dblog.eth) frontend
    // - Add a new blog frontend version to the blog frontend library
    // - Set a new blog frontend version as default (but each individual blog can override this)
    address public owner;

    // For possible future extensions : a listing of extension contracts
    address[] public extensions;


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }


    /**
     * 
     * @param _topdomain eth
     * @param _domain dblog
     * @param _factoryFrontend The frontend of the factory, handling the web3://dblog.eth requests
     * @param _factoryToken Methods for handling the thumbnail generation and tokenURI()
     * @param _blogImplementation The implementation of the blog contract, to be cloned
     * @param _blogFrontendImplementation The implementation of the blog frontend contract, to be cloned
     * @param _blogFrontendLibrary The library containing the blog frontend versions
     */
    struct ConstructorParams {
        string topdomain;
        string domain;
        DBlogFactoryFrontend factoryFrontend;
        DBlogFactoryToken factoryToken;
        DBlog blogImplementation;
        DBlogFrontend blogFrontendImplementation;
        DBlogFrontendLibrary blogFrontendLibrary;
        NameWrapper ensNameWrapper;
        ETHRegistrarController ensEthRegistrarController;
        BaseRegistrarImplementation ensBaseRegistrar;
        FileStore ethfsFileStore;
        TestEthStorageContractKZG ethStorage;
    }
    constructor(ConstructorParams memory _params) ERC721A("web3://dblog.eth", "DBLOG") {
        owner = msg.sender;

        topdomain = _params.topdomain;
        domain = _params.domain;

        factoryFrontend = _params.factoryFrontend;
        factoryToken = _params.factoryToken;
        blogImplementation = _params.blogImplementation;
        blogFrontendImplementation = _params.blogFrontendImplementation;
        blogFrontendLibrary = _params.blogFrontendLibrary;

        // Adding some backlinks
        factoryFrontend.setBlogFactory(this);
        factoryToken.setBlogFactory(this);
        blogFrontendLibrary.setBlogFactory(this);

        ensNameWrapper = _params.ensNameWrapper;
        ensEthRegistrarController = _params.ensEthRegistrarController;
        ensBaseRegistrar = _params.ensBaseRegistrar;

        ethFsFileStore = _params.ethfsFileStore;

        ethStorage = _params.ethStorage;
    }

    /**
     * Add a new blog
     * @param title Title of the blog
     * @param description Optional
     * @param subdomain Optional : xxx.blog.eth
     */
    function addBlog(string memory title, string memory description, string memory subdomain) public payable returns(address) {
        require(bytes(title).length > 0, "Title cannot be empty");

        DBlog newBlog = DBlog(Clones.clone(address(blogImplementation)));
        DBlogFrontend newBlogFrontend = DBlogFrontend(Clones.clone(address(blogFrontendImplementation)));

        newBlog.initialize(this, newBlogFrontend, subdomain, title, description);
        blogs.push(newBlog);
        blogToIndex[newBlog] = blogs.length - 1;

        // Mint an ERC721 token. TokenId will match blogs index
        _mint(msg.sender, 1);

        // Subdomain requested?
        if(bytes(subdomain).length > 0) {
            // Require fee of 0.01 ETH
            require(msg.value == 0.01 ether, "Fee of 0.01 ETH required for subdomain");

            // Valid and available?
            (bool isValidAndAvailable, string memory reason) = isSubdomainValidAndAvailable(subdomain);
            require(isValidAndAvailable, reason);

            // Adding the namehash -> blog mapping for our custom resolver
            bytes32 subdomainNameHash = computeSubdomainNameHash(subdomain);
            subdomainNameHashToBlog[subdomainNameHash] = newBlog;

            // ENS : Register the subdomain
            // For more gas efficiency, we could have implemented the ENSIP-10 wildcard resolution
            // but we would need to first update the web3:// lib ecosystem to use ENSIP-10 resolution
            ensNameWrapper.setSubnodeRecord(computeSubdomainNameHash(""), subdomain, address(this), address(this), 0, 0, 0);

            // EIP-137 ENS resolver event
            emit AddrChanged(subdomainNameHash, address(newBlogFrontend));
            // EIP-2304 ENS resolver event
            emit AddressChanged(subdomainNameHash, COIN_TYPE_ETH, abi.encodePacked(address(newBlogFrontend)));
        }

        emit BlogCreated(blogs.length - 1, address(newBlog), address(newBlogFrontend));

        return address(newBlog);
    }

    /**
     * For frontend: Get a batch of parameters in a single call
     */
    function getParameters() public view returns (string memory _topdomain, string memory _domain, address _frontend, address _blogImplementation) {
        return (topdomain, domain, address(factoryFrontend), address(blogImplementation));
    }

    /**
     * For frontend: Get the list of blogs
     */
    struct BlogInfo {
        uint256 id;
        address blogAddress;
        address blogFrontendAddress;
        string subdomain;
        string title;
        string description;
        uint256 postCount;
    }
    function getBlogInfoList(uint startIndex, uint limit) public view returns (BlogInfo[] memory blogInfos, uint256 blogCount) {
        uint256 blogsCount = blogs.length;
        uint256 actualLimit = limit;
        if(startIndex >= blogsCount) {
            actualLimit = 0;
        } else if(startIndex + limit > blogsCount) {
            actualLimit = blogsCount - startIndex;
        }

        blogInfos = new BlogInfo[](actualLimit);
        for(uint i = 0; i < actualLimit; i++) {
            DBlog blog = blogs[startIndex + i];
            blogInfos[i] = BlogInfo({
                id: startIndex + i,
                blogAddress: address(blog),
                blogFrontendAddress: address(blog.frontend()),
                subdomain: blog.subdomain(),
                title: blog.title(),
                description: blog.description(),
                postCount: blog.getPostCount()
            });
        }

        return (blogInfos, blogsCount);
    }

    function getBlogAddress(uint256 index) public view returns (address) {
        require(index < blogs.length, "Blog does not exist");

        return address(blogs[index]);
    }
    
    function getBlogCount() public view returns (uint256) {
        return blogs.length;
    }


    //
    // ENS : handling of dblog.eth
    //

    // Collected funds by the sale of subdomains have 2 roles : 
    // - Fund the renewal of the dblog.eth domain of the next 100 years
    // - Any overflow money go to the Protocol Guild
    //
    // -> Anyone can trigger this
    // -> Deployer get nothing!
    function deployFunds() public {
        uint256 domainExpiry = ensBaseRegistrar.nameExpires(uint(keccak256(bytes(domain))));
        uint256 domainYearsFunded = 0;
        if(domainExpiry > block.timestamp) {
            domainYearsFunded = (domainExpiry - block.timestamp) / (365 * 24 * 3600);
        }
        uint256 totalYearsToRenew = 100 - domainYearsFunded;
        // We will renew by chunks of 5 years, to save gas
        totalYearsToRenew = (totalYearsToRenew / 5) * 5;

        // Determine how long we can renew
        uint256 yearsToRenew = totalYearsToRenew;
        IPriceOracle.Price memory ensRenewalPrice;
        for(;yearsToRenew > 0; yearsToRenew -= 5) {
            ensRenewalPrice = ensEthRegistrarController.rentPrice(domain, yearsToRenew * 365 * 24 * 3600);
            if(ensRenewalPrice.base < address(this).balance) {
                break;
            }
        }

        // Renew the domain
        if(yearsToRenew > 0) {
            ensEthRegistrarController.renew{value: ensRenewalPrice.base}(domain, yearsToRenew * 365 * 24 * 3600);
        }

        // If years were to be renewed, but we could not renew all : 
        // We don't have enough money left, we stop
        if(totalYearsToRenew > 0 && yearsToRenew != totalYearsToRenew) {
            return;
        }

        // Send all the remaining money to the Protocol guild
        if(address(this).balance > 0) {
            // Donations going to Ethereum protocol contributors via the Protocol guild
            // https://twitter.com/StatefulWorks/status/1477006979704967169
            // https://stateful.mirror.xyz/mEDvFXGCKdDhR-N320KRtsq60Y2OPk8rHcHBCFVryXY
            // https://protocol-guild.readthedocs.io/en/latest/
            address protocolGuildAddress = 0xF29Ff96aaEa6C9A1fBa851f74737f3c069d4f1a9;
            payable(protocolGuildAddress).transfer(address(this).balance);
        }
    }

    // If no more sales, and blog owners want to extend the renewal of dblog.eth, they can
    // fund the contract then call deployFunds()
    function fundContract() public payable {
        // Thanks!
    }

    // Testnet only : Give back the domain so that we can reuse it for another test
    function testnetSendBackDomain() public onlyOwner {
        require(block.chainid != 1, "Only testnet");
        ensNameWrapper.safeTransferFrom(address(this), owner, uint(computeSubdomainNameHash("")), 1, "");
    }


    ///
    // ENS : Custom resolver
    //

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == 0x01ffc9a7 || 
            interfaceId == 0x3b3b57de || // ENS EIP-137 addr(bytes32)
            interfaceId == 0xf1cb7e06 || // ENS EIP-2304 addr(bytes32, uint256)
            interfaceId == 0x59d1d43c || // ENS EIP-634 text()
            ERC721A.supportsInterface(interfaceId);
    }

    // EIP-137 : Addr()
    function addr(bytes32 nameHash) public view returns (address) {
        if(nameHash == computeSubdomainNameHash("")) {
            return address(factoryFrontend);
        }
        if(address(subdomainNameHashToBlog[nameHash]) == address(0)) {
            return address(0);
        }
        return address(subdomainNameHashToBlog[nameHash].frontend());
    }

    // EIP-137 : Resolvers MUST specify a fallback function that throws. Not sure why.
    fallback() external {
        revert();
    }
    
    // EIP-2304 : addr()
    function addr(bytes32 node, uint coinType) public view returns(bytes memory) {
        if(coinType != COIN_TYPE_ETH) {
            return "";
        }

        return abi.encodePacked(addr(node));
    }

    // EIP-634 : text()
    function text(bytes32 node, string memory key) public view returns (string memory) {
        // If the blog frontend version is using EthStorage, use ERC-6821 cross-chain
        // resolution so that the EthStorage chain is queried
        if(keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("contentcontract"))) {
            // Determine which EthStorage chain we use
            string memory ethStorageChainShortName = "es";
            if(block.chainid != 1) {
                ethStorageChainShortName = "es-t";
            }

            // Blog factory
            if(node == computeSubdomainNameHash("") && factoryFrontend.frontendVersion().storageMode == FileStorageMode.EthStorage) {
                return string.concat(ethStorageChainShortName, ":", Strings.toHexString(address(factoryFrontend)));
            }

            // Blogs
            if(address(subdomainNameHashToBlog[node]) != address(0) &&
            subdomainNameHashToBlog[node].frontend().blogFrontendVersion().storageMode == FileStorageMode.EthStorage) {
                return string.concat(ethStorageChainShortName, ":", Strings.toHexString(address(subdomainNameHashToBlog[node].frontend())));
            }
        }
        
        return "";
    }


    //
    // Handle subdomains
    //

    /**
     * Is a subdomain valid and available? If false, the reason is given, to be used by frontends.
     */
    function isSubdomainValidAndAvailable(string memory subdomain) public view returns (bool result, string memory reason) {
        (result, reason) = isSubdomainValid(subdomain);
        if (!result) {
            return (result, reason);
        }

        bytes32 subdomainNameHash = computeSubdomainNameHash(subdomain);
        if (addr(subdomainNameHash) != address(0)) {
            return (false, "Subdomain is already used");
        }

        return (true, "");
    }

    /**
     * Is a subdomain valid? If false, the reason is given, to be used by frontends.
     * Ideally we should use the same normalization as ENS (ENSIP-15) but we aim at a very
     * light frontend that will not be often updated (if ever), so we will use a simple
     * and restrictive set of rules : a-z, 0-9, - chars, min 3 chars, max 20 chars
     */
    function isSubdomainValid(string memory subdomain) public pure returns (bool, string memory) {
        bytes memory b = bytes(subdomain);
        
        if(b.length < 3) {
            return (false, "Subdomain is too short (min 3 chars)");
        } 
        if(b.length > 20) {
            return (false, "Subdomain is too long (max 20 chars)");
        }
        
        for (uint i; i < b.length; i++) {
            bytes1 char = b[i];
            if (!(char >= 0x30 && char <= 0x39) && //9-0
                !(char >= 0x61 && char <= 0x7A) && //a-z
                !(char == 0x2D) //-
            ) {
                return (false, "Subdomain contains invalid characters. Only a-z, 0-9, - are allowed.");
            }
        }

        return (true, "");
    }

    /**
     * For a given subdomain of dblog.eth, compute its namehash.
     * If not subdomain is given, return the namehash of dblog.eth
     */
    function computeSubdomainNameHash(string memory subdomain) public view returns (bytes32) {
        bytes32 emptyNamehash = 0x00;
        bytes32 topdomainNamehash = keccak256(abi.encodePacked(emptyNamehash, keccak256(abi.encodePacked(topdomain))));
		bytes32 domainNamehash = keccak256(abi.encodePacked(topdomainNamehash, keccak256(abi.encodePacked(domain))));

        if(bytes(subdomain).length == 0) {
            return domainNamehash;
        }
		
        return keccak256(abi.encodePacked(domainNamehash, keccak256(abi.encodePacked(subdomain))));
    }

    /**
     * On suddomain registration, we receive an ERC1155 token
     */
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4) {
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }


    //
    // ERC721
    //

    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal override {
        // When blogs are transfered, clear the editor list
        for(uint i = 0; i < quantity; i++) {
            DBlog blog = blogs[startTokenId + i];
            blog.clearEditors();
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(tokenId < blogs.length, "Token does not exist");

        return factoryToken.tokenURI(tokenId);
    }

    function tokenSVG(uint tokenId) public view returns (string memory) {
        require(tokenId < blogs.length, "Token does not exist");

        return factoryToken.tokenSVG(tokenId);
    }


    //
    // Admin
    //

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function addExtension(address _extension) public onlyOwner {
        extensions.push(_extension);
    }

    function getExtensions() public view returns (address[] memory) {
        return extensions;
    }

}
