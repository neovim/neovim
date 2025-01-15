--- @module 'nvim.options'
local options = require('options')
local options_meta = options.options
local cstr = options.cstr
local valid_scopes = options.valid_scopes

--- @param o vim.option_meta
--- @return string
local function get_values_var(o)
  return ('opt_%s_values'):format(o.abbreviation or o.full_name)
end

--- @param s string
--- @return string
local function lowercase_to_titlecase(s)
  return table.concat(vim.tbl_map(function(word) --- @param word string
    return word:sub(1, 1):upper() .. word:sub(2)
  end, vim.split(s, '[-_]')))
end

--- @param scope string
--- @param option_name string
--- @return string
local function get_scope_option(scope, option_name)
  return ('k%sOpt%s'):format(lowercase_to_titlecase(scope), lowercase_to_titlecase(option_name))
end

local redraw_flags = {
  ui_option = 'kOptFlagUIOption',
  tabline = 'kOptFlagRedrTabl',
  statuslines = 'kOptFlagRedrStat',
  current_window = 'kOptFlagRedrWin',
  current_buffer = 'kOptFlagRedrBuf',
  all_windows = 'kOptFlagRedrAll',
  curswant = 'kOptFlagCurswant',
  highlight_only = 'kOptFlagHLOnly',
}

local list_flags = {
  comma = 'kOptFlagComma',
  onecomma = 'kOptFlagOneComma',
  commacolon = 'kOptFlagComma|kOptFlagColon',
  onecommacolon = 'kOptFlagOneComma|kOptFlagColon',
  flags = 'kOptFlagFlagList',
  flagscomma = 'kOptFlagComma|kOptFlagFlagList',
}

--- @param o vim.option_meta
--- @return string
local function get_flags(o)
  --- @type string[]
  local flags = { '0' }

  --- @param f string
  local function add_flag(f)
    table.insert(flags, f)
  end

  if o.list then
    add_flag(list_flags[o.list])
  end

  for _, r_flag in ipairs(o.redraw or {}) do
    add_flag(redraw_flags[r_flag])
  end

  if o.expand then
    add_flag('kOptFlagExpand')
    if o.expand == 'nodefault' then
      add_flag('kOptFlagNoDefExp')
    end
  end

  for _, flag_desc in ipairs({
    { 'nodefault', 'NoDefault' },
    { 'no_mkrc', 'NoMkrc' },
    { 'secure' },
    { 'gettext' },
    { 'noglob', 'NoGlob' },
    { 'normal_fname_chars', 'NFname' },
    { 'normal_dname_chars', 'NDname' },
    { 'pri_mkrc', 'PriMkrc' },
    { 'deny_in_modelines', 'NoML' },
    { 'deny_duplicates', 'NoDup' },
    { 'modelineexpr', 'MLE' },
    { 'func' },
  }) do
    local key_name, flag_suffix = flag_desc[1], flag_desc[2]
    if o[key_name] then
      local def_name = 'kOptFlag' .. (flag_suffix or lowercase_to_titlecase(key_name))
      add_flag(def_name)
    end
  end

  return table.concat(flags, '|')
end

--- @param opt_type vim.option_type
--- @return string
local function opt_type_enum(opt_type)
  return ('kOptValType%s'):format(lowercase_to_titlecase(opt_type))
end

--- @param scope vim.option_scope
--- @return string
local function opt_scope_enum(scope)
  return ('kOptScope%s'):format(lowercase_to_titlecase(scope))
end

--- @param o vim.option_meta
--- @return string
local function get_scope_flags(o)
  local scope_flags = '0'

  for _, scope in ipairs(o.scope) do
    scope_flags = ('%s | (1 << %s)'):format(scope_flags, opt_scope_enum(scope))
  end

  return scope_flags
end

--- @param o vim.option_meta
--- @return string
local function get_scope_idx(o)
  --- @type string[]
  local strs = {}

  for _, scope in pairs(valid_scopes) do
    local has_scope = vim.tbl_contains(o.scope, scope)
    strs[#strs + 1] = ('      [%s] = %s'):format(
      opt_scope_enum(scope),
      get_scope_option(scope, has_scope and o.full_name or 'Invalid')
    )
  end

  return ('{\n%s\n    }'):format(table.concat(strs, ',\n'))
end

--- @param s string
--- @return string
local function static_cstr_as_string(s)
  return ('{ .data = %s, .size = sizeof(%s) - 1 }'):format(s, s)
end

--- @param v vim.option_value|function
--- @return string
local function get_opt_val(v)
  --- @type vim.option_type
  local v_type

  if type(v) == 'function' then
    v, v_type = v() --[[ @as string, vim.option_type ]]

    if v_type == 'string' then
      v = static_cstr_as_string(v)
    end
  else
    v_type = type(v) --[[ @as vim.option_type ]]

    if v_type == 'boolean' then
      v = v and 'true' or 'false'
    elseif v_type == 'number' then
      v = ('%iL'):format(v)
    elseif v_type == 'string' then
      --- @cast v string
      v = static_cstr_as_string(cstr(v))
    end
  end

  return ('{ .type = %s, .data.%s = %s }'):format(opt_type_enum(v_type), v_type, v)
end

--- @param d vim.option_value|function
--- @param n string
--- @return string
local function get_defaults(d, n)
  if d == nil then
    error("option '" .. n .. "' should have a default value")
  end
  return get_opt_val(d)
end

--- @param i integer
--- @param o vim.option_meta
--- @param write fun(...: string)
local function dump_option(i, o, write)
  write('  [', ('%u'):format(i - 1) .. ']={')
  write('    .fullname=', cstr(o.full_name))
  if o.abbreviation then
    write('    .shortname=', cstr(o.abbreviation))
  end
  write('    .type=', opt_type_enum(o.type))
  write('    .flags=', get_flags(o))
  write('    .scope_flags=', get_scope_flags(o))
  write('    .scope_idx=', get_scope_idx(o))
  write('    .values=', (o.values and get_values_var(o) or 'NULL'))
  write('    .values_len=', (o.values and #o.values or '0'))
  write('    .flags_var=', (o.flags_varname and ('&%s'):format(o.flags_varname) or 'NULL'))
  if o.enable_if then
    write(('#if defined(%s)'):format(o.enable_if))
  end

  local is_window_local = #o.scope == 1 and o.scope[1] == 'win'

  if is_window_local then
    write('    .var=NULL')
  elseif o.varname then
    write('    .var=&', o.varname)
  elseif o.immutable then
    -- Immutable options can directly point to the default value.
    write(('    .var=&options[%u].def_val.data'):format(i - 1))
  else
    error('Option must be immutable or have a variable.')
  end

  write('    .immutable=', (o.immutable and 'true' or 'false'))
  write('    .opt_did_set_cb=', o.cb or 'NULL')
  write('    .opt_expand_cb=', o.expand_cb or 'NULL')

  if o.enable_if then
    write('#else')
    -- Hidden option directly points to default value.
    write(('    .var=&options[%u].def_val.data'):format(i - 1))
    -- Option is always immutable on the false branch of `enable_if`.
    write('    .immutable=true')
    write('#endif')
  end

  if not o.defaults then
    write('    .def_val=NIL_OPTVAL')
  elseif o.defaults.condition then
    write(('#if defined(%s)'):format(o.defaults.condition))
    write('    .def_val=', get_defaults(o.defaults.if_true, o.full_name))
    if o.defaults.if_false then
      write('#else')
      write('    .def_val=', get_defaults(o.defaults.if_false, o.full_name))
    end
    write('#endif')
  else
    write('    .def_val=', get_defaults(o.defaults.if_true, o.full_name))
  end

  write('  },')
end

--- @param prefix string
--- @param values vim.option_valid_values
local function preorder_traversal(prefix, values)
  local out = {} --- @type string[]

  local function add(s)
    table.insert(out, s)
  end

  add('')
  add(('EXTERN const char *(%s_values[%s]) INIT( = {'):format(prefix, #vim.tbl_keys(values) + 1))

  --- @type [string,vim.option_valid_values][]
  local children = {}

  for _, value in ipairs(values) do
    if type(value) == 'string' then
      add(('  "%s",'):format(value))
    else
      assert(type(value) == 'table' and type(value[1]) == 'string' and type(value[2]) == 'table')
      add(('  "%s",'):format(value[1]))
      table.insert(children, value)
    end
  end

  add('  NULL')
  add('});')

  for _, value in pairs(children) do
    -- Remove trailing colon from the added prefix to prevent syntax errors.
    add(preorder_traversal(prefix .. '_' .. value[1]:gsub(':$', ''), value[2]))
  end

  return table.concat(out, '\n')
end

--- @param o vim.option_meta
--- @return string
local function gen_opt_enum(o)
  local out = {} --- @type string[]

  local function add(s)
    table.insert(out, s)
  end

  add('')
  add('typedef enum {')

  local opt_name = lowercase_to_titlecase(o.abbreviation or o.full_name)
  --- @type table<string,integer>
  local enum_values

  if type(o.flags) == 'table' then
    enum_values = o.flags --[[ @as table<string,integer> ]]
  else
    enum_values = {}
    for i, flag_name in ipairs(o.values) do
      assert(type(flag_name) == 'string')
      enum_values[flag_name] = math.pow(2, i - 1)
    end
  end

  -- Sort the keys by the flag value so that the enum can be generated in order.
  --- @type string[]
  local flag_names = vim.tbl_keys(enum_values)
  table.sort(flag_names, function(a, b)
    return enum_values[a] < enum_values[b]
  end)

  for _, flag_name in pairs(flag_names) do
    add(
      ('  kOpt%sFlag%s = 0x%02x,'):format(
        opt_name,
        lowercase_to_titlecase(flag_name:gsub(':$', '')),
        enum_values[flag_name]
      )
    )
  end

  add(('} Opt%sFlags;'):format(opt_name))

  return table.concat(out, '\n')
end

--- @param output_file string
--- @return table<string,string> options_index Map of option name to option index
local function gen_enums(output_file)
  --- Options for each scope.
  --- @type table<string, vim.option_meta[]>
  local scope_options = {}
  for _, scope in ipairs(valid_scopes) do
    scope_options[scope] = {}
  end

  local fd = assert(io.open(output_file, 'w'))

  --- @param s string
  local function write(s)
    fd:write(s)
    fd:write('\n')
  end

  -- Generate options enum file
  write('// IWYU pragma: private, include "nvim/option_defs.h"')
  write('')

  --- Map of option name to option index
  --- @type table<string, string>
  local option_index = {}

  -- Generate option index enum and populate the `option_index` and `scope_option` dicts.
  write('typedef enum {')
  write('  kOptInvalid = -1,')

  for i, o in ipairs(options_meta) do
    local enum_val_name = 'kOpt' .. lowercase_to_titlecase(o.full_name)
    write(('  %s = %u,'):format(enum_val_name, i - 1))

    option_index[o.full_name] = enum_val_name

    if o.abbreviation then
      option_index[o.abbreviation] = enum_val_name
    end

    local alias = o.alias or {} --[[@as string[] ]]
    for _, v in ipairs(alias) do
      option_index[v] = enum_val_name
    end

    for _, scope in ipairs(o.scope) do
      table.insert(scope_options[scope], o)
    end
  end

  write('  // Option count')
  write('#define kOptCount ' .. tostring(#options_meta))
  write('} OptIndex;')

  -- Generate option index enum for each scope
  for _, scope in ipairs(valid_scopes) do
    write('')

    local scope_name = lowercase_to_titlecase(scope)
    write('typedef enum {')
    write(('  %s = -1,'):format(get_scope_option(scope, 'Invalid')))

    for idx, option in ipairs(scope_options[scope]) do
      write(('  %s = %u,'):format(get_scope_option(scope, option.full_name), idx - 1))
    end

    write(('  // %s option count'):format(scope_name))
    write(('#define %s %d'):format(get_scope_option(scope, 'Count'), #scope_options[scope]))
    write(('} %sOptIndex;'):format(scope_name))
  end

  -- Generate reverse lookup from option scope index to option index for each scope.
  for _, scope in ipairs(valid_scopes) do
    write('')
    write(('EXTERN const OptIndex %s_opt_idx[] INIT( = {'):format(scope))
    for _, option in ipairs(scope_options[scope]) do
      local idx = option_index[option.full_name]
      write(('  [%s] = %s,'):format(get_scope_option(scope, option.full_name), idx))
    end
    write('});')
  end

  fd:close()

  return option_index
end

--- @param output_file string
--- @param option_index table<string,string>
local function gen_map(output_file, option_index)
  -- Generate option index map.
  local hashy = require('generators.hashy')

  local neworder, hashfun = hashy.hashy_hash(
    'find_option',
    vim.tbl_keys(option_index),
    function(idx)
      return ('option_hash_elems[%s].name'):format(idx)
    end
  )

  local fd = assert(io.open(output_file, 'w'))

  --- @param s string
  local function write(s)
    fd:write(s)
    fd:write('\n')
  end

  write('static const struct { const char *name; OptIndex opt_idx; } option_hash_elems[] = {')

  for _, name in ipairs(neworder) do
    assert(option_index[name] ~= nil)
    write(('  { .name = "%s", .opt_idx = %s },'):format(name, option_index[name]))
  end

  write('};')
  write('')
  write('static ' .. hashfun)

  fd:close()
end

--- @param output_file string
local function gen_vars(output_file)
  local fd = assert(io.open(output_file, 'w'))

  --- @param s string
  local function write(s)
    fd:write(s)
    fd:write('\n')
  end

  write('// IWYU pragma: private, include "nvim/option_vars.h"')

  -- Generate enums for option flags.
  for _, o in ipairs(options_meta) do
    if o.flags and (type(o.flags) == 'table' or o.values) then
      write(gen_opt_enum(o))
    end
  end

  -- Generate valid values for each option.
  for _, option in ipairs(options_meta) do
    -- Since option values can be nested, we need to do preorder traversal to generate the values.
    if option.values then
      local values_var = ('opt_%s'):format(option.abbreviation or option.full_name)
      write(preorder_traversal(values_var, option.values))
    end
  end

  fd:close()
end

--- @param output_file string
local function gen_options(output_file)
  local fd = assert(io.open(output_file, 'w'))

  --- @param ... string
  local function write(...)
    local s = table.concat({ ... }, '')
    fd:write(s)
    if s:match('^    %.') then
      fd:write(',')
    end
    fd:write('\n')
  end

  -- Generate options[] array.
  write([[
  #include "nvim/ex_docmd.h"
  #include "nvim/ex_getln.h"
  #include "nvim/insexpand.h"
  #include "nvim/mapping.h"
  #include "nvim/ops.h"
  #include "nvim/option.h"
  #include "nvim/optionstr.h"
  #include "nvim/quickfix.h"
  #include "nvim/runtime.h"
  #include "nvim/tag.h"
  #include "nvim/window.h"

  static vimoption_T options[] = {]])

  for i, o in ipairs(options_meta) do
    dump_option(i, o, write)
  end

  write('};')

  fd:close()
end

local function main()
  local options_file = arg[1]
  local options_enum_file = arg[2]
  local options_map_file = arg[3]
  local option_vars_file = arg[4]

  local option_index = gen_enums(options_enum_file)
  gen_map(options_map_file, option_index)
  gen_vars(option_vars_file)
  gen_options(options_file)
end

main()
