// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlogFactory.sol";
import "./interfaces/IDecentralizedApp.sol";
import { File } from "ethfs/FileStore.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { Strings } from "./library/Strings.sol";

contract DBlogFactoryFrontend is IDecentralizedApp {
    DBlogFactory public immutable blogFactory;

    // A version of a frontend, containing a single HTML, CSS and JS file.
    struct FrontendVersion {
        // Pointers to ethfs File structures stored with SSTORE2
        // Note: These files are expected to be compressed with gzip
        address htmlFile;
        address cssFile;
        address jsFile;

        // Infos about this version
        string infos;
    }
    FrontendVersion[] public frontendVersions;
    uint256 public defaultFrontendIndex;


    modifier onlyFactoryOrFactoryOwner() {
        require(msg.sender == address(blogFactory) || msg.sender == blogFactory.owner(), "Not owner");
        _;
    }

    constructor(DBlogFactory _blogFactory, address _initialHtmlFile, address _initialCssFile, address _initialJsFile) {
        blogFactory = _blogFactory;

        // Setup the initial frontend
        addFrontendVersion(_initialHtmlFile, _initialCssFile, _initialJsFile, "Initial version");
    }

    function addFrontendVersion(address _htmlFile, address _cssFile, address _jsFile, string memory _infos) public onlyFactoryOrFactoryOwner {
        FrontendVersion memory newFrontend = FrontendVersion(_htmlFile, _cssFile, _jsFile, _infos);
        frontendVersions.push(newFrontend);
    }

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

        // Frontpage
        if(resource.length == 0) {
            File memory file = abi.decode(SSTORE2.read(frontend.htmlFile), (File));
            body = file.read();
            statusCode = 200;
            headers = new KeyValue[](2);
            headers[0].key = "Content-type";
            headers[0].value = "text/html";
            headers[1].key = "Content-Encoding";
            headers[1].value = "gzip";
        }
        // blogFactoryAddress.json : it exposes the addess of the blog factory
        else if(resource.length == 1 && Strings.compare(resource[0], "blogFactoryAddress.json")) {
            // Manual JSON serialization, safe with the vars we encode
            body = string.concat("{\"address\":\"", Strings.toHexString(address(blogFactory)), "\", \"chainId\":", Strings.toString(block.chainid), "}");
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
                File memory file = abi.decode(SSTORE2.read(frontend.cssFile), (File));
                body = file.read();
                statusCode = 200;
                headers = new KeyValue[](2);
                headers[0].key = "Content-type";
                headers[0].value = "text/css";
                headers[1].key = "Content-Encoding";
                headers[1].value = "gzip";
            }
            else if(Strings.strlen(assetName) > 3 && 
                Strings.compare(Strings.substring(assetName, assetNameLen - 3, assetNameLen), ".js")) {
                File memory file = abi.decode(SSTORE2.read(frontend.jsFile), (File));
                body = file.read();
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
