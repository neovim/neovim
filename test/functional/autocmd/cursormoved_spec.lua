local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local funcs = helpers.funcs
local source = helpers.source
local command = helpers.command

describe('CursorMoved', function()
  before_each(clear)

  it('is triggered after BufEnter when changing or splitting windows #11878 #12031', function()
    source([[
    call setline(1, 'foo')
    let g:log = []
    autocmd BufEnter * let g:log += ['BufEnter' .. expand("<abuf>")]
    autocmd CursorMoved * let g:log += ['CursorMoved' .. expand("<abuf>")]
    ]])
    eq({}, eval('g:log'))
    command('new')
    eq({'BufEnter2', 'CursorMoved2'}, eval('g:log'))
    command('wincmd w')
    eq({'BufEnter2', 'CursorMoved2', 'BufEnter1', 'CursorMoved1'}, eval('g:log'))
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

  it("is not triggered by cursor movement prior to first CursorMoved instantiation", function()
    source([[
    let g:cursormoved = 0
    autocmd! CursorMoved
    autocmd CursorMoved * let g:cursormoved += 1
    ]])
    eq(0, eval('g:cursormoved'))
  end)
end)
