local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec = n.exec
local assert_alive = n.assert_alive
local fn = n.fn
local eq = t.eq

describe('registers', function()
  before_each(clear)

  -- oldtest: Test_register_cursor_column_negative()
  it('no negative column when pasting', function()
    exec([[
      f XREGISTER
      call setline(1, 'abcdef a')
      call setreg("a", "\n", 'c')
      call cursor(1, 7)
      call feedkeys("i\<C-R>\<C-P>azyx$#\<esc>", 't')
    ]])
    assert_alive()
    eq('XREGISTER', fn.bufname())
  end)
end)
