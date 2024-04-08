-- Tests for regexp with multi-byte encoding and various magic settings.
-- Test matchstr() with a count and multi-byte chars.
--
-- This test contains both "test44" and "test99" from the old test suite.

local t = require('test.functional.testutil')(after_each)
local feed, insert = t.feed, t.insert
local clear, feed_command, expect = t.clear, t.feed_command, t.expect

-- Runs the test protocol with the given 'regexpengine' setting. In the old test
-- suite the test protocol was duplicated in test44 and test99, the only
-- difference being the 'regexpengine' setting. We've extracted it here.
local function run_test_with_regexpengine(regexpengine)
  insert([[
    1 a aa abb abbccc
    2 d dd dee deefff
    3 g gg ghh ghhiii
    4 j jj jkk jkklll
    5 m mm mnn mnnooo
    6 x ^aa$ x
    7 (a)(b) abbaa
    8 axx [ab]xx
    9 หม่x อมx
    a อมx หม่x
    b ちカヨは
    c x ¬€x
    d 天使x
    e ������y
    f ������z
    g a啷bb
    j 0123❤x
    k combinations
    l ä ö ü ᾱ̆́]])

  feed_command('set re=' .. regexpengine)

  -- Lines 1-8. Exercise regexp search with various magic settings. On each
  -- line the character on which the cursor is expected to land is deleted.
  feed('/^1<cr>')
  feed([[/a*b\{2}c\+/e<cr>x]])
  feed([[/\Md\*e\{2}f\+/e<cr>x]])
  feed_command('set nomagic')
  feed([[/g\*h\{2}i\+/e<cr>x]])
  feed([[/\mj*k\{2}l\+/e<cr>x]])
  feed([[/\vm*n{2}o+/e<cr>x]])
  feed([[/\V^aa$<cr>x]])
  feed_command('set magic')
  feed([[/\v(a)(b)\2\1\1/e<cr>x]])
  feed([[/\V[ab]\(\[xy]\)\1<cr>x]])

  -- Line 9. Search for multi-byte character without combining character.
  feed('/ม<cr>x')

  -- Line a. Search for multi-byte character with combining character.
  feed('/ม่<cr>x')

  -- Line b. Find word by change of word class.
  -- (The "<" character in this test step seemed to confuse our "feed" test
  -- helper, which is why we've resorted to "execute" here.)
  feed_command([[/ち\<カヨ\>は]])
  feed('x')

  -- Lines c-i. Test \%u, [\u], and friends.
  feed([[/\%u20ac<cr>x]])
  feed([[/[\u4f7f\u5929]\+<cr>x]])
  feed([[/\%U12345678<cr>x]])
  feed([[/[\U1234abcd\u1234\uabcd]<cr>x]])
  feed([[/\%d21879b<cr>x]])

  -- Line j. Test backwards search from a multi-byte character.
  feed('/x<cr>x')
  feed('?.<cr>x')

  -- Line k. Test substitution with combining characters by executing register
  -- contents.
  feed_command([[let @w=':%s#comb[i]nations#œ̄ṣ́m̥̄ᾱ̆́#g']])
  feed_command('@w')

  -- Line l. Ex command ":s/ \?/ /g" should NOT split multi-byte characters
  -- into bytes (fixed by vim-7.3.192).
  feed_command([[/^l]])
  feed_command([[s/ \?/ /g]])

  -- Additional tests. Test matchstr() with multi-byte characters.
  feed('G')
  feed_command([[put =matchstr(\"אבגד\", \".\", 0, 2)]])   -- ב
  feed_command([[put =matchstr(\"אבגד\", \"..\", 0, 2)]])  -- בג
  feed_command([[put =matchstr(\"אבגד\", \".\", 0, 0)]])   -- א
  feed_command([[put =matchstr(\"אבגד\", \".\", 4, -1)]])  -- ג

  -- Test that a search with "/e" offset wraps around at the end of the buffer.
  feed_command('new')
  feed_command([[$put =['dog(a', 'cat('] ]])
  feed('/(/e+<cr>')
  feed('"ayn')
  feed_command('bd!')
  feed_command([[$put ='']])
  feed('G"ap')

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
    9 หม่x อx
    a อมx หx
    b カヨは
    c x ¬x
    d 使x
    e y
    f z
    g abb
    j 012❤
    k œ̄ṣ́m̥̄ᾱ̆́
     l ä ö ü ᾱ̆́
    ב
    בג
    א
    ג
    a
    cat(]])
end

describe('multi-byte regexp search with magic settings', function()
  before_each(clear)

  it('is working with regexpengine=1', function()
    -- The old test44.
    run_test_with_regexpengine(1)
  end)

  it('is working with regexpengine=2', function()
    -- The old test99.
    run_test_with_regexpengine(2)
  end)
end)
