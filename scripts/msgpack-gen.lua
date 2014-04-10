lpeg = require('lpeg')
msgpack = require('cmsgpack')

P, R, S = lpeg.P, lpeg.R, lpeg.S
C, Ct, Cc, Cg = lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.Cg

any = P(1) -- (consume one character)
letter = R('az', 'AZ') + S('_$')
alpha = letter + R('09')
nl = P('\n')
not_nl = any - nl
ws = S(' \t') + nl
fill = ws ^ 0
c_comment = P('//') * (not_nl ^ 0)
c_preproc = P('#') * (not_nl ^ 0)
c_id = letter * (alpha ^ 0)
c_void = P('void')
c_raw = P('char') * fill * P('*')
c_int = P('uint32_t')
c_array = c_raw * fill * P('*') * Cc('array')
c_param_type = (
  (c_array  * Cc('array') * fill) +
  (c_raw * Cc('raw') * fill) +
  (c_int * Cc('integer') * (ws ^ 1))
  )
c_type = (c_void * Cc('none') * (ws ^ 1)) + c_param_type
c_param = Ct(c_param_type * C(c_id))
c_param_list = c_param * (fill * (P(',') * fill * c_param) ^ 0)
c_params = Ct(c_void + c_param_list)
c_proto = Ct(
  Cg(c_type, 'rtype') * Cg(c_id, 'fname') *
  fill * P('(') * fill * Cg(c_params, 'params') * fill * P(')') *
  fill * P(';')
  )
grammar = Ct((c_proto + c_comment + c_preproc + ws) ^ 1)

inputf = assert(arg[1])
outputf = assert(arg[2])

input = io.open(inputf, 'rb')
api = grammar:match(input:read('*all'))
input:close()

-- assign a unique integer id for each api function
for i = 1, #api do
  api[i].id = i
end

output = io.open(outputf, 'wb')

output:write([[
#include <stdbool.h>
#include <stdint.h>
#include <msgpack.h>

#include "api.h"
#include "msgpack_rpc.h"

static const uint8_t msgpack_metadata[] = {

]])
packed = msgpack.pack(api)
for i = 1, #packed do
  output:write(string.byte(packed, i)..', ')
  if i % 10 == 0 then
    output:write('\n  ')
  end
end
output:write([[
};

bool msgpack_rpc_dispatch(msgpack_object *req, msgpack_packer *res)
{
  uint32_t method_id = (uint32_t)req->via.u64;

  switch (method_id) {
    case 0:
      msgpack_rpc_response(req, res);
      msgpack_pack_nil(res);
      // The result is the `msgpack_metadata` byte array
      msgpack_pack_raw(res, sizeof(msgpack_metadata));
      msgpack_pack_raw_body(res, msgpack_metadata, sizeof(msgpack_metadata));
      return true;
]])

for i = 1, #api do
  local fn
  local args = {}
  fn = api[i]
  output:write('\n    case '..fn.id..':')
  for j = 1, #fn.params do
    local expected, convert, param
    local idx = tostring(j - 1)
    param = fn.params[j]
    ref = '(req->via.array.ptr[3].via.array.ptr + '..idx..')'
    -- decide which validation/conversion to use for this argument
    if param[1] == 'array' then
      expected = 'MSGPACK_OBJECT_ARRAY'
      convert = 'msgpack_rpc_array_argument'
    elseif param[1] == 'raw' then
      expected = 'MSGPACK_OBJECT_RAW'
      convert = 'msgpack_rpc_raw_argument'
    elseif param[1] == 'integer' then
      expected = 'MSGPACK_OBJECT_POSITIVE_INTEGER'
      convert = 'msgpack_rpc_integer_argument'
    end
    output:write('\n      if ('..ref..'->type != '..expected..') {')
    output:write('\n        return msgpack_rpc_error(req, res, "Wrong argument types");')
    output:write('\n      }')
    table.insert(args, convert..'('..ref..')')
  end
  local call_args = table.concat(args, ', ')
  -- convert the result back to msgpack
  if fn.rtype == 'none' then
    output:write('\n      '..fn.fname..'('..call_args..');')
    output:write('\n      return msgpack_rpc_void_result(req, res);\n')
  else
    if fn.rtype == 'array' then
      convert = 'msgpack_rpc_array_result'
    elseif fn.rtype == 'raw' then
      convert = 'msgpack_rpc_raw_result'
    elseif fn.rtype == 'integer' then
      convert = 'msgpack_rpc_integer_result'
    end
    output:write('\n      return '..convert..'('..fn.fname..'('..call_args..'), req, res);\n')
  end
end
output:write([[
    default:
      abort();
      return false;
  }
}
]])
output:close()
