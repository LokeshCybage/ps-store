import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
  },
  test: {
    environment: 'node',
    coverage: {
      reporter: ['text', 'lcov', 'cobertura'],
      reportsDirectory: 'coverage',
    },
  },
});
