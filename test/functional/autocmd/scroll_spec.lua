local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local funcs = helpers.funcs
local source = helpers.source

describe('Scroll', function()
  before_each(clear)

  it('is triggered by scrolling the window', function()
    source([[
    let g:scroll = 0
    let g:buf = bufnr('%')

    autocmd scroll * let g:scroll += 1

    call nvim_buf_set_lines(g:buf, 0, -1, v:true, ['1', '2', '3', '4', '5'])
    call feedkeys("\<C-e>", "n")
    ]])
    eq(1, eval('g:scroll'))
  end)
end)
