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

    -- """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""".
    -- """ Previously written tests """""""""""""""""""""""""""""""".
    -- """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""".

    execute([=[call add(tl, [2, 'ab', 'aab', 'ab'])]=])
    execute([=[call add(tl, [2, 'b', 'abcdef', 'b'])]=])
    execute([=[call add(tl, [2, 'bc*', 'abccccdef', 'bcccc'])]=])
    execute([=[call add(tl, [2, 'bc\{-}', 'abccccdef', 'b'])]=])
    execute([=[call add(tl, [2, 'bc\{-}\(d\)', 'abccccdef', 'bccccd', 'd'])]=])
    execute([=[call add(tl, [2, 'bc*', 'abbdef', 'b'])]=])
    execute([=[call add(tl, [2, 'c*', 'ccc', 'ccc'])]=])
    execute([=[call add(tl, [2, 'bc*', 'abdef', 'b'])]=])
    execute([=[call add(tl, [2, 'c*', 'abdef', ''])]=])
    execute([=[call add(tl, [2, 'bc\+', 'abccccdef', 'bcccc'])]=])
    -- No match.
    execute([=[call add(tl, [2, 'bc\+', 'abdef'])]=])

    -- Operator \|.
    -- Alternation is ordered.
    execute([=[call add(tl, [2, 'a\|ab', 'cabd', 'a'])]=])

    execute([=[call add(tl, [2, 'c\?', 'ccb', 'c'])]=])
    execute([=[call add(tl, [2, 'bc\?', 'abd', 'b'])]=])
    execute([=[call add(tl, [2, 'bc\?', 'abccd', 'bc'])]=])

    execute([=[call add(tl, [2, '\va{1}', 'ab', 'a'])]=])

    execute([=[call add(tl, [2, '\va{2}', 'aa', 'aa'])]=])
    execute([=[call add(tl, [2, '\va{2}', 'caad', 'aa'])]=])
    execute([=[call add(tl, [2, '\va{2}', 'aba'])]=])
    execute([=[call add(tl, [2, '\va{2}', 'ab'])]=])
    execute([=[call add(tl, [2, '\va{2}', 'abaa', 'aa'])]=])
    execute([=[call add(tl, [2, '\va{2}', 'aaa', 'aa'])]=])

    execute([=[call add(tl, [2, '\vb{1}', 'abca', 'b'])]=])
    execute([=[call add(tl, [2, '\vba{2}', 'abaa', 'baa'])]=])
    execute([=[call add(tl, [2, '\vba{3}', 'aabaac'])]=])

    execute([=[call add(tl, [2, '\v(ab){1}', 'ab', 'ab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(ab){1}', 'dabc', 'ab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(ab){1}', 'acb'])]=])

    execute([=[call add(tl, [2, '\v(ab){0,2}', 'acb', "", ""])]=])
    execute([=[call add(tl, [2, '\v(ab){0,2}', 'ab', 'ab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(ab){1,2}', 'ab', 'ab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(ab){1,2}', 'ababc', 'abab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(ab){2,4}', 'ababcab', 'abab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(ab){2,4}', 'abcababa', 'abab', 'ab'])]=])

    execute([=[call add(tl, [2, '\v(ab){2}', 'abab', 'abab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(ab){2}', 'cdababe', 'abab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(ab){2}', 'abac'])]=])
    execute([=[call add(tl, [2, '\v(ab){2}', 'abacabab', 'abab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v((ab){2}){2}', 'abababab', 'abababab', 'abab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v((ab){2}){2}', 'abacabababab', 'abababab', 'abab', 'ab'])]=])

    execute([=[call add(tl, [2, '\v(a{1}){1}', 'a', 'a', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a{2}){1}', 'aa', 'aa', 'aa'])]=])
    execute([=[call add(tl, [2, '\v(a{2}){1}', 'aaac', 'aa', 'aa'])]=])
    execute([=[call add(tl, [2, '\v(a{2}){1}', 'daaac', 'aa', 'aa'])]=])
    execute([=[call add(tl, [2, '\v(a{1}){2}', 'daaac', 'aa', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a{1}){2}', 'aaa', 'aa', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a{2})+', 'adaac', 'aa', 'aa'])]=])
    execute([=[call add(tl, [2, '\v(a{2})+', 'aa', 'aa', 'aa'])]=])
    execute([=[call add(tl, [2, '\v(a{2}){1}', 'aa', 'aa', 'aa'])]=])
    execute([=[call add(tl, [2, '\v(a{1}){2}', 'aa', 'aa', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a{1}){1}', 'a', 'a', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a{2}){2}', 'aaaa', 'aaaa', 'aa'])]=])
    execute([=[call add(tl, [2, '\v(a{2}){2}', 'aaabaaaa', 'aaaa', 'aa'])]=])

    execute([=[call add(tl, [2, '\v(a+){2}', 'dadaac', 'aa', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a{3}){2}', 'aaaaaaa', 'aaaaaa', 'aaa'])]=])

    execute([=[call add(tl, [2, '\v(a{1,2}){2}', 'daaac', 'aaa', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a{1,3}){2}', 'daaaac', 'aaaa', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a{1,3}){2}', 'daaaaac', 'aaaaa', 'aa'])]=])
    execute([=[call add(tl, [2, '\v(a{1,3}){3}', 'daac'])]=])
    execute([=[call add(tl, [2, '\v(a{1,2}){2}', 'dac'])]=])
    execute([=[call add(tl, [2, '\v(a+)+', 'daac', 'aa', 'aa'])]=])
    execute([=[call add(tl, [2, '\v(a+)+', 'aaa', 'aaa', 'aaa'])]=])
    execute([=[call add(tl, [2, '\v(a+){1,2}', 'aaa', 'aaa', 'aaa'])]=])
    execute([=[call add(tl, [2, '\v(a+)(a+)', 'aaa', 'aaa', 'aa', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a{3})+', 'daaaac', 'aaa', 'aaa'])]=])
    execute([=[call add(tl, [2, '\v(a|b|c)+', 'aacb', 'aacb', 'b'])]=])
    execute([=[call add(tl, [2, '\v(a|b|c){2}', 'abcb', 'ab', 'b'])]=])
    execute([=[call add(tl, [2, '\v(abc){2}', 'abcabd', ])]=])
    execute([=[call add(tl, [2, '\v(abc){2}', 'abdabcabc','abcabc', 'abc'])]=])

    execute([=[call add(tl, [2, 'a*', 'cc', ''])]=])
    execute([=[call add(tl, [2, '\v(a*)+', 'cc', ''])]=])
    execute([=[call add(tl, [2, '\v((ab)+)+', 'ab', 'ab', 'ab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(((ab)+)+)+', 'ab', 'ab', 'ab', 'ab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(((ab)+)+)+', 'dababc', 'abab', 'abab', 'abab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(a{0,2})+', 'cc', ''])]=])
    execute([=[call add(tl, [2, '\v(a*)+', '', ''])]=])
    execute([=[call add(tl, [2, '\v((a*)+)+', '', ''])]=])
    execute([=[call add(tl, [2, '\v((ab)*)+', '', ''])]=])
    execute([=[call add(tl, [2, '\va{1,3}', 'aab', 'aa'])]=])
    execute([=[call add(tl, [2, '\va{2,3}', 'abaa', 'aa'])]=])

    execute([=[call add(tl, [2, '\v((ab)+|c*)+', 'abcccaba', 'abcccab', '', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(a{2})|(b{3})', 'bbabbbb', 'bbb', '', 'bbb'])]=])
    execute([=[call add(tl, [2, '\va{2}|b{2}', 'abab'])]=])
    execute([=[call add(tl, [2, '\v(a)+|(c)+', 'bbacbaacbbb', 'a', 'a'])]=])
    execute([=[call add(tl, [2, '\vab{2,3}c', 'aabbccccccccccccc', 'abbc'])]=])
    execute([=[call add(tl, [2, '\vab{2,3}c', 'aabbbccccccccccccc', 'abbbc'])]=])
    execute([=[call add(tl, [2, '\vab{2,3}cd{2,3}e', 'aabbbcddee', 'abbbcdde'])]=])
    execute([=[call add(tl, [2, '\va(bc){2}d', 'aabcbfbc' ])]=])
    execute([=[call add(tl, [2, '\va*a{2}', 'a', ])]=])
    execute([=[call add(tl, [2, '\va*a{2}', 'aa', 'aa' ])]=])
    execute([=[call add(tl, [2, '\va*a{2}', 'aaa', 'aaa' ])]=])
    execute([=[call add(tl, [2, '\va*a{2}', 'bbbabcc', ])]=])
    execute([=[call add(tl, [2, '\va*b*|a*c*', 'a', 'a'])]=])
    execute([=[call add(tl, [2, '\va{1}b{1}|a{1}b{1}', ''])]=])

    -- Submatches.
    execute([=[call add(tl, [2, '\v(a)', 'ab', 'a', 'a'])]=])
    execute([=[call add(tl, [2, '\v(a)(b)', 'ab', 'ab', 'a', 'b'])]=])
    execute([=[call add(tl, [2, '\v(ab)(b)(c)', 'abbc', 'abbc', 'ab', 'b', 'c'])]=])
    execute([=[call add(tl, [2, '\v((a)(b))', 'ab', 'ab', 'ab', 'a', 'b'])]=])
    execute([=[call add(tl, [2, '\v(a)|(b)', 'ab', 'a', 'a'])]=])

    execute([=[call add(tl, [2, '\v(a*)+', 'aaaa', 'aaaa', ''])]=])
    execute([=[call add(tl, [2, 'x', 'abcdef'])]=])

    -- """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""".
    -- """" Simple tests """"""""""""""""""""""""""""""""""""""""""".
    -- """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""".

    -- Search single groups.
    execute([=[call add(tl, [2, 'ab', 'aab', 'ab'])]=])
    execute([=[call add(tl, [2, 'ab', 'baced'])]=])
    execute([=[call add(tl, [2, 'ab', '                    ab           ', 'ab'])]=])

    -- Search multi-modifiers.
    execute([=[call add(tl, [2, 'x*', 'xcd', 'x'])]=])
    execute([=[call add(tl, [2, 'x*', 'xxxxxxxxxxxxxxxxsofijiojgf', 'xxxxxxxxxxxxxxxx'])]=])
    -- Empty match is good.
    execute([=[call add(tl, [2, 'x*', 'abcdoij', ''])]=])
    -- No match here.
    execute([=[call add(tl, [2, 'x\+', 'abcdoin'])]=])
    execute([=[call add(tl, [2, 'x\+', 'abcdeoijdfxxiuhfij', 'xx'])]=])
    execute([=[call add(tl, [2, 'x\+', 'xxxxx', 'xxxxx'])]=])
    execute([=[call add(tl, [2, 'x\+', 'abc x siufhiush xxxxxxxxx', 'x'])]=])
    execute([=[call add(tl, [2, 'x\=', 'x sdfoij', 'x'])]=])
    -- Empty match is good.
    execute([=[call add(tl, [2, 'x\=', 'abc sfoij', ''])]=])
    execute([=[call add(tl, [2, 'x\=', 'xxxxxxxxx c', 'x'])]=])
    execute([=[call add(tl, [2, 'x\?', 'x sdfoij', 'x'])]=])
    -- Empty match is good.
    execute([=[call add(tl, [2, 'x\?', 'abc sfoij', ''])]=])
    execute([=[call add(tl, [2, 'x\?', 'xxxxxxxxxx c', 'x'])]=])

    execute([=[call add(tl, [2, 'a\{0,0}', 'abcdfdoij', ''])]=])
    -- Same thing as 'a?'.
    execute([=[call add(tl, [2, 'a\{0,1}', 'asiubid axxxaaa', 'a'])]=])
    -- Same thing as 'a\{0,1}'.
    execute([=[call add(tl, [2, 'a\{1,0}', 'asiubid axxxaaa', 'a'])]=])
    execute([=[call add(tl, [2, 'a\{3,6}', 'aa siofuh'])]=])
    execute([=[call add(tl, [2, 'a\{3,6}', 'aaaaa asfoij afaa', 'aaaaa'])]=])
    execute([=[call add(tl, [2, 'a\{3,6}', 'aaaaaaaa', 'aaaaaa'])]=])
    execute([=[call add(tl, [2, 'a\{0}', 'asoiuj', ''])]=])
    execute([=[call add(tl, [2, 'a\{2}', 'aaaa', 'aa'])]=])
    execute([=[call add(tl, [2, 'a\{2}', 'iuash fiusahfliusah fiushfilushfi uhsaifuh askfj nasfvius afg aaaa sfiuhuhiushf', 'aa'])]=])
    execute([=[call add(tl, [2, 'a\{2}', 'abcdefghijklmnopqrestuvwxyz1234567890'])]=])
    -- Same thing as 'a*'.
    execute([=[call add(tl, [2, 'a\{0,}', 'oij sdigfusnf', ''])]=])
    execute([=[call add(tl, [2, 'a\{0,}', 'aaaaa aa', 'aaaaa'])]=])
    execute([=[call add(tl, [2, 'a\{2,}', 'sdfiougjdsafg'])]=])
    execute([=[call add(tl, [2, 'a\{2,}', 'aaaaasfoij ', 'aaaaa'])]=])
    execute([=[call add(tl, [2, 'a\{5,}', 'xxaaaaxxx '])]=])
    execute([=[call add(tl, [2, 'a\{5,}', 'xxaaaaaxxx ', 'aaaaa'])]=])
    execute([=[call add(tl, [2, 'a\{,0}', 'oidfguih iuhi hiu aaaa', ''])]=])
    execute([=[call add(tl, [2, 'a\{,5}', 'abcd', 'a'])]=])
    execute([=[call add(tl, [2, 'a\{,5}', 'aaaaaaaaaa', 'aaaaa'])]=])
    -- Leading star as normal char when \{} follows.
    execute([=[call add(tl, [2, '^*\{4,}$', '***'])]=])
    execute([=[call add(tl, [2, '^*\{4,}$', '****', '****'])]=])
    execute([=[call add(tl, [2, '^*\{4,}$', '*****', '*****'])]=])
    -- Same thing as 'a*'.
    execute([=[call add(tl, [2, 'a\{}', 'bbbcddiuhfcd', ''])]=])
    execute([=[call add(tl, [2, 'a\{}', 'aaaaioudfh coisf jda', 'aaaa'])]=])

    execute([=[call add(tl, [2, 'a\{-0,0}', 'abcdfdoij', ''])]=])
    -- Anti-greedy version of 'a?'.
    execute([=[call add(tl, [2, 'a\{-0,1}', 'asiubid axxxaaa', ''])]=])
    execute([=[call add(tl, [2, 'a\{-3,6}', 'aa siofuh'])]=])
    execute([=[call add(tl, [2, 'a\{-3,6}', 'aaaaa asfoij afaa', 'aaa'])]=])
    execute([=[call add(tl, [2, 'a\{-3,6}', 'aaaaaaaa', 'aaa'])]=])
    execute([=[call add(tl, [2, 'a\{-0}', 'asoiuj', ''])]=])
    execute([=[call add(tl, [2, 'a\{-2}', 'aaaa', 'aa'])]=])
    execute([=[call add(tl, [2, 'a\{-2}', 'abcdefghijklmnopqrestuvwxyz1234567890'])]=])
    execute([=[call add(tl, [2, 'a\{-0,}', 'oij sdigfusnf', ''])]=])
    execute([=[call add(tl, [2, 'a\{-0,}', 'aaaaa aa', ''])]=])
    execute([=[call add(tl, [2, 'a\{-2,}', 'sdfiougjdsafg'])]=])
    execute([=[call add(tl, [2, 'a\{-2,}', 'aaaaasfoij ', 'aa'])]=])
    execute([=[call add(tl, [2, 'a\{-,0}', 'oidfguih iuhi hiu aaaa', ''])]=])
    execute([=[call add(tl, [2, 'a\{-,5}', 'abcd', ''])]=])
    execute([=[call add(tl, [2, 'a\{-,5}', 'aaaaaaaaaa', ''])]=])
    -- Anti-greedy version of 'a*'.
    execute([=[call add(tl, [2, 'a\{-}', 'bbbcddiuhfcd', ''])]=])
    execute([=[call add(tl, [2, 'a\{-}', 'aaaaioudfh coisf jda', ''])]=])

    -- Test groups of characters and submatches.
    execute([=[call add(tl, [2, '\(abc\)*', 'abcabcabc', 'abcabcabc', 'abc'])]=])
    execute([=[call add(tl, [2, '\(ab\)\+', 'abababaaaaa', 'ababab', 'ab'])]=])
    execute([=[call add(tl, [2, '\(abaaaaa\)*cd', 'cd', 'cd', ''])]=])
    execute([=[call add(tl, [2, '\(test1\)\? \(test2\)\?', 'test1 test3', 'test1 ', 'test1', ''])]=])
    execute([=[call add(tl, [2, '\(test1\)\= \(test2\) \(test4443\)\=', ' test2 test4443 yupiiiiiiiiiii', ' test2 test4443', '', 'test2', 'test4443'])]=])
    execute([=[call add(tl, [2, '\(\(sub1\) hello \(sub 2\)\)', 'asterix sub1 hello sub 2 obelix', 'sub1 hello sub 2', 'sub1 hello sub 2', 'sub1', 'sub 2'])]=])
    execute([=[call add(tl, [2, '\(\(\(yyxxzz\)\)\)', 'abcdddsfiusfyyzzxxyyxxzz', 'yyxxzz', 'yyxxzz', 'yyxxzz', 'yyxxzz'])]=])
    execute([=[call add(tl, [2, '\v((ab)+|c+)+', 'abcccaba', 'abcccab', 'ab', 'ab'])]=])
    execute([=[call add(tl, [2, '\v((ab)|c*)+', 'abcccaba', 'abcccab', '', 'ab'])]=])
    execute([=[call add(tl, [2, '\v(a(c*)+b)+', 'acbababaaa', 'acbabab', 'ab', ''])]=])
    execute([=[call add(tl, [2, '\v(a|b*)+', 'aaaa', 'aaaa', ''])]=])
    execute([=[call add(tl, [2, '\p*', 'aá 	', 'aá '])]=])

    -- Test greedy-ness and lazy-ness.
    execute([=[call add(tl, [2, 'a\{-2,7}','aaaaaaaaaaaaa', 'aa'])]=])
    execute([=[call add(tl, [2, 'a\{-2,7}x','aaaaaaaaax', 'aaaaaaax'])]=])
    execute([=[call add(tl, [2, 'a\{2,7}','aaaaaaaaaaaaaaaaaaaa', 'aaaaaaa'])]=])
    execute([=[call add(tl, [2, 'a\{2,7}x','aaaaaaaaax', 'aaaaaaax'])]=])
    execute([=[call add(tl, [2, '\vx(.{-,8})yz(.*)','xayxayzxayzxayz','xayxayzxayzxayz','ayxa','xayzxayz'])]=])
    execute([=[call add(tl, [2, '\vx(.*)yz(.*)','xayxayzxayzxayz','xayxayzxayzxayz', 'ayxayzxayzxa',''])]=])
    execute([=[call add(tl, [2, '\v(a{1,2}){-2,3}','aaaaaaa','aaaa','aa'])]=])
    execute([=[call add(tl, [2, '\v(a{-1,3})+', 'aa', 'aa', 'a'])]=])
    execute([=[call add(tl, [2, '^\s\{-}\zs\( x\|x$\)', ' x', ' x', ' x'])]=])
    execute([=[call add(tl, [2, '^\s\{-}\zs\(x\| x$\)', ' x', ' x', ' x'])]=])
    execute([=[call add(tl, [2, '^\s\{-}\ze\(x\| x$\)', ' x', '', ' x'])]=])
    execute([=[call add(tl, [2, '^\(\s\{-}\)\(x\| x$\)', ' x', ' x', '', ' x'])]=])

    -- Test Character classes.
    execute([=[call add(tl, [2, '\d\+e\d\d','test 10e23 fd','10e23'])]=])

    -- Test collections and character range [].
    execute([=[call add(tl, [2, '\v[a]', 'abcd', 'a'])]=])
    execute([=[call add(tl, [2, 'a[bcd]', 'abcd', 'ab'])]=])
    execute([=[call add(tl, [2, 'a[b-d]', 'acbd', 'ac'])]=])
    execute([=[call add(tl, [2, '[a-d][e-f][x-x]d', 'cexdxx', 'cexd'])]=])
    execute([=[call add(tl, [2, '\v[[:alpha:]]+', 'abcdefghijklmnopqrstuvwxyz6','abcdefghijklmnopqrstuvwxyz'])]=])
    execute([=[call add(tl, [2, '[[:alpha:]\+]', '6x8','x'])]=])
    execute([=[call add(tl, [2, '[^abc]\+','abcabcabc'])]=])
    execute([=[call add(tl, [2, '[^abc]','defghiasijvoinasoiunbvb','d'])]=])
    execute([=[call add(tl, [2, '[^abc]\+','ddddddda','ddddddd'])]=])
    execute([=[call add(tl, [2, '[^a-d]\+','aaaAAAZIHFNCddd','AAAZIHFNC'])]=])
    execute([=[call add(tl, [2, '[a-f]*','iiiiiiii',''])]=])
    execute([=[call add(tl, [2, '[a-f]*','abcdefgh','abcdef'])]=])
    execute([=[call add(tl, [2, '[^a-f]\+','abcdefgh','gh'])]=])
    execute([=[call add(tl, [2, '[a-c]\{-3,6}','abcabc','abc'])]=])
    execute([=[call add(tl, [2, '[^[:alpha:]]\+','abcccadfoij7787ysf287yrnccdu','7787'])]=])
    execute([=[call add(tl, [2, '[-a]', '-', '-'])]=])
    execute([=[call add(tl, [2, '[a-]', '-', '-'])]=])
    execute([=[call add(tl, [2, '[a-f]*\c','ABCDEFGH','ABCDEF'])]=])
    execute([=[call add(tl, [2, '[abc][xyz]\c','-af-AF-BY--','BY'])]=])
    -- Filename regexp.
    execute([=[call add(tl, [2, '[-./[:alnum:]_~]\+', 'log13.file', 'log13.file'])]=])
    -- Special chars.
    execute([=[call add(tl, [2, '[\]\^\-\\]\+', '\^\\\-\---^', '\^\\\-\---^'])]=])
    -- Collation elem.
    execute([=[call add(tl, [2, '[[.a.]]\+', 'aa', 'aa'])]=])
    -- Middle of regexp.
    execute([=[call add(tl, [2, 'abc[0-9]*ddd', 'siuhabc ii'])]=])
    execute([=[call add(tl, [2, 'abc[0-9]*ddd', 'adf abc44482ddd oijs', 'abc44482ddd'])]=])
    execute([=[call add(tl, [2, '\_[0-9]\+', 'asfi9888u', '9888'])]=])
    execute([=[call add(tl, [2, '[0-9\n]\+', 'asfi9888u', '9888'])]=])
    execute([=[call add(tl, [2, '\_[0-9]\+', "asfi\n9888u", "\n9888"])]=])
    execute([=[call add(tl, [2, '\_f', "  \na ", "\n"])]=])
    execute([=[call add(tl, [2, '\_f\+', "  \na ", "\na"])]=])
    execute([=[call add(tl, [2, '[0-9A-Za-z-_.]\+', " @0_a.A-{ ", "0_a.A-"])]=])

    -- """ Test start/end of line, start/end of file.
    execute([=[call add(tl, [2, '^a.', "a_\nb ", "a_"])]=])
    execute([=[call add(tl, [2, '^a.', "b a \na_"])]=])
    execute([=[call add(tl, [2, '.a$', " a\n "])]=])
    execute([=[call add(tl, [2, '.a$', " a b\n_a", "_a"])]=])
    execute([=[call add(tl, [2, '\%^a.', "a a\na", "a "])]=])
    execute([=[call add(tl, [2, '\%^a', " a \na "])]=])
    execute([=[call add(tl, [2, '.a\%$', " a\n "])]=])
    execute([=[call add(tl, [2, '.a\%$', " a\n_a", "_a"])]=])

    -- """ Test recognition of character classes.
    execute([=[call add(tl, [2, '[0-7]\+', 'x0123456789x', '01234567'])]=])
    execute([=[call add(tl, [2, '[^0-7]\+', '0a;X+% 897', 'a;X+% 89'])]=])
    execute([=[call add(tl, [2, '[0-9]\+', 'x0123456789x', '0123456789'])]=])
    execute([=[call add(tl, [2, '[^0-9]\+', '0a;X+% 9', 'a;X+% '])]=])
    execute([=[call add(tl, [2, '[0-9a-fA-F]\+', 'x0189abcdefg', '0189abcdef'])]=])
    execute([=[call add(tl, [2, '[^0-9A-Fa-f]\+', '0189g;X+% ab', 'g;X+% '])]=])
    execute([=[call add(tl, [2, '[a-z_A-Z0-9]\+', ';+aso_SfOij ', 'aso_SfOij'])]=])
    execute([=[call add(tl, [2, '[^a-z_A-Z0-9]\+', 'aSo_;+% sfOij', ';+% '])]=])
    execute([=[call add(tl, [2, '[a-z_A-Z]\+', '0abyz_ABYZ;', 'abyz_ABYZ'])]=])
    execute([=[call add(tl, [2, '[^a-z_A-Z]\+', 'abAB_09;+% yzYZ', '09;+% '])]=])
    execute([=[call add(tl, [2, '[a-z]\+', '0abcxyz1', 'abcxyz'])]=])
    execute([=[call add(tl, [2, '[a-z]\+', 'AabxyzZ', 'abxyz'])]=])
    execute([=[call add(tl, [2, '[^a-z]\+', 'a;X09+% x', ';X09+% '])]=])
    execute([=[call add(tl, [2, '[^a-z]\+', 'abX0;%yz', 'X0;%'])]=])
    execute([=[call add(tl, [2, '[a-zA-Z]\+', '0abABxzXZ9', 'abABxzXZ'])]=])
    execute([=[call add(tl, [2, '[^a-zA-Z]\+', 'ab09_;+ XZ', '09_;+ '])]=])
    execute([=[call add(tl, [2, '[A-Z]\+', 'aABXYZz', 'ABXYZ'])]=])
    execute([=[call add(tl, [2, '[^A-Z]\+', 'ABx0;%YZ', 'x0;%'])]=])
    execute([=[call add(tl, [2, '[a-z]\+\c', '0abxyzABXYZ;', 'abxyzABXYZ'])]=])
    execute([=[call add(tl, [2, '[A-Z]\+\c', '0abABxzXZ9', 'abABxzXZ'])]=])
    execute([=[call add(tl, [2, '\c[^a-z]\+', 'ab09_;+ XZ', '09_;+ '])]=])
    execute([=[call add(tl, [2, '\c[^A-Z]\+', 'ab09_;+ XZ', '09_;+ '])]=])
    execute([=[call add(tl, [2, '\C[^A-Z]\+', 'ABCOIJDEOIFNSD jsfoij sa', ' jsfoij sa'])]=])

    -- """ Tests for \z features.
    -- Match ends at \ze.
    execute([=[call add(tl, [2, 'xx \ze test', 'xx '])]=])
    execute([=[call add(tl, [2, 'abc\zeend', 'oij abcend', 'abc'])]=])
    execute([=[call add(tl, [2, 'aa\zebb\|aaxx', ' aabb ', 'aa'])]=])
    execute([=[call add(tl, [2, 'aa\zebb\|aaxx', ' aaxx ', 'aaxx'])]=])
    execute([=[call add(tl, [2, 'aabb\|aa\zebb', ' aabb ', 'aabb'])]=])
    execute([=[call add(tl, [2, 'aa\zebb\|aaebb', ' aabb ', 'aa'])]=])
    -- Match starts at \zs.
    execute([=[call add(tl, [2, 'abc\zsdd', 'ddabcddxyzt', 'dd'])]=])
    execute([=[call add(tl, [2, 'aa \zsax', ' ax'])]=])
    execute([=[call add(tl, [2, 'abc \zsmatch\ze abc', 'abc abc abc match abc abc', 'match'])]=])
    execute([=[call add(tl, [2, '\v(a \zsif .*){2}', 'a if then a if last', 'if last', 'a if last'])]=])
    execute([=[call add(tl, [2, '\>\zs.', 'aword. ', '.'])]=])
    execute([=[call add(tl, [2, '\s\+\ze\[/\|\s\zs\s\+', 'is   [a t', '  '])]=])

    -- """ Tests for \@= and \& features.
    execute([=[call add(tl, [2, 'abc\@=', 'abc', 'ab'])]=])
    execute([=[call add(tl, [2, 'abc\@=cd', 'abcd', 'abcd'])]=])
    execute([=[call add(tl, [2, 'abc\@=', 'ababc', 'ab'])]=])
    -- Will never match, no matter the input text.
    execute([=[call add(tl, [2, 'abcd\@=e', 'abcd'])]=])
    -- Will never match.
    execute([=[call add(tl, [2, 'abcd\@=e', 'any text in here ... '])]=])
    execute([=[call add(tl, [2, '\v(abc)@=..', 'xabcd', 'ab', 'abc'])]=])
    execute([=[call add(tl, [2, '\(.*John\)\@=.*Bob', 'here is John, and here is B'])]=])
    execute([=[call add(tl, [2, '\(John.*\)\@=.*Bob', 'John is Bobs friend', 'John is Bob', 'John is Bobs friend'])]=])
    execute([=[call add(tl, [2, '\<\S\+\())\)\@=', '$((i=i+1))', 'i=i+1', '))'])]=])
    execute([=[call add(tl, [2, '.*John\&.*Bob', 'here is John, and here is B'])]=])
    execute([=[call add(tl, [2, '.*John\&.*Bob', 'John is Bobs friend', 'John is Bob'])]=])
    execute([=[call add(tl, [2, '\v(test1)@=.*yep', 'this is a test1, yep it is', 'test1, yep', 'test1'])]=])
    execute([=[call add(tl, [2, 'foo\(bar\)\@!', 'foobar'])]=])
    execute([=[call add(tl, [2, 'foo\(bar\)\@!', 'foo bar', 'foo'])]=])
    execute([=[call add(tl, [2, 'if \(\(then\)\@!.\)*$', ' if then else'])]=])
    execute([=[call add(tl, [2, 'if \(\(then\)\@!.\)*$', ' if else ', 'if else ', ' '])]=])
    execute([=[call add(tl, [2, '\(foo\)\@!bar', 'foobar', 'bar'])]=])
    execute([=[call add(tl, [2, '\(foo\)\@!...bar', 'foobar'])]=])
    execute([=[call add(tl, [2, '^\%(.*bar\)\@!.*\zsfoo', ' bar foo '])]=])
    execute([=[call add(tl, [2, '^\%(.*bar\)\@!.*\zsfoo', ' foo bar '])]=])
    execute([=[call add(tl, [2, '^\%(.*bar\)\@!.*\zsfoo', ' foo xxx ', 'foo'])]=])
    execute([=[call add(tl, [2, '[ ]\@!\p\%([ ]\@!\p\)*:', 'implicit mappings:', 'mappings:'])]=])
    execute([=[call add(tl, [2, '[ ]\@!\p\([ ]\@!\p\)*:', 'implicit mappings:', 'mappings:', 's'])]=])
    execute([=[call add(tl, [2, 'm\k\+_\@=\%(_\@!\k\)\@<=\k\+e', 'mx__xe', 'mx__xe'])]=])
    execute([=[call add(tl, [2, '\%(\U\@<=S\k*\|S\l\)R', 'SuR', 'SuR'])]=])

    -- """ Combining different tests and features.
    execute([=[call add(tl, [2, '[[:alpha:]]\{-2,6}', '787abcdiuhsasiuhb4', 'ab'])]=])
    execute([=[call add(tl, [2, '', 'abcd', ''])]=])
    execute([=[call add(tl, [2, '\v(())', 'any possible text', ''])]=])
    execute([=[call add(tl, [2, '\v%(ab(xyz)c)', '   abxyzc ', 'abxyzc', 'xyz'])]=])
    execute([=[call add(tl, [2, '\v(test|)empty', 'tesempty', 'empty', ''])]=])
    execute([=[call add(tl, [2, '\v(a|aa)(a|aa)', 'aaa', 'aa', 'a', 'a'])]=])

    -- """ \%u and friends.
    execute([=[call add(tl, [2, '\%d32', 'yes no', ' '])]=])
    execute([=[call add(tl, [2, '\%o40', 'yes no', ' '])]=])
    execute([=[call add(tl, [2, '\%x20', 'yes no', ' '])]=])
    execute([=[call add(tl, [2, '\%u0020', 'yes no', ' '])]=])
    execute([=[call add(tl, [2, '\%U00000020', 'yes no', ' '])]=])
    execute([=[call add(tl, [2, '\%d0', "yes\x0ano", "\x0a"])]=])

    -- """" \%[abc].
    execute([=[call add(tl, [2, 'foo\%[bar]', 'fobar'])]=])
    execute([=[call add(tl, [2, 'foo\%[bar]', 'foobar', 'foobar'])]=])
    execute([=[call add(tl, [2, 'foo\%[bar]', 'fooxx', 'foo'])]=])
    execute([=[call add(tl, [2, 'foo\%[bar]', 'foobxx', 'foob'])]=])
    execute([=[call add(tl, [2, 'foo\%[bar]', 'foobaxx', 'fooba'])]=])
    execute([=[call add(tl, [2, 'foo\%[bar]', 'foobarxx', 'foobar'])]=])
    execute([=[call add(tl, [2, 'foo\%[bar]x', 'foobxx', 'foobx'])]=])
    execute([=[call add(tl, [2, 'foo\%[bar]x', 'foobarxx', 'foobarx'])]=])
    execute([=[call add(tl, [2, '\%[bar]x', 'barxx', 'barx'])]=])
    execute([=[call add(tl, [2, '\%[bar]x', 'bxx', 'bx'])]=])
    execute([=[call add(tl, [2, '\%[bar]x', 'xxx', 'x'])]=])
    execute([=[call add(tl, [2, 'b\%[[ao]r]', 'bar bor', 'bar'])]=])
    execute([=[call add(tl, [2, 'b\%[[]]r]', 'b]r bor', 'b]r'])]=])
    execute([=[call add(tl, [2, '@\%[\w\-]*', '<http://john.net/pandoc/>[@pandoc]', '@pandoc'])]=])

    -- """ Alternatives, must use first longest match.
    execute([=[call add(tl, [2, 'goo\|go', 'google', 'goo'])]=])
    execute([=[call add(tl, [2, '\<goo\|\<go', 'google', 'goo'])]=])
    execute([=[call add(tl, [2, '\<goo\|go', 'google', 'goo'])]=])

    -- """ Back references.
    execute([=[call add(tl, [2, '\(\i\+\) \1', ' abc abc', 'abc abc', 'abc'])]=])
    execute([=[call add(tl, [2, '\(\i\+\) \1', 'xgoo goox', 'goo goo', 'goo'])]=])
    execute([=[call add(tl, [2, '\(a\)\(b\)\(c\)\(dd\)\(e\)\(f\)\(g\)\(h\)\(i\)\1\2\3\4\5\6\7\8\9', 'xabcddefghiabcddefghix', 'abcddefghiabcddefghi', 'a', 'b', 'c', 'dd', 'e', 'f', 'g', 'h', 'i'])]=])
    execute([=[call add(tl, [2, '\(\d*\)a \1b', ' a b ', 'a b', ''])]=])
    execute([=[call add(tl, [2, '^.\(.\).\_..\1.', "aaa\naaa\nb", "aaa\naaa", 'a'])]=])
    execute([=[call add(tl, [2, '^.*\.\(.*\)/.\+\(\1\)\@<!$', 'foo.bat/foo.com', 'foo.bat/foo.com', 'bat'])]=])
    execute([=[call add(tl, [2, '^.*\.\(.*\)/.\+\(\1\)\@<!$', 'foo.bat/foo.bat'])]=])
    execute([=[call add(tl, [2, '^.*\.\(.*\)/.\+\(\1\)\@<=$', 'foo.bat/foo.bat', 'foo.bat/foo.bat', 'bat', 'bat'])]=])
    execute([=[call add(tl, [2, '\\\@<!\${\(\d\+\%(:.\{-}\)\?\\\@<!\)}', '2013-06-27${0}', '${0}', '0'])]=])
    execute([=[call add(tl, [2, '^\(a*\)\1$', 'aaaaaaaa', 'aaaaaaaa', 'aaaa'])]=])
    execute([=[call add(tl, [2, '^\(a\{-2,}\)\1\+$', 'aaaaaaaaa', 'aaaaaaaaa', 'aaa'])]=])

    -- """ Look-behind with limit.
    execute([=[call add(tl, [2, '<\@<=span.', 'xxspanxx<spanyyy', 'spany'])]=])
    execute([=[call add(tl, [2, '<\@1<=span.', 'xxspanxx<spanyyy', 'spany'])]=])
    execute([=[call add(tl, [2, '<\@2<=span.', 'xxspanxx<spanyyy', 'spany'])]=])
    execute([=[call add(tl, [2, '\(<<\)\@<=span.', 'xxspanxxxx<spanxx<<spanyyy', 'spany', '<<'])]=])
    execute([=[call add(tl, [2, '\(<<\)\@1<=span.', 'xxspanxxxx<spanxx<<spanyyy'])]=])
    execute([=[call add(tl, [2, '\(<<\)\@2<=span.', 'xxspanxxxx<spanxx<<spanyyy', 'spany', '<<'])]=])
    execute([=[call add(tl, [2, '\(foo\)\@<!bar.', 'xx foobar1 xbar2 xx', 'bar2'])]=])

    -- Look-behind match in front of a zero-width item.
    -- Test header']).
    execute([[call add(tl, [2, '\v\C%(<Last Changed:\s+)@<=.*$', ']])
    -- Last Changed: 1970', '1970']).
    execute([[call add(tl, [2, '\v\C%(<Last Changed:\s+)@<=.*$', ']])
    execute([=[call add(tl, [2, '\(foo\)\@<=\>', 'foobar'])]=])
    execute([=[call add(tl, [2, '\(foo\)\@<=\>', 'barfoo', '', 'foo'])]=])
    execute([=[call add(tl, [2, '\(foo\)\@<=.*', 'foobar', 'bar', 'foo'])]=])

    -- Complicated look-behind match.
    execute([=[call add(tl, [2, '\(r\@<=\|\w\@<!\)\/', 'x = /word/;', '/'])]=])
    execute([=[call add(tl, [2, '^[a-z]\+\ze \&\(asdf\)\@<!', 'foo bar', 'foo'])]=])

    -- """" \@>.
    execute([=[call add(tl, [2, '\(a*\)\@>a', 'aaaa'])]=])
    execute([=[call add(tl, [2, '\(a*\)\@>b', 'aaab', 'aaab', 'aaa'])]=])
    execute([=[call add(tl, [2, '^\(.\{-}b\)\@>.', '  abcbd', '  abc', '  ab'])]=])
    execute([=[call add(tl, [2, '\(.\{-}\)\(\)\@>$', 'abc', 'abc', 'abc', ''])]=])
    -- TODO: BT engine does not restore submatch after failure.
    execute([=[call add(tl, [1, '\(a*\)\@>a\|a\+', 'aaaa', 'aaaa'])]=])

    -- """ "\_" prepended negated collection matches EOL.
    execute([=[call add(tl, [2, '\_[^8-9]\+', "asfi\n9888", "asfi\n"])]=])
    execute([=[call add(tl, [2, '\_[^a]\+', "asfi\n9888", "sfi\n9888"])]=])

    -- """ Requiring lots of states.
    execute([=[call add(tl, [2, '[0-9a-zA-Z]\{8}-\([0-9a-zA-Z]\{4}-\)\{3}[0-9a-zA-Z]\{12}', " 12345678-1234-1234-1234-123456789012 ", "12345678-1234-1234-1234-123456789012", "1234-"])]=])

    -- """ Skip adding state twice.
    execute([=[call add(tl, [2, '^\%(\%(^\s*#\s*if\>\|#\s*if\)\)\(\%>1c.*$\)\@=', "#if FOO", "#if", ' FOO'])]=])

    -- "" Test \%V atom.
    execute([=[call add(tl, [2, '\%>70vGesamt', 'Jean-Michel Charlier & Victor Hubinon\Gesamtausgabe [Salleck]    Buck Danny {Jean-Michel Charlier & Victor Hubinon}\Gesamtausgabe', 'Gesamt'])]=])

    -- """ Run the tests.

    execute('for t in tl')
    execute('  let re = t[0]')
    execute('  let pat = t[1]')
    execute('  let text = t[2]')
    execute('  let matchidx = 3')
    execute('  for engine in [0, 1, 2]')
    execute('    if engine == 2 && re == 0 || engine == 1 && re == 1')
    execute('      continue')
    execute('    endif')
    execute('    let &regexpengine = engine')
    execute('    try')
    execute('      let l = matchlist(text, pat)')
    execute('    catch')
    execute([[      $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", caused an exception: \"' . v:exception . '\"']])
    execute('    endtry')
    -- Check the match itself.
    execute('    if len(l) == 0 && len(t) > matchidx')
    execute([=[      $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", did not match, expected: \"' . t[matchidx] . '\"']=])
    execute('    elseif len(l) > 0 && len(t) == matchidx')
    execute([=[      $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", match: \"' . l[0] . '\", expected no match']=])
    execute('    elseif len(t) > matchidx && l[0] != t[matchidx]')
    execute([=[      $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", match: \"' . l[0] . '\", expected: \"' . t[matchidx] . '\"']=])
    execute('    else')
    execute([[      $put ='OK ' . engine . ' - ' . pat]])
    execute('    endif')
    execute('    if len(l) > 0')
    -- Check all the nine submatches.
    execute('      for i in range(1, 9)')
    execute('        if len(t) <= matchidx + i')
    execute([[          let e = '']])
    execute('        else')
    execute('          let e = t[matchidx + i]')
    execute('        endif')
    execute('        if l[i] != e')
    execute([=[          $put ='ERROR ' . engine . ': pat: \"' . pat . '\", text: \"' . text . '\", submatch ' . i . ': \"' . l[i] . '\", expected: \"' . e . '\"']=])
    execute('        endif')
    execute('      endfor')
    execute('      unlet i')
    execute('    endif')
    execute('  endfor')
    execute('endfor')
    execute('unlet t tl e l')

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
    execute([=[/\(<\_[xy]\+\)\@3<=start]=])
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

    feed('Go<esc>p:<cr>')

    -- Check matching marks.
    execute('/^Marks:')
    feed('jfSmsfEme')
    execute([[.-4,.+6s/.\%>'s.*\%<'e../here/]])
    feed('jfSmsj0fEme')
    execute([[.-4,.+6s/.\%>'s\_.*\%<'e../again/]])
    execute(':/^Marks:/+1,/^Marks:/+3yank')

    feed('Go<esc>p')

    -- Check patterns matching cursor position.
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
    execute('set regexpengine=2')
    execute([=[for pat in [' \ze*', ' \zs*']]=])
    execute('  try')
    execute([[    let l = matchlist('x x', pat)]])
    execute([[    $put ='E888 NOT detected for ' . pat]])
    execute('  catch')
    execute([[    $put ='E888 detected for ' . pat]])
    execute('  endtry')
    execute('endfor')

    -- Prepare buffer for expect()
    execute([[0,/^\%#=1^Results/-1 delete]])

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
