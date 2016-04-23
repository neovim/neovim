-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Test for autocommand that changes current buffer on BufEnter event.
-- Check if modelines are interpreted for the correct buffer.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

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

    execute('au BufEnter Xxx brew')

    -- Write test file Xxx
    execute('/start of')
    execute('.,/end of/w! Xxx')
    execute('set ai modeline modelines=3')

    -- Split to Xxx, autocmd will do :brew
    execute('sp Xxx')

    -- Append text with autoindent to this file
    feed('G?this is a<CR>')
    feed('othis should be auto-indented<Esc>')

    -- Go to Xxx, no autocmd anymore
    execute('au! BufEnter Xxx')
    execute('buf Xxx')

    -- Append text without autoindent to Xxx
    feed('G?this is a<CR>')
    feed('othis should be in column 1<Esc>')
    execute('wq')

    -- Include Xxx in the current file
    feed('G:r Xxx<CR>')

    -- Vim issue #57 do not move cursor on <c-o> when autoindent is set
    execute('set fo+=r')
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
