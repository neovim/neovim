// wasm/nvim_io.js - Emscripten JS-library glue for Neovim's wasm engine.
//
// Integrates Neovim's libuv event loop with JSPI and backs the engine's
// stdin/stdout with the postMessage channel of the "separate processes +
// message passing" architecture (see wasm/README.md). There is a single role:
//
//   * ENGINE (`nvim --embed`, runs in a worker): the JS host (wasm/worker.js in
//     Node, wasm/web/engine-worker.js in the browser) sets Module.nvimChannel to
//     a message channel before boot. We back fd 0/1 with that channel: fd 0 reads
//     bytes the host received over postMessage, fd 1 writes by handing bytes to
//     the host to postMessage onward. Set up in NvimIO.setup().
//
// The clients live entirely in JS now (wasm/web/neovim.js + neovim-ui.js); no
// wasm runs on the client side, so there is no in-wasm UI client to wire here.
//
// The engine does not block: nvim's poll() suspends asynchronously via JSPI and
// is resumed when a message arrives or the libuv timeout elapses. This is what
// lets us use postMessage at all -- a thread parked in a synchronous Atomics.wait
// would never return to its event loop to receive a message.
//
// A "channel" is a plain object shared (same realm/thread) between the host JS
// and this module:
//   { inQueue: [{buf,off}],   // bytes the host received; we drain on fd read
//     closed: bool,           // peer went away; fd read then reports EOF
//     notify: fn|null,        // we install it; host calls it after push/close
//     postOutput: fn(u8) }    // host provides; we call it on fd write
//
// poll(2) bits: POLLIN 0x001  POLLOUT 0x004  POLLERR 0x008  POLLHUP 0x010  POLLNVAL 0x020
// errno: EAGAIN 6  ESPIPE 70

addToLibrary({
  // Install channel stream ops from onRuntimeInitialized, NOT preRun: the
  // standard streams (fd 0/1/2) are created by FS.init() during initRuntime,
  // which runs *after* preRun. Installing in preRun would find no fd-0 stream.
  $NvimIO__postset:
    '(function(){var _p=Module["onRuntimeInitialized"];' +
    'Module["onRuntimeInitialized"]=function(){NvimIO.setup();if(_p){_p();}};})();',
  $NvimIO__deps: ['$FS'],
  $NvimIO: {
    dbg: function (m) {
      try {
        var p = (typeof process !== 'undefined') && process.env && process.env.NVIM_WASM_IO_LOG;
        if (p) { require('fs').appendFileSync(p, m + '\n'); }
      } catch (e) { /* ignore */ }
    },
    channel: null,        // the engine's message channel (host sets Module.nvimChannel)
    wake: null,           // resolves the pending async poll; set during a wait

    // The engine channel calls this after it enqueues data / closes, to resume a
    // suspended poll().
    signalWake: function () { if (NvimIO.wake) { NvimIO.wake(); } },

    // Emscripten caches directory-entry nodes in FS.nameTable and never
    // re-validates NODEFS-backed entries against the host filesystem. When an
    // EXTERNAL process deletes (or deletes and recreates) a file the engine
    // has looked up before, the stale cached node makes subsequent operations
    // fail: an O_CREAT open takes the "node exists" path in FS.open and then
    // ENOENTs in truncate/stream-open instead of creating the file (seen as
    // shada E886 / writefile E482 in the upstream test suite, but it equally
    // breaks `:w` after `rm` from another terminal). Validate cache hits for
    // NODEFS *file* nodes with a host lstat and evict stale ones, then redo
    // the lookup so a recreated file gets a fresh node and a missing one
    // throws ENOENT from the backend. Directory nodes are left alone to keep
    // path-walk components cheap (each lookup validates only the leaf file).
    patchNodefsStaleness: function () {
      if (typeof process === 'undefined' || !process.versions || !process.versions.node) {
        return;  // browser: MEMFS only, no external mutations possible
      }
      var NODEFS = FS.filesystems && FS.filesystems.NODEFS;
      if (!NODEFS) { return; }
      var fs = require('fs');
      var origLookupNode = FS.lookupNode;
      FS.lookupNode = function (parent, name) {
        var node = origLookupNode.call(FS, parent, name);
        if (node && node.node_ops === NODEFS.node_ops &&
            !FS.isMountpoint(node) && !FS.isDir(node.mode)) {
          var gone = false;
          try {
            fs.lstatSync(NODEFS.realPath(node));
          } catch (e) {
            gone = !!(e && e.code === 'ENOENT');
          }
          if (gone) {
            FS.hashRemoveNode(node);
            return origLookupNode.call(FS, parent, name);
          }
        }
        return node;
      };
    },

    setup: function () {
      NvimIO.patchNodefsStaleness();
      var ch = Module['nvimChannel'];
      if (!ch) {
        // No engine channel: this isn't the --embed engine (e.g. a headless
        // `node nvim.js -- --headless -l script.lua` run). Leave fd 0/1 as the
        // default emscripten streams.
        return;
      }
      // ENGINE role.
      NvimIO.channel = ch;
      ch.notify = NvimIO.signalWake;
      NvimIO.applyChannelOps(FS.getStream(0), ch, 'r');
      NvimIO.applyChannelOps(FS.getStream(1), ch, 'w');
    },

    // Install message-channel stream ops on an existing FS stream. mode 'r' reads
    // ch.inQueue; mode 'w' hands bytes to ch.postOutput. We keep stream.tty set
    // (the standard fd 0/1 streams are ttys by default): isatty(fd) must stay true
    // so libuv's uv_guess_handle() returns UV_TTY (the pipe path) rather than
    // UV_FILE (which would read the fd as a file and immediately EOF).
    applyChannelOps: function (stream, ch, mode) {
      if (!stream) {
        return;
      }
      stream.seekable = false;
      var EAGAIN = 6;
      var POLLIN = 0x001, POLLOUT = 0x004;
      stream.stream_ops = {
        read: function (stream, buffer, offset, length /*, position */) {
          var q = ch.inQueue;
          if (q.length === 0) {
            if (ch.closed) { return 0; }  // genuine EOF
            throw new FS.ErrnoError(EAGAIN);
          }
          var u8 = new Uint8Array(buffer.buffer, buffer.byteOffset || 0);
          var n = 0;
          while (n < length && q.length > 0) {
            var head = q[0];
            var avail = head.buf.length - head.off;
            var take = Math.min(avail, length - n);
            u8.set(head.buf.subarray(head.off, head.off + take), offset + n);
            head.off += take;
            n += take;
            if (head.off >= head.buf.length) { q.shift(); }
          }
          return n;
        },
        write: function (stream, buffer, offset, length /*, position */) {
          // Copy out of the wasm heap before handing bytes to the host: memory
          // growth can detach the heap's ArrayBuffer, and the host transfers the
          // buffer onward (postMessage), which needs it standalone.
          var u8 = new Uint8Array(buffer.buffer, (buffer.byteOffset || 0) + offset, length);
          ch.postOutput(u8.slice());
          return length;
        },
        poll: function (/* stream, timeout */) {
          var mask = 0;
          if (mode === 'r' && (ch.inQueue.length > 0 || ch.closed)) {
            mask |= POLLIN;
          }
          if (mode === 'w') {
            mask |= POLLOUT;  // the outbound queue is unbounded; always writable
          }
          return mask;
        },
        llseek: function () { throw new FS.ErrnoError(70); },
      };
    },

    // Async (non-blocking) wait used by __syscall_poll. Resolves when the engine
    // channel becomes readable (a message arrives or it closes -- both call
    // signalWake) or the libuv timeout elapses.
    //
    // Wakeups come from real platform events (worker 'message', setTimeout), i.e.
    // macrotasks, so there is no microtask busy-spin and the wall clock the C
    // event loop relies on (os_hrtime) keeps advancing. We do NOT resolve
    // synchronously here: __syscall_poll only calls this after a compute() that
    // already found nothing ready, so there is nothing to race.
    pollWaitAsync: function (timeout) {
      return new Promise(function (resolve) {
        var done = false;
        var prevWake = NvimIO.wake;
        function finish() {
          if (done) { return; }
          done = true;
          if (timer) { clearTimeout(timer); }
          NvimIO.wake = prevWake;
          resolve();
        }
        var timer = timeout > 0 ? setTimeout(finish, timeout) : null;
        NvimIO.wake = finish;
      });
    },
  },

  // Replacement for Emscripten's __syscall_poll. Computes fd readiness without
  // crashing on streams that lack a poll op, then -- when nothing is ready --
  // suspends asynchronously via JSPI until a source wakes us or the timeout
  // elapses. Nothing blocks.
  __syscall_poll__deps: ['$FS', '$NvimIO'],
  __syscall_poll__async: true,
  __syscall_poll: function (fds, nfds, timeout) {
    var POLLIN = 0x001, POLLOUT = 0x004, POLLNVAL = 0x020;

    function compute() {
      var n = 0;
      for (var i = 0; i < nfds; i++) {
        var pollfd = fds + 8 * i;
        var fd = HEAP32[pollfd >> 2];
        var events = HEAP16[(pollfd + 4) >> 1];
        var revents;
        var stream = FS.getStream(fd);
        if (!stream) {
          revents = POLLNVAL;
        } else if (stream.stream_ops && stream.stream_ops.poll) {
          revents = stream.stream_ops.poll(stream, -1) & events;
        } else {
          revents = events & (POLLIN | POLLOUT);
        }
        HEAP16[(pollfd + 6) >> 1] = revents;
        if (revents) {
          n++;
        }
      }
      return n;
    }

    var ready = compute();
    if (ready > 0 || timeout === 0) {
      return ready;
    }
    return NvimIO.pollWaitAsync(timeout).then(compute);
  },
});
