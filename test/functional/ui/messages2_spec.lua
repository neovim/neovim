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
      {1:~                                                    }|*12
      foo[+1]                                              |
    ]])
    command('set ruler showcmd noshowmode')
    feed('g<lt>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      ─────────────────────────────────────────────────────|
      {4:fo^o                                                  }|
      {4:bar                                                  }|
      foo[+1]                             1,3           All|
    ]])
    -- New message clears spill indicator.
    feed('Q')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      ─────────────────────────────────────────────────────|
      {4:fo^o                                                  }|
      {4:bar                                                  }|
      {9:E354: Invalid register name: '^@'}   1,3           All|
    ]])
    -- Multiple messages in same event loop iteration are appended.
    feed([[q:echo "foo\nbar" | echo "baz"<CR>]])
    screen:expect([[
                                                           |
      {1:~                                                    }|*8
      ─────────────────────────────────────────────────────|
      {4:^foo                                                  }|
      {4:bar                                                  }|
      {4:baz                                                  }|
                                          1,1           All|
    ]])
    -- No error for ruler virt_text msg_row exceeding buffer length.
    command([[map Q <cmd>echo "foo\nbar" <bar> ls<CR>]])
    feed('qQ')
    screen:expect([[
                                                           |
      {1:~                                                    }|*7
      ─────────────────────────────────────────────────────|
      {4:^foo                                                  }|
      {4:bar                                                  }|
      {4:                                                     }|
      {4:  1 %a   "[No Name]"                    line 1       }|
                                          1,1           All|
    ]])
    -- edit_unputchar() does not clear already updated screen #34515.
    feed('qix<Esc>dwi<C-r>')
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
      ─────────────────────────────────────────────────────|
      {4:fo^o                                                  }|
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
      {1:~                                               }┌───┐|
      {1:~                                               }│{4:foo}│|
      {1:~                                               }└───┘|
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
      {1:~                                               }┌───┐|
      {1:~                                               }│{4:foo}│|
      {1:~                                               }└───┘|
    ]])
    command('echo ""')
    screen:expect_unchanged()
  end)
end)
