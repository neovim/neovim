local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local funcs = helpers.funcs
local source = helpers.source

describe('WinScrolled', function()
  before_each(clear)

  it('is triggered by scrolling in normal/visual mode', function()
    source([[
    let width = winwidth(0)
    let lines = [repeat('*', range(width * 2))]
    call nvim_buf_set_lines(g:buf, 0, -1, v:true, lines)

    let g:scrolled = 0
    autocmd WinScrolled * let g:scrolled += 1
    normal! zl
    normal! <C-e>
    ]])
    eq(1, eval('g:scrolled'))
  end)

  it('is triggered when the window scrolls in insert mode', function()
    source([[
    let height = winheight(0)
    let lines = map(range(height * 2), {_, i -> string(i)})
    call nvim_buf_set_lines(g:buf, 0, -1, v:true, lines)

    let g:scrolled = 0
    autocmd WinScrolled * let g:scrolled += 1
    call feedkeys("LA\<CR><Esc>", "n")
    ]])
    eq(1, eval('g:scrolled'))
  end)

  it('is triggered when the window is resized', function()
    source([[
    let g:scrolled = 0
    autocmd WinScrolled * let g:scrolled += 1
    wincmd v
    ]])
    eq(1, eval('g:scrolled'))
  end)
end)
