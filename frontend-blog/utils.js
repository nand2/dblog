export function strip_tags(text) {
  return text.replace(/(<[^>]+>)/g, "");
}

// Uint8Array to hex string
export function uint8ArrayToHexString(byteArray) {
  return Array.from(byteArray, function(byte) {
      return ('0' + (byte & 0xFF).toString(16)).slice(-2);
  }).join('');
}

// Automatic window.location parsing will break
// We do our own parsing
export function parseWeb3Url(web3Url) {
  let matchResult = web3Url.match(/^(?<protocol>[^:]+):\/\/(?<hostname>[^:\/?]+)(:(?<chainId>[1-9][0-9]*))?(?<path>.*)?$/)
  if(matchResult == null) {
    throw new Error("Failed basic parsing of the URL");
  }

  return matchResult.groups;
}