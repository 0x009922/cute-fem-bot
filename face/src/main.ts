localStorage.debug = '*'

import 'uno.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import '@grammyjs/web-app'

const pinia = createPinia()

createApp(App).use(pinia).use(router).mount('#app')

try {
  window.Telegram.WebApp.ready()
} catch {}
