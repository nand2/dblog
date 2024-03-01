#! /bin/bash

set -euo pipefail

# Go to the root folder
cd $(dirname $(readlink -f $0))
cd ..

# Load .env file
# CONTRACT_SALT and PRIVATE_KEY must be defined
source .env

# Setup cleanup
function cleanup {
  echo "Cleaning up..."
  # rm -rf dist
}
trap cleanup EXIT

# Build factory
echo "Building factory frontend..."
npm run build-factory

# Compressing output
echo ""
echo "Compressing frontend..."
mkdir -p dist/frontend-factory/assets
# Compress the index.html file
HTML_FILE=index.html
COMPRESSED_HTML_FILE=dblog-index.html.gz
gzip -c frontend-factory/dist/${HTML_FILE} > dist/frontend-factory/${COMPRESSED_HTML_FILE}
# Find out the name of the CSS file in the asset folder and compress it
CSS_FILE=$(ls frontend-factory/dist/assets | grep "css")
COMPRESSED_CSS_FILE=dblog-${CSS_FILE}.gz
gzip -c frontend-factory/dist/assets/${CSS_FILE} > dist/frontend-factory/assets/${COMPRESSED_CSS_FILE}
# Find out the name of the JS file in the asset folder and compress it
JS_FILE=$(ls frontend-factory/dist/assets | grep "js")
COMPRESSED_JS_FILE=dblog-${JS_FILE}.gz
gzip -c frontend-factory/dist/assets/${JS_FILE} > dist/frontend-factory/assets/${COMPRESSED_JS_FILE}

# Launch the DBlogFactoryScript forge script
echo ""
echo "Deploying... "

# Kill and restart anvil
killall anvil || true
anvil 1>/tmp/anvil.log &
# Loop: wait until anvil is ready
while ! grep -q "Listening on 127.0.0.1:8545" /tmp/anvil.log; do
  sleep 0.2
done

# Execute the forge script, copy the output for later processing
exec 5>&1
OUTPUT="$(FACTORY_FRONTEND_HTML_FILE=$COMPRESSED_HTML_FILE \
  FACTORY_FRONTEND_CSS_FILE=$COMPRESSED_CSS_FILE \
  FACTORY_FRONTEND_JS_FILE=$COMPRESSED_JS_FILE \
  forge script DBlogFactoryScript --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 --rpc-url http://127.0.0.1:8545 --broadcast | tee >(cat - >&5))"

# Write again at the end the web3:// address
echo ""
echo "Web3 addresses:"
echo "$OUTPUT" | grep "web3://"
echo "boo"
