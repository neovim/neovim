local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)

local child_call_once = helpers.child_call_once
local cimport = helpers.cimport
local ffi = helpers.ffi
local eq = helpers.eq

local lib = cimport('./src/nvim/viml/parser/expressions.h')

local eltkn_type_tab, eltkn_cmp_type_tab, ccs_tab, eltkn_mul_type_tab
local eltkn_opt_scope_tab
child_call_once(function()
  eltkn_type_tab = {
    [tonumber(lib.kExprLexInvalid)] = 'Invalid',
    [tonumber(lib.kExprLexMissing)] = 'Missing',
    [tonumber(lib.kExprLexSpacing)] = 'Spacing',
    [tonumber(lib.kExprLexEOC)] = 'EOC',

    [tonumber(lib.kExprLexQuestion)] = 'Question',
    [tonumber(lib.kExprLexColon)] = 'Colon',
    [tonumber(lib.kExprLexOr)] = 'Or',
    [tonumber(lib.kExprLexAnd)] = 'And',
    [tonumber(lib.kExprLexComparison)] = 'Comparison',
    [tonumber(lib.kExprLexPlus)] = 'Plus',
    [tonumber(lib.kExprLexMinus)] = 'Minus',
    [tonumber(lib.kExprLexDot)] = 'Dot',
    [tonumber(lib.kExprLexMultiplication)] = 'Multiplication',

    [tonumber(lib.kExprLexNot)] = 'Not',

    [tonumber(lib.kExprLexNumber)] = 'Number',
    [tonumber(lib.kExprLexSingleQuotedString)] = 'SingleQuotedString',
    [tonumber(lib.kExprLexDoubleQuotedString)] = 'DoubleQuotedString',
    [tonumber(lib.kExprLexOption)] = 'Option',
    [tonumber(lib.kExprLexRegister)] = 'Register',
    [tonumber(lib.kExprLexEnv)] = 'Env',
    [tonumber(lib.kExprLexPlainIdentifier)] = 'PlainIdentifier',

    [tonumber(lib.kExprLexBracket)] = 'Bracket',
    [tonumber(lib.kExprLexFigureBrace)] = 'FigureBrace',
    [tonumber(lib.kExprLexParenthesis)] = 'Parenthesis',
    [tonumber(lib.kExprLexComma)] = 'Comma',
    [tonumber(lib.kExprLexArrow)] = 'Arrow',
  }

  eltkn_cmp_type_tab = {
    [tonumber(lib.kExprLexCmpEqual)] = 'Equal',
    [tonumber(lib.kExprLexCmpMatches)] = 'Matches',
    [tonumber(lib.kExprLexCmpGreater)] = 'Greater',
    [tonumber(lib.kExprLexCmpGreaterOrEqual)] = 'GreaterOrEqual',
    [tonumber(lib.kExprLexCmpIdentical)] = 'Identical',
  }

  ccs_tab = {
    [tonumber(lib.kCCStrategyUseOption)] = 'UseOption',
    [tonumber(lib.kCCStrategyMatchCase)] = 'MatchCase',
    [tonumber(lib.kCCStrategyIgnoreCase)] = 'IgnoreCase',
  }

  eltkn_mul_type_tab = {
    [tonumber(lib.kExprLexMulMul)] = 'Mul',
    [tonumber(lib.kExprLexMulDiv)] = 'Div',
    [tonumber(lib.kExprLexMulMod)] = 'Mod',
  }

  eltkn_opt_scope_tab = {
    [tonumber(lib.kExprLexOptUnspecified)] = 'Unspecified',
    [tonumber(lib.kExprLexOptGlobal)] = 'Global',
    [tonumber(lib.kExprLexOptLocal)] = 'Local',
  }
end)

local function array_size(arr)
  return ffi.sizeof(arr) / ffi.sizeof(arr[0])
end

local function kvi_size(kvi)
  return array_size(kvi.init_array)
end

local function kvi_init(kvi)
  kvi.capacity = kvi_size(kvi)
  kvi.items = kvi.init_array
  return kvi
end

local function kvi_new(ct)
  return kvi_init(ffi.new(ct))
end

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
  end
  local pline_init = {
    data = nil,
    size = 0,
  }
  local state = {
    reader = {
      get_line = get_line,
      cookie = nil,
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

local function conv_enum(etab, eval)
  local n = tonumber(eval)
  return etab[n] or n
end

local function conv_eltkn_type(typ)
  return conv_enum(eltkn_type_tab, typ)
end

local function pline2lua(pline)
  return ffi.string(pline.data, pline.size)
end

local bracket_types = {
  Bracket = true,
  FigureBrace = true,
  Parenthesis = true,
}

local function intchar2lua(ch)
  ch = tonumber(ch)
  return (20 <= ch and ch < 127) and ('%c'):format(ch) or ch
end

local function eltkn2lua(pstate, tkn)
  local ret = {
    type = conv_eltkn_type(tkn.type),
    len = tonumber(tkn.len),
    start = { line = tonumber(tkn.start.line), col = tonumber(tkn.start.col) },
  }
  if ret.start.line < pstate.reader.lines.size then
    local pstr = pline2lua(pstate.reader.lines.items[ret.start.line])
    if ret.start.col >= #pstr then
      ret.error = 'start.col >= #pstr'
    else
      ret.str = pstr:sub(ret.start.col + 1, ret.start.col + ret.len)
      if #(ret.str) ~= ret.len then
        ret.error = '#str /= len'
      end
    end
  else
    ret.error = 'start.line >= pstate.reader.lines.size'
  end
  if ret.type == 'Comparison' then
    ret.data = {
      type = conv_enum(eltkn_cmp_type_tab, tkn.data.cmp.type),
      ccs = conv_enum(ccs_tab, tkn.data.cmp.ccs),
      inv = (not not tkn.data.cmp.inv),
    }
  elseif ret.type == 'Multiplication' then
    ret.data = { type = conv_enum(eltkn_mul_type_tab, tkn.data.mul.type) }
  elseif bracket_types[ret.type] then
    ret.data = { closing = (not not tkn.data.brc.closing) }
  elseif ret.type == 'Register' then
    ret.data = { name = intchar2lua(tkn.data.reg.name) }
  elseif (ret.type == 'SingleQuotedString'
          or ret.type == 'DoubleQuotedString') then
    ret.data = { closed = (not not tkn.data.str.closed) }
  elseif ret.type == 'Option' then
    ret.data = {
      scope = conv_enum(eltkn_opt_scope_tab, tkn.data.opt.scope),
      name = ffi.string(tkn.data.opt.name, tkn.data.opt.len),
    }
  elseif ret.type == 'PlainIdentifier' then
    ret.data = {
      scope = intchar2lua(tkn.data.var.scope),
      autoload = (not not tkn.data.var.autoload),
    }
  elseif ret.type == 'Invalid' then
    ret.data = { error = ffi.string(tkn.data.err.msg) }
  end
  return ret, tkn
end

local function next_eltkn(pstate)
  return eltkn2lua(pstate, lib.viml_pexpr_next_token(pstate, false))
end

describe('Expressions lexer', function()
  itp('works (single tokens)', function()
    local function singl_eltkn_test(typ, str, data)
      local pstate = new_pstate({str})
      eq({data=data, len=#str, start={col=0, line=0}, str=str, type=typ},
         next_eltkn(pstate))
      if not (
          typ == 'Spacing'
          or (typ == 'Register' and str == '@')
          or ((typ == 'SingleQuotedString' or typ == 'DoubleQuotedString')
              and not data.closed)
      ) then
        pstate = new_pstate({str .. ' '})
        eq({data=data, len=#str, start={col=0, line=0}, str=str, type=typ},
           next_eltkn(pstate))
      end
      pstate = new_pstate({'x' .. str})
      pstate.pos.col = 1
      eq({data=data, len=#str, start={col=1, line=0}, str=str, type=typ},
         next_eltkn(pstate))
    end
    singl_eltkn_test('Parenthesis', '(', {closing=false})
    singl_eltkn_test('Parenthesis', ')', {closing=true})
    singl_eltkn_test('Bracket', '[', {closing=false})
    singl_eltkn_test('Bracket', ']', {closing=true})
    singl_eltkn_test('FigureBrace', '{', {closing=false})
    singl_eltkn_test('FigureBrace', '}', {closing=true})
    singl_eltkn_test('Question', '?')
    singl_eltkn_test('Colon', ':')
    singl_eltkn_test('Dot', '.')
    singl_eltkn_test('Plus', '+')
    singl_eltkn_test('Comma', ',')
    singl_eltkn_test('Multiplication', '*', {type='Mul'})
    singl_eltkn_test('Multiplication', '/', {type='Div'})
    singl_eltkn_test('Multiplication', '%', {type='Mod'})
    singl_eltkn_test('Spacing', '  \t\t  \t\t')
    singl_eltkn_test('Spacing', ' ')
    singl_eltkn_test('Spacing', '\t')
    singl_eltkn_test('Invalid', '\x01\x02\x03', {error='E15: Invalid control character present in input: %.*s'})
    singl_eltkn_test('Number', '0123')
    singl_eltkn_test('Number', '0')
    singl_eltkn_test('Number', '9')
    singl_eltkn_test('Env', '$abc')
    singl_eltkn_test('Env', '$')
    singl_eltkn_test('PlainIdentifier', 'test', {autoload=false, scope=0})
    singl_eltkn_test('PlainIdentifier', '_test', {autoload=false, scope=0})
    singl_eltkn_test('PlainIdentifier', '_test_foo', {autoload=false, scope=0})
    singl_eltkn_test('PlainIdentifier', 't', {autoload=false, scope=0})
    singl_eltkn_test('PlainIdentifier', 'test5', {autoload=false, scope=0})
    singl_eltkn_test('PlainIdentifier', 't0', {autoload=false, scope=0})
    singl_eltkn_test('PlainIdentifier', 'test#var', {autoload=true, scope=0})
    singl_eltkn_test('PlainIdentifier', 'test#var#val###', {autoload=true, scope=0})
    singl_eltkn_test('PlainIdentifier', 't#####', {autoload=true, scope=0})
    local function scope_test(scope)
      singl_eltkn_test('PlainIdentifier', scope .. ':test#var', {autoload=true, scope=scope})
      singl_eltkn_test('PlainIdentifier', scope .. ':', {autoload=false, scope=scope})
    end
    scope_test('s')
    scope_test('g')
    scope_test('v')
    scope_test('b')
    scope_test('w')
    scope_test('t')
    scope_test('l')
    scope_test('a')
    local function comparison_test(op, inv_op, cmp_type)
      singl_eltkn_test('Comparison', op, {type=cmp_type, inv=false, ccs='UseOption'})
      singl_eltkn_test('Comparison', inv_op, {type=cmp_type, inv=true, ccs='UseOption'})
      singl_eltkn_test('Comparison', op .. '#', {type=cmp_type, inv=false, ccs='MatchCase'})
      singl_eltkn_test('Comparison', inv_op .. '#', {type=cmp_type, inv=true, ccs='MatchCase'})
      singl_eltkn_test('Comparison', op .. '?', {type=cmp_type, inv=false, ccs='IgnoreCase'})
      singl_eltkn_test('Comparison', inv_op .. '?', {type=cmp_type, inv=true, ccs='IgnoreCase'})
    end
    comparison_test('is', 'isnot', 'Identical')
    singl_eltkn_test('And', '&&')
    singl_eltkn_test('Invalid', '&', {error='E112: Option name missing: %.*s'})
    singl_eltkn_test('Option', '&opt', {scope='Unspecified', name='opt'})
    singl_eltkn_test('Option', '&t_xx', {scope='Unspecified', name='t_xx'})
    singl_eltkn_test('Option', '&t_\r\r', {scope='Unspecified', name='t_\r\r'})
    singl_eltkn_test('Option', '&t_\t\t', {scope='Unspecified', name='t_\t\t'})
    singl_eltkn_test('Option', '&t_  ', {scope='Unspecified', name='t_  '})
    singl_eltkn_test('Option', '&g:opt', {scope='Global', name='opt'})
    singl_eltkn_test('Option', '&l:opt', {scope='Local', name='opt'})
    singl_eltkn_test('Invalid', '&l:', {error='E112: Option name missing: %.*s'})
    singl_eltkn_test('Invalid', '&g:', {error='E112: Option name missing: %.*s'})
    singl_eltkn_test('Register', '@', {name=-1})
    singl_eltkn_test('Register', '@a', {name='a'})
    singl_eltkn_test('Register', '@\r', {name=13})
    singl_eltkn_test('Register', '@ ', {name=' '})
    singl_eltkn_test('Register', '@\t', {name=9})
    singl_eltkn_test('SingleQuotedString', '\'test', {closed=false})
    singl_eltkn_test('SingleQuotedString', '\'test\'', {closed=true})
    singl_eltkn_test('SingleQuotedString', '\'\'\'\'', {closed=true})
    singl_eltkn_test('SingleQuotedString', '\'x\'\'\'', {closed=true})
    singl_eltkn_test('SingleQuotedString', '\'\'\'x\'', {closed=true})
    singl_eltkn_test('SingleQuotedString', '\'\'\'', {closed=false})
    singl_eltkn_test('SingleQuotedString', '\'x\'\'', {closed=false})
    singl_eltkn_test('SingleQuotedString', '\'\'\'x', {closed=false})
    singl_eltkn_test('DoubleQuotedString', '"test', {closed=false})
    singl_eltkn_test('DoubleQuotedString', '"test"', {closed=true})
    singl_eltkn_test('DoubleQuotedString', '"\\""', {closed=true})
    singl_eltkn_test('DoubleQuotedString', '"x\\""', {closed=true})
    singl_eltkn_test('DoubleQuotedString', '"\\"x"', {closed=true})
    singl_eltkn_test('DoubleQuotedString', '"\\"', {closed=false})
    singl_eltkn_test('DoubleQuotedString', '"x\\"', {closed=false})
    singl_eltkn_test('DoubleQuotedString', '"\\"x', {closed=false})
    singl_eltkn_test('Not', '!')
    singl_eltkn_test('Invalid', '=', {error='E15: Expected == or =~: %.*s'})
    comparison_test('==', '!=', 'Equal')
    comparison_test('=~', '!~', 'Matches')
    comparison_test('>', '<=', 'Greater')
    comparison_test('>=', '<', 'GreaterOrEqual')
    singl_eltkn_test('Minus', '-')
    singl_eltkn_test('Arrow', '->')
    singl_eltkn_test('EOC', '\0')
    singl_eltkn_test('EOC', '\n')
    singl_eltkn_test('Invalid', '~', {error='E15: Unidentified character: %.*s'})

    local pstate = new_pstate({{data=nil, size=0}})
    eq({len=0, error='start.col >= #pstr', start={col=0, line=0}, type='EOC'},
       next_eltkn(pstate))

    local pstate = new_pstate({''})
    eq({len=0, error='start.col >= #pstr', start={col=0, line=0}, type='EOC'},
       next_eltkn(pstate))
  end)
end)
