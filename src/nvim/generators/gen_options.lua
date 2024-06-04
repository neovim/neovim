local options_file = arg[1]

local opt_fd = assert(io.open(options_file, 'w'))

local w = function(s)
  if s:match('^    %.') then
    opt_fd:write(s .. ',\n')
  else
    opt_fd:write(s .. '\n')
  end
end

--- @module 'nvim.options'
local options = require('options')

local cstr = options.cstr

local redraw_flags = {
  ui_option = 'P_UI_OPTION',
  tabline = 'P_RTABL',
  statuslines = 'P_RSTAT',
  current_window = 'P_RWIN',
  current_buffer = 'P_RBUF',
  all_windows = 'P_RALL',
  curswant = 'P_CURSWANT',
  highlight_only = 'P_HLONLY',
}

local list_flags = {
  comma = 'P_COMMA',
  onecomma = 'P_ONECOMMA',
  commacolon = 'P_COMMA|P_COLON',
  onecommacolon = 'P_ONECOMMA|P_COLON',
  flags = 'P_FLAGLIST',
  flagscomma = 'P_COMMA|P_FLAGLIST',
}

--- @param s string
--- @return string
local lowercase_to_titlecase = function(s)
  return s:sub(1, 1):upper() .. s:sub(2)
end

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
    add_flag('P_EXPAND')
    if o.expand == 'nodefault' then
      add_flag('P_NO_DEF_EXP')
    end
  end
  for _, flag_desc in ipairs({
    { 'alloced' },
    { 'nodefault' },
    { 'no_mkrc' },
    { 'secure' },
    { 'gettext' },
    { 'noglob' },
    { 'normal_fname_chars', 'P_NFNAME' },
    { 'normal_dname_chars', 'P_NDNAME' },
    { 'pri_mkrc' },
    { 'deny_in_modelines', 'P_NO_ML' },
    { 'deny_duplicates', 'P_NODUP' },
    { 'modelineexpr', 'P_MLE' },
    { 'func' },
  }) do
    local key_name = flag_desc[1]
    local def_name = flag_desc[2] or ('P_' .. key_name:upper())
    if o[key_name] then
      add_flag(def_name)
    end
  end
  return flags
end

--- @param o vim.option_meta
--- @return string
local function get_type_flags(o)
  local opt_types = (type(o.type) == 'table') and o.type or { o.type }
  local type_flags = '0'
  assert(type(opt_types) == 'table')

  for _, opt_type in ipairs(opt_types) do
    assert(type(opt_type) == 'string')
    type_flags = ('%s | (1 << kOptValType%s)'):format(type_flags, lowercase_to_titlecase(opt_type))
  end

  return type_flags
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

local get_defaults = function(d, n)
  if d == nil then
    error("option '" .. n .. "' should have a default value")
  end

  local value_dumpers = {
    ['function'] = function(v)
      return v()
    end,
    string = function(v)
      return '.string=' .. cstr(v)
    end,
    boolean = function(v)
      return '.boolean=' .. (v and 'true' or 'false')
    end,
    number = function(v)
      return ('.number=%iL'):format(v)
    end,
  }

  return value_dumpers[type(d)](d)
end

--- @type [string,string][]
local defines = {}

--- @param i integer
--- @param o vim.option_meta
local function dump_option(i, o)
  w('  [' .. ('%u'):format(i - 1) .. ']={')
  w('    .fullname=' .. cstr(o.full_name))
  if o.abbreviation then
    w('    .shortname=' .. cstr(o.abbreviation))
  end
  w('    .flags=' .. get_flags(o))
  w('    .type_flags=' .. get_type_flags(o))
  if o.enable_if then
    w(get_cond(o.enable_if))
  end

  -- An option cannot be both hidden and immutable.
  assert(not o.hidden or not o.immutable)

  local has_var = true
  if o.varname then
    w('    .var=&' .. o.varname)
  elseif o.hidden or o.immutable then
    -- Hidden and immutable options can directly point to the default value.
    w(('    .var=&options[%u].def_val'):format(i - 1))
  elseif #o.scope == 1 and o.scope[1] == 'window' then
    w('    .var=VAR_WIN')
  else
    has_var = false
  end
  -- `enable_if = false` should be present iff there is no variable.
  assert((o.enable_if == false) == not has_var)
  w('    .hidden=' .. (o.hidden and 'true' or 'false'))
  w('    .immutable=' .. (o.immutable and 'true' or 'false'))
  if #o.scope == 1 and o.scope[1] == 'global' then
    w('    .indir=PV_NONE')
  else
    assert(#o.scope == 1 or #o.scope == 2)
    assert(#o.scope == 1 or o.scope[1] == 'global')
    local min_scope = o.scope[#o.scope]
    local varname = o.pv_name or o.varname or ('p_' .. (o.abbreviation or o.full_name))
    local pv_name = (
      'OPT_'
      .. min_scope:sub(1, 3):upper()
      .. '('
      .. (min_scope:sub(1, 1):upper() .. 'V_' .. varname:sub(3):upper())
      .. ')'
    )
    if #o.scope == 2 then
      pv_name = 'OPT_BOTH(' .. pv_name .. ')'
    end
    table.insert(defines, { 'PV_' .. varname:sub(3):upper(), pv_name })
    w('    .indir=' .. pv_name)
  end
  if o.cb then
    w('    .opt_did_set_cb=' .. o.cb)
  end
  if o.expand_cb then
    w('    .opt_expand_cb=' .. o.expand_cb)
  end
  if o.enable_if then
    w('#else')
    w('    .var=NULL')
    w('    .indir=PV_NONE')
    w('#endif')
  end
  if o.defaults then
    if o.defaults.condition then
      w(get_cond(o.defaults.condition))
    end
    w('    .def_val' .. get_defaults(o.defaults.if_true, o.full_name))
    if o.defaults.condition then
      if o.defaults.if_false then
        w('#else')
        w('    .def_val' .. get_defaults(o.defaults.if_false, o.full_name))
      end
      w('#endif')
    end
  end
  w('  },')
end

w([[
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
w('')

for _, v in ipairs(defines) do
  w('#define ' .. v[1] .. ' ' .. v[2])
end
