const CAP = 1 << 16;

let state = null;
let ringData = null;

let moduleRef = null;

let totalBytesRead = 0;
const consumedBytes = [];
const STATUS_MSG_CAP = 2000;
let statusMsgCount = 0;
let statusCapNoticeSent = false;

function safeStatus(text) {
  statusMsgCount++;
  if (statusMsgCount > STATUS_MSG_CAP) {
    if (!statusCapNoticeSent) {
      statusCapNoticeSent = true;
      postMessage({
        type: "status",
        text:
          "STATUS LOGGING SUPPRESSED after " +
          STATUS_MSG_CAP +
          " messages -- likely a busy/runaway loop. " +
          "See perFdWriteCount below for which fd is spinning.",
      });
    }
    return;
  }
  postMessage({ type: "status", text: text });
}

const perFdWriteCount = {};
function bumpFdWriteCount(fd) {
  perFdWriteCount[fd] = (perFdWriteCount[fd] || 0) + 1;
}

/* File descriptor monitored by libuv for stdin. Verify this value
   against the startup FD dump, as it may differ across environments. */

const STDIN_FD = 9;

/*
 SharedArrayBuffer layout:
 offset 0:
 Int32Array:
 [0] head
 [1] tail
 [2] closed

 offset 12:
 Uint8Array data
*/

function unreadCount() {
  const head = Atomics.load(state, 0);
  const tail = Atomics.load(state, 1);
  return (head - tail + CAP) % CAP;
}

// Synchronizes the JS ring buffer with the shared atomics used by
// uv__io_poll to allow libuv to detect newly available input.
function markReadable() {
  safeStatus(
    "MARK READABLE called moduleRef=" + !!moduleRef + " STDIN_FD=" + STDIN_FD,
  );
  if (!moduleRef) return;
  const n = unreadCount();
  safeStatus("MARK READABLE n=" + n);
  try {
    moduleRef.ccall(
      "uv_browser_set_readable",
      null,
      ["number", "number"],
      [STDIN_FD, n],
    );
    safeStatus("MARK READABLE ccall succeeded");
  } catch (e) {
    safeStatus("MARK READABLE FAILED: " + e);
  }
}

// Debug helper
function dumpFD(fd) {
  const s = moduleRef.FS.streams[fd];

  safeStatus(" FD " + fd);

  if (!s) {
    safeStatus("NO STREAM");
    return;
  }

  safeStatus("path=" + s.path + " fd=" + s.fd + " tty=" + !!s.tty);

  safeStatus(
    "same stdout ops=" + (s.stream_ops === moduleRef.FS.streams[1].stream_ops),
  );

  try {
    const st = moduleRef.FS.fstat(fd);

    safeStatus(
      "mode=" +
        st.mode.toString(8) +
        " isChrdev=" +
        moduleRef.FS.isChrdev(st.mode),
    );
  } catch (e) {
    safeStatus("fstat failed: " + e);
  }
}

function popByte() {
  const head = Atomics.load(state, 0);
  const tail = Atomics.load(state, 1);

  if (head === tail) return -1;

  const b = ringData[tail];

  Atomics.store(state, 1, (tail + 1) % CAP);

  totalBytesRead++;
  consumedBytes.push(b);

  console.log("POP BYTE", b.toString(16));

  return b;
}

// Called when new bytes are pushed into the ring buffer from the main
//  thread. Advances head and notifies both the JS side Atomics.wait() consumers and the C-side
//  futex consumers (uv__io_poll).
function pushBytes(bytes) {
  if (!bytes || !bytes.length) return;

  let head = Atomics.load(state, 0);

  for (let i = 0; i < bytes.length; i++) {
    const tail = Atomics.load(state, 1);
    const nextHead = (head + 1) % CAP;

    /* If the ring buffer is full, drop new data instead of overwriting
   unread bytes. Overwriting would corrupt the input stream. If this
   happens often, increase CAP or add backpressure on the producer. */
    if (nextHead === tail) {
      console.warn("stdin ring buffer full, dropping byte");
      break;
    }

    ringData[head] = bytes[i];
    head = nextHead;
  }

  Atomics.store(state, 0, head);

  // wake anything doing an Atomics.wait() on head, if anything still does
  Atomics.notify(state, 0);

  // tell the C side (uv__io_poll) that fd 9 now has data
  markReadable();
}

function flushAll() {
  if (stdoutBuffer.length) {
    postMessage({
      type: "stdout",
      bytes: stdoutBuffer,
    });
    stdoutBuffer = [];
  }

  if (stderrBuffer.length) {
    postMessage({
      type: "stderr",
      bytes: stderrBuffer,
    });
    stderrBuffer = [];
  }
}

let stdoutBuffer = [];
let stderrBuffer = [];

function writeStderr(c) {
  stderrBuffer.push(c);

  if (stderrBuffer.length > 50) {
    postMessage({
      type: "stderr",
      bytes: stderrBuffer,
    });

    stderrBuffer = [];
  }
}

function makeArgv(M, args) {
  const ptrs = args.map((s) => {
    const len = M.lengthBytesUTF8(s) + 1;

    const p = M._malloc(len);

    M.stringToUTF8(s, p, len);

    return p;
  });

  const argv = M._malloc((ptrs.length + 1) * 4);

  ptrs.forEach((p, i) => M.setValue(argv + i * 4, p, "*"));

  M.setValue(argv + ptrs.length * 4, 0, "*");

  return {
    argc: ptrs.length,
    argv,
  };
}

self.onerror = (e) => {
  safeStatus("WORKER ERROR " + e.message);
};

self.onunhandledrejection = (e) => {
  const r = e.reason;
  const info =
    r && typeof r === "object"
      ? `name=${r.name} message=${r.message} status=${r.status}`
      : String(r);
  safeStatus("REJECTION " + info);
};

/* Hook the shared TTY get_char callback instead of stream_ops.read.
   All duplicated file descriptors share the same TTY object, making
   this work for stdin and any dup()ed descriptors.
   Return one byte when available, undefined when no data is ready
   (causing Emscripten to report EAGAIN), or null on EOF. Blocking is
   handled by uv__io_poll so this callback always remains non-blocking.
 */
function installStdoutWrite(m, stdoutStream) {
  if (
    !stdoutStream.stream_ops ||
    typeof stdoutStream.stream_ops.write !== "function"
  ) {
    throw new Error(
      "stdout stream has no stream_ops.write: " + stdoutStream.path,
    );
  }
  // The worker owns the transport, so forwarding the chunk via postMessage
  // completes the write.
  // Skip the original stream_ops.write to avoid duplicate output.
  stdoutStream.stream_ops.write = function (
    stream,
    buffer,
    offset,
    length,
    position,
  ) {
    safeStatus(
      "WRITE HOOK fd=" + stream.fd + " path=" + stream.path + " len=" + length,
    );

    try {
      console.log("HOOK: entered");
      /* Forward the entire chunk as a single message to preserve msgpack-RPC
   framing. Then copy it into a Uint8Array to ensure the transmitted bytes
   remain correct regardless of the source buffer's signedness. */
      const chunk = new Uint8Array(length);
      for (let i = 0; i < length; i++) {
        chunk[i] = buffer[offset + i];
      }
      console.log(
        "HOOK: chunk built",
        chunk.length,
        chunk[0],
        chunk[1],
        chunk[2],
        chunk[3],
      );
      console.log(
        "stdout chunk",
        length,
        chunk[0],
        chunk[1],
        chunk[2],
        chunk[3],
      );
      console.log("HOOK: BEFORE postMessage");

      postMessage({
        type: "stdout",
        bytes: chunk,
      });
      console.log("HOOK: AFTER postMessage");
    } catch (e) {
      console.error("HOOK: postMessage failed", e);

      safeStatus("STDOUT HOOK ERROR: " + e + " stack=" + e.stack);
    }
    return length;
  };
}

function installStdinGetChar(m, stdinStream) {
  if (!stdinStream.tty || !stdinStream.tty.ops) {
    throw new Error(
      "stdin stream has no .tty.ops -- stream is not TTY-backed: " +
        stdinStream.path,
    );
  }

  stdinStream.tty.ops.get_char = function (tty) {
    const b = popByte();

    if (b !== -1) {
      markReadable(); // reflect the new unread count
      return b;
    }

    if (Atomics.load(state, 2) === 1) {
      console.log("stdin closed");
      return null; // real EOF
    }

    return undefined; // no data yet -> Emscripten turns this into EAGAIN
  };
}

self.onmessage = async (ev) => {
  const msg = ev.data;

  if (msg.type === "init") {
    state = new Int32Array(msg.sab, 0, 3); // [head, tail, closed]
    ringData = new Uint8Array(msg.sab, 12, CAP); // offset moved from 8 → 12
    safeStatus("loading wasm...");
    importScripts("../../zig-out/bin/nvim.js");

    const m = await createNvim({
      locateFile: (p) =>
        p.endsWith(".data")
          ? "../../zig-out/bin/nvim.data"
          : "../../zig-out/bin/" + p,
      noInitialRun: true,
      interactive: false,

      stdout: () => {},

      stderr: (c) => writeStderr(c),
      tty: false,
      print: (t) => safeStatus("[print] " + t),
      printErr: (t) => safeStatus("[printErr] " + t),
      preRun: [
        (m) => {
          m.ENV.TERM = "xterm-256color";
          m.ENV.HOME = "/home/user";
          m.ENV.VIMRUNTIME = "/runtime";
        },
      ],
    });

    moduleRef = m;

    const statePtr = m.ccall(
      "uv_browser_get_shared_state_ptr",
      "number",
      [],
      [],
    );
    postMessage({
      type: "shared-info",
      memory: m.HEAPU8.buffer,
      statePtr: statePtr,
    });
    postMessage({ type: "ready" });
    const stdinStream = m.FS.streams[0];

    console.log("stdin stream", stdinStream.path);

    installStdinGetChar(m, stdinStream);
    const stdoutStream = m.FS.streams[1];

    console.log("stdoutStream ", stdoutStream);
    console.log(stdoutStream.node);
    console.log(stdoutStream.node.rdev);
    console.log(stdoutStream.tty);
    console.log(stdoutStream.stream_ops);

    console.log("stdout stream", stdoutStream.path);
    installStdoutWrite(m, stdoutStream);
    console.log("PATCHED STDOUT WRITE =", m.FS.streams[1].stream_ops.write);
    await new Promise((res, rej) =>
      m.FS.syncfs(true, (e) => (e ? rej(e) : res())),
    );
    try {
      m.FS.mkdir("/home/user/.config/nvim");
    } catch (e) {}
    try {
      m.FS.mkdir("/home/user/.local/share/nvim");
    } catch (e) {}
    try {
      m.FS.mkdir("/runtime/parser");
    } catch (e) {}
    [
      "lua",
      "c",
      "vim",
      "vimdoc",
      "query",
      "markdown",
      "markdown_inline",
    ].forEach((p) => {
      try {
        m.FS.writeFile(`/runtime/parser/${p}.so`, "");
      } catch (e) {}
    });

    const patchedOps = stdinStream.tty && stdinStream.tty.ops;
    // Dump every open fd and confirm which fd libuv is actually polling
    // on and whether it shares the patched tty record. If STDIN_FD
    // above doesn't match what shows up here as the dup'd stdin fd then
    // fix the constant at the top of this file.
    for (let i = 0; i < 16; i++) {
      const s = m.FS.streams[i];
      console.log("FD", i, s && s.path, s && s.tty && s.tty.ops === patchedOps);
    }

    function sanitizeAttr(attr) {
      attr.dev = attr.dev ?? 1;
      attr.ino = attr.ino ?? 1;
      attr.mode = attr.mode ?? 0o666;
      attr.nlink = attr.nlink ?? 1;
      attr.uid = attr.uid ?? 0;
      attr.gid = attr.gid ?? 0;
      attr.rdev = attr.rdev ?? 0;
      attr.size =
        typeof attr.size === "number" && !isNaN(attr.size) ? attr.size : 0;
      attr.blksize = attr.blksize ?? 4096;
      attr.blocks = attr.blocks ?? 0;
      const validDate = (d) => d instanceof Date && !isNaN(d.getTime());
      attr.atime = validDate(attr.atime) ? attr.atime : new Date(0);
      attr.mtime = validDate(attr.mtime) ? attr.mtime : new Date(0);
      attr.ctime = validDate(attr.ctime) ? attr.ctime : new Date(0);
      return attr;
    }

    function isStdinLike(path) {
      const p = path || "";
      return (
        p.startsWith("pipe[") || p.includes("my_stdin") || p === "/dev/stdin"
      );
    }

    ["fstat", "stat", "lstat"].forEach((name) => {
      if (typeof m.FS[name] !== "function") return;
      const orig = m.FS[name].bind(m.FS);
      m.FS[name] = function (...args) {
        const attr = orig(...args);
        const path =
          name === "fstat"
            ? m.FS.streams[args[0]] && m.FS.streams[args[0]].path
            : args[0];
        if (isStdinLike(path)) {
          attr.mode = 0o010666;
        }
        return sanitizeAttr(attr);
      };
    });

    const origFSWrite = m.FS.write;
    m.FS.write = function (stream, buffer, offset, length, position, canOwn) {
      console.log("FS.write-----");
      console.log("fd =", stream.fd);
      console.log("path =", stream.path);

      console.log("stream_ops =", stream.stream_ops);

      console.log("write fn =", stream.stream_ops && stream.stream_ops.write);

      console.log("stdout write fn =", m.FS.streams[1].stream_ops.write);

      console.log(
        "same write?",
        stream.stream_ops &&
          stream.stream_ops.write === m.FS.streams[1].stream_ops.write,
      );
      bumpFdWriteCount(stream.fd);
      safeStatus(
        "FS.write fd=" +
          stream.fd +
          " path=" +
          stream.path +
          " len=" +
          length +
          " (fd" +
          stream.fd +
          " call#" +
          perFdWriteCount[stream.fd] +
          ")",
      );
      return origFSWrite.call(
        this,
        stream,
        buffer,
        offset,
        length,
        position,
        canOwn,
      );
    };

    const { argc, argv } = makeArgv(m, ["nvim", "--embed", "--cmd", "set noautoread"]);

    let ret;

    try {
      safeStatus("Starting Neovim...");

      console.log("CALLING NVIM MAIN");

      const nvimPromise = m._nvim_main(argc, argv);

      console.log("returned:", nvimPromise);
      console.log("instanceof Promise:", nvimPromise instanceof Promise);
      console.log("constructor:", nvimPromise?.constructor?.name);

      setTimeout(() => {
        dumpFD(1);
        dumpFD(9);
        dumpFD(10);
      }, 1000);

      ret = await nvimPromise;

      console.log("NVIM EXITED");
      postMessage({ type: "exited", code: ret });
      try {
        moduleRef.ccall("emscripten_force_exit", null, ["number"], [ret]);
      } catch (e) {
        safeStatus("force_exit failed: " + e);
      }
      const unread = unreadCount();
      safeStatus(
        `_nvim_main RETURNED ret=${ret}, unread bytes still in buffer=${unread}`,
      );
    } catch (e) {
          console.log('CAUGHT EXIT EXCEPTION', e, 'name=', e && e.name, 'status=', e && e.status, 'constructor=', e && e.constructor && e.constructor.name);

      flushAll();
    if (e && e.name === 'ExitStatus') {
        safeStatus(`Neovim exited cleanly, code=${e.status}`);
        ret = e.status;
    
    // Notify app.js so it can show a session ended state instead of
    // leaving the UI looking frozen.
    postMessage({ type: "exited", code: ret });
    try {
          moduleRef.ccall("emscripten_force_exit", null, ["number"], [ret]);
        } catch (fe) {
          safeStatus("force_exit failed: " + fe);
        }
      }
    else 
      {
        safeStatus('EXCEPTION: ' + e.message + '\nSTACK:\n' + e.stack);
        throw e;
    }
    }

    flushAll();

    const hexStr = consumedBytes
      .slice(0, 50)
      .map((x) => x.toString(16).padStart(2, "0"))
      .join(" ");
    const remaining =
      consumedBytes.length > 50
        ? `... (${consumedBytes.length - 50} more bytes)`
        : "";
    safeStatus(
      `EXIT CODE ${ret}. Read ${totalBytesRead} bytes: ${hexStr}${remaining}`,
    );
  }

  if (msg.type === "stdin") {
    pushBytes(msg.bytes);
  }

  if (msg.type === "persist") {
    if (!moduleRef) {
      postMessage({ type: "persisted", error: "module not ready" });
      return;
    }
    moduleRef.FS.syncfs(false, (e) =>
      postMessage({ type: "persisted", error: e ? String(e) : null }),
    );
  }
  if (msg.type === "readable-hint") {
    markReadable();
  }

  if (msg.type === "dump-counters") {
    safeStatus(
      "perFdWriteCount=" +
        JSON.stringify(perFdWriteCount) +
        " statusMsgCount=" +
        statusMsgCount +
        " suppressed=" +
        statusCapNoticeSent,
    );
  }
  if (msg.type === "shutdown") {
    if (state) {
      Atomics.store(state, 2, 1);
      Atomics.notify(state, 0); // wake up anything Atomics.wait()ing
      markReadable(); // also wake the C side futex so uv__io_poll rescans and sees the close
    }
  }
};
