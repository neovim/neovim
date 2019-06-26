if arg[1] == '--help' then
  print('Usage: genoptions.lua src/nvim options_file')
  os.exit(0)
end

local nvimsrcdir = arg[1]
local options_file = arg[2]

package.path = nvimsrcdir .. '/?.lua;' .. package.path

local opt_fd = io.open(options_file, 'w')

local w = function(s)
  if s:match('^    %.') then
    opt_fd:write(s .. ',\n')
  else
    opt_fd:write(s .. '\n')
  end
end

local options = require('options')

cstr = options.cstr

local type_flags={
  bool='P_BOOL',
  number='P_NUM',
  string='P_STRING',
}

local redraw_flags={
  statuslines='P_RSTAT',
  current_window='P_RWIN',
  current_window_only='P_RWINONLY',
  current_buffer='P_RBUF',
  all_windows='P_RALL',
  everything='P_RCLR',
  curswant='P_CURSWANT',
  ui_option='P_UI_OPTION',
}

local list_flags={
  comma='P_COMMA',
  onecomma='P_ONECOMMA',
  flags='P_FLAGLIST',
  flagscomma='P_COMMA|P_FLAGLIST',
}

local get_flags = function(o)
  local ret = {type_flags[o.type]}
  local add_flag = function(f)
    ret[1] = ret[1] .. '|' .. f
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
    {'alloced'},
    {'nodefault'},
    {'no_mkrc'},
    {'vi_def'},
    {'vim'},
    {'secure'},
    {'gettext'},
    {'noglob'},
    {'normal_fname_chars', 'P_NFNAME'},
    {'normal_dname_chars', 'P_NDNAME'},
    {'pri_mkrc'},
    {'deny_in_modelines', 'P_NO_ML'},
    {'deny_duplicates', 'P_NODUP'},
    {'modelineexpr', 'P_MLE'},
  }) do
    local key_name = flag_desc[1]
    local def_name = flag_desc[2] or ('P_' .. key_name:upper())
    if o[key_name] then
      add_flag(def_name)
    end
  end
  return ret[1]
end

local get_cond
get_cond = function(c, base_string)
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

value_dumpers = {
  ['function']=function(v) return v() end,
  string=cstr,
  boolean=function(v) return v and 'true' or 'false' end,
  number=function(v) return ('%iL'):format(v) end,
  ['nil']=function(v) return '0L' end,
}

local get_value = function(v)
  return '(char_u *) ' .. value_dumpers[type(v)](v)
end

local get_defaults = function(d)
  return ('{' .. get_value(d.vi) .. ', ' .. get_value(d.vim) .. '}')
end

local defines = {}

local dump_option = function(i, o)
  w('  [' .. ('%u'):format(i - 1) .. ']={')
  w('    .fullname=' .. cstr(o.full_name))
  if o.abbreviation then
    w('    .shortname=' .. cstr(o.abbreviation))
  end
  w('    .flags=' .. get_flags(o))
  if o.enable_if then
    w(get_cond(o.enable_if))
  end
  if o.varname then
    w('    .var=(char_u *)&' .. o.varname)
  elseif #o.scope == 1 and o.scope[1] == 'window' then
    w('    .var=VAR_WIN')
  end
  if o.enable_if then
    w('#endif')
  end
  if #o.scope == 1 and o.scope[1] == 'global' then
    w('    .indir=PV_NONE')
  else
    assert (#o.scope == 1 or #o.scope == 2)
    assert (#o.scope == 1 or o.scope[1] == 'global')
    local min_scope = o.scope[#o.scope]
    local varname = o.pv_name or o.varname or (
      'p_' .. (o.abbreviation or o.full_name))
    local pv_name = (
      'OPT_' .. min_scope:sub(1, 3):upper() .. '(' .. (
        min_scope:sub(1, 1):upper() .. 'V_' .. varname:sub(3):upper()
      ) .. ')'
    )
    if #o.scope == 2 then
      pv_name = 'OPT_BOTH(' .. pv_name .. ')'
    end
    defines['PV_' .. varname:sub(3):upper()] = pv_name
    w('    .indir=' .. pv_name)
  end
  if o.defaults then
    if o.defaults.condition then
      w(get_cond(o.defaults.condition))
    end
    w('    .def_val=' .. get_defaults(o.defaults.if_true))
    if o.defaults.condition then
      if o.defaults.if_false then
        w('#else')
        w('    .def_val=' .. get_defaults(o.defaults.if_false))
      end
      w('#endif')
    end
  end
  w('  },')
end

w('static vimoption_T options[] = {')
for i, o in ipairs(options.options) do
  dump_option(i, o)
end
w('  [' .. ('%u'):format(#options.options) .. ']={.fullname=NULL}')
w('};')
w('')

for k, v in pairs(defines) do
  w('#define ' .. k .. ' ' .. v)
end
opt_fd:close()
