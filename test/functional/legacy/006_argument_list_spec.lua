-- Test for autocommand that redefines the argument list, when doing ":all".

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, dedent, eq = helpers.execute, helpers.dedent, helpers.eq
local curbuf_contents = helpers.curbuf_contents

describe('argument list', function()
  setup(clear)

  it('is working', function()
    insert([[
      start of test file Xxx
          this is a test
          this is a test
          this is a test
          this is a test
      end of test file Xxx]])

    execute('au BufReadPost Xxx2 next Xxx2 Xxx1')
    execute('/^start of')
    
    -- Write test file Xxx1
    feed('A1<Esc>:.,/end of/w! Xxx1<cr>')

    -- Write test file Xxx2
    feed('$r2:.,/end of/w! Xxx2<cr>')

    -- Write test file Xxx3
    feed('$r3:.,/end of/w! Xxx3<cr>')

    -- Redefine arglist; go to Xxx1
    execute('next! Xxx1 Xxx2 Xxx3')
    
    -- Open window for all args
    execute('all')
    
    -- Write contents of Xxx1
    execute('%yank A')

    -- Append contents of last window (Xxx1)
    feed('')
    execute('%yank A')
    
    -- should now be in Xxx2
    execute('rew')
    
    -- Append contents of Xxx2
    execute('%yank A')

    execute('%d')
    execute('0put=@a')
    execute('$d')

    eq(dedent([[
      start of test file Xxx1
          this is a test
          this is a test
          this is a test
          this is a test
      end of test file Xxx
      start of test file Xxx1
          this is a test
          this is a test
          this is a test
          this is a test
      end of test file Xxx
      start of test file Xxx2
          this is a test
          this is a test
          this is a test
          this is a test
      end of test file Xxx]]), curbuf_contents())
  end)

  teardown(function()
    os.remove('Xxx1')   
    os.remove('Xxx2')   
    os.remove('Xxx3')   
  end)
end)
