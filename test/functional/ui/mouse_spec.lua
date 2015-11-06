local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, nvim = helpers.clear, helpers.feed, helpers.nvim
local insert, execute = helpers.insert, helpers.execute

describe('Mouse input', function()
  local screen

  local hlgroup_colors = {
    NonText = Screen.colors.Blue,
    Visual = Screen.colors.LightGrey
  }

  before_each(function()
    clear()
    nvim('set_option', 'mouse', 'a')
    -- set mouset to very high value to ensure that even in valgrind/travis,
    -- nvim will still pick multiple clicks
    nvim('set_option', 'mouset', 5000)
    screen = Screen.new(25, 5)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {background = hlgroup_colors.Visual},
      [2] = {bold = true}
    })
    screen:set_default_attr_ignore( {{bold=true, foreground=hlgroup_colors.NonText}} )
    feed('itesting<cr>mouse<cr>support and selection<esc>')
    screen:expect([[
      testing                  |
      mouse                    |
      support and selectio^n    |
      ~                        |
                               |
    ]])
  end)

  after_each(function()
    screen:detach()
  end)

  it('left click moves cursor', function()
    feed('<LeftMouse><2,1>')
    screen:expect([[
      testing                  |
      mo^use                    |
      support and selection    |
      ~                        |
                               |
    ]])
    feed('<LeftMouse><0,0>')
    screen:expect([[
      ^testing                  |
      mouse                    |
      support and selection    |
      ~                        |
                               |
    ]])
  end)

  it('left click in tabline switches to tab', function()
    local tab_attrs = {
      tab  = { background=Screen.colors.LightGrey, underline=true },
      sel  = { bold=true },
      fill = { reverse=true }
    }
    execute('%delete')
    insert('this is foo')
    execute('silent file foo | tabnew | file bar')
    insert('this is bar')
    screen:expect([[
      {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
      this is ba^r              |
      ~                        |
      ~                        |
                               |
    ]], tab_attrs)
    feed('<LeftMouse><4,0>')
    screen:expect([[
      {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
      this is fo^o              |
      ~                        |
      ~                        |
                               |
    ]], tab_attrs)
  end)

  it('left drag changes visual selection', function()
    -- drag events must be preceded by a click
    feed('<LeftMouse><2,1>')
    screen:expect([[
      testing                  |
      mo^use                    |
      support and selection    |
      ~                        |
                               |
    ]])
    feed('<LeftDrag><4,1>')
    screen:expect([[
      testing                  |
      mo{1:us}^e                    |
      support and selection    |
      ~                        |
      {2:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><2,2>')
    screen:expect([[
      testing                  |
      mo{1:use }                   |
      {1:su}^pport and selection    |
      ~                        |
      {2:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><0,0>')
    screen:expect([[
      ^t{1:esting }                 |
      {1:mou}se                    |
      support and selection    |
      ~                        |
      {2:-- VISUAL --}             |
    ]])
  end)

  it('left drag changes visual selection after tab click', function()
    local tab_attrs = {
      tab  = { background=Screen.colors.LightGrey, underline=true },
      sel  = { bold=true },
      fill = { reverse=true },
      vis  = { background=Screen.colors.LightGrey }
    }
    execute('silent file foo | tabnew | file bar')
    insert('this is bar')
    execute('tabprevious')  -- go to first tab
    screen:expect([[
      {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
      mouse                    |
      support and selectio^n    |
      ~                        |
                               |
    ]], tab_attrs)
    feed('<LeftMouse><10,0><LeftRelease>')  -- go to second tab
    helpers.wait()
    feed('<LeftMouse><0,1>')
    screen:expect([[
      {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
      ^this is bar              |
      ~                        |
      ~                        |
                               |
    ]], tab_attrs)
    feed('<LeftDrag><4,1>')
    screen:expect([[
      {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
      {vis:this}^ is bar              |
      ~                        |
      ~                        |
      {sel:-- VISUAL --}             |
    ]], tab_attrs)
  end)

  it('two clicks will select the word and enter VISUAL', function()
    feed('<LeftMouse><2,2><LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {1:suppor}^t and selection    |
      ~                        |
      {2:-- VISUAL --}             |
    ]])
  end)

  it('three clicks will select the line and enter VISUAL LINE', function()
    feed('<LeftMouse><2,2><LeftMouse><2,2><LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {1:su}^p{1:port and selection }   |
      ~                        |
      {2:-- VISUAL LINE --}        |
    ]])
  end)

  it('four clicks will enter VISUAL BLOCK', function()
    feed('<LeftMouse><2,2><LeftMouse><2,2><LeftMouse><2,2><LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      su^pport and selection    |
      ~                        |
      {2:-- VISUAL BLOCK --}       |
    ]])
  end)

  it('right click extends visual selection to the clicked location', function()
    feed('<LeftMouse><0,0>')
    screen:expect([[
      ^testing                  |
      mouse                    |
      support and selection    |
      ~                        |
                               |
    ]])
    feed('<RightMouse><2,2>')
    screen:expect([[
      {1:testing }                 |
      {1:mouse }                   |
      {1:su}^pport and selection    |
      ~                        |
      {2:-- VISUAL --}             |
    ]])
  end)

  it('ctrl + left click will search for a tag', function()
    nvim('set_option', 'tags', './non-existent-tags-file')
    feed('<C-LeftMouse><0,0>')
    screen:expect([[
      E433: No tags file       |
      E426: tag not found: test|
      ing                      |
      Press ENTER or type comma|
      nd to continue^           |
    ]],nil,true)
    feed('<cr>')
  end)

  it('mouse whell will target the hovered window', function()
    feed('ggdG')
    insert([[
    Inserting
    text
    with
    many
    lines
    to
    test
    mouse scrolling
    ]])
    screen:try_resize(53, 14)
    execute('sp', 'vsp')
    screen:set_default_attr_ignore( {{bold=true, foreground=hlgroup_colors.NonText},
            {reverse=true}, {bold=true, reverse=true}} )
    screen:expect([[
      lines                     |lines                     |
      to                        |to                        |
      test                      |test                      |
      mouse scrolling           |mouse scrolling           |
      ^                          |                          |
      ~                         |~                         |
      [No Name] [+]              [No Name] [+]             |
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      ~                                                    |
      [No Name] [+]                                        |
      :vsp                                                 |
    ]])
    feed('<MouseUp><0,0>')
    screen:expect([[
      mouse scrolling           |lines                     |
      ^                          |to                        |
      ~                         |test                      |
      ~                         |mouse scrolling           |
      ~                         |                          |
      ~                         |~                         |
      [No Name] [+]              [No Name] [+]             |
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      ~                                                    |
      [No Name] [+]                                        |
                                                           |
    ]])
    feed('<MouseDown><27,0>')
    screen:expect([[
      mouse scrolling           |text                      |
      ^                          |with                      |
      ~                         |many                      |
      ~                         |lines                     |
      ~                         |to                        |
      ~                         |test                      |
      [No Name] [+]              [No Name] [+]             |
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      ~                                                    |
      [No Name] [+]                                        |
                                                           |
    ]])
    feed('<MouseDown><27,7><MouseDown>')
    screen:expect([[
      mouse scrolling           |text                      |
      ^                          |with                      |
      ~                         |many                      |
      ~                         |lines                     |
      ~                         |to                        |
      ~                         |test                      |
      [No Name] [+]              [No Name] [+]             |
      Inserting                                            |
      text                                                 |
      with                                                 |
      many                                                 |
      lines                                                |
      [No Name] [+]                                        |
                                                           |
    ]])
  end)
end)
