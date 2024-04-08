-- Test for autocommand that changes the buffer list, when doing ":ball".

local t = require('test.functional.testutil')(after_each)
local clear, feed, insert = t.clear, t.feed, t.insert
local feed_command, expect = t.feed_command, t.expect

describe(':ball', function()
  setup(clear)

  it('is working', function()
    -- Must disable 'hidden' so that the BufReadPost autocmd is triggered
    -- when Xxx2 is reloaded
    feed_command('set nohidden')
    insert([[
      start of test file Xxx
          this is a test
          this is a test
      end of test file Xxx]])

    feed_command('w! Xxx0')
    feed('gg')

    -- Write test file Xxx1
    feed('A1<esc>:.,/end of/w! Xxx1<cr>')
    feed_command('sp Xxx1')
    feed_command('close')

    -- Write test file Xxx2
    feed('$r2:.,/end of/w! Xxx2<cr>')
    feed_command('sp Xxx2')
    feed_command('close')

    -- Write test file Xxx3
    feed('$r3:.,/end of/w! Xxx3<cr>')
    feed_command('sp Xxx3')
    feed_command('close')

    feed_command('au BufReadPost Xxx2 bwipe')

    -- Open window for all args, close Xxx2
    feed('$r4:ball<cr>')

    -- Write contents of this file
    feed_command('%yank A')

    -- Append contents of second window (Xxx1)
    feed('')
    feed_command('%yank A')

    -- Append contents of last window (this file)
    feed('')
    feed_command('%yank A')

    feed_command('bf')
    feed_command('%d')
    feed_command('0put=@a')
    feed_command('$d')

    expect([[
      start of test file Xxx4
          this is a test
          this is a test
      end of test file Xxx
      start of test file Xxx1
          this is a test
          this is a test
      end of test file Xxx
      start of test file Xxx4
          this is a test
          this is a test
      end of test file Xxx]])
  end)

  teardown(function()
    os.remove('Xxx0')
    os.remove('Xxx1')
    os.remove('Xxx2')
    os.remove('Xxx3')
  end)
end)
