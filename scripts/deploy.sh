#! /bin/bash

set -euo pipefail

# Target chain: If empty, default to "local"
# Can be: local, sepolia, holesky, mainnet
TARGET_CHAIN=${1:-local}
# Section: Can be "all", "contracts", "frontend-factory", "frontend-blog". Default to "all"
# Will not work for local chain, as SSTORE2 frontends is used on local chain
SECTION=${2:-all}
# Check that section is in allowed values
if [ "$SECTION" != "all" ] && [ "$SECTION" != "contracts" ] && [ "$SECTION" != "frontend-factory" ] && [ "$SECTION" != "frontend-blog" ]; then
  echo "Invalid section: $SECTION"
  exit 1
fi
# Domain name: If empty, default to "dblog"
DOMAIN=${3:-dblog}

# Setup cleanup
function cleanup {
  echo "Exiting, cleaning up..."
  # rm -rf dist
}
trap cleanup EXIT

# Go to the root folder
cd $(dirname $(readlink -f $0))
cd ..

# Load .env file
# PRIVATE_KEY must be defined
source .env
# Determine the private key and RPC URL to use, and the chain id
PRIVKEY=
RPC_URL=
CHAIN_ID=
if [ "$TARGET_CHAIN" == "local" ]; then
  PRIVKEY=$PRIVATE_KEY_LOCAL
  RPC_URL=http://127.0.0.1:8545
  CHAIN_ID=31337
elif [ "$TARGET_CHAIN" == "sepolia" ]; then
  PRIVKEY=$PRIVATE_KEY_SEPOLIA
  RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
  CHAIN_ID=11155111
elif [ "$TARGET_CHAIN" == "holesky" ]; then
  PRIVKEY=$PRIVATE_KEY_HOLESKY
  RPC_URL=https://ethereum-holesky-rpc.publicnode.com
  CHAIN_ID=17000
fi


# Timestamp
TIMESTAMP=$(date +%s)



# Build factory
echo "Building factory frontend..."
npm run build-factory

# Compressing output
echo ""
echo "Compressing factory frontend..."
mkdir -p dist/frontend-factory/assets
# Compress the index.html file
FACTORY_FRONTEND_HTML_FILE=index.html
FACTORY_FRONTEND_COMPRESSED_HTML_FILE=${DOMAIN}-factory-${TIMESTAMP}-index.html.gz
gzip -c frontend-factory/dist/${FACTORY_FRONTEND_HTML_FILE} > dist/frontend-factory/${FACTORY_FRONTEND_COMPRESSED_HTML_FILE}
# Find out the name of the CSS file in the asset folder and compress it
FACTORY_FRONTEND_CSS_FILE=$(ls frontend-factory/dist/assets | grep "css")
FACTORY_FRONTEND_COMPRESSED_CSS_FILE=${DOMAIN}-factory-${TIMESTAMP}-${FACTORY_FRONTEND_CSS_FILE}.gz
gzip -c frontend-factory/dist/assets/${FACTORY_FRONTEND_CSS_FILE} > dist/frontend-factory/assets/${FACTORY_FRONTEND_COMPRESSED_CSS_FILE}
# Find out the name of the JS file in the asset folder and compress it
FACTORY_FRONTEND_JS_FILE=$(ls frontend-factory/dist/assets | grep "js")
FACTORY_FRONTEND_COMPRESSED_JS_FILE=${DOMAIN}-factory-${TIMESTAMP}-${FACTORY_FRONTEND_JS_FILE}.gz
gzip -c frontend-factory/dist/assets/${FACTORY_FRONTEND_JS_FILE} > dist/frontend-factory/assets/${FACTORY_FRONTEND_COMPRESSED_JS_FILE}

# Build blog
echo "Building blog frontend..."
npm run build-blog

# Compressing output
echo ""
echo "Compressing blog frontend..."
mkdir -p dist/frontend-blog/assets
# Compress the index.html file
BLOG_FRONTEND_HTML_FILE=index.html
BLOG_FRONTEND_COMPRESSED_HTML_FILE=${DOMAIN}-${TIMESTAMP}-index.html.gz
gzip -c frontend-blog/dist/${BLOG_FRONTEND_HTML_FILE} > dist/frontend-blog/${BLOG_FRONTEND_COMPRESSED_HTML_FILE}
# Find out the name of the CSS file in the asset folder and compress it
BLOG_FRONTEND_CSS_FILE=$(ls frontend-blog/dist/assets | grep "css")
BLOG_FRONTEND_COMPRESSED_CSS_FILE=${DOMAIN}-${TIMESTAMP}-${BLOG_FRONTEND_CSS_FILE}.gz
gzip -c frontend-blog/dist/assets/${BLOG_FRONTEND_CSS_FILE} > dist/frontend-blog/assets/${BLOG_FRONTEND_COMPRESSED_CSS_FILE}
# Find out the name of the biggest JS file in the asset folder and compress it
# (there should only be one, but sometimes the bundler put a unused tiny bit on another file, 
# which need to be debugged)
BLOG_FRONTEND_JS_FILE=$(ls -S frontend-blog/dist/assets | grep "js" | head -n 1)
BLOG_FRONTEND_COMPRESSED_JS_FILE=${DOMAIN}-${TIMESTAMP}-${BLOG_FRONTEND_JS_FILE}.gz
gzip -c frontend-blog/dist/assets/${BLOG_FRONTEND_JS_FILE} > dist/frontend-blog/assets/${BLOG_FRONTEND_COMPRESSED_JS_FILE}
# Find out the name of the wasm file in the asset folder and compress it
BLOG_FRONTEND_WASM_FILE=$(ls frontend-blog/dist/assets | grep "wasm")
BLOG_FRONTEND_COMPRESSED_WASM_FILE=${DOMAIN}-${TIMESTAMP}-${BLOG_FRONTEND_WASM_FILE}.gz
gzip -c frontend-blog/dist/assets/${BLOG_FRONTEND_WASM_FILE} > dist/frontend-blog/assets/${BLOG_FRONTEND_COMPRESSED_WASM_FILE}


# Section contracts: Deploy the contracts
if [ "$SECTION" == "all" ] || [ "$SECTION" == "contracts" ]; then

  # Testnet : get back the domain we sent to DBlogFactory
  if [ "$TARGET_CHAIN" != "mainnet" ] && [ "$TARGET_CHAIN" != "local" ]; then
    echo ""
    echo "Fetching back domain ..."

    DBLOGFACTORY_ADDRESS=$(cat contracts/broadcast/DBlogFactory.s.sol/${CHAIN_ID}/run-latest.json | jq -r '[.transactions[] | select(.contractName == "DBlogFactory")][0].contractAddress')
    echo $DBLOGFACTORY_ADDRESS
    cast send --private-key ${PRIVKEY} --rpc-url ${RPC_URL}  $DBLOGFACTORY_ADDRESS "testnetSendBackDomain()"
  fi


  # Launch the DBlogFactoryScript forge script
  echo ""
  echo "Deploying... "

  # Local target chain: Kill and restart anvil
  if [ "$TARGET_CHAIN" == "local" ]; then
    killall anvil || true
    anvil --gas-limit 500000000 1>/tmp/anvil.log &
    # Loop: wait until anvil is ready
    while ! grep -q "Listening on 127.0.0.1:8545" /tmp/anvil.log; do
      sleep 0.2
    done
  fi


  # Execute the forge script, copy the output for later processing
  FORGE_SCRIPT_OPTIONS=
  if [ "$TARGET_CHAIN" == "local" ]; then
    # 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
    FORGE_SCRIPT_OPTIONS="--broadcast"
  elif [ "$TARGET_CHAIN" == "sepolia" ]; then
    # 0xAafA7E1FBE681de12D41Ef9a5d5206A96963390e
    FORGE_SCRIPT_OPTIONS="--broadcast"
  elif [ "$TARGET_CHAIN" == "holesky" ]; then
    # 0xAafA7E1FBE681de12D41Ef9a5d5206A96963390e
    FORGE_SCRIPT_OPTIONS="--broadcast --verify"
  fi
  exec 5>&1
  OUTPUT="$(FACTORY_FRONTEND_HTML_FILE=$FACTORY_FRONTEND_HTML_FILE \
    FACTORY_FRONTEND_CSS_FILE=$FACTORY_FRONTEND_CSS_FILE \
    FACTORY_FRONTEND_JS_FILE=$FACTORY_FRONTEND_JS_FILE \
    FACTORY_FRONTEND_COMPRESSED_HTML_FILE=$FACTORY_FRONTEND_COMPRESSED_HTML_FILE \
    FACTORY_FRONTEND_COMPRESSED_CSS_FILE=$FACTORY_FRONTEND_COMPRESSED_CSS_FILE \
    FACTORY_FRONTEND_COMPRESSED_JS_FILE=$FACTORY_FRONTEND_COMPRESSED_JS_FILE \
    BLOG_FRONTEND_HTML_FILE=$BLOG_FRONTEND_HTML_FILE \
    BLOG_FRONTEND_CSS_FILE=$BLOG_FRONTEND_CSS_FILE \
    BLOG_FRONTEND_JS_FILE=$BLOG_FRONTEND_JS_FILE \
    BLOG_FRONTEND_WASM_FILE=$BLOG_FRONTEND_WASM_FILE \
    BLOG_FRONTEND_COMPRESSED_HTML_FILE=$BLOG_FRONTEND_COMPRESSED_HTML_FILE \
    BLOG_FRONTEND_COMPRESSED_CSS_FILE=$BLOG_FRONTEND_COMPRESSED_CSS_FILE \
    BLOG_FRONTEND_COMPRESSED_JS_FILE=$BLOG_FRONTEND_COMPRESSED_JS_FILE \
    BLOG_FRONTEND_COMPRESSED_WASM_FILE=$BLOG_FRONTEND_COMPRESSED_WASM_FILE \
    TARGET_CHAIN=$TARGET_CHAIN \
    DOMAIN=$DOMAIN \
    forge script DBlogFactoryScript --private-key ${PRIVKEY} --rpc-url ${RPC_URL}  $FORGE_SCRIPT_OPTIONS | tee >(cat - >&5))"


  # Write again at the end the web3:// address
  # echo ""
  # echo "ENS:"
  # echo "$OUTPUT" | grep "ENS registry:"
  echo ""
  echo "Web3 addresses:"
  echo "$OUTPUT" | grep "web3://"

fi


# Do the EthStorage uploads. Unfortunately, since blobs are involved, we need to to it outside
# the main solidity script
if [ "$TARGET_CHAIN" != "local" ]; then
  # Section frontend-factory: Upload the factory frontend
  if [ "$SECTION" == "all" ] || [ "$SECTION" == "frontend-factory" ]; then
    # Upload blog factory frontend as blobs to EthStorage
    # Fetch the address of the DBlogFactoryFrontend
    DBLOGFACTORY_FRONTEND_ADDRESS=$(cat contracts/broadcast/DBlogFactory.s.sol/${CHAIN_ID}/run-latest.json | jq -r '[.transactions[] | select(.contractName == "DBlogFactoryFrontend")][0].contractAddress')
    # Do the uploading
    echo ""
    echo "Uploading frontend to DBlogFactoryFrontend ($DBLOGFACTORY_FRONTEND_ADDRESS) ..."
    node --env-file=.env scripts/upload-ethstorage-frontend.js \
      $TARGET_CHAIN $DBLOGFACTORY_FRONTEND_ADDRESS \
      ${FACTORY_FRONTEND_HTML_FILE}:dist/frontend-factory/${FACTORY_FRONTEND_COMPRESSED_HTML_FILE} \
      assets/${FACTORY_FRONTEND_CSS_FILE}:dist/frontend-factory/assets/${FACTORY_FRONTEND_COMPRESSED_CSS_FILE} \
      assets/${FACTORY_FRONTEND_JS_FILE}:dist/frontend-factory/assets/${FACTORY_FRONTEND_COMPRESSED_JS_FILE}
  fi


  # Section frontend-blog: Upload the blog frontend
  if [ "$SECTION" == "all" ] || [ "$SECTION" == "frontend-blog" ]; then
    # Upload blog frontend as blobs to EthStorage
    # Fetch the address of the DBlogFrontendLibrary
    DBLOGFRONTEND_LIBRARY_ADDRESS=$(cat contracts/broadcast/DBlogFactory.s.sol/${CHAIN_ID}/run-latest.json | jq -r '[.transactions[] | select(.contractName == "DBlogFrontendLibrary")][0].contractAddress')
    # Do the uploading
    echo ""
    echo "Uploading frontend to DBlogFrontendLibrary ($DBLOGFRONTEND_LIBRARY_ADDRESS) ..."
    node --env-file=.env scripts/upload-ethstorage-frontend.js \
      $TARGET_CHAIN $DBLOGFRONTEND_LIBRARY_ADDRESS \
      ${BLOG_FRONTEND_HTML_FILE}:dist/frontend-blog/${BLOG_FRONTEND_COMPRESSED_HTML_FILE} \
      assets/${BLOG_FRONTEND_CSS_FILE}:dist/frontend-blog/assets/${BLOG_FRONTEND_COMPRESSED_CSS_FILE} \
      assets/${BLOG_FRONTEND_JS_FILE}:dist/frontend-blog/assets/${BLOG_FRONTEND_COMPRESSED_JS_FILE} \
      assets/${BLOG_FRONTEND_WASM_FILE}:dist/frontend-blog/assets/${BLOG_FRONTEND_COMPRESSED_WASM_FILE}
  fi
fi