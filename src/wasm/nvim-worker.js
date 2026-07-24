const CAP = 1 << 16; // must match the main thread's ring buffer size
let state, ringData; // state is now Int32Array(3): [head, tail, closed]

let stdinPollCount = 0;
let totalBytesRead = 0;
const consumedBytes = [];

let pendingPollCallbacks = [];
function wakePendingPolls() {
    const cbs = pendingPollCallbacks;
    pendingPollCallbacks = [];
    for (const cb of cbs) cb(65);
}
let lastCheckedTail = -1;

function checkForNewDataAndWake() {
    if (!state) return; // not initialized yet
    const head = Atomics.load(state, 0);
    const tail = Atomics.load(state, 1);
    if (head !== tail && pendingPollCallbacks.length > 0) {
        wakePendingPolls();
    }
}

setInterval(checkForNewDataAndWake, 20); // check every 20ms

function popNonBlocking() {
    const head = Atomics.load(state, 0);
    const tail = Atomics.load(state, 1);
    if (head !== tail) {
        const b = ringData[tail];
        Atomics.store(state, 1, (tail + 1) % CAP);
        totalBytesRead++;
        consumedBytes.push(b);
        return b;
    }
    return -1;
}

// blocks the Worker thread until a byte is available or shutdown fires.
function popBlocking() {
    while (true) { //producer-consumer
        const head = Atomics.load(state, 0);
        const tail = Atomics.load(state, 1);

        if (head !== tail) {
            const b = ringData[tail];
            Atomics.store(state, 1, (tail + 1) % CAP);
            totalBytesRead++;
            consumedBytes.push(b);
            return b;
        }

        if (Atomics.load(state, 2) === 1) {
            return -1; 
        }

        // Blocks here until Atomics.notify(state, 0) fires, or 1s elapses
        Atomics.wait(state, 0, head, 1000);
    }
}

let stdoutBuf = [];
let stderrBuf = [];

function flushStdout() {
  if (stdoutBuf.length) {
    postMessage({ type: 'stdout', bytes: stdoutBuf });
    stdoutBuf = [];
  }
}

function flushStderr() {
  if (stderrBuf.length) {
    postMessage({ type: 'stderr', bytes: stderrBuf });
    stderrBuf = [];
  }
}

function flushAll() {
  flushStdout();
  flushStderr();
}

function writeStdout(c) {
  stdoutBuf.push(c);
  flushStdout();
}

function writeStderr(c) {
  stderrBuf.push(c);
  if (stderrBuf.length > 80) {
    flushStderr();
  }
}

function makeArgv(M, args) {
  const ptrs = args.map(s => {
    const len = M.lengthBytesUTF8(s) + 1, p = M._malloc(len);
    M.stringToUTF8(s, p, len);
    return p;
  });
  const argv = M._malloc((ptrs.length + 1) * 4);
  ptrs.forEach((p, i) => M.setValue(argv + i * 4, p, '*'));
  M.setValue(argv + ptrs.length * 4, 0, '*');
  return { argc: ptrs.length, argv };
}

let moduleRef = null;

self.onerror = (e) => {
  postMessage({ type: 'status', text: 'WORKER ERROR: ' + e.message });
};

self.onunhandledrejection = (e) => {
  postMessage({ type: 'status', text: 'WORKER REJECTION: ' + e });
};

function makeBridgeReadOps(origOps, label) {
  const newOps = Object.assign({}, origOps);
  newOps.read = function (stream, buffer, offset, length, position) {
      let n = 0;
      while (n < length) {
          const b = popNonBlocking();
          if (b === -1) break;
          buffer[offset + n] = b;
          n++;
      }
      if (n === 0) {
          console.log(`[stream_ops:${label}] no data available, returning 0 (temporary — not correct long-term)`);
          return 0; // TEMP: fake EOF
      }
      console.log(`[stream_ops:${label}] read ${n} bytes`);
      return n;
  };
newOps.poll = function (stream, timeout, notifyCallback) {
    const head = Atomics.load(state, 0);
    const tail = Atomics.load(state, 1);

    if (head !== tail) {
        return 65;
    }

    if (notifyCallback) {
        pendingPollCallbacks.push(notifyCallback);
    }

    return 0;
};
  const origGetattr = origOps.getattr;
  newOps.getattr = function (stream) {
    const attr = origGetattr ? origGetattr.call(this, stream) : { mode: 0 };
    attr.mode = (attr.mode & ~0xF000) | 0x1000;
    return attr;
  };
  return newOps;
}

self.onmessage = async (ev) => {
  const msg = ev.data;

  if (msg.type === 'init') {
    state = new Int32Array(msg.sab, 0, 3);   // [head, tail, closed]
    ringData = new Uint8Array(msg.sab, 12, CAP); // offset moved from 8 → 12
setInterval(checkForNewDataAndWake, 20); 
    postMessage({ type: 'status', text: 'loading wasm...' });
    importScripts('../../zig-out/bin/nvim.js');

    const m = await createNvim({
      locateFile: (p) => p.endsWith('.data') ? '../../zig-out/bin/nvim.data' : '../../zig-out/bin/' + p,
      noInitialRun: true,
      stdin: () => {
      console.log('[stdin callback] fired');
      const b = popNonBlocking();
      return b === -1 ? null : b;
      },
      stdout: c => writeStdout(c),
      stderr: c => writeStderr(c),
      print: t => postMessage({ type: 'status', text: '[print] ' + t }),
      printErr: t => postMessage({ type: 'status', text: '[printErr] ' + t }),
      preRun: [m => {
        m.ENV.TERM = "xterm-256color";
        m.ENV.HOME = "/home/user";
        m.ENV.VIMRUNTIME = "/runtime";
        m.ENV.COLUMNS = String(msg.cols);
        m.ENV.LINES = String(msg.rows);
        try { m.FS.mkdir('/tmp'); } catch (e) {}
        m.FS.mkdir('/home/user');
        m.FS.mkdir('/home/user/.config');
        m.FS.mkdir('/home/user/.local');
        m.FS.mkdir('/home/user/.local/share');
        m.FS.mount(m.IDBFS, {}, '/home/user/.config');
        m.FS.mount(m.IDBFS, {}, '/home/user/.local/share');
      }],
    });

    await new Promise((res, rej) => m.FS.syncfs(true, e => e ? rej(e) : res()));
    try { m.FS.mkdir('/home/user/.config/nvim'); } catch (e) {}
    try { m.FS.mkdir('/home/user/.local/share/nvim'); } catch (e) {}
    try { m.FS.mkdir('/runtime/parser'); } catch (e) {}
    ['lua', 'c', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline'].forEach(p => {
      try { m.FS.writeFile(`/runtime/parser/${p}.so`, ''); } catch (e) {}
    });

    moduleRef = m;

    function sanitizeAttr(attr) {
      attr.dev = attr.dev ?? 1;
      attr.ino = attr.ino ?? 1;
      attr.mode = attr.mode ?? 0o666;
      attr.nlink = attr.nlink ?? 1;
      attr.uid = attr.uid ?? 0;
      attr.gid = attr.gid ?? 0;
      attr.rdev = attr.rdev ?? 0;
      attr.size = (typeof attr.size === 'number' && !isNaN(attr.size)) ? attr.size : 0;
      attr.blksize = attr.blksize ?? 4096;
      attr.blocks = attr.blocks ?? 0;
      const validDate = d => d instanceof Date && !isNaN(d.getTime());
      attr.atime = validDate(attr.atime) ? attr.atime : new Date(0);
      attr.mtime = validDate(attr.mtime) ? attr.mtime : new Date(0);
      attr.ctime = validDate(attr.ctime) ? attr.ctime : new Date(0);
      return attr;
    }

    function isStdinLike(path) {
      const p = path || '';
      return p.startsWith('pipe[') || p.includes('my_stdin') || p === '/dev/stdin';
    }

    ['fstat', 'stat', 'lstat'].forEach(name => {
      if (typeof m.FS[name] !== 'function') return;
      const orig = m.FS[name].bind(m.FS);
      m.FS[name] = function (...args) {
        const attr = orig(...args);
        const path = (name === 'fstat')
          ? (m.FS.streams[args[0]] && m.FS.streams[args[0]].path)
          : args[0];
        if (isStdinLike(path)) {
          attr.mode = 0o010666;
        }
        return sanitizeAttr(attr);
      };
    });

    const origCreateStream = m.FS.createStream;
    m.FS.createStream = function (stream, fd) {
      const s = origCreateStream.call(this, stream, fd);
      const p = s.path || '';
      const looksLikeStdin = p.startsWith('pipe[') || p.includes('my_stdin') || p === '/dev/stdin';
      if (looksLikeStdin && !s._patched) {
        s.stream_ops = makeBridgeReadOps(s.stream_ops, 'createStream:' + p);
        s._patched = true;
      }
      return s;
    };

    const origFSRead = m.FS.read;
    m.FS.read = function (stream, buffer, offset, length, position) {
      if (stream.path && stream.path.startsWith('pipe[') && !stream._patched) {
        stream.stream_ops = makeBridgeReadOps(stream.stream_ops, 'fallback:' + stream.path);
        stream._patched = true;
      }
      return origFSRead.call(this, stream, buffer, offset, length, position);
    };

    const origFSWrite = m.FS.write;
    m.FS.write = function (stream, buffer, offset, length, position, canOwn) {
      return origFSWrite.call(this, stream, buffer, offset, length, position, canOwn);
    };

    const { argc, argv } = makeArgv(m, ["nvim", "--embed"]);
    let ret;
    try {
      postMessage({ type: 'status', text: 'Starting Neovim...' });
      ret = await m._nvim_main(argc, argv);
      const headAtExit = Atomics.load(state, 0);
      const tailAtExit = Atomics.load(state, 1);
      const unread = (headAtExit - tailAtExit + CAP) % CAP;
      postMessage({ type: 'status', text: `_nvim_main RETURNED ret=${ret}, unread bytes still in buffer=${unread} (head=${headAtExit}, tail=${tailAtExit})` });

    } catch (e) {
      flushAll();
      postMessage({ type: 'status', text: 'EXCEPTION: ' + e.message });
      throw e;
    }

    flushAll();

    const hexStr = consumedBytes.slice(0, 50).map(x => x.toString(16).padStart(2, '0')).join(' ');
    const remaining = consumedBytes.length > 50 ? `... (${consumedBytes.length - 50} more bytes)` : '';
    postMessage({ type: 'status', text: `EXIT CODE ${ret}. Read ${totalBytesRead} bytes: ${hexStr}${remaining}` });
  }
  if (msg.type === 'persist') {
    if (!moduleRef) { postMessage({ type: 'persisted', error: 'module not ready' }); return; }
    moduleRef.FS.syncfs(false, e => postMessage({ type: 'persisted', error: e ? String(e) : null }));
  }
    if (msg.type === 'shutdown') {
    if (state) {
        Atomics.store(state, 2, 1);
        Atomics.notify(state, 0); // wake up any pending popBlocking()
    }
  }
};
