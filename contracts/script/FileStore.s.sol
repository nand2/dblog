// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FileStore, File} from "ethfs/FileStore.sol";

contract FileStoreScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        bytes32 contractSalt = vm.envBytes32("CONTRACT_SALT");
        vm.startBroadcast(deployerPrivateKey);

        FileStore store = new FileStore(address(0x4e59b44847b379578588920cA78FbF26c0B4956C));
        
        (address pointer, File memory file) = store.createFile("test.txt", "Hello, world!");
        string memory contents = store.readFile("test.txt");
        console.log(contents);

        bytes memory gzipedData = hex"1f8b08000000000000034bcacf0700fdcd7a8b03000000";
        (pointer, file) = store.createFile("test.txt.gz", string(gzipedData));
        contents = store.readFile("test.txt.gz");
        console.logBytes(bytes(contents));

        vm.stopBroadcast();
    }
}
