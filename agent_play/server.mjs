// Minimal static server for a Godot web export.
//
// Two things a Godot 4 WebGL build needs that `python -m http.server` won't give you:
//   1. Cross-origin isolation headers (COOP/COEP) — required when the export enables
//      threads/SharedArrayBuffer. We send them ALWAYS (harmless when threads are off),
//      so this server works for any Godot game.
//   2. Correct MIME types for .wasm and .pck, or the engine fails to stream-compile.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { config } from './config.mjs';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
  '.css': 'text/css',
  '.ico': 'image/x-icon',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
};

export function startServer({ dir = config.buildDir, port = config.port } = {}) {
  const root = path.resolve(dir);
  const server = http.createServer((req, res) => {
    // Cross-origin isolation — needed for threaded Godot exports; safe otherwise.
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');

    let urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (urlPath === '/') urlPath = '/index.html';
    const filePath = path.join(root, urlPath);

    // Path-traversal guard.
    if (!filePath.startsWith(root)) {
      res.writeHead(403);
      res.end('Forbidden');
      return;
    }
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end(`Not found: ${urlPath}`);
        return;
      }
      const ext = path.extname(filePath).toLowerCase();
      res.setHeader('Content-Type', MIME[ext] || 'application/octet-stream');
      res.writeHead(200);
      res.end(data);
    });
  });

  return new Promise((resolve, reject) => {
    server.on('error', reject);
    server.listen(port, () => {
      resolve({
        url: `http://localhost:${port}`,
        close: () => new Promise((r) => server.close(r)),
      });
    });
  });
}

// Allow running directly: `node server.mjs`
const invokedDirectly =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (invokedDirectly) {
  const { url } = await startServer();
  console.log(`Serving ${config.buildDir}`);
  console.log(`  open ${url}/index.html?agent=1`);
  console.log('Ctrl+C to stop.');
}
