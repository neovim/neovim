local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local source = helpers.source
local request = helpers.request

describe('WinScrolled', function()
  before_each(clear)

  it('is triggered by scrolling vertically', function()
    source([[
    set nowrap
    let width = winwidth(0)
    let line = '123' . repeat('*', width * 2)
    let lines = [line, line]
    call nvim_buf_set_lines(0, 0, -1, v:true, lines)

    let g:scrolled = 0
    autocmd WinScrolled * let g:scrolled += 1
    execute "normal! \<C-e>"
    ]])
    eq(1, eval('g:scrolled'))
  end)

  it('is triggered by scrolling horizontally', function()
    source([[
    set nowrap
    let width = winwidth(0)
    let line = '123' . repeat('*', width * 2)
    let lines = [line, line]
    call nvim_buf_set_lines(0, 0, -1, v:true, lines)

    let g:scrolled = 0
    autocmd WinScrolled * let g:scrolled += 1
    execute "normal! zl"
    ]])
    eq(1, eval('g:scrolled'))
  end)

  it('is triggered when the window scrolls in insert mode', function()
    source([[
    let height = winheight(0)
    let lines = map(range(height * 2), {_, i -> string(i)})
    call nvim_buf_set_lines(0, 0, -1, v:true, lines)

    let g:scrolled = 0
    autocmd WinScrolled * let g:scrolled += 1
    call feedkeys("LA\<CR><Esc>", "n")
    ]])
    eq(2, eval('g:scrolled'))
  end)

  it('is triggered when the window is resized', function()
    source([[
    let g:scrolled = 0
    autocmd WinScrolled * let g:scrolled += 1
    wincmd v
    ]])
    eq(1, eval('g:scrolled'))
  end)

  it('is triggered through nvim_win_set(width|height)', function()
    source([[
    let g:scrolled = 0
    vsplit foo
    split bar
    autocmd WinScrolled <buffer> let g:scrolled += 1
    wincmd w
    ]])
    request('nvim_win_set_width', 0, eval('winwidth(0) - 1'))
    eq(1, eval('g:scrolled'))
    request('nvim_win_set_height', 0, eval('winheight(0) - 1'))
    eq(2, eval('g:scrolled'))
  end)
end)
