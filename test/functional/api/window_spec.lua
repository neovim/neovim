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

    it('disallowed in cmdwin if win={old_}curwin or buf=curbuf', function()
      local new_buf = meths.create_buf(true, true)
      local old_win = meths.get_current_win()
      local new_win = meths.open_win(new_buf, false, {
        relative='editor', row=10, col=10, width=50, height=10,
      })
      feed('q:')
      eq('E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
         pcall_err(meths.win_set_buf, 0, new_buf))
      eq('E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
         pcall_err(meths.win_set_buf, old_win, new_buf))
      eq('E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
         pcall_err(meths.win_set_buf, new_win, 0))

      local next_buf = meths.create_buf(true, true)
      meths.win_set_buf(new_win, next_buf)
      eq(next_buf, meths.win_get_buf(new_win))
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
      local otherwin = meths.open_win(0, false, {
        relative='editor', row=10, col=10, width=10, height=10,
      })
      -- Open cmdline-window.
      feed('q:')
      eq(4, #meths.list_wins())
      eq(':', funcs.getcmdwintype())
      -- Not allowed to close previous window from cmdline-window.
      eq('E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
         pcall_err(meths.win_close, oldwin, true))
      -- Closing other windows is fine.
      meths.win_close(otherwin, true)
      eq(false, meths.win_is_valid(otherwin))
      -- Close cmdline-window.
      meths.win_close(0, true)
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
    it('in the cmdwin', function()
      feed('q:')
      -- Can close the cmdwin.
      meths.win_hide(0)
      eq('', funcs.getcmdwintype())

      local old_win = meths.get_current_win()
      local other_win = meths.open_win(0, false, {
        relative='win', row=3, col=3, width=12, height=3
      })
      feed('q:')
      -- Cannot close the previous window.
      eq('E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
         pcall_err(meths.win_hide, old_win))
      -- Can close other windows.
      meths.win_hide(other_win)
      eq(false, meths.win_is_valid(other_win))
    end)
  end)

  describe('text_height', function()
    it('validation', function()
      local X = meths.get_vvar('maxcol')
      insert([[
        aaa
        bbb
        ccc
        ddd
        eee]])
      eq("Invalid window id: 23",
         pcall_err(meths.win_text_height, 23, {}))
      eq("Line index out of bounds",
         pcall_err(curwinmeths.text_height, { start_row = 5 }))
      eq("Line index out of bounds",
         pcall_err(curwinmeths.text_height, { start_row = -6 }))
      eq("Line index out of bounds",
         pcall_err(curwinmeths.text_height, { end_row = 5 }))
      eq("Line index out of bounds",
         pcall_err(curwinmeths.text_height, { end_row = -6 }))
      eq("'start_row' is higher than 'end_row'",
         pcall_err(curwinmeths.text_height, { start_row = 3, end_row = 1 }))
      eq("'start_vcol' specified without 'start_row'",
         pcall_err(curwinmeths.text_height, { end_row = 2, start_vcol = 0 }))
      eq("'end_vcol' specified without 'end_row'",
         pcall_err(curwinmeths.text_height, { start_row = 2, end_vcol = 0 }))
      eq("Invalid 'start_vcol': out of range",
         pcall_err(curwinmeths.text_height, { start_row = 2, start_vcol = -1 }))
      eq("Invalid 'start_vcol': out of range",
         pcall_err(curwinmeths.text_height, { start_row = 2, start_vcol = X + 1 }))
      eq("Invalid 'end_vcol': out of range",
         pcall_err(curwinmeths.text_height, { end_row = 2, end_vcol = -1 }))
      eq("Invalid 'end_vcol': out of range",
         pcall_err(curwinmeths.text_height, { end_row = 2, end_vcol = X + 1 }))
      eq("'start_vcol' is higher than 'end_vcol'",
         pcall_err(curwinmeths.text_height, { start_row = 2, end_row = 2, start_vcol = 10, end_vcol = 5 }))
    end)

    it('with two diff windows', function()
      local X = meths.get_vvar('maxcol')
      local screen = Screen.new(45, 22)
      screen:set_default_attr_ids({
        [0] = {foreground = Screen.colors.Blue1, bold = true};
        [1] = {foreground = Screen.colors.Blue4, background = Screen.colors.Grey};
        [2] = {foreground = Screen.colors.Brown};
        [3] = {foreground = Screen.colors.Blue1, background = Screen.colors.LightCyan1, bold = true};
        [4] = {background = Screen.colors.LightBlue};
        [5] = {foreground = Screen.colors.Blue4, background = Screen.colors.LightGrey};
        [6] = {background = Screen.colors.Plum1};
        [7] = {background = Screen.colors.Red, bold = true};
        [8] = {reverse = true};
        [9] = {bold = true, reverse = true};
      })
      screen:attach()
      exec([[
        set diffopt+=context:2 number
        let expr = 'printf("%08d", v:val) .. repeat("!", v:val)'
        call setline(1, map(range(1, 20) + range(25, 45), expr))
        vnew
        call setline(1, map(range(3, 20) + range(28, 50), expr))
        windo diffthis
      ]])
      feed('24gg')
      screen:expect{grid=[[
        {1:  }{2:    }{3:----------------}│{1:  }{2:  1 }{4:00000001!       }|
        {1:  }{2:    }{3:----------------}│{1:  }{2:  2 }{4:00000002!!      }|
        {1:  }{2:  1 }00000003!!!     │{1:  }{2:  3 }00000003!!!     |
        {1:  }{2:  2 }00000004!!!!    │{1:  }{2:  4 }00000004!!!!    |
        {1:+ }{2:  3 }{5:+-- 14 lines: 00}│{1:+ }{2:  5 }{5:+-- 14 lines: 00}|
        {1:  }{2: 17 }00000019!!!!!!!!│{1:  }{2: 19 }00000019!!!!!!!!|
        {1:  }{2: 18 }00000020!!!!!!!!│{1:  }{2: 20 }00000020!!!!!!!!|
        {1:  }{2:    }{3:----------------}│{1:  }{2: 21 }{4:00000025!!!!!!!!}|
        {1:  }{2:    }{3:----------------}│{1:  }{2: 22 }{4:00000026!!!!!!!!}|
        {1:  }{2:    }{3:----------------}│{1:  }{2: 23 }{4:00000027!!!!!!!!}|
        {1:  }{2: 19 }00000028!!!!!!!!│{1:  }{2: 24 }^00000028!!!!!!!!|
        {1:  }{2: 20 }00000029!!!!!!!!│{1:  }{2: 25 }00000029!!!!!!!!|
        {1:+ }{2: 21 }{5:+-- 14 lines: 00}│{1:+ }{2: 26 }{5:+-- 14 lines: 00}|
        {1:  }{2: 35 }00000044!!!!!!!!│{1:  }{2: 40 }00000044!!!!!!!!|
        {1:  }{2: 36 }00000045!!!!!!!!│{1:  }{2: 41 }00000045!!!!!!!!|
        {1:  }{2: 37 }{4:00000046!!!!!!!!}│{1:  }{2:    }{3:----------------}|
        {1:  }{2: 38 }{4:00000047!!!!!!!!}│{1:  }{2:    }{3:----------------}|
        {1:  }{2: 39 }{4:00000048!!!!!!!!}│{1:  }{2:    }{3:----------------}|
        {1:  }{2: 40 }{4:00000049!!!!!!!!}│{1:  }{2:    }{3:----------------}|
        {1:  }{2: 41 }{4:00000050!!!!!!!!}│{1:  }{2:    }{3:----------------}|
        {8:[No Name] [+]          }{9:[No Name] [+]         }|
                                                     |
      ]]}
      screen:try_resize(45, 3)
      screen:expect{grid=[[
        {1:  }{2: 19 }00000028!!!!!!!!│{1:  }{2: 24 }^00000028!!!!!!!!|
        {8:[No Name] [+]          }{9:[No Name] [+]         }|
                                                     |
      ]]}
      eq({ all = 20, fill = 5 }, meths.win_text_height(1000, {}))
      eq({ all = 20, fill = 5 }, meths.win_text_height(1001, {}))
      eq({ all = 20, fill = 5 }, meths.win_text_height(1000, { start_row = 0 }))
      eq({ all = 20, fill = 5 }, meths.win_text_height(1001, { start_row = 0 }))
      eq({ all = 15, fill = 0 }, meths.win_text_height(1000, { end_row = -1 }))
      eq({ all = 15, fill = 0 }, meths.win_text_height(1000, { end_row = 40 }))
      eq({ all = 20, fill = 5 }, meths.win_text_height(1001, { end_row = -1 }))
      eq({ all = 20, fill = 5 }, meths.win_text_height(1001, { end_row = 40 }))
      eq({ all = 10, fill = 5 }, meths.win_text_height(1000, { start_row = 23 }))
      eq({ all = 13, fill = 3 }, meths.win_text_height(1001, { start_row = 18 }))
      eq({ all = 11, fill = 0 }, meths.win_text_height(1000, { end_row = 23 }))
      eq({ all = 11, fill = 5 }, meths.win_text_height(1001, { end_row = 18 }))
      eq({ all = 11, fill = 0 }, meths.win_text_height(1000, { start_row = 3, end_row = 39 }))
      eq({ all = 11, fill = 3 }, meths.win_text_height(1001, { start_row = 1, end_row = 34 }))
      eq({ all = 9, fill = 0 }, meths.win_text_height(1000, { start_row = 4, end_row = 38 }))
      eq({ all = 9, fill = 3 }, meths.win_text_height(1001, { start_row = 2, end_row = 33 }))
      eq({ all = 9, fill = 0 }, meths.win_text_height(1000, { start_row = 5, end_row = 37 }))
      eq({ all = 9, fill = 3 }, meths.win_text_height(1001, { start_row = 3, end_row = 32 }))
      eq({ all = 9, fill = 0 }, meths.win_text_height(1000, { start_row = 17, end_row = 25 }))
      eq({ all = 9, fill = 3 }, meths.win_text_height(1001, { start_row = 15, end_row = 20 }))
      eq({ all = 7, fill = 0 }, meths.win_text_height(1000, { start_row = 18, end_row = 24 }))
      eq({ all = 7, fill = 3 }, meths.win_text_height(1001, { start_row = 16, end_row = 19 }))
      eq({ all = 6, fill = 5 }, meths.win_text_height(1000, { start_row = -1 }))
      eq({ all = 5, fill = 5 }, meths.win_text_height(1000, { start_row = -1, start_vcol = X }))
      eq({ all = 0, fill = 0 }, meths.win_text_height(1000, { start_row = -1, start_vcol = X, end_row = -1 }))
      eq({ all = 0, fill = 0 }, meths.win_text_height(1000, { start_row = -1, start_vcol = X, end_row = -1, end_vcol = X }))
      eq({ all = 1, fill = 0 }, meths.win_text_height(1000, { start_row = -1, start_vcol = 0, end_row = -1, end_vcol = X }))
      eq({ all = 3, fill = 2 }, meths.win_text_height(1001, { end_row = 0 }))
      eq({ all = 2, fill = 2 }, meths.win_text_height(1001, { end_row = 0, end_vcol = 0 }))
      eq({ all = 2, fill = 2 }, meths.win_text_height(1001, { start_row = 0, end_row = 0, end_vcol = 0 }))
      eq({ all = 0, fill = 0 }, meths.win_text_height(1001, { start_row = 0, start_vcol = 0, end_row = 0, end_vcol = 0 }))
      eq({ all = 1, fill = 0 }, meths.win_text_height(1001, { start_row = 0, start_vcol = 0, end_row = 0, end_vcol = X }))
      eq({ all = 11, fill = 5 }, meths.win_text_height(1001, { end_row = 18 }))
      eq({ all = 9, fill = 3 }, meths.win_text_height(1001, { start_row = 0, start_vcol = 0, end_row = 18 }))
      eq({ all = 10, fill = 5 }, meths.win_text_height(1001, { end_row = 18, end_vcol = 0 }))
      eq({ all = 8, fill = 3 }, meths.win_text_height(1001, { start_row = 0, start_vcol = 0, end_row = 18, end_vcol = 0 }))
    end)

    it('with wrapped lines', function()
      local X = meths.get_vvar('maxcol')
      local screen = Screen.new(45, 22)
      screen:set_default_attr_ids({
        [0] = {foreground = Screen.colors.Blue1, bold = true};
        [1] = {foreground = Screen.colors.Brown};
        [2] = {background = Screen.colors.Yellow};
      })
      screen:attach()
      exec([[
        set number cpoptions+=n
        call setline(1, repeat([repeat('foobar-', 36)], 3))
      ]])
      local ns = meths.create_namespace('')
      meths.buf_set_extmark(0, ns, 1, 100, { virt_text = {{('?'):rep(15), 'Search'}}, virt_text_pos = 'inline' })
      meths.buf_set_extmark(0, ns, 2, 200, { virt_text = {{('!'):rep(75), 'Search'}}, virt_text_pos = 'inline' })
      screen:expect{grid=[[
        {1:  1 }^foobar-foobar-foobar-foobar-foobar-foobar|
        -foobar-foobar-foobar-foobar-foobar-foobar-fo|
        obar-foobar-foobar-foobar-foobar-foobar-fooba|
        r-foobar-foobar-foobar-foobar-foobar-foobar-f|
        oobar-foobar-foobar-foobar-foobar-foobar-foob|
        ar-foobar-foobar-foobar-foobar-              |
        {1:  2 }foobar-foobar-foobar-foobar-foobar-foobar|
        -foobar-foobar-foobar-foobar-foobar-foobar-fo|
        obar-foobar-fo{2:???????????????}obar-foobar-foob|
        ar-foobar-foobar-foobar-foobar-foobar-foobar-|
        foobar-foobar-foobar-foobar-foobar-foobar-foo|
        bar-foobar-foobar-foobar-foobar-foobar-foobar|
        -                                            |
        {1:  3 }foobar-foobar-foobar-foobar-foobar-foobar|
        -foobar-foobar-foobar-foobar-foobar-foobar-fo|
        obar-foobar-foobar-foobar-foobar-foobar-fooba|
        r-foobar-foobar-foobar-foobar-foobar-foobar-f|
        oobar-foobar-foobar-foob{2:!!!!!!!!!!!!!!!!!!!!!}|
        {2:!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!}|
        {2:!!!!!!!!!}ar-foobar-foobar-foobar-foobar-fooba|
        r-foobar-foobar-                             |
                                                     |
      ]]}
      screen:try_resize(45, 2)
      screen:expect{grid=[[
        {1:  1 }^foobar-foobar-foobar-foobar-foobar-foobar|
                                                     |
      ]]}
      eq({ all = 21, fill = 0 }, meths.win_text_height(0, {}))
      eq({ all = 6, fill = 0 }, meths.win_text_height(0, { start_row = 0, end_row = 0 }))
      eq({ all = 7, fill = 0 }, meths.win_text_height(0, { start_row = 1, end_row = 1 }))
      eq({ all = 8, fill = 0 }, meths.win_text_height(0, { start_row = 2, end_row = 2 }))
      eq({ all = 0, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 0 }))
      eq({ all = 1, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 41 }))
      eq({ all = 2, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 42 }))
      eq({ all = 2, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 86 }))
      eq({ all = 3, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 87 }))
      eq({ all = 6, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 266 }))
      eq({ all = 7, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 267 }))
      eq({ all = 7, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 311 }))
      eq({ all = 7, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 312 }))
      eq({ all = 7, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = X }))
      eq({ all = 7, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 40, end_row = 1, end_vcol = X }))
      eq({ all = 6, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 41, end_row = 1, end_vcol = X }))
      eq({ all = 6, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 85, end_row = 1, end_vcol = X }))
      eq({ all = 5, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 86, end_row = 1, end_vcol = X }))
      eq({ all = 2, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 265, end_row = 1, end_vcol = X }))
      eq({ all = 1, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 266, end_row = 1, end_vcol = X }))
      eq({ all = 1, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 310, end_row = 1, end_vcol = X }))
      eq({ all = 0, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 311, end_row = 1, end_vcol = X }))
      eq({ all = 1, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 86, end_row = 1, end_vcol = 131 }))
      eq({ all = 1, fill = 0 }, meths.win_text_height(0, { start_row = 1, start_vcol = 221, end_row = 1, end_vcol = 266 }))
      eq({ all = 18, fill = 0 }, meths.win_text_height(0, { start_row = 0, start_vcol = 131 }))
      eq({ all = 19, fill = 0 }, meths.win_text_height(0, { start_row = 0, start_vcol = 130 }))
      eq({ all = 20, fill = 0 }, meths.win_text_height(0, { end_row = 2, end_vcol = 311 }))
      eq({ all = 21, fill = 0 }, meths.win_text_height(0, { end_row = 2, end_vcol = 312 }))
      eq({ all = 17, fill = 0 }, meths.win_text_height(0, { start_row = 0, start_vcol = 131, end_row = 2, end_vcol = 311 }))
      eq({ all = 19, fill = 0 }, meths.win_text_height(0, { start_row = 0, start_vcol = 130, end_row = 2, end_vcol = 312 }))
      eq({ all = 16, fill = 0 }, meths.win_text_height(0, { start_row = 0, start_vcol = 221 }))
      eq({ all = 17, fill = 0 }, meths.win_text_height(0, { start_row = 0, start_vcol = 220 }))
      eq({ all = 14, fill = 0 }, meths.win_text_height(0, { end_row = 2, end_vcol = 41 }))
      eq({ all = 15, fill = 0 }, meths.win_text_height(0, { end_row = 2, end_vcol = 42 }))
      eq({ all = 9, fill = 0 }, meths.win_text_height(0, { start_row = 0, start_vcol = 221, end_row = 2, end_vcol = 41 }))
      eq({ all = 11, fill = 0 }, meths.win_text_height(0, { start_row = 0, start_vcol = 220, end_row = 2, end_vcol = 42 }))
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

    it('disallowed in cmdwin if enter=true or buf=curbuf', function()
      local new_buf = meths.create_buf(true, true)
      feed('q:')
      eq('E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
         pcall_err(meths.open_win, new_buf, true, {
           relative='editor', row=5, col=5, width=5, height=5,
         }))
      eq('E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
         pcall_err(meths.open_win, 0, false, {
           relative='editor', row=5, col=5, width=5, height=5,
         }))

      eq(new_buf, meths.win_get_buf(meths.open_win(new_buf, false, {
           relative='editor', row=5, col=5, width=5, height=5,
         })))
    end)

    it('aborts if buffer is invalid', function()
      local wins_before = meths.list_wins()
      eq('Invalid buffer id: 1337', pcall_err(meths.open_win, 1337, false, {
           relative='editor', row=5, col=5, width=5, height=5,
         }))
      eq(wins_before, meths.list_wins())
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
