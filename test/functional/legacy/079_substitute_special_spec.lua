-- Test for *sub-replace-special* and *sub-replace-expression* on :substitute.
-- Test for submatch() on :substitue.
-- Test for *:s%* on :substitute.
-- Test for :s replacing \n with  line break.

local helpers = require('test.functional.helpers')(before_each)
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local eq, eval, write_file = helpers.eq, helpers.eval, helpers.write_file

describe(':substitue', function()
  setup(function()
    write_file('test_79_7.in', 'A\rA\nB\x00B\nC\x00C\nD\x00\nD\nE\x00\n\x00'..
      '\n\x00\n\x00\n\x00E\nQ\nQ\n')
  end)
  before_each(clear)
  teardown(function()
    os.remove('test_79_7.in')
  end)

  it('with "set magic" (TEST_1)', function()
    insert([[
      A
      B
      C123456789
      D
      E
      F
      G
      H
      I
      J
      K
      lLl
      mMm
      nNn
      oOo
      pPp
      qQq
      rRr
      sSs
      tTt
      U
      V
      ]])
    execute('set magic')
    execute('1s/A/&&/')
    execute([[2s/B/\&/]])
    execute([[3s/C\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\0\9\8\7\6\5\4\3\2\1/]])
    execute('4s/D/d/')
    execute('5s/E/~/')
    execute([[6s/F/\~/]])
    execute([[7s/G/\ugg/]])
    execute([[8s/H/\Uh\Eh/]])
    execute([[9s/I/\lII/]])
    execute([[10s/J/\LJ\EJ/]])
    execute([[11s/K/\Uk\ek/]])
    execute('12s/L/\x16\r/')
    -- The previous substitution added a new line so we continue on line 14.
    execute([[14s/M/\r/]])
    -- The previous substitution added a new line so we continue on line 16.
    execute('16s/N/\\\x16\r/')
    execute([[17s/O/\n/]])
    execute([[18s/P/\b/]])
    execute([[19s/Q/\t/]])
    execute([[20s/R/\\/]])
    execute([[21s/S/\c/]])
    -- The null byte is troublesome in execute() calls.
    feed(':22s/T/<C-V><C-@>/<cr>')
    execute([[23s/U/\L\uuUu\l\EU/]])
    execute([[24s/V/\U\lVvV\u\Ev/]])
    expect([[
      AA
      &
      C123456789987654321
      d
      d
      ~
      Gg
      Hh
      iI
      jJ
      Kk
      l
      l
      m
      m
      n]]..'\r'..[[n
      o]]..'\x00'..[[o
      p]]..'\x08'..[[p
      q	q
      r\r
      scs
      t]]..'\x00'..[[t
      UuuU
      vVVv
      ]])
  end)

  it('with "set nomagic" (TEST_2)', function()
    insert([[
      A
      B
      C123456789
      D
      E
      F
      G
      H
      I
      J
      K
      lLl
      mMm
      nNn
      oOo
      pPp
      qQq
      rRr
      sSs
      tTt
      U
      V
      ]])

    execute('set nomagic')
    execute('1s/A/&&/')
    execute([[2s/B/\&/]])
    execute([[3s/\mC\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\0\9\8\7\6\5\4\3\2\1/]])
    execute('4s/D/d/')
    execute('5s/E/~/')
    execute([[6s/F/\~/]])
    execute([[7s/G/\ugg/]])
    execute([[8s/H/\Uh\Eh/]])
    execute([[9s/I/\lII/]])
    execute([[10s/J/\LJ\EJ/]])
    execute([[11s/K/\Uk\ek/]])
    execute('12s/L/\x16\r/')
    -- The previous substitution added a new line so we continue on line 14.
    execute([[14s/M/\r/]])
    -- The previous substitution added a new line so we continue on line 16.
    execute('16s/N/\\\x16\r/')
    execute([[17s/O/\n/]])
    execute([[18s/P/\b/]])
    execute([[19s/Q/\t/]])
    execute([[20s/R/\\/]])
    execute([[21s/S/\c/]])
    -- The null byte is troublesome in execute() calls.
    feed(':22s/T/<C-V><C-@>/<cr>')
    execute([[23s/U/\L\uuUu\l\EU/]])
    execute([[24s/V/\U\lVvV\u\Ev/]])
    expect([[
      &&
      B
      C123456789987654321
      d
      ~
      ~
      Gg
      Hh
      iI
      jJ
      Kk
      l
      l
      m
      m
      n]]..'\r'..[[n
      o]]..'\x00'..[[o
      p]]..'\x08'..[[p
      q	q
      r\r
      scs
      t]]..'\x00'..[[t
      UuuU
      vVVv
      ]])
  end)

  it('with sub-replace-expression (TEST_3)', function()
    insert([[
      aAa
      bBb
      cCc
      dDd
      eEe
      fFf
      gGg
      hHh
      iIi
      jJj
      kKk
      lLl
      ]])

    -- Some of these substitutions add a new line to the file so we have to
    -- increase the line number for the next command.
    execute('set magic&')
    execute([[1s/A/\='\'/]])
    execute([[2s/B/\='\\'/]])
    execute([[3s/C/\=']]..'\x16\r'..[['/]])
    execute([[5s/D/\='\]]..'\x16\r'..[['/]])
    execute([[7s/E/\='\\]]..'\x16\r'..[['/]])
    execute([[9s/F/\='\r'/]])
    -- The null byte is troublesome in execute() calls.
    feed([[:10s/G/\='<C-V><C-@>'/<cr>]])
    feed([[:12s/H/\='\<C-V><C-@>'/<cr>]])
    feed([[:14s/I/\='\\<C-V><C-@>'/<cr>]])
    execute([[16s/J/\='\n'/]])
    execute([[17s/K/\="\r"/]])
    execute([[19s/L/\="\n"/]])
    expect([[
      a\a
      b\\b
      c
      c
      d\
      d
      e\\
      e
      f\rf
      g
      g
      h\
      h
      i\\
      i
      j\nj
      k
      k
      l
      l
      ]])
  end)

  it('with sub-replace-expression and submatch() (TEST_4)', function()
    insert([[
      aAa
      bBb
      cCc
      dDd
      eEe
      fFf
      gGg
      hHh
      iIi
      jJj
      kKk
      lLl
      ]])

    -- Some of these substitutions add a new line to the file so we have to
    -- increase the line number for the next command.
    execute('set magic&')
    execute([[1s/A/\=substitute(submatch(0), '.', '\', '')/]])
    execute([[2s/B/\=substitute(submatch(0), '.', '\\', '')/]])
    execute([[3s/C/\=substitute(submatch(0), '.', ']]..'\x16\r'..[[', '')/]])
    execute([[5s/D/\=substitute(submatch(0), '.', '\]]..'\x16\r'..[[', '')/]])
    execute([[7s/E/\=substitute(submatch(0), '.', '\\]]..'\x16\r'..[[', '')/]])
    execute([[9s/F/\=substitute(submatch(0), '.', '\r', '')/]])
    -- The null byte is troublesome in execute() calls.
    feed([[:11s/G/\=substitute(submatch(0), '.', '<C-V><C-@>', '')/<cr>]])
    feed([[:13s/H/\=substitute(submatch(0), '.', '\<C-V><C-@>', '')/<cr>]])
    feed([[:15s/I/\=substitute(submatch(0), '.', '\\<C-V><C-@>', '')/<cr>]])
    execute([[17s/J/\=substitute(submatch(0), '.', '\n', '')/]])
    execute([[19s/K/\=substitute(submatch(0), '.', "\r", '')/]])
    execute([[21s/L/\=substitute(submatch(0), '.', "\n", '')/]])
    expect([[
      a\a
      b\b
      c
      c
      d
      d
      e\
      e
      f
      f
      g
      g
      h
      h
      i\
      i
      j
      j
      k
      k
      l
      l
      ]])
  end)

  it('with sub-replace-expression and submatch() (TEST_5)', function()
    insert([[
      A123456789
      B123456789
      ]])

    source([[
      set magic&
      1s/A\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\=submatch(0) . submatch(9) . submatch(8) . submatch(7) . submatch(6) . submatch(5) . submatch(4) . submatch(3) . submatch(2) . submatch(1)/
      2s/B\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\=string([submatch(0, 1), submatch(9, 1), submatch(8, 1), submatch(7, 1), submatch(6, 1), submatch(5, 1), submatch(4, 1), submatch(3, 1), submatch(2, 1), submatch(1, 1)])/
    ]])
    expect([=[
      A123456789987654321
      [['B123456789'], ['9'], ['8'], ['7'], ['6'], ['5'], ['4'], ['3'], ['2'], ['1']]
      ]=])
  end)

  -- TEST_6 was about the 'cpoptions' flag / which was removed in pull request
  -- #2943.

  it('with submatch() and strtrans() (TEST_7)', function()
    source([[
      e test_79_7.in
      set magic&
      1s/A./\=submatch(0)/
      3s/B./\=submatch(0)/
      5s/C./\=strtrans(string(submatch(0, 1)))/
      6s/D.\nD/\=strtrans(string(submatch(0, 1)))/
      7s/E\_.\{-}E/\=strtrans(string(submatch(0, 1)))/
    ]])
    execute('/^Q$')
    execute([[s/Q[^\n]Q/\=submatch(0)."foobar"/]])
    expect([[
      A
      A
      B
      B
      ['C^@']C
      ['D^@', 'D']
      ['E^@', '^@', '^@', '^@', '^@E']
      Q
      Q]])
  end)

  -- TODO is this test needed?
  it("errors don't break dotest on Windows", function()
    insert([[
      test_one
      test_two
      ]])

    source([[
      function! TitleString()
        let check = 'foo' =~ 'bar'
        return ""
      endfunction
      set titlestring=%{TitleString()}
      /^test_one/s/.*/\="foo\nbar"/
    ]])
    execute([[:/^test_two/s/.*/\="foo\nbar"/c]])
    feed('y')
    expect([[
      foo
      bar
      foo
      bar
      ]])
  end)
end)
