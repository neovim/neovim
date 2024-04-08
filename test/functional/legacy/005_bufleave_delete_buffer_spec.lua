-- Test for autocommand that deletes the current buffer on BufLeave event.
-- Also test deleting the last buffer, should give a new, empty buffer.

local t = require('test.functional.testutil')(after_each)
local clear, feed, insert = t.clear, t.feed, t.insert
local command, expect = t.command, t.expect
local poke_eventloop = t.poke_eventloop

describe('test5', function()
  setup(clear)

  -- luacheck: ignore 621 (Indentation)
  it('is working', function()
    insert([[
      start of test file Xxx
      vim: set noai :
      	this is a test
      	this is a test
      	this is a test
      	this is a test
      end of test file Xxx]])

    command('w! Xxx0')
    command('au BufLeave Xxx bwipe')
    command('/start of')

    -- Write test file Xxx.
    command('.,/end of/w! Xxx')

    -- Split to Xxx.
    command('sp Xxx')

    -- Delete buffer Xxx, now we're back here.
    command('bwipe')
    feed('G?this is a<cr>')
    feed('othis is some more text<esc>')
    poke_eventloop()

    -- Append some text to this file.

    -- Write current file contents.
    command('?start?,$yank A')

    -- Delete current buffer, get an empty one.
    command('bwipe!')
    -- Append an extra line to the output register.
    feed('ithis is another test line<esc>:yank A<cr>')
    poke_eventloop()

    -- Output results
    command('%d')
    command('0put a')
    command('$d')

    -- Assert buffer contents.
    expect([[
      start of test file Xxx
      vim: set noai :
      	this is a test
      	this is a test
      	this is a test
      	this is a test
      this is some more text
      end of test file Xxx
      this is another test line]])
  end)

  teardown(function()
    os.remove('Xxx')
    os.remove('Xxx0')
  end)
end)
