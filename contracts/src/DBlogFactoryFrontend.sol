// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlogFactory.sol";

contract DBlogFactoryFrontend {
    DBlogFactory public immutable blogFactory;

    struct Frontend {
        string title;
        mapping(string => string) files;
    }
    Frontend[] public frontends;
    Frontend public frontend;

    constructor(DBlogFactory _blogFactory) {
        blogFactory = _blogFactory;
    }

    function resolveMode() external pure returns (bytes32) {
        return "5219";
    }

    
}
