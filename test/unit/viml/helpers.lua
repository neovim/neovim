local helpers = require('test.unit.helpers')(nil)

local ffi = helpers.ffi
local cimport = helpers.cimport
local kvi_new = helpers.kvi_new
local kvi_init = helpers.kvi_init
local conv_enum = helpers.conv_enum
local make_enum_conv_tab = helpers.make_enum_conv_tab

local lib = cimport('./src/nvim/viml/parser/expressions.h')

local function new_pstate(strings)
  local strings_idx = 0
  local function get_line(_, ret_pline)
    strings_idx = strings_idx + 1
    local str = strings[strings_idx]
    local data, size
    if type(str) == 'string' then
      data = str
      size = #str
    elseif type(str) == 'nil' then
      data = nil
      size = 0
    elseif type(str) == 'table' then
      data = str.data
      size = str.size
    elseif type(str) == 'function' then
      data, size = str()
      size = size or 0
    end
    ret_pline.data = data
    ret_pline.size = size
    ret_pline.allocated = false
  end
  local state = {
    reader = {
      get_line = get_line,
      cookie = nil,
      conv = {
        vc_type = 0,
        vc_factor = 1,
        vc_fail = false,
      },
    },
    pos = { line = 0, col = 0 },
    colors = kvi_new('ParserHighlight'),
    can_continuate = false,
  }
  local ret = ffi.new('ParserState', state)
  kvi_init(ret.reader.lines)
  kvi_init(ret.stack)
  return ret
end

local function pline2lua(pline)
  return ffi.string(pline.data, pline.size)
end

local function pstate_str(pstate, start, len)
  local str = nil
  local err = nil
  if start.line < pstate.reader.lines.size then
    local pstr = pline2lua(pstate.reader.lines.items[start.line])
    if start.col >= #pstr then
      err = 'start.col >= #pstr'
    else
      str = pstr:sub(tonumber(start.col) + 1, tonumber(start.col + len))
    end
  else
    err = 'start.line >= pstate.reader.lines.size'
  end
  return str, err
end

local function pstate_set_str(pstate, start, len, ret)
  ret = ret or {}
  ret.start = {
    line = tonumber(start.line),
    col = tonumber(start.col)
  }
  ret.len = tonumber(len)
  ret.str, ret.error = pstate_str(pstate, start, len)
  return ret
end

local eltkn_cmp_type_tab
make_enum_conv_tab(lib, {
  'kExprCmpEqual',
  'kExprCmpMatches',
  'kExprCmpGreater',
  'kExprCmpGreaterOrEqual',
  'kExprCmpIdentical',
}, 'kExprCmp', function(ret) eltkn_cmp_type_tab = ret end)

local function conv_cmp_type(typ)
  return conv_enum(eltkn_cmp_type_tab, typ)
end

local ccs_tab
make_enum_conv_tab(lib, {
  'kCCStrategyUseOption',
  'kCCStrategyMatchCase',
  'kCCStrategyIgnoreCase',
}, 'kCCStrategy', function(ret) ccs_tab = ret end)

local function conv_ccs(ccs)
  return conv_enum(ccs_tab, ccs)
end

local expr_asgn_type_tab
make_enum_conv_tab(lib, {
  'kExprAsgnPlain',
  'kExprAsgnAdd',
  'kExprAsgnSubtract',
  'kExprAsgnConcat',
}, 'kExprAsgn', function(ret) expr_asgn_type_tab = ret end)

local function conv_expr_asgn_type(expr_asgn_type)
  return conv_enum(expr_asgn_type_tab, expr_asgn_type)
end

return {
  conv_ccs = conv_ccs,
  pline2lua = pline2lua,
  pstate_str = pstate_str,
  new_pstate = new_pstate,
  conv_cmp_type = conv_cmp_type,
  pstate_set_str = pstate_set_str,
  conv_expr_asgn_type = conv_expr_asgn_type,
}
