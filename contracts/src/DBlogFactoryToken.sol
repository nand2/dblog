// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { DBlogFactory } from "./DBlogFactory.sol";
import { DBlog } from "./DBlog.sol";
import "./library/Strings.sol";
import "./interfaces/FileInfos.sol";

contract DBlogFactoryToken {
    DBlogFactory public blogFactory;

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

    function tokenSVG(uint tokenId) public view returns (string memory) {
        require(tokenId < blogFactory.getBlogCount(), "Token does not exist");

        DBlog blog = blogFactory.blogs(tokenId);

        // Prepare the address part
        string memory svgAddressPart = "";
        uint subdomainLength = bytes(blog.subdomain()).length;
        if(subdomainLength > 0) {
            uint subdomainFontSize = 25;
            if(subdomainLength >= 15) {
                subdomainFontSize = 23 - (subdomainLength - 15);
            }

            svgAddressPart = string.concat(
                '<text x="20" y="53" font-size="25">',
                    '<tspan x="20" dy="1em" font-size="', Strings.toString(subdomainFontSize), '">', blog.subdomain(), '</tspan>',
                    '<tspan x="20" dy="1.2em" opacity="0.6">', blogFactory.domain(), '.', blogFactory.topdomain(), '</tspan>',
                '</text>'
            );
        }
        else {
            string memory addressStr = Strings.toHexString(address(blog.frontend()));
            string memory addressStrPart1 = Strings.substring(addressStr, 0, 24);
            string memory addressStrPart2 = Strings.substring(addressStr, 24, 42);

            uint chainId = block.chainid;
            FileStorageMode storageMode = blog.frontend().blogFrontendVersion().storageMode;
            if(storageMode == FileStorageMode.EthStorage) {
                if(block.chainid == 1) {
                    chainId = 333;
                }
                else if(block.chainid == 11155111) {
                    chainId = 3333;
                }
            }
            if(chainId > 1) {
                addressStrPart2 = string.concat(addressStrPart2, ":", Strings.toString(chainId));
            }

            svgAddressPart = string.concat(
                '<text x="20" y="90" font-size="15">'
                    '<tspan x="20" dy="-1.2em">', addressStrPart1, '</tspan>'
                    '<tspan x="20" dy="1.2em">', addressStrPart2, '</tspan>'
                '</text>'
            );
        }

        return string.concat(
            '<svg width="256" height="256" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg">'
                '<style>'
                    '@font-face{'
                        'font-family: "IBMPlexMono";src:url(data:font/woff2;base64,',
                        blogFactory.ethFsFileStore().readFile("IBMPlexMono-Regular.woff2"),
                        ') format("woff2");'
                        'font-weight: normal;'
                        'font-style: normal;'
                    '}'
                    'text {'
                        'font-family: IBMPlexMono;'
                        'font-weight: bold;'
                        'font-style: normal;'
                        'fill : white;'
                        'filter: drop-shadow(0px 0px 3px #48912d);'
                    '}'
                '</style>'
                '<rect width="256" height="256" fill="#61c23e" />'
                '<text x="20" y="45" font-size="30">'
                    'web3://'
                '</text>',
                // '<text x="20" y="90" font-size="15">'
                //     '<tspan x="20" dy="-1.2em">0x1613beB3B2C4f22Ee086B2</tspan>'
                //     '<tspan x="20" dy="1.2em">b38C1476A3cE7f78E8:333</tspan>'
                // '</text>'
                // '<text x="20" y="53" font-size="25">'
                //     '<tspan x="20" dy="1em">nand.</tspan>'
                //     '<tspan x="20" dy="1.2em" opacity="0.6">dblog.eth</tspan>'
                // '</text>'
                svgAddressPart,
                '<text x="160" y="230" font-size="60">'
                    'DB'
                '</text>'
            '</svg>'
        );
    }
}