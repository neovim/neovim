local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, curbuf, curbuf_contents, curwin, eq, neq, matches, ok, feed, insert, eval =
  n.clear,
  n.api.nvim_get_current_buf,
  n.curbuf_contents,
  n.api.nvim_get_current_win,
  t.eq,
  t.neq,
  t.matches,
  t.ok,
  n.feed,
  n.insert,
  n.eval
local poke_eventloop = n.poke_eventloop
local exec = n.exec
local exec_lua = n.exec_lua
local fn = n.fn
local request = n.request
local NIL = vim.NIL
local api = n.api
local command = n.command
local pcall_err = t.pcall_err
local assert_alive = n.assert_alive

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
           vim._with({buf = new_buf}, function()
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
           vim._with({win = new_win}, function()
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

    describe("with 'autochdir'", function()
      local topdir
      local otherbuf
      local oldwin
      local newwin

      before_each(function()
        command('set shellslash')
        topdir = fn.getcwd()
        t.mkdir(topdir .. '/Xacd')
        t.mkdir(topdir .. '/Xacd/foo')
        otherbuf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_name(otherbuf, topdir .. '/Xacd/baz.txt')

        command('set autochdir')
        command('edit Xacd/foo/bar.txt')
        eq(topdir .. '/Xacd/foo', fn.getcwd())

        oldwin = api.nvim_get_current_win()
        command('vsplit')
        newwin = api.nvim_get_current_win()
      end)

      after_each(function()
        n.rmdir(topdir .. '/Xacd')
      end)

      it('does not change cwd with non-current window', function()
        api.nvim_win_set_buf(oldwin, otherbuf)
        eq(topdir .. '/Xacd/foo', fn.getcwd())
      end)

      it('changes cwd with current window', function()
        api.nvim_win_set_buf(newwin, otherbuf)
        eq(topdir .. '/Xacd', fn.getcwd())
      end)
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
        {3:[No Name]                     }|
        prologue                      |
                                      |*2
        {2:[No Name] [+]                 }|
                                      |
      ]],
      }

      -- move cursor to end
      api.nvim_win_set_cursor(win, { 101, 0 })
      screen:expect {
        grid = [[
        ^                              |
        {1:~                             }|*2
        {3:[No Name]                     }|
                                      |*2
        epilogue                      |
        {2:[No Name] [+]                 }|
                                      |
      ]],
      }

      -- move cursor to the beginning again
      api.nvim_win_set_cursor(win, { 1, 0 })
      screen:expect {
        grid = [[
        ^                              |
        {1:~                             }|*2
        {3:[No Name]                     }|
        prologue                      |
                                      |*2
        {2:[No Name] [+]                 }|
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
        {21:dd^d                           }│{21:ddd                          }|
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]  4,3         All }{2:[No Name] [+]  4,3        All}|
                                                                    |
      ]])
      api.nvim_win_set_cursor(oldwin, { 1, 0 })
      screen:expect([[
        aaa                           │{21:aaa                          }|
        bbb                           │bbb                          |
        ccc                           │ccc                          |
        {21:dd^d                           }│ddd                          |
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]  4,3         All }{2:[No Name] [+]  1,1        All}|
                                                                    |
      ]])
    end)

    it('updates cursorcolumn in non-current window', function()
      local screen = Screen.new(60, 8)
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
        aa{21:a}                           │aa{21:a}                          |
        bb{21:b}                           │bb{21:b}                          |
        cc{21:c}                           │cc{21:c}                          |
        dd^d                           │ddd                          |
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]                  }{2:[No Name] [+]                }|
                                                                    |
      ]])
      api.nvim_win_set_cursor(oldwin, { 2, 0 })
      screen:expect([[
        aa{21:a}                           │{21:a}aa                          |
        bb{21:b}                           │bbb                          |
        cc{21:c}                           │{21:c}cc                          |
        dd^d                           │{21:d}dd                          |
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]                  }{2:[No Name] [+]                }|
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
        vim._with({win = ...}, function()
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
        vim._with({win = otherwin}, function()
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
        vim._with({win = ...}, function()
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
        vim._with({win = otherwin}, function()
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
        {7:  }{8:    }{23:----------------}│{7:  }{8:  1 }{22:00000001!       }|
        {7:  }{8:    }{23:----------------}│{7:  }{8:  2 }{22:00000002!!      }|
        {7:  }{8:  1 }00000003!!!     │{7:  }{8:  3 }00000003!!!     |
        {7:  }{8:  2 }00000004!!!!    │{7:  }{8:  4 }00000004!!!!    |
        {7:+ }{8:  3 }{13:+-- 14 lines: 00}│{7:+ }{8:  5 }{13:+-- 14 lines: 00}|
        {7:  }{8: 17 }00000019!!!!!!!!│{7:  }{8: 19 }00000019!!!!!!!!|
        {7:  }{8: 18 }00000020!!!!!!!!│{7:  }{8: 20 }00000020!!!!!!!!|
        {7:  }{8:    }{23:----------------}│{7:  }{8: 21 }{22:00000025!!!!!!!!}|
        {7:  }{8:    }{23:----------------}│{7:  }{8: 22 }{22:00000026!!!!!!!!}|
        {7:  }{8:    }{23:----------------}│{7:  }{8: 23 }{22:00000027!!!!!!!!}|
        {7:  }{8: 19 }00000028!!!!!!!!│{7:  }{8: 24 }^00000028!!!!!!!!|
        {7:  }{8: 20 }00000029!!!!!!!!│{7:  }{8: 25 }00000029!!!!!!!!|
        {7:+ }{8: 21 }{13:+-- 14 lines: 00}│{7:+ }{8: 26 }{13:+-- 14 lines: 00}|
        {7:  }{8: 35 }00000044!!!!!!!!│{7:  }{8: 40 }00000044!!!!!!!!|
        {7:  }{8: 36 }00000045!!!!!!!!│{7:  }{8: 41 }00000045!!!!!!!!|
        {7:  }{8: 37 }{22:00000046!!!!!!!!}│{7:  }{8:    }{23:----------------}|
        {7:  }{8: 38 }{22:00000047!!!!!!!!}│{7:  }{8:    }{23:----------------}|
        {7:  }{8: 39 }{22:00000048!!!!!!!!}│{7:  }{8:    }{23:----------------}|
        {7:  }{8: 40 }{22:00000049!!!!!!!!}│{7:  }{8:    }{23:----------------}|
        {7:  }{8: 41 }{22:00000050!!!!!!!!}│{7:  }{8:    }{23:----------------}|
        {2:[No Name] [+]          }{3:[No Name] [+]         }|
                                                     |
      ]],
      }
      screen:try_resize(45, 3)
      screen:expect {
        grid = [[
        {7:  }{8: 19 }00000028!!!!!!!!│{7:  }{8: 24 }^00000028!!!!!!!!|
        {2:[No Name] [+]          }{3:[No Name] [+]         }|
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
        {8:  1 }^foobar-foobar-foobar-foobar-foobar-foobar|
        -foobar-foobar-foobar-foobar-foobar-foobar-fo|
        obar-foobar-foobar-foobar-foobar-foobar-fooba|
        r-foobar-foobar-foobar-foobar-foobar-foobar-f|
        oobar-foobar-foobar-foobar-foobar-foobar-foob|
        ar-foobar-foobar-foobar-foobar-              |
        {8:  2 }foobar-foobar-foobar-foobar-foobar-foobar|
        -foobar-foobar-foobar-foobar-foobar-foobar-fo|
        obar-foobar-fo{10:???????????????}obar-foobar-foob|
        ar-foobar-foobar-foobar-foobar-foobar-foobar-|
        foobar-foobar-foobar-foobar-foobar-foobar-foo|
        bar-foobar-foobar-foobar-foobar-foobar-foobar|
        -                                            |
        {8:  3 }foobar-foobar-foobar-foobar-foobar-foobar|
        -foobar-foobar-foobar-foobar-foobar-foobar-fo|
        obar-foobar-foobar-foobar-foobar-foobar-fooba|
        r-foobar-foobar-foobar-foobar-foobar-foobar-f|
        oobar-foobar-foobar-foob{10:!!!!!!!!!!!!!!!!!!!!!}|
        {10:!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!}|
        {10:!!!!!!!!!}ar-foobar-foobar-foobar-foobar-fooba|
        r-foobar-foobar-                             |
                                                     |
      ]],
      }
      screen:try_resize(45, 2)
      screen:expect {
        grid = [[
        {8:  1 }^foobar-foobar-foobar-foobar-foobar-foobar|
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
           vim._with({buf = vim.api.nvim_create_buf(false, true)}, function()
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

    describe('creates a split window above', function()
      local function test_open_win_split_above(key, val)
        local initial_win = api.nvim_get_current_win()
        local win = api.nvim_open_win(0, true, {
          [key] = val,
          height = 10,
        })
        eq('', api.nvim_win_get_config(win).relative)
        eq(10, api.nvim_win_get_height(win))
        local layout = fn.winlayout()
        eq({
          'col',
          {
            { 'leaf', win },
            { 'leaf', initial_win },
          },
        }, layout)
      end

      it("with split = 'above'", function()
        test_open_win_split_above('split', 'above')
      end)

      it("with vertical = false and 'nosplitbelow'", function()
        api.nvim_set_option_value('splitbelow', false, {})
        test_open_win_split_above('vertical', false)
      end)
    end)

    describe('creates a split window below', function()
      local function test_open_win_split_below(key, val)
        local initial_win = api.nvim_get_current_win()
        local win = api.nvim_open_win(0, true, {
          [key] = val,
          height = 15,
        })
        eq('', api.nvim_win_get_config(win).relative)
        eq(15, api.nvim_win_get_height(win))
        local layout = fn.winlayout()
        eq({
          'col',
          {
            { 'leaf', initial_win },
            { 'leaf', win },
          },
        }, layout)
      end

      it("with split = 'below'", function()
        test_open_win_split_below('split', 'below')
      end)

      it("with vertical = false and 'splitbelow'", function()
        api.nvim_set_option_value('splitbelow', true, {})
        test_open_win_split_below('vertical', false)
      end)
    end)

    describe('creates a split window to the left', function()
      local function test_open_win_split_left(key, val)
        local initial_win = api.nvim_get_current_win()
        local win = api.nvim_open_win(0, true, {
          [key] = val,
          width = 25,
        })
        eq('', api.nvim_win_get_config(win).relative)
        eq(25, api.nvim_win_get_width(win))
        local layout = fn.winlayout()
        eq({
          'row',
          {
            { 'leaf', win },
            { 'leaf', initial_win },
          },
        }, layout)
      end

      it("with split = 'left'", function()
        test_open_win_split_left('split', 'left')
      end)

      it("with vertical = true and 'nosplitright'", function()
        api.nvim_set_option_value('splitright', false, {})
        test_open_win_split_left('vertical', true)
      end)
    end)

    describe('creates a split window to the right', function()
      local function test_open_win_split_right(key, val)
        local initial_win = api.nvim_get_current_win()
        local win = api.nvim_open_win(0, true, {
          [key] = val,
          width = 30,
        })
        eq('', api.nvim_win_get_config(win).relative)
        eq(30, api.nvim_win_get_width(win))
        local layout = fn.winlayout()
        eq({
          'row',
          {
            { 'leaf', initial_win },
            { 'leaf', win },
          },
        }, layout)
      end

      it("with split = 'right'", function()
        test_open_win_split_right('split', 'right')
      end)

      it("with vertical = true and 'splitright'", function()
        api.nvim_set_option_value('splitright', true, {})
        test_open_win_split_right('vertical', true)
      end)
    end)

    it("doesn't change tp_curwin when splitting window in another tab with enter=false", function()
      local tab1 = api.nvim_get_current_tabpage()
      local tab1_win = api.nvim_get_current_win()

      n.command('tabnew')
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
    end)

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

    it('opens floating windows in other tabpages', function()
      local first_win = api.nvim_get_current_win()
      local first_tab = api.nvim_get_current_tabpage()

      command('tabnew')
      local new_tab = api.nvim_get_current_tabpage()
      local win = api.nvim_open_win(0, false, {
        relative = 'win',
        win = first_win,
        width = 5,
        height = 5,
        row = 1,
        col = 1,
      })
      eq(api.nvim_win_get_tabpage(win), first_tab)
      eq(api.nvim_get_current_tabpage(), new_tab)
    end)

    it('switches to new windows in non-current tabpages when enter=true', function()
      local first_win = api.nvim_get_current_win()
      local first_tab = api.nvim_get_current_tabpage()
      command('tabnew')
      local win = api.nvim_open_win(0, true, {
        relative = 'win',
        win = first_win,
        width = 5,
        height = 5,
        row = 1,
        col = 1,
      })
      eq(api.nvim_win_get_tabpage(win), first_tab)
      eq(api.nvim_get_current_tabpage(), first_tab)
    end)

    local function setup_tabbed_autocmd_test()
      local info = {}
      info.orig_buf = api.nvim_get_current_buf()
      info.other_buf = api.nvim_create_buf(true, true)
      info.tab1_curwin = api.nvim_get_current_win()
      info.tab1 = api.nvim_get_current_tabpage()
      command('tab split | split')
      info.tab2_curwin = api.nvim_get_current_win()
      info.tab2 = api.nvim_get_current_tabpage()
      exec([=[
        tabfirst
        let result = []
        autocmd TabEnter * let result += [["TabEnter", nvim_get_current_tabpage()]]
        autocmd TabLeave * let result += [["TabLeave", nvim_get_current_tabpage()]]
        autocmd WinEnter * let result += [["WinEnter", win_getid()]]
        autocmd WinLeave * let result += [["WinLeave", win_getid()]]
        autocmd WinNew * let result += [["WinNew", win_getid()]]
        autocmd WinClosed * let result += [["WinClosed", str2nr(expand("<afile>"))]]
        autocmd BufEnter * let result += [["BufEnter", win_getid(), bufnr()]]
        autocmd BufLeave * let result += [["BufLeave", win_getid(), bufnr()]]
        autocmd BufWinEnter * let result += [["BufWinEnter", win_getid(), bufnr()]]
        autocmd BufWinLeave * let result += [["BufWinLeave", win_getid(), bufnr()]]
      ]=])
      return info
    end

    it('noautocmd option works', function()
      local info = setup_tabbed_autocmd_test()

      api.nvim_open_win(
        info.other_buf,
        true,
        { split = 'left', win = info.tab2_curwin, noautocmd = true }
      )
      eq({}, eval('result'))

      api.nvim_open_win(
        info.orig_buf,
        true,
        { relative = 'editor', row = 0, col = 0, width = 10, height = 10, noautocmd = true }
      )
      eq({}, eval('result'))
    end)

    it('fires expected autocmds when creating splits without entering', function()
      local info = setup_tabbed_autocmd_test()

      -- For these, don't want BufWinEnter if visiting the same buffer, like :{s}buffer.
      -- Same tabpage, same buffer.
      local new_win = api.nvim_open_win(0, false, { split = 'left', win = info.tab1_curwin })
      eq({
        { 'WinNew', new_win },
      }, eval('result'))
      eq(info.tab1_curwin, api.nvim_get_current_win())

      -- Other tabpage, same buffer.
      command('let result = []')
      new_win = api.nvim_open_win(0, false, { split = 'left', win = info.tab2_curwin })
      eq({
        { 'WinNew', new_win },
      }, eval('result'))
      eq(info.tab1_curwin, api.nvim_get_current_win())

      -- Same tabpage, other buffer.
      command('let result = []')
      new_win = api.nvim_open_win(info.other_buf, false, { split = 'left', win = info.tab1_curwin })
      eq({
        { 'WinNew', new_win },
        { 'BufWinEnter', new_win, info.other_buf },
      }, eval('result'))
      eq(info.tab1_curwin, api.nvim_get_current_win())

      -- Other tabpage, other buffer.
      command('let result = []')
      new_win = api.nvim_open_win(info.other_buf, false, { split = 'left', win = info.tab2_curwin })
      eq({
        { 'WinNew', new_win },
        { 'BufWinEnter', new_win, info.other_buf },
      }, eval('result'))
      eq(info.tab1_curwin, api.nvim_get_current_win())
    end)

    it('fires expected autocmds when creating and entering splits', function()
      local info = setup_tabbed_autocmd_test()

      -- Same tabpage, same buffer.
      local new_win = api.nvim_open_win(0, true, { split = 'left', win = info.tab1_curwin })
      eq({
        { 'WinNew', new_win },
        { 'WinLeave', info.tab1_curwin },
        { 'WinEnter', new_win },
      }, eval('result'))

      -- Same tabpage, other buffer.
      api.nvim_set_current_win(info.tab1_curwin)
      command('let result = []')
      new_win = api.nvim_open_win(info.other_buf, true, { split = 'left', win = info.tab1_curwin })
      eq({
        { 'WinNew', new_win },
        { 'WinLeave', info.tab1_curwin },
        { 'WinEnter', new_win },
        { 'BufLeave', new_win, info.orig_buf },
        { 'BufEnter', new_win, info.other_buf },
        { 'BufWinEnter', new_win, info.other_buf },
      }, eval('result'))

      -- For these, the other tabpage's prevwin and curwin will change like we switched from its old
      -- curwin to the new window, so the extra events near TabEnter reflect that.
      -- Other tabpage, same buffer.
      api.nvim_set_current_win(info.tab1_curwin)
      command('let result = []')
      new_win = api.nvim_open_win(0, true, { split = 'left', win = info.tab2_curwin })
      eq({
        { 'WinNew', new_win },
        { 'WinLeave', info.tab1_curwin },
        { 'TabLeave', info.tab1 },

        { 'WinEnter', info.tab2_curwin },
        { 'TabEnter', info.tab2 },
        { 'WinLeave', info.tab2_curwin },
        { 'WinEnter', new_win },
      }, eval('result'))

      -- Other tabpage, other buffer.
      api.nvim_set_current_win(info.tab2_curwin)
      api.nvim_set_current_win(info.tab1_curwin)
      command('let result = []')
      new_win = api.nvim_open_win(info.other_buf, true, { split = 'left', win = info.tab2_curwin })
      eq({
        { 'WinNew', new_win },
        { 'WinLeave', info.tab1_curwin },
        { 'TabLeave', info.tab1 },

        { 'WinEnter', info.tab2_curwin },
        { 'TabEnter', info.tab2 },
        { 'WinLeave', info.tab2_curwin },
        { 'WinEnter', new_win },

        { 'BufLeave', new_win, info.orig_buf },
        { 'BufEnter', new_win, info.other_buf },
        { 'BufWinEnter', new_win, info.other_buf },
      }, eval('result'))

      -- Other tabpage, other buffer; but other tabpage's curwin has a new buffer active.
      api.nvim_set_current_win(info.tab2_curwin)
      local new_buf = api.nvim_create_buf(true, true)
      api.nvim_set_current_buf(new_buf)
      api.nvim_set_current_win(info.tab1_curwin)
      command('let result = []')
      new_win = api.nvim_open_win(info.other_buf, true, { split = 'left', win = info.tab2_curwin })
      eq({
        { 'WinNew', new_win },
        { 'BufLeave', info.tab1_curwin, info.orig_buf },
        { 'WinLeave', info.tab1_curwin },
        { 'TabLeave', info.tab1 },

        { 'WinEnter', info.tab2_curwin },
        { 'TabEnter', info.tab2 },
        { 'BufEnter', info.tab2_curwin, new_buf },
        { 'WinLeave', info.tab2_curwin },
        { 'WinEnter', new_win },
        { 'BufLeave', new_win, new_buf },
        { 'BufEnter', new_win, info.other_buf },
        { 'BufWinEnter', new_win, info.other_buf },
      }, eval('result'))
    end)

    it('OK when new window is moved to other tabpage by autocommands', function()
      -- Use nvim_win_set_config in the autocommands, as other methods of moving a window to a
      -- different tabpage (e.g: wincmd T) actually creates a new window.
      local tab0 = api.nvim_get_current_tabpage()
      local tab0_win = api.nvim_get_current_win()
      command('tabnew')
      local new_buf = api.nvim_create_buf(true, true)
      local tab1 = api.nvim_get_current_tabpage()
      local tab1_parent = api.nvim_get_current_win()
      command(
        'tabfirst | autocmd WinNew * ++once call nvim_win_set_config(0, #{split: "left", win: '
          .. tab1_parent
          .. '})'
      )
      local new_win = api.nvim_open_win(new_buf, true, { split = 'left' })
      eq(tab1, api.nvim_get_current_tabpage())
      eq(new_win, api.nvim_get_current_win())
      eq(new_buf, api.nvim_get_current_buf())

      -- nvim_win_set_config called after entering. It doesn't follow a curwin that is moved to a
      -- different tabpage, but instead moves to the win filling the space, which is tab0_win.
      command(
        'tabfirst | autocmd WinEnter * ++once call nvim_win_set_config(0, #{split: "left", win: '
          .. tab1_parent
          .. '})'
      )
      new_win = api.nvim_open_win(new_buf, true, { split = 'left' })
      eq(tab0, api.nvim_get_current_tabpage())
      eq(tab0_win, api.nvim_get_current_win())
      eq(tab1, api.nvim_win_get_tabpage(new_win))
      eq(new_buf, api.nvim_win_get_buf(new_win))

      command(
        'tabfirst | autocmd BufEnter * ++once call nvim_win_set_config(0, #{split: "left", win: '
          .. tab1_parent
          .. '})'
      )
      new_win = api.nvim_open_win(new_buf, true, { split = 'left' })
      eq(tab0, api.nvim_get_current_tabpage())
      eq(tab0_win, api.nvim_get_current_win())
      eq(tab1, api.nvim_win_get_tabpage(new_win))
      eq(new_buf, api.nvim_win_get_buf(new_win))
    end)

    it('does not fire BufWinEnter if win_set_buf fails', function()
      exec([[
        set nohidden modified
        autocmd WinNew * ++once only!
        let fired = v:false
        autocmd BufWinEnter * ++once let fired = v:true
      ]])
      eq(
        'Failed to set buffer 2',
        pcall_err(api.nvim_open_win, api.nvim_create_buf(true, true), false, { split = 'left' })
      )
      eq(false, eval('fired'))
    end)

    it('fires Buf* autocommands when `!enter` if window is entered via autocommands', function()
      exec([[
        autocmd WinNew * ++once only!
        let fired = v:false
        autocmd BufEnter * ++once let fired = v:true
      ]])
      api.nvim_open_win(api.nvim_create_buf(true, true), false, { split = 'left' })
      eq(true, eval('fired'))
    end)

    it('no heap-use-after-free if target buffer deleted by autocommands', function()
      local cur_buf = api.nvim_get_current_buf()
      local new_buf = api.nvim_create_buf(true, true)
      command('autocmd WinNew * ++once call nvim_buf_delete(' .. new_buf .. ', #{force: 1})')
      api.nvim_open_win(new_buf, true, { split = 'left' })
      eq(cur_buf, api.nvim_get_current_buf())
    end)

    it('checks if splitting disallowed', function()
      command('split | autocmd WinEnter * ++once call nvim_open_win(0, 0, #{split: "right"})')
      matches("E242: Can't split a window while closing another$", pcall_err(command, 'quit'))

      command('only | autocmd BufHidden * ++once call nvim_open_win(0, 0, #{split: "left"})')
      matches(
        'E1159: Cannot split a window when closing the buffer$',
        pcall_err(command, 'new | quit')
      )

      local w = api.nvim_get_current_win()
      command(
        'only | new | autocmd BufHidden * ++once call nvim_open_win(0, 0, #{split: "left", win: '
          .. w
          .. '})'
      )
      matches(
        'E1159: Cannot split a window when closing the buffer$',
        pcall_err(api.nvim_win_close, w, true)
      )

      -- OK when using window to different buffer than `win`s.
      w = api.nvim_get_current_win()
      command(
        'only | autocmd BufHidden * ++once call nvim_open_win(0, 0, #{split: "left", win: '
          .. w
          .. '})'
      )
      command('new | quit')
    end)

    it('restores last known cursor position if BufWinEnter did not move it', function()
      -- This test mostly exists to ensure BufWinEnter is executed before enter_buffer's epilogue.
      local buf = api.nvim_get_current_buf()
      insert([[
        foo
        bar baz .etc
        i love autocommand bugs!
        supercalifragilisticexpialidocious
        marvim is actually a human
        llanfairpwllgwyngyllgogerychwyrndrobwllllantysiliogogogoch
      ]])
      api.nvim_win_set_cursor(0, { 5, 2 })
      command('set nostartofline | enew')
      local new_win = api.nvim_open_win(buf, false, { split = 'left' })
      eq({ 5, 2 }, api.nvim_win_get_cursor(new_win))

      exec([[
        only!
        autocmd BufWinEnter * ++once normal! j6l
      ]])
      new_win = api.nvim_open_win(buf, false, { split = 'left' })
      eq({ 2, 6 }, api.nvim_win_get_cursor(new_win))
    end)

    it('does not block all win_set_buf autocommands if !enter and !noautocmd', function()
      local new_buf = fn.bufadd('foobarbaz')
      exec([[
        let triggered = ""
        autocmd BufReadCmd * ++once let triggered = bufname()
      ]])
      api.nvim_open_win(new_buf, false, { split = 'left' })
      eq('foobarbaz', eval('triggered'))
    end)

    it('sets error when no room', function()
      matches('E36: Not enough room$', pcall_err(command, 'execute "split|"->repeat(&lines)'))
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_open_win, 0, true, { split = 'above', win = 0 })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_open_win, 0, true, { split = 'below', win = 0 })
      )
    end)

    describe("with 'autochdir'", function()
      local topdir
      local otherbuf

      before_each(function()
        command('set shellslash')
        topdir = fn.getcwd()
        t.mkdir(topdir .. '/Xacd')
        t.mkdir(topdir .. '/Xacd/foo')
        otherbuf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_name(otherbuf, topdir .. '/Xacd/baz.txt')

        command('set autochdir')
        command('edit Xacd/foo/bar.txt')
        eq(topdir .. '/Xacd/foo', fn.getcwd())
      end)

      after_each(function()
        n.rmdir(topdir .. '/Xacd')
      end)

      it('does not change cwd with enter=false #15280', function()
        api.nvim_open_win(
          otherbuf,
          false,
          { relative = 'editor', height = 5, width = 5, row = 5, col = 5 }
        )
        eq(topdir .. '/Xacd/foo', fn.getcwd())
      end)

      it('changes cwd with enter=true', function()
        api.nvim_open_win(
          otherbuf,
          true,
          { relative = 'editor', height = 5, width = 5, row = 5, col = 5 }
        )
        eq(topdir .. '/Xacd', fn.getcwd())
      end)
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

      eq(
        "non-float with 'win' requires at least 'split' or 'vertical'",
        pcall_err(api.nvim_win_set_config, 0, { win = 0 })
      )
      eq(
        "non-float with 'win' requires at least 'split' or 'vertical'",
        pcall_err(api.nvim_win_set_config, 0, { win = 0, relative = '' })
      )
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

    it('closing new curwin when moving window to other tabpage works', function()
      command('split | tabnew')
      local t2_win = api.nvim_get_current_win()
      command('tabfirst | autocmd WinEnter * ++once quit')
      local t1_move_win = api.nvim_get_current_win()
      -- win_set_config fails to switch away from "t1_move_win" because the WinEnter autocmd that
      -- closed the window we're switched to returns us to "t1_move_win", as it filled the space.
      eq(
        'Failed to switch away from window ' .. t1_move_win,
        pcall_err(api.nvim_win_set_config, t1_move_win, { win = t2_win, split = 'left' })
      )
      eq(t1_move_win, api.nvim_get_current_win())

      command('split | split | autocmd WinEnter * ++once quit')
      t1_move_win = api.nvim_get_current_win()
      -- In this case, we closed the window that we got switched to, but doing so didn't switch us
      -- back to "t1_move_win", which is fine.
      api.nvim_win_set_config(t1_move_win, { win = t2_win, split = 'left' })
      neq(t1_move_win, api.nvim_get_current_win())
    end)

    it('messing with "win" or "parent" when moving "win" to other tabpage', function()
      command('split | tabnew')
      local t2 = api.nvim_get_current_tabpage()
      local t2_win1 = api.nvim_get_current_win()
      command('split')
      local t2_win2 = api.nvim_get_current_win()
      command('split')
      local t2_win3 = api.nvim_get_current_win()

      command('tabfirst | autocmd WinEnter * ++once call nvim_win_close(' .. t2_win1 .. ', 1)')
      local cur_win = api.nvim_get_current_win()
      eq(
        'Windows to split were closed',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_win1, split = 'left' })
      )
      eq(cur_win, api.nvim_get_current_win())

      command('split | autocmd WinLeave * ++once quit!')
      cur_win = api.nvim_get_current_win()
      eq(
        'Windows to split were closed',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_win2, split = 'left' })
      )
      neq(cur_win, api.nvim_get_current_win())

      exec([[
        split
        autocmd WinLeave * ++once
              \ call nvim_win_set_config(0, #{relative:'editor', row:0, col:0, width:5, height:5})
      ]])
      cur_win = api.nvim_get_current_win()
      eq(
        'Floating state of windows to split changed',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_win3, split = 'left' })
      )
      eq('editor', api.nvim_win_get_config(0).relative)
      eq(cur_win, api.nvim_get_current_win())

      command('autocmd WinLeave * ++once wincmd J')
      cur_win = api.nvim_get_current_win()
      eq(
        'Floating state of windows to split changed',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_win3, split = 'left' })
      )
      eq('', api.nvim_win_get_config(0).relative)
      eq(cur_win, api.nvim_get_current_win())

      -- Try to make "parent" floating. This should give the same error as before, but because
      -- changing a split from another tabpage into a float isn't supported yet, check for that
      -- error instead for now.
      -- Use ":silent!" to avoid the one second delay from printing the error message.
      exec(([[
        autocmd WinLeave * ++once silent!
              \ call nvim_win_set_config(%d, #{relative:'editor', row:0, col:0, width:5, height:5})
      ]]):format(t2_win3))
      cur_win = api.nvim_get_current_win()
      api.nvim_win_set_config(0, { win = t2_win3, split = 'left' })
      matches(
        'Cannot change window from different tabpage into float$',
        api.nvim_get_vvar('errmsg')
      )
      -- The error doesn't abort moving the window (or maybe it should, if that's wanted?)
      neq(cur_win, api.nvim_get_current_win())
      eq(t2, api.nvim_win_get_tabpage(cur_win))
    end)

    it('expected autocmds when moving window to other tabpage', function()
      local new_curwin = api.nvim_get_current_win()
      command('split')
      local win = api.nvim_get_current_win()
      command('tabnew')
      local parent = api.nvim_get_current_win()
      exec([[
        tabfirst
        let result = []
        autocmd WinEnter * let result += ["Enter", win_getid()]
        autocmd WinLeave * let result += ["Leave", win_getid()]
        autocmd WinNew * let result += ["New", win_getid()]
      ]])
      api.nvim_win_set_config(0, { win = parent, split = 'left' })
      -- Shouldn't see WinNew, as we're not creating any new windows, just moving existing ones.
      eq({ 'Leave', win, 'Enter', new_curwin }, eval('result'))
    end)

    it('no autocmds when moving window within same tabpage', function()
      local parent = api.nvim_get_current_win()
      exec([[
        split
        let result = []
        autocmd WinEnter * let result += ["Enter", win_getid()]
        autocmd WinLeave * let result += ["Leave", win_getid()]
        autocmd WinNew * let result += ["New", win_getid()]
      ]])
      api.nvim_win_set_config(0, { win = parent, split = 'left' })
      -- Shouldn't see any of those events, as we remain in the same window.
      eq({}, eval('result'))
    end)

    it('checks if splitting disallowed', function()
      command('split | autocmd WinEnter * ++once call nvim_win_set_config(0, #{split: "right"})')
      matches("E242: Can't split a window while closing another$", pcall_err(command, 'quit'))

      command('autocmd BufHidden * ++once call nvim_win_set_config(0, #{split: "left"})')
      matches(
        'E1159: Cannot split a window when closing the buffer$',
        pcall_err(command, 'new | quit')
      )

      -- OK when using window to different buffer.
      local w = api.nvim_get_current_win()
      command('autocmd BufHidden * ++once call nvim_win_set_config(' .. w .. ', #{split: "left"})')
      command('new | quit')
    end)

    --- Returns a function to get information about the window layout, sizes and positions of a
    --- tabpage.
    local function define_tp_info_function()
      exec_lua([[
        function tp_info(tp)
          return {
            layout = vim.fn.winlayout(vim.api.nvim_tabpage_get_number(tp)),
            pos_sizes = vim.tbl_map(
              function(w)
                local pos = vim.fn.win_screenpos(w)
                return {
                  row = pos[1],
                  col = pos[2],
                  width = vim.fn.winwidth(w),
                  height = vim.fn.winheight(w)
                }
              end,
              vim.api.nvim_tabpage_list_wins(tp)
            )
          }
        end
      ]])

      return function(tp)
        return exec_lua('return tp_info(...)', tp)
      end
    end

    it('attempt to move window with no room', function()
      -- Fill the 2nd tabpage full of windows until we run out of room.
      -- Use &laststatus=0 to ensure restoring missing statuslines doesn't affect things.
      command('set laststatus=0 | tabnew')
      matches('E36: Not enough room$', pcall_err(command, 'execute "split|"->repeat(&lines)'))
      command('vsplit | wincmd | | wincmd p')
      local t2 = api.nvim_get_current_tabpage()
      local t2_cur_win = api.nvim_get_current_win()
      local t2_top_split = fn.win_getid(1)
      local t2_bot_split = fn.win_getid(fn.winnr('$'))
      local t2_float = api.nvim_open_win(
        0,
        false,
        { relative = 'editor', row = 0, col = 0, width = 10, height = 10 }
      )
      local t2_float_config = api.nvim_win_get_config(t2_float)
      local tp_info = define_tp_info_function()
      local t2_info = tp_info(t2)
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_top_split, split = 'above' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_top_split, split = 'below' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_bot_split, split = 'above' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_bot_split, split = 'below' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, t2_float, { win = t2_top_split, split = 'above' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, t2_float, { win = t2_top_split, split = 'below' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, t2_float, { win = t2_bot_split, split = 'above' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, t2_float, { win = t2_bot_split, split = 'below' })
      )
      eq(t2_cur_win, api.nvim_get_current_win())
      eq(t2_info, tp_info(t2))
      eq(t2_float_config, api.nvim_win_get_config(t2_float))

      -- Try to move windows from the 1st tabpage to the 2nd.
      command('tabfirst | split | wincmd _')
      local t1 = api.nvim_get_current_tabpage()
      local t1_cur_win = api.nvim_get_current_win()
      local t1_float = api.nvim_open_win(
        0,
        false,
        { relative = 'editor', row = 5, col = 3, width = 7, height = 6 }
      )
      local t1_float_config = api.nvim_win_get_config(t1_float)
      local t1_info = tp_info(t1)
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_top_split, split = 'above' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_top_split, split = 'below' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_bot_split, split = 'above' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, 0, { win = t2_bot_split, split = 'below' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, t1_float, { win = t2_top_split, split = 'above' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, t1_float, { win = t2_top_split, split = 'below' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, t1_float, { win = t2_bot_split, split = 'above' })
      )
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, t1_float, { win = t2_bot_split, split = 'below' })
      )
      eq(t1_cur_win, api.nvim_get_current_win())
      eq(t1_info, tp_info(t1))
      eq(t1_float_config, api.nvim_win_get_config(t1_float))
    end)

    it('attempt to move window from other tabpage with no room', function()
      -- Fill up the 1st tabpage with horizontal splits, then create a 2nd with only a few. Go back
      -- to the 1st and try to move windows from the 2nd (while it's non-current) to it. Check that
      -- window positions and sizes in the 2nd are unchanged.
      command('set laststatus=0')
      matches('E36: Not enough room$', pcall_err(command, 'execute "split|"->repeat(&lines)'))

      command('tab split')
      local t2 = api.nvim_get_current_tabpage()
      local t2_top = api.nvim_get_current_win()
      command('belowright split')
      local t2_mid_left = api.nvim_get_current_win()
      command('belowright vsplit')
      local t2_mid_right = api.nvim_get_current_win()
      command('split | wincmd J')
      local t2_bot = api.nvim_get_current_win()
      local tp_info = define_tp_info_function()
      local t2_info = tp_info(t2)
      eq({
        'col',
        {
          { 'leaf', t2_top },
          {
            'row',
            {
              { 'leaf', t2_mid_left },
              { 'leaf', t2_mid_right },
            },
          },
          { 'leaf', t2_bot },
        },
      }, t2_info.layout)

      local function try_move_t2_wins_to_t1()
        for _, w in ipairs({ t2_bot, t2_mid_left, t2_mid_right, t2_top }) do
          matches(
            'E36: Not enough room$',
            pcall_err(api.nvim_win_set_config, w, { win = 0, split = 'below' })
          )
          eq(t2_info, tp_info(t2))
        end
      end
      command('tabfirst')
      try_move_t2_wins_to_t1()
      -- Go to the 2nd tabpage to ensure nothing changes after win_comp_pos, last_status, .etc.
      -- from enter_tabpage.
      command('tabnext')
      eq(t2_info, tp_info(t2))

      -- Check things are fine with the global statusline too, for good measure.
      -- Set it while the 2nd tabpage is current, so last_status runs for it.
      command('set laststatus=3')
      t2_info = tp_info(t2)
      command('tabfirst')
      try_move_t2_wins_to_t1()
    end)

    it('handles cmdwin and textlock restrictions', function()
      command('tabnew')
      local t2 = api.nvim_get_current_tabpage()
      local t2_win = api.nvim_get_current_win()
      command('tabfirst')
      local t1_move_win = api.nvim_get_current_win()
      command('split')

      -- Can't move the cmdwin, or its old curwin to a different tabpage.
      local old_curwin = api.nvim_get_current_win()
      feed('q:')
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_win_set_config, 0, { split = 'left', win = t2_win })
      )
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(api.nvim_win_set_config, old_curwin, { split = 'left', win = t2_win })
      )
      -- But we can move other windows.
      api.nvim_win_set_config(t1_move_win, { split = 'left', win = t2_win })
      eq(t2, api.nvim_win_get_tabpage(t1_move_win))
      command('quit!')

      -- Can't configure windows such that the cmdwin would become the only non-float.
      command('only!')
      feed('q:')
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(
          api.nvim_win_set_config,
          old_curwin,
          { relative = 'editor', row = 0, col = 0, width = 5, height = 5 }
        )
      )
      -- old_curwin is now no longer the only other non-float, so we can make it floating now.
      local t1_new_win = api.nvim_open_win(
        api.nvim_create_buf(true, true),
        false,
        { split = 'left', win = old_curwin }
      )
      api.nvim_win_set_config(
        old_curwin,
        { relative = 'editor', row = 0, col = 0, width = 5, height = 5 }
      )
      eq('editor', api.nvim_win_get_config(old_curwin).relative)
      -- ...which means we shouldn't be able to also make the new window floating too!
      eq(
        'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
        pcall_err(
          api.nvim_win_set_config,
          t1_new_win,
          { relative = 'editor', row = 0, col = 0, width = 5, height = 5 }
        )
      )
      -- Nothing ought to stop us from making the cmdwin itself floating, though...
      api.nvim_win_set_config(0, { relative = 'editor', row = 0, col = 0, width = 5, height = 5 })
      eq('editor', api.nvim_win_get_config(0).relative)
      -- We can't make our new window from before floating too, as it's now the only non-float.
      eq(
        'Cannot change last window into float',
        pcall_err(
          api.nvim_win_set_config,
          t1_new_win,
          { relative = 'editor', row = 0, col = 0, width = 5, height = 5 }
        )
      )
      command('quit!')

      -- Can't switch away from window before moving it to a different tabpage during textlock.
      exec(([[
        new
        call setline(1, 'foo')
        setlocal debug=throw indentexpr=nvim_win_set_config(0,#{split:'left',win:%d})
      ]]):format(t2_win))
      local cur_win = api.nvim_get_current_win()
      matches(
        'E565: Not allowed to change text or change window$',
        pcall_err(command, 'normal! ==')
      )
      eq(cur_win, api.nvim_get_current_win())
    end)

    it('updates statusline when moving bottom split', function()
      local screen = Screen.new(10, 10)
      screen:attach()
      exec([[
        set laststatus=0
        belowright split
        call nvim_win_set_config(0, #{split: 'above', win: win_getid(winnr('#'))})
      ]])
      screen:expect([[
        ^            |
        {1:~           }|*3
        {3:[No Name]   }|
                    |
        {1:~           }|*3
                    |
      ]])
    end)

    it("updates tp_curwin of moved window's original tabpage", function()
      local t1 = api.nvim_get_current_tabpage()
      command('tab split | split')
      local t2 = api.nvim_get_current_tabpage()
      local t2_alt_win = api.nvim_get_current_win()
      command('vsplit')
      local t2_cur_win = api.nvim_get_current_win()
      command('tabprevious')
      eq(t2_cur_win, api.nvim_tabpage_get_win(t2))

      -- tp_curwin is unchanged when moved within the same tabpage.
      api.nvim_win_set_config(t2_cur_win, { split = 'left', win = t2_alt_win })
      eq(t2_cur_win, api.nvim_tabpage_get_win(t2))

      -- Also unchanged if the move failed.
      command('let &winwidth = &columns | let &winminwidth = &columns')
      matches(
        'E36: Not enough room$',
        pcall_err(api.nvim_win_set_config, t2_cur_win, { split = 'left', win = 0 })
      )
      eq(t2_cur_win, api.nvim_tabpage_get_win(t2))
      command('set winminwidth& winwidth&')

      -- But is changed if successfully moved to a different tabpage.
      api.nvim_win_set_config(t2_cur_win, { split = 'left', win = 0 })
      eq(t2_alt_win, api.nvim_tabpage_get_win(t2))
      eq(t1, api.nvim_win_get_tabpage(t2_cur_win))

      -- Now do it for a float, which has different altwin logic.
      command('tabnext')
      t2_cur_win =
        api.nvim_open_win(0, true, { relative = 'editor', row = 5, col = 5, width = 5, height = 5 })
      eq(t2_alt_win, fn.win_getid(fn.winnr('#')))
      command('tabprevious')
      eq(t2_cur_win, api.nvim_tabpage_get_win(t2))

      api.nvim_win_set_config(t2_cur_win, { split = 'left', win = 0 })
      eq(t2_alt_win, api.nvim_tabpage_get_win(t2))
      eq(t1, api.nvim_win_get_tabpage(t2_cur_win))
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
