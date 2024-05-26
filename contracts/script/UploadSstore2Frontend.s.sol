// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/interfaces/IFrontendLibrary.sol";
import { Strings } from "../src/library/Strings.sol";

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

        // Get the files to upload
        FileNameAndCompressedName[] memory files = abi.decode(vm.envBytes("FILE_ARGS"), (FileNameAndCompressedName[]));
        string memory compressedFilesBasePath = vm.envString("COMPRESSED_FILES_BASE_PATH");

        // Upload them, store them into FileInfos format
        FileInfos[] memory fileInfos = new FileInfos[](files.length);
        for (uint256 i = 0; i < files.length; i++) {
            console.log("Handling file", files[i].filename, files[i].compressedFileName);
            console.log("    ", files[i].mimeType, files[i].subFolder);

            bytes memory fileContents = vm.readFileBinary(string.concat(compressedFilesBasePath, files[i].subFolder, files[i].compressedFileName));
            (address filePointer, ) = frontendLibrary.getEthFsFileStore().createFile(files[i].compressedFileName, string(fileContents));
            bytes32[] memory contentKeys = new bytes32[](1);
            contentKeys[0] = bytes32(uint256(uint160(filePointer)));
            fileInfos[i] = FileInfos(string.concat(files[i].subFolder, files[i].filename), files[i].mimeType, contentKeys);
        }

        // If there is already a frontend version which is unlocked, we wipe it and replace it
        if(frontendLibrary.frontendVersionsCount() > 0 && frontendLibrary.getFrontendVersion(frontendLibrary.frontendVersionsCount() - 1).locked == false) {
            console.log("Resetting and replacing latest frontend version");
            frontendLibrary.resetLatestFrontendVersion();
            frontendLibrary.addFilesToCurrentSStore2FrontendVersion(fileInfos);
        }
        // Otherwise we add a new version
        else {
            console.log("Adding new frontend version");
            frontendLibrary.addSStore2FrontendVersion(fileInfos, "Initial version");
        }

        vm.stopBroadcast();
    }

}