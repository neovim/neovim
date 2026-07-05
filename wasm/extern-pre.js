// wasm/extern-pre.js - Emscripten --extern-pre-js (prepended before ALL of
// Emscripten's generated JS, including the --preload-file data-package loader).
//
// Why this exists: the data-package loader computes its path at the very top of
// nvim.js as `Module.locateFile ? Module.locateFile('nvim.data','') : 'nvim.data'`
// -- and unlike the .wasm loader it does NOT fall back to the script directory,
// so without locateFile it opens a *cwd-relative* 'nvim.data' and fails with
// ENOENT when nvim.js is run from anywhere other than its own directory. The
// normal --pre-js runs far too late to set locateFile in time; --extern-pre-js
// runs first.
//
// Under Node we point locateFile at __dirname so nvim.wasm/nvim.data resolve next
// to nvim.js regardless of cwd (the launcher and the engine worker both rely on
// this). In the browser the default (relative to the script URL) is correct, so
// we leave it alone.
if (typeof process !== 'undefined' && process.versions && process.versions.node) {
  var Module = (typeof Module !== 'undefined' && Module) || {};
  if (!Module['locateFile']) {
    Module['locateFile'] = function (p) { return require('path').join(__dirname, p); };
  }
}
