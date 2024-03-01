import './style.css'
import javascriptLogo from './javascript.svg'
import { setupBlogCreationPopup } from './blog-creation-popup.js'

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
  <div>
    <img src="${javascriptLogo}" class="logo vanilla" alt="JavaScript logo" />
    <h1>DBlog.eth</h1>
    <h2>Decentralized <a href="web3://w3url.eth/" target="_blank">web3://</a> blogs</h2>
    <button id="create-your-own">Create your DBlog</button>

    <p class="read-the-docs">
      Click on the Vite logo to learn more
    </p>
    
    <div id="blogs">
      <div class="blog">
        <h3 class="title"><a href="web3://xoxo.dblog.eth">DBlog 1</a></h3>
        <div class="description">Content of the first DBlog</div>
      </div>
      <div class="blog">
        <h3 class="title"><a href="web3://xoxo.dblog.eth">DBlog 1</a></h3>
        <div class="description">Content of the first DBlog</div>
      </div>
      <div class="blog">
        <h3 class="title"><a href="web3://xoxo.dblog.eth">DBlog 1</a></h3>
        <div class="description">Content of the first DBlog</div>
      </div>
      <div class="blog">
        <h3 class="title"><a href="web3://xoxo.dblog.eth">DBlog 1</a></h3>
        <div class="description">Content of the first DBlog</div>
      </div>
      <div class="blog">
        <h3 class="title"><a href="web3://xoxo.dblog.eth">DBlog 1</a></h3>
        <div class="description">Content of the first DBlog fdsd fs f fs fsd fs fsd f sfirst DBlog fdsd fs f fs fsd fs fsd f sfirst DBlog fdsd fs f fs fsd fs fsd f sfirst DBlog fdsd fs f fs fsd fs fsd f sfirst DBlog fdsd fs f fs fsd fs fsd f s</div>
      </div>
      <div class="blog">
        <h3 class="title"><a href="web3://xoxo.dblog.eth">DBlog 1 sdf sdfs dfsdf sd fsd fsd fsd fsd fsd fsd fsd fsd fs d fsd ff sdf sd  d dsf sdf sd fsdf sd fdsf sd fdsf  fsdf s df</a></h3>
        <div class="description">Content of the first DBlog</div>
      </div>
      <div class="blog">
        <h3 class="title"><a href="web3://xoxo.dblog.eth">DBlog 1</a></h3>
        <div class="description">Content of the first DBlog</div>
      </div>
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
            <button type="button" id="cancel">Cancel</button>
          </form>
        </div>
        <div id="step-2">
          <h2>🎉 Your DBlog is now ready!</h2>
          <div id="created-blog-address">
            <a href="" target="_blank">web3://</a> 
          </div>
          <div id="created-blog-infos">
            <p>
              ➔ Your DBlog is a standalone smart contract, located on Ethereum at address <span id="new-blog-address"></span>
            </p>
            <p>
              ➔ You can use your own .eth domain by pointing it to the address of the smart contract
            </p>
            <p>
              ➔ Your DBlog smart contract is a immutable proxy to the reference DBlog smart contract located on Ethereum at address <span id="blog-implementation-address"></span>
            </p>
          </div>
          <div>
            <button id="copy-link">Copy link</button>
            <button id="success-close-popup">Close</button>
          </div>
      </div>
    </div>
  </div>
`

// Now making a call to the blog factory to fetch the list of blogs
let topDomain = null
let domain = null
let blogs = []
let blogCount = 0
await fetch(`web3://${blogFactoryAddress}:${chainId}/getBlogInfoList/0/100?returns=(string,string,uint,(uint,address,string,string,uint)[])`)
  .then(response => response.json())
  .then(data => {
    console.log("Fetched blogs : ", data)
    topDomain = data[0]
    domain = data[1]
    blogCount = data[2]
    // The blogs are returned as a an array of array, we convert that into an array of objects
    blogs = data[3].map(blog => {
      return {
        id: blog[0],
        address: blog[1],
        title: blog[2],
        description: blog[3],
        postCount: blog[4]
      }
    })
  })
  .catch(error => {
    console.error(error)
  })

// Insert the blogs
let blogsElement = document.querySelector('#blogs')
blogs.forEach(blog => {
  let blogElement = document.createElement('div')
  blogElement.className = 'blog'

  // Strip HTML
  const strippedTitle = document.createElement('div');
  strippedTitle.innerHTML = blog.title;
  const strippedDescription = document.createElement('div');
  strippedDescription.innerHTML = blog.description;

  blogElement.innerHTML = `
    <h3 class="title"><a href="web3://${blog.address}">${strippedTitle.innerText}</a></h3>
    <div class="description">${strippedDescription.innerText}</div>
  `;
  blogsElement.appendChild(blogElement)
})


setupBlogCreationPopup(document.querySelector('#create-popup-bg'), blogFactoryAddress, chainId, topDomain, domain)

// Show the create blog popup
document.querySelector('#create-your-own').addEventListener('click', () => {
  document.querySelector('#create-popup-bg').style.display = 'flex'
})