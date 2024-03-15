// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Script, console} from "forge-std/Script.sol";
import {DBlogFactory} from "../src/DBlogFactory.sol";
import {FileStore, File} from "ethfs/FileStore.sol";
import {ENSRegistry} from "ens-contracts/registry/ENSRegistry.sol";
import {ReverseRegistrar} from "ens-contracts/reverseRegistrar/ReverseRegistrar.sol";

contract DBlogFactoryScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        bytes32 contractSalt = vm.envBytes32("CONTRACT_SALT");
        vm.startBroadcast(deployerPrivateKey);

        // ENS
        ENSRegistry ensRegistry = new ENSRegistry{salt: contractSalt}();
        console.log("ENS registry: ", vm.toString(address(ensRegistry)));
        ReverseRegistrar reverseRegistrar = new ReverseRegistrar{salt: contractSalt}(ensRegistry);
        console.log("Reverse registrar: ", vm.toString(address(reverseRegistrar)));

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

        // Storing files of the blog frontend
        // HTML
        fileContents = vm.readFileBinary(string.concat("dist/frontend-blog/", vm.envString("BLOG_FRONTEND_HTML_FILE")));
        (address blogHtmlFilePointer, ) = store.createFile(vm.envString("BLOG_FRONTEND_HTML_FILE"), string(fileContents));
        // CSS
        fileContents = vm.readFileBinary(string.concat("dist/frontend-blog/assets/", vm.envString("BLOG_FRONTEND_CSS_FILE")));
        (address blogCssFilePointer, ) = store.createFile(vm.envString("BLOG_FRONTEND_CSS_FILE"), string(fileContents));
        // JS
        fileContents = vm.readFileBinary(string.concat("dist/frontend-blog/assets/", vm.envString("BLOG_FRONTEND_JS_FILE")));
        (address blogJsFilePointer, ) = store.createFile(vm.envString("BLOG_FRONTEND_JS_FILE"), string(fileContents));


        // Deploying the blog factory
        DBlogFactory factory = new DBlogFactory{salt: contractSalt}("eth", "dblog", factoryHtmlFilePointer, factoryCssFilePointer, factoryJsFilePointer, blogHtmlFilePointer, blogCssFilePointer, blogJsFilePointer);

        // Printing the web3:// address of the factory frontend
        string memory web3FactoryFrontendAddress = string.concat("web3://", vm.toString(address(factory.factoryFrontend())));
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

        // Adding the main blog
        factory.addBlog{value: 0.01 ether}("DBlog", "A decentralized blog", "dblog");
        string memory web3BlogFrontendAddress = string.concat("web3://", vm.toString(address(factory.blogs(0).frontend())));
        if(block.chainid > 1) {
            web3BlogFrontendAddress = string.concat(web3BlogFrontendAddress, ":", vm.toString(block.chainid));
        }
        console.log("web3://dblog.dblog.eth frontend: ", web3BlogFrontendAddress);

        string memory web3BlogAddress = string.concat("web3://", vm.toString(address(factory.blogs(0))));
        if(block.chainid > 1) {
            web3BlogAddress = string.concat(web3BlogAddress, ":", vm.toString(block.chainid));
        }
        console.log("web3://dblog.dblog.eth: ", web3BlogAddress);

        vm.stopBroadcast();
    }
}
