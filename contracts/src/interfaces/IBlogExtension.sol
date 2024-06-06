// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { DBlog } from "../DBlog.sol";

interface IFactoryExtension {
  function getName() external view returns (string memory);
}

interface IBlogExtension {
  function getName() external view returns (string memory);
  function initialize(DBlog _blog) external;
}