// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {NameWrapper} from "ens-contracts/wrapper/NameWrapper.sol";

import "./DBlogFactoryFrontend.sol";
import "./DBlog.sol";
import "./DBlogFrontend.sol";
import "./DBlogFrontendLibrary.sol";

contract DBlogFactory {
    DBlogFactoryFrontend public immutable factoryFrontend;

    DBlog public immutable blogImplementation;
    DBlogFrontend public immutable blogFrontendImplementation;

    DBlogFrontendLibrary public immutable blogFrontendLibrary;

    DBlog[] public blogs;
    event BlogCreated(uint indexed blogId, address blog, address blogFrontend);

    NameWrapper public ensNameWrapper;
    // EIP-137 ENS resolver events
    event AddrChanged(bytes32 indexed node, address a);
    // EIP-2304 ENS resolver events
    event AddressChanged(bytes32 indexed node, uint coinType, bytes newAddress);
    uint constant private COIN_TYPE_ETH = 60;

    string public topdomain;
    string public domain;
    mapping(bytes32 => DBlog) subdomainNameHashToBlog;

    // The owner of the whole Dblog factory will only be able to : 
    // - Update the factory (web3://dblog.eth) frontend
    // - Add a new blog frontend version to the blog frontend library
    // - Set a new blog frontend version as default (but each individual blog can override this)
    address public owner;


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }


    /**
     * 
     * @param _topdomain eth
     * @param _domain dblog
     * @param _factoryFrontend The frontend of the factory, handling the web3://dblog.eth requests
     * @param _blogImplementation The implementation of the blog contract, to be cloned
     * @param _blogFrontendImplementation The implementation of the blog frontend contract, to be cloned
     * @param _blogFrontendLibrary The library containing the blog frontend versions
     */
    constructor(string memory _topdomain, string memory _domain, DBlogFactoryFrontend _factoryFrontend, DBlog _blogImplementation, DBlogFrontend _blogFrontendImplementation, DBlogFrontendLibrary _blogFrontendLibrary, NameWrapper _ensNameWrapper) {
        owner = msg.sender;

        topdomain = _topdomain;
        domain = _domain;

        factoryFrontend = _factoryFrontend;
        blogImplementation = _blogImplementation;
        blogFrontendImplementation = _blogFrontendImplementation;
        blogFrontendLibrary = _blogFrontendLibrary;

        // Adding some backlinks
        factoryFrontend.setBlogFactory(this);
        blogFrontendLibrary.setBlogFactory(this);

        ensNameWrapper = _ensNameWrapper;
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

        newBlog.initialize(this, msg.sender, newBlogFrontend, subdomain, title, description);
        blogs.push(newBlog);

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


    ///
    // ENS : Custom resolver
    //

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return interfaceID == 0x01ffc9a7 || 
            interfaceID == 0x3b3b57de || // ENS EIP-137 addr(bytes32)
            interfaceID == 0xf1cb7e06 || // ENS EIP-2304 addr(bytes32, uint256)
            interfaceID == 0x59d1d43c; // ENS EIP-634 text()
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
    function text(bytes32 node, string memory key) public pure returns (string memory) {
        return "";
    }

    function testnetSendBackDomain() public onlyOwner {
        require(block.chainid != 1, "Only testnet");
        ensNameWrapper.safeTransferFrom(address(this), owner, uint(computeSubdomainNameHash("")), 1, "");
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
}
