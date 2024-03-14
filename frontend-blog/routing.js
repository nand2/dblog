import { homeController, blogEntryController, adminController, entryEditController } from "./controllers.js";
import { parseWeb3Url } from "./utils.js";

export function setupRouting(blogAddress, chainId) {
  const routes = [
    {
      path: "^/$",
      template: "home",
      controller: homeController,
    },
    {
      path: "^/entry/[^\\/]*$",
      template: "entry",
      controller: blogEntryController,
    },
    {
      path: "^/admin",
      template: "admin",
      controller: adminController,
    },
    {
      path: "^/add",
      template: "entry-edit",
      controller: entryEditController,
    },
    {
      path: "^/entry/[^\\/]*/edit$",
      template: "entry-edit",
      controller: entryEditController,
    },
    {
      path: ".*",
      template: "404",
      controller: null,
    },
  ];
  
  // Handle the routing
  const parsedUrl = parseWeb3Url(window.location.href)
  const baseUrl = parsedUrl.protocol + "://" + parsedUrl.hostname + (parsedUrl.chainId ? ":" + parsedUrl.chainId : "")
  document.addEventListener("click", (e) => {
    const { target } = e;
    
    // If the link is relative, we handle the routing
    if (target.tagName === "A" && target.href.startsWith(baseUrl)) {
      e.preventDefault();
      route(e);
    }
  });
  
  const route = (event) => {
    event = event || window.event; // get window.event if event argument not provided
    event.preventDefault();
    
    // This is broken, due to the browser not parsing correctly the web3:// URL
    // So we use a old-school /#/<url> SPA routing
    // window.history.pushState({}, "", event.target.href);
    // locationHandler();
    window.location.href = event.target.href;
  };
  
  const locationHandler = async () => {
    // Old-school /#/<url> SPA routing
    let parsedUrl = parseWeb3Url(window.location.href)
    let location = parsedUrl.path || "/#/";
    if(location.startsWith("/#/") === false) {
      location = "/#/";
    }
    location = location.substring(2);
    
    const route = routes.find((route) => {
        return new RegExp(route.path).test(location);
    });
    
    // Hide all pages whose id start with "page-"
    document.querySelectorAll("[id^=page-]").forEach((page) => {
        page.style.display = "none";
    });
    // Show the page with the id corresponding to the template
    document.getElementById(`page-${route.template}`).style.display = "block";
    // document.title = route.title;
    // Call the controller
    if (route.controller) {
        route.controller(blogAddress, chainId);
    }
  };
  
  // add an event listener to the window that watches for url changes
  window.onpopstate = locationHandler;
  // call the urlLocationHandler function to handle the initial url
  locationHandler();
  
}