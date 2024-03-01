// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DBlog.sol";

contract DBlogFrontend {
    DBlog public data;
    string public subdomain;

    struct Frontend {
        string title;
        mapping(string => string) files;
    }
    Frontend[] public frontends;
    Frontend public frontend;

    function resolveMode() external pure returns (bytes32) {
        return "5219";
    }

    
}
