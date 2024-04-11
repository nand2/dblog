// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { File } from "ethfs/FileStore.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { Strings } from "./library/Strings.sol";
import { TestEthStorageContractKZG } from "storage-contracts-v1/TestEthStorageContractKZG.sol";

import "./DBlog.sol";
import "./interfaces/IDecentralizedApp.sol";
import "./DBlogFrontendLibrary.sol";
import "./DBlogFactory.sol";

contract DBlogFrontend is IDecentralizedApp {
    // The data of this blog frontend
    DBlog public blog;

    // Blog frontend versions are stored in DBlogFrontendLibrary
    // By default the frontend version used is chosen by the DblogFactory owner
    // But you can choose to override it and use a specific version
    // Useful if you don't want the new default frontend update to be applied to your blog
    bool useNonDefaultFrontend;
    uint overridenFrontendIndex;


    modifier onlyBlogOwner() {
        require(msg.sender == blog.owner(), "Not blog owner");
        _;
    }

    function initialize(DBlog _blog) public {
        require(address(blog) == address(0), "Already initialized");

        blog = _blog;
    }

    function useSpecificBlogFrontend(uint _index) public onlyBlogOwner {
        require(_index < blog.factory().blogFrontendLibrary().getFrontendVersionCount(), "Index out of bounds");
        useNonDefaultFrontend = true;
        overridenFrontendIndex = _index;
    }

    function useDefaultBlogFrontend() public onlyBlogOwner {
        useNonDefaultFrontend = false;
    }

    // Web3:// mode selection
    function resolveMode() external pure returns (bytes32) {
        return "5219";
    }

    // Implementation for the ERC-5219 mode
    function request(string[] memory resource, KeyValue[] memory params) external view returns (uint statusCode, string memory body, KeyValue[] memory headers) {
        DBlogFrontendLibrary frontendLibrary = blog.factory().blogFrontendLibrary();
        BlogFrontendVersion memory frontend = frontendLibrary.getDefaultFrontend();
        if(useNonDefaultFrontend) {
            frontend = frontendLibrary.getFrontendVersion(overridenFrontendIndex);
        }

        // Frontpage or single-page javascript app pages (#/page/1, #/page/2, etc.)
        // At the moment, proper SPA routing in JS with history.pushState() is broken (due 
        // to bad web3:// URL parsing in the browser)
        if(resource.length == 0 || Strings.compare(resource[0], "#")) {
            if(frontend.storageMode == FrontendStorageMode.SSTORE2) {
                File memory file = abi.decode(SSTORE2.read(address(uint160(uint256(frontend.htmlFile)))), (File));
                body = file.read();
            }
            else if(frontend.storageMode == FrontendStorageMode.EthStorage) {
                body = string(frontendLibrary.getEthStorageFileContents(frontend.htmlFile));
            }
            statusCode = 200;
            headers = new KeyValue[](2);
            headers[0].key = "Content-type";
            headers[0].value = "text/html";
            headers[1].key = "Content-Encoding";
            headers[1].value = "gzip";
        }
        // blogAddress.json : it exposes the addess of the blog
        else if(resource.length == 1 && Strings.compare(resource[0], "blogAddress.json")) {
            uint chainid = block.chainid;
            // Special case: Sepolia chain id 11155111 is > 65k, which breaks URL parsing in EVM browser
            // As a temporary measure, we will test Sepolia with a fake chain id of 11155
            if(chainid == 11155111) {
                chainid = 11155;
            }
            // Manual JSON serialization, safe with the vars we encode
            body = string.concat("{\"address\":\"", Strings.toHexString(address(blog)), "\", \"chainId\":", Strings.toString(chainid), "}");
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
                    body = string(frontendLibrary.getEthStorageFileContents(frontend.cssFile));
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
                    body = string(frontendLibrary.getEthStorageFileContents(frontend.jsFile));
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
