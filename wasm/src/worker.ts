// wasm/src/worker.ts - Neovim engine endpoint, run in a Node worker_thread.
//
// Hosts the Neovim engine wasm (`nvim --embed`) directly in this worker and
// backs its stdin/stdout (fd 0/1) with a postMessage channel to the main thread
// (wasm/nvim_io.js installs the stream ops). The main thread only ever exchanges
// messages with the engine; it never shares fds, pipes, or memory. That is the
// property the browser target needs (page <-> Worker over postMessage) and the
// browser host (wasm/web/engine-worker.js) is the same shape.
//
// The engine does NOT block: nvim's poll() suspends via JSPI and resumes when a
// message arrives, so this worker keeps returning to its event loop to receive
// the parent's messages.
//
// Compiled (by wasm/build-ts.sh) to a classic Node CommonJS script worker.js
// (gitignored) -- it is loaded by `new Worker(path)` and require()s nvim.js
// from its own directory at runtime, so it stays require-based and
// module-wrapper-free. This TypeScript is the SOURCE OF TRUTH.
'use strict';

const { parentPort, workerData } = require('worker_threads');
const path = require('path');

// The channel object wasm/nvim_io.js reads (Module.nvimChannel) to back fd 0/1.
const channel = {
  inQueue: [] as any[],   // bytes from the main thread; drained on fd-0 read
  closed: false,          // parent went away -> fd-0 read reports EOF
  notify: null as null | (() => void),  // nvim_io installs this; we call it after push/close
  postOutput: function (u8: Uint8Array) { parentPort.postMessage(u8.buffer, [u8.buffer]); },
};

parentPort.on('message', function (d: any) {
  channel.inQueue.push({ buf: new Uint8Array(d), off: 0 });
  if (channel.notify) { channel.notify(); }
});
// The main thread closing its end of the port shows up as 'close'.
parentPort.on('close', function () {
  channel.closed = true;
  if (channel.notify) { channel.notify(); }
});

// worker_threads inherit the parent's env, so the engine would otherwise share
// the client's $NVIM_LOG_FILE and interleave logs. Give the engine its own.
if (process.env.NVIM_LOG_FILE) {
  process.env.NVIM_LOG_FILE = process.env.NVIM_LOG_FILE + '.engine';
}

// Hand the channel + argv to the engine wasm. pre.js reads these globals (it
// can't see a require()-set Module because Emscripten's own `var Module`
// shadows it).
const G = globalThis as any;
G.__nvimChannel = channel;
G.__nvimArgs = ['--embed'].concat(workerData.args || []);

// The create() runtime config travels the same seam as args: the Node transport
// puts it on workerData, we forward it onto the __nvim* globals pre.js reads.
// (The browser analogue is engine-worker.js doing the same off its init message.)
if (workerData.env) { G.__nvimEnv = workerData.env; }
if (workerData.filesystem) { G.__nvimFiles = workerData.filesystem; }
if (typeof workerData.cwd === 'string') { G.__nvimCwd = workerData.cwd; }

// Runtime-fetched tree-sitter grammars ({ parsers: { baseUrl?, urls? } } on
// workerData): the Node analogue of engine-worker.js's hook -- language.add()
// falls back to it when no parser file exists on the runtimepath, and the
// bytes are dlopen'd as an emscripten side module. Node >= 18 has global
// fetch. Absent => no hook => current behavior (additive/opt-in).
if (workerData.parsers && (workerData.parsers.baseUrl || workerData.parsers.urls)) {
  const parsers = workerData.parsers;
  G.__nvimParserFetch = async function (lang: string): Promise<Uint8Array | null> {
    const url = (parsers.urls && parsers.urls[lang]) ||
      (parsers.baseUrl ? parsers.baseUrl.replace(/\/+$/, '') + '/' + lang + '.wasm' : null);
    if (!url) { return null; }
    const resp = await fetch(url);
    if (!resp.ok) { return null; }
    return new Uint8Array(await resp.arrayBuffer());
  };
}

// Booting the (non-MODULARIZE) Emscripten module starts the engine. When it
// exits (e.g. :q) the worker thread exits, which the parent observes as the
// worker's 'exit' event and treats as channel EOF.
require(path.join(__dirname, 'nvim.js'));
