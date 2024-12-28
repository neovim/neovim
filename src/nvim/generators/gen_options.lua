local options_file = arg[1]
local options_enum_file = arg[2]
local options_map_file = arg[3]
local option_vars_file = arg[4]

local opt_fd = assert(io.open(options_file, 'w'))
local opt_enum_fd = assert(io.open(options_enum_file, 'w'))
local opt_map_fd = assert(io.open(options_map_file, 'w'))
local opt_vars_fd = assert(io.open(option_vars_file, 'w'))

local w = function(s)
  if s:match('^    %.') then
    opt_fd:write(s .. ',\n')
  else
    opt_fd:write(s .. '\n')
  end
end

--- @param s string
local function enum_w(s)
  opt_enum_fd:write(s .. '\n')
end

--- @param s string
local function map_w(s)
  opt_map_fd:write(s .. '\n')
end

local function vars_w(s)
  opt_vars_fd:write(s .. '\n')
end

--- @module 'nvim.options'
local options = require('options')
local options_meta = options.options

local cstr = options.cstr
local valid_scopes = options.valid_scopes

--- Options for each scope.
--- @type table<string, vim.option_meta[]>
local scope_options = {}
for _, scope in ipairs(valid_scopes) do
  scope_options[scope] = {}
end

--- @param s string
--- @return string
local lowercase_to_titlecase = function(s)
  return table.concat(vim.tbl_map(function(word) --- @param word string
    return word:sub(1, 1):upper() .. word:sub(2)
  end, vim.split(s, '[-_]')))
end

-- Generate options enum file
enum_w('// IWYU pragma: private, include "nvim/option_defs.h"')
enum_w('')

--- Map of option name to option index
--- @type table<string, string>
local option_index = {}

-- Generate option index enum and populate the `option_index` and `scope_option` dicts.
enum_w('typedef enum {')
enum_w('  kOptInvalid = -1,')

for i, o in ipairs(options_meta) do
  local enum_val_name = 'kOpt' .. lowercase_to_titlecase(o.full_name)
  enum_w(('  %s = %u,'):format(enum_val_name, i - 1))

  option_index[o.full_name] = enum_val_name

  if o.abbreviation then
    option_index[o.abbreviation] = enum_val_name
  end

  if o.alias then
    o.alias = type(o.alias) == 'string' and { o.alias } or o.alias

    for _, v in ipairs(o.alias) do
      option_index[v] = enum_val_name
    end
  end

  for _, scope in ipairs(o.scope) do
    table.insert(scope_options[scope], o)
  end
end

enum_w('  // Option count')
enum_w('#define kOptCount ' .. tostring(#options_meta))
enum_w('} OptIndex;')

--- @param scope string
--- @param option_name string
--- @return string
local get_scope_option = function(scope, option_name)
  return ('k%sOpt%s'):format(lowercase_to_titlecase(scope), lowercase_to_titlecase(option_name))
end

-- Generate option index enum for each scope
for _, scope in ipairs(valid_scopes) do
  enum_w('')

  local scope_name = lowercase_to_titlecase(scope)
  enum_w('typedef enum {')
  enum_w(('  %s = -1,'):format(get_scope_option(scope, 'Invalid')))

  for idx, option in ipairs(scope_options[scope]) do
    enum_w(('  %s = %u,'):format(get_scope_option(scope, option.full_name), idx - 1))
  end

  enum_w(('  // %s option count'):format(scope_name))
  enum_w(('#define %s %d'):format(get_scope_option(scope, 'Count'), #scope_options[scope]))
  enum_w(('} %sOptIndex;'):format(scope_name))
end

-- Generate reverse lookup from option scope index to option index for each scope.
for _, scope in ipairs(valid_scopes) do
  enum_w('')
  enum_w(('EXTERN const OptIndex %s_opt_idx[] INIT( = {'):format(scope))
  for _, option in ipairs(scope_options[scope]) do
    local idx = option_index[option.full_name]
    enum_w(('  [%s] = %s,'):format(get_scope_option(scope, option.full_name), idx))
  end
  enum_w('});')
end

opt_enum_fd:close()

-- Generate option index map.
local hashy = require('generators.hashy')
local neworder, hashfun = hashy.hashy_hash('find_option', vim.tbl_keys(option_index), function(idx)
  return ('option_hash_elems[%s].name'):format(idx)
end)

map_w('static const struct { const char *name; OptIndex opt_idx; } option_hash_elems[] = {')

for _, name in ipairs(neworder) do
  assert(option_index[name] ~= nil)
  map_w(('  { .name = "%s", .opt_idx = %s },'):format(name, option_index[name]))
end

map_w('};\n')
map_w('static ' .. hashfun)

opt_map_fd:close()

vars_w('// IWYU pragma: private, include "nvim/option_vars.h"')

-- Generate enums for option flags.
for _, option in ipairs(options_meta) do
  if option.flags and (type(option.flags) == 'table' or option.values) then
    vars_w('')
    vars_w('typedef enum {')

    local opt_name = lowercase_to_titlecase(option.abbreviation or option.full_name)
    --- @type table<string,integer>
    local enum_values

    if type(option.flags) == 'table' then
      enum_values = option.flags --[[ @as table<string,integer> ]]
    else
      enum_values = {}
      for i, flag_name in ipairs(option.values) do
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
      vars_w(
        ('  kOpt%sFlag%s = 0x%02x,'):format(
          opt_name,
          lowercase_to_titlecase(flag_name:gsub(':$', '')),
          enum_values[flag_name]
        )
      )
    end

    vars_w(('} Opt%sFlags;'):format(opt_name))
  end
end

-- Generate valid values for each option.
for _, option in ipairs(options_meta) do
  --- @type function
  local preorder_traversal
  --- @param prefix string
  --- @param values vim.option_valid_values
  preorder_traversal = function(prefix, values)
    vars_w('')
    vars_w(
      ('EXTERN const char *(%s_values[%s]) INIT( = {'):format(prefix, #vim.tbl_keys(values) + 1)
    )

    --- @type [string,vim.option_valid_values][]
    local children = {}

    for _, value in ipairs(values) do
      if type(value) == 'string' then
        vars_w(('  "%s",'):format(value))
      else
        assert(type(value) == 'table' and type(value[1]) == 'string' and type(value[2]) == 'table')

        vars_w(('  "%s",'):format(value[1]))
        table.insert(children, value)
      end
    end

    vars_w('  NULL')
    vars_w('});')

    for _, value in pairs(children) do
      -- Remove trailing colon from the added prefix to prevent syntax errors.
      preorder_traversal(prefix .. '_' .. value[1]:gsub(':$', ''), value[2])
    end
  end

  -- Since option values can be nested, we need to do preorder traversal to generate the values.
  if option.values then
    preorder_traversal(('opt_%s'):format(option.abbreviation or option.full_name), option.values)
  end
end

opt_vars_fd:close()

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
  --- @type string
  local flags = '0'

  --- @param f string
  local add_flag = function(f)
    flags = flags .. '|' .. f
  end

  if o.list then
    add_flag(list_flags[o.list])
  end
  if o.redraw then
    for _, r_flag in ipairs(o.redraw) do
      add_flag(redraw_flags[r_flag])
    end
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
    local key_name = flag_desc[1]
    local def_name = 'kOptFlag' .. (flag_desc[2] or lowercase_to_titlecase(key_name))
    if o[key_name] then
      add_flag(def_name)
    end
  end
  return flags
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

--- @param c string|string[]
--- @param base_string? string
--- @return string
local function get_cond(c, base_string)
  local cond_string = base_string or '#if '
  if type(c) == 'table' then
    cond_string = cond_string .. get_cond(c[1], '')
    for i, subc in ipairs(c) do
      if i > 1 then
        cond_string = cond_string .. ' && ' .. get_cond(subc, '')
      end
    end
  elseif c:sub(1, 1) == '!' then
    cond_string = cond_string .. '!defined(' .. c:sub(2) .. ')'
  else
    cond_string = cond_string .. 'defined(' .. c .. ')'
  end
  return cond_string
end

--- @param s string
--- @return string
local static_cstr_as_string = function(s)
  return ('{ .data = %s, .size = sizeof(%s) - 1 }'):format(s, s)
end

--- @param v vim.option_value|function
--- @return string
local get_opt_val = function(v)
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
      v = static_cstr_as_string(cstr(v))
    end
  end

  return ('{ .type = %s, .data.%s = %s }'):format(opt_type_enum(v_type), v_type, v)
end

--- @param d vim.option_value|function
--- @param n string
--- @return string
local get_defaults = function(d, n)
  if d == nil then
    error("option '" .. n .. "' should have a default value")
  end
  return get_opt_val(d)
end

--- @param i integer
--- @param o vim.option_meta
local function dump_option(i, o)
  w('  [' .. ('%u'):format(i - 1) .. ']={')
  w('    .fullname=' .. cstr(o.full_name))
  if o.abbreviation then
    w('    .shortname=' .. cstr(o.abbreviation))
  end
  w('    .type=' .. opt_type_enum(o.type))
  w('    .flags=' .. get_flags(o))
  w('    .scope_flags=' .. get_scope_flags(o))
  w('    .scope_idx=' .. get_scope_idx(o))
  if o.enable_if then
    w(get_cond(o.enable_if))
  end

  local is_window_local = #o.scope == 1 and o.scope[1] == 'win'

  if not is_window_local then
    if o.varname then
      w('    .var=&' .. o.varname)
    elseif o.immutable then
      -- Immutable options can directly point to the default value.
      w(('    .var=&options[%u].def_val.data'):format(i - 1))
    else
      -- Option must be immutable or have a variable.
      assert(false)
    end
  else
    w('    .var=NULL')
  end
  w('    .immutable=' .. (o.immutable and 'true' or 'false'))
  if o.cb then
    w('    .opt_did_set_cb=' .. o.cb)
  end
  if o.expand_cb then
    w('    .opt_expand_cb=' .. o.expand_cb)
  end
  if o.enable_if then
    w('#else')
    -- Hidden option directly points to default value.
    w(('    .var=&options[%u].def_val.data'):format(i - 1))
    -- Option is always immutable on the false branch of `enable_if`.
    w('    .immutable=true')
    w('#endif')
  end
  if o.defaults then
    if o.defaults.condition then
      w(get_cond(o.defaults.condition))
    end
    w('    .def_val=' .. get_defaults(o.defaults.if_true, o.full_name))
    if o.defaults.condition then
      if o.defaults.if_false then
        w('#else')
        w('    .def_val=' .. get_defaults(o.defaults.if_false, o.full_name))
      end
      w('#endif')
    end
  else
    w('    .def_val=NIL_OPTVAL')
  end
  w('  },')
end

-- Generate options[] array.
w([[
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
for i, o in ipairs(options.options) do
  dump_option(i, o)
end
w('};')
