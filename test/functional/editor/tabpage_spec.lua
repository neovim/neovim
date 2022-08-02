local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local neq = helpers.neq
local feed = helpers.feed
local eval = helpers.eval
local exec = helpers.exec
local funcs = helpers.funcs

describe('tabpage', function()
  before_each(clear)

  it('advances to the next page via <C-W>gt', function()
    -- add some tabpages
    command('tabnew')
    command('tabnew')
    command('tabnew')

    eq(4, eval('tabpagenr()'))

    feed('<C-W>gt')

    eq(1, eval('tabpagenr()'))
  end)

  it('retreats to the previous page via <C-W>gT', function()
    -- add some tabpages
    command('tabnew')
    command('tabnew')
    command('tabnew')

    eq(4, eval('tabpagenr()'))

    feed('<C-W>gT')

    eq(3, eval('tabpagenr()'))
  end)

  it('does not crash or loop 999 times if BufWipeout autocommand switches window #17868', function()
    exec([[
      tabedit
      let s:window_id = win_getid()
      botright new
      setlocal bufhidden=wipe
      let g:win_closed = 0
      autocmd WinClosed * let g:win_closed += 1
      autocmd BufWipeout <buffer> call win_gotoid(s:window_id)
      tabprevious
      +tabclose
    ]])
    neq(999, eval('g:win_closed'))
  end)

  it(":tabmove handles modifiers and addr", function()
    command('tabnew | tabnew | tabnew')
    eq(4, funcs.nvim_tabpage_get_number(0))
    command('     silent      :keepalt   :: :::    silent!    -    tabmove')
    eq(3, funcs.nvim_tabpage_get_number(0))
    command('     silent      :keepalt   :: :::    silent!    -2    tabmove')
    eq(1, funcs.nvim_tabpage_get_number(0))
  end)
end)
