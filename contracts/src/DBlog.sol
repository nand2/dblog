// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlogFrontend.sol";
import "./DBlogFactory.sol";

contract DBlog {
    DBlogFactory public factory;
    DBlogFrontend public frontend;
    string public title;
    string public description;

    event PostCreated(uint indexed postId);
    event PostEdited(uint indexed postId);

    struct BlogPost {
        string title;
        uint256 timestamp;
        string content;
        // string contentKey;
    }
    BlogPost[] public posts;

    function initialize(DBlogFactory _factory, DBlogFrontend _frontend,string memory _title, string memory _description) public {
        factory = _factory;

        frontend = _frontend;
        frontend.initialize(this);

        title = _title;
        description = _description;
    }

    function addPost(string memory postTitle, string memory postContent) public {
        posts.push(BlogPost(postTitle, block.timestamp, postContent));

        emit PostCreated(posts.length - 1);
    }

    function getPost(uint256 index) public view returns (string memory postTitle, uint256 timestamp, string memory postContent) {
        return (posts[index].title, posts[index].timestamp, posts[index].content);
    }

    function editPost(uint256 index, string memory postTitle, string memory postContent) public {
        require(index < posts.length, "Index out of bounds");

        posts[index].title = postTitle;
        posts[index].content = postContent;

        emit PostEdited(index);
    }

    function getPostCount() public view returns (uint256) {
        return posts.length;
    }

    function getPosts() public view returns (BlogPost[] memory) {
        return posts;
    }
}
