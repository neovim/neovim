-- Tests for (protocol-driven) ui2, intended to replace the legacy message grid UI.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, exec, exec_lua, feed = n.clear, n.exec, n.exec_lua, n.feed

describe('cmdline2', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new()
    screen:add_extra_attr_ids({
      [100] = { foreground = Screen.colors.Magenta1, bold = true },
      [101] = { background = Screen.colors.Yellow, foreground = Screen.colors.Grey0 },
    })
    exec_lua(function()
      require('vim._extui').enable({})
    end)
  end)

  it("no crash for invalid grid after 'cmdheight' OptionSet", function()
    exec('tabnew | tabprev')
    feed(':set ch=0')
    screen:expect([[
      {5: [No Name] }{24: [No Name] }{2:                              }{24:X}|
                                                           |
      {1:~                                                    }|*11
      {16::}{15:set} {16:ch}{15:=}0^                                            |
    ]])
    feed('<CR>')
    exec('tabnext')
    screen:expect([[
      {24: [No Name] }{5: [No Name] }{2:                              }{24:X}|
      ^                                                     |
      {1:~                                                    }|*11
      {16::}{15:set} {16:ch}{15:=}0                                            |
    ]])
    exec('tabnext')
    screen:expect([[
      {5: [No Name] }{24: [No Name] }{2:                              }{24:X}|
      ^                                                     |
      {1:~                                                    }|*12
    ]])
    n.assert_alive()
  end)

  it("redraw does not clear 'incsearch' highlight with conceal", function()
    exec('call setline(1, ["foo", "foobar"]) | set conceallevel=1 concealcursor=c')
    feed('/foo')
    screen:expect([[
      {10:foo}                                                  |
      {2:foo}bar                                               |
      {1:~                                                    }|*11
      /foo^                                                 |
    ]])
  end)

  it('block mode', function()
    feed(':if 1<CR>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*11
      {16::}{15:if} {26:1}                                                |
      {16::}  ^                                                  |
    ]])
    feed('echo "foo"')
    screen:expect([[
                                                           |
      {1:~                                                    }|*11
      {16::}{15:if} {26:1}                                                |
      {16::}  {15:echo} {26:"foo"}^                                        |
    ]])
    feed('<CR>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      {16::}{15:if} {26:1}                                                |
      {16::}  {15:echo} {26:"foo"}                                        |
      {15:foo}                                                  |
      {16::}  ^                                                  |
    ]])
    feed([[echo input("foo\nbar:")<CR>]])
    screen:expect([[
                                                           |
      {1:~                                                    }|*7
      :if 1                                                |
      :  echo "foo"                                        |
      foo                                                  |
      :  echo input("foo\nbar:")                           |
      foo                                                  |
      bar:^                                                 |
    ]])
    feed('baz')
    screen:expect([[
                                                           |
      {1:~                                                    }|*7
      :if 1                                                |
      :  echo "foo"                                        |
      foo                                                  |
      :  echo input("foo\nbar:")                           |
      foo                                                  |
      bar:baz^                                              |
    ]])
    feed('<CR>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*5
      {16::}{15:if} {26:1}                                                |
      {16::}  {15:echo} {26:"foo"}                                        |
      {15:foo}                                                  |
      {16::}  {15:echo} {25:input}{16:(}{26:"foo\nbar:"}{16:)}                           |
      {15:foo}                                                  |
      {15:bar}:baz                                              |
      {15:baz}                                                  |
      {16::}  ^                                                  |
    ]])
    feed('endif')
    screen:expect([[
                                                           |
      {1:~                                                    }|*5
      {16::}{15:if} {26:1}                                                |
      {16::}  {15:echo} {26:"foo"}                                        |
      {15:foo}                                                  |
      {16::}  {15:echo} {25:input}{16:(}{26:"foo\nbar:"}{16:)}                           |
      {15:foo}                                                  |
      {15:bar}:baz                                              |
      {15:baz}                                                  |
      {16::}  {15:endif}^                                             |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
                                                           |
    ]])
  end)

  it('handles empty prompt', function()
    feed(":call input('')<CR>")
    screen:expect([[
                                                           |
      {1:~                                                    }|*12
      ^                                                     |
    ]])
  end)

  it('highlights after deleting buffer', function()
    feed(':%bw!<CR>:call foo()')
    screen:expect([[
                                                           |
      {1:~                                                    }|*12
      {16::}{15:call} {25:foo}{16:()}^                                          |
    ]])
  end)

  it('can change cmdline buffer during textlock', function()
    exec([[
      func Foo(a, b)
        redrawstatus!
      endfunc
      set wildoptions=pum findfunc=Foo wildmode=noselect:lastused,full
      au CmdlineChanged * call wildtrigger()
    ]])
    feed(':find ')
    screen:expect([[
                                                           |
      {1:~                                                    }|*12
      {16::}{15:find} ^                                               |
    ]])
    t.eq(n.eval('v:errmsg'), "E1514: 'findfunc' did not return a List type")
  end)

  it('substitution match does not clear cmdline', function()
    exec('call setline(1, "foo")')
    feed(':s/f')
    screen:expect([[
      {10:f}oo                                                  |
      {1:~                                                    }|*12
      {16::}{15:s}{16:/f}^                                                 |
    ]])
  end)

  it('dialog position is adjusted for toggled wildmenu', function()
    exec([[
      set wildmode=list:full,full wildoptions-=pum
      func Foo()
      endf
      func Fooo()
      endf
    ]])
    feed(':call Fo<C-Z>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      {3:                                                     }|
      Foo()   Fooo()                                       |
                                                           |
      {16::}{15:call} Fo^                                             |
    ]])
    feed('<C-Z>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*8
      {3:                                                     }|
      Foo()   Fooo()                                       |
                                                           |
      {101:Foo()}{3:  Fooo()                                        }|
      {16::}{15:call} {25:Foo}{16:()}^                                          |
    ]])
    feed('()')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      {3:                                                     }|
      Foo()   Fooo()                                       |
                                                           |
      {16::}{15:call} {25:Foo}{16:()()}^                                        |
    ]])
  end)
end)

describe('cmdline2', function()
  it('resizing during startup shows confirm prompt #36439', function()
    clear({
      args = {
        '--clean',
        '+lua require("vim._extui").enable({})',
        "+call feedkeys(':')",
      },
    })
    local screen = Screen.new()
    feed('call confirm("Ok?")<CR>')
    screen:try_resize(screen._width + 1, screen._height)
    screen:expect([[
                                                            |
      {1:~                                                     }|*8
      {3:                                                      }|
                                                            |
      {6:Ok?}                                                   |
                                                            |
      {6:[O]k: }^                                                |
    ]])
    -- And resizing the next event loop iteration also works.
    feed('k')
    screen:try_resize(screen._width, screen._height + 1)
    screen:expect([[
                                                            |
      {1:~                                                     }|*9
      {3:                                                      }|
                                                            |
      {6:Ok?}                                                   |
                                                            |
      {6:[O]k: }^                                                |
    ]])
  end)
end)
