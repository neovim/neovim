mpack = require('mpack')

-- we need at least 4 arguments since the last two are output files
if arg[1] == '--help' then
  print('Usage: genmsgpack.lua args')
  print('Args: 1: source directory')
  print('      2: dispatch output file (dispatch_wrappers.generated.h)')
  print('      3: functions metadata output file (funcs_metadata.generated.h)')
  print('      4: API metadata output file (api_metadata.mpack)')
  print('      5: lua C bindings output file (msgpack_lua_c_bindings.generated.c)')
  print('      rest: C files where API functions are defined')
end
assert(#arg >= 4)
functions = {}

local nvimdir = arg[1]
package.path = nvimdir .. '/?/init.lua;' .. nvimdir .. '/?.lua;' .. package.path
package.path = nvimdir .. '/../../?.lua;' .. package.path

-- names of all headers relative to the source root (for inclusion in the
-- generated file)
headers = {}

-- output h file with generated dispatch functions
dispatch_outputf = arg[2]
-- output h file with packed metadata
funcs_metadata_outputf = arg[3]
-- output metadata mpack file, for use by other build scripts
mpack_outputf = arg[4]
lua_c_bindings_outputf = arg[5]

-- set of function names, used to detect duplicates
function_names = {}

c_grammar = require('generators.c_grammar')
local lust = require('generators.lust')
local global_test_helpers = require('test.helpers')

local dedent = global_test_helpers.dedent
local shallowcopy = global_test_helpers.shallowcopy

-- read each input file, parse and append to the api metadata
for i = 6, #arg do
  local full_path = arg[i]
  local parts = {}
  for part in string.gmatch(full_path, '[^/]+') do
    parts[#parts + 1] = part
  end
  headers[#headers + 1] = parts[#parts - 1]..'/'..parts[#parts]

  local input = io.open(full_path, 'rb')

  local tmp = c_grammar.grammar:match(input:read('*all'))
  for i = 1, #tmp do
    local fn = tmp[i]
    if not fn.noexport then
      functions[#functions + 1] = tmp[i]
      function_names[fn.name] = true
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
  end
  input:close()
end

local function shallowcopy(orig)
  local copy = {}
  for orig_key, orig_value in pairs(orig) do
    copy[orig_key] = orig_value
  end
  return copy
end

local function startswith(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

-- Export functions under older deprecated names.
-- These will be removed eventually.
local deprecated_aliases = require("api.dispatch_deprecated")
for i,f in ipairs(shallowcopy(functions)) do
  local ismethod = false
  if startswith(f.name, "nvim_") then
    if startswith(f.name, "nvim__") then
      f.since = -1
    elseif f.since == nil then
      print("Function "..f.name.." lacks since field.\n")
      os.exit(1)
    end
    f.since = tonumber(f.since)
    if f.deprecated_since ~= nil then
      f.deprecated_since = tonumber(f.deprecated_since)
    end

    if startswith(f.name, "nvim_buf_") then
      ismethod = true
    elseif startswith(f.name, "nvim_win_") then
      ismethod = true
    elseif startswith(f.name, "nvim_tabpage_") then
      ismethod = true
    end
  else
    f.remote_only = true
    f.since = 0
    f.deprecated_since = 1
  end
  f.method = ismethod
  local newname = deprecated_aliases[f.name]
  if newname ~= nil then
    if function_names[newname] then
      -- duplicate
      print("Function "..f.name.." has deprecated alias\n"
            ..newname.." which has a separate implementation.\n"..
            "Please remove it from src/nvim/api/dispatch_deprecated.lua")
      os.exit(1)
    end
    local newf = shallowcopy(f)
    newf.name = newname
    if newname == "ui_try_resize" then
      -- The return type was incorrectly set to Object in 0.1.5.
      -- Keep it that way for clients that rely on this.
      newf.return_type = "Object"
    end
    newf.impl_name = f.name
    newf.remote_only = true
    newf.since = 0
    newf.deprecated_since = 1
    functions[#functions+1] = newf
  end
end

-- don't expose internal attributes like "impl_name" in public metadata
exported_attributes = {'name', 'parameters', 'return_type', 'method',
                       'since', 'deprecated_since'}
exported_functions = {}
for _,f in ipairs(functions) do
  if not startswith(f.name, "nvim__") then
    local f_exported = {}
    for _,attr in ipairs(exported_attributes) do
      f_exported[attr] = f[attr]
    end
    exported_functions[#exported_functions+1] = f_exported
  end
end


-- serialize the API metadata using msgpack and embed into the resulting
-- binary for easy querying by clients
funcs_metadata_output = io.open(funcs_metadata_outputf, 'wb')
packed = mpack.pack(exported_functions)
dump_bin_array = require("generators.dump_bin_array")
dump_bin_array(funcs_metadata_output, 'funcs_metadata', packed)
funcs_metadata_output:close()

-- start building the dispatch wrapper output
output = io.open(dispatch_outputf, 'wb')

local function real_type(type)
  local rv = type
  if c_grammar.typed_container:match(rv) then
    if rv:match('Array') then
      rv = 'Array'
    else
      rv = 'Dictionary'
    end
  end
  return rv
end

local function attr_name(rt)
  if rt == 'Float' then
    return 'floating'
  else
    return rt:lower()
  end
end

local function nl(s)
  local ret = s:gsub('\\n', '\n')
  return ret
end

handlers_template = lust({
  nl(dedent([[
    @map{fn = functions, _separator="\n\n"}:{{@if(not fn.impl_name)<handle_function>}}
    void msgpack_rpc_init_method_table(void)
    {
      @map{fn = functions, _separator="\n"}:add_method_handler
    }\n]])),
  add_method_handler = dedent([[
    msgpack_rpc_add_method_handler(
      (String) { .data = "$fn.name", .size = sizeof("$fn.name") - 1 },
      (MsgpackRpcRequestHandler) {
        .fn = handle_@if(fn.impl_name)<{{$fn.impl_name}}>else<{{$fn.name}}>,
        .async = $async,
      });]]),
  handle_function = nl(dedent([[
    Object handle_$fn.name(uint64_t channel_id, Array args, Error *error)
    {
      Object ret = NIL;
      if (args.size != $#fn.parameters) {
        api_set_error(
          error, kErrorTypeException,
          "Wrong number of arguments: expecting $#fn.parameters but got %zu",
          args.size);
        goto cleanup;
      }

      @map{param = fn.parameters, _separator="\n\n"}:{{@process_arg}}

      @fcallstart$fn.name(@fcallargs);
      @if(fn.can_fail)<error_cleanup>
      @if(fn.return_type ~= "void")<{{ret = @<fn_rt_upper>_OBJ(rv);}}>

    cleanup:
      return ret;
    }]])),
  error_cleanup = dedent([[
    if (ERROR_SET(error)) {
      goto cleanup;
    }]]),
  process_arg = dedent([[
    $param.1 arg_$i0;
    @if(rt == "Object")<assign_object>else<check_and_assign_arg>]]),
  assign_object = '$converted = args.items[$i0];',
  check_and_assign_arg = dedent([[
    if (@arg_cond) {
      @arg_assignment
    } else {
      api_set_error(error, kErrorTypeException,
                    "Wrong type for argument $i1, expecting $param.1");
      goto cleanup;
    }]]),
  arg_cond = (
    '@if(rt_is_handle)<handle_cond>'
    .. 'else<{{args.items[$i0].type == kObjectType$rt}}>'
  ),
  arg_assignment = (
    '$converted = @if(rt_is_handle)<{{'
      .. '(handle_T)args.items[$i0].data.integer'
    .. '}}>else<{{'
      .. 'args.items[$i0].data.$rt_attr'
    .. '}}>;'
  ),
  handle_cond = dedent([[

    (args.items[$i0].type == kObjectType$rt
     || args.items[$i0].type == kObjectTypeInteger)
    && args.items[$i0].data.integer >= 0
  ]]),
  fcallstart = '@if(fn.return_type ~= "void")<{{$fn.return_type rv = }}>',
  fcallargs = (
    '@if(fn.receives_channel_id)<{{'
      .. 'channel_id@if(#fn.parameters > "0" or fn.can_fail)<{{, }}>'
    .. '}}>'
    .. '@map{ param = fn.parameters, _separator=", "}:{{arg_$i0}}'
    .. '@if(fn.can_fail)<{{'
      .. '@if(#fn.parameters > "0")<{{, }}>error'
    .. '}}>'
  ),
  fn_rt_upper = '$fn_rt_upper',
})
handlers_template:register('fn_rt_upper', function(env)
  return { fn_rt_upper = real_type(env.fn.return_type):upper() }
end)
handlers_template:register('process_arg', function(env)
  local ret = shallowcopy(env)
  ret.rt = real_type(env.param[1])
  ret.rt_attr = attr_name(ret.rt)
  ret.rt_is_handle = (ret.rt == "Buffer"
                      or ret.rt == "Window"
                      or ret.rt == "Tabpage")
  ret.converted = 'arg_' .. env.i0
  return ret
end)
handlers_template:register('add_method_handler', function(env)
  local ret = shallowcopy(env)
  ret.async = tostring(env.fn.async)
  return ret
end)
local handlers = handlers_template:gen({
  functions=functions
}):gsub('\n%s*\n', '\n\n'):gsub('\n\n+', '\n\n')
output:write(handlers)
output:close()

mpack_output = io.open(mpack_outputf, 'wb')
mpack_output:write(mpack.pack(functions))
mpack_output:close()

local function include_headers(output, headers)
  for i = 1, #headers do
    if headers[i]:sub(-12) ~= '.generated.h' then
      output:write('\n#include "nvim/'..headers[i]..'"')
    end
  end
end

local function write_shifted_output(output, str)
  str = str:gsub('\n  ', '\n')
  str = str:gsub('^  ', '')
  str = str:gsub(' +$', '')
  output:write(str)
end

-- start building lua output
output = io.open(lua_c_bindings_outputf, 'wb')

output:write([[
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "nvim/func_attr.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/lua/converter.h"
]])
include_headers(output, headers)
output:write('\n')

lua_c_functions = {}

local function process_function(fn)
  lua_c_function_name = ('nlua_msgpack_%s'):format(fn.name)
  write_shifted_output(output, string.format([[

  static int %s(lua_State *lstate)
  {
    Error err = ERROR_INIT;
    if (lua_gettop(lstate) != %i) {
      api_set_error(&err, kErrorTypeValidation, "Expected %i argument%s");
      goto exit_0;
    }
  ]], lua_c_function_name, #fn.parameters, #fn.parameters,
      (#fn.parameters == 1) and '' or 's'))
  lua_c_functions[#lua_c_functions + 1] = {
    binding=lua_c_function_name,
    api=fn.name
  }
  local cparams = ''
  local free_code = {}
  for j = #fn.parameters,1,-1 do
    param = fn.parameters[j]
    cparam = string.format('arg%u', j)
    param_type = real_type(param[1])
    lc_param_type = param_type:lower()
    write_shifted_output(output, string.format([[
    const %s %s = nlua_pop_%s(lstate, &err);

    if (ERROR_SET(&err)) {
      goto exit_%u;
    }
    ]], param[1], cparam, param_type, #fn.parameters - j))
    free_code[#free_code + 1] = ('api_free_%s(%s);'):format(
      lc_param_type, cparam)
    cparams = cparam .. ', ' .. cparams
  end
  if fn.receives_channel_id then
    cparams = 'LUA_INTERNAL_CALL, ' .. cparams
  end
  if fn.can_fail then
    cparams = cparams .. '&err'
  else
    cparams = cparams:gsub(', $', '')
  end
  local free_at_exit_code = ''
  for i = 1, #free_code do
    local rev_i = #free_code - i + 1
    local code = free_code[rev_i]
    if i == 1 then
      free_at_exit_code = free_at_exit_code .. ('\n    %s'):format(code)
    else
      free_at_exit_code = free_at_exit_code .. ('\n  exit_%u:\n    %s'):format(
        rev_i, code)
    end
  end
  local err_throw_code = [[

  exit_0:
    if (ERROR_SET(&err)) {
      luaL_where(lstate, 1);
      lua_pushstring(lstate, err.msg);
      api_clear_error(&err);
      lua_concat(lstate, 2);
      return lua_error(lstate);
    }
  ]]
  if fn.return_type ~= 'void' then
    if fn.return_type:match('^ArrayOf') then
      return_type = 'Array'
    else
      return_type = fn.return_type
    end
    write_shifted_output(output, string.format([[
    const %s ret = %s(%s);
    nlua_push_%s(lstate, ret);
    api_free_%s(ret);
  %s
  %s
    return 1;
    ]], fn.return_type, fn.name, cparams, return_type, return_type:lower(),
        free_at_exit_code, err_throw_code))
  else
    write_shifted_output(output, string.format([[
    %s(%s);
  %s
  %s
    return 0;
    ]], fn.name, cparams, free_at_exit_code, err_throw_code))
  end
  write_shifted_output(output, [[
  }
  ]])
end

for _, fn in ipairs(functions) do
  if not fn.remote_only or fn.name:sub(1, 4) == '_vim' then
    process_function(fn)
  end
end

output:write(string.format([[
void nlua_add_api_functions(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  lua_createtable(lstate, 0, %u);
]], #lua_c_functions))
for _, func in ipairs(lua_c_functions) do
  output:write(string.format([[

  lua_pushcfunction(lstate, &%s);
  lua_setfield(lstate, -2, "%s");]], func.binding, func.api))
end
output:write([[

  lua_setfield(lstate, -2, "api");
}
]])

output:close()
