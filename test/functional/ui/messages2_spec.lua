-- Tests for (protocol-driven) ui2, intended to replace the legacy message grid UI.

local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, command, exec_lua, feed = n.clear, n.command, n.exec_lua, n.feed

describe('messages2', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new()
    screen:add_extra_attr_ids({
      [100] = { foreground = Screen.colors.Magenta1, bold = true },
    })
    exec_lua(function()
      require('vim._extui').enable({})
    end)
  end)

  it('multiline messages and pager', function()
    command('echo "foo\nbar"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*10
      {3:─────────────────────────────────────────────────────}|
      foo                                                  |
      bar                                                  |
    ]])
    command('set ruler showcmd noshowmode')
    feed('g<lt>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      {3:─────────────────────────────────────────────────────}|
      fo^o                                                  |
      bar                                                  |
                                          1,3           All|
    ]])
    -- Multiple messages in same event loop iteration are appended and shown in full.
    feed([[q:echo "foo" | echo "bar\nbaz\n"->repeat(&lines)<CR>]])
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*5
      {3:─────────────────────────────────────────────────────}|
      foo                                                  |
      bar                                                  |
      baz                                                  |
      bar                                                  |
      baz                                                  |
      bar                                                  |
      baz [+23]                                            |
    ]])
    -- Any key press resizes the cmdline and updates the spill indicator.
    feed('j')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      foo [+29]                           0,0-1         All|
    ]])
    command('echo "foo"')
    -- New message clears spill indicator.
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      foo                                 0,0-1         All|
    ]])
    -- No error for ruler virt_text msg_row exceeding buffer length.
    command([[map Q <cmd>echo "foo\nbar" <bar> ls<CR>]])
    feed('Q')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*8
      {3:─────────────────────────────────────────────────────}|
      foo                                                  |
      bar                                                  |
                                                           |
        1 %a   "[No Name]"                    line 1       |
    ]])
    feed('<C-L>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
                                          0,0-1         All|
    ]])
    -- edit_unputchar() does not clear already updated screen #34515.
    feed('ix<Esc>dwi<C-r>')
    screen:expect([[
      {18:^"}                                                    |
      {1:~                                                    }|*12
                               ^R         1,1           All|
    ]])
    feed('-')
    screen:expect([[
      x^                                                    |
      {1:~                                                    }|*12
                                          1,2           All|
    ]])
  end)

  it('new buffer, window and options after closing a buffer', function()
    command('set nomodifiable | echom "foo" | messages')
    screen:expect([[
                                                           |
      {1:~                                                    }|*10
      {3:─────────────────────────────────────────────────────}|
      fo^o                                                  |
      foo                                                  |
    ]])
    command('bdelete | messages')
    screen:expect_unchanged()
  end)

  it('screenclear and empty message clears messages', function()
    command('echo "foo"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      foo                                                  |
    ]])
    command('mode')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
                                                           |
    ]])
    command('echo "foo"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      foo                                                  |
    ]])
    command('echo ""')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
                                                           |
    ]])
    command('set cmdheight=0')
    command('echo "foo"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*10
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                 }{4:foo}|
    ]])
    command('mode')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*13
    ]])
    -- But not with target='msg'
    command('echo "foo"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*10
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                 }{4:foo}|
    ]])
    command('echo ""')
    screen:expect_unchanged()
    -- Or a screen resize
    screen:try_resize(screen._width, screen._height - 1)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*9
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                 }{4:foo}|
    ]])
    -- Moved up when opening cmdline
    feed(':')
    screen:expect([[
                                                           |
      {1:~                                                    }|*10
      {1:~                                                 }{4:foo}|
      {16::}^                                                    |
    ]])
    -- Highlighter disabled when message is moved to cmdline #34884
    feed([[echo "bar\n"->repeat(&lines)<CR>]])
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*4
      {3:─────────────────────────────────────────────────────}|
      foo                                                  |
      bar                                                  |*5
      bar [+8]                                             |
    ]])
  end)

  it("deleting buffer restores 'buftype'", function()
    feed(':%bdelete<CR>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      5 buffers deleted                                    |
    ]])
    -- Would trigger changed dialog if 'buftype' was not restored.
    command('%bdelete')
    screen:expect_unchanged()
  end)

  it('showmode does not overwrite important messages', function()
    command('set readonly')
    feed('i')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      {19:W10: Warning: Changing a readonly file}               |
    ]])
    feed('<Esc>Qi')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      {9:E354: Invalid register name: '^@'}                    |
    ]])
  end)

  it('hit-enter prompt does not error for invalid window #35095', function()
    command('echo "foo\nbar"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*10
      {3:─────────────────────────────────────────────────────}|
      foo                                                  |
      bar                                                  |
    ]])
    feed('<C-w>o')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      foo [+1]                                             |
    ]])
  end)

  it('not restoring already open hit-enter-prompt config #35298', function()
    command('echo "foo\nbar"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*10
      {3:─────────────────────────────────────────────────────}|
      foo                                                  |
      bar                                                  |
    ]])
    command('echo "foo\nbar"')
    screen:expect_unchanged()
    feed(':')
    screen:expect([[
                                                           |
      {1:~                                                    }|*12
      {16::}^                                                    |
    ]])
  end)

  it('paging prompt dialog #35191', function()
    screen:try_resize(71, screen._height)
    local top = [[
                                                                             |
      {1:~                                                                      }|*4
      {3:───────────────────────────────────────────────────────────────────────}|
      0                                                                      |
      1                                                                      |
      2                                                                      |
      3                                                                      |
      4                                                                      |
      5                                                                      |
      6 [+93]                                                                |
      Type number and <Enter> or click with the mouse (q or empty cancels): ^ |
    ]]
    feed(':call inputlist(range(100))<CR>')
    screen:expect(top)
    feed('j')
    screen:expect([[
                                                                             |
      {1:~                                                                      }|*4
      {3:───────────────────────────────────────────────────────────────────────}|
      1 [+1]                                                                 |
      2                                                                      |
      3                                                                      |
      4                                                                      |
      5                                                                      |
      6                                                                      |
      7 [+92]                                                                |
      Type number and <Enter> or click with the mouse (q or empty cancels): ^ |
    ]])
    feed('k')
    screen:expect(top)
    feed('d')
    screen:expect([[
                                                                             |
      {1:~                                                                      }|*4
      {3:───────────────────────────────────────────────────────────────────────}|
      3 [+3]                                                                 |
      4                                                                      |
      5                                                                      |
      6                                                                      |
      7                                                                      |
      8                                                                      |
      9 [+90]                                                                |
      Type number and <Enter> or click with the mouse (q or empty cancels): ^ |
    ]])
    feed('u')
    screen:expect(top)
    feed('f')
    screen:expect([[
                                                                             |
      {1:~                                                                      }|*4
      {3:───────────────────────────────────────────────────────────────────────}|
      5 [+5]                                                                 |
      6                                                                      |
      7                                                                      |
      8                                                                      |
      9                                                                      |
      10                                                                     |
      11 [+88]                                                               |
      Type number and <Enter> or click with the mouse (q or empty cancels): ^ |
    ]])
    feed('b')
    screen:expect(top)
    feed('G')
    screen:expect([[
                                                                             |
      {1:~                                                                      }|*4
      {3:───────────────────────────────────────────────────────────────────────}|
      93 [+93]                                                               |
      94                                                                     |
      95                                                                     |
      96                                                                     |
      97                                                                     |
      98                                                                     |
      99                                                                     |
      Type number and <Enter> or click with the mouse (q or empty cancels): ^ |
    ]])
    feed('g')
    screen:expect(top)
  end)

  it('in cmdline_block mode', function()
    feed(':if 1<CR>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*11
      {16::}{15:if} {26:1}                                                |
      {16::}  ^                                                  |
    ]])
    feed([[echo input("foo\nbar:")<CR>]])
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      :if 1                                                |
      :  echo input("foo\nbar:")                           |
      foo                                                  |
      bar:^                                                 |
    ]])
    feed('baz<CR>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      {16::}{15:if} {26:1}                                                |
      {16::}  {15:echo} {25:input}{16:(}{26:"foo\nbar:"}{16:)}                           |
      {15:baz}                                                  |
      {16::}  ^                                                  |
    ]])
    feed([[echo input("foo\nbar:")<CR>]])
    screen:expect([[
                                                           |
      {1:~                                                    }|*7
      :if 1                                                |
      :  echo input("foo\nbar:")                           |
      baz                                                  |
      :  echo input("foo\nbar:")                           |
      foo                                                  |
      bar:^                                                 |
    ]])
    feed('<Esc>:endif')
    screen:expect([[
                                                           |
      {1:~                                                    }|*8
      {16::}{15:if} {26:1}                                                |
      {16::}  {15:echo} {25:input}{16:(}{26:"foo\nbar:"}{16:)}                           |
      {15:baz}                                                  |
      {16::}  {15:echo} {25:input}{16:(}{26:"foo\nbar:"}{16:)}                           |
      {16::}  {16::}{15:endif}^                                            |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
                                                           |
    ]])
  end)
end)
