mpack = require('mpack')

-- we need at least 4 arguments since the last two are output files
if arg[1] == '--help' then
  print('Usage: genmsgpack.lua args')
  print('Args: 1: source directory')
  print('      2: dispatch output file (dispatch_wrappers.generated.c)')
  print('      3: dispatch table output file (dispatch_table.generated.h)')
  print('      4: functions metadata output file (funcs_metadata.generated.h)')
  print('      5: API metadata output file (api_metadata.mpack)')
  print('      6: lua C bindings output file (msgpack_lua_c_bindings.generated.c)')
  print('      rest: C files where API functions are defined')
end
assert(#arg >= 6)
functions = {}

local nvimdir = arg[1]
package.path = nvimdir .. '/?/init.lua;' .. nvimdir .. '/?.lua;' .. package.path
package.path = nvimdir .. '/../../?.lua;' .. package.path

-- names of all headers relative to the source root (for inclusion in the
-- generated file)
headers = {}
-- Like `headers`, but without headers ending with .generated.h
local written_headers = {}

-- output c file with generated dispatch functions
local dispatch_outputf = arg[2]
-- output h file with generated dispatch table
local dispatch_table_outputf = arg[3]
-- output h file with packed metadata
local funcs_metadata_outputf = arg[4]
-- output metadata mpack file, for use by other build scripts
local mpack_outputf = arg[5]
-- output c file with lua bindings
local lua_c_bindings_outputf = arg[6]

-- set of function names, used to detect duplicates
function_names = {}

c_grammar = require('generators.c_grammar')
local lust = require('generators.lust')
local gperf = require('generators.gperf')
local global_test_helpers = require('test.helpers')

local dedent = global_test_helpers.dedent
local shallowcopy = global_test_helpers.shallowcopy

local function path_split(full_path)
  local parts = {}
  for part in string.gmatch(full_path, '[^/]+') do
    parts[#parts + 1] = part
  end
  return parts
end

-- read each input file, parse and append to the api metadata
for i = 7, #arg do
  local full_path = arg[i]
  local parts = path_split(full_path)
  local header = parts[#parts - 1]..'/'..parts[#parts]
  headers[#headers + 1] = header
  if header:sub(-12) ~= '.generated.h' then
    written_headers[#written_headers + 1] = header
  end

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
    #include "nvim/func_attr.h"
    #include "nvim/api/private/dispatch.h"
    #include "nvim/api/private/helpers.h"
    #include "nvim/api/private/defs.h"

    @map{h = written_headers, _separator="\n"}:{{#include "nvim/$h"}}

    @map{fn = functions, _="\n\n"}:{{@if(not fn.impl_name)<handle_function>}}
    ]])),
  add_method_handler = dedent([[
    msgpack_rpc_add_method_handler(
      (String) { .data = "$fn.name", .size = sizeof("$fn.name") - 1 },
      (MsgpackRpcRequestHandler) {
        .fn = handle_@if(fn.impl_name)<{{$fn.impl_name}}>else<{{$fn.name}}>,
        .async = $async,
      });]]),
  handle_function = nl(dedent([[
    Object handle_$fn.name(uint64_t channel_id, Array args, Error *error)
      FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
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
  assign_object = 'arg_$i0 = args.items[$i0];',
  check_and_assign_arg = dedent([[
    if (@arg_cond) {
      arg_$i0 = @arg_value;
    } else {
      api_set_error(error, kErrorTypeException,
                    "Wrong type for argument $i1, expecting $param.1");
      goto cleanup;
    }]]),
  arg_cond = (
    '@if(rt_is_handle)<handle_cond>'
    .. 'else<{{'
      .. '@if(rt == "Boolean")<boolean_cond>'
      .. 'else<{{args.items[$i0].type == kObjectType$rt}}>'
    .. '}}>'
  ),
  arg_value = (
    '@if(rt_is_handle)<{{'
      .. '(handle_T)args.items[$i0].data.integer'
    .. '}}>else<{{'
      .. '@if(rt == "Boolean")<{{'
        .. dedent([[
          (
                args.items[$i0].type == kObjectTypeInteger
                ? args.items[$i0].data.integer
                : args.items[$i0].data.$rt_attr)]])
      .. '}}>else<{{'
        .. 'args.items[$i0].data.$rt_attr'
      .. '}}>'
    .. '}}>'
  ),
  handle_cond = dedent([[

    (args.items[$i0].type == kObjectType$rt
     || args.items[$i0].type == kObjectTypeInteger)
    && args.items[$i0].data.integer >= 0
  ]]),
  boolean_cond = dedent([[

    args.items[$i0].type == kObjectTypeBoolean
    || (args.items[$i0].type == kObjectTypeInteger
        && args.items[$i0].data.integer >= 0)
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
  return ret
end)
local dispatch_table_input_parts = path_split(dispatch_table_outputf)
local handlers = handlers_template:gen({
  written_headers=written_headers,
  functions=functions,
}):gsub('\n%s*\n', '\n\n'):gsub('\n\n+', '\n\n')
dispatch_output = io.open(dispatch_outputf, 'wb')
dispatch_output:write(handlers)
dispatch_output:close()

gperf.generate({
  outputf_base = dispatch_outputf,
  struct_type = 'MsgpackRpcRequestHandlerMapItem',
  initializer_suffix = ',{NULL,0}',
  item_callback = function(self, _, fn)
    return ('%s, {&handle_%s, %s}'):format(
      fn.name, fn.impl_name or fn.name, async and '1' or '0')
  end,
  data = functions,
})

mpack_output = io.open(mpack_outputf, 'wb')
mpack_output:write(mpack.pack(functions))
mpack_output:close()

-- start building lua output
local lua_functions = {}
for _, fn in ipairs(functions) do
  if not fn.remote_only then
    lua_functions[#lua_functions + 1] = fn
  end
end
lua_bindings_template = lust({
  nl(dedent([[
    #include <lua.h>
    #include <lualib.h>
    #include <lauxlib.h>

    #include "nvim/func_attr.h"
    #include "nvim/api/private/defs.h"
    #include "nvim/api/private/helpers.h"
    #include "nvim/lua/converter.h"

    @map{h = written_headers, _separator="\n"}:{{#include "nvim/$h"}}

    @map{fn = lua_functions, _separator="\n\n"}:binding_function
    void nlua_add_api_functions(lua_State *lstate)
      FUNC_ATTR_NONNULL_ALL
    {
      lua_createtable(lstate, 0, $#lua_functions);

      @map{fn = lua_functions, _separator="\n\n"}:add_binding_function

      lua_setfield(lstate, -2, "api");
    }\n]])),
  add_binding_function = dedent([[
    lua_pushcfunction(lstate, &@lua_c_function_name);
    lua_setfield(lstate, -2, "$fn.name");]]),
  lua_c_function_name = 'nlua_msgpack_$fn.name',
  binding_function = nl(dedent([[
    static int @lua_c_function_name(lua_State *lstate)
      FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
    {
      Error err = ERROR_INIT;
      if (lua_gettop(lstate) != $#fn.parameters) {
        api_set_error(&err, kErrorTypeValidation,
                      "Expected $#fn.parameters argument@param_s");
        goto exit_0;
      }

      @iter{fn.parameters, _separator="\n\n"}:process_arg

      @fcallstart$fn.name(@fcallargs);

      @if(fn.return_type ~= "void")<push_return>

    @map{param = fn.parameters, _separator="\n"}:cleanup_arg

    exit_0:
      if (ERROR_SET(&err)) {
        luaL_where(lstate, 1);
        lua_pushstring(lstate, err.msg);
        api_clear_error(&err);
        lua_concat(lstate, 2);
        return lua_error(lstate);
      }

      return @if(fn.return_type == "void")<{{0}}>else<{{1}}>;
    }]])),
  param_s = '@if(#fn.parameters ~= "1")<{{s}}>else<{{}}>',
  process_arg = dedent([[
    const $param.1 arg_$rev_i1 = nlua_pop_$rt(lstate, &err);
    if (ERROR_SET(&err)) {
      goto exit_$i0;
    }]]),
  cleanup_arg = dedent([[
    @if(i0 ~= "0")<{{exit_$rev_i0:}}>
      api_free_$rt_lower(arg_$i0);]]),
  fcallstart = '@if(fn.return_type ~= "void")<{{const $fn.return_type rv = }}>',
  fcallargs = (
    '@if(fn.receives_channel_id)<{{'
      .. 'LUA_INTERNAL_CALL@if(#fn.parameters > "0" or fn.can_fail)<{{, }}>'
    .. '}}>'
    .. '@map{ param = fn.parameters, _separator=", "}:{{arg_$i0}}'
    .. '@if(fn.can_fail)<{{'
      .. '@if(#fn.parameters > "0")<{{, }}>&err'
    .. '}}>'
  ),
  push_return = dedent([[
    nlua_push_$returntype(lstate, rv);
    api_free_$returntype_lower(rv);]]),
})
lua_bindings_template:register('process_arg', function(env)
  local ret = shallowcopy(env)
  ret.rev_i1 = #env.fn.parameters - env.i1
  ret.param = env.fn.parameters[ret.rev_i1 + 1]
  ret.rt = real_type(ret.param[1])
  ret.rt_lower = ret.rt:lower()
  return ret
end)
lua_bindings_template:register('cleanup_arg', function(env)
  local ret = shallowcopy(env)
  ret.rev_i0 = #env.fn.parameters - env.i0
  ret.rt = real_type(env.param[1])
  ret.rt_lower = ret.rt:lower()
  return ret
end)
lua_bindings_template:register('push_return', function(env)
  local returntype = real_type(env.fn.return_type)
  return {
    returntype = returntype,
    returntype_lower = returntype:lower()
  }
end)
local lua_bindings_output = io.open(lua_c_bindings_outputf, 'wb')
local handlers = lua_bindings_template:gen({
  written_headers=written_headers,
  lua_functions=lua_functions,
}):gsub('\n%s*\n', '\n\n'):gsub('\n\n+', '\n\n')
lua_bindings_output:write(handlers)
lua_bindings_output:close()
