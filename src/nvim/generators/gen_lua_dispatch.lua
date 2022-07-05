-- we need at least 4 arguments since the last two are output files
if arg[1] == '--help' then
  print('Usage: genmsgpack.lua args')
  print('Args: 1: source directory')
  print('      2: lua C bindings output file (lua_stdlib_c_bindings.generated.c)')
  print('      rest: C files where stdlib functions are defined')
end

assert(#arg >= 2)
local functions = {}

local nvimdir = arg[1]
package.path = nvimdir .. '/?.lua;' .. package.path

_G.vim = loadfile(nvimdir..'/../../runtime/lua/vim/shared.lua')()

-- names of all headers relative to the source root (for inclusion in the
-- generated file)
local headers = {}

local lua_c_bindings_outputf = arg[2]

local c_grammar = require('generators.c_grammar')

local function startswith(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

-- read each input file, parse and append to the api metadata
for i = 3, #arg do
  local full_path = arg[i]
  local parts = {}
  for part in string.gmatch(full_path, '[^/]+') do
    parts[#parts + 1] = part
  end
  headers[#headers + 1] = parts[#parts - 1]..'/'..parts[#parts]

  local input = assert(io.open(full_path, 'rb'))

  local tmp = c_grammar.grammar:match(input:read('*all'))
  for j = 1, #tmp do
    local fn = tmp[j]
    local public = startswith(fn.name, "nlua_stdlib_") or fn.deprecated_since
    if public and not fn.noexport then
      functions[#functions + 1] = tmp[j]
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

for _, f in ipairs(shallowcopy(functions)) do
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
    f.remote = f.remote_only or not f.lua_only
    f.lua = f.lua_only or not f.remote_only
    f.eval = (not f.lua_only) and (not f.remote_only)
  else
    f.since = 0
  end
  f.method = ismethod
end

-- don't expose internal attributes like "impl_name" in public metadata
local exported_attributes = {'name', 'return_type', 'method',
                             'since', 'deprecated_since'}
local exported_functions = {}
for _,f in ipairs(functions) do
  if not startswith(f.name, "nvim__") then
    local f_exported = {}
    for _,attr in ipairs(exported_attributes) do
      f_exported[attr] = f[attr]
    end
    f_exported.parameters = {}
    for i,param in ipairs(f.parameters) do
      if param[1] == "DictionaryOf(LuaRef)" then
        param = {"Dictionary", param[2]}
      elseif startswith(param[1], "Dict(") then
        param = {"Dictionary", param[2]}
      end
      f_exported.parameters[i] = param
    end
    exported_functions[#exported_functions+1] = f_exported
  end
end

local function real_type(type)
  local rv = type
  local rmatch = string.match(type, "Dict%(([_%w]+)%)")
  if rmatch then
    return "KeyDict_"..rmatch
  elseif c_grammar.typed_container:match(rv) then
    if rv:match('Array') then
      rv = 'Array'
    else
      rv = 'Dictionary'
    end
  end
  return rv
end

local function include_headers(output_handle, headers_to_include)
  for i = 1, #headers_to_include do
    if headers_to_include[i]:sub(-12) ~= '.generated.h' then
      output_handle:write('\n#include "nvim/'..headers_to_include[i]..'"')
    end
  end
end

-- start building lua output
local output = assert(io.open(lua_c_bindings_outputf, 'wb'))

local function write_shifted_output(_, str)
  str = str:gsub('\n  ', '\n')
  str = str:gsub('^  ', '')
  str = str:gsub(' +$', '')
  output:write(str)
end

output:write([[
// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "nvim/func_attr.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/lua/converter.h"
#include "nvim/lua/executor.h"
]])
include_headers(output, headers)
output:write('\n')

local lua_c_functions = {}

local function process_function(fn)
  local lua_c_function_name = ('nlua_stdlib_%s'):format(fn.name)
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
    api=fn.name:sub(13)
  }

  if not fn.fast then
    write_shifted_output(output, string.format([[
    if (!nlua_is_deferred_safe()) {
      return luaL_error(lstate, e_luv_api_disabled, "%s");
    }
    ]], fn.name))
  end

  if fn.check_textlock then
    write_shifted_output(output, [[
    if (textlock != 0) {
      api_set_error(&err, kErrorTypeException, "%s", e_secure);
      goto exit_0;
    }
    ]])
  end

  local cparams = ''
  local free_code = {}
  for j = #fn.parameters,1,-1 do
    local param = fn.parameters[j]
    local cparam = string.format('arg%u', j)
    local param_type = real_type(param[1])
    local lc_param_type = real_type(param[1]):lower()
    local extra = param_type == "Dictionary" and "false, " or ""
    if param[1] == "Object" or param[1] == "DictionaryOf(LuaRef)" then
      extra = "true, "
    end
    local errshift = 0
    if string.match(param_type, '^KeyDict_') then
      write_shifted_output(output, string.format([[
      %s %s = { 0 }; nlua_pop_keydict(lstate, &%s, %s_get_field, %s&err);]], param_type, cparam, cparam, param_type, extra))
      cparam = '&'..cparam
      errshift = 1 -- free incomplete dict on error
    else
      write_shifted_output(output, string.format([[
      const %s %s = nlua_pop_%s(lstate, %s&err);]], param[1], cparam, param_type, extra))
    end

    write_shifted_output(output, string.format([[

    if (ERROR_SET(&err)) {
      goto exit_%u;
    }

    ]], #fn.parameters - j + errshift))
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
    if i == 1 and not string.match(real_type(fn.parameters[1][1]), '^KeyDict_') then
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
  local return_type
  if fn.return_type ~= 'void' then
    if fn.return_type:match('^ArrayOf') then
      return_type = 'Array'
    else
      return_type = fn.return_type
    end
    write_shifted_output(output, string.format([[
    const %s ret = %s(%s);
    nlua_push_%s(lstate, ret, true);
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
  process_function(fn)
end

output:write(string.format([[
void nlua_state_add_stdlib_gen(lua_State *lstate);  // silence -Wmissing-prototypes
void nlua_state_add_stdlib_gen(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
]]))
for _, func in ipairs(lua_c_functions) do
  output:write(string.format([[

  lua_pushcfunction(lstate, &%s);
  lua_setfield(lstate, -2, "%s");]], func.binding, func.api))
end
output:write([[

}
]])

output:close()
