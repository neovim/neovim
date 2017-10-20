local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, meths = helpers.clear, helpers.feed, helpers.meths
local insert, feed_command = helpers.insert, helpers.feed_command
local eq, funcs = helpers.eq, helpers.funcs

describe('ui/mouse/input', function()
  local screen

  before_each(function()
    clear()
    meths.set_option('mouse', 'a')
    meths.set_option('listchars', 'eol:$')
    screen = Screen.new(25, 5)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {background = Screen.colors.LightGrey},
      [2] = {bold = true},
      [3] = {
        foreground = Screen.colors.Blue,
        background = Screen.colors.LightGrey,
        bold = true,
      },
      [4] = {reverse = true},
      [5] = {bold = true, reverse = true},
    })
    feed('itesting<cr>mouse<cr>support and selection<esc>')
    screen:expect([[
      testing                  |
      mouse                    |
      support and selectio^n    |
      {0:~                        }|
                               |
    ]])
  end)

  after_each(function()
    screen:detach()
  end)

  it('single left click moves cursor', function()
    feed('<LeftMouse><2,1>')
    screen:expect([[
      testing                  |
      mo^use                    |
      support and selection    |
      {0:~                        }|
                               |
    ]])
    feed('<LeftMouse><0,0>')
    screen:expect([[
      ^testing                  |
      mouse                    |
      support and selection    |
      {0:~                        }|
                               |
    ]])
  end)

  it('double left click enters visual mode', function()
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    screen:expect([[
      {1:testin}^g                  |
      mouse                    |
      support and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
  end)

  it('triple left click enters visual line mode', function()
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    screen:expect([[
      ^t{1:esting}{3: }                 |
      mouse                    |
      support and selection    |
      {0:~                        }|
      {2:-- VISUAL LINE --}        |
    ]])
  end)

  it('quadruple left click enters visual block mode', function()
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    screen:expect([[
      ^testing                  |
      mouse                    |
      support and selection    |
      {0:~                        }|
      {2:-- VISUAL BLOCK --}       |
    ]])
  end)

  describe('tab drag', function()
    before_each(function()
      screen:set_default_attr_ids( {
        [0] = {bold=true, foreground=Screen.colors.Blue},
        tab  = { background=Screen.colors.LightGrey, underline=true },
        sel  = { bold=true },
        fill = { reverse=true }
      })
    end)

    it('in tabline on filler space moves tab to the end', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftDrag><14,0>')
      screen:expect([[
        {tab: + bar }{sel: + foo }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end)

    it('in tabline to the left moves tab left', function()
      if helpers.skip_fragile(pending,
        os.getenv("TRAVIS") and (helpers.os_name() == "osx"
          or os.getenv("CLANG_SANITIZER") == "ASAN_UBSAN"))  -- #4874
      then
        return
      end

      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><11,0>')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftDrag><6,0>')
      screen:expect([[
        {sel: + bar }{tab: + foo }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end)

    it('in tabline to the right moves tab right', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftDrag><7,0>')
      screen:expect([[
        {tab: + bar }{sel: + foo }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end)

    it('out of tabline under filler space moves tab to the end', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftDrag><4,1>')
      screen:expect([[
        {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftDrag><14,1>')
      screen:expect([[
        {tab: + bar }{sel: + foo }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end)

    it('out of tabline to the left moves tab left', function()
      if helpers.skip_fragile(pending,
        os.getenv("TRAVIS") and (helpers.os_name() == "osx"
          or os.getenv("CLANG_SANITIZER") == "ASAN_UBSAN"))  -- #4874
      then
        return
      end

      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><11,0>')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftDrag><11,1>')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftDrag><6,1>')
      screen:expect([[
        {sel: + bar }{tab: + foo }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end)

    it('out of tabline to the right moves tab right', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftDrag><4,1>')
      screen:expect([[
        {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftDrag><7,1>')
      screen:expect([[
        {tab: + bar }{sel: + foo }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end)
  end)

  describe('tabline', function()
    before_each(function()
      screen:set_default_attr_ids( {
        [0] = {bold=true, foreground=Screen.colors.Blue},
        tab  = { background=Screen.colors.LightGrey, underline=true },
        sel  = { bold=true },
        fill = { reverse=true }
      })
    end)

    it('left click in default tabline (position 4) switches to tab', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end)

    it('left click in default tabline (position 24) closes tab', function()
      meths.set_option('hidden', true)
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><24,0>')
      screen:expect([[
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end)

    it('double click in default tabline (position 4) opens new tab', function()
      meths.set_option('hidden', true)
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<2-LeftMouse><4,0>')
      screen:expect([[
        {sel:  Name] }{tab: + foo  + bar }{fill:  }{tab:X}|
        ^                         |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end)

    describe('%@ label', function()
      before_each(function()
        feed_command([[
          function Test(...)
            let g:reply = a:000
            return copy(a:000)  " Check for memory leaks: return should be freed
          endfunction
        ]])
        feed_command([[
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
          {0:~                        }|
                                   |
        ]])
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
      {0:~                        }|
                               |
    ]])
    feed('<LeftDrag><4,1>')
    screen:expect([[
      testing                  |
      mo{1:us}^e                    |
      support and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><2,2>')
    screen:expect([[
      testing                  |
      mo{1:use}{3: }                   |
      {1:su}^pport and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><0,0>')
    screen:expect([[
      ^t{1:esting}{3: }                 |
      {1:mou}se                    |
      support and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
  end)

  it('left drag changes visual selection after tab click', function()
    screen:set_default_attr_ids({
      [0] = {bold=true, foreground=Screen.colors.Blue},
      tab  = { background=Screen.colors.LightGrey, underline=true },
      sel  = { bold=true },
      fill = { reverse=true },
      vis  = { background=Screen.colors.LightGrey }
    })
    feed_command('silent file foo | tabnew | file bar')
    insert('this is bar')
    feed_command('tabprevious')  -- go to first tab
    screen:expect([[
      {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
      mouse                    |
      support and selectio^n    |
      {0:~                        }|
                               |
    ]])
    feed('<LeftMouse><10,0><LeftRelease>')  -- go to second tab
    helpers.wait()
    feed('<LeftMouse><0,1>')
    screen:expect([[
      {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
      ^this is bar              |
      {0:~                        }|
      {0:~                        }|
                               |
    ]])
    feed('<LeftDrag><4,1>')
    screen:expect([[
      {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
      {vis:this}^ is bar              |
      {0:~                        }|
      {0:~                        }|
      {sel:-- VISUAL --}             |
    ]])
  end)

  it('two clicks will select the word and enter VISUAL', function()
    feed('<LeftMouse><2,2><LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {1:suppor}^t and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
  end)

  it('three clicks will select the line and enter VISUAL LINE', function()
    feed('<LeftMouse><2,2><LeftMouse><2,2><LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {1:su}^p{1:port and selection}{3: }   |
      {0:~                        }|
      {2:-- VISUAL LINE --}        |
    ]])
  end)

  it('four clicks will enter VISUAL BLOCK', function()
    feed('<LeftMouse><2,2><LeftMouse><2,2><LeftMouse><2,2><LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      su^pport and selection    |
      {0:~                        }|
      {2:-- VISUAL BLOCK --}       |
    ]])
  end)

  it('right click extends visual selection to the clicked location', function()
    feed('<LeftMouse><0,0>')
    screen:expect([[
      ^testing                  |
      mouse                    |
      support and selection    |
      {0:~                        }|
                               |
    ]])
    feed('<RightMouse><2,2>')
    screen:expect([[
      {1:testing}{3: }                 |
      {1:mouse}{3: }                   |
      {1:su}^pport and selection    |
      {0:~                        }|
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
    feed_command('sp', 'vsp')
    screen:expect([[
      lines                     {4:|}lines                     |
      to                        {4:|}to                        |
      test                      {4:|}test                      |
      mouse scrolling           {4:|}mouse scrolling           |
      ^                          {4:|}                          |
      {0:~                         }{4:|}{0:~                         }|
      {5:[No Name] [+]              }{4:[No Name] [+]             }|
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      {0:~                                                    }|
      {4:[No Name] [+]                                        }|
      :vsp                                                 |
    ]])
    feed('<ScrollWheelDown><0,0>')
    screen:expect([[
      mouse scrolling           {4:|}lines                     |
      ^                          {4:|}to                        |
      {0:~                         }{4:|}test                      |
      {0:~                         }{4:|}mouse scrolling           |
      {0:~                         }{4:|}                          |
      {0:~                         }{4:|}{0:~                         }|
      {5:[No Name] [+]              }{4:[No Name] [+]             }|
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      {0:~                                                    }|
      {4:[No Name] [+]                                        }|
                                                           |
    ]])
    feed('<ScrollWheelUp><27,0>')
    screen:expect([[
      mouse scrolling           {4:|}text                      |
      ^                          {4:|}with                      |
      {0:~                         }{4:|}many                      |
      {0:~                         }{4:|}lines                     |
      {0:~                         }{4:|}to                        |
      {0:~                         }{4:|}test                      |
      {5:[No Name] [+]              }{4:[No Name] [+]             }|
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      {0:~                                                    }|
      {4:[No Name] [+]                                        }|
                                                           |
    ]])
    feed('<ScrollWheelUp><27,7><ScrollWheelUp>')
    screen:expect([[
      mouse scrolling           {4:|}text                      |
      ^                          {4:|}with                      |
      {0:~                         }{4:|}many                      |
      {0:~                         }{4:|}lines                     |
      {0:~                         }{4:|}to                        |
      {0:~                         }{4:|}test                      |
      {5:[No Name] [+]              }{4:[No Name] [+]             }|
      Inserting                                            |
      text                                                 |
      with                                                 |
      many                                                 |
      lines                                                |
      {4:[No Name] [+]                                        }|
                                                           |
    ]])
  end)

  it('horizontal scrolling', function()
    feed("<esc>:set nowrap<cr>")

    feed("a <esc>20Ab<esc>")
    screen:expect([[
                               |
                               |
      bbbbbbbbbbbbbbb^b         |
      {0:~                        }|
                               |
    ]])

    feed("<ScrollWheelLeft><0,0>")
    screen:expect([[
                               |
                               |
      n bbbbbbbbbbbbbbbbbbb^b   |
      {0:~                        }|
                               |
    ]])

    feed("^<ScrollWheelRight><0,0>")
    screen:expect([[
      g                        |
                               |
      ^t and selection bbbbbbbbb|
      {0:~                        }|
                               |
    ]])
  end)

  describe('on concealed text', function()
    -- Helpful for reading the test expectations:
    -- :match Error /\^/

    before_each(function()
      screen:try_resize(25, 7)
      screen:set_default_attr_ids({
        [0] = {bold=true, foreground=Screen.colors.Blue},
        c = { foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray },
      })
      feed('ggdG')

      feed_command('set concealcursor=n')
      feed_command('set nowrap')
      feed_command('syntax match NonText "\\<amet\\>" conceal')
      feed_command('syntax match NonText "\\cs\\|g." conceal cchar=X')
      feed_command('syntax match NonText "\\%(lo\\|cl\\)." conceal')
      feed_command('syntax match NonText "Lo" conceal cchar=Y')

      insert([[
      Lorem ipsum dolor sit amet, consetetur sadipscing elitr.
      Stet clita kasd gubergren, no sea takimata sanctus est.
      ]])

      feed('gg')
    end)

    it('(level 1) click on non-wrapped lines', function()
      feed_command('let &conceallevel=1', 'echo')

      feed('<esc><LeftMouse><0,0>')
      screen:expect([[
        {c:^Y}rem ip{c:X}um do{c: } {c:X}it {c: }, con|
        {c:X}tet {c: }ta ka{c:X}d {c:X}ber{c:X}en, no|
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><1,0>')
      screen:expect([[
        {c:Y}^rem ip{c:X}um do{c: } {c:X}it {c: }, con|
        {c:X}tet {c: }ta ka{c:X}d {c:X}ber{c:X}en, no|
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><15,0>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do{c: } {c:^X}it {c: }, con|
        {c:X}tet {c: }ta ka{c:X}d {c:X}ber{c:X}en, no|
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><15,1>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do{c: } {c:X}it {c: }, con|
        {c:X}tet {c: }ta ka{c:X}d {c:X}^ber{c:X}en, no|
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end) -- level 1 - non wrapped

    it('(level 1) click on wrapped lines', function()
      feed_command('let &conceallevel=1', 'let &wrap=1', 'echo')

      feed('<esc><LeftMouse><0,0>')
      screen:expect([[
        {c:^Y}rem ip{c:X}um do{c: } {c:X}it {c: }     |
        , con{c:X}etetur {c:X}adip{c:X}cin{c:X}  |
        elitr.                   |
        {c:X}tet {c: }ta ka{c:X}d {c:X}ber{c:X}en    |
        , no {c:X}ea takimata {c:X}anctu{c:X}|
         e{c:X}t.                    |
                                 |
      ]])

      feed('<esc><LeftMouse><6,1>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do{c: } {c:X}it {c: }     |
        , con{c:X}^etetur {c:X}adip{c:X}cin{c:X}  |
        elitr.                   |
        {c:X}tet {c: }ta ka{c:X}d {c:X}ber{c:X}en    |
        , no {c:X}ea takimata {c:X}anctu{c:X}|
         e{c:X}t.                    |
                                 |
      ]])

      feed('<esc><LeftMouse><15,1>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do{c: } {c:X}it {c: }     |
        , con{c:X}etetur {c:X}a^dip{c:X}cin{c:X}  |
        elitr.                   |
        {c:X}tet {c: }ta ka{c:X}d {c:X}ber{c:X}en    |
        , no {c:X}ea takimata {c:X}anctu{c:X}|
         e{c:X}t.                    |
                                 |
      ]])

      feed('<esc><LeftMouse><15,3>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do{c: } {c:X}it {c: }     |
        , con{c:X}etetur {c:X}adip{c:X}cin{c:X}  |
        elitr.                   |
        {c:X}tet {c: }ta ka{c:X}d {c:X}^ber{c:X}en    |
        , no {c:X}ea takimata {c:X}anctu{c:X}|
         e{c:X}t.                    |
                                 |
      ]])
    end) -- level 1 - wrapped


    it('(level 2) click on non-wrapped lines', function()
      feed_command('let &conceallevel=2', 'echo')

      feed('<esc><LeftMouse><0,0>')
      screen:expect([[
        {c:^Y}rem ip{c:X}um do {c:X}it , con{c:X}e|
        {c:X}tet ta ka{c:X}d {c:X}ber{c:X}en, no |
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><1,0>')
      screen:expect([[
        {c:Y}^rem ip{c:X}um do {c:X}it , con{c:X}e|
        {c:X}tet ta ka{c:X}d {c:X}ber{c:X}en, no |
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><15,0>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do {c:X}^it , con{c:X}e|
        {c:X}tet ta ka{c:X}d {c:X}ber{c:X}en, no |
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><15,1>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do {c:X}it , con{c:X}e|
        {c:X}tet ta ka{c:X}d {c:X}b^er{c:X}en, no |
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end) -- level 2 - non wrapped

    it('(level 2) click on wrapped lines', function()
      feed_command('let &conceallevel=2', 'let &wrap=1', 'echo')

      feed('<esc><LeftMouse><0,0>')
      screen:expect([[
        {c:^Y}rem ip{c:X}um do {c:X}it        |
        , con{c:X}etetur {c:X}adip{c:X}cin{c:X}  |
        elitr.                   |
        {c:X}tet ta ka{c:X}d {c:X}ber{c:X}en     |
        , no {c:X}ea takimata {c:X}anctu{c:X}|
         e{c:X}t.                    |
                                 |
      ]])

      feed('<esc><LeftMouse><6,1>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do {c:X}it        |
        , con{c:X}^etetur {c:X}adip{c:X}cin{c:X}  |
        elitr.                   |
        {c:X}tet ta ka{c:X}d {c:X}ber{c:X}en     |
        , no {c:X}ea takimata {c:X}anctu{c:X}|
         e{c:X}t.                    |
                                 |
      ]])

      feed('<esc><LeftMouse><15,1>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do {c:X}it        |
        , con{c:X}etetur {c:X}a^dip{c:X}cin{c:X}  |
        elitr.                   |
        {c:X}tet ta ka{c:X}d {c:X}ber{c:X}en     |
        , no {c:X}ea takimata {c:X}anctu{c:X}|
         e{c:X}t.                    |
                                 |
      ]])

      feed('<esc><LeftMouse><15,3>')
      screen:expect([[
        {c:Y}rem ip{c:X}um do {c:X}it        |
        , con{c:X}etetur {c:X}adip{c:X}cin{c:X}  |
        elitr.                   |
        {c:X}tet ta ka{c:X}d {c:X}b^er{c:X}en     |
        , no {c:X}ea takimata {c:X}anctu{c:X}|
         e{c:X}t.                    |
                                 |
      ]])
    end) -- level 2 - wrapped


    it('(level 3) click on non-wrapped lines', function()
      feed_command('let &conceallevel=3', 'echo')

      feed('<esc><LeftMouse><0,0>')
      screen:expect([[
        ^rem ipum do it , conetetu|
        tet ta kad beren, no ea t|
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><1,0>')
      screen:expect([[
        r^em ipum do it , conetetu|
        tet ta kad beren, no ea t|
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><15,0>')
      screen:expect([[
        rem ipum do it ^, conetetu|
        tet ta kad beren, no ea t|
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><15,1>')
      screen:expect([[
        rem ipum do it , conetetu|
        tet ta kad bere^n, no ea t|
                                 |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end) -- level 3 - non wrapped

    it('(level 3) click on wrapped lines', function()
      feed_command('let &conceallevel=3', 'let &wrap=1', 'echo')

      feed('<esc><LeftMouse><0,0>')
      screen:expect([[
        ^rem ipum do it           |
        , conetetur adipcin      |
        elitr.                   |
        tet ta kad beren         |
        , no ea takimata anctu   |
         et.                     |
                                 |
      ]])

      feed('<esc><LeftMouse><6,1>')
      screen:expect([[
        rem ipum do it           |
        , cone^tetur adipcin      |
        elitr.                   |
        tet ta kad beren         |
        , no ea takimata anctu   |
         et.                     |
                                 |
      ]])

      feed('<esc><LeftMouse><15,1>')
      screen:expect([[
        rem ipum do it           |
        , conetetur adi^pcin      |
        elitr.                   |
        tet ta kad beren         |
        , no ea takimata anctu   |
         et.                     |
                                 |
      ]])

      feed('<esc><LeftMouse><15,3>')
      screen:expect([[
        rem ipum do it           |
        , conetetur adipcin      |
        elitr.                   |
        tet ta kad bere^n         |
        , no ea takimata anctu   |
         et.                     |
                                 |
      ]])
    end) -- level 3 - wrapped
  end)
end)
