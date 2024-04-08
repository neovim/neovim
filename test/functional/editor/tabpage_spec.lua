local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = t.clear
local command = t.command
local eq = t.eq
local neq = t.neq
local feed = t.feed
local eval = t.eval
local exec = t.exec
local fn = t.fn
local api = t.api
local curwin = t.api.nvim_get_current_win
local assert_alive = t.assert_alive

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

  it('no segfault with strange WinClosed autocommand #20290', function()
    pcall(
      exec,
      [[
      set nohidden
      edit Xa
      split Xb
      tab split
      new
      autocmd WinClosed * tabprev | bwipe!
      close
    ]]
    )
    assert_alive()
  end)

  it('nvim_win_close and nvim_win_hide update tabline #20285', function()
    eq(1, #api.nvim_list_tabpages())
    eq({ 1, 1 }, fn.win_screenpos(0))
    local win1 = curwin()

    command('tabnew')
    eq(2, #api.nvim_list_tabpages())
    eq({ 2, 1 }, fn.win_screenpos(0))
    local win2 = curwin()

    api.nvim_win_close(win1, true)
    eq(win2, curwin())
    eq(1, #api.nvim_list_tabpages())
    eq({ 1, 1 }, fn.win_screenpos(0))

    command('tabnew')
    eq(2, #api.nvim_list_tabpages())
    eq({ 2, 1 }, fn.win_screenpos(0))
    local win3 = curwin()

    api.nvim_win_hide(win2)
    eq(win3, curwin())
    eq(1, #api.nvim_list_tabpages())
    eq({ 1, 1 }, fn.win_screenpos(0))
  end)

  it('switching tabpage after setting laststatus=3 #19591', function()
    local screen = Screen.new(40, 8)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue },
      [1] = { bold = true, reverse = true }, -- StatusLine
      [2] = { reverse = true }, -- TabLineFill
      [3] = { bold = true }, -- TabLineSel
      [4] = { background = Screen.colors.LightGrey, underline = true }, -- TabLine
      [5] = { bold = true, foreground = Screen.colors.Magenta },
    })
    screen:attach()

    command('tabnew')
    command('tabprev')
    command('set laststatus=3')
    command('tabnext')
    feed('<C-G>')
    screen:expect([[
      {4: [No Name] }{3: [No Name] }{2:                 }{4:X}|
      ^                                        |
      {0:~                                       }|*4
      {1:[No Name]                               }|
      "[No Name]" --No lines in buffer--      |
    ]])
    command('vnew')
    screen:expect([[
      {4: [No Name] }{3: }{5:2}{3: [No Name] }{2:               }{4:X}|
      ^                    │                   |
      {0:~                   }│{0:~                  }|*4
      {1:[No Name]                               }|
      "[No Name]" --No lines in buffer--      |
    ]])
  end)

  it(':tabmove handles modifiers and addr', function()
    command('tabnew | tabnew | tabnew')
    eq(4, fn.nvim_tabpage_get_number(0))
    command('     silent      :keepalt   :: :::    silent!    -    tabmove')
    eq(3, fn.nvim_tabpage_get_number(0))
    command('     silent      :keepalt   :: :::    silent!    -2    tabmove')
    eq(1, fn.nvim_tabpage_get_number(0))
  end)

  it(':tabs does not overflow IObuff with long path with comma #20850', function()
    api.nvim_buf_set_name(0, ('x'):rep(1024) .. ',' .. ('x'):rep(1024))
    command('tabs')
    assert_alive()
  end)
end)
