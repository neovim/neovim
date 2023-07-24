local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, meths = helpers.clear, helpers.feed, helpers.meths
local insert, feed_command = helpers.insert, helpers.feed_command
local eq, funcs = helpers.eq, helpers.funcs
local poke_eventloop = helpers.poke_eventloop
local command = helpers.command
local exec = helpers.exec

describe('ui/mouse/input', function()
  local screen

  before_each(function()
    clear()
    meths.set_option_value('mouse', 'a', {})
    meths.set_option_value('list', true, {})
    -- NB: this is weird, but mostly irrelevant to the test
    -- So I didn't bother to change it
    command('set listchars=eol:$')
    command('setl listchars=nbsp:x')
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
      [6] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [7] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [8] = {foreground = Screen.colors.Brown},
    })
    command("set mousemodel=extend")
    feed('itesting<cr>mouse<cr>support and selection<esc>')
    screen:expect([[
      testing                  |
      mouse                    |
      support and selectio^n    |
      {0:~                        }|
                               |
    ]])
  end)

  it('single left click moves cursor', function()
    feed('<LeftMouse><2,1>')
    screen:expect{grid=[[
      testing                  |
      mo^use                    |
      support and selection    |
      {0:~                        }|
                               |
    ]], mouse_enabled=true}
    feed('<LeftMouse><0,0>')
    screen:expect([[
      ^testing                  |
      mouse                    |
      support and selection    |
      {0:~                        }|
                               |
    ]])
  end)

  it("in external ui works with unset 'mouse'", function()
    meths.set_option_value('mouse', '', {})
    feed('<LeftMouse><2,1>')
    screen:expect{grid=[[
      testing                  |
      mo^use                    |
      support and selection    |
      {0:~                        }|
                               |
    ]], mouse_enabled=false}
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
      ^t{1:esting}                  |
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
        this is ba^r{0:$}             |
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
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r{0:$}             |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><11,0>')
      screen:expect{grid=[[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r{0:$}             |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]], unchanged=true}
      feed('<LeftDrag><6,0>')
      screen:expect([[
        {sel: + bar }{tab: + foo }{fill:          }{tab:X}|
        this is ba^r{0:$}             |
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
        this is ba^r{0:$}             |
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
        this is ba^r{0:$}             |
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
      screen:expect{grid=[[
        {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]], unchanged=true}
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
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r{0:$}             |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<LeftMouse><11,0>')
      screen:expect{grid=[[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r{0:$}             |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]], unchanged=true}
      feed('<LeftDrag><11,1>')
      screen:expect{grid=[[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r{0:$}             |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]], unchanged=true}
      feed('<LeftDrag><6,1>')
      screen:expect([[
        {sel: + bar }{tab: + foo }{fill:          }{tab:X}|
        this is ba^r{0:$}             |
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
        this is ba^r{0:$}             |
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
      screen:expect{grid=[[
        {sel: + foo }{tab: + bar }{fill:          }{tab:X}|
        this is fo^o              |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]], unchanged=true}
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
        this is ba^r{0:$}             |
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
      meths.set_option_value('hidden', true, {})
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r{0:$}             |
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
      meths.set_option_value('hidden', true, {})
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
        this is ba^r{0:$}             |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      feed('<2-LeftMouse><4,0>')
      screen:expect([[
        {sel:  Name] }{tab: + foo  + bar }{fill:  }{tab:X}|
        {0:^$}                        |
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
        meths.set_option_value('tabline', '%@Test@test%X-%5@Test2@test2', {})
        meths.set_option_value('showtabline', 2, {})
        screen:expect([[
          {fill:test-test2               }|
          testing                  |
          mouse                    |
          support and selectio^n    |
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

        local function doit(do_click)
          eq(1, funcs.has('tablineat'))
          do_click(0,3)
          check_reply({0, click_num, mouse_button, modifiers})
          do_click(0,4)
          check_reply({})
          do_click(0,6)
          check_reply({5, click_num, mouse_button, modifiers, 2})
          do_click(0,13)
          check_reply({5, click_num, mouse_button, modifiers, 2})
        end

        it(name .. ' works (pseudokey)', function()
          doit(function (row,col)
              feed(click_str .. '<' .. col .. ',' .. row .. '>')
          end)
        end)

        it(name .. ' works (nvim_input_mouse)', function()
          doit(function (row,col)
            local buttons = {l='left',m='middle',r='right'}
            local modstr = (click_num > 1) and tostring(click_num) or ''
            for char in string.gmatch(modifiers, '%w') do
              modstr = modstr .. char .. '-' -- - not needed but should be accepted
            end
            meths.input_mouse(buttons[mouse_button], 'press', modstr, 0, row, col)
          end)
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
      mo{1:use}                    |
      {1:su}^pport and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><0,0>')
    screen:expect([[
      ^t{1:esting}                  |
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
      testing                  |
      mouse                    |
      support and selectio^n    |
      :tabprevious             |
    ]])
    feed('<LeftMouse><10,0><LeftRelease>')  -- go to second tab
    helpers.poke_eventloop()
    feed('<LeftMouse><0,1>')
    screen:expect([[
      {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
      ^this is bar{0:$}             |
      {0:~                        }|
      {0:~                        }|
      :tabprevious             |
    ]])
    feed('<LeftDrag><4,1>')
    screen:expect([[
      {tab: + foo }{sel: + bar }{fill:          }{tab:X}|
      {vis:this}^ is bar{0:$}             |
      {0:~                        }|
      {0:~                        }|
      {sel:-- VISUAL --}             |
    ]])
  end)

  it('left drag changes visual selection in split layout', function()
    screen:try_resize(53,14)
    command('set mouse=a')
    command('vsplit')
    command('wincmd l')
    command('below split')
    command('enew')
    feed('ifoo\nbar<esc>')

    screen:expect{grid=[[
      testing                   │testing                   |
      mouse                     │mouse                     |
      support and selection     │support and selection     |
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {0:~                         }│{4:[No Name] [+]             }|
      {0:~                         }│foo{0:$}                      |
      {0:~                         }│ba^r{0:$}                      |
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {4:[No Name] [+]              }{5:[No Name] [+]             }|
                                                           |
    ]]}

    meths.input_mouse('left', 'press', '', 0, 6, 27)
    screen:expect{grid=[[
      testing                   │testing                   |
      mouse                     │mouse                     |
      support and selection     │support and selection     |
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {0:~                         }│{4:[No Name] [+]             }|
      {0:~                         }│^foo{0:$}                      |
      {0:~                         }│bar{0:$}                      |
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {4:[No Name] [+]              }{5:[No Name] [+]             }|
                                                           |
    ]]}
    meths.input_mouse('left', 'drag', '', 0, 7, 30)

    screen:expect{grid=[[
      testing                   │testing                   |
      mouse                     │mouse                     |
      support and selection     │support and selection     |
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {0:~                         }│{4:[No Name] [+]             }|
      {0:~                         }│{1:foo}{3:$}                      |
      {0:~                         }│{1:bar}{0:^$}                      |
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {0:~                         }│{0:~                         }|
      {4:[No Name] [+]              }{5:[No Name] [+]             }|
      {2:-- VISUAL --}                                         |
    ]]}
  end)

  it('two clicks will enter VISUAL and dragging selects words', function()
    feed('<LeftMouse><2,2>')
    feed('<LeftRelease><2,2>')
    feed('<LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {1:suppor}^t and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><0,1>')
    screen:expect([[
      testing                  |
      ^m{1:ouse}                    |
      {1:support} and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><4,0>')
    screen:expect([[
      ^t{1:esting}                  |
      {1:mouse}                    |
      {1:support} and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><14,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {1:support and selectio}^n    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
  end)

  it('three clicks will enter VISUAL LINE and dragging selects lines', function()
    feed('<LeftMouse><2,2>')
    feed('<LeftRelease><2,2>')
    feed('<LeftMouse><2,2>')
    feed('<LeftRelease><2,2>')
    feed('<LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {1:su}^p{1:port and selection}    |
      {0:~                        }|
      {2:-- VISUAL LINE --}        |
    ]])
    feed('<LeftDrag><0,1>')
    screen:expect([[
      testing                  |
      ^m{1:ouse}                    |
      {1:support and selection}    |
      {0:~                        }|
      {2:-- VISUAL LINE --}        |
    ]])
    feed('<LeftDrag><4,0>')
    screen:expect([[
      {1:test}^i{1:ng}                  |
      {1:mouse}                    |
      {1:support and selection}    |
      {0:~                        }|
      {2:-- VISUAL LINE --}        |
    ]])
    feed('<LeftDrag><14,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {1:support and se}^l{1:ection}    |
      {0:~                        }|
      {2:-- VISUAL LINE --}        |
    ]])
  end)

  it('four clicks will enter VISUAL BLOCK and dragging selects blockwise', function()
    feed('<LeftMouse><2,2>')
    feed('<LeftRelease><2,2>')
    feed('<LeftMouse><2,2>')
    feed('<LeftRelease><2,2>')
    feed('<LeftMouse><2,2>')
    feed('<LeftRelease><2,2>')
    feed('<LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      su^pport and selection    |
      {0:~                        }|
      {2:-- VISUAL BLOCK --}       |
    ]])
    feed('<LeftDrag><0,1>')
    screen:expect([[
      testing                  |
      ^m{1:ou}se                    |
      {1:sup}port and selection    |
      {0:~                        }|
      {2:-- VISUAL BLOCK --}       |
    ]])
    feed('<LeftDrag><4,0>')
    screen:expect([[
      te{1:st}^ing                  |
      mo{1:use}                    |
      su{1:ppo}rt and selection    |
      {0:~                        }|
      {2:-- VISUAL BLOCK --}       |
    ]])
    feed('<LeftDrag><14,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      su{1:pport and se}^lection    |
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
      {1:testing}                  |
      {1:mouse}                    |
      {1:su}^pport and selection    |
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]])
  end)

  it('ctrl + left click will search for a tag', function()
    meths.set_option_value('tags', './non-existent-tags-file', {})
    feed('<C-LeftMouse><0,0>')
    screen:expect([[
      {6:E433: No tags file}       |
      {6:E426: Tag not found: test}|
      {6:ing}                      |
      {7:Press ENTER or type comma}|
      {7:nd to continue}^           |
    ]])
    feed('<cr>')
  end)

  it('dragging vertical separator', function()
    screen:try_resize(45, 5)
    command('setlocal nowrap')
    local oldwin = meths.get_current_win().id
    command('rightbelow vnew')
    screen:expect([[
      testing               │{0:^$}                     |
      mouse                 │{0:~                     }|
      support and selection │{0:~                     }|
      {4:[No Name] [+]          }{5:[No Name]             }|
                                                   |
    ]])
    meths.input_mouse('left', 'press', '', 0, 0, 22)
    poke_eventloop()
    meths.input_mouse('left', 'drag', '', 0, 1, 12)
    screen:expect([[
      testing     │{0:^$}                               |
      mouse       │{0:~                               }|
      support and │{0:~                               }|
      {4:< Name] [+]  }{5:[No Name]                       }|
                                                   |
    ]])
    meths.input_mouse('left', 'drag', '', 0, 2, 2)
    screen:expect([[
      te│{0:^$}                                         |
      mo│{0:~                                         }|
      su│{0:~                                         }|
      {4:<  }{5:[No Name]                                 }|
                                                   |
    ]])
    meths.input_mouse('left', 'release', '', 0, 2, 2)
    meths.set_option_value('statuscolumn', 'foobar', { win = oldwin })
    screen:expect([[
      {8:fo}│{0:^$}                                         |
      {8:fo}│{0:~                                         }|
      {8:fo}│{0:~                                         }|
      {4:<  }{5:[No Name]                                 }|
                                                   |
    ]])
    meths.input_mouse('left', 'press', '', 0, 0, 2)
    poke_eventloop()
    meths.input_mouse('left', 'drag', '', 0, 1, 12)
    screen:expect([[
      {8:foobar}testin│{0:^$}                               |
      {8:foobar}mouse │{0:~                               }|
      {8:foobar}suppor│{0:~                               }|
      {4:< Name] [+]  }{5:[No Name]                       }|
                                                   |
    ]])
    meths.input_mouse('left', 'drag', '', 0, 2, 22)
    screen:expect([[
      {8:foobar}testing         │{0:^$}                     |
      {8:foobar}mouse           │{0:~                     }|
      {8:foobar}support and sele│{0:~                     }|
      {4:[No Name] [+]          }{5:[No Name]             }|
                                                   |
    ]])
    meths.input_mouse('left', 'release', '', 0, 2, 22)
  end)

  local function wheel(use_api)
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
    feed('k')
    feed_command('sp', 'vsp')
    screen:expect([[
      lines                     │lines                     |
      to                        │to                        |
      test                      │test                      |
      ^mouse scrolling           │mouse scrolling           |
                                │                          |
      {0:~                         }│{0:~                         }|
      {5:[No Name] [+]              }{4:[No Name] [+]             }|
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      {0:~                                                    }|
      {4:[No Name] [+]                                        }|
      :vsp                                                 |
    ]])
    if use_api then
      meths.input_mouse('wheel', 'down', '', 0, 0, 0)
    else
      feed('<ScrollWheelDown><0,0>')
    end
    screen:expect([[
      ^mouse scrolling           │lines                     |
                                │to                        |
      {0:~                         }│test                      |
      {0:~                         }│mouse scrolling           |
      {0:~                         }│                          |
      {0:~                         }│{0:~                         }|
      {5:[No Name] [+]              }{4:[No Name] [+]             }|
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      {0:~                                                    }|
      {4:[No Name] [+]                                        }|
      :vsp                                                 |
    ]])
    if use_api then
      meths.input_mouse('wheel', 'up', '', 0, 0, 27)
    else
      feed('<ScrollWheelUp><27,0>')
    end
    screen:expect([[
      ^mouse scrolling           │text                      |
                                │with                      |
      {0:~                         }│many                      |
      {0:~                         }│lines                     |
      {0:~                         }│to                        |
      {0:~                         }│test                      |
      {5:[No Name] [+]              }{4:[No Name] [+]             }|
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      {0:~                                                    }|
      {4:[No Name] [+]                                        }|
      :vsp                                                 |
    ]])
    if use_api then
      meths.input_mouse('wheel', 'up', '', 0, 7, 27)
      meths.input_mouse('wheel', 'up', '', 0, 7, 27)
    else
      feed('<ScrollWheelUp><27,7><ScrollWheelUp>')
    end
    screen:expect([[
      ^mouse scrolling           │text                      |
                                │with                      |
      {0:~                         }│many                      |
      {0:~                         }│lines                     |
      {0:~                         }│to                        |
      {0:~                         }│test                      |
      {5:[No Name] [+]              }{4:[No Name] [+]             }|
      Inserting                                            |
      text                                                 |
      with                                                 |
      many                                                 |
      lines                                                |
      {4:[No Name] [+]                                        }|
      :vsp                                                 |
    ]])
  end

  it('mouse wheel will target the hovered window (pseudokey)', function()
    wheel(false)
  end)

  it('mouse wheel will target the hovered window (nvim_input_mouse)', function()
    wheel(true)
  end)

  it('horizontal scrolling (pseudokey)', function()
    command('set sidescroll=0')
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

  it('horizontal scrolling (nvim_input_mouse)', function()
    command('set sidescroll=0')
    feed("<esc>:set nowrap<cr>")

    feed("a <esc>20Ab<esc>")
    screen:expect([[
                               |
                               |
      bbbbbbbbbbbbbbb^b         |
      {0:~                        }|
                               |
    ]])

    meths.input_mouse('wheel', 'left', '', 0, 0, 27)
    screen:expect([[
                               |
                               |
      n bbbbbbbbbbbbbbbbbbb^b   |
      {0:~                        }|
                               |
    ]])

    feed("^")
    meths.input_mouse('wheel', 'right', '', 0, 0, 0)
    screen:expect([[
      g                        |
                               |
      ^t and selection bbbbbbbbb|
      {0:~                        }|
                               |
    ]])
  end)

  it("'sidescrolloff' applies to horizontal scrolling", function()
    command('set nowrap')
    command('set sidescrolloff=4')

    feed("I <esc>020ib<esc>0")
    screen:expect([[
      testing                  |
      mouse                    |
      ^bbbbbbbbbbbbbbbbbbbb supp|
      {0:~                        }|
                               |
    ]])

    meths.input_mouse('wheel', 'right', '', 0, 0, 27)
    screen:expect([[
      g                        |
                               |
      bbbb^bbbbbbbbbb support an|
      {0:~                        }|
                               |
    ]])

    -- window-local 'sidescrolloff' should override global value. #21162
    command('setlocal sidescrolloff=2')
    feed('0')
    screen:expect([[
      testing                  |
      mouse                    |
      ^bbbbbbbbbbbbbbbbbbbb supp|
      {0:~                        }|
                               |
    ]])

    meths.input_mouse('wheel', 'right', '', 0, 0, 27)
    screen:expect([[
      g                        |
                               |
      bb^bbbbbbbbbbbb support an|
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
        sm = {bold = true},
      })
      feed('ggdG')

      command([[setlocal concealcursor=ni nowrap shiftwidth=2 tabstop=4 list listchars=tab:>-]])
      command([[syntax region X0 matchgroup=X1 start=/\*/ end=/\*/ concealends contains=X2]])
      command([[syntax match X2 /cats/ conceal cchar=X contained]])
      -- No heap-use-after-free with multi-line syntax pattern #24317
      command([[syntax match X3 /\n\@<=x/ conceal cchar=>]])
      command([[highlight link X0 Normal]])
      command([[highlight link X1 NonText]])
      command([[highlight link X2 NonText]])
      command([[highlight link X3 NonText]])

      -- First column is there to retain the tabs.
      insert([[
      |Section				*t1*
      |			  *t2* *t3* *t4*
      |x 私は猫が大好き	*cats* ✨🐈✨
      ]])

      feed('gg<c-v>Gxgg')
    end)

    it('(level 1) click on non-wrapped lines', function()
      feed_command('let &conceallevel=1', 'echo')

      feed('<esc><LeftMouse><0,0>')
      screen:expect([[
        ^Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        {c:>} 私は猫が大好き{0:>---}{c: X } {0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><1,0>')
      screen:expect([[
        S^ection{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        {c:>} 私は猫が大好き{0:>---}{c: X } {0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><21,0>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }^t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        {c:>} 私は猫が大好き{0:>---}{c: X } {0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><21,1>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t^3{c: } {c: }|
        {c:>} 私は猫が大好き{0:>---}{c: X } {0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><0,2>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        {c:^>} 私は猫が大好き{0:>---}{c: X } {0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><7,2>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        {c:>} 私は^猫が大好き{0:>---}{c: X } {0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><21,2>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        {c:>} 私は猫が大好き{0:>---}{c: ^X } {0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

    end) -- level 1 - non wrapped

    it('(level 1) click on wrapped lines', function()
      feed_command('let &conceallevel=1', 'let &wrap=1', 'echo')

      feed('<esc><LeftMouse><24,1>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c:^ }|
        t4{c: }                      |
        {c:>} 私は猫が大好き{0:>---}{c: X}   |
        {c: } ✨🐈✨                 |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><0,2>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        ^t4{c: }                      |
        {c:>} 私は猫が大好き{0:>---}{c: X}   |
        {c: } ✨🐈✨                 |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><8,3>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        t4{c: }                      |
        {c:>} 私は猫^が大好き{0:>---}{c: X}   |
        {c: } ✨🐈✨                 |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><21,3>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        t4{c: }                      |
        {c:>} 私は猫が大好き{0:>---}{c: ^X}   |
        {c: } ✨🐈✨                 |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><4,4>')
      screen:expect([[
        Section{0:>>--->--->---}{c: }t1{c: } |
        {0:>--->--->---}  {c: }t2{c: } {c: }t3{c: } {c: }|
        t4{c: }                      |
        {c:>} 私は猫が大好き{0:>---}{c: X}   |
        {c: } ✨^🐈✨                 |
                                 |
                                 |
      ]])
    end) -- level 1 - wrapped


    it('(level 2) click on non-wrapped lines', function()
      feed_command('let &conceallevel=2', 'echo')

      feed('<esc><LeftMouse><20,0>')
      screen:expect([[
        Section{0:>>--->--->---}^t1   |
        {0:>--->--->---}  t2 t3 t4   |
        {c:>} 私は猫が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><14,1>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  ^t2 t3 t4   |
        {c:>} 私は猫が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><18,1>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t^3 t4   |
        {c:>} 私は猫が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><0,2>')  -- Weirdness
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
        {c:^>} 私は猫が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><8,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
        {c:>} 私は猫^が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><20,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
        {c:>} 私は猫が大好き{0:>---}{c:^X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end) -- level 2 - non wrapped

    it('(level 2) click on non-wrapped lines (insert mode)', function()
      feed_command('let &conceallevel=2', 'echo')

      feed('<esc>i<LeftMouse><20,0>')
      screen:expect([[
        Section{0:>>--->--->---}^t1   |
        {0:>--->--->---}  t2 t3 t4   |
        {c:>} 私は猫が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
        {sm:-- INSERT --}             |
      ]])

      feed('<LeftMouse><14,1>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  ^t2 t3 t4   |
        {c:>} 私は猫が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
        {sm:-- INSERT --}             |
      ]])

      feed('<LeftMouse><18,1>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t^3 t4   |
        {c:>} 私は猫が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
        {sm:-- INSERT --}             |
      ]])

      feed('<LeftMouse><0,2>')  -- Weirdness
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
        {c:^>} 私は猫が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
        {sm:-- INSERT --}             |
      ]])

      feed('<LeftMouse><8,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
        {c:>} 私は猫^が大好き{0:>---}{c:X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
        {sm:-- INSERT --}             |
      ]])

      feed('<LeftMouse><20,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
        {c:>} 私は猫が大好き{0:>---}{c:^X} ✨{0:>}|
                                 |
        {0:~                        }|
        {0:~                        }|
        {sm:-- INSERT --}             |
      ]])
    end) -- level 2 - non wrapped (insert mode)

    it('(level 2) click on wrapped lines', function()
      feed_command('let &conceallevel=2', 'let &wrap=1', 'echo')

      feed('<esc><LeftMouse><20,0>')
      screen:expect([[
        Section{0:>>--->--->---}^t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
        {c:>} 私は猫が大好き{0:>---}{c:X}    |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><14,1>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  ^t2 t3      |
        t4                       |
        {c:>} 私は猫が大好き{0:>---}{c:X}    |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><18,1>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t^3      |
        t4                       |
        {c:>} 私は猫が大好き{0:>---}{c:X}    |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      -- NOTE: The click would ideally be on the 't' in 't4', but wrapping
      -- caused the invisible '*' right before 't4' to remain on the previous
      -- screen line.  This is being treated as expected because fixing this is
      -- out of scope for mouse clicks.  Should the wrapping behavior of
      -- concealed characters change in the future, this case should be
      -- reevaluated.
      feed('<esc><LeftMouse><0,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 ^     |
        t4                       |
        {c:>} 私は猫が大好き{0:>---}{c:X}    |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><1,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t^4                       |
        {c:>} 私は猫が大好き{0:>---}{c:X}    |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><0,3>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
        {c:^>} 私は猫が大好き{0:>---}{c:X}    |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><20,3>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
        {c:>} 私は猫が大好き{0:>---}{c:^X}    |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><1,4>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
        {c:>} 私は猫が大好き{0:>---}{c:X}    |
         ^✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><5,4>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
        {c:>} 私は猫が大好き{0:>---}{c:X}    |
         ✨🐈^✨                  |
                                 |
                                 |
      ]])
    end) -- level 2 - wrapped


    it('(level 3) click on non-wrapped lines', function()
      feed_command('let &conceallevel=3', 'echo')

      feed('<esc><LeftMouse><0,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
        ^ 私は猫が大好き{0:>----} ✨🐈|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><1,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
         ^私は猫が大好き{0:>----} ✨🐈|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><13,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
         私は猫が大好^き{0:>----} ✨🐈|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])

      feed('<esc><LeftMouse><20,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3 t4   |
         私は猫が大好き{0:>----}^ ✨🐈|
                                 |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
    end) -- level 3 - non wrapped

    it('(level 3) click on wrapped lines', function()
      feed_command('let &conceallevel=3', 'let &wrap=1', 'echo')

      feed('<esc><LeftMouse><14,1>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  ^t2 t3      |
        t4                       |
         私は猫が大好き{0:>----}     |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><18,1>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t^3      |
        t4                       |
         私は猫が大好き{0:>----}     |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><1,2>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t^4                       |
         私は猫が大好き{0:>----}     |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><0,3>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
        ^ 私は猫が大好き{0:>----}     |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><20,3>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
         私は猫が大好き{0:>----}^     |
         ✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><1,4>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
         私は猫が大好き{0:>----}     |
         ^✨🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><3,4>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
         私は猫が大好き{0:>----}     |
         ✨^🐈✨                  |
                                 |
                                 |
      ]])

      feed('<esc><LeftMouse><5,4>')
      screen:expect([[
        Section{0:>>--->--->---}t1   |
        {0:>--->--->---}  t2 t3      |
        t4                       |
         私は猫が大好き{0:>----}     |
         ✨🐈^✨                  |
                                 |
                                 |
      ]])

    end) -- level 3 - wrapped
  end)

  it('getmousepos works correctly', function()
    local winwidth = meths.get_option_value('winwidth', {})
    -- Set winwidth=1 so that window sizes don't change.
    meths.set_option_value('winwidth', 1, {})
    command('tabedit')
    local tabpage = meths.get_current_tabpage()
    insert('hello')
    command('vsplit')
    local opts = {
      relative='editor',
      width=12,
      height=1,
      col=8,
      row=1,
      anchor='NW',
      style='minimal',
      border='single',
      focusable=1
    }
    local float = meths.open_win(meths.get_current_buf(), false, opts)
    command('redraw')
    local lines = meths.get_option_value('lines', {})
    local columns = meths.get_option_value('columns', {})

    -- Test that screenrow and screencol are set properly for all positions.
    for row = 0, lines - 1 do
      for col = 0, columns - 1 do
        -- Skip the X button that would close the tab.
        if row ~= 0 or col ~= columns - 1 then
          meths.input_mouse('left', 'press', '', 0, row, col)
          meths.set_current_tabpage(tabpage)
          local mousepos = funcs.getmousepos()
          eq(row + 1, mousepos.screenrow)
          eq(col + 1, mousepos.screencol)
          -- All other values should be 0 when clicking on the command line.
          if row == lines - 1 then
            eq(0, mousepos.winid)
            eq(0, mousepos.winrow)
            eq(0, mousepos.wincol)
            eq(0, mousepos.line)
            eq(0, mousepos.column)
          end
        end
      end
    end

    -- Test that mouse position values are properly set for the floating window
    -- with a border. 1 is added to the height and width to account for the
    -- border.
    for win_row = 0, opts.height + 1 do
      for win_col = 0, opts.width + 1 do
        local row = win_row + opts.row
        local col = win_col + opts.col
        meths.input_mouse('left', 'press', '', 0, row, col)
        local mousepos = funcs.getmousepos()
        eq(float.id, mousepos.winid)
        eq(win_row + 1, mousepos.winrow)
        eq(win_col + 1, mousepos.wincol)
        local line = 0
        local column = 0
        if win_row > 0 and win_row < opts.height + 1
            and win_col > 0 and win_col < opts.width + 1 then
          -- Because of border, win_row and win_col don't need to be
          -- incremented by 1.
          line = math.min(win_row, funcs.line('$'))
          column = math.min(win_col, #funcs.getline(line) + 1)
        end
        eq(line, mousepos.line)
        eq(column, mousepos.column)
      end
    end

    -- Test that mouse position values are properly set for the floating
    -- window, after removing the border.
    opts.border = 'none'
    meths.win_set_config(float, opts)
    command('redraw')
    for win_row = 0, opts.height - 1 do
      for win_col = 0, opts.width - 1 do
        local row = win_row + opts.row
        local col = win_col + opts.col
        meths.input_mouse('left', 'press', '', 0, row, col)
        local mousepos = funcs.getmousepos()
        eq(float.id, mousepos.winid)
        eq(win_row + 1, mousepos.winrow)
        eq(win_col + 1, mousepos.wincol)
        local line = math.min(win_row + 1, funcs.line('$'))
        local column = math.min(win_col + 1, #funcs.getline(line) + 1)
        eq(line, mousepos.line)
        eq(column, mousepos.column)
      end
    end

    -- Test that mouse position values are properly set for ordinary windows.
    -- Set the float to be unfocusable instead of closing, to additionally test
    -- that getmousepos does not consider unfocusable floats. (see discussion
    -- in PR #14937 for details).
    opts.focusable = false
    meths.win_set_config(float, opts)
    command('redraw')
    for nr = 1, 2 do
      for win_row = 0, funcs.winheight(nr) - 1 do
        for win_col = 0, funcs.winwidth(nr) - 1 do
          local row = win_row + funcs.win_screenpos(nr)[1] - 1
          local col = win_col + funcs.win_screenpos(nr)[2] - 1
          meths.input_mouse('left', 'press', '', 0, row, col)
          local mousepos = funcs.getmousepos()
          eq(funcs.win_getid(nr), mousepos.winid)
          eq(win_row + 1, mousepos.winrow)
          eq(win_col + 1, mousepos.wincol)
          local line = math.min(win_row + 1, funcs.line('$'))
          local column = math.min(win_col + 1, #funcs.getline(line) + 1)
          eq(line, mousepos.line)
          eq(column, mousepos.column)
        end
      end
    end

    -- Restore state and release mouse.
    command('tabclose!')
    meths.set_option_value('winwidth', winwidth, {})
    meths.input_mouse('left', 'release', '', 0, 0, 0)
  end)

  it('scroll keys are not translated into multiclicks and can be mapped #6211 #6989', function()
    meths.set_var('mouse_up', 0)
    meths.set_var('mouse_up2', 0)
    command('nnoremap <ScrollWheelUp> <Cmd>let g:mouse_up += 1<CR>')
    command('nnoremap <2-ScrollWheelUp> <Cmd>let g:mouse_up2 += 1<CR>')
    feed('<ScrollWheelUp><0,0>')
    feed('<ScrollWheelUp><0,0>')
    meths.input_mouse('wheel', 'up', '', 0, 0, 0)
    meths.input_mouse('wheel', 'up', '', 0, 0, 0)
    eq(4, meths.get_var('mouse_up'))
    eq(0, meths.get_var('mouse_up2'))
  end)

  it('<MouseMove> is not translated into multiclicks and can be mapped', function()
    meths.set_var('mouse_move', 0)
    meths.set_var('mouse_move2', 0)
    command('nnoremap <MouseMove> <Cmd>let g:mouse_move += 1<CR>')
    command('nnoremap <2-MouseMove> <Cmd>let g:mouse_move2 += 1<CR>')
    feed('<MouseMove><0,0>')
    feed('<MouseMove><0,0>')
    meths.input_mouse('move', '', '', 0, 0, 0)
    meths.input_mouse('move', '', '', 0, 0, 0)
    eq(4, meths.get_var('mouse_move'))
    eq(0, meths.get_var('mouse_move2'))
  end)

  it('feeding <MouseMove> in Normal mode does not use uninitialized memory #19480', function()
    feed('<MouseMove>')
    helpers.poke_eventloop()
    helpers.assert_alive()
  end)

  it('mousemodel=popup_setpos', function()
    screen:try_resize(80, 24)
    exec([[
      5new
      call setline(1, ['the dish ran away with the spoon',
            \ 'the cow jumped over the moon' ])

      set mouse=a mousemodel=popup_setpos

      aunmenu PopUp
      nmenu PopUp.foo :let g:menustr = 'foo'<CR>
      nmenu PopUp.bar :let g:menustr = 'bar'<CR>
      nmenu PopUp.baz :let g:menustr = 'baz'<CR>
      vmenu PopUp.foo y:<C-U>let g:menustr = 'foo'<CR>
      vmenu PopUp.bar y:<C-U>let g:menustr = 'bar'<CR>
      vmenu PopUp.baz y:<C-U>let g:menustr = 'baz'<CR>
    ]])

    meths.win_set_cursor(0, {1, 0})
    meths.input_mouse('right', 'press', '', 0, 0, 4)
    meths.input_mouse('right', 'release', '', 0, 0, 4)
    feed('<Down><Down><CR>')
    eq('bar', meths.get_var('menustr'))
    eq({1, 4}, meths.win_get_cursor(0))

    -- Test for right click in visual mode inside the selection
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {1, 9})
    feed('vee')
    meths.input_mouse('right', 'press', '', 0, 0, 11)
    meths.input_mouse('right', 'release', '', 0, 0, 11)
    feed('<Down><CR>')
    eq({1, 9}, meths.win_get_cursor(0))
    eq('ran away', funcs.getreg('"'))

    -- Test for right click in visual mode right before the selection
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {1, 9})
    feed('vee')
    meths.input_mouse('right', 'press', '', 0, 0, 8)
    meths.input_mouse('right', 'release', '', 0, 0, 8)
    feed('<Down><CR>')
    eq({1, 8}, meths.win_get_cursor(0))
    eq('', funcs.getreg('"'))

    -- Test for right click in visual mode right after the selection
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {1, 9})
    feed('vee')
    meths.input_mouse('right', 'press', '', 0, 0, 17)
    meths.input_mouse('right', 'release', '', 0, 0, 17)
    feed('<Down><CR>')
    eq({1, 17}, meths.win_get_cursor(0))
    eq('', funcs.getreg('"'))

    -- Test for right click in block-wise visual mode inside the selection
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {1, 15})
    feed('<C-V>j3l')
    meths.input_mouse('right', 'press', '', 0, 1, 16)
    meths.input_mouse('right', 'release', '', 0, 1, 16)
    feed('<Down><CR>')
    eq({1, 15}, meths.win_get_cursor(0))
    eq('\0224', funcs.getregtype('"'))

    -- Test for right click in block-wise visual mode outside the selection
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {1, 15})
    feed('<C-V>j3l')
    meths.input_mouse('right', 'press', '', 0, 1, 1)
    meths.input_mouse('right', 'release', '', 0, 1, 1)
    feed('<Down><CR>')
    eq({2, 1}, meths.win_get_cursor(0))
    eq('v', funcs.getregtype('"'))
    eq('', funcs.getreg('"'))

    -- Test for right click in line-wise visual mode inside the selection
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {1, 15})
    feed('V')
    meths.input_mouse('right', 'press', '', 0, 0, 9)
    meths.input_mouse('right', 'release', '', 0, 0, 9)
    feed('<Down><CR>')
    eq({1, 0}, meths.win_get_cursor(0)) -- After yanking, the cursor goes to 1,1
    eq('V', funcs.getregtype('"'))
    eq(1, #funcs.getreg('"', 1, true))

    -- Test for right click in multi-line line-wise visual mode inside the selection
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {1, 15})
    feed('Vj')
    meths.input_mouse('right', 'press', '', 0, 1, 19)
    meths.input_mouse('right', 'release', '', 0, 1, 19)
    feed('<Down><CR>')
    eq({1, 0}, meths.win_get_cursor(0)) -- After yanking, the cursor goes to 1,1
    eq('V', funcs.getregtype('"'))
    eq(2, #funcs.getreg('"', 1, true))

    -- Test for right click in line-wise visual mode outside the selection
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {1, 15})
    feed('V')
    meths.input_mouse('right', 'press', '', 0, 1, 9)
    meths.input_mouse('right', 'release', '', 0, 1, 9)
    feed('<Down><CR>')
    eq({2, 9}, meths.win_get_cursor(0))
    eq('', funcs.getreg('"'))

    -- Try clicking outside the window
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {2, 1})
    feed('vee')
    meths.input_mouse('right', 'press', '', 0, 6, 1)
    meths.input_mouse('right', 'release', '', 0, 6, 1)
    feed('<Down><CR>')
    eq(2, funcs.winnr())
    eq('', funcs.getreg('"'))

    -- Test for right click in visual mode inside the selection with vertical splits
    command('wincmd t')
    command('rightbelow vsplit')
    funcs.setreg('"', '')
    meths.win_set_cursor(0, {1, 9})
    feed('vee')
    meths.input_mouse('right', 'press', '', 0, 0, 52)
    meths.input_mouse('right', 'release', '', 0, 0, 52)
    feed('<Down><CR>')
    eq({1, 9}, meths.win_get_cursor(0))
    eq('ran away', funcs.getreg('"'))

    -- Test for right click inside visual selection at bottom of window with winbar
    command('setlocal winbar=WINBAR')
    feed('2yyP')
    funcs.setreg('"', '')
    feed('G$vbb')
    meths.input_mouse('right', 'press', '', 0, 4, 61)
    meths.input_mouse('right', 'release', '', 0, 4, 61)
    feed('<Down><CR>')
    eq({4, 20}, meths.win_get_cursor(0))
    eq('the moon', funcs.getreg('"'))
  end)
end)
