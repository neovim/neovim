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

  it(':sign <tab> shows wildmenu completions', function()
    command('set wildmode=full')
    command('set wildmenu')
    feed(':sign <tab>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      define  jump  list  >    |
      :sign define^             |
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
    -- Because this test verifies a _lack_ of activity after screen:sleep(), we
    -- must wait the full timeout. So make it reasonable.
    screen.timeout = 1000

    command('set wildmenu wildmode=full')
    command('set scrollback=4')
    if iswin() then
      if helpers.pending_win32(pending) then return end
      -- feed([[:terminal 1,2,3,4,5 | foreach-object -process {echo $_; sleep 0.1}]])
    else
      feed([[:terminal for i in $(seq 1 5000); do printf 'foo\nfoo\nfoo\n'; sleep 0.1; done<cr>]])
    end

    feed([[<C-\><C-N>gg]])
    feed([[:sign <Tab>]])   -- Invoke wildmenu.
    screen:sleep(50)        -- Allow some terminal output.
    screen:expect([[
      foo                      |
      foo                      |
      foo                      |
      define  jump  list  >    |
      :sign define^             |
    ]])

    -- cmdline CTRL-D display should also be preserved.
    feed([[<C-\><C-N>]])
    feed([[:sign <C-D>]])   -- Invoke cmdline CTRL-D.
    screen:sleep(50)        -- Allow some terminal output.
    screen:expect([[
      :sign                    |
      define    place          |
      jump      undefine       |
      list      unplace        |
      :sign ^                   |
    ]])

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
    -- Because this test verifies a _lack_ of activity after screen:sleep(), we
    -- must wait the full timeout. So make it reasonable.
    screen.timeout = 1000

    command('set wildmenu wildmode=full')
    command([[call timer_start(10, {->execute('redrawstatus')}, {'repeat':-1})]])
    feed([[<C-\><C-N>]])
    feed([[:sign <Tab>]])   -- Invoke wildmenu.
    screen:sleep(30)        -- Allow some timer activity.
    screen:expect([[
                               |
      ~                        |
      ~                        |
      define  jump  list  >    |
      :sign define^             |
    ]])
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
    screen:sleep(10)      -- Flush
    -- Check only the last 2 lines, because the shell output is
    -- system-dependent.
    screen:expect('!  #  &  <  =  >  @  >   \n:!^', nil, nil, nil, true)
  end)
end)

describe('command line completion', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 5)
    screen:attach()
    screen:set_default_attr_ids({[1]={bold=true, foreground=Screen.colors.Blue}})
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
end)

describe('ui/ext_wildmenu', function()
  local screen
  local items, selected = nil, nil

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_wildmenu=true})
    screen:set_on_event_handler(function(name, data)
      if name == "wildmenu_show" then
        items = data[1]
      elseif name == "wildmenu_select" then
        selected = data[1]
      elseif name == "wildmenu_hide" then
        items, selected = nil, nil
      end
    end)
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
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign define^             |
    ]], nil, nil, function()
      eq(expected, items)
      eq(0, selected)
    end)

    feed('<tab>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign jump^               |
    ]], nil, nil, function()
      eq(expected, items)
      eq(1, selected)
    end)

    feed('<left><left>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign ^                   |
    ]], nil, nil, function()
      eq(expected, items)
      eq(-1, selected)
    end)

    feed('<right>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign define^             |
    ]], nil, nil, function()
      eq(expected, items)
      eq(0, selected)
    end)

    feed('a')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      :sign definea^            |
    ]], nil, nil, function()
      eq(nil, items)
      eq(nil, selected)
    end)
  end)
end)
