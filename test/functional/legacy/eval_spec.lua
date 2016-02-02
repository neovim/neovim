-- Test for various eval features.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local eq, eval, write_file = helpers.eq, helpers.eval, helpers.write_file

local function has_clipboard()
  clear()
  return 1 == eval("has('clipboard')")
end

describe('eval', function()
  setup(function()
    write_file('test_eval_setup.vim', [[
      set noswapfile
      lang C

      fun AppendRegContents(reg)
        call AppendRegParts(a:reg, getregtype(a:reg), getreg(a:reg), string(getreg(a:reg, 0, 1)), getreg(a:reg, 1), string(getreg(a:reg, 1, 1)))
      endfun

      fun AppendRegParts(reg, type, cont, strcont, cont1, strcont1)
        call append('$', printf('%s: type %s; value: %s (%s), expr: %s (%s)', a:reg, a:type, a:cont, a:strcont, a:cont1, a:strcont1))
      endfun

      command -nargs=? AR :call AppendRegContents(<q-args>)

      fun SetReg(...)
          call call('setreg', a:000)
          call append('$', printf('{{{2 setreg(%s)', string(a:000)[1:-2]))
          call AppendRegContents(a:1)
          if a:1 isnot# '='
              execute "silent normal! Go==\n==\e\"".a:1."P"
          endif
      endfun
      ]])
  end)
  before_each(clear)
  teardown(function()
    os.remove('test_eval_setup.vim')
  end)

  it(':let', function()
    execute('so test_eval_setup.vim')
    execute([[let @" = 'abc']])
    execute('AR "')
    execute([[let @" = "abc\n"]])
    source('AR "')
    execute([[let @" = "abc\<C-m>"]])
    execute('AR "')
    execute([[let @= = '"abc"']])
    execute('AR =')
    expect([[
      
      ": type v; value: abc (['abc']), expr: abc (['abc'])
      ": type V; value: abc]].."\x00 (['abc']), expr: abc\x00"..[[ (['abc'])
      ": type V; value: abc]].."\r\x00 (['abc\r']), expr: abc\r\x00 (['abc\r"..[['])
      =: type v; value: abc (['abc']), expr: "abc" (['"abc"'])]])
  end)

  it('basic setreg() tests', function()
    execute('so test_eval_setup.vim')
    insert('{{{1 Basic setreg tests')
    execute([[call SetReg('a', 'abcA', 'c')]])
    execute([[call SetReg('b', 'abcB', 'v')]])
    execute([[call SetReg('c', 'abcC', 'l')]])
    execute([[call SetReg('d', 'abcD', 'V')]])
    execute([[call SetReg('e', 'abcE', 'b')]])
    execute([[call SetReg('f', 'abcF', "\<C-v>")]])
    execute([[call SetReg('g', 'abcG', 'b10')]])
    execute([[call SetReg('h', 'abcH', "\<C-v>10")]])
    execute([[call SetReg('I', 'abcI')]])

    feed('Go{{{1 Appending single lines with setreg()<esc>')
    execute([[call SetReg('A', 'abcAc', 'c')]])
    execute([[call SetReg('A', 'abcAl', 'l')]])
    execute([[call SetReg('A', 'abcAc2','c')]])
    execute([[call SetReg('b', 'abcBc', 'ca')]])
    execute([[call SetReg('b', 'abcBb', 'ba')]])
    execute([[call SetReg('b', 'abcBc2','ca')]])
    execute([[call SetReg('b', 'abcBb2','b50a')]])
    execute([[call SetReg('C', 'abcCl', 'l')]])
    execute([[call SetReg('C', 'abcCc', 'c')]])
    execute([[call SetReg('D', 'abcDb', 'b')]])
    execute([[call SetReg('E', 'abcEb', 'b')]])
    execute([[call SetReg('E', 'abcEl', 'l')]])
    execute([[call SetReg('F', 'abcFc', 'c')]])
    expect([[
      {{{1 Basic setreg tests
      {{{2 setreg('a', 'abcA', 'c')
      a: type v; value: abcA (['abcA']), expr: abcA (['abcA'])
      ==
      =abcA=
      {{{2 setreg('b', 'abcB', 'v')
      b: type v; value: abcB (['abcB']), expr: abcB (['abcB'])
      ==
      =abcB=
      {{{2 setreg('c', 'abcC', 'l')
      c: type V; value: abcC]].."\x00 (['abcC']), expr: abcC\x00"..[[ (['abcC'])
      ==
      abcC
      ==
      {{{2 setreg('d', 'abcD', 'V')
      d: type V; value: abcD]].."\x00 (['abcD']), expr: abcD\x00"..[[ (['abcD'])
      ==
      abcD
      ==
      {{{2 setreg('e', 'abcE', 'b')
      e: type ]]..'\x16'..[[4; value: abcE (['abcE']), expr: abcE (['abcE'])
      ==
      =abcE=
      {{{2 setreg('f', 'abcF', ']]..'\x16'..[[')
      f: type ]]..'\x16'..[[4; value: abcF (['abcF']), expr: abcF (['abcF'])
      ==
      =abcF=
      {{{2 setreg('g', 'abcG', 'b10')
      g: type ]]..'\x16'..[[10; value: abcG (['abcG']), expr: abcG (['abcG'])
      ==
      =abcG      =
      {{{2 setreg('h', 'abcH', ']]..'\x16'..[[10')
      h: type ]]..'\x16'..[[10; value: abcH (['abcH']), expr: abcH (['abcH'])
      ==
      =abcH      =
      {{{2 setreg('I', 'abcI')
      I: type v; value: abcI (['abcI']), expr: abcI (['abcI'])
      ==
      =abcI=
      {{{1 Appending single lines with setreg()
      {{{2 setreg('A', 'abcAc', 'c')
      A: type v; value: abcAabcAc (['abcAabcAc']), expr: abcAabcAc (['abcAabcAc'])
      ==
      =abcAabcAc=
      {{{2 setreg('A', 'abcAl', 'l')
      A: type V; value: abcAabcAcabcAl]].."\x00 (['abcAabcAcabcAl']), expr: abcAabcAcabcAl\x00"..[[ (['abcAabcAcabcAl'])
      ==
      abcAabcAcabcAl
      ==
      {{{2 setreg('A', 'abcAc2', 'c')
      A: type v; value: abcAabcAcabcAl]].."\x00abcAc2 (['abcAabcAcabcAl', 'abcAc2']), expr: abcAabcAcabcAl\x00"..[[abcAc2 (['abcAabcAcabcAl', 'abcAc2'])
      ==
      =abcAabcAcabcAl
      abcAc2=
      {{{2 setreg('b', 'abcBc', 'ca')
      b: type v; value: abcBabcBc (['abcBabcBc']), expr: abcBabcBc (['abcBabcBc'])
      ==
      =abcBabcBc=
      {{{2 setreg('b', 'abcBb', 'ba')
      b: type ]]..'\x16'..[[5; value: abcBabcBcabcBb (['abcBabcBcabcBb']), expr: abcBabcBcabcBb (['abcBabcBcabcBb'])
      ==
      =abcBabcBcabcBb=
      {{{2 setreg('b', 'abcBc2', 'ca')
      b: type v; value: abcBabcBcabcBb]].."\x00abcBc2 (['abcBabcBcabcBb', 'abcBc2']), expr: abcBabcBcabcBb\x00"..[[abcBc2 (['abcBabcBcabcBb', 'abcBc2'])
      ==
      =abcBabcBcabcBb
      abcBc2=
      {{{2 setreg('b', 'abcBb2', 'b50a')
      b: type ]].."\x1650; value: abcBabcBcabcBb\x00abcBc2abcBb2 (['abcBabcBcabcBb', 'abcBc2abcBb2']), expr: abcBabcBcabcBb\x00"..[[abcBc2abcBb2 (['abcBabcBcabcBb', 'abcBc2abcBb2'])
      ==
      =abcBabcBcabcBb                                    =
       abcBc2abcBb2
      {{{2 setreg('C', 'abcCl', 'l')
      C: type V; value: abcC]].."\x00abcCl\x00 (['abcC', 'abcCl']), expr: abcC\x00abcCl\x00"..[[ (['abcC', 'abcCl'])
      ==
      abcC
      abcCl
      ==
      {{{2 setreg('C', 'abcCc', 'c')
      C: type v; value: abcC]].."\x00abcCl\x00abcCc (['abcC', 'abcCl', 'abcCc']), expr: abcC\x00abcCl\x00"..[[abcCc (['abcC', 'abcCl', 'abcCc'])
      ==
      =abcC
      abcCl
      abcCc=
      {{{2 setreg('D', 'abcDb', 'b')
      D: type ]].."\x165; value: abcD\x00abcDb (['abcD', 'abcDb']), expr: abcD\x00"..[[abcDb (['abcD', 'abcDb'])
      ==
      =abcD =
       abcDb
      {{{2 setreg('E', 'abcEb', 'b')
      E: type ]].."\x165; value: abcE\x00abcEb (['abcE', 'abcEb']), expr: abcE\x00"..[[abcEb (['abcE', 'abcEb'])
      ==
      =abcE =
       abcEb
      {{{2 setreg('E', 'abcEl', 'l')
      E: type V; value: abcE]].."\x00abcEb\x00abcEl\x00 (['abcE', 'abcEb', 'abcEl']), expr: abcE\x00abcEb\x00abcEl\x00"..[[ (['abcE', 'abcEb', 'abcEl'])
      ==
      abcE
      abcEb
      abcEl
      ==
      {{{2 setreg('F', 'abcFc', 'c')
      F: type v; value: abcF]].."\x00abcFc (['abcF', 'abcFc']), expr: abcF\x00"..[[abcFc (['abcF', 'abcFc'])
      ==
      =abcF
      abcFc=]])
  end)

  it('appending NL with setreg()', function()
    execute('so test_eval_setup.vim')

    execute([[call setreg('a', 'abcA2', 'c')]])
    execute([[call setreg('b', 'abcB2', 'v')]])
    execute([[call setreg('c', 'abcC2', 'l')]])
    execute([[call setreg('d', 'abcD2', 'V')]])
    execute([[call setreg('e', 'abcE2', 'b')]])
    execute([[call setreg('f', 'abcF2', "\<C-v>")]])
    -- These registers where set like this in the old test_eval.in but never
    -- copied to the output buffer with SetReg().  They do not appear in
    -- test_eval.ok.  Therefore they are commented out.
    --execute([[call setreg('g', 'abcG2', 'b10')]])
    --execute([[call setreg('h', 'abcH2', "\<C-v>10")]])
    --execute([[call setreg('I', 'abcI2')]])

    execute([[call SetReg('A', "\n")]])
    execute([[call SetReg('B', "\n", 'c')]])
    execute([[call SetReg('C', "\n")]])
    execute([[call SetReg('D', "\n", 'l')]])
    execute([[call SetReg('E', "\n")]])
    execute([[call SetReg('F', "\n", 'b')]])
    expect([[
      
      {{{2 setreg('A', ']]..'\x00'..[[')
      A: type V; value: abcA2]].."\x00 (['abcA2']), expr: abcA2\x00"..[[ (['abcA2'])
      ==
      abcA2
      ==
      {{{2 setreg('B', ']]..'\x00'..[[', 'c')
      B: type v; value: abcB2]].."\x00 (['abcB2', '']), expr: abcB2\x00"..[[ (['abcB2', ''])
      ==
      =abcB2
      =
      {{{2 setreg('C', ']]..'\x00'..[[')
      C: type V; value: abcC2]].."\x00\x00 (['abcC2', '']), expr: abcC2\x00\x00"..[[ (['abcC2', ''])
      ==
      abcC2
      
      ==
      {{{2 setreg('D', ']]..'\x00'..[[', 'l')
      D: type V; value: abcD2]].."\x00\x00 (['abcD2', '']), expr: abcD2\x00\x00"..[[ (['abcD2', ''])
      ==
      abcD2
      
      ==
      {{{2 setreg('E', ']]..'\x00'..[[')
      E: type V; value: abcE2]].."\x00\x00 (['abcE2', '']), expr: abcE2\x00\x00"..[[ (['abcE2', ''])
      ==
      abcE2
      
      ==
      {{{2 setreg('F', ']]..'\x00'..[[', 'b')
      F: type ]].."\x160; value: abcF2\x00 (['abcF2', '']), expr: abcF2\x00"..[[ (['abcF2', ''])
      ==
      =abcF2=
       ]])
  end)

  it('setting and appending list with setreg()', function()
    execute('so test_eval_setup.vim')

    execute([[$put ='{{{1 Setting lists with setreg()']])
    execute([=[call SetReg('a', ['abcA3'], 'c')]=])
    execute([=[call SetReg('b', ['abcB3'], 'l')]=])
    execute([=[call SetReg('c', ['abcC3'], 'b')]=])
    execute([=[call SetReg('d', ['abcD3'])]=])
    execute([=[call SetReg('e', [1, 2, 'abc', 3])]=])
    execute([=[call SetReg('f', [1, 2, 3])]=])

    execute([[$put ='{{{1 Appending lists with setreg()']])
    execute([=[call SetReg('A', ['abcA3c'], 'c')]=])
    execute([=[call SetReg('b', ['abcB3l'], 'la')]=])
    execute([=[call SetReg('C', ['abcC3b'], 'lb')]=])
    execute([=[call SetReg('D', ['abcD32'])]=])
    execute([=[call SetReg('A', ['abcA32'])]=])
    execute([=[call SetReg('B', ['abcB3c'], 'c')]=])
    execute([=[call SetReg('C', ['abcC3l'], 'l')]=])
    execute([=[call SetReg('D', ['abcD3b'], 'b')]=])
    expect([[
      
      {{{1 Setting lists with setreg()
      {{{2 setreg('a', ['abcA3'], 'c')
      a: type v; value: abcA3 (['abcA3']), expr: abcA3 (['abcA3'])
      ==
      =abcA3=
      {{{2 setreg('b', ['abcB3'], 'l')
      b: type V; value: abcB3]].."\x00 (['abcB3']), expr: abcB3\x00"..[[ (['abcB3'])
      ==
      abcB3
      ==
      {{{2 setreg('c', ['abcC3'], 'b')
      c: type ]]..'\x16'..[[5; value: abcC3 (['abcC3']), expr: abcC3 (['abcC3'])
      ==
      =abcC3=
      {{{2 setreg('d', ['abcD3'])
      d: type V; value: abcD3]].."\x00 (['abcD3']), expr: abcD3\x00"..[[ (['abcD3'])
      ==
      abcD3
      ==
      {{{2 setreg('e', [1, 2, 'abc', 3])
      e: type V; value: 1]].."\x002\x00abc\x003\x00 (['1', '2', 'abc', '3']), expr: 1\x002\x00abc\x003\x00"..[[ (['1', '2', 'abc', '3'])
      ==
      1
      2
      abc
      3
      ==
      {{{2 setreg('f', [1, 2, 3])
      f: type V; value: 1]].."\x002\x003\x00 (['1', '2', '3']), expr: 1\x002\x003\x00"..[[ (['1', '2', '3'])
      ==
      1
      2
      3
      ==
      {{{1 Appending lists with setreg()
      {{{2 setreg('A', ['abcA3c'], 'c')
      A: type v; value: abcA3]].."\x00abcA3c (['abcA3', 'abcA3c']), expr: abcA3\x00"..[[abcA3c (['abcA3', 'abcA3c'])
      ==
      =abcA3
      abcA3c=
      {{{2 setreg('b', ['abcB3l'], 'la')
      b: type V; value: abcB3]].."\x00abcB3l\x00 (['abcB3', 'abcB3l']), expr: abcB3\x00abcB3l\x00"..[[ (['abcB3', 'abcB3l'])
      ==
      abcB3
      abcB3l
      ==
      {{{2 setreg('C', ['abcC3b'], 'lb')
      C: type ]].."\x166; value: abcC3\x00abcC3b (['abcC3', 'abcC3b']), expr: abcC3\x00"..[[abcC3b (['abcC3', 'abcC3b'])
      ==
      =abcC3 =
       abcC3b
      {{{2 setreg('D', ['abcD32'])
      D: type V; value: abcD3]].."\x00abcD32\x00 (['abcD3', 'abcD32']), expr: abcD3\x00abcD32\x00"..[[ (['abcD3', 'abcD32'])
      ==
      abcD3
      abcD32
      ==
      {{{2 setreg('A', ['abcA32'])
      A: type V; value: abcA3]].."\x00abcA3c\x00abcA32\x00 (['abcA3', 'abcA3c', 'abcA32']), expr: abcA3\x00abcA3c\x00abcA32\x00"..[[ (['abcA3', 'abcA3c', 'abcA32'])
      ==
      abcA3
      abcA3c
      abcA32
      ==
      {{{2 setreg('B', ['abcB3c'], 'c')
      B: type v; value: abcB3]].."\x00abcB3l\x00abcB3c (['abcB3', 'abcB3l', 'abcB3c']), expr: abcB3\x00abcB3l\x00"..[[abcB3c (['abcB3', 'abcB3l', 'abcB3c'])
      ==
      =abcB3
      abcB3l
      abcB3c=
      {{{2 setreg('C', ['abcC3l'], 'l')
      C: type V; value: abcC3]].."\x00abcC3b\x00abcC3l\x00 (['abcC3', 'abcC3b', 'abcC3l']), expr: abcC3\x00abcC3b\x00abcC3l\x00"..[[ (['abcC3', 'abcC3b', 'abcC3l'])
      ==
      abcC3
      abcC3b
      abcC3l
      ==
      {{{2 setreg('D', ['abcD3b'], 'b')
      D: type ]].."\x166; value: abcD3\x00abcD32\x00abcD3b (['abcD3', 'abcD32', 'abcD3b']), expr: abcD3\x00abcD32\x00"..[[abcD3b (['abcD3', 'abcD32', 'abcD3b'])
      ==
      =abcD3 =
       abcD32
       abcD3b]])

    -- From now on we delete the buffer contents after each expect() to make
    -- the next expect() easier to write.  This is neccessary because null
    -- bytes on a line by itself don't play well together with the dedent
    -- function used in expect().
    execute('%delete')
    execute([[$put ='{{{1 Appending lists with NL with setreg()']])
    execute([=[call SetReg('A', ["\n", 'abcA3l2'], 'l')]=])
    expect(
      '\n'..
      '{{{1 Appending lists with NL with setreg()\n'..
      "{{{2 setreg('A', ['\x00', 'abcA3l2'], 'l')\n"..
      "A: type V; value: abcA3\x00abcA3c\x00abcA32\x00\x00\x00abcA3l2\x00 (['abcA3', 'abcA3c', 'abcA32', '\x00', 'abcA3l2']), expr: abcA3\x00abcA3c\x00abcA32\x00\x00\x00abcA3l2\x00 (['abcA3', 'abcA3c', 'abcA32', '\x00', 'abcA3l2'])\n"..
      '==\n'..
      'abcA3\n'..
      'abcA3c\n'..
      'abcA32\n'..
      '\x00\n'..
      'abcA3l2\n'..
      '==')
    execute('%delete')
    execute([=[call SetReg('B', ["\n", 'abcB3c2'], 'c')]=])
    expect(
      '\n'..
      "{{{2 setreg('B', ['\x00', 'abcB3c2'], 'c')\n"..
      "B: type v; value: abcB3\x00abcB3l\x00abcB3c\x00\x00\x00abcB3c2 (['abcB3', 'abcB3l', 'abcB3c', '\x00', 'abcB3c2']), expr: abcB3\x00abcB3l\x00abcB3c\x00\x00\x00abcB3c2 (['abcB3', 'abcB3l', 'abcB3c', '\x00', 'abcB3c2'])\n"..
      '==\n'..
      '=abcB3\n'..
      'abcB3l\n'..
      'abcB3c\n'..
      '\x00\n'..
      'abcB3c2=')
    execute('%delete')
    execute([=[call SetReg('C', ["\n", 'abcC3b2'], 'b')]=])
    expect(
      '\n'..
      "{{{2 setreg('C', ['\x00', 'abcC3b2'], 'b')\n"..
      "C: type \x167; value: abcC3\x00abcC3b\x00abcC3l\x00\x00\x00abcC3b2 (['abcC3', 'abcC3b', 'abcC3l', '\x00', 'abcC3b2']), expr: abcC3\x00abcC3b\x00abcC3l\x00\x00\x00abcC3b2 (['abcC3', 'abcC3b', 'abcC3l', '\x00', 'abcC3b2'])\n"..
      '==\n'..
      '=abcC3  =\n'..
      ' abcC3b\n'..
      ' abcC3l\n'..
      ' \x00\n'..
      ' abcC3b2')
    execute('%delete')
    execute([=[call SetReg('D', ["\n", 'abcD3b50'],'b50')]=])
    expect(
      '\n'..
      "{{{2 setreg('D', ['\x00', 'abcD3b50'], 'b50')\n"..
      "D: type \x1650; value: abcD3\x00abcD32\x00abcD3b\x00\x00\x00abcD3b50 (['abcD3', 'abcD32', 'abcD3b', '\x00', 'abcD3b50']), expr: abcD3\x00abcD32\x00abcD3b\x00\x00\x00abcD3b50 (['abcD3', 'abcD32', 'abcD3b', '\x00', 'abcD3b50'])\n"..
      '==\n'..
      '=abcD3                                             =\n'..
      ' abcD32\n'..
      ' abcD3b\n'..
      ' \x00\n'..
      ' abcD3b50')
  end)

  -- The tests for setting lists with NLs are split into seperate it() blocks
  -- to make the expect() calls easier to write.  Otherwise the null byte can
  -- make trouble on a line on its own.
  it('setting lists with NLs with setreg(), part 1', function()
    execute('so test_eval_setup.vim')
    execute([=[call SetReg('a', ['abcA4-0', "\n", "abcA4-2\n", "\nabcA4-3", "abcA4-4\nabcA4-4-2"])]=])
    expect(
     '\n'..
      "{{{2 setreg('a', ['abcA4-0', '\x00', 'abcA4-2\x00', '\x00abcA4-3', 'abcA4-4\x00abcA4-4-2'])\n"..
      "a: type V; value: abcA4-0\x00\x00\x00abcA4-2\x00\x00\x00abcA4-3\x00abcA4-4\x00abcA4-4-2\x00 (['abcA4-0', '\x00', 'abcA4-2\x00', '\x00abcA4-3', 'abcA4-4\x00abcA4-4-2']), expr: abcA4-0\x00\x00\x00abcA4-2\x00\x00\x00abcA4-3\x00abcA4-4\x00abcA4-4-2\x00 (['abcA4-0', '\x00', 'abcA4-2\x00', '\x00abcA4-3', 'abcA4-4\x00abcA4-4-2'])\n"..
      '==\n'..
      'abcA4-0\n'..
      '\x00\n'..
      'abcA4-2\x00\n'..
      '\x00abcA4-3\n'..
      'abcA4-4\x00abcA4-4-2\n'..
      '==')
  end)

  it('setting lists with NLs with setreg(), part 2', function()
    execute('so test_eval_setup.vim')
    execute([=[call SetReg('b', ['abcB4c-0', "\n", "abcB4c-2\n", "\nabcB4c-3", "abcB4c-4\nabcB4c-4-2"], 'c')]=])
    expect(
      '\n'..
      "{{{2 setreg('b', ['abcB4c-0', '\x00', 'abcB4c-2\x00', '\x00abcB4c-3', 'abcB4c-4\x00abcB4c-4-2'], 'c')\n"..
      "b: type v; value: abcB4c-0\x00\x00\x00abcB4c-2\x00\x00\x00abcB4c-3\x00abcB4c-4\x00abcB4c-4-2 (['abcB4c-0', '\x00', 'abcB4c-2\x00', '\x00abcB4c-3', 'abcB4c-4\x00abcB4c-4-2']), expr: abcB4c-0\x00\x00\x00abcB4c-2\x00\x00\x00abcB4c-3\x00abcB4c-4\x00abcB4c-4-2 (['abcB4c-0', '\x00', 'abcB4c-2\x00', '\x00abcB4c-3', 'abcB4c-4\x00abcB4c-4-2'])\n"..
      '==\n'..
      '=abcB4c-0\n'..
      '\x00\n'..
      'abcB4c-2\x00\n'..
      '\x00abcB4c-3\n'..
      'abcB4c-4\x00abcB4c-4-2=')
  end)

  it('setting lists with NLs with setreg(), part 3', function()
    execute('so test_eval_setup.vim')
    execute([=[call SetReg('c', ['abcC4l-0', "\n", "abcC4l-2\n", "\nabcC4l-3", "abcC4l-4\nabcC4l-4-2"], 'l')]=])
    expect(
      '\n'..
      "{{{2 setreg('c', ['abcC4l-0', '\x00', 'abcC4l-2\x00', '\x00abcC4l-3', 'abcC4l-4\x00abcC4l-4-2'], 'l')\n"..
      "c: type V; value: abcC4l-0\x00\x00\x00abcC4l-2\x00\x00\x00abcC4l-3\x00abcC4l-4\x00abcC4l-4-2\x00 (['abcC4l-0', '\x00', 'abcC4l-2\x00', '\x00abcC4l-3', 'abcC4l-4\x00abcC4l-4-2']), expr: abcC4l-0\x00\x00\x00abcC4l-2\x00\x00\x00abcC4l-3\x00abcC4l-4\x00abcC4l-4-2\x00 (['abcC4l-0', '\x00', 'abcC4l-2\x00', '\x00abcC4l-3', 'abcC4l-4\x00abcC4l-4-2'])\n"..
      '==\n'..
      'abcC4l-0\n'..
      '\x00\n'..
      'abcC4l-2\x00\n'..
      '\x00abcC4l-3\n'..
      'abcC4l-4\x00abcC4l-4-2\n'..
      '==')
  end)
  it('setting lists with NLs with setreg(), part 4', function()
    execute('so test_eval_setup.vim')
    execute([=[call SetReg('d', ['abcD4b-0', "\n", "abcD4b-2\n", "\nabcD4b-3", "abcD4b-4\nabcD4b-4-2"], 'b')]=])
    expect(
      '\n'..
      "{{{2 setreg('d', ['abcD4b-0', '\x00', 'abcD4b-2\x00', '\x00abcD4b-3', 'abcD4b-4\x00abcD4b-4-2'], 'b')\n"..
      "d: type \x1619; value: abcD4b-0\x00\x00\x00abcD4b-2\x00\x00\x00abcD4b-3\x00abcD4b-4\x00abcD4b-4-2 (['abcD4b-0', '\x00', 'abcD4b-2\x00', '\x00abcD4b-3', 'abcD4b-4\x00abcD4b-4-2']), expr: abcD4b-0\x00\x00\x00abcD4b-2\x00\x00\x00abcD4b-3\x00abcD4b-4\x00abcD4b-4-2 (['abcD4b-0', '\x00', 'abcD4b-2\x00', '\x00abcD4b-3', 'abcD4b-4\x00abcD4b-4-2'])\n"..
      '==\n'..
      '=abcD4b-0           =\n'..
      ' \x00\n'..
      ' abcD4b-2\x00\n'..
      ' \x00abcD4b-3\n'..
      ' abcD4b-4\x00abcD4b-4-2')
  end)
  it('setting lists with NLs with setreg(), part 5', function()
    execute('so test_eval_setup.vim')
    execute([=[call SetReg('e', ['abcE4b10-0', "\n", "abcE4b10-2\n", "\nabcE4b10-3", "abcE4b10-4\nabcE4b10-4-2"], 'b10')]=])
    expect(
      '\n'..
      "{{{2 setreg('e', ['abcE4b10-0', '\x00', 'abcE4b10-2\x00', '\x00abcE4b10-3', 'abcE4b10-4\x00abcE4b10-4-2'], 'b10')\n"..
      "e: type \x1610; value: abcE4b10-0\x00\x00\x00abcE4b10-2\x00\x00\x00abcE4b10-3\x00abcE4b10-4\x00abcE4b10-4-2 (['abcE4b10-0', '\x00', 'abcE4b10-2\x00', '\x00abcE4b10-3', 'abcE4b10-4\x00abcE4b10-4-2']), expr: abcE4b10-0\x00\x00\x00abcE4b10-2\x00\x00\x00abcE4b10-3\x00abcE4b10-4\x00abcE4b10-4-2 (['abcE4b10-0', '\x00', 'abcE4b10-2\x00', '\x00abcE4b10-3', 'abcE4b10-4\x00abcE4b10-4-2'])\n"..
      '==\n'..
      '=abcE4b10-0=\n'..
      ' \x00\n'..
      ' abcE4b10-2\x00\n'..
      ' \x00abcE4b10-3\n'..
      ' abcE4b10-4\x00abcE4b10-4-2')
  end)

  it('search and expressions', function()
    execute('so test_eval_setup.vim')
    execute([=[call SetReg('/', ['abc/'])]=])
    execute([=[call SetReg('/', ["abc/\n"])]=])
    execute([=[call SetReg('=', ['"abc/"'])]=])
    execute([=[call SetReg('=', ["\"abc/\n\""])]=])
    expect([[
      
      {{{2 setreg('/', ['abc/'])
      /: type v; value: abc/ (['abc/']), expr: abc/ (['abc/'])
      ==
      =abc/=
      {{{2 setreg('/', ['abc/]]..'\x00'..[['])
      /: type v; value: abc/]].."\x00 (['abc/\x00']), expr: abc/\x00 (['abc/\x00"..[['])
      ==
      =abc/]]..'\x00'..[[=
      {{{2 setreg('=', ['"abc/"'])
      =: type v; value: abc/ (['abc/']), expr: "abc/" (['"abc/"'])
      {{{2 setreg('=', ['"abc/]]..'\x00'..[["'])
      =: type v; value: abc/]].."\x00 (['abc/\x00"..[[']), expr: "abc/]]..'\x00'..[[" (['"abc/]]..'\x00'..[["'])]])
  end)

  if has_clipboard() then
    it('system clipboard', function()
      insert([[
	Some first line (this text was at the top of the old test_eval.in).
	
	Note: system clipboard is saved, changed and restored.
	
	clipboard contents
	something else]])
      execute('so test_eval_setup.vim')
      -- Save and restore system clipboard.
      execute("let _clipreg = ['*', getreg('*'), getregtype('*')]")
      execute('let _clipopt = &cb')
      execute("let &cb='unnamed'")
      execute('5y')
      execute('AR *')
      execute('tabdo :windo :echo "hi"')
      execute('6y')
      execute('AR *')
      execute('let &cb=_clipopt')
      execute("call call('setreg', _clipreg)")
      expect([[
	Some first line (this text was at the top of the old test_eval.in).
	
	Note: system clipboard is saved, changed and restored.
	
	clipboard contents
	something else
	*: type V; value: clipboard contents]]..'\00'..[[ (['clipboard contents']), expr: clipboard contents]]..'\00'..[[ (['clipboard contents'])
	*: type V; value: something else]]..'\00'..[[ (['something else']), expr: something else]]..'\00'..[[ (['something else'])]])
    end)
  else
    pending('system clipboard not available', function() end)
  end

  it('errors', function()
    source([[
      fun ErrExe(str)
	call append('$', 'Executing '.a:str)
	try
	  execute a:str
	catch
	  $put =v:exception
	endtry
      endfun]])
    execute([[call ErrExe('call setreg()')]])
    execute([[call ErrExe('call setreg(1)')]])
    execute([[call ErrExe('call setreg(1, 2, 3, 4)')]])
    execute([=[call ErrExe('call setreg([], 2)')]=])
    execute([[call ErrExe('call setreg(1, {})')]])
    execute([=[call ErrExe('call setreg(1, 2, [])')]=])
    execute([=[call ErrExe('call setreg("/", ["1", "2"])')]=])
    execute([=[call ErrExe('call setreg("=", ["1", "2"])')]=])
    execute([=[call ErrExe('call setreg(1, ["", "", [], ""])')]=])
    expect([[
      
      Executing call setreg()
      Vim(call):E119: Not enough arguments for function: setreg
      Executing call setreg(1)
      Vim(call):E119: Not enough arguments for function: setreg
      Executing call setreg(1, 2, 3, 4)
      Vim(call):E118: Too many arguments for function: setreg
      Executing call setreg([], 2)
      Vim(call):E730: using List as a String
      Executing call setreg(1, {})
      Vim(call):E731: using Dictionary as a String
      Executing call setreg(1, 2, [])
      Vim(call):E730: using List as a String
      Executing call setreg("/", ["1", "2"])
      Vim(call):E883: search pattern and expression register may not contain two or more lines
      Executing call setreg("=", ["1", "2"])
      Vim(call):E883: search pattern and expression register may not contain two or more lines
      Executing call setreg(1, ["", "", [], ""])
      Vim(call):E730: using List as a String]])
  end)

  it('function name not starting with a capital', function()
    execute('try')
    execute('  func! g:test()')
    execute('    echo "test"')
    execute('  endfunc')
    execute('catch')
    execute('  let tmp = v:exception')
    execute('endtry')
    eq('Vim(function):E128: Function name must start with a capital or "s:": g:test()', eval('tmp'))
  end)

  it('Function name followed by #', function()
    execute('try')
    execute('  func! test2() "#')
    execute('    echo "test2"')
    execute('  endfunc')
    execute('catch')
    execute('  let tmp = v:exception')
    execute('endtry')
    eq('Vim(function):E128: Function name must start with a capital or "s:": test2() "#', eval('tmp'))
  end)

  it('function name includes a colon', function()
    execute('try')
    execute('  func! b:test()')
    execute('    echo "test"')
    execute('  endfunc')
    execute('catch')
    execute('  let tmp = v:exception')
    execute('endtry')
    eq('Vim(function):E128: Function name must start with a capital or "s:": b:test()', eval('tmp'))
  end)

  it('function name starting with/without "g:", buffer-local funcref', function()
    execute('function! g:Foo(n)')
    execute("  $put ='called Foo(' . a:n . ')'")
    execute('endfunction')
    execute("let b:my_func = function('Foo')")
    execute('call b:my_func(1)')
    execute('echo g:Foo(2)')
    execute('echo Foo(3)')
    expect([[
      
      called Foo(1)
      called Foo(2)
      called Foo(3)]])
  end)

  it('script-local function used in Funcref must exist', function()
    source([[
      " Vim script used in test_eval.in.  Needed for script-local function.
      
      func! s:Testje()
        return "foo"
      endfunc
      
      let Bar = function('s:Testje')
      
      $put ='s:Testje exists: ' . exists('s:Testje')
      $put ='func s:Testje exists: ' . exists('*s:Testje')
      $put ='Bar exists: ' . exists('Bar')
      $put ='func Bar exists: ' . exists('*Bar')
      ]])
    expect([[
      
      s:Testje exists: 0
      func s:Testje exists: 1
      Bar exists: 1
      func Bar exists: 1]])
  end)

  it("using $ instead of '$' must give an error", function()
    execute('try')
    execute("  call append($, 'foobar')")
    execute('catch')
    execute('  let tmp = v:exception')
    execute('endtry')
    eq('Vim(call):E116: Invalid arguments for function append', eval('tmp'))
  end)

  it('getcurpos/setpos', function()
    insert([[
      012345678
      012345678

      start:]])
    execute('/^012345678')
    feed('6l')
    execute('let sp = getcurpos()')
    feed('0')
    execute("call setpos('.', sp)")
    feed('jyl')
    execute('$put')
    expect([[
      012345678
      012345678

      start:
      6]])
  end)
end)
