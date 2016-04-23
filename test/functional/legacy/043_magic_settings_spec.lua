-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Tests for regexp with various magic settings.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

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

    execute('/^1')
    execute([[/a*b\{2}c\+/e]])
    feed([[x/\Md\*e\{2}f\+/e<cr>]])
    feed('x:set nomagic<cr>')
    execute([[/g\*h\{2}i\+/e]])
    feed([[x/\mj*k\{2}l\+/e<cr>]])
    feed([[x/\vm*n{2}o+/e<cr>]])
    feed([[x/\V^aa$<cr>]])
    feed('x:set magic<cr>')
    execute([[/\v(a)(b)\2\1\1/e]])
    feed([[x/\V[ab]\(\[xy]\)\1<cr>]])
    feed('x:$<cr>')
    execute('set undolevels=100')
    feed('dv?bar?<cr>')
    feed('Yup:<cr>')
    execute('?^1?,$yank A')

    -- Put @a and clean empty line
    execute('%d')
    execute('0put a')
    execute('$d')

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
