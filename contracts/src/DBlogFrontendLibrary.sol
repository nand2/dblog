// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/FileInfos.sol";
import "./interfaces/IFrontendLibrary.sol";
import "./DBlogFactory.sol";
import "./StorageBackendEthStorage.sol";


contract DBlogFrontendLibrary is IFrontendLibrary {
    DBlogFactory public blogFactory;

    FrontendFilesSet2[] public frontendVersions;
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

    function getStorageBackendIndexByName(string memory name) public view returns (uint16 index) {
        return blogFactory.getStorageBackendIndexByName(name);
    }
    
    function getStorageBackend(uint16 index) public view returns (IStorageBackend storageBackend) {
        return blogFactory.storageBackends(index);
    }

    function addFrontendVersion(uint16 storageBackendIndex, string memory _infos) public onlyFactoryOrFactoryOwner {
        // Previous frontend version must be locked
        if(frontendVersions.length > 0) {
            require(frontendVersions[frontendVersions.length - 1].locked, "Previous frontend version must be locked");
        }

        frontendVersions.push();
        FrontendFilesSet2 storage newFrontend = frontendVersions[frontendVersions.length - 1];
        newFrontend.storageBackendIndex = storageBackendIndex;
        newFrontend.infos = _infos;
        defaultFrontendIndex = frontendVersions.length - 1;
    }

    function addFilesToCurrentFrontendVersion(FileUploadInfos[] memory fileUploadInfos) public payable onlyFactoryOrFactoryOwner {
        FrontendFilesSet2 storage frontend = frontendVersions[frontendVersions.length - 1];
        require(!frontend.locked, "Frontend version is locked");

        IStorageBackend storageBackend = blogFactory.storageBackends(frontend.storageBackendIndex);

        uint totalFundsUsed = 0;
        for(uint i = 0; i < fileUploadInfos.length; i++) {
            (uint contentKey, uint fundsUsed) = storageBackend.create(fileUploadInfos[i].data, fileUploadInfos[i].fileSize);
            totalFundsUsed += fundsUsed;

            FileInfos2 memory fileInfos = FileInfos2({
                contentKey: contentKey,
                filePath: fileUploadInfos[i].filePath,
                contentType: fileUploadInfos[i].contentType
            });
            frontend.files.push(fileInfos);
        }

        // Send back remaining funds sent by the caller
        if(msg.value - totalFundsUsed > 0) {
            payable(msg.sender).transfer(msg.value - totalFundsUsed);
        }
    }

    function appendToFileInCurrentFrontendVersion(uint256 fileIndex, bytes memory data) public payable onlyFactoryOrFactoryOwner {
        FrontendFilesSet2 storage frontend = frontendVersions[frontendVersions.length - 1];
        require(!frontend.locked, "Frontend version is locked");

        IStorageBackend storageBackend = blogFactory.storageBackends(frontend.storageBackendIndex);

        uint fundsUsed = storageBackend.append(frontend.files[fileIndex].contentKey, data);

        // Send back remaining funds sent by the caller
        if(msg.value - fundsUsed > 0) {
            payable(msg.sender).transfer(msg.value - fundsUsed);
        }
    }

    function getEthStorageUpfrontPayment() external view returns (uint256) {
        StorageBackendEthStorage storageBackendEthStorage = StorageBackendEthStorage(address(blogFactory.getStorageBackendByName("EthStorage")));

        return storageBackendEthStorage.blobStorageUpfrontCost();
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

        IStorageBackend storageBackend = blogFactory.storageBackends(frontend.storageBackendIndex);

        // Clear the file list
        while(frontend.files.length > 0) {
            storageBackend.remove(frontend.files[frontend.files.length - 1].contentKey);
            frontend.files.pop();
        }
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