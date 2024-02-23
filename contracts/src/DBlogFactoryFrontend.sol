// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlogData.sol";

contract DBlogFactoryFrontend {

    struct Frontend {
        string title;
        mapping(string => string) files;
    }
    Frontend[] public frontends;
    Frontend public frontend;

    constructor() {
    }

    function resolveMode() external pure returns (bytes32) {
        return "5219";
    }

    
}
