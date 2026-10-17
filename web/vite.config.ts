import { defineConfig } from "vite";

export default defineConfig({
  base: "./",
  server: { port: 5173, strictPort: true },
  preview: { port: 4173, strictPort: true },
  build: {
    target: "es2022",
    chunkSizeWarningLimit: 7000,
    // asset-pipeline is a sibling tool owned by the character pipeline session.
    rollupOptions: { input: "index.html" },
  },
  optimizeDeps: { exclude: ["@dimforge/rapier3d-compat"] },
});
