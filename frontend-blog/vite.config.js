import { defineConfig } from 'vite'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [],
  build: {
    target: "esnext",
  },
  // Yarn run dev: it won't work with the loading of the wasm file
  optimizeDeps: {
    exclude: ['kzg-wasm'],
    esbuildOptions: {
      target: 'esnext',
    },
  },
  resolve: {
    alias: {
      module: "./index.js"
    }
  },
})
