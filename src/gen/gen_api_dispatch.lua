-- Generates C code to bridge API <=> Lua.
--
-- Example (manual) invocation:
--
--    make
--    cp build/nvim_version.lua src/nvim/
--    cd src/nvim
--    nvim -l generators/gen_api_dispatch.lua "../../build/src/nvim/auto/api/private/dispatch_wrappers.generated.h" "../../build/src/nvim/auto/api/private/api_metadata.generated.h" "../../build/funcs_metadata.mpack" "../../build/src/nvim/auto/lua_api_c_bindings.generated.h" "../../build/src/nvim/auto/keysets_defs.generated.h" "../../build/ui_metadata.mpack" "../../build/cmake.config/auto/versiondef_git.h" "./api/autocmd.h" "./api/buffer.h" "./api/command.h" "./api/deprecated.h" "./api/extmark.h" "./api/keysets_defs.h" "./api/options.h" "./api/tabpage.h" "./api/ui.h" "./api/vim.h" "./api/vimscript.h" "./api/win_config.h" "./api/window.h" "../../build/include/api/autocmd.h.generated.h" "../../build/include/api/buffer.h.generated.h" "../../build/include/api/command.h.generated.h" "../../build/include/api/deprecated.h.generated.h" "../../build/include/api/extmark.h.generated.h" "../../build/include/api/options.h.generated.h" "../../build/include/api/tabpage.h.generated.h" "../../build/include/api/ui.h.generated.h" "../../build/include/api/vim.h.generated.h" "../../build/include/api/vimscript.h.generated.h" "../../build/include/api/win_config.h.generated.h" "../../build/include/api/window.h.generated.h"

local hashy = require 'gen.hashy'
local c_grammar = require('gen.c_grammar')

-- output h file with generated dispatch functions (dispatch_wrappers.generated.h)
local dispatch_outputf = arg[1]
-- output h file with packed metadata (api_metadata.generated.h)
local api_metadata_outputf = arg[2]
-- output metadata mpack file, for use by other build scripts (funcs_metadata.mpack)
local mpack_outputf = arg[3]
local lua_c_bindings_outputf = arg[4] -- lua_api_c_bindings.generated.c
local keysets_outputf = arg[5] -- keysets_defs.generated.h
local ui_metadata_inputf = arg[6] -- ui events metadata
local git_version_inputf = arg[7] -- git version header
local nvim_version_inputf = arg[8] -- nvim version
local dump_bin_array_inputf = arg[9]
local dispatch_deprecated_inputf = arg[10]
local pre_args = 10
assert(#arg >= pre_args)

local function real_type(type, exported)
  local ptype = c_grammar.typed_container:match(type)
  if ptype then
    local container = ptype[1]
    if container == 'Union' then
      return 'Object'
    elseif container == 'Tuple' or container == 'ArrayOf' then
      return 'Array'
    elseif container == 'DictOf' or container == 'DictAs' then
      return 'Dict'
    elseif container == 'LuaRefOf' then
      return 'LuaRef'
    elseif container == 'Enum' then
      return 'String'
    elseif container == 'Dict' then
      if exported then
        return 'Dict'
      end
      -- internal type, used for keysets
      return 'KeyDict_' .. ptype[2]
    end
  end
  return type
end

--- @class gen_api_dispatch.Function : nvim.c_grammar.Proto
--- @field method boolean
--- @field receives_array_args? true
--- @field receives_channel_id? true
--- @field can_fail? true
--- @field has_lua_imp? true
--- @field receives_arena? true
--- @field impl_name? string
--- @field remote? boolean
--- @field lua? boolean
--- @field eval? boolean
--- @field handler_id? integer

--- @type gen_api_dispatch.Function[]
local functions = {}

--- Names of all headers relative to the source root (for inclusion in the
--- generated file)
--- @type string[]
local headers = {}

--- Set of function names, used to detect duplicates
--- @type table<string, true>
local function_names = {}

local startswith = vim.startswith

--- @param fn gen_api_dispatch.Function
local function add_function(fn)
  local public = startswith(fn.name, 'nvim_') or fn.deprecated_since
  if public and not fn.noexport then
    functions[#functions + 1] = fn
    function_names[fn.name] = true
    if
      #fn.parameters >= 2
      and fn.parameters[2][1] == 'Array'
      and fn.parameters[2][2] == 'uidata'
    then
      -- function receives the "args" as a parameter
      fn.receives_array_args = true
      -- remove the args parameter
      table.remove(fn.parameters, 2)
    end
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
    if #fn.parameters ~= 0 and fn.parameters[#fn.parameters][1] == 'lstate' then
      fn.has_lua_imp = true
      fn.parameters[#fn.parameters] = nil
    end
    if #fn.parameters ~= 0 and fn.parameters[#fn.parameters][1] == 'arena' then
      fn.receives_arena = true
      fn.parameters[#fn.parameters] = nil
    end
  end
end

--- @class gen_api_dispatch.Keyset
--- @field name string
--- @field keys string[]
--- @field c_names table<string, string>
--- @field types table<string, string>
--- @field has_optional boolean

--- @type gen_api_dispatch.Keyset[]
local keysets = {}

--- @param val nvim.c_grammar.Keyset
local function add_keyset(val)
  local keys = {} --- @type string[]
  local types = {} --- @type table<string, string>
  local c_names = {} --- @type table<string, string>
  local is_set_name = 'is_set__' .. val.keyset_name .. '_'
  local has_optional = false
  for i, field in ipairs(val.fields) do
    local dict_key = field.dict_key or field.name
    if field.type ~= 'Object' then
      types[dict_key] = field.type
    end
    if field.name ~= is_set_name and field.type ~= 'OptionalKeys' then
      table.insert(keys, dict_key)
      if dict_key ~= field.name then
        c_names[dict_key] = field.name
      end
    else
      if i > 1 then
        error("'is_set__{type}_' must be first if present")
      elseif field.name ~= is_set_name then
        error(val.keyset_name .. ': name of first key should be ' .. is_set_name)
      elseif field.type ~= 'OptionalKeys' then
        error("'" .. is_set_name .. "' must have type 'OptionalKeys'")
      end
      has_optional = true
    end
  end
  keysets[#keysets + 1] = {
    name = val.keyset_name,
    keys = keys,
    c_names = c_names,
    types = types,
    has_optional = has_optional,
  }
end

local ui_options_text = nil

-- read each input file, parse and append to the api metadata
for i = pre_args + 1, #arg do
  local full_path = arg[i]
  local parts = {} --- @type string[]
  for part in full_path:gmatch('[^/]+') do
    parts[#parts + 1] = part
  end
  headers[#headers + 1] = parts[#parts - 1] .. '/' .. parts[#parts]

  local input = assert(io.open(full_path, 'rb'))

  --- @type string
  local text = input:read('*all')
  for _, val in ipairs(c_grammar.grammar:match(text)) do
    if val.keyset_name then
      --- @cast val nvim.c_grammar.Keyset
      add_keyset(val)
    elseif val.name then
      --- @cast val gen_api_dispatch.Function
      add_function(val)
    end
  end

  ui_options_text = ui_options_text or text:match('ui_ext_names%[][^{]+{([^}]+)}')
  input:close()
end

--- @cast ui_options_text string

--- @generic T: table
--- @param orig T
--- @return T
local function shallowcopy(orig)
  local copy = {}
  for orig_key, orig_value in pairs(orig) do
    copy[orig_key] = orig_value
  end
  return copy
end

--- Export functions under older deprecated names.
--- These will be removed eventually.
--- @type table<string, string>
local deprecated_aliases = loadfile(dispatch_deprecated_inputf)()

for _, f in ipairs(shallowcopy(functions)) do
  local ismethod = false
  if startswith(f.name, 'nvim_') then
    if startswith(f.name, 'nvim__') or f.name == 'nvim_error_event' then
      f.since = -1
    elseif f.since == nil then
      print('Function ' .. f.name .. ' lacks since field.\n')
      os.exit(1)
    end
    f.since = tonumber(f.since)
    if f.deprecated_since ~= nil then
      f.deprecated_since = tonumber(f.deprecated_since)
    end

    if startswith(f.name, 'nvim_buf_') then
      ismethod = true
    elseif startswith(f.name, 'nvim_win_') then
      ismethod = true
    elseif startswith(f.name, 'nvim_tabpage_') then
      ismethod = true
    end
    f.remote = f.remote_only or not f.lua_only
    f.lua = f.lua_only or not f.remote_only
    f.eval = (not f.lua_only) and not f.remote_only
  else
    f.deprecated_since = tonumber(f.deprecated_since)
    assert(f.deprecated_since == 1)
    f.remote = true
    f.since = 0
  end
  f.method = ismethod
  local newname = deprecated_aliases[f.name]
  if newname ~= nil then
    if function_names[newname] then
      -- duplicate
      print(
        'Function '
          .. f.name
          .. ' has deprecated alias\n'
          .. newname
          .. ' which has a separate implementation.\n'
          .. 'Remove it from src/nvim/api/dispatch_deprecated.lua'
      )
      os.exit(1)
    end
    local newf = shallowcopy(f)
    newf.name = newname
    if newname == 'ui_try_resize' then
      -- The return type was incorrectly set to Object in 0.1.5.
      -- Keep it that way for clients that rely on this.
      newf.return_type = 'Object'
    end
    newf.impl_name = f.name
    newf.lua = false
    newf.eval = false
    newf.since = 0
    newf.deprecated_since = 1
    functions[#functions + 1] = newf
  end
end

--- don't expose internal attributes like "impl_name" in public metadata
--- @class gen_api_dispatch.Function.Exported
--- @field name string
--- @field parameters [string, string][]
--- @field return_type string
--- @field method boolean
--- @field since integer
--- @field deprecated_since integer

--- @type gen_api_dispatch.Function.Exported[]
local exported_functions = {}

for _, f in ipairs(functions) do
  if not (startswith(f.name, 'nvim__') or f.name == 'nvim_error_event' or f.name == 'redraw') then
    --- @type gen_api_dispatch.Function.Exported
    local f_exported = {
      name = f.name,
      method = f.method,
      since = f.since,
      deprecated_since = f.deprecated_since,
      parameters = {},
      return_type = real_type(f.return_type, true),
    }
    for i, param in ipairs(f.parameters) do
      f_exported.parameters[i] = { real_type(param[1], true), param[2] }
    end
    exported_functions[#exported_functions + 1] = f_exported
  end
end

local ui_options = { 'rgb' }
for x in ui_options_text:gmatch('"([a-z][a-z_]+)"') do
  table.insert(ui_options, x)
end

--- @type integer[]
local version = loadfile(nvim_version_inputf)()
local git_version = io.open(git_version_inputf):read '*a'
local version_build = git_version:match('#define NVIM_VERSION_BUILD "([^"]+)"') or vim.NIL

local pieces = {} --- @type string[]

-- Naively using mpack.encode({foo=x, bar=y}) will make the build
-- "non-reproducible". Emit maps directly as FIXDICT(2) "foo" x "bar" y instead
local function fixdict(num)
  if num > 15 then
    error 'implement more dict codes'
  end
  pieces[#pieces + 1] = string.char(128 + num)
end

local function put(item, item2)
  table.insert(pieces, vim.mpack.encode(item))
  if item2 ~= nil then
    table.insert(pieces, vim.mpack.encode(item2))
  end
end

fixdict(6)

put('version')
fixdict(1 + #version)
for _, item in ipairs(version) do
  -- NB: all items are mandatory. But any error will be less confusing
  -- with placeholder vim.NIL (than invalid mpack data)
  local val = item[2] == nil and vim.NIL or item[2]
  put(item[1], val)
end
put('build', version_build)

put('functions', exported_functions)
put('ui_events')
table.insert(pieces, io.open(ui_metadata_inputf, 'rb'):read('*all'))
put('ui_options', ui_options)

put('error_types')
fixdict(2)
put('Exception', { id = 0 })
put('Validation', { id = 1 })

put('types')
local types =
  { { 'Buffer', 'nvim_buf_' }, { 'Window', 'nvim_win_' }, { 'Tabpage', 'nvim_tabpage_' } }
fixdict(#types)
for i, item in ipairs(types) do
  put(item[1])
  fixdict(2)
  put('id', i - 1)
  put('prefix', item[2])
end

local packed = table.concat(pieces)
--- @type fun(api_metadata: file*, name: string, packed: string)
local dump_bin_array = loadfile(dump_bin_array_inputf)()

-- serialize the API metadata using msgpack and embed into the resulting
-- binary for easy querying by clients
local api_metadata_output = assert(io.open(api_metadata_outputf, 'wb'))
dump_bin_array(api_metadata_output, 'packed_api_metadata', packed)
api_metadata_output:close()

-- start building the dispatch wrapper output
local output = assert(io.open(dispatch_outputf, 'wb'))

-- ===========================================================================
-- NEW API FILES MUST GO HERE.
--
--  When creating a new API file, you must include it here,
--  so that the dispatcher can find the C functions that you are creating!
-- ===========================================================================
output:write([[
#include "nvim/errors.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/globals.h"
#include "nvim/log.h"
#include "nvim/map_defs.h"

#include "nvim/api/autocmd.h"
#include "nvim/api/buffer.h"
#include "nvim/api/command.h"
#include "nvim/api/deprecated.h"
#include "nvim/api/extmark.h"
#include "nvim/api/options.h"
#include "nvim/api/tabpage.h"
#include "nvim/api/ui.h"
#include "nvim/api/vim.h"
#include "nvim/api/vimscript.h"
#include "nvim/api/win_config.h"
#include "nvim/api/window.h"
#include "nvim/ui_client.h"

]])

local keysets_defs = assert(io.open(keysets_outputf, 'wb'))

keysets_defs:write('// IWYU pragma: private, include "nvim/api/private/dispatch.h"\n\n')

for _, k in ipairs(keysets) do
  local neworder, hashfun = hashy.hashy_hash(k.name, k.keys, function(idx)
    return k.name .. '_table[' .. idx .. '].str'
  end)

  keysets_defs:write('extern KeySetLink ' .. k.name .. '_table[' .. (1 + #neworder) .. '];\n')

  local function typename(type)
    if type == 'HLGroupID' then
      return 'kObjectTypeInteger'
    elseif not type or vim.startswith(type, 'Union') then
      return 'kObjectTypeNil'
    elseif type == 'StringArray' then
      return 'kUnpackTypeStringArray'
    end
    return 'kObjectType' .. real_type(type)
  end

  output:write('KeySetLink ' .. k.name .. '_table[] = {\n')
  for i, key in ipairs(neworder) do
    local ind = -1
    if k.has_optional then
      ind = i
      keysets_defs:write('#define KEYSET_OPTIDX_' .. k.name .. '__' .. key .. ' ' .. ind .. '\n')
    end
    output:write(
      '  {"'
        .. key
        .. '", offsetof(KeyDict_'
        .. k.name
        .. ', '
        .. (k.c_names[key] or key)
        .. '), '
        .. typename(k.types[key])
        .. ', '
        .. ind
        .. ', '
        .. (k.types[key] == 'HLGroupID' and 'true' or 'false')
        .. '},\n'
    )
  end
  output:write('  {NULL, 0, kObjectTypeNil, -1, false},\n')
  output:write('};\n\n')

  output:write(hashfun)

  output:write([[
KeySetLink *KeyDict_]] .. k.name .. [[_get_field(const char *str, size_t len)
{
  int hash = ]] .. k.name .. [[_hash(str, len);
  if (hash == -1) {
    return NULL;
  }
  return &]] .. k.name .. [[_table[hash];
}

]])
end

keysets_defs:close()

local function attr_name(rt)
  if rt == 'Float' then
    return 'floating'
  else
    return rt:lower()
  end
end

-- start the handler functions. Visit each function metadata to build the
-- handler function with code generated for validating arguments and calling to
-- the real API.
for i = 1, #functions do
  local fn = functions[i]
  if fn.impl_name == nil and fn.remote then
    local args = {} --- @type string[]

    output:write(
      'Object handle_' .. fn.name .. '(uint64_t channel_id, Array args, Arena* arena, Error *error)'
    )
    output:write('\n{')
    output:write('\n#ifdef NVIM_LOG_DEBUG')
    output:write('\n  DLOG("RPC: ch %" PRIu64 ": invoke ' .. fn.name .. '", channel_id);')
    output:write('\n#endif')
    output:write('\n  Object ret = NIL;')
    -- Declare/initialize variables that will hold converted arguments
    for j = 1, #fn.parameters do
      local param = fn.parameters[j]
      local rt = real_type(param[1])
      local converted = 'arg_' .. j
      output:write('\n  ' .. rt .. ' ' .. converted .. ';')
    end
    output:write('\n')
    if not fn.receives_array_args then
      output:write('\n  if (args.size != ' .. #fn.parameters .. ') {')
      output:write(
        '\n    api_set_error(error, kErrorTypeException, \
        "Wrong number of arguments: expecting '
          .. #fn.parameters
          .. ' but got %zu", args.size);'
      )
      output:write('\n    goto cleanup;')
      output:write('\n  }\n')
    end

    -- Validation/conversion for each argument
    for j = 1, #fn.parameters do
      local converted, param
      param = fn.parameters[j]
      converted = 'arg_' .. j
      local rt = real_type(param[1])
      if rt == 'Object' then
        output:write('\n  ' .. converted .. ' = args.items[' .. (j - 1) .. '];\n')
      elseif rt:match('^KeyDict_') then
        converted = '&' .. converted
        output:write('\n  if (args.items[' .. (j - 1) .. '].type == kObjectTypeDict) {') --luacheck: ignore 631
        output:write('\n    memset(' .. converted .. ', 0, sizeof(*' .. converted .. '));') -- TODO: neeeee
        output:write(
          '\n    if (!api_dict_to_keydict('
            .. converted
            .. ', '
            .. rt
            .. '_get_field, args.items['
            .. (j - 1)
            .. '].data.dict, error)) {'
        )
        output:write('\n      goto cleanup;')
        output:write('\n    }')
        output:write(
          '\n  } else if (args.items['
            .. (j - 1)
            .. '].type == kObjectTypeArray && args.items['
            .. (j - 1)
            .. '].data.array.size == 0) {'
        ) --luacheck: ignore 631
        output:write('\n    memset(' .. converted .. ', 0, sizeof(*' .. converted .. '));')

        output:write('\n  } else {')
        output:write(
          '\n    api_set_error(error, kErrorTypeException, \
          "Wrong type for argument '
            .. j
            .. ' when calling '
            .. fn.name
            .. ', expecting '
            .. param[1]
            .. '");'
        )
        output:write('\n    goto cleanup;')
        output:write('\n  }\n')
      else
        if rt:match('^Buffer$') or rt:match('^Window$') or rt:match('^Tabpage$') then
          -- Buffer, Window, and Tabpage have a specific type, but are stored in integer
          output:write(
            '\n  if (args.items['
              .. (j - 1)
              .. '].type == kObjectType'
              .. rt
              .. ' && args.items['
              .. (j - 1)
              .. '].data.integer >= 0) {'
          )
          output:write(
            '\n    ' .. converted .. ' = (handle_T)args.items[' .. (j - 1) .. '].data.integer;'
          )
        else
          output:write('\n  if (args.items[' .. (j - 1) .. '].type == kObjectType' .. rt .. ') {')
          output:write(
            '\n    '
              .. converted
              .. ' = args.items['
              .. (j - 1)
              .. '].data.'
              .. attr_name(rt)
              .. ';'
          )
        end
        if
          rt:match('^Buffer$')
          or rt:match('^Window$')
          or rt:match('^Tabpage$')
          or rt:match('^Boolean$')
        then
          -- accept nonnegative integers for Booleans, Buffers, Windows and Tabpages
          output:write(
            '\n  } else if (args.items['
              .. (j - 1)
              .. '].type == kObjectTypeInteger && args.items['
              .. (j - 1)
              .. '].data.integer >= 0) {'
          )
          output:write(
            '\n    ' .. converted .. ' = (handle_T)args.items[' .. (j - 1) .. '].data.integer;'
          )
        end
        if rt:match('^Float$') then
          -- accept integers for Floats
          output:write('\n  } else if (args.items[' .. (j - 1) .. '].type == kObjectTypeInteger) {')
          output:write(
            '\n    ' .. converted .. ' = (Float)args.items[' .. (j - 1) .. '].data.integer;'
          )
        end
        -- accept empty lua tables as empty dictionaries
        if rt:match('^Dict') then
          output:write(
            '\n  } else if (args.items['
              .. (j - 1)
              .. '].type == kObjectTypeArray && args.items['
              .. (j - 1)
              .. '].data.array.size == 0) {'
          ) --luacheck: ignore 631
          output:write('\n    ' .. converted .. ' = (Dict)ARRAY_DICT_INIT;')
        end
        output:write('\n  } else {')
        output:write(
          '\n    api_set_error(error, kErrorTypeException, \
          "Wrong type for argument '
            .. j
            .. ' when calling '
            .. fn.name
            .. ', expecting '
            .. param[1]
            .. '");'
        )
        output:write('\n    goto cleanup;')
        output:write('\n  }\n')
      end
      args[#args + 1] = converted
    end

    if fn.textlock then
      output:write('\n  if (text_locked()) {')
      output:write('\n    api_set_error(error, kErrorTypeException, "%s", get_text_locked_msg());')
      output:write('\n    goto cleanup;')
      output:write('\n  }\n')
    elseif fn.textlock_allow_cmdwin then
      output:write('\n  if (textlock != 0 || expr_map_locked()) {')
      output:write('\n    api_set_error(error, kErrorTypeException, "%s", e_textlock);')
      output:write('\n    goto cleanup;')
      output:write('\n  }\n')
    end

    -- function call
    output:write('\n  ')
    if fn.return_type ~= 'void' then
      -- has a return value, prefix the call with a declaration
      output:write(fn.return_type .. ' rv = ')
    end

    -- write the function name and the opening parenthesis
    output:write(fn.name .. '(')

    local call_args = {}
    if fn.receives_channel_id then
      table.insert(call_args, 'channel_id')
    end

    if fn.receives_array_args then
      table.insert(call_args, 'args')
    end

    for _, a in ipairs(args) do
      table.insert(call_args, a)
    end

    if fn.receives_arena then
      table.insert(call_args, 'arena')
    end

    if fn.has_lua_imp then
      table.insert(call_args, 'NULL')
    end

    if fn.can_fail then
      table.insert(call_args, 'error')
    end

    output:write(table.concat(call_args, ', '))
    output:write(');\n')

    if fn.can_fail then
      -- if the function can fail, also pass a pointer to the local error object
      -- and check for the error
      output:write('\n  if (ERROR_SET(error)) {')
      output:write('\n    goto cleanup;')
      output:write('\n  }\n')
    end

    local ret_type = real_type(fn.return_type)
    if ret_type:match('^KeyDict_') then
      local table = ret_type:sub(9) .. '_table'
      output:write(
        '\n  ret = DICT_OBJ(api_keydict_to_dict(&rv, '
          .. table
          .. ', ARRAY_SIZE('
          .. table
          .. '), arena));'
      )
    elseif ret_type ~= 'void' then
      output:write('\n  ret = ' .. real_type(fn.return_type):upper() .. '_OBJ(rv);')
    end
    output:write('\n\ncleanup:')

    output:write('\n  return ret;\n}\n\n')
  end
end

--- @type {[string]: gen_api_dispatch.Function, redraw: {impl_name: string, fast: boolean}}
local remote_fns = {}
for _, fn in ipairs(functions) do
  if fn.remote then
    remote_fns[fn.name] = fn
  end
end
remote_fns.redraw = { impl_name = 'ui_client_redraw', fast = true }

local names = vim.tbl_keys(remote_fns)
table.sort(names)
local hashorder, hashfun = hashy.hashy_hash('msgpack_rpc_get_handler_for', names, function(idx)
  return 'method_handlers[' .. idx .. '].name'
end)

output:write('const MsgpackRpcRequestHandler method_handlers[] = {\n')
for n, name in ipairs(hashorder) do
  local fn = remote_fns[name]
  fn.handler_id = n - 1
  output:write(
    '  { .name = "'
      .. name
      .. '", .fn = handle_'
      .. (fn.impl_name or fn.name)
      .. ', .fast = '
      .. tostring(fn.fast)
      .. ', .ret_alloc = '
      .. tostring(not not fn.ret_alloc)
      .. '},\n'
  )
end
output:write('};\n\n')
output:write(hashfun)

output:close()

--- @cast functions {[integer]: gen_api_dispatch.Function, keysets: gen_api_dispatch.Keyset[]}
functions.keysets = keysets
local mpack_output = assert(io.open(mpack_outputf, 'wb'))
mpack_output:write(vim.mpack.encode(functions))
mpack_output:close()

local function include_headers(output_handle, headers_to_include)
  for i = 1, #headers_to_include do
    if headers_to_include[i]:sub(-12) ~= '.generated.h' then
      output_handle:write('\n#include "nvim/' .. headers_to_include[i] .. '"')
    end
  end
end

--- @param str string
local function write_shifted_output(str, ...)
  str = str:gsub('\n  ', '\n')
  str = str:gsub('^  ', '')
  str = str:gsub(' +$', '')
  output:write(str:format(...))
end

-- start building lua output
output = assert(io.open(lua_c_bindings_outputf, 'wb'))

include_headers(output, headers)
output:write('\n')

--- @type {binding: string, api:string}[]
local lua_c_functions = {}

--- Generates C code to bridge RPC API <=> Lua.
---
--- Inspect the result here:
---    build/src/nvim/auto/api/private/dispatch_wrappers.generated.h
--- @param fn gen_api_dispatch.Function
local function process_function(fn)
  local lua_c_function_name = ('nlua_api_%s'):format(fn.name)
  write_shifted_output(
    [[

  static int %s(lua_State *lstate)
  {
    Error err = ERROR_INIT;
    Arena arena = ARENA_EMPTY;
    char *err_param = 0;
    if (lua_gettop(lstate) != %i) {
      api_set_error(&err, kErrorTypeValidation, "Expected %i argument%s");
      goto exit_0;
    }
  ]],
    lua_c_function_name,
    #fn.parameters,
    #fn.parameters,
    (#fn.parameters == 1) and '' or 's'
  )
  lua_c_functions[#lua_c_functions + 1] = {
    binding = lua_c_function_name,
    api = fn.name,
  }

  if not fn.fast then
    write_shifted_output(
      [[
    if (!nlua_is_deferred_safe()) {
      return luaL_error(lstate, e_fast_api_disabled, "%s");
    }
    ]],
      fn.name
    )
  end

  if fn.textlock then
    write_shifted_output([[
    if (text_locked()) {
      api_set_error(&err, kErrorTypeException, "%%s", get_text_locked_msg());
      goto exit_0;
    }
    ]])
  elseif fn.textlock_allow_cmdwin then
    write_shifted_output([[
    if (textlock != 0 || expr_map_locked()) {
      api_set_error(&err, kErrorTypeException, "%%s", e_textlock);
      goto exit_0;
    }
    ]])
  end

  local cparams = ''
  local free_code = {} --- @type string[]
  for j = #fn.parameters, 1, -1 do
    local param = fn.parameters[j]
    local cparam = string.format('arg%u', j)
    local param_type = real_type(param[1])
    local extra = param_type == 'Dict' and 'false, ' or ''
    local arg_free_code = ''
    if param_type == 'Object' then
      extra = 'true, '
      arg_free_code = '  api_luarefs_free_object(' .. cparam .. ');'
    elseif param[1] == 'DictOf(LuaRef)' then
      extra = 'true, '
      arg_free_code = '  api_luarefs_free_dict(' .. cparam .. ');'
    elseif param[1] == 'LuaRef' then
      arg_free_code = '  api_free_luaref(' .. cparam .. ');'
    end
    local errshift = 0
    local seterr = ''
    if param_type:match('^KeyDict_') then
      write_shifted_output(
        [[
    %s %s = KEYDICT_INIT;
    nlua_pop_keydict(lstate, &%s, %s_get_field, &err_param, &arena, &err);
    ]],
        param_type,
        cparam,
        cparam,
        param_type
      )
      cparam = '&' .. cparam
      errshift = 1 -- free incomplete dict on error
      arg_free_code = '  api_luarefs_free_keydict('
        .. cparam
        .. ', '
        .. param_type:sub(9)
        .. '_table);'
    else
      write_shifted_output(
        [[
    const %s %s = nlua_pop_%s(lstate, %s&arena, &err);]],
        param[1],
        cparam,
        param_type,
        extra
      )
      seterr = '\n      err_param = "' .. param[2] .. '";'
    end

    write_shifted_output([[

    if (ERROR_SET(&err)) {]] .. seterr .. [[

      goto exit_%u;
    }

    ]], #fn.parameters - j + errshift)
    free_code[#free_code + 1] = arg_free_code
    cparams = cparam .. ', ' .. cparams
  end
  if fn.receives_channel_id then
    --- @type string
    cparams = 'LUA_INTERNAL_CALL, ' .. cparams
  end
  if fn.receives_arena then
    cparams = cparams .. '&arena, '
  end

  if fn.has_lua_imp then
    cparams = cparams .. 'lstate, '
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
    if i == 1 and not real_type(fn.parameters[1][1]):match('^KeyDict_') then
      free_at_exit_code = free_at_exit_code .. ('\n%s'):format(code)
    else
      free_at_exit_code = free_at_exit_code .. ('\nexit_%u:\n%s'):format(rev_i, code)
    end
  end
  local err_throw_code = [[

exit_0:
  arena_mem_free(arena_finish(&arena));
  if (ERROR_SET(&err)) {
    luaL_where(lstate, 1);
    if (err_param) {
      lua_pushstring(lstate, "Invalid '");
      lua_pushstring(lstate, err_param);
      lua_pushstring(lstate, "': ");
    }
    lua_pushstring(lstate, err.msg);
    api_clear_error(&err);
    lua_concat(lstate, err_param ? 5 : 2);
    return lua_error(lstate);
  }
]]
  if fn.return_type ~= 'void' then
    local return_type = real_type(fn.return_type)
    local free_retval = ''
    if fn.ret_alloc then
      free_retval = '  api_free_' .. return_type:lower() .. '(ret);'
    end
    write_shifted_output('    %s ret = %s(%s);\n', fn.return_type, fn.name, cparams)

    local ret_type = real_type(fn.return_type)
    local ret_mode = (ret_type == 'Object') and '&' or ''
    if fn.has_lua_imp then
      -- only push onto the Lua stack if we haven't already
      write_shifted_output(
        [[
    if (lua_gettop(lstate) == 0) {
      nlua_push_%s(lstate, %sret, kNluaPushSpecial | kNluaPushFreeRefs);
    }
      ]],
        return_type,
        ret_mode
      )
    elseif ret_type:match('^KeyDict_') then
      write_shifted_output('    nlua_push_keydict(lstate, &ret, %s_table);\n', return_type:sub(9))
    else
      local special = (fn.since ~= nil and fn.since < 11)
      write_shifted_output(
        '    nlua_push_%s(lstate, %sret, %s | kNluaPushFreeRefs);\n',
        return_type,
        ret_mode,
        special and 'kNluaPushSpecial' or '0'
      )
    end

    -- NOTE: we currently assume err_throw needs nothing from arena
    write_shifted_output(
      [[
  %s
  %s
  %s
    return 1;
    ]],
      free_retval,
      free_at_exit_code,
      err_throw_code
    )
  else
    write_shifted_output(
      [[
    %s(%s);
  %s
  %s
    return 0;
    ]],
      fn.name,
      cparams,
      free_at_exit_code,
      err_throw_code
    )
  end
  write_shifted_output([[
  }
  ]])
end

for _, fn in ipairs(functions) do
  if fn.lua or fn.name:sub(1, 4) == '_vim' then
    process_function(fn)
  end
end

output:write(string.format(
  [[
void nlua_add_api_functions(lua_State *lstate)
{
  lua_createtable(lstate, 0, %u);
]],
  #lua_c_functions
))
for _, func in ipairs(lua_c_functions) do
  output:write(string.format(
    [[

  lua_pushcfunction(lstate, &%s);
  lua_setfield(lstate, -2, "%s");]],
    func.binding,
    func.api
  ))
end
output:write([[

  lua_setfield(lstate, -2, "api");
}
]])

output:close()
