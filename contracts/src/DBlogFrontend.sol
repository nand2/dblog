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

    function useSpecificBlogFrontendVersion(uint _index) public onlyBlogOwner {
        require(_index < blog.factory().blogFrontendLibrary().getFrontendVersionCount(), "Index out of bounds");
        useNonDefaultFrontend = true;
        overridenFrontendIndex = _index;
    }

    function useDefaultBlogFrontendVersion() public onlyBlogOwner {
        useNonDefaultFrontend = false;
    }

    function blogFrontendVersion() public view returns (BlogFrontendVersion memory) {
        DBlogFrontendLibrary frontendLibrary = blog.factory().blogFrontendLibrary();
        if(useNonDefaultFrontend) {
            return frontendLibrary.getFrontendVersion(overridenFrontendIndex);
        }
        return frontendLibrary.getDefaultFrontend();
    }

    // Web3:// mode selection
    function resolveMode() external pure returns (bytes32) {
        return "5219";
    }

    // Implementation for the ERC-5219 mode
    function request(string[] memory resource, KeyValue[] memory params) external view returns (uint statusCode, string memory body, KeyValue[] memory headers) {
        DBlogFrontendLibrary frontendLibrary = blog.factory().blogFrontendLibrary();
        BlogFrontendVersion memory frontendVersion = blogFrontendVersion();

        // Compute the filePath of the requested resource
        string memory filePath = "";
        // Root path requested("/")? Serve the index.html
        // Frontpage or single-page javascript app pages (#/page/1, #/page/2, etc.)
        // At the moment, proper SPA routing in JS with history.pushState() is broken (due 
        // to bad web3:// URL parsing in the browser)
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

        // Search for the requested resource
        for(uint i = 0; i < frontendVersion.files.length; i++) {
            if(Strings.compare(filePath, frontendVersion.files[i].filePath)) {
                if(frontendVersion.storageMode == FrontendStorageMode.SSTORE2) {
                    File memory file = abi.decode(SSTORE2.read(address(uint160(uint256(frontendVersion.files[i].contentKeys[0])))), (File));
                    body = file.read();
                }
                else if(frontendVersion.storageMode == FrontendStorageMode.EthStorage) {
                    bytes memory content;
                    for(uint j = 0; j < frontendVersion.files[i].contentKeys.length; j++) {
                        content = bytes.concat(content, frontendLibrary.getEthStorageFileContents(frontendVersion.files[i].contentKeys[j]));
                    }
                    body = string(content);
                }
                statusCode = 200;
                headers = new KeyValue[](2);
                headers[0].key = "Content-type";
                headers[0].value = frontendVersion.files[i].contentType;
                headers[1].key = "Content-Encoding";
                headers[1].value = "gzip";
                return (statusCode, body, headers);
            }
        }

        // blogAddress.json : it exposes the addess of the blog
        if(resource.length == 1 && Strings.compare(resource[0], "blogAddress.json")) {
            uint chainid = block.chainid;
            // Special case: Sepolia chain id 11155111 is > 65k, which breaks URL parsing in EVM browser
            // As a temporary measure, we will test Sepolia with a fake chain id of 11155
            // if(chainid == 11155111) {
            //     chainid = 11155;
            // }
            // Manual JSON serialization, safe with the vars we encode
            body = string.concat("{\"address\":\"", Strings.toHexString(address(blog)), "\", \"chainId\":", Strings.toString(chainid), "}");
            statusCode = 200;
            headers = new KeyValue[](1);
            headers[0].key = "Content-type";
            headers[0].value = "application/json";
        }
        else {
            statusCode = 404;
        }
    }

}
