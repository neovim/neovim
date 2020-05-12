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

  it("is not triggered by functions that don't change the window", function()
    source([[
    let g:cursormoved = 0
    let g:buf = bufnr('%')
    vsplit foo
    autocmd CursorMoved * let g:cursormoved += 1
    call nvim_buf_set_lines(g:buf, 0, -1, v:true, ['aaa'])
    ]])
    eq({'aaa'}, funcs.nvim_buf_get_lines(eval('g:buf'), 0, -1, true))
    eq(0, eval('g:cursormoved'))
  end)
end)
