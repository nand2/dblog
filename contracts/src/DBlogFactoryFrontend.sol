// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { File } from "ethfs/FileStore.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { Strings } from "./library/Strings.sol";
import { DecentralizedKV } from "storage-contracts-v1/DecentralizedKV.sol";
import { TestEthStorageContractKZG } from "storage-contracts-v1/TestEthStorageContractKZG.sol";

import "./DBlogFactory.sol";
import "./interfaces/IDecentralizedApp.sol";

contract DBlogFactoryFrontend is IDecentralizedApp {
    DBlogFactory public blogFactory;

    enum FrontendStorageMode {
        SSTORE2, // Store on the ethereum network itself using SSTORE2
        EthStorage // Store with the EthStorage project
    }
    // A version of a frontend, containing a single HTML, CSS and JS file.
    struct FrontendVersion {
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
    FrontendVersion[] public frontendVersions;
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
        FrontendVersion memory newFrontend = FrontendVersion(
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

        FrontendVersion memory newFrontend = FrontendVersion(FrontendStorageMode.EthStorage, _htmlFileKey, _cssFileKey, _jsFileKey, _infos);
        frontendVersions.push(newFrontend);
        defaultFrontendIndex = frontendVersions.length - 1;
    }

    // If a new frontend is borked, go back in history
    function setDefaultFrontend(uint256 _index) public onlyFactoryOrFactoryOwner {
        require(_index < frontendVersions.length, "Index out of bounds");
        defaultFrontendIndex = _index;
    }


    // Indicate we are serving a website with the resource request mode
    function resolveMode() external pure returns (bytes32) {
        return "5219";
    }

    // Implementation for the ERC-5219 mode
    function request(string[] memory resource, KeyValue[] memory params) external view returns (uint statusCode, string memory body, KeyValue[] memory headers) {
        FrontendVersion memory frontend = frontendVersions[defaultFrontendIndex];
        TestEthStorageContractKZG ethStorage = blogFactory.ethStorage();

        // Frontpage
        if(resource.length == 0) {
            if(frontend.storageMode == FrontendStorageMode.SSTORE2) {
                File memory file = abi.decode(SSTORE2.read(address(uint160(uint256(frontend.htmlFile)))), (File));
                body = file.read();
            }
            else if(frontend.storageMode == FrontendStorageMode.EthStorage) {
                body = string(ethStorage.get(
                    frontend.htmlFile, 
                    DecentralizedKV.DecodeType.PaddingPer31Bytes, 
                    0, 
                    ethStorage.size(frontend.htmlFile)));
            }
            statusCode = 200;
            headers = new KeyValue[](2);
            headers[0].key = "Content-type";
            headers[0].value = "text/html";
            headers[1].key = "Content-Encoding";
            headers[1].value = "gzip";
        }
        // blogFactoryAddress.json : it exposes the addess of the blog factory
        else if(resource.length == 1 && Strings.compare(resource[0], "blogFactoryAddress.json")) {
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
        }
        // /assets/[assetName]
        else if(resource.length == 2 && Strings.compare(resource[0], "assets")) {
            string memory assetName = resource[1];
            uint256 assetNameLen = Strings.strlen(assetName);

            // If the last 4 characters are ".css"
            if(Strings.strlen(assetName) > 4 && 
                Strings.compare(Strings.substring(assetName, assetNameLen - 4, assetNameLen), ".css")) {
                if(frontend.storageMode == FrontendStorageMode.SSTORE2) {
                    File memory file = abi.decode(SSTORE2.read(address(uint160(uint256(frontend.cssFile)))), (File));
                    body = file.read();
                }
                else if(frontend.storageMode == FrontendStorageMode.EthStorage) {
                    body = string(ethStorage.get(
                        frontend.cssFile, 
                        DecentralizedKV.DecodeType.PaddingPer31Bytes, 
                        0, 
                        ethStorage.size(frontend.cssFile)));
                }
                statusCode = 200;
                headers = new KeyValue[](2);
                headers[0].key = "Content-type";
                headers[0].value = "text/css";
                headers[1].key = "Content-Encoding";
                headers[1].value = "gzip";
            }
            else if(Strings.strlen(assetName) > 3 && 
                Strings.compare(Strings.substring(assetName, assetNameLen - 3, assetNameLen), ".js")) {
                if(frontend.storageMode == FrontendStorageMode.SSTORE2) {
                    File memory file = abi.decode(SSTORE2.read(address(uint160(uint256(frontend.jsFile)))), (File));
                    body = file.read();
                }
                else if(frontend.storageMode == FrontendStorageMode.EthStorage) {
                    body = string(ethStorage.get(
                        frontend.jsFile, 
                        DecentralizedKV.DecodeType.PaddingPer31Bytes, 
                        0, 
                        ethStorage.size(frontend.jsFile)));
                }
                statusCode = 200;
                headers = new KeyValue[](2);
                headers[0].key = "Content-type";
                headers[0].value = "text/javascript";
                headers[1].key = "Content-Encoding";
                headers[1].value = "gzip";
            }
            else {
                statusCode = 404;
            }
        }
        else {
            statusCode = 404;
        }
    }

}
