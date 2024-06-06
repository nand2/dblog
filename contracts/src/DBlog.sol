// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./DBlogFrontend.sol";
import "./DBlogFactory.sol";
import "./StorageBackendEthStorage.sol";
import "./interfaces/FileInfos.sol";
import "./interfaces/IStorageBackend.sol";
import "./interfaces/IBlogExtension.sol";

contract DBlog {
    // Link to our creator, handling all the blogs
    DBlogFactory public factory;
    // Link to the frontend of this blog, answering the web3:// calls
    DBlogFrontend public frontend;

    // Editors of the blog
    address[] public editors;

    // The optional subdomain of the blog. If not empty, 
    // <subdomain>.<domain>.<topdomain> will point to the frontend of this blog,
    // with domain and topdomain located in the factory.
    string public subdomain;

    string public title;
    string public description;

    // Files uploaded by the author/editors
    FileInfosWithStorageBackend[] uploadedFiles;
    struct FileNameToIndex {
        bool exists;
        uint248 index;
    }
    mapping(string => FileNameToIndex) uploadedFilesNameToIndex;

    // Blog extensions, registered from the factory
    IBlogExtension[] public extensions;

    // Flags for possible extensions?
    bytes32 public flags;


    event PostCreated(uint indexed postId);
    event PostEdited(uint indexed postId);
    event PostDeleted(uint indexed postId);
    event FileUploaded(string filename, string contentType);

    struct BlogPost {
        string title;
        uint64 timestamp;
        bool deleted;

        // For possible future evolutions: the data format of the stored content
        // 0: Plain text
        // Later: compression, JSON w/ metadata, ...
        uint8 contentFormatVersion;

        // "Free" data space, to be used for possible future evolutions
        bytes20 extra;

        // The storage backend used for the content
        uint16 storageBackendIndex;
        // Pointer to the file contents on the selected backend
        uint contentKey;
    }
    BlogPost[] posts;

    modifier onlyFactory() {
        require(msg.sender == address(factory), "Not factory");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner(), "Not owner");
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
        require(msg.sender == owner() || isEditor, "Not owner or editor");
        _;
    }

    // Because we will clone this contract, we initialize it with this instead of the constructor
    function initialize(DBlogFactory _factory, DBlogFrontend _frontend, string memory _title, string memory _description) public {
        require(address(factory) == address(0), "Already initialized");

        factory = _factory;

        frontend = _frontend;
        frontend.initialize(this);

        title = _title;
        if(bytes(_description).length > 0) {
            description = _description;
        }
    }

    function owner() public view returns (address) {
        return factory.ownerOf(factory.blogToIndex(this));
    }

    function setTitle(string memory _title) public onlyOwner {
        require(bytes(_title).length > 0, "Title must be not empty");
        title = _title;
    }

    function setDescription(string memory _description) public onlyOwner {
        require(bytes(_description).length > 0, "Description must be not empty");
        description = _description;
    }

    function setSubdomain(string memory _subdomain) public onlyFactory {
        subdomain = _subdomain;
    }


    //
    // Editors
    //

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

    function clearEditors() public onlyFactory {
        // Remove all editors from the array
        while(editors.length > 0) {
            editors.pop();
        }
    }


    //
    // Blog posts
    //

    function addPost(string memory postTitle, string memory storageBackendName, bytes memory data, uint dataLength, uint8 contentFormatVersion, bytes20 extra) public payable onlyOwnerOrEditors {
        posts.push();
        BlogPost storage newPost = posts[posts.length - 1];
        newPost.title = postTitle;
        newPost.timestamp = uint64(block.timestamp);
        newPost.contentFormatVersion = contentFormatVersion;
        newPost.extra = extra;
        // getStorageBackendIndexByName() will revert if not found
        newPost.storageBackendIndex = factory.getStorageBackendIndexByName(storageBackendName);

        // We store the content on the storage backend
        // We store all at once (we assume blog posts themselves won't require multiple tx)
        uint fundsUsed;
        (newPost.contentKey, fundsUsed) = factory.storageBackends(newPost.storageBackendIndex).create(data, dataLength);

        emit PostCreated(posts.length - 1);

        // Send back remaining funds sent by the caller
        if(msg.value - fundsUsed > 0) {
            payable(msg.sender).transfer(msg.value - fundsUsed);
        }
    }

    function getEthStorageUpfrontPayment() external view returns (uint256) {
        StorageBackendEthStorage storageBackendEthStorage = StorageBackendEthStorage(address(factory.getStorageBackendByName("EthStorage")));

        return storageBackendEthStorage.blobStorageUpfrontCost();
    }


    function getPost(uint256 index) public view returns (BlogPost memory, string memory) {
        require(index < posts.length, "Index out of bounds");
        require(posts[index].deleted == false, "Post deleted");

        // For EthStorage, we need to fetch it via the EthStorage chain
        uint nextChunkId;
        bytes memory content;
        (content, nextChunkId) = factory.storageBackends(posts[index].storageBackendIndex).read(address(this), posts[index].contentKey, 0);
        
        // We don't expect to be a nextChunkId for blog content, as the blog post themselves should not
        // be too big. We expect nextChunkId for media files.

        return (posts[index], string(content));
    }


    function editPost(uint256 index, string memory postTitle, string memory storageBackendName, bytes memory data, uint dataLength, uint8 contentFormatVersion, bytes20 extra) public payable onlyOwnerOrEditors {
        require(index < posts.length, "Index out of bounds");
        require(posts[index].deleted == false, "Post deleted");

        // getStorageBackendIndexByName() will revert if not found
        posts[index].storageBackendIndex = factory.getStorageBackendIndexByName(storageBackendName);

        posts[index].title = postTitle;
        posts[index].contentFormatVersion = contentFormatVersion;
        posts[index].extra = extra;

        // We delete the old version
        factory.storageBackends(posts[index].storageBackendIndex).remove(posts[index].contentKey);
        // We store the content on the storage backend
        // We store all at once (we assume blog posts themselves won't require multiple tx)
        uint fundsUsed;
        (posts[index].contentKey, fundsUsed) = factory.storageBackends(posts[index].storageBackendIndex).create(data, dataLength);

        emit PostEdited(index);

        // Send back remaining funds sent by the caller
        if(msg.value - fundsUsed > 0) {
            payable(msg.sender).transfer(msg.value - fundsUsed);
        }
    }

    function deletePost(uint256 index) public onlyOwnerOrEditors {
        require(index < posts.length, "Index out of bounds");
        require(posts[index].deleted == false, "Post already deleted");

        factory.storageBackends(posts[index].storageBackendIndex).remove(posts[index].contentKey);

        posts[index].deleted = true;

        emit PostDeleted(index);
    }

    function getPostCount() public view returns (uint256) {
        uint count = 0;
        for(uint i = 0; i < posts.length; i++) {
            if(posts[i].deleted == false) {
                count++;
            }
        }
        return count;
    }

    /**
     * Return the non-deleted blog posts.
     */
    struct BlogPostWithIndex {
        uint256 index;
        BlogPost post;
    }
    function getPosts() public view returns (BlogPostWithIndex[] memory publishedPosts) {
        publishedPosts = new BlogPostWithIndex[](getPostCount());

        uint publishedIndex = 0;
        for(uint i = 0; i < posts.length; i++) {
            if(posts[i].deleted == false) {
                publishedPosts[publishedIndex].index = i;
                publishedPosts[publishedIndex].post = posts[i];
                publishedIndex++;
            }
        }

        return publishedPosts;
    }


    //
    // Uploaded files for the blog posts
    //

    function addUploadedFile(string memory fileName, string memory contentType, string memory storageBackendName, bytes memory data, uint dataLength) public payable onlyOwnerOrEditors {
        require(Strings.compare(fileName, "") == false, "File path must be set");
        require(Strings.compare(contentType, "") == false, "Content type must be set");
        require(uploadedFilesNameToIndex[fileName].exists == false, "File already exists");

        uploadedFiles.push();
        FileInfosWithStorageBackend storage newFile = uploadedFiles[uploadedFiles.length - 1];
        // getStorageBackendIndexByName() will revert if not found
        newFile.storageBackendIndex = factory.getStorageBackendIndexByName(storageBackendName);
        newFile.fileInfos.filePath = fileName;
        uploadedFilesNameToIndex[fileName] = FileNameToIndex({exists: true, index: uint248(uploadedFiles.length - 1)});
        newFile.fileInfos.contentType = contentType;

        // We store the content on the storage backend
        // Only a portion of the data may have been sent, in which case we will need to append
        // with appendToUploadedFile()
        uint fundsUsed;
        (newFile.fileInfos.contentKey, fundsUsed) = factory.storageBackends(newFile.storageBackendIndex).create(data, dataLength);

        emit FileUploaded(fileName, contentType);

        // Send back remaining funds sent by the caller
        if(msg.value - fundsUsed > 0) {
            payable(msg.sender).transfer(msg.value - fundsUsed);
        }
    }

    function appendToUploadedFile(string memory fileName, bytes memory data) public payable onlyOwnerOrEditors {
        require(uploadedFilesNameToIndex[fileName].exists, "File not found");

        uint index = uploadedFilesNameToIndex[fileName].index;
        FileInfosWithStorageBackend storage uploadedFile = uploadedFiles[index];

        uint fundsUsed = factory.storageBackends(uploadedFile.storageBackendIndex).append(uploadedFile.fileInfos.contentKey, data);

        // Send back remaining funds sent by the caller
        if(msg.value - fundsUsed > 0) {
            payable(msg.sender).transfer(msg.value - fundsUsed);
        }
    }

    function getUploadedFiles() public view returns (FileInfosWithStorageBackend[] memory) {
        return uploadedFiles;
    }

    function getUploadedFilesCount() public view returns (uint256) {
        return uploadedFiles.length;
    }

    function getUploadedFile(uint256 index) public view returns (FileInfosWithStorageBackend memory) {
        require(index < uploadedFiles.length, "Index out of bounds");

        return uploadedFiles[index];
    }

    function getUploadedFileByName(string memory fileName) public view returns (FileInfosWithStorageBackend memory uploadedFile, uint256 index) {
        require(uploadedFilesNameToIndex[fileName].exists, "File not found");

        index = uploadedFilesNameToIndex[fileName].index;
        uploadedFile = uploadedFiles[index];
    }

    function getUploadedFileContents(uint256 index, uint256 startingChunkId) public view returns (bytes memory contents, uint nextChunkId) {
        require(index < uploadedFiles.length, "Index out of bounds");

        FileInfosWithStorageBackend memory uploadedFile = uploadedFiles[index];
        IStorageBackend storageBackend = factory.storageBackends(uploadedFile.storageBackendIndex);
        (contents, nextChunkId) = storageBackend.read(address(this), uploadedFile.fileInfos.contentKey, startingChunkId);
    }

    function removeUploadedFile(uint256 index) public onlyOwnerOrEditors {
        require(index < uploadedFiles.length, "Index out of bounds");

        FileInfosWithStorageBackend storage uploadedFile = uploadedFiles[index];

        factory.storageBackends(uploadedFile.storageBackendIndex).remove(uploadedFile.fileInfos.contentKey);

        uploadedFilesNameToIndex[uploadedFile.fileInfos.filePath].exists = false;
        
        uploadedFile.storageBackendIndex = uploadedFiles[uploadedFiles.length - 1].storageBackendIndex;
        uploadedFile.fileInfos = uploadedFiles[uploadedFiles.length - 1].fileInfos;

        uploadedFilesNameToIndex[uploadedFile.fileInfos.filePath].index = uint248(index);
        uploadedFiles.pop();
    }


    //
    // Some calls with infos packed as much as possible in order to not overwhelm RPC clients
    // for web3:// calls
    //

    function getTitleAndDescriptionAndOwner() public view returns (string memory, string memory, address) {
        return (title, description, owner());
    }

    struct FileInfosWithStorageBackendAndCompleteness {
        FileInfosWithStorageBackend fileInfos;
        bool complete;
    }
    function getEditorsAndPostsAndUploadedFiles() public view returns (address[] memory, BlogPostWithIndex[] memory, FileInfosWithStorageBackendAndCompleteness[] memory) {

        FileInfosWithStorageBackendAndCompleteness[] memory uploadedFilesWithCompleteness = new FileInfosWithStorageBackendAndCompleteness[](uploadedFiles.length);
        for(uint i = 0; i < uploadedFiles.length; i++) {
            uploadedFilesWithCompleteness[i].fileInfos = uploadedFiles[i];
            uploadedFilesWithCompleteness[i].complete = factory.storageBackends(uploadedFiles[i].storageBackendIndex).isComplete(address(this), uploadedFiles[i].fileInfos.contentKey);
        }

        return (editors, getPosts(), uploadedFilesWithCompleteness);
    }


    //
    // Blog frontend : expose data to be called in web3://
    // That is the current limitation of the resourceRequest mode : if you want to 
    // expose structured data in JSON like in auto mode, you have to manually serialize it
    // Should be a good idea of a new extension of the resourceRequest mode
    //

    function frontendVersion() public view returns (FrontendFilesSet memory, bool, uint256) {
        return (frontend.blogFrontendVersion(), frontend.useNonDefaultFrontend(), frontend.overridenFrontendIndex());
    }


    //
    // Extension for the future
    // 

    function addExtension(string memory name) public onlyOwner {
        IBlogExtension extensionImplementationToAdd = factory.getBlogExtensionByName(name);
        require(address(extensionImplementationToAdd) != address(0), "Extension not found");

        for(uint i = 0; i < extensions.length; i++) {
            require(Strings.compare(extensions[i].getName(), extensionImplementationToAdd.getName()) == false, "Extension already added");
        }

        IBlogExtension extensionToAdd = IBlogExtension(Clones.clone(address(extensionImplementationToAdd)));
        extensionToAdd.initialize(this);

        extensions.push(extensionToAdd);
    }

    struct ExtensionInfos {
        string name;
        address extensionAddress;
    }
    function getExtensions() public view returns (ExtensionInfos[] memory) {
        ExtensionInfos[] memory extensionsInfos = new ExtensionInfos[](extensions.length);
        for(uint i = 0; i < extensions.length; i++) {
            extensionsInfos[i].name = extensions[i].getName();
            extensionsInfos[i].extensionAddress = address(extensions[i]);
        }

        return extensionsInfos;
    }

    function setFlags(bytes32 _flags) public onlyOwner {
        flags = _flags;
    }
}
