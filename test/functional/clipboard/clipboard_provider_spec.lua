-- Test clipboard provider support

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local feed_command, expect, eq, eval = helpers.feed_command, helpers.expect, helpers.eq, helpers.eval
local command = helpers.command

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
  before_each(clear)

  it('unnamed register works without provider', function()
    eq('"', eval('v:register'))
    basic_register_test()
  end)

  it('`:redir @+>` with invalid g:clipboard shows error exactly once', function()
    local screen = Screen.new(72, 8)
    screen:attach()
    command("let g:clipboard = 'bogus'")
    feed_command('redir @+> | :call system("cat CONTRIBUTING.md") | redir END')
    -- it is made empty
    screen:expect([[
      ~                                                                       |
      ~                                                                       |
      ~                                                                       |
      Error detected while processing function provider#clipboard#Executable: |
      line    5:                                                              |
      clipboard: invalid g:clipboard                                          |
      clipboard: No provider. Try ":CheckHealth" or ":h clipboard".           |
      Press ENTER or type command to continue^                                 |
    ]], nil, {{bold = true, foreground = Screen.colors.Blue}})
  end)
end)

describe('clipboard', function()
  local function reset(...)
    clear('--cmd', 'let &rtp = "test/functional/fixtures,".&rtp', ...)
  end

  before_each(function()
    reset()
    feed_command('call getreg("*")') -- force load of provider
  end)

   it('has independent "* and unnamed registers per default', function()
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

  end)

  describe('with clipboard=unnamedplus', function()
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
      ~                                                           |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      :registers                                                  |
      {1:--- Registers ---}                                           |
      "*   some{2:^J}star data{2:^J}                                      |
      "+   such{2:^J}plus{2:^J}stuff                                      |
      ":   let g:test_clip['+'] = ['such', 'plus', 'stuff']       |
      {3:Press ENTER or type command to continue}^                     |
    ]], {
      [1] = {bold = true, foreground = Screen.colors.Fuchsia},
      [2] = {foreground = Screen.colors.Blue},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen}},
      {{bold = true, foreground = Screen.colors.Blue}})
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
    screen:attach()
    insert([[
      the source
      a target]])
    feed('gg"*ywwyw')
    -- clicking depends on the exact visual layout, so expect it:
    screen:expect([[
      the ^source                    |
      a target                      |
      ~                             |
      ~                             |
                                    |
    ]], nil, {{bold = true, foreground = Screen.colors.Blue}})

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

end)
