// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>

#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/lib/khash.h"

/// Hash implementation for API String type
///
/// @param[in]  s  String to compute hash of.
///
/// @return Computed hash.
static inline khint_t string_hash(const String s)
  FUNC_ATTR_PURE FUNC_ATTR_ALWAYS_INLINE
{
  khint_t h = 0;
  for (size_t i = 0; i < s.size && s.data[i]; i++) {
    h = (h << 5) - h + (uint8_t)s.data[i];
  }
  return h;
}

/// Equality comparison implementation for API String type
///
/// @param[in]  a  First string to compare.
/// @param[in]  b  Second string to compare.
///
/// @return True if strings are equal, false otherwise.
static inline bool string_eq(const String a, const String b)
  FUNC_ATTR_PURE FUNC_ATTR_ALWAYS_INLINE
{
  if (a.size != b.size) {
    return false;
  }
  if (a.size == 0) {
    return true;
  }
  return memcmp(a.data, b.data, a.size) == 0;
}

KHASH_INIT(RpcRequestHandlersMap, String, MsgpackRpcRequestHandler,
           1, string_hash, string_eq)

/// Hash containing all supported RPC methods
khash_t(RpcRequestHandlersMap) methods = KHASH_EMPTY_INIT;

/// Store method handler in methods hash
///
/// @param[in]  method  Method name.
/// @param[in]  handler  Handler definition.
void msgpack_rpc_add_method_handler(String method,
                                    MsgpackRpcRequestHandler handler)
{
  int ret;
  const khiter_t k = kh_put(RpcRequestHandlersMap, &methods, method, &ret);
  assert(ret);
  kh_val(&methods, k) = handler;
}

/// Get handler for the given method name
///
/// @param[in]  name  Method name.
/// @param[in]  name_len  Method name length.
///
/// @return Handler stored in `methods` hash or
///         msgpack_rpc_handle_missing_method() handler.
MsgpackRpcRequestHandler msgpack_rpc_get_handler_for(const char *const name,
                                                     const size_t name_len)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  const String m = { .data = (char *)name, .size = name_len };
  const khiter_t k = kh_get(RpcRequestHandlersMap, &methods, m);
  if (k == kh_end(&methods)) {
    return (MsgpackRpcRequestHandler) {
      .fn = msgpack_rpc_handle_missing_method,
    };
  }
  return kh_val(&methods, k);
}
