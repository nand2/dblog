// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {FileStore, File} from "ethfs/FileStore.sol";

import "./DBlogFrontend.sol";
import "./DBlogFactory.sol";
import "./interfaces/FileInfos.sol";
import "./interfaces/IStorageBackend.sol";

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

    // SSTORE2: Own clone of the FileStore contract, to have our own namespace
    FileStore public fileStore;

    // EthStorage content keys: we use a simple incrementing key
    uint256 public ethStorageLastUsedKey = 0;
    // When deleting files, we store the keys to reuse them (we don't need to pay EthStorage again)
    bytes32[] public reusableEthStorageKeys;

    // Flags for possible extensions?
    bytes32 public flags;


    event PostCreated(uint indexed postId);
    event PostEdited(uint indexed postId);
    event FileUploaded(string filename, string contentType);

    struct BlogPost {
        string title;
        uint64 timestamp;

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
    BlogPost[] public posts;

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
    function initialize(DBlogFactory _factory, DBlogFrontend _frontend, string memory _subdomain, string memory _title, string memory _description) public {
        require(address(factory) == address(0), "Already initialized");

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

    function addPost(string memory postTitle, string memory storageBackendName, bytes memory data, uint dataLength, uint8 contentFormatVersion, bytes20 extra) public onlyOwnerOrEditors {
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
        newPost.contentKey = factory.storageBackends(newPost.storageBackendIndex).create(data, dataLength);

        emit PostCreated(posts.length - 1);
    }

    // function addPostOnEthereumState(string memory postTitle, string memory postContent, uint8 contentFormatVersion, bytes20 extra) public onlyOwnerOrEditors {
    //     // Initialise the FileStore if not done yet
    //     if(address(fileStore) == address(0)) {
    //         fileStore = FileStore(Clones.clone(address(factory.ethFsFileStore())));
    //     }

    //     posts.push();
    //     BlogPost storage newPost = posts[posts.length - 1];
    //     newPost.title = postTitle;
    //     newPost.timestamp = uint64(block.timestamp);
    //     newPost.contentFormatVersion = contentFormatVersion;
    //     newPost.extra = extra;
    //     newPost.storageMode = FileStorageMode.SSTORE2;
        
    //     // We store the content on FileStore
    //     (address filePointer, ) = fileStore.createFile(string.concat("blog-entry-", Strings.toString(posts.length - 1), ".txt"), postContent);
    //     newPost.contentKey = bytes32(uint256(uint160(filePointer)));

    //     emit PostCreated(posts.length - 1);
    // }

    function getEthStorageUpfrontPayment() external view returns (uint256) {
        return factory.ethStorage().upfrontPayment();
    }

    // function addPostOnEthStorage(string memory postTitle, uint256 blobDataSize, uint8 contentFormatVersion, bytes20 extra) public payable onlyOwnerOrEditors {
    //     posts.push();
    //     BlogPost storage newPost = posts[posts.length - 1];
    //     newPost.title = postTitle;
    //     newPost.timestamp = uint64(block.timestamp);
    //     newPost.contentFormatVersion = contentFormatVersion;
    //     newPost.extra = extra;
    //     newPost.storageMode = FileStorageMode.EthStorage;

    //     // We store the content on EthStorage
    //     ethStorageLastUsedKey++;
    //     bytes32 ethStorageContentKey = bytes32(ethStorageLastUsedKey);
    //     uint256 upfrontPayment = this.getEthStorageUpfrontPayment();
    //     factory.ethStorage().putBlob{value: upfrontPayment}(ethStorageContentKey, 0, blobDataSize);
    //     newPost.contentKey = ethStorageContentKey;

    //     emit PostCreated(posts.length - 1);
    // }

    function getPost(uint256 index) public view returns (BlogPost memory, string memory) {
        require(index < posts.length, "Index out of bounds");

        // For EthStorage, we need to fetch it via the EthStorage chain
        uint nextChunkId;
        bytes memory content;
        (content, nextChunkId) = factory.storageBackends(posts[index].storageBackendIndex).read(address(this), posts[index].contentKey, 0);
        
        // We don't expect to be a nextChunkId for blog content, as the blog post themselves should not
        // be too big. We expect nextChunkId for media files.

        return (posts[index], string(content));
    }

    // // Need to be called with the EthStorage chain
    // function getPostEthStorageContent(uint256 index) public view returns (bytes memory) {
    //     require(index < posts.length, "Index out of bounds");
    //     require(posts[index].storageMode == FileStorageMode.EthStorage, "Post is not on EthStorage");

    //     return factory.ethStorage().get(
    //         posts[index].contentKey, 
    //         DecentralizedKV.DecodeType.PaddingPer31Bytes, 
    //         0, 
    //         factory.ethStorage().size(posts[index].contentKey));
    // }

    function editPost(uint256 index, string memory postTitle, string memory storageBackendName, bytes memory data, uint dataLength, uint8 contentFormatVersion, bytes20 extra) public onlyOwnerOrEditors {
        require(index < posts.length, "Index out of bounds");
        // getStorageBackendIndexByName() will revert if not found
        posts[index].storageBackendIndex = factory.getStorageBackendIndexByName(storageBackendName);

        posts[index].title = postTitle;
        posts[index].contentFormatVersion = contentFormatVersion;
        posts[index].extra = extra;
        // We store the content on the storage backend
        // We store all at once (we assume blog posts themselves won't require multiple tx)
        posts[index].contentKey = factory.storageBackends(posts[index].storageBackendIndex).create(data, dataLength);

        emit PostEdited(index);
    }

    // function editEthereumStatePost(uint256 index, string memory postTitle, string memory postContent, uint8 contentFormatVersion, bytes20 extra) public onlyOwnerOrEditors {
    //     require(index < posts.length, "Index out of bounds");
    //     require(posts[index].storageMode == FileStorageMode.SSTORE2, "Post is not on Ethereum state");

    //     posts[index].title = postTitle;
    //     posts[index].contentFormatVersion = contentFormatVersion;
    //     posts[index].extra = extra;
    //     // Each edition has a unique file name. Finds out the filename to use
    //     uint revision = 1;
    //     string memory fileName;
    //     while(true) {
    //         fileName = string.concat("blog-entry-", Strings.toString(index), "-", Strings.toString(revision), ".txt");
    //         if(fileStore.fileExists(fileName) == false) {
    //             break;
    //         } else {
    //             revision++;
    //         }
    //     }
    //     // We store the content on FileStore
    //     (address filePointer, ) = fileStore.createFile(fileName, postContent);
    //     posts[index].contentKey = bytes32(uint256(uint160(filePointer)));

    //     emit PostEdited(index);
    // }

    // function editEthStoragePost(uint256 index, string memory postTitle, uint256 blobDataSize, uint8 contentFormatVersion, bytes20 extra) public payable onlyOwnerOrEditors {
    //     require(index < posts.length, "Index out of bounds");
    //     require(posts[index].storageMode == FileStorageMode.EthStorage, "Post is not on EthStorage");

    //     posts[index].title = postTitle;
    //     posts[index].contentFormatVersion = contentFormatVersion;
    //     posts[index].extra = extra;
    //     // We store the content on EthStorage
    //     // No payment, as we reuse a key
    //     factory.ethStorage().putBlob(posts[index].contentKey, 0, blobDataSize);

    //     emit PostEdited(index);
    // }

    function getPostCount() public view returns (uint256) {
        return posts.length;
    }

    function getPosts() public view returns (BlogPost[] memory) {
        return posts;
    }


    //
    // Uploaded files for the blog posts
    //

    function addUploadedFile(string memory fileName, string memory contentType, string memory storageBackendName, bytes memory data, uint dataLength) public onlyOwnerOrEditors {
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
        newFile.fileInfos.contentKey = factory.storageBackends(newFile.storageBackendIndex).create(data, dataLength);

        emit FileUploaded(fileName, contentType);
    }

    function appendToUploadedFile(string memory fileName, bytes memory data) public onlyOwnerOrEditors {
        require(uploadedFilesNameToIndex[fileName].exists, "File not found");

        uint index = uploadedFilesNameToIndex[fileName].index;
        FileInfosWithStorageBackend storage uploadedFile = uploadedFiles[index];

        factory.storageBackends(uploadedFile.storageBackendIndex).append(uploadedFile.fileInfos.contentKey, data);
    }


    // function addUploadedFileOnEthfs(string memory fileName, string memory contentType, bytes memory fileContents) public onlyOwnerOrEditors {
    //     // Initialise the FileStore if not done yet
    //     if(address(fileStore) == address(0)) {
    //         fileStore = FileStore(Clones.clone(address(factory.ethFsFileStore())));
    //     }

    //     uploadedFiles.push();
    //     FileInfosWithStorageMode storage newFile = uploadedFiles[uploadedFiles.length - 1];
    //     newFile.storageMode = FileStorageMode.SSTORE2;
    //     newFile.fileInfos.filePath = fileName;
    //     uploadedFilesNameToIndex[fileName] = FileNameToIndex({exists: true, index: uint248(uploadedFiles.length - 1)});
    //     newFile.fileInfos.contentType = contentType;

    //     // We store the content on ethFs
    //     (address filePointer, ) = fileStore.createFile(fileName, string(fileContents));
    //     newFile.fileInfos.contentKeys.push(bytes32(uint256(uint160(filePointer))));

    //     emit FileUploaded(fileName, contentType);
    // }

    /**
     * Adding a file on EthStorage can be done in multiple calls: this one, and several 
     * completeUploadedFileOnEthStorage() calls.
     * @param filePath The path of the file, without root slash. E.g. "images/logo.png"
     * @param contentType The content type of the file, e.g. "image/png"
     * @param blobsCount The number of blobs that will be uploaded, in this call and optional several other completeUploadedFileOnEthStorage() calls
     * @param blobDataSizes The size of each blob that will be uploaded in this call.
     */
    // function addUploadedFileOnEthStorage(string memory filePath, string memory contentType, uint256 blobsCount, uint256[] memory blobDataSizes) public payable onlyOwnerOrEditors {
    //     require(Strings.compare(filePath, "") == false, "File path must be set");
    //     require(Strings.compare(contentType, "") == false, "Content type must be set");
    //     require(blobDataSizes.length > 0, "At least one blob");
    //     require(blobsCount >= blobDataSizes.length, "Total blob count must be at least the blobDataSizes length");
    //     // Ensure file name is unique
    //     for(uint i = 0; i < uploadedFiles.length; i++) {
    //         require(keccak256(abi.encodePacked(uploadedFiles[i].fileInfos.filePath)) != keccak256(abi.encodePacked(filePath)), "File already uploaded");
    //     }

    //     uploadedFiles.push();
    //     FileInfosWithStorageMode storage newFile = uploadedFiles[uploadedFiles.length - 1];
    //     newFile.storageMode = FileStorageMode.EthStorage;
    //     newFile.fileInfos.filePath = filePath;
    //     uploadedFilesNameToIndex[filePath] = FileNameToIndex({exists: true, index: uint248(uploadedFiles.length - 1)});
    //     newFile.fileInfos.contentType = contentType;

    //     // We store the content on EthStorage
    //     bytes32[] memory ethStorageKeys = new bytes32[](blobsCount);
    //     uint256 upfrontPayment = this.getEthStorageUpfrontPayment();
    //     uint256 fundsUsed = 0;
    //     for(uint i = 0; i < blobDataSizes.length; i++) {
    //         uint payment = 0;

    //         if(reusableEthStorageKeys.length > 0) {
    //             ethStorageKeys[i] = reusableEthStorageKeys[reusableEthStorageKeys.length - 1];
    //             reusableEthStorageKeys.pop();
    //         } else {
    //             ethStorageLastUsedKey++;
    //             ethStorageKeys[i] = bytes32(ethStorageLastUsedKey);
    //             payment = upfrontPayment;
    //         }

    //         factory.ethStorage().putBlob{value: payment}(ethStorageKeys[i], i, blobDataSizes
    //         [i]);
    //         fundsUsed += payment;
    //     }
    //     newFile.fileInfos.contentKeys = ethStorageKeys;

    //     emit FileUploaded(filePath, contentType);

    //     // Send back remaining funds sent by the caller
    //     if(msg.value - fundsUsed > 0) {
    //         payable(msg.sender).transfer(msg.value - fundsUsed);
    //     }
    // }

    /**
     * Complete the upload of a file on EthStorage. This function can be called multiple times.
     */
    // function completeUploadedFileOnEthStorage(string memory filePath, uint256[] memory blobDataSizes) public payable onlyOwnerOrEditors {
        
    //     uint uploadedFileIndex;
    //     bool found = false;
    //     for(uint i = 0; i < uploadedFiles.length; i++) {
    //         if(Strings.compare(uploadedFiles[i].fileInfos.filePath, filePath)) {
    //             uploadedFileIndex = i;
    //             found = true;
    //             break;
    //         }
    //     }
    //     require(found, "File not found");
    //     FileInfosWithStorageMode storage uploadedFile = uploadedFiles[uploadedFileIndex];

    //     require(uploadedFile.storageMode == FileStorageMode.EthStorage, "File is not on EthStorage");

    //     // Determine the position of the last blob which was not uploaded yet
    //     uint contentKeyStartingIndex = 0;
    //     for(uint i = 0; i < uploadedFile.fileInfos.contentKeys.length; i++) {
    //         if(uploadedFile.fileInfos.contentKeys[i] == 0) {
    //             contentKeyStartingIndex = i;
    //             break;
    //         }
    //     }
    //     require(contentKeyStartingIndex > 0, "All blobs already uploaded");
    //     require(contentKeyStartingIndex + blobDataSizes.length <= uploadedFile.fileInfos.contentKeys.length, "Too many blobs");

    //     // We store the content on EthStorage
    //     uint256 upfrontPayment = this.getEthStorageUpfrontPayment();
    //     for(uint i = 0; i < blobDataSizes.length; i++) {
    //         ethStorageLastUsedKey++;
    //         uploadedFile.fileInfos.contentKeys[contentKeyStartingIndex + i] = bytes32(ethStorageLastUsedKey);
    //         factory.ethStorage().putBlob{value: upfrontPayment}(uploadedFile.fileInfos.contentKeys[contentKeyStartingIndex + i], i, blobDataSizes[i]);
    //     }
    // }

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


        // TestEthStorageContractKZG ethStorage = factory.ethStorage();
        

        // if(uploadedFile.storageMode == FileStorageMode.SSTORE2) {
        //     File memory file = abi.decode(SSTORE2.read(address(uint160(uint256(uploadedFile.fileInfos.contentKeys[0])))), (File));
        //     contents = bytes(file.read());
        // }
        // else if(uploadedFile.storageMode == FileStorageMode.EthStorage) {
        //     bytes memory content;
        //     for(uint j = chunkId * ETHSTORAGE_BLOBS_PER_WEB3_PROTOCOL_CHUNK; j < (chunkId + 1) * ETHSTORAGE_BLOBS_PER_WEB3_PROTOCOL_CHUNK && j < uploadedFile.fileInfos.contentKeys.length; j++) {
        //         content = bytes.concat(content, ethStorage.get(uploadedFile.fileInfos.contentKeys[j], DecentralizedKV.DecodeType.PaddingPer31Bytes, 0, ethStorage.size(uploadedFile.fileInfos.contentKeys[j])));
        //     }
        //     contents = content;
        // }
    }

    function removeUploadedFile(uint256 index) public onlyOwnerOrEditors {
        require(index < uploadedFiles.length, "Index out of bounds");

        FileInfosWithStorageBackend storage uploadedFile = uploadedFiles[index];

        // if(uploadedFile.storageMode == FileStorageMode.EthStorage) {
        //     // Store the keys to reuse them
        //     for(uint i = 0; i < uploadedFile.fileInfos.contentKeys.length; i++) {
        //         reusableEthStorageKeys.push(uploadedFile.fileInfos.contentKeys[i]);
        //     }
        // }

        uploadedFilesNameToIndex[uploadedFile.fileInfos.filePath].exists = false;
        uploadedFile = uploadedFiles[uploadedFiles.length - 1];
        uploadedFiles.pop();
    }


    //
    // Some calls with infos packed as much as possible in order to not overwhelm RPC clients
    // for web3:// calls
    //

    function getTitleAndDescriptionAndOwner() public view returns (string memory, string memory, address) {
        return (title, description, owner());
    }

    function getEditorsAndPostsAndUploadedFiles() public view returns (address[] memory, BlogPost[] memory, FileInfosWithStorageBackend[] memory) {
        return (editors, posts, uploadedFiles);
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

    // function setFlags(bytes32 _flags) public onlyOwner {
    //     flags = _flags;
    // }
}
