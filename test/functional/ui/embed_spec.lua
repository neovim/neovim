local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local feed = helpers.feed
local eq = helpers.eq
local clear = helpers.clear

local function test_embed(ext_linegrid)
  local screen
  local function startup(...)
    clear{args_rm={'--headless'}, args={...}}

    -- attach immediately after startup, for early UI
    screen = Screen.new(60, 8)
    screen:attach{ext_linegrid=ext_linegrid}
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [2] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [3] = {bold = true, foreground = Screen.colors.Blue1},
      [4] = {bold = true, foreground = Screen.colors.Green},
      [5] = {bold = true, reverse = true},
    })
  end

  it('can display errors', function()
    startup('--cmd', 'echoerr invalid+')
    screen:expect([[
                                                                  |
                                                                  |
                                                                  |
                                                                  |
                                                                  |
      Error detected while processing pre-vimrc command line:     |
      E121: Undefined variable: invalid                           |
      Press ENTER or type command to continue^                     |
    ]])

    feed('<cr>')
    screen:expect([[
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]])
  end)

  it("doesn't erase output when setting color scheme", function()
    if 'openbsd' == helpers.uname() then
      pending('FIXME #10804')
    end
    startup('--cmd', 'echoerr "foo"', '--cmd', 'color default', '--cmd', 'echoerr "bar"')
    screen:expect([[
                                                                  |
                                                                  |
                                                                  |
      {5:                                                            }|
      Error detected while processing pre-vimrc command line:     |
      foo                                                         |
      {1:bar}                                                         |
      {4:Press ENTER or type command to continue}^                     |
    ]])
  end)

  it("doesn't erase output when setting Normal colors", function()
    startup('--cmd', 'echoerr "foo"', '--cmd', 'hi Normal guibg=Green', '--cmd', 'echoerr "bar"')
    screen:expect{grid=[[
                                                                  |
                                                                  |
                                                                  |
                                                                  |
      Error detected while processing pre-vimrc command line:     |
      foo                                                         |
      bar                                                         |
      Press ENTER or type command to continue^                     |
    ]], condition=function()
      eq(Screen.colors.Green, screen.default_colors.rgb_bg)
    end}
  end)

  it("set display-=msgsep before first redraw", function()
    startup('--cmd', 'set display-=msgsep')
    screen:expect{grid=[[
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}
  end)
end

describe('--embed UI on startup (ext_linegrid=true)', function() test_embed(true) end)
describe('--embed UI on startup (ext_linegrid=false)', function() test_embed(false) end)
