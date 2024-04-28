import { markdown } from './drawdown.js'
import { strip_tags, uint8ArrayToHexString, parseWeb3Url, getBaseFeePerBlobGas } from './utils.js'
import { encodeParameters } from '@zoltu/ethereum-abi-encoder'
import { createPublicClient, createWalletClient, custom, publicActions, toBlobs, toHex, setupKzg, encodeFunctionData, stringToHex, blobsToCommitments, commitmentsToVersionedHashes, blobsToProofs, defineChain, http, formatEther, fromHex } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia, mainnet, anvil } from 'viem/chains'
import { loadKZG } from 'kzg-wasm'
import mime from 'mime';


// Frontent contract ABI
// All write functions, as we are using web3:// for read functions
const frontendABI = [
  {
    inputs: [{ name: 'title', type: 'string' }, { name: 'blobDataSize', type: 'uint256' }],
    name: 'addPostOnEthStorage',
    outputs: [],
    type: 'function',
  },
  {
    inputs: [{ name: 'id', type: 'uint256' }, { name: 'title', type: 'string' }, { name: 'blobDataSize', type: 'uint256' }],
    name: 'editEthStoragePost',
    outputs: [],
    type: 'function',
  },
  {
    inputs: [{ name: 'title', type: 'string' }, { name: 'content', type: 'string' }],
    name: 'addPostOnEthereumState',
    outputs: [],
    type: 'function',
  },
  {
    inputs: [{ name: 'id', type: 'uint256' }, { name: 'title', type: 'string' }, { name: 'content', type: 'string' }],
    name: 'editEthereumStatePost',
    outputs: [],
    type: 'function',
  },
  {
    inputs: [{ name: 'editor', type: 'address' }],
    name: 'addEditor',
    outputs: [],
    type: 'function',
  },
  {
    inputs: [{ name: 'editor', type: 'address' }],
    name: 'removeEditor',
    outputs: [],
    type: 'function',
  },
  {
    inputs: [{ name: 'fileName', type: 'string' }, { name: 'contentType', type: 'string' }, { name: 'blobsCount', type: 'uint256' }, { name: 'blobDataSizes', type: 'uint256[]' }],
    name: 'addUploadedFileOnEthStorage',
    outputs: [],
    type: 'function',
  },
  {
    inputs: [{ name: 'fileName', type: 'string' }, { name: 'blobDataSizes', type: 'uint256[]' }],
    name: 'completeUploadedFileOnEthStorage',
    outputs: [],
    type: 'function',
  },
  {
    inputs: [{ name: 'filePath', type: 'string' }, { name: 'contentType', type: 'string' }, { name: 'fileContents', type: 'bytes' }],
    name: 'addUploadedFileOnEthfs',
    outputs: [],
    type: 'function',
  }
];

async function sendTransaction(blogAddress, chainId, methodName, args, opts) {
  // Put default options in opts
  opts = opts || {}
  opts.blobs = opts.blobs || []
  opts.value = opts.value || 0n
  opts.burnerWalletPrivateKey = opts.burnerWalletPrivateKey || null
  opts.burnerWalletRequiredToBeEditor = opts.burnerWalletRequiredToBeEditor || false
  opts.burnerWalletSavePrivateKeyToLocalStorage = opts.burnerWalletSavePrivateKeyToLocalStorage || false

  // Determine if we are using a burner wallet
  let burnerWallet = null
  if(opts.burnerWalletPrivateKey) {
    try {
      burnerWallet = privateKeyToAccount(opts.burnerWalletPrivateKey)
    }
    catch (error) {
      throw new Error('Burner wallet private key is invalid')
    }
    // Store it on localStorage as the default burner wallet we are now using
    if(opts.burnerWalletSavePrivateKeyToLocalStorage) {
      try {
        localStorage.setItem('burnerPrivateKey', opts.burnerWalletPrivateKey)
      }
      catch (error) {
        // Do nothing. We know localstorage support is not available in EVM browser
      }
    }
  }

  // Check presence of EIP-1193 provider
  if (burnerWallet == null && !window.ethereum) {
    stopWithError('No Ethereum provider found')
    return
  }

  // Prepare a Viem client
  let accountAddress = null
  let createWalletClientOpts = {
    transport: custom(window.ethereum)
  }
  if(burnerWallet) {
    accountAddress = burnerWallet
    // Ideally we should use custom(window.ethereum) to pipe through request to the main wallet
    // it seems to be issues with the presence of blobs
    // So we use our own http transport with the embedded RPC endpoints of the viem lib
    let transport = http()
    createWalletClientOpts = {
      account: burnerWallet,
      chain: chainId == 31337 ? anvil : chainId == 11155111 ? sepolia : mainnet,
      transport: transport
    }
  }
  const viemClient = createWalletClient(createWalletClientOpts).extend(publicActions)

  // Burner wallet: check that there are funds in the wallet (this will be a regular error)
  if(burnerWallet) {
    const walletBalance = await viemClient.getBalance({address: burnerWallet.address})
    if(walletBalance == 0n) {
      throw new Error('Burner wallet ' + burnerWallet.address + ' has no funds')
    }
  }

  // Burner wallet: Check that the wallet is an editor
  // If not, we will ask the user to add the burner wallet as an editor
  if(opts.burnerWalletRequiredToBeEditor && burnerWallet) {
    let editors = []
    await fetch(`web3://${blogAddress}:${chainId}/getEditors?returns=(address[])`)
      .then(response => response.json())
      .then(data => {
        editors = data[0]
      })
      .catch(error => {
        throw new Error('Editors fetching failed : ' + error.message)
      })
    
    if(editors.includes(burnerWallet.address) == false) {
      alert("The burner wallet needs to be added as an editor to be able to post. We will now ask you to sign a transaction to add the burner wallet as an editor.")
      
      try {
        await sendTransaction(blogAddress, chainId, "addEditor", [burnerWallet.address]);
      }
      catch (error) {
        throw new Error(error.message)
      }
    }
  }

  // Request the address to use, if not using the burner wallet
  if(burnerWallet == null) {
    try {
      let accounts = await viemClient.requestAddresses()
      accountAddress = accounts[0]
    }
    catch (error) {
      throw new Error('Address fetching failed : ' + error.message)
    }
  }

  // Request chain change, if not using the burner wallet
  if(burnerWallet == null) {
    try {
      await viemClient.switchChain({ id: chainId }) 
    }
    catch (error) {
      throw new Error('Chain switch failed : ' + error.message)
    }
  }

  // Prepare the calldata
  const calldata = encodeFunctionData({
    abi: frontendABI,
    functionName: methodName,
    args: args
  })

console.log("About to call", methodName, "with args", args)
console.log("Calldata", calldata)
console.log("value", opts.value)
console.log("blobs length", opts.blobs.length)

  // Prepare transaction
  const transactionOpts = {
    chain: defineChain({
      id: chainId,
    }),
    account: accountAddress,
    to: blogAddress,
    data: calldata,
    value: opts.value,
  }
  if(opts.blobs.length > 0) {
    // Prepare the KZG setup
    const wasmKzg = await loadKZG()
    const kzg = setupKzg(wasmKzg)

    transactionOpts.blobs = opts.blobs;
    transactionOpts.kzg = kzg;
    let block = await viemClient.getBlock();
    transactionOpts.maxFeePerBlobGas = getBaseFeePerBlobGas(block.excessBlobGas ?? 0n) * 2n;
  }
console.log("transactionOpts", transactionOpts)

  // Send transaction
  let txHash = null;
  try {
    txHash = await viemClient.sendTransaction(transactionOpts)
  }
  catch (error) {
    console.log('Transaction failed : ' + error.message)
    throw new Error('Transaction failed : ' + error.details)
  }
console.log("txHash", txHash)

  // Wait for the transaction to be mined
  let txResult = null;
  try {
    txResult = await viemClient.waitForTransactionReceipt( 
      { hash: txHash }
    )
  }
  catch (error) {
    throw new Error('Failed to fetch the transaction result : ' + error.message)
  }

  return txResult;
}


/**
 * Home controller
 */
export async function homeController(blogAddress, chainId) {
  // Remove the blog posts
  const blogEntries = document.getElementById('blog-entries')
  blogEntries.innerHTML = ''

  // Call the blog to fetch the posts
  let posts = []
  await fetch(`web3://${blogAddress}:${chainId}/getPosts?returns=((string,uint256,string)[])`)
    .then(response => response.json())
    .then(data => {
      console.log("Fetched posts : ", data)
      // The blogs are returned as a an array of array, we convert that into an array of objects
      posts = data[0].map((post, index) => {
        return {
          id: index,
          title: post[0],
          date: post[1],
          content: post[2],
        }
      })
    })
    .catch(error => {
      console.error(error)
    })

    // Insert the posts
    if(posts.length == 0) {
      blogEntries.innerHTML = `
        <div class="blog-entry">
          <h2 class="title"><a href="/#/add">Add your first post</a></h2>
        </div>
      `;
    }
    posts.reverse().forEach(post => {
      let blogEntry = document.createElement('div')
      blogEntry.className = 'blog-entry'
      const options = { year: 'numeric', month: 'long', day: 'numeric' };
      const formattedDate = new Date(post.date * 1000).toLocaleDateString(undefined, options);
      blogEntry.innerHTML = `
        <div class="date">${formattedDate}</div>
        <h2 class="title"><a href="/#/entry/${post.id}">${strip_tags(post.title)}</a></h2>
      `;
      blogEntries.appendChild(blogEntry)
    })
}


/**
 * Singe blog post controller
 */
export async function blogEntryController(blogAddress, chainId) {
  const page = document.getElementById('page-entry');

  // Clear the post
  page.querySelector('h2').innerHTML = ''
  page.querySelector('.date').innerHTML = ''
  page.querySelector('.blog-entry-content').innerHTML = ''

  // Extract the post number from the URL
  let parsedUrl = parseWeb3Url(window.location.href)
  const postNumber = parseInt(parsedUrl.path.split('/').pop())

  // Call the blog to fetch the post
  let post = null
  await fetch(`web3://${blogAddress}:${chainId}/getPost/${postNumber}?returns=(string,uint256,string,bytes32)`)
    .then(response => response.json())
    .then(data => {
      console.log("Fetched post : ", data)
      post = {
        title: data[0],
        date: data[1],
        ethereumStateContent: data[2],
        ethStorageContentKey: data[3],
      }
    })
    .catch(error => {
      console.error(error)
    })

  // Get the content, from EthStorage or from Ethereum state
  let content = ''
  if(post.ethStorageContentKey != "0x0000000000000000000000000000000000000000000000000000000000000000") {
    // Determine which EthStorage chain to use
    let ethStorageChainId = 333
    if(chainId != 1) {
      ethStorageChainId = 3333
    }
    // Call the EthStorage to fetch the content
    await fetch(`web3://${blogAddress}:${ethStorageChainId}/getPostEthStorageContent/${postNumber}?returns=(string)`)
      .then(response => response.json())
      .then(data => {
        console.log("Fetched blog ethstorage content : ", data)
        content = data[0]
      })
      .catch(error => {
        console.error(error)
      })
  }
  else {
    content = post.ethereumStateContent;
  }

  // Insert the post
  page.querySelector('h2').innerHTML = strip_tags(post.title)
  const options = { year: 'numeric', month: 'long', day: 'numeric' };
  const formattedDate = new Date(post.date * 1000).toLocaleDateString(undefined, options);
  page.querySelector('.date').innerHTML = formattedDate
  page.querySelector('.blog-entry-content').innerHTML = markdown(strip_tags(content))
}


/**
 * Admin page controller
 */
export async function adminController(blogAddress, chainId) { 
  // Remove the blog posts
  const blogEntries = document.getElementById('admin-blog-entries')
  blogEntries.innerHTML = ''

  // Call the blog to fetch the posts
  let posts = []
  await fetch(`web3://${blogAddress}:${chainId}/getPosts?returns=((string,uint256,string)[])`)
    .then(response => response.json())
    .then(data => {
      console.log("Fetched posts : ", data)
      // The blogs are returned as a an array of array, we convert that into an array of objects
      posts = data[0].map((post, index) => {
        return {
          id: index,
          title: post[0],
          date: post[1],
          content: post[2],
        }
      })
    })
    .catch(error => {
      console.error(error)
    })

  // Insert the posts
  posts.reverse().forEach(post => {
    let blogEntry = document.createElement('div')
    blogEntry.className = 'blog-entry'
    const formattedDate = new Date(post.date * 1000).toISOString().split('T')[0];
    blogEntry.innerHTML = `
      <span class="date">${formattedDate}</span>
      <a href="/#/entry/${post.id}">${strip_tags(post.title)}</a> - <a href="/#/entry/${post.id}/edit">edit</a>
    `;
    blogEntries.appendChild(blogEntry)
  })

  const loadEditorsInterface = async () => {
    // Call the blog to get the owner
    let owner = null
    await fetch(`web3://${blogAddress}:${chainId}/owner?returns=(address)`)
      .then(response => response.json())
      .then(data => {
        console.log("Fetched owner : ", data)
        owner = data[0]
      })
      .catch(error => {
        console.error(error)
      })

    // Call the blog to fetch the editors
    let editors = []
    await fetch(`web3://${blogAddress}:${chainId}/getEditors?returns=(address[])`)
      .then(response => response.json())
      .then(data => {
        console.log("Fetched editors : ", data)
        editors = data[0]
      })
      .catch(error => {
        console.error(error)
      })
    
    // Insert the owner and editors
    const adminEditors = document.getElementById('admin-editors')
    adminEditors.innerHTML = ''
    let ownerDiv = document.createElement('div')
    ownerDiv.className = 'editor'
    ownerDiv.innerHTML = `<span>${owner}</span> (blog owner)`
    adminEditors.appendChild(ownerDiv)
    editors.forEach(editor => {
      let editorDiv = document.createElement('div')
      editorDiv.className = 'editor'
      editorDiv.innerHTML = `<span>${editor}</span> <button type="button" class="admin-remove-editor" editor-address="${editor}">Remove</button>`
      adminEditors.appendChild(editorDiv)
    })

    // Add the event listener to remove editors
    const removeEditorButtons = document.querySelectorAll('.admin-remove-editor')
    removeEditorButtons.forEach(button => {
      button.addEventListener('click', async (event) => {
        const addressToRemove = event.target.getAttribute('editor-address')
        if(confirm(`Are you sure you want to remove ${addressToRemove} as an editor?`) == false) {
          return;
        }
        
        try {
          await sendTransaction(blogAddress, chainId, "removeEditor", [addressToRemove]);
        }
        catch (error) {
          alert(error.message)
          return
        }

        loadEditorsInterface()
      })
    })
  }
  loadEditorsInterface()

  // Add an event listener to add a new editor
  const addEditorButton = document.getElementById('admin-add-editor')
  const addEditorButtonClickHandler = async (event) => {
    event.preventDefault()
    const newEditorAddress = document.getElementById('admin-new-editor-address').value
    // If not the right format, skip
    const ethereumAddressRegex = /^0x[a-fA-F0-9]{40}$/;
    if (!ethereumAddressRegex.test(newEditorAddress)) {
      alert('Invalid Ethereum address');
      return
    }

    try {
      await sendTransaction(blogAddress, chainId, "addEditor", [newEditorAddress]);
    }
    catch (error) {
      alert(error.message)
      return
    }

    loadEditorsInterface()
  }
  if(addEditorButton.hasAttribute('data-event-listener-added') == false) {
    addEditorButton.addEventListener('click', addEditorButtonClickHandler)
    addEditorButton.setAttribute('data-event-listener-added', 'true')
  }
}


/**
 * Add/Edit blog post controller
 */
export async function entryEditController(blogAddress, chainId) {
  const page = document.getElementById('page-entry-edit');
  
  // Reinit fields
  page.querySelector('#title').value = ''
  page.querySelector('#content').value = ''
  page.querySelector('#burner-address-private-key').value = ''

  // Determine if we are adding or editing by checking if the URL start with /add
  let parsedUrl = parseWeb3Url(window.location.href)
  const newPost = parsedUrl.path.startsWith('/#/add')
  // If not a new post, fetch the post number from the URL
  const postNumber = newPost ? null : parseInt(parsedUrl.path.split('/')[3])
  // Store the postNumber in the form
  page.querySelector('#post-number').value = postNumber

  // Whether new blog post or editing an existing, change the page title
  page.querySelector('h2').innerHTML = newPost ? 'Add a new post' : 'Edit post'

  // If we are editing, fetch the post
  let post = null
  if (!newPost) {
    // Call the blog to fetch the post
    await fetch(`web3://${blogAddress}:${chainId}/getPost/${postNumber}?returns=(string,uint256,string,bytes32)`)
      .then(response => response.json())
      .then(data => {
        console.log("Fetched post : ", data)
        post = {
          title: data[0],
          date: data[1],
          ethereumStateContent: data[2],
          ethStorageContentKey: data[3],
        }
      })
      .catch(error => {
        console.error(error)
      })

    // Get the content, from EthStorage or from Ethereum state
    let content = ''
    if(post.ethStorageContentKey != "0x0000000000000000000000000000000000000000000000000000000000000000") {
      // Determine which EthStorage chain to use
      let ethStorageChainId = 333
      if(chainId != 1) {
        ethStorageChainId = 3333
      }
      // Call the EthStorage to fetch the content
      await fetch(`web3://${blogAddress}:${ethStorageChainId}/getPostEthStorageContent/${postNumber}?returns=(string)`)
        .then(response => response.json())
        .then(data => {
          console.log("Fetched blog ethstorage content : ", data)
          content = data[0]
        })
        .catch(error => {
          console.error(error)
        })
    }
    else {
      content = post.ethereumStateContent;
    }

    // Insert the post
    page.querySelector('#title').value = post.title
    page.querySelector('#content').value = content
  }


  // Markdown/preview switch
  let isPreviewShown = false
  let showMarkdownButton = page.querySelector('#button-markdown')
  let showPreviewButton = page.querySelector('#button-preview')
  const applyPreviewShownState = () => {
    page.querySelector('#content-textarea').style.display = isPreviewShown ? 'none' : 'flex'
    page.querySelector('#content-preview').style.display = isPreviewShown ? 'block' : 'none'
    showMarkdownButton.classList.toggle('active', !isPreviewShown)
    showPreviewButton.classList.toggle('active', isPreviewShown)
    if(isPreviewShown) {
      page.querySelector('#content-preview').innerHTML = markdown(strip_tags(page.querySelector('#content').value))
    }
  }
  const handleMarkdownButton = async (event) => {
    event.preventDefault()
    isPreviewShown = false
    applyPreviewShownState()
  }
  const handlePreviewButton = async (event) => {
    event.preventDefault()
    isPreviewShown = true
    applyPreviewShownState()
  }
  if(showMarkdownButton.hasAttribute('data-event-listener-added') == false) {
    showMarkdownButton.addEventListener('click', handleMarkdownButton)
    showMarkdownButton.setAttribute('data-event-listener-added', 'true')
  }
  if(showPreviewButton.hasAttribute('data-event-listener-added') == false) {
    showPreviewButton.addEventListener('click', handlePreviewButton)
    showPreviewButton.setAttribute('data-event-listener-added', 'true')
  }

  // Insert image button
  const insertImageButton = page.querySelector('#button-insert-image')
  const handleInsertImageButton = async (event) => {
    event.preventDefault()
    insertImageButton.disabled = true
    insertImageButton.innerHTML = 'Uploading ...';

    const revertButtonState = () => {
      insertImageButton.disabled = false
      insertImageButton.innerHTML = 'Insert image'
    }
    const stopWithError = (message) => {
      alert(message)
      revertButtonState()
    }
    
    // Show a file selector to the user with an hidden file input, get the content of the file
    const fileInput = document.createElement('input');
    fileInput.type = 'file';
    fileInput.style.display = 'none';
    fileInput.addEventListener('change', (event) => {
      const file = event.target.files[0];

      // Determine mime type of the file
      let mimeType = mime.getType(file.name.split('.').pop())
      if(mimeType == "") {
        stopWithError("Unable to determine mime type of the file")
        return;
      }

      const reader = new FileReader();
      reader.onload = async (event) => {
        const fileContent = event.target.result;

        // Prepare the calldata/value/blobs
        let calls = [];
        // Ethereum mainnet or sepolia: Store on EthStorage
        if(chainId == 1 || chainId == 11155111) {
          let blobs = []
          const fullBlobDataSize = (32 - 1) * 4096;
          // Convert the fileContent to blobs ready to be sent
          // toBlobs will throw an error above 6 blobs, so we make
          // chunks of 1 blob
          let fileContentUint8Array = new Uint8Array(fileContent)
          let fileContentChunks = []
          for(let i = 0; i < fileContentUint8Array.length; i += fullBlobDataSize) {
            fileContentChunks.push(fileContentUint8Array.slice(i, i + fullBlobDataSize))
          }
          for(let i = 0; i < fileContentChunks.length; i++) {
            try {
              // Note: Viem's ToBlobs add the 0x80 bytes at the end of content, not clear 
              // why. Since we chunked the file content so that they fit one chunk, we
              // can ignore the second chunk generated by ToBlobs which is made of just 0x80
              blobs.push(toBlobs({ data: toHex(fileContentChunks[i]) })[0]);
            }
            // toBlobs will also catch if the file is too big ( > 6 blobs)
            catch (error) {
              stopWithError(error);
              return
            }
          }
          console.log("Image blobs count", blobs.length)

          // Prepare the data sizes stored in the blobs
          let remaningFileSize = file.size
          let blobDataSizes = []
          for(let i = 0; i < blobs.length - 1; i++) {
            blobDataSizes.push(fullBlobDataSize)
            remaningFileSize -= fullBlobDataSize
          }
          blobDataSizes.push(remaningFileSize)

          // Get price of ethstorage upfront payment
          // We need to pay that
          let ethStorageUpfrontPayment = 0n
          await fetch(`web3://${blogAddress}:${chainId}/getEthStorageUpfrontPayment?returns=(uint256)`)
            .then(response => response.json())
            .then(data => {
              ethStorageUpfrontPayment = fromHex(data[0], 'bigint')
            })
            .catch(error => {
              stopWithError('EthStorage upfront fee fetching failed : ' + error.message)
              return
            })

          // Now, because of public RPC endpoints limitations (e.g. rpc.sepolia.org will throw a 
          // HTTP 413 error on eth_getTransactionReceipt, publicnode will throw a HTTP 500 if the
          // body of the request is too big, ...), we limit the number of blobs to X per tx
          // Chunk the blobDataSizes
          let chunkSize = 2
          let chunkedBlobs = []
          let chunkedBlobDataSizes = []
          for(let i = 0; i < blobDataSizes.length; i += chunkSize) {
            chunkedBlobs.push(blobs.slice(i, i + chunkSize))
            chunkedBlobDataSizes.push(blobDataSizes.slice(i, i + chunkSize))
          }

          // Show a summary of what is going to happen to the user, let him confirm
          if(confirm('You are about to upload an image made of ' + blobs.length + ' blobs, in ' + chunkedBlobs.length + ' separate transactions. \n\n The cost will be:\n - The EthStorage cost: ' + formatEther(ethStorageUpfrontPayment * BigInt(blobs.length)) + ' ETH \n - The gas cost of the transactions themselves \n\n Do you want to continue?') == false) {
            revertButtonState()
            return
          }

          // Now prepare the calls based on the chunkedBlobDataSizes
          for(let i = 0; i < chunkedBlobs.length; i++) {
            let methodName = i == 0 ? "addUploadedFileOnEthStorage" : "completeUploadedFileOnEthStorage";
            let args = i == 0 ? [file.name, mimeType, blobs.length, chunkedBlobDataSizes[i]] : [file.name, chunkedBlobDataSizes[i]];
            let value = ethStorageUpfrontPayment * BigInt(chunkedBlobs[i].length);
            calls.push({ methodName: methodName, args: args, value: value, blobs: chunkedBlobs[i] });
          }
        }
        // Other networks: Otherwise store on state
        else {
          let methodName = "addUploadedFileOnEthfs";
          let args = [file.name, mimeType, toHex(new Uint8Array(fileContent))];
          calls.push({ methodName: methodName, args: args, value: 0n, blobs: [] });
        }

        // Fetch the burner private key
        const burnerAddressPrivateKey = page.querySelector('#burner-address-private-key').value
        if(burnerAddressPrivateKey == "" && calls.reduce((count, call) => count + call.blobs.length, 0) > 0) {
          if(confirm('You are not using a burner wallet. Unless your wallet supports blob transactions, this will fail. Do you want to continue?') == false) {
            revertButtonState()
            return
          }
        }
console.log("Calls to be made", calls);

        // Make the calls
        for(let i = 0; i < calls.length; i++) {
          let txResult = null;
          try {
            txResult = await sendTransaction(blogAddress, chainId, calls[i].methodName, calls[i].args, {
              value: calls[i].value,
              blobs: calls[i].blobs,
              burnerWalletPrivateKey: burnerAddressPrivateKey,
              burnerWalletRequiredToBeEditor: true,
              burnerWalletSavePrivateKeyToLocalStorage: true,
            });
          }
          catch (error) {
            stopWithError(error.message)
            return
          }  
console.log("txResult", txResult)
        }


        const imageUrl = "/uploads/" + file.name;
        const content = page.querySelector('#content')
        const cursorPosition = content.selectionStart
        const contentBefore = content.value.substring(0, cursorPosition)
        const contentAfter = content.value.substring(cursorPosition)
        content.value = contentBefore + `![Image](${imageUrl})` + contentAfter

        revertButtonState()
      };
      reader.readAsArrayBuffer(file);
    });
    fileInput.click();    
  }
  if(insertImageButton.hasAttribute('data-event-listener-added') == false) {
    insertImageButton.addEventListener('click', handleInsertImageButton)
    insertImageButton.setAttribute('data-event-listener-added', 'true')
  }

  // Burner wallet generation
  const burnerAddressPrivateKeyInput = page.querySelector('#burner-address-private-key')
  const burnerAddressGenerated = page.querySelector('#burner-address-generated')
  const burnerAddressGeneratedArea = page.querySelector('#burner-address-generated-area')
  const burnerAddressBalance = page.querySelector('#burner-address-balance')
  const generateBurnerAddressButton = page.querySelector('#generate-burner-address')
  const handleGenerateBurnerAddress = async (event) => {
    if(confirm('This will generate a new burner wallet. Make sure to make a backup of the private key. \n\nThen send some funds to this wallet. Only send a small amount to pay for the transaction.\n\nContinue?') == false) {
      return;
    }
    event.preventDefault()
    const newBurnerArray = new Uint8Array(32);
    self.crypto.getRandomValues(newBurnerArray);
    const newBurnerPrivateKey = "0x" + uint8ArrayToHexString(newBurnerArray);
    burnerAddressPrivateKeyInput.value = newBurnerPrivateKey
    handleBurnerPrivateKeyChange()
    // Store it on localStorage
    try {
      localStorage.setItem('burnerPrivateKey', newBurnerPrivateKey)
    }
    catch (error) {
      // Do nothing. We know localstorage support is not available in EVM browser yet
    }
  }
  const handleBurnerPrivateKeyChange = async (event) => {
    const publicClient = createPublicClient({ 
      chain: chainId == 31337 ? anvil : chainId == 11155111 ? sepolia : mainnet,
      transport: http()
    })

    if(burnerAddressPrivateKeyInput.value) {
      try {
        const publicAddress = privateKeyToAccount(burnerAddressPrivateKeyInput.value).address;
        burnerAddressGenerated.innerHTML = publicAddress
        const balance = await publicClient.getBalance({address: publicAddress})
        burnerAddressBalance.innerHTML = formatEther(balance)
      }
      catch (error) {
        burnerAddressGenerated.innerHTML = burnerAddressPrivateKeyInput.value ? 'Invalid private key' : ''
      }
    }
    burnerAddressGeneratedArea.style.display = burnerAddressPrivateKeyInput.value ? 'block' : 'none'
  }
  if(generateBurnerAddressButton.hasAttribute('data-event-listener-added') == false) {
    generateBurnerAddressButton.addEventListener('click', handleGenerateBurnerAddress)
    generateBurnerAddressButton.setAttribute('data-event-listener-added', 'true')
  }
  if(burnerAddressPrivateKeyInput.hasAttribute('data-event-listener-added') == false) {
    burnerAddressPrivateKeyInput.addEventListener('input', handleBurnerPrivateKeyChange)
    burnerAddressPrivateKeyInput.setAttribute('data-event-listener-added', 'true')
  }
  // Private key field: Load the burner address from localStorage, if it was previously stored
  try {
    if(localStorage.getItem('burnerPrivateKey')) {
      burnerAddressPrivateKeyInput.value = localStorage.getItem('burnerPrivateKey')
      handleBurnerPrivateKeyChange()
    }
  }
  catch (error) {
    // Do nothing. We know localstorage support is not available in EVM browser yet
  }


  // On submit, create a new blog by calling the createBlog method of the BlogFactory contract
  const form = page.querySelector('form');
  const submitButton = form.querySelector('button[type="submit"]');
  const errorMessageDiv = form.querySelector('.error-message');
  errorMessageDiv.innerHTML = '';
  errorMessageDiv.style.display = 'none';

  const stopWithError = (message) => {
    errorMessageDiv.innerHTML = strip_tags(message ?? "")
    errorMessageDiv.style.display = 'block'
    submitButton.disabled = false
    submitButton.innerHTML = 'Save'
  }
 
  const handleSubmit = async (event) => {
    event.preventDefault();
    submitButton.disabled = true;
    submitButton.innerHTML = 'Saving ...';
    errorMessageDiv.innerHTML = '';
    errorMessageDiv.style.display = 'none';

    const title = form.querySelector('#title').value;
    const content = form.querySelector('#content').value;
    const burnerAddressPrivateKey = form.querySelector('#burner-address-private-key').value
    let postNumber = form.querySelector('#post-number').value;
    const newPost = postNumber == '';
    if(newPost == false) {
      postNumber = parseInt(postNumber)
    }

    // If title or content is empty : throw an error
    if (title.length === 0 || content.length === 0) {
      stopWithError('Title and content are required');
      return;
    }

    // Prepare the calldata/value/blobs
    let methodName;
    let args = [];
    let value = 0n;
    let blobs = [];
    // Ethereum mainnet or sepolia: Store on EthStorage
    if(chainId == 1 || chainId == 11155111) {
      // Ensure max content size to fit in blob
      blobs = toBlobs({ data: stringToHex(content) });
      if(blobs.length > 1) {
        stopWithError('Blog post entry too big (must be less than 126976 chars)')
        return
      }

      if (newPost) {
        // Get price of ethstorage upfront payment
        // We need to pay that
        await fetch(`web3://${blogAddress}:${chainId}/getEthStorageUpfrontPayment?returns=(uint256)`)
          .then(response => response.json())
          .then(data => {
            value = fromHex(data[0], 'bigint')
          })
          .catch(error => {
            stopWithError('EthStorage upfront fee fetching failed : ' + error.message)
            return
          })

        methodName = "addPostOnEthStorage";
        args = [title, content.length];
      }
      else {
        methodName = "editEthStoragePost";
        args = [postNumber, title, content.length];
      }
    }
    // Other networks: Otherwise store on state
    else {
      if(newPost) {
        methodName = "addPostOnEthereumState";
        args = [title, content];
      }
      else {
        methodName = "editEthereumStatePost";
        args = [postNumber, title, content];
      }
    }

    // Make the call
    let txResult = null;
    try {
      txResult = await sendTransaction(blogAddress, chainId, methodName, args, {
        value: value,
        blobs: blobs,
        burnerWalletPrivateKey: burnerAddressPrivateKey,
        burnerWalletRequiredToBeEditor: true,
        burnerWalletSavePrivateKeyToLocalStorage: true,
      });
    }
    catch (error) {
      stopWithError(error.message)
      return
    }
      
console.log("txResult", txResult)

    // Check tx status
    if(txResult.status == "reverted") {
      if(txResult.type == "eip1559") {
        stopWithError('Transaction reverted: Your wallet do not support blob transactions')
        return
      }
      stopWithError('Transaction reverted')
      return
    }
    // Take the BlogCreated/BlogEdited event
    const log = txResult.logs[txResult.logs.length - 1]
    // Find the post number
    const savedPostNumber = parseInt(log.topics[1], 16)
    // Go to the post
    window.location.href = `/#/entry/${savedPostNumber}`

    submitButton.disabled = false;
    submitButton.innerHTML = 'Save';
  };

  // Add the event listener only once
  if(form.hasAttribute('data-event-listener-added') == false) {
    form.addEventListener('submit', handleSubmit);
    form.setAttribute('data-event-listener-added', 'true')
  }
}