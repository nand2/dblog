import { encodeFunctionData } from 'viem'

export function setupBlogCreation(element, blogFactoryAddress, chainId) {
  const submitButton = element.querySelector('button[type="submit"]')

  // On submut, create a new blog by calling the createBlog method of the BlogFactory contract
  element.querySelector('form').addEventListener('submit', async event => {
    event.preventDefault()
    submitButton.disabled = true
    submitButton.innerHTML = 'Creating...'
    const title = element.querySelector('#title').value
    const description = element.querySelector('#description').value
    const subdomain = element.querySelector('#subdomain').value

    // Request EIP-1193 provider access authorization
    const walletList = await window.ethereum.request({
      "method": "eth_requestAccounts",
      "params": []
    });

    // Request chain change
    await window.ethereum.request({
      "method": "wallet_switchEthereumChain",
      "params": [
        {
          "chainId": "0x" + Number(chainId).toString(16).padStart(2, '0')
        }
      ]
    });
    

    // Prepare the calldata
    const calldata = encodeFunctionData({
      abi: [{
        inputs: [{ name: 'title', type: 'string' }, { name: 'description', type: 'string' }, { name: 'subdomain', type: 'string' }],
        name: 'addBlog',
        outputs: [{ name: 'blog', type: 'address' }],
        type: 'function',
      }],
      args: [title, description, subdomain]
    })
console.log("About to send with args:", title, description, subdomain)
console.log("Calldata", calldata)
console.log("window.ethereum.selectedAddress", walletList[0])

    // Estimate gas
    let gasEstimate = null
    try {
      gasEstimate = await window.ethereum
        .request({
          method: 'eth_estimateGas',
          params: [
            {
              to: blogFactoryAddress,
              from: walletList[0],
              data: calldata,
              gasLimit: '0xf4240',
            }
          ],
        })
    }
    catch (error) {
      console.log("Error", error)
      element.querySelector('#error-message').innerHTML = 'Call failed'
      submitButton.disabled = false
      submitButton.innerHTML = 'Create'
      return
    } 
console.log("gasEstimate", gasEstimate)

    // Use the EIP-1193 Ethereum Provider JavaScript API to call the createBlog method of the BlogFactory contract
    let txHash = null
    try {
      txHash = await window.ethereum
        .request({
          method: 'eth_sendTransaction',
          params: [
            {
              to: blogFactoryAddress,
              from: walletList[0],
              data: calldata,
              gasLimit: '0xf4240',
            }
          ],
        })
    }
    catch (error) {
      console.log("Error", error)
      element.querySelector('#error-message').innerHTML = 'Call failed'
      submitButton.disabled = false
      submitButton.innerHTML = 'Create'
    }    
console.log("txHash", txHash)  

    // Wait for the transaction to be mined
    let txResult = null
    try {
      txResult = await window.ethereum.request({
        "method": "eth_getTransactionReceipt",
        "params": [
          "0x59976834ab49c2cacf304457b80bca777d2f16b8f586f435e2558b430dafb07f"
        ]
      });
    }
    catch (error) {
      console.log("Error", error)
      element.querySelector('#error-message').innerHTML = 'Call failed'
      submitButton.disabled = false
      submitButton.innerHTML = 'Create'
    }
      
console.log("txResult", txResult)

    element.querySelector('#error-message').innerHTML = '';
    submitButton.disabled = false
    submitButton.innerHTML = 'Create'
  })
}
