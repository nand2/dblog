import { markdown } from './drawdown.js'
import { strip_tags, uint8ArrayToHexString, parseWeb3Url, getBaseFeePerBlobGas } from './utils.js'
import { encodeParameters } from '@zoltu/ethereum-abi-encoder'
import { createWalletClient, custom, publicActions, toBlobs, toHex, setupKzg, encodeFunctionData, stringToHex, blobsToCommitments, commitmentsToVersionedHashes, blobsToProofs, defineChain, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { sepolia } from 'viem/chains'
import { loadKZG } from 'kzg-wasm'

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
  page.querySelector('.content').innerHTML = ''

  // Extract the post number from the URL
  let parsedUrl = parseWeb3Url(window.location.href)
  const postNumber = parseInt(parsedUrl.path.split('/').pop())

  // Call the blog to fetch the post
  let post = null
  await fetch(`web3://${blogAddress}:${chainId}/getPost/${postNumber}?returns=(string,uint256,string)`)
    .then(response => response.json())
    .then(data => {
      console.log("Fetched post : ", data)
      post = {
        title: data[0],
        date: data[1],
        content: data[2],
      }
    })
    .catch(error => {
      console.error(error)
    })

  // Insert the post
  page.querySelector('h2').innerHTML = strip_tags(post.title)
  const options = { year: 'numeric', month: 'long', day: 'numeric' };
  const formattedDate = new Date(post.date * 1000).toLocaleDateString(undefined, options);
  page.querySelector('.date').innerHTML = formattedDate
  page.querySelector('.content').innerHTML = markdown(strip_tags(post.content))
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
}


/**
 * Add/Edit blog post controller
 */
export async function entryEditController(blogAddress, chainId) {
  const page = document.getElementById('page-entry-edit');
  
  // Reinit fields
  page.querySelector('#title').value = ''
  page.querySelector('#content').value = ''

  // Determine if we are adding or editing by checking if the URL start with /add
  let parsedUrl = parseWeb3Url(window.location.href)
  const newPost = parsedUrl.path.startsWith('/#/add')
  // If not a new post, fetch the post number from the URL
  const postNumber = newPost ? null : parseInt(parsedUrl.path.split('/')[3])

  // Whether new blog post or editing an existing, change the page title
  page.querySelector('h2').innerHTML = newPost ? 'Add a new post' : 'Edit post'

  // If we are editing, fetch the post
  let post = null
  if (!newPost) {
    // Call the blog to fetch the post
    await fetch(`web3://${blogAddress}:${chainId}/getPost/${postNumber}?returns=(string,uint256,string)`)
      .then(response => response.json())
      .then(data => {
        console.log("Fetched post : ", data)
        post = {
          title: data[0],
          date: data[1],
          content: data[2],
        }
      })
      .catch(error => {
        console.error(error)
      })

    // Insert the post
    page.querySelector('#title').value = post.title
    page.querySelector('#content').value = post.content
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
  showMarkdownButton.removeEventListener('click', handleMarkdownButton)
  showMarkdownButton.addEventListener('click', handleMarkdownButton)
  showPreviewButton.removeEventListener('click', handlePreviewButton)
  showPreviewButton.addEventListener('click', handlePreviewButton)


  // On submit, create a new blog by calling the createBlog method of the BlogFactory contract
  const form = page.querySelector('form');
  const submitButton = form.querySelector('button[type="submit"]');
  const errorMessageDiv = form.querySelector('.error-message');

  const stopWithError = (message) => {
    errorMessageDiv.innerHTML = strip_tags(message)
    errorMessageDiv.style.display = 'block'
    submitButton.disabled = false
    submitButton.innerHTML = 'Save'
  }
 
  const handleSubmit = async (event) => {
    event.preventDefault();
    submitButton.disabled = true;
    submitButton.innerHTML = 'Saving ...';
    errorMessageDiv.innerHTML = '';

    const title = form.querySelector('#title').value;
    const content = form.querySelector('#content').value;

    // If title or content is empty : throw an error
    if (title.length === 0 || content.length === 0) {
      stopWithError('Title and content are required');
      return;
    }

    // Check presence of EI-1193 provider
    if (!window.ethereum) {
      stopWithError('No Ethereum provider found')
      return
    }

    // Frontent contract ABI
    const frontendABI = [
      {
        inputs:[],
        name: "getEthStorageUpfrontPayment",
        outputs: [{name:"", type :"uint256"}],
        stateMutability: "view",
        type: "function"
      },
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
      }
    ];

    // Prepare a Viem client
    const viemClient = createWalletClient({
      transport: custom(window.ethereum)
    }).extend(publicActions)

    // Request the address
    let accounts = []
    try {
      accounts = await viemClient.requestAddresses()
    }
    catch (error) {
      stopWithError('Address fetching failed : ' + error.message)
      return
    }

    // Request chain change
    try {
      await viemClient.switchChain({ id: chainId }) 
    }
    catch (error) {
      stopWithError('Chain switch failed : ' + error.message)
      return
    }

    // Prepare the calldata/value/blobs
    let calldata = null;
    let value = 0n;
    let kzg = null;
    let blobs = [];
    // Ethereum mainnet or sepolia: Store on EthStorage
    if(chainId == 1 || chainId == 11155111) {
      // Ensure max content size to fit in blob
      blobs = toBlobs({ data: stringToHex(content) });
      if(blobs.length > 1) {
        stopWithError('Blog post entry too big (must be less than 126976 chars)')
        return
      }

      // Prepare the KZG setup
      const wasmKzg = await loadKZG()
      kzg = setupKzg(wasmKzg)

      if (newPost) {
        // Get price of ethstorage upfront payment
        // We need to pay that
        const ethStorageUpfrontPayment = await viemClient.readContract({
          address: blogAddress,
          abi: frontendABI,
          functionName: 'getEthStorageUpfrontPayment',
        })
        value = ethStorageUpfrontPayment

        calldata = encodeFunctionData({
          abi: frontendABI,
          functionName: "addPostOnEthStorage",
          args: [title, content.length]
        })
      }
      else {
        calldata = encodeFunctionData({
          abi: frontendABI,
          functionName: "editEthStoragePost",
          args: [postNumber, title, content.length]
        })
      }
    }
    // Other networks: Otherwise store on state
    else {
      if(newPost) {
        calldata = encodeFunctionData({
          abi: frontendABI,
          functionName: "addPostOnEthereumState",
          args: [title, content]
        })
      }
      else {
        calldata = encodeFunctionData({
          abi: frontendABI,
          functionName: "editEthereumStatePost",
          args: [postNumber, title, content]
        })
      }
    }

console.log("About to send with args:", title, content)
console.log("Calldata", calldata)
console.log("value", value)
console.log("blobs length", blobs.length)

    // Prepare transaction
    const transactionOpts = {
      chain: defineChain({
        id: chainId,
      }),
      account: accounts[0],
      to: blogAddress,
      data: calldata,
      value: value,
      gas: 1000000n,
    }
    if(blobs.length > 0) {
      transactionOpts.blobs = blobs;
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
      stopWithError('Transaction failed : ' + error.message)
      return
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
      stopWithError('Failed to fetch the transaction result : ' + error.message)
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
    const log = txResult.logs[0]
    // Find the post number
    const savedPostNumber = parseInt(log.topics[1], 16)
    // Go to the post
    window.location.href = `/#/entry/${savedPostNumber}`

    submitButton.disabled = false;
    submitButton.innerHTML = 'Save';
  };

  // Add the event listener only once
  form.removeEventListener('submit', handleSubmit);
  form.addEventListener('submit', handleSubmit);
}