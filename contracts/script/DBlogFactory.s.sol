// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DBlogFactory} from "../src/DBlogFactory.sol";
import {FileStore, File} from "ethfs/FileStore.sol";
import {ENSRegistry} from "ens-contracts/registry/ENSRegistry.sol";
import {ReverseRegistrar} from "ens-contracts/reverseRegistrar/ReverseRegistrar.sol";
import {Root} from "ens-contracts/root/Root.sol";
import {BaseRegistrarImplementation} from "ens-contracts/ethregistrar/BaseRegistrarImplementation.sol";
import {DummyOracle} from "ens-contracts/ethregistrar/DummyOracle.sol";
import {ExponentialPremiumPriceOracle} from "ens-contracts/ethregistrar/ExponentialPremiumPriceOracle.sol";
import {AggregatorInterface} from "ens-contracts/ethregistrar/StablePriceOracle.sol";
import {StaticMetadataService} from "ens-contracts/wrapper/StaticMetadataService.sol";
import {NameWrapper} from "ens-contracts/wrapper/NameWrapper.sol";
import {IMetadataService} from "ens-contracts/wrapper/IMetadataService.sol";
import {ETHRegistrarController} from "ens-contracts/ethregistrar/ETHRegistrarController.sol";
import {OwnedResolver} from "ens-contracts/resolvers/OwnedResolver.sol";
import {ExtendedDNSResolver} from "ens-contracts/resolvers/profiles/ExtendedDNSResolver.sol";
import {PublicResolver} from "ens-contracts/resolvers/PublicResolver.sol";

contract DBlogFactoryScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        bytes32 contractSalt = vm.envBytes32("CONTRACT_SALT");
        vm.startBroadcast(deployerPrivateKey);


        ENSRegistry registry;
        ETHRegistrarController registrarController;
        PublicResolver publicResolver;
        NameWrapper nameWrapper;
        {
            bytes32 topdomainNamehash = keccak256(abi.encodePacked(bytes32(0x0), keccak256(abi.encodePacked("eth"))));

            // ENS registry
            registry = new ENSRegistry();
            console.log("ENS registry: ", vm.toString(address(registry)));
            console.log("ENS registry owner: ", vm.toString(registry.owner(0x0)));
        
            // Root
            Root root = new Root(registry);
            console.log("Root: ", vm.toString(address(root)));
            registry.setOwner(0x0, address(root));
            root.setController(msg.sender, true);
            
            // ENS reverse registrar
            ReverseRegistrar reverseRegistrar = new ReverseRegistrar(registry);
            console.log("Reverse registrar: ", vm.toString(address(reverseRegistrar)));
            root.setSubnodeOwner(keccak256(abi.encodePacked("reverse")), msg.sender);
            registry.setSubnodeOwner(keccak256(abi.encodePacked(bytes32(0x0), keccak256(abi.encodePacked("reverse")))), keccak256(abi.encodePacked("addr")), address(reverseRegistrar));
            
            // Base registrar implementation
            BaseRegistrarImplementation registrar = new BaseRegistrarImplementation(registry, topdomainNamehash);
            root.setSubnodeOwner(keccak256(abi.encodePacked("eth")), address(registrar));
            console.log("Base registrar: ", vm.toString(address(registrar)));
            
            ExponentialPremiumPriceOracle priceOracle;
            {
                // Dummy price oracle
                DummyOracle oracle = new DummyOracle(160000000000);
                console.log("Dummy oracle: ", vm.toString(address(oracle)));

                // Exponential price oracle
                uint256[] memory rentPrices = new uint256[](5);
                rentPrices[0] = 0;
                rentPrices[1] = 0;
                rentPrices[2] = 20294266869609;
                rentPrices[3] = 5073566717402;
                rentPrices[4] = 158548959919;
                priceOracle = new ExponentialPremiumPriceOracle(AggregatorInterface(address(oracle)), rentPrices, 100000000000000000000000000, 21);
                console.log("Exponential price oracle: ", vm.toString(address(priceOracle)));
            }

            {
                // Static metadata service
                StaticMetadataService metadata = new StaticMetadataService("http://localhost:8080/name/0x{id}");
                console.log("Static metadata service: ", vm.toString(address(metadata)));

                // Name wrapper
                nameWrapper = new NameWrapper(registry, registrar, IMetadataService(address(metadata)));
                console.log("Name wrapper: ", vm.toString(address(nameWrapper)));
                registrar.addController(address(nameWrapper));
            }

            // Eth Registrar controller
            registrarController = new ETHRegistrarController(registrar, priceOracle, 0 /** min commitment age normally to 60, put it to 0 for fast registration testing */, 86400, reverseRegistrar, nameWrapper, registry);
            console.log("ETH registrar controller: ", vm.toString(address(registrarController)));
            nameWrapper.setController(address(registrarController), true);
            reverseRegistrar.setController(address(registrarController), true);
            console.log("Eth resolver: ", vm.toString(registry.resolver(topdomainNamehash)));

            {
                // Eth owned resolver
                OwnedResolver ethOwnedResolver = new OwnedResolver();
                console.log("Eth resolver: ", vm.toString(address(ethOwnedResolver)));
                registrar.setResolver(address(ethOwnedResolver));
                console.log("Registry: Eth resolver: ", vm.toString(registry.resolver(topdomainNamehash)));

                // Extended resolver
                ExtendedDNSResolver extendedResolver = new ExtendedDNSResolver();
                console.log("Extended resolver: ", vm.toString(address(extendedResolver)));

                // Public resolver
                publicResolver = new PublicResolver(registry, nameWrapper, address(registrarController), address(reverseRegistrar));
                console.log("Public resolver: ", vm.toString(address(publicResolver)));
                reverseRegistrar.setDefaultResolver(address(publicResolver));
            }

            // TODO: call ethOwnedResolver.setInterface()
        }


        // Register dblog.eth
        {
            bytes[] memory data = new bytes[](0);
            bytes32 commitment = registrarController.makeCommitment("dblog", msg.sender, 31536000, 0x00, address(0x0), data, false, 0);
            registrarController.commit(commitment);
            registrarController.register{value: 0.1 ether}("dblog", msg.sender, 31536000, 0x00, address(0x0), data, false, 0);
        }


        // ETHFS filestore
        FileStore store = new FileStore{salt: contractSalt}(address(0x4e59b44847b379578588920cA78FbF26c0B4956C));
        console.log("FileStore: ", vm.toString(address(store)));

        DBlogFactory factory;
        {
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
            factory = new DBlogFactory{salt: contractSalt}("eth", "dblog", factoryHtmlFilePointer, factoryCssFilePointer, factoryJsFilePointer, blogHtmlFilePointer, blogCssFilePointer, blogJsFilePointer);

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
        }

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

        // Set the ENS resolver of dblog.eth to the contract
        {
            bytes32 topdomainNamehash = keccak256(abi.encodePacked(bytes32(0x0), keccak256(abi.encodePacked("eth"))));
            bytes32 dblogDomainNamehash = keccak256(abi.encodePacked(topdomainNamehash, keccak256(abi.encodePacked("dblog"))));
            nameWrapper.setResolver(dblogDomainNamehash, address(factory));

            // Resolve a few domains
            // Get resolver of dblog.eth
            address dblogEthResolver = registry.resolver(dblogDomainNamehash);
            console.log("Resolver of dblog.eth: ", vm.toString(dblogEthResolver));
            // Resolve dblog.eth
            address dblogEthAddress = PublicResolver(dblogEthResolver).addr(dblogDomainNamehash);
            console.log("Address of dblog.eth: ", vm.toString(dblogEthAddress));
            // Resolve dblog.dblog.eth
            address dblogDblogEthAddress = PublicResolver(dblogEthResolver).addr(keccak256(abi.encodePacked(dblogDomainNamehash, keccak256(abi.encodePacked("dblog")))));
            console.log("Address of dblog.dblog.eth: ", vm.toString(dblogDblogEthAddress));
        }

        vm.stopBroadcast();
    }
}
