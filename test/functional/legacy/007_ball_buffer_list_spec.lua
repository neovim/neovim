-- Test for autocommand that changes the buffer list, when doing ":ball".

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe(':ball', function()
  setup(clear)

  it('is working', function()
    insert([[
      start of test file Xxx
          this is a test
          this is a test
      end of test file Xxx]])

    execute('w! Xxx0')
    feed('gg')

    -- Write test file Xxx1
    feed('A1:.,/end of/w! Xxx1<cr>')
    execute('sp Xxx1')
    execute('close')

    -- Write test file Xxx2
    feed('$r2:.,/end of/w! Xxx2<cr>')
    execute('sp Xxx2')
    execute('close')

    -- Write test file Xxx3
    feed('$r3:.,/end of/w! Xxx3<cr>')
    execute('sp Xxx3')
    execute('close')

    execute('au BufReadPost Xxx2 bwipe')

    -- Open window for all args, close Xxx2
    feed('$r4:ball<cr>')
   
    -- Write contents of this file
    execute('%yank A')
    
    -- Append contents of second window (Xxx1) 
    feed('')
    execute('%yank A')

    -- Append contents of last window (this file)
    feed('')
    execute('%yank A')

    execute('bf')
    execute('%d')
    execute('0put=@a')
    execute('$d')

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
