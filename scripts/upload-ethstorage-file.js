import { createWalletClient, http, publicActions } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet, sepolia, holesky, hardhat } from 'viem/chains'
import { default as cKzg } from 'c-kzg'
import { setupKzg } from 'viem'
import { parseGwei, stringToHex, toBlobs, toHex } from 'viem'
import path from 'path';
import {fileURLToPath} from 'url';
import { encodeFunctionData } from 'viem'
import { getContract } from 'viem'
import fs from 'fs'

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Read first argument: targetChain. Default to "local"
const targetChain = process.argv[2] || "local"

// Read second argument : contract address of the frontend
const frontendAddress = process.argv[3]

// Read third to fifth argument: file paths to upload
const htmlFilePath = process.argv[4]
const cssFilePath = process.argv[5]
const jsFilePath = process.argv[6]

console.log(`Uploading ${htmlFilePath}, ${cssFilePath}, ${jsFilePath} to ${frontendAddress} on ${targetChain} chain`)


// Blob functions and constants
const MIN_BLOB_GASPRICE = 1n;
const BLOB_GASPRICE_UPDATE_FRACTION = 3338477n;
function fakeExponential(factor, numerator, denominator) {
    let i = 1n;
    let output = 0n;
    let numerator_accum = factor * denominator;
    while (numerator_accum > 0n) {
        output += numerator_accum;
        numerator_accum = (numerator_accum * numerator) / (denominator * i);
        i++;
    }
    return output / denominator;
}
async function getBaseFeePerBlobGas() {
  let block = await client.getBlock();
  let blogGasFee = fakeExponential(MIN_BLOB_GASPRICE, block.excessBlobGas ?? 0n,BLOB_GASPRICE_UPDATE_FRACTION);
  return blogGasFee;
}


// Determine the private key to use based on the target chain
// Determine also the chain and the RPC URL, and the ethStorage contract address
let privateKey
let chain
let rpcUrl
if (targetChain === "local") {
  privateKey = process.env.PRIVATE_KEY_LOCAL;
  chain = hardhat
  rpcUrl = "http://127.0.0.1:8545";
}
else if (targetChain === "sepolia") {
  privateKey = process.env.PRIVATE_KEY_SEPOLIA;
  chain = sepolia
  rpcUrl = "https://ethereum-sepolia-rpc.publicnode.com";
}
else if (targetChain === "holesky") {
  privateKey = process.env.PRIVATE_KEY_HOLESKY;
  chain = holesky
  rpcUrl = "https://ethereum-holesky-rpc.publicnode.com";
}


// Setup client
const account = privateKeyToAccount(privateKey)
const client = createWalletClient({
  account,
  chain: chain,
  transport: http(rpcUrl)
}).extend(publicActions)
const kzg = setupKzg(cKzg, path.resolve(__dirname, "kzg-trusted-setup-mainnet.json"))

// Setup Frontend contract
const frontendABI = [
  {"inputs":[
    {"internalType":"bytes32","name":"htmlFile","type":"bytes32"},
    {"internalType":"uint256","name":"htmlFileSize","type":"uint256"},
    {"internalType":"bytes32","name":"cssFile","type":"bytes32"},
    {"internalType":"bytes32","name":"jsFile","type":"bytes32"},
    {"internalType":"string","name":"infos","type":"string"}],
    "name":"addEthStorageFrontendVersion","outputs":[],"stateMutability":"payable","type":"function"},
  {"inputs":[],"name":"getEthStorageUpfrontPayment","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
];
const ethStorage = getContract({
  address: frontendAddress,
  abi: frontendABI,
  client: client,
})
 

// Fetch the upfront payment necessary to store the blob to ethStorage
const upfrontPayment = await ethStorage.read.getEthStorageUpfrontPayment()
console.log("EthStorage upfront payment", upfrontPayment)


let baseFeePerBlobGas = await getBaseFeePerBlobGas();
let maxFeePerBlobGas = baseFeePerBlobGas * 2n;

// Prepare blob
// const blob1 = toBlobs({ data: toHex(fs.readFileSync(htmlFilePath)) }) 
// const blob2 = toBlobs({ data: stringToHex('hello world') }) 
// const blob3 = toBlobs({ data: stringToHex('hello world') }) 
// const blobs = [...blob1, ...blob2, ...blob3];
const htmlData = fs.readFileSync(htmlFilePath);
const htmlDataSize = Buffer.byteLength(htmlData);
const blobs = toBlobs({ data: toHex(htmlData) }) 
console.log("htmlDataSize", htmlDataSize)

// Prepare data call
const data = encodeFunctionData({
  abi: frontendABI,
  functionName: 'addEthStorageFrontendVersion',
  args: ['0x00000000000000000000000000000000000000000000000000000000000000f1', htmlDataSize, '0x00000000000000000000000000000000000000000000000000000000000000f2', '0x00000000000000000000000000000000000000000000000000000000000000f3', 'Initial version']
})

// Send transaction
const hash = await client.sendTransaction({
  blobs,
  kzg,
  maxFeePerBlobGas: maxFeePerBlobGas,
  to: frontendAddress,
  value: upfrontPayment,
  data: data,
})
console.log("tx hash", hash)

const transaction = await client.waitForTransactionReceipt( 
  { hash: hash }
)
console.log(transaction)