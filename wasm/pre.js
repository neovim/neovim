// wasm/pre.js - Emscripten --pre-js for Neovim's wasm build.
//
// Concatenated into nvim.js and executed while the module initializes. It
// configures things Emscripten does not derive on its own:
//   * argv: under Node, the `node nvim.js -- <nvim args>` convention; in any
//     environment, a host may override argv via globalThis.__nvimArgs.
//   * a postMessage RPC channel (globalThis.__nvimChannel), for the engine role
//     (see wasm/nvim_io.js).
//   * $VIMRUNTIME + a minimal environment (Emscripten's ENV does not inherit
//     the host environment).
//
// This file runs in BOTH targets from one binary:
//   * Node (worker_thread engine, or the builtin-TUI client): `process` exists,
//     so we mount the host filesystem via NODEFS and copy across process.env.
//   * Browser (Web Worker engine): no `process`. The runtime ships preloaded
//     into MEMFS at /usr/share/nvim/runtime (--preload-file), and the host page
//     hands us argv + the postMessage channel through globals before the module boots.
(function () {
  var isNode = (typeof process !== 'undefined' &&
                process.versions && process.versions.node);

  // Where $VIMRUNTIME lives. nvim.wasm no longer bakes the runtime in via
  // --preload-file (it is RUNTIME-AGNOSTIC; see src/nvim/CMakeLists.txt). The two
  // targets get the runtime differently:
  //
  //   * BROWSER: there is no host FS, so a file_packager data package
  //     (nvim-<variant>.data + its loader) is loaded BEFORE nvim.js and unpacks
  //     the runtime into MEMFS at /usr/share/nvim/runtime. So the browser default
  //     stays /usr/share/nvim/runtime.
  //
  //   * NODE: the file_packager loader can't be used here -- loaded as a separate
  //     module under require()/importScripts, its top-line
  //     `var Module = typeof Module != 'undefined' ? Module : {}` resolves to a
  //     fresh throwaway object (Emscripten's own `var Module` shadows any we set),
  //     so its addRunDependency()/preRun would never reach the engine's Module.
  //     But Node doesn't need it: the real runtime/ tree is already on disk and
  //     reachable through the /home NODEFS mount below. So under Node we point
  //     VIMRUNTIME at the on-disk runtime/ next to the build (build-wasm/bin ->
  //     ../../runtime), giving every Node host the full runtime with zero
  //     per-host wiring and no .data at all.
  var VIMRUNTIME = '/usr/share/nvim/runtime';

  var args = [];
  if (isNode) {
    // argv after a literal `--` (or everything, if there's no `--`).
    args = process.argv.slice(2);
    var sep = args.indexOf('--');
    if (sep !== -1) {
      args = args.slice(sep + 1);
    }
    if (process.env.VIMRUNTIME) {
      VIMRUNTIME = process.env.VIMRUNTIME;
    } else {
      // Default to the on-disk runtime/ tree, resolved relative to nvim.js's dir
      // (build-wasm/bin) -> ../../runtime. It is reachable inside the wasm FS via
      // the /home NODEFS mount set up in preRun below. An explicit $VIMRUNTIME
      // (or a host passing __nvimEnv.VIMRUNTIME) still wins.
      try {
        var pth = require('path');
        VIMRUNTIME = pth.resolve(__dirname, '..', '..', 'runtime');
      } catch (e) { /* keep the /usr default if __dirname/path are unavailable */ }
    }
  }

  // A host (the engine worker, Node or browser) overrides argv and supplies the
  // postMessage RPC channel via globals. We read them here because
  // Emscripten's own `var Module` shadows any globalThis.Module a host could set.
  //
  // The same seam also carries the optional runtime config the `create()` API
  // exposes (see wasm/README.md): __nvimEnv (environment
  // overrides), __nvimFiles (files to seed into the wasm FS), __nvimCwd (working
  // directory). They are applied in preRun below, AFTER the default env/FS setup.
  var cfgEnv = null;    // { KEY: 'val', ... } environment overrides (caller wins)
  var cfgFiles = null;  // { '/abs/path': 'contents' | Uint8Array } files to seed
  var cfgCwd = null;    // '/abs/path' working directory to chdir into last
  if (typeof globalThis !== 'undefined') {
    if (globalThis.__nvimArgs) {
      args = globalThis.__nvimArgs;
    }
    if (globalThis.__nvimChannel) {
      Module['nvimChannel'] = globalThis.__nvimChannel;
    }
    if (globalThis.__nvimEnv) { cfgEnv = globalThis.__nvimEnv; }
    if (globalThis.__nvimFiles) { cfgFiles = globalThis.__nvimFiles; }
    if (typeof globalThis.__nvimCwd === 'string') { cfgCwd = globalThis.__nvimCwd; }
  }
  Module['arguments'] = args;
  // Keep a pristine copy: Emscripten's callMain() does args.unshift(thisProgram),
  // mutating Module['arguments'] in place before user code runs.
  Module['nvimUserArgs'] = args.slice();
  Module['thisProgram'] = '/usr/bin/nvim';
  // (locateFile for the preloaded nvim.data is set in wasm/extern-pre.js, which
  // runs before the data-package loader; --pre-js would be too late.)

  Module['preRun'] = Module['preRun'] || [];
  Module['preRun'].push(function () {
    if (isNode) {
      // Mount the host filesystem. Unlike NODERAWFS, MEMFS+NODEFS keeps fd 0/1 as
      // virtual streams (so they can be backed by the postMessage RPC channel), while real
      // files remain reachable. We mount each existing top-level host directory
      // onto the same path inside the wasm FS. /usr is intentionally skipped so it
      // does not shadow the preloaded runtime at /usr/share/nvim/runtime.
      try {
        var fs = require('fs');
        var NODEFS = FS.filesystems.NODEFS;
        var roots = ['/home', '/etc', '/opt', '/var', '/root', '/mnt',
                     '/tmp', '/srv', '/run'];
        // Ensure the on-disk VIMRUNTIME (default ../../runtime) is reachable even
        // if the checkout lives outside the roots above: mount its top-level dir.
        // (The runtime now comes from disk under Node, not a baked-in nvim.data.)
        try {
          var vrTop = '/' + String(VIMRUNTIME).split('/').filter(Boolean)[0];
          if (vrTop !== '/' && roots.indexOf(vrTop) === -1) { roots.push(vrTop); }
        } catch (e) { /* fall back to the fixed roots */ }
        for (var r = 0; r < roots.length; r++) {
          var d = roots[r];
          try {
            if (!fs.existsSync(d)) { continue; }
            try { FS.mkdir(d); } catch (e) { /* may already exist (e.g. /tmp) */ }
            FS.mount(NODEFS, { root: d }, d);
          } catch (e) { /* skip dirs we can't mount */ }
        }
        try { FS.chdir(process.cwd()); } catch (e) { /* stay at default cwd */ }
      } catch (e) {
        // No NODEFS (or mount failed): fall back to plain MEMFS.
      }
    } else {
      // Browser: no host FS. Make sure a couple of writable dirs exist for HOME
      // and temp files (we pass -i NONE, so shada is off, but be safe).
      ['/root', '/tmp'].forEach(function (d) {
        try { FS.mkdir(d); } catch (e) { /* exists */ }
      });
      try { FS.chdir('/root'); } catch (e) { /* stay at / */ }
    }

    // ENV is the Emscripten runtime's environment map (used by getenv()).
    ENV['VIMRUNTIME'] = VIMRUNTIME;
    if (isNode) {
      ENV['PWD'] = process.cwd();
      ENV['TERM'] = process.env.TERM || 'xterm-256color';
      var passthrough = [
        'HOME', 'USER', 'LOGNAME', 'SHELL', 'LANG', 'LC_ALL', 'PATH',
        'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME',
        'XDG_RUNTIME_DIR', 'NVIM_APPNAME', 'COLORTERM', 'NO_COLOR',
        'NVIM_LOG_FILE', '__NVIM_TEST_LOG',
      ];
      for (var j = 0; j < passthrough.length; j++) {
        var k = passthrough[j];
        if (process.env[k] !== undefined) {
          ENV[k] = process.env[k];
        }
      }
    } else {
      // Browser: no host environment to inherit; give nvim a writable MEMFS
      // home and a plausible identity. __nvimEnv (below) can override any of it.
      ENV['HOME'] = '/root';
      ENV['USER'] = 'web';
      ENV['LOGNAME'] = 'web';
      ENV['PWD'] = '/root';
      ENV['TERM'] = 'xterm-256color';
      ENV['LANG'] = 'C.UTF-8';
    }

    // --- create()-supplied runtime config (applied on top of the defaults) ---
    // Order matters: env first, then seed files (so a cwd inside a seeded dir
    // exists), then chdir into cwd last. All of these fail soft -- a bad path or
    // missing dir must not crash the engine boot.
    function dbg(msg) {
      try {
        if (typeof err === 'function') { err(msg); }
        else if (typeof console !== 'undefined') { console.warn(msg); }
      } catch (_e) { /* never let logging break boot */ }
    }

    // 1. env overrides: caller values win over the defaults set above. Works in
    //    BOTH targets (override HOME, set arbitrary vars, etc.).
    if (cfgEnv && typeof cfgEnv === 'object') {
      for (var ek in cfgEnv) {
        if (Object.prototype.hasOwnProperty.call(cfgEnv, ek)) {
          ENV[ek] = String(cfgEnv[ek]);
        }
      }
    }

    // 2. filesystem: seed each { '/abs/path': contents } entry into the wasm FS
    //    (MEMFS) before main() runs. There is no mkdirp, so walk the path and
    //    FS.mkdir each parent segment (ignoring "already exists"). Values are
    //    file contents -- a string, or a Uint8Array for binary data.
    if (cfgFiles && typeof cfgFiles === 'object') {
      var mkdirp = function (dir) {
        var parts = dir.split('/');
        var cur = '';
        for (var p = 0; p < parts.length; p++) {
          if (parts[p] === '') { continue; }   // leading slash / doubled slashes
          cur += '/' + parts[p];
          try { FS.mkdir(cur); } catch (e) { /* already exists -- fine */ }
        }
      };
      for (var fpath in cfgFiles) {
        if (!Object.prototype.hasOwnProperty.call(cfgFiles, fpath)) { continue; }
        try {
          var slash = fpath.lastIndexOf('/');
          if (slash > 0) { mkdirp(fpath.slice(0, slash)); }
          var data = cfgFiles[fpath];
          // FS.writeFile takes a string or a typed array; pass through either.
          FS.writeFile(fpath, data);
        } catch (e) {
          dbg('nvim wasm: failed to seed file ' + fpath + ': ' + e);
        }
      }
    }

    // 3. cwd: chdir last, so a cwd that lives inside a seeded dir resolves. In
    //    the BROWSER the requested cwd may have no MEMFS node yet -- create the
    //    directory chain first. Under Node the host filesystem is NODEFS-mounted,
    //    so creating directories would touch the real disk -- chdir only. Fail
    //    soft -- on a missing dir keep the default cwd rather than crashing.
    if (cfgCwd) {
      try {
        if (!isNode) {
          try { FS.mkdirTree(cfgCwd); } catch (e) { /* may already exist */ }
        }
        FS.chdir(cfgCwd);
      } catch (e) { dbg('nvim wasm: failed to chdir to ' + cfgCwd + ': ' + e); }
    }
  });
})();
