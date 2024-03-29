// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlogFactory.sol";

// A version of a frontend, containing a single HTML, CSS and JS file.
struct BlogFrontendVersion {
    // Pointers to ethfs File structures stored with SSTORE2
    // Note: These files are expected to be compressed with gzip
    address htmlFile;
    address cssFile;
    address jsFile;

    // Infos about this version
    string infos;
}

contract DBlogFrontendLibrary {
    DBlogFactory public blogFactory;

    BlogFrontendVersion[] public frontendVersions;
    uint256 public defaultFrontendIndex;


    modifier onlyFactoryOrFactoryOwner() {
        require(msg.sender == address(blogFactory) || msg.sender == blogFactory.owner(), "Not owner");
        _;
    }

    constructor() {}

    // Due to difficulties with verifying source of contracts deployed by contracts, and 
    // this contract and DBlogFactory pointing to each other, we add the pointer to the blog factory
    // in this method, after this contract has been created.
    // Security : This can be only called once. Both pointers are set on DBlogFactory constructor, 
    // so this method can be open
    function setBlogFactory(DBlogFactory _blogFactory) public {
        // We can only set the blog factory once
        require(address(blogFactory) == address(0), "Already set");
        blogFactory = _blogFactory;
    }

    function addFrontendVersion(address _htmlFile, address _cssFile, address _jsFile, string memory _infos) public onlyFactoryOrFactoryOwner {
        BlogFrontendVersion memory newFrontend = BlogFrontendVersion(_htmlFile, _cssFile, _jsFile, _infos);
        frontendVersions.push(newFrontend);
    }

    function getFrontendVersion(uint256 _index) public view returns (BlogFrontendVersion memory) {
        require(_index < frontendVersions.length, "Index out of bounds");
        return frontendVersions[_index];
    }

    function setDefaultFrontend(uint256 _index) public onlyFactoryOrFactoryOwner {
        require(_index < frontendVersions.length, "Index out of bounds");
        defaultFrontendIndex = _index;
    }

    function getDefaultFrontend() public view returns (BlogFrontendVersion memory) {
        return frontendVersions[defaultFrontendIndex];
    }

    function getFrontendVersionCount() public view returns (uint256) {
        return frontendVersions.length;
    }
}