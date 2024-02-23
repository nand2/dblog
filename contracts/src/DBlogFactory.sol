// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import Blog from "./DBlog.sol";

contract DBlogFactory {
    
    Blog[] public blogs;

    constructor() {
    }

    function resolveMode() external pure returns (bytes32) {
        return "auto";
    }

    function addBlog(string memory title, string memory description) public {
        
    }

    

    function getBlogCount() public view returns (uint256) {
        return blogs.length;
    }
}
