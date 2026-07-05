// wasm/web/src/neovim.ts - headless Neovim instance (msgpack-RPC core).
//
// The "core API" layer of the browser port (see wasm/README.md). It owns ONLY
// the msgpack-RPC conversation with an `nvim --embed` engine; it has no DOM, no
// grid, and no knowledge of how the engine worker is hosted. Rendering lives in
// neovim-ui.ts; the page wiring lives in app.ts.
//
// An instance talks to the engine through a *transport* -- a thin byte channel
// the caller supplies. This is what keeps the core environment-agnostic and
// testable: the browser drives the engine in a Web Worker (engine-worker.ts),
// while the headless Node test (e2e.test.js) drives it in a worker_thread
// (wasm/worker.js). Both look identical to the core.
//
// This module is the TypeScript SOURCE OF TRUTH. The build (wasm/web/build-ts.sh)
// emits three artifacts from it: a UMD `neovim.js` (usable as a <script> that
// sets globalThis.Neovim, or via require() in Node), an ESM `neovim.mjs` (see
// src/neovim.mts), and a `neovim.d.ts` type declaration.

// ---- public types ---------------------------------------------------------

// A thin byte channel between the core and an `nvim --embed` engine. The caller
// supplies it; the core sets the on* callbacks.
export interface Transport {
  // Hand RPC bytes to the engine (transfers u8.buffer).
  send(u8: Uint8Array): void;
  // Optional: called once before any send (e.g. the browser worker's {args}
  // init message).
  start?(): void;
  // Optional: tear the engine down.
  close?(): void;
  // WE set this; transport calls it with each RPC byte chunk from the engine.
  onMessage?: ((u8: Uint8Array) => void) | null;
  // WE set this; transport calls it when the engine exits / the channel closes.
  onClose?: (() => void) | null;
  // WE set this (optional); transport calls it with out-of-band {kind,...}
  // status objects.
  onStatus?: ((status: any) => void) | null;
}

// The shape of the @msgpack/msgpack module the core needs.
export interface MessagePackModule {
  encode(value: any): Uint8Array;
  decodeMultiStream(stream: AsyncIterable<Uint8Array>): AsyncIterable<any>;
}

// Out-of-band transport status objects.
export interface NvimStatus {
  kind: 'booting' | 'stdout' | 'stderr' | 'exit' | 'error' | string;
  text?: string;
  error?: string;
  [k: string]: any;
}

// A clipboard provider: get() returns the system clipboard, set() writes it.
export interface ClipboardProvider {
  get(): Promise<string | string[] | [string[], string]> | string | string[] | [string[], string];
  set(lines: string[] | string, regtype?: string): Promise<void> | void;
}

export type ClipboardOption = 'browser' | ClipboardProvider;

export type PluginsVariant = 'full' | 'core' | 'minimal';

// Optional runtime source for tree-sitter grammars that are NOT bundled into
// the engine. When vim.treesitter.language.add() finds no parser anywhere on
// the runtimepath, the engine asks the worker, which fetch()es
//   urls[lang]                  (if present), else
//   baseUrl + '/' + lang + '.wasm'
// and hands the bytes to the engine's dlopen (the .wasm grammar files
// published by `tree-sitter build --wasm` are emscripten side modules the
// engine loads natively). Absent => behavior unchanged ("No parser for
// language" as today).
export interface ParsersConfig {
  baseUrl?: string;
  urls?: Record<string, string>;
}

export interface CreateNvimOptions {
  transport?: Transport;
  MessagePack?: MessagePackModule;
}

export interface BrowserEngineConfig {
  args?: string[];
  env?: Record<string, string>;
  cwd?: string;
  filesystem?: Record<string, string>;
  plugins?: PluginsVariant;
  parsers?: ParsersConfig | null;
}

export interface CreateOptions extends BrowserEngineConfig {
  baseUrl?: string;
  engineUrl?: string;
  transport?: Transport;
  MessagePack?: MessagePackModule;
  clipboard?: ClipboardOption | null;
}

// A request/notification handler invoked by the engine.
export type RequestHandler = (method: string, params: any[]) => any;

// The headless core instance (returned by createNvim).
export interface NeovimInstance {
  request(method: string, params?: any[]): Promise<any>;
  notify(method: string, params?: any[]): void;
  input(keys: string): void;
  onNotification(method: string, fn: (params: any) => void): () => void;
  onStatus(fn: (status: NvimStatus) => void): () => void;
  onRequest(fn: RequestHandler): void;
  chan: number | null;
  dispose(): void;
  ready: Promise<NeovimInstance>;
}

// create()'s "promise-facade": a real Promise that fulfills with the ready
// instance, plus the instance's synchronous surface forwarded onto it.
export interface NeovimFacade extends Promise<NeovimInstance> {
  request(method: string, params?: any[]): Promise<any>;
  notify(method: string, params?: any[]): void;
  input(keys: string): void;
  onNotification(method: string, fn: (params: any) => void): () => void;
  onStatus(fn: (status: NvimStatus) => void): () => void;
  onRequest(fn: RequestHandler): void;
  dispose(): void;
  ready: Promise<NeovimInstance>;
  readonly chan: number | null;
}

// ---- ByteQueue ------------------------------------------------------------

// A tiny async-iterable byte queue: the transport pushes RPC chunks in,
// @msgpack/msgpack's decodeMultiStream pulls whole values out (handling
// msgpack messages split across postMessage boundaries).
export class ByteQueue implements AsyncIterable<Uint8Array> {
  private _items: Uint8Array[] = [];
  private _waiters: Array<(r: IteratorResult<Uint8Array>) => void> = [];
  private _done = false;

  push(u8: Uint8Array): void {
    const w = this._waiters.shift();
    if (w) { w({ value: u8, done: false }); }
    else { this._items.push(u8); }
  }
  close(): void {
    this._done = true;
    while (this._waiters.length) {
      this._waiters.shift()!({ value: undefined as any, done: true });
    }
  }
  [Symbol.asyncIterator](): AsyncIterator<Uint8Array> {
    const self = this;
    return {
      next(): Promise<IteratorResult<Uint8Array>> {
        if (self._items.length) {
          return Promise.resolve({ value: self._items.shift()!, done: false });
        }
        if (self._done) {
          return Promise.resolve({ value: undefined as any, done: true });
        }
        return new Promise(function (res) { self._waiters.push(res); });
      },
    };
  }
}

// ---- createNvim -----------------------------------------------------------

// Create a headless Neovim instance over `transport`. `MessagePack` is the
// @msgpack/msgpack module ({encode, decodeMultiStream}); it defaults to the
// UMD global when present (browser). Returns the instance immediately; its
// `.ready` promise resolves once the engine answers nvim_get_api_info (which
// also populates `.chan`).
export function createNvim(opts?: CreateNvimOptions): NeovimInstance {
  opts = opts || {};
  const transport = opts.transport;
  if (!transport) { throw new Error('createNvim: opts.transport is required'); }
  const MP: MessagePackModule | null = opts.MessagePack ||
    (typeof (globalThis as any).MessagePack !== 'undefined' ? (globalThis as any).MessagePack : null);
  if (!MP) { throw new Error('createNvim: MessagePack (@msgpack/msgpack) not provided'); }

  let nextMsgId = 1;
  const pending: Record<number, { resolve: (v: any) => void; reject: (e: any) => void }> = {};
  const notifyHandlers: Record<string, Array<(params: any) => void>> = {};
  const statusHandlers: Array<(status: NvimStatus) => void> = [];
  let requestHandler: RequestHandler | null = null;
  const inbox = new ByteQueue();
  let closed = false;

  function send(value: any): void {
    // Standalone copy so the buffer can be transferred (zero-copy clone).
    const u8 = MP!.encode(value).slice();
    transport!.send(u8);
  }
  function request(method: string, params?: any[]): Promise<any> {
    const id = nextMsgId++;
    const p = new Promise(function (resolve, reject) { pending[id] = { resolve: resolve, reject: reject }; });
    send([0, id, method, params || []]);
    return p;
  }
  function notify(method: string, params?: any[]): void { send([2, method, params || []]); }

  function onMessage(msg: any): void {
    if (!Array.isArray(msg)) { return; }
    const type = msg[0];
    if (type === 1) {                       // response: [1, msgid, error, result]
      const h = pending[msg[1]];
      if (h) { delete pending[msg[1]]; if (msg[2]) { h.reject(msg[2]); } else { h.resolve(msg[3]); } }
    } else if (type === 2) {                // notification: [2, method, params]
      const hs = notifyHandlers[msg[1]];
      if (hs) { for (let i = 0; i < hs.length; i++) { hs[i](msg[2]); } }
    } else if (type === 0) {                // request from engine: [0, msgid, method, params]
      // ASYNC SEAM: the handler may return a value OR a Promise. We always
      // await it (via Promise.resolve, so a plain synchronous return still
      // works), then reply [1, msgid, error, result]. nvim BLOCKS on
      // rpcrequest, but the engine's poll() suspends via JSPI, so an async
      // reply is fine -- the engine just waits. Without a handler we reply nil
      // (what most UIs want). A throw / rejection becomes an RPC error so the
      // engine's rpcrequest fails rather than hanging.
      const msgid = msg[1];
      let p: Promise<any>;
      if (requestHandler) {
        try { p = Promise.resolve(requestHandler(msg[2], msg[3])); }
        catch (e) { p = Promise.reject(e); }
      } else {
        p = Promise.resolve(null);
      }
      p.then(function (result) {
        send([1, msgid, null, result === undefined ? null : result]);
      }, function (err) {
        send([1, msgid, String(err && err.message || err), null]);
      });
    }
  }

  function emitStatus(s: NvimStatus): void { for (let i = 0; i < statusHandlers.length; i++) { statusHandlers[i](s); } }

  transport.onMessage = function (u8) { inbox.push(u8); };
  transport.onClose = function () { closeInstance(); };
  transport.onStatus = emitStatus;

  function closeInstance(): void {
    if (closed) { return; }
    closed = true;
    inbox.close();
    emitStatus({ kind: 'exit' });
    // Reject any in-flight requests so callers don't hang forever.
    for (const id in pending) {
      if (Object.prototype.hasOwnProperty.call(pending, id)) {
        pending[id as any].reject(new Error('engine closed'));
        delete pending[id as any];
      }
    }
  }

  async function receiveLoop(): Promise<void> {
    try {
      for await (const msg of MP!.decodeMultiStream(inbox)) { onMessage(msg); }
    } catch (err: any) {
      emitStatus({ kind: 'error', error: String(err && err.stack || err) });
    }
  }

  const instance: NeovimInstance = {
    request: request,
    notify: notify,
    // Convenience: feed raw key input to the engine.
    input: function (keys) { return notify('nvim_input', [keys]); },
    // Subscribe to a notification method (e.g. 'redraw'). Returns an unsubscribe fn.
    onNotification: function (method, fn) {
      (notifyHandlers[method] || (notifyHandlers[method] = [])).push(fn);
      return function () {
        const hs = notifyHandlers[method];
        if (!hs) { return; }
        const idx = hs.indexOf(fn);
        if (idx !== -1) { hs.splice(idx, 1); }
      };
    },
    // Subscribe to out-of-band transport status ({kind:'booting'|'stdout'|
    // 'stderr'|'exit'|'error', ...}). Returns an unsubscribe fn.
    onStatus: function (fn) {
      statusHandlers.push(fn);
      return function () { const i = statusHandlers.indexOf(fn); if (i !== -1) { statusHandlers.splice(i, 1); } };
    },
    // Handle requests the engine makes of the client (rare). fn(method, params)
    // -> reply value. Without one we reply nil, which is what most UIs want.
    onRequest: function (fn) { requestHandler = fn; },
    chan: null,         // this client's RPC channel id (set once ready)
    dispose: function () { try { if (transport!.close) { transport!.close(); } } finally { closeInstance(); } },
    ready: undefined as any,
  };

  receiveLoop();
  if (transport.start) { transport.start(); }

  // Round-trip one request so callers can `await nvim.ready`, and learn our
  // channel id (needed to address rpcnotify() back at us). This also proves
  // the engine booted and the transport works end to end.
  instance.ready = request('nvim_get_api_info').then(function (info) {
    instance.chan = Array.isArray(info) ? info[0] : null;
    return instance;
  });

  return instance;
}

// ---- clipboard (the first ENGINE->page call) ----------------------------
//
// Background: every other call goes page->engine. The clipboard is the first
// call the ENGINE makes OF the page. When nvim yanks to the `+`/`*` register it
// invokes its clipboard PROVIDER; we wire that provider to rpcrequest()s back at
// this client (addressed by `instance.chan`). The client answers those requests
// through the async onRequest seam above:
//   * copy:  engine -> rpcrequest(chan, 'clipboard_set', lines, regtype)
//   * paste: engine -> rpcrequest(chan, 'clipboard_get')  -> [lines, regtype]
// nvim BLOCKS on rpcrequest, but the engine's poll() suspends via JSPI, so the
// client's reply may be async (e.g. navigator.clipboard.readText()).
//
// A clipboard PROVIDER is `{ get(): Promise<string|[lines,regtype]>,
//                            set(lines, regtype): Promise<void>|void }`.
// `get` may return a plain string (wrapped as [string.split('\n'), 'v']) or a
// [lines, regtype] pair; `set` receives (lines, regtype).

// A built-in provider backed by navigator.clipboard. If navigator.clipboard is
// absent (e.g. Node, or an insecure context) it does NOT throw at construction;
// get()/set() reject/warn so the failure surfaces as a clear RPC error rather
// than at install time. CAVEAT: navigator.clipboard.readText() may be denied
// without a user gesture (paste then yields an error to nvim).
function browserClipboardProvider(): ClipboardProvider {
  function clip(): any {
    return (typeof navigator !== 'undefined' && navigator.clipboard) || null;
  }
  // A plain-text clipboard cannot carry nvim's regtype (charwise 'v' vs linewise
  // 'V' vs blockwise 'b'), so a naive round-trip would turn every `yy` into a
  // charwise paste (`yyp` -> "linelines" instead of two lines). We recover the
  // regtype two ways, mirroring nvim's own provider/clipboard.vim:
  //   1. cache the last value WE wrote, and reuse its regtype when the clipboard
  //      still holds it (the common in-editor yank->put); and
  //   2. otherwise infer from a trailing newline -- the same convention the
  //      shell providers (xclip/pbcopy/win32yank) use: text ending in "\n" is
  //      linewise. This makes copy/paste with external apps behave sanely too.
  let last: { text: string; value: [string[], string] } | null = null;
  return {
    get: function () {
      const c = clip();
      if (!c || typeof c.readText !== 'function') {
        return Promise.reject(new Error('clipboard: navigator.clipboard.readText unavailable'));
      }
      return c.readText().then(function (raw: any): [string[], string] {
        const text = String(raw == null ? '' : raw);
        // If the clipboard still holds what we last copied, reuse its regtype.
        // Some platform clipboards strip a lone trailing newline, so match the
        // stored text with and without it.
        if (last && (text === last.text || text + '\n' === last.text)) {
          return [last.value[0].slice(), last.value[1]];
        }
        // External copy: a trailing newline marks a linewise selection.
        if (text.length > 0 && text.charAt(text.length - 1) === '\n') {
          return [text.slice(0, -1).split('\n'), 'V'];
        }
        return [text.split('\n'), 'v'];
      });
    },
    set: function (lines, regtype) {
      const c = clip();
      const arr = Array.isArray(lines) ? lines : [String(lines == null ? '' : lines)];
      const text = arr.join('\n');
      // Remember the exact bytes + regtype so a later get() can restore the
      // regtype the plain-text clipboard would otherwise lose.
      last = { text: text, value: [arr.slice(), regtype || 'v'] };
      if (!c || typeof c.writeText !== 'function') {
        if (typeof console !== 'undefined') {
          console.warn('clipboard: navigator.clipboard.writeText unavailable; copy ignored');
        }
        return Promise.resolve();
      }
      // Don't let a writeText rejection (e.g. "Document is not focused", or a
      // denied permission) propagate to nvim and error out the YANK -- the text
      // is already in nvim's register; only the mirror to the system clipboard
      // failed. Warn and resolve so editing isn't interrupted. (Paste/get does
      // propagate, so a failed read still surfaces.)
      return Promise.resolve(c.writeText(text)).catch(function (e: any) {
        if (typeof console !== 'undefined') {
          console.warn('clipboard: writeText failed (copy not mirrored to system clipboard):', e && e.message || e);
        }
      });
    },
  };
}

// Normalise a clipboard option into a provider object. Accepts:
//   'browser'  -> the built-in navigator.clipboard provider
//   <provider> -> a custom { get, set } object (the escape hatch / embedder hook)
function resolveClipboardProvider(clipboard: ClipboardOption): ClipboardProvider {
  if (clipboard === 'browser') { return browserClipboardProvider(); }
  if (clipboard && typeof (clipboard as any).get === 'function' && typeof (clipboard as any).set === 'function') {
    return clipboard as ClipboardProvider;
  }
  throw new Error("clipboard option must be 'browser' or a { get, set } provider");
}

// enableClipboard(instance, provider) -- wire `provider` as the instance's
// clipboard. Reusable + unit-testable; exported as Neovim.enableClipboard for
// embedders driving createNvim() directly. Must be called AFTER the instance is
// ready (so instance.chan exists). It:
//   a. installs an onRequest handler that routes 'clipboard_get'/'clipboard_set'
//      to the provider and DELEGATES every other method to a caller-supplied
//      onRequest (if any) -- it never silently clobbers a user's handler;
//   b. sets g:clipboard in the engine so nvim's clipboard provider calls back
//      via rpcrequest(<instance.chan>, 'clipboard_get'/'clipboard_set', ...);
//   c. sets `clipboard=unnamedplus` so plain y/p/d use the system clipboard
//      (pass setRegister=false to wire only the explicit "+/"* registers).
// Returns a Promise that resolves once g:clipboard is installed.
export function enableClipboard(
  instance: NeovimInstance,
  provider: ClipboardProvider,
  prevRequestHandler?: RequestHandler | null,
  setRegister?: boolean,
): Promise<any> {
  if (instance.chan == null) {
    throw new Error('enableClipboard: instance has no RPC channel yet (await instance.ready)');
  }
  // Compose: clipboard methods first, then delegate to the prior handler.
  instance.onRequest(function (method, params) {
    params = params || [];
    if (method === 'clipboard_get') {
      return Promise.resolve(provider.get()).then(function (res: any) {
        // Accept a plain string (wrap as [lines, 'v']) or a [lines, regtype] pair.
        if (typeof res === 'string') { return [res.split('\n'), 'v']; }
        if (Array.isArray(res) && Array.isArray(res[0])) { return res; }
        if (Array.isArray(res)) { return [res, 'v']; }   // a bare lines array
        return [[''], 'v'];
      });
    }
    if (method === 'clipboard_set') {
      // params: [lines, regtype, reg] -- nvim passes the lines list and regtype.
      return Promise.resolve(provider.set(params[0], params[1]));
    }
    if (typeof prevRequestHandler === 'function') {
      return prevRequestHandler(method, params);
    }
    return null;   // unknown method, no delegate -> reply nil (as default)
  });

  // Install g:clipboard with Lua function entries that rpcrequest() back at us.
  // nvim's provider (runtime/autoload/provider/clipboard.vim) accepts a
  // g:clipboard dict whose copy/paste '+'/'*' entries are FUNCREFS (it checks
  // `type(...) == v:t_func`). A Lua function assigned via vim.g.clipboard
  // becomes a v:t_func funcref, so the provider calls it directly:
  //   paste: s:paste[reg]()           -> our get  -> returns [lines, regtype]
  //   copy:  s:copy[reg](lines, type) -> our set
  // We force-reload the provider (unlet g:loaded_clipboard_provider + re-source)
  // so it re-reads g:clipboard even if it was evaluated during startup.
  const chan = instance.chan;
  const lua =
    'local chan = ...\n' +
    'local function paste(reg)\n' +
    '  return function()\n' +
    '    return vim.rpcrequest(chan, "clipboard_get", reg)\n' +
    '  end\n' +
    'end\n' +
    'local function copy(reg)\n' +
    '  return function(lines, regtype)\n' +
    '    vim.rpcrequest(chan, "clipboard_set", lines, regtype, reg)\n' +
    '  end\n' +
    'end\n' +
    'vim.g.clipboard = {\n' +
    '  name = "neovim-wasm",\n' +
    '  copy = { ["+"] = copy("+"), ["*"] = copy("*") },\n' +
    '  paste = { ["+"] = paste("+"), ["*"] = paste("*") },\n' +
    '  cache_enabled = 0,\n' +
    '}\n' +
    // Re-source the provider so g:loaded_clipboard_provider re-evaluates against
    // the new g:clipboard (it may have been 0 from a headless boot with no tool).
    'pcall(function() vim.g.loaded_clipboard_provider = nil end)\n' +
    'vim.cmd("runtime autoload/provider/clipboard.vim")\n' +
    // Route the UNNAMED register through the clipboard so plain y/p/d "just
    // work" with the system clipboard -- without this, only the explicit "+/"*
    // registers ("+p etc.) touch it, which surprises most users. Skipped when
    // setRegister is false (an embedder who wants only the +/* registers).
    (setRegister === false ? '' : 'pcall(function() vim.o.clipboard = "unnamedplus" end)\n');
  return instance.request('nvim_exec_lua', [lua, [chan]]);
}

// Browser convenience: spawn the engine in a Web Worker (engine-worker.js) and
// wrap it as a transport. `config` is the engine init payload sent as the
// worker's first message: { args, env, cwd, filesystem }. `args` are the nvim
// args (without `--embed`, which the worker prepends); env/cwd/filesystem are
// the optional create() runtime config that engine-worker.js forwards to pre.js
// via the __nvim* globals. Only valid in a browser/worker context (uses Worker).
//
// Back-compat: a bare array may be passed in place of `config` (legacy
// `browserEngineTransport(url, args)` callers) -- it is treated as `{ args }`.
export function browserEngineTransport(engineUrl: string, config?: BrowserEngineConfig | string[]): Transport {
  if (Array.isArray(config)) { config = { args: config }; }
  config = config || {};
  const init = {
    args: config.args || [],
    env: config.env,
    cwd: config.cwd,
    filesystem: config.filesystem,
    // Runtime bundle variant. engine-worker.js loads nvim-<plugins>.data.js
    // before nvim.js. Default 'full'.
    plugins: config.plugins,
    // Optional runtime-fetched tree-sitter grammars ({ baseUrl?, urls? }).
    // engine-worker.js installs the fetch hook the engine falls back to when
    // no parser file exists; absent => no hook (additive/opt-in).
    parsers: config.parsers,
  };
  const worker = new Worker(engineUrl);
  const t: Transport = {
    onMessage: null,
    onClose: null,
    onStatus: null,
    send: function (u8) { worker.postMessage(u8.buffer, [u8.buffer]); },
    start: function () { worker.postMessage(init); },
    close: function () { worker.terminate(); },
  };
  worker.onmessage = function (e) {
    const d = e.data;
    if (d instanceof ArrayBuffer) { if (t.onMessage) { t.onMessage(new Uint8Array(d)); } return; }
    if (d && d.kind === 'exit') { if (t.onClose) { t.onClose(); } return; }
    if (t.onStatus) { t.onStatus(d); }
  };
  worker.onerror = function (e) {
    if (t.onStatus) { t.onStatus({ kind: 'error', error: e.message || (e.filename + ':' + e.lineno) }); }
  };
  return t;
}

// Resolve the engine-worker URL from opts. Precedence:
//   1. opts.engineUrl  (explicit override; used verbatim)
//   2. opts.baseUrl + 'engine-worker.js'  (host the bundle anywhere)
//   3. 'engine-worker.js'  (relative to the page, the original behaviour)
// `baseUrl` accepts a value with or without a trailing slash.
//
// How the rest of the asset chain resolves once engine-worker.js is loaded
// from `baseUrl` (verified by hosting the bundle from a subpath and curling
// the asset URLs, see wasm/web/build-lib.sh):
//   * The worker does `importScripts('nvim.js')`, which resolves RELATIVE to
//     the worker's own URL -- i.e. relative to `baseUrl`. So nvim.js loads
//     from baseUrl/nvim.js with no extra plumbing.
//   * Emscripten's browser `locateFile` then resolves nvim.wasm / nvim.data
//     relative to the script that loaded it (nvim.js, itself under baseUrl),
//     so those land under baseUrl too.
// The whole chain therefore follows `baseUrl` automatically; nothing needs to
// be threaded into the worker. CAVEAT: `new Worker(url)` requires a SAME-ORIGIN
// url, so `baseUrl` may point at a subpath of the page's origin but not at a
// different-origin CDN. Cross-origin hosting needs a Blob-bootstrap shim, which
// is intentionally out of scope here (see wasm/README.md).
export function resolveEngineUrl(opts: { engineUrl?: string; baseUrl?: string }): string {
  if (opts.engineUrl) { return opts.engineUrl; }
  if (opts.baseUrl) {
    let base = opts.baseUrl;
    if (base.charAt(base.length - 1) !== '/') { base += '/'; }
    return base + 'engine-worker.js';
  }
  return 'engine-worker.js';
}

// Runtime bundle variants (the `plugins` option). nvim.wasm is shared across
// all of them; each is a different (nvim-<variant>.data + loader) pair:
//   full    - the complete runtime (default).
//   core    - trimmed: boot + edit + filetype/indent + a curated syntax slice.
//   minimal - strictly the boot/edit essentials (no syntax/ftplugin/doc).
const PLUGIN_VARIANTS: Record<string, number> = { full: 1, core: 1, minimal: 1 };

// Validate the optional `parsers` config (runtime-fetched tree-sitter
// grammars). ADDITIVE and OPT-IN: absent => no hook is installed and a missing
// grammar errors exactly as today. Returns the normalized config or null.
function validateParsers(parsers: ParsersConfig | null | undefined): ParsersConfig | null {
  if (parsers == null) { return null; }
  if (typeof parsers !== 'object') {
    throw new Error('Neovim.create: parsers must be an object { baseUrl?, urls? }');
  }
  if (parsers.baseUrl != null && typeof parsers.baseUrl !== 'string') {
    throw new Error('Neovim.create: parsers.baseUrl must be a string URL prefix');
  }
  if (parsers.urls != null && typeof parsers.urls !== 'object') {
    throw new Error('Neovim.create: parsers.urls must be a map of language name -> URL');
  }
  if (parsers.baseUrl == null && parsers.urls == null) {
    throw new Error('Neovim.create: parsers needs baseUrl and/or urls');
  }
  return { baseUrl: parsers.baseUrl, urls: parsers.urls };
}

// The README-facing entry point: build a browser engine transport and a core
// instance over it.
//   opts: { args, baseUrl, engineUrl, transport, MessagePack,
//           env, cwd, filesystem, plugins }
// `plugins` selects the runtime bundle ('full' (default) | 'core' | 'minimal');
// all share one nvim.wasm and differ only in which nvim-<variant>.data the
// engine worker loads. It is validated here and only applies on the default
// browser worker path (with a caller-supplied `transport` it has no effect).
// env/cwd/filesystem are the runtime config (see wasm/README.md): they are
// carried in the engine worker's init message and applied by pre.js before the
// engine's main() runs. With a caller-supplied `transport` they have no effect
// (the transport owns the engine handshake), so they only apply on the default
// browser path.
//
// RETURN SHAPE -- a "promise-facade": create() returns a real Promise that
// FULFILLS WITH THE (distinct) ready instance, so `await Neovim.create(...)`
// yields a fully-usable instance. The same object ALSO carries the instance's
// synchronous members forwarded onto it (request/notify/input/onNotification/
// onStatus/onRequest/dispose/ready and a `chan` getter), so the existing
// synchronous usage (app.js: subscribe onStatus, mount_into, then `.ready`)
// keeps working WITHOUT awaiting.
//
// CORRECTNESS: a Promise can never fulfill with itself (the Promise resolution
// procedure would deadlock). So the facade must fulfill with the *instance*,
// which is a DISTINCT, non-thenable object -- NOT with the facade. We therefore
// build the facade from `instance.ready` (which already fulfills with the
// instance) and never make the instance itself thenable. createNvim() stays a
// plain synchronous instance and is intentionally NOT wrapped.
export function create(opts?: CreateOptions): NeovimFacade {
  opts = opts || {};
  // Validate `plugins` up front so a typo fails loudly here, not after the
  // worker silently 404s on a missing nvim-<typo>.data.js.
  if (opts.plugins != null && !PLUGIN_VARIANTS[opts.plugins]) {
    throw new Error("Neovim.create: unknown plugins variant '" + opts.plugins +
      "' (expected 'full', 'core', or 'minimal')");
  }
  // Validate the optional runtime-grammar config (opt-in; absent => unchanged).
  const parsers = validateParsers(opts.parsers);
  const transport = opts.transport ||
    browserEngineTransport(resolveEngineUrl(opts), {
      args: opts.args || [],
      env: opts.env,
      cwd: opts.cwd,
      filesystem: opts.filesystem,
      plugins: opts.plugins,
      // Threaded as init.parsers; the worker installs the grammar fetch hook.
      parsers: parsers,
    });
  const instance = createNvim({ transport: transport, MessagePack: opts.MessagePack });

  // Clipboard: if requested, resolve the provider up front (so a bad option
  // throws synchronously from create()), then install it after the instance is
  // ready. We compose with any onRequest the caller sets on the facade BEFORE
  // we install (clipboard methods first, then delegate), so we never clobber a
  // user handler. Track the last user-set onRequest here.
  let userRequestHandler: RequestHandler | null = null;
  const clipboardProvider = (opts.clipboard != null)
    ? resolveClipboardProvider(opts.clipboard) : null;

  // A real Promise fulfilling with the DISTINCT instance once it's ready, after
  // the clipboard (if any) is wired so an awaiter gets a clipboard-ready
  // instance. A clipboard install failure is surfaced as a status, not a reject,
  // so the editor is still usable without clipboard.
  const facade = instance.ready.then(function () {
    if (!clipboardProvider) { return instance; }
    return enableClipboard(instance, clipboardProvider, userRequestHandler)
      .then(function () { return instance; }, function (err) {
        if (typeof console !== 'undefined') {
          console.warn('clipboard: failed to install g:clipboard:', err);
        }
        return instance;
      });
  }) as NeovimFacade;

  // Forward the instance's synchronous surface onto the facade so callers who
  // don't await still get the instance API directly off the create() result.
  (['request', 'notify', 'input', 'onNotification', 'onStatus',
    'dispose'] as const).forEach(function (m) {
    (facade as any)[m] = function () { return (instance as any)[m].apply(instance, arguments); };
  });
  // onRequest is intercepted so the clipboard install can compose with (rather
  // than clobber) a user-supplied handler regardless of call order. If clipboard
  // is already installed, re-install so the new user handler is the delegate.
  facade.onRequest = function (fn: RequestHandler) {
    userRequestHandler = fn;
    if (clipboardProvider && instance.chan != null) {
      enableClipboard(instance, clipboardProvider, userRequestHandler);
    } else if (!clipboardProvider) {
      instance.onRequest(fn);
    }
    // else: clipboard requested but not ready yet -- the facade's ready handler
    // above installs it with this userRequestHandler as the delegate.
  };
  facade.ready = instance.ready;
  // `chan` is set asynchronously on the instance once ready; expose it live.
  Object.defineProperty(facade, 'chan', {
    enumerable: true,
    get: function () { return instance.chan; },
  });
  return facade;
}
