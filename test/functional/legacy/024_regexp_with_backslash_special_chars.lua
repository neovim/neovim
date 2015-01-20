-- Tests for regexp with backslash and other special characters inside []
-- Also test backslash for hex/octal numbered character

local helpers = require("test.functional.helpers")
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('regexp_backslash', function()
    setup(clear)

    it('is_working', function()
        insert([=[
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
            test text  test text  [\x00]
            test te xt test text  [\x00-\x10]
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
            bcdbcdbcd]=])


        expect([[
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
            test text  test text  [\x00]
            test te xt test text  [\x00-\x10]
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

        -- These are a real pain to pass to lua correctly...
        feed([[ /[\x] ]])
        feed([=[ x/[\t\]] ]=])
        feed([[ x/[]y] ]])
        feed([=[ x/[\]] ]=])
        feed([[ x/[y^] ]])
        feed([[ x/[$y] ]])
        feed([[ x/[\x61] ]])
        feed([[ x/[\x60-\x64] ]])
        feed([[ xj0/[\x785] ]])
        feed([[ x/[\o143] ]])
        feed([[ x/[\o140-\o144] ]])
        feed([[ x/[\o417] ]])
        feed([[ x/\%x42 ]])
        feed([[ x/\%o103 ]])
        feed([[ x/[\x00] ]])
        feed('x')

        execute([[ s/[\x00-\x10]//g ]])
        execute([[ s/[\x-z]\+// ]])
        execute([[ s/[\u-z]\{2,}// ]])
        execute([[ s/\(a\)\+// ]])
        execute([[ s/\(a*\)\+// ]])
        execute([[ s/\(a*\)*// ]])
        execute([[ s/\(a\)\{2,3}/A/ ]])
        execute([[ s/\(a\)\{-2,3}/A/ ]])
        execute([[ s/\(a\)*\(12\)\@>/A/ ]])
        execute([[ s/\(foo\)\@<!bar/A/ ]])
        execute([[ s/\(an\_s\+\)\@<=file/A/ ]])
        execute([[ s/^\(\h\w*\%(->\|\.\)\=\)\+=/XX/ ]])
        execute([[ s/^\(\h\w*\%(->\|\.\)\=\)\+=/YY/ ]])
        execute([[ s/aaa/xyz/ ]])
        execute([[ s/~/bcd/ ]])
        execute([[ s/~\+/BB/ ]])
        execute('"')
        execute('?start?,$w! test.out')
        --execute('qa!')

        expect([[
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
            BB]])

    end)
end)


