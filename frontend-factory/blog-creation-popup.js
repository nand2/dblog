import { encodeFunctionData } from 'viem'

export function setupBlogCreationPopup(element, blogFactoryAddress, blogImplementationAddress, chainId, topDomain, domain, createdBlogCallback) {
  // Cancel button behavior
  element.querySelector('#cancel').addEventListener('click', () => {
    element.style.display = 'none'
  })
  // Close button behavior (step 2)
  element.querySelector('#success-close-popup').addEventListener('click', () => {
    element.style.display = 'none'
    element.querySelector('#step-1').style.display = 'block'
    element.querySelector('#step-2').style.display = 'none'
    if(createdBlogCallback) {
      createdBlogCallback()
    }
  })

  // Set the blog implementation address
  // element.querySelector('#blog-implementation-address').textContent = blogImplementationAddress

  // Copy link button behavior
  element.querySelector('#copy-link').addEventListener('click', () => {
    const link = element.querySelector('#created-blog-address a').href
    navigator.clipboard.writeText(link)
  })


  //
  // Subdomain check behavior
  //

  const subdomainInput = element.querySelector('#subdomain')
  const subdomainCheck = element.querySelector('#subdomain-check')
  let timeoutId

  subdomainInput.addEventListener('input', () => {
    clearTimeout(timeoutId)
    timeoutId = setTimeout(() => {
      const subdomain = subdomainInput.value
      if (subdomain.length === 0) {
        return
      }
      subdomainCheck.style.color = '';
      subdomainCheck.innerHTML = 'checking...'
      fetch(`web3://${blogFactoryAddress}:${chainId}/isSubdomainValidAndAvailable/string!${subdomain}?returns=(bool,string)`)
        .then(response => response.json())
        .then(data => {
          if (data[0] == true) {
            subdomainCheck.innerHTML = 'Available'
            subdomainCheck.style.color = 'rgb(0, 180, 0)';
          } else {
            subdomainCheck.innerHTML = 'Unavailable: ' + data[1]
            subdomainCheck.style.color = 'rgb(255, 80, 80)';
          }
        })
        .catch(error => {
          subdomainCheck.innerHTML = 'Call failed'
            subdomainCheck.style.color = 'rgb(255, 80, 80)';
          console.error(error)
        })
    }, 500)
  })


  //
  // Form validation
  //

  const errorMessageDiv = element.querySelector('#error-message')
  const submitButton = element.querySelector('button[type="submit"]')

  // On submit, create a new blog by calling the createBlog method of the BlogFactory contract
  element.querySelector('form').addEventListener('submit', async event => {
    event.preventDefault()
    submitButton.disabled = true
    submitButton.innerHTML = 'Creating...'
    errorMessageDiv.innerHTML = '';
    const title = element.querySelector('#title').value
    const description = element.querySelector('#description').value
    const subdomain = element.querySelector('#subdomain').value

    const stopWithError = (message) => {
      errorMessageDiv.innerHTML = message
      errorMessageDiv.style.display = 'block'
      submitButton.disabled = false
      submitButton.innerHTML = 'Create'
    }

    // Check presence of EI-1193 provider
    if (!window.ethereum) {
      stopWithError('No Ethereum provider found')
      return
    }

    // Request EIP-1193 provider access authorization
    let walletList = null
    try {
      walletList = await window.ethereum.request({
        "method": "eth_requestAccounts",
        "params": []
      });
    }
    catch (error) {
      stopWithError('Wallet authorization failed : ' + error.message)
      return
    }

    // Request chain change
    try {
      await window.ethereum.request({
        "method": "wallet_switchEthereumChain",
        "params": [
          {
            "chainId": "0x" + Number(chainId).toString(16).padStart(2, '0')
          }
        ]
      });
    }
    catch (error) {
      stopWithError('Chain switch failed : ' + error.message)
      return
    }
    

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
    // Prepare the value to send: 0.01eth if subdomain
    let value = '0x0'
    if(subdomain.length > 0) {
      value = '0x' + (0.01 * 10**18).toString(16)
    }

console.log("About to send with args:", title, description, subdomain)
console.log("Calldata", calldata)
console.log("value", value)
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
              value: value,
              gasLimit: '0xf4240',
            }
          ],
        })
    }
    catch (error) {
      stopWithError('Gas estimation failed : ' + error.message)
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
              value: value,
              gasLimit: gasEstimate,
            }
          ],
        })
    }
    catch (error) {
      stopWithError('Call failed : ' + error.message)
      return
    }
console.log("txHash", txHash)  

    // Wait for the transaction to be mined
    let txResult = null
    while(txResult == null) {
      try {
        txResult = await window.ethereum.request({
          "method": "eth_getTransactionReceipt",
          "params": [
            txHash
          ]
        });
      }
      catch (error) {
        stopWithError('Transaction check failed : ' + error.message)
        return
      }
      await new Promise(resolve => setTimeout(resolve, 5000))
    }
      
console.log("txResult", txResult)

    // Take the last log of the transaction, which is the BlogCreated one
    const log = txResult.logs[txResult.logs.length - 1]
    // Get the blog address from the log
    const newBlogAddress = "0x" + log.data.substring(26, 66)
    let newBlogWeb3Address = subdomain ? `web3://${subdomain}.${domain}.${topDomain}` : `web3://${newBlogAddress}`
    newBlogWeb3Address += (chainId > 1 ? `:${chainId}` : '')
console.log("newBlogAddress", newBlogAddress)
console.log("newBlogWeb3Address", newBlogWeb3Address)
    // Inject it in the UI
    element.querySelector('#created-blog-address a').href = newBlogWeb3Address
    element.querySelector('#created-blog-address a').textContent = newBlogWeb3Address
    element.querySelector('#new-blog-address').textContent = newBlogAddress

    // Hide step 1 and show step 2
    submitButton.disabled = false
    submitButton.innerHTML = 'Create'
    element.querySelector('#step-1').style.display = 'none'
    element.querySelector('#create-popup').style.maxWidth = '700px'
    element.querySelector('#step-2').style.display = 'block'


    

  })
}
