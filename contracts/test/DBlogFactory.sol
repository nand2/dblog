// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/DBlogFactory.sol";

contract DBlogTest is Test {
    DBlogFactory public blogFactory;

    function setUp() public {
        blogFactory = new DBlogFactory();
    }

    function test_AddBlog() public {
        blogFactory.addBlog("Blog title", "My blog description");
        assertEq(blogFactory.getBlogCount(), 1);
    }
}
