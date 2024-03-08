// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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
    BlogFrontendVersion[] public frontendVersions;
    uint256 public defaultFrontendIndex;


    function addFrontendVersion(address _htmlFile, address _cssFile, address _jsFile, string memory _infos) public {
        BlogFrontendVersion memory newFrontend = BlogFrontendVersion(_htmlFile, _cssFile, _jsFile, _infos);
        frontendVersions.push(newFrontend);
    }

    function setDefaultFrontend(uint256 _index) public {
        require(_index < frontendVersions.length, "Index out of bounds");
        defaultFrontendIndex = _index;
    }

    function getDefaultFrontend() public view returns (BlogFrontendVersion memory) {
        return frontendVersions[defaultFrontendIndex];
    }
}