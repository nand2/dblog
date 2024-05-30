// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { File } from "ethfs/FileStore.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { Strings } from "./library/Strings.sol";
import { TestEthStorageContractKZG } from "storage-contracts-v1/TestEthStorageContractKZG.sol";

import "./DBlog.sol";
import "./interfaces/IDecentralizedApp.sol";
import "./interfaces/FileInfos.sol";
import "./interfaces/IStorageBackend.sol";
import "./DBlogFrontendLibrary.sol";
import "./DBlogFactory.sol";

contract DBlogFrontend is IDecentralizedApp {
    // The data of this blog frontend
    DBlog public blog;

    // Blog frontend versions are stored in DBlogFrontendLibrary
    // By default the frontend version used is chosen by the DblogFactory owner
    // But you can choose to override it and use a specific version
    // Useful if you don't want the new default frontend update to be applied to your blog
    bool public useNonDefaultFrontend;
    uint public overridenFrontendIndex;


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

    function blogFrontendVersion() public view returns (FrontendFilesSet2 memory) {
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
        FrontendFilesSet2 memory frontendVersion = blogFrontendVersion();

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
        for(uint i = 0; i < frontendVersion.files.length; i++) {
            if(Strings.compare(filePath, frontendVersion.files[i].filePath)) {
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

                IStorageBackend storageBackend = blog.factory().storageBackends(frontendVersion.storageBackendIndex);
                (bytes memory data, uint nextChunkId) = storageBackend.read(address(frontendLibrary), frontendVersion.files[i].contentKey, chunkIndex);
                body = string(data);
                statusCode = 200;

                uint headersCount = 2;
                if(nextChunkId > 0) {
                    headersCount = 3;
                }
                headers = new KeyValue[](headersCount);
                headers[0].key = "Content-type";
                headers[0].value = frontendVersion.files[i].contentType;
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

        // blogAddress.json : it exposes the addess of the blog
        if(resource.length == 1 && Strings.compare(resource[0], "blogAddress.json")) {
            uint chainid = block.chainid;
            // Manual JSON serialization, safe with the vars we encode
            body = string.concat("{\"address\":\"", Strings.toHexString(address(blog)), "\", \"frontendAddress\":\"", Strings.toHexString(address(this)), "\", \"chainId\":", Strings.toString(chainid), "}");
            statusCode = 200;
            headers = new KeyValue[](1);
            headers[0].key = "Content-type";
            headers[0].value = "application/json";
            return (statusCode, body, headers);
        }

        // /uploads/<uploadedFile>
        if(resource.length == 2 && Strings.compare(resource[0], "uploads")) {
            string memory uploadedFileName = resource[1];
            try blog.getUploadedFileByName(uploadedFileName) returns (FileInfosWithStorageBackend memory uploadedFile, uint fileIndex) {

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

                (bytes memory data, uint nextChunkId) = blog.getUploadedFileContents(fileIndex, chunkIndex);
                body = string(data);
                statusCode = 200;

                uint headersCount = 1;
                if(nextChunkId > 0) {
                    headersCount = 2;
                }
                headers = new KeyValue[](headersCount);
                headers[0].key = "Content-type";
                headers[0].value = uploadedFile.fileInfos.contentType;
                // If there is more chunk remaining, add a pointer to the next chunk
                if(nextChunkId > 0) {
                    headers[1].key = "web3-next-chunk";
                    headers[1].value = string.concat("/uploads/", resource[1], "?chunk=", Strings.toString(nextChunkId));
                }
                
                return (statusCode, body, headers);
            } catch {
                // Filename not found in uploaded files. Go to the next lookups
            }
        }
        
        statusCode = 404;
    }

}
