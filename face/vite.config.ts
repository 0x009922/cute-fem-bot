import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import uno from 'unocss/vite'
import AutoImport from 'unplugin-auto-import/vite'
import Icons from 'unplugin-icons/vite'
import path from 'path'

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
  resolve: {
    alias: {
      '~': path.resolve(__dirname, 'src'),
    },
  },
  server: {
    proxy: {
      // '/api/v1': {
      //   target: 'https://api.cutefembot-landing.nyash.space',
      //   secure: false,
      //   rewrite: (path) => path.replace(/^\/api/, ''),
      // },
      '/api/v1': 'http://127.0.0.1:4000',
    },
  },
})
