-- Test for various eval features.

local t = require('test.functional.testutil')(after_each)
local assert_alive = t.assert_alive
local feed, insert, source = t.feed, t.insert, t.source
local clear, command, expect = t.clear, t.command, t.expect
local eq, eval, write_file = t.eq, t.eval, t.write_file
local poke_eventloop = t.poke_eventloop
local exc_exec = t.exc_exec
local dedent = t.dedent

describe('eval', function()
  setup(function()
    write_file(
      'test_eval_setup.vim',
      [[
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
      ]]
    )
  end)
  before_each(clear)
  teardown(function()
    os.remove('test_eval_setup.vim')
  end)

  it(':let', function()
    command('so test_eval_setup.vim')
    command([[let @" = 'abc']])
    command('AR "')
    command([[let @" = "abc\n"]])
    source('AR "')
    command([[let @" = "abc\<C-m>"]])
    command('AR "')
    command([[let @= = '"abc"']])
    command('AR =')
    expect([[

      ": type v; value: abc (['abc']), expr: abc (['abc'])
      ": type V; value: abc]] .. "\000 (['abc']), expr: abc\000" .. [[ (['abc'])
      ": type V; value: abc]] .. "\r\000 (['abc\r']), expr: abc\r\000 (['abc\r" .. [['])
      =: type v; value: abc (['abc']), expr: "abc" (['"abc"'])]])
  end)

  it('basic setreg() tests', function()
    command('so test_eval_setup.vim')
    insert('{{{1 Basic setreg tests')
    command([[call SetReg('a', 'abcA', 'c')]])
    command([[call SetReg('b', 'abcB', 'v')]])
    command([[call SetReg('c', 'abcC', 'l')]])
    command([[call SetReg('d', 'abcD', 'V')]])
    command([[call SetReg('e', 'abcE', 'b')]])
    command([[call SetReg('f', 'abcF', "\<C-v>")]])
    command([[call SetReg('g', 'abcG', 'b10')]])
    command([[call SetReg('h', 'abcH', "\<C-v>10")]])
    command([[call SetReg('I', 'abcI')]])

    feed('Go{{{1 Appending single lines with setreg()<esc>')
    poke_eventloop()
    command([[call SetReg('A', 'abcAc', 'c')]])
    command([[call SetReg('A', 'abcAl', 'l')]])
    command([[call SetReg('A', 'abcAc2','c')]])
    command([[call SetReg('b', 'abcBc', 'ca')]])
    command([[call SetReg('b', 'abcBb', 'ba')]])
    command([[call SetReg('b', 'abcBc2','ca')]])
    command([[call SetReg('b', 'abcBb2','b50a')]])
    command([[call SetReg('C', 'abcCl', 'l')]])
    command([[call SetReg('C', 'abcCc', 'c')]])
    command([[call SetReg('D', 'abcDb', 'b')]])
    command([[call SetReg('E', 'abcEb', 'b')]])
    command([[call SetReg('E', 'abcEl', 'l')]])
    command([[call SetReg('F', 'abcFc', 'c')]])
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
      c: type V; value: abcC]] .. "\000 (['abcC']), expr: abcC\000" .. [[ (['abcC'])
      ==
      abcC
      ==
      {{{2 setreg('d', 'abcD', 'V')
      d: type V; value: abcD]] .. "\000 (['abcD']), expr: abcD\000" .. [[ (['abcD'])
      ==
      abcD
      ==
      {{{2 setreg('e', 'abcE', 'b')
      e: type ]] .. '\022' .. [[4; value: abcE (['abcE']), expr: abcE (['abcE'])
      ==
      =abcE=
      {{{2 setreg('f', 'abcF', ']] .. '\022' .. [[')
      f: type ]] .. '\022' .. [[4; value: abcF (['abcF']), expr: abcF (['abcF'])
      ==
      =abcF=
      {{{2 setreg('g', 'abcG', 'b10')
      g: type ]] .. '\022' .. [[10; value: abcG (['abcG']), expr: abcG (['abcG'])
      ==
      =abcG      =
      {{{2 setreg('h', 'abcH', ']] .. '\022' .. [[10')
      h: type ]] .. '\022' .. [[10; value: abcH (['abcH']), expr: abcH (['abcH'])
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
      A: type V; value: abcAabcAcabcAl]] .. "\000 (['abcAabcAcabcAl']), expr: abcAabcAcabcAl\000" .. [[ (['abcAabcAcabcAl'])
      ==
      abcAabcAcabcAl
      ==
      {{{2 setreg('A', 'abcAc2', 'c')
      A: type v; value: abcAabcAcabcAl]] .. "\000abcAc2 (['abcAabcAcabcAl', 'abcAc2']), expr: abcAabcAcabcAl\000" .. [[abcAc2 (['abcAabcAcabcAl', 'abcAc2'])
      ==
      =abcAabcAcabcAl
      abcAc2=
      {{{2 setreg('b', 'abcBc', 'ca')
      b: type v; value: abcBabcBc (['abcBabcBc']), expr: abcBabcBc (['abcBabcBc'])
      ==
      =abcBabcBc=
      {{{2 setreg('b', 'abcBb', 'ba')
      b: type ]] .. '\022' .. [[5; value: abcBabcBcabcBb (['abcBabcBcabcBb']), expr: abcBabcBcabcBb (['abcBabcBcabcBb'])
      ==
      =abcBabcBcabcBb=
      {{{2 setreg('b', 'abcBc2', 'ca')
      b: type v; value: abcBabcBcabcBb]] .. "\000abcBc2 (['abcBabcBcabcBb', 'abcBc2']), expr: abcBabcBcabcBb\000" .. [[abcBc2 (['abcBabcBcabcBb', 'abcBc2'])
      ==
      =abcBabcBcabcBb
      abcBc2=
      {{{2 setreg('b', 'abcBb2', 'b50a')
      b: type ]] .. "\02250; value: abcBabcBcabcBb\000abcBc2abcBb2 (['abcBabcBcabcBb', 'abcBc2abcBb2']), expr: abcBabcBcabcBb\000" .. [[abcBc2abcBb2 (['abcBabcBcabcBb', 'abcBc2abcBb2'])
      ==
      =abcBabcBcabcBb                                    =
       abcBc2abcBb2
      {{{2 setreg('C', 'abcCl', 'l')
      C: type V; value: abcC]] .. "\000abcCl\000 (['abcC', 'abcCl']), expr: abcC\000abcCl\000" .. [[ (['abcC', 'abcCl'])
      ==
      abcC
      abcCl
      ==
      {{{2 setreg('C', 'abcCc', 'c')
      C: type v; value: abcC]] .. "\000abcCl\000abcCc (['abcC', 'abcCl', 'abcCc']), expr: abcC\000abcCl\000" .. [[abcCc (['abcC', 'abcCl', 'abcCc'])
      ==
      =abcC
      abcCl
      abcCc=
      {{{2 setreg('D', 'abcDb', 'b')
      D: type ]] .. "\0225; value: abcD\000abcDb (['abcD', 'abcDb']), expr: abcD\000" .. [[abcDb (['abcD', 'abcDb'])
      ==
      =abcD =
       abcDb
      {{{2 setreg('E', 'abcEb', 'b')
      E: type ]] .. "\0225; value: abcE\000abcEb (['abcE', 'abcEb']), expr: abcE\000" .. [[abcEb (['abcE', 'abcEb'])
      ==
      =abcE =
       abcEb
      {{{2 setreg('E', 'abcEl', 'l')
      E: type V; value: abcE]] .. "\000abcEb\000abcEl\000 (['abcE', 'abcEb', 'abcEl']), expr: abcE\000abcEb\000abcEl\000" .. [[ (['abcE', 'abcEb', 'abcEl'])
      ==
      abcE
      abcEb
      abcEl
      ==
      {{{2 setreg('F', 'abcFc', 'c')
      F: type v; value: abcF]] .. "\000abcFc (['abcF', 'abcFc']), expr: abcF\000" .. [[abcFc (['abcF', 'abcFc'])
      ==
      =abcF
      abcFc=]])
  end)

  it('appending NL with setreg()', function()
    command('so test_eval_setup.vim')

    command([[call setreg('a', 'abcA2', 'c')]])
    command([[call setreg('b', 'abcB2', 'v')]])
    command([[call setreg('c', 'abcC2', 'l')]])
    command([[call setreg('d', 'abcD2', 'V')]])
    command([[call setreg('e', 'abcE2', 'b')]])
    command([[call setreg('f', 'abcF2', "\<C-v>")]])
    -- These registers where set like this in the old test_eval.in but never
    -- copied to the output buffer with SetReg().  They do not appear in
    -- test_eval.ok.  Therefore they are commented out.
    --execute([[call setreg('g', 'abcG2', 'b10')]])
    --execute([[call setreg('h', 'abcH2', "\<C-v>10")]])
    --execute([[call setreg('I', 'abcI2')]])

    command([[call SetReg('A', "\n")]])
    command([[call SetReg('B', "\n", 'c')]])
    command([[call SetReg('C', "\n")]])
    command([[call SetReg('D', "\n", 'l')]])
    command([[call SetReg('E', "\n")]])
    command([[call SetReg('F', "\n", 'b')]])
    expect([[

      {{{2 setreg('A', ']] .. '\000' .. [[')
      A: type V; value: abcA2]] .. "\000 (['abcA2']), expr: abcA2\000" .. [[ (['abcA2'])
      ==
      abcA2
      ==
      {{{2 setreg('B', ']] .. '\000' .. [[', 'c')
      B: type v; value: abcB2]] .. "\000 (['abcB2', '']), expr: abcB2\000" .. [[ (['abcB2', ''])
      ==
      =abcB2
      =
      {{{2 setreg('C', ']] .. '\000' .. [[')
      C: type V; value: abcC2]] .. "\000\000 (['abcC2', '']), expr: abcC2\000\000" .. [[ (['abcC2', ''])
      ==
      abcC2

      ==
      {{{2 setreg('D', ']] .. '\000' .. [[', 'l')
      D: type V; value: abcD2]] .. "\000\000 (['abcD2', '']), expr: abcD2\000\000" .. [[ (['abcD2', ''])
      ==
      abcD2

      ==
      {{{2 setreg('E', ']] .. '\000' .. [[')
      E: type V; value: abcE2]] .. "\000\000 (['abcE2', '']), expr: abcE2\000\000" .. [[ (['abcE2', ''])
      ==
      abcE2

      ==
      {{{2 setreg('F', ']] .. '\000' .. [[', 'b')
      F: type ]] .. "\0220; value: abcF2\000 (['abcF2', '']), expr: abcF2\000" .. [[ (['abcF2', ''])
      ==
      =abcF2=
       ]])
  end)

  it('setting and appending list with setreg()', function()
    command('so test_eval_setup.vim')

    command([[$put ='{{{1 Setting lists with setreg()']])
    command([=[call SetReg('a', ['abcA3'], 'c')]=])
    command([=[call SetReg('b', ['abcB3'], 'l')]=])
    command([=[call SetReg('c', ['abcC3'], 'b')]=])
    command([=[call SetReg('d', ['abcD3'])]=])
    command([=[call SetReg('e', [1, 2, 'abc', 3])]=])
    command([=[call SetReg('f', [1, 2, 3])]=])

    command([[$put ='{{{1 Appending lists with setreg()']])
    command([=[call SetReg('A', ['abcA3c'], 'c')]=])
    command([=[call SetReg('b', ['abcB3l'], 'la')]=])
    command([=[call SetReg('C', ['abcC3b'], 'lb')]=])
    command([=[call SetReg('D', ['abcD32'])]=])
    command([=[call SetReg('A', ['abcA32'])]=])
    command([=[call SetReg('B', ['abcB3c'], 'c')]=])
    command([=[call SetReg('C', ['abcC3l'], 'l')]=])
    command([=[call SetReg('D', ['abcD3b'], 'b')]=])
    expect([[

      {{{1 Setting lists with setreg()
      {{{2 setreg('a', ['abcA3'], 'c')
      a: type v; value: abcA3 (['abcA3']), expr: abcA3 (['abcA3'])
      ==
      =abcA3=
      {{{2 setreg('b', ['abcB3'], 'l')
      b: type V; value: abcB3]] .. "\000 (['abcB3']), expr: abcB3\000" .. [[ (['abcB3'])
      ==
      abcB3
      ==
      {{{2 setreg('c', ['abcC3'], 'b')
      c: type ]] .. '\022' .. [[5; value: abcC3 (['abcC3']), expr: abcC3 (['abcC3'])
      ==
      =abcC3=
      {{{2 setreg('d', ['abcD3'])
      d: type V; value: abcD3]] .. "\000 (['abcD3']), expr: abcD3\000" .. [[ (['abcD3'])
      ==
      abcD3
      ==
      {{{2 setreg('e', [1, 2, 'abc', 3])
      e: type V; value: 1]] .. "\0002\000abc\0003\000 (['1', '2', 'abc', '3']), expr: 1\0002\000abc\0003\000" .. [[ (['1', '2', 'abc', '3'])
      ==
      1
      2
      abc
      3
      ==
      {{{2 setreg('f', [1, 2, 3])
      f: type V; value: 1]] .. "\0002\0003\000 (['1', '2', '3']), expr: 1\0002\0003\000" .. [[ (['1', '2', '3'])
      ==
      1
      2
      3
      ==
      {{{1 Appending lists with setreg()
      {{{2 setreg('A', ['abcA3c'], 'c')
      A: type v; value: abcA3]] .. "\000abcA3c (['abcA3', 'abcA3c']), expr: abcA3\000" .. [[abcA3c (['abcA3', 'abcA3c'])
      ==
      =abcA3
      abcA3c=
      {{{2 setreg('b', ['abcB3l'], 'la')
      b: type V; value: abcB3]] .. "\000abcB3l\000 (['abcB3', 'abcB3l']), expr: abcB3\000abcB3l\000" .. [[ (['abcB3', 'abcB3l'])
      ==
      abcB3
      abcB3l
      ==
      {{{2 setreg('C', ['abcC3b'], 'lb')
      C: type ]] .. "\0226; value: abcC3\000abcC3b (['abcC3', 'abcC3b']), expr: abcC3\000" .. [[abcC3b (['abcC3', 'abcC3b'])
      ==
      =abcC3 =
       abcC3b
      {{{2 setreg('D', ['abcD32'])
      D: type V; value: abcD3]] .. "\000abcD32\000 (['abcD3', 'abcD32']), expr: abcD3\000abcD32\000" .. [[ (['abcD3', 'abcD32'])
      ==
      abcD3
      abcD32
      ==
      {{{2 setreg('A', ['abcA32'])
      A: type V; value: abcA3]] .. "\000abcA3c\000abcA32\000 (['abcA3', 'abcA3c', 'abcA32']), expr: abcA3\000abcA3c\000abcA32\000" .. [[ (['abcA3', 'abcA3c', 'abcA32'])
      ==
      abcA3
      abcA3c
      abcA32
      ==
      {{{2 setreg('B', ['abcB3c'], 'c')
      B: type v; value: abcB3]] .. "\000abcB3l\000abcB3c (['abcB3', 'abcB3l', 'abcB3c']), expr: abcB3\000abcB3l\000" .. [[abcB3c (['abcB3', 'abcB3l', 'abcB3c'])
      ==
      =abcB3
      abcB3l
      abcB3c=
      {{{2 setreg('C', ['abcC3l'], 'l')
      C: type V; value: abcC3]] .. "\000abcC3b\000abcC3l\000 (['abcC3', 'abcC3b', 'abcC3l']), expr: abcC3\000abcC3b\000abcC3l\000" .. [[ (['abcC3', 'abcC3b', 'abcC3l'])
      ==
      abcC3
      abcC3b
      abcC3l
      ==
      {{{2 setreg('D', ['abcD3b'], 'b')
      D: type ]] .. "\0226; value: abcD3\000abcD32\000abcD3b (['abcD3', 'abcD32', 'abcD3b']), expr: abcD3\000abcD32\000" .. [[abcD3b (['abcD3', 'abcD32', 'abcD3b'])
      ==
      =abcD3 =
       abcD32
       abcD3b]])

    -- From now on we delete the buffer contents after each expect() to make
    -- the next expect() easier to write.  This is necessary because null
    -- bytes on a line by itself don't play well together with the dedent
    -- function used in expect().
    command('%delete')
    command([[$put ='{{{1 Appending lists with NL with setreg()']])
    command([=[call SetReg('A', ["\n", 'abcA3l2'], 'l')]=])
    expect(
      '\n'
        .. '{{{1 Appending lists with NL with setreg()\n'
        .. "{{{2 setreg('A', ['\000', 'abcA3l2'], 'l')\n"
        .. "A: type V; value: abcA3\000abcA3c\000abcA32\000\000\000abcA3l2\000 (['abcA3', 'abcA3c', 'abcA32', '\000', 'abcA3l2']), expr: abcA3\000abcA3c\000abcA32\000\000\000abcA3l2\000 (['abcA3', 'abcA3c', 'abcA32', '\000', 'abcA3l2'])\n"
        .. '==\n'
        .. 'abcA3\n'
        .. 'abcA3c\n'
        .. 'abcA32\n'
        .. '\000\n'
        .. 'abcA3l2\n'
        .. '=='
    )
    command('%delete')
    command([=[call SetReg('B', ["\n", 'abcB3c2'], 'c')]=])
    expect(
      '\n'
        .. "{{{2 setreg('B', ['\000', 'abcB3c2'], 'c')\n"
        .. "B: type v; value: abcB3\000abcB3l\000abcB3c\000\000\000abcB3c2 (['abcB3', 'abcB3l', 'abcB3c', '\000', 'abcB3c2']), expr: abcB3\000abcB3l\000abcB3c\000\000\000abcB3c2 (['abcB3', 'abcB3l', 'abcB3c', '\000', 'abcB3c2'])\n"
        .. '==\n'
        .. '=abcB3\n'
        .. 'abcB3l\n'
        .. 'abcB3c\n'
        .. '\000\n'
        .. 'abcB3c2='
    )
    command('%delete')
    command([=[call SetReg('C', ["\n", 'abcC3b2'], 'b')]=])
    expect(
      '\n'
        .. "{{{2 setreg('C', ['\000', 'abcC3b2'], 'b')\n"
        .. "C: type \0227; value: abcC3\000abcC3b\000abcC3l\000\000\000abcC3b2 (['abcC3', 'abcC3b', 'abcC3l', '\000', 'abcC3b2']), expr: abcC3\000abcC3b\000abcC3l\000\000\000abcC3b2 (['abcC3', 'abcC3b', 'abcC3l', '\000', 'abcC3b2'])\n"
        .. '==\n'
        .. '=abcC3  =\n'
        .. ' abcC3b\n'
        .. ' abcC3l\n'
        .. ' \000\n'
        .. ' abcC3b2'
    )
    command('%delete')
    command([=[call SetReg('D', ["\n", 'abcD3b50'],'b50')]=])
    expect(
      '\n'
        .. "{{{2 setreg('D', ['\000', 'abcD3b50'], 'b50')\n"
        .. "D: type \02250; value: abcD3\000abcD32\000abcD3b\000\000\000abcD3b50 (['abcD3', 'abcD32', 'abcD3b', '\000', 'abcD3b50']), expr: abcD3\000abcD32\000abcD3b\000\000\000abcD3b50 (['abcD3', 'abcD32', 'abcD3b', '\000', 'abcD3b50'])\n"
        .. '==\n'
        .. '=abcD3                                             =\n'
        .. ' abcD32\n'
        .. ' abcD3b\n'
        .. ' \000\n'
        .. ' abcD3b50'
    )
  end)

  -- The tests for setting lists with NLs are split into separate it() blocks
  -- to make the expect() calls easier to write.  Otherwise the null byte can
  -- make trouble on a line on its own.
  it('setting lists with NLs with setreg(), part 1', function()
    command('so test_eval_setup.vim')
    command(
      [=[call SetReg('a', ['abcA4-0', "\n", "abcA4-2\n", "\nabcA4-3", "abcA4-4\nabcA4-4-2"])]=]
    )
    expect(
      '\n'
        .. "{{{2 setreg('a', ['abcA4-0', '\000', 'abcA4-2\000', '\000abcA4-3', 'abcA4-4\000abcA4-4-2'])\n"
        .. "a: type V; value: abcA4-0\000\000\000abcA4-2\000\000\000abcA4-3\000abcA4-4\000abcA4-4-2\000 (['abcA4-0', '\000', 'abcA4-2\000', '\000abcA4-3', 'abcA4-4\000abcA4-4-2']), expr: abcA4-0\000\000\000abcA4-2\000\000\000abcA4-3\000abcA4-4\000abcA4-4-2\000 (['abcA4-0', '\000', 'abcA4-2\000', '\000abcA4-3', 'abcA4-4\000abcA4-4-2'])\n"
        .. '==\n'
        .. 'abcA4-0\n'
        .. '\000\n'
        .. 'abcA4-2\000\n'
        .. '\000abcA4-3\n'
        .. 'abcA4-4\000abcA4-4-2\n'
        .. '=='
    )
  end)

  it('setting lists with NLs with setreg(), part 2', function()
    command('so test_eval_setup.vim')
    command(
      [=[call SetReg('b', ['abcB4c-0', "\n", "abcB4c-2\n", "\nabcB4c-3", "abcB4c-4\nabcB4c-4-2"], 'c')]=]
    )
    expect(
      '\n'
        .. "{{{2 setreg('b', ['abcB4c-0', '\000', 'abcB4c-2\000', '\000abcB4c-3', 'abcB4c-4\000abcB4c-4-2'], 'c')\n"
        .. "b: type v; value: abcB4c-0\000\000\000abcB4c-2\000\000\000abcB4c-3\000abcB4c-4\000abcB4c-4-2 (['abcB4c-0', '\000', 'abcB4c-2\000', '\000abcB4c-3', 'abcB4c-4\000abcB4c-4-2']), expr: abcB4c-0\000\000\000abcB4c-2\000\000\000abcB4c-3\000abcB4c-4\000abcB4c-4-2 (['abcB4c-0', '\000', 'abcB4c-2\000', '\000abcB4c-3', 'abcB4c-4\000abcB4c-4-2'])\n"
        .. '==\n'
        .. '=abcB4c-0\n'
        .. '\000\n'
        .. 'abcB4c-2\000\n'
        .. '\000abcB4c-3\n'
        .. 'abcB4c-4\000abcB4c-4-2='
    )
  end)

  it('setting lists with NLs with setreg(), part 3', function()
    command('so test_eval_setup.vim')
    command(
      [=[call SetReg('c', ['abcC4l-0', "\n", "abcC4l-2\n", "\nabcC4l-3", "abcC4l-4\nabcC4l-4-2"], 'l')]=]
    )
    expect(
      '\n'
        .. "{{{2 setreg('c', ['abcC4l-0', '\000', 'abcC4l-2\000', '\000abcC4l-3', 'abcC4l-4\000abcC4l-4-2'], 'l')\n"
        .. "c: type V; value: abcC4l-0\000\000\000abcC4l-2\000\000\000abcC4l-3\000abcC4l-4\000abcC4l-4-2\000 (['abcC4l-0', '\000', 'abcC4l-2\000', '\000abcC4l-3', 'abcC4l-4\000abcC4l-4-2']), expr: abcC4l-0\000\000\000abcC4l-2\000\000\000abcC4l-3\000abcC4l-4\000abcC4l-4-2\000 (['abcC4l-0', '\000', 'abcC4l-2\000', '\000abcC4l-3', 'abcC4l-4\000abcC4l-4-2'])\n"
        .. '==\n'
        .. 'abcC4l-0\n'
        .. '\000\n'
        .. 'abcC4l-2\000\n'
        .. '\000abcC4l-3\n'
        .. 'abcC4l-4\000abcC4l-4-2\n'
        .. '=='
    )
  end)
  it('setting lists with NLs with setreg(), part 4', function()
    command('so test_eval_setup.vim')
    command(
      [=[call SetReg('d', ['abcD4b-0', "\n", "abcD4b-2\n", "\nabcD4b-3", "abcD4b-4\nabcD4b-4-2"], 'b')]=]
    )
    expect(
      '\n'
        .. "{{{2 setreg('d', ['abcD4b-0', '\000', 'abcD4b-2\000', '\000abcD4b-3', 'abcD4b-4\000abcD4b-4-2'], 'b')\n"
        .. "d: type \02219; value: abcD4b-0\000\000\000abcD4b-2\000\000\000abcD4b-3\000abcD4b-4\000abcD4b-4-2 (['abcD4b-0', '\000', 'abcD4b-2\000', '\000abcD4b-3', 'abcD4b-4\000abcD4b-4-2']), expr: abcD4b-0\000\000\000abcD4b-2\000\000\000abcD4b-3\000abcD4b-4\000abcD4b-4-2 (['abcD4b-0', '\000', 'abcD4b-2\000', '\000abcD4b-3', 'abcD4b-4\000abcD4b-4-2'])\n"
        .. '==\n'
        .. '=abcD4b-0           =\n'
        .. ' \000\n'
        .. ' abcD4b-2\000\n'
        .. ' \000abcD4b-3\n'
        .. ' abcD4b-4\000abcD4b-4-2'
    )
  end)
  it('setting lists with NLs with setreg(), part 5', function()
    command('so test_eval_setup.vim')
    command(
      [=[call SetReg('e', ['abcE4b10-0', "\n", "abcE4b10-2\n", "\nabcE4b10-3", "abcE4b10-4\nabcE4b10-4-2"], 'b10')]=]
    )
    expect(
      '\n'
        .. "{{{2 setreg('e', ['abcE4b10-0', '\000', 'abcE4b10-2\000', '\000abcE4b10-3', 'abcE4b10-4\000abcE4b10-4-2'], 'b10')\n"
        .. "e: type \02210; value: abcE4b10-0\000\000\000abcE4b10-2\000\000\000abcE4b10-3\000abcE4b10-4\000abcE4b10-4-2 (['abcE4b10-0', '\000', 'abcE4b10-2\000', '\000abcE4b10-3', 'abcE4b10-4\000abcE4b10-4-2']), expr: abcE4b10-0\000\000\000abcE4b10-2\000\000\000abcE4b10-3\000abcE4b10-4\000abcE4b10-4-2 (['abcE4b10-0', '\000', 'abcE4b10-2\000', '\000abcE4b10-3', 'abcE4b10-4\000abcE4b10-4-2'])\n"
        .. '==\n'
        .. '=abcE4b10-0=\n'
        .. ' \000\n'
        .. ' abcE4b10-2\000\n'
        .. ' \000abcE4b10-3\n'
        .. ' abcE4b10-4\000abcE4b10-4-2'
    )
  end)

  it('getreg("a",1,1) returns a valid list when "a is unset', function()
    -- Precondition: "a is actually unset and "0 is nonempty
    eq('', eval("getregtype('a')"))
    eq('', eval("getreg('a')"))
    command("call setreg('0','text')")

    -- This used to return a NULL list
    -- which setreg didn't handle
    command("let x = getreg('a',1,1)")
    command("call setreg('0',x)")

    -- nvim didn't crash and "0 was emptied
    assert_alive()
    eq({}, eval("getreg('0',1,1)"))

    -- x is a mutable list
    command('let y = x')
    eq({}, eval('y'))
    command("call add(x, 'item')")
    eq({ 'item' }, eval('y'))
  end)

  it('sets the unnamed register when the "u" option is passed to setreg', function()
    command("call setreg('a','a reg', 'cu')")
    eq('a reg', eval('@"'))
    command("call setreg('b','b reg', 'cu')")
    eq('b reg', eval('@"'))
    command("call setreg('c','c reg', 'c')")
    eq('b reg', eval('@"'))
  end)

  it('search and expressions', function()
    command('so test_eval_setup.vim')
    command([=[call SetReg('/', ['abc/'])]=])
    command([=[call SetReg('/', ["abc/\n"])]=])
    command([=[call SetReg('=', ['"abc/"'])]=])
    command([=[call SetReg('=', ["\"abc/\n\""])]=])
    expect(
      [[

      {{{2 setreg('/', ['abc/'])
      /: type v; value: abc/ (['abc/']), expr: abc/ (['abc/'])
      ==
      =abc/=
      {{{2 setreg('/', ['abc/]]
        .. '\000'
        .. [['])
      /: type v; value: abc/]]
        .. "\000 (['abc/\000']), expr: abc/\000 (['abc/\000"
        .. [['])
      ==
      =abc/]]
        .. '\000'
        .. [[=
      {{{2 setreg('=', ['"abc/"'])
      =: type v; value: abc/ (['abc/']), expr: "abc/" (['"abc/"'])
      {{{2 setreg('=', ['"abc/]]
        .. '\000'
        .. [["'])
      =: type v; value: abc/]]
        .. "\000 (['abc/\000"
        .. [[']), expr: "abc/]]
        .. '\000'
        .. [[" (['"abc/]]
        .. '\000'
        .. [["'])]]
    )
  end)

  describe('system clipboard', function()
    before_each(function()
      command('let &runtimepath = "test/functional/fixtures,".&runtimepath')
      command('call getreg("*")') -- force load of provider
    end)

    it('works', function()
      insert([[
	Some first line (this text was at the top of the old test_eval.in).

	Note: system clipboard is saved, changed and restored.

	clipboard contents
	something else]])
      command('so test_eval_setup.vim')
      -- Save and restore system clipboard.
      command("let _clipreg = ['*', getreg('*'), getregtype('*')]")
      command('let _clipopt = &cb')
      command("let &cb='unnamed'")
      command('5y')
      command('AR *')
      command('tabdo :windo :echo "hi"')
      command('6y')
      command('AR *')
      command('let &cb=_clipopt')
      command("call call('setreg', _clipreg)")
      expect(
        [[
	Some first line (this text was at the top of the old test_eval.in).

	Note: system clipboard is saved, changed and restored.

	clipboard contents
	something else
	*: type V; value: clipboard contents]]
          .. '\00'
          .. [[ (['clipboard contents']), expr: clipboard contents]]
          .. '\00'
          .. [[ (['clipboard contents'])
	*: type V; value: something else]]
          .. '\00'
          .. [[ (['something else']), expr: something else]]
          .. '\00'
          .. [[ (['something else'])]]
      )
    end)
  end)

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
    command([[call ErrExe('call setreg()')]])
    command([[call ErrExe('call setreg(1)')]])
    command([[call ErrExe('call setreg(1, 2, 3, 4)')]])
    command([=[call ErrExe('call setreg([], 2)')]=])
    command([=[call ErrExe('call setreg(1, 2, [])')]=])
    command([=[call ErrExe('call setreg("/", ["1", "2"])')]=])
    command([=[call ErrExe('call setreg("=", ["1", "2"])')]=])
    command([=[call ErrExe('call setreg(1, ["", "", [], ""])')]=])
    expect([[

      Executing call setreg()
      Vim(call):E119: Not enough arguments for function: setreg
      Executing call setreg(1)
      Vim(call):E119: Not enough arguments for function: setreg
      Executing call setreg(1, 2, 3, 4)
      Vim(call):E118: Too many arguments for function: setreg
      Executing call setreg([], 2)
      Vim(call):E730: Using a List as a String
      Executing call setreg(1, 2, [])
      Vim(call):E730: Using a List as a String
      Executing call setreg("/", ["1", "2"])
      Vim(call):E883: Search pattern and expression register may not contain two or more lines
      Executing call setreg("=", ["1", "2"])
      Vim(call):E883: Search pattern and expression register may not contain two or more lines
      Executing call setreg(1, ["", "", [], ""])
      Vim(call):E730: Using a List as a String]])
  end)

  it('function name not starting with a capital', function()
    eq(
      'Vim(function):E128: Function name must start with a capital or "s:": g:test()\\nendfunction',
      exc_exec(dedent([[
        function! g:test()
        endfunction]]))
    )
  end)

  it('Function name followed by #', function()
    eq(
      'Vim(function):E128: Function name must start with a capital or "s:": test2() "#\\nendfunction',
      exc_exec(dedent([[
        function! test2() "#
        endfunction]]))
    )
  end)

  it('function name includes a colon', function()
    eq(
      'Vim(function):E884: Function name cannot contain a colon: b:test()\\nendfunction',
      exc_exec(dedent([[
        function! b:test()
        endfunction]]))
    )
  end)

  it('function name starting with/without "g:", buffer-local funcref', function()
    command([[
      function! g:Foo(n)
        $put ='called Foo(' . a:n . ')'
      endfunction
    ]])
    command("let b:my_func = function('Foo')")
    command('call b:my_func(1)')
    command('echo g:Foo(2)')
    command('echo Foo(3)')
    expect([[

      called Foo(1)
      called Foo(2)
      called Foo(3)]])
  end)

  it('script-local function used in Funcref must exist', function()
    source([[
      " Vim script used in test_eval.in.  Needed for script-local function.

      func s:Testje()
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
    eq(
      'Vim(call):E116: Invalid arguments for function append',
      exc_exec('call append($, "foobar")')
    )
  end)

  it('getcurpos/setpos', function()
    insert([[
      012345678
      012345678

      start:]])
    command('/^012345678')
    feed('6l')
    poke_eventloop()
    command('let sp = getcurpos()')
    feed('0')
    poke_eventloop()
    command("call setpos('.', sp)")
    feed('jyl')
    poke_eventloop()
    command('$put')
    expect([[
      012345678
      012345678

      start:
      6]])
  end)

  it('substring and variable name', function()
    command("let str = 'abcdef'")
    command('let n = 3')
    eq('def', eval('str[n:]'))
    eq('abcd', eval('str[:n]'))
    eq('d', eval('str[n:n]'))
    command('unlet n')
    command('let nn = 3')
    eq('def', eval('str[nn:]'))
    eq('abcd', eval('str[:nn]'))
    eq('d', eval('str[nn:nn]'))
    command('unlet nn')
    command('let b:nn = 4')
    eq('ef', eval('str[b:nn:]'))
    eq('abcde', eval('str[:b:nn]'))
    eq('e', eval('str[b:nn:b:nn]'))
  end)
end)
