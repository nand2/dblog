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

    uint256 public ethStorageLastUsedKey = 0;

    event PostCreated(uint indexed postId);
    event PostEdited(uint indexed postId);

    struct BlogPost {
        string title;
        uint256 timestamp;

        // Content of the blog post is either on EthStorage
        // and we specify the content part key, or it is on
        // ethereum state
        string ethereumStateContent;
        bytes32 ethStorageContentKey;
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
        // Check that it is not in the editor list already
        for(uint i = 0; i < editors.length; i++) {
            require(editors[i] != editor, "Already editor");
        }

        editors.push(editor);
    }

    function getEditors() public view returns (address[] memory) {
        return editors;
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

    function addPostOnEthereumState(string memory postTitle, string memory postContent) public onlyOwnerOrEditors {
        posts.push();
        BlogPost storage newPost = posts[posts.length - 1];
        newPost.title = postTitle;
        newPost.timestamp = block.timestamp;
        newPost.ethereumStateContent = postContent;

        emit PostCreated(posts.length - 1);
    }

    function getEthStorageUpfrontPayment() external view returns (uint256) {
        return factory.ethStorage().upfrontPayment();
    }

    function addPostOnEthStorage(string memory postTitle, uint256 blobDataSize) public payable onlyOwnerOrEditors {
        posts.push();
        BlogPost storage newPost = posts[posts.length - 1];
        newPost.title = postTitle;
        newPost.timestamp = block.timestamp;

        // We store the content on EthStorage
        ethStorageLastUsedKey++;
        bytes32 ethStorageContentKey = bytes32(ethStorageLastUsedKey);
        uint256 upfrontPayment = this.getEthStorageUpfrontPayment();
        factory.ethStorage().putBlob{value: upfrontPayment}(ethStorageContentKey, 0, blobDataSize);
        newPost.ethStorageContentKey = ethStorageContentKey;

        emit PostCreated(posts.length - 1);
    }

    function getPost(uint256 index) public view returns (string memory postTitle, uint256 timestamp, string memory ethereumStateContent, bytes32 ethStorageContentKey) {
        return (posts[index].title, posts[index].timestamp, posts[index].ethereumStateContent, posts[index].ethStorageContentKey);
    }

    // Need to be called with the EthStorage chain
    function getPostEthStorageContent(uint256 index) public view returns (bytes memory) {
        require(index < posts.length, "Index out of bounds");
        require(posts[index].ethStorageContentKey != 0, "Post is on Ethereum state");

        return factory.ethStorage().get(
            posts[index].ethStorageContentKey, 
            DecentralizedKV.DecodeType.PaddingPer31Bytes, 
            0, 
            factory.ethStorage().size(posts[index].ethStorageContentKey));
    }

    function editEthereumStatePost(uint256 index, string memory postTitle, string memory postContent) public onlyOwnerOrEditors {
        require(index < posts.length, "Index out of bounds");
        require(posts[index].ethStorageContentKey == 0, "Post is on EthStorage");

        posts[index].title = postTitle;
        posts[index].ethereumStateContent = postContent;

        emit PostEdited(index);
    }

    function editEthStoragePost(uint256 index, string memory postTitle, uint256 blobDataSize) public payable onlyOwnerOrEditors {
        require(index < posts.length, "Index out of bounds");
        require(posts[index].ethStorageContentKey != 0, "Post is on Ethereum state");

        posts[index].title = postTitle;
        // We store the content on EthStorage
        // No payment, as we reuse a key
        factory.ethStorage().putBlob(posts[index].ethStorageContentKey, 0, blobDataSize);

        emit PostEdited(index);
    }

    function getPostCount() public view returns (uint256) {
        return posts.length;
    }

    function getPosts() public view returns (BlogPost[] memory) {
        return posts;
    }
}
