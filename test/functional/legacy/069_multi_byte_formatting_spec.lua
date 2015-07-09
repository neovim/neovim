-- Test for multi-byte text formatting.
-- Also test, that 'mps' with multibyte chars works.
-- And test "ra" on multi-byte characters.
-- Also test byteidx() and byteidxcomp()

local helpers = require('test.functional.helpers')
local feed, insert = helpers.feed, helpers.insert
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('multi byte text', function()
  before_each(clear)

  it('formatting with "set fo=t"', function()
    insert([[
      {
      ＸＹＺ
      abc ＸＹＺ
      }]])
    execute('/^{/+1')
    execute('set tw=2 fo=t')
    feed('gqgqjgqgqo<cr>')
    feed('ＸＹＺ<cr>')
    feed('abc ＸＹＺ<esc><esc>')
    expect([[
      {
      ＸＹＺ
      abc
      ＸＹＺ
      
      ＸＹＺ
      abc
      ＸＹＺ
      }]])
  end)

  it('formatting with "set fo=tm"', function()
    insert([[
      {
      Ｘ
      Ｘa
      Ｘ a
      ＸＹ
      Ｘ Ｙ
      }]])
    execute('/^{/+1')
    execute('set tw=1 fo=tm')
    feed('gqgqjgqgqjgqgqjgqgqjgqgqo<cr>')
    feed('Ｘ<cr>')
    feed('Ｘa<cr>')
    feed('Ｘ a<cr>')
    feed('ＸＹ<cr>')
    feed('Ｘ Ｙ<esc><esc>')
    expect([[
      {
      Ｘ
      Ｘ
      a
      Ｘ
      a
      Ｘ
      Ｙ
      Ｘ
      Ｙ
      
      Ｘ
      Ｘ
      a
      Ｘ
      a
      Ｘ
      Ｙ
      Ｘ
      Ｙ
      }]])
  end)

  it('formatting with "set fo=tm" (part 2)', function()
    insert([[
      {
      Ｘ
      Ｘa
      Ｘ a
      ＸＹ
      Ｘ Ｙ
      aＸ
      abＸ
      abcＸ
      abＸ c
      abＸＹ
      }]])
    execute('/^{/+1')
    execute('set tw=2 fo=tm')
    feed('gqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqo<cr>')
    feed('Ｘ<cr>')
    feed('Ｘa<cr>')
    feed('Ｘ a<cr>')
    feed('ＸＹ<cr>')
    feed('Ｘ Ｙ<cr>')
    feed('aＸ<cr>')
    feed('abＸ<cr>')
    feed('abcＸ<cr>')
    feed('abＸ c<cr>')
    feed('abＸＹ<esc><esc>')
    expect([[
      {
      Ｘ
      Ｘ
      a
      Ｘ
      a
      Ｘ
      Ｙ
      Ｘ
      Ｙ
      a
      Ｘ
      ab
      Ｘ
      abc
      Ｘ
      ab
      Ｘ
      c
      ab
      Ｘ
      Ｙ
      
      Ｘ
      Ｘ
      a
      Ｘ
      a
      Ｘ
      Ｙ
      Ｘ
      Ｙ
      a
      Ｘ
      ab
      Ｘ
      abc
      Ｘ
      ab
      Ｘ
      c
      ab
      Ｘ
      Ｙ
      }]])
  end)

  it('formatting with "set ai fo=tm"', function()
    insert([[
      {
        Ｘ
        Ｘa
      }]])
    execute('/^{/+1')
    execute('set ai tw=2 fo=tm')
    feed('gqgqjgqgqo<cr>')
    feed('Ｘ<cr>')
    feed('Ｘa<esc>')
    expect([[
      {
        Ｘ
        Ｘ
        a
      
        Ｘ
        Ｘ
        a
      }]])
  end)

  it('formatting with "set ai fo=tm" (part 2)', function()
    insert([[
      {
        Ｘ
        Ｘa
      }]])
    execute('/^{/+1')
    execute('set noai tw=2 fo=tm')
    feed('gqgqjgqgqo<cr>')
    -- Literal spaces will be trimmed from the by feed().
    feed('<space><space>Ｘ<cr>')
    feed('<space><space>Ｘa<esc>')
    expect([[
      {
        Ｘ
        Ｘ
      a
      
        Ｘ
        Ｘ
      a
      }]])
  end)

  it('formatting with "set fo=cqm" and multi byte comments', function()
    insert([[
      {
      Ｘ
      Ｘa
      ＸaＹ
      ＸＹ
      ＸＹＺ
      Ｘ Ｙ
      Ｘ ＹＺ
      ＸＸ
      ＸＸa
      ＸＸＹ
      }]])
    execute('/^{/+1')
    execute('set tw=2 fo=cqm comments=n:Ｘ')
    feed('gqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqo<cr>')
    feed('Ｘ<cr>')
    feed('Ｘa<cr>')
    feed('ＸaＹ<cr>')
    feed('ＸＹ<cr>')
    feed('ＸＹＺ<cr>')
    feed('Ｘ Ｙ<cr>')
    feed('Ｘ ＹＺ<cr>')
    feed('ＸＸ<cr>')
    feed('ＸＸa<cr>')
    feed('ＸＸＹ<esc><esc>')
    expect([[
      {
      Ｘ
      Ｘa
      Ｘa
      ＸＹ
      ＸＹ
      ＸＹ
      ＸＺ
      Ｘ Ｙ
      Ｘ Ｙ
      Ｘ Ｚ
      ＸＸ
      ＸＸa
      ＸＸＹ
      
      Ｘ
      Ｘa
      Ｘa
      ＸＹ
      ＸＹ
      ＸＹ
      ＸＺ
      Ｘ Ｙ
      Ｘ Ｙ
      Ｘ Ｚ
      ＸＸ
      ＸＸa
      ＸＸＹ
      }]])
  end)

  it('formatting in replace mode', function()
    insert([[
      {
      
      }]])
    execute('/^{/+1')
    execute('set tw=2 fo=tm')
    feed('RＸa<esc>')
    expect([[
      {
      Ｘ
      a
      }]])
  end)

  it("as values of 'mps'", function()
    insert([[
      {
      ‘ two three ’ four
      }]])
    execute('/^{/+1')
    execute('set mps+=‘:’')
    feed('d%<cr>')
    expect([[
      {
       four
      }]])
  end)

  it('can be replaced with r', function()
    insert([[
      ａbbａ
      ａａb]])
    feed('gg0Vjra<cr>')
    expect([[
      aaaa
      aaa]])
  end)

  it("doesn't interfere with 'whichwrap'", function()
    insert([[
      á
      x]])
    execute('set whichwrap+=h')
    execute('/^x')
    feed('dh')
    expect([[
      áx]])
  end)

  it('can be querried with byteidx() and byteidxcomp()', function()
    insert([[
      byteidx
      byteidxcomp]])
    -- One char of two bytes.
    execute("let a = '.é.'")
    -- Normal e with composing char.
    execute("let b = '.é.'")
    execute('/^byteidx')
    execute('put =string([byteidx(a, 0), byteidx(a, 1), byteidx(a, 2), byteidx(a, 3), byteidx(a, 4)])')
    execute('put =string([byteidx(b, 0), byteidx(b, 1), byteidx(b, 2), byteidx(b, 3), byteidx(b, 4)])')
    execute('/^byteidxcomp')
    execute('put =string([byteidxcomp(a, 0), byteidxcomp(a, 1), byteidxcomp(a, 2), byteidxcomp(a, 3), byteidxcomp(a, 4)])')
    execute("let b = '.é.'")
    execute('put =string([byteidxcomp(b, 0), byteidxcomp(b, 1), byteidxcomp(b, 2), byteidxcomp(b, 3), byteidxcomp(b, 4), byteidxcomp(b, 5)])')
    expect([=[
      byteidx
      [0, 1, 3, 4, -1]
      [0, 1, 4, 5, -1]
      byteidxcomp
      [0, 1, 3, 4, -1]
      [0, 1, 2, 4, 5, -1]]=])
  end)

  it('correctly interact with the \zs pattern', function()
    insert('substitute')
    execute([[let y = substitute('１２３', '\zs', 'a', 'g') | put =y]])
    expect([[
      substitute
      a１a２a３a]])
  end)
end)
