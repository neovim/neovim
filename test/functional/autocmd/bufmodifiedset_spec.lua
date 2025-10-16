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

  it('triggers BufModifiedSet when writes non-current buffer #32817', function()
    source([[
    let g:modified = 0
    let g:second_trigger_buf = 0
    autocmd BufModifiedSet * let g:modified += 1 | if g:modified == 2 | let g:second_trigger_buf = str2nr(expand('<abuf>')) | endif
    ]])
    request('nvim_command', [[edit test_a | badd test_b]])
    request('nvim_command', [[normal! aa\<Esc>]])
    request('nvim_command', [[let g:buf_a = bufnr()]])
    request('nvim_command', [[bn]])
    request('nvim_command', [[wa]])
    os.remove('test_a')
    eq({ 2, true }, { eval('g:modified'), eval('g:buf_a') == eval('g:second_trigger_buf') })
  end)

  it('should not crash', function()
    source([[
    file Xtest_a
    call setline(1, 'foo')
    autocmd BufModifiedSet * bwipe!
    write
    ]])
    n.assert_alive()
    os.remove('Xtest_a')
  end)
end)
