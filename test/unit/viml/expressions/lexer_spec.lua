local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)
local viml_helpers = require('test.unit.viml.helpers')

local child_call_once = helpers.child_call_once
local conv_enum = helpers.conv_enum
local cimport = helpers.cimport
local ffi = helpers.ffi
local eq = helpers.eq
local shallowcopy = helpers.shallowcopy
local intchar2lua = helpers.intchar2lua

local conv_ccs = viml_helpers.conv_ccs
local new_pstate = viml_helpers.new_pstate
local conv_cmp_type = viml_helpers.conv_cmp_type
local pstate_set_str = viml_helpers.pstate_set_str
local conv_expr_asgn_type = viml_helpers.conv_expr_asgn_type

local lib = cimport('./src/nvim/viml/parser/expressions.h')

local eltkn_type_tab, eltkn_mul_type_tab, eltkn_opt_scope_tab
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

    [tonumber(lib.kExprLexAssignment)] = 'Assignment',
  }

  eltkn_mul_type_tab = {
    [tonumber(lib.kExprLexMulMul)] = 'Mul',
    [tonumber(lib.kExprLexMulDiv)] = 'Div',
    [tonumber(lib.kExprLexMulMod)] = 'Mod',
  }

  eltkn_opt_scope_tab = {
    [tonumber(lib.kExprOptScopeUnspecified)] = 'Unspecified',
    [tonumber(lib.kExprOptScopeGlobal)] = 'Global',
    [tonumber(lib.kExprOptScopeLocal)] = 'Local',
  }
end)

local function conv_eltkn_type(typ)
  return conv_enum(eltkn_type_tab, typ)
end

local bracket_types = {
  Bracket = true,
  FigureBrace = true,
  Parenthesis = true,
}

local function eltkn2lua(pstate, tkn)
  local ret = {
    type = conv_eltkn_type(tkn.type),
  }
  pstate_set_str(pstate, tkn.start, tkn.len, ret)
  if not ret.error and (#(ret.str) ~= ret.len) then
    ret.error = '#str /= len'
  end
  if ret.type == 'Comparison' then
    ret.data = {
      type = conv_cmp_type(tkn.data.cmp.type),
      ccs = conv_ccs(tkn.data.cmp.ccs),
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
  elseif ret.type == 'Number' then
    ret.data = {
      is_float = (not not tkn.data.num.is_float),
      base = tonumber(tkn.data.num.base),
    }
    ret.data.val = tonumber(tkn.data.num.is_float
                            and tkn.data.num.val.floating
                            or tkn.data.num.val.integer)
  elseif ret.type == 'Assignment' then
    ret.data = { type = conv_expr_asgn_type(tkn.data.ass.type) }
  elseif ret.type == 'Invalid' then
    ret.data = { error = ffi.string(tkn.data.err.msg) }
  end
  return ret, tkn
end

local function next_eltkn(pstate, flags)
  return eltkn2lua(pstate, lib.viml_pexpr_next_token(pstate, flags))
end

describe('Expressions lexer', function()
  local flags = 0
  local should_advance = true
  local function check_advance(pstate, bytes_to_advance, initial_col)
    local tgt = initial_col + bytes_to_advance
    if should_advance then
      if pstate.reader.lines.items[0].size == tgt then
        eq(1, pstate.pos.line)
        eq(0, pstate.pos.col)
      else
        eq(0, pstate.pos.line)
        eq(tgt, pstate.pos.col)
      end
    else
      eq(0, pstate.pos.line)
      eq(initial_col, pstate.pos.col)
    end
  end
  local function singl_eltkn_test(typ, str, data)
    local pstate = new_pstate({str})
    eq({data=data, len=#str, start={col=0, line=0}, str=str, type=typ},
       next_eltkn(pstate, flags))
    check_advance(pstate, #str, 0)
    if not (
        typ == 'Spacing'
        or (typ == 'Register' and str == '@')
        or ((typ == 'SingleQuotedString' or typ == 'DoubleQuotedString')
            and not data.closed)
    ) then
      pstate = new_pstate({str .. ' '})
      eq({data=data, len=#str, start={col=0, line=0}, str=str, type=typ},
         next_eltkn(pstate, flags))
      check_advance(pstate, #str, 0)
    end
    pstate = new_pstate({'x' .. str})
    pstate.pos.col = 1
    eq({data=data, len=#str, start={col=1, line=0}, str=str, type=typ},
       next_eltkn(pstate, flags))
    check_advance(pstate, #str, 1)
  end
  local function scope_test(scope)
    singl_eltkn_test('PlainIdentifier', scope .. ':test#var', {autoload=true, scope=scope})
    singl_eltkn_test('PlainIdentifier', scope .. ':', {autoload=false, scope=scope})
  end
  local function comparison_test(op, inv_op, cmp_type)
    singl_eltkn_test('Comparison', op, {type=cmp_type, inv=false, ccs='UseOption'})
    singl_eltkn_test('Comparison', inv_op, {type=cmp_type, inv=true, ccs='UseOption'})
    singl_eltkn_test('Comparison', op .. '#', {type=cmp_type, inv=false, ccs='MatchCase'})
    singl_eltkn_test('Comparison', inv_op .. '#', {type=cmp_type, inv=true, ccs='MatchCase'})
    singl_eltkn_test('Comparison', op .. '?', {type=cmp_type, inv=false, ccs='IgnoreCase'})
    singl_eltkn_test('Comparison', inv_op .. '?', {type=cmp_type, inv=true, ccs='IgnoreCase'})
  end
  local function simple_test(pstate_arg, exp_type, exp_len, exp)
    local pstate = new_pstate(pstate_arg)
    exp = shallowcopy(exp)
    exp.type = exp_type
    exp.len = exp_len or #(pstate_arg[0])
    exp.start = { col = 0, line = 0 }
    eq(exp, next_eltkn(pstate, flags))
  end
  local function stable_tests()
    singl_eltkn_test('Parenthesis', '(', {closing=false})
    singl_eltkn_test('Parenthesis', ')', {closing=true})
    singl_eltkn_test('Bracket', '[', {closing=false})
    singl_eltkn_test('Bracket', ']', {closing=true})
    singl_eltkn_test('FigureBrace', '{', {closing=false})
    singl_eltkn_test('FigureBrace', '}', {closing=true})
    singl_eltkn_test('Question', '?')
    singl_eltkn_test('Colon', ':')
    singl_eltkn_test('Dot', '.')
    singl_eltkn_test('Assignment', '.=', {type='Concat'})
    singl_eltkn_test('Plus', '+')
    singl_eltkn_test('Assignment', '+=', {type='Add'})
    singl_eltkn_test('Comma', ',')
    singl_eltkn_test('Multiplication', '*', {type='Mul'})
    singl_eltkn_test('Multiplication', '/', {type='Div'})
    singl_eltkn_test('Multiplication', '%', {type='Mod'})
    singl_eltkn_test('Spacing', '  \t\t  \t\t')
    singl_eltkn_test('Spacing', ' ')
    singl_eltkn_test('Spacing', '\t')
    singl_eltkn_test('Invalid', '\x01\x02\x03', {error='E15: Invalid control character present in input: %.*s'})
    singl_eltkn_test('Number', '0123', {is_float=false, base=8, val=83})
    singl_eltkn_test('Number', '01234567', {is_float=false, base=8, val=342391})
    singl_eltkn_test('Number', '012345678', {is_float=false, base=10, val=12345678})
    singl_eltkn_test('Number', '0x123', {is_float=false, base=16, val=291})
    singl_eltkn_test('Number', '0x56FF', {is_float=false, base=16, val=22271})
    singl_eltkn_test('Number', '0xabcdef', {is_float=false, base=16, val=11259375})
    singl_eltkn_test('Number', '0xABCDEF', {is_float=false, base=16, val=11259375})
    singl_eltkn_test('Number', '0x0', {is_float=false, base=16, val=0})
    singl_eltkn_test('Number', '00', {is_float=false, base=8, val=0})
    singl_eltkn_test('Number', '0b0', {is_float=false, base=2, val=0})
    singl_eltkn_test('Number', '0b010111', {is_float=false, base=2, val=23})
    singl_eltkn_test('Number', '0b100111', {is_float=false, base=2, val=39})
    singl_eltkn_test('Number', '0', {is_float=false, base=10, val=0})
    singl_eltkn_test('Number', '9', {is_float=false, base=10, val=9})
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
    singl_eltkn_test('And', '&&')
    singl_eltkn_test('Or', '||')
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
    singl_eltkn_test('Assignment', '=', {type='Plain'})
    comparison_test('==', '!=', 'Equal')
    comparison_test('=~', '!~', 'Matches')
    comparison_test('>', '<=', 'Greater')
    comparison_test('>=', '<', 'GreaterOrEqual')
    singl_eltkn_test('Minus', '-')
    singl_eltkn_test('Assignment', '-=', {type='Subtract'})
    singl_eltkn_test('Arrow', '->')
    singl_eltkn_test('Invalid', '~', {error='E15: Unidentified character: %.*s'})
    simple_test({{data=nil, size=0}}, 'EOC', 0, {error='start.col >= #pstr'})
    simple_test({''}, 'EOC', 0, {error='start.col >= #pstr'})
    simple_test({'2.'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2e5'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.x'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.2.'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0x'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e+'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e-'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e+x'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e-x'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e+1a'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e-1a'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'0b102'}, 'Number', 4, {data={is_float=false, base=2, val=2}, str='0b10'})
    simple_test({'10F'}, 'Number', 2, {data={is_float=false, base=10, val=10}, str='10'})
    simple_test({'0x0123456789ABCDEFG'}, 'Number', 18, {data={is_float=false, base=16, val=81985529216486895}, str='0x0123456789ABCDEF'})
    simple_test({{data='00', size=2}}, 'Number', 2, {data={is_float=false, base=8, val=0}, str='00'})
    simple_test({{data='009', size=2}}, 'Number', 2, {data={is_float=false, base=8, val=0}, str='00'})
    simple_test({{data='01', size=1}}, 'Number', 1, {data={is_float=false, base=10, val=0}, str='0'})
  end

  local function regular_scope_tests()
    scope_test('s')
    scope_test('g')
    scope_test('v')
    scope_test('b')
    scope_test('w')
    scope_test('t')
    scope_test('l')
    scope_test('a')

    simple_test({'g:'}, 'PlainIdentifier', 2, {data={scope='g', autoload=false}, str='g:'})
    simple_test({'g:is#foo'}, 'PlainIdentifier', 8, {data={scope='g', autoload=true}, str='g:is#foo'})
    simple_test({'g:isnot#foo'}, 'PlainIdentifier', 11, {data={scope='g', autoload=true}, str='g:isnot#foo'})
  end

  local function regular_is_tests()
    comparison_test('is', 'isnot', 'Identical')

    simple_test({'is'}, 'Comparison', 2, {data={type='Identical', inv=false, ccs='UseOption'}, str='is'})
    simple_test({'isnot'}, 'Comparison', 5, {data={type='Identical', inv=true, ccs='UseOption'}, str='isnot'})
    simple_test({'is?'}, 'Comparison', 3, {data={type='Identical', inv=false, ccs='IgnoreCase'}, str='is?'})
    simple_test({'isnot?'}, 'Comparison', 6, {data={type='Identical', inv=true, ccs='IgnoreCase'}, str='isnot?'})
    simple_test({'is#'}, 'Comparison', 3, {data={type='Identical', inv=false, ccs='MatchCase'}, str='is#'})
    simple_test({'isnot#'}, 'Comparison', 6, {data={type='Identical', inv=true, ccs='MatchCase'}, str='isnot#'})
    simple_test({'is#foo'}, 'Comparison', 3, {data={type='Identical', inv=false, ccs='MatchCase'}, str='is#'})
    simple_test({'isnot#foo'}, 'Comparison', 6, {data={type='Identical', inv=true, ccs='MatchCase'}, str='isnot#'})
  end

  local function regular_number_tests()
    simple_test({'2.0'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e5'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e+5'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({'2.0e-5'}, 'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
  end

  local function regular_eoc_tests()
    singl_eltkn_test('EOC', '|')
    singl_eltkn_test('EOC', '\0')
    singl_eltkn_test('EOC', '\n')
  end

  itp('works (single tokens, zero flags)', function()
    stable_tests()

    regular_eoc_tests()
    regular_scope_tests()
    regular_is_tests()
    regular_number_tests()
  end)
  itp('peeks', function()
    flags = tonumber(lib.kELFlagPeek)
    should_advance = false
    stable_tests()

    regular_eoc_tests()
    regular_scope_tests()
    regular_is_tests()
    regular_number_tests()
  end)
  itp('forbids scope', function()
    flags = tonumber(lib.kELFlagForbidScope)
    stable_tests()

    regular_eoc_tests()
    regular_is_tests()
    regular_number_tests()

    simple_test({'g:'}, 'PlainIdentifier', 1, {data={scope=0, autoload=false}, str='g'})
  end)
  itp('allows floats', function()
    flags = tonumber(lib.kELFlagAllowFloat)
    stable_tests()

    regular_eoc_tests()
    regular_scope_tests()
    regular_is_tests()

    simple_test({'2.2'}, 'Number', 3, {data={is_float=true, base=10, val=2.2}, str='2.2'})
    simple_test({'2.0e5'}, 'Number', 5, {data={is_float=true, base=10, val=2e5}, str='2.0e5'})
    simple_test({'2.0e+5'}, 'Number', 6, {data={is_float=true, base=10, val=2e5}, str='2.0e+5'})
    simple_test({'2.0e-5'}, 'Number', 6, {data={is_float=true, base=10, val=2e-5}, str='2.0e-5'})
    simple_test({'2.500000e-5'}, 'Number', 11, {data={is_float=true, base=10, val=2.5e-5}, str='2.500000e-5'})
    simple_test({'2.5555e2'}, 'Number', 8, {data={is_float=true, base=10, val=2.5555e2}, str='2.5555e2'})
    simple_test({'2.5555e+2'}, 'Number', 9, {data={is_float=true, base=10, val=2.5555e2}, str='2.5555e+2'})
    simple_test({'2.5555e-2'}, 'Number', 9, {data={is_float=true, base=10, val=2.5555e-2}, str='2.5555e-2'})
    simple_test({{data='2.5e-5', size=3}},
                'Number', 3, {data={is_float=true, base=10, val=2.5}, str='2.5'})
    simple_test({{data='2.5e5', size=4}},
                'Number', 1, {data={is_float=false, base=10, val=2}, str='2'})
    simple_test({{data='2.5e-50', size=6}},
                'Number', 6, {data={is_float=true, base=10, val=2.5e-5}, str='2.5e-5'})
  end)
  itp('treats `is` as an identifier', function()
    flags = tonumber(lib.kELFlagIsNotCmp)
    stable_tests()

    regular_eoc_tests()
    regular_scope_tests()
    regular_number_tests()

    simple_test({'is'}, 'PlainIdentifier', 2, {data={scope=0, autoload=false}, str='is'})
    simple_test({'isnot'}, 'PlainIdentifier', 5, {data={scope=0, autoload=false}, str='isnot'})
    simple_test({'is?'}, 'PlainIdentifier', 2, {data={scope=0, autoload=false}, str='is'})
    simple_test({'isnot?'}, 'PlainIdentifier', 5, {data={scope=0, autoload=false}, str='isnot'})
    simple_test({'is#'}, 'PlainIdentifier', 3, {data={scope=0, autoload=true}, str='is#'})
    simple_test({'isnot#'}, 'PlainIdentifier', 6, {data={scope=0, autoload=true}, str='isnot#'})
    simple_test({'is#foo'}, 'PlainIdentifier', 6, {data={scope=0, autoload=true}, str='is#foo'})
    simple_test({'isnot#foo'}, 'PlainIdentifier', 9, {data={scope=0, autoload=true}, str='isnot#foo'})
  end)
  itp('forbids EOC', function()
    flags = tonumber(lib.kELFlagForbidEOC)
    stable_tests()

    regular_scope_tests()
    regular_is_tests()
    regular_number_tests()

    singl_eltkn_test('Invalid', '|', {error='E15: Unexpected EOC character: %.*s'})
    singl_eltkn_test('Invalid', '\0', {error='E15: Unexpected EOC character: %.*s'})
    singl_eltkn_test('Invalid', '\n', {error='E15: Unexpected EOC character: %.*s'})
  end)
end)
