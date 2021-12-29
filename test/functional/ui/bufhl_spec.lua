local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command, neq = helpers.command, helpers.neq
local meths = helpers.meths
local curbufmeths, eq = helpers.curbufmeths, helpers.eq
local pcall_err = helpers.pcall_err

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
      [14] = {background = Screen.colors.Gray90},
      [15] = {background = Screen.colors.Gray90, bold = true, foreground = Screen.colors.Brown},
      [16] = {foreground = Screen.colors.Magenta, background = Screen.colors.Gray90},
      [17] = {foreground = Screen.colors.Magenta, background = Screen.colors.LightRed},
      [18] = {background = Screen.colors.LightRed},
      [19] = {foreground = Screen.colors.Blue1, background = Screen.colors.LightRed},
      [20] = {underline = true, bold = true, foreground = Screen.colors.Cyan4},
    })
  end)

  local add_highlight = curbufmeths.add_highlight
  local clear_namespace = curbufmeths.clear_namespace

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

    add_highlight(-1, "String", 0 , 10, 14)
    add_highlight(-1, "Statement", 1 , 5, -1)

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

    clear_namespace(-1, 0, -1)
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

  describe('support using multiple namespaces', function()
    local id1, id2
    before_each(function()
      insert([[
        a longer example
        in order to demonstrate
        combining highlights
        from different sources]])

      command("hi ImportantWord gui=bold cterm=bold")
      id1 = add_highlight(0, "ImportantWord", 0, 2, 8)
      add_highlight(id1, "ImportantWord", 1, 12, -1)
      add_highlight(id1, "ImportantWord", 2, 0, 9)
      add_highlight(id1, "ImportantWord", 3, 5, 14)

      -- add_highlight can be called like this to get a new source
      -- without adding any highlight
      id2 = add_highlight(0, "", 0, 0, 0)
      neq(id1, id2)

      add_highlight(id2, "Special", 0, 2, 8)
      add_highlight(id2, "Identifier", 1, 3, 8)
      add_highlight(id2, "Special", 1, 14, 20)
      add_highlight(id2, "Underlined", 2, 6, 12)
      add_highlight(id2, "Underlined", 3, 0, 9)

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
      clear_namespace(id1, 0, -1)
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

    it('and clearing using deprecated name', function()
      curbufmeths.clear_highlight(id1, 0, -1)
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
      clear_namespace(id2, 0, -1)
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
      clear_namespace(-1, 0, 1)
      clear_namespace(id1, 1, 2)
      clear_namespace(id2, 2, -1)
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

      -- TODO(bfedl): this behaves a bit weirdly due to the highlight on
      -- the deleted line wrapping around. we should invalidate
      -- highlights when they are completely inside deleted text
      command('3move 4')
      screen:expect{grid=[[
        a {5:longer} example                        |
                                                |
        {8:from different sources}                  |
        {8:^in }{20:order}{8: to demonstrate}                 |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}
      --screen:expect([[
      --  a {5:longer} example                        |
      --                                          |
      --  {9:from }{8:diff}{7:erent} sources                  |
      --  ^in {6:order} to {7:de}{5:monstr}{7:ate}                 |
      --  {1:~                                       }|
      --  {1:~                                       }|
      --  {1:~                                       }|
      --                                          |
      --]])

      command('undo')
      screen:expect{grid=[[
        a {5:longer} example                        |
        ^                                        |
        in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        1 change; before #4  {MATCH:.*}|
      ]]}

      command('undo')
      screen:expect{grid=[[
        ^a {5:longer} example                        |
        in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        1 line less; before #3  {MATCH:.*}|
      ]]}

      command('undo')
      screen:expect{grid=[[
        a {5:longer} example                        |
        in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {7:^combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        1 more line; before #2  {MATCH:.*}|
      ]]}
    end)

    it('and moving lines around', function()
      command('2move 3')
      screen:expect{grid=[[
        a {5:longer} example                        |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        ^in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}

      command('1,2move 4')
      screen:expect{grid=[[
        in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {9:from }{8:diff}{7:erent} sources                  |
        a {5:longer} example                        |
        {7:^combin}{8:ing}{9: hi}ghlights                    |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}

      command('undo')
      screen:expect{grid=[[
        a {5:longer} example                        |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        ^in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        2 change3; before #3  {MATCH:.*}|
      ]]}

      command('undo')
      screen:expect{grid=[[
        a {5:longer} example                        |
        ^in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        1 change; before #2  {MATCH:.*}|
      ]]}
    end)

    it('and adjusting columns', function()
      -- insert before
      feed('ggiquite <esc>')
      screen:expect{grid=[[
        quite^ a {5:longer} example                  |
        in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}

      feed('u')
      screen:expect{grid=[[
        ^a {5:longer} example                        |
        in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        1 change; before #2  {MATCH:.*}|
      ]]}

      -- change/insert in the middle
      feed('+fesAAAA')
      screen:expect{grid=[[
        a {5:longer} example                        |
        in {6:ordAAAA^r} to {7:de}{5:monstr}{7:ate}              |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {7:-- INSERT --}                            |
      ]]}

      feed('<esc>tdD')
      screen:expect{grid=[[
        a {5:longer} example                        |
        in {6:ordAAAAr} t^o                          |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}

      feed('u')
      screen:expect{grid=[[
        a {5:longer} example                        |
        in {6:ordAAAAr} to^ {7:de}{5:monstr}{7:ate}              |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        1 change; before #4  {MATCH:.*}|
      ]]}

      feed('u')
      screen:expect{grid=[[
        a {5:longer} example                        |
        in {6:ord^er} to {7:de}{5:monstr}{7:ate}                 |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        1 change; before #3  {MATCH:.*}|
      ]]}
    end)

    it('and joining lines', function()
      feed('ggJJJ')
      screen:expect{grid=[[
        a {5:longer} example in {6:order} to {7:de}{5:monstr}{7:ate}|
         {7:combin}{8:ing}{9: hi}ghlights^ {9:from }{8:diff}{7:erent} sou|
        rces                                    |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}

      feed('uuu')
      screen:expect{grid=[[
        ^a {5:longer} example                        |
        in {6:order} to {7:de}{5:monstr}{7:ate}                 |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        1 more line; before #2  {MATCH:.*}|
      ]]}
    end)

    it('and splitting lines', function()
      feed('2Gtti<cr>')
      screen:expect{grid=[[
        a {5:longer} example                        |
        in {6:order}                                |
        ^ to {7:de}{5:monstr}{7:ate}                         |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {7:-- INSERT --}                            |
      ]]}

      feed('<esc>tsi<cr>')
      screen:expect{grid=[[
        a {5:longer} example                        |
        in {6:order}                                |
         to {7:de}{5:mo}                                |
        {5:^nstr}{7:ate}                                 |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {7:-- INSERT --}                            |
      ]]}

      feed('<esc>u')
      screen:expect{grid=[[
        a {5:longer} example                        |
        in {6:order}                                |
         to {7:de}{5:mo^nstr}{7:ate}                         |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        1 line less; before #3  {MATCH:.*}|
      ]]}

      feed('<esc>u')
      screen:expect{grid=[[
        a {5:longer} example                        |
        in {6:order}^ to {7:de}{5:monstr}{7:ate}                 |
        {7:combin}{8:ing}{9: hi}ghlights                    |
        {9:from }{8:diff}{7:erent} sources                  |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        1 line less; before #2  {MATCH:.*}|
      ]]}
    end)
  end)

  pending('prioritizes latest added highlight', function()
    insert([[
      three overlapping colors]])
    add_highlight(0, "Identifier", 0, 6, 17)
    add_highlight(0, "String", 0, 14, 23)
    local id = add_highlight(0, "Special", 0, 0, 9)

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

    clear_namespace(id, 0, 1)
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

  it('prioritizes earlier highlight groups (TEMP)', function()
    insert([[
      three overlapping colors]])
    add_highlight(0, "Identifier", 0, 6, 17)
    add_highlight(0, "String", 0, 14, 23)
    local id = add_highlight(0, "Special", 0, 0, 9)

    screen:expect{grid=[[
      {4:three }{6:overlapp}{2:ing color}^s                |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]]}

    clear_namespace(id, 0, 1)
    screen:expect{grid=[[
      three {6:overlapp}{2:ing color}^s                |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]]}
  end)

  it('respects priority', function()
    local set_extmark = curbufmeths.set_extmark
    local id = meths.create_namespace('')
    insert [[foobar]]

    set_extmark(id, 0, 0, {
      end_line = 0,
      end_col = 5,
      hl_group = "Statement",
      priority = 100
    })
    set_extmark(id, 0, 0, {
      end_line = 0,
      end_col = 6,
      hl_group = "String",
      priority = 1
    })

    screen:expect [[
      {3:fooba}{2:^r}                                  |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]]

    clear_namespace(id, 0, -1)

    set_extmark(id, 0, 0, {
      end_line = 0,
      end_col = 6,
      hl_group = "String",
      priority = 1
    })
    set_extmark(id, 0, 0, {
      end_line = 0,
      end_col = 5,
      hl_group = "Statement",
      priority = 100
    })

    screen:expect [[
      {3:fooba}{2:^r}                                  |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]]
  end)

  it('works with multibyte text', function()
    insert([[
      Ta båten över sjön!]])
    add_highlight(-1, "Identifier", 0, 3, 9)
    add_highlight(-1, "String", 0, 16, 21)

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
    add_highlight(-1, "FancyLangItem", 0, 0, 5)
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

  describe('virtual text decorations', function()
    local set_virtual_text = curbufmeths.set_virtual_text
    local id1, id2
    before_each(function()
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

      id1 = set_virtual_text(0, 0, {{"=", "Statement"}, {" 3", "Number"}}, {})
      set_virtual_text(id1, 1, {{"ERROR:", "ErrorMsg"}, {" invalid syntax"}}, {})
      id2 = set_virtual_text(0, 2, {{"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."}}, {})
      neq(id2, id1)

    end)

    it('works', function()
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

      clear_namespace(id1, 0, -1)
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
      eq(-1, set_virtual_text(-1, 1, {{"暗x事zz速野谷質結育副住新覚丸活解終事", "Comment"}}, {}))
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

      feed("2Gdd")
      -- TODO(bfredl): currently decorations get moved from a deleted line
      -- to the next one. We might want to add "invalidation" when deleting
      -- over a decoration.
      screen:expect{grid=[[
        1 + 2                                   |
        ^5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,  {12:暗x事zz速野谷質結育}|
        x = 4                                   |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}
      --screen:expect([[
      --  1 + 2                                   |
      --  ^5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
      --  , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
      --  x = 4                                   |
      --  {1:~                                       }|
      --  {1:~                                       }|
      --  {1:~                                       }|
      --                                          |
      --]])
    end)

    it('validates contents', function()
      -- this used to leak memory
      eq('Chunk is not an array', pcall_err(set_virtual_text, id1, 0, {"texty"}, {}))
      eq('Chunk is not an array', pcall_err(set_virtual_text, id1, 0, {{"very"}, "texty"}, {}))
    end)

    it('can be retrieved', function()
      local get_extmarks = curbufmeths.get_extmarks
      local line_count = curbufmeths.line_count

      local s1 = {{'Köttbullar', 'Comment'}, {'Kräuterbutter'}}
      local s2 = {{'こんにちは', 'Comment'}}

      -- TODO: only a virtual text from the same ns curretly overrides
      -- an existing virtual text. We might add a prioritation system.
      set_virtual_text(id1, 0, s1, {})
      eq({{1, 0, 0, { priority = 0, virt_text = s1}}}, get_extmarks(id1, {0,0}, {0, -1}, {details=true}))

      -- TODO: is this really valid? shouldn't the max be line_count()-1?
      local lastline = line_count()
      set_virtual_text(id1, line_count(), s2, {})
      eq({{3, lastline, 0, { priority = 0, virt_text = s2}}}, get_extmarks(id1, {lastline,0}, {lastline, -1}, {details=true}))

      eq({}, get_extmarks(id1, {lastline+9000,0}, {lastline+9000, -1}, {}))
    end)

    it('is not highlighted by visual selection', function()
      feed("ggVG")
      screen:expect([[
        {13:1 + 2} {3:=}{2: 3}                               |
        {13:3 +} {11:ERROR:} invalid syntax               |
        {13:5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5}|
        {13:, 5, 5, 5, 5, 5, 5, } Lorem ipsum dolor s|
        ^x{13: = 4}                                   |
        {1:~                                       }|
        {1:~                                       }|
        {7:-- VISUAL LINE --}                       |
      ]])

      feed("<esc>")
      screen:expect([[
        1 + 2 {3:=}{2: 3}                               |
        3 + {11:ERROR:} invalid syntax               |
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
        ^x = 4                                   |
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])

      -- special case: empty line has extra eol highlight
      feed("ggd$")
      screen:expect([[
        ^ {3:=}{2: 3}                                    |
        3 + {11:ERROR:} invalid syntax               |
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
        x = 4                                   |
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])

      feed("jvk")
      screen:expect([[
        ^ {3:=}{2: 3}                                    |
        {13:3} + {11:ERROR:} invalid syntax               |
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
        x = 4                                   |
        {1:~                                       }|
        {1:~                                       }|
        {7:-- VISUAL --}                            |
      ]])

      feed("o")
      screen:expect([[
        {13: }{3:=}{2: 3}                                    |
        ^3 + {11:ERROR:} invalid syntax               |
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
        x = 4                                   |
        {1:~                                       }|
        {1:~                                       }|
        {7:-- VISUAL --}                            |
      ]])
    end)


    it('works with listchars', function()
      command("set list listchars+=eol:$")
      screen:expect([[
        ^1 + 2{1:$}{3:=}{2: 3}                               |
        3 +{1:$}{11:ERROR:} invalid syntax               |
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,{1:-$}Lorem ipsum dolor s|
        x = 4{1:$}                                  |
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])

      clear_namespace(-1, 0, -1)
      screen:expect([[
        ^1 + 2{1:$}                                  |
        3 +{1:$}                                    |
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,{1:-$}                   |
        x = 4{1:$}                                  |
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])
    end)

    it('works with cursorline', function()
      command("set cursorline")

      screen:expect{grid=[[
        {14:^1 + 2 }{3:=}{2: 3}{14:                               }|
        3 + {11:ERROR:} invalid syntax               |
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
        x = 4                                   |
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}

      feed('j')
      screen:expect{grid=[[
        1 + 2 {3:=}{2: 3}                               |
        {14:^3 + }{11:ERROR:} invalid syntax{14:               }|
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
        x = 4                                   |
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}


      feed('j')
      screen:expect{grid=[[
        1 + 2 {3:=}{2: 3}                               |
        3 + {11:ERROR:} invalid syntax               |
        {14:^5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5}|
        {14:, 5, 5, 5, 5, 5, 5,  }Lorem ipsum dolor s|
        x = 4                                   |
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}
    end)

    it('works with color column', function()
      eq(-1, set_virtual_text(-1, 3, {{"暗x事", "Comment"}}, {}))
      screen:expect{grid=[[
        ^1 + 2 {3:=}{2: 3}                               |
        3 + {11:ERROR:} invalid syntax               |
        5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
        x = 4 {12:暗x事}                             |
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}

      command("set colorcolumn=9")
      screen:expect{grid=[[
        ^1 + 2 {3:=}{2: 3}                               |
        3 + {11:ERROR:} invalid syntax               |
        5, 5, 5,{18: }5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5|
        , 5, 5, 5, 5, 5, 5,  Lorem ipsum dolor s|
        x = 4 {12:暗x事}                             |
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]]}
    end)
  end)

  it('and virtual text use the same namespace counter', function()
    local set_virtual_text = curbufmeths.set_virtual_text
    eq(1, add_highlight(0, "String", 0 , 0, -1))
    eq(2, set_virtual_text(0, 0, {{"= text", "Comment"}}, {}))
    eq(3, meths.create_namespace("my-ns"))
    eq(4, add_highlight(0, "String", 0 , 0, -1))
    eq(5, set_virtual_text(0, 0, {{"= text", "Comment"}}, {}))
    eq(6, meths.create_namespace("other-ns"))
  end)
end)
