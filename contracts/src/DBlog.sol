// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlogFrontend.sol";
import "./DBlogFactory.sol";

contract DBlog {
    // Link to our creator, handling all the blogs
    DBlogFactory public factory;
    // Link to the frontend of this blog, answering the web3:// calls
    DBlogFrontend public frontend;

    // The owner of the DBlog
    address public owner;
    // Editors of the blog
    address[] public editors;

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

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyOwnerOrEditors() {
        bool isEditor = false;
        for(uint i = 0; i < editors.length; i++) {
            if(msg.sender == editors[i]) {
                isEditor = true;
                break;
            }
        }
        require(msg.sender == owner || isEditor, "Not owner or editor");
        _;
    }

    // Because we will clone this contract, we initialize it with this instead of the constructor
    function initialize(DBlogFactory _factory, address _owner, DBlogFrontend _frontend, string memory _subdomain, string memory _title, string memory _description) public {
        require(address(factory) == address(0), "Already initialized");

        factory = _factory;

        owner = _owner;

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

    function addEditor(address editor) public onlyOwner {
        editors.push(editor);
    }

    function removeEditor(address editor) public onlyOwner {
        for(uint i = 0; i < editors.length; i++) {
            if(editors[i] == editor) {
                editors[i] = editors[editors.length - 1];
                editors.pop();
                break;
            }
        }
    }

    function addPost(string memory postTitle, string memory postContent) public onlyOwnerOrEditors {
        posts.push(BlogPost(postTitle, block.timestamp, postContent));

        emit PostCreated(posts.length - 1);
    }

    function getPost(uint256 index) public view returns (string memory postTitle, uint256 timestamp, string memory postContent) {
        return (posts[index].title, posts[index].timestamp, posts[index].content);
    }

    function editPost(uint256 index, string memory postTitle, string memory postContent) public onlyOwnerOrEditors {
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
