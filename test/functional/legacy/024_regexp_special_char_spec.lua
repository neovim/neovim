-- Tests for regexp with backslash and other special characters inside []
-- Also test backslash for hex/octal numbered character.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('RegExp with backslash and other special characters', function()
  setup(clear)

  it('is working', function()
    insert([[
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
      test text teCst text  \%o103]])

    -- Using "feed" instead of "insert"
    -- because "insert" escapes "<" preventing inputting special characters.
    feed([[otest text <C-V>x00test text  [\x00]<CR>]])
    feed([[test te<C-V>x00xt t<C-V><C-D>est t<C-V><C-P>ext  [\x00-\x10]<CR><ESC>]])

    -- Insert the rest of the block.
    insert([[
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
       bcdbcdbcd]])

    feed([=[/[\x]<cr>]=])
    feed([=[x/[\t\]]<cr>]=])
    feed('x/[]y]<cr>')
    feed([=[x/[\]]<cr>]=])
    feed('x/[y^]<cr>')
    feed('x/[$y]<cr>')
    feed([=[x/[\x61]<cr>]=])
    feed([=[x/[\x60-\x64]<cr>]=])
    feed([=[xj0/[\x785]<cr>]=])
    feed([=[x/[\o143]<cr>]=])
    feed([=[x/[\o140-\o144]<cr>]=])
    feed([=[x/[\o417]<cr>]=])
    feed([[x/\%x42<cr>]])
    feed([[x/\%o103<cr>]])
    feed([=[x/[\x00]<cr>]=])
    feed('x<cr>')
    execute([=[s/[\x00-\x10]//g]=])
    feed('<CR>')
    execute([=[s/[\x-z]\+//]=])
    feed('<CR>')
    execute([=[s/[\u-z]\{2,}//]=])
    feed('<CR>')
    execute([[s/\(a\)\+//]])
    feed('<CR>')
    execute([[s/\(a*\)\+//]])
    feed('<CR>')
    execute([[s/\(a*\)*//]])
    feed('<CR>')
    execute([[s/\(a\)\{2,3}/A/]])
    feed('<CR>')
    execute([[s/\(a\)\{-2,3}/A/]])
    feed('<CR>')
    execute([[s/\(a\)*\(12\)\@>/A/]])
    feed('<CR>')
    execute([[s/\(foo\)\@<!bar/A/]])
    feed('<CR>')
    execute([[s/\(an\_s\+\)\@<=file/A/]])
    feed('<CR>')
    execute([[s/^\(\h\w*\%(->\|\.\)\=\)\+=/XX/]])
    feed('<CR>')
    execute([[s/^\(\h\w*\%(->\|\.\)\=\)\+=/YY/]])
    feed('<CR>')
    execute('s/aaa/xyz/')
    feed('<CR>')
    execute('s/~/bcd/')
    feed('<CR>')
    execute([[s/~\+/BB/]])

    expect([[
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
       BB]])
  end)
end)
