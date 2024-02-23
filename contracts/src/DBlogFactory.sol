// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./DBlogFactoryFrontend.sol";
import "./DBlog.sol";

contract DBlogFactory {
    address public immutable frontend;
    address immutable blogImplementation;
    DBlog[] public blogs;

    constructor() {
        frontend = address(new DBlogFactoryFrontend(this));
        blogImplementation = address(new DBlog());
    }

    function addBlog(string memory title, string memory description) public {
        address clone = Clones.clone(blogImplementation);
        DBlog(clone).initialize(title, description);
        blogs.push(DBlog(clone));
    }
    

    function getBlogCount() public view returns (uint256) {
        return blogs.length;
    }
}
