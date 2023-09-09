local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, command = helpers.clear, helpers.feed, helpers.command
local funcs = helpers.funcs
local meths = helpers.meths
local eq = helpers.eq
local eval = helpers.eval
local retry = helpers.retry
local testprg = helpers.testprg
local is_os = helpers.is_os

describe("'wildmenu'", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
  end)

  it('C-E to cancel wildmenu completion restore original input', function()
    feed(':sign <tab>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      define  jump  list  >    |
      :sign define^             |
    ]])
    feed('<C-E>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign ^                   |
    ]])
  end)

  it('C-Y to apply selection and end wildmenu completion', function()
    feed(':sign <tab>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      define  jump  list  >    |
      :sign define^             |
    ]])
    feed('<tab><C-Y>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign jump^               |
    ]])
  end)

  it(':sign <tab> shows wildmenu completions', function()
    command('set wildmenu wildmode=full')
    feed(':sign <tab>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      define  jump  list  >    |
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
      ~                        |
      ~                        |
      define  jump  list  >    |
      :sign define^             |
    ]])
    feed('<space>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      [No Name]                |
      :sign define ^            |
    ]])
  end)

  it('does not crash after cycling back to original text', function()
    command('set wildmode=full')
    feed(':j<Tab><Tab><Tab>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      join  jumps              |
      :j^                       |
    ]])
    -- This would cause nvim to crash before #6650
    feed('<BS><Tab>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      !  #  &  <  =  >  @  >   |
      :!^                       |
    ]])
  end)

  it('is preserved during :terminal activity', function()
    command('set wildmenu wildmode=full')
    command('set scrollback=4')
    feed((':terminal "%s" REP 5000 !terminal_output!<cr>'):format(testprg('shell-test')))
    feed('G')  -- Follow :terminal output.
    feed([[:sign <Tab>]])   -- Invoke wildmenu.
    -- NB: in earlier versions terminal output was redrawn during cmdline mode.
    -- For now just assert that the screen remains unchanged.
    screen:expect{any='define  jump  list  >    |\n:sign define^             |'}
    screen:expect_unchanged()

    -- cmdline CTRL-D display should also be preserved.
    feed([[<C-U>]])
    feed([[sign <C-D>]])   -- Invoke cmdline CTRL-D.
    screen:expect{grid=[[
      :sign                    |
      define    place          |
      jump      undefine       |
      list      unplace        |
      :sign ^                   |
    ]]}
    screen:expect_unchanged()

    -- Exiting cmdline should show the buffer.
    feed([[<C-\><C-N>]])
    screen:expect{any=[[!terminal_output!]]}
  end)

  it('ignores :redrawstatus called from a timer #7108', function()
    command('set wildmenu wildmode=full')
    command([[call timer_start(10, {->execute('redrawstatus')}, {'repeat':-1})]])
    feed([[<C-\><C-N>]])
    feed([[:sign <Tab>]])   -- Invoke wildmenu.
    screen:expect{grid=[[
                               |
      ~                        |
      ~                        |
      define  jump  list  >    |
      :sign define^             |
    ]]}
    screen:expect_unchanged()
  end)

  it('with laststatus=0, :vsplit, :term #2255', function()
    -- Because this test verifies a _lack_ of activity after screen:sleep(), we
    -- must wait the full timeout. So make it reasonable.
    screen.timeout = 1000

    if not is_os('win') then
      command('set shell=sh')  -- Need a predictable "$" prompt.
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
    feed([[:<Tab>]])      -- Invoke wildmenu.
    -- Check only the last 2 lines, because the shell output is
    -- system-dependent.
    screen:expect{any='!  #  &  <  =  >  @  >   |\n:!^'}
    screen:expect_unchanged()
  end)

  it('wildmode=list,full and messages interaction #10092', function()
    -- Need more than 5 rows, else tabline is covered and will be redrawn.
    screen:try_resize(25, 7)

    command('set wildmenu wildmode=list,full')
    command('set showtabline=2')
    feed(':set wildm<tab>')
    screen:expect([[
       [No Name]               |
                               |
      ~                        |
                               |
      :set wildm               |
      wildmenu  wildmode       |
      :set wildm^               |
    ]])
    feed('<tab>') -- trigger wildmode full
    screen:expect([[
       [No Name]               |
                               |
                               |
      :set wildm               |
      wildmenu  wildmode       |
      wildmenu  wildmode       |
      :set wildmenu^            |
    ]])
    feed('<Esc>')
    screen:expect([[
       [No Name]               |
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
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
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      :sign un^                 |
    ]])
    feed('<tab>') -- trigger wildmode list
    screen:expect([[
                               |
      ~                        |
      ~                        |
                               |
      :sign un                 |
      undefine  unplace        |
      :sign un^                 |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]])

    -- give wildmode-longest something it cannot expand, use list
    feed(':sign un<tab>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
                               |
      :sign un                 |
      undefine  unplace        |
      :sign un^                 |
    ]])
    feed('<tab>')
    screen:expect_unchanged()
    feed('<Esc>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
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
      ~                        |
      ~                        |
                               |
      :sign u                  |
      undefine  unplace        |
      :sign u^                  |
    ]])
    feed('<tab>') -- trigger wildmode longest
    screen:expect([[
                               |
      ~                        |
      ~                        |
                               |
      :sign u                  |
      undefine  unplace        |
      :sign un^                 |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
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
      ~                        |
      ~                        |
                               |
      :set wildm               |
      wildmenu  wildmode       |
      :set wildm^               |
    ]])
    feed('<c-d>')
    screen:expect([[
                               |
                               |
      :set wildm               |
      wildmenu  wildmode       |
      :set wildm               |
      wildmenu  wildmode       |
      :set wildm^               |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      [No Name]                |
                               |
    ]])
  end)

  it('works with c_CTRL_Z standard mapping', function()
    screen:set_default_attr_ids {
      [1] = {bold = true, foreground = Screen.colors.Blue1};
      [2] = {foreground = Screen.colors.Grey0, background = Screen.colors.Yellow};
      [3] = {bold = true, reverse = true};
    }

    -- Wildcharm? where we are going we aint't no need no wildcharm.
    eq(0, meths.get_option_value('wildcharm', {}))
    -- Don't mess the defaults yet (neovim is about backwards compatibility)
    eq(9, meths.get_option_value('wildchar', {}))
    -- Lol what is cnoremap? Some say it can define mappings.
    command 'set wildchar=0'
    eq(0, meths.get_option_value('wildchar', {}))

    command 'cnoremap <f2> <c-z>'
    feed(':syntax <f2>')
    screen:expect{grid=[[
                               |
      {1:~                        }|
      {1:~                        }|
      {2:case}{3:  clear  cluster  >  }|
      :syntax case^             |
    ]]}
    feed '<esc>'

    command 'set wildmode=longest:full,full'
    -- this will get cleaner once we have native lua expr mappings:
    command [[cnoremap <expr> <tab> luaeval("not rawset(_G, 'coin', not coin).coin") ? "<c-z>" : "c"]]

    feed ':syntax <tab>'
    screen:expect{grid=[[
                               |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      :syntax c^                |
    ]]}

    feed '<tab>'
    screen:expect{grid=[[
                               |
      {1:~                        }|
      {1:~                        }|
      {3:case  clear  cluster  >  }|
      :syntax c^                |
    ]]}

    feed '<tab>'
    screen:expect{grid=[[
                               |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      :syntax cc^               |
    ]]}
  end)
end)

describe('command line completion', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(40, 5)
    screen:set_default_attr_ids({
     [1] = {bold = true, foreground = Screen.colors.Blue1},
     [2] = {foreground = Screen.colors.Grey0, background = Screen.colors.Yellow},
     [3] = {bold = true, reverse = true},
    })
    screen:attach()
  end)
  after_each(function()
    os.remove('Xtest-functional-viml-compl-dir')
  end)

  it('lists directories with empty PATH', function()
    local tmp = funcs.tempname()
    command('e '.. tmp)
    command('cd %:h')
    command("call mkdir('Xtest-functional-viml-compl-dir')")
    command('let $PATH=""')
    feed(':!<tab><bs>')
    screen:expect([[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      :!Xtest-functional-viml-compl-dir^       |
    ]])
  end)

  it('completes env var names #9681', function()
    command('let $XTEST_1 = "foo" | let $XTEST_2 = "bar"')
    command('set wildmenu wildmode=full')
    feed(':!echo $XTEST_<tab>')
    screen:expect([[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {2:XTEST_1}{3:  XTEST_2                        }|
      :!echo $XTEST_1^                         |
    ]])
  end)

  it('completes (multibyte) env var names #9655', function()
    clear({env={
      ['XTEST_1AaあB']='foo',
      ['XTEST_2']='bar',
    }})
    screen:attach()
    command('set wildmenu wildmode=full')
    feed(':!echo $XTEST_<tab>')
    screen:expect([[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {2:XTEST_1AaあB}{3:  XTEST_2                   }|
      :!echo $XTEST_1AaあB^                    |
    ]])
  end)

  it('does not leak memory with <S-Tab> with wildmenu and only one match #19874', function()
    meths.set_option_value('wildmenu', true, {})
    meths.set_option_value('wildmode', 'full', {})
    meths.set_option_value('wildoptions', 'pum', {})

    feed(':sign unpla<S-Tab>')
    screen:expect([[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      :sign unplace^                           |
    ]])

    feed('<Space>buff<Tab>')
    screen:expect([[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      :sign unplace buffer=^                   |
    ]])
  end)

  it('does not show matches with <S-Tab> without wildmenu with wildmode=full', function()
    meths.set_option_value('wildmenu', false, {})
    meths.set_option_value('wildmode', 'full', {})

    feed(':sign <S-Tab>')
    screen:expect([[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      :sign unplace^                           |
    ]])
  end)

  it('shows matches with <S-Tab> without wildmenu with wildmode=list', function()
    meths.set_option_value('wildmenu', false, {})
    meths.set_option_value('wildmode', 'list', {})

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
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_wildmenu=true})
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
    screen:expect{grid=[[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign define^             |
    ]], wildmenu_items=expected, wildmenu_pos=0}

    feed('<tab>')
    screen:expect{grid=[[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign jump^               |
    ]], wildmenu_items=expected, wildmenu_pos=1}

    feed('<left><left>')
    screen:expect{grid=[[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign ^                   |
    ]], wildmenu_items=expected, wildmenu_pos=-1}

    feed('<right>')
    screen:expect{grid=[[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign define^             |
    ]], wildmenu_items=expected, wildmenu_pos=0}

    feed('a')
    screen:expect{grid=[[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign definea^            |
    ]]}
  end)
end)
