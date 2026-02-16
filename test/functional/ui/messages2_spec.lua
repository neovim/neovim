-- Tests for (protocol-driven) ui2, intended to replace the legacy message grid UI.

local t = require('test.testutil')
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
      require('vim._core.ui2').enable({})
    end)
  end)
  after_each(function()
    -- Since ui2 module lasts until Nvim exits, there may be unfinished timers.
    -- Close unfinished timers to avoid 2s delay on exit with ASAN or TSAN.
    exec_lua(function()
      vim.uv.walk(function(handle)
        if not handle:is_closing() then
          handle:close()
        end
      end)
    end)
  end)

  it('multiline messages and pager', function()
    command('echo "foo\nbar"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*10
      {3:                                                     }|
      foo                                                  |
      bar                                                  |
    ]])
    command('set ruler showcmd noshowmode')
    feed('g<lt>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      {3:                                                     }|
      fo^o                                                  |
      bar                                                  |
                                          1,3           All|
    ]])
    -- Multiple messages in same event loop iteration are appended and shown in full.
    feed([[q:echo "foo" | echo "bar\nbaz\n"->repeat(&lines)<CR>]])
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*5
      {3:                                                     }|
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
      {1:~                                                    }|*9
      {3:                                                     }|
      foo                                                  |
      bar                                                  |
        1 %a   "[No Name]"                    line 1       |
    ]])
    feed('<C-L>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
                                          0,0-1         All|
    ]])
    -- g< shows messages from last command
    feed('g<lt>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*8
      {3:                                                     }|
      fo^o                                                  |
      bar                                                  |
        1 %a   "[No Name]"                    line 1       |
                                          1,3           All|
    ]])
    -- edit_unputchar() does not clear already updated screen #34515.
    feed('qix<Esc>dwi<C-r>')
    screen:expect([[
      {18:^"}                                                    |
      {1:~                                                    }|*12
                               ^R         1,1           All|
    ]])
    feed('-<Esc>')
    screen:expect([[
      ^x                                                    |
      {1:~                                                    }|*12
                                          1,1           All|
    ]])
    -- Switching tabpage closes expanded cmdline #37659.
    command('tabnew | echo "foo\nbar"')
    screen:expect([[
      {24: + [No Name] }{5: }{100:2}{5: [No Name] }{2:                          }{24:X}|
      ^                                                     |
      {1:~                                                    }|*9
      {3:                                                     }|
      foo                                                  |
      bar                                                  |
    ]])
    feed('gt')
    screen:expect([[
      {5: + [No Name] }{24: [No Name] }{2:                            }{24:X}|
      ^x                                                    |
      {1:~                                                    }|*11
      foo [+1]                            1,1           All|
    ]])
  end)

  it('new buffer, window and options after closing a buffer', function()
    command('set nomodifiable | echom "foo" | messages')
    screen:expect([[
                                                           |
      {1:~                                                    }|*10
      {3:                                                     }|
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
    -- A redraw indicates the start of messages in the cmdline, which empty should clear.
    command('echo "foo" | redraw | echo "bar"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      bar                                                  |
    ]])
    command('echo "foo" | redraw | echo ""')
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
      {3:                                                     }|
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
      {3:                                                     }|
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
      {3:                                                     }|
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
      {3:                                                                       }|
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
      {3:                                                                       }|
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
      {3:                                                                       }|
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
      {3:                                                                       }|
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
      {3:                                                                       }|
      93 [+93]                                                               |
      94                                                                     |
      95                                                                     |
      96                                                                     |
      97                                                                     |
      98                                                                     |
      99                                                                     |
      Type number and <Enter> or click with the mouse (q or empty cancels): ^ |
    ]])
    -- No scrolling beyond end of buffer #36114
    feed('f')
    screen:expect([[
                                                                             |
      {1:~                                                                      }|*3
      {3:                                                                       }|
      93 [+93]                                                               |
      94                                                                     |
      95                                                                     |
      96                                                                     |
      97                                                                     |
      98                                                                     |
      99                                                                     |
      Type number and <Enter> or click with the mouse (q or empty cancels): f|
      ^                                                                       |
    ]])
    feed('<Backspace>g')
    screen:expect(top)
  end)

  it('FileType is fired after default options are set', function()
    n.exec([[
      let g:set = {}
      au FileType pager set nowrap
      au OptionSet * let g:set[expand('<amatch>')] = g:set->get(expand('<amatch>'), 0) + 1
      echom 'foo'->repeat(&columns)
      messages
    ]])
    screen:expect([[
                                                           |
      {1:~                                                    }|*10
      {3:                                                     }|
      foofoofoofoofoofoofoofoofo^o                          |
                                                           |
    ]])
    t.eq({ filetype = 5 }, n.eval('g:set')) -- still fires for 'filetype'
  end)

  it('Search highlights only apply to pager', function()
    screen:add_extra_attr_ids({
      [100] = { background = Screen.colors.Blue1, foreground = Screen.colors.Red },
      [101] = { background = Screen.colors.Red1, foreground = Screen.colors.Blue1 },
    })
    command('hi MsgArea guifg=Red guibg=Blue')
    command('hi Search guifg=Blue guibg=Red')
    command('set hlsearch shortmess+=s')
    feed('/foo<CR>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      {9:E486: Pattern not found: foo}{100:                         }|
    ]])
    command('set cmdheight=0 | echo "foo"')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      {1:~                                                 }{4:foo}|
    ]])
    feed('g<lt>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*11
      {3:                                                     }|
      {101:fo^o}{100:                                                  }|
    ]])
  end)

  it(':echon appends message', function()
    command([[echo 1 | echon 2]])
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      12                                                   |
    ]])
    feed('g<lt>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*10
      {3:                                                     }|
      ^12                                                   |
                                                           |
    ]])
    feed([[q:echo 1 | echon 2 | echon 2 | echon 3<CR>]])
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      1223                                                 |
    ]])
    feed('g<lt>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*10
      {3:                                                     }|
      ^1223                                                 |
                                                           |
    ]])
  end)

  it('shows message from still running command', function()
    exec_lua(function()
      vim.schedule(function()
        print('foo')
        vim.fn.getchar()
      end)
    end)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      foo                                                  |
    ]])
  end)

  it('properly formatted carriage return messages', function()
    screen:try_resize(screen._width, 20)
    command([[echon "\r" | echon "Hello" | echon " " | echon "World"]])
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*18
      Hello World                                          |
    ]])
    exec_lua(function()
      vim.api.nvim_echo({ { 'fooo\nbarbaz\n\nlol', 'statement' }, { '\rbar' } }, true, {})
      vim.api.nvim_echo({ { 'foooooooo', 'statement' }, { 'baz\rb', 'error' } }, true, {})
      vim.api.nvim_echo({ { 'fooobar', 'statement' }, { '\rbaz\n' } }, true, {})
      vim.api.nvim_echo({ { 'fooobar', 'statement' }, { '\rbaz\rb', 'error' } }, true, {})
      vim.api.nvim_echo({ { 'fooo\rbar', 'statement' }, { 'baz', 'error' } }, true, {})
    end)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*9
      {3:                                                     }|
      {15:fooo}                                                 |
      {15:barbaz}                                               |
                                                           |
      bar                                                  |
      {9:b}{15:oooooooo}{9:baz}                                         |
      baz{15:obar}                                              |
                                                           |
      {9:baz}{15:obar}                                              |
      {15:bar}{9:baz}                                               |
    ]])
  end)

  it('can show message during textlock', function()
    exec_lua(function()
      _G.omnifunc = function()
        print('x!')
        vim.cmd.sleep('100m')
      end
      vim.bo.omnifunc = 'v:lua.omnifunc'
    end)
    feed('i<C-X>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      {5:-- ^X mode (^]^D^E^F^I^K^L^N^O^P^Rs^U^V^Y)}           |
    ]])
    feed('<C-O>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      x!                                                   |
    ]])
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      {5:-- Omni completion (^O^N^P) }{9:Pattern not found}        |
    ]])
    exec_lua(function()
      vim.keymap.set('n', '<F1>', function()
        print('i hate locks so much!!!!')
        vim.cmd.messages()
      end, { expr = true })
    end)
    feed('<Esc><F1>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*8
      {3:                                                     }|
      x^!                                                   |
      x!                                                   |
      i hate locks so much!!!!                             |*2
    ]])
  end)

  it('replace by message ID', function()
    exec_lua(function()
      vim.api.nvim_echo({ { 'foo' } }, true, { id = 1 })
      vim.api.nvim_echo({ { 'bar\nbaz' } }, true, { id = 2 })
      vim.api.nvim_echo({ { 'foo' } }, true, { id = 3 })
    end)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*8
      {3:                                                     }|
      foo                                                  |
      bar                                                  |
      baz                                                  |
      foo                                                  |
    ]])
    exec_lua(function()
      vim.api.nvim_echo({ { 'foo' } }, true, { id = 2 })
    end)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*9
      {3:                                                     }|
      foo                                                  |*3
    ]])
    exec_lua(function()
      vim.api.nvim_echo({ { 'bar\nbaz' } }, true, { id = 1 })
    end)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*8
      {3:                                                     }|
      bar                                                  |
      baz                                                  |
      foo                                                  |*2
    ]])
    exec_lua(function()
      vim.o.cmdheight = 0
      vim.api.nvim_echo({ { 'foo' } }, true, { id = 1 })
      vim.api.nvim_echo({ { 'bar\nbaz' } }, true, { id = 2 })
      vim.api.nvim_echo({ { 'foo' } }, true, { id = 3 })
    end)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*9
      {1:~                                                 }{4:foo}|
      {1:~                                                 }{4:bar}|
      {1:~                                                 }{4:baz}|
      {1:~                                                 }{4:foo}|
    ]])
    exec_lua(function()
      vim.api.nvim_echo({ { 'foo' } }, true, { id = 2 })
    end)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*10
      {1:~                                                 }{4:foo}|*3
    ]])
    exec_lua(function()
      vim.api.nvim_echo({ { 'f', 'Conceal' }, { 'oo\nbar' } }, true, { id = 3 })
    end)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*9
      {1:~                                                 }{4:foo}|*2
      {1:~                                                 }{14:f}{4:oo}|
      {1:~                                                 }{4:bar}|
    ]])
    -- No error expanding the cmdline when trying to copy over message span marks #37672.
    screen:try_resize(screen._width, 6)
    command('ls!')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|
      {3:                                                     }|
      foo                                                  |*2
      {14:f}oo                                                  |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*5
    ]])
  end)

  it('while cmdline is open', function()
    command('cnoremap <C-A> <Cmd>lua error("foo")<CR>')
    feed(':echo "bar"<C-A>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*7
      {3:                                                     }|
      {9:E5108: Lua: [string ":lua"]:1: foo}                   |
      {9:stack traceback:}                                     |
      {9:        [C]: in function 'error'}                     |
      {9:        [string ":lua"]:1: in main chunk}             |
      {16::}{15:echo} {26:"bar"}^                                          |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
      bar                                                  |
    ]])
    command('set cmdheight=0')
    feed([[:call confirm("foo\nbar")<C-A>]])
    screen:expect([[
                                                           |
      {1:~                                                    }|*8
      {1:~            }{9:E5108: Lua: [string ":lua"]:1: foo}{4:      }|
      {1:~            }{9:stack traceback:}{4:                        }|
      {1:~            }{9:        [C]: in function 'error'}{4:        }|
      {1:~            }{9:        [string ":lua"]:1: in main chunk}|
      {16::}{15:call} {25:confirm}{16:(}{26:"foo\nbar"}{16:)}^                            |
    ]])
    feed('<CR>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*7
      {3:                                                     }|
                                                           |
      {6:foo}                                                  |
      {6:bar}                                                  |
                                                           |
      {6:[O]k: }^                                               |
    ]])
  end)
end)
