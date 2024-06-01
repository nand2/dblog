// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { File } from "ethfs/FileStore.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { Strings } from "./library/Strings.sol";

import "./DBlogFactory.sol";
import "./StorageBackendEthStorage.sol";
import "./interfaces/IDecentralizedApp.sol";
import "./interfaces/FileInfos.sol";
import "./interfaces/IFrontendLibrary.sol";
import "./interfaces/IStorageBackend.sol";

contract DBlogFactoryFrontend is IDecentralizedApp, IFrontendLibrary {
    DBlogFactory public blogFactory;

    FrontendFilesSet2[] public frontendVersions;
    uint256 public defaultFrontendIndex;

    uint256 public ethStorageLastUsedKey = 0;


    modifier onlyFactoryOrFactoryOwner() {
        require(msg.sender == address(blogFactory) || msg.sender == blogFactory.owner(), string.concat("Not owner", Strings.toHexString(msg.sender)));
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

    function createFile(uint16 storageBackendIndex, bytes memory data, uint dataLength) public payable onlyFactoryOrFactoryOwner returns (uint contentKey) {
        IStorageBackend storageBackend = blogFactory.storageBackends(storageBackendIndex);

        uint fundsUsed;
        (contentKey, fundsUsed) = storageBackend.create(data, dataLength);

        // Send back remaining funds sent by the caller
        if(msg.value - fundsUsed > 0) {
            payable(msg.sender).transfer(msg.value - fundsUsed);
        }

        return contentKey;
    }

    function appendToFile(uint16 storageBackendIndex, uint256 fileIndex, bytes memory data) public payable onlyFactoryOrFactoryOwner {
        IStorageBackend storageBackend = blogFactory.storageBackends(storageBackendIndex);

        uint fundsUsed = storageBackend.append(fileIndex, data);

        // Send back remaining funds sent by the caller
        if(msg.value - fundsUsed > 0) {
            payable(msg.sender).transfer(msg.value - fundsUsed);
        }
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
        StorageBackendEthStorage storageBackendEthStorage = StorageBackendEthStorage(address(blogFactory.getStorageBackendByName("EthStorage")));

        return storageBackendEthStorage.blobStorageUpfrontCost();
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

    function getFrontendVersion(uint256 _index) public view returns (FrontendFilesSet2 memory) {
        require(_index < frontendVersions.length, "Index out of bounds");
        return frontendVersions[_index];
    }

    // If a new frontend is borked, go back in history
    function setDefaultFrontend(uint256 _index) public onlyFactoryOrFactoryOwner {
        require(_index < frontendVersions.length, "Index out of bounds");
        defaultFrontendIndex = _index;
    }

    function getDefaultFrontend() public view returns (FrontendFilesSet2 memory) {
        return frontendVersions[defaultFrontendIndex];
    }


    // Indicate we are serving a website with the resource request mode
    function resolveMode() external pure returns (bytes32) {
        return "5219";
    }

    function frontendVersion() public view returns (FrontendFilesSet2 memory) {
        return getDefaultFrontend();
    }

    // web3:// protocol
    // Implementation for the ERC-5219 mode
    function request(string[] memory resource, KeyValue[] memory params) external view returns (uint statusCode, string memory body, KeyValue[] memory headers) {
        FrontendFilesSet2 memory frontend = frontendVersion();

        // Compute the filePath of the requested resource
        string memory filePath = "";
        // Root path requested("/")? Serve the index.html
        // We handle frontpage or single-page javascript app pages (#/page/1, #/page/2, etc.)
        // -> At the moment, in EVM browser, proper SPA routing in JS with history.pushState() 
        // is broken (due to bad web3:// URL parsing in the browser)
        // Todo: clarify the behavior of the "#" character in resourceRequest mode, this 
        // character is not forwarded to the web server in HTTP
        if(resource.length == 0 || Strings.compare(resource[0], "#")) {
            filePath = "index.html";
        }
        else {
            for(uint i = 0; i < resource.length; i++) {
                if(i > 0) {
                    filePath = string.concat(filePath, "/");
                }
                filePath = string.concat(filePath, resource[i]);
            }
        }

        // Search for the requested resource in our static file list
        for(uint i = 0; i < frontend.files.length; i++) {
            if(Strings.compare(filePath, frontend.files[i].filePath)) {
                // web3:// chunk feature : if the file is big, we will send the file
                // in chunks
                // Determine the requested chunk
                uint chunkIndex = 0;
                for(uint j = 0; j < params.length; j++) {
                    if(Strings.compare(params[j].key, "chunk")) {
                        chunkIndex = Strings.stringToUint(params[j].value);
                        break;
                    }
                }

                // if(frontend.storageMode == FileStorageMode.SSTORE2) {
                //     File memory file = abi.decode(SSTORE2.read(address(uint160(uint256(frontend.files[i].contentKeys[0])))), (File));
                //     body = file.read();
                // }
                // else if(frontend.storageMode == FileStorageMode.EthStorage) {
                //     bytes memory content;
                //     for(uint j = 0; j < frontend.files[i].contentKeys.length; j++) {
                //         content = bytes.concat(content, ethStorage.get(
                //             frontend.files[i].contentKeys[j], 
                //             DecentralizedKV.DecodeType.PaddingPer31Bytes, 
                //             0, 
                //             ethStorage.size(frontend.files[i].contentKeys[j])));
                //     }
                //     body = string(content);
                // }

                IStorageBackend storageBackend = blogFactory.storageBackends(frontend.storageBackendIndex);
                (bytes memory data, uint nextChunkId) = storageBackend.read(address(this), frontend.files[i].contentKey, chunkIndex);
                body = string(data);
                statusCode = 200;

                uint headersCount = 2;
                if(nextChunkId > 0) {
                    headersCount = 3;
                }
                headers = new KeyValue[](headersCount);
                headers[0].key = "Content-type";
                headers[0].value = frontend.files[i].contentType;
                headers[1].key = "Content-Encoding";
                headers[1].value = "gzip";
                // If there is more chunk remaining, add a pointer to the next chunk
                if(nextChunkId > 0) {
                    headers[2].key = "web3-next-chunk";
                    headers[2].value = string.concat("/", filePath, "?chunk=", Strings.toString(nextChunkId));
                }

                return (statusCode, body, headers);
            }
        }

        // blogFactoryAddress.json : it exposes the addess of the blog factory
        if(resource.length == 1 && Strings.compare(resource[0], "blogFactoryAddress.json")) {
            uint chainid = block.chainid;
            // Special case: Sepolia chain id 11155111 is > 65k, which breaks URL parsing in EVM browser
            // As a temporary measure, we will test Sepolia with a fake chain id of 11155
            // if(chainid == 11155111) {
            //     chainid = 11155;
            // }
            // Manual JSON serialization, safe with the vars we encode
            body = string.concat("{\"address\":\"", Strings.toHexString(address(blogFactory)), "\", \"chainId\":", Strings.toString(chainid), "}");
            statusCode = 200;
            headers = new KeyValue[](1);
            headers[0].key = "Content-type";
            headers[0].value = "application/json";
            return (statusCode, body, headers);
        }
        
        statusCode = 404;
    }

}
