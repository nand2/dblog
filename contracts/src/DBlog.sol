// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract DBlog {
    string public title;
    string public description;

    struct BlogPost {
        string title;
        string content;
        // string contentKey;
    }
    BlogPost[] public posts;

    function initialize(string memory _title, string memory _description) public {
        title = _title;
        description = _description;
    }

    function addPost(string memory postTitle, string memory postContent) public {
        posts.push(BlogPost(postTitle, postContent));
    }

    function getPost(uint256 index) public view returns (string memory postTitle, string memory postContent) {
        return (posts[index].title, posts[index].content);
    }

    function getPostCount() public view returns (uint256) {
        return posts.length;
    }
}
