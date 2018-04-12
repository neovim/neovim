-- Tests for regexp with backslash and other special characters inside []
-- Also test backslash for hex/octal numbered character.
--
-- Note:
-- Since this text input contains null characters (\x00) we can't pass the
-- full input to `insert`. We need instead to insert the input reading
-- from 3 files and insert the null bytes manually between them.

local helpers = require('test.functional.helpers')(after_each)
local feed, write_file = helpers.feed, helpers.write_file
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

local file_part1 = [=[start
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
test text ]=]

local file_part2 = [=[test text  [\x00]
test te]=]

local file_part3 = [=[xt test text  [\x00-\x10]
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
 bcdbcdbcd]=]

describe('regexp with backslash, using also hex/octal numbered characters', function()
  before_each(clear)
  after_each(function ()
    os.remove('part_1')
    os.remove('part_2')
    os.remove('part_3')
  end)

  it('is working', function()
    -- Prepare the input to run the test
    write_file('part_1', file_part1, false)
    write_file('part_2', file_part2, false)
    write_file('part_3', file_part3, false)
    execute('.read part_1')  -- read part_1 of the input
    feed('G$')               -- goto end of buffer
    feed('a<C-V><C-@><Esc>') -- insert null byte
    execute('read part_2')   -- read part_2 of the input
    feed('kgJ')              -- join inputs
    feed('G$')               -- goto end of buffer
    feed('a<C-v><C-@><Esc>') -- another null byte
    execute('read part_3')   -- read part_3 of the input
    feed('kgJ')              -- join inputs
    feed('ggdd')             -- delete first line (empty)

    -- Now we can start the test
    -- <cr> are needed to go to the next line to perform the next substitutions
    execute([=[/[\x]]=])
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
    feed('<cr>')
    execute([=[s/[\x-z]\+//]=])
    feed('<cr>')
    execute([=[s/[\u-z]\{2,}//]=])
    feed('<cr>')
    execute([[s/\(a\)\+//]])
    feed('<cr>')
    execute([[s/\(a*\)\+//]])
    feed('<cr>')
    execute([[s/\(a*\)*//]])
    feed('<cr>')
    execute([[s/\(a\)\{2,3}/A/]])
    feed('<cr>')
    execute([[s/\(a\)\{-2,3}/A/]])
    feed('<cr>')
    execute([[s/\(a\)*\(12\)\@>/A/]])
    feed('<cr>')
    execute([[s/\(foo\)\@<!bar/A/]])
    feed('<cr>')
    execute([[s/\(an\_s\+\)\@<=file/A/]])
    feed('<cr>')
    execute([[s/^\(\h\w*\%(->\|\.\)\=\)\+=/XX/]])
    feed('<cr>')
    execute([[s/^\(\h\w*\%(->\|\.\)\=\)\+=/YY/]])
    feed('<cr>')
    execute('s/aaa/xyz/')
    feed('<cr>')
    execute('s/~/bcd/')
    feed('<cr>')
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
