// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlog.sol";
import "./interfaces/IDecentralizedApp.sol";

contract DBlogFrontend is IDecentralizedApp {
    DBlog public blog;

    struct Frontend {
        string title;
        mapping(string => string) files;
    }
    Frontend[] public frontends;
    Frontend public frontend;

    function initialize(DBlog _blog) public {
        blog = _blog;
    }

    function resolveMode() external pure returns (bytes32) {
        return "5219";
    }

    // Implementation for the ERC-5219 mode
    function request(string[] memory resource, KeyValue[] memory params) external view returns (uint statusCode, string memory body, KeyValue[] memory headers) {
        // FrontendVersion memory frontend = frontendVersions[defaultFrontendIndex];

        statusCode = 200;
        body = "Hello, world!";

        // // Frontpage
        // if(resource.length == 0) {
        //     File memory file = abi.decode(SSTORE2.read(frontend.htmlFile), (File));
        //     body = file.read();
        //     statusCode = 200;
        //     headers = new KeyValue[](2);
        //     headers[0].key = "Content-type";
        //     headers[0].value = "text/html";
        //     headers[1].key = "Content-Encoding";
        //     headers[1].value = "gzip";
        // }
        // // blogFactoryAddress.json : it exposes the addess of the blog factory
        // else if(resource.length == 1 && Strings.compare(resource[0], "blogFactoryAddress.json")) {
        //     // Manual JSON serialization, safe with the vars we encode
        //     body = string.concat("{\"address\":\"", Strings.toHexString(address(blogFactory)), "\", \"chainId\":", Strings.toString(block.chainid), "}");
        //     statusCode = 200;
        //     headers = new KeyValue[](1);
        //     headers[0].key = "Content-type";
        //     headers[0].value = "application/json";
        // }
        // // /assets/[assetName]
        // else if(resource.length == 2 && Strings.compare(resource[0], "assets")) {
        //     string memory assetName = resource[1];
        //     uint256 assetNameLen = Strings.strlen(assetName);

        //     // If the last 4 characters are ".css"
        //     if(Strings.strlen(assetName) > 4 && 
        //         Strings.compare(Strings.substring(assetName, assetNameLen - 4, assetNameLen), ".css")) {
        //         File memory file = abi.decode(SSTORE2.read(frontend.cssFile), (File));
        //         body = file.read();
        //         statusCode = 200;
        //         headers = new KeyValue[](2);
        //         headers[0].key = "Content-type";
        //         headers[0].value = "text/css";
        //         headers[1].key = "Content-Encoding";
        //         headers[1].value = "gzip";
        //     }
        //     else if(Strings.strlen(assetName) > 3 && 
        //         Strings.compare(Strings.substring(assetName, assetNameLen - 3, assetNameLen), ".js")) {
        //         File memory file = abi.decode(SSTORE2.read(frontend.jsFile), (File));
        //         body = file.read();
        //         statusCode = 200;
        //         headers = new KeyValue[](2);
        //         headers[0].key = "Content-type";
        //         headers[0].value = "text/javascript";
        //         headers[1].key = "Content-Encoding";
        //         headers[1].value = "gzip";
        //     }
        //     else {
        //         statusCode = 404;
        //     }
        // }
        // else {
        //     statusCode = 404;
        // }


        // // /index/[uint]
        // else if(resource.length >= 1 && resource.length <= 2 && Strings.compare(resource[0], "index")) {
        //     uint page = 1;
        //     if(resource.length == 2) {
        //         page = ToString.stringToUint(resource[1]);
        //     }
        //     if(page == 0) {
        //         statusCode = 404;
        //     }
        //     else {
        //         body = indexHTML(page);
        //         statusCode = 200;
        //         headers = new KeyValue[](1);
        //         headers[0].key = "Content-type";
        //         headers[0].value = "text/html";
        //     }
        // }
    }

}
