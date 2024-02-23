export function setupBlogCreation(element, blogFactoryAddress) {
  const submitButton = element.querySelector('button[type="submit"]')

  // On submut, create a new blog by calling the createBlog method of the BlogFactory contract
  element.querySelector('form').addEventListener('submit', event => {
    event.preventDefault()
    submitButton.disabled = true
    submitButton.innerHTML = 'Creating...'
    const title = element.querySelector('#title').value
    const description = element.querySelector('#description').value
    const subdomain = element.querySelector('#subdomain').value

    // Use the EIP-1193 Ethereum Provider JavaScript API to call the createBlog method of the BlogFactory contract
    // The createBlog method is called with the title, description, and subdomain as arguments
    // The createBlog method returns a boolean and a string
    // If the boolean is true, the string is the address of the new blog
    // If the boolean is false, the string is an error message
    // The error message is displayed in the #error-message div
    // If the boolean is true, the user is redirected to the new blog
    window.ethereum
      .request({
        method: 'eth_sendTransaction',
        params: [
          {
            to: blogFactoryAddress,
            data: `0x4d4c9c4f
              ${web3.eth.abi.encodeParameters(
                ['string', 'string', 'string'],
                [title, description, subdomain]
              )}`,
          },
          null
        ],
      })
      .then(txHash => {
        submitButton.disabled = false
        submitButton.innerHTML = 'Create'
        console.log(txHash)
      })
      .catch(error => {
        element.querySelector('#error-message').innerHTML = 'Call failed'
        submitButton.disabled = false
        submitButton.innerHTML = 'Create'
        console.error(error)
      })

  //   fetch(`web3://${blogFactoryAddress}/createBlog/string!${title},string!${description},string!${subdomain}`)
  //     .then(response => response.json())
  //     .then(data => {
  //       if (data[0] == true) {
  //         window.location = `web3://${data[1]}`
  //       } else {
  //         element.querySelector('#error-message').innerHTML = data[1]
  //         submitButton.disabled = false
  //         submitButton.innerHTML = 'Create'
  //       }
  //     })
  //     .catch(error => {
  //       element.querySelector('#error-message').innerHTML = 'Call failed'
  //       submitButton.disabled = false
  //       submitButton.innerHTML = 'Create'
  //       console.error(error)
  //     })
  })
}
