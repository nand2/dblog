// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlogFrontend.sol";
import "./DBlogFactory.sol";
import "./interfaces/FileInfos.sol";

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

    // Files uploaded by the author/editors
    FileInfosWithStorageMode[] uploadedFiles;

    // EthStorage content keys: we use a simple incrementing key
    uint256 public ethStorageLastUsedKey = 0;
    // When deleting files, we store the keys to reuse them (we don't need to pay EthStorage again)
    bytes32[] public reusableEthStorageKeys;

    uint256 public constant ETHSTORAGE_BLOBS_PER_WEB3_PROTOCOL_CHUNK = 4;

    event PostCreated(uint indexed postId);
    event PostEdited(uint indexed postId);
    event FileUploaded(string filename, string contentType);

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

    function addUploadedFileOnEthfs(string memory fileName, string memory contentType, bytes memory fileContents) public onlyOwnerOrEditors {
        // EthFs already ensure file uniqueness
        // This simple implementation has his drawback : the file name table is global
        // But this is mostly done for local testing, even though it can be used on mainnet

        uploadedFiles.push();
        FileInfosWithStorageMode storage newFile = uploadedFiles[uploadedFiles.length - 1];
        newFile.storageMode = FileStorageMode.SSTORE2;
        newFile.fileInfos.filePath = fileName;
        newFile.fileInfos.contentType = contentType;

        // We store the content on ethFs
        (address filePointer, ) = factory.ethsFileStore().createFile(fileName, string(fileContents));
        newFile.fileInfos.contentKeys.push(bytes32(uint256(uint160(filePointer))));

        emit FileUploaded(fileName, contentType);
    }

    /**
     * Adding a file on EthStorage can be done in multiple calls: this one, and several 
     * completeUploadedFileOnEthStorage() calls.
     * @param filePath The path of the file, without root slash. E.g. "images/logo.png"
     * @param contentType The content type of the file, e.g. "image/png"
     * @param blobsCount The number of blobs that will be uploaded, in this call and optional several other completeUploadedFileOnEthStorage() calls
     * @param blobDataSizes The size of each blob that will be uploaded in this call.
     */
    function addUploadedFileOnEthStorage(string memory filePath, string memory contentType, uint256 blobsCount, uint256[] memory blobDataSizes) public payable onlyOwnerOrEditors {
        require(Strings.compare(filePath, "") == false, "File path must be set");
        require(Strings.compare(contentType, "") == false, "Content type must be set");
        require(blobDataSizes.length > 0, "At least one blob");
        require(blobsCount >= blobDataSizes.length, "Total blob count must be at least the blobDataSizes length");
        // Ensure file name is unique
        for(uint i = 0; i < uploadedFiles.length; i++) {
            require(keccak256(abi.encodePacked(uploadedFiles[i].fileInfos.filePath)) != keccak256(abi.encodePacked(filePath)), "File already uploaded");
        }

        uploadedFiles.push();
        FileInfosWithStorageMode storage newFile = uploadedFiles[uploadedFiles.length - 1];
        newFile.storageMode = FileStorageMode.EthStorage;
        newFile.fileInfos.filePath = filePath;
        newFile.fileInfos.contentType = contentType;

        // We store the content on EthStorage
        bytes32[] memory ethStorageKeys = new bytes32[](blobsCount);
        uint256 upfrontPayment = this.getEthStorageUpfrontPayment();
        uint256 fundsUsed = 0;
        for(uint i = 0; i < blobDataSizes.length; i++) {
            uint payment = 0;

            if(reusableEthStorageKeys.length > 0) {
                ethStorageKeys[i] = reusableEthStorageKeys[reusableEthStorageKeys.length - 1];
                reusableEthStorageKeys.pop();
            } else {
                ethStorageLastUsedKey++;
                ethStorageKeys[i] = bytes32(ethStorageLastUsedKey);
                payment = upfrontPayment;
            }

            factory.ethStorage().putBlob{value: payment}(ethStorageKeys[i], i, blobDataSizes
            [i]);
            fundsUsed += payment;
        }
        newFile.fileInfos.contentKeys = ethStorageKeys;

        emit FileUploaded(filePath, contentType);

        // Send back remaining funds sent by the caller
        if(msg.value - fundsUsed > 0) {
            payable(msg.sender).transfer(msg.value - fundsUsed);
        }
    }

    /**
     * Complete the upload of a file on EthStorage. This function can be called multiple times.
     */
    function completeUploadedFileOnEthStorage(string memory filePath, uint256[] memory blobDataSizes) public payable onlyOwnerOrEditors {
        
        uint uploadedFileIndex;
        bool found = false;
        for(uint i = 0; i < uploadedFiles.length; i++) {
            if(Strings.compare(uploadedFiles[i].fileInfos.filePath, filePath)) {
                uploadedFileIndex = i;
                found = true;
                break;
            }
        }
        require(found, "File not found");
        FileInfosWithStorageMode storage uploadedFile = uploadedFiles[uploadedFileIndex];

        require(uploadedFile.storageMode == FileStorageMode.EthStorage, "File is not on EthStorage");

        // Determine the position of the last blob which was not uploaded yet
        uint contentKeyStartingIndex = 0;
        for(uint i = 0; i < uploadedFile.fileInfos.contentKeys.length; i++) {
            if(uploadedFile.fileInfos.contentKeys[i] == 0) {
                contentKeyStartingIndex = i;
                break;
            }
        }
        require(contentKeyStartingIndex > 0, "All blobs already uploaded");
        require(contentKeyStartingIndex + blobDataSizes.length <= uploadedFile.fileInfos.contentKeys.length, "Too many blobs");

        // We store the content on EthStorage
        uint256 upfrontPayment = this.getEthStorageUpfrontPayment();
        for(uint i = 0; i < blobDataSizes.length; i++) {
            ethStorageLastUsedKey++;
            uploadedFile.fileInfos.contentKeys[contentKeyStartingIndex + i] = bytes32(ethStorageLastUsedKey);
            factory.ethStorage().putBlob{value: upfrontPayment}(uploadedFile.fileInfos.contentKeys[contentKeyStartingIndex + i], i, blobDataSizes[i]);
        }
    }

    function getUploadedFiles() public view returns (FileInfosWithStorageMode[] memory) {
        return uploadedFiles;
    }

    function getUploadedFilesCount() public view returns (uint256) {
        return uploadedFiles.length;
    }

    function getUploadedFile(uint256 index) public view returns (FileInfosWithStorageMode memory) {
        require(index < uploadedFiles.length, "Index out of bounds");

        return uploadedFiles[index];
    }

    function getUploadedFileContentsChunkCount(uint256 index) public view returns (uint256 chunkCount) {
        require(index < uploadedFiles.length, "Index out of bounds");

        FileInfosWithStorageMode memory uploadedFile = uploadedFiles[index];

        if(uploadedFile.storageMode == FileStorageMode.SSTORE2) {
            chunkCount = 1;
        }
        else if(uploadedFile.storageMode == FileStorageMode.EthStorage) {
            chunkCount = uploadedFile.fileInfos.contentKeys.length / ETHSTORAGE_BLOBS_PER_WEB3_PROTOCOL_CHUNK;
            if(uploadedFile.fileInfos.contentKeys.length % ETHSTORAGE_BLOBS_PER_WEB3_PROTOCOL_CHUNK > 0) {
                chunkCount++;
            }
        }
    }

    function getUploadedFileContents(uint256 index, uint256 chunkId) public view returns (bytes memory contents) {
        require(index < uploadedFiles.length, "Index out of bounds");

        TestEthStorageContractKZG ethStorage = factory.ethStorage();
        FileInfosWithStorageMode memory uploadedFile = uploadedFiles[index];

        if(uploadedFile.storageMode == FileStorageMode.SSTORE2) {
            File memory file = abi.decode(SSTORE2.read(address(uint160(uint256(uploadedFile.fileInfos.contentKeys[0])))), (File));
            contents = bytes(file.read());
        }
        else if(uploadedFile.storageMode == FileStorageMode.EthStorage) {
            bytes memory content;
            for(uint j = chunkId * ETHSTORAGE_BLOBS_PER_WEB3_PROTOCOL_CHUNK; j < (chunkId + 1) * ETHSTORAGE_BLOBS_PER_WEB3_PROTOCOL_CHUNK && j < uploadedFile.fileInfos.contentKeys.length; j++) {
                content = bytes.concat(content, ethStorage.get(uploadedFile.fileInfos.contentKeys[j], DecentralizedKV.DecodeType.PaddingPer31Bytes, 0, ethStorage.size(uploadedFile.fileInfos.contentKeys[j])));
            }
            contents = content;
        }
    }

    function removeUploadedFile(uint256 index) public onlyOwnerOrEditors {
        require(index < uploadedFiles.length, "Index out of bounds");

        FileInfosWithStorageMode storage uploadedFile = uploadedFiles[index];

        if(uploadedFile.storageMode == FileStorageMode.EthStorage) {
            // Store the keys to reuse them
            for(uint i = 0; i < uploadedFile.fileInfos.contentKeys.length; i++) {
                reusableEthStorageKeys.push(uploadedFile.fileInfos.contentKeys[i]);
            }
        }

        uploadedFile = uploadedFiles[uploadedFiles.length - 1];
        uploadedFiles.pop();
    }
}
