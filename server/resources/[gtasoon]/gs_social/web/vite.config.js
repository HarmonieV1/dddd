import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// base './' : chemins relatifs, obligatoires pour nui://gs_social/web/dist/
export default defineConfig({
  plugins: [react()],
  base: './',
  build: { outDir: 'dist', emptyOutDir: true, assetsInlineLimit: 0, chunkSizeWarningLimit: 300 },
})
