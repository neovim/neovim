-- Tests for (protocol-driven) ui2, intended to replace the legacy message grid UI.

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
    })
    exec_lua(function()
      require('vim._extui').enable({})
    end)
  end)

  it("no crash for invalid grid after 'cmdheight' OptionSet", function()
    exec('tabnew | tabprev')
    feed(':set ch=0')
    screen:expect([[
      {5: }{100:2}{5: [No Name] }{24: [No Name] }{2:                            }{24:X}|
                                                           |
      {1:~                                                    }|*11
      {16::}{15:set} {16:ch}{15:=}0^                                            |
    ]])
    feed('<CR>')
    exec('tabnext')
    screen:expect([[
      {24: [No Name] }{5: }{100:2}{5: [No Name] }{2:                            }{24:X}|
      ^                                                     |
      {1:~                                                    }|*11
      {16::}{15:set} {16:ch}{15:=}0                                            |
    ]])
    exec('tabnext')
    screen:expect([[
      {5: }{100:2}{5: [No Name] }{24: [No Name] }{2:                            }{24:X}|
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
    feed('echo "foo"<CR>')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      {16::}{15:if} {26:1}                                                |
      {16::}  {15:echo} {26:"foo"}                                        |
      {15:foo}                                                  |
      {16::}  ^                                                  |
    ]])
    feed('endif')
    screen:expect([[
                                                           |
      {1:~                                                    }|*9
      {16::}{15:if} {26:1}                                                |
      {16::}  {15:echo} {26:"foo"}                                        |
      {15:foo}                                                  |
      {16::}  {15:endif}^                                             |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
                                                           |
    ]])
  end)
end)
