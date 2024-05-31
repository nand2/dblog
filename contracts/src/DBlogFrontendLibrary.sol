// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestEthStorageContractKZG } from "storage-contracts-v1/TestEthStorageContractKZG.sol";
import { DecentralizedKV } from "storage-contracts-v1/DecentralizedKV.sol";

import "./interfaces/FileInfos.sol";
import "./interfaces/IFrontendLibrary.sol";
import "./DBlogFactory.sol";


contract DBlogFrontendLibrary is IFrontendLibrary {
    DBlogFactory public blogFactory;

    FrontendFilesSet2[] public frontendVersions;
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

    function getEthFsFileStore() external view override returns (FileStore) {
        return blogFactory.ethFsFileStore();
    }

    function getStorageBackendIndexByName(string memory name) public view returns (uint16 index) {
        return blogFactory.getStorageBackendIndexByName(name);
    }
    
    function getStorageBackend(uint16 index) public view returns (IStorageBackend storageBackend) {
        return blogFactory.storageBackends(index);
    }

    function createFile(uint16 storageBackendIndex, bytes memory data, uint dataLength) public onlyFactoryOrFactoryOwner returns (uint contentKey) {
        IStorageBackend storageBackend = blogFactory.storageBackends(storageBackendIndex);
        contentKey = storageBackend.create(data, dataLength);

        return contentKey;
    }

    function appendToFile(uint16 storageBackendIndex, uint256 fileIndex, bytes memory data) public onlyFactoryOrFactoryOwner {
        IStorageBackend storageBackend = blogFactory.storageBackends(storageBackendIndex);
        storageBackend.append(fileIndex, data);
    }

    function addFrontendVersion(uint16 storageBackendIndex, FileInfos2[] memory files, string memory _infos) public onlyFactoryOrFactoryOwner {
        // Previous frontend version must be locked
        if(frontendVersions.length > 0) {
            require(frontendVersions[frontendVersions.length - 1].locked, "Previous frontend version must be locked");
        }

        frontendVersions.push();
        FrontendFilesSet2 storage newFrontend = frontendVersions[frontendVersions.length - 1];
        newFrontend.storageBackendIndex = storageBackendIndex;
        for(uint i = 0; i < files.length; i++) {
            newFrontend.files.push(files[i]);
        }
        newFrontend.infos = _infos;
        defaultFrontendIndex = frontendVersions.length - 1;
    }

    function addFilesToCurrentFrontendVersion(FileInfos2[] memory files) public onlyFactoryOrFactoryOwner {
        FrontendFilesSet2 storage frontend = frontendVersions[frontendVersions.length - 1];
        require(!frontend.locked, "Frontend version is locked");

        for(uint i = 0; i < files.length; i++) {
            frontend.files.push(files[i]);
        }
    }

    function addSStore2FrontendVersion(FileInfos[] memory files, string memory _infos) public onlyFactoryOrFactoryOwner {
        // // Previous frontend version must be locked
        // if(frontendVersions.length > 0) {
        //     require(frontendVersions[frontendVersions.length - 1].locked, "Previous frontend version must be locked");
        // }

        // // Weird insertion into frontendVersions due to :
        // // Error: Unimplemented feature (/solidity/libsolidity/codegen/ArrayUtils.cpp:227):Copying of type struct FileInfos memory[] memory to storage not yet supported.
        // frontendVersions.push();
        // FrontendFilesSet storage newFrontend = frontendVersions[frontendVersions.length - 1];
        // newFrontend.storageMode = FileStorageMode.SSTORE2;
        // for(uint i = 0; i < files.length; i++) {
        //     newFrontend.files.push(files[i]);
        // }
        // newFrontend.infos = _infos;
        // defaultFrontendIndex = frontendVersions.length - 1;
    }

    function addFilesToCurrentSStore2FrontendVersion(FileInfos[] memory files) public onlyFactoryOrFactoryOwner {
        // FrontendFilesSet storage frontend = frontendVersions[frontendVersions.length - 1];
        // require(!frontend.locked, "Frontend version is locked");
        // require(frontend.storageMode == FileStorageMode.SSTORE2, "Not SSTORE2 mode");

        // for(uint i = 0; i < files.length; i++) {
        //     frontend.files.push(files[i]);
        // }
    }


    function getEthStorageUpfrontPayment() external view returns (uint256) {
        return blogFactory.ethStorage().upfrontPayment();
    }


    function addEthStorageFrontendVersion(EthStorageFileUploadInfos[] memory files, string memory _infos) public payable onlyFactoryOrFactoryOwner {
        // TestEthStorageContractKZG ethStorage = blogFactory.ethStorage();
        // uint256 upfrontPayment = this.getEthStorageUpfrontPayment();

        // // Previous frontend version must be locked
        // if(frontendVersions.length > 0) {
        //     require(frontendVersions[frontendVersions.length - 1].locked, "Previous frontend version must be locked");
        // }

        // // Weird insertion into frontendVersions due to :
        // // Error: Unimplemented feature (/solidity/libsolidity/codegen/ArrayUtils.cpp:227):Copying of type struct FileInfos memory[] memory to storage not yet supported.
        // frontendVersions.push();
        // FrontendFilesSet storage newFrontend = frontendVersions[frontendVersions.length - 1];
        // newFrontend.storageMode = FileStorageMode.EthStorage;
        // for(uint i = 0; i < files.length; i++) {
        //     bytes32[] memory ethStorageKeys = new bytes32[](files[i].blobIndexes.length);
        //     for(uint j = 0; j < files[i].blobIndexes.length; j++) {
        //         ethStorageLastUsedKey++;
        //         ethStorageKeys[j] = bytes32(ethStorageLastUsedKey);
        //         // Upload part of the file
        //         // ethStorageKeys[j] is a key we choose, and it will be mixed with msg.sender
        //         ethStorage.putBlob{value: upfrontPayment}(ethStorageKeys[j], files[i].blobIndexes[j], files[i].blobDataSizes[j]);
        //     }
        //     newFrontend.files.push(FileInfos({
        //         filePath: files[i].filePath,
        //         contentType: files[i].contentType,
        //         contentKeys: ethStorageKeys
        //     }));
        // }
        // newFrontend.infos = _infos;
        // defaultFrontendIndex = frontendVersions.length - 1;
    }

    // Add extra files to the latest unlocked EthStorage frontend version
    function addFilesToLatestEthStorageFrontendVersion(EthStorageFileUploadInfos[] memory files) public payable onlyFactoryOrFactoryOwner {
        // TestEthStorageContractKZG ethStorage = blogFactory.ethStorage();
        // uint256 upfrontPayment = this.getEthStorageUpfrontPayment();
        // uint256 fundsUsed = 0;

        // FrontendFilesSet storage frontend = frontendVersions[frontendVersions.length - 1];
        // require(!frontend.locked, "Frontend version is locked");
        // require(frontend.storageMode == FileStorageMode.EthStorage, "Not EthStorage mode");

        // for(uint i = 0; i < files.length; i++) {
        //     bytes32[] memory ethStorageKeys = new bytes32[](files[i].blobIndexes.length);
        //     for(uint j = 0; j < files[i].blobIndexes.length; j++) {
        //         ethStorageLastUsedKey++;
        //         ethStorageKeys[j] = bytes32(ethStorageLastUsedKey);

        //         uint payment = 0;
        //         if(ethStorage.exist(ethStorageKeys[j]) == false) {
        //             payment = upfrontPayment;
        //         }

        //         // Upload part of the file
        //         // ethStorageKeys[j] is a key we choose, and it will be mixed with msg.sender
        //         ethStorage.putBlob{value: payment}(ethStorageKeys[j], files[i].blobIndexes[j], files[i].blobDataSizes[j]);
        //         fundsUsed += payment;
        //     }
        //     frontend.files.push(FileInfos({
        //         filePath: files[i].filePath,
        //         contentType: files[i].contentType,
        //         contentKeys: ethStorageKeys
        //     }));
        // }

        // // Send back remaining funds sent by the caller
        // if(msg.value - fundsUsed > 0) {
        //     payable(msg.sender).transfer(msg.value - fundsUsed);
        // }
    }

    // Get the count of frontend versions
    function frontendVersionsCount() public view returns (uint256) {
        return frontendVersions.length;
    }

    // Lock the latest frontend version
    function lockLatestFrontendVersion() public onlyFactoryOrFactoryOwner {
        FrontendFilesSet2 storage frontend = frontendVersions[frontendVersions.length - 1];
        require(!frontend.locked, "Already locked");
        frontend.locked = true;
    }

    // Empty the files of the latest frontend version, if not locked yet
    // This is useful if we want to deploy a small fix to a frontend version
    // In the case of EthStorage, we don't need to repay the upfront payment
    function resetLatestFrontendVersion() public onlyFactoryOrFactoryOwner {
        FrontendFilesSet2 storage frontend = frontendVersions[frontendVersions.length - 1];
        require(!frontend.locked, "Already locked");

        // // If EthStorage: move back the pointer of last used key, so that we can
        // // reuse them for free
        // if(frontend.storageMode == FileStorageMode.EthStorage) {
        //     for(uint i = 0; i < frontend.files.length; i++) {
        //         ethStorageLastUsedKey -= frontend.files[i].contentKeys.length;
        //     }
        // }
        // Clear the file list
        while(frontend.files.length > 0) {
            frontend.files.pop();
        }
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

    function getFrontendVersion(uint256 _index) public view returns (FrontendFilesSet2 memory) {
        require(_index < frontendVersions.length, "Index out of bounds");
        return frontendVersions[_index];
    }

    function setDefaultFrontend(uint256 _index) public onlyFactoryOrFactoryOwner {
        require(_index < frontendVersions.length, "Index out of bounds");
        defaultFrontendIndex = _index;
    }

    function getDefaultFrontend() public view returns (FrontendFilesSet2 memory) {
        return frontendVersions[defaultFrontendIndex];
    }

    function getFrontendVersionCount() public view returns (uint256) {
        return frontendVersions.length;
    }
}