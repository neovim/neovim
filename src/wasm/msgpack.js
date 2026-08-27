if (typeof msgpackr === 'undefined') {
  throw new Error(
    'msgpackr library not loaded. ' +
    'Check that the script tag for msgpackr is present and loads correctly.'
  );
}

// Buffer/Window/Tabpage handles come back as msgpack EXT values.
// - Type code: not fixed across builds, so read it from
//   nvim_get_api_info()'s types metadata at runtime instead of
//   hardcoding it.
// - Payload: itself a variable length msgpack integer,
//   so it needs a real unpack call, not a fixed width DataView read.
function registerNvimHandleTypes(types) {
  for (const [name, info] of Object.entries(types)) {
    msgpackr.addExtension({
      type: info.id,
      unpack(payload) {
        return { __nvimType: name, id: msgpackr.unpack(payload) };
      },
      pack(value) {
        return msgpackr.pack(value.id);
      },
    });
    console.log(`[msgpack] registered Nvim EXT type ${info.id} -> ${name}`);
  }
}

const MsgpackCodec = {
  encode(value) {
    const encoded = msgpackr.pack(value);
    const prefix = Array.from(encoded.slice(0, Math.min(encoded.length, 8)))
      .map(b => b.toString(16).padStart(2, '0'))
      .join(' ');
    console.log(`[MsgpackCodec.encode] ${encoded.length} bytes, prefix: ${prefix}`);
    return encoded;
  },

  decodeMultiple(bytes) {
    const messages = [];
    let consumed = 0;

    try {
      msgpackr.unpackMultiple(bytes, (value, start, end) => {
        messages.push(value);
        consumed = end;
      });
      consumed = bytes.length;
    } catch (e) {
      if (!isIncompleteDataError(e)) {
        console.error('[MsgpackCodec.decodeMultiple] fatal decode error', e, 'consumed so far:', consumed);
        throw e;
      }
    }

    return { messages, consumed };
  },
};

function isIncompleteDataError(e) {
  return /unexpected end|incomplete|out of bounds|out of range/i.test(e?.message || '');
}
