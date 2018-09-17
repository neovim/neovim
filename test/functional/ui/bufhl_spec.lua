local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command, neq = helpers.command, helpers.neq
local curbufmeths = helpers.curbufmeths

describe('Buffer highlighting', function()
  local screen

  before_each(function()
    clear()
    command('syntax on')
    screen = Screen.new(40, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold=true, foreground=Screen.colors.Blue},
      [2] = {foreground = Screen.colors.Fuchsia}, -- String
      [3] = {foreground = Screen.colors.Brown, bold = true}, -- Statement
      [4] = {foreground = Screen.colors.SlateBlue}, -- Special
      [5] = {bold = true, foreground = Screen.colors.SlateBlue},
      [6] = {foreground = Screen.colors.DarkCyan}, -- Identifier
      [7] = {bold = true},
      [8] = {underline = true, bold = true, foreground = Screen.colors.SlateBlue},
      [9] = {foreground = Screen.colors.SlateBlue, underline = true},
      [10] = {foreground = Screen.colors.Red},
      [11] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [12] = {foreground = Screen.colors.Blue1},
      [13] = {background = Screen.colors.LightGrey},
    })
  end)

  after_each(function()
    screen:detach()
  end)

  local add_hl = curbufmeths.add_highlight
  local clear_hl = curbufmeths.clear_highlight

  it('works', function()
    insert([[
      these are some lines
      with colorful text]])
    feed('+')

    screen:expect([[
      these are some lines                    |
      with colorful tex^t                      |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    add_hl(-1, "String", 0 , 10, 14)
    add_hl(-1, "Statement", 1 , 5, -1)

    screen:expect([[
      these are {2:some} lines                    |
      with {3:colorful tex^t}                      |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    feed("ggo<esc>")
    screen:expect([[
      these are {2:some} lines                    |
      ^                                        |
      with {3:colorful text}                      |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    clear_hl(-1, 0, -1)
    screen:expect([[
      these are some lines                    |
      ^                                        |
      with colorful text                      |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])
  end)

  describe('support adding multiple sources', function()
    local id1, id2
    before_each(function()
      insert([[
        a longer example
        in order to demonstrate
        combining highlights
        from different sources]])

      command("hi ImportantWord gui=bold cterm=bold")
      id1 = add_hl(0, "ImportantWord", 0, 2, 8)
      add_hl(id1, "ImportantWord", 1, 12, -1)
      add_hl(id1, "ImportantWord", 2, 0, 9)
      add_hl(id1, "ImportantWord", 3, 5, 14)

      -- add_highlight can be called like this to get a new source
      -- without adding any highlight
      id2 = add_hl(0, "", 0, 0, 0)
      neq(id1, id2)

      add_hl(id2, "Special", 0, 2, 8)
      add_hl(id2, "Identifier", 1, 3, 8)
      add_hl(id2, "Special", 1, 14, 20)
      add_hl(id2, "Underlined", 2, 6, 12)
      add_hl(id2, "Underlined", 3, 0, 9)

      screen:expect([[
        a {5:longer} example                        |
        in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} source^s                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])
    end)

    it('and clearing the first added', function()
      clear_hl(id1, 0, -1)
      screen:expect([[
        a {4:longer} example                        |
        in {6:order} to de{4:monstr}ate                 |
        combin{9:ing hi}ghlights                    |
        {9:from diff}erent source^s                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])
    end)

    it('and clearing the second added', function()
      clear_hl(id2, 0, -1)
      screen:expect([[
        a {7:longer} example                        |
        in order to {7:demonstrate}                 |
        {7:combining} highlights                    |
        from {7:different} source^s                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])
    end)

    it('and clearing line ranges', function()
      clear_hl(-1, 0, 1)
      clear_hl(id1, 1, 2)
      clear_hl(id2, 2, -1)
      screen:expect([[
        a longer example                        |
        in {6:order} to de{4:monstr}ate                 |
        {7:combining} highlights                    |
        from {7:different} source^s                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])
    end)

    it('and renumbering lines', function()
      feed('3Gddggo<esc>')
      screen:expect([[
        a {5:longer} example                        |
        ^                                        |
        in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])

      command(':3move 4')
      screen:expect([[
        a {5:longer} example                        |
                                                |
        {9:from }{8:diff}{7:erent} sources                  |
        ^in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])
    end)
  end)

  it('prioritizes latest added highlight', function()
    insert([[
      three overlapping colors]])
    add_hl(0, "Identifier", 0, 6, 17)
    add_hl(0, "String", 0, 14, 23)
    local id = add_hl(0, "Special", 0, 0, 9)

    screen:expect([[
      {4:three ove}{6:rlapp}{2:ing color}^s                |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    clear_hl(id, 0, 1)
    screen:expect([[
      three {6:overlapp}{2:ing color}^s                |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])
  end)

  it('works with multibyte text', function()
    insert([[
      Ta båten över sjön!]])
    add_hl(-1, "Identifier", 0, 3, 9)
    add_hl(-1, "String", 0, 16, 21)

    screen:expect([[
      Ta {6:båten} över {2:sjön}^!                     |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])
  end)

  it('works with new syntax groups', function()
    insert([[
      fancy code in a new fancy language]])
    add_hl(-1, "FancyLangItem", 0, 0, 5)
    screen:expect([[
      fancy code in a new fancy languag^e      |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    command('hi FancyLangItem guifg=red')
    screen:expect([[
      {10:fancy} code in a new fancy languag^e      |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])
  end)

  it('supports virtual text annotations', function()
    local set_virtual_text = curbufmeths.set_virtual_text
    insert([[
      1 + 2
      3 +
      x = 4]])
    feed('O<esc>20A5, <esc>gg')
    screen:expect([[
      ^1 + 2                                   |
      3 +                                     |
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      , 5, 5, 5, 5, 5, 5,                     |
      x = 4                                   |
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    local id1 = set_virtual_text(0, 0, {{"=", "Statement"}, {" 3", "Number"}}, {})
    set_virtual_text(id1, 1, {{"ERROR:", "ErrorMsg"}, {" invalid syntax"}}, {})
    local id2 = set_virtual_text(0, 2, {{"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."}}, {})
    neq(id2, id1)

    screen:expect([[
      ^1 + 2 {3:=}{2: 3}                               |
      3 + {11:ERROR:} invalid syntax               |
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
      x = 4                                   |
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    clear_hl(id1, 0, -1)
    screen:expect([[
      ^1 + 2                                   |
      3 +                                     |
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
      x = 4                                   |
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    -- Handles doublewidth chars, leaving a space if truncating
    -- in the middle of a char
    set_virtual_text(id1, 1, {{"暗x事zz速野谷質結育副住新覚丸活解終事", "Comment"}}, {})
    screen:expect([[
      ^1 + 2                                   |
      3 + {12:暗x事zz速野谷質結育副住新覚丸活解終 }|
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
      x = 4                                   |
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    feed("2Gx")
    screen:expect([[
      1 + 2                                   |
      ^ + {12:暗x事zz速野谷質結育副住新覚丸活解終事}|
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
      x = 4                                   |
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    -- visual selection doesn't highlight virtual text
    feed("ggVG")
    screen:expect([[
      {13:1 + 2}                                   |
      {13: +} {12:暗x事zz速野谷質結育副住新覚丸活解終事}|
      {13:5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5}|
      {13:, 5, 5, 5, 5, 5, 5, } Lorem ipsum dolor s|
      ^x{13: = 4}                                   |
      {1:~                                       }|
      {1:~                                       }|
      {7:-- VISUAL LINE --}                       |
    ]])

    feed("<esc>")
    screen:expect([[
      1 + 2                                   |
       + {12:暗x事zz速野谷質結育副住新覚丸活解終事}|
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
      ^x = 4                                   |
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    feed("2Gdd")
    screen:expect([[
      1 + 2                                   |
      ^5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
      x = 4                                   |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    -- listchars=eol:- works, and doesn't shift virtual text
    command("set list")
    screen:expect([[
      1 + 2                                   |
      ^5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      , 5, 5, 5, 5, 5, 5,{1:-} Lorem ipsum dolor s|
      x = 4                                   |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    clear_hl(-1, 0, -1)
    screen:expect([[
      1 + 2                                   |
      ^5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      , 5, 5, 5, 5, 5, 5,{1:-}                    |
      x = 4                                   |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

  end)
end)
