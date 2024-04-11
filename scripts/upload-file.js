import { createWalletClient, http, publicActions } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet, sepolia, holesky, hardhat } from 'viem/chains'
import { default as cKzg } from 'c-kzg'
import { setupKzg } from 'viem'
import { parseGwei, stringToHex, toBlobs } from 'viem'
import path from 'path';
import {fileURLToPath} from 'url';
import { encodeFunctionData } from 'viem'
import { getContract } from 'viem'

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Read first argument: targetChain. Default to "local"
const targetChain = process.argv[2] || "local"

// Read second argument: file path. Default to "upload-file.js"
const filePath = process.argv[3] || "upload-file.js"


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
  let blogGasFee = fakeExponential(MIN_BLOB_GASPRICE, block.excessBlobGas,BLOB_GASPRICE_UPDATE_FRACTION);
  return blogGasFee;
}


// Determine the private key to use based on the target chain
// Determine also the chain and the RPC URL, and the ethStorage contract address
let privateKey
let chain
let rpcUrl
let ethStorageAddress
if (targetChain === "local") {
  privateKey = process.env.PRIVATE_KEY_LOCAL;
  chain = hardhat
  rpcUrl = "http://127.0.0.1:8545";
}
else if (targetChain === "sepolia") {
  privateKey = process.env.PRIVATE_KEY_SEPOLIA;
  chain = sepolia
  rpcUrl = "https://ethereum-sepolia-rpc.publicnode.com";
  ethStorageAddress = '0x804C520d3c084C805E37A35E90057Ac32831F96f'
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

// Setup ethStorage contract
const ethStorageABI = [
  {"inputs":[{"internalType":"bytes32[]","name":"keys","type":"bytes32[]"}],"name":"putBlobs","outputs":[],"stateMutability":"payable","type":"function"},
  {"inputs":[],"name":"upfrontPayment","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
];
const ethStorage = getContract({
  address: ethStorageAddress,
  abi: ethStorageABI,
  client: client,
})
 

// Fetch the upfront payment necessary to store the blob to ethStorage
const upfrontPayment = await ethStorage.read.upfrontPayment()
console.log("EthStorage upfront payment", upfrontPayment)


// Prepare data call
const data = encodeFunctionData({
  abi: ethStorageABI,
  functionName: 'putBlobs',
  args: [['0xa5cc3c03994DB5b0d9A5eEdD10CabaB0813678ACACACACACACACACACACACACAC']]
})

let baseFeePerBlobGas = await getBaseFeePerBlobGas();
let maxFeePerBlobGas = baseFeePerBlobGas * 2n;

// Prepare blob
const blobs = toBlobs({ data: stringToHex('hello world') }) 

// Send transaction
const hash = await client.sendTransaction({
  blobs,
  kzg,
  maxFeePerBlobGas: maxFeePerBlobGas,
  to: ethStorageAddress,
  value: upfrontPayment,
  data: data,
})

// // Prepare blob
// const blobs = toBlobs({ data: stringToHex('hello world') }) 
// // Send transaction
// const hash = await client.sendTransaction({
//   blobs,
//   kzg,
//   maxFeePerBlobGas: maxFeePerBlobGas,
//   to: "0x252641Ee227bD18D874c94a6e4429AE9BA2D8DDd",
//   // // Remplacement
//   // nonce: 52,
//   // maxPriorityFeePerGas: parseGwei('2'), 
// })

console.log("tx hash", hash)

const transaction = await client.waitForTransactionReceipt( 
  { hash: hash }
)
console.log(transaction)