// Transport: owns the worker + SharedArrayBuffer ring buffer
class WorkerTransport {
  constructor(workerPath, { cols = 80, rows = 24, cap = 1 << 16 } = {}) {
    this.CAP = cap;
    this.sab = new SharedArrayBuffer(12 + this.CAP); 
    this.state = new Int32Array(this.sab, 0, 3);     // [head, tail, closed]
    this.ringData = new Uint8Array(this.sab, 12, this.CAP); // offset 12

    this._bytesHandlers = [];
    this._statusHandlers = [];

    this.worker = new Worker(workerPath);
    this.worker.onmessage = (ev) => {
      console.log('[main] Worker message:', ev.data.type, ev.data);
      this._onWorkerMessage(ev.data);
    };
    this.worker.onerror = (e) => this._emitStatus('worker error: ' + e.message);
    this.worker.postMessage({ type: 'init', sab: this.sab, cols, rows });
  }
  shutdown() {
    Atomics.store(this.state, 2, 1);
    Atomics.notify(this.state, 0);
    this.worker.postMessage({ type: 'shutdown' });
    }

  _onWorkerMessage(msg) {
    console.log('[main] _onWorkermessage:', msg.type);
    if (msg.type === 'stdout') {
      console.log(`[main] stdout bytes:`, msg.bytes);
      this._bytesHandlers.forEach(h => h(msg.bytes));
    } else if (msg.type === 'stderr') {
      const text = new TextDecoder().decode(new Uint8Array(msg.bytes));
      this._emitStatus('[stderr] ' + text);
    } else if (msg.type === 'status') {
      this._emitStatus(msg.text);
    }
  }

  _emitStatus(text) {
    console.log('[main] status:', text);
    this._statusHandlers.forEach(h => h(text));
  }

  send(bytes) {
    console.log("[main] SEND: writing", bytes.length, "bytes");
    
// This ensures all data is in the buffer before Nvim wakes up
const hexStr = Array.from(bytes)
        .map(b => b.toString(16).padStart(2, '0'))
        .join(' ');
    console.log(`[main] Send: ${bytes.length} bytes: ${hexStr}`);
    
    for (let i = 0; i < bytes.length; i++) {
      const b = bytes[i];
      const head = Atomics.load(this.state, 0);
      const tail = Atomics.load(this.state, 1);
      
      const next = (head + 1) % this.CAP;
      if (next === tail) {
        console.error('[main] Send: ring buffer full');
        return false;
      }
      
      this.ringData[head] = b;
      Atomics.store(this.state, 0, next);
      // wait until all bytes are written
    }
    
    // notify once after all bytes are in the buffer
    Atomics.notify(this.state, 0);
    
    console.log("[main] SEND DONE, notified worker");
    return true;
  }

  onBytes(cb) { this._bytesHandlers.push(cb); }
  onStatus(cb) { this._statusHandlers.push(cb); }
  persist() { this.worker.postMessage({ type: 'persist' }); }
}

class RpcClient {
  constructor(transport) {
    this.transport = transport;
    this.nextMsgId = 1;
    this.pending = new Map();
    this.notificationHandlers = new Map();

    this._buffer = new Uint8Array(0);
    this._decodedMessages = [];
    
    transport.onBytes(bytes => this._handleBytes(bytes));
  }

  _handleBytes(newBytes) {
    const combined = new Uint8Array(this._buffer.length + newBytes.length);
    combined.set(this._buffer, 0);
    combined.set(newBytes, this._buffer.length);
    this._buffer = combined;

    const decoder = new MessagePack.Decoder();
    let offset = 0;

    while (offset < this._buffer.length) {
      let msg;
      try {
        // decodes exactly one value starting at `offset` tells us how much it consumed
        decoder.setBuffer(this._buffer.subarray(offset));
        msg = decoder.decode();
      } catch (e) {
        break; // incomplete trailing message — stop, wait for more bytes
      }
      offset += decoder.bytesConsumed ?? decoder.pos; // depends on library version
      this._dispatch(msg);
    }

    // only drop what was actually consumed and keep any incomplete tail
    this._buffer = this._buffer.slice(offset);
  }

  _dispatch(rawMsg) {
    console.log('[RpcClient] dispatching:', rawMsg);
    
    let msg;
    try {
      msg = Protocol.parseMessage(rawMsg);
    } catch (e) {
      console.error('[RpcClient] parse failed', rawMsg, e);
      return;
    }

    console.log('[RpcClient] parsed:', msg);

    if (msg.kind === 'response') {
      const p = this.pending.get(msg.msgid);
      if (!p) {
        console.warn('[RpcClient] unknown msgid', msg.msgid);
        return;
      }
      this.pending.delete(msg.msgid);
      clearTimeout(p.timeoutId);
      console.log('[RpcClient] resolved msgid', msg.msgid);
      if (msg.error) {
        p.reject(new Error(msg.error));
      } else {
        p.resolve(msg.result);
      }
    } else if (msg.kind === 'notification') {
      console.log('[RpcClient] notification:', msg.method);
      const handlers = this.notificationHandlers.get(msg.method) || [];
      handlers.forEach(h => h(msg.params));
    } else if (msg.kind === 'request') {
      console.warn('[RpcClient] unhandled request', msg);
    }
  }

  request(method, params = []) {
    const msgid = this.nextMsgId++;
    const bytes = Protocol.encodeRequest(msgid, method, params);
    console.log(`[RpcClient] sending request ${msgid} (${method}), ${bytes.length} bytes`);
    
    return new Promise((resolve, reject) => {
      this.pending.set(msgid, { resolve, reject, method, timestamp: Date.now() });
      
      const timeoutId = setTimeout(() => {
        if (this.pending.has(msgid)) {
          this.pending.delete(msgid);
          reject(new Error(`Request ${msgid} (${method}) timed out after 30s`));
        }
      }, 30000);
      
      this.pending.get(msgid).timeoutId = timeoutId;
      
      //  This batches all bytes before notifying
      this.transport.send(bytes);
    });
  }

  notify(method, params = []) {
    const bytes = Protocol.encodeNotification(method, params);
    console.log(`[RpcClient] sending notification ${method}, ${bytes.length} bytes`);
    this.transport.send(bytes);
  }

  on(method, handler) {
    if (!this.notificationHandlers.has(method)) {
      this.notificationHandlers.set(method, []);
    }
    this.notificationHandlers.get(method).push(handler);
  }
}
