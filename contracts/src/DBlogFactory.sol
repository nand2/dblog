// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./DBlogFactoryFrontend.sol";
import "./DBlog.sol";

contract DBlogFactory {
    address public immutable frontend;
    address public immutable blogImplementation;
    DBlog[] public blogs;
    event BlogCreated(uint indexed blogId, address blog);

    // EIP-137 ENS resolver events
    event AddrChanged(bytes32 indexed node, address a);

    string public topdomain;
    string public domain;
    mapping(bytes32 => DBlog) subDomainNameHashToBlog;

    /**
     * 
     * @param _topdomain eth
     * @param _domain dblog
     * @param initialFrontendHtmlFile A pointer to a ethfs File structure stored with SSTORE2
     * @param initialFrontendCssFile A pointer to a ethfs File structure stored with SSTORE2
     * @param initialFrontendJsFile A pointer to a ethfs File structure stored with SSTORE2
     */
    constructor(string memory _topdomain, string memory _domain, address initialFrontendHtmlFile, address initialFrontendCssFile, address initialFrontendJsFile) {
        topdomain = _topdomain;
        domain = _domain;

        frontend = address(new DBlogFactoryFrontend(this, initialFrontendHtmlFile, initialFrontendCssFile, initialFrontendJsFile));
        blogImplementation = address(new DBlog());
    }

    function addBlog(string memory title, string memory description, string memory subdomain) public payable returns(address) {
        require(bytes(title).length > 0, "Title cannot be empty");

        address clone = Clones.clone(blogImplementation);
        DBlog newBlog = DBlog(clone);
        newBlog.initialize(title, description);
        blogs.push(newBlog);

        // Subdomain requested?
        if(bytes(subdomain).length > 0) {
            // Require fee of 0.01 ETH
            require(msg.value == 0.01 ether, "Fee of 0.01 ETH required for subdomain");

            // Valid and available?
            (bool isValidAndAvailable, string memory reason) = isSubdomainValidAndAvailable(subdomain);
            require(isValidAndAvailable, reason);

            bytes32 subdomainNameHash = computeSubdomainNameHash(subdomain);
            subDomainNameHashToBlog[subdomainNameHash] = newBlog;
            // EIP-137 ENS resolver event
            emit AddrChanged(subdomainNameHash, address(newBlog));
        }

        emit BlogCreated(blogs.length - 1, address(newBlog));

        return address(newBlog);
    }

    struct BlogInfo {
        uint256 id;
        address blogAddress;
        string title;
        string description;
        uint256 postCount;
    }
    function getBlogInfoList(uint startIndex, uint limit) public view returns (string memory _topdomain, string memory _domain, uint blogCount, BlogInfo[] memory blogInfos) {
        uint256 count = blogs.length;
        uint256 actualLimit = limit;
        if(startIndex >= count) {
            actualLimit = 0;
        } else if(startIndex + limit > count) {
            actualLimit = count - startIndex;
        }

        blogInfos = new BlogInfo[](actualLimit);
        for(uint i = 0; i < actualLimit; i++) {
            DBlog blog = blogs[startIndex + i];
            blogInfos[i] = BlogInfo({
                id: startIndex + i,
                blogAddress: address(blog),
                title: blog.title(),
                description: blog.description(),
                postCount: blog.getPostCount()
            });
        }

        return (topdomain, domain, count, blogInfos);
    }

    function getBlogAddress(uint256 index) public view returns (address) {
        require(index < blogs.length, "Blog does not exist");

        return address(blogs[index]);
    }
    
    function getBlogCount() public view returns (uint256) {
        return blogs.length;
    }


    ///
    // Implementation of EIP-137 ENS resolver
    //

    function addr(bytes32 nameHash) public view returns (address) {
        if(nameHash == computeSubdomainNameHash("")) {
            return address(frontend);
        }

        return address(subDomainNameHashToBlog[nameHash]);
    }

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return interfaceID == 0x3b3b57de || interfaceID == 0x01ffc9a7;
    }
     
    // EIP-137 : Resolvers MUST specify a fallback function that throws. Not sure why.
    fallback() external {
        revert();
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
}
