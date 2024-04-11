// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestEthStorageContractKZG } from "storage-contracts-v1/TestEthStorageContractKZG.sol";
import { DecentralizedKV } from "storage-contracts-v1/DecentralizedKV.sol";

import "./DBlogFactory.sol";

enum FrontendStorageMode {
    SSTORE2, // Store on the ethereum network itself using SSTORE2
    EthStorage // Store with the EthStorage project
}
// A version of a frontend, containing a single HTML, CSS and JS file.
struct BlogFrontendVersion {
    // Storage mode for the frontend files
    FrontendStorageMode storageMode;

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

    function addSStore2FrontendVersion(address _htmlFile, address _cssFile, address _jsFile, string memory _infos) public onlyFactoryOrFactoryOwner {
        BlogFrontendVersion memory newFrontend = BlogFrontendVersion(
            FrontendStorageMode.SSTORE2,
            bytes32(uint256(uint160(_htmlFile))), 
            bytes32(uint256(uint160(_cssFile))), 
            bytes32(uint256(uint160(_jsFile))), 
            _infos);
        frontendVersions.push(newFrontend);
        defaultFrontendIndex = frontendVersions.length - 1;
    }

    function getEthStorageUpfrontPayment() external view returns (uint256) {
        return blogFactory.ethStorage().upfrontPayment();
    }

    function addEthStorageFrontendVersion(bytes32 _htmlFileKey, uint256 _htmlFileSize, bytes32 _cssFileKey, uint256 _cssFileSize, bytes32 _jsFileKey, uint256 _jsFileSize, string memory _infos) public payable onlyFactoryOrFactoryOwner {
        TestEthStorageContractKZG ethStorage = blogFactory.ethStorage();
        uint256 upfrontPayment = this.getEthStorageUpfrontPayment();

        ethStorage.putBlob{value: upfrontPayment}(_htmlFileKey, 0, _htmlFileSize);
        ethStorage.putBlob{value: upfrontPayment}(_cssFileKey, 1, _cssFileSize);
        ethStorage.putBlob{value: upfrontPayment}(_jsFileKey, 2, _jsFileSize);

        BlogFrontendVersion memory newFrontend = BlogFrontendVersion(FrontendStorageMode.EthStorage, _htmlFileKey, _cssFileKey, _jsFileKey, _infos);
        frontendVersions.push(newFrontend);
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