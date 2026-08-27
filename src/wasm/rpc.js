// TODO: Add a fallback when SharedArrayBuffer is unavailable.
// Transport: owns the worker and SharedArrayBuffer
class WorkerTransport {
  constructor(workerPath, { cols = 80, rows = 24, cap = 1 << 16 } = {}) {
    this.CAP = cap;
    this.sab = new SharedArrayBuffer(12 + this.CAP);
    this.state = new Int32Array(this.sab, 0, 3); // [head, tail, closed]
    this.ringData = new Uint8Array(this.sab, 12, this.CAP); // offset 12

    this._bytesHandlers = [];
    this._statusHandlers = [];
    this._readyHandlers = [];
    this._exitHandlers = [];

    this.worker = new Worker(workerPath);
    this.worker.onmessage = (ev) => {
      console.log("[main] worker message", ev.data.type, ev.data);
      this._onWorkerMessage(ev.data);
    };
    this.worker.onerror = (e) => this._emitStatus("worker error: " + e.message);
    this.worker.postMessage({ type: "init", sab: this.sab, cols, rows });
  }

  shutdown() {
    Atomics.store(this.state, 2, 1);
    Atomics.notify(this.state, 0);
    this.worker.postMessage({ type: "shutdown" });
  }

  _onWorkerMessage(msg) {
    console.log("[main] _onWorkerMessage got", msg.type);

    if (msg.type === "stdout") {
      console.log(`[main] stdout bytes:`, msg.bytes);
      this._bytesHandlers.forEach((h) => h(msg.bytes));
    } else if (msg.type === "stderr") {
      const text = new TextDecoder().decode(new Uint8Array(msg.bytes));
      this._emitStatus("[stderr] " + text);
    } else if (msg.type === "status") {
      this._emitStatus(msg.text);
    } else if (msg.type === "shared-info") {
      this.sharedState = new Int32Array(
        msg.memory,
        msg.statePtr,
        1 + 256 + 256,
      );
      console.log("[main] shared-info received, direct futex wake enabled");
    } else if (msg.type === "ready") {
      console.log("[main] worker signaled ready, RPC channel should be live");
      this._readyHandlers.forEach((h) => h());
    }
    else if (msg.type === "exited") {
      console.log("worker signaled nvim exited, code=", msg.code);
      this._exitHandlers.forEach((h) => h(msg.code));
    }
  }

  _emitStatus(text) {
    console.log("[main] status:", text);
    this._statusHandlers.forEach((h) => h(text));
  }

  send(bytes) {
    console.log("[main] Send: writing", bytes.length, "bytes");
    const hexStr = Array.from(bytes)
      .map((b) => b.toString(16).padStart(2, "0"))
      .join(" ");
    console.log(`[main] Send: ${bytes.length} bytes: ${hexStr}`);

    let lastHead = 0;
    for (let i = 0; i < bytes.length; i++) {
      const b = bytes[i];
      const head = Atomics.load(this.state, 0);
      const tail = Atomics.load(this.state, 1);
      const next = (head + 1) % this.CAP;
      if (next === tail) {
        console.error("[main] Send: ring buffer full");
        return false;
      }
      this.ringData[head] = b;
      Atomics.store(this.state, 0, next);
      lastHead = next;
    }

    if (this.sharedState) {
      // Write straight into the C-side shared struct, then wake the futex.
      // This only works if the worker is already inside
      // emscripten_futex_wait() at the moment call notify() if it is
      // not waiting yet, the notify does nothing. Atomics.notify() does not
      // queue up a wake for some future wait() call as it only wakes threads
      // that are waiting right now.
      const STDIN_FD = 9;
      const tail = Atomics.load(this.state, 1);
      const n = (lastHead - tail + this.CAP) % this.CAP;
      Atomics.store(this.sharedState, 1 + STDIN_FD, n); // readable[STDIN_FD] = n
      Atomics.add(this.sharedState, 0, 1); // generation++
      Atomics.notify(this.sharedState, 0, 1); // wake the futex_wait, if any
      console.log("[main] Send Done, direct notified futex, n=", n);
    }
    // There's a real startup race here: if this send() happens before the
    // worker's event loop has reached its first Atomics.wait() (e.g.
    // auto-attach fires the instant ready arrives), the direct notify
    // above lands on nobody and is silently wasted. And if the C side poll
    // loop only reacts to notify events instead of rechecking the shared
    // value on every scan that missed wake is gone for good and the
    // request just sits in the ring buffer forever.
    //
    // But until the worker actually starts blocking, it is still free to
    // process its own message queue so this postMessage gets handled
    // right away, routing through the worker's own markReadable() ->
    // uv_browser_set_readable ccall path. That makes send() correct
    // whether or not nvim has reached its poll loop yet instead of
    // depending on lucky notify timing.
    this.worker.postMessage({ type: "readable-hint" });
    console.log(
      "[main] SEND DONE, also sent readable-hint as belt-and-suspenders",
    );

    return true;
  }

  onBytes(cb) {
    this._bytesHandlers.push(cb);
  }
  onStatus(cb) {
    this._statusHandlers.push(cb);
  }
  onReady(cb) {
    this._readyHandlers.push(cb);
  }
  onExit(cb) {
    this._exitHandlers.push(cb);
  }
  persist() {
    this.worker.postMessage({ type: "persist" });
  }
}

class RpcClient {
  constructor(transport) {
    this.transport = transport;
    this.nextMsgId = 1;
    this.pending = new Map();
    this.notificationHandlers = new Map();

    this._buffer = new Uint8Array(0);

    transport.onBytes((bytes) => this._handleBytes(bytes));
  }

  _handleBytes(newBytes) {
    console.log(
      "[RpcClient] _handleBytes",
      newBytes.length,
      newBytes.slice(0, 32),
    );

    const combined = new Uint8Array(this._buffer.length + newBytes.length);
    combined.set(this._buffer, 0);
    combined.set(newBytes, this._buffer.length);
    this._buffer = combined;

    const { messages, consumed } = MsgpackCodec.decodeMultiple(this._buffer);

    for (const msg of messages) {
      console.log("[RpcClient] raw decoded:", JSON.stringify(msg));
      this._dispatch(msg);
    }

    this._buffer = this._buffer.slice(consumed);
  }

  _dispatch(rawMsg) {
    console.log("[RpcClient] dispatching:", rawMsg);

    let msg;
    try {
      msg = Protocol.parseMessage(rawMsg);
    } catch (e) {
      console.error("[RpcClient] parse failed", rawMsg, e);
      return;
    }

    console.log("[RpcClient] parsed:", msg);

    if (msg.kind === "response") {
      const p = this.pending.get(msg.msgid);
      if (!p) {
        console.warn("[RpcClient] unknown msgid", msg.msgid, "pending:", [
          ...this.pending.keys(),
        ]);
        return;
      }
      this.pending.delete(msg.msgid);
      clearTimeout(p.timeoutId);
      console.log("[RpcClient] resolved msgid", msg.msgid);
      if (msg.error) {
        p.reject(new Error(msg.error));
      } else {
        p.resolve(msg.result);
      }
    } else if (msg.kind === "notification") {
      console.log("[RpcClient] notification:", msg.method);
      const handlers = this.notificationHandlers.get(msg.method) || [];
      handlers.forEach((h) => h(msg.params));
    } else if (msg.kind === "request") {
      console.warn("[RpcClient] unhandled request", msg);
    }
  }

  request(method, params = []) {
    const msgid = this.nextMsgId++;
    const bytes = Protocol.encodeRequest(msgid, method, params);
    console.log(
      `[RpcClient] sending request ${msgid} (${method}), ${bytes.length} bytes`,
    );

    return new Promise((resolve, reject) => {
      this.pending.set(msgid, {
        resolve,
        reject,
        method,
        timestamp: Date.now(),
      });

      const timeoutId = setTimeout(() => {
        if (this.pending.has(msgid)) {
          this.pending.delete(msgid);
          reject(new Error(`Request ${msgid} (${method}) timed out after 30s`));
        }
      }, 30000);

      this.pending.get(msgid).timeoutId = timeoutId;

      this.transport.send(bytes);
    });
  }

  notify(method, params = []) {
    const bytes = Protocol.encodeNotification(method, params);
    console.log(
      `[RpcClient] sending notification ${method}, ${bytes.length} bytes`,
    );
    this.transport.send(bytes);
  }

  on(method, handler) {
    if (!this.notificationHandlers.has(method)) {
      this.notificationHandlers.set(method, []);
    }
    this.notificationHandlers.get(method).push(handler);
  }
}
