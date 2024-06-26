import './style.css'
import logo from './dblog.svg'
import { setupBlogCreationPopup } from './blog-creation-popup.js'
import { strip_tags } from './utils.js'

// Calling ourselves (so via a relative web3:// address) to fetch the address
// of the blog factory smart contract
// With some extra toolchain work, it could be included directly in the uploaded frontend...
let blogFactoryAddress = null
let chainId = null
await fetch(`/blogFactoryAddress.json`)
  .then(response => response.json())
  .then(data => {
    console.log("Fetched blog factory address : ", data.address, data.chainId)
    blogFactoryAddress = data.address
    chainId = data.chainId
  })
  .catch(error => {
    console.error(error)
  })


document.querySelector('#app').innerHTML = `
  <div id="app-wrapper">
    <img src="${logo}" class="logo vanilla" alt="DBlog logo" />
    <h1>DBlog.eth</h1>
    <button id="create-your-own">Create your DBlog</button>

    <p class="read-the-docs">
      Unstoppable decentralized <a href="web3://w3url.eth/">web3://</a> blogs
    </p>
    
    <div id="blogs">
    </div>

    <div id="blogs-pagination">
      <button id="previous-page" disabled="disabled">Previous</button>
      <button id="next-page" disabled="disabled">Next</button>
    </div>

    <div id="create-popup-bg">
      <div id="create-popup">
        <div id="step-1">
          <h2>Create your DBlog</h2>
          <form>
            <div class="form-row">
              <label for="title">Title <span class="required">*</span></label>
              <input type="text" id="title" name="title">
            </div>
            <div class="form-row">
              <label for="description">Description</label>
              <textarea id="description" name="description"></textarea>
            </div>
            <div class="form-row">
              <label for="subdomain">Subdomain</label>
              <div id="subdomain-input-area">
                <div id="subdomain-input">
                  <input type="text" id="subdomain" name="subdomain"><span class="domain-suffix">.dblog.eth</span>
                </div>
                <div id="subdomain-check">
                  
                </div>
                <div id="subdomain-input-help">
                  Subdomain is optional and has a one-time fee of 0.01 eth.
                </div>
              </div>
            </div>
            <div id="error-message">
              Error message
            </div>
            <button type="submit">Create</button>
            <button type="button" id="cancel"class="secondary">Cancel</button>
          </form>
        </div>
        <div id="step-2">
          <h2>🎉 Your DBlog is now ready!</h2>
          <div id="created-blog-address">
            <a href="">web3://</a> 
          </div>
          <div id="created-blog-infos">
            <p>
              ➔ Your DBlog will appear as a NFT in your wallet. The owner of the NFT is the owner of the blog.
            </p>
            <p>
              ➔ Your DBlog is made of several standalone smart contracts. Your frontend contract is located on Ethereum at address <code id="new-blog-address"></code>
            </p>
            <p>
              ➔ You can use your own .eth domain for it, see instructions in your blog admin page
            </p>
          </div>
          <div>
            <!--<button id="copy-link">Copy link</button>-->
            <button id="success-close-popup">Close</button>
          </div>
      </div>
    </div>
  </div>
`

// Now make a call to the blog factory to fetch the parameters
let topDomain = null
let domain = null
let blogImplementationAddress = null
await fetch(`web3://${blogFactoryAddress}:${chainId}/getParameters?returns=(string,string,address,address)`)
  .then(response => response.json())
  .then(data => {
console.log("Fetched parameters : ", data)
    topDomain = data[0]
    domain = data[1]
    blogImplementationAddress = data[3]
  })
  .catch(error => {
    console.error(error)
  })


// Fetch and display the blogs
let blogs = []
let page = 0;
const blogsPerPage = 9;
let blogCount = 0
const previousPageButton = document.querySelector('#previous-page')
const nextPageButton = document.querySelector('#next-page')
const fetchAndDisplayBlogs = async () => {
  // Now making a call to the blog factory to fetch the list of blog
  await fetch(`web3://${blogFactoryAddress}:${chainId}/getBlogInfoList/${page * blogsPerPage}/${blogsPerPage}?returns=((uint,address,address,string,string,string,uint)[],uint)`)
    .then(response => response.json())
    .then(data => {
      console.log("Fetched blogs : ", data)
      // The blogs are returned as a an array of array, we convert that into an array of objects
      blogs = data[0].map(blog => {
        return {
          id: blog[0],
          address: blog[1],
          frontendAddress: blog[2],
          subdomain: blog[3],
          title: blog[4],
          description: blog[5],
          postCount: blog[6]
        }
      })
      blogCount = parseInt(data[1], 16)
    })
    .catch(error => {
      console.error(error)
    })

  // Insert the blogs
  let blogsElement = document.querySelector('#blogs')
  blogsElement.innerHTML = ''
  if(blogs.length === 0) {
    blogsElement.innerHTML = `
      <div class="blog">
        <h3 class="title">No blog yet</h3>
        <div class="description">Be the first to create a DBlog!</div>
      </div>
    `;
  }
  blogs.forEach(blog => {
    let blogElement = document.createElement('div')
    blogElement.className = 'blog'

    let blogAddress = "web3://" + blog.frontendAddress + (chainId > 1 ? ":" + chainId : "") + "/"
    if(blog.subdomain) {
      blogAddress = "web3://" + blog.subdomain + "." + domain + "." + topDomain + (chainId > 1 ? ":" + chainId : "") + "/"
    }

    blogElement.innerHTML = `
      <h3 class="title"><a href="${blogAddress}">${strip_tags(blog.title)}</a></h3>
      <div class="description">${strip_tags(blog.description)}</div>
    `;
    blogsElement.appendChild(blogElement)
  })

  // Update the navigation buttons
  previousPageButton.disabled = page === 0
  nextPageButton.disabled = page * blogsPerPage + blogsPerPage >= blogCount
}
previousPageButton.onclick = () => {
  page--
  fetchAndDisplayBlogs()
}
nextPageButton.onclick = () => {
  page++
  fetchAndDisplayBlogs()
}
fetchAndDisplayBlogs()




setupBlogCreationPopup(document.querySelector('#create-popup-bg'), blogFactoryAddress, blogImplementationAddress, chainId, topDomain, domain, fetchAndDisplayBlogs)

// Show the create blog popup
document.querySelector('#create-your-own').addEventListener('click', () => {
  const popupBg = document.querySelector('#create-popup-bg')
  popupBg.style.display = 'flex'
  popupBg.querySelector('#title').value = "";
  popupBg.querySelector('#description').value = "";
  popupBg.querySelector('#subdomain').value = "";
})