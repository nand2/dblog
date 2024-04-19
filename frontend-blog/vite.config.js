import { defineConfig } from 'vite'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [],
  build: {
    target: "esnext",
    chunkSizeWarningLimit: 1000
  },
  // Yarn run dev: it won't work with the loading of the wasm file, we need this
  optimizeDeps: {
    exclude: ['kzg-wasm'],
    esbuildOptions: {
      target: 'esnext',
    },
  },
})
