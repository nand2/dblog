export function setupSubdomainCheck(element, blogFactoryAddress, chainId) {
  const subdomainInput = element.querySelector('#subdomain')
  const subdomainCheck = element.querySelector('#subdomain-check')
  let timeoutId

  subdomainInput.addEventListener('input', () => {
    clearTimeout(timeoutId)
    timeoutId = setTimeout(() => {
      const subdomain = subdomainInput.value
      if (subdomain.length === 0) {
        return
      }
      subdomainCheck.style.color = '';
      subdomainCheck.innerHTML = 'checking...'
      fetch(`web3://${blogFactoryAddress}:${chainId}/isSubdomainValidAndAvailable/string!${subdomain}?returns=(bool,string)`)
        .then(response => response.json())
        .then(data => {
          if (data[0] == true) {
            subdomainCheck.innerHTML = 'Available'
            subdomainCheck.style.color = 'rgb(0, 180, 0)';
          } else {
            subdomainCheck.innerHTML = 'Unavailable: ' + data[1]
            subdomainCheck.style.color = 'rgb(255, 80, 80)';
          }
        })
        .catch(error => {
          subdomainCheck.innerHTML = 'Call failed'
            subdomainCheck.style.color = 'rgb(255, 80, 80)';
          console.error(error)
        })
    }, 500)
  })

}
