import { encodeFunctionData } from 'viem'

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
          <h2 class="title"><a href="/add">Add your first post</a></h2>
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
        <h2 class="title"><a href="/entry/${post.id}">${post.title}</a></h2>
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
  const postNumber = parseInt(window.location.pathname.split('/').pop())

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
  page.querySelector('h2').innerHTML = post.title
  const options = { year: 'numeric', month: 'long', day: 'numeric' };
  const formattedDate = new Date(post.date * 1000).toLocaleDateString(undefined, options);
  page.querySelector('.date').innerHTML = formattedDate
  page.querySelector('.content').innerHTML = post.content
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
      <a href="/entry/${post.id}/edit">${post.title}</a> - <a href="/entry/${post.id}/edit">edit</a>
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
  const newPost = window.location.pathname.startsWith('/add')
  // If not a new post, fetch the post number from the URL
  const postNumber = newPost ? null : parseInt(window.location.pathname.split('/')[2])

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

  // On submit, create a new blog by calling the createBlog method of the BlogFactory contract
  const form = page.querySelector('form');
  const submitButton = form.querySelector('button[type="submit"]');
  const errorMessageDiv = form.querySelector('.error-message');

  const stopWithError = (message) => {
    errorMessageDiv.innerHTML = message
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
    let calldata = null;
    let value = '0x0';
    if (newPost) {
      calldata = encodeFunctionData({
        abi: [{
          inputs: [{ name: 'title', type: 'string' }, { name: 'content', type: 'string' }],
          name: 'addPost',
          outputs: [],
          type: 'function',
        }],
        args: [title, content]
      })
    }
    else {
      calldata = encodeFunctionData({
        abi: [{
          inputs: [{ name: 'id', type: 'uint256' }, { name: 'title', type: 'string' }, { name: 'content', type: 'string' }],
          name: 'editPost',
          outputs: [],
          type: 'function',
        }],
        args: [postNumber, title, content]
      })
    }

console.log("About to send with args:", title, content)
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
              to: blogAddress,
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
              to: blogAddress,
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

    // Take the BlogCreated/BlogEdited event
    const log = txResult.logs[0]
    // Find the post number
    const savedPostNumber = parseInt(log.topics[1], 16)
console.log("savedPostNumber", savedPostNumber)
    // Go to the post
    window.location.href = `/entry/${savedPostNumber}`

    submitButton.disabled = false;
    submitButton.innerHTML = 'Save';
  };

  // Add the event listener only once
  form.removeEventListener('submit', handleSubmit);
  form.addEventListener('submit', handleSubmit);
}