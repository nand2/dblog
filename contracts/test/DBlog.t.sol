// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DBlog} from "../src/DBlog.sol";

contract DBlogTest is Test {
    DBlog public dBlog;

    function setUp() public {
        dBlog = new DBlog("title", "description");
    }

    // function test_AddPost() public {
    //     dBlog.addPost("boo", "baa");
    //     assertEq(dBlog.getPostCount(), 1);
    // }
}
