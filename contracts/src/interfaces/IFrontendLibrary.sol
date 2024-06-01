// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./FileInfos.sol";
import "./IStorageBackend.sol";
// EthFs
import {FileStore} from "ethfs/FileStore.sol";

interface IFrontendLibrary {
  function getStorageBackendIndexByName(string memory name) external view returns (uint16 index);
  function getStorageBackend(uint16 index) external view returns (IStorageBackend storageBackend);

  function createFile(uint16 storageBackendIndex, bytes memory data, uint dataLength) external payable returns (uint256);
  function appendToFile(uint16 storageBackendIndex, uint256 fileIndex, bytes memory data) external payable;

  function addFrontendVersion(uint16 storageBackendIndex, FileInfos2[] memory files, string memory _infos) external;
  function addFilesToCurrentFrontendVersion(FileInfos2[] memory files) external;


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
  function getFrontendVersion(uint256 _index) external view returns (FrontendFilesSet2 memory);
  function setDefaultFrontend(uint256 _index) external;
  function getDefaultFrontend() external view returns (FrontendFilesSet2 memory);
}