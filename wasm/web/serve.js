// wasm/web/serve.js - Plain static dev server for the browser build.
//
// The transport is postMessage (not SharedArrayBuffer), so the page needs NO
// special headers — this is a plain static server, the same as any host would
// be. It just resolves the kinds of asset from where they live in the tree:
//   * page + library (index.html, neovim.js, neovim-ui.js, app.js,
//     engine-worker.js)                                   -> wasm/web/
//   * the msgpack UMD bundle (msgpack.min.js)             -> node_modules
//   * the wasm build artifacts (nvim.js/.wasm/.data)      -> build-wasm/bin/
//
// So you can edit the page JS and just reload — only pre.js/runtime changes need
// a rebuild.  Usage:  node wasm/web/serve.js [port]
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const WEB = __dirname;                                   // wasm/web
const DIST = path.join(WEB, 'dist');                     // wasm/web/dist (tsc output)
const ROOT = path.resolve(__dirname, '..', '..');        // repo root
const BUILD = path.join(ROOT, 'build-wasm', 'bin');

// The page + library JS is compiled from TypeScript (src/) into dist/ by
// build-ts.sh; serve those built artifacts (index.html itself is hand-written and
// stays in wasm/web). Keep this list in sync with build-ts.sh's dist/ output.
const BUILT = new Set([
  'neovim.js', 'neovim-ui.js', 'neovim-ui-pre.js',
  'app.js', 'engine-worker.js',
]);
const MSGPACK = path.join(WEB, 'node_modules', '@msgpack', 'msgpack', 'dist.umd', 'msgpack.min.js');

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.data': 'application/octet-stream',
  '.json': 'application/json',
  '.css': 'text/css; charset=utf-8',
  '.map': 'application/json',
};

// Map a request URL path to a file on disk (or null to forbid): page + library
// from wasm/web, engine assets from build-wasm/bin.
function resolveStaticPath(urlPath) {
  if (urlPath === '/' || urlPath === '') { return path.join(WEB, 'index.html'); }
  // Engine assets live in build-wasm/bin: nvim.js/.wasm and the per-variant
  // runtime packages nvim-<variant>.data + nvim-<variant>.data.js (loaders).
  if (urlPath === '/nvim.js' || urlPath === '/nvim.wasm' ||
      /^\/nvim(-(full|core|minimal))?\.data(\.js)?$/.test(urlPath)) {
    return path.join(BUILD, urlPath);
  }
  if (urlPath === '/msgpack.min.js') { return MSGPACK; }
  // The TypeScript-compiled page + library JS lives in dist/.
  if (BUILT.has(urlPath.slice(1))) { return path.join(DIST, urlPath); }
  // Everything else from wasm/web, but never escape it.
  const p = path.normalize(path.join(WEB, urlPath));
  return p.startsWith(WEB) ? p : null;
}

function serveStaticFile(file, urlPath, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (!file) { res.statusCode = 403; res.end('forbidden'); return; }
  fs.readFile(file, function (err, data) {
    if (err) {
      res.statusCode = 404;
      res.end('not found: ' + urlPath);
      return;
    }
    res.setHeader('Content-Type', TYPES[path.extname(file)] || 'application/octet-stream');
    res.end(data);
  });
}

function handleRequest(req, res) {
  const urlPath = decodeURIComponent(req.url.split('?')[0]);
  serveStaticFile(resolveStaticPath(urlPath), urlPath, res);
}

// Warn early if the wasm build is stale (the page needs nvim.js + a runtime data
// package).
function warnIfBuildStale() {
  const missing = ['nvim.js', 'nvim.wasm', 'nvim-full.data.js', 'nvim-full.data']
    .filter(function (f) { return !fs.existsSync(path.join(BUILD, f)); });
  if (missing.length) {
    console.warn('  WARNING: missing in ' + BUILD + ': ' + missing.join(', '));
    console.warn('  WARNING: Run wasm/build-nvim.sh to (re)build the engine + runtime data packages.');
  }
  // The page + library JS is compiled into dist/ by build-ts.sh.
  if (!fs.existsSync(path.join(DIST, 'neovim.js'))) {
    console.warn('  WARNING: missing ' + path.join(DIST, 'neovim.js') +
      ' — run wasm/web/build-ts.sh (or `npm run build`) to compile the TypeScript page + library.');
  }
}

const PORT = parseInt(process.argv[2] || '8000', 10);
http.createServer(handleRequest).listen(PORT, function () {
  console.log('serving Neovim wasm grid UI on http://localhost:' + PORT);
  console.log('  page+lib   : ' + DIST + ' (compiled from ' + path.join(WEB, 'src') + ')');
  console.log('  wasm build : ' + BUILD);
  warnIfBuildStale();
});
