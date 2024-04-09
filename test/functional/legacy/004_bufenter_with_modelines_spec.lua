-- Test for autocommand that changes current buffer on BufEnter event.
-- Check if modelines are interpreted for the correct buffer.

local t = require('test.functional.testutil')()
local clear, feed, insert = t.clear, t.feed, t.insert
local feed_command, expect = t.feed_command, t.expect

describe('BufEnter with modelines', function()
  setup(clear)

  it('is working', function()
    insert([[
      startstart
      start of test file Xxx
      vim: set noai :
          this is a test
          this is a test
          this is a test
          this is a test
      end of test file Xxx]])

    feed_command('au BufEnter Xxx brew')

    -- Write test file Xxx
    feed_command('/start of')
    feed_command('.,/end of/w! Xxx')
    feed_command('set ai modeline modelines=3')

    -- Split to Xxx, autocmd will do :brew
    feed_command('sp Xxx')

    -- Append text with autoindent to this file
    feed('G?this is a<CR>')
    feed('othis should be auto-indented<Esc>')

    -- Go to Xxx, no autocmd anymore
    feed_command('au! BufEnter Xxx')
    feed_command('buf Xxx')

    -- Append text without autoindent to Xxx
    feed('G?this is a<CR>')
    feed('othis should be in column 1<Esc>')
    feed_command('wq')

    -- Include Xxx in the current file
    feed('G:r Xxx<CR>')

    -- Vim issue #57 do not move cursor on <c-o> when autoindent is set
    feed_command('set fo+=r')
    feed('G')
    feed('o# abcdef<Esc>2hi<CR><c-o>d0<Esc>')
    feed('o# abcdef<Esc>2hi<c-o>d0<Esc>')

    expect([[
      startstart
      start of test file Xxx
      vim: set noai :
          this is a test
          this is a test
          this is a test
          this is a test
          this should be auto-indented
      end of test file Xxx
      start of test file Xxx
      vim: set noai :
          this is a test
          this is a test
          this is a test
          this is a test
      this should be in column 1
      end of test file Xxx
      # abc
      def
      def]])
  end)

  teardown(function()
    os.remove('Xxx')
  end)
end)
