-- Tests for regexp with various magic settings.

local t = require('test.functional.testutil')()
local clear, feed, insert = t.clear, t.feed, t.insert
local feed_command, expect = t.feed_command, t.expect

describe('regexp with magic settings', function()
  setup(clear)

  it('is working', function()
    insert([[
      1 a aa abb abbccc
      2 d dd dee deefff
      3 g gg ghh ghhiii
      4 j jj jkk jkklll
      5 m mm mnn mnnooo
      6 x ^aa$ x
      7 (a)(b) abbaa
      8 axx [ab]xx
      9 foobar
      ]])

    feed_command('/^1')
    feed_command([[/a*b\{2}c\+/e]])
    feed([[x/\Md\*e\{2}f\+/e<cr>]])
    feed('x:set nomagic<cr>')
    feed_command([[/g\*h\{2}i\+/e]])
    feed([[x/\mj*k\{2}l\+/e<cr>]])
    feed([[x/\vm*n{2}o+/e<cr>]])
    feed([[x/\V^aa$<cr>]])
    feed('x:set magic<cr>')
    feed_command([[/\v(a)(b)\2\1\1/e]])
    feed([[x/\V[ab]\(\[xy]\)\1<cr>]])
    feed('x:$<cr>')
    feed_command('set undolevels=100')
    feed('dv?bar?<cr>')
    feed('Yup:<cr>')
    feed_command('?^1?,$yank A')

    -- Put @a and clean empty line
    feed_command('%d')
    feed_command('0put a')
    feed_command('$d')

    -- Assert buffer contents.
    expect([[
      1 a aa abb abbcc
      2 d dd dee deeff
      3 g gg ghh ghhii
      4 j jj jkk jkkll
      5 m mm mnn mnnoo
      6 x aa$ x
      7 (a)(b) abba
      8 axx ab]xx
      9 foobar
      9 foo
      ]])
  end)
end)
