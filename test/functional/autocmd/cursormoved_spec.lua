local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local eval = n.eval
local api = n.api
local source = n.source
local command = n.command

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
    eq({ 'BufEnter2', 'CursorMoved2' }, eval('g:log'))
    command('wincmd w')
    eq({ 'BufEnter2', 'CursorMoved2', 'BufEnter1', 'CursorMoved1' }, eval('g:log'))
  end)

  it('is not triggered by temporarily switching window', function()
    source([[
      let g:cursormoved = 0
      vnew
      autocmd CursorMoved * let g:cursormoved += 1
    ]])
    command('wincmd w | wincmd p')
    eq(0, eval('g:cursormoved'))
  end)

  it("is not triggered by functions that don't change the window", function()
    source([[
      let g:cursormoved = 0
      let g:buf = bufnr('%')
      vsplit foo
      autocmd CursorMoved * let g:cursormoved += 1
    ]])
    api.nvim_buf_set_lines(eval('g:buf'), 0, -1, true, { 'aaa' })
    eq(0, eval('g:cursormoved'))
    eq({ 'aaa' }, api.nvim_buf_get_lines(eval('g:buf'), 0, -1, true))
    eq(0, eval('g:cursormoved'))
  end)

  it('is not triggered by cursor movement prior to first CursorMoved instantiation', function()
    source([[
      let g:cursormoved = 0
      autocmd! CursorMoved
      autocmd CursorMoved * let g:cursormoved += 1
    ]])
    eq(0, eval('g:cursormoved'))
  end)
end)
