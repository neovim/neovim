local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command, request, neq = helpers.command, helpers.request, helpers.neq

describe('Buffer highlighting', function()
  local screen
  local curbuf

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
      [10] = {foreground = Screen.colors.Red}
    })
    curbuf = request('nvim_get_current_buf')
  end)

  after_each(function()
    screen:detach()
  end)

  local function add_hl(...)
    return request('nvim_buf_add_highlight', curbuf, ...)
  end

  local function clear_hl(...)
    return request('nvim_buf_clear_highlight', curbuf, ...)
  end


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

    clear_hl(-1, 0 , -1)
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
end)
