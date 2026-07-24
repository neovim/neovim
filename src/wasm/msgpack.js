// Check that the library is actually loaded.
if (typeof MessagePack === 'undefined') {
  throw new Error(
    'MessagePack library not loaded. ' +
    'Check that the CDN script tag for @msgpack/msgpack is present and loads correctly.'
  );
}

const MsgpackCodec = {
  encode(value) {
    const encoded = MessagePack.encode(value);

    // Debug: log the encoded bytes (first few bytes) to verify.
    const prefix = Array.from(encoded.slice(0, Math.min(encoded.length, 8)))
      .map(b => b.toString(16).padStart(2, '0'))
      .join(' ');
    console.log(`[MsgpackCodec.encode] ${encoded.length} bytes, prefix: ${prefix}`);

    return encoded;
  },

  decodeMulti(bytes) {
    return [...MessagePack.decodeMulti(bytes)];  // ✅ correct global
  },
};
