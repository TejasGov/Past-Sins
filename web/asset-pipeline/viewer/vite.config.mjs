import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';

const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.resolve(here, '../out');

// POST /__save/<name>.png with a PNG body writes web/asset-pipeline/out/<name>.png,
// so contact sheets rendered in the browser land next to the pipeline.
function saveScreenshots() {
  return {
    name: 'save-screenshots',
    configureServer(server) {
      server.middlewares.use('/__save/', async (req, res) => {
        const name = decodeURIComponent(req.url.replace(/^\//, '').split('?')[0]);
        if (req.method !== 'POST' || !/^[\w.-]+\.png$/.test(name)) {
          res.statusCode = 400;
          res.end('expected POST /__save/<name>.png');
          return;
        }
        const chunks = [];
        for await (const c of req) chunks.push(c);
        await fs.mkdir(outDir, { recursive: true });
        const file = path.join(outDir, name);
        await fs.writeFile(file, Buffer.concat(chunks));
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify({ saved: path.relative(path.resolve(here, '..'), file), bytes: Buffer.concat(chunks).length }));
      });
      server.middlewares.use('/__report', async (_req, res) => {
        res.setHeader('content-type', 'application/json');
        try {
          res.end(await fs.readFile(path.join(outDir, 'build-report.json')));
        } catch {
          res.end('{}');
        }
      });
    },
  };
}

export default defineConfig({
  root: here,
  // Serve web/public so the viewer loads the same /assets/characters/* URLs as the game.
  publicDir: path.resolve(here, '../../public'),
  server: { port: 5180, strictPort: true },
  // props.html?src=<id> reads the raw Poly Haven downloads straight from the cache.
  define: { __PROPS_SOURCE__: JSON.stringify(path.resolve(here, '../.cache/polyhaven')) },
  plugins: [saveScreenshots()],
});
