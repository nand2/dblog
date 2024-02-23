import './style.css'
import javascriptLogo from './javascript.svg'
import { setupSubdomainCheck } from './subdomain-check.js'
import { setupBlogCreation } from './blog-creation.js'

const blogFactoryAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const chainId = 31337;

document.querySelector('#app').innerHTML = `
  <div>
    <img src="${javascriptLogo}" class="logo vanilla" alt="JavaScript logo" />
    <h1>DBlog.eth</h1>
    <h2>Decentralized <a href="web3://w3url.eth/">web3://</a> blogs</h2>
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
        <h2>Create your DBlog</h2>
        <form>
          <div class="form-row">
            <label for="title">Title</label>
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
                Subdomain is optional and is a one-time fee of 0.01 eth.
              </div>
            </div>
          </div>
          <div id="error-message">

          </div>
          <button type="submit">Create</button>
          <button type="button" id="cancel">Cancel</button>
        </form>
      </div>
    </div>
  </div>
`

setupSubdomainCheck(document.querySelector('#subdomain-input-area'), blogFactoryAddress, chainId)

setupBlogCreation(document.querySelector('#create-popup'), blogFactoryAddress, chainId)