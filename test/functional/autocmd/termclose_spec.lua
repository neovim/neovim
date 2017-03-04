local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear, execute, feed, nvim, nvim_dir = helpers.clear,
helpers.execute, helpers.feed, helpers.nvim, helpers.nvim_dir
local eval, eq = helpers.eval, helpers.eq

if helpers.pending_win32(pending) then return end

describe('TermClose event', function()
  local screen
  before_each(function()
    clear()
    nvim('set_option', 'shell', nvim_dir .. '/shell-test')
    nvim('set_option', 'shellcmdflag', 'EXE')
    screen = Screen.new(20, 4)
    screen:attach({rgb=false})
  end)

  it('works as expected', function()
    execute('autocmd TermClose * echomsg "TermClose works!"')
    execute('terminal')
    screen:expect([[
      ^ready $             |
      [Process exited 0]  |
                          |
      TermClose works!    |
    ]])
  end)

  it('reports the correct <abuf>', function()
    execute('set hidden')
    execute('autocmd TermClose * let g:abuf = expand("<abuf>")')
    execute('edit foo')
    execute('edit bar')
    eq(2, eval('bufnr("%")'))
    execute('terminal')
    feed('<c-\\><c-n>')
    eq(3, eval('bufnr("%")'))
    execute('buffer 1')
    eq(1, eval('bufnr("%")'))
    execute('3bdelete!')
    eq('3', eval('g:abuf'))
  end)
end)
