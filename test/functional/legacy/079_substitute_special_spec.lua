-- Test for *sub-replace-special* and *sub-replace-expression* on :substitute.
-- Test for submatch() on :substitue.
-- Test for *:s%* on :substitute.
-- Test for :s replacing \n with  line break.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local eq, eval, write_file = helpers.eq, helpers.eval, helpers.write_file

local function expect_line(line)
  return eq(line, eval('getline(".")'))
end

describe(':substitue', function()
  setup(function()
    write_file('test_79_7.in', 'TEST_7:\nA\rA\nB\x00B\nC\x00C\nD\x00\nD\nE'..
      '\x00\n\x00\n\x00\n\x00\n\x00E\nQ\nQ\n')
  end)
  before_each(clear)
  teardown(function()
    os.remove('test_79_7.in')
  end)

  it('with "set magic"', function()
    insert([[
      TEST_1:
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
    execute('2s/A/&&/')
    execute([[3s/B/\&/]])
    execute([[4s/C\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\0\9\8\7\6\5\4\3\2\1/]])
    execute('5s/D/d/')
    execute('6s/E/~/')
    execute([[7s/F/\~/]])
    execute([[8s/G/\ugg/]])
    execute([[9s/H/\Uh\Eh/]])
    execute([[10s/I/\lII/]])
    execute([[11s/J/\LJ\EJ/]])
    execute([[12s/K/\Uk\ek/]])
    execute('13s/L/\x16\r/')
    -- The previous substitution added a new line so we continue on line 15.
    execute([[15s/M/\r/]])
    -- The previous substitution added a new line so we continue on line 17.
    execute('17s/N/\\\x16\r/')
    execute([[18s/O/\n/]])
    execute([[19s/P/\b/]])
    execute([[20s/Q/\t/]])
    execute([[21s/R/\\/]])
    execute([[22s/S/\c/]])
    -- The null byte is troublesome in execute() calls.
    feed(':23s/T/<C-V><C-@>/<cr>')
    execute([[24s/U/\L\uuUu\l\EU/]])
    execute([[25s/V/\U\lVvV\u\Ev/]])
    expect([[
      TEST_1:
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

  it('with "set nomagic"', function()
    insert([[
      TEST_2:
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
    execute('2s/A/&&/')
    execute([[3s/B/\&/]])
    execute([[4s/\mC\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\0\9\8\7\6\5\4\3\2\1/]])
    execute('5s/D/d/')
    execute('6s/E/~/')
    execute([[7s/F/\~/]])
    execute([[8s/G/\ugg/]])
    execute([[9s/H/\Uh\Eh/]])
    execute([[10s/I/\lII/]])
    execute([[11s/J/\LJ\EJ/]])
    execute([[12s/K/\Uk\ek/]])
    execute('13s/L/\x16\r/')
    -- The previous substitution added a new line so we continue on line 15.
    execute([[15s/M/\r/]])
    -- The previous substitution added a new line so we continue on line 17.
    execute('17s/N/\\\x16\r/')
    execute([[18s/O/\n/]])
    execute([[19s/P/\b/]])
    execute([[20s/Q/\t/]])
    execute([[21s/R/\\/]])
    execute([[22s/S/\c/]])
    -- The null byte is troublesome in execute() calls.
    feed(':23s/T/<C-V><C-@>/<cr>')
    execute([[24s/U/\L\uuUu\l\EU/]])
    execute([[25s/V/\U\lVvV\u\Ev/]])
    expect([[
      TEST_2:
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

  it('with sub-replace-expression', function()
    insert([[
      TEST_3:
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
    execute([[2s/A/\='\'/]])
    execute([[3s/B/\='\\'/]])
    execute([[4s/C/\=']]..'\x16\r'..[['/]])
    execute([[6s/D/\='\]]..'\x16\r'..[['/]])
    execute([[8s/E/\='\\]]..'\x16\r'..[['/]])
    execute([[10s/F/\='\r'/]])
    -- The null byte is troublesome in execute() calls.
    feed([[:11s/G/\='<C-V><C-@>'/<cr>]])
    feed([[:13s/H/\='\<C-V><C-@>'/<cr>]])
    feed([[:15s/I/\='\\<C-V><C-@>'/<cr>]])
    execute([[17s/J/\='\n'/]])
    execute([[18s/K/\="\r"/]])
    execute([[20s/L/\="\n"/]])
    expect([[
      TEST_3:
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

  it('with sub-replace-expression and submatch()', function()
    insert([[
      TEST_4:
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
    execute([[2s/A/\=substitute(submatch(0), '.', '\', '')/]])
    execute([[3s/B/\=substitute(submatch(0), '.', '\\', '')/]])
    execute([[4s/C/\=substitute(submatch(0), '.', ']]..'\x16\r'..[[', '')/]])
    execute([[6s/D/\=substitute(submatch(0), '.', '\]]..'\x16\r'..[[', '')/]])
    execute([[8s/E/\=substitute(submatch(0), '.', '\\]]..'\x16\r'..[[', '')/]])
    execute([[10s/F/\=substitute(submatch(0), '.', '\r', '')/]])
    -- The null byte is troublesome in execute() calls.
    feed([[:12s/G/\=substitute(submatch(0), '.', '<C-V><C-@>', '')/<cr>]])
    feed([[:14s/H/\=substitute(submatch(0), '.', '\<C-V><C-@>', '')/<cr>]])
    feed([[:16s/I/\=substitute(submatch(0), '.', '\\<C-V><C-@>', '')/<cr>]])
    execute([[18s/J/\=substitute(submatch(0), '.', '\n', '')/]])
    execute([[20s/K/\=substitute(submatch(0), '.', "\r", '')/]])
    execute([[22s/L/\=substitute(submatch(0), '.', "\n", '')/]])
    expect([[
      TEST_4:
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

  it('with sub-replace-expression and submatch() (part 2)', function()
    insert([[
      TEST_5:
      A123456789
      B123456789
      ]])

    source([[
      set magic&
      2s/A\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\=submatch(0) . submatch(9) . submatch(8) . submatch(7) . submatch(6) . submatch(5) . submatch(4) . submatch(3) . submatch(2) . submatch(1)/
      3s/B\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)/\=string([submatch(0, 1), submatch(9, 1), submatch(8, 1), submatch(7, 1), submatch(6, 1), submatch(5, 1), submatch(4, 1), submatch(3, 1), submatch(2, 1), submatch(1, 1)])/
    ]])
    expect([=[
      TEST_5:
      A123456789987654321
      [['B123456789'], ['9'], ['8'], ['7'], ['6'], ['5'], ['4'], ['3'], ['2'], ['1']]
      ]=])
  end)

  -- TEST_6 was about the 'cpoptions' flag / which was removed in pull request
  -- #2943.

  it('with submatch() and strtrans()', function()
    source([[
      e test_79_7.in
      set magic&
      2s/A./\=submatch(0)/
      4s/B./\=submatch(0)/
      6s/C./\=strtrans(string(submatch(0, 1)))/
      7s/D.\nD/\=strtrans(string(submatch(0, 1)))/
      8s/E\_.\{-}E/\=strtrans(string(submatch(0, 1)))/
    ]])
    execute('/^Q$')
    execute([[s/Q[^\n]Q/\=submatch(0)."foobar"/]])
    expect([[
      TEST_7:
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
