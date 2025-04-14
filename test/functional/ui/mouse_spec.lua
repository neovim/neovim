local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed, api = n.clear, n.feed, n.api
local insert, feed_command = n.insert, n.feed_command
local eq, fn = t.eq, n.fn
local poke_eventloop = n.poke_eventloop
local command = n.command
local exec = n.exec

describe('ui/mouse/input', function()
  local screen

  before_each(function()
    clear()
    api.nvim_set_option_value('mouse', 'a', {})
    api.nvim_set_option_value('list', true, {})
    -- NB: this is weird, but mostly irrelevant to the test
    -- So I didn't bother to change it
    command('set listchars=eol:$')
    command('setl listchars=nbsp:x')
    screen = Screen.new(25, 5)
    screen:add_extra_attr_ids {
      [100] = {
        bold = true,
        background = Screen.colors.LightGrey,
        foreground = Screen.colors.Blue1,
      },
    }
    command('set mousemodel=extend')
    feed('itesting<cr>mouse<cr>support and selection<esc>')
    screen:expect([[
      testing                  |
      mouse                    |
      support and selectio^n    |
      {1:~                        }|
                               |
    ]])
  end)

  it('single left click moves cursor', function()
    feed('<LeftMouse><2,1>')
    screen:expect {
      grid = [[
      testing                  |
      mo^use                    |
      support and selection    |
      {1:~                        }|
                               |
    ]],
      mouse_enabled = true,
    }
    feed('<LeftMouse><0,0>')
    screen:expect([[
      ^testing                  |
      mouse                    |
      support and selection    |
      {1:~                        }|
                               |
    ]])
  end)

  it("in external ui works with unset 'mouse'", function()
    api.nvim_set_option_value('mouse', '', {})
    feed('<LeftMouse><2,1>')
    screen:expect {
      grid = [[
      testing                  |
      mo^use                    |
      support and selection    |
      {1:~                        }|
                               |
    ]],
      mouse_enabled = false,
    }
    feed('<LeftMouse><0,0>')
    screen:expect([[
      ^testing                  |
      mouse                    |
      support and selection    |
      {1:~                        }|
                               |
    ]])
  end)

  it('double left click enters visual mode', function()
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    feed('<LeftMouse><0,0>')
    feed('<LeftRelease><0,0>')
    screen:expect([[
      {17:testin}^g                  |
      mouse                    |
      support and selection    |
      {1:~                        }|
      {5:-- VISUAL --}             |
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
      ^t{17:esting}                  |
      mouse                    |
      support and selection    |
      {1:~                        }|
      {5:-- VISUAL LINE --}        |
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
      {1:~                        }|
      {5:-- VISUAL BLOCK --}       |
    ]])
  end)

  describe('tab drag', function()
    it('in tabline on filler space moves tab to the end', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {5: + foo }{24: + bar }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftDrag><14,0>')
      screen:expect([[
        {24: + bar }{5: + foo }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
    end)

    it('in tabline to the left moves tab left', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><11,0>')
      -- Prevent the case where screen:expect() with "unchanged" returns too early,
      -- causing the click position to be overwritten by the next drag.
      poke_eventloop()
      screen:expect {
        grid = [[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]],
        unchanged = true,
      }
      feed('<LeftDrag><6,0>')
      screen:expect([[
        {5: + bar }{24: + foo }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
    end)

    it('in tabline to the right moves tab right', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {5: + foo }{24: + bar }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftDrag><7,0>')
      screen:expect([[
        {24: + bar }{5: + foo }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
    end)

    it('out of tabline under filler space moves tab to the end', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {5: + foo }{24: + bar }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftDrag><4,1>')
      screen:expect {
        grid = [[
        {5: + foo }{24: + bar }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]],
        unchanged = true,
      }
      feed('<LeftDrag><14,1>')
      screen:expect([[
        {24: + bar }{5: + foo }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
    end)

    it('out of tabline to the left moves tab left', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><11,0>')
      -- Prevent the case where screen:expect() with "unchanged" returns too early,
      -- causing the click position to be overwritten by the next drag.
      poke_eventloop()
      screen:expect {
        grid = [[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]],
        unchanged = true,
      }
      feed('<LeftDrag><11,1>')
      screen:expect {
        grid = [[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]],
        unchanged = true,
      }
      feed('<LeftDrag><6,1>')
      screen:expect([[
        {5: + bar }{24: + foo }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
    end)

    it('out of tabline to the right moves tab right', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {5: + foo }{24: + bar }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftDrag><4,1>')
      screen:expect {
        grid = [[
        {5: + foo }{24: + bar }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]],
        unchanged = true,
      }
      feed('<LeftDrag><7,1>')
      screen:expect([[
        {24: + bar }{5: + foo }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
    end)
  end)

  describe('tabline', function()
    it('left click in default tabline (tabpage label) switches to tab', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><4,0>')
      screen:expect([[
        {5: + foo }{24: + bar }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><6,0>')
      screen:expect_unchanged()
      feed('<LeftMouse><10,0>')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><12,0>')
      screen:expect_unchanged()
    end)

    it('left click in default tabline (blank space) switches tab', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><20,0>')
      screen:expect([[
        {5: + foo }{24: + bar }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><22,0>')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
    end)

    it('left click in default tabline (close label) closes tab', function()
      api.nvim_set_option_value('hidden', true, {})
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<LeftMouse><24,0>')
      screen:expect([[
        this is fo^o              |
        {1:~                        }|*3
                                 |
      ]])
    end)

    it('double click in default tabline opens new tab before', function()
      feed_command('%delete')
      insert('this is foo')
      feed_command('silent file foo | tabnew | file bar')
      insert('this is bar')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<2-LeftMouse><4,0>')
      screen:expect([[
        {5:  Name] }{24: + foo  + bar }{2:  }{24:X}|
        {1:^$}                        |
        {1:~                        }|*2
                                 |
      ]])
      command('tabclose')
      screen:expect([[
        {5: + foo }{24: + bar }{2:          }{24:X}|
        this is fo^o              |
        {1:~                        }|*2
                                 |
      ]])
      feed('<2-LeftMouse><20,0>')
      screen:expect([[
        {24: + foo  + bar }{5:  Name] }{2:  }{24:X}|
        {1:^$}                        |
        {1:~                        }|*2
                                 |
      ]])
      command('tabclose')
      screen:expect([[
        {24: + foo }{5: + bar }{2:          }{24:X}|
        this is ba^r{1:$}             |
        {1:~                        }|*2
                                 |
      ]])
      feed('<2-LeftMouse><10,0>')
      screen:expect([[
        {24: + foo }{5:  Name] }{24: + bar }{2:  }{24:X}|
        {1:^$}                        |
        {1:~                        }|*2
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
        api.nvim_set_option_value('tabline', '%@Test@test%X-%5@Test2@test2', {})
        api.nvim_set_option_value('showtabline', 2, {})
        screen:expect([[
          {2:test-test2               }|
          testing                  |
          mouse                    |
          support and selectio^n    |
                                   |
        ]])
        api.nvim_set_var('reply', {})
      end)

      local check_reply = function(expected)
        eq(expected, api.nvim_get_var('reply'))
        api.nvim_set_var('reply', {})
      end

      local test_click = function(name, click_str, click_num, mouse_button, modifiers)
        local function doit(do_click)
          eq(1, fn.has('tablineat'))
          do_click(0, 3)
          check_reply({ 0, click_num, mouse_button, modifiers })
          do_click(0, 4)
          check_reply({})
          do_click(0, 6)
          check_reply({ 5, click_num, mouse_button, modifiers, 2 })
          do_click(0, 13)
          check_reply({ 5, click_num, mouse_button, modifiers, 2 })
        end

        it(name .. ' works (pseudokey)', function()
          doit(function(row, col)
            feed(click_str .. '<' .. col .. ',' .. row .. '>')
          end)
        end)

        it(name .. ' works (nvim_input_mouse)', function()
          doit(function(row, col)
            local buttons = { l = 'left', m = 'middle', r = 'right' }
            local modstr = (click_num > 1) and tostring(click_num) or ''
            for char in string.gmatch(modifiers, '%w') do
              modstr = modstr .. char .. '-' -- - not needed but should be accepted
            end
            api.nvim_input_mouse(buttons[mouse_button], 'press', modstr, 0, row, col)
          end)
        end)
      end

      test_click('single left click', '<LeftMouse>', 1, 'l', '    ')
      test_click('shifted single left click', '<S-LeftMouse>', 1, 'l', 's   ')
      test_click('shifted single left click with alt modifier', '<S-A-LeftMouse>', 1, 'l', 's a ')
      test_click(
        'shifted single left click with alt and ctrl modifiers',
        '<S-C-A-LeftMouse>',
        1,
        'l',
        'sca '
      )
      -- <C-RightMouse> does not work
      test_click('shifted single right click with alt modifier', '<S-A-RightMouse>', 1, 'r', 's a ')
      -- Modifiers do not work with MiddleMouse
      test_click(
        'shifted single middle click with alt and ctrl modifiers',
        '<MiddleMouse>',
        1,
        'm',
        '    '
      )
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
      {1:~                        }|
                               |
    ]])
    feed('<LeftDrag><4,1>')
    screen:expect([[
      testing                  |
      mo{17:us}^e                    |
      support and selection    |
      {1:~                        }|
      {5:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><2,2>')
    screen:expect([[
      testing                  |
      mo{17:use}                    |
      {17:su}^pport and selection    |
      {1:~                        }|
      {5:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><0,0>')
    screen:expect([[
      ^t{17:esting}                  |
      {17:mou}se                    |
      support and selection    |
      {1:~                        }|
      {5:-- VISUAL --}             |
    ]])
  end)

  it('left drag changes visual selection after tab click', function()
    feed_command('silent file foo | tabnew | file bar')
    insert('this is bar')
    feed_command('tabprevious') -- go to first tab
    screen:expect([[
      {5: + foo }{24: + bar }{2:          }{24:X}|
      testing                  |
      mouse                    |
      support and selectio^n    |
      :tabprevious             |
    ]])
    feed('<LeftMouse><10,0><LeftRelease>') -- go to second tab
    n.poke_eventloop()
    feed('<LeftMouse><0,1>')
    screen:expect([[
      {24: + foo }{5: + bar }{2:          }{24:X}|
      ^this is bar{1:$}             |
      {1:~                        }|*2
      :tabprevious             |
    ]])
    feed('<LeftDrag><4,1>')
    screen:expect([[
      {24: + foo }{5: + bar }{2:          }{24:X}|
      {17:this}^ is bar{1:$}             |
      {1:~                        }|*2
      {5:-- VISUAL --}             |
    ]])
  end)

  it('left drag changes visual selection in split layout', function()
    screen:try_resize(53, 14)
    command('set mouse=a')
    command('vsplit')
    command('wincmd l')
    command('below split')
    command('enew')
    feed('ifoo\nbar<esc>')

    screen:expect {
      grid = [[
      testing                   │testing                   |
      mouse                     │mouse                     |
      support and selection     │support and selection     |
      {1:~                         }│{1:~                         }|*2
      {1:~                         }│{2:[No Name] [+]             }|
      {1:~                         }│foo{1:$}                      |
      {1:~                         }│ba^r{1:$}                      |
      {1:~                         }│{1:~                         }|*4
      {2:[No Name] [+]              }{3:[No Name] [+]             }|
                                                           |
    ]],
    }

    api.nvim_input_mouse('left', 'press', '', 0, 6, 27)
    screen:expect {
      grid = [[
      testing                   │testing                   |
      mouse                     │mouse                     |
      support and selection     │support and selection     |
      {1:~                         }│{1:~                         }|*2
      {1:~                         }│{2:[No Name] [+]             }|
      {1:~                         }│^foo{1:$}                      |
      {1:~                         }│bar{1:$}                      |
      {1:~                         }│{1:~                         }|*4
      {2:[No Name] [+]              }{3:[No Name] [+]             }|
                                                           |
    ]],
    }
    api.nvim_input_mouse('left', 'drag', '', 0, 7, 30)

    screen:expect {
      grid = [[
      testing                   │testing                   |
      mouse                     │mouse                     |
      support and selection     │support and selection     |
      {1:~                         }│{1:~                         }|*2
      {1:~                         }│{2:[No Name] [+]             }|
      {1:~                         }│{17:foo}{100:$}                      |
      {1:~                         }│{17:bar}{1:^$}                      |
      {1:~                         }│{1:~                         }|*4
      {2:[No Name] [+]              }{3:[No Name] [+]             }|
      {5:-- VISUAL --}                                         |
    ]],
    }
  end)

  it('two clicks will enter VISUAL and dragging selects words', function()
    feed('<LeftMouse><2,2>')
    feed('<LeftRelease><2,2>')
    feed('<LeftMouse><2,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {17:suppor}^t and selection    |
      {1:~                        }|
      {5:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><0,1>')
    screen:expect([[
      testing                  |
      ^m{17:ouse}                    |
      {17:support} and selection    |
      {1:~                        }|
      {5:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><4,0>')
    screen:expect([[
      ^t{17:esting}                  |
      {17:mouse}                    |
      {17:support} and selection    |
      {1:~                        }|
      {5:-- VISUAL --}             |
    ]])
    feed('<LeftDrag><14,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {17:support and selectio}^n    |
      {1:~                        }|
      {5:-- VISUAL --}             |
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
      {17:su}^p{17:port and selection}    |
      {1:~                        }|
      {5:-- VISUAL LINE --}        |
    ]])
    feed('<LeftDrag><0,1>')
    screen:expect([[
      testing                  |
      ^m{17:ouse}                    |
      {17:support and selection}    |
      {1:~                        }|
      {5:-- VISUAL LINE --}        |
    ]])
    feed('<LeftDrag><4,0>')
    screen:expect([[
      {17:test}^i{17:ng}                  |
      {17:mouse}                    |
      {17:support and selection}    |
      {1:~                        }|
      {5:-- VISUAL LINE --}        |
    ]])
    feed('<LeftDrag><14,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      {17:support and se}^l{17:ection}    |
      {1:~                        }|
      {5:-- VISUAL LINE --}        |
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
      {1:~                        }|
      {5:-- VISUAL BLOCK --}       |
    ]])
    feed('<LeftDrag><0,1>')
    screen:expect([[
      testing                  |
      ^m{17:ou}se                    |
      {17:sup}port and selection    |
      {1:~                        }|
      {5:-- VISUAL BLOCK --}       |
    ]])
    feed('<LeftDrag><4,0>')
    screen:expect([[
      te{17:st}^ing                  |
      mo{17:use}                    |
      su{17:ppo}rt and selection    |
      {1:~                        }|
      {5:-- VISUAL BLOCK --}       |
    ]])
    feed('<LeftDrag><14,2>')
    screen:expect([[
      testing                  |
      mouse                    |
      su{17:pport and se}^lection    |
      {1:~                        }|
      {5:-- VISUAL BLOCK --}       |
    ]])
  end)

  it('right click extends visual selection to the clicked location', function()
    feed('<LeftMouse><0,0>')
    screen:expect([[
      ^testing                  |
      mouse                    |
      support and selection    |
      {1:~                        }|
                               |
    ]])
    feed('<RightMouse><2,2>')
    screen:expect([[
      {17:testing}                  |
      {17:mouse}                    |
      {17:su}^pport and selection    |
      {1:~                        }|
      {5:-- VISUAL --}             |
    ]])
  end)

  it('ctrl + left click will search for a tag', function()
    api.nvim_set_option_value('tags', './non-existent-tags-file', {})
    feed('<C-LeftMouse><0,0>')
    screen:expect([[
      {9:E433: No tags file}       |
      {9:E426: Tag not found: test}|
      {9:ing}                      |
      {6:Press ENTER or type comma}|
      {6:nd to continue}^           |
    ]])
    feed('<cr>')
  end)

  it('x1 and x2 can be triggered by api', function()
    api.nvim_set_var('x1_pressed', 0)
    api.nvim_set_var('x1_released', 0)
    api.nvim_set_var('x2_pressed', 0)
    api.nvim_set_var('x2_released', 0)
    command('nnoremap <X1Mouse> <Cmd>let g:x1_pressed += 1<CR>')
    command('nnoremap <X1Release> <Cmd>let g:x1_released += 1<CR>')
    command('nnoremap <X2Mouse> <Cmd>let g:x2_pressed += 1<CR>')
    command('nnoremap <X2Release> <Cmd>let g:x2_released += 1<CR>')
    api.nvim_input_mouse('x1', 'press', '', 0, 0, 0)
    api.nvim_input_mouse('x1', 'release', '', 0, 0, 0)
    api.nvim_input_mouse('x2', 'press', '', 0, 0, 0)
    api.nvim_input_mouse('x2', 'release', '', 0, 0, 0)
    eq(1, api.nvim_get_var('x1_pressed'), 'x1 pressed once')
    eq(1, api.nvim_get_var('x1_released'), 'x1 released once')
    eq(1, api.nvim_get_var('x2_pressed'), 'x2 pressed once')
    eq(1, api.nvim_get_var('x2_released'), 'x2 released once')
  end)

  it('dragging vertical separator', function()
    screen:try_resize(45, 5)
    command('setlocal nowrap')
    local oldwin = api.nvim_get_current_win()
    command('rightbelow vnew')
    screen:expect([[
      testing               │{1:^$}                     |
      mouse                 │{1:~                     }|
      support and selection │{1:~                     }|
      {2:[No Name] [+]          }{3:[No Name]             }|
                                                   |
    ]])
    api.nvim_input_mouse('left', 'press', '', 0, 0, 22)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 0, 1, 12)
    screen:expect([[
      testing     │{1:^$}                               |
      mouse       │{1:~                               }|
      support and │{1:~                               }|
      {2:< Name] [+]  }{3:[No Name]                       }|
                                                   |
    ]])
    api.nvim_input_mouse('left', 'drag', '', 0, 2, 2)
    screen:expect([[
      te│{1:^$}                                         |
      mo│{1:~                                         }|
      su│{1:~                                         }|
      {2:<  }{3:[No Name]                                 }|
                                                   |
    ]])
    api.nvim_input_mouse('left', 'release', '', 0, 2, 2)
    api.nvim_set_option_value('statuscolumn', 'foobar', { win = oldwin })
    screen:expect([[
      {8:fo}│{1:^$}                                         |
      {8:fo}│{1:~                                         }|*2
      {2:<  }{3:[No Name]                                 }|
                                                   |
    ]])
    api.nvim_input_mouse('left', 'press', '', 0, 0, 2)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 0, 1, 12)
    screen:expect([[
      {8:foobar}testin│{1:^$}                               |
      {8:foobar}mouse │{1:~                               }|
      {8:foobar}suppor│{1:~                               }|
      {2:< Name] [+]  }{3:[No Name]                       }|
                                                   |
    ]])
    api.nvim_input_mouse('left', 'drag', '', 0, 2, 22)
    screen:expect([[
      {8:foobar}testing         │{1:^$}                     |
      {8:foobar}mouse           │{1:~                     }|
      {8:foobar}support and sele│{1:~                     }|
      {2:[No Name] [+]          }{3:[No Name]             }|
                                                   |
    ]])
    api.nvim_input_mouse('left', 'release', '', 0, 2, 22)
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
      {1:~                         }│{1:~                         }|
      {3:[No Name] [+]              }{2:[No Name] [+]             }|
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      {1:~                                                    }|
      {2:[No Name] [+]                                        }|
      :vsp                                                 |
    ]])
    if use_api then
      api.nvim_input_mouse('wheel', 'down', '', 0, 0, 0)
    else
      feed('<ScrollWheelDown><0,0>')
    end
    screen:expect([[
      ^mouse scrolling           │lines                     |
                                │to                        |
      {1:~                         }│test                      |
      {1:~                         }│mouse scrolling           |
      {1:~                         }│                          |
      {1:~                         }│{1:~                         }|
      {3:[No Name] [+]              }{2:[No Name] [+]             }|
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      {1:~                                                    }|
      {2:[No Name] [+]                                        }|
      :vsp                                                 |
    ]])
    if use_api then
      api.nvim_input_mouse('wheel', 'up', '', 0, 0, 27)
    else
      feed('<ScrollWheelUp><27,0>')
    end
    screen:expect([[
      ^mouse scrolling           │text                      |
                                │with                      |
      {1:~                         }│many                      |
      {1:~                         }│lines                     |
      {1:~                         }│to                        |
      {1:~                         }│test                      |
      {3:[No Name] [+]              }{2:[No Name] [+]             }|
      to                                                   |
      test                                                 |
      mouse scrolling                                      |
                                                           |
      {1:~                                                    }|
      {2:[No Name] [+]                                        }|
      :vsp                                                 |
    ]])
    if use_api then
      api.nvim_input_mouse('wheel', 'up', '', 0, 7, 27)
      api.nvim_input_mouse('wheel', 'up', '', 0, 7, 27)
    else
      feed('<ScrollWheelUp><27,7><ScrollWheelUp>')
    end
    screen:expect([[
      ^mouse scrolling           │text                      |
                                │with                      |
      {1:~                         }│many                      |
      {1:~                         }│lines                     |
      {1:~                         }│to                        |
      {1:~                         }│test                      |
      {3:[No Name] [+]              }{2:[No Name] [+]             }|
      Inserting                                            |
      text                                                 |
      with                                                 |
      many                                                 |
      lines                                                |
      {2:[No Name] [+]                                        }|
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
    feed('<esc>:set nowrap<cr>')

    feed('a <esc>17Ab<esc>3Ab<esc>')
    screen:expect([[
                               |*2
      bbbbbbbbbbbbbbb^b         |
      {1:~                        }|
                               |
    ]])

    feed('<ScrollWheelLeft><0,0>')
    screen:expect([[
                               |*2
      n bbbbbbbbbbbbbbbbbbb^b   |
      {1:~                        }|
                               |
    ]])

    feed('^<ScrollWheelRight><0,0>')
    screen:expect([[
      g                        |
                               |
      ^t and selection bbbbbbbbb|
      {1:~                        }|
                               |
    ]])
  end)

  it('horizontal scrolling (nvim_input_mouse)', function()
    command('set sidescroll=0')
    feed('<esc>:set nowrap<cr>')

    feed('a <esc>17Ab<esc>3Ab<esc>')
    screen:expect([[
                               |*2
      bbbbbbbbbbbbbbb^b         |
      {1:~                        }|
                               |
    ]])

    api.nvim_input_mouse('wheel', 'left', '', 0, 0, 27)
    screen:expect([[
                               |*2
      n bbbbbbbbbbbbbbbbbbb^b   |
      {1:~                        }|
                               |
    ]])

    feed('^')
    api.nvim_input_mouse('wheel', 'right', '', 0, 0, 0)
    screen:expect([[
      g                        |
                               |
      ^t and selection bbbbbbbbb|
      {1:~                        }|
                               |
    ]])
  end)

  it("'sidescrolloff' applies to horizontal scrolling", function()
    command('set nowrap')
    command('set sidescrolloff=4')

    feed('I <esc>020ib<esc>0')
    screen:expect([[
      testing                  |
      mouse                    |
      ^bbbbbbbbbbbbbbbbbbbb supp|
      {1:~                        }|
                               |
    ]])

    api.nvim_input_mouse('wheel', 'right', '', 0, 0, 27)
    screen:expect([[
      g                        |
                               |
      bbbb^bbbbbbbbbb support an|
      {1:~                        }|
                               |
    ]])

    -- window-local 'sidescrolloff' should override global value. #21162
    command('setlocal sidescrolloff=2')
    feed('0')
    screen:expect([[
      testing                  |
      mouse                    |
      ^bbbbbbbbbbbbbbbbbbbb supp|
      {1:~                        }|
                               |
    ]])

    api.nvim_input_mouse('wheel', 'right', '', 0, 0, 27)
    screen:expect([[
      g                        |
                               |
      bb^bbbbbbbbbbbb support an|
      {1:~                        }|
                               |
    ]])
  end)

  local function test_mouse_click_conceal()
    it('(level 1) click on non-wrapped lines', function()
      feed_command('let &conceallevel=1', 'echo')

      feed('<esc><LeftMouse><0,0>')
      screen:expect([[
        ^Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        {14:>} 私は猫が大好き{1:>---}{14: X } {1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><1,0>')
      screen:expect([[
        S^ection{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        {14:>} 私は猫が大好き{1:>---}{14: X } {1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><21,0>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }^t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        {14:>} 私は猫が大好き{1:>---}{14: X } {1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><21,1>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t^3{14: } {14: }|
        {14:>} 私は猫が大好き{1:>---}{14: X } {1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><0,2>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        {14:^>} 私は猫が大好き{1:>---}{14: X } {1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><7,2>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        {14:>} 私は^猫が大好き{1:>---}{14: X } {1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><21,2>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        {14:>} 私は猫が大好き{1:>---}{14: ^X } {1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])
    end) -- level 1 - non wrapped

    it('(level 1) click on wrapped lines', function()
      feed_command('let &conceallevel=1', 'let &wrap=1', 'echo')

      feed('<esc><LeftMouse><24,1>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14:^ }|
        t4{14: }                      |
        {14:>} 私は猫が大好き{1:>---}{14: X}   |
        {14: } ✨🐈✨                 |
                                 |*2
      ]])

      feed('<esc><LeftMouse><0,2>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        ^t4{14: }                      |
        {14:>} 私は猫が大好き{1:>---}{14: X}   |
        {14: } ✨🐈✨                 |
                                 |*2
      ]])

      feed('<esc><LeftMouse><8,3>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        t4{14: }                      |
        {14:>} 私は猫^が大好き{1:>---}{14: X}   |
        {14: } ✨🐈✨                 |
                                 |*2
      ]])

      feed('<esc><LeftMouse><21,3>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        t4{14: }                      |
        {14:>} 私は猫が大好き{1:>---}{14: ^X}   |
        {14: } ✨🐈✨                 |
                                 |*2
      ]])

      feed('<esc><LeftMouse><4,4>')
      screen:expect([[
        Section{1:>>--->--->---}{14: }t1{14: } |
        {1:>--->--->---}  {14: }t2{14: } {14: }t3{14: } {14: }|
        t4{14: }                      |
        {14:>} 私は猫が大好き{1:>---}{14: X}   |
        {14: } ✨^🐈✨                 |
                                 |*2
      ]])
    end) -- level 1 - wrapped

    it('(level 2) click on non-wrapped lines', function()
      feed_command('let &conceallevel=2', 'echo')

      feed('<esc><LeftMouse><20,0>')
      screen:expect([[
        Section{1:>>--->--->---}^t1   |
        {1:>--->--->---}  t2 t3 t4   |
        {14:>} 私は猫が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><14,1>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  ^t2 t3 t4   |
        {14:>} 私は猫が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><18,1>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t^3 t4   |
        {14:>} 私は猫が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><0,2>') -- Weirdness
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
        {14:^>} 私は猫が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><8,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
        {14:>} 私は猫^が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><20,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
        {14:>} 私は猫が大好き{1:>---}{14:^X} ✨{1:>}|
                                 |
        {1:~                        }|*2
                                 |
      ]])
    end) -- level 2 - non wrapped

    it('(level 2) click on non-wrapped lines (insert mode)', function()
      feed_command('let &conceallevel=2', 'echo')

      feed('<esc>i<LeftMouse><20,0>')
      screen:expect([[
        Section{1:>>--->--->---}^t1   |
        {1:>--->--->---}  t2 t3 t4   |
        {14:>} 私は猫が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
        {5:-- INSERT --}             |
      ]])

      feed('<LeftMouse><14,1>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  ^t2 t3 t4   |
        {14:>} 私は猫が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
        {5:-- INSERT --}             |
      ]])

      feed('<LeftMouse><18,1>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t^3 t4   |
        {14:>} 私は猫が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
        {5:-- INSERT --}             |
      ]])

      feed('<LeftMouse><0,2>') -- Weirdness
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
        {14:^>} 私は猫が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
        {5:-- INSERT --}             |
      ]])

      feed('<LeftMouse><8,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
        {14:>} 私は猫^が大好き{1:>---}{14:X} ✨{1:>}|
                                 |
        {1:~                        }|*2
        {5:-- INSERT --}             |
      ]])

      feed('<LeftMouse><20,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
        {14:>} 私は猫が大好き{1:>---}{14:^X} ✨{1:>}|
                                 |
        {1:~                        }|*2
        {5:-- INSERT --}             |
      ]])
    end) -- level 2 - non wrapped (insert mode)

    it('(level 2) click on wrapped lines', function()
      feed_command('let &conceallevel=2', 'let &wrap=1', 'echo')

      feed('<esc><LeftMouse><20,0>')
      screen:expect([[
        Section{1:>>--->--->---}^t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
        {14:>} 私は猫が大好き{1:>---}{14:X}    |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><14,1>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  ^t2 t3      |
        t4                       |
        {14:>} 私は猫が大好き{1:>---}{14:X}    |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><18,1>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t^3      |
        t4                       |
        {14:>} 私は猫が大好き{1:>---}{14:X}    |
         ✨🐈✨                  |
                                 |*2
      ]])

      -- NOTE: The click would ideally be on the 't' in 't4', but wrapping
      -- caused the invisible '*' right before 't4' to remain on the previous
      -- screen line.  This is being treated as expected because fixing this is
      -- out of scope for mouse clicks.  Should the wrapping behavior of
      -- concealed characters change in the future, this case should be
      -- reevaluated.
      feed('<esc><LeftMouse><0,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 ^     |
        t4                       |
        {14:>} 私は猫が大好き{1:>---}{14:X}    |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><1,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t^4                       |
        {14:>} 私は猫が大好き{1:>---}{14:X}    |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><0,3>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
        {14:^>} 私は猫が大好き{1:>---}{14:X}    |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><20,3>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
        {14:>} 私は猫が大好き{1:>---}{14:^X}    |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><1,4>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
        {14:>} 私は猫が大好き{1:>---}{14:X}    |
         ^✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><5,4>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
        {14:>} 私は猫が大好き{1:>---}{14:X}    |
         ✨🐈^✨                  |
                                 |*2
      ]])
    end) -- level 2 - wrapped

    it('(level 3) click on non-wrapped lines', function()
      feed_command('let &conceallevel=3', 'echo')

      feed('<esc><LeftMouse><0,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
        ^ 私は猫が大好き{1:>----} ✨🐈|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><1,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
         ^私は猫が大好き{1:>----} ✨🐈|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><13,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
         私は猫が大好^き{1:>----} ✨🐈|
                                 |
        {1:~                        }|*2
                                 |
      ]])

      feed('<esc><LeftMouse><20,2>')
      feed('zH') -- FIXME: unnecessary horizontal scrolling
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3 t4   |
         私は猫が大好き{1:>----}^ ✨🐈|
                                 |
        {1:~                        }|*2
                                 |
      ]])
    end) -- level 3 - non wrapped

    it('(level 3) click on wrapped lines', function()
      feed_command('let &conceallevel=3', 'let &wrap=1', 'echo')

      feed('<esc><LeftMouse><14,1>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  ^t2 t3      |
        t4                       |
         私は猫が大好き{1:>----}     |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><18,1>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t^3      |
        t4                       |
         私は猫が大好き{1:>----}     |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><1,2>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t^4                       |
         私は猫が大好き{1:>----}     |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><0,3>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
        ^ 私は猫が大好き{1:>----}     |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><20,3>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
         私は猫が大好き{1:>----}^     |
         ✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><1,4>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
         私は猫が大好き{1:>----}     |
         ^✨🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><3,4>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
         私は猫が大好き{1:>----}     |
         ✨^🐈✨                  |
                                 |*2
      ]])

      feed('<esc><LeftMouse><5,4>')
      screen:expect([[
        Section{1:>>--->--->---}t1   |
        {1:>--->--->---}  t2 t3      |
        t4                       |
         私は猫が大好き{1:>----}     |
         ✨🐈^✨                  |
                                 |*2
      ]])
    end) -- level 3 - wrapped
  end

  describe('on concealed text', function()
    -- Helpful for reading the test expectations:
    -- :match Error /\^/

    before_each(function()
      screen:try_resize(25, 7)
      feed('ggdG')

      command([[setlocal concealcursor=ni nowrap shiftwidth=2 tabstop=4 list listchars=tab:>-]])
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

    describe('(syntax)', function()
      before_each(function()
        command([[syntax region X0 matchgroup=X1 start=/\*/ end=/\*/ concealends contains=X2]])
        command([[syntax match X2 /cats/ conceal cchar=X contained]])
        command([[syntax match X3 /\n\@<=x/ conceal cchar=>]])
      end)
      test_mouse_click_conceal()
    end)

    describe('(matchadd())', function()
      before_each(function()
        fn.matchadd('Conceal', [[\*]])
        fn.matchadd('Conceal', [[cats]], 10, -1, { conceal = 'X' })
        fn.matchadd('Conceal', [[\n\@<=x]], 10, -1, { conceal = '>' })
      end)
      test_mouse_click_conceal()
    end)

    describe('(extmarks)', function()
      before_each(function()
        local ns = api.nvim_create_namespace('conceal')
        api.nvim_buf_set_extmark(0, ns, 0, 11, { end_col = 12, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 0, 14, { end_col = 15, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 1, 5, { end_col = 6, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 1, 8, { end_col = 9, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 1, 10, { end_col = 11, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 1, 13, { end_col = 14, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 1, 15, { end_col = 16, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 1, 18, { end_col = 19, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 2, 24, { end_col = 25, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 2, 29, { end_col = 30, conceal = '' })
        api.nvim_buf_set_extmark(0, ns, 2, 25, { end_col = 29, conceal = 'X' })
        api.nvim_buf_set_extmark(0, ns, 2, 0, { end_col = 1, conceal = '>' })
      end)
      test_mouse_click_conceal()
    end)
  end)

  it('virtual text does not change cursor placement on concealed line', function()
    command('%delete')
    insert('aaaaaaaaaa|hidden|bbbbbbbbbb|hidden|cccccccccc')
    command('syntax match test /|hidden|/ conceal cchar=X')
    command('set conceallevel=2 concealcursor=n virtualedit=all')
    screen:expect([[
      aaaaaaaaaa{14:X}bbbbbbb       |
      bbb{14:X}ccccccccc^c           |
      {1:~                        }|*2
                               |
    ]])
    api.nvim_input_mouse('left', 'press', '', 0, 0, 22)
    screen:expect([[
      aaaaaaaaaa{14:X}bbbbbb^b       |
      bbb{14:X}cccccccccc           |
      {1:~                        }|*2
                               |
    ]])
    api.nvim_input_mouse('left', 'press', '', 0, 1, 16)
    screen:expect([[
      aaaaaaaaaa{14:X}bbbbbbb       |
      bbb{14:X}cccccccccc  ^         |
      {1:~                        }|*2
                               |
    ]])

    api.nvim_buf_set_extmark(0, api.nvim_create_namespace(''), 0, 0, {
      virt_text = { { '?', 'ErrorMsg' } },
      virt_text_pos = 'right_align',
      virt_text_repeat_linebreak = true,
    })
    screen:expect([[
      aaaaaaaaaa{14:X}bbbbbbb      {9:?}|
      bbb{14:X}cccccccccc  ^        {9:?}|
      {1:~                        }|*2
                               |
    ]])
    api.nvim_input_mouse('left', 'press', '', 0, 0, 22)
    screen:expect([[
      aaaaaaaaaa{14:X}bbbbbb^b      {9:?}|
      bbb{14:X}cccccccccc          {9:?}|
      {1:~                        }|*2
                               |
    ]])
    api.nvim_input_mouse('left', 'press', '', 0, 1, 16)
    screen:expect([[
      aaaaaaaaaa{14:X}bbbbbbb      {9:?}|
      bbb{14:X}cccccccccc  ^        {9:?}|
      {1:~                        }|*2
                               |
    ]])
  end)

  it("mouse click on window separator in statusline doesn't crash", function()
    api.nvim_set_option_value('winwidth', 1, {})
    api.nvim_set_option_value('statusline', '%f', {})

    command('vsplit')
    command('redraw')

    local lines = api.nvim_get_option_value('lines', {})
    local columns = api.nvim_get_option_value('columns', {})

    api.nvim_input_mouse('left', 'press', '', 0, lines - 1, math.floor(columns / 2))
    command('redraw')
  end)

  it('getmousepos() works correctly', function()
    local winwidth = api.nvim_get_option_value('winwidth', {})
    -- Set winwidth=1 so that window sizes don't change.
    api.nvim_set_option_value('winwidth', 1, {})
    command('tabedit')
    local tabpage = api.nvim_get_current_tabpage()
    insert('hello')
    command('vsplit')
    local opts = {
      relative = 'editor',
      width = 12,
      height = 1,
      col = 8,
      row = 1,
      anchor = 'NW',
      style = 'minimal',
      border = 'single',
      focusable = 1,
    }
    local float = api.nvim_open_win(api.nvim_get_current_buf(), false, opts)
    command('redraw')
    local lines = api.nvim_get_option_value('lines', {})
    local columns = api.nvim_get_option_value('columns', {})

    -- Test that screenrow and screencol are set properly for all positions.
    for row = 0, lines - 1 do
      for col = 0, columns - 1 do
        -- Skip the X button that would close the tab.
        if row ~= 0 or col ~= columns - 1 then
          api.nvim_input_mouse('left', 'press', '', 0, row, col)
          api.nvim_set_current_tabpage(tabpage)
          local mousepos = fn.getmousepos()
          eq(row + 1, mousepos.screenrow)
          eq(col + 1, mousepos.screencol)
          -- All other values should be 0 when clicking on the command line.
          if row == lines - 1 then
            eq(0, mousepos.winid)
            eq(0, mousepos.winrow)
            eq(0, mousepos.wincol)
            eq(0, mousepos.line)
            eq(0, mousepos.column)
            eq(0, mousepos.coladd)
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
        api.nvim_input_mouse('left', 'press', '', 0, row, col)
        local mousepos = fn.getmousepos()
        eq(float, mousepos.winid)
        eq(win_row + 1, mousepos.winrow)
        eq(win_col + 1, mousepos.wincol)
        local line = 0
        local column = 0
        local coladd = 0
        if
          win_row > 0
          and win_row < opts.height + 1
          and win_col > 0
          and win_col < opts.width + 1
        then
          -- Because of border, win_row and win_col don't need to be
          -- incremented by 1.
          line = math.min(win_row, fn.line('$'))
          column = math.min(win_col, #fn.getline(line) + 1)
          coladd = win_col - column
        end
        eq(line, mousepos.line)
        eq(column, mousepos.column)
        eq(coladd, mousepos.coladd)
      end
    end

    -- Test that mouse position values are properly set for the floating
    -- window, after removing the border.
    opts.border = 'none'
    api.nvim_win_set_config(float, opts)
    command('redraw')
    for win_row = 0, opts.height - 1 do
      for win_col = 0, opts.width - 1 do
        local row = win_row + opts.row
        local col = win_col + opts.col
        api.nvim_input_mouse('left', 'press', '', 0, row, col)
        local mousepos = fn.getmousepos()
        eq(float, mousepos.winid)
        eq(win_row + 1, mousepos.winrow)
        eq(win_col + 1, mousepos.wincol)
        local line = math.min(win_row + 1, fn.line('$'))
        local column = math.min(win_col + 1, #fn.getline(line) + 1)
        local coladd = win_col + 1 - column
        eq(line, mousepos.line)
        eq(column, mousepos.column)
        eq(coladd, mousepos.coladd)
      end
    end

    -- Test that mouse position values are properly set for ordinary windows.
    -- Set the float to be unfocusable instead of closing, to additionally test
    -- that getmousepos() does not consider unfocusable floats. (see discussion
    -- in PR #14937 for details).
    opts.focusable = false
    api.nvim_win_set_config(float, opts)
    command('redraw')
    for nr = 1, 2 do
      for win_row = 0, fn.winheight(nr) - 1 do
        for win_col = 0, fn.winwidth(nr) - 1 do
          local row = win_row + fn.win_screenpos(nr)[1] - 1
          local col = win_col + fn.win_screenpos(nr)[2] - 1
          api.nvim_input_mouse('left', 'press', '', 0, row, col)
          local mousepos = fn.getmousepos()
          eq(fn.win_getid(nr), mousepos.winid)
          eq(win_row + 1, mousepos.winrow)
          eq(win_col + 1, mousepos.wincol)
          local line = math.min(win_row + 1, fn.line('$'))
          local column = math.min(win_col + 1, #fn.getline(line) + 1)
          local coladd = win_col + 1 - column
          eq(line, mousepos.line)
          eq(column, mousepos.column)
          eq(coladd, mousepos.coladd)
        end
      end
    end

    -- Restore state and release mouse.
    command('tabclose!')
    api.nvim_set_option_value('winwidth', winwidth, {})
    api.nvim_input_mouse('left', 'release', '', 0, 0, 0)
  end)

  it('scroll keys are not translated into multiclicks and can be mapped #6211 #6989', function()
    api.nvim_set_var('mouse_up', 0)
    api.nvim_set_var('mouse_up2', 0)
    command('nnoremap <ScrollWheelUp> <Cmd>let g:mouse_up += 1<CR>')
    command('nnoremap <2-ScrollWheelUp> <Cmd>let g:mouse_up2 += 1<CR>')
    feed('<ScrollWheelUp><0,0>')
    feed('<ScrollWheelUp><0,0>')
    api.nvim_input_mouse('wheel', 'up', '', 0, 0, 0)
    api.nvim_input_mouse('wheel', 'up', '', 0, 0, 0)
    eq(4, api.nvim_get_var('mouse_up'))
    eq(0, api.nvim_get_var('mouse_up2'))
  end)

  it('<MouseMove> to different locations can be mapped', function()
    api.nvim_set_var('mouse_move', 0)
    api.nvim_set_var('mouse_move2', 0)
    command('nnoremap <MouseMove> <Cmd>let g:mouse_move += 1<CR>')
    command('nnoremap <2-MouseMove> <Cmd>let g:mouse_move2 += 1<CR>')
    feed('<MouseMove><1,0>')
    feed('<MouseMove><2,0>')
    api.nvim_input_mouse('move', '', '', 0, 0, 3)
    api.nvim_input_mouse('move', '', '', 0, 0, 4)
    eq(4, api.nvim_get_var('mouse_move'))
    eq(0, api.nvim_get_var('mouse_move2'))
  end)

  it('<MouseMove> to same location does not generate events #31103', function()
    api.nvim_set_var('mouse_move', 0)
    api.nvim_set_var('mouse_move2', 0)
    command('nnoremap <MouseMove> <Cmd>let g:mouse_move += 1<CR>')
    command('nnoremap <2-MouseMove> <Cmd>let g:mouse_move2 += 1<CR>')
    api.nvim_input_mouse('move', '', '', 0, 0, 3)
    eq(1, api.nvim_get_var('mouse_move'))
    eq(0, api.nvim_get_var('mouse_move2'))
    feed('<MouseMove><3,0>')
    feed('<MouseMove><3,0>')
    api.nvim_input_mouse('move', '', '', 0, 0, 3)
    api.nvim_input_mouse('move', '', '', 0, 0, 3)
    eq(1, api.nvim_get_var('mouse_move'))
    eq(0, api.nvim_get_var('mouse_move2'))
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    feed('<MouseMove><3,0><Insert>')
    eq(1, api.nvim_get_var('mouse_move'))
    eq(0, api.nvim_get_var('mouse_move2'))
    eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
  end)

  it('feeding <MouseMove> in Normal mode does not use uninitialized memory #19480', function()
    feed('<MouseMove>')
    n.poke_eventloop()
    n.assert_alive()
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

    api.nvim_win_set_cursor(0, { 1, 0 })
    api.nvim_input_mouse('right', 'press', '', 0, 0, 4)
    api.nvim_input_mouse('right', 'release', '', 0, 0, 4)
    feed('<Down><Down><CR>')
    eq('bar', api.nvim_get_var('menustr'))
    eq({ 1, 4 }, api.nvim_win_get_cursor(0))

    -- Test for right click in visual mode inside the selection
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 1, 9 })
    feed('vee')
    api.nvim_input_mouse('right', 'press', '', 0, 0, 11)
    api.nvim_input_mouse('right', 'release', '', 0, 0, 11)
    feed('<Down><CR>')
    eq({ 1, 9 }, api.nvim_win_get_cursor(0))
    eq('ran away', fn.getreg('"'))

    -- Test for right click in visual mode right before the selection
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 1, 9 })
    feed('vee')
    api.nvim_input_mouse('right', 'press', '', 0, 0, 8)
    api.nvim_input_mouse('right', 'release', '', 0, 0, 8)
    feed('<Down><CR>')
    eq({ 1, 8 }, api.nvim_win_get_cursor(0))
    eq('', fn.getreg('"'))

    -- Test for right click in visual mode right after the selection
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 1, 9 })
    feed('vee')
    api.nvim_input_mouse('right', 'press', '', 0, 0, 17)
    api.nvim_input_mouse('right', 'release', '', 0, 0, 17)
    feed('<Down><CR>')
    eq({ 1, 17 }, api.nvim_win_get_cursor(0))
    eq('', fn.getreg('"'))

    -- Test for right click in block-wise visual mode inside the selection
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 1, 15 })
    feed('<C-V>j3l')
    api.nvim_input_mouse('right', 'press', '', 0, 1, 16)
    api.nvim_input_mouse('right', 'release', '', 0, 1, 16)
    feed('<Down><CR>')
    eq({ 1, 15 }, api.nvim_win_get_cursor(0))
    eq('\0224', fn.getregtype('"'))

    -- Test for right click in block-wise visual mode outside the selection
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 1, 15 })
    feed('<C-V>j3l')
    api.nvim_input_mouse('right', 'press', '', 0, 1, 1)
    api.nvim_input_mouse('right', 'release', '', 0, 1, 1)
    feed('<Down><CR>')
    eq({ 2, 1 }, api.nvim_win_get_cursor(0))
    eq('v', fn.getregtype('"'))
    eq('', fn.getreg('"'))

    -- Test for right click in line-wise visual mode inside the selection
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 1, 15 })
    feed('V')
    api.nvim_input_mouse('right', 'press', '', 0, 0, 9)
    api.nvim_input_mouse('right', 'release', '', 0, 0, 9)
    feed('<Down><CR>')
    eq({ 1, 0 }, api.nvim_win_get_cursor(0)) -- After yanking, the cursor goes to 1,1
    eq('V', fn.getregtype('"'))
    eq(1, #fn.getreg('"', 1, true))

    -- Test for right click in multi-line line-wise visual mode inside the selection
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 1, 15 })
    feed('Vj')
    api.nvim_input_mouse('right', 'press', '', 0, 1, 19)
    api.nvim_input_mouse('right', 'release', '', 0, 1, 19)
    feed('<Down><CR>')
    eq({ 1, 0 }, api.nvim_win_get_cursor(0)) -- After yanking, the cursor goes to 1,1
    eq('V', fn.getregtype('"'))
    eq(2, #fn.getreg('"', 1, true))

    -- Test for right click in line-wise visual mode outside the selection
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 1, 15 })
    feed('V')
    api.nvim_input_mouse('right', 'press', '', 0, 1, 9)
    api.nvim_input_mouse('right', 'release', '', 0, 1, 9)
    feed('<Down><CR>')
    eq({ 2, 9 }, api.nvim_win_get_cursor(0))
    eq('', fn.getreg('"'))

    -- Try clicking outside the window
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 2, 1 })
    feed('vee')
    api.nvim_input_mouse('right', 'press', '', 0, 6, 1)
    api.nvim_input_mouse('right', 'release', '', 0, 6, 1)
    feed('<Down><CR>')
    eq(2, fn.winnr())
    eq('', fn.getreg('"'))

    -- Test for right click in visual mode inside the selection with vertical splits
    command('wincmd t')
    command('rightbelow vsplit')
    fn.setreg('"', '')
    api.nvim_win_set_cursor(0, { 1, 9 })
    feed('vee')
    api.nvim_input_mouse('right', 'press', '', 0, 0, 52)
    api.nvim_input_mouse('right', 'release', '', 0, 0, 52)
    feed('<Down><CR>')
    eq({ 1, 9 }, api.nvim_win_get_cursor(0))
    eq('ran away', fn.getreg('"'))

    -- Test for right click inside visual selection at bottom of window with winbar
    command('setlocal winbar=WINBAR')
    feed('2yyP')
    fn.setreg('"', '')
    feed('G$vbb')
    api.nvim_input_mouse('right', 'press', '', 0, 4, 61)
    api.nvim_input_mouse('right', 'release', '', 0, 4, 61)
    feed('<Down><CR>')
    eq({ 4, 20 }, api.nvim_win_get_cursor(0))
    eq('the moon', fn.getreg('"'))

    -- Try clicking in the cmdline
    api.nvim_input_mouse('right', 'press', '', 0, 23, 0)
    api.nvim_input_mouse('right', 'release', '', 0, 23, 0)
    feed('<Down><Down><Down><CR>')
    eq('baz', api.nvim_get_var('menustr'))

    -- Try clicking in horizontal separator with global statusline
    command('set laststatus=3')
    api.nvim_input_mouse('right', 'press', '', 0, 5, 0)
    api.nvim_input_mouse('right', 'release', '', 0, 5, 0)
    feed('<Down><CR>')
    eq('foo', api.nvim_get_var('menustr'))

    -- Try clicking in the cmdline with global statusline
    api.nvim_input_mouse('right', 'press', '', 0, 23, 0)
    api.nvim_input_mouse('right', 'release', '', 0, 23, 0)
    feed('<Down><Down><CR>')
    eq('bar', api.nvim_get_var('menustr'))
  end)

  it('below a concealed line #33450', function()
    api.nvim_set_option_value('conceallevel', 2, {})
    api.nvim_buf_set_extmark(0, api.nvim_create_namespace(''), 1, 0, { conceal_lines = '' })
    api.nvim_input_mouse('left', 'press', '', 0, 1, 0)
    api.nvim_input_mouse('left', 'release', '', 0, 1, 0)
    eq(3, fn.line('.'))
    -- No error when clicking below last line that is concealed.
    screen:try_resize(80, 10) -- Prevent hit-enter
    api.nvim_set_option_value('cmdheight', 3, {})
    local count = api.nvim_buf_line_count(0)
    api.nvim_buf_set_extmark(0, 1, count - 1, 0, { conceal_lines = '' })
    api.nvim_input_mouse('left', 'press', '', 0, count, 0)
    eq('', api.nvim_get_vvar('errmsg'))
  end)
end)
