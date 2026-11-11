import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// Same-origin API proxy: the browser visits localhost:3000 and Vite forwards
// API/media requests to Django on 127.0.0.1:8000. No CORS change is needed.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: { rollupOptions: { input: { storefront: "index.html", admin: "admin/index.html" } } },
  server: {
    host: 'localhost', port: 3000, strictPort: true,
    proxy: {
      '/api': { target: 'http://127.0.0.1:8000', changeOrigin: true },
      '/media': { target: 'http://127.0.0.1:8000', changeOrigin: true },
      '/static': { target: 'http://127.0.0.1:8000', changeOrigin: true },
    },
  },
});
