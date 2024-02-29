import './style.css'
import javascriptLogo from './javascript.svg'
import { setupBlogCreationPopup } from './blog-creation-popup.js'

const blogFactoryAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const chainId = 31337;
const topDomain = "eth";
const domain = "dblog";

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

setupBlogCreationPopup(document.querySelector('#create-popup-bg'), blogFactoryAddress, chainId, topDomain, domain)

// Show the create blog popup
document.querySelector('#create-your-own').addEventListener('click', () => {
  document.querySelector('#create-popup-bg').style.display = 'flex'
})