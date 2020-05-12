-- Test for edit functions
-- See also: src/nvim/testdir/test_edit.vim

local helpers = require('test.functional.helpers')(after_each)
local source = helpers.source
local eq, eval = helpers.eq, helpers.eval
local funcs = helpers.funcs
local clear = helpers.clear

describe('edit', function()
  before_each(clear)

  it('reset insertmode from i_ctrl-r_=', function()
    source([=[
      call setline(1, ['abc'])
      call cursor(1, 4)
      call feedkeys(":set im\<cr>ZZZ\<c-r>=setbufvar(1,'&im', 0)\<cr>",'tnix')
    ]=])
    eq({'abZZZc'}, funcs.getline(1,'$'))
    eq({0, 1, 1, 0}, funcs.getpos('.'))
    eq(0, eval('&im'))
  end)

end)

