// wasm/web/src/engine-worker.ts - Neovim engine endpoint, run in a Web Worker.
//
// The browser analogue of wasm/worker.js. Hosts the Neovim engine wasm
// (`nvim --embed`) directly in this Worker and backs its stdin/stdout (fd 0/1)
// with a postMessage channel to the page (wasm/nvim_io.js installs the stream
// ops). The page and the engine only ever exchange messages -- no shared memory,
// so the page needs no COOP/COEP / cross-origin isolation.
//
// Protocol with the page:
//   page -> worker:  first message {args, env, cwd, filesystem, plugins} (init);
//                    then ArrayBuffers (RPC input)
//   worker -> page:  ArrayBuffers (RPC output); {kind:'booting'|'stdout'|'stderr'
//                    |'exit'} status objects
//
// Runtime VARIANTS (the create({plugins}) option): nvim.wasm is runtime-agnostic,
// so the runtime ships as a separate file_packager data package per variant
// (nvim-<variant>.data + nvim-<variant>.data.js loader). The loader unpacks the
// runtime into MEMFS at /usr/share/nvim/runtime and, crucially, registers a
// run-dependency (addRunDependency / preRun) on `self.Module`, so nvim's main()
// waits for the data before it runs. We MUST importScripts the loader BEFORE
// nvim.js, and self.Module must already exist so the loader's
// `var Module = typeof Module != 'undefined' ? Module : {}` binds to OUR Module
// (the same one nvim.js then uses) rather than a throwaway object.
//
// Compiled (by wasm/web/build-ts.sh) to a classic worker script engine-worker.js
// — it stays importScripts-loadable and module-wrapper-free.
'use strict';

// `self` carries a pile of dynamic __nvim* config globals (read by pre.js) plus
// Emscripten's Module.
const S: any = self as any;

const VARIANTS: Record<string, number> = { full: 1, core: 1, minimal: 1 };
let started = false;

onmessage = function (e: MessageEvent) {
  if (!started) {
    started = true;
    const init = e.data || {};
    const args = init.args || [];

    // The channel object wasm/nvim_io.js reads (Module.nvimChannel).
    const channel = {
      inQueue: [] as any[],
      closed: false,
      notify: null as null | (() => void),
      postOutput: function (u8: Uint8Array) { (postMessage as any)(u8.buffer, [u8.buffer]); },
    };
    S.__nvimChannel = channel;
    S.__nvimArgs = ['--embed'].concat(args);

    // create() runtime config (env/cwd/filesystem) travels in the same init
    // message and is handed to the engine via the __nvim* globals pre.js reads,
    // mirroring the Node host (wasm/worker.js) exactly.
    if (init.env) { S.__nvimEnv = init.env; }
    if (init.filesystem) { S.__nvimFiles = init.filesystem; }
    if (typeof init.cwd === 'string') { S.__nvimCwd = init.cwd; }

    // Runtime-fetched tree-sitter grammars (create({parsers})): install the
    // hook wasm/nvim_ts_dl.js consults when language.add() finds no parser
    // file. Resolution: urls[lang] first, else baseUrl/<lang>.wasm. Returning
    // null keeps nvim's usual "No parser for language" error. Absent config =>
    // no hook => byte-for-byte current behavior (additive/opt-in).
    if (init.parsers && (init.parsers.baseUrl || init.parsers.urls)) {
      const parsers = init.parsers;
      S.__nvimParserFetch = async function (lang: string): Promise<Uint8Array | null> {
        const url = (parsers.urls && parsers.urls[lang]) ||
          (parsers.baseUrl ? parsers.baseUrl.replace(/\/+$/, '') + '/' + lang + '.wasm' : null);
        if (!url) { return null; }
        const resp = await fetch(url);
        if (!resp.ok) { return null; }
        return new Uint8Array(await resp.arrayBuffer());
      };
    }

    // Surface engine stdout/stderr + exit back to the page. Set BEFORE boot so
    // the engine's own prints are always captured.
    S.Module = S.Module || {};
    S.Module.print = function (s: string) { try { postMessage({ kind: 'stdout', text: s }); } catch (_e) {} };
    S.Module.printErr = function (s: string) { try { postMessage({ kind: 'stderr', text: s }); } catch (_e) {} };
    S.Module.onExit = function () { try { postMessage({ kind: 'exit' }); } catch (_e) {} };

    // Runtime variant: default 'full'. create() already validates this, but guard
    // here too since the worker can be driven directly.
    const variant = init.plugins || 'full';

    // bootEngine loads the variant's data package + nvim.js (which runs main()).
    function bootEngine() {
      if (!VARIANTS[variant]) {
        postMessage({ kind: 'error', error: "unknown plugins variant '" + variant +
          "' (expected 'full', 'core', or 'minimal')" });
        return;
      }
      postMessage({ kind: 'booting' });
      // Load the variant's data-package loader FIRST (it registers a run-dependency
      // on self.Module + a preRun that unpacks the runtime into MEMFS), THEN nvim.js
      // (which sees the dependency and waits for the data before main()). Both
      // resolve relative to this worker's URL, i.e. under the bundle's baseUrl.
      //
      // The data-package loader is generated by wasm/build-nvim.sh (file_packager).
      // If the build is stale (predates the runtime-variants change) the file is
      // absent and importScripts throws an opaque NetworkError -- catch it and post
      // an actionable message instead of letting the worker die silently.
      try {
        importScripts('nvim-' + variant + '.data.js');
      } catch (err: any) {
        postMessage({ kind: 'error', error:
          "failed to load the runtime package 'nvim-" + variant + ".data.js' (" +
          (err && err.message || err) + "). The wasm build is likely stale -- run " +
          "wasm/build-nvim.sh to (re)generate the per-variant runtime data packages " +
          "next to nvim.js." });
        return;
      }
      importScripts('nvim.js');   // boots the engine; main() runs the libuv loop
    }

    bootEngine();
    return;
  }

  // After init, every message is RPC input bytes (a transferred ArrayBuffer).
  const ch = S.__nvimChannel;
  ch.inQueue.push({ buf: new Uint8Array(e.data), off: 0 });
  if (ch.notify) { ch.notify(); }
};
