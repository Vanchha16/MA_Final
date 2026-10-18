import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Served by Flask at /dashboard (npm run build writes into the backend's static folder).
// npm run dev serves it at http://localhost:5173/dashboard/ and forwards /api and /uploads to Flask.
export default defineConfig({
  base: '/dashboard/',
  plugins: [react()],
  build: {
    outDir: '../backend/app/static/web-admin',
    emptyOutDir: true,
    rollupOptions: { output: { manualChunks: { react: ['react', 'react-dom', 'react-router-dom'], charts: ['recharts'] } } },
  },
  server: {
    proxy: {
      '/api': 'http://127.0.0.1:5000',
      '/uploads': 'http://127.0.0.1:5000',
    },
  },
  test: { environment: 'jsdom', setupFiles: './src/test/setup.js', globals: true },
});
