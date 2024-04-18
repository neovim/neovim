-- Tests for Unicode manipulations

local t = require('test.functional.testutil')()
local clear, feed, insert = t.clear, t.feed, t.insert
local command, expect = t.command, t.expect
local eq, eval = t.eq, t.eval
local source = t.source
local poke_eventloop = t.poke_eventloop

describe('utf8', function()
  before_each(clear)

  it('is working', function()
    insert('start:')

    command('new')
    command('call setline(1, ["aaa", "あああ", "bbb"])')

    -- Visual block Insert adjusts for multi-byte char
    feed('gg0l<C-V>jjIx<Esc>')
    poke_eventloop()

    command('let r = getline(1, "$")')
    command('bwipeout!')
    command('$put=r')
    command('call garbagecollect(1)')

    expect([[
      start:
      axaa
       xあああ
      bxbb]])
  end)

  it('strchars()', function()
    eq(1, eval('strchars("a")'))
    eq(1, eval('strchars("a", 0)'))
    eq(1, eval('strchars("a", 1)'))

    eq(3, eval('strchars("あいa")'))
    eq(3, eval('strchars("あいa", 0)'))
    eq(3, eval('strchars("あいa", 1)'))

    eq(2, eval('strchars("A\\u20dd")'))
    eq(2, eval('strchars("A\\u20dd", 0)'))
    eq(1, eval('strchars("A\\u20dd", 1)'))

    eq(3, eval('strchars("A\\u20dd\\u20dd")'))
    eq(3, eval('strchars("A\\u20dd\\u20dd", 0)'))
    eq(1, eval('strchars("A\\u20dd\\u20dd", 1)'))

    eq(1, eval('strchars("\\u20dd")'))
    eq(1, eval('strchars("\\u20dd", 0)'))
    eq(1, eval('strchars("\\u20dd", 1)'))
  end)

  -- luacheck: ignore 613 (Trailing whitespace in a string)
  it('customlist completion', function()
    source([[
      function! CustomComplete1(lead, line, pos)
        return ['あ', 'い']
      endfunction
      command -nargs=1 -complete=customlist,CustomComplete1 Test1 echo]])
    feed(":Test1 <C-L>'<C-B>$put='<CR>")

    source([[
      function! CustomComplete2(lead, line, pos)
        return ['あたし', 'あたま', 'あたりめ']
      endfunction
      command -nargs=1 -complete=customlist,CustomComplete2 Test2 echo]])
    feed(":Test2 <C-L>'<C-B>$put='<CR>")

    source([[
      function! CustomComplete3(lead, line, pos)
        return ['Nこ', 'Nん', 'Nぶ']
      endfunction
      command -nargs=1 -complete=customlist,CustomComplete3 Test3 echo]])
    feed(":Test3 <C-L>'<C-B>$put='<CR>")

    expect([[

      Test1 
      Test2 あた
      Test3 N]])
  end)
end)
