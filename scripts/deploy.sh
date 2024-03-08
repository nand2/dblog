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
echo "Compressing factory frontend..."
mkdir -p dist/frontend-factory/assets
# Compress the index.html file
FACTORY_FRONTEND_HTML_FILE=index.html
FACTORY_FRONTEND_COMPRESSED_HTML_FILE=dblog-factory-index.html.gz
gzip -c frontend-factory/dist/${FACTORY_FRONTEND_HTML_FILE} > dist/frontend-factory/${FACTORY_FRONTEND_COMPRESSED_HTML_FILE}
# Find out the name of the CSS file in the asset folder and compress it
FACTORY_FRONTEND_CSS_FILE=$(ls frontend-factory/dist/assets | grep "css")
FACTORY_FRONTEND_COMPRESSED_CSS_FILE=dblog-factory-${FACTORY_FRONTEND_CSS_FILE}.gz
gzip -c frontend-factory/dist/assets/${FACTORY_FRONTEND_CSS_FILE} > dist/frontend-factory/assets/${FACTORY_FRONTEND_COMPRESSED_CSS_FILE}
# Find out the name of the JS file in the asset folder and compress it
FACTORY_FRONTEND_JS_FILE=$(ls frontend-factory/dist/assets | grep "js")
FACTORY_FRONTEND_COMPRESSED_JS_FILE=dblog-factory-${FACTORY_FRONTEND_JS_FILE}.gz
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
BLOG_FRONTEND_COMPRESSED_HTML_FILE=dblog-index.html.gz
gzip -c frontend-blog/dist/${BLOG_FRONTEND_HTML_FILE} > dist/frontend-blog/${BLOG_FRONTEND_COMPRESSED_HTML_FILE}
# Find out the name of the CSS file in the asset folder and compress it
BLOG_FRONTEND_CSS_FILE=$(ls frontend-blog/dist/assets | grep "css")
BLOG_FRONTEND_COMPRESSED_CSS_FILE=dblog-${BLOG_FRONTEND_CSS_FILE}.gz
gzip -c frontend-blog/dist/assets/${BLOG_FRONTEND_CSS_FILE} > dist/frontend-blog/assets/${BLOG_FRONTEND_COMPRESSED_CSS_FILE}
# Find out the name of the JS file in the asset folder and compress it
BLOG_FRONTEND_JS_FILE=$(ls frontend-blog/dist/assets | grep "js")
BLOG_FRONTEND_COMPRESSED_JS_FILE=dblog-${BLOG_FRONTEND_JS_FILE}.gz
gzip -c frontend-blog/dist/assets/${BLOG_FRONTEND_JS_FILE} > dist/frontend-blog/assets/${BLOG_FRONTEND_COMPRESSED_JS_FILE}


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
OUTPUT="$(FACTORY_FRONTEND_HTML_FILE=$FACTORY_FRONTEND_COMPRESSED_HTML_FILE \
  FACTORY_FRONTEND_CSS_FILE=$FACTORY_FRONTEND_COMPRESSED_CSS_FILE \
  FACTORY_FRONTEND_JS_FILE=$FACTORY_FRONTEND_COMPRESSED_JS_FILE \
  BLOG_FRONTEND_HTML_FILE=$BLOG_FRONTEND_COMPRESSED_HTML_FILE \
  BLOG_FRONTEND_CSS_FILE=$BLOG_FRONTEND_COMPRESSED_CSS_FILE \
  BLOG_FRONTEND_JS_FILE=$BLOG_FRONTEND_COMPRESSED_JS_FILE \
  forge script DBlogFactoryScript --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 --rpc-url http://127.0.0.1:8545 --broadcast | tee >(cat - >&5))"


# Write again at the end the web3:// address
echo ""
echo "Web3 addresses:"
echo "$OUTPUT" | grep "web3://"
echo "boo"
