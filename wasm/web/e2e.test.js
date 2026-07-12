// wasm/web/e2e.test.js - headless end-to-end test of the browser library split.
//
// Boots the REAL Neovim engine (build-wasm/bin/nvim.js, hosted in a Node
// worker_thread via wasm/worker.js) and drives it through the very same library
// layers the browser page uses:
//   * neovim.js      - the headless msgpack-RPC core (here over a Node worker
//                      transport instead of a Web Worker; the core can't tell).
//   * neovim-ui.js   - the headless Screen (redraw -> grid decode) the page
//                      renders into. We assert on it directly, no DOM.
//
// This is what validates that the core/renderer split is clean: if either layer
// secretly depended on the DOM or on a specific worker host, this test couldn't
// run. It also locks the msgpack-RPC contract end to end.
//
// Prereqs: a finished wasm/build-nvim.sh (build-wasm/bin/{nvim.js,nvim.wasm,
// nvim.data,worker.js}) and `npm install` in wasm/web (@msgpack/msgpack).
// Run:  node wasm/web/e2e.test.js        (Node >= 24, or >= 22 with
//                                          --experimental-wasm-jspi)
'use strict';

const path = require('path');
const fs = require('fs');
const { Worker } = require('worker_threads');

const MessagePack = require('@msgpack/msgpack');
// The library is compiled from TypeScript (src/) into dist/ by build-ts.sh; this
// test drives those build artifacts. `npm test` runs the build first (pretest).
const Neovim = require('./dist/neovim.js');
const NeovimUI = require('./dist/neovim-ui.js');

const ROOT = path.resolve(__dirname, '..', '..');
const BIN = path.join(ROOT, 'build-wasm', 'bin');
const WORKER = path.join(BIN, 'worker.js');

// ---- tiny test harness ----------------------------------------------------
let failures = 0;
function ok(cond, msg) {
  if (cond) { console.log('  ok   - ' + msg); }
  else { failures++; console.log('  FAIL - ' + msg); }
}
function fatal(msg) { console.error('e2e: ' + msg); process.exit(1); }
function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
async function waitFor(pred, timeoutMs, label) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (pred()) { return true; }
    await sleep(25);
  }
  return false;
}

// ---- a Node worker_thread transport (the analogue of the browser worker) ---
// `cfg` carries the create() runtime config { args, env, cwd, filesystem }; it is
// forwarded on workerData exactly as the browser path posts it in the worker's
// init message, so worker.js -> pre.js apply identical logic in both targets.
function nodeEngineTransport(cfg) {
  cfg = cfg || {};
  // Give the engine a clean env: drop NVIM_LOG_FILE so worker.js's `.engine`
  // suffix can't point at an unwritable path (which would emit a startup
  // warning -> hit-enter prompt). CI won't have it set; a dev shell might.
  const env = Object.assign({}, process.env);
  delete env.NVIM_LOG_FILE;
  const worker = new Worker(WORKER, {
    // worker.js prepends `--embed` to args and forwards env/cwd/filesystem to
    // the __nvim* globals pre.js reads.
    workerData: {
      args: cfg.args || [],
      env: cfg.env,
      cwd: cfg.cwd,
      filesystem: cfg.filesystem,
    },
    env: env,
    stdout: true, stderr: true,           // capture; don't litter the test output
  });
  const t = {
    onMessage: null, onClose: null, onStatus: null,
    send: function (u8) { worker.postMessage(u8.buffer, [u8.buffer]); },
    close: function () { worker.terminate(); },
  };
  worker.on('message', function (d) { if (t.onMessage) { t.onMessage(new Uint8Array(d)); } });
  worker.on('exit', function () { if (t.onClose) { t.onClose(); } });
  worker.on('error', function (e) { if (t.onStatus) { t.onStatus({ kind: 'error', error: String(e && e.stack || e) }); } });
  // Surface engine stderr only when explicitly debugging.
  if (process.env.NVIM_WASM_ENGINE_LOG === '-') {
    worker.stderr.on('data', function (b) { process.stderr.write(b); });
  }
  return { transport: t, worker: worker };
}

async function main() {
  if (typeof WebAssembly.Suspending === 'undefined') {
    fatal('this Node lacks JSPI (WebAssembly.Suspending). Use Node >= 24, or ' +
          'Node >= 22 with --experimental-wasm-jspi.');
  }
  // Under Node the runtime is read from the on-disk runtime/ tree (via the /home
  // NODEFS mount), not from a baked-in nvim.data -- nvim.wasm is runtime-agnostic
  // now and the file_packager .data packages are a BROWSER concern. So we no
  // longer require nvim.data here.
  for (const f of ['nvim.js', 'nvim.wasm', 'worker.js']) {
    if (!fs.existsSync(path.join(BIN, f))) {
      fatal('missing ' + path.join(BIN, f) + ' (run wasm/build-deps.sh && wasm/build-nvim.sh first)');
    }
  }

  // `-n` disables swap files (otherwise E303 + the intro both queue messages and
  // nvim raises a "Press ENTER" prompt that blocks input/RPC). `-u/-i NONE` keep
  // the session pristine, matching the browser demo.
  //
  // Exercise the create() runtime config seam (env/cwd/filesystem) on the SAME
  // path the browser uses: the values ride workerData -> worker.js -> __nvim*
  // globals -> pre.js preRun, identical to the browser's init message ->
  // engine-worker.js -> __nvim* globals -> pre.js. We assert each took effect via
  // RPC below (checks 6-8).
  const { transport, worker } = nodeEngineTransport({
    args: ['-u', 'NONE', '-i', 'NONE', '-n'],
    env: { NVIM_WASM_PROBE: 'hi-from-env' },
    filesystem: { '/work/hello.txt': 'seeded-contents\n' },
    cwd: '/work',
  });
  const nvim = Neovim.createNvim({ transport: transport, MessagePack: MessagePack });

  let engineError = null;
  nvim.onStatus(function (s) { if (s && s.kind === 'error') { engineError = s.error; } });

  // 1. Core boots and round-trips RPC: nvim.ready resolves with our channel id.
  const ready = await Promise.race([
    nvim.ready.then(function () { return 'ready'; }),
    sleep(20000).then(function () { return 'timeout'; }),
  ]);
  if (ready !== 'ready') { fatal('engine did not become ready within 20s' + (engineError ? (': ' + engineError) : '')); }
  ok(typeof nvim.chan === 'number' && nvim.chan > 0, 'nvim_get_api_info round-trips; chan = ' + nvim.chan);

  // 2. Renderer: drive the SAME headless Screen the page renders into.
  const screen = new NeovimUI.Screen(80, 24);
  nvim.onNotification('redraw', function (params) { screen.handleRedraw(params); });
  await nvim.request('nvim_ui_attach', [80, 24, { rgb: true, ext_linegrid: true }]);

  // Clear any residual startup "Press ENTER" prompt before driving input, so a
  // stray message in some environment can't make the test flaky.
  for (let i = 0; i < 20; i++) {
    const m = await nvim.request('nvim_get_mode');
    if (!m || !m.blocking) { break; }
    nvim.input('<CR>');
    await sleep(50);
  }

  // 3. Type into the buffer and assert the grid reflects it.
  nvim.input('ihello');
  nvim.input('<Esc>');
  const typed = await waitFor(function () { return /(^|\n)hello/.test(screen.text()); }, 10000);
  ok(typed, "typing 'ihello<Esc>' renders 'hello' on the grid");
  ok(screen.text().split('\n')[0].indexOf('hello') === 0, "'hello' is at the start of row 0");
  // After `ihello<Esc>` the cursor rests on the last inserted char ('o', col 4).
  // Wait for the post-Esc cursor_goto to land before asserting.
  const curOk = await waitFor(function () { return screen.cursor.row === 0 && screen.cursor.col === 4; }, 5000);
  ok(curOk, 'cursor decoded to row 0 col 4 (got ' + screen.cursor.row + ',' + screen.cursor.col + ')');

  // 4. Command line is drawn into the bottom grid row (no ext_cmdline).
  nvim.input(':');
  const cmdline = await waitFor(function () { return screen.text().split('\n')[screen.rows - 1].indexOf(':') === 0; }, 5000);
  ok(cmdline, "':' opens a command line on the bottom row");
  nvim.input('<Esc>');

  // 5. Colour decode: type Python, turn on syntax highlighting, and assert the
  //    headless Screen decoded REAL highlights (default_colors_set populated the
  //    defaults, hl_attr_define filled hlAttrs, and a keyword cell carries a
  //    non-zero hl id whose resolved attrs have a foreground). The Node host has
  //    the full on-disk runtime, so `:syntax on` actually highlights.
  //
  //    First clear the buffer so the typed text lands at a known place.
  await nvim.request('nvim_command', ['%delete _']);
  // `def` starts at column 0 of some line; type a keyword we can locate.
  nvim.input('iimport os<CR>def f():<Esc>');
  await waitFor(function () { return /(^|\n)def f\(\):/.test(screen.text()); }, 10000);
  await nvim.request('nvim_command', ['set filetype=python']);
  await nvim.request('nvim_command', ['syntax on']);

  // Find the row holding `def f():` and the column of its leading `d`.
  function defPos() {
    var rows = screen.text().split('\n');
    for (var i = 0; i < rows.length; i++) {
      var col = rows[i].indexOf('def f():');
      if (col >= 0) { return { row: i, col: col }; }
    }
    return null;
  }
  // Wait for syntax highlighting to flush: the `d` of `def` should get a non-zero
  // hl id once the python syntax loads.
  const highlit = await waitFor(function () {
    var p = defPos();
    if (!p) { return false; }
    return screen.hlIdAt(p.row, p.col) !== 0 && Object.keys(screen.hlAttrs).length > 1;
  }, 10000);
  ok(highlit, "`:syntax on` over python decodes a non-zero hl id on the `def` keyword");

  ok(Object.keys(screen.hlAttrs).length > 1,
     'hlAttrs is populated from hl_attr_define (' + Object.keys(screen.hlAttrs).length + ' entries)');
  ok(screen.defaultFg !== null || screen.defaultBg !== null,
     'default_colors_set populated the defaults (fg=' + screen.defaultFg + ', bg=' + screen.defaultBg + ')');

  const dp = defPos() || { row: 0, col: 0 };
  const defId = screen.hlIdAt(dp.row, dp.col);
  ok(defId !== 0, 'the `def` keyword cell has a non-zero hl id (' + defId + ')');
  const defAttrs = screen.attrAt(dp.row, dp.col);
  ok(typeof defAttrs.foreground === 'number',
     'the `def` keyword hl resolves to attrs with a foreground (' + JSON.stringify(defAttrs) + ')');

  // A plain-text cell (the `o` in `import os`, which is not a keyword) stays on
  // the default highlight (id 0).
  function importOsPos() {
    var rows = screen.text().split('\n');
    for (var i = 0; i < rows.length; i++) {
      var col = rows[i].indexOf('import os');
      if (col >= 0) { return { row: i, col: col + 8 }; }   // the trailing `s` of `os`
    }
    return null;
  }
  const ip = importOsPos();
  ok(ip !== null && screen.hlIdAt(ip.row, ip.col) === 0,
     'a plain-text cell resolves to the default highlight (id 0)');

  // 5b. The <pre> renderer (neovim-ui-pre.js, the demo page's renderer)
  //     renders the same Screen into styled HTML. Drive it with a stub
  //     element - no DOM library needed.
  const PreUI = require('./dist/neovim-ui-pre.js');
  const fakeEl = { style: {}, innerHTML: '' };
  PreUI.render(fakeEl, screen);
  ok(fakeEl.innerHTML.replace(/<[^>]*>/g, '').indexOf('def f():') !== -1,
     'neovim-ui-pre render() emits the screen text as HTML (tags stripped)');
  ok(fakeEl.innerHTML.indexOf('<span') !== -1 && fakeEl.innerHTML.indexOf('color:#') !== -1,
     'neovim-ui-pre render() emits colored spans for highlighted cells');

  // Clear any residual prompt that `syntax on` / the edits may have queued
  // (nvim_get_mode returns even while a hit-enter prompt is up), then drop the
  // scratch edits so later buffer switches don't hit an E37 "no write since
  // last change" prompt.
  nvim.input('<Esc>');
  for (let i = 0; i < 20; i++) {
    const m = await nvim.request('nvim_get_mode');
    if (!m || !m.blocking) { break; }
    nvim.input('<CR>');
    await sleep(50);
  }
  await nvim.request('nvim_command', ['set nomodified']);

  // ---- create() runtime config (env / filesystem / cwd) ---------------------
  // These assert the config we passed into nodeEngineTransport above reached the
  // engine via the create() seam (workerData -> worker.js -> __nvim* -> pre.js).

  // 6. env: pre.js applied our override on top of its defaults, so $NVIM_WASM_PROBE
  //    is visible to nvim's expand().
  const probe = await nvim.request('nvim_eval', ['$NVIM_WASM_PROBE']);
  ok(probe === 'hi-from-env', "env override is visible to nvim ($NVIM_WASM_PROBE = '" + probe + "')");

  // 7. filesystem: the seeded file exists in the wasm FS with the given contents.
  const lines = await nvim.request('nvim_exec_lua', ['return vim.fn.readfile("/work/hello.txt")', []]);
  ok(Array.isArray(lines) && lines.length === 1 && lines[0] === 'seeded-contents',
     "seeded /work/hello.txt reads back as 'seeded-contents' (got " + JSON.stringify(lines) + ')');

  // 8. cwd: pre.js chdir'd into the seeded dir, so getcwd() reflects it.
  const cwd = await nvim.request('nvim_eval', ['getcwd()']);
  ok(cwd === '/work', "cwd took effect (getcwd() = '" + cwd + "')");

  // ---- async onRequest seam + clipboard (engine -> page calls) ---------------
  // These exercise the FIRST direction where the engine makes requests OF the
  // client. Node has no navigator.clipboard, so we use a CUSTOM in-memory
  // provider -- which is also the embedder escape hatch the seam exists for.

  // 14. async onRequest seam: register an async handler that resolves a value
  //     after a tick, have the engine rpcrequest it, and assert the engine got
  //     the AWAITED value (proving we await the handler's Promise before replying).
  nvim.onRequest(function (method, params) {
    if (method === 'ping') {
      return new Promise(function (res) { setTimeout(function () { res('pong:' + params[0]); }, 30); });
    }
    if (method === 'boom') {
      return Promise.reject(new Error('handler-rejected'));
    }
    return null;
  });
  const pong = await nvim.request('nvim_exec_lua',
    ['return vim.rpcrequest(..., "ping", "hi")', [nvim.chan]]);
  ok(pong === 'pong:hi',
     "async onRequest: engine rpcrequest('ping') gets the awaited Promise value (got " + JSON.stringify(pong) + ')');

  // 15. a rejecting onRequest handler -> the engine's rpcrequest FAILS (does not
  //     hang). nvim_exec_lua should reject because vim.rpcrequest errored.
  let boomRejected = false;
  try {
    await nvim.request('nvim_exec_lua', ['return vim.rpcrequest(..., "boom")', [nvim.chan]]);
  } catch (e) {
    boomRejected = true;
  }
  ok(boomRejected, 'a rejecting onRequest handler makes the engine rpcrequest fail (does not hang)');

  // ---- clipboard round-trip via the in-memory provider -----------------------
  // An in-memory clipboard store + provider. set() records the call; get()
  // returns the seeded contents. enableClipboard composes this with the onRequest
  // handler we set above (clipboard methods first, then delegate to 'ping'/'boom').
  let store = { lines: ['seeded-paste'], regtype: 'v' };
  let lastSet = null;
  const memProvider = {
    get: function () { return [store.lines, store.regtype]; },
    set: function (lines, regtype) { lastSet = { lines: lines, regtype: regtype }; store = { lines: lines, regtype: regtype }; },
  };
  // The prior onRequest (ping/boom) must keep working after enableClipboard, so
  // pass it as the delegate.
  const priorHandler = function (method, params) {
    if (method === 'ping') {
      return new Promise(function (res) { setTimeout(function () { res('pong:' + params[0]); }, 30); });
    }
    if (method === 'boom') { return Promise.reject(new Error('handler-rejected')); }
    return null;
  };
  await Neovim.enableClipboard(nvim, memProvider, priorHandler);
  // enableClipboard sets clipboard=unnamedplus itself so plain y/p/d integrate
  // with the system clipboard (the user-facing default). Assert it took effect.
  const clipOpt = await nvim.request('nvim_get_option_value', ['clipboard', {}]);
  ok(clipOpt === 'unnamedplus',
     "enableClipboard sets clipboard=unnamedplus (plain y/p use the clipboard); got " + JSON.stringify(clipOpt));

  // 16. clipboard COPY: drive nvim to set the `+` register; assert provider.set
  //     was called with the expected lines (engine -> rpcrequest('clipboard_set')).
  await nvim.request('nvim_call_function', ['setreg', ['+', 'hello-clip']]);
  const sawSet = await waitFor(function () { return lastSet !== null; }, 5000);
  ok(sawSet, "clipboard COPY: setreg('+', ...) invokes provider.set (engine rpcrequested clipboard_set)");
  ok(sawSet && Array.isArray(lastSet.lines) && lastSet.lines.join('\n').indexOf('hello-clip') >= 0,
     'clipboard COPY: provider.set received the yanked lines (got ' + JSON.stringify(lastSet && lastSet.lines) + ')');

  // 17. clipboard PASTE: seed the store, read `+` back from the engine; assert it
  //     returns the seeded contents (engine -> rpcrequest('clipboard_get') -> us).
  store = { lines: ['paste-me-back'], regtype: 'v' };
  const pasted = await nvim.request('nvim_call_function', ['getreg', ['+']]);
  ok(pasted === 'paste-me-back',
     "clipboard PASTE: getreg('+') returns the provider's seeded contents (got " + JSON.stringify(pasted) + ')');

  // 18. the prior onRequest delegate still works after enableClipboard composed
  //     over it (clipboard methods first, then delegate).
  const pong2 = await nvim.request('nvim_exec_lua',
    ['return vim.rpcrequest(..., "ping", "again")', [nvim.chan]]);
  ok(pong2 === 'pong:again', 'enableClipboard composes with (does not clobber) the prior onRequest (ping still works)');

  // 18b. Bare y/p (NOT "+y/"+p) use the clipboard now that unnamedplus is set --
  //      this is exactly the "hitting p does what I expect" case. Seed a buffer
  //      line, `yy` (should copy to the provider), then `p` on a fresh buffer
  //      (should paste the provider's contents).
  lastSet = null;
  await nvim.request('nvim_command', ['enew!']);
  await nvim.request('nvim_buf_set_lines', [0, 0, -1, false, ['bare-yank-line']]);
  await nvim.request('nvim_command', ['normal! ggyy']);     // bare yank
  const bareYank = await waitFor(function () { return lastSet !== null; }, 5000);
  ok(bareYank && lastSet.lines.join('\n').indexOf('bare-yank-line') >= 0,
     'bare `yy` copies to the clipboard via unnamedplus (provider.set got the line)');
  store = { lines: ['bare-paste-content'], regtype: 'v' };
  await nvim.request('nvim_command', ['enew!']);
  await nvim.request('nvim_command', ['normal! p']);        // bare paste
  const bareLines = await nvim.request('nvim_buf_get_lines', [0, 0, -1, false]);
  ok(bareLines.join('\n').indexOf('bare-paste-content') >= 0,
     'bare `p` pastes from the clipboard via unnamedplus (got ' + JSON.stringify(bareLines) + ')');

  // 9. Lifecycle: when the engine goes away, the core must observe EOF and tear
  // down. This is the path the browser relies on (engine-worker posts
  // {kind:'exit'} -> transport.onClose -> the core closes). We simulate the
  // engine vanishing by terminating its worker, then assert the core both emits
  // 'exit' and rejects any in-flight request (so callers never hang).
  // (Note: in the BROWSER, `:qa!` terminates the engine and engine-worker.js
  // posts {kind:'exit'} on Module.onExit, so the channel closes on its own. The
  // Node host (wasm/worker.js) doesn't hook Module.onExit -- its worker_thread
  // stays alive in the JSPI-suspended poll -- so `:qa!` over RPC doesn't close
  // the channel here yet; we close from the host side instead. Either way this
  // exercises the same transport.onClose -> core-close path.)
  let closed = false;
  nvim.onStatus(function (s) { if (s && s.kind === 'exit') { closed = true; } });
  const hangs = nvim.request('nvim_eval', ['1+1']);   // in-flight across the close
  // The contract under test is "an in-flight request never HANGS forever once the
  // channel closes" -- it must settle. Normally it rejects (closeInstance rejects
  // all pending), but the engine can occasionally answer `2` before terminate()
  // lands, in which case it legitimately resolves. Accept either: assert it
  // settled (not still pending), which is the property callers actually rely on.
  let settled = false;
  hangs.then(function () { settled = true; }, function () { settled = true; });
  worker.terminate();
  await waitFor(function () { return closed; }, 5000);
  ok(closed, 'engine going away closes the channel (EOF propagates to the core)');
  await waitFor(function () { return settled; }, 2000);
  ok(settled, 'in-flight requests settle (do not hang) when the channel closes');

  console.log('');
  if (failures) { console.log(failures + ' check(s) FAILED'); process.exit(1); }
  console.log('all checks passed');
  process.exit(0);
}

main().catch(function (e) { fatal((e && e.stack) || String(e)); });
