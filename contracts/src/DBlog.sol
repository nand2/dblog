// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlogData.sol";

contract DBlog {
    DBlogData public data;

    struct Frontend {
        string title;
        mapping(string => string) files;
    }
    Frontend[] public frontends;
    Frontend public frontend;

    constructor(string memory title, string memory description) {
        data = new DBlogData(title, description);
    }

    function resolveMode() external pure returns (bytes32) {
        return "5219";
    }

    
}
