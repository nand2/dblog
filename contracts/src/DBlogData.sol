// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract DBlogData {
    string title;
    string description;

    struct BlogPost {
        string title;
        string content;
        // string contentKey;
    }
    BlogPost[] public posts;

    constructor(string memory _title, string memory _description) {
        title = _title;
        description = _description;
    }

    function resolveMode() external pure returns (bytes32) {
        return "auto";
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
