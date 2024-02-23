// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/DBlogFactory.sol";

contract DBlogTest is Test {
    DBlogFactory public blogFactory;

    function setUp() public {
        blogFactory = new DBlogFactory("eth", "dblog");
    }

    // Namehash working?
    function test_NameHash() public {
        // Hash of dblog.eth
        assertEq(blogFactory.computeSubdomainNameHash(""), hex"714dbca26f285bc3e859ae76430b35877230643ab2ea48f61c24402f04258af8");
        // sub.dblog.eth
        assertEq(blogFactory.computeSubdomainNameHash("sub"), hex"4a7168fafb2d63dd6048cc14a422b3c82e508d08815ad4a604c6d9233af0030f");
    }

    function test_AddBlog() public {
        blogFactory.addBlog("Blog title", "My blog description", "sub");
        assertEq(blogFactory.getBlogCount(), 1);
        // Check domain name resolution
        assertEq(blogFactory.addr(blogFactory.computeSubdomainNameHash("sub")), address(blogFactory.blogs(0)));
    }
}
