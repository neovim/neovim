local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, meths = helpers.clear, helpers.feed, helpers.meths
local insert, execute = helpers.insert, helpers.execute
local eq, funcs = helpers.eq, helpers.funcs

describe('Mouse input', function()
  local screen

  local hlgroup_colors = {
    NonText = Screen.colors.Blue,
    Visual = Screen.colors.LightGrey
  }

  before_each(function()
    clear()
    meths.set_option('mouse', 'a')
    meths.set_option('listchars', 'eol:$')
    -- set mouset to very high value to ensure that even in valgrind/travis,
    -- nvim will still pick multiple clicks
    meths.set_option('mouset', 5000)
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

  describe('tabline', function()
    local tab_attrs = {
      tab  = { background=Screen.colors.LightGrey, underline=true },
      sel  = { bold=true },
      fill = { reverse=true }
    }

    it('left click in default tabline (position 4) switches to tab', function()
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

    it('left click in default tabline (position 24) closes tab', function()
      meths.set_option('hidden', true)
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
      feed('<LeftMouse><24,0>')
      screen:expect([[
        this is fo^o              |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], tab_attrs)
    end)

    it('double click in default tabline (position 4) opens new tab', function()
      meths.set_option('hidden', true)
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
      feed('<2-LeftMouse><4,0>')
      screen:expect([[
        {sel:  Name] }{tab: + foo  + bar }{fill:  }{tab:X}|
        ^                         |
        ~                        |
        ~                        |
                                 |
      ]], tab_attrs)
    end)

    describe('%@ label', function()
      before_each(function()
        execute([[
          function Test(...)
            let g:reply = a:000
            return copy(a:000)  " Check for memory leaks: return should be freed
          endfunction
        ]])
        execute([[
          function Test2(...)
            return call('Test', a:000 + [2])
          endfunction
        ]])
        meths.set_option('tabline', '%@Test@test%X-%5@Test2@test2')
        meths.set_option('showtabline', 2)
        screen:expect([[
          {fill:test-test2               }|
          mouse                    |
          support and selectio^n    |
          ~                        |
                                   |
        ]], tab_attrs)
        meths.set_var('reply', {})
      end)

      local check_reply = function(expected)
        eq(expected, meths.get_var('reply'))
        meths.set_var('reply', {})
      end

      local test_click = function(name, click_str, click_num, mouse_button,
                                  modifiers)
        it(name .. ' works', function()
          eq(1, funcs.has('tablineat'))
          feed(click_str .. '<3,0>')
          check_reply({0, click_num, mouse_button, modifiers})
          feed(click_str .. '<4,0>')
          check_reply({})
          feed(click_str .. '<6,0>')
          check_reply({5, click_num, mouse_button, modifiers, 2})
          feed(click_str .. '<13,0>')
          check_reply({5, click_num, mouse_button, modifiers, 2})
        end)
      end

      test_click('single left click', '<LeftMouse>', 1, 'l', '    ')
      test_click('shifted single left click', '<S-LeftMouse>', 1, 'l', 's   ')
      test_click('shifted single left click with alt modifier',
                 '<S-A-LeftMouse>', 1, 'l', 's a ')
      test_click('shifted single left click with alt and ctrl modifiers',
                 '<S-C-A-LeftMouse>', 1, 'l', 'sca ')
      -- <C-RightMouse> does not work
      test_click('shifted single right click with alt modifier',
                 '<S-A-RightMouse>', 1, 'r', 's a ')
      -- Modifiers do not work with MiddleMouse
      test_click('shifted single middle click with alt and ctrl modifiers',
                 '<MiddleMouse>', 1, 'm', '    ')
      -- Modifiers do not work with N-*Mouse
      test_click('double left click', '<2-LeftMouse>', 2, 'l', '    ')
      test_click('triple left click', '<3-LeftMouse>', 3, 'l', '    ')
      test_click('quadruple left click', '<4-LeftMouse>', 4, 'l', '    ')
      test_click('double right click', '<2-RightMouse>', 2, 'r', '    ')
      test_click('triple right click', '<3-RightMouse>', 3, 'r', '    ')
      test_click('quadruple right click', '<4-RightMouse>', 4, 'r', '    ')
      test_click('double middle click', '<2-MiddleMouse>', 2, 'm', '    ')
      test_click('triple middle click', '<3-MiddleMouse>', 3, 'm', '    ')
      test_click('quadruple middle click', '<4-MiddleMouse>', 4, 'm', '    ')
    end)
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
    meths.set_option('tags', './non-existent-tags-file')
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
