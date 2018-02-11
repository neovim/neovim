local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq
local feed_command = helpers.feed_command
local insert = helpers.insert
local meths = helpers.meths

describe("multibyte rendering", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 6)
    screen:attach({rgb=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
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
end)

