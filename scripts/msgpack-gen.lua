lpeg = require('lpeg')
msgpack = require('cmsgpack')

-- lpeg grammar for building api metadata from a set of header files. It
-- ignores comments and preprocessor commands and parses a very small subset
-- of C prototypes with a limited set of types
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
c_param_type = (
  ((P('Error') * fill * P('*') * fill) * Cc('error')) +
  (C(c_id) * (ws ^ 1))
  )
c_type = (C(c_void) * (ws ^ 1)) + c_param_type
c_param = Ct(c_param_type * C(c_id))
c_param_list = c_param * (fill * (P(',') * fill * c_param) ^ 0)
c_params = Ct(c_void + c_param_list)
c_proto = Ct(
  Cg(c_type, 'return_type') * Cg(c_id, 'name') *
  fill * P('(') * fill * Cg(c_params, 'parameters') * fill * P(')') *
  fill * P(';')
  )
grammar = Ct((c_proto + c_comment + c_preproc + ws) ^ 1)

-- we need at least 2 arguments since the last one is the output file
assert(#arg >= 1)
-- api metadata
api = {
  functions = {},
  -- Helpers for object-oriented languages
  classes = {'Buffer', 'Window', 'Tabpage'}
}
-- names of all headers relative to the source root(for inclusion in the
-- generated file)
headers = {}
-- output file(dispatch function + metadata serialized with msgpack)
outputf = arg[#arg]

-- read each input file, parse and append to the api metadata
for i = 1, #arg - 1 do
  local full_path = arg[i]
  local parts = {}
  for part in string.gmatch(full_path, '[^/]+') do
    parts[#parts + 1] = part
  end
  headers[#headers + 1] = parts[#parts - 1]..'/'..parts[#parts]

  local input = io.open(full_path, 'rb')
  local tmp = grammar:match(input:read('*all'))
  for i = 1, #tmp do
    api.functions[#api.functions + 1] = tmp[i]
    local fn_id = #api.functions
    local fn = api.functions[fn_id]
    if #fn.parameters ~= 0 and fn.parameters[1][2] == 'channel_id' then
      -- this function should receive the channel id
      fn.receives_channel_id = true
      -- remove the parameter since it won't be passed by the api client
      table.remove(fn.parameters, 1)
    end
    if #fn.parameters ~= 0 and fn.parameters[#fn.parameters][1] == 'error' then
      -- function can fail if the last parameter type is 'Error'
      fn.can_fail = true
      -- remove the error parameter, msgpack has it's own special field
      -- for specifying errors
      fn.parameters[#fn.parameters] = nil
    end
    -- assign a unique integer id for each api function
    fn.id = fn_id
  end
  input:close()
end


-- start building the output
output = io.open(outputf, 'wb')

output:write([[
#include <stdbool.h>
#include <stdint.h>
#include <msgpack.h>

#include "nvim/os/msgpack_rpc.h"
]])

for i = 1, #headers do
  if headers[i]:sub(-12) ~= '.generated.h' then
    output:write('\n#include "nvim/'..headers[i]..'"')
  end
end

output:write([[


const uint8_t msgpack_metadata[] = {

]])
-- serialize the API metadata using msgpack and embed into the resulting
-- binary for easy querying by clients 
packed = msgpack.pack(api)
for i = 1, #packed do
  output:write(string.byte(packed, i)..', ')
  if i % 10 == 0 then
    output:write('\n  ')
  end
end
-- start the dispatch function. number 0 is reserved for querying the metadata,
-- usually it is the first function called by clients.
output:write([[
};
const unsigned int msgpack_metadata_size = sizeof(msgpack_metadata);

void msgpack_rpc_dispatch(uint64_t channel_id, msgpack_object *req, msgpack_packer *res)
{
  Error error = { .set = false };
  uint64_t method_id = (uint32_t)req->via.array.ptr[2].via.u64;

  switch (method_id) {
    case 0:
      msgpack_pack_nil(res);
      // The result is the [channel_id, metadata] array
      msgpack_pack_array(res, 2);
      msgpack_pack_uint64(res, channel_id);
      msgpack_pack_raw(res, sizeof(msgpack_metadata));
      msgpack_pack_raw_body(res, msgpack_metadata, sizeof(msgpack_metadata));
      return;
]])

-- Visit each function metadata to build the case label with code generated
-- for validating arguments and calling to the real API
for i = 1, #api.functions do
  local fn = api.functions[i]
  local args = {}
  local cleanup_label = 'cleanup_'..i
  output:write('\n    case '..fn.id..': {')

  output:write('\n      if (req->via.array.ptr[3].via.array.size != '..#fn.parameters..') {')
  output:write('\n        snprintf(error.msg, sizeof(error.msg), "Wrong number of arguments: expecting '..#fn.parameters..' but got %u", req->via.array.ptr[3].via.array.size);')
  output:write('\n        msgpack_rpc_error(error.msg, res);')
  output:write('\n        goto '..cleanup_label..';')
  output:write('\n      }\n')
  -- Declare/initialize variables that will hold converted arguments
  for j = 1, #fn.parameters do
    local param = fn.parameters[j]
    local converted = 'arg_'..j
    output:write('\n      '..param[1]..' '..converted..' msgpack_rpc_init_'..string.lower(param[1])..';')
  end
  output:write('\n')
  -- Validation/conversion for each argument
  for j = 1, #fn.parameters do
    local converted, convert_arg, param, arg
    param = fn.parameters[j]
    arg = '(req->via.array.ptr[3].via.array.ptr + '..(j - 1)..')'
    converted = 'arg_'..j
    convert_arg = 'msgpack_rpc_to_'..string.lower(param[1])
    output:write('\n      if (!'..convert_arg..'('..arg..', &'..converted..')) {')
    output:write('\n        msgpack_rpc_error("Wrong type for argument '..j..', expecting '..param[1]..'", res);')
    output:write('\n        goto '..cleanup_label..';')
    output:write('\n      }\n')
    args[#args + 1] = converted
  end
  
  -- function call
  local call_args = table.concat(args, ', ')
  output:write('\n      ')
  if fn.return_type ~= 'void' then
    -- has a return value, prefix the call with a declaration
    output:write(fn.return_type..' rv = ')
  end

  -- write the function name and the opening parenthesis
  output:write(fn.name..'(')

  if fn.receives_channel_id then
    -- if the function receives the channel id, pass it as first argument
    if #args > 0 then
      output:write('channel_id, '..call_args)
    else
      output:write('channel_id')
    end
  else
    output:write(call_args)
  end

  if fn.can_fail then
    -- if the function can fail, also pass a pointer to the local error object
    if #args > 0 then
      output:write(', &error);\n')
    else
      output:write('&error);\n')
    end
    -- and check for the error
    output:write('\n      if (error.set) {')
    output:write('\n        msgpack_rpc_error(error.msg, res);')
    output:write('\n        goto '..cleanup_label..';')
    output:write('\n      }\n')
  else
    output:write(');\n')
  end

  -- nil error
  output:write('\n      msgpack_pack_nil(res);');

  if fn.return_type == 'void' then
    output:write('\n      msgpack_pack_nil(res);');
  else
    output:write('\n      msgpack_rpc_from_'..string.lower(fn.return_type)..'(rv, res);')
    -- free the return value
    output:write('\n      msgpack_rpc_free_'..string.lower(fn.return_type)..'(rv);')
  end
  -- Now generate the cleanup label for freeing memory allocated for the
  -- arguments
  output:write('\n\n'..cleanup_label..':');

  for j = 1, #fn.parameters do
    local param = fn.parameters[j]
    output:write('\n      msgpack_rpc_free_'..string.lower(param[1])..'(arg_'..j..');')
  end
  output:write('\n      return;');
  output:write('\n    };\n');

end

output:write([[


    default:
      msgpack_rpc_error("Invalid function id", res);
  }
}
]])
output:close()
