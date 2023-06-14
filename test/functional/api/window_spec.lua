local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, nvim, curbuf, curbuf_contents, window, curwin, eq, neq,
  ok, feed, insert, eval, tabpage = helpers.clear, helpers.nvim, helpers.curbuf,
  helpers.curbuf_contents, helpers.window, helpers.curwin, helpers.eq,
  helpers.neq, helpers.ok, helpers.feed, helpers.insert, helpers.eval,
  helpers.tabpage
local poke_eventloop = helpers.poke_eventloop
local curwinmeths = helpers.curwinmeths
local exec = helpers.exec
local funcs = helpers.funcs
local request = helpers.request
local NIL = helpers.NIL
local meths = helpers.meths
local command = helpers.command
local pcall_err = helpers.pcall_err
local assert_alive = helpers.assert_alive

describe('API/win', function()
  before_each(clear)

  describe('get_buf', function()
    it('works', function()
      eq(curbuf(), window('get_buf', nvim('list_wins')[1]))
      nvim('command', 'new')
      nvim('set_current_win', nvim('list_wins')[2])
      eq(curbuf(), window('get_buf', nvim('list_wins')[2]))
      neq(window('get_buf', nvim('list_wins')[1]),
        window('get_buf', nvim('list_wins')[2]))
    end)
  end)

  describe('set_buf', function()
    it('works', function()
      nvim('command', 'new')
      local windows = nvim('list_wins')
      neq(window('get_buf', windows[2]), window('get_buf', windows[1]))
      window('set_buf', windows[2], window('get_buf', windows[1]))
      eq(window('get_buf', windows[2]), window('get_buf', windows[1]))
    end)

    it('validates args', function()
      eq('Invalid buffer id: 23', pcall_err(window, 'set_buf', nvim('get_current_win'), 23))
      eq('Invalid window id: 23', pcall_err(window, 'set_buf', 23, nvim('get_current_buf')))
    end)
  end)

  describe('{get,set}_cursor', function()
    it('works', function()
      eq({1, 0}, curwin('get_cursor'))
      nvim('command', 'normal ityping\027o  some text')
      eq('typing\n  some text', curbuf_contents())
      eq({2, 10}, curwin('get_cursor'))
      curwin('set_cursor', {2, 6})
      nvim('command', 'normal i dumb')
      eq('typing\n  some dumb text', curbuf_contents())
    end)

    it('does not leak memory when using invalid window ID with invalid pos', function()
      eq('Invalid window id: 1', pcall_err(meths.win_set_cursor, 1, {"b\na"}))
    end)

    it('updates the screen, and also when the window is unfocused', function()
      local screen = Screen.new(30, 9)
      screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue},
        [2] = {bold = true, reverse = true};
        [3] = {reverse = true};
      })
      screen:attach()

      insert("prologue")
      feed('100o<esc>')
      insert("epilogue")
      local win = curwin()
      feed('gg')

      screen:expect{grid=[[
        ^prologue                      |
                                      |
                                      |
                                      |
                                      |
                                      |
                                      |
                                      |
                                      |
      ]]}
      -- cursor position is at beginning
      eq({1, 0}, window('get_cursor', win))

      -- move cursor to end
      window('set_cursor', win, {101, 0})
      screen:expect{grid=[[
                                      |
                                      |
                                      |
                                      |
                                      |
                                      |
                                      |
        ^epilogue                      |
                                      |
      ]]}

      -- move cursor to the beginning again
      window('set_cursor', win, {1, 0})
      screen:expect{grid=[[
        ^prologue                      |
                                      |
                                      |
                                      |
                                      |
                                      |
                                      |
                                      |
                                      |
      ]]}

      -- move focus to new window
      nvim('command',"new")
      neq(win, curwin())

      -- sanity check, cursor position is kept
      eq({1, 0}, window('get_cursor', win))
      screen:expect{grid=[[
        ^                              |
        {1:~                             }|
        {1:~                             }|
        {2:[No Name]                     }|
        prologue                      |
                                      |
                                      |
        {3:[No Name] [+]                 }|
                                      |
      ]]}

      -- move cursor to end
      window('set_cursor', win, {101, 0})
      screen:expect{grid=[[
        ^                              |
        {1:~                             }|
        {1:~                             }|
        {2:[No Name]                     }|
                                      |
                                      |
        epilogue                      |
        {3:[No Name] [+]                 }|
                                      |
      ]]}

      -- move cursor to the beginning again
      window('set_cursor', win, {1, 0})
      screen:expect{grid=[[
        ^                              |
        {1:~                             }|
        {1:~                             }|
        {2:[No Name]                     }|
        prologue                      |
                                      |
                                      |
        {3:[No Name] [+]                 }|
                                      |
      ]]}

      -- curwin didn't change back
      neq(win, curwin())
    end)

    it('remembers what column it wants to be in', function()
      insert("first line")
      feed('o<esc>')
      insert("second line")

      feed('gg')
      poke_eventloop() -- let nvim process the 'gg' command

      -- cursor position is at beginning
      local win = curwin()
      eq({1, 0}, window('get_cursor', win))

      -- move cursor to column 5
      window('set_cursor', win, {1, 5})

      -- move down a line
      feed('j')
      poke_eventloop() -- let nvim process the 'j' command

      -- cursor is still in column 5
      eq({2, 5}, window('get_cursor', win))
    end)

    it('updates cursorline and statusline ruler in non-current window', function()
      local screen = Screen.new(60, 8)
      screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
        [2] = {background = Screen.colors.Grey90},  -- CursorLine
        [3] = {bold = true, reverse = true},  -- StatusLine
        [4] = {reverse = true},  -- StatusLineNC
      })
      screen:attach()
      command('set ruler')
      command('set cursorline')
      insert([[
        aaa
        bbb
        ccc
        ddd]])
      local oldwin = curwin()
      command('vsplit')
      screen:expect([[
        aaa                           │aaa                          |
        bbb                           │bbb                          |
        ccc                           │ccc                          |
        {2:dd^d                           }│{2:ddd                          }|
        {1:~                             }│{1:~                            }|
        {1:~                             }│{1:~                            }|
        {3:[No Name] [+]  4,3         All }{4:[No Name] [+]  4,3        All}|
                                                                    |
      ]])
      window('set_cursor', oldwin, {1, 0})
      screen:expect([[
        aaa                           │{2:aaa                          }|
        bbb                           │bbb                          |
        ccc                           │ccc                          |
        {2:dd^d                           }│ddd                          |
        {1:~                             }│{1:~                            }|
        {1:~                             }│{1:~                            }|
        {3:[No Name] [+]  4,3         All }{4:[No Name] [+]  1,1        All}|
                                                                    |
      ]])
    end)

    it('updates cursorcolumn in non-current window', function()
      local screen = Screen.new(60, 8)
      screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
        [2] = {background = Screen.colors.Grey90},  -- CursorColumn
        [3] = {bold = true, reverse = true},  -- StatusLine
        [4] = {reverse = true},  -- StatusLineNC
      })
      screen:attach()
      command('set cursorcolumn')
      insert([[
        aaa
        bbb
        ccc
        ddd]])
      local oldwin = curwin()
      command('vsplit')
      screen:expect([[
        aa{2:a}                           │aa{2:a}                          |
        bb{2:b}                           │bb{2:b}                          |
        cc{2:c}                           │cc{2:c}                          |
        dd^d                           │ddd                          |
        {1:~                             }│{1:~                            }|
        {1:~                             }│{1:~                            }|
        {3:[No Name] [+]                  }{4:[No Name] [+]                }|
                                                                    |
      ]])
      window('set_cursor', oldwin, {2, 0})
      screen:expect([[
        aa{2:a}                           │{2:a}aa                          |
        bb{2:b}                           │bbb                          |
        cc{2:c}                           │{2:c}cc                          |
        dd^d                           │{2:d}dd                          |
        {1:~                             }│{1:~                            }|
        {1:~                             }│{1:~                            }|
        {3:[No Name] [+]                  }{4:[No Name] [+]                }|
                                                                    |
      ]])
    end)
  end)

  describe('{get,set}_height', function()
    it('works', function()
      nvim('command', 'vsplit')
      eq(window('get_height', nvim('list_wins')[2]),
        window('get_height', nvim('list_wins')[1]))
      nvim('set_current_win', nvim('list_wins')[2])
      nvim('command', 'split')
      eq(window('get_height', nvim('list_wins')[2]),
        math.floor(window('get_height', nvim('list_wins')[1]) / 2))
      window('set_height', nvim('list_wins')[2], 2)
      eq(2, window('get_height', nvim('list_wins')[2]))
    end)

    it('correctly handles height=1', function()
      nvim('command', 'split')
      nvim('set_current_win', nvim('list_wins')[1])
      window('set_height', nvim('list_wins')[2], 1)
      eq(1, window('get_height', nvim('list_wins')[2]))
    end)

    it('correctly handles height=1 with a winbar', function()
      nvim('command', 'set winbar=foobar')
      nvim('command', 'set winminheight=0')
      nvim('command', 'split')
      nvim('set_current_win', nvim('list_wins')[1])
      window('set_height', nvim('list_wins')[2], 1)
      eq(1, window('get_height', nvim('list_wins')[2]))
    end)

    it('do not cause ml_get errors with foldmethod=expr #19989', function()
      insert([[
        aaaaa
        bbbbb
        ccccc]])
      command('set foldmethod=expr')
      exec([[
        new
        let w = nvim_get_current_win()
        wincmd w
        call nvim_win_set_height(w, 5)
      ]])
      feed('l')
      eq('', meths.get_vvar('errmsg'))
    end)
  end)

  describe('{get,set}_width', function()
    it('works', function()
      nvim('command', 'split')
      eq(window('get_width', nvim('list_wins')[2]),
        window('get_width', nvim('list_wins')[1]))
      nvim('set_current_win', nvim('list_wins')[2])
      nvim('command', 'vsplit')
      eq(window('get_width', nvim('list_wins')[2]),
        math.floor(window('get_width', nvim('list_wins')[1]) / 2))
      window('set_width', nvim('list_wins')[2], 2)
      eq(2, window('get_width', nvim('list_wins')[2]))
    end)

    it('do not cause ml_get errors with foldmethod=expr #19989', function()
      insert([[
        aaaaa
        bbbbb
        ccccc]])
      command('set foldmethod=expr')
      exec([[
        vnew
        let w = nvim_get_current_win()
        wincmd w
        call nvim_win_set_width(w, 5)
      ]])
      feed('l')
      eq('', meths.get_vvar('errmsg'))
    end)
  end)

  describe('{get,set,del}_var', function()
    it('works', function()
      curwin('set_var', 'lua', {1, 2, {['3'] = 1}})
      eq({1, 2, {['3'] = 1}}, curwin('get_var', 'lua'))
      eq({1, 2, {['3'] = 1}}, nvim('eval', 'w:lua'))
      eq(1, funcs.exists('w:lua'))
      curwinmeths.del_var('lua')
      eq(0, funcs.exists('w:lua'))
      eq('Key not found: lua', pcall_err(curwinmeths.del_var, 'lua'))
      curwinmeths.set_var('lua', 1)
      command('lockvar w:lua')
      eq('Key is locked: lua', pcall_err(curwinmeths.del_var, 'lua'))
      eq('Key is locked: lua', pcall_err(curwinmeths.set_var, 'lua', 1))
    end)

    it('window_set_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL, request('window_set_var', 0, 'lua', val1))
      eq(val1, request('window_set_var', 0, 'lua', val2))
    end)

    it('window_del_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL,  request('window_set_var', 0, 'lua', val1))
      eq(val1, request('window_set_var', 0, 'lua', val2))
      eq(val2, request('window_del_var', 0, 'lua'))
    end)
  end)

  describe('nvim_get_option_value, nvim_set_option_value', function()
    it('works', function()
      nvim('set_option_value', 'colorcolumn', '4,3', {})
      eq('4,3', nvim('get_option_value', 'colorcolumn', {}))
      command("set modified hidden")
      command("enew") -- edit new buffer, window option is preserved
      eq('4,3', nvim('get_option_value', 'colorcolumn', {}))

      -- global-local option
      nvim('set_option_value', 'statusline', 'window-status', {win=0})
      eq('window-status', nvim('get_option_value', 'statusline', {win=0}))
      eq('', nvim('get_option_value', 'statusline', {scope='global'}))
      command("set modified")
      command("enew") -- global-local: not preserved in new buffer
      -- confirm local value was not copied
      eq('', nvim('get_option_value', 'statusline', {win = 0}))
      eq('', eval('&l:statusline'))
    end)

    it('after switching windows #15390', function()
      nvim('command', 'tabnew')
      local tab1 = unpack(nvim('list_tabpages'))
      local win1 = unpack(tabpage('list_wins', tab1))
      nvim('set_option_value', 'statusline', 'window-status', {win=win1.id})
      nvim('command', 'split')
      nvim('command', 'wincmd J')
      nvim('command', 'wincmd j')
      eq('window-status', nvim('get_option_value', 'statusline', {win = win1.id}))
      assert_alive()
    end)

    it('returns values for unset local options', function()
      eq(-1, nvim('get_option_value', 'scrolloff', {win=0, scope='local'}))
    end)
  end)

  describe('get_position', function()
    it('works', function()
      local height = window('get_height', nvim('list_wins')[1])
      local width = window('get_width', nvim('list_wins')[1])
      nvim('command', 'split')
      nvim('command', 'vsplit')
      eq({0, 0}, window('get_position', nvim('list_wins')[1]))
      local vsplit_pos = math.floor(width / 2)
      local split_pos = math.floor(height / 2)
      local win2row, win2col =
        unpack(window('get_position', nvim('list_wins')[2]))
      local win3row, win3col =
        unpack(window('get_position', nvim('list_wins')[3]))
      eq(0, win2row)
      eq(0, win3col)
      ok(vsplit_pos - 1 <= win2col and win2col <= vsplit_pos + 1)
      ok(split_pos - 1 <= win3row and win3row <= split_pos + 1)
    end)
  end)

  describe('get_position', function()
    it('works', function()
      nvim('command', 'tabnew')
      nvim('command', 'vsplit')
      eq(window('get_tabpage',
        nvim('list_wins')[1]), nvim('list_tabpages')[1])
      eq(window('get_tabpage',
        nvim('list_wins')[2]), nvim('list_tabpages')[2])
      eq(window('get_tabpage',
        nvim('list_wins')[3]), nvim('list_tabpages')[2])
    end)
  end)

  describe('get_number', function()
    it('works', function()
      local wins = nvim('list_wins')
      eq(1, window('get_number', wins[1]))

      nvim('command', 'split')
      local win1, win2 = unpack(nvim('list_wins'))
      eq(1, window('get_number', win1))
      eq(2, window('get_number', win2))

      nvim('command', 'wincmd J')
      eq(2, window('get_number', win1))
      eq(1, window('get_number', win2))

      nvim('command', 'tabnew')
      local win3 = nvim('list_wins')[3]
      -- First tab page
      eq(2, window('get_number', win1))
      eq(1, window('get_number', win2))
      -- Second tab page
      eq(1, window('get_number', win3))
    end)
  end)

  describe('is_valid', function()
    it('works', function()
      nvim('command', 'split')
      local win = nvim('list_wins')[2]
      nvim('set_current_win', win)
      ok(window('is_valid', win))
      nvim('command', 'close')
      ok(not window('is_valid', win))
    end)
  end)

  describe('close', function()
    it('can close current window', function()
      local oldwin = meths.get_current_win()
      command('split')
      local newwin = meths.get_current_win()
      meths.win_close(newwin,false)
      eq({oldwin}, meths.list_wins())
    end)

    it('can close noncurrent window', function()
      local oldwin = meths.get_current_win()
      command('split')
      local newwin = meths.get_current_win()
      meths.win_close(oldwin,false)
      eq({newwin}, meths.list_wins())
    end)

    it("handles changed buffer when 'hidden' is unset", function()
      command('set nohidden')
      local oldwin = meths.get_current_win()
      insert('text')
      command('new')
      local newwin = meths.get_current_win()
      eq("Vim:E37: No write since last change (add ! to override)",
         pcall_err(meths.win_close, oldwin,false))
      eq({newwin,oldwin}, meths.list_wins())
    end)

    it('handles changed buffer with force', function()
      local oldwin = meths.get_current_win()
      insert('text')
      command('new')
      local newwin = meths.get_current_win()
      meths.win_close(oldwin,true)
      eq({newwin}, meths.list_wins())
    end)

    it('in cmdline-window #9767', function()
      command('split')
      eq(2, #meths.list_wins())
      local oldwin = meths.get_current_win()
      -- Open cmdline-window.
      feed('q:')
      eq(3, #meths.list_wins())
      eq(':', funcs.getcmdwintype())
      -- Vim: not allowed to close other windows from cmdline-window.
      eq('E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(meths.win_close, oldwin, true))
      -- Close cmdline-window.
      meths.win_close(0,true)
      eq(2, #meths.list_wins())
      eq('', funcs.getcmdwintype())
    end)

    it('closing current (float) window of another tabpage #15313', function()
      command('tabedit')
      command('botright split')
      local prevwin = curwin().id
      eq(2, eval('tabpagenr()'))
      local win = meths.open_win(0, true, {
        relative='editor', row=10, col=10, width=50, height=10
      })
      local tab = eval('tabpagenr()')
      command('tabprevious')
      eq(1, eval('tabpagenr()'))
      meths.win_close(win, false)

      eq(prevwin, meths.tabpage_get_win(tab).id)
      assert_alive()
    end)
  end)

  describe('hide', function()
    it('can hide current window', function()
      local oldwin = meths.get_current_win()
      command('split')
      local newwin = meths.get_current_win()
      meths.win_hide(newwin)
      eq({oldwin}, meths.list_wins())
    end)
    it('can hide noncurrent window', function()
      local oldwin = meths.get_current_win()
      command('split')
      local newwin = meths.get_current_win()
      meths.win_hide(oldwin)
      eq({newwin}, meths.list_wins())
    end)
    it('does not close the buffer', function()
      local oldwin = meths.get_current_win()
      local oldbuf = meths.get_current_buf()
      local buf = meths.create_buf(true, false)
      local newwin = meths.open_win(buf, true, {
        relative='win', row=3, col=3, width=12, height=3
      })
      meths.win_hide(newwin)
      eq({oldwin}, meths.list_wins())
      eq({oldbuf, buf}, meths.list_bufs())
    end)
    it('deletes the buffer when bufhidden=wipe', function()
      local oldwin = meths.get_current_win()
      local oldbuf = meths.get_current_buf()
      local buf = meths.create_buf(true, false).id
      local newwin = meths.open_win(buf, true, {
        relative='win', row=3, col=3, width=12, height=3
      })
      meths.set_option_value('bufhidden', 'wipe', {buf=buf})
      meths.win_hide(newwin)
      eq({oldwin}, meths.list_wins())
      eq({oldbuf}, meths.list_bufs())
    end)
  end)

  describe('open_win', function()
    it('noautocmd option works', function()
      command('autocmd BufEnter,BufLeave,BufWinEnter * let g:fired = 1')
      meths.open_win(meths.create_buf(true, true), true, {
        relative='win', row=3, col=3, width=12, height=3, noautocmd=true
      })
      eq(0, funcs.exists('g:fired'))
      meths.open_win(meths.create_buf(true, true), true, {
        relative='win', row=3, col=3, width=12, height=3
      })
      eq(1, funcs.exists('g:fired'))
    end)
  end)

  describe('get_config', function()
    it('includes border', function()
      local b = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' }
      local win = meths.open_win(0, true, {
         relative='win', row=3, col=3, width=12, height=3,
         border = b,
      })

      local cfg = meths.win_get_config(win)
      eq(b, cfg.border)
    end)
    it('includes border with highlight group', function()
      local b = {
        {'a', 'Normal'},
        {'b', 'Special'},
        {'c', 'String'},
        {'d', 'Comment'},
        {'e', 'Visual'},
        {'f', 'Error'},
        {'g', 'Constant'},
        {'h', 'PreProc'},
      }
      local win = meths.open_win(0, true, {
         relative='win', row=3, col=3, width=12, height=3,
         border = b,
      })

      local cfg = meths.win_get_config(win)
      eq(b, cfg.border)
    end)
  end)
end)
