-- Test for *sub-replace-special* and *sub-replace-expression* on substitute().
-- Test for submatch() on substitute().
-- Test for *:s%* on :substitute.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local feed, insert = n.feed, n.insert
local exec = n.exec
local clear, feed_command, expect = n.clear, n.feed_command, n.expect
local eq, eval = t.eq, n.eval

describe('substitute()', function()
  before_each(clear)

  -- The original test contained several TEST_X lines to delimit different
  -- parts.  These where used to split the test into different it() blocks.
  -- The TEST_X strings are repeated in the description of the blocks to make
  -- it easier to incorporate upstream changes.

  local function test_1_and_2()
    eq('AA', eval("substitute('A', 'A', '&&', '')"))
    eq('&', eval([[substitute('B', 'B', '\&', '')]]))
    eq(
      'C123456789987654321',
      eval(
        [[substitute('C123456789', ]]
          .. [['C\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)', ]]
          .. [['\0\9\8\7\6\5\4\3\2\1', '')]]
      )
    )
    eq('d', eval("substitute('D', 'D', 'd', '')"))
    eq('~', eval("substitute('E', 'E', '~', '')"))
    eq('~', eval([[substitute('F', 'F', '\~', '')]]))
    eq('Gg', eval([[substitute('G', 'G', '\ugg', '')]]))
    eq('Hh', eval([[substitute('H', 'H', '\Uh\Eh', '')]]))
    eq('iI', eval([[substitute('I', 'I', '\lII', '')]]))
    eq('jJ', eval([[substitute('J', 'J', '\LJ\EJ', '')]]))
    eq('Kk', eval([[substitute('K', 'K', '\Uk\ek', '')]]))
    eq('l\rl', eval("substitute('lLl', 'L', '\r', '')"))
    eq('m\rm', eval([[substitute('mMm', 'M', '\r', '')]]))
    eq('n\rn', eval("substitute('nNn', 'N', '\\\r', '')"))
    eq('o\no', eval([[substitute('oOo', 'O', '\n', '')]]))
    eq('p\bp', eval([[substitute('pPp', 'P', '\b', '')]]))
    eq('q\tq', eval([[substitute('qQq', 'Q', '\t', '')]]))
    eq('r\\r', eval([[substitute('rRr', 'R', '\\', '')]]))
    eq('scs', eval([[substitute('sSs', 'S', '\c', '')]]))
    eq('t\rt', eval([[substitute('tTt', 'T', "\r", '')]]))
    eq('u\nu', eval([[substitute('uUu', 'U', "\n", '')]]))
    eq('v\bv', eval([[substitute('vVv', 'V', "\b", '')]]))
    eq('w\\w', eval([[substitute('wWw', 'W', "\\", '')]]))
    eq('XxxX', eval([[substitute('X', 'X', '\L\uxXx\l\EX', '')]]))
    eq('yYYy', eval([[substitute('Y', 'Y', '\U\lYyY\u\Ey', '')]]))
  end

  it('with "set magic" (TEST_1)', function()
    feed_command('set magic')
    test_1_and_2()
  end)

  it('with "set nomagic" (TEST_2)', function()
    feed_command('set nomagic')
    test_1_and_2()
  end)

  it('with sub-replace-expression (TEST_3)', function()
    feed_command('set magic&')
    eq('a\\a', eval([[substitute('aAa', 'A', '\="\\"', '')]]))
    eq('b\\\\b', eval([[substitute('bBb', 'B', '\="\\\\"', '')]]))
    eq('c\rc', eval([[substitute('cCc', 'C', '\="]] .. '\r' .. [["', '')]]))
    eq('d\\\rd', eval([[substitute('dDd', 'D', '\="\\]] .. '\r' .. [["', '')]]))
    eq('e\\\\\re', eval([[substitute('eEe', 'E', '\="\\\\]] .. '\r' .. [["', '')]]))
    eq('f\\rf', eval([[substitute('fFf', 'F', '\="\\r"', '')]]))
    eq('j\\nj', eval([[substitute('jJj', 'J', '\="\\n"', '')]]))
    eq('k\rk', eval([[substitute('kKk', 'K', '\="\r"', '')]]))
    eq('l\nl', eval([[substitute('lLl', 'L', '\="\n"', '')]]))
  end)

  it('with submatch() (TEST_4)', function()
    feed_command('set magic&')
    eq(
      'a\\a',
      eval([[substitute('aAa', 'A', ]] .. [['\=substitute(submatch(0), ".", "\\", "")', '')]])
    )
    eq(
      'b\\b',
      eval([[substitute('bBb', 'B', ]] .. [['\=substitute(submatch(0), ".", "\\\\", "")', '')]])
    )
    eq(
      'c\rc',
      eval(
        [[substitute('cCc', 'C', ]]
          .. [['\=substitute(submatch(0), ".", "]]
          .. '\r'
          .. [[", "")', '')]]
      )
    )
    eq(
      'd\rd',
      eval(
        [[substitute('dDd', 'D', ]]
          .. [['\=substitute(submatch(0), ".", "\\]]
          .. '\r'
          .. [[", "")', '')]]
      )
    )
    eq(
      'e\\\re',
      eval(
        [[substitute('eEe', 'E', ]]
          .. [['\=substitute(submatch(0), ".", "\\\\]]
          .. '\r'
          .. [[", "")', '')]]
      )
    )
    eq(
      'f\rf',
      eval([[substitute('fFf', 'F', ]] .. [['\=substitute(submatch(0), ".", "\\r", "")', '')]])
    )
    eq(
      'j\nj',
      eval([[substitute('jJj', 'J', ]] .. [['\=substitute(submatch(0), ".", "\\n", "")', '')]])
    )
    eq(
      'k\rk',
      eval([[substitute('kKk', 'K', ]] .. [['\=substitute(submatch(0), ".", "\r", "")', '')]])
    )
    eq(
      'l\nl',
      eval([[substitute('lLl', 'L', ]] .. [['\=substitute(submatch(0), ".", "\n", "")', '')]])
    )
  end)

  it('with submatch() (TEST_5)', function()
    feed_command('set magic&')
    eq(
      'A123456789987654321',
      eval(
        [[substitute('A123456789', ]]
          .. [['A\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)', ]]
          .. [['\=submatch(0) . submatch(9) . submatch(8) . submatch(7) . ]]
          .. [[submatch(6) . submatch(5) . submatch(4) . submatch(3) . ]]
          .. [[submatch(2) . submatch(1)', '')]]
      )
    )
    eq(
      "[['A123456789'], ['9'], ['8'], ['7'], ['6'], ['5'], ['4'], ['3'], " .. "['2'], ['1']]",
      eval(
        [[substitute('A123456789', ]]
          .. [['A\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)', ]]
          .. [['\=string([submatch(0, 1), submatch(9, 1), submatch(8, 1), ]]
          .. [[submatch(7, 1), submatch(6, 1), submatch(5, 1), submatch(4, 1), ]]
          .. [[submatch(3, 1), submatch(2, 1), submatch(1, 1)])', '')]]
      )
    )
  end)

  -- TEST_6 was about the 'cpoptions' flag / which was removed in pull request
  -- #2943.

  it('with submatch or \\ze (TEST_7)', function()
    feed_command('set magic&')
    eq('A\rA', eval("substitute('A\rA', 'A.', '\\=submatch(0)', '')"))
    eq('B\nB', eval([[substitute("B\nB", 'B.', '\=submatch(0)', '')]]))
    eq("['B\n']B", eval([[substitute("B\nB", 'B.', '\=string(submatch(0, 1))', '')]]))
    eq('-abab', eval([[substitute('-bb', '\zeb', 'a', 'g')]]))
    eq('c-cbcbc', eval([[substitute('-bb', '\ze', 'c', 'g')]]))
  end)

  it('with \\zs and \\ze (TEST_10)', function()
    feed_command('set magic&')
    eq('a1a2a3a', eval([[substitute('123', '\zs', 'a', 'g')]]))
    eq('aaa', eval([[substitute('123', '\zs.', 'a', 'g')]]))
    eq('1a2a3a', eval([[substitute('123', '.\zs', 'a', 'g')]]))
    eq('a1a2a3a', eval([[substitute('123', '\ze', 'a', 'g')]]))
    eq('a1a2a3', eval([[substitute('123', '\ze.', 'a', 'g')]]))
    eq('aaa', eval([[substitute('123', '.\ze', 'a', 'g')]]))
    eq('aa2a3a', eval([[substitute('123', '1\|\ze', 'a', 'g')]]))
    eq('1aaa', eval([[substitute('123', '1\zs\|[23]', 'a', 'g')]]))
  end)
end)

describe(':substitute', function()
  before_each(clear)

  it('with \\ze and \\zs and confirmation dialog (TEST_8)', function()
    insert([[
      ,,X
      ,,Y
      ,,Z]])
    feed_command('set magic&')
    feed_command([[1s/\(^\|,\)\ze\(,\|X\)/\1N/g]])
    feed_command([[2s/\(^\|,\)\ze\(,\|Y\)/\1N/gc]])
    feed('a') -- For the dialog of the previous :s command.
    feed_command([[3s/\(^\|,\)\ze\(,\|Z\)/\1N/gc]])
    feed('yy') -- For the dialog of the previous :s command.
    expect([[
      N,,NX
      N,,NY
      N,,NZ]])
  end)

  it('with confirmation dialog (TEST_9)', function()
    insert('xxx')
    feed_command('set magic&')
    feed_command('s/x/X/gc')
    feed('yyq') -- For the dialog of the previous :s command.
    expect('XXx')
  end)

  it('first char is highlighted with confirmation dialog and empty match', function()
    local screen = Screen.new(60, 8)
    exec([[
      set nohlsearch noincsearch
      call setline(1, ['one', 'two', 'three'])
    ]])
    feed(':%s/^/   /c<CR>')
    screen:expect([[
      {2:o}ne                                                         |
      two                                                         |
      three                                                       |
      {1:~                                                           }|*4
      {6:replace with     (y/n/a/q/l/^E/^Y)?}^                         |
    ]])
  end)
end)
