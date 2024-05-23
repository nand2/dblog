import './style.css'
import { setupRouting } from './routing.js'
import { strip_tags } from './utils.js'


// Calling ourselves (so via a relative web3:// address) to fetch the address
// of the blog smart contract
let blogAddress = null
let frontendAddress = null
let chainId = null
try {
  await fetch(`/blogAddress.json`)
    .then(response => response.json())
    .then(data => {
      console.log("Fetched blog address : ", data.address, data.frontendAddress, data.chainId)
      blogAddress = data.address
      frontendAddress = data.frontendAddress
      chainId = data.chainId
    })
}
catch(error) {
  console.log(error)
  alert("Failed fetching the blog contract address: " + error)
}


document.querySelector('#app').innerHTML = `
  <div>
    <h1 id="blog-title">
      <a href="/#/">
        <!--My blog title-->
      </a>
    </h1>

    <p id="blog-subtitle">
      <!--My blog description-->
    </p>

    <hr id="main-separator" />

    <a id="admin-link" href="/#/admin">[ Admin ]</a>
    
    <div id="page-home">
      <div id="blog-entries">
        <!--<div class="blog-entry">
          <div class="date">09 Feb 2023</div>
          <h2 class="title"><a href="/#/entry/xx">My first blog entry</a></h2>
        </div>-->
      </div>
    </div>
    <div id="page-entry">
      <h2 class="blog-entry-title"><!--My first blog entry--></h2>
      <hr />
      <div class="sub-hr">
        <div class="date"><!--09 Feb 2023--></div>
        <a href="/#/">See all posts</a>
      </div>
      <div class="blog-entry-content">
        <!--Some content here-->
      </div>
    </div>
    <div id="page-admin">
      <h2 class="page-title">Admin</h2>
      <div id="admin-cols">
        <div class="col">
          <h3>Blog entries <a href="/#/add">[Add new]</a></h3>
          <div id="admin-blog-entries">
            <!--<div class="blog-entry">
              2023-02-01 <a href="/#/entry/xx">My first blog entry</a> - <a href="/#/entry/xx/edit">Edit</a>
            </div>-->
          </div>
          <h3>Editors</h3>
          <div id="admin-editors">
            <!--<div class="editor">
              <span>0x1234...5678</span> (blog owner)
            </div>
            <div class="editor">
              <span>0x1234...5678</span> <button type="button" class="admin-remove-editor">Remove</button>
            </div>-->
          </div>
          <form id="admin-editor-add">
            <input type="text" id="admin-new-editor-address" placeholder="New editor ethereum address">
            <button type="submit" id="admin-add-editor">Add editor</button>
          </form>
          <h3>Uploaded files</h3>
          <div id="admin-uploaded-files">
            <ul>
              <!--<li><a href="/...">File name</a> <button type="button" class="admin-remove-file">Remove</button></li>-->
            </ul>
          </div>
        </div>
        <div class="col">
          <h3>Blog contract addresses</h3>
          <div>
            Frontend: <code id="admin-blog-frontend-address"></code>
          </div>
          <div>
            Data: <code id="admin-blog-address"></code>
          </div>
          <h3>Using a custom .eth domain</h3>
          <div id="admin-ens-ethereum-chain">
            <div style="margin-bottom:5px">
              To use your blog with a custom .eth domain, you need to point your domain to the following address :
            </div>
            <div>
              <code id="admin-ens-address"></code>
            </div>
          </div>
          <div id="admin-ens-other-chain">
            <div style="margin-bottom:5px">
              To use your blog with a custom .eth domain, you need to add a TXT record to your ENS domain with a key of <code>contentcontract</code> and the following value :
            </div>
            <div>
              <code id="admin-ens-custom-txt"></code>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div id="page-entry-edit">
      <h2 class="page-title">New blog post</h2>
      <form>
        <div class="form-row">
          <label for="title">Title</label>
          <input type="text" id="title" name="title">
        </div>
        <div class="form-row">
          <label for="content">Content</label>
          <div style="flex: 1;">
            <div class="editor-toolbar">
              <button type="input" id="button-markdown" disabled="disabled">Markdown</button>
              <button type="input" id="button-preview">Preview</button>
              <button type="input" id="button-insert-image">Insert image</button>
            </div>
            <div id="content-textarea">
              <textarea id="content" name="content"></textarea>
            </div>
            <div id="content-preview" class="blog-entry-content">
            </div>
          </div>
        </div>
        <div class="form-row">
          <label for="burner-address-private-key">Burner wallet</label>
          <div id="burner-address-area">
            <div id="burner-address-field-area">
              <input type="text" id="burner-address-private-key" name="burner-address-private-key" placeholder="Private key (0x...)">
              <button type="button" id="generate-burner-address">Generate</button>
            </div>
            <div class="burner-help" id="burner-address-generated-area" style="display:none";>
              Your burner wallet address is : <strong id="burner-address-generated"></strong> (balance: <span id="burner-address-balance"></span> ETH)
            </div>
            <div class="burner-help">
              Using an burner wallet is necessary as long as your wallet (Metamask, ...) does not support blob transactions
            </div>
          </div>
        </div>
        <div class="error-message">
          Error message
        </div>
        <input type="hidden" id="post-number" name="post-number" value="">
        <div class="buttons">
          <button type="submit">Save</button>
        </div>
      </form>
    </div>
    <div id="page-404">
      <h2>404</h2>
    </div>
  </div>
`

// Fetch the blog title and description
let blogTitle = null
let blogDescription = null
let blogOwner = null
try {
  await fetch(`web3://${blogAddress}:${chainId}/getTitleAndDescriptionAndOwner?returns=(string,string,address)`)
    .then(response => response.json())
    .then(data => {
      blogTitle = data[0]
      blogDescription = data[1]
      blogOwner = data[2]

      document.querySelector('#blog-title a').innerHTML = strip_tags(blogTitle)
      document.title = strip_tags(blogTitle) + " - DBlog"
      document.querySelector('#blog-subtitle').innerHTML = strip_tags(blogDescription)
    })
}
catch(error) {
  console.log(error)
  alert("Error while fetching blog title, description and owner: " + error)
}

// Setup the routing
setupRouting(frontendAddress, blogAddress, chainId, blogOwner)