local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, curbuf, curbuf_contents, curwin, eq, neq, matches, ok, feed, insert, eval =
  helpers.clear,
  helpers.api.nvim_get_current_buf,
  helpers.curbuf_contents,
  helpers.api.nvim_get_current_win,
  helpers.eq,
  helpers.neq,
  helpers.matches,
  helpers.ok,
  helpers.feed,
  helpers.insert,
  helpers.eval
local poke_eventloop = helpers.poke_eventloop
local exec = helpers.exec
local exec_lua = helpers.exec_lua
local fn = helpers.fn
local request = helpers.request
local NIL = vim.NIL
local api = helpers.api
local command = helpers.command
local pcall_err = helpers.pcall_err
local assert_alive = helpers.assert_alive

describe('API/win', function()
  before_each(clear)

  describe('get_buf', function()
    it('works', function()
      eq(curbuf(), api.nvim_win_get_buf(api.nvim_list_wins()[1]))
      command('new')
      api.nvim_set_current_win(api.nvim_list_wins()[2])
      eq(curbuf(), api.nvim_win_get_buf(api.nvim_list_wins()[2]))
      neq(
        api.nvim_win_get_buf(api.nvim_list_wins()[1]),
        api.nvim_win_get_buf(api.nvim_list_wins()[2])
      )
    end)
  end)

  describe('set_buf', function()
    it('works', function()
      command('new')
      local windows = api.nvim_list_wins()
      neq(api.nvim_win_get_buf(windows[2]), api.nvim_win_get_buf(windows[1]))
      api.nvim_win_set_buf(windows[2], api.nvim_win_get_buf(windows[1]))
      eq(api.nvim_win_get_buf(windows[2]), api.nvim_win_get_buf(windows[1]))
    end)

    it('validates args', function()
      eq('Invalid buffer id: 23', pcall_err(api.nvim_win_set_buf, api.nvim_get_current_win(), 23))
      eq('Invalid window id: 23', pcall_err(api.nvim_win_set_buf, 23, api.nvim_get_current_buf()))
    end)

    it('disallowed in cmdwin if win=cmdwin_{old_cur}win or buf=cmdwin_buf', function()
      local new_buf = api.nvim_create_buf(true, true)
      local old_win = api.nvim_get_current_win()
      local new_win = api.nvim_open_win(new_buf, false, {
        relative = 'editor',
        row = 10,
        col = 10,
        width = 50,
        height = 10,
      })
      feed('q:')
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_win_set_buf, 0, new_buf)
      )
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_win_set_buf, old_win, new_buf)
      )
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_win_set_buf, new_win, 0)
      )
      matches(
        'E11: Invalid in command%-line window; <CR> executes, CTRL%-C quits$',
        pcall_err(
          exec_lua,
          [[
           local cmdwin_buf = vim.api.nvim_get_current_buf()
           local new_win, new_buf = ...
           vim.api.nvim_buf_call(new_buf, function()
             vim.api.nvim_win_set_buf(new_win, cmdwin_buf)
           end)
         ]],
          new_win,
          new_buf
        )
      )
      matches(
        'E11: Invalid in command%-line window; <CR> executes, CTRL%-C quits$',
        pcall_err(
          exec_lua,
          [[
           local cmdwin_win = vim.api.nvim_get_current_win()
           local new_win, new_buf = ...
           vim.api.nvim_win_call(new_win, function()
             vim.api.nvim_win_set_buf(cmdwin_win, new_buf)
           end)
         ]],
          new_win,
          new_buf
        )
      )

      local next_buf = api.nvim_create_buf(true, true)
      api.nvim_win_set_buf(new_win, next_buf)
      eq(next_buf, api.nvim_win_get_buf(new_win))
    end)
  end)

  describe('{get,set}_cursor', function()
    it('works', function()
      eq({ 1, 0 }, api.nvim_win_get_cursor(0))
      command('normal ityping\027o  some text')
      eq('typing\n  some text', curbuf_contents())
      eq({ 2, 10 }, api.nvim_win_get_cursor(0))
      api.nvim_win_set_cursor(0, { 2, 6 })
      command('normal i dumb')
      eq('typing\n  some dumb text', curbuf_contents())
    end)

    it('does not leak memory when using invalid window ID with invalid pos', function()
      eq('Invalid window id: 1', pcall_err(api.nvim_win_set_cursor, 1, { 'b\na' }))
    end)

    it('updates the screen, and also when the window is unfocused', function()
      local screen = Screen.new(30, 9)
      screen:set_default_attr_ids({
        [1] = { bold = true, foreground = Screen.colors.Blue },
        [2] = { bold = true, reverse = true },
        [3] = { reverse = true },
      })
      screen:attach()

      insert('prologue')
      feed('100o<esc>')
      insert('epilogue')
      local win = curwin()
      feed('gg')

      screen:expect {
        grid = [[
        ^prologue                      |
                                      |*8
      ]],
      }
      -- cursor position is at beginning
      eq({ 1, 0 }, api.nvim_win_get_cursor(win))

      -- move cursor to end
      api.nvim_win_set_cursor(win, { 101, 0 })
      screen:expect {
        grid = [[
                                      |*7
        ^epilogue                      |
                                      |
      ]],
      }

      -- move cursor to the beginning again
      api.nvim_win_set_cursor(win, { 1, 0 })
      screen:expect {
        grid = [[
        ^prologue                      |
                                      |*8
      ]],
      }

      -- move focus to new window
      command('new')
      neq(win, curwin())

      -- sanity check, cursor position is kept
      eq({ 1, 0 }, api.nvim_win_get_cursor(win))
      screen:expect {
        grid = [[
        ^                              |
        {1:~                             }|*2
        {2:[No Name]                     }|
        prologue                      |
                                      |*2
        {3:[No Name] [+]                 }|
                                      |
      ]],
      }

      -- move cursor to end
      api.nvim_win_set_cursor(win, { 101, 0 })
      screen:expect {
        grid = [[
        ^                              |
        {1:~                             }|*2
        {2:[No Name]                     }|
                                      |*2
        epilogue                      |
        {3:[No Name] [+]                 }|
                                      |
      ]],
      }

      -- move cursor to the beginning again
      api.nvim_win_set_cursor(win, { 1, 0 })
      screen:expect {
        grid = [[
        ^                              |
        {1:~                             }|*2
        {2:[No Name]                     }|
        prologue                      |
                                      |*2
        {3:[No Name] [+]                 }|
                                      |
      ]],
      }

      -- curwin didn't change back
      neq(win, curwin())
    end)

    it('remembers what column it wants to be in', function()
      insert('first line')
      feed('o<esc>')
      insert('second line')

      feed('gg')
      poke_eventloop() -- let nvim process the 'gg' command

      -- cursor position is at beginning
      local win = curwin()
      eq({ 1, 0 }, api.nvim_win_get_cursor(win))

      -- move cursor to column 5
      api.nvim_win_set_cursor(win, { 1, 5 })

      -- move down a line
      feed('j')
      poke_eventloop() -- let nvim process the 'j' command

      -- cursor is still in column 5
      eq({ 2, 5 }, api.nvim_win_get_cursor(win))
    end)

    it('updates cursorline and statusline ruler in non-current window', function()
      local screen = Screen.new(60, 8)
      screen:set_default_attr_ids({
        [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
        [2] = { background = Screen.colors.Grey90 }, -- CursorLine
        [3] = { bold = true, reverse = true }, -- StatusLine
        [4] = { reverse = true }, -- StatusLineNC
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
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]  4,3         All }{4:[No Name] [+]  4,3        All}|
                                                                    |
      ]])
      api.nvim_win_set_cursor(oldwin, { 1, 0 })
      screen:expect([[
        aaa                           │{2:aaa                          }|
        bbb                           │bbb                          |
        ccc                           │ccc                          |
        {2:dd^d                           }│ddd                          |
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]  4,3         All }{4:[No Name] [+]  1,1        All}|
                                                                    |
      ]])
    end)

    it('updates cursorcolumn in non-current window', function()
      local screen = Screen.new(60, 8)
      screen:set_default_attr_ids({
        [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
        [2] = { background = Screen.colors.Grey90 }, -- CursorColumn
        [3] = { bold = true, reverse = true }, -- StatusLine
        [4] = { reverse = true }, -- StatusLineNC
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
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]                  }{4:[No Name] [+]                }|
                                                                    |
      ]])
      api.nvim_win_set_cursor(oldwin, { 2, 0 })
      screen:expect([[
        aa{2:a}                           │{2:a}aa                          |
        bb{2:b}                           │bbb                          |
        cc{2:c}                           │{2:c}cc                          |
        dd^d                           │{2:d}dd                          |
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]                  }{4:[No Name] [+]                }|
                                                                    |
      ]])
    end)
  end)

  describe('{get,set}_height', function()
    it('works', function()
      command('vsplit')
      eq(
        api.nvim_win_get_height(api.nvim_list_wins()[2]),
        api.nvim_win_get_height(api.nvim_list_wins()[1])
      )
      api.nvim_set_current_win(api.nvim_list_wins()[2])
      command('split')
      eq(
        api.nvim_win_get_height(api.nvim_list_wins()[2]),
        math.floor(api.nvim_win_get_height(api.nvim_list_wins()[1]) / 2)
      )
      api.nvim_win_set_height(api.nvim_list_wins()[2], 2)
      eq(2, api.nvim_win_get_height(api.nvim_list_wins()[2]))
    end)

    it('correctly handles height=1', function()
      command('split')
      api.nvim_set_current_win(api.nvim_list_wins()[1])
      api.nvim_win_set_height(api.nvim_list_wins()[2], 1)
      eq(1, api.nvim_win_get_height(api.nvim_list_wins()[2]))
    end)

    it('correctly handles height=1 with a winbar', function()
      command('set winbar=foobar')
      command('set winminheight=0')
      command('split')
      api.nvim_set_current_win(api.nvim_list_wins()[1])
      api.nvim_win_set_height(api.nvim_list_wins()[2], 1)
      eq(1, api.nvim_win_get_height(api.nvim_list_wins()[2]))
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
      eq('', api.nvim_get_vvar('errmsg'))
    end)
  end)

  describe('{get,set}_width', function()
    it('works', function()
      command('split')
      eq(
        api.nvim_win_get_width(api.nvim_list_wins()[2]),
        api.nvim_win_get_width(api.nvim_list_wins()[1])
      )
      api.nvim_set_current_win(api.nvim_list_wins()[2])
      command('vsplit')
      eq(
        api.nvim_win_get_width(api.nvim_list_wins()[2]),
        math.floor(api.nvim_win_get_width(api.nvim_list_wins()[1]) / 2)
      )
      api.nvim_win_set_width(api.nvim_list_wins()[2], 2)
      eq(2, api.nvim_win_get_width(api.nvim_list_wins()[2]))
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
      eq('', api.nvim_get_vvar('errmsg'))
    end)
  end)

  describe('{get,set,del}_var', function()
    it('works', function()
      api.nvim_win_set_var(0, 'lua', { 1, 2, { ['3'] = 1 } })
      eq({ 1, 2, { ['3'] = 1 } }, api.nvim_win_get_var(0, 'lua'))
      eq({ 1, 2, { ['3'] = 1 } }, api.nvim_eval('w:lua'))
      eq(1, fn.exists('w:lua'))
      api.nvim_win_del_var(0, 'lua')
      eq(0, fn.exists('w:lua'))
      eq('Key not found: lua', pcall_err(api.nvim_win_del_var, 0, 'lua'))
      api.nvim_win_set_var(0, 'lua', 1)
      command('lockvar w:lua')
      eq('Key is locked: lua', pcall_err(api.nvim_win_del_var, 0, 'lua'))
      eq('Key is locked: lua', pcall_err(api.nvim_win_set_var, 0, 'lua', 1))
    end)

    it('window_set_var returns the old value', function()
      local val1 = { 1, 2, { ['3'] = 1 } }
      local val2 = { 4, 7 }
      eq(NIL, request('window_set_var', 0, 'lua', val1))
      eq(val1, request('window_set_var', 0, 'lua', val2))
    end)

    it('window_del_var returns the old value', function()
      local val1 = { 1, 2, { ['3'] = 1 } }
      local val2 = { 4, 7 }
      eq(NIL, request('window_set_var', 0, 'lua', val1))
      eq(val1, request('window_set_var', 0, 'lua', val2))
      eq(val2, request('window_del_var', 0, 'lua'))
    end)
  end)

  describe('nvim_get_option_value, nvim_set_option_value', function()
    it('works', function()
      api.nvim_set_option_value('colorcolumn', '4,3', {})
      eq('4,3', api.nvim_get_option_value('colorcolumn', {}))
      command('set modified hidden')
      command('enew') -- edit new buffer, window option is preserved
      eq('4,3', api.nvim_get_option_value('colorcolumn', {}))

      -- global-local option
      api.nvim_set_option_value('statusline', 'window-status', { win = 0 })
      eq('window-status', api.nvim_get_option_value('statusline', { win = 0 }))
      eq('', api.nvim_get_option_value('statusline', { scope = 'global' }))
      command('set modified')
      command('enew') -- global-local: not preserved in new buffer
      -- confirm local value was not copied
      eq('', api.nvim_get_option_value('statusline', { win = 0 }))
      eq('', eval('&l:statusline'))
    end)

    it('after switching windows #15390', function()
      command('tabnew')
      local tab1 = unpack(api.nvim_list_tabpages())
      local win1 = unpack(api.nvim_tabpage_list_wins(tab1))
      api.nvim_set_option_value('statusline', 'window-status', { win = win1 })
      command('split')
      command('wincmd J')
      command('wincmd j')
      eq('window-status', api.nvim_get_option_value('statusline', { win = win1 }))
      assert_alive()
    end)

    it('returns values for unset local options', function()
      eq(-1, api.nvim_get_option_value('scrolloff', { win = 0, scope = 'local' }))
    end)
  end)

  describe('get_position', function()
    it('works', function()
      local height = api.nvim_win_get_height(api.nvim_list_wins()[1])
      local width = api.nvim_win_get_width(api.nvim_list_wins()[1])
      command('split')
      command('vsplit')
      eq({ 0, 0 }, api.nvim_win_get_position(api.nvim_list_wins()[1]))
      local vsplit_pos = math.floor(width / 2)
      local split_pos = math.floor(height / 2)
      local win2row, win2col = unpack(api.nvim_win_get_position(api.nvim_list_wins()[2]))
      local win3row, win3col = unpack(api.nvim_win_get_position(api.nvim_list_wins()[3]))
      eq(0, win2row)
      eq(0, win3col)
      ok(vsplit_pos - 1 <= win2col and win2col <= vsplit_pos + 1)
      ok(split_pos - 1 <= win3row and win3row <= split_pos + 1)
    end)
  end)

  describe('get_position', function()
    it('works', function()
      command('tabnew')
      command('vsplit')
      eq(api.nvim_win_get_tabpage(api.nvim_list_wins()[1]), api.nvim_list_tabpages()[1])
      eq(api.nvim_win_get_tabpage(api.nvim_list_wins()[2]), api.nvim_list_tabpages()[2])
      eq(api.nvim_win_get_tabpage(api.nvim_list_wins()[3]), api.nvim_list_tabpages()[2])
    end)
  end)

  describe('get_number', function()
    it('works', function()
      local wins = api.nvim_list_wins()
      eq(1, api.nvim_win_get_number(wins[1]))

      command('split')
      local win1, win2 = unpack(api.nvim_list_wins())
      eq(1, api.nvim_win_get_number(win1))
      eq(2, api.nvim_win_get_number(win2))

      command('wincmd J')
      eq(2, api.nvim_win_get_number(win1))
      eq(1, api.nvim_win_get_number(win2))

      command('tabnew')
      local win3 = api.nvim_list_wins()[3]
      -- First tab page
      eq(2, api.nvim_win_get_number(win1))
      eq(1, api.nvim_win_get_number(win2))
      -- Second tab page
      eq(1, api.nvim_win_get_number(win3))
    end)
  end)

  describe('is_valid', function()
    it('works', function()
      command('split')
      local win = api.nvim_list_wins()[2]
      api.nvim_set_current_win(win)
      ok(api.nvim_win_is_valid(win))
      command('close')
      ok(not api.nvim_win_is_valid(win))
    end)
  end)

  describe('close', function()
    it('can close current window', function()
      local oldwin = api.nvim_get_current_win()
      command('split')
      local newwin = api.nvim_get_current_win()
      api.nvim_win_close(newwin, false)
      eq({ oldwin }, api.nvim_list_wins())
    end)

    it('can close noncurrent window', function()
      local oldwin = api.nvim_get_current_win()
      command('split')
      local newwin = api.nvim_get_current_win()
      api.nvim_win_close(oldwin, false)
      eq({ newwin }, api.nvim_list_wins())
    end)

    it("handles changed buffer when 'hidden' is unset", function()
      command('set nohidden')
      local oldwin = api.nvim_get_current_win()
      insert('text')
      command('new')
      local newwin = api.nvim_get_current_win()
      eq(
        'Vim:E37: No write since last change (add ! to override)',
        pcall_err(api.nvim_win_close, oldwin, false)
      )
      eq({ newwin, oldwin }, api.nvim_list_wins())
    end)

    it('handles changed buffer with force', function()
      local oldwin = api.nvim_get_current_win()
      insert('text')
      command('new')
      local newwin = api.nvim_get_current_win()
      api.nvim_win_close(oldwin, true)
      eq({ newwin }, api.nvim_list_wins())
    end)

    it('in cmdline-window #9767', function()
      command('split')
      eq(2, #api.nvim_list_wins())
      local oldbuf = api.nvim_get_current_buf()
      local oldwin = api.nvim_get_current_win()
      local otherwin = api.nvim_open_win(0, false, {
        relative = 'editor',
        row = 10,
        col = 10,
        width = 10,
        height = 10,
      })
      -- Open cmdline-window.
      feed('q:')
      eq(4, #api.nvim_list_wins())
      eq(':', fn.getcmdwintype())
      -- Not allowed to close previous window from cmdline-window.
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_win_close, oldwin, true)
      )
      -- Closing other windows is fine.
      api.nvim_win_close(otherwin, true)
      eq(false, api.nvim_win_is_valid(otherwin))
      -- Close cmdline-window.
      api.nvim_win_close(0, true)
      eq(2, #api.nvim_list_wins())
      eq('', fn.getcmdwintype())

      -- Closing curwin in context of a different window shouldn't close cmdwin.
      otherwin = api.nvim_open_win(0, false, {
        relative = 'editor',
        row = 10,
        col = 10,
        width = 10,
        height = 10,
      })
      feed('q:')
      exec_lua(
        [[
        vim.api.nvim_win_call(..., function()
          vim.api.nvim_win_close(0, true)
        end)
      ]],
        otherwin
      )
      eq(false, api.nvim_win_is_valid(otherwin))
      eq(':', fn.getcmdwintype())
      -- Closing cmdwin in context of a non-previous window is still OK.
      otherwin = api.nvim_open_win(oldbuf, false, {
        relative = 'editor',
        row = 10,
        col = 10,
        width = 10,
        height = 10,
      })
      exec_lua(
        [[
        local otherwin, cmdwin = ...
        vim.api.nvim_win_call(otherwin, function()
          vim.api.nvim_win_close(cmdwin, true)
        end)
      ]],
        otherwin,
        api.nvim_get_current_win()
      )
      eq('', fn.getcmdwintype())
      eq(true, api.nvim_win_is_valid(otherwin))
    end)

    it('closing current (float) window of another tabpage #15313', function()
      command('tabedit')
      command('botright split')
      local prevwin = curwin()
      eq(2, eval('tabpagenr()'))
      local win = api.nvim_open_win(0, true, {
        relative = 'editor',
        row = 10,
        col = 10,
        width = 50,
        height = 10,
      })
      local tab = eval('tabpagenr()')
      command('tabprevious')
      eq(1, eval('tabpagenr()'))
      api.nvim_win_close(win, false)

      eq(prevwin, api.nvim_tabpage_get_win(tab))
      assert_alive()
    end)
  end)

  describe('hide', function()
    it('can hide current window', function()
      local oldwin = api.nvim_get_current_win()
      command('split')
      local newwin = api.nvim_get_current_win()
      api.nvim_win_hide(newwin)
      eq({ oldwin }, api.nvim_list_wins())
    end)
    it('can hide noncurrent window', function()
      local oldwin = api.nvim_get_current_win()
      command('split')
      local newwin = api.nvim_get_current_win()
      api.nvim_win_hide(oldwin)
      eq({ newwin }, api.nvim_list_wins())
    end)
    it('does not close the buffer', function()
      local oldwin = api.nvim_get_current_win()
      local oldbuf = api.nvim_get_current_buf()
      local buf = api.nvim_create_buf(true, false)
      local newwin = api.nvim_open_win(buf, true, {
        relative = 'win',
        row = 3,
        col = 3,
        width = 12,
        height = 3,
      })
      api.nvim_win_hide(newwin)
      eq({ oldwin }, api.nvim_list_wins())
      eq({ oldbuf, buf }, api.nvim_list_bufs())
    end)
    it('deletes the buffer when bufhidden=wipe', function()
      local oldwin = api.nvim_get_current_win()
      local oldbuf = api.nvim_get_current_buf()
      local buf = api.nvim_create_buf(true, false)
      local newwin = api.nvim_open_win(buf, true, {
        relative = 'win',
        row = 3,
        col = 3,
        width = 12,
        height = 3,
      })
      api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
      api.nvim_win_hide(newwin)
      eq({ oldwin }, api.nvim_list_wins())
      eq({ oldbuf }, api.nvim_list_bufs())
    end)
    it('in the cmdwin', function()
      feed('q:')
      -- Can close the cmdwin.
      api.nvim_win_hide(0)
      eq('', fn.getcmdwintype())

      local old_buf = api.nvim_get_current_buf()
      local old_win = api.nvim_get_current_win()
      local other_win = api.nvim_open_win(0, false, {
        relative = 'win',
        row = 3,
        col = 3,
        width = 12,
        height = 3,
      })
      feed('q:')
      -- Cannot close the previous window.
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_win_hide, old_win)
      )
      -- Can close other windows.
      api.nvim_win_hide(other_win)
      eq(false, api.nvim_win_is_valid(other_win))

      -- Closing curwin in context of a different window shouldn't close cmdwin.
      other_win = api.nvim_open_win(old_buf, false, {
        relative = 'editor',
        row = 10,
        col = 10,
        width = 10,
        height = 10,
      })
      exec_lua(
        [[
        vim.api.nvim_win_call(..., function()
          vim.api.nvim_win_hide(0)
        end)
      ]],
        other_win
      )
      eq(false, api.nvim_win_is_valid(other_win))
      eq(':', fn.getcmdwintype())
      -- Closing cmdwin in context of a non-previous window is still OK.
      other_win = api.nvim_open_win(old_buf, false, {
        relative = 'editor',
        row = 10,
        col = 10,
        width = 10,
        height = 10,
      })
      exec_lua(
        [[
        local otherwin, cmdwin = ...
        vim.api.nvim_win_call(otherwin, function()
          vim.api.nvim_win_hide(cmdwin)
        end)
      ]],
        other_win,
        api.nvim_get_current_win()
      )
      eq('', fn.getcmdwintype())
      eq(true, api.nvim_win_is_valid(other_win))
    end)
  end)

  describe('text_height', function()
    it('validation', function()
      local X = api.nvim_get_vvar('maxcol')
      insert([[
        aaa
        bbb
        ccc
        ddd
        eee]])
      eq('Invalid window id: 23', pcall_err(api.nvim_win_text_height, 23, {}))
      eq('Line index out of bounds', pcall_err(api.nvim_win_text_height, 0, { start_row = 5 }))
      eq('Line index out of bounds', pcall_err(api.nvim_win_text_height, 0, { start_row = -6 }))
      eq('Line index out of bounds', pcall_err(api.nvim_win_text_height, 0, { end_row = 5 }))
      eq('Line index out of bounds', pcall_err(api.nvim_win_text_height, 0, { end_row = -6 }))
      eq(
        "'start_row' is higher than 'end_row'",
        pcall_err(api.nvim_win_text_height, 0, { start_row = 3, end_row = 1 })
      )
      eq(
        "'start_vcol' specified without 'start_row'",
        pcall_err(api.nvim_win_text_height, 0, { end_row = 2, start_vcol = 0 })
      )
      eq(
        "'end_vcol' specified without 'end_row'",
        pcall_err(api.nvim_win_text_height, 0, { start_row = 2, end_vcol = 0 })
      )
      eq(
        "Invalid 'start_vcol': out of range",
        pcall_err(api.nvim_win_text_height, 0, { start_row = 2, start_vcol = -1 })
      )
      eq(
        "Invalid 'start_vcol': out of range",
        pcall_err(api.nvim_win_text_height, 0, { start_row = 2, start_vcol = X + 1 })
      )
      eq(
        "Invalid 'end_vcol': out of range",
        pcall_err(api.nvim_win_text_height, 0, { end_row = 2, end_vcol = -1 })
      )
      eq(
        "Invalid 'end_vcol': out of range",
        pcall_err(api.nvim_win_text_height, 0, { end_row = 2, end_vcol = X + 1 })
      )
      eq(
        "'start_vcol' is higher than 'end_vcol'",
        pcall_err(
          api.nvim_win_text_height,
          0,
          { start_row = 2, end_row = 2, start_vcol = 10, end_vcol = 5 }
        )
      )
    end)

    it('with two diff windows', function()
      local X = api.nvim_get_vvar('maxcol')
      local screen = Screen.new(45, 22)
      screen:set_default_attr_ids({
        [0] = { foreground = Screen.colors.Blue1, bold = true },
        [1] = { foreground = Screen.colors.Blue4, background = Screen.colors.Grey },
        [2] = { foreground = Screen.colors.Brown },
        [3] = {
          foreground = Screen.colors.Blue1,
          background = Screen.colors.LightCyan1,
          bold = true,
        },
        [4] = { background = Screen.colors.LightBlue },
        [5] = { foreground = Screen.colors.Blue4, background = Screen.colors.LightGrey },
        [6] = { background = Screen.colors.Plum1 },
        [7] = { background = Screen.colors.Red, bold = true },
        [8] = { reverse = true },
        [9] = { bold = true, reverse = true },
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
      screen:expect {
        grid = [[
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
      ]],
      }
      screen:try_resize(45, 3)
      screen:expect {
        grid = [[
        {1:  }{2: 19 }00000028!!!!!!!!│{1:  }{2: 24 }^00000028!!!!!!!!|
        {8:[No Name] [+]          }{9:[No Name] [+]         }|
                                                     |
      ]],
      }
      eq({ all = 20, fill = 5 }, api.nvim_win_text_height(1000, {}))
      eq({ all = 20, fill = 5 }, api.nvim_win_text_height(1001, {}))
      eq({ all = 20, fill = 5 }, api.nvim_win_text_height(1000, { start_row = 0 }))
      eq({ all = 20, fill = 5 }, api.nvim_win_text_height(1001, { start_row = 0 }))
      eq({ all = 15, fill = 0 }, api.nvim_win_text_height(1000, { end_row = -1 }))
      eq({ all = 15, fill = 0 }, api.nvim_win_text_height(1000, { end_row = 40 }))
      eq({ all = 20, fill = 5 }, api.nvim_win_text_height(1001, { end_row = -1 }))
      eq({ all = 20, fill = 5 }, api.nvim_win_text_height(1001, { end_row = 40 }))
      eq({ all = 10, fill = 5 }, api.nvim_win_text_height(1000, { start_row = 23 }))
      eq({ all = 13, fill = 3 }, api.nvim_win_text_height(1001, { start_row = 18 }))
      eq({ all = 11, fill = 0 }, api.nvim_win_text_height(1000, { end_row = 23 }))
      eq({ all = 11, fill = 5 }, api.nvim_win_text_height(1001, { end_row = 18 }))
      eq({ all = 11, fill = 0 }, api.nvim_win_text_height(1000, { start_row = 3, end_row = 39 }))
      eq({ all = 11, fill = 3 }, api.nvim_win_text_height(1001, { start_row = 1, end_row = 34 }))
      eq({ all = 9, fill = 0 }, api.nvim_win_text_height(1000, { start_row = 4, end_row = 38 }))
      eq({ all = 9, fill = 3 }, api.nvim_win_text_height(1001, { start_row = 2, end_row = 33 }))
      eq({ all = 9, fill = 0 }, api.nvim_win_text_height(1000, { start_row = 5, end_row = 37 }))
      eq({ all = 9, fill = 3 }, api.nvim_win_text_height(1001, { start_row = 3, end_row = 32 }))
      eq({ all = 9, fill = 0 }, api.nvim_win_text_height(1000, { start_row = 17, end_row = 25 }))
      eq({ all = 9, fill = 3 }, api.nvim_win_text_height(1001, { start_row = 15, end_row = 20 }))
      eq({ all = 7, fill = 0 }, api.nvim_win_text_height(1000, { start_row = 18, end_row = 24 }))
      eq({ all = 7, fill = 3 }, api.nvim_win_text_height(1001, { start_row = 16, end_row = 19 }))
      eq({ all = 6, fill = 5 }, api.nvim_win_text_height(1000, { start_row = -1 }))
      eq({ all = 5, fill = 5 }, api.nvim_win_text_height(1000, { start_row = -1, start_vcol = X }))
      eq(
        { all = 0, fill = 0 },
        api.nvim_win_text_height(1000, { start_row = -1, start_vcol = X, end_row = -1 })
      )
      eq(
        { all = 0, fill = 0 },
        api.nvim_win_text_height(
          1000,
          { start_row = -1, start_vcol = X, end_row = -1, end_vcol = X }
        )
      )
      eq(
        { all = 1, fill = 0 },
        api.nvim_win_text_height(
          1000,
          { start_row = -1, start_vcol = 0, end_row = -1, end_vcol = X }
        )
      )
      eq({ all = 3, fill = 2 }, api.nvim_win_text_height(1001, { end_row = 0 }))
      eq({ all = 2, fill = 2 }, api.nvim_win_text_height(1001, { end_row = 0, end_vcol = 0 }))
      eq(
        { all = 2, fill = 2 },
        api.nvim_win_text_height(1001, { start_row = 0, end_row = 0, end_vcol = 0 })
      )
      eq(
        { all = 0, fill = 0 },
        api.nvim_win_text_height(1001, { start_row = 0, start_vcol = 0, end_row = 0, end_vcol = 0 })
      )
      eq(
        { all = 1, fill = 0 },
        api.nvim_win_text_height(1001, { start_row = 0, start_vcol = 0, end_row = 0, end_vcol = X })
      )
      eq({ all = 11, fill = 5 }, api.nvim_win_text_height(1001, { end_row = 18 }))
      eq(
        { all = 9, fill = 3 },
        api.nvim_win_text_height(1001, { start_row = 0, start_vcol = 0, end_row = 18 })
      )
      eq({ all = 10, fill = 5 }, api.nvim_win_text_height(1001, { end_row = 18, end_vcol = 0 }))
      eq(
        { all = 8, fill = 3 },
        api.nvim_win_text_height(
          1001,
          { start_row = 0, start_vcol = 0, end_row = 18, end_vcol = 0 }
        )
      )
    end)

    it('with wrapped lines', function()
      local X = api.nvim_get_vvar('maxcol')
      local screen = Screen.new(45, 22)
      screen:set_default_attr_ids({
        [0] = { foreground = Screen.colors.Blue1, bold = true },
        [1] = { foreground = Screen.colors.Brown },
        [2] = { background = Screen.colors.Yellow },
      })
      screen:attach()
      exec([[
        set number cpoptions+=n
        call setline(1, repeat([repeat('foobar-', 36)], 3))
      ]])
      local ns = api.nvim_create_namespace('')
      api.nvim_buf_set_extmark(
        0,
        ns,
        1,
        100,
        { virt_text = { { ('?'):rep(15), 'Search' } }, virt_text_pos = 'inline' }
      )
      api.nvim_buf_set_extmark(
        0,
        ns,
        2,
        200,
        { virt_text = { { ('!'):rep(75), 'Search' } }, virt_text_pos = 'inline' }
      )
      screen:expect {
        grid = [[
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
      ]],
      }
      screen:try_resize(45, 2)
      screen:expect {
        grid = [[
        {1:  1 }^foobar-foobar-foobar-foobar-foobar-foobar|
                                                     |
      ]],
      }
      eq({ all = 21, fill = 0 }, api.nvim_win_text_height(0, {}))
      eq({ all = 6, fill = 0 }, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }))
      eq({ all = 7, fill = 0 }, api.nvim_win_text_height(0, { start_row = 1, end_row = 1 }))
      eq({ all = 8, fill = 0 }, api.nvim_win_text_height(0, { start_row = 2, end_row = 2 }))
      eq(
        { all = 0, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 0 })
      )
      eq(
        { all = 1, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 41 })
      )
      eq(
        { all = 2, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 42 })
      )
      eq(
        { all = 2, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 86 })
      )
      eq(
        { all = 3, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 87 })
      )
      eq(
        { all = 6, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 266 })
      )
      eq(
        { all = 7, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 267 })
      )
      eq(
        { all = 7, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 311 })
      )
      eq(
        { all = 7, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = 312 })
      )
      eq(
        { all = 7, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 0, end_row = 1, end_vcol = X })
      )
      eq(
        { all = 7, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 40, end_row = 1, end_vcol = X })
      )
      eq(
        { all = 6, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 41, end_row = 1, end_vcol = X })
      )
      eq(
        { all = 6, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 85, end_row = 1, end_vcol = X })
      )
      eq(
        { all = 5, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 86, end_row = 1, end_vcol = X })
      )
      eq(
        { all = 2, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 265, end_row = 1, end_vcol = X })
      )
      eq(
        { all = 1, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 266, end_row = 1, end_vcol = X })
      )
      eq(
        { all = 1, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 310, end_row = 1, end_vcol = X })
      )
      eq(
        { all = 0, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 311, end_row = 1, end_vcol = X })
      )
      eq(
        { all = 1, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 1, start_vcol = 86, end_row = 1, end_vcol = 131 })
      )
      eq(
        { all = 1, fill = 0 },
        api.nvim_win_text_height(
          0,
          { start_row = 1, start_vcol = 221, end_row = 1, end_vcol = 266 }
        )
      )
      eq({ all = 18, fill = 0 }, api.nvim_win_text_height(0, { start_row = 0, start_vcol = 131 }))
      eq({ all = 19, fill = 0 }, api.nvim_win_text_height(0, { start_row = 0, start_vcol = 130 }))
      eq({ all = 20, fill = 0 }, api.nvim_win_text_height(0, { end_row = 2, end_vcol = 311 }))
      eq({ all = 21, fill = 0 }, api.nvim_win_text_height(0, { end_row = 2, end_vcol = 312 }))
      eq(
        { all = 17, fill = 0 },
        api.nvim_win_text_height(
          0,
          { start_row = 0, start_vcol = 131, end_row = 2, end_vcol = 311 }
        )
      )
      eq(
        { all = 19, fill = 0 },
        api.nvim_win_text_height(
          0,
          { start_row = 0, start_vcol = 130, end_row = 2, end_vcol = 312 }
        )
      )
      eq({ all = 16, fill = 0 }, api.nvim_win_text_height(0, { start_row = 0, start_vcol = 221 }))
      eq({ all = 17, fill = 0 }, api.nvim_win_text_height(0, { start_row = 0, start_vcol = 220 }))
      eq({ all = 14, fill = 0 }, api.nvim_win_text_height(0, { end_row = 2, end_vcol = 41 }))
      eq({ all = 15, fill = 0 }, api.nvim_win_text_height(0, { end_row = 2, end_vcol = 42 }))
      eq(
        { all = 9, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 0, start_vcol = 221, end_row = 2, end_vcol = 41 })
      )
      eq(
        { all = 11, fill = 0 },
        api.nvim_win_text_height(0, { start_row = 0, start_vcol = 220, end_row = 2, end_vcol = 42 })
      )
    end)
  end)

  describe('open_win', function()
    it('noautocmd option works', function()
      command('autocmd BufEnter,BufLeave,BufWinEnter * let g:fired = 1')
      api.nvim_open_win(api.nvim_create_buf(true, true), true, {
        relative = 'win',
        row = 3,
        col = 3,
        width = 12,
        height = 3,
        noautocmd = true,
      })
      eq(0, fn.exists('g:fired'))
      api.nvim_open_win(api.nvim_create_buf(true, true), true, {
        relative = 'win',
        row = 3,
        col = 3,
        width = 12,
        height = 3,
      })
      eq(1, fn.exists('g:fired'))
    end)

    it('disallowed in cmdwin if enter=true or buf=cmdwin_buf', function()
      local new_buf = api.nvim_create_buf(true, true)
      feed('q:')
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_open_win, new_buf, true, {
          relative = 'editor',
          row = 5,
          col = 5,
          width = 5,
          height = 5,
        })
      )
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_open_win, 0, false, {
          relative = 'editor',
          row = 5,
          col = 5,
          width = 5,
          height = 5,
        })
      )
      matches(
        'E11: Invalid in command%-line window; <CR> executes, CTRL%-C quits$',
        pcall_err(
          exec_lua,
          [[
           local cmdwin_buf = vim.api.nvim_get_current_buf()
           vim.api.nvim_buf_call(vim.api.nvim_create_buf(false, true), function()
             vim.api.nvim_open_win(cmdwin_buf, false, {
               relative='editor', row=5, col=5, width=5, height=5,
             })
           end)
         ]]
        )
      )

      eq(
        new_buf,
        api.nvim_win_get_buf(api.nvim_open_win(new_buf, false, {
          relative = 'editor',
          row = 5,
          col = 5,
          width = 5,
          height = 5,
        }))
      )
    end)

    it('aborts if buffer is invalid', function()
      local wins_before = api.nvim_list_wins()
      eq(
        'Invalid buffer id: 1337',
        pcall_err(api.nvim_open_win, 1337, false, {
          relative = 'editor',
          row = 5,
          col = 5,
          width = 5,
          height = 5,
        })
      )
      eq(wins_before, api.nvim_list_wins())
    end)

    it('creates a split window', function()
      local win = api.nvim_open_win(0, true, {
        vertical = false,
      })
      eq('', api.nvim_win_get_config(win).relative)
    end)

    it('creates split windows in the correct direction', function()
      local initial_win = api.nvim_get_current_win()
      local win = api.nvim_open_win(0, true, {
        vertical = true,
      })
      eq('', api.nvim_win_get_config(win).relative)

      local layout = fn.winlayout()

      eq({
        'row',
        {
          { 'leaf', win },
          { 'leaf', initial_win },
        },
      }, layout)
    end)

    it("respects the 'split' option", function()
      local initial_win = api.nvim_get_current_win()
      local win = api.nvim_open_win(0, true, {
        split = 'below',
      })
      eq('', api.nvim_win_get_config(win).relative)

      local layout = fn.winlayout()

      eq({
        'col',
        {
          { 'leaf', initial_win },
          { 'leaf', win },
        },
      }, layout)
    end)

    it(
      "doesn't change tp_curwin when splitting window in non-current tab with enter=false",
      function()
        local tab1 = api.nvim_get_current_tabpage()
        local tab1_win = api.nvim_get_current_win()

        helpers.command('tabnew')
        local tab2 = api.nvim_get_current_tabpage()
        local tab2_win = api.nvim_get_current_win()

        eq({ tab1_win, tab2_win }, api.nvim_list_wins())
        eq({ tab1, tab2 }, api.nvim_list_tabpages())

        api.nvim_set_current_tabpage(tab1)
        eq(tab1_win, api.nvim_get_current_win())

        local tab2_prevwin = fn.tabpagewinnr(tab2, '#')

        -- split in tab2 whine in tab2, with enter = false
        local tab2_win2 = api.nvim_open_win(api.nvim_create_buf(false, true), false, {
          win = tab2_win,
          split = 'right',
        })
        eq(tab1_win, api.nvim_get_current_win()) -- we should still be in the first tp
        eq(tab1_win, api.nvim_tabpage_get_win(tab1))

        eq(tab2_win, api.nvim_tabpage_get_win(tab2)) -- tab2's tp_curwin should not have changed
        eq(tab2_prevwin, fn.tabpagewinnr(tab2, '#')) -- tab2's tp_prevwin should not have changed
        eq({ tab1_win, tab2_win, tab2_win2 }, api.nvim_list_wins())
        eq({ tab2_win, tab2_win2 }, api.nvim_tabpage_list_wins(tab2))
      end
    )

    it('creates splits in the correct location', function()
      local first_win = api.nvim_get_current_win()
      -- specifying window 0 should create a split next to the current window
      local win = api.nvim_open_win(0, true, {
        vertical = false,
      })
      local layout = fn.winlayout()
      eq({
        'col',
        {
          { 'leaf', win },
          { 'leaf', first_win },
        },
      }, layout)
      -- not specifying a window should create a top-level split
      local win2 = api.nvim_open_win(0, true, {
        split = 'left',
        win = -1,
      })
      layout = fn.winlayout()
      eq({
        'row',
        {
          { 'leaf', win2 },
          {
            'col',
            {
              { 'leaf', win },
              { 'leaf', first_win },
            },
          },
        },
      }, layout)

      -- specifying a window should create a split next to that window
      local win3 = api.nvim_open_win(0, true, {
        win = win,
        vertical = false,
      })
      layout = fn.winlayout()
      eq({
        'row',
        {
          { 'leaf', win2 },
          {
            'col',
            {
              { 'leaf', win3 },
              { 'leaf', win },
              { 'leaf', first_win },
            },
          },
        },
      }, layout)
    end)
  end)

  describe('set_config', function()
    it('moves a split into a float', function()
      local win = api.nvim_open_win(0, true, {
        vertical = false,
      })
      eq('', api.nvim_win_get_config(win).relative)
      api.nvim_win_set_config(win, {
        relative = 'editor',
        row = 5,
        col = 5,
        width = 5,
        height = 5,
      })
      eq('editor', api.nvim_win_get_config(win).relative)
    end)

    it('throws error when attempting to move the last window', function()
      local err = pcall_err(api.nvim_win_set_config, 0, {
        vertical = false,
      })
      eq('Cannot move last window', err)
    end)

    it('passing retval of get_config results in no-op', function()
      -- simple split layout
      local win = api.nvim_open_win(0, true, {
        split = 'left',
      })
      local layout = fn.winlayout()
      local config = api.nvim_win_get_config(win)
      api.nvim_win_set_config(win, config)
      eq(layout, fn.winlayout())

      -- nested split layout
      local win2 = api.nvim_open_win(0, true, {
        vertical = true,
      })
      local win3 = api.nvim_open_win(0, true, {
        win = win2,
        vertical = false,
      })
      layout = fn.winlayout()
      config = api.nvim_win_get_config(win2)
      api.nvim_win_set_config(win2, config)
      eq(layout, fn.winlayout())

      config = api.nvim_win_get_config(win3)
      api.nvim_win_set_config(win3, config)
      eq(layout, fn.winlayout())
    end)

    it('moves a float into a split', function()
      local layout = fn.winlayout()
      eq('leaf', layout[1])
      local win = api.nvim_open_win(0, true, {
        relative = 'editor',
        row = 5,
        col = 5,
        width = 5,
        height = 5,
      })
      api.nvim_win_set_config(win, {
        split = 'below',
        win = -1,
      })
      eq('', api.nvim_win_get_config(win).relative)
      layout = fn.winlayout()
      eq('col', layout[1])
      eq(2, #layout[2])
      eq(win, layout[2][2][2])
    end)

    it('respects the "split" option', function()
      local layout = fn.winlayout()
      eq('leaf', layout[1])
      local first_win = layout[2]
      local win = api.nvim_open_win(0, true, {
        relative = 'editor',
        row = 5,
        col = 5,
        width = 5,
        height = 5,
      })
      api.nvim_win_set_config(win, {
        split = 'right',
        win = first_win,
      })
      layout = fn.winlayout()
      eq('row', layout[1])
      eq(2, #layout[2])
      eq(win, layout[2][2][2])
      local config = api.nvim_win_get_config(win)
      eq('', config.relative)
      eq('right', config.split)
      api.nvim_win_set_config(win, {
        split = 'below',
        win = first_win,
      })
      layout = fn.winlayout()
      eq('col', layout[1])
      eq(2, #layout[2])
      eq(win, layout[2][2][2])
      config = api.nvim_win_get_config(win)
      eq('', config.relative)
      eq('below', config.split)
    end)

    it('creates top-level splits', function()
      local win = api.nvim_open_win(0, true, {
        vertical = false,
      })
      local win2 = api.nvim_open_win(0, true, {
        vertical = true,
        win = -1,
      })
      local layout = fn.winlayout()
      eq('row', layout[1])
      eq(2, #layout[2])
      eq(win2, layout[2][1][2])
      api.nvim_win_set_config(win, {
        split = 'below',
        win = -1,
      })
      layout = fn.winlayout()
      eq('col', layout[1])
      eq(2, #layout[2])
      eq('row', layout[2][1][1])
      eq(win, layout[2][2][2])
    end)

    it('moves splits to other tabpages', function()
      local curtab = api.nvim_get_current_tabpage()
      local win = api.nvim_open_win(0, false, { split = 'left' })
      command('tabnew')
      local tabnr = api.nvim_get_current_tabpage()
      command('tabprev') -- return to the initial tab

      api.nvim_win_set_config(win, {
        split = 'right',
        win = api.nvim_tabpage_get_win(tabnr),
      })

      eq(tabnr, api.nvim_win_get_tabpage(win))
      -- we are changing the config, the current tabpage should not change
      eq(curtab, api.nvim_get_current_tabpage())

      command('tabnext') -- switch to the new tabpage so we can get the layout
      local layout = fn.winlayout()

      eq({
        'row',
        {
          { 'leaf', api.nvim_tabpage_get_win(tabnr) },
          { 'leaf', win },
        },
      }, layout)
    end)

    it('correctly moves curwin when moving curwin to a different tabpage', function()
      local curtab = api.nvim_get_current_tabpage()
      command('tabnew')
      local tab2 = api.nvim_get_current_tabpage()
      local tab2_win = api.nvim_get_current_win()

      command('tabprev') -- return to the initial tab

      local neighbor = api.nvim_get_current_win()

      -- create and enter a new split
      local win = api.nvim_open_win(0, true, {
        vertical = false,
      })

      eq(curtab, api.nvim_win_get_tabpage(win))

      eq({ win, neighbor }, api.nvim_tabpage_list_wins(curtab))

      -- move the current win to a different tabpage
      api.nvim_win_set_config(win, {
        split = 'right',
        win = api.nvim_tabpage_get_win(tab2),
      })

      eq(curtab, api.nvim_get_current_tabpage())

      -- win should have moved to tab2
      eq(tab2, api.nvim_win_get_tabpage(win))
      -- tp_curwin of tab2 should not have changed
      eq(tab2_win, api.nvim_tabpage_get_win(tab2))
      -- win lists should be correct
      eq({ tab2_win, win }, api.nvim_tabpage_list_wins(tab2))
      eq({ neighbor }, api.nvim_tabpage_list_wins(curtab))

      -- current win should have moved to neighboring win
      eq(neighbor, api.nvim_tabpage_get_win(curtab))
    end)

    it('splits windows in non-current tabpage', function()
      local curtab = api.nvim_get_current_tabpage()
      command('tabnew')
      local tabnr = api.nvim_get_current_tabpage()
      command('tabprev') -- return to the initial tab

      local win = api.nvim_open_win(0, false, {
        vertical = false,
        win = api.nvim_tabpage_get_win(tabnr),
      })

      eq(tabnr, api.nvim_win_get_tabpage(win))
      -- since enter = false, the current tabpage should not change
      eq(curtab, api.nvim_get_current_tabpage())
    end)

    it('moves the current split window', function()
      local initial_win = api.nvim_get_current_win()
      local win = api.nvim_open_win(0, true, {
        vertical = true,
      })
      local win2 = api.nvim_open_win(0, true, {
        vertical = true,
      })
      api.nvim_set_current_win(win)
      eq({
        'row',
        {
          { 'leaf', win2 },
          { 'leaf', win },
          { 'leaf', initial_win },
        },
      }, fn.winlayout())

      api.nvim_win_set_config(0, {
        vertical = false,
        win = 0,
      })
      eq(win, api.nvim_get_current_win())
      eq({
        'col',
        {
          { 'leaf', win },
          {
            'row',
            {
              { 'leaf', win2 },
              { 'leaf', initial_win },
            },
          },
        },
      }, fn.winlayout())

      api.nvim_set_current_win(win2)
      local win3 = api.nvim_open_win(0, true, {
        vertical = true,
      })
      eq(win3, api.nvim_get_current_win())

      eq({
        'col',
        {
          { 'leaf', win },
          {
            'row',
            {
              { 'leaf', win3 },
              { 'leaf', win2 },
              { 'leaf', initial_win },
            },
          },
        },
      }, fn.winlayout())

      api.nvim_win_set_config(0, {
        vertical = false,
        win = 0,
      })

      eq(win3, api.nvim_get_current_win())
      eq({
        'col',
        {
          { 'leaf', win },
          {
            'row',
            {
              {
                'col',
                {
                  { 'leaf', win3 },
                  { 'leaf', win2 },
                },
              },
              { 'leaf', initial_win },
            },
          },
        },
      }, fn.winlayout())
    end)
  end)

  describe('get_config', function()
    it('includes border', function()
      local b = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' }
      local win = api.nvim_open_win(0, true, {
        relative = 'win',
        row = 3,
        col = 3,
        width = 12,
        height = 3,
        border = b,
      })

      local cfg = api.nvim_win_get_config(win)
      eq(b, cfg.border)
    end)

    it('includes border with highlight group', function()
      local b = {
        { 'a', 'Normal' },
        { 'b', 'Special' },
        { 'c', 'String' },
        { 'd', 'Comment' },
        { 'e', 'Visual' },
        { 'f', 'Error' },
        { 'g', 'Constant' },
        { 'h', 'PreProc' },
      }
      local win = api.nvim_open_win(0, true, {
        relative = 'win',
        row = 3,
        col = 3,
        width = 12,
        height = 3,
        border = b,
      })

      local cfg = api.nvim_win_get_config(win)
      eq(b, cfg.border)
    end)

    it('includes title and footer', function()
      local title = { { 'A', { 'StatusLine', 'TabLine' } }, { 'B' }, { 'C', 'WinBar' } }
      local footer = { { 'A', 'WinBar' }, { 'B' }, { 'C', { 'StatusLine', 'TabLine' } } }
      local win = api.nvim_open_win(0, true, {
        relative = 'win',
        row = 3,
        col = 3,
        width = 12,
        height = 3,
        border = 'single',
        title = title,
        footer = footer,
      })

      local cfg = api.nvim_win_get_config(win)
      eq(title, cfg.title)
      eq(footer, cfg.footer)
    end)

    it('includes split for normal windows', function()
      local win = api.nvim_open_win(0, true, {
        vertical = true,
        win = -1,
      })
      eq('left', api.nvim_win_get_config(win).split)
      api.nvim_win_set_config(win, {
        vertical = false,
        win = -1,
      })
      eq('above', api.nvim_win_get_config(win).split)
      api.nvim_win_set_config(win, {
        split = 'below',
        win = -1,
      })
      eq('below', api.nvim_win_get_config(win).split)
    end)

    it('includes split when splitting with ex commands', function()
      local win = api.nvim_get_current_win()
      eq('left', api.nvim_win_get_config(win).split)

      command('vsplit')
      local win2 = api.nvim_get_current_win()

      -- initial window now be marked as right split
      -- since it was split with a vertical split
      -- and 'splitright' is false by default
      eq('right', api.nvim_win_get_config(win).split)
      eq('left', api.nvim_win_get_config(win2).split)

      api.nvim_set_option_value('splitbelow', true, {
        scope = 'global',
      })
      api.nvim_win_close(win, true)
      command('split')
      local win3 = api.nvim_get_current_win()
      eq('below', api.nvim_win_get_config(win3).split)
    end)

    it("includes the correct 'split' option in complex layouts", function()
      local initial_win = api.nvim_get_current_win()
      local win = api.nvim_open_win(0, false, {
        split = 'right',
        win = -1,
      })

      local win2 = api.nvim_open_win(0, false, {
        split = 'below',
        win = win,
      })

      api.nvim_win_set_config(win2, {
        width = 50,
      })

      api.nvim_win_set_config(win, {
        split = 'left',
        win = -1,
      })

      local win3 = api.nvim_open_win(0, false, {
        split = 'above',
        win = -1,
      })
      local float = api.nvim_open_win(0, false, {
        relative = 'editor',
        width = 40,
        height = 20,
        col = 20,
        row = 10,
      })
      api.nvim_win_set_config(float, {
        split = 'right',
        win = -1,
      })

      local layout = fn.winlayout()

      eq({
        'row',
        {
          {
            'col',
            {
              { 'leaf', win3 },
              {
                'row',
                {
                  { 'leaf', win },
                  { 'leaf', initial_win },
                  { 'leaf', win2 },
                },
              },
            },
          },
          {
            'leaf',
            float,
          },
        },
      }, layout)

      eq('above', api.nvim_win_get_config(win3).split)
      eq('left', api.nvim_win_get_config(win).split)
      eq('left', api.nvim_win_get_config(initial_win).split)
      eq('right', api.nvim_win_get_config(win2).split)
      eq('right', api.nvim_win_get_config(float).split)
    end)
  end)

  describe('set_config', function()
    it('no crash with invalid title', function()
      local win = api.nvim_open_win(0, true, {
        width = 10,
        height = 10,
        relative = 'editor',
        row = 10,
        col = 10,
        title = { { 'test' } },
        border = 'single',
      })
      eq(
        'title/footer cannot be an empty array',
        pcall_err(api.nvim_win_set_config, win, { title = {} })
      )
      command('redraw!')
      assert_alive()
    end)

    it('no crash with invalid footer', function()
      local win = api.nvim_open_win(0, true, {
        width = 10,
        height = 10,
        relative = 'editor',
        row = 10,
        col = 10,
        footer = { { 'test' } },
        border = 'single',
      })
      eq(
        'title/footer cannot be an empty array',
        pcall_err(api.nvim_win_set_config, win, { footer = {} })
      )
      command('redraw!')
      assert_alive()
    end)
  end)

  describe('set_config', function()
    it('no crash with invalid title', function()
      local win = api.nvim_open_win(0, true, {
        width = 10,
        height = 10,
        relative = 'editor',
        row = 10,
        col = 10,
        title = { { 'test' } },
        border = 'single',
      })
      eq(
        'title/footer cannot be an empty array',
        pcall_err(api.nvim_win_set_config, win, { title = {} })
      )
      command('redraw!')
      assert_alive()
    end)

    it('no crash with invalid footer', function()
      local win = api.nvim_open_win(0, true, {
        width = 10,
        height = 10,
        relative = 'editor',
        row = 10,
        col = 10,
        footer = { { 'test' } },
        border = 'single',
      })
      eq(
        'title/footer cannot be an empty array',
        pcall_err(api.nvim_win_set_config, win, { footer = {} })
      )
      command('redraw!')
      assert_alive()
    end)
  end)
end)
