local t = require('test.functional.testutil')()

local clear = t.clear
local eq = t.eq
local eval = t.eval
local source = t.source
local request = t.request

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
