-- Test clipboard provider support

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect, eq, eval = helpers.execute, helpers.expect, helpers.eq, helpers.eval
local nvim, run, stop, restart = helpers.nvim, helpers.run, helpers.stop, helpers.restart

local function reset()
  clear()
  execute('let &rtp = "test/functional/clipboard,".&rtp')
end

local function basic_register_test()
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
  reset()
end

describe('clipboard usage', function()
  setup(reset)
  it("works", function()
    basic_register_test()

    -- "* and unnamed should function as independent registers
    insert("some words")
    feed('^"*dwdw"*P')
    expect('some ')
    eq({'some '}, eval("g:test_clip['*']"))
    reset()

    -- "* and "+ should be independent when the provider supports it
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
    eq({'third line', ''}, eval("g:test_clip['+']"))
    eq({'secound line', ''}, eval("g:test_clip['*']"))
    reset()

    -- handle null bytes
    insert("some\022000text\n\022000very binary\022000")
    feed('"*y-+"*p')
    eq({'some\ntext', '\nvery binary\n',''}, eval("g:test_clip['*']"))
    expect("some\00text\n\00very binary\00\nsome\00text\n\00very binary\00")

    -- test getreg/getregtype
    eq('some\ntext\n\nvery binary\n\n', eval("getreg('*', 1)"))
    eq("V", eval("getregtype('*')"))
    reset()

    -- blockwise paste
    insert([[
      much
      text]])
    feed('"*yy') -- force load of provider
    execute("let g:test_clip['*'] = [['very','block'],'b']")
    feed('gg"*P')
    expect([[
      very much
      blocktext]])
    eq("\0225", eval("getregtype('*')"))
    reset()

    -- test setreg
    execute('call setreg("*", "setted\\ntext", "c")')
    execute('call setreg("+", "explicitly\\nlines", "l")')
    feed('"+P"*p')
    expect([[
        esetted
        textxplicitly
        lines
        ]])
    reset()

    -- test let @+ (issue #1427)
    execute("let @+ = 'some'")
    execute("let @* = ' other stuff'")
    eq({'some'}, eval("g:test_clip['+']"))
    eq({' other stuff'}, eval("g:test_clip['*']"))
    feed('"+p"*p')
    expect('some other stuff')
    execute("let @+ .= ' more'")
    feed('dd"+p')
    expect('some more')
    reset()

    -- the basic behavior of unnamed register should be the same
    -- even when handled by clipboard provider
    execute('set clipboard=unnamed')
    basic_register_test()

    -- with cb=unnamed, "* and unnamed will be the same register
    execute('set clipboard=unnamed')
    insert("some words")
    feed('^"*dwdw"*P')
    expect('words')
    eq({'words'}, eval("g:test_clip['*']"))

    execute("let g:test_clip['*'] = ['linewise stuff','']")
    feed('p')
    expect([[
      words
      linewise stuff]])
    reset()

    end)
end)
