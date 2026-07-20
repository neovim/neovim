// msgpack-rpc message shapes:
//   request:      [0, msgid, method, params]
//   response:     [1, msgid, error, result]
//   notification: [2, method, params]

const Protocol = {
  encodeRequest(msgid, method, params) {
    return MsgpackCodec.encode([0, msgid, method, params]);
  },

  encodeNotification(method, params) {
    return MsgpackCodec.encode([2, method, params]);
  },

  // classifies a decoded msgpack-rpc array into a tagged object.
  // throws if `msg` doesn't look like a valid rpc message.
  parseMessage(msg) {
    if (!Array.isArray(msg)) throw new Error('rpc message is not an array');
    const [type, ...rest] = msg;
    if (type === 0) {
      const [msgid, method, params] = rest;
      return { kind: 'request', msgid, method, params };
    }
    if (type === 1) {
      const [msgid, error, result] = rest;
      return { kind: 'response', msgid, error, result };
    }
    if (type === 2) {
      const [method, params] = rest;
      return { kind: 'notification', method, params };
    }
    throw new Error('unknown rpc message type: ' + type);
  },
};
