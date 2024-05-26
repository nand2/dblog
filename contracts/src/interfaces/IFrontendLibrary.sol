// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./FileInfos.sol";
// EthFs
import {FileStore} from "ethfs/FileStore.sol";

interface IFrontendLibrary {
  function getEthFsFileStore() external view returns (FileStore);
  function addSStore2FrontendVersion(FileInfos[] memory files, string memory _infos) external;
  function addFilesToCurrentSStore2FrontendVersion(FileInfos[] memory files) external;

  // The idea behind the frontend versions is that they will eventually be immutable
  // (after being locked)
  // So in the case of EthStorage, we cannot give the keys as arguments (otherwise we can
  // override a key), so the keys will be generated by this contract. We will only give
  // the blob indexes to this function
  struct EthStorageFileUploadInfos {
      // The path of the file, without root slash. E.g. "images/logo.png"
      string filePath;
      // The content type of the file, e.g. "image/png"
      string contentType;
      // The indexes of the blobs to use for this file
      uint256[] blobIndexes;
      // The size of the data in the blobs
      uint256[] blobDataSizes;
  }
  function addEthStorageFrontendVersion(EthStorageFileUploadInfos[] memory files, string memory _infos) external payable;
  function addFilesToLatestEthStorageFrontendVersion(EthStorageFileUploadInfos[] memory files) external payable;

  function lockLatestFrontendVersion() external;
  function resetLatestFrontendVersion() external;

  function frontendVersionsCount() external view returns (uint256);
  function getFrontendVersion(uint256 _index) external view returns (FrontendFilesSet memory);
  function setDefaultFrontend(uint256 _index) external;
  function getDefaultFrontend() external view returns (FrontendFilesSet memory);
}