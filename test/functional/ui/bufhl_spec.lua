local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, request, neq = helpers.execute, helpers.request, helpers.neq


describe('Buffer highlighting', function()
  local screen
  local curbuf

  local hl_colors = {
    NonText = Screen.colors.Blue,
    Question = Screen.colors.SeaGreen,
    String = Screen.colors.Fuchsia,
    Statement = Screen.colors.Brown,
    Special = Screen.colors.SlateBlue,
    Identifier = Screen.colors.DarkCyan
  }

  before_each(function()
    clear()
    execute("syntax on")
    screen = Screen.new(40, 8)
    screen:attach()
    screen:set_default_attr_ignore( {{bold=true, foreground=hl_colors.NonText}} )
    screen:set_default_attr_ids({
      [1] = {foreground = hl_colors.String},
      [2] = {foreground = hl_colors.Statement, bold = true},
      [3] = {foreground = hl_colors.Special},
      [4] = {bold = true, foreground = hl_colors.Special},
      [5] = {foreground = hl_colors.Identifier},
      [6] = {bold = true},
      [7] = {underline = true, bold = true, foreground = hl_colors.Special},
      [8] = {foreground = hl_colors.Special, underline = true}
    })
    curbuf = request('vim_get_current_buffer')
  end)

  after_each(function()
    screen:detach()
  end)

  local function add_hl(...)
    return request('buffer_add_highlight', curbuf, ...)
  end

  local function clear_hl(...)
    return request('buffer_clear_highlight', curbuf, ...)
  end


  it('works', function()
    insert([[
      these are some lines
      with colorful text]])
    feed('+')

    screen:expect([[
      these are some lines                    |
      with colorful tex^t                      |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])

    add_hl(-1, "String", 0 , 10, 14)
    add_hl(-1, "Statement", 1 , 5, -1)

    screen:expect([[
      these are {1:some} lines                    |
      with {2:colorful tex^t}                      |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])

    feed("ggo<esc>")
    screen:expect([[
      these are {1:some} lines                    |
      ^                                        |
      with {2:colorful text}                      |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])

    clear_hl(-1, 0 , -1)
    screen:expect([[
      these are some lines                    |
      ^                                        |
      with colorful text                      |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
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

      execute("hi ImportantWord gui=bold cterm=bold")
      id1 = add_hl(0, "ImportantWord", 0, 2, 8)
      add_hl(id1, "ImportantWord", 1, 12, -1)
      add_hl(id1, "ImportantWord", 2, 0, 9)
      add_hl(id1, "ImportantWord", 3, 5, 14)

      id2 = add_hl(0, "Special", 0, 2, 8)
      add_hl(id2, "Identifier", 1, 3, 8)
      add_hl(id2, "Special", 1, 14, 20)
      add_hl(id2, "Underlined", 2, 6, 12)
      add_hl(id2, "Underlined", 3, 0, 9)
      neq(id1, id2)

      screen:expect([[
        a {4:longer} example                        |
        in {5:order} to {6:de}{4:monstr}{6:ate}                 |
        {6:combin}{7:ing}{8: hi}ghlights                    |
        {8:from }{7:diff}{6:erent} source^s                  |
        ~                                       |
        ~                                       |
        ~                                       |
        :hi ImportantWord gui=bold cterm=bold   |
      ]])
    end)

    it('and clearing the first added', function()
      clear_hl(id1, 0, -1)
      screen:expect([[
        a {3:longer} example                        |
        in {5:order} to de{3:monstr}ate                 |
        combin{8:ing hi}ghlights                    |
        {8:from diff}erent source^s                  |
        ~                                       |
        ~                                       |
        ~                                       |
        :hi ImportantWord gui=bold cterm=bold   |
      ]])
    end)

    it('and clearing the second added', function()
      clear_hl(id2, 0, -1)
      screen:expect([[
        a {6:longer} example                        |
        in order to {6:demonstrate}                 |
        {6:combining} highlights                    |
        from {6:different} source^s                  |
        ~                                       |
        ~                                       |
        ~                                       |
        :hi ImportantWord gui=bold cterm=bold   |
      ]])
    end)

    it('and clearing line ranges', function()
      clear_hl(-1, 0, 1)
      clear_hl(id1, 1, 2)
      clear_hl(id2, 2, -1)
      screen:expect([[
        a longer example                        |
        in {5:order} to de{3:monstr}ate                 |
        {6:combining} highlights                    |
        from {6:different} source^s                  |
        ~                                       |
        ~                                       |
        ~                                       |
        :hi ImportantWord gui=bold cterm=bold   |
      ]])
    end)

    it('and renumbering lines', function()
      feed('3Gddggo<esc>')
      screen:expect([[
        a {4:longer} example                        |
        ^                                        |
        in {5:order} to {6:de}{4:monstr}{6:ate}                 |
        {8:from }{7:diff}{6:erent} sources                  |
        ~                                       |
        ~                                       |
        ~                                       |
                                                |
      ]])

      execute(':3move 4')
      screen:expect([[
        a {4:longer} example                        |
                                                |
        {8:from }{7:diff}{6:erent} sources                  |
        ^in {5:order} to {6:de}{4:monstr}{6:ate}                 |
        ~                                       |
        ~                                       |
        ~                                       |
        ::3move 4                               |
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
      {3:three ove}{5:rlapp}{1:ing color}^s                |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])

    clear_hl(id, 0, 1)
    screen:expect([[
      three {5:overlapp}{1:ing color}^s                |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
  end)

  it('works with multibyte text', function()
    insert([[
      Ta båten över sjön!]])
    add_hl(-1, "Identifier", 0, 3, 9)
    add_hl(-1, "String", 0, 16, 21)

    screen:expect([[
      Ta {5:båten} över {1:sjön}^!                     |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
  end)
end)
