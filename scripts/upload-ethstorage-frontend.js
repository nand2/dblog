import { createWalletClient, http, publicActions, toBlobs, toHex, setupKzg, encodeFunctionData, getContract } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet, sepolia, holesky, hardhat } from 'viem/chains'
import { default as cKzg } from 'c-kzg'
import path from 'path';
import {fileURLToPath} from 'url';
import fs from 'fs'
import mime from 'mime';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Read first argument: targetChain. Default to "local"
const targetChain = process.argv[2] || "local"

// Read second argument : contract address of the frontend
const frontendAddress = process.argv[3]

// Read all remaining arguments: files to upload, in the format: <htmlFilePath>:<diskFilePath>
// where htmlFilePath is the path to which it should answer on the web3:// protocol, and
// diskFilePath is the path to the file on disk
let files = []
for (let i = 4; i < process.argv.length; i++) {
  files.push({
    htmlFilePath: process.argv[i].split(":")[0],
    diskFilePath: process.argv[i].split(":")[1]
  })
}

console.log(`Uploading to ${frontendAddress} on ${targetChain} chain : `)
files.forEach(file => console.log(`  - ${file.htmlFilePath} from ${file.diskFilePath}`))


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
  rpcUrl = process.env.RPC_SEPOLIA || "https://ethereum-sepolia-rpc.publicnode.com";
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
  {
    "inputs":[
      {
        "components":[
          {"internalType":"string","name":"filePath","type":"string"},
          {"internalType":"string","name":"contentType","type":"string"},
          {"internalType":"uint256[]","name":"blobIndexes","type":"uint256[]"},
          {"internalType":"uint256[]","name":"blobDataSizes","type":"uint256[]"}
        ],
        "internalType":"struct DBlogFrontendLibrary.EthStorageFileUploadInfos[]",
        "name":"files",
        "type":"tuple[]"
      },
      {"internalType":"string","name":"_infos","type":"string"}
    ],
    "name":"addEthStorageFrontendVersion",
    "outputs":[],"stateMutability":"payable","type":"function"
  },
  {
    "inputs":[],
    "name":"getEthStorageUpfrontPayment",
    "outputs":[{"internalType":"uint256","name":"","type":"uint256"}],
    "stateMutability":"view","type":"function"
  }
];
const frontendContract = getContract({
  address: frontendAddress,
  abi: frontendABI,
  client: client,
})
 

// Fetch the upfront payment necessary to store the blob to ethStorage
const upfrontPayment = await frontendContract.read.getEthStorageUpfrontPayment()
console.log("EthStorage upfront payment", upfrontPayment)


let baseFeePerBlobGas = await getBaseFeePerBlobGas();
let maxFeePerBlobGas = baseFeePerBlobGas * 4n;

// Prepare the args
let fileArgs = []
let blobs = []
const fullBlobDataSize = (32 - 1) * 4096;
files.forEach((file, index) => {
  // Determine mime type of the file
  let mimeType = mime.getType(file.htmlFilePath.split('.').pop())
  if(mimeType == "") {
    console.log("ERROR: unknown mime type for file", file.htmlFilePath)
    process.exit(1);
  }
  
  const data = fs.readFileSync(file.diskFilePath);
  const fileBlobs = toBlobs({ data: toHex(data) })

  let fileBlobIndexes = []
  let fileBlobDataSizes = []
  let remaningDataSize = Buffer.byteLength(data)
  for(let i = 0; i < fileBlobs.length; i++) {
    blobs.push(fileBlobs[i])
    fileBlobIndexes.push(blobs.length - 1)
    if(i < fileBlobs.length - 1) {
      fileBlobDataSizes.push(fullBlobDataSize)
    }
    else {
      fileBlobDataSizes.push(remaningDataSize)
    }
    remaningDataSize -= fileBlobDataSizes[fileBlobDataSizes.length - 1]
  }

  fileArgs.push([
    file.htmlFilePath,
    mimeType,
    fileBlobIndexes,
    fileBlobDataSizes,
  ])
})

// Prepare data call
const args = [
  fileArgs,
  'Initial version'
]
const data = encodeFunctionData({
  abi: frontendABI,
  functionName: 'addEthStorageFrontendVersion',
  args: args,
})

// Send transaction
const hash = await client.sendTransaction({
  blobs,
  kzg,
  maxFeePerBlobGas: maxFeePerBlobGas,
  to: frontendAddress,
  value: upfrontPayment * BigInt(blobs.length),
  data: data,
  gas: 1000000n, // Weirdly I need this on sepolia
  // Replace tx:
  // nonce: 748,
  // maxPriorityFeePerGas: 53776n * 2n,
})
console.log("tx hash", hash)

const transaction = await client.waitForTransactionReceipt( 
  { hash: hash }
)
console.log(transaction)