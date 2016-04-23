-- Tests for Unicode manipulations

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect
local eq, eval = helpers.eq, helpers.eval
local source = helpers.source

describe('utf8', function()
  before_each(clear)

  it('is working', function()
    insert('start:')

    execute('new')
    execute('call setline(1, ["aaa", "あああ", "bbb"])')

    -- Visual block Insert adjusts for multi-byte char
    feed('gg0l<C-V>jjIx<Esc>')

    execute('let r = getline(1, "$")')
    execute('bwipeout!')
    execute('$put=r')
    execute('call garbagecollect(1)')

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
