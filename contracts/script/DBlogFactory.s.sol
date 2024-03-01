// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Script, console} from "forge-std/Script.sol";
import {DBlogFactory} from "../src/DBlogFactory.sol";
import {FileStore, File} from "ethfs/FileStore.sol";

contract DBlogFactoryScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        bytes32 contractSalt = vm.envBytes32("CONTRACT_SALT");
        vm.startBroadcast(deployerPrivateKey);

        // ETHFS filestore
        FileStore store = new FileStore{salt: contractSalt}(address(0x4e59b44847b379578588920cA78FbF26c0B4956C));
        console.log("FileStore: ", vm.toString(address(store)));

        // Storing files of the factory frontend
        // HTML
        bytes memory fileContents = vm.readFileBinary(string.concat("dist/frontend-factory/", vm.envString("FACTORY_FRONTEND_HTML_FILE")));
        (address factoryHtmlFilePointer, ) = store.createFile(vm.envString("FACTORY_FRONTEND_HTML_FILE"), string(fileContents));
        // CSS
        fileContents = vm.readFileBinary(string.concat("dist/frontend-factory/assets/", vm.envString("FACTORY_FRONTEND_CSS_FILE")));
        (address factoryCssFilePointer, ) = store.createFile(vm.envString("FACTORY_FRONTEND_CSS_FILE"), string(fileContents));
        // JS
        fileContents = vm.readFileBinary(string.concat("dist/frontend-factory/assets/", vm.envString("FACTORY_FRONTEND_JS_FILE")));
        (address factoryJsFilePointer, ) = store.createFile(vm.envString("FACTORY_FRONTEND_JS_FILE"), string(fileContents));

        // Deploying the blog factory
        DBlogFactory factory = new DBlogFactory{salt: contractSalt}("eth", "dblog", factoryHtmlFilePointer, factoryCssFilePointer, factoryJsFilePointer);

        // Printing the web3:// address of the factory frontend
        string memory web3FactoryFrontendAddress = string.concat("web3://", vm.toString(factory.frontend()));
        if(block.chainid > 1) {
            web3FactoryFrontendAddress = string.concat(web3FactoryFrontendAddress, ":", vm.toString(block.chainid));
        }
        console.log("web3:// factory frontend: ", web3FactoryFrontendAddress);

        // Printing the web3:// address of the factory contract
        string memory web3FactoryAddress = string.concat("web3://", vm.toString(address(factory)));
        if(block.chainid > 1) {
            web3FactoryAddress = string.concat(web3FactoryAddress, ":", vm.toString(block.chainid));
        }
        console.log("web3:// factory: ", web3FactoryAddress);

        vm.stopBroadcast();
    }
}
