-- Test for regexp patterns without multi-byte support.
-- See test95 for multi-byte tests.
-- A pattern that gives the expected result produces OK, so that we know it was
-- actually tried.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('64', function()
  setup(clear)

  it('is working', function()
    insert([[
      Substitute here:
      <T="">Ta 5</Title>
      <T="">Ac 7</Title>
      
      Behind:
      asdfasd<yyy
      xxstart1
      asdfasd<yy
      xxxstart2
      asdfasd<yy
      xxstart3
      
      Visual:
      thexe the thexethe
      andaxand andaxand
      oooxofor foroxooo
      oooxofor foroxooo
      
      Marks:
      asdfSasdfsadfEasdf
      asdfSas
      dfsadfEasdf
      
      Results of test64:]])

    -- tl is a List of Lists with:
    --    regexp engine
    --    regexp pattern
    --    text to test the pattern on
    --    expected match (optional)
    --    expected submatch 1 (optional)
    --    expected submatch 2 (optional)
    --    etc.
    -- When there is no match use only the first two items.
    execute('let tl = []')

    -- 
    --     Previously written tests 
    --

    source([[
      call add(tl, [2, 'ab', 'aab', 'ab'])
      call add(tl, [2, 'b', 'abcdef', 'b'])
      call add(tl, [2, 'bc*', 'abccccdef', 'bcccc'])
      call add(tl, [2, 'bc\{-}', 'abccccdef', 'b'])
      call add(tl, [2, 'bc\{-}\(d\)', 'abccccdef', 'bccccd', 'd'])
      call add(tl, [2, 'bc*', 'abbdef', 'b'])
      call add(tl, [2, 'c*', 'ccc', 'ccc'])
      call add(tl, [2, 'bc*', 'abdef', 'b'])
      call add(tl, [2, 'c*', 'abdef', ''])
      call add(tl, [2, 'bc\+', 'abccccdef', 'bcccc'])

      " no match
      call add(tl, [2, 'bc\+', 'abdef'])

      " operator \|
      " Alternation is ordered.
      call add(tl, [2, 'a\|ab', 'cabd', 'a'])

      call add(tl, [2, 'c\?', 'ccb', 'c'])
      call add(tl, [2, 'bc\?', 'abd', 'b'])
      call add(tl, [2, 'bc\?', 'abccd', 'bc'])

      call add(tl, [2, '\va{1}', 'ab', 'a'])

      call add(tl, [2, '\va{2}', 'aa', 'aa'])
      call add(tl, [2, '\va{2}', 'caad', 'aa'])
      call add(tl, [2, '\va{2}', 'aba'])
      call add(tl, [2, '\va{2}', 'ab'])
      call add(tl, [2, '\va{2}', 'abaa', 'aa'])
      call add(tl, [2, '\va{2}', 'aaa', 'aa'])

      call add(tl, [2, '\vb{1}', 'abca', 'b'])
      call add(tl, [2, '\vba{2}', 'abaa', 'baa'])
      call add(tl, [2, '\vba{3}', 'aabaac'])

      call add(tl, [2, '\v(ab){1}', 'ab', 'ab', 'ab'])
      call add(tl, [2, '\v(ab){1}', 'dabc', 'ab', 'ab'])
      call add(tl, [2, '\v(ab){1}', 'acb'])

      call add(tl, [2, '\v(ab){0,2}', 'acb', "", ""])
      call add(tl, [2, '\v(ab){0,2}', 'ab', 'ab', 'ab'])
      call add(tl, [2, '\v(ab){1,2}', 'ab', 'ab', 'ab'])
      call add(tl, [2, '\v(ab){1,2}', 'ababc', 'abab', 'ab'])
      call add(tl, [2, '\v(ab){2,4}', 'ababcab', 'abab', 'ab'])
      call add(tl, [2, '\v(ab){2,4}', 'abcababa', 'abab', 'ab'])

      call add(tl, [2, '\v(ab){2}', 'abab', 'abab', 'ab'])
      call add(tl, [2, '\v(ab){2}', 'cdababe', 'abab', 'ab'])
      call add(tl, [2, '\v(ab){2}', 'abac'])
      call add(tl, [2, '\v(ab){2}', 'abacabab', 'abab', 'ab'])
      call add(tl, [2, '\v((ab){2}){2}', 'abababab', 'abababab', 'abab', 'ab'])
      call add(tl, [2, '\v((ab){2}){2}', 'abacabababab', 'abababab', 'abab', 'ab'])

      call add(tl, [2, '\v(a{1}){1}', 'a', 'a', 'a'])
      call add(tl, [2, '\v(a{2}){1}', 'aa', 'aa', 'aa'])
      call add(tl, [2, '\v(a{2}){1}', 'aaac', 'aa', 'aa'])
      call add(tl, [2, '\v(a{2}){1}', 'daaac', 'aa', 'aa'])
      call add(tl, [2, '\v(a{1}){2}', 'daaac', 'aa', 'a'])
      call add(tl, [2, '\v(a{1}){2}', 'aaa', 'aa', 'a'])
      call add(tl, [2, '\v(a{2})+', 'adaac', 'aa', 'aa'])
      call add(tl, [2, '\v(a{2})+', 'aa', 'aa', 'aa'])
      call add(tl, [2, '\v(a{2}){1}', 'aa', 'aa', 'aa'])
      call add(tl, [2, '\v(a{1}){2}', 'aa', 'aa', 'a'])
      call add(tl, [2, '\v(a{1}){1}', 'a', 'a', 'a'])
      call add(tl, [2, '\v(a{2}){2}', 'aaaa', 'aaaa', 'aa'])
      call add(tl, [2, '\v(a{2}){2}', 'aaabaaaa', 'aaaa', 'aa'])

      call add(tl, [2, '\v(a+){2}', 'dadaac', 'aa', 'a'])
      call add(tl, [2, '\v(a{3}){2}', 'aaaaaaa', 'aaaaaa', 'aaa'])

      call add(tl, [2, '\v(a{1,2}){2}', 'daaac', 'aaa', 'a'])
      call add(tl, [2, '\v(a{1,3}){2}', 'daaaac', 'aaaa', 'a'])
      call add(tl, [2, '\v(a{1,3}){2}', 'daaaaac', 'aaaaa', 'aa'])
      call add(tl, [2, '\v(a{1,3}){3}', 'daac'])
      call add(tl, [2, '\v(a{1,2}){2}', 'dac'])
      call add(tl, [2, '\v(a+)+', 'daac', 'aa', 'aa'])
      call add(tl, [2, '\v(a+)+', 'aaa', 'aaa', 'aaa'])
      call add(tl, [2, '\v(a+){1,2}', 'aaa', 'aaa', 'aaa'])
      call add(tl, [2, '\v(a+)(a+)', 'aaa', 'aaa', 'aa', 'a'])
      call add(tl, [2, '\v(a{3})+', 'daaaac', 'aaa', 'aaa'])
      call add(tl, [2, '\v(a|b|c)+', 'aacb', 'aacb', 'b'])
      call add(tl, [2, '\v(a|b|c){2}', 'abcb', 'ab', 'b'])
      call add(tl, [2, '\v(abc){2}', 'abcabd', ])
      call add(tl, [2, '\v(abc){2}', 'abdabcabc','abcabc', 'abc'])

      call add(tl, [2, 'a*', 'cc', ''])
      call add(tl, [2, '\v(a*)+', 'cc', ''])
      call add(tl, [2, '\v((ab)+)+', 'ab', 'ab', 'ab', 'ab'])
      call add(tl, [2, '\v(((ab)+)+)+', 'ab', 'ab', 'ab', 'ab', 'ab'])
      call add(tl, [2, '\v(((ab)+)+)+', 'dababc', 'abab', 'abab', 'abab', 'ab'])
      call add(tl, [2, '\v(a{0,2})+', 'cc', ''])
      call add(tl, [2, '\v(a*)+', '', ''])
      call add(tl, [2, '\v((a*)+)+', '', ''])
      call add(tl, [2, '\v((ab)*)+', '', ''])
      call add(tl, [2, '\va{1,3}', 'aab', 'aa'])
      call add(tl, [2, '\va{2,3}', 'abaa', 'aa'])

      call add(tl, [2, '\v((ab)+|c*)+', 'abcccaba', 'abcccab', '', 'ab'])
      call add(tl, [2, '\v(a{2})|(b{3})', 'bbabbbb', 'bbb', '', 'bbb'])
      call add(tl, [2, '\va{2}|b{2}', 'abab'])
      call add(tl, [2, '\v(a)+|(c)+', 'bbacbaacbbb', 'a', 'a'])
      call add(tl, [2, '\vab{2,3}c', 'aabbccccccccccccc', 'abbc'])
      call add(tl, [2, '\vab{2,3}c', 'aabbbccccccccccccc', 'abbbc'])
      call add(tl, [2, '\vab{2,3}cd{2,3}e', 'aabbbcddee', 'abbbcdde'])
      call add(tl, [2, '\va(bc){2}d', 'aabcbfbc' ])
      call add(tl, [2, '\va*a{2}', 'a', ])
      call add(tl, [2, '\va*a{2}', 'aa', 'aa' ])
      call add(tl, [2, '\va*a{2}', 'aaa', 'aaa' ])
      call add(tl, [2, '\va*a{2}', 'bbbabcc', ])
      call add(tl, [2, '\va*b*|a*c*', 'a', 'a'])
      call add(tl, [2, '\va{1}b{1}|a{1}b{1}', ''])

      " submatches
      call add(tl, [2, '\v(a)', 'ab', 'a', 'a'])
      call add(tl, [2, '\v(a)(b)', 'ab', 'ab', 'a', 'b'])
      call add(tl, [2, '\v(ab)(b)(c)', 'abbc', 'abbc', 'ab', 'b', 'c'])
      call add(tl, [2, '\v((a)(b))', 'ab', 'ab', 'ab', 'a', 'b'])
      call add(tl, [2, '\v(a)|(b)', 'ab', 'a', 'a'])

      call add(tl, [2, '\v(a*)+', 'aaaa', 'aaaa', ''])
      call add(tl, [2, 'x', 'abcdef'])
    ]])

    -- 
    --      Simple tests 
    -- 

    source([[
      " Search single groups.
      call add(tl, [2, 'ab', 'aab', 'ab'])
      call add(tl, [2, 'ab', 'baced'])
      call add(tl, [2, 'ab', '                    ab           ', 'ab'])

      " Search multi-modifiers.
      call add(tl, [2, 'x*', 'xcd', 'x'])
      call add(tl, [2, 'x*', 'xxxxxxxxxxxxxxxxsofijiojgf', 'xxxxxxxxxxxxxxxx'])
      " Empty match is good.
      call add(tl, [2, 'x*', 'abcdoij', ''])
      " No match here.
      call add(tl, [2, 'x\+', 'abcdoin'])
      call add(tl, [2, 'x\+', 'abcdeoijdfxxiuhfij', 'xx'])
      call add(tl, [2, 'x\+', 'xxxxx', 'xxxxx'])
      call add(tl, [2, 'x\+', 'abc x siufhiush xxxxxxxxx', 'x'])
      call add(tl, [2, 'x\=', 'x sdfoij', 'x'])
      " Empty match is good.
      call add(tl, [2, 'x\=', 'abc sfoij', ''])
      call add(tl, [2, 'x\=', 'xxxxxxxxx c', 'x'])
      call add(tl, [2, 'x\?', 'x sdfoij', 'x'])
      " Empty match is good.
      call add(tl, [2, 'x\?', 'abc sfoij', ''])
      call add(tl, [2, 'x\?', 'xxxxxxxxxx c', 'x'])

      call add(tl, [2, 'a\{0,0}', 'abcdfdoij', ''])
      " Same thing as 'a?'.
      call add(tl, [2, 'a\{0,1}', 'asiubid axxxaaa', 'a'])
      " Same thing as 'a\{0,1}'.
      call add(tl, [2, 'a\{1,0}', 'asiubid axxxaaa', 'a'])
      call add(tl, [2, 'a\{3,6}', 'aa siofuh'])
      call add(tl, [2, 'a\{3,6}', 'aaaaa asfoij afaa', 'aaaaa'])
      call add(tl, [2, 'a\{3,6}', 'aaaaaaaa', 'aaaaaa'])
      call add(tl, [2, 'a\{0}', 'asoiuj', ''])
      call add(tl, [2, 'a\{2}', 'aaaa', 'aa'])
      call add(tl, [2, 'a\{2}', 'iuash fiusahfliusah fiushfilushfi uhsaifuh askfj nasfvius afg aaaa sfiuhuhiushf', 'aa'])
      call add(tl, [2, 'a\{2}', 'abcdefghijklmnopqrestuvwxyz1234567890'])
      " Same thing as 'a*'.
      call add(tl, [2, 'a\{0,}', 'oij sdigfusnf', ''])
      call add(tl, [2, 'a\{0,}', 'aaaaa aa', 'aaaaa'])
      call add(tl, [2, 'a\{2,}', 'sdfiougjdsafg'])
      call add(tl, [2, 'a\{2,}', 'aaaaasfoij ', 'aaaaa'])
      call add(tl, [2, 'a\{5,}', 'xxaaaaxxx '])
      call add(tl, [2, 'a\{5,}', 'xxaaaaaxxx ', 'aaaaa'])
      call add(tl, [2, 'a\{,0}', 'oidfguih iuhi hiu aaaa', ''])
      call add(tl, [2, 'a\{,5}', 'abcd', 'a'])
      call add(tl, [2, 'a\{,5}', 'aaaaaaaaaa', 'aaaaa'])
      " Leading star as normal char when \{} follows.
      call add(tl, [2, '^*\{4,}$', '***'])
      call add(tl, [2, '^*\{4,}$', '****', '****'])
      call add(tl, [2, '^*\{4,}$', '*****', '*****'])
      " Same thing as 'a*'.
      call add(tl, [2, 'a\{}', 'bbbcddiuhfcd', ''])
      call add(tl, [2, 'a\{}', 'aaaaioudfh coisf jda', 'aaaa'])

      call add(tl, [2, 'a\{-0,0}', 'abcdfdoij', ''])
      " Anti-greedy version of 'a?'.
      call add(tl, [2, 'a\{-0,1}', 'asiubid axxxaaa', ''])
      call add(tl, [2, 'a\{-3,6}', 'aa siofuh'])
      call add(tl, [2, 'a\{-3,6}', 'aaaaa asfoij afaa', 'aaa'])
      call add(tl, [2, 'a\{-3,6}', 'aaaaaaaa', 'aaa'])
      call add(tl, [2, 'a\{-0}', 'asoiuj', ''])
      call add(tl, [2, 'a\{-2}', 'aaaa', 'aa'])
      call add(tl, [2, 'a\{-2}', 'abcdefghijklmnopqrestuvwxyz1234567890'])
      call add(tl, [2, 'a\{-0,}', 'oij sdigfusnf', ''])
      call add(tl, [2, 'a\{-0,}', 'aaaaa aa', ''])
      call add(tl, [2, 'a\{-2,}', 'sdfiougjdsafg'])
      call add(tl, [2, 'a\{-2,}', 'aaaaasfoij ', 'aa'])
      call add(tl, [2, 'a\{-,0}', 'oidfguih iuhi hiu aaaa', ''])
      call add(tl, [2, 'a\{-,5}', 'abcd', ''])
      call add(tl, [2, 'a\{-,5}', 'aaaaaaaaaa', ''])
      " Anti-greedy version of 'a*'.
      call add(tl, [2, 'a\{-}', 'bbbcddiuhfcd', ''])
      call add(tl, [2, 'a\{-}', 'aaaaioudfh coisf jda', ''])
    ]])

    -- Test groups of characters and submatches.
    source([[
      call add(tl, [2, '\(abc\)*', 'abcabcabc', 'abcabcabc', 'abc'])
      call add(tl, [2, '\(ab\)\+', 'abababaaaaa', 'ababab', 'ab'])
      call add(tl, [2, '\(abaaaaa\)*cd', 'cd', 'cd', ''])
      call add(tl, [2, '\(test1\)\? \(test2\)\?', 'test1 test3', 'test1 ', 'test1', ''])
      call add(tl, [2, '\(test1\)\= \(test2\) \(test4443\)\=', ' test2 test4443 yupiiiiiiiiiii', ' test2 test4443', '', 'test2', 'test4443'])
      call add(tl, [2, '\(\(sub1\) hello \(sub 2\)\)', 'asterix sub1 hello sub 2 obelix', 'sub1 hello sub 2', 'sub1 hello sub 2', 'sub1', 'sub 2'])
      call add(tl, [2, '\(\(\(yyxxzz\)\)\)', 'abcdddsfiusfyyzzxxyyxxzz', 'yyxxzz', 'yyxxzz', 'yyxxzz', 'yyxxzz'])
      call add(tl, [2, '\v((ab)+|c+)+', 'abcccaba', 'abcccab', 'ab', 'ab'])
      call add(tl, [2, '\v((ab)|c*)+', 'abcccaba', 'abcccab', '', 'ab'])
      call add(tl, [2, '\v(a(c*)+b)+', 'acbababaaa', 'acbabab', 'ab', ''])
      call add(tl, [2, '\v(a|b*)+', 'aaaa', 'aaaa', ''])
      call add(tl, [2, '\p*', 'aá 	', 'aá '])
    ]])

    -- Test greedy-ness and lazy-ness.
    source([[
      call add(tl, [2, 'a\{-2,7}','aaaaaaaaaaaaa', 'aa'])
      call add(tl, [2, 'a\{-2,7}x','aaaaaaaaax', 'aaaaaaax'])
      call add(tl, [2, 'a\{2,7}','aaaaaaaaaaaaaaaaaaaa', 'aaaaaaa'])
      call add(tl, [2, 'a\{2,7}x','aaaaaaaaax', 'aaaaaaax'])
      call add(tl, [2, '\vx(.{-,8})yz(.*)','xayxayzxayzxayz','xayxayzxayzxayz','ayxa','xayzxayz'])
      call add(tl, [2, '\vx(.*)yz(.*)','xayxayzxayzxayz','xayxayzxayzxayz', 'ayxayzxayzxa',''])
      call add(tl, [2, '\v(a{1,2}){-2,3}','aaaaaaa','aaaa','aa'])
      call add(tl, [2, '\v(a{-1,3})+', 'aa', 'aa', 'a'])
      call add(tl, [2, '^\s\{-}\zs\( x\|x$\)', ' x', ' x', ' x'])
      call add(tl, [2, '^\s\{-}\zs\(x\| x$\)', ' x', ' x', ' x'])
      call add(tl, [2, '^\s\{-}\ze\(x\| x$\)', ' x', '', ' x'])
      call add(tl, [2, '^\(\s\{-}\)\(x\| x$\)', ' x', ' x', '', ' x'])
    ]])

    -- Test Character classes.
    execute([[call add(tl, [2, '\d\+e\d\d','test 10e23 fd','10e23'])]])

    -- Test collections and character range [].
    source([=[
      call add(tl, [2, '\v[a]', 'abcd', 'a'])
      call add(tl, [2, 'a[bcd]', 'abcd', 'ab'])
      call add(tl, [2, 'a[b-d]', 'acbd', 'ac'])
      call add(tl, [2, '[a-d][e-f][x-x]d', 'cexdxx', 'cexd'])
      call add(tl, [2, '\v[[:alpha:]]+', 'abcdefghijklmnopqrstuvwxyz6','abcdefghijklmnopqrstuvwxyz'])
      call add(tl, [2, '[[:alpha:]\+]', '6x8','x'])
      call add(tl, [2, '[^abc]\+','abcabcabc'])
      call add(tl, [2, '[^abc]','defghiasijvoinasoiunbvb','d'])
      call add(tl, [2, '[^abc]\+','ddddddda','ddddddd'])
      call add(tl, [2, '[^a-d]\+','aaaAAAZIHFNCddd','AAAZIHFNC'])
      call add(tl, [2, '[a-f]*','iiiiiiii',''])
      call add(tl, [2, '[a-f]*','abcdefgh','abcdef'])
      call add(tl, [2, '[^a-f]\+','abcdefgh','gh'])
      call add(tl, [2, '[a-c]\{-3,6}','abcabc','abc'])
      call add(tl, [2, '[^[:alpha:]]\+','abcccadfoij7787ysf287yrnccdu','7787'])
      call add(tl, [2, '[-a]', '-', '-'])
      call add(tl, [2, '[a-]', '-', '-'])
      call add(tl, [2, '[a-f]*\c','ABCDEFGH','ABCDEF'])
      call add(tl, [2, '[abc][xyz]\c','-af-AF-BY--','BY'])
      " Filename regexp.
      call add(tl, [2, '[-./[:alnum:]_~]\+', 'log13.file', 'log13.file'])
      " Special chars.
      call add(tl, [2, '[\]\^\-\\]\+', '\^\\\-\---^', '\^\\\-\---^'])
      " Collation elem.
      call add(tl, [2, '[[.a.]]\+', 'aa', 'aa'])
      " Middle of regexp.
      call add(tl, [2, 'abc[0-9]*ddd', 'siuhabc ii'])
      call add(tl, [2, 'abc[0-9]*ddd', 'adf abc44482ddd oijs', 'abc44482ddd'])
      call add(tl, [2, '\_[0-9]\+', 'asfi9888u', '9888'])
      call add(tl, [2, '[0-9\n]\+', 'asfi9888u', '9888'])
      call add(tl, [2, '\_[0-9]\+', "asfi\n9888u", "\n9888"])
      call add(tl, [2, '\_f', "  \na ", "\n"])
      call add(tl, [2, '\_f\+', "  \na ", "\na"])
      call add(tl, [2, '[0-9A-Za-z-_.]\+', " @0_a.A-{ ", "0_a.A-"])
    ]=])

    -- """ Test start/end of line, start/end of file.
    source([[
      call add(tl, [2, '^a.', "a_\nb ", "a_"])
      call add(tl, [2, '^a.', "b a \na_"])
      call add(tl, [2, '.a$', " a\n "])
      call add(tl, [2, '.a$', " a b\n_a", "_a"])
      call add(tl, [2, '\%^a.', "a a\na", "a "])
      call add(tl, [2, '\%^a', " a \na "])
      call add(tl, [2, '.a\%$', " a\n "])
      call add(tl, [2, '.a\%$', " a\n_a", "_a"])
    ]])

    -- Test recognition of character classes.
    source([[
      call add(tl, [2, '[0-7]\+', 'x0123456789x', '01234567'])
      call add(tl, [2, '[^0-7]\+', '0a;X+% 897', 'a;X+% 89'])
      call add(tl, [2, '[0-9]\+', 'x0123456789x', '0123456789'])
      call add(tl, [2, '[^0-9]\+', '0a;X+% 9', 'a;X+% '])
      call add(tl, [2, '[0-9a-fA-F]\+', 'x0189abcdefg', '0189abcdef'])
      call add(tl, [2, '[^0-9A-Fa-f]\+', '0189g;X+% ab', 'g;X+% '])
      call add(tl, [2, '[a-z_A-Z0-9]\+', ';+aso_SfOij ', 'aso_SfOij'])
      call add(tl, [2, '[^a-z_A-Z0-9]\+', 'aSo_;+% sfOij', ';+% '])
      call add(tl, [2, '[a-z_A-Z]\+', '0abyz_ABYZ;', 'abyz_ABYZ'])
      call add(tl, [2, '[^a-z_A-Z]\+', 'abAB_09;+% yzYZ', '09;+% '])
      call add(tl, [2, '[a-z]\+', '0abcxyz1', 'abcxyz'])
      call add(tl, [2, '[a-z]\+', 'AabxyzZ', 'abxyz'])
      call add(tl, [2, '[^a-z]\+', 'a;X09+% x', ';X09+% '])
      call add(tl, [2, '[^a-z]\+', 'abX0;%yz', 'X0;%'])
      call add(tl, [2, '[a-zA-Z]\+', '0abABxzXZ9', 'abABxzXZ'])
      call add(tl, [2, '[^a-zA-Z]\+', 'ab09_;+ XZ', '09_;+ '])
      call add(tl, [2, '[A-Z]\+', 'aABXYZz', 'ABXYZ'])
      call add(tl, [2, '[^A-Z]\+', 'ABx0;%YZ', 'x0;%'])
      call add(tl, [2, '[a-z]\+\c', '0abxyzABXYZ;', 'abxyzABXYZ'])
      call add(tl, [2, '[A-Z]\+\c', '0abABxzXZ9', 'abABxzXZ'])
      call add(tl, [2, '\c[^a-z]\+', 'ab09_;+ XZ', '09_;+ '])
      call add(tl, [2, '\c[^A-Z]\+', 'ab09_;+ XZ', '09_;+ '])
      call add(tl, [2, '\C[^A-Z]\+', 'ABCOIJDEOIFNSD jsfoij sa', ' jsfoij sa'])
    ]])

    -- Tests for \z features.
    source([[
      " Match ends at \ze.
      call add(tl, [2, 'xx \ze test', 'xx '])
      call add(tl, [2, 'abc\zeend', 'oij abcend', 'abc'])
      call add(tl, [2, 'aa\zebb\|aaxx', ' aabb ', 'aa'])
      call add(tl, [2, 'aa\zebb\|aaxx', ' aaxx ', 'aaxx'])
      call add(tl, [2, 'aabb\|aa\zebb', ' aabb ', 'aabb'])
      call add(tl, [2, 'aa\zebb\|aaebb', ' aabb ', 'aa'])
      " Match starts at \zs.
      call add(tl, [2, 'abc\zsdd', 'ddabcddxyzt', 'dd'])
      call add(tl, [2, 'aa \zsax', ' ax'])
      call add(tl, [2, 'abc \zsmatch\ze abc', 'abc abc abc match abc abc', 'match'])
      call add(tl, [2, '\v(a \zsif .*){2}', 'a if then a if last', 'if last', 'a if last'])
      call add(tl, [2, '\>\zs.', 'aword. ', '.'])
      call add(tl, [2, '\s\+\ze\[/\|\s\zs\s\+', 'is   [a t', '  '])
    ]])

    -- """ Tests for \@= and \& features.
    source([[
      call add(tl, [2, 'abc\@=', 'abc', 'ab'])
      call add(tl, [2, 'abc\@=cd', 'abcd', 'abcd'])
      call add(tl, [2, 'abc\@=', 'ababc', 'ab'])
      " Will never match, no matter the input text.
      call add(tl, [2, 'abcd\@=e', 'abcd'])
      " Will never match.
      call add(tl, [2, 'abcd\@=e', 'any text in here ... '])
      call add(tl, [2, '\v(abc)@=..', 'xabcd', 'ab', 'abc'])
      call add(tl, [2, '\(.*John\)\@=.*Bob', 'here is John, and here is B'])
      call add(tl, [2, '\(John.*\)\@=.*Bob', 'John is Bobs friend', 'John is Bob', 'John is Bobs friend'])
      call add(tl, [2, '\<\S\+\())\)\@=', '$((i=i+1))', 'i=i+1', '))'])
      call add(tl, [2, '.*John\&.*Bob', 'here is John, and here is B'])
      call add(tl, [2, '.*John\&.*Bob', 'John is Bobs friend', 'John is Bob'])
      call add(tl, [2, '\v(test1)@=.*yep', 'this is a test1, yep it is', 'test1, yep', 'test1'])
      call add(tl, [2, 'foo\(bar\)\@!', 'foobar'])
      call add(tl, [2, 'foo\(bar\)\@!', 'foo bar', 'foo'])
      call add(tl, [2, 'if \(\(then\)\@!.\)*$', ' if then else'])
      call add(tl, [2, 'if \(\(then\)\@!.\)*$', ' if else ', 'if else ', ' '])
      call add(tl, [2, '\(foo\)\@!bar', 'foobar', 'bar'])
      call add(tl, [2, '\(foo\)\@!...bar', 'foobar'])
      call add(tl, [2, '^\%(.*bar\)\@!.*\zsfoo', ' bar foo '])
      call add(tl, [2, '^\%(.*bar\)\@!.*\zsfoo', ' foo bar '])
      call add(tl, [2, '^\%(.*bar\)\@!.*\zsfoo', ' foo xxx ', 'foo'])
      call add(tl, [2, '[ ]\@!\p\%([ ]\@!\p\)*:', 'implicit mappings:', 'mappings:'])
      call add(tl, [2, '[ ]\@!\p\([ ]\@!\p\)*:', 'implicit mappings:', 'mappings:', 's'])
      call add(tl, [2, 'm\k\+_\@=\%(_\@!\k\)\@<=\k\+e', 'mx__xe', 'mx__xe'])
      call add(tl, [2, '\%(\U\@<=S\k*\|S\l\)R', 'SuR', 'SuR'])
    ]])

    -- """ Combining different tests and features.
    execute([=[call add(tl, [2, '[[:alpha:]]\{-2,6}', '787abcdiuhsasiuhb4', 'ab'])]=])
    execute([[call add(tl, [2, '', 'abcd', ''])]])
    execute([[call add(tl, [2, '\v(())', 'any possible text', ''])]])
    execute([[call add(tl, [2, '\v%(ab(xyz)c)', '   abxyzc ', 'abxyzc', 'xyz'])]])
    execute([[call add(tl, [2, '\v(test|)empty', 'tesempty', 'empty', ''])]])
    execute([[call add(tl, [2, '\v(a|aa)(a|aa)', 'aaa', 'aa', 'a', 'a'])]])

    -- """ \%u and friends.
    execute([[call add(tl, [2, '\%d32', 'yes no', ' '])]])
    execute([[call add(tl, [2, '\%o40', 'yes no', ' '])]])
    execute([[call add(tl, [2, '\%x20', 'yes no', ' '])]])
    execute([[call add(tl, [2, '\%u0020', 'yes no', ' '])]])
    execute([[call add(tl, [2, '\%U00000020', 'yes no', ' '])]])
    execute([[call add(tl, [2, '\%d0', "yes\x0ano", "\x0a"])]])

    -- """" \%[abc].
    execute([[call add(tl, [2, 'foo\%[bar]', 'fobar'])]])
    execute([[call add(tl, [2, 'foo\%[bar]', 'foobar', 'foobar'])]])
    execute([[call add(tl, [2, 'foo\%[bar]', 'fooxx', 'foo'])]])
    execute([[call add(tl, [2, 'foo\%[bar]', 'foobxx', 'foob'])]])
    execute([[call add(tl, [2, 'foo\%[bar]', 'foobaxx', 'fooba'])]])
    execute([[call add(tl, [2, 'foo\%[bar]', 'foobarxx', 'foobar'])]])
    execute([[call add(tl, [2, 'foo\%[bar]x', 'foobxx', 'foobx'])]])
    execute([[call add(tl, [2, 'foo\%[bar]x', 'foobarxx', 'foobarx'])]])
    execute([[call add(tl, [2, '\%[bar]x', 'barxx', 'barx'])]])
    execute([[call add(tl, [2, '\%[bar]x', 'bxx', 'bx'])]])
    execute([[call add(tl, [2, '\%[bar]x', 'xxx', 'x'])]])
    execute([[call add(tl, [2, 'b\%[[ao]r]', 'bar bor', 'bar'])]])
    execute([=[call add(tl, [2, 'b\%[[]]r]', 'b]r bor', 'b]r'])]=])
    execute([[call add(tl, [2, '@\%[\w\-]*', '<http://john.net/pandoc/>[@pandoc]', '@pandoc'])]])

    -- """ Alternatives, must use first longest match.
    execute([[call add(tl, [2, 'goo\|go', 'google', 'goo'])]])
    execute([[call add(tl, [2, '\<goo\|\<go', 'google', 'goo'])]])
    execute([[call add(tl, [2, '\<goo\|go', 'google', 'goo'])]])

    -- """ Back references.
    execute([[call add(tl, [2, '\(\i\+\) \1', ' abc abc', 'abc abc', 'abc'])]])
    execute([[call add(tl, [2, '\(\i\+\) \1', 'xgoo goox', 'goo goo', 'goo'])]])
    execute([[call add(tl, [2, '\(a\)\(b\)\(c\)\(dd\)\(e\)\(f\)\(g\)\(h\)\(i\)\1\2\3\4\5\6\7\8\9', 'xabcddefghiabcddefghix', 'abcddefghiabcddefghi', 'a', 'b', 'c', 'dd', 'e', 'f', 'g', 'h', 'i'])]])
    execute([[call add(tl, [2, '\(\d*\)a \1b', ' a b ', 'a b', ''])]])
    execute([[call add(tl, [2, '^.\(.\).\_..\1.', "aaa\naaa\nb", "aaa\naaa", 'a'])]])
    execute([[call add(tl, [2, '^.*\.\(.*\)/.\+\(\1\)\@<!$', 'foo.bat/foo.com', 'foo.bat/foo.com', 'bat'])]])
    execute([[call add(tl, [2, '^.*\.\(.*\)/.\+\(\1\)\@<!$', 'foo.bat/foo.bat'])]])
    execute([[call add(tl, [2, '^.*\.\(.*\)/.\+\(\1\)\@<=$', 'foo.bat/foo.bat', 'foo.bat/foo.bat', 'bat', 'bat'])]])
    execute([[call add(tl, [2, '\\\@<!\${\(\d\+\%(:.\{-}\)\?\\\@<!\)}', '2013-06-27${0}', '${0}', '0'])]])
    execute([[call add(tl, [2, '^\(a*\)\1$', 'aaaaaaaa', 'aaaaaaaa', 'aaaa'])]])
    execute([[call add(tl, [2, '^\(a\{-2,}\)\1\+$', 'aaaaaaaaa', 'aaaaaaaaa', 'aaa'])]])

    -- """ Look-behind with limit.
    execute([[call add(tl, [2, '<\@<=span.', 'xxspanxx<spanyyy', 'spany'])]])
    execute([[call add(tl, [2, '<\@1<=span.', 'xxspanxx<spanyyy', 'spany'])]])
    execute([[call add(tl, [2, '<\@2<=span.', 'xxspanxx<spanyyy', 'spany'])]])
    execute([[call add(tl, [2, '\(<<\)\@<=span.', 'xxspanxxxx<spanxx<<spanyyy', 'spany', '<<'])]])
    execute([[call add(tl, [2, '\(<<\)\@1<=span.', 'xxspanxxxx<spanxx<<spanyyy'])]])
    execute([[call add(tl, [2, '\(<<\)\@2<=span.', 'xxspanxxxx<spanxx<<spanyyy', 'spany', '<<'])]])
    execute([[call add(tl, [2, '\(foo\)\@<!bar.', 'xx foobar1 xbar2 xx', 'bar2'])]])

    -- Look-behind match in front of a zero-width item.
    -- Test header']).
    execute([[call add(tl, [2, '\v\C%(<Last Changed:\s+)@<=.*$', ']])
    -- Last Changed: 1970', '1970']).
    execute([[call add(tl, [2, '\v\C%(<Last Changed:\s+)@<=.*$', ']])
    execute([[call add(tl, [2, '\(foo\)\@<=\>', 'foobar'])]])
    execute([[call add(tl, [2, '\(foo\)\@<=\>', 'barfoo', '', 'foo'])]])
    execute([[call add(tl, [2, '\(foo\)\@<=.*', 'foobar', 'bar', 'foo'])]])

    -- Complicated look-behind match.
    execute([[call add(tl, [2, '\(r\@<=\|\w\@<!\)\/', 'x = /word/;', '/'])]])
    execute([[call add(tl, [2, '^[a-z]\+\ze \&\(asdf\)\@<!', 'foo bar', 'foo'])]])

    -- """" \@>.
    execute([[call add(tl, [2, '\(a*\)\@>a', 'aaaa'])]])
    execute([[call add(tl, [2, '\(a*\)\@>b', 'aaab', 'aaab', 'aaa'])]])
    execute([[call add(tl, [2, '^\(.\{-}b\)\@>.', '  abcbd', '  abc', '  ab'])]])
    execute([[call add(tl, [2, '\(.\{-}\)\(\)\@>$', 'abc', 'abc', 'abc', ''])]])
    -- TODO: BT engine does not restore submatch after failure.
    execute([[call add(tl, [1, '\(a*\)\@>a\|a\+', 'aaaa', 'aaaa'])]])

    -- """ "\_" prepended negated collection matches EOL.
    execute([[call add(tl, [2, '\_[^8-9]\+', "asfi\n9888", "asfi\n"])]])
    execute([[call add(tl, [2, '\_[^a]\+', "asfi\n9888", "sfi\n9888"])]])

    -- """ Requiring lots of states.
    execute([[call add(tl, [2, '[0-9a-zA-Z]\{8}-\([0-9a-zA-Z]\{4}-\)\{3}[0-9a-zA-Z]\{12}', " 12345678-1234-1234-1234-123456789012 ", "12345678-1234-1234-1234-123456789012", "1234-"])]])

    -- """ Skip adding state twice.
    execute([[call add(tl, [2, '^\%(\%(^\s*#\s*if\>\|#\s*if\)\)\(\%>1c.*$\)\@=', "#if FOO", "#if", ' FOO'])]])

    -- "" Test \%V atom.
    execute([[call add(tl, [2, '\%>70vGesamt', 'Jean-Michel Charlier & Victor Hubinon\Gesamtausgabe [Salleck]    Buck Danny {Jean-Michel Charlier & Victor Hubinon}\Gesamtausgabe', 'Gesamt'])]])

    -- """ Run the tests.

    source([[
      for t in tl
        let re = t[0]
        let pat = t[1]
        let text = t[2]
        let matchidx = 3
        for engine in [0, 1, 2]
          if engine == 2 && re == 0 || engine == 1 && re == 1
            continue
          endif
          let &regexpengine = engine
          try
            let l = matchlist(text, pat)
          catch
            $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", caused an exception: \"' . v:exception . '\"'
          endtry
	  " Check the match itself.
          if len(l) == 0 && len(t) > matchidx
            $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", did not match, expected: \"' . t[matchidx] . '\"'
          elseif len(l) > 0 && len(t) == matchidx
            $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", match: \"' . l[0] . '\", expected no match'
          elseif len(t) > matchidx && l[0] != t[matchidx]
            $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", match: \"' . l[0] . '\", expected: \"' . t[matchidx] . '\"'
          else
            $put ='OK ' . engine . ' - ' . pat
          endif
          if len(l) > 0
	  " Check all the nine submatches.
            for i in range(1, 9)
              if len(t) <= matchidx + i
                let e = ''
              else
                let e = t[matchidx + i]
              endif
              if l[i] != e
                $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", submatch ' . i . ': \"' . l[i] . '\", expected: \"' . e . '\"'
              endif
            endfor
            unlet i
          endif
        endfor
      endfor
      unlet t tl e l
    ]])

    -- """"" multi-line tests """""""""""""""""""".
    execute('let tl = []')

    -- """ back references.
    execute([=[call add(tl, [2, '^.\(.\).\_..\1.', ['aaa', 'aaa', 'b'], ['XX', 'b']])]=])
    execute([=[call add(tl, [2, '\v.*\/(.*)\n.*\/\1$', ['./Dir1/Dir2/zyxwvuts.txt', './Dir1/Dir2/abcdefgh.bat', '', './Dir1/Dir2/file1.txt', './OtherDir1/OtherDir2/file1.txt'], ['./Dir1/Dir2/zyxwvuts.txt', './Dir1/Dir2/abcdefgh.bat', '', 'XX']])]=])

    -- """ line breaks.
    execute([=[call add(tl, [2, '\S.*\nx', ['abc', 'def', 'ghi', 'xjk', 'lmn'], ['abc', 'def', 'XXjk', 'lmn']])]=])

    -- Check that \_[0-9] matching EOL does not break a following \>.
    execute([=[call add(tl, [2, '\<\(\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\.\)\{3\}\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\>', ['', 'localnet/192.168.0.1', ''], ['', 'localnet/XX', '']])]=])

    -- Check a pattern with a line break and ^ and $.
    execute([=[call add(tl, [2, 'a\n^b$\n^c', ['a', 'b', 'c'], ['XX']])]=])

    execute([=[call add(tl, [2, '\(^.\+\n\)\1', [' dog', ' dog', 'asdf'], ['XXasdf']])]=])

    -- """ Run the multi-line tests.

    execute([[$put ='multi-line tests']])
    execute('for t in tl')
    execute('  let re = t[0]')
    execute('  let pat = t[1]')
    execute('  let before = t[2]')
    execute('  let after = t[3]')
    execute('  for engine in [0, 1, 2]')
    execute('    if engine == 2 && re == 0 || engine == 1 && re ==1')
    execute('      continue')
    execute('    endif')
    execute('    let &regexpengine = engine')
    execute('    new')
    execute('    call setline(1, before)')
    execute([[    exe '%s/' . pat . '/XX/']])
    execute([[    let result = getline(1, '$')]])
    execute('    q!')
    execute('    if result != after')
    execute([[      $put ='ERROR: pat: \"' . pat . '\", text: \"' . string(before) . '\", expected: \"' . string(after) . '\", got: \"' . string(result) . '\"']])
    execute('    else')
    execute([[      $put ='OK ' . engine . ' - ' . pat]])
    execute('    endif')
    execute('  endfor')
    execute('endfor')
    execute('unlet t tl')

    -- Check that using a pattern on two lines doesn't get messed up by using.
    -- Matchstr() with \ze in between.
    execute('set re=0')
    execute('/^Substitute here')
    execute([[.+1,.+2s/""/\='"'.matchstr(getline("."), '\d\+\ze<').'"']])
    execute('/^Substitute here')
    execute('.+1,.+2yank')

    feed('Go<esc>p')

    -- Check a pattern with a look beind crossing a line boundary.
    execute('/^Behind:')
    execute([[/\(<\_[xy]\+\)\@3<=start]])
    execute('.yank')

    feed('Go<esc>p')

    -- Check matching Visual area.
    execute('/^Visual:')
    feed('jfxvfx')
    execute([[s/\%Ve/E/g]])
    feed('jV')
    execute([[s/\%Va/A/g]])
    feed('jfx<C-V>fxj')
    execute([[s/\%Vo/O/g]])
    execute(':/^Visual/+1,/^Visual/+4yank')

    feed('Go<esc>p')

    -- Check matching marks.
    execute('/^Marks:')
    feed('jfSmsfEme')
    execute([[.-4,.+6s/.\%>'s.*\%<'e../here/]])
    feed('jfSmsj0fEme')
    execute([[.-4,.+6s/.\%>'s\_.*\%<'e../again/]])
    execute(':/^Marks:/+1,/^Marks:/+3yank')

    feed('Go<esc>p')

    -- Check patterns matching cursor position.
    -- TODO: is the line cont OK?
    source([[
      func! Postest()
        new
        call setline(1, ['ffooooo', 'boboooo', 'zoooooo', 'koooooo',
	  \ 'moooooo', "\t\t\tfoo", 'abababababababfoo', 'bababababababafoo',
	  \ '********_'])
        call setpos('.', [0, 1, 0, 0])
        s/\%>3c.//g
        call setpos('.', [0, 2, 4, 0])
        s/\%#.*$//g
        call setpos('.', [0, 3, 0, 0])
        s/\%<3c./_/g
        %s/\%4l\%>5c./_/g
        %s/\%6l\%>25v./_/g
        %s/\%>6l\%3c./!/g
        %s/\%>7l\%12c./?/g
        %s/\%>7l\%<9l\%>5v\%<8v./#/g
        1,$yank
        quit!
      endfunc
    ]])
    feed('Go-0-<esc>')
    execute('set re=0')
    execute('call Postest()')
    execute('put')
    feed('o-1-<esc>')
    execute('set re=1')
    execute('call Postest()')
    execute('put')
    feed('o-2-<esc>')
    execute('set re=2')
    execute('call Postest()')
    execute('put')

    -- Start and end of buffer.
    execute([[/\%^]])

    feed('yeGo<esc>p')
    feed('50%')
    execute([[/\%^..]])

    feed('yeGo<esc>pA END<esc>')
    feed('50%')
    execute([[/\%$]])
    feed('ayb20gg')
    execute([[/..\%$]])
    feed('"bybGo<esc>"apo<esc>"bp')

    -- Check for detecting error.
    source([=[
      set regexpengine=2
      for pat in [' \ze*', ' \zs*']
        try
          let l = matchlist('x x', pat)
          $put ='E888 NOT detected for ' . pat
        catch
          $put ='E888 detected for ' . pat
        endtry
      endfor
    ]=])

    -- Prepare buffer for expect()
    execute([[0,/\%#=1^Results/-1 delete]])

    -- Assert buffer contents.
    expect([=[
      Results of test64:
      OK 0 - ab
      OK 1 - ab
      OK 2 - ab
      OK 0 - b
      OK 1 - b
      OK 2 - b
      OK 0 - bc*
      OK 1 - bc*
      OK 2 - bc*
      OK 0 - bc\{-}
      OK 1 - bc\{-}
      OK 2 - bc\{-}
      OK 0 - bc\{-}\(d\)
      OK 1 - bc\{-}\(d\)
      OK 2 - bc\{-}\(d\)
      OK 0 - bc*
      OK 1 - bc*
      OK 2 - bc*
      OK 0 - c*
      OK 1 - c*
      OK 2 - c*
      OK 0 - bc*
      OK 1 - bc*
      OK 2 - bc*
      OK 0 - c*
      OK 1 - c*
      OK 2 - c*
      OK 0 - bc\+
      OK 1 - bc\+
      OK 2 - bc\+
      OK 0 - bc\+
      OK 1 - bc\+
      OK 2 - bc\+
      OK 0 - a\|ab
      OK 1 - a\|ab
      OK 2 - a\|ab
      OK 0 - c\?
      OK 1 - c\?
      OK 2 - c\?
      OK 0 - bc\?
      OK 1 - bc\?
      OK 2 - bc\?
      OK 0 - bc\?
      OK 1 - bc\?
      OK 2 - bc\?
      OK 0 - \va{1}
      OK 1 - \va{1}
      OK 2 - \va{1}
      OK 0 - \va{2}
      OK 1 - \va{2}
      OK 2 - \va{2}
      OK 0 - \va{2}
      OK 1 - \va{2}
      OK 2 - \va{2}
      OK 0 - \va{2}
      OK 1 - \va{2}
      OK 2 - \va{2}
      OK 0 - \va{2}
      OK 1 - \va{2}
      OK 2 - \va{2}
      OK 0 - \va{2}
      OK 1 - \va{2}
      OK 2 - \va{2}
      OK 0 - \va{2}
      OK 1 - \va{2}
      OK 2 - \va{2}
      OK 0 - \vb{1}
      OK 1 - \vb{1}
      OK 2 - \vb{1}
      OK 0 - \vba{2}
      OK 1 - \vba{2}
      OK 2 - \vba{2}
      OK 0 - \vba{3}
      OK 1 - \vba{3}
      OK 2 - \vba{3}
      OK 0 - \v(ab){1}
      OK 1 - \v(ab){1}
      OK 2 - \v(ab){1}
      OK 0 - \v(ab){1}
      OK 1 - \v(ab){1}
      OK 2 - \v(ab){1}
      OK 0 - \v(ab){1}
      OK 1 - \v(ab){1}
      OK 2 - \v(ab){1}
      OK 0 - \v(ab){0,2}
      OK 1 - \v(ab){0,2}
      OK 2 - \v(ab){0,2}
      OK 0 - \v(ab){0,2}
      OK 1 - \v(ab){0,2}
      OK 2 - \v(ab){0,2}
      OK 0 - \v(ab){1,2}
      OK 1 - \v(ab){1,2}
      OK 2 - \v(ab){1,2}
      OK 0 - \v(ab){1,2}
      OK 1 - \v(ab){1,2}
      OK 2 - \v(ab){1,2}
      OK 0 - \v(ab){2,4}
      OK 1 - \v(ab){2,4}
      OK 2 - \v(ab){2,4}
      OK 0 - \v(ab){2,4}
      OK 1 - \v(ab){2,4}
      OK 2 - \v(ab){2,4}
      OK 0 - \v(ab){2}
      OK 1 - \v(ab){2}
      OK 2 - \v(ab){2}
      OK 0 - \v(ab){2}
      OK 1 - \v(ab){2}
      OK 2 - \v(ab){2}
      OK 0 - \v(ab){2}
      OK 1 - \v(ab){2}
      OK 2 - \v(ab){2}
      OK 0 - \v(ab){2}
      OK 1 - \v(ab){2}
      OK 2 - \v(ab){2}
      OK 0 - \v((ab){2}){2}
      OK 1 - \v((ab){2}){2}
      OK 2 - \v((ab){2}){2}
      OK 0 - \v((ab){2}){2}
      OK 1 - \v((ab){2}){2}
      OK 2 - \v((ab){2}){2}
      OK 0 - \v(a{1}){1}
      OK 1 - \v(a{1}){1}
      OK 2 - \v(a{1}){1}
      OK 0 - \v(a{2}){1}
      OK 1 - \v(a{2}){1}
      OK 2 - \v(a{2}){1}
      OK 0 - \v(a{2}){1}
      OK 1 - \v(a{2}){1}
      OK 2 - \v(a{2}){1}
      OK 0 - \v(a{2}){1}
      OK 1 - \v(a{2}){1}
      OK 2 - \v(a{2}){1}
      OK 0 - \v(a{1}){2}
      OK 1 - \v(a{1}){2}
      OK 2 - \v(a{1}){2}
      OK 0 - \v(a{1}){2}
      OK 1 - \v(a{1}){2}
      OK 2 - \v(a{1}){2}
      OK 0 - \v(a{2})+
      OK 1 - \v(a{2})+
      OK 2 - \v(a{2})+
      OK 0 - \v(a{2})+
      OK 1 - \v(a{2})+
      OK 2 - \v(a{2})+
      OK 0 - \v(a{2}){1}
      OK 1 - \v(a{2}){1}
      OK 2 - \v(a{2}){1}
      OK 0 - \v(a{1}){2}
      OK 1 - \v(a{1}){2}
      OK 2 - \v(a{1}){2}
      OK 0 - \v(a{1}){1}
      OK 1 - \v(a{1}){1}
      OK 2 - \v(a{1}){1}
      OK 0 - \v(a{2}){2}
      OK 1 - \v(a{2}){2}
      OK 2 - \v(a{2}){2}
      OK 0 - \v(a{2}){2}
      OK 1 - \v(a{2}){2}
      OK 2 - \v(a{2}){2}
      OK 0 - \v(a+){2}
      OK 1 - \v(a+){2}
      OK 2 - \v(a+){2}
      OK 0 - \v(a{3}){2}
      OK 1 - \v(a{3}){2}
      OK 2 - \v(a{3}){2}
      OK 0 - \v(a{1,2}){2}
      OK 1 - \v(a{1,2}){2}
      OK 2 - \v(a{1,2}){2}
      OK 0 - \v(a{1,3}){2}
      OK 1 - \v(a{1,3}){2}
      OK 2 - \v(a{1,3}){2}
      OK 0 - \v(a{1,3}){2}
      OK 1 - \v(a{1,3}){2}
      OK 2 - \v(a{1,3}){2}
      OK 0 - \v(a{1,3}){3}
      OK 1 - \v(a{1,3}){3}
      OK 2 - \v(a{1,3}){3}
      OK 0 - \v(a{1,2}){2}
      OK 1 - \v(a{1,2}){2}
      OK 2 - \v(a{1,2}){2}
      OK 0 - \v(a+)+
      OK 1 - \v(a+)+
      OK 2 - \v(a+)+
      OK 0 - \v(a+)+
      OK 1 - \v(a+)+
      OK 2 - \v(a+)+
      OK 0 - \v(a+){1,2}
      OK 1 - \v(a+){1,2}
      OK 2 - \v(a+){1,2}
      OK 0 - \v(a+)(a+)
      OK 1 - \v(a+)(a+)
      OK 2 - \v(a+)(a+)
      OK 0 - \v(a{3})+
      OK 1 - \v(a{3})+
      OK 2 - \v(a{3})+
      OK 0 - \v(a|b|c)+
      OK 1 - \v(a|b|c)+
      OK 2 - \v(a|b|c)+
      OK 0 - \v(a|b|c){2}
      OK 1 - \v(a|b|c){2}
      OK 2 - \v(a|b|c){2}
      OK 0 - \v(abc){2}
      OK 1 - \v(abc){2}
      OK 2 - \v(abc){2}
      OK 0 - \v(abc){2}
      OK 1 - \v(abc){2}
      OK 2 - \v(abc){2}
      OK 0 - a*
      OK 1 - a*
      OK 2 - a*
      OK 0 - \v(a*)+
      OK 1 - \v(a*)+
      OK 2 - \v(a*)+
      OK 0 - \v((ab)+)+
      OK 1 - \v((ab)+)+
      OK 2 - \v((ab)+)+
      OK 0 - \v(((ab)+)+)+
      OK 1 - \v(((ab)+)+)+
      OK 2 - \v(((ab)+)+)+
      OK 0 - \v(((ab)+)+)+
      OK 1 - \v(((ab)+)+)+
      OK 2 - \v(((ab)+)+)+
      OK 0 - \v(a{0,2})+
      OK 1 - \v(a{0,2})+
      OK 2 - \v(a{0,2})+
      OK 0 - \v(a*)+
      OK 1 - \v(a*)+
      OK 2 - \v(a*)+
      OK 0 - \v((a*)+)+
      OK 1 - \v((a*)+)+
      OK 2 - \v((a*)+)+
      OK 0 - \v((ab)*)+
      OK 1 - \v((ab)*)+
      OK 2 - \v((ab)*)+
      OK 0 - \va{1,3}
      OK 1 - \va{1,3}
      OK 2 - \va{1,3}
      OK 0 - \va{2,3}
      OK 1 - \va{2,3}
      OK 2 - \va{2,3}
      OK 0 - \v((ab)+|c*)+
      OK 1 - \v((ab)+|c*)+
      OK 2 - \v((ab)+|c*)+
      OK 0 - \v(a{2})|(b{3})
      OK 1 - \v(a{2})|(b{3})
      OK 2 - \v(a{2})|(b{3})
      OK 0 - \va{2}|b{2}
      OK 1 - \va{2}|b{2}
      OK 2 - \va{2}|b{2}
      OK 0 - \v(a)+|(c)+
      OK 1 - \v(a)+|(c)+
      OK 2 - \v(a)+|(c)+
      OK 0 - \vab{2,3}c
      OK 1 - \vab{2,3}c
      OK 2 - \vab{2,3}c
      OK 0 - \vab{2,3}c
      OK 1 - \vab{2,3}c
      OK 2 - \vab{2,3}c
      OK 0 - \vab{2,3}cd{2,3}e
      OK 1 - \vab{2,3}cd{2,3}e
      OK 2 - \vab{2,3}cd{2,3}e
      OK 0 - \va(bc){2}d
      OK 1 - \va(bc){2}d
      OK 2 - \va(bc){2}d
      OK 0 - \va*a{2}
      OK 1 - \va*a{2}
      OK 2 - \va*a{2}
      OK 0 - \va*a{2}
      OK 1 - \va*a{2}
      OK 2 - \va*a{2}
      OK 0 - \va*a{2}
      OK 1 - \va*a{2}
      OK 2 - \va*a{2}
      OK 0 - \va*a{2}
      OK 1 - \va*a{2}
      OK 2 - \va*a{2}
      OK 0 - \va*b*|a*c*
      OK 1 - \va*b*|a*c*
      OK 2 - \va*b*|a*c*
      OK 0 - \va{1}b{1}|a{1}b{1}
      OK 1 - \va{1}b{1}|a{1}b{1}
      OK 2 - \va{1}b{1}|a{1}b{1}
      OK 0 - \v(a)
      OK 1 - \v(a)
      OK 2 - \v(a)
      OK 0 - \v(a)(b)
      OK 1 - \v(a)(b)
      OK 2 - \v(a)(b)
      OK 0 - \v(ab)(b)(c)
      OK 1 - \v(ab)(b)(c)
      OK 2 - \v(ab)(b)(c)
      OK 0 - \v((a)(b))
      OK 1 - \v((a)(b))
      OK 2 - \v((a)(b))
      OK 0 - \v(a)|(b)
      OK 1 - \v(a)|(b)
      OK 2 - \v(a)|(b)
      OK 0 - \v(a*)+
      OK 1 - \v(a*)+
      OK 2 - \v(a*)+
      OK 0 - x
      OK 1 - x
      OK 2 - x
      OK 0 - ab
      OK 1 - ab
      OK 2 - ab
      OK 0 - ab
      OK 1 - ab
      OK 2 - ab
      OK 0 - ab
      OK 1 - ab
      OK 2 - ab
      OK 0 - x*
      OK 1 - x*
      OK 2 - x*
      OK 0 - x*
      OK 1 - x*
      OK 2 - x*
      OK 0 - x*
      OK 1 - x*
      OK 2 - x*
      OK 0 - x\+
      OK 1 - x\+
      OK 2 - x\+
      OK 0 - x\+
      OK 1 - x\+
      OK 2 - x\+
      OK 0 - x\+
      OK 1 - x\+
      OK 2 - x\+
      OK 0 - x\+
      OK 1 - x\+
      OK 2 - x\+
      OK 0 - x\=
      OK 1 - x\=
      OK 2 - x\=
      OK 0 - x\=
      OK 1 - x\=
      OK 2 - x\=
      OK 0 - x\=
      OK 1 - x\=
      OK 2 - x\=
      OK 0 - x\?
      OK 1 - x\?
      OK 2 - x\?
      OK 0 - x\?
      OK 1 - x\?
      OK 2 - x\?
      OK 0 - x\?
      OK 1 - x\?
      OK 2 - x\?
      OK 0 - a\{0,0}
      OK 1 - a\{0,0}
      OK 2 - a\{0,0}
      OK 0 - a\{0,1}
      OK 1 - a\{0,1}
      OK 2 - a\{0,1}
      OK 0 - a\{1,0}
      OK 1 - a\{1,0}
      OK 2 - a\{1,0}
      OK 0 - a\{3,6}
      OK 1 - a\{3,6}
      OK 2 - a\{3,6}
      OK 0 - a\{3,6}
      OK 1 - a\{3,6}
      OK 2 - a\{3,6}
      OK 0 - a\{3,6}
      OK 1 - a\{3,6}
      OK 2 - a\{3,6}
      OK 0 - a\{0}
      OK 1 - a\{0}
      OK 2 - a\{0}
      OK 0 - a\{2}
      OK 1 - a\{2}
      OK 2 - a\{2}
      OK 0 - a\{2}
      OK 1 - a\{2}
      OK 2 - a\{2}
      OK 0 - a\{2}
      OK 1 - a\{2}
      OK 2 - a\{2}
      OK 0 - a\{0,}
      OK 1 - a\{0,}
      OK 2 - a\{0,}
      OK 0 - a\{0,}
      OK 1 - a\{0,}
      OK 2 - a\{0,}
      OK 0 - a\{2,}
      OK 1 - a\{2,}
      OK 2 - a\{2,}
      OK 0 - a\{2,}
      OK 1 - a\{2,}
      OK 2 - a\{2,}
      OK 0 - a\{5,}
      OK 1 - a\{5,}
      OK 2 - a\{5,}
      OK 0 - a\{5,}
      OK 1 - a\{5,}
      OK 2 - a\{5,}
      OK 0 - a\{,0}
      OK 1 - a\{,0}
      OK 2 - a\{,0}
      OK 0 - a\{,5}
      OK 1 - a\{,5}
      OK 2 - a\{,5}
      OK 0 - a\{,5}
      OK 1 - a\{,5}
      OK 2 - a\{,5}
      OK 0 - ^*\{4,}$
      OK 1 - ^*\{4,}$
      OK 2 - ^*\{4,}$
      OK 0 - ^*\{4,}$
      OK 1 - ^*\{4,}$
      OK 2 - ^*\{4,}$
      OK 0 - ^*\{4,}$
      OK 1 - ^*\{4,}$
      OK 2 - ^*\{4,}$
      OK 0 - a\{}
      OK 1 - a\{}
      OK 2 - a\{}
      OK 0 - a\{}
      OK 1 - a\{}
      OK 2 - a\{}
      OK 0 - a\{-0,0}
      OK 1 - a\{-0,0}
      OK 2 - a\{-0,0}
      OK 0 - a\{-0,1}
      OK 1 - a\{-0,1}
      OK 2 - a\{-0,1}
      OK 0 - a\{-3,6}
      OK 1 - a\{-3,6}
      OK 2 - a\{-3,6}
      OK 0 - a\{-3,6}
      OK 1 - a\{-3,6}
      OK 2 - a\{-3,6}
      OK 0 - a\{-3,6}
      OK 1 - a\{-3,6}
      OK 2 - a\{-3,6}
      OK 0 - a\{-0}
      OK 1 - a\{-0}
      OK 2 - a\{-0}
      OK 0 - a\{-2}
      OK 1 - a\{-2}
      OK 2 - a\{-2}
      OK 0 - a\{-2}
      OK 1 - a\{-2}
      OK 2 - a\{-2}
      OK 0 - a\{-0,}
      OK 1 - a\{-0,}
      OK 2 - a\{-0,}
      OK 0 - a\{-0,}
      OK 1 - a\{-0,}
      OK 2 - a\{-0,}
      OK 0 - a\{-2,}
      OK 1 - a\{-2,}
      OK 2 - a\{-2,}
      OK 0 - a\{-2,}
      OK 1 - a\{-2,}
      OK 2 - a\{-2,}
      OK 0 - a\{-,0}
      OK 1 - a\{-,0}
      OK 2 - a\{-,0}
      OK 0 - a\{-,5}
      OK 1 - a\{-,5}
      OK 2 - a\{-,5}
      OK 0 - a\{-,5}
      OK 1 - a\{-,5}
      OK 2 - a\{-,5}
      OK 0 - a\{-}
      OK 1 - a\{-}
      OK 2 - a\{-}
      OK 0 - a\{-}
      OK 1 - a\{-}
      OK 2 - a\{-}
      OK 0 - \(abc\)*
      OK 1 - \(abc\)*
      OK 2 - \(abc\)*
      OK 0 - \(ab\)\+
      OK 1 - \(ab\)\+
      OK 2 - \(ab\)\+
      OK 0 - \(abaaaaa\)*cd
      OK 1 - \(abaaaaa\)*cd
      OK 2 - \(abaaaaa\)*cd
      OK 0 - \(test1\)\? \(test2\)\?
      OK 1 - \(test1\)\? \(test2\)\?
      OK 2 - \(test1\)\? \(test2\)\?
      OK 0 - \(test1\)\= \(test2\) \(test4443\)\=
      OK 1 - \(test1\)\= \(test2\) \(test4443\)\=
      OK 2 - \(test1\)\= \(test2\) \(test4443\)\=
      OK 0 - \(\(sub1\) hello \(sub 2\)\)
      OK 1 - \(\(sub1\) hello \(sub 2\)\)
      OK 2 - \(\(sub1\) hello \(sub 2\)\)
      OK 0 - \(\(\(yyxxzz\)\)\)
      OK 1 - \(\(\(yyxxzz\)\)\)
      OK 2 - \(\(\(yyxxzz\)\)\)
      OK 0 - \v((ab)+|c+)+
      OK 1 - \v((ab)+|c+)+
      OK 2 - \v((ab)+|c+)+
      OK 0 - \v((ab)|c*)+
      OK 1 - \v((ab)|c*)+
      OK 2 - \v((ab)|c*)+
      OK 0 - \v(a(c*)+b)+
      OK 1 - \v(a(c*)+b)+
      OK 2 - \v(a(c*)+b)+
      OK 0 - \v(a|b*)+
      OK 1 - \v(a|b*)+
      OK 2 - \v(a|b*)+
      OK 0 - \p*
      OK 1 - \p*
      OK 2 - \p*
      OK 0 - a\{-2,7}
      OK 1 - a\{-2,7}
      OK 2 - a\{-2,7}
      OK 0 - a\{-2,7}x
      OK 1 - a\{-2,7}x
      OK 2 - a\{-2,7}x
      OK 0 - a\{2,7}
      OK 1 - a\{2,7}
      OK 2 - a\{2,7}
      OK 0 - a\{2,7}x
      OK 1 - a\{2,7}x
      OK 2 - a\{2,7}x
      OK 0 - \vx(.{-,8})yz(.*)
      OK 1 - \vx(.{-,8})yz(.*)
      OK 2 - \vx(.{-,8})yz(.*)
      OK 0 - \vx(.*)yz(.*)
      OK 1 - \vx(.*)yz(.*)
      OK 2 - \vx(.*)yz(.*)
      OK 0 - \v(a{1,2}){-2,3}
      OK 1 - \v(a{1,2}){-2,3}
      OK 2 - \v(a{1,2}){-2,3}
      OK 0 - \v(a{-1,3})+
      OK 1 - \v(a{-1,3})+
      OK 2 - \v(a{-1,3})+
      OK 0 - ^\s\{-}\zs\( x\|x$\)
      OK 1 - ^\s\{-}\zs\( x\|x$\)
      OK 2 - ^\s\{-}\zs\( x\|x$\)
      OK 0 - ^\s\{-}\zs\(x\| x$\)
      OK 1 - ^\s\{-}\zs\(x\| x$\)
      OK 2 - ^\s\{-}\zs\(x\| x$\)
      OK 0 - ^\s\{-}\ze\(x\| x$\)
      OK 1 - ^\s\{-}\ze\(x\| x$\)
      OK 2 - ^\s\{-}\ze\(x\| x$\)
      OK 0 - ^\(\s\{-}\)\(x\| x$\)
      OK 1 - ^\(\s\{-}\)\(x\| x$\)
      OK 2 - ^\(\s\{-}\)\(x\| x$\)
      OK 0 - \d\+e\d\d
      OK 1 - \d\+e\d\d
      OK 2 - \d\+e\d\d
      OK 0 - \v[a]
      OK 1 - \v[a]
      OK 2 - \v[a]
      OK 0 - a[bcd]
      OK 1 - a[bcd]
      OK 2 - a[bcd]
      OK 0 - a[b-d]
      OK 1 - a[b-d]
      OK 2 - a[b-d]
      OK 0 - [a-d][e-f][x-x]d
      OK 1 - [a-d][e-f][x-x]d
      OK 2 - [a-d][e-f][x-x]d
      OK 0 - \v[[:alpha:]]+
      OK 1 - \v[[:alpha:]]+
      OK 2 - \v[[:alpha:]]+
      OK 0 - [[:alpha:]\+]
      OK 1 - [[:alpha:]\+]
      OK 2 - [[:alpha:]\+]
      OK 0 - [^abc]\+
      OK 1 - [^abc]\+
      OK 2 - [^abc]\+
      OK 0 - [^abc]
      OK 1 - [^abc]
      OK 2 - [^abc]
      OK 0 - [^abc]\+
      OK 1 - [^abc]\+
      OK 2 - [^abc]\+
      OK 0 - [^a-d]\+
      OK 1 - [^a-d]\+
      OK 2 - [^a-d]\+
      OK 0 - [a-f]*
      OK 1 - [a-f]*
      OK 2 - [a-f]*
      OK 0 - [a-f]*
      OK 1 - [a-f]*
      OK 2 - [a-f]*
      OK 0 - [^a-f]\+
      OK 1 - [^a-f]\+
      OK 2 - [^a-f]\+
      OK 0 - [a-c]\{-3,6}
      OK 1 - [a-c]\{-3,6}
      OK 2 - [a-c]\{-3,6}
      OK 0 - [^[:alpha:]]\+
      OK 1 - [^[:alpha:]]\+
      OK 2 - [^[:alpha:]]\+
      OK 0 - [-a]
      OK 1 - [-a]
      OK 2 - [-a]
      OK 0 - [a-]
      OK 1 - [a-]
      OK 2 - [a-]
      OK 0 - [a-f]*\c
      OK 1 - [a-f]*\c
      OK 2 - [a-f]*\c
      OK 0 - [abc][xyz]\c
      OK 1 - [abc][xyz]\c
      OK 2 - [abc][xyz]\c
      OK 0 - [-./[:alnum:]_~]\+
      OK 1 - [-./[:alnum:]_~]\+
      OK 2 - [-./[:alnum:]_~]\+
      OK 0 - [\]\^\-\\]\+
      OK 1 - [\]\^\-\\]\+
      OK 2 - [\]\^\-\\]\+
      OK 0 - [[.a.]]\+
      OK 1 - [[.a.]]\+
      OK 2 - [[.a.]]\+
      OK 0 - abc[0-9]*ddd
      OK 1 - abc[0-9]*ddd
      OK 2 - abc[0-9]*ddd
      OK 0 - abc[0-9]*ddd
      OK 1 - abc[0-9]*ddd
      OK 2 - abc[0-9]*ddd
      OK 0 - \_[0-9]\+
      OK 1 - \_[0-9]\+
      OK 2 - \_[0-9]\+
      OK 0 - [0-9\n]\+
      OK 1 - [0-9\n]\+
      OK 2 - [0-9\n]\+
      OK 0 - \_[0-9]\+
      OK 1 - \_[0-9]\+
      OK 2 - \_[0-9]\+
      OK 0 - \_f
      OK 1 - \_f
      OK 2 - \_f
      OK 0 - \_f\+
      OK 1 - \_f\+
      OK 2 - \_f\+
      OK 0 - [0-9A-Za-z-_.]\+
      OK 1 - [0-9A-Za-z-_.]\+
      OK 2 - [0-9A-Za-z-_.]\+
      OK 0 - ^a.
      OK 1 - ^a.
      OK 2 - ^a.
      OK 0 - ^a.
      OK 1 - ^a.
      OK 2 - ^a.
      OK 0 - .a$
      OK 1 - .a$
      OK 2 - .a$
      OK 0 - .a$
      OK 1 - .a$
      OK 2 - .a$
      OK 0 - \%^a.
      OK 1 - \%^a.
      OK 2 - \%^a.
      OK 0 - \%^a
      OK 1 - \%^a
      OK 2 - \%^a
      OK 0 - .a\%$
      OK 1 - .a\%$
      OK 2 - .a\%$
      OK 0 - .a\%$
      OK 1 - .a\%$
      OK 2 - .a\%$
      OK 0 - [0-7]\+
      OK 1 - [0-7]\+
      OK 2 - [0-7]\+
      OK 0 - [^0-7]\+
      OK 1 - [^0-7]\+
      OK 2 - [^0-7]\+
      OK 0 - [0-9]\+
      OK 1 - [0-9]\+
      OK 2 - [0-9]\+
      OK 0 - [^0-9]\+
      OK 1 - [^0-9]\+
      OK 2 - [^0-9]\+
      OK 0 - [0-9a-fA-F]\+
      OK 1 - [0-9a-fA-F]\+
      OK 2 - [0-9a-fA-F]\+
      OK 0 - [^0-9A-Fa-f]\+
      OK 1 - [^0-9A-Fa-f]\+
      OK 2 - [^0-9A-Fa-f]\+
      OK 0 - [a-z_A-Z0-9]\+
      OK 1 - [a-z_A-Z0-9]\+
      OK 2 - [a-z_A-Z0-9]\+
      OK 0 - [^a-z_A-Z0-9]\+
      OK 1 - [^a-z_A-Z0-9]\+
      OK 2 - [^a-z_A-Z0-9]\+
      OK 0 - [a-z_A-Z]\+
      OK 1 - [a-z_A-Z]\+
      OK 2 - [a-z_A-Z]\+
      OK 0 - [^a-z_A-Z]\+
      OK 1 - [^a-z_A-Z]\+
      OK 2 - [^a-z_A-Z]\+
      OK 0 - [a-z]\+
      OK 1 - [a-z]\+
      OK 2 - [a-z]\+
      OK 0 - [a-z]\+
      OK 1 - [a-z]\+
      OK 2 - [a-z]\+
      OK 0 - [^a-z]\+
      OK 1 - [^a-z]\+
      OK 2 - [^a-z]\+
      OK 0 - [^a-z]\+
      OK 1 - [^a-z]\+
      OK 2 - [^a-z]\+
      OK 0 - [a-zA-Z]\+
      OK 1 - [a-zA-Z]\+
      OK 2 - [a-zA-Z]\+
      OK 0 - [^a-zA-Z]\+
      OK 1 - [^a-zA-Z]\+
      OK 2 - [^a-zA-Z]\+
      OK 0 - [A-Z]\+
      OK 1 - [A-Z]\+
      OK 2 - [A-Z]\+
      OK 0 - [^A-Z]\+
      OK 1 - [^A-Z]\+
      OK 2 - [^A-Z]\+
      OK 0 - [a-z]\+\c
      OK 1 - [a-z]\+\c
      OK 2 - [a-z]\+\c
      OK 0 - [A-Z]\+\c
      OK 1 - [A-Z]\+\c
      OK 2 - [A-Z]\+\c
      OK 0 - \c[^a-z]\+
      OK 1 - \c[^a-z]\+
      OK 2 - \c[^a-z]\+
      OK 0 - \c[^A-Z]\+
      OK 1 - \c[^A-Z]\+
      OK 2 - \c[^A-Z]\+
      OK 0 - \C[^A-Z]\+
      OK 1 - \C[^A-Z]\+
      OK 2 - \C[^A-Z]\+
      OK 0 - xx \ze test
      OK 1 - xx \ze test
      OK 2 - xx \ze test
      OK 0 - abc\zeend
      OK 1 - abc\zeend
      OK 2 - abc\zeend
      OK 0 - aa\zebb\|aaxx
      OK 1 - aa\zebb\|aaxx
      OK 2 - aa\zebb\|aaxx
      OK 0 - aa\zebb\|aaxx
      OK 1 - aa\zebb\|aaxx
      OK 2 - aa\zebb\|aaxx
      OK 0 - aabb\|aa\zebb
      OK 1 - aabb\|aa\zebb
      OK 2 - aabb\|aa\zebb
      OK 0 - aa\zebb\|aaebb
      OK 1 - aa\zebb\|aaebb
      OK 2 - aa\zebb\|aaebb
      OK 0 - abc\zsdd
      OK 1 - abc\zsdd
      OK 2 - abc\zsdd
      OK 0 - aa \zsax
      OK 1 - aa \zsax
      OK 2 - aa \zsax
      OK 0 - abc \zsmatch\ze abc
      OK 1 - abc \zsmatch\ze abc
      OK 2 - abc \zsmatch\ze abc
      OK 0 - \v(a \zsif .*){2}
      OK 1 - \v(a \zsif .*){2}
      OK 2 - \v(a \zsif .*){2}
      OK 0 - \>\zs.
      OK 1 - \>\zs.
      OK 2 - \>\zs.
      OK 0 - \s\+\ze\[/\|\s\zs\s\+
      OK 1 - \s\+\ze\[/\|\s\zs\s\+
      OK 2 - \s\+\ze\[/\|\s\zs\s\+
      OK 0 - abc\@=
      OK 1 - abc\@=
      OK 2 - abc\@=
      OK 0 - abc\@=cd
      OK 1 - abc\@=cd
      OK 2 - abc\@=cd
      OK 0 - abc\@=
      OK 1 - abc\@=
      OK 2 - abc\@=
      OK 0 - abcd\@=e
      OK 1 - abcd\@=e
      OK 2 - abcd\@=e
      OK 0 - abcd\@=e
      OK 1 - abcd\@=e
      OK 2 - abcd\@=e
      OK 0 - \v(abc)@=..
      OK 1 - \v(abc)@=..
      OK 2 - \v(abc)@=..
      OK 0 - \(.*John\)\@=.*Bob
      OK 1 - \(.*John\)\@=.*Bob
      OK 2 - \(.*John\)\@=.*Bob
      OK 0 - \(John.*\)\@=.*Bob
      OK 1 - \(John.*\)\@=.*Bob
      OK 2 - \(John.*\)\@=.*Bob
      OK 0 - \<\S\+\())\)\@=
      OK 1 - \<\S\+\())\)\@=
      OK 2 - \<\S\+\())\)\@=
      OK 0 - .*John\&.*Bob
      OK 1 - .*John\&.*Bob
      OK 2 - .*John\&.*Bob
      OK 0 - .*John\&.*Bob
      OK 1 - .*John\&.*Bob
      OK 2 - .*John\&.*Bob
      OK 0 - \v(test1)@=.*yep
      OK 1 - \v(test1)@=.*yep
      OK 2 - \v(test1)@=.*yep
      OK 0 - foo\(bar\)\@!
      OK 1 - foo\(bar\)\@!
      OK 2 - foo\(bar\)\@!
      OK 0 - foo\(bar\)\@!
      OK 1 - foo\(bar\)\@!
      OK 2 - foo\(bar\)\@!
      OK 0 - if \(\(then\)\@!.\)*$
      OK 1 - if \(\(then\)\@!.\)*$
      OK 2 - if \(\(then\)\@!.\)*$
      OK 0 - if \(\(then\)\@!.\)*$
      OK 1 - if \(\(then\)\@!.\)*$
      OK 2 - if \(\(then\)\@!.\)*$
      OK 0 - \(foo\)\@!bar
      OK 1 - \(foo\)\@!bar
      OK 2 - \(foo\)\@!bar
      OK 0 - \(foo\)\@!...bar
      OK 1 - \(foo\)\@!...bar
      OK 2 - \(foo\)\@!...bar
      OK 0 - ^\%(.*bar\)\@!.*\zsfoo
      OK 1 - ^\%(.*bar\)\@!.*\zsfoo
      OK 2 - ^\%(.*bar\)\@!.*\zsfoo
      OK 0 - ^\%(.*bar\)\@!.*\zsfoo
      OK 1 - ^\%(.*bar\)\@!.*\zsfoo
      OK 2 - ^\%(.*bar\)\@!.*\zsfoo
      OK 0 - ^\%(.*bar\)\@!.*\zsfoo
      OK 1 - ^\%(.*bar\)\@!.*\zsfoo
      OK 2 - ^\%(.*bar\)\@!.*\zsfoo
      OK 0 - [ ]\@!\p\%([ ]\@!\p\)*:
      OK 1 - [ ]\@!\p\%([ ]\@!\p\)*:
      OK 2 - [ ]\@!\p\%([ ]\@!\p\)*:
      OK 0 - [ ]\@!\p\([ ]\@!\p\)*:
      OK 1 - [ ]\@!\p\([ ]\@!\p\)*:
      OK 2 - [ ]\@!\p\([ ]\@!\p\)*:
      OK 0 - m\k\+_\@=\%(_\@!\k\)\@<=\k\+e
      OK 1 - m\k\+_\@=\%(_\@!\k\)\@<=\k\+e
      OK 2 - m\k\+_\@=\%(_\@!\k\)\@<=\k\+e
      OK 0 - \%(\U\@<=S\k*\|S\l\)R
      OK 1 - \%(\U\@<=S\k*\|S\l\)R
      OK 2 - \%(\U\@<=S\k*\|S\l\)R
      OK 0 - [[:alpha:]]\{-2,6}
      OK 1 - [[:alpha:]]\{-2,6}
      OK 2 - [[:alpha:]]\{-2,6}
      OK 0 - 
      OK 1 - 
      OK 2 - 
      OK 0 - \v(())
      OK 1 - \v(())
      OK 2 - \v(())
      OK 0 - \v%(ab(xyz)c)
      OK 1 - \v%(ab(xyz)c)
      OK 2 - \v%(ab(xyz)c)
      OK 0 - \v(test|)empty
      OK 1 - \v(test|)empty
      OK 2 - \v(test|)empty
      OK 0 - \v(a|aa)(a|aa)
      OK 1 - \v(a|aa)(a|aa)
      OK 2 - \v(a|aa)(a|aa)
      OK 0 - \%d32
      OK 1 - \%d32
      OK 2 - \%d32
      OK 0 - \%o40
      OK 1 - \%o40
      OK 2 - \%o40
      OK 0 - \%x20
      OK 1 - \%x20
      OK 2 - \%x20
      OK 0 - \%u0020
      OK 1 - \%u0020
      OK 2 - \%u0020
      OK 0 - \%U00000020
      OK 1 - \%U00000020
      OK 2 - \%U00000020
      OK 0 - \%d0
      OK 1 - \%d0
      OK 2 - \%d0
      OK 0 - foo\%[bar]
      OK 1 - foo\%[bar]
      OK 2 - foo\%[bar]
      OK 0 - foo\%[bar]
      OK 1 - foo\%[bar]
      OK 2 - foo\%[bar]
      OK 0 - foo\%[bar]
      OK 1 - foo\%[bar]
      OK 2 - foo\%[bar]
      OK 0 - foo\%[bar]
      OK 1 - foo\%[bar]
      OK 2 - foo\%[bar]
      OK 0 - foo\%[bar]
      OK 1 - foo\%[bar]
      OK 2 - foo\%[bar]
      OK 0 - foo\%[bar]
      OK 1 - foo\%[bar]
      OK 2 - foo\%[bar]
      OK 0 - foo\%[bar]x
      OK 1 - foo\%[bar]x
      OK 2 - foo\%[bar]x
      OK 0 - foo\%[bar]x
      OK 1 - foo\%[bar]x
      OK 2 - foo\%[bar]x
      OK 0 - \%[bar]x
      OK 1 - \%[bar]x
      OK 2 - \%[bar]x
      OK 0 - \%[bar]x
      OK 1 - \%[bar]x
      OK 2 - \%[bar]x
      OK 0 - \%[bar]x
      OK 1 - \%[bar]x
      OK 2 - \%[bar]x
      OK 0 - b\%[[ao]r]
      OK 1 - b\%[[ao]r]
      OK 2 - b\%[[ao]r]
      OK 0 - b\%[[]]r]
      OK 1 - b\%[[]]r]
      OK 2 - b\%[[]]r]
      OK 0 - @\%[\w\-]*
      OK 1 - @\%[\w\-]*
      OK 2 - @\%[\w\-]*
      OK 0 - goo\|go
      OK 1 - goo\|go
      OK 2 - goo\|go
      OK 0 - \<goo\|\<go
      OK 1 - \<goo\|\<go
      OK 2 - \<goo\|\<go
      OK 0 - \<goo\|go
      OK 1 - \<goo\|go
      OK 2 - \<goo\|go
      OK 0 - \(\i\+\) \1
      OK 1 - \(\i\+\) \1
      OK 2 - \(\i\+\) \1
      OK 0 - \(\i\+\) \1
      OK 1 - \(\i\+\) \1
      OK 2 - \(\i\+\) \1
      OK 0 - \(a\)\(b\)\(c\)\(dd\)\(e\)\(f\)\(g\)\(h\)\(i\)\1\2\3\4\5\6\7\8\9
      OK 1 - \(a\)\(b\)\(c\)\(dd\)\(e\)\(f\)\(g\)\(h\)\(i\)\1\2\3\4\5\6\7\8\9
      OK 2 - \(a\)\(b\)\(c\)\(dd\)\(e\)\(f\)\(g\)\(h\)\(i\)\1\2\3\4\5\6\7\8\9
      OK 0 - \(\d*\)a \1b
      OK 1 - \(\d*\)a \1b
      OK 2 - \(\d*\)a \1b
      OK 0 - ^.\(.\).\_..\1.
      OK 1 - ^.\(.\).\_..\1.
      OK 2 - ^.\(.\).\_..\1.
      OK 0 - ^.*\.\(.*\)/.\+\(\1\)\@<!$
      OK 1 - ^.*\.\(.*\)/.\+\(\1\)\@<!$
      OK 2 - ^.*\.\(.*\)/.\+\(\1\)\@<!$
      OK 0 - ^.*\.\(.*\)/.\+\(\1\)\@<!$
      OK 1 - ^.*\.\(.*\)/.\+\(\1\)\@<!$
      OK 2 - ^.*\.\(.*\)/.\+\(\1\)\@<!$
      OK 0 - ^.*\.\(.*\)/.\+\(\1\)\@<=$
      OK 1 - ^.*\.\(.*\)/.\+\(\1\)\@<=$
      OK 2 - ^.*\.\(.*\)/.\+\(\1\)\@<=$
      OK 0 - \\\@<!\${\(\d\+\%(:.\{-}\)\?\\\@<!\)}
      OK 1 - \\\@<!\${\(\d\+\%(:.\{-}\)\?\\\@<!\)}
      OK 2 - \\\@<!\${\(\d\+\%(:.\{-}\)\?\\\@<!\)}
      OK 0 - ^\(a*\)\1$
      OK 1 - ^\(a*\)\1$
      OK 2 - ^\(a*\)\1$
      OK 0 - ^\(a\{-2,}\)\1\+$
      OK 1 - ^\(a\{-2,}\)\1\+$
      OK 2 - ^\(a\{-2,}\)\1\+$
      OK 0 - <\@<=span.
      OK 1 - <\@<=span.
      OK 2 - <\@<=span.
      OK 0 - <\@1<=span.
      OK 1 - <\@1<=span.
      OK 2 - <\@1<=span.
      OK 0 - <\@2<=span.
      OK 1 - <\@2<=span.
      OK 2 - <\@2<=span.
      OK 0 - \(<<\)\@<=span.
      OK 1 - \(<<\)\@<=span.
      OK 2 - \(<<\)\@<=span.
      OK 0 - \(<<\)\@1<=span.
      OK 1 - \(<<\)\@1<=span.
      OK 2 - \(<<\)\@1<=span.
      OK 0 - \(<<\)\@2<=span.
      OK 1 - \(<<\)\@2<=span.
      OK 2 - \(<<\)\@2<=span.
      OK 0 - \(foo\)\@<!bar.
      OK 1 - \(foo\)\@<!bar.
      OK 2 - \(foo\)\@<!bar.
      OK 0 - \v\C%(<Last Changed:\s+)@<=.*$
      OK 1 - \v\C%(<Last Changed:\s+)@<=.*$
      OK 2 - \v\C%(<Last Changed:\s+)@<=.*$
      OK 0 - \v\C%(<Last Changed:\s+)@<=.*$
      OK 1 - \v\C%(<Last Changed:\s+)@<=.*$
      OK 2 - \v\C%(<Last Changed:\s+)@<=.*$
      OK 0 - \(foo\)\@<=\>
      OK 1 - \(foo\)\@<=\>
      OK 2 - \(foo\)\@<=\>
      OK 0 - \(foo\)\@<=\>
      OK 1 - \(foo\)\@<=\>
      OK 2 - \(foo\)\@<=\>
      OK 0 - \(foo\)\@<=.*
      OK 1 - \(foo\)\@<=.*
      OK 2 - \(foo\)\@<=.*
      OK 0 - \(r\@<=\|\w\@<!\)\/
      OK 1 - \(r\@<=\|\w\@<!\)\/
      OK 2 - \(r\@<=\|\w\@<!\)\/
      OK 0 - ^[a-z]\+\ze \&\(asdf\)\@<!
      OK 1 - ^[a-z]\+\ze \&\(asdf\)\@<!
      OK 2 - ^[a-z]\+\ze \&\(asdf\)\@<!
      OK 0 - \(a*\)\@>a
      OK 1 - \(a*\)\@>a
      OK 2 - \(a*\)\@>a
      OK 0 - \(a*\)\@>b
      OK 1 - \(a*\)\@>b
      OK 2 - \(a*\)\@>b
      OK 0 - ^\(.\{-}b\)\@>.
      OK 1 - ^\(.\{-}b\)\@>.
      OK 2 - ^\(.\{-}b\)\@>.
      OK 0 - \(.\{-}\)\(\)\@>$
      OK 1 - \(.\{-}\)\(\)\@>$
      OK 2 - \(.\{-}\)\(\)\@>$
      OK 0 - \(a*\)\@>a\|a\+
      OK 2 - \(a*\)\@>a\|a\+
      OK 0 - \_[^8-9]\+
      OK 1 - \_[^8-9]\+
      OK 2 - \_[^8-9]\+
      OK 0 - \_[^a]\+
      OK 1 - \_[^a]\+
      OK 2 - \_[^a]\+
      OK 0 - [0-9a-zA-Z]\{8}-\([0-9a-zA-Z]\{4}-\)\{3}[0-9a-zA-Z]\{12}
      OK 1 - [0-9a-zA-Z]\{8}-\([0-9a-zA-Z]\{4}-\)\{3}[0-9a-zA-Z]\{12}
      OK 2 - [0-9a-zA-Z]\{8}-\([0-9a-zA-Z]\{4}-\)\{3}[0-9a-zA-Z]\{12}
      OK 0 - ^\%(\%(^\s*#\s*if\>\|#\s*if\)\)\(\%>1c.*$\)\@=
      OK 1 - ^\%(\%(^\s*#\s*if\>\|#\s*if\)\)\(\%>1c.*$\)\@=
      OK 2 - ^\%(\%(^\s*#\s*if\>\|#\s*if\)\)\(\%>1c.*$\)\@=
      OK 0 - \%>70vGesamt
      OK 1 - \%>70vGesamt
      OK 2 - \%>70vGesamt
      multi-line tests
      OK 0 - ^.\(.\).\_..\1.
      OK 1 - ^.\(.\).\_..\1.
      OK 2 - ^.\(.\).\_..\1.
      OK 0 - \v.*\/(.*)\n.*\/\1$
      OK 1 - \v.*\/(.*)\n.*\/\1$
      OK 2 - \v.*\/(.*)\n.*\/\1$
      OK 0 - \S.*\nx
      OK 1 - \S.*\nx
      OK 2 - \S.*\nx
      OK 0 - \<\(\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\.\)\{3\}\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\>
      OK 1 - \<\(\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\.\)\{3\}\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\>
      OK 2 - \<\(\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\.\)\{3\}\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[01]\?\_[0-9]\_[0-9]\?\)\>
      OK 0 - a\n^b$\n^c
      OK 1 - a\n^b$\n^c
      OK 2 - a\n^b$\n^c
      OK 0 - \(^.\+\n\)\1
      OK 1 - \(^.\+\n\)\1
      OK 2 - \(^.\+\n\)\1
      
      <T="5">Ta 5</Title>
      <T="7">Ac 7</Title>
      
      xxstart3
      
      thexE thE thExethe
      AndAxAnd AndAxAnd
      oooxOfOr fOrOxooo
      oooxOfOr fOrOxooo
      
      asdfhereasdf
      asdfagainasdf
      
      -0-
      ffo
      bob
      __ooooo
      koooo__
      moooooo
      			f__
      ab!babababababfoo
      ba!ab##abab?bafoo
      **!*****_
      -1-
      ffo
      bob
      __ooooo
      koooo__
      moooooo
      			f__
      ab!babababababfoo
      ba!ab##abab?bafoo
      **!*****_
      -2-
      ffo
      bob
      __ooooo
      koooo__
      moooooo
      			f__
      ab!babababababfoo
      ba!ab##abab?bafoo
      **!*****_
      Test
      Test END
      EN
      E
      E888 detected for  \ze*
      E888 detected for  \zs*]=])
  end)
end)
