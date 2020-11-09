local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local funcs = helpers.funcs
local source = helpers.source

describe('CursorMoved', function()
  before_each(clear)

  it('is triggered by changing windows', function()
    source([[
    let g:cursormoved = 0
    vsplit
    autocmd CursorMoved * let g:cursormoved += 1
    wincmd w
    wincmd w
    ]])
    eq(2, eval('g:cursormoved'))
  end)

  it("is triggered when changed from a non-current window", function()
    source([[
    let g:cursormoved = 0
    let g:buf = bufnr('%')
    let g:win = win_getid()
    vsplit foo
    autocmd CursorMoved * let g:cursormoved += 1
    call nvim_buf_set_lines(g:buf, 0, -1, v:true, ['a', 'b', 'c'])
    call nvim_win_set_cursor(g:win, [3, 0])
    ]])
    eq({'a', 'b', 'c'}, funcs.nvim_buf_get_lines(eval('g:buf'), 0, -1, true))
    eq(1, eval('g:cursormoved'))
  end)
end)
