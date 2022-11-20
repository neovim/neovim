local helpers = require('test.functional.helpers')()
local Screen = require('test.functional.ui.screen')
local feed = helpers.feed
local clear = helpers.clear

describe(':debug', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(30, 14)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {bold = true, reverse = true},
      [3] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
    })
    screen:attach()
  end)
  it('scrolls messages correctly', function()
    feed(':echoerr bork<cr>')
    screen:expect([[
                                    |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {2:                              }|
      {3:E121: Undefined variable: bork}|
                                    |
      {4:Press ENTER or type command to}|
      {4: continue}^                     |
    ]])

    feed(':debug echo "aa"| echo "bb"<cr>')
    screen:expect([[
                                    |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {2:                              }|
      {3:E121: Undefined variable: bork}|
                                    |
      {4:Press ENTER or type command to}|
      Entering Debug mode.  Type "co|
      nt" to continue.              |
      cmd: echo "aa"| echo "bb"     |
      >^                             |
    ]])

    feed('step<cr>')
    screen:expect([[
                                    |
      {1:~                             }|
      {1:~                             }|
      {2:                              }|
      {3:E121: Undefined variable: bork}|
                                    |
      {4:Press ENTER or type command to}|
      Entering Debug mode.  Type "co|
      nt" to continue.              |
      cmd: echo "aa"| echo "bb"     |
      >step                         |
      aa                            |
      cmd: echo "bb"                |
      >^                             |
    ]])

    feed('step<cr>')
    screen:expect([[
      {2:                              }|
      {3:E121: Undefined variable: bork}|
                                    |
      {4:Press ENTER or type command to}|
      Entering Debug mode.  Type "co|
      nt" to continue.              |
      cmd: echo "aa"| echo "bb"     |
      >step                         |
      aa                            |
      cmd: echo "bb"                |
      >step                         |
      bb                            |
      {4:Press ENTER or type command to}|
      {4: continue}^                     |
    ]])

    feed('<cr>')
    screen:expect([[
      ^                              |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
                                    |
    ]])
  end)
end)
