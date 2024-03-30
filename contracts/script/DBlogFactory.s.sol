// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DBlogFactory} from "../src/DBlogFactory.sol";
import {DBlogFactoryFrontend} from "../src/DBlogFactoryFrontend.sol";
import {DBlogFrontendLibrary} from "../src/DBlogFrontendLibrary.sol";
import {DBlogFrontend} from "../src/DBlogFrontend.sol";
import {DBlog} from "../src/DBlog.sol";
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
import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";

contract DBlogFactoryScript is Script {
    enum TargetChain{ LOCAL, SEPOLIA, HOLESKY, MAINNET }

    function setUp() public {}

    function run() public {
        // Environment variables
        string memory targetChainString = vm.envString("TARGET_CHAIN");
        TargetChain targetChain = TargetChain.LOCAL;
        if(keccak256(abi.encodePacked(targetChainString)) == keccak256(abi.encodePacked("local"))) {
            targetChain = TargetChain.LOCAL;
        } else if(keccak256(abi.encodePacked(targetChainString)) == keccak256(abi.encodePacked("sepolia"))) {
            targetChain = TargetChain.SEPOLIA;
        } else if(keccak256(abi.encodePacked(targetChainString)) == keccak256(abi.encodePacked("holesky"))) {
            targetChain = TargetChain.HOLESKY;
        } else if(keccak256(abi.encodePacked(targetChainString)) == keccak256(abi.encodePacked("mainnet"))) {
            targetChain = TargetChain.MAINNET;
        }
        string memory domain = vm.envString("DOMAIN");


        vm.startBroadcast();

        // Get ENS nameWrapper (will deploy ENS and register domain name if necessary)
        (NameWrapper nameWrapper, BaseRegistrarImplementation baseRegistrar, ETHRegistrarController ethRegistrarController) = registerDomainAndGetEnsContracts(targetChain, domain);

        // Get ETHFS filestore
        FileStore store = getFileStore(targetChain);
        console.log("FileStore: ", vm.toString(address(store)));

        DBlogFactory factory;
        {
            // Create the factory frontend
            DBlogFactoryFrontend factoryFrontend = new DBlogFactoryFrontend();

            // Create the dblog frontend library
            DBlogFrontendLibrary blogFrontendLibrary = new DBlogFrontendLibrary();

            // Create the blog and blogFrontend implementations
            DBlog blogImplementation = new DBlog();
            DBlogFrontend blogFrontendImplementation = new DBlogFrontend();

            // Deploying the blog factory
            factory = new DBlogFactory("eth", domain, factoryFrontend, blogImplementation, blogFrontendImplementation, blogFrontendLibrary, nameWrapper, ethRegistrarController, baseRegistrar);

            // Add factory frontend initial version
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

                factoryFrontend.addFrontendVersion(factoryHtmlFilePointer, factoryCssFilePointer, factoryJsFilePointer, "Initial version");
            }

            // Add frontend library initial version
            {
                // Storing files of the blog frontend
                // HTML
                bytes memory fileContents = vm.readFileBinary(string.concat("dist/frontend-blog/", vm.envString("BLOG_FRONTEND_HTML_FILE")));
                (address blogHtmlFilePointer, ) = store.createFile(vm.envString("BLOG_FRONTEND_HTML_FILE"), string(fileContents));
                // CSS
                fileContents = vm.readFileBinary(string.concat("dist/frontend-blog/assets/", vm.envString("BLOG_FRONTEND_CSS_FILE")));
                (address blogCssFilePointer, ) = store.createFile(vm.envString("BLOG_FRONTEND_CSS_FILE"), string(fileContents));
                // JS
                fileContents = vm.readFileBinary(string.concat("dist/frontend-blog/assets/", vm.envString("BLOG_FRONTEND_JS_FILE")));
                (address blogJsFilePointer, ) = store.createFile(vm.envString("BLOG_FRONTEND_JS_FILE"), string(fileContents));

                blogFrontendLibrary.addFrontendVersion(blogHtmlFilePointer, blogCssFilePointer, blogJsFilePointer, "Initial version");
            }

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

        // Set the ENS resolver of dblog.eth to the contract
        {
            bytes32 topdomainNamehash = keccak256(abi.encodePacked(bytes32(0x0), keccak256(abi.encodePacked("eth"))));
            bytes32 dblogDomainNamehash = keccak256(abi.encodePacked(topdomainNamehash, keccak256(abi.encodePacked(domain))));
            nameWrapper.setResolver(dblogDomainNamehash, address(factory));
        }

        // Transferring dblog.eth to the factory
        {
            bytes32 topdomainNamehash = keccak256(abi.encodePacked(bytes32(0x0), keccak256(abi.encodePacked("eth"))));
            bytes32 dblogDomainNamehash = keccak256(abi.encodePacked(topdomainNamehash, keccak256(abi.encodePacked(domain))));

            nameWrapper.safeTransferFrom(msg.sender, address(factory), uint(dblogDomainNamehash), 1, "");
            // Testnet: Temporary testing (double checking we can fetch back the domain)
            if(targetChain != TargetChain.MAINNET) {
                factory.testnetSendBackDomain();
                nameWrapper.safeTransferFrom(msg.sender, address(factory), uint(dblogDomainNamehash), 1, "");
            }
        }

        // Adding the main blog
        factory.addBlog{value: 0.01 ether}("DBlog", "Decentralized blogs", domain);
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


    /**
     * Optionally register domain, get some ENS contracts
     * Target chain:
     * - local: Deploy ENS, register domain, returns the name wrapper
     * - sepolia : Register test domain, return the name wrapper
     * - mainnet : Return the name wrapper
     */
    function registerDomainAndGetEnsContracts(TargetChain targetChain, string memory domain) public returns (NameWrapper, BaseRegistrarImplementation, ETHRegistrarController) {
        NameWrapper nameWrapper;
        BaseRegistrarImplementation registrar;
        ETHRegistrarController registrarController;

        // Local chain : deploy ENS
        if(targetChain == TargetChain.LOCAL){
            ENSRegistry registry;
            PublicResolver publicResolver;
            
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
            registrar = new BaseRegistrarImplementation(registry, topdomainNamehash);
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
        // Sepolia: Get ENS sepolia addresses
        else if(targetChain == TargetChain.SEPOLIA) {
            nameWrapper = NameWrapper(0x0635513f179D50A207757E05759CbD106d7dFcE8);
            registrar = BaseRegistrarImplementation(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
            registrarController = ETHRegistrarController(0xFED6a969AaA60E4961FCD3EBF1A2e8913ac65B72);
        }
        // Sepolia: Get ENS holesky addresses
        else if(targetChain == TargetChain.HOLESKY) {
            nameWrapper = NameWrapper(0xab50971078225D365994dc1Edcb9b7FD72Bb4862);
            registrar = BaseRegistrarImplementation(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
            registrarController = ETHRegistrarController(0x179Be112b24Ad4cFC392eF8924DfA08C20Ad8583);
        }
        // Mainnet: Get ENS mainnet addresses
        else if(targetChain == TargetChain.MAINNET) {
            nameWrapper = NameWrapper(0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401);
            registrar = BaseRegistrarImplementation(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
            registrarController = ETHRegistrarController(0x253553366Da8546fC250F225fe3d25d0C782303b);
        }


        // Local : Register dblog.eth
        if(targetChain == TargetChain.LOCAL) {
            bytes[] memory data = new bytes[](0);
            bytes32 commitment = registrarController.makeCommitment(domain, msg.sender, 365 * 24 * 3600, 0x00, address(0x0), data, false, 0);
            registrarController.commit(commitment);
            registrarController.register{value: 0.05 ether}(domain, msg.sender, 365 * 24 * 3600, 0x00, address(0x0), data, false, 0);
        }

        return (nameWrapper, registrar, registrarController);
    }

    /**
     * Optionally deploy FileStore, get FileStore address
     * Target chain:
     * - local: Deploy FileStore, return the address
     * - sepolia : Return the address
     * - mainnet : Return the address
     */
    function getFileStore(TargetChain targetChain) public returns (FileStore) {
        FileStore store;
        
        // Local: Deploy new filestore
        if(targetChain == TargetChain.LOCAL) {
            store = new FileStore(address(0x4e59b44847b379578588920cA78FbF26c0B4956C));
        }
        // Sepolia : Get existing value
        else if(targetChain == TargetChain.SEPOLIA) {
            store = FileStore(0xFe1411d6864592549AdE050215482e4385dFa0FB);
        }
        // Holesky : Get existing value
        else if(targetChain == TargetChain.HOLESKY) {
            store = FileStore(0xFe1411d6864592549AdE050215482e4385dFa0FB);
        }
        // Mainnet : Get existing value
        else if(targetChain == TargetChain.MAINNET) {
            store = FileStore(0xFe1411d6864592549AdE050215482e4385dFa0FB);
        }
        
        return store;
    }
}
