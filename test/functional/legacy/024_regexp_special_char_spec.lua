-- Tests for regexp with backslash and other special characters inside []
-- Also test backslash for hex/octal numbered character.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local eq, eval, wait = helpers.eq, helpers.eval, helpers.wait

describe('regexp with special characters', function()
  setup(function()
    clear()
    -- For the control characters it is easier to write them to a file than to
    -- put them in the neovim buffer via insert() as they need to be escaped
    -- with <C-V>.
    local file = io.open('testfile', 'w')
    file:write(helpers.dedent([=[
      start
      test \text test text
      test 	text test text
      test text ]test text
      test ]text test text
      test text te^st text
      test te$xt test text
      test taext test text  x61
      test tbext test text  x60-x64
      test 5text test text  x78 5
      testc text test text  o143
      tesdt text test text  o140-o144
      test7 text test text  o41 7
      test text tBest text  \%x42
      test text teCst text  \%o103
      test text ]=]..'\x00'..[=[test text  [\x00]
      test te]=]..'\x00xt t\x04est t\x10'..[=[ext  [\x00-\x10]
      test \xyztext test text  [\x-z]
      test text tev\uyst text  [\u-z]
      xx aaaaa xx a
      xx aaaaa xx a
      xx aaaaa xx a
      xx aaaaa xx
      xx aaaaa xx
      xx aaa12aa xx
      xx foobar xbar xx
      xx an file xx
      x= 9;
      hh= 77;
       aaa
       xyz
       bcdbcdbcd]=]))
   file:flush()
   file:close()
  end)
  teardown(function()
    os.remove('testfile')
  end)

  it('is working', function()
    execute('e testfile')
    execute([=[/[\x]]=])
    feed('x')
    execute([=[/[\t\]]]=])
    feed('x')
    execute('/[]y]')
    feed('x')
    execute([=[/[\]]]=])
    feed('x')
    execute('/[y^]')
    feed('x')
    execute('/[$y]')
    feed('x')
    execute([=[/[\x61]]=]) -- this should find the letter 'a'
    feed('x')
    execute([=[/[\x60-\x64]]=])
    feed('x')
    feed('j0')
    execute([=[/[\x785]]=]) -- this should find a 'x' or a '5'
    feed('x')
    execute([=[/[\o143]]=])
    feed('x')
    execute([=[/[\o140-\o144]]=])
    feed('x')
    execute([=[/[\o417]]=])
    feed('x')
    execute([[/\%x42]])
    feed('x')
    execute([[/\%o103]])
    feed('x')
    execute([=[/[\x00]]=])
    feed('x')
    feed('j')
    execute([[s/[\x00-\x10]//g]])
    feed('j')
    execute([[s/[\x-z]\+//]])
    feed('j')
    execute([[s/[\u-z]\{2,}//]])
    feed('j')
    execute([[s/\(a\)\+//]])
    feed('j')
    execute([[s/\(a*\)\+//]])
    feed('j')
    execute([[s/\(a*\)*//]])
    feed('j')
    execute([[s/\(a\)\{2,3}/A/]])
    feed('j')
    execute([[s/\(a\)\{-2,3}/A/]])
    feed('j')
    execute([[s/\(a\)*\(12\)\@>/A/]])
    feed('j')
    execute([[s/\(foo\)\@<!bar/A/]])
    feed('j')
    execute([[s/\(an\_s\+\)\@<=file/A/]])
    feed('j')
    execute([[s/^\(\h\w*\%(->\|\.\)\=\)\+=/XX/]])
    feed('j')
    execute([[s/^\(\h\w*\%(->\|\.\)\=\)\+=/YY/]])
    feed('j')
    execute('s/aaa/xyz/')
    feed('j')
    execute('s/~/bcd/')
    feed('j')
    execute([[s/~\+/BB/]])

    -- Assert buffer contents.
    expect([=[
      start
      test text test text
      test text test text
      test text test text
      test text test text
      test text test text
      test text test text
      test text test text  x61
      test text test text  x60-x64
      test text test text  x78 5
      test text test text  o143
      test text test text  o140-o144
      test text test text  o41 7
      test text test text  \%x42
      test text test text  \%o103
      test text test text  [\x00]
      test text test text  [\x00-\x10]
      test text test text  [\x-z]
      test text test text  [\u-z]
      xx  xx a
      xx aaaaa xx a
      xx aaaaa xx a
      xx Aaa xx
      xx Aaaa xx
      xx Aaa xx
      xx foobar xA xx
      xx an A xx
      XX 9;
      YY 77;
       xyz
       bcd
       BB]=])
  end)
end)
