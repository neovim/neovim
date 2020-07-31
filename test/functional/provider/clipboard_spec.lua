-- Test clipboard provider support

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local feed_command, expect, eq, eval, source = helpers.feed_command, helpers.expect, helpers.eq, helpers.eval, helpers.source
local command = helpers.command
local meths = helpers.meths

local function basic_register_test(noblock)
  insert("some words")

  feed('^dwP')
  expect('some words')

  feed('veyP')
  expect('some words words')

  feed('^dwywe"-p')
  expect('wordssome  words')

  feed('p')
  expect('wordssome words  words')

  feed('yyp')
  expect([[
    wordssome words  words
    wordssome words  words]])
  feed('d-')

  insert([[
    some text, and some more
    random text stuff]])
  feed('ggtav+2ed$p')
  expect([[
    some text, stuff and some more
    random text]])

  -- deleting line or word uses "1/"- and doesn't clobber "0
  -- and deleting word to unnamed doesn't clobber "1
  feed('ggyyjdddw"0p"1p"-P')
  expect([[
    text, stuff and some more
    some text, stuff and some more
    some random text]])

  -- delete line doesn't clobber "-
  feed('dd"-P')
  expect([[
    text, stuff and some more
    some some text, stuff and some more]])

  -- deleting a word to named ("a) updates "1 (and not "-)
  feed('gg"adwj"1P^"-P')
  expect([[
    , stuff and some more
    some textsome some text, stuff and some more]])

  -- deleting a line does update ""
  feed('ggdd""P')
  expect([[
    , stuff and some more
    some textsome some text, stuff and some more]])

  feed('ggw<c-v>jwyggP')
  if noblock then
    expect([[
      stuf
      me t
      , stuff and some more
      some textsome some text, stuff and some more]])
  else
    expect([[
      stuf, stuff and some more
      me tsome textsome some text, stuff and some more]])
  end

  -- pasting in visual does unnamed delete of visual selection
  feed('ggdG')
  insert("one and two and three")
  feed('"ayiwbbviw"ap^viwp$viw"-p')
  expect("two and three and one")
end

describe('clipboard', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(72, 4)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [2] = {bold = true, foreground = Screen.colors.SeaGreen4},
    })
    screen:attach()
    command("set display-=msgsep")
  end)

  it('unnamed register works without provider', function()
    eq('"', eval('v:register'))
    basic_register_test()
  end)

  it('`:redir @+>` with invalid g:clipboard shows exactly one error #7184',
  function()
    command("let g:clipboard = 'bogus'")
    feed_command('redir @+> | :silent echo system("cat CONTRIBUTING.md") | redir END')
    screen:expect([[
      ^                                                                        |
      {0:~                                                                       }|
      {0:~                                                                       }|
      clipboard: No provider. Try ":checkhealth" or ":h clipboard".           |
    ]])
  end)

  it('`:redir @+>|bogus_cmd|redir END` + invalid g:clipboard must not recurse #7184',
  function()
    command("let g:clipboard = 'bogus'")
    feed_command('redir @+> | bogus_cmd | redir END')
    screen:expect{grid=[[
      {0:~                                                                       }|
      clipboard: No provider. Try ":checkhealth" or ":h clipboard".           |
      {1:E492: Not an editor command: bogus_cmd | redir END}                      |
      {2:Press ENTER or type command to continue}^                                 |
    ]]}
  end)

  it('invalid g:clipboard shows hint if :redir is not active', function()
    command("let g:clipboard = 'bogus'")
    eq('', eval('provider#clipboard#Executable()'))
    eq('clipboard: invalid g:clipboard', eval('provider#clipboard#Error()'))

    command("let g:clipboard = 'bogus'")
    -- Explicit clipboard attempt, should show a hint message.
    feed_command('let @+="foo"')
    screen:expect([[
      ^                                                                        |
      {0:~                                                                       }|
      {0:~                                                                       }|
      clipboard: No provider. Try ":checkhealth" or ":h clipboard".           |
    ]])
  end)

  it('valid g:clipboard', function()
    -- provider#clipboard#Executable() only checks the structure.
    meths.set_var('clipboard', {
      ['name'] = 'clippy!',
      ['copy'] = { ['+'] = 'any command', ['*'] = 'some other' },
      ['paste'] = { ['+'] = 'any command', ['*'] = 'some other' },
    })
    eq('clippy!', eval('provider#clipboard#Executable()'))
    eq('', eval('provider#clipboard#Error()'))
  end)

  it('g:clipboard using VimL functions', function()
    -- Implements a fake clipboard provider. cache_enabled is meaningless here.
    source([[let g:clipboard = {
            \  'name': 'custom',
            \  'copy': {
            \     '+': {lines, regtype -> extend(g:, {'dummy_clipboard_plus': [lines, regtype]}) },
            \     '*': {lines, regtype -> extend(g:, {'dummy_clipboard_star': [lines, regtype]}) },
            \   },
            \  'paste': {
            \     '+': {-> get(g:, 'dummy_clipboard_plus', [])},
            \     '*': {-> get(g:, 'dummy_clipboard_star', [])},
            \  },
            \  'cache_enabled': 1,
            \}]])

    eq('', eval('provider#clipboard#Error()'))
    eq('custom', eval('provider#clipboard#Executable()'))

    eq('', eval("getreg('*')"))
    eq('', eval("getreg('+')"))

    command('call setreg("*", "star")')
    command('call setreg("+", "plus")')
    eq('star', eval("getreg('*')"))
    eq('plus', eval("getreg('+')"))

    command('call setreg("*", "star", "v")')
    eq({{'star'}, 'v'}, eval("g:dummy_clipboard_star"))
    command('call setreg("*", "star", "V")')
    eq({{'star', ''}, 'V'}, eval("g:dummy_clipboard_star"))
    command('call setreg("*", "star", "b")')
    eq({{'star', ''}, 'b'}, eval("g:dummy_clipboard_star"))
  end)

  describe('g:clipboard[paste] VimL function', function()
    it('can return empty list for empty clipboard', function()
      source([[let g:dummy_clipboard = []
              let g:clipboard = {
              \  'name': 'custom',
              \  'copy': { '*': {lines, regtype ->  0} },
              \  'paste': { '*': {-> g:dummy_clipboard} },
              \}]])
      eq('', eval('provider#clipboard#Error()'))
      eq('custom', eval('provider#clipboard#Executable()'))
      eq('', eval("getreg('*')"))
    end)

    it('can return a list with a single string', function()
      source([=[let g:dummy_clipboard = ['hello']
              let g:clipboard = {
              \  'name': 'custom',
              \  'copy': { '*': {lines, regtype ->  0} },
              \  'paste': { '*': {-> g:dummy_clipboard} },
              \}]=])
      eq('', eval('provider#clipboard#Error()'))
      eq('custom', eval('provider#clipboard#Executable()'))

      eq('hello', eval("getreg('*')"))
      source([[let g:dummy_clipboard = [''] ]])
      eq('', eval("getreg('*')"))
    end)

    it('can return a list of lines if a regtype is provided', function()
      source([=[let g:dummy_clipboard = [['hello'], 'v']
              let g:clipboard = {
              \  'name': 'custom',
              \  'copy': { '*': {lines, regtype ->  0} },
              \  'paste': { '*': {-> g:dummy_clipboard} },
              \}]=])
      eq('', eval('provider#clipboard#Error()'))
      eq('custom', eval('provider#clipboard#Executable()'))
      eq('hello', eval("getreg('*')"))
    end)

    it('can return a list of lines instead of [lines, regtype]', function()
      source([=[let g:dummy_clipboard = ['hello', 'v']
              let g:clipboard = {
              \  'name': 'custom',
              \  'copy': { '*': {lines, regtype ->  0} },
              \  'paste': { '*': {-> g:dummy_clipboard} },
              \}]=])
      eq('', eval('provider#clipboard#Error()'))
      eq('custom', eval('provider#clipboard#Executable()'))
      eq('hello\nv', eval("getreg('*')"))
    end)
  end)
end)

describe('clipboard (with fake clipboard.vim)', function()
  local function reset(...)
    clear('--cmd', 'let &rtp = "test/functional/fixtures,".&rtp', ...)
  end

  before_each(function()
    reset()
    feed_command('call getreg("*")') -- force load of provider
  end)

  it('`:redir @+>` invokes clipboard once-per-message', function()
    eq(0, eval("g:clip_called_set"))
    feed_command('redir @+> | :silent echo system("cat CONTRIBUTING.md") | redir END')
    -- Assuming CONTRIBUTING.md has >100 lines.
    assert(eval("g:clip_called_set") > 100)
  end)

  it('`:redir @">` does NOT invoke clipboard', function()
    -- :redir to a non-clipboard register, with `:set clipboard=unnamed` does
    -- NOT propagate to the clipboard. This is consistent with Vim.
    command("set clipboard=unnamedplus")
    eq(0, eval("g:clip_called_set"))
    feed_command('redir @"> | :silent echo system("cat CONTRIBUTING.md") | redir END')
    eq(0, eval("g:clip_called_set"))
  end)

  it('`:redir @+>|bogus_cmd|redir END` must not recurse #7184',
  function()
    local screen = Screen.new(72, 4)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
    })
    feed_command('redir @+> | bogus_cmd | redir END')
    screen:expect([[
      ^                                                                        |
      {0:~                                                                       }|
      {0:~                                                                       }|
      {1:E492: Not an editor command: bogus_cmd | redir END}                      |
    ]])
  end)

  it('has independent "* and unnamed registers by default', function()
    insert("some words")
    feed('^"*dwdw"*P')
    expect('some ')
    eq({{'some '}, 'v'}, eval("g:test_clip['*']"))
    eq('words', eval("getreg('\"', 1)"))
  end)

  it('supports separate "* and "+ when the provider supports it', function()
    insert([[
      text:
      first line
      secound line
      third line]])

    feed('G"+dd"*dddd"+p"*pp')
    expect([[
      text:
      third line
      secound line
      first line]])
    -- linewise selection should be encoded as an extra newline
    eq({{'third line', ''}, 'V'}, eval("g:test_clip['+']"))
    eq({{'secound line', ''}, 'V'}, eval("g:test_clip['*']"))
  end)

  it('handles null bytes when pasting and in getreg', function()
    insert("some\022000text\n\022000very binary\022000")
    feed('"*y-+"*p')
    eq({{'some\ntext', '\nvery binary\n',''}, 'V'}, eval("g:test_clip['*']"))
    expect("some\00text\n\00very binary\00\nsome\00text\n\00very binary\00")

    -- test getreg/getregtype
    eq('some\ntext\n\nvery binary\n\n', eval("getreg('*', 1)"))
    eq("V", eval("getregtype('*')"))

    -- getreg supports three arguments
    eq('some\ntext\n\nvery binary\n\n', eval("getreg('*', 1, 0)"))
    eq({'some\ntext', '\nvery binary\n'}, eval("getreg('*', 1, 1)"))
  end)

  it('autodetects regtype', function()
    feed_command("let g:test_clip['*'] = ['linewise stuff','']")
    feed_command("let g:test_clip['+'] = ['charwise','stuff']")
    eq("V", eval("getregtype('*')"))
    eq("v", eval("getregtype('+')"))
    insert("just some text")
    feed('"*p"+p')
    expect([[
      just some text
      lcharwise
      stuffinewise stuff]])
  end)

  it('support blockwise operations', function()
    insert([[
      much
      text]])
    feed_command("let g:test_clip['*'] = [['very','block'],'b']")
    feed('gg"*P')
    expect([[
      very much
      blocktext]])
    eq("\0225", eval("getregtype('*')"))
    feed('gg4l<c-v>j4l"+ygg"+P')
    expect([[
       muchvery much
      ktextblocktext]])
    eq({{' much', 'ktext', ''}, 'b'}, eval("g:test_clip['+']"))
  end)

  it('supports setreg()', function()
    feed_command('call setreg("*", "setted\\ntext", "c")')
    feed_command('call setreg("+", "explicitly\\nlines", "l")')
    feed('"+P"*p')
    expect([[
        esetted
        textxplicitly
        lines
        ]])
    feed_command('call setreg("+", "blocky\\nindeed", "b")')
    feed('"+p')
    expect([[
        esblockyetted
        teindeedxtxplicitly
        lines
        ]])
  end)

  it('supports :let @+ (issue #1427)', function()
    feed_command("let @+ = 'some'")
    feed_command("let @* = ' other stuff'")
    eq({{'some'}, 'v'}, eval("g:test_clip['+']"))
    eq({{' other stuff'}, 'v'}, eval("g:test_clip['*']"))
    feed('"+p"*p')
    expect('some other stuff')
    feed_command("let @+ .= ' more'")
    feed('dd"+p')
    expect('some more')
  end)

  it('pastes unnamed register if the provider fails', function()
    insert('the text')
    feed('yy')
    feed_command("let g:cliperror = 1")
    feed('"*p')
    expect([[
      the text
      the text]])
  end)


  describe('with clipboard=unnamed', function()
    -- the basic behavior of unnamed register should be the same
    -- even when handled by clipboard provider
    before_each(function()
      feed_command('set clipboard=unnamed')
    end)

    it('works', function()
      basic_register_test()
    end)

    it('works with pure text clipboard', function()
      feed_command("let g:cliplossy = 1")
      -- expect failure for block mode
      basic_register_test(true)
    end)

    it('links the "* and unnamed registers', function()
      -- with cb=unnamed, "* and unnamed will be the same register
      insert("some words")
      feed('^"*dwdw"*P')
      expect('words')
      eq({{'words'}, 'v'}, eval("g:test_clip['*']"))

      -- "+ shouldn't have changed
      eq({''}, eval("g:test_clip['+']"))

      feed_command("let g:test_clip['*'] = ['linewise stuff','']")
      feed('p')
      expect([[
        words
        linewise stuff]])
    end)

    it('does not clobber "0 when pasting', function()
      insert('a line')
      feed('yy')
      feed_command("let g:test_clip['*'] = ['b line','']")
      feed('"0pp"0p')
      expect([[
        a line
        a line
        b line
        a line]])
    end)

    it('supports v:register and getreg() without parameters', function()
      eq('*', eval('v:register'))
      feed_command("let g:test_clip['*'] = [['some block',''], 'b']")
      eq('some block', eval('getreg()'))
      eq('\02210', eval('getregtype()'))
    end)

    it('yanks visual selection when pasting', function()
      insert("indeed visual")
      feed_command("let g:test_clip['*'] = [['clipboard'], 'c']")
      feed("viwp")
      eq({{'visual'}, 'v'}, eval("g:test_clip['*']"))
      expect("indeed clipboard")

      -- explicit "* should do the same
      feed_command("let g:test_clip['*'] = [['star'], 'c']")
      feed('viw"*p')
      eq({{'clipboard'}, 'v'}, eval("g:test_clip['*']"))
      expect("indeed star")
    end)

    it('unamed operations work even if the provider fails', function()
      insert('the text')
      feed('yy')
      feed_command("let g:cliperror = 1")
      feed('p')
      expect([[
        the text
        the text]])
    end)

    it('is updated on global changes', function()
      insert([[
	text
	match
	match
	text
      ]])
      feed_command('g/match/d')
      eq('match\n', eval('getreg("*")'))
      feed('u')
      eval('setreg("*", "---")')
      feed_command('g/test/')
      feed('<esc>')
      eq('---', eval('getreg("*")'))
    end)

    it('works in the cmdline window', function()
      feed('q:itext<esc>yy')
      eq({{'text', ''}, 'V'}, eval("g:test_clip['*']"))
      command("let g:test_clip['*'] = [['star'], 'c']")
      feed('p')
      eq('textstar', meths.get_current_line())
    end)
  end)

  describe('clipboard=unnamedplus', function()
    before_each(function()
      feed_command('set clipboard=unnamedplus')
    end)

    it('links the "+ and unnamed registers', function()
      eq('+', eval('v:register'))
      insert("one two")
      feed('^"+dwdw"+P')
      expect('two')
      eq({{'two'}, 'v'}, eval("g:test_clip['+']"))

      -- "* shouldn't have changed
      eq({''}, eval("g:test_clip['*']"))

      feed_command("let g:test_clip['+'] = ['three']")
      feed('p')
      expect('twothree')
    end)

    it('and unnamed, yanks to both', function()
      feed_command('set clipboard=unnamedplus,unnamed')
      insert([[
        really unnamed
        text]])
      feed('ggdd"*p"+p')
      expect([[
        text
        really unnamed
        really unnamed]])
      eq({{'really unnamed', ''}, 'V'}, eval("g:test_clip['+']"))
      eq({{'really unnamed', ''}, 'V'}, eval("g:test_clip['*']"))

      -- unnamedplus takes predecence when pasting
      eq('+', eval('v:register'))
      feed_command("let g:test_clip['+'] = ['the plus','']")
      feed_command("let g:test_clip['*'] = ['the star','']")
      feed("p")
      expect([[
        text
        really unnamed
        really unnamed
        the plus]])
    end)

    it('is updated on global changes', function()
      insert([[
	text
	match
	match
	text
      ]])
      feed_command('g/match/d')
      eq('match\n', eval('getreg("+")'))
      feed('u')
      eval('setreg("+", "---")')
      feed_command('g/test/')
      feed('<esc>')
      eq('---', eval('getreg("+")'))
    end)
  end)

  it('sets v:register after startup', function()
    reset()
    eq('"', eval('v:register'))
    reset('--cmd', 'set clipboard=unnamed')
    eq('*', eval('v:register'))
  end)

  it('supports :put', function()
    insert("a line")
    feed_command("let g:test_clip['*'] = ['some text']")
    feed_command("let g:test_clip['+'] = ['more', 'text', '']")
    feed_command(":put *")
    expect([[
    a line
    some text]])
    feed_command(":put +")
    expect([[
    a line
    some text
    more
    text]])
  end)

  it('supports "+ and "* in registers', function()
    local screen = Screen.new(60, 10)
    screen:attach()
    feed_command("let g:test_clip['*'] = ['some', 'star data','']")
    feed_command("let g:test_clip['+'] = ['such', 'plus', 'stuff']")
    feed_command("registers")
    screen:expect([[
                                                                  |
      {0:~                                                           }|
      {0:~                                                           }|
      {4:                                                            }|
      :registers                                                  |
      {1:--- Registers ---}                                           |
      "*   some{2:^J}star data{2:^J}                                      |
      "+   such{2:^J}plus{2:^J}stuff                                      |
      ":   let g:test_clip['+'] = ['such', 'plus', 'stuff']       |
      {3:Press ENTER or type command to continue}^                     |
    ]], {
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {bold = true, foreground = Screen.colors.Fuchsia},
      [2] = {foreground = Screen.colors.Blue},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen},
      [4] = {bold = true, reverse = true}})
    feed('<cr>') -- clear out of Press ENTER screen
  end)

  it('can paste "* to the commandline', function()
    insert('s/s/t/')
    feed('gg"*y$:<c-r>*<cr>')
    expect('t/s/t/')
    feed_command("let g:test_clip['*'] = ['s/s/u']")
    feed(':<c-r>*<cr>')
    expect('t/u/t/')
  end)

  it('supports :redir @*>', function()
    feed_command("let g:test_clip['*'] = ['stuff']")
    feed_command('redir @*>')
    -- it is made empty
    eq({{''}, 'v'}, eval("g:test_clip['*']"))
    feed_command('let g:test = doesnotexist')
    feed('<cr>')
    eq({{
      '',
      '',
      'E121: Undefined variable: doesnotexist',
      'E15: Invalid expression: doesnotexist',
    }, 'v'}, eval("g:test_clip['*']"))
    feed_command(':echo "Howdy!"')
    eq({{
      '',
      '',
      'E121: Undefined variable: doesnotexist',
      'E15: Invalid expression: doesnotexist',
      '',
      'Howdy!',
    }, 'v'}, eval("g:test_clip['*']"))
  end)

  it('handles middleclick correctly', function()
    feed_command('set mouse=a')

    local screen = Screen.new(30, 5)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
    })
    screen:attach()
    insert([[
      the source
      a target]])
    feed('gg"*ywwyw')
    -- clicking depends on the exact visual layout, so expect it:
    screen:expect([[
      the ^source                    |
      a target                      |
      {0:~                             }|
      {0:~                             }|
                                    |
    ]])

    feed('<MiddleMouse><0,1>')
    expect([[
      the source
      the a target]])

    -- on error, fall back to unnamed register
    feed_command("let g:cliperror = 1")
    feed('<MiddleMouse><6,1>')
    expect([[
      the source
      the a sourcetarget]])
  end)

  it('setreg("*") with clipboard=unnamed #5646', function()
    source([=[
      function! Paste_without_yank(direction) range
        let [reg_save,regtype_save] = [getreg('*'), getregtype('*')]
        normal! gvp
        call setreg('*', reg_save, regtype_save)
      endfunction
      xnoremap p :call Paste_without_yank('p')<CR>
      set clipboard=unnamed
    ]=])
    insert('some words')
    feed('gg0yiw')
    feed('wviwp')
    expect('some some')
    eq('some', eval('getreg("*")'))
  end)
end)
