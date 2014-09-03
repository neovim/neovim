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
    local fn = tmp[i]
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
  end
  input:close()
end


-- start building the output
output = io.open(outputf, 'wb')

output:write([[
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>
#include <msgpack.h>

#include "nvim/map.h"
#include "nvim/log.h"
#include "nvim/vim.h"
#include "nvim/os/msgpack_rpc.h"
#include "nvim/os/msgpack_rpc_helpers.h"
#include "nvim/api/private/helpers.h"
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
output:write([[
};
const unsigned int msgpack_metadata_size = sizeof(msgpack_metadata);
msgpack_unpacked msgpack_unpacked_metadata;

]])

-- start the handler functions. First handler (method_id=0) is reserved for
-- querying the metadata, usually it is the first function called by clients.
-- Visit each function metadata to build the handler function with code
-- generated for validating arguments and calling to the real API.
for i = 1, #api.functions do
  local fn = api.functions[i]
  local args = {}

  output:write('static Object handle_'..fn.name..'(uint64_t channel_id, msgpack_object *req, Error *error)')
  output:write('\n{')
  output:write('\n  DLOG("Received msgpack-rpc call to '..fn.name..'(request id: %" PRIu64 ")", req->via.array.ptr[1].via.u64);')
  -- Declare/initialize variables that will hold converted arguments
  for j = 1, #fn.parameters do
    local param = fn.parameters[j]
    local converted = 'arg_'..j
    output:write('\n  '..param[1]..' '..converted..' msgpack_rpc_init_'..string.lower(param[1])..';')
  end
  output:write('\n')
  output:write('\n  if (req->via.array.ptr[3].via.array.size != '..#fn.parameters..') {')
  output:write('\n    snprintf(error->msg, sizeof(error->msg), "Wrong number of arguments: expecting '..#fn.parameters..' but got %u", req->via.array.ptr[3].via.array.size);')
  output:write('\n    error->set = true;')
  output:write('\n    goto cleanup;')
  output:write('\n  }\n')

  -- Validation/conversion for each argument
  for j = 1, #fn.parameters do
    local converted, convert_arg, param, arg
    param = fn.parameters[j]
    arg = '(req->via.array.ptr[3].via.array.ptr + '..(j - 1)..')'
    converted = 'arg_'..j
    convert_arg = 'msgpack_rpc_to_'..string.lower(param[1])
    output:write('\n  if (!'..convert_arg..'('..arg..', &'..converted..')) {')
    output:write('\n    snprintf(error->msg, sizeof(error->msg), "Wrong type for argument '..j..', expecting '..param[1]..'");')
    output:write('\n    error->set = true;')
    output:write('\n    goto cleanup;')
    output:write('\n  }\n')
    args[#args + 1] = converted
  end

  -- function call
  local call_args = table.concat(args, ', ')
  output:write('\n  ')
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
      output:write(', error);\n')
    else
      output:write('error);\n')
    end
    -- and check for the error
    output:write('\n  if (error->set) {')
    output:write('\n    goto cleanup;')
    output:write('\n  }\n')
  else
    output:write(');\n')
  end

  if fn.return_type ~= 'void' then
    output:write('\n  Object ret = '..string.upper(fn.return_type)..'_OBJ(rv);')
  end
  -- Now generate the cleanup label for freeing memory allocated for the
  -- arguments
  output:write('\n\ncleanup:');

  for j = 1, #fn.parameters do
    local param = fn.parameters[j]
    output:write('\n  msgpack_rpc_free_'..string.lower(param[1])..'(arg_'..j..');')
  end
  if fn.return_type ~= 'void' then
    output:write('\n  return ret;\n}\n\n');
  else
    output:write('\n  return NIL;\n}\n\n');
  end
end

-- Generate a function that initializes method names with handler functions
output:write([[
static Map(String, rpc_method_handler_fn) *methods = NULL;

void msgpack_rpc_init(void)
{
  msgpack_unpacked_init(&msgpack_unpacked_metadata);
  if (msgpack_unpack_next(&msgpack_unpacked_metadata,
                          (const char *)msgpack_metadata,
                          msgpack_metadata_size,
                          NULL) != MSGPACK_UNPACK_SUCCESS) {
    abort();
  }

  methods = map_new(String, rpc_method_handler_fn)();

]])

-- Keep track of the maximum method name length in order to avoid walking
-- strings longer than that when searching for a method handler
local max_fname_len = 0
for i = 1, #api.functions do
  local fn = api.functions[i]
  output:write('  map_put(String, rpc_method_handler_fn)(methods, '..
               '(String) {.data = "'..fn.name..'", '..
               '.size = sizeof("'..fn.name..'") - 1}, handle_'..
               fn.name..');\n')

  if #fn.name > max_fname_len then
    max_fname_len = #fn.name
  end
end

local metadata_fn = 'get_api_metadata'
output:write('  map_put(String, rpc_method_handler_fn)(methods, '..
             '(String) {.data = "'..metadata_fn..'", '..
             '.size = sizeof("'..metadata_fn..'") - 1}, msgpack_rpc_handle_'..
             metadata_fn..');\n')

output:write('\n}\n\n')

output:write([[
Object msgpack_rpc_dispatch(uint64_t channel_id,
                            msgpack_object *req,
                            Error *error)
{
  msgpack_object method = req->via.array.ptr[2];
  rpc_method_handler_fn handler = NULL;

  if (method.type == MSGPACK_OBJECT_BIN || method.type == MSGPACK_OBJECT_STR) {
]])
output:write('    handler = map_get(String, rpc_method_handler_fn)')
output:write('(methods, (String){.data=(char *)method.via.bin.ptr,')
output:write('.size=min(method.via.bin.size, '..max_fname_len..')});\n')
output:write([[
  }

  if (!handler) {
    handler = msgpack_rpc_handle_missing_method;
  }

  return handler(channel_id, req, error);
}
]])

output:close()
