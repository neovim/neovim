-- Test for autocommand that redefines the argument list, when doing ":all".

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command, dedent, eq = helpers.command, helpers.dedent, helpers.eq
local curbuf_contents = helpers.curbuf_contents
local wait = helpers.wait

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
    wait()

    command('au BufReadPost Xxx2 next Xxx2 Xxx1')
    command('/^start of')

    -- Write test file Xxx1
    feed('A1<Esc>:.,/end of/w! Xxx1<cr>')

    -- Write test file Xxx2
    feed('$r2:.,/end of/w! Xxx2<cr>')

    -- Write test file Xxx3
    feed('$r3:.,/end of/w! Xxx3<cr>')
    wait()

    -- Redefine arglist; go to Xxx1
    command('next! Xxx1 Xxx2 Xxx3')

    -- Open window for all args
    command('all')

    -- Write contents of Xxx1
    command('%yank A')

    -- Append contents of last window (Xxx1)
    feed('')
    wait()
    command('%yank A')

    -- should now be in Xxx2
    command('rew')

    -- Append contents of Xxx2
    command('%yank A')

    command('%d')
    command('0put=@a')
    command('$d')

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
