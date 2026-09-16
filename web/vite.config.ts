/// <reference types="vitest/config" />
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'

// GitHub Pages serves the site from /<repo>/; override with VITE_BASE for other hosts.
export default defineConfig({
  base: process.env.VITE_BASE ?? '/neuropro-tracker/',
  plugins: [react(), tailwindcss()],
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
})
