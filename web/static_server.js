const http = require('http');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// Hosts (Render, Railway, ...) assign the public port through $PORT.
const PORT = Number(process.env.PORT) || 8081;

/* The AI features (Virasat Mitr, VR guide, translator, scanner narration)
   all talk to the Groq proxy in server.js on :3005. Every one of them
   degrades to canned replies when that process isn't running — which is
   what "the AI isn't answering my question" almost always turns out to be.
   So starting the site starts the proxy too, unless NO_AI=1 is set or
   something is already listening on 3005. */
function ensureAiProxy() {
  if (process.env.NO_AI === '1') return;
  const net = require('net');
  const probe = net.createConnection({ port: 3005, host: '127.0.0.1' });
  probe.once('connect', () => { probe.destroy(); console.log('🤖 AI proxy already running on :3005'); });
  probe.once('error', () => {
    probe.destroy();
    const { fork } = require('child_process');
    // server.js also reads $PORT: pin it to 3005 so it never grabs the public port.
    const child = fork(path.join(__dirname, 'server.js'), [], { stdio: 'inherit', env: { ...process.env, PORT: '3005' } });
    child.on('exit', code => console.warn(`⚠️  AI proxy exited (code ${code}). Restart with: node server.js`));
    process.on('exit', () => { try { child.kill(); } catch (e) {} });
  });
}
ensureAiProxy();

const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.jpg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.mp4': 'video/mp4',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm'
};

// Server-side files that must never leave the machine. server.js carries the
// AI provider key; backups carry older copies of it.
const BLOCKED_FILES = new Set([
  'server.js',
  'static_server.js',
  'package.json',
  'package-lock.json'
]);
const BLOCKED_EXTENSIONS = [
  '.bak', '.bak2', '.apibak', '.env', '.key', '.pem', '.log', '.sqlite', '.db'
];
const BLOCKED_DIRS = ['node_modules', '.git', '.claude'];

function isBlocked(urlPath) {
  const parts = urlPath.split('/').filter(Boolean);
  const name = (parts[parts.length - 1] || '').toLowerCase();

  if (parts.some(p => BLOCKED_DIRS.includes(p.toLowerCase()))) return true;
  if (name.startsWith('.')) return true;                       // .env, dotfiles
  if (BLOCKED_FILES.has(name)) return true;
  if (BLOCKED_EXTENSIONS.some(ext => name.endsWith(ext))) return true;
  return false;
}

const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Same-origin pass-through to the AI proxy on :3005 so the site works
  // from a phone / tunnel where "localhost:3005" is unreachable.
  if (req.url.startsWith('/api/')) {
    const up = http.request({ host: '127.0.0.1', port: 3005, path: req.url, method: req.method, headers: req.headers }, r => {
      res.writeHead(r.statusCode, r.headers);
      r.pipe(res);
    });
    up.on('error', () => { res.writeHead(502, { 'Content-Type': 'application/json' }); res.end('{"error":"ai proxy down"}'); });
    req.pipe(up);
    return;
  }

  // Parse URL to find local path
  let safeUrl = decodeURIComponent(req.url.split('?')[0]);
  if (safeUrl === '/') {
    safeUrl = '/index.html';
  }

  const filePath = path.join(__dirname, safeUrl);

  // Basic security check: ensure request path doesn't escape workspace
  if (!filePath.startsWith(__dirname)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('403 Forbidden');
    return;
  }

  // This server hands out the whole project folder, which sits next to the
  // proxy that holds the API key. Serve web assets only — never source,
  // config, secrets or backups.
  if (isBlocked(safeUrl)) {
    console.log(`[blocked] ${safeUrl}`);
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('403 Forbidden');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('404 Not Found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    // Images/audio are already compressed and rarely change: cache for a
    // day. Code is tiny once gzipped (A-Frame: 1.4 MB -> ~350 KB) but edits
    // must show up on reload, so it is revalidated every time.
    const isText = /^(text\/|application\/(javascript|json))/.test(contentType);
    const headers = {
      'Content-Type': contentType,
      'Cache-Control': isText ? 'no-cache' : 'public, max-age=86400',
      'Vary': 'Accept-Encoding'
    };
    const acceptsGzip = /gzip/.test(req.headers['accept-encoding'] || '');
    const stream = fs.createReadStream(filePath);
    if (isText && acceptsGzip) {
      headers['Content-Encoding'] = 'gzip';
      res.writeHead(200, headers);
      stream.pipe(zlib.createGzip({ level: 6 })).pipe(res);
    } else {
      headers['Content-Length'] = stats.size;
      res.writeHead(200, headers);
      stream.pipe(res);
    }
  });
});

function startStaticServer(port) {
  server.listen(port, '0.0.0.0', () => {
    console.log(`\n============================================================`);
    console.log(`⚡ Virasat Platform Static Server is ACTIVE!`);
    console.log(`📍 Main App:     http://localhost:${port}/`);
    console.log(`📍 Explore City: http://localhost:${port}/explore.html`);
    console.log(`📍 Report Site:  http://localhost:${port}/report.html`);
    console.log(`============================================================\n`);
  }).on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.log(`Port ${port} is in use, trying port ${port + 1}...`);
      startStaticServer(port + 1);
    } else {
      console.error('Static server error:', err);
    }
  });
}

startStaticServer(PORT);
