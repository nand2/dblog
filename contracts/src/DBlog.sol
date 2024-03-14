// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlogFrontend.sol";
import "./DBlogFactory.sol";

contract DBlog {
    // Link to our creator, handling all the blogs
    DBlogFactory public factory;
    // Link to the frontend of this blog, answering the web3:// calls
    DBlogFrontend public frontend;

    // The optional subdomain of the blog. If not empty, 
    // <subdomain>.<domain>.<topdomain> will point to the frontend of this blog,
    // with domain and topdomain located in the factory.
    string public subdomain;

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

    // Because we will clone this contract, we initialize it with this instead of the constructor
    function initialize(DBlogFactory _factory, DBlogFrontend _frontend, string memory _subdomain, string memory _title, string memory _description) public {
        factory = _factory;

        frontend = _frontend;
        frontend.initialize(this);

        if(bytes(_subdomain).length > 0) {
            subdomain = _subdomain;
        }

        title = _title;
        if(bytes(_description).length > 0) {
            description = _description;
        }
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
