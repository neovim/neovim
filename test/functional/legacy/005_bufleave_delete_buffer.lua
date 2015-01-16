-- Test for autocommand that deletes the current buffer on BufLeave event.
-- Also test deleting the last buffer, should give a new, empty buffer.

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('test5', function()
  setup(clear)

  it('is working', function()
    insert([[
      start of test file Xxx
      vim: set noai :
      	this is a test
      	this is a test
      	this is a test
      	this is a test
      end of test file Xxx]])

    execute('w! Xxx0')
    execute('au BufLeave Xxx bwipe')
    execute('/start of')

    -- Write test file Xxx.
    execute('.,/end of/w! Xxx')

    -- Split to Xxx.
    execute('sp Xxx')

    -- Delete buffer Xxx, now we're back here.
    execute('bwipe')
    feed('G?this is a<cr>')
    feed('othis is some more text<esc>')

    -- Append some text to this file.

    -- Write current file contents.
    execute('?start?,$yank A')

    -- Delete alternate buffer.
    execute('bwipe test.out')
    execute('au bufleave test5.in bwipe')

    -- Delete current buffer, get an empty one.
    execute('bwipe!')
    feed('ithis is another test line<esc>:yank A<cr>')

    -- Output results
    execute('%d')
    execute('0put a')
    execute('1d | $d')

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
