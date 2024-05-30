// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import { Strings } from "../src/library/Strings.sol";
import "../src/interfaces/IFrontendLibrary.sol";
import "../src/interfaces/IStorageBackend.sol";

contract UploadSstore2Frontend is Script {

    function setUp() public {}

    struct FileNameAndCompressedName {
        string filename;
        string compressedFileName;
        string mimeType;
        string subFolder;
    }
    function run() public {
        vm.startBroadcast();

        IFrontendLibrary frontendLibrary = IFrontendLibrary(vm.envAddress("IFRONTEND_LIBRARY_CONTRACT_ADDRESS"));

        // Get the SSTORE2 storage backend
        uint16 storageBackendIndex = frontendLibrary.getStorageBackendIndexByName("SSTORE2");
        IStorageBackend storageBackend = frontendLibrary.getStorageBackend(storageBackendIndex);

        // Get the files to upload
        FileNameAndCompressedName[] memory files = abi.decode(vm.envBytes("FILE_ARGS"), (FileNameAndCompressedName[]));
        string memory compressedFilesBasePath = vm.envString("COMPRESSED_FILES_BASE_PATH");

        // Upload them, store them into FileInfos format
        FileInfos2[] memory fileInfos = new FileInfos2[](files.length);
        for (uint256 i = 0; i < files.length; i++) {
            console.log("Handling file", files[i].filename, files[i].compressedFileName);
            console.log("    ", files[i].mimeType, files[i].subFolder);

            bytes memory fileContents = vm.readFileBinary(string.concat(compressedFilesBasePath, files[i].subFolder, files[i].compressedFileName));
            fileInfos[i] = frontendLibrary.createFile(string.concat(files[i].subFolder, files[i].filename), files[i].mimeType, storageBackendIndex, fileContents, fileContents.length);
        }

        // If there is already a frontend version which is unlocked, we wipe it and replace it
        if(frontendLibrary.frontendVersionsCount() > 0 && frontendLibrary.getFrontendVersion(frontendLibrary.frontendVersionsCount() - 1).locked == false) {
            console.log("Resetting and replacing latest frontend version");
            frontendLibrary.resetLatestFrontendVersion();
            frontendLibrary.addFilesToCurrentFrontendVersion(fileInfos);
        }
        // Otherwise we add a new version
        else {
            console.log("Adding new frontend version");
            frontendLibrary.addFrontendVersion(storageBackendIndex, fileInfos, "Initial version");
        }

        vm.stopBroadcast();
    }

}