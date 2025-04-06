local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed, command = n.clear, n.feed, n.command
local fn = n.fn
local api = n.api
local eq = t.eq
local eval = n.eval
local retry = t.retry
local testprg = n.testprg
local is_os = t.is_os

describe("'wildmenu'", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Yellow1, foreground = Screen.colors.Black },
    }
  end)

  -- oldtest: Test_wildmenu_screendump()
  it('works', function()
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Yellow1, foreground = Screen.colors.Black },
    }
    -- Test simple wildmenu
    feed(':sign <Tab>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      {100:define}{3:  jump  list  >    }|
      :sign define^             |
    ]],
    }

    feed('<Tab>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      {3:define  }{100:jump}{3:  list  >    }|
      :sign jump^               |
    ]],
    }

    feed('<Tab>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      {3:define  jump  }{100:list}{3:  >    }|
      :sign list^               |
    ]],
    }

    -- Looped back to the original value
    feed('<Tab><Tab><Tab><Tab>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      {3:define  jump  list  >    }|
      :sign ^                   |
    ]],
    }

    -- Test that the wild menu is cleared properly
    feed('<Space>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*3
      :sign  ^                  |
    ]],
    }

    -- Test that a different wildchar still works
    feed('<Esc>')
    command('set wildchar=<Esc>')
    feed(':sign <Esc>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      {100:define}{3:  jump  list  >    }|
      :sign define^             |
    ]],
    }

    -- Double-<Esc> is a hard-coded method to escape while wildchar=<Esc>. Make
    -- sure clean up is properly done in edge case like this.
    feed('<Esc>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
    }
  end)

  it('C-E to cancel wildmenu completion restore original input', function()
    feed(':sign <tab>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {100:define}{3:  jump  list  >    }|
      :sign define^             |
    ]])
    feed('<C-E>')
    screen:expect([[
                               |
      {1:~                        }|*3
      :sign ^                   |
    ]])
  end)

  it('C-Y to apply selection and end wildmenu completion', function()
    feed(':sign <tab>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {100:define}{3:  jump  list  >    }|
      :sign define^             |
    ]])
    feed('<tab><C-Y>')
    screen:expect([[
                               |
      {1:~                        }|*3
      :sign jump^               |
    ]])
  end)

  it(':sign <tab> shows wildmenu completions', function()
    command('set wildmenu wildmode=full')
    feed(':sign <tab>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {100:define}{3:  jump  list  >    }|
      :sign define^             |
    ]])
  end)

  it(':sign <tab> <space> hides wildmenu #8453', function()
    command('set wildmode=full')
    -- only a regression if status-line open
    command('set laststatus=2')
    command('set wildmenu')
    feed(':sign <tab>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {100:define}{3:  jump  list  >    }|
      :sign define^             |
    ]])
    feed('<space>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {3:[No Name]                }|
      :sign define ^            |
    ]])
  end)

  it('does not crash after cycling back to original text', function()
    command('set wildmode=full')
    feed(':j<Tab><Tab><Tab>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {3:join  jumps              }|
      :j^                       |
    ]])
    -- This would cause nvim to crash before #6650
    feed('<BS><Tab>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {100:!}{3:  #  &  <  =  >  @  >   }|
      :!^                       |
    ]])
  end)

  it('is preserved during :terminal activity', function()
    command('set wildmenu wildmode=full')
    command('set scrollback=4')
    feed((':terminal "%s" REP 5000 !terminal_output!<cr>'):format(testprg('shell-test')))
    feed('G') -- Follow :terminal output.
    feed([[:sign <Tab>]]) -- Invoke wildmenu.
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Black, background = Screen.colors.Yellow },
      [101] = {
        bold = true,
        foreground = Screen.colors.White,
        background = Screen.colors.DarkGreen,
      },
    }
    -- NB: in earlier versions terminal output was redrawn during cmdline mode.
    -- For now just assert that the screen remains unchanged.
    screen:expect { any = '{100:define}{101:  jump  list  >    }|\n:sign define^             |' }
    screen:expect_unchanged()

    -- cmdline CTRL-D display should also be preserved.
    feed([[<C-U>]])
    feed([[sign <C-D>]]) -- Invoke cmdline CTRL-D.
    screen:expect {
      grid = [[
      :sign                    |
      define    place          |
      jump      undefine       |
      list      unplace        |
      :sign ^                   |
    ]],
    }
    screen:expect_unchanged()

    -- Exiting cmdline should show the buffer.
    feed([[<C-\><C-N>]])
    screen:expect { any = [[!terminal_output!]] }
  end)

  it('ignores :redrawstatus called from a timer #7108', function()
    command('set wildmenu wildmode=full')
    command([[call timer_start(10, {->execute('redrawstatus')}, {'repeat':-1})]])
    feed([[<C-\><C-N>]])
    feed([[:sign <Tab>]]) -- Invoke wildmenu.
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      {100:define}{3:  jump  list  >    }|
      :sign define^             |
    ]],
    }
    screen:expect_unchanged()
  end)

  it('with laststatus=0, :vsplit, :term #2255', function()
    if not is_os('win') then
      command('set shell=sh') -- Need a predictable "$" prompt.
      command('let $PS1 = "$"')
    end
    command('set laststatus=0')
    command('vsplit')
    command('term')

    -- Check for a shell prompt to verify that the terminal loaded.
    retry(nil, nil, function()
      if is_os('win') then
        eq('Microsoft', eval("matchstr(join(getline(1, '$')), 'Microsoft')"))
      else
        eq('$', eval([[matchstr(getline(1), '\$')]]))
      end
    end)

    feed([[<C-\><C-N>]])
    feed([[:<Tab>]]) -- Invoke wildmenu.
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Black, background = Screen.colors.Yellow },
      [101] = {
        bold = true,
        foreground = Screen.colors.White,
        background = Screen.colors.DarkGreen,
      },
    }
    -- Check only the last 2 lines, because the shell output is
    -- system-dependent.
    screen:expect { any = '{100:!}{101:  #  &  <  =  >  @  >   }|\n:!^' }
    -- Because this test verifies a _lack_ of activity, we must wait the full timeout.
    -- So make it reasonable.
    screen:expect_unchanged(false, 1000)
  end)

  it('wildmode=list,full and messages interaction #10092', function()
    -- Need more than 5 rows, else tabline is covered and will be redrawn.
    screen:try_resize(25, 7)

    command('set wildmenu wildmode=list,full')
    command('set showtabline=2')
    feed(':set wildm<tab>')
    screen:expect([[
      {5: [No Name] }{2:              }|
                               |
      {1:~                        }|
      {3:                         }|
      :set wildm               |
      wildmenu  wildmode       |
      :set wildm^               |
    ]])
    feed('<tab>') -- trigger wildmode full
    screen:expect([[
      {5: [No Name] }{2:              }|
                               |
      {3:                         }|
      :set wildm               |
      wildmenu  wildmode       |
      {100:wildmenu}{3:  wildmode       }|
      :set wildmenu^            |
    ]])
    feed('<Esc>')
    screen:expect([[
      {5: [No Name] }{2:              }|
      ^                         |
      {1:~                        }|*4
                               |
    ]])
  end)

  it('wildmode=longest,list', function()
    -- Need more than 5 rows, else tabline is covered and will be redrawn.
    screen:try_resize(25, 7)

    command('set wildmenu wildmode=longest,list')

    -- give wildmode-longest something to expand to
    feed(':sign u<tab>')
    screen:expect([[
                               |
      {1:~                        }|*5
      :sign un^                 |
    ]])
    feed('<tab>') -- trigger wildmode list
    screen:expect([[
                               |
      {1:~                        }|*2
      {3:                         }|
      :sign un                 |
      undefine  unplace        |
      :sign un^                 |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^                         |
      {1:~                        }|*5
                               |
    ]])

    -- give wildmode-longest something it cannot expand, use list
    feed(':sign un<tab>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {3:                         }|
      :sign un                 |
      undefine  unplace        |
      :sign un^                 |
    ]])
    feed('<tab>')
    screen:expect_unchanged()
    feed('<Esc>')
    screen:expect([[
      ^                         |
      {1:~                        }|*5
                               |
    ]])
  end)

  it('wildmode=list,longest', function()
    -- Need more than 5 rows, else tabline is covered and will be redrawn.
    screen:try_resize(25, 7)

    command('set wildmenu wildmode=list,longest')
    feed(':sign u<tab>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {3:                         }|
      :sign u                  |
      undefine  unplace        |
      :sign u^                  |
    ]])
    feed('<tab>') -- trigger wildmode longest
    screen:expect([[
                               |
      {1:~                        }|*2
      {3:                         }|
      :sign u                  |
      undefine  unplace        |
      :sign un^                 |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^                         |
      {1:~                        }|*5
                               |
    ]])
  end)

  it('multiple <C-D> renders correctly', function()
    screen:try_resize(25, 7)

    command('set laststatus=2')
    feed(':set wildm')
    feed('<c-d>')
    screen:expect([[
                               |
      {1:~                        }|*2
      {3:                         }|
      :set wildm               |
      wildmenu  wildmode       |
      :set wildm^               |
    ]])
    feed('<c-d>')
    screen:expect([[
                               |
      {3:                         }|
      :set wildm               |
      wildmenu  wildmode       |
      :set wildm               |
      wildmenu  wildmode       |
      :set wildm^               |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^                         |
      {1:~                        }|*4
      {3:[No Name]                }|
                               |
    ]])
  end)

  it('works with c_CTRL_Z standard mapping', function()
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Yellow1, foreground = Screen.colors.Black },
    }

    -- Wildcharm? where we are going we aint't no need no wildcharm.
    eq(0, api.nvim_get_option_value('wildcharm', {}))
    -- Don't mess the defaults yet (neovim is about backwards compatibility)
    eq(9, api.nvim_get_option_value('wildchar', {}))
    -- Lol what is cnoremap? Some say it can define mappings.
    command 'set wildchar=0'
    eq(0, api.nvim_get_option_value('wildchar', {}))

    command 'cnoremap <f2> <c-z>'
    feed(':syntax <f2>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      {100:case}{3:  clear  cluster  >  }|
      :syntax case^             |
    ]],
    }
    feed '<esc>'

    command 'set wildmode=longest:full,full'
    -- this will get cleaner once we have native lua expr mappings:
    command [[cnoremap <expr> <tab> luaeval("not rawset(_G, 'coin', not coin).coin") ? "<c-z>" : "c"]]

    feed ':syntax <tab>'
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*3
      :syntax c^                |
    ]],
    }

    feed '<tab>'
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      {3:case  clear  cluster  >  }|
      :syntax c^                |
    ]],
    }

    feed '<tab>'
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*3
      :syntax cc^               |
    ]],
    }
  end)
end)

describe('command line completion', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(40, 5)
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Yellow1, foreground = Screen.colors.Black },
    }
  end)
  after_each(function()
    os.remove('Xtest-functional-viml-compl-dir')
  end)

  it('lists directories with empty PATH', function()
    local tmp = fn.tempname()
    command('e ' .. tmp)
    command('cd %:h')
    command("call mkdir('Xtest-functional-viml-compl-dir')")
    command('let $PATH=""')
    feed(':!<tab><bs>')
    screen:expect([[
                                              |
      {1:~                                       }|*3
      :!Xtest-functional-viml-compl-dir^       |
    ]])
  end)

  it('completes env var names #9681', function()
    command('let $XTEST_1 = "foo" | let $XTEST_2 = "bar"')
    command('set wildmenu wildmode=full')
    feed(':!echo $XTEST_<tab>')
    screen:expect([[
                                              |
      {1:~                                       }|*2
      {100:XTEST_1}{3:  XTEST_2                        }|
      :!echo $XTEST_1^                         |
    ]])
  end)

  it('completes (multibyte) env var names #9655', function()
    clear({ env = {
      ['XTEST_1AaあB'] = 'foo',
      ['XTEST_2'] = 'bar',
    } })
    screen:attach()
    command('set wildmenu wildmode=full')
    feed(':!echo $XTEST_<tab>')
    screen:expect([[
                                              |
      {1:~                                       }|*2
      {100:XTEST_1AaあB}{3:  XTEST_2                   }|
      :!echo $XTEST_1AaあB^                    |
    ]])
  end)

  it('does not leak memory with <S-Tab> with wildmenu and only one match #19874', function()
    api.nvim_set_option_value('wildmenu', true, {})
    api.nvim_set_option_value('wildmode', 'full', {})
    api.nvim_set_option_value('wildoptions', 'pum', {})

    feed(':sign unpla<S-Tab>')
    screen:expect([[
                                              |
      {1:~                                       }|*3
      :sign unplace^                           |
    ]])

    feed('<Space>buff<Tab>')
    screen:expect([[
                                              |
      {1:~                                       }|*3
      :sign unplace buffer=^                   |
    ]])
  end)

  it('does not show matches with <S-Tab> without wildmenu with wildmode=full', function()
    api.nvim_set_option_value('wildmenu', false, {})
    api.nvim_set_option_value('wildmode', 'full', {})

    feed(':sign <S-Tab>')
    screen:expect([[
                                              |
      {1:~                                       }|*3
      :sign unplace^                           |
    ]])
  end)

  it('shows matches with <S-Tab> without wildmenu with wildmode=list', function()
    api.nvim_set_option_value('wildmenu', false, {})
    api.nvim_set_option_value('wildmode', 'list', {})

    feed(':sign <S-Tab>')
    screen:expect([[
      {3:                                        }|
      :sign define                            |
      define    list      undefine            |
      jump      place     unplace             |
      :sign unplace^                           |
    ]])
  end)
end)

describe('ui/ext_wildmenu', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5, { rgb = true, ext_wildmenu = true })
  end)

  it('works with :sign <tab>', function()
    local expected = {
      'define',
      'jump',
      'list',
      'place',
      'undefine',
      'unplace',
    }

    command('set wildmode=full')
    command('set wildmenu')
    feed(':sign <tab>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*3
      :sign define^             |
    ]],
      wildmenu_items = expected,
      wildmenu_pos = 0,
    }

    feed('<tab>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*3
      :sign jump^               |
    ]],
      wildmenu_items = expected,
      wildmenu_pos = 1,
    }

    feed('<left><left>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*3
      :sign ^                   |
    ]],
      wildmenu_items = expected,
      wildmenu_pos = -1,
    }

    feed('<right>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*3
      :sign define^             |
    ]],
      wildmenu_items = expected,
      wildmenu_pos = 0,
    }

    feed('a')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*3
      :sign definea^            |
    ]],
    }
  end)
end)
