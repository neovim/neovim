// wasm/web/src/app.ts - page wiring for the browser demo.
//
// This is the thin glue an embedder would write: it composes the library
// layers -- the headless core (neovim.js), the headless screen model
// (neovim-ui.js) and the <pre> DOM renderer (neovim-ui-pre.js) -- into the
// page. All the reusable logic lives in those modules; this file only knows
// about *this* page's DOM and status line.
//
// Loaded as a classic <script> after the library bundles set their globals,
// so it reads `Neovim` / `NeovimUIPre` off the global scope (declared below).

declare const Neovim: any;
declare const NeovimUIPre: any;

(function () {
  const win = window as any;
  const statusEl = document.getElementById('status');
  const screenEl = document.getElementById('screen') as HTMLElement;

  function setStatus(s: string, opts?: { error?: boolean }) {
    if (!s) { return; }
    // Also mirrored onto <body data-status> as a persistent, machine-readable
    // signal automated tests can poll for boot state.
    document.body.setAttribute('data-status', s);
    if (statusEl) {
      statusEl.textContent = s;
      statusEl.classList.toggle('error', !!(opts && opts.error));
    }
  }

  setStatus('starting engine worker…');

  // 1. Core: boot `nvim --embed` in a Web Worker and speak msgpack-RPC to it.
  //    -n: no swap files (there is no meaningful place for them in MEMFS).
  //    clipboard: 'browser' wires the +/* registers (and, via unnamedplus,
  //    plain y/p/d) to the system clipboard through navigator.clipboard.
  //    Pasting may prompt for clipboard-read permission the first time; needs
  //    a secure context (HTTPS or localhost).
  const nvim = Neovim.create({ args: ['-n'], clipboard: 'browser' });

  nvim.onStatus(function (s: any) {
    if (!s) { return; }
    if (s.kind === 'booting') { setStatus('engine booting (loading wasm + runtime)…'); }
    else if (s.kind === 'stdout' || s.kind === 'stderr') {
      console.log('[engine ' + s.kind + ']', s.text);
    }
    else if (s.kind === 'exit') { setStatus('engine exited'); }
    else if (s.kind === 'error') { console.error('engine error', s.error); setStatus('engine error: ' + s.error, { error: true }); }
  });

  // 2. Renderer: mount the <pre> grid UI and forward keystrokes. No fixed
  //    cols/rows -> mount_into auto-sizes the grid to fill #screen and tracks
  //    its size (resize the window to reflow).
  const ui = NeovimUIPre.mount_into(nvim, screenEl, {
    font_family: 'ui-monospace, "DejaVu Sans Mono", Menlo, Consolas, monospace',
    font_size: 16,
  });

  nvim.ready
    .then(function () {
      setStatus('attached — click the grid and type (chan ' + nvim.chan + ')');
    })
    .catch(function (err: any) { setStatus('failed to start: ' + (err && err.message || err), { error: true }); });

  // 3. Expose a tiny API for debugging / automated testing.
  win.nvim = {
    input: function (keys: string) { return nvim.input(keys); },
    request: function (method: string, params: any[]) { return nvim.request(method, params); },
    resize: function (c: number, r: number) { return ui.resize(c, r); },
    gridText: function () { return ui.screen.text(); },
    state: function () { return { cols: ui.screen.cols, rows: ui.screen.rows, cursor: ui.screen.cursor }; },
  };
})();
