// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestEthStorageContractKZG } from "storage-contracts-v1/TestEthStorageContractKZG.sol";
import { DecentralizedKV } from "storage-contracts-v1/DecentralizedKV.sol";

import "./DBlogFactory.sol";

enum FrontendStorageMode {
    SSTORE2, // Store on the ethereum network itself using SSTORE2
    EthStorage // Store with the EthStorage project
}
struct FileInfos {
    // The path of the file, without root slash. E.g. "images/logo.png"
    string filePath;
    // The content type of the file, e.g. "image/png"
    string contentType;

    // Pointers to the file contents
    // If storage mode is SSTORE2, then there will only be one address pointer to the SSTORE2 file
    // If storage mode is EthStorage, then these are the keys to the EthStorage file parts
    // Note: These files are expected to be compressed with gzip
    bytes32[] contentKeys;
}
// A version of a frontend, containing a single HTML, CSS and JS file.
struct BlogFrontendVersion {
    // Storage mode for the frontend files
    FrontendStorageMode storageMode;

    // The files of the frontend
    FileInfos[] files;

    // Pointers to the files
    // If storage mode is SSTORE2, then these are address pointers to the SSTORE2 files
    // If storage mode is EthStorage, then these are the keys to the EthStorage files
    // Note: These files are expected to be compressed with gzip
    bytes32 htmlFile;
    bytes32 cssFile;
    bytes32 jsFile;

    // Infos about this version
    string infos;
}

contract DBlogFrontendLibrary {
    DBlogFactory public blogFactory;

    BlogFrontendVersion[] public frontendVersions;
    uint256 public defaultFrontendIndex;

    uint256 public ethStorageLastUsedKey = 0;


    modifier onlyFactoryOrFactoryOwner() {
        require(msg.sender == address(blogFactory) || msg.sender == blogFactory.owner(), "Not owner");
        _;
    }

    constructor() {}

    // Due to difficulties with verifying source of contracts deployed by contracts, and 
    // this contract and DBlogFactory pointing to each other, we add the pointer to the blog factory
    // in this method, after this contract has been created.
    // Security : This can be only called once. Both pointers are set on DBlogFactory constructor, 
    // so this method can be open
    function setBlogFactory(DBlogFactory _blogFactory) public {
        // We can only set the blog factory once
        require(address(blogFactory) == address(0), "Already set");
        blogFactory = _blogFactory;
    }

    function addSStore2FrontendVersion(FileInfos[] memory files, string memory _infos) public onlyFactoryOrFactoryOwner {
        // Weird insertion into frontendVersions due to :
        // Error: Unimplemented feature (/solidity/libsolidity/codegen/ArrayUtils.cpp:227):Copying of type struct FileInfos memory[] memory to storage not yet supported.
        frontendVersions.push();
        BlogFrontendVersion storage newFrontend = frontendVersions[frontendVersions.length - 1];
        newFrontend.storageMode = FrontendStorageMode.SSTORE2;
        for(uint i = 0; i < files.length; i++) {
            newFrontend.files.push(files[i]);
        }
        newFrontend.infos = _infos;
        defaultFrontendIndex = frontendVersions.length - 1;
    }

    function getEthStorageUpfrontPayment() external view returns (uint256) {
        return blogFactory.ethStorage().upfrontPayment();
    }

    // The idea behind the frontend versions is that they are immutable
    // So in the case of EthStorage, we cannot give the keys as arguments (otherwise we can
    // override a key), so the keys will be generated by this contract. We will only give
    // the blob indexes to this function
    struct EthStorageFileUploadInfos {
        // The path of the file, without root slash. E.g. "images/logo.png"
        string filePath;
        // The content type of the file, e.g. "image/png"
        string contentType;
        // The indexes of the blobs to use for this file
        uint256[] blobIndexes;
        // The size of the data in the blobs
        uint256[] blobDataSizes;
    }
    function addEthStorageFrontendVersion(EthStorageFileUploadInfos[] memory files, string memory _infos) public payable onlyFactoryOrFactoryOwner {
        TestEthStorageContractKZG ethStorage = blogFactory.ethStorage();
        uint256 upfrontPayment = this.getEthStorageUpfrontPayment();

        // Weird insertion into frontendVersions due to :
        // Error: Unimplemented feature (/solidity/libsolidity/codegen/ArrayUtils.cpp:227):Copying of type struct FileInfos memory[] memory to storage not yet supported.
        frontendVersions.push();
        BlogFrontendVersion storage newFrontend = frontendVersions[frontendVersions.length - 1];
        newFrontend.storageMode = FrontendStorageMode.EthStorage;
        for(uint i = 0; i < files.length; i++) {
            bytes32[] memory ethStorageKeys = new bytes32[](files[i].blobIndexes.length);
            for(uint j = 0; j < files[i].blobIndexes.length; j++) {
                ethStorageLastUsedKey++;
                ethStorageKeys[j] = bytes32(ethStorageLastUsedKey);
                // Upload part of the file
                // ethStorageKeys[j] is a key we choose, and it will be mixed with msg.sender
                ethStorage.putBlob{value: upfrontPayment}(ethStorageKeys[j], files[i].blobIndexes[j], files[i].blobDataSizes[j]);
            }
            newFrontend.files.push(FileInfos({
                filePath: files[i].filePath,
                contentType: files[i].contentType,
                contentKeys: ethStorageKeys
            }));
        }
        newFrontend.infos = _infos;
        defaultFrontendIndex = frontendVersions.length - 1;
    }

    // Peculiar EthStorage thing: When storing a blob with a key, it mixes the key with
    // msg.sender. So the uploader should also be the fetcher
    function getEthStorageFileContents(bytes32 _key) public view returns (bytes memory) {
        TestEthStorageContractKZG ethStorage = blogFactory.ethStorage();
        return ethStorage.get(
            _key, 
            DecentralizedKV.DecodeType.PaddingPer31Bytes, 
            0, 
            ethStorage.size(_key));
    }

    function getFrontendVersion(uint256 _index) public view returns (BlogFrontendVersion memory) {
        require(_index < frontendVersions.length, "Index out of bounds");
        return frontendVersions[_index];
    }

    function setDefaultFrontend(uint256 _index) public onlyFactoryOrFactoryOwner {
        require(_index < frontendVersions.length, "Index out of bounds");
        defaultFrontendIndex = _index;
    }

    function getDefaultFrontend() public view returns (BlogFrontendVersion memory) {
        return frontendVersions[defaultFrontendIndex];
    }

    function getFrontendVersionCount() public view returns (uint256) {
        return frontendVersions.length;
    }
}