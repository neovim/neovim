local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local eval = n.eval
local source = n.source
local request = n.request

describe('BufModified', function()
  before_each(clear)

  it('is triggered when modified and un-modified', function()
    source([[
    let g:modified = 0
    autocmd BufModifiedSet * let g:modified += 1
    ]])
    request('nvim_command', [[normal! aa\<Esc>]])
    eq(1, eval('g:modified'))
    request('nvim_command', [[normal! u]])
    eq(2, eval('g:modified'))
  end)
end)
