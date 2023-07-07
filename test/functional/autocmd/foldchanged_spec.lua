local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local eval = helpers.eval
local exec = helpers.exec
local feed = helpers.feed

before_each(helpers.clear)

describe('FoldChanged', function()
  it('works', function()
    exec([[
      set foldmethod=indent
      set shiftwidth=1
      call setline(1, ['111', ' 222', '  333'])

      let g:foldchanged = 0
      au FoldChanged * let g:foldchanged += 1
      au FoldChanged * let g:amatch = str2nr(expand('<amatch>'))
      au FoldChanged * let g:afile = str2nr(expand('<afile>'))
    ]])
    eq(0, eval('g:foldchanged'))

    feed('zM')
    eq(1, eval('g:foldchanged'))

    feed('zR')
    eq(2, eval('g:foldchanged'))
  end)
end)
