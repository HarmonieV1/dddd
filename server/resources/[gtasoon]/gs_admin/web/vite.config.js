import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// base './' : chemins relatifs, obligatoires pour nui://gs_admin/web/dist/ (F10) et pour /gs_admin/ (appli staff externe)
// Deux pages : index.html = panneau F10 en jeu ; staff.html = appli staff externe (tablette, téléphone, PC), servie par server/web.lua
export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: 'dist', emptyOutDir: true, assetsInlineLimit: 0, chunkSizeWarningLimit: 400,
    rollupOptions: { input: { index: 'index.html', staff: 'staff.html' } },
  },
})
