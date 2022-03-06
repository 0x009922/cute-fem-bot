import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import uno from 'unocss/vite'
import AutoImport from 'unplugin-auto-import/vite'
import Icons from 'unplugin-icons/vite'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    vue({
      reactivityTransform: true,
    }),
    uno(),
    AutoImport({
      imports: ['vue', '@vueuse/core', 'vue-router'],
      eslintrc: { enabled: true },
    }),
    Icons(),
  ],
  server: {
    proxy: {
      '/api': 'http://localhost:4000',
    },
  },
})
