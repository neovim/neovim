local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local feed = helpers.feed
local feed_command = helpers.feed_command
local insert = helpers.insert
local funcs = helpers.funcs

describe("multibyte rendering", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 6)
    screen:attach({rgb=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {background = Screen.colors.WebGray},
      [3] = {background = Screen.colors.LightMagenta},
      [4] = {bold = true},
    })
  end)

  after_each(function()
    screen:detach()
  end)

  it("works with composed char at start of line", function()
    insert([[
      ̊
      x]])
    feed("gg")
     -- verify the modifier infact is alone
    feed_command("ascii")
    screen:expect([[
      ^ ̊                                                           |
      x                                                           |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      < ̊> 778, Hex 030a, Octal 1412                               |
    ]])

    -- a char inserted before will spontaneously merge with it
    feed("ia<esc>")
    feed_command("ascii")
    screen:expect([[
      ^å                                                           |
      x                                                           |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      <a>  97,  Hex 61,  Octal 141 < ̊> 778, Hex 030a, Octal 1412  |
    ]])
  end)

  it('works with doublewidth char at end of line', function()
    feed('58a <esc>a馬<esc>')
    screen:expect([[
                                                                ^馬|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]])

    feed('i <esc>')
    screen:expect([[
                                                                ^ {1:>}|
      馬                                                          |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]])

    feed('l')
    screen:expect([[
                                                                 {1:>}|
      ^馬                                                          |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]])
  end)

  it('clears left half of double-width char when right half is overdrawn', function()
    feed('o-馬<esc>ggiab ')
    screen:expect([[
      ab ^                                                         |
      -馬                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {4:-- INSERT --}                                                |
    ]])

    -- check double-with char is temporarily hidden when overlapped
    funcs.complete(4, {'xx', 'yy'})
    screen:expect([[
      ab xx^                                                       |
      - {2: xx             }                                          |
      {1:~ }{3: yy             }{1:                                          }|
      {1:~                                                           }|
      {1:~                                                           }|
      {4:-- INSERT --}                                                |
    ]])

    -- check it is properly restored
    feed('z')
    screen:expect([[
      ab xxz^                                                      |
      -馬                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {4:-- INSERT --}                                                |
    ]])
  end)
end)

