local global_helpers = require('test.helpers')
local shallowcopy = global_helpers.shallowcopy
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, command = helpers.clear, helpers.feed, helpers.command
local iswin = helpers.iswin
local funcs = helpers.funcs
local eq = helpers.eq
local eval = helpers.eval
local retry = helpers.retry

describe("'wildmenu'", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
  end)
  after_each(function()
    screen:detach()
  end)

  -- expect the screen stayed unchanged some time after first seen success
  local function expect_stay_unchanged(args)
    screen:expect(args)
    args = shallowcopy(args)
    args.unchanged = true
    screen:expect(args)
  end

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
    if iswin() then
      feed([[:terminal for /L \%I in (1,1,5000) do @(echo foo & echo foo & echo foo)<cr>]])
    else
      feed([[:terminal for i in $(seq 1 5000); do printf 'foo\nfoo\nfoo\n'; sleep 0.1; done<cr>]])
    end

    feed([[<C-\><C-N>gg]])
    feed([[:sign <Tab>]])   -- Invoke wildmenu.
    expect_stay_unchanged{grid=[[
      foo                      |
      foo                      |
      foo                      |
      define  jump  list  >    |
      :sign define^             |
    ]]}

    -- cmdline CTRL-D display should also be preserved.
    feed([[<C-\><C-N>]])
    feed([[:sign <C-D>]])   -- Invoke cmdline CTRL-D.
    expect_stay_unchanged{grid=[[
      :sign                    |
      define    place          |
      jump      undefine       |
      list      unplace        |
      :sign ^                   |
    ]]}

    -- Exiting cmdline should show the buffer.
    feed([[<C-\><C-N>]])
    screen:expect([[
      ^foo                      |
      foo                      |
      foo                      |
      foo                      |
                               |
    ]])
  end)

  it('ignores :redrawstatus called from a timer #7108', function()
    command('set wildmenu wildmode=full')
    command([[call timer_start(10, {->execute('redrawstatus')}, {'repeat':-1})]])
    feed([[<C-\><C-N>]])
    feed([[:sign <Tab>]])   -- Invoke wildmenu.
    expect_stay_unchanged{grid=[[
                               |
      ~                        |
      ~                        |
      define  jump  list  >    |
      :sign define^             |
    ]]}
  end)

  it('with laststatus=0, :vsplit, :term #2255', function()
    -- Because this test verifies a _lack_ of activity after screen:sleep(), we
    -- must wait the full timeout. So make it reasonable.
    screen.timeout = 1000

    if not iswin() then
      command('set shell=sh')  -- Need a predictable "$" prompt.
    end
    command('set laststatus=0')
    command('vsplit')
    command('term')

    -- Check for a shell prompt to verify that the terminal loaded.
    retry(nil, nil, function()
      if iswin() then
        eq('Microsoft', eval("matchstr(join(getline(1, '$')), 'Microsoft')"))
      else
        eq('$', eval([[matchstr(getline(1), '\$')]]))
      end
    end)

    feed([[<C-\><C-N>]])
    feed([[:<Tab>]])      -- Invoke wildmenu.
    -- Check only the last 2 lines, because the shell output is
    -- system-dependent.
    expect_stay_unchanged{any='!  #  &  <  =  >  @  >   |\n:!^'}
  end)
end)

describe('command line completion', function()
  local screen
  before_each(function()
    screen = Screen.new(40, 5)
    screen:set_default_attr_ids({
     [1] = {bold = true, foreground = Screen.colors.Blue1},
     [2] = {foreground = Screen.colors.Grey0, background = Screen.colors.Yellow},
     [3] = {bold = true, reverse = true},
    })
  end)
  after_each(function()
    os.remove('Xtest-functional-viml-compl-dir')
  end)

  it('lists directories with empty PATH', function()
    clear()
    screen:attach()
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
    clear()
    screen:attach()
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
end)

describe('ui/ext_wildmenu', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_wildmenu=true})
  end)

  after_each(function()
    screen:detach()
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
