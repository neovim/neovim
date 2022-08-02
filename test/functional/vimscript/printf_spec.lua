local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local funcs = helpers.funcs
local meths = helpers.meths
local exc_exec = helpers.exc_exec

describe('printf()', function()
  before_each(clear)

  it('works with zero and %b', function()
    eq('0', funcs.printf('%lb', 0))
    eq('0', funcs.printf('%llb', 0))
    eq('0', funcs.printf('%zb', 0))
  end)
  it('works with one and %b', function()
    eq('1', funcs.printf('%b', 1))
    eq('1', funcs.printf('%lb', 1))
    eq('1', funcs.printf('%llb', 1))
    eq('1', funcs.printf('%zb', 1))
  end)
  it('works with 0xff and %b', function()
    eq('11111111', funcs.printf('%b', 0xff))
    eq('11111111', funcs.printf('%lb', 0xff))
    eq('11111111', funcs.printf('%llb', 0xff))
    eq('11111111', funcs.printf('%zb', 0xff))
  end)
  it('accepts width modifier with %b', function()
    eq('  1', funcs.printf('%3b', 1))
  end)
  it('accepts prefix modifier with %b', function()
    eq('0b1', funcs.printf('%#b', 1))
  end)
  it('writes capital B with %B', function()
    eq('0B1', funcs.printf('%#B', 1))
  end)
  it('accepts prefix, zero-fill and width modifiers with %b', function()
    eq('0b001', funcs.printf('%#05b', 1))
  end)
  it('accepts prefix and width modifiers with %b', function()
    eq('  0b1', funcs.printf('%#5b', 1))
  end)
  it('does not write prefix for zero with prefix and width modifier used with %b', function()
    eq('    0', funcs.printf('%#5b', 0))
  end)
  it('accepts precision modifier with %b', function()
    eq('00000', funcs.printf('%.5b', 0))
  end)
  it('accepts all modifiers with %b at once', function()
    -- zero-fill modifier is ignored when used with left-align
    -- force-sign and add-blank are ignored
    -- use-grouping-characters modifier is ignored always
    eq('0b00011   ', funcs.printf('% \'+#0-10.5b', 3))
  end)
  it('errors out when %b modifier is used for a list', function()
    eq('Vim(call):E745: Using a List as a Number', exc_exec('call printf("%b", [])'))
  end)
  it('errors out when %b modifier is used for a float', function()
    eq('Vim(call):E805: Using a Float as a Number', exc_exec('call printf("%b", 3.1415926535)'))
  end)
  it('works with %p correctly', function()
    local null_ret = nil
    local seen_rets = {}
    -- Collect all args in an array to avoid possible allocation of the same
    -- address after freeing unreferenced values.
    meths.set_var('__args', {})
    local function check_printf(expr, is_null)
      eq(0, exc_exec('call add(__args, ' .. expr .. ')'))
      eq(0, exc_exec('let __result = printf("%p", __args[-1])'))
      local id_ret = eval('id(__args[-1])')
      eq(id_ret, meths.get_var('__result'))
      if is_null then
        if null_ret then
          eq(null_ret, id_ret)
        else
          null_ret = id_ret
        end
      else
        eq(nil, seen_rets[id_ret])
        seen_rets[id_ret] = expr
      end
      meths.del_var('__result')
    end
    check_printf('v:_null_list', true)
    check_printf('v:_null_dict', true)
    check_printf('[]')
    check_printf('{}')
    check_printf('function("tr", ["a"])')
  end)
end)
