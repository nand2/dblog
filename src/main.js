import { createApp } from 'vue'
import './style.css'
import "bootstrap/dist/css/bootstrap.min.css"
import "bootstrap"
import App from './App.vue'

// Font-awesome
import { library } from '@fortawesome/fontawesome-svg-core'
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'
import { faChevronRight, faChevronDown, faXmark, faTriangleExclamation } from '@fortawesome/free-solid-svg-icons'
import { faCircleQuestion as farCircleQuestion } from '@fortawesome/free-regular-svg-icons'
library.add(faChevronRight, faChevronDown, faXmark, faTriangleExclamation, farCircleQuestion)

createApp(App).component('font-awesome-icon', FontAwesomeIcon).mount('#app')
