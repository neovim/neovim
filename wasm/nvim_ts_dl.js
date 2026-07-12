// wasm/nvim_ts_dl.js - Emscripten JS-library: host-fetched tree-sitter grammars.
//
// The engine is linked -sMAIN_MODULE=2, so third-party grammar `.wasm` files
// (emscripten side modules -- the artifact `tree-sitter build --wasm`
// publishes) can be dlopen'd at runtime by nvim's normal parser loader. Files
// that already exist on a filesystem the engine can read (runtimepath dirs,
// a MEMFS seed) need nothing from this library -- the C
// loader stages + dlopens them by itself (see stage_parser_for_dlopen in
// src/nvim/lua/treesitter.c).
//
// This library is the LAST-RESORT hook for the "JS library" embedding: when
// vim.treesitter.language.add() finds no parser file anywhere, the engine
// asks the HOST for the grammar bytes so a browser page can fetch() them at
// runtime. The engine worker installs the hook (globalThis.__nvimParserFetch)
// when create() is configured with `parsers: { baseUrl }` or
// `parsers: { urls: { <lang>: <url> } }`.
//
// ADDITIVE + OPT-IN (the standing invariant): with no hook installed this
// returns 0 synchronously and language.add() reports its usual "No parser for
// language" error -- behavior is byte-for-byte unchanged.
//
//   nvim_ts_parser_fetch(lang, out, outlen) -> 1 and writes the MEMFS path of
//   the fetched grammar into `out`, or 0 (no hook / fetch failed / no file).
//   Marked __async: the wasm frame suspends via JSPI while the host fetches.

addToLibrary({
  nvim_ts_parser_fetch__deps: ['$FS', '$UTF8ToString', '$stringToUTF8', '$lengthBytesUTF8'],
  nvim_ts_parser_fetch__async: true,
  nvim_ts_parser_fetch: function (langPtr, outPtr, outLen) {
    var hook = globalThis.__nvimParserFetch;
    if (typeof hook !== 'function') { return 0; }  // sync fast path: no suspend
    var lang = UTF8ToString(langPtr);
    return (async function () {
      try {
        var bytes = await hook(lang);
        if (!bytes || !bytes.length) { return 0; }
        var dir = '/usr/share/nvim/parser-fetch';
        FS.mkdirTree(dir);
        var path = dir + '/' + lang + '.wasm';
        FS.writeFile(path, bytes);
        if (lengthBytesUTF8(path) + 1 > outLen) { return 0; }
        stringToUTF8(path, outPtr, outLen);
        return 1;
      } catch (e) {
        if (typeof console !== 'undefined') {
          console.warn('nvim: parser fetch for "' + lang + '" failed:', e);
        }
        return 0;
      }
    })();
  },
});
