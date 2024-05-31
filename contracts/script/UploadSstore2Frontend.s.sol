// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import { Strings } from "../src/library/Strings.sol";
import {LibString} from "solady/utils/LibString.sol";

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

        // Get the files to upload
        FileNameAndCompressedName[] memory files = abi.decode(vm.envBytes("FILE_ARGS"), (FileNameAndCompressedName[]));
        string memory compressedFilesBasePath = vm.envString("COMPRESSED_FILES_BASE_PATH");

        // Upload them, store them into FileInfos format
        FileInfos2[] memory fileInfos = new FileInfos2[](files.length);
        for (uint256 i = 0; i < files.length; i++) {
            console.log("Handling file", files[i].filename, files[i].compressedFileName);
            console.log("    ", files[i].mimeType, files[i].subFolder);

            bytes memory fileContents = vm.readFileBinary(string.concat(compressedFilesBasePath, files[i].subFolder, files[i].compressedFileName));

            // Transaction size limit is 131072 bytes, so we need to split the file in chunks
            // We also get "exceeds block gas limit" when trying to put too much
            // Let's put 3 * (0x6000-1) bytes ((0x6000-1) being the size of a SSTORE2 chunk)
            uint256 chunkSize = 3 * (0x6000-1);
            uint256 chunksCount = fileContents.length / chunkSize;
            if (fileContents.length % chunkSize != 0) {
                chunksCount++;
            }

            for(uint256 j = 0; j < chunksCount; j++) {
                uint256 start = j * chunkSize;
                uint256 end = start + chunkSize;
                if(end > fileContents.length) {
                    end = fileContents.length;
                }
                bytes memory chunk = bytes(LibString.slice(string(fileContents), start, end));
                console.log("    - Uploading chunk", j, "of size", chunk.length);
                if(j == 0) {
                    fileInfos[i] = FileInfos2({
                        filePath: string.concat(files[i].subFolder, files[i].filename),
                        contentType: files[i].mimeType,
                        contentKey: frontendLibrary.createFile(storageBackendIndex, chunk, fileContents.length)
                    });
                }
                else {
                    frontendLibrary.appendToFile(storageBackendIndex, fileInfos[i].contentKey, chunk);
                }
            }
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