" Test try-catch-finally exception handling
" Most of this was formerly in test49.

source check.vim
source shared.vim
source vim9.vim

"-------------------------------------------------------------------------------
" Test environment							    {{{1
"-------------------------------------------------------------------------------

com!		   XpathINIT  let g:Xpath = ''
com! -nargs=1 -bar Xpath      let g:Xpath = g:Xpath . <args>

" Test 25:  Executing :finally clauses on normal control flow		    {{{1
"
"	    Control flow in a :try conditional should always fall through to its
"	    :finally clause.  A :finally clause of a :try conditional inside an
"	    inactive conditional should never be executed.
"-------------------------------------------------------------------------------

func T25_F()
  let loops = 3
  while loops > 0
    Xpath 'a' . loops
    if loops >= 2
      try
        Xpath 'b' . loops
        if loops == 2
          try
            Xpath 'c' . loops
          finally
            Xpath 'd' . loops
          endtry
        endif
      finally
        Xpath 'e' . loops
        if loops == 2
          try
            Xpath 'f' . loops
          final
            Xpath 'g' . loops
          endtry
        endif
      endtry
    endif
    Xpath 'h' . loops
    let loops = loops - 1
  endwhile
  Xpath 'i'
endfunc

" Also try using "fina" and "final" and "finall" as abbreviations.
func T25_G()
  if 1
    try
      Xpath 'A'
      call T25_F()
      Xpath 'B'
    fina
      Xpath 'C'
    endtry
  else
    try
      Xpath 'D'
    finall
      Xpath 'E'
    endtry
  endif
endfunc

func Test_finally()
  XpathINIT
  call T25_G()
  call assert_equal('Aa3b3e3h3a2b2c2d2e2f2g2h2a1h1iBC', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 26:  Executing :finally clauses after :continue or :break	    {{{1
"
"	    For a :continue or :break dynamically enclosed in a :try/:endtry
"	    region inside the next surrounding :while/:endwhile, if the
"	    :continue/:break is before the :finally, the :finally clause is
"	    executed first.  If the :continue/:break is after the :finally, the
"	    :finally clause is broken (like an :if/:endif region).
"-------------------------------------------------------------------------------

func T26_F()
  try
    let loops = 3
    while loops > 0
      try
        try
          if loops == 2
            Xpath 'a' . loops
            let loops = loops - 1
            continue
          elseif loops == 1
            Xpath 'b' . loops
            break
            finish
          endif
          Xpath 'c' . loops
        endtry
      finally
        Xpath 'd' . loops
      endtry
      Xpath 'e' . loops
      let loops = loops - 1
    endwhile
    Xpath 'f'
  finally
    Xpath 'g'
    let loops = 3
    while loops > 0
      try
      finally
        try
          if loops == 2
            Xpath 'h' . loops
            let loops = loops - 1
            continue
          elseif loops == 1
            Xpath 'i' . loops
            break
            finish
          endif
        endtry
        Xpath 'j' . loops
      endtry
      Xpath 'k' . loops
      let loops = loops - 1
    endwhile
    Xpath 'l'
  endtry
  Xpath 'm'
endfunc

func Test_finally_after_continue()
  XpathINIT
  call T26_F()
  call assert_equal('c3d3e3a2d1b1d1fgj3k3h2i1lm', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 32:  Remembering the :return value on :finally			    {{{1
"
"	    If a :finally clause is executed due to a :return specifying
"	    a value, this is the value visible to the caller if not overwritten
"	    by a new :return in the :finally clause.  A :return without a value
"	    in the :finally clause overwrites with value 0.
"-------------------------------------------------------------------------------

func T32_F()
  try
    Xpath 'a'
    try
      Xpath 'b'
      return "ABCD"
      Xpath 'c'
    finally
      Xpath 'd'
    endtry
    Xpath 'e'
  finally
    Xpath 'f'
  endtry
  Xpath 'g'
endfunc

func T32_G()
  try
    Xpath 'h'
    return 8
    Xpath 'i'
  finally
    Xpath 'j'
    return 16 + strlen(T32_F())
    Xpath 'k'
  endtry
  Xpath 'l'
endfunc

func T32_H()
  try
    Xpath 'm'
    return 32
    Xpath 'n'
  finally
    Xpath 'o'
    return
    Xpath 'p'
  endtry
  Xpath 'q'
endfunc

func T32_I()
  try
    Xpath 'r'
  finally
    Xpath 's'
    return T32_G() + T32_H() + 64
    Xpath 't'
  endtry
  Xpath 'u'
endfunc

func Test_finally_return()
  XpathINIT
  call assert_equal(84, T32_I())
  call assert_equal('rshjabdfmo', g:Xpath)
endfunc

"-------------------------------------------------------------------------------
" Test 33:  :return under :execute or user command and :finally		    {{{1
"
"	    A :return command may be executed under an ":execute" or from
"	    a user command.  Executing of :finally clauses and passing through
"	    the return code works also then.
"-------------------------------------------------------------------------------

func T33_F()
  try
    RETURN 10
    Xpath 'a'
  finally
    Xpath 'b'
  endtry
  Xpath 'c'
endfunc

func T33_G()
  try
    RETURN 20
    Xpath 'd'
  finally
    Xpath 'e'
    RETURN 30
    Xpath 'f'
  endtry
  Xpath 'g'
endfunc

func T33_H()
  try
    execute "try | return 40 | finally | return 50 | endtry"
    Xpath 'h'
  finally
    Xpath 'i'
  endtry
  Xpath 'j'
endfunc

func T33_I()
  try
    execute "try | return 60 | finally | return 70 | endtry"
    Xpath 'k'
  finally
    Xpath 'l'
    execute "try | return 80 | finally | return 90 | endtry"
    Xpath 'm'
  endtry
  Xpath 'n'
endfunc

func T33_J()
  try
    RETURN 100
    Xpath 'o'
  finally
    Xpath 'p'
    return
    Xpath 'q'
  endtry
  Xpath 'r'
endfunc

func T33_K()
  try
    execute "try | return 110 | finally | return 120 | endtry"
    Xpath 's'
  finally
    Xpath 't'
    execute "try | return 130 | finally | return | endtry"
    Xpath 'u'
  endtry
  Xpath 'v'
endfunc

func T33_L()
  try
    return
    Xpath 'w'
  finally
    Xpath 'x'
    RETURN 140
    Xpath 'y'
  endtry
  Xpath 'z'
endfunc

func T33_M()
  try
    return
    Xpath 'A'
  finally
    Xpath 'B'
    execute "try | return 150 | finally | return 160 | endtry"
    Xpath 'C'
  endtry
  Xpath 'D'
endfunc

func T33_N()
  RETURN 170
endfunc

func T33_O()
  execute "try | return 180 | finally | return 190 | endtry"
endfunc

func Test_finally_cmd_return()
  command! -nargs=? RETURN
        \ try | return <args> | finally | return <args> * 2 | endtry
  XpathINIT
  call assert_equal(20, T33_F())
  call assert_equal(60, T33_G())
  call assert_equal(50, T33_H())
  call assert_equal(90, T33_I())
  call assert_equal(0, T33_J())
  call assert_equal(0, T33_K())
  call assert_equal(280, T33_L())
  call assert_equal(160, T33_M())
  call assert_equal(340, T33_N())
  call assert_equal(190, T33_O())
  call assert_equal('beilptxB', g:Xpath)
  delcommand RETURN
endfunc


"-------------------------------------------------------------------------------
" Test 41:  Skipped :throw finding next command				    {{{1
"
"	    A :throw in an inactive conditional must not hide a following
"	    command.
"-------------------------------------------------------------------------------

func T41_F()
  Xpath 'a'
  if 0 | throw 'never' | endif | Xpath 'b'
  Xpath 'c'
endfunc

func T41_G()
  Xpath 'd'
  while 0 | throw 'never' | endwhile | Xpath 'e'
  Xpath 'f'
endfunc

func T41_H()
  Xpath 'g'
  if 0 | try | throw 'never' | endtry | endif | Xpath 'h'
  Xpath 'i'
endfunc

func Test_throw_inactive_cond()
  XpathINIT
  try
    Xpath 'j'
    call T41_F()
    Xpath 'k'
  catch /.*/
    Xpath 'l'
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry

  try
    Xpath 'm'
    call T41_G()
    Xpath 'n'
  catch /.*/
    Xpath 'o'
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry

  try
    Xpath 'p'
    call T41_H()
    Xpath 'q'
  catch /.*/
    Xpath 'r'
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry

  call assert_equal('jabckmdefnpghiq', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 42:  Catching number and string exceptions			    {{{1
"
"	    When a number is thrown, it is converted to a string exception.
"	    Numbers and strings may be caught by specifying a regular exception
"	    as argument to the :catch command.
"-------------------------------------------------------------------------------


func T42_F()
  try

    try
      Xpath 'a'
      throw 4711
      Xpath 'b'
    catch /4711/
      Xpath 'c'
    endtry

    try
      Xpath 'd'
      throw 4711
      Xpath 'e'
    catch /^4711$/
      Xpath 'f'
    endtry

    try
      Xpath 'g'
      throw 4711
      Xpath 'h'
    catch /\d/
      Xpath 'i'
    endtry

    try
      Xpath 'j'
      throw 4711
      Xpath 'k'
    catch /^\d\+$/
      Xpath 'l'
    endtry

    try
      Xpath 'm'
      throw "arrgh"
      Xpath 'n'
    catch /arrgh/
      Xpath 'o'
    endtry

    try
      Xpath 'p'
      throw "arrgh"
      Xpath 'q'
    catch /^arrgh$/
      Xpath 'r'
    endtry

    try
      Xpath 's'
      throw "arrgh"
      Xpath 't'
    catch /\l/
      Xpath 'u'
    endtry

    try
      Xpath 'v'
      throw "arrgh"
      Xpath 'w'
    catch /^\l\+$/
      Xpath 'x'
    endtry

    try
      try
        Xpath 'y'
        throw "ARRGH"
        Xpath 'z'
      catch /^arrgh$/
        Xpath 'A'
      endtry
    catch /^\carrgh$/
      Xpath 'B'
    endtry

    try
      Xpath 'C'
      throw ""
      Xpath 'D'
    catch /^$/
      Xpath 'E'
    endtry

  catch /.*/
    Xpath 'F'
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry
endfunc

func Test_catch_number_string()
  XpathINIT
  call T42_F()
  call assert_equal('acdfgijlmoprsuvxyBCE', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 43:  Selecting the correct :catch clause				    {{{1
"
"	    When an exception is thrown and there are multiple :catch clauses,
"	    the first matching one is taken.
"-------------------------------------------------------------------------------

func T43_F()
  let loops = 3
  while loops > 0
    try
      if loops == 3
        Xpath 'a' . loops
        throw "a"
        Xpath 'b' . loops
      elseif loops == 2
        Xpath 'c' . loops
        throw "ab"
        Xpath 'd' . loops
      elseif loops == 1
        Xpath 'e' . loops
        throw "abc"
        Xpath 'f' . loops
      endif
    catch /abc/
      Xpath 'g' . loops
    catch /ab/
      Xpath 'h' . loops
    catch /.*/
      Xpath 'i' . loops
    catch /a/
      Xpath 'j' . loops
    endtry

    let loops = loops - 1
  endwhile
  Xpath 'k'
endfunc

func Test_multi_catch()
  XpathINIT
  call T43_F()
  call assert_equal('a3i3c2h2e1g1k', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 44:  Missing or empty :catch patterns				    {{{1
"
"	    A missing or empty :catch pattern means the same as /.*/, that is,
"	    catches everything.  To catch only empty exceptions, /^$/ must be
"	    used.  A :catch with missing, empty, or /.*/ argument also works
"	    when followed by another command separated by a bar on the same
"	    line.  :catch patterns cannot be specified between ||.  But other
"	    pattern separators can be used instead of //.
"-------------------------------------------------------------------------------

func T44_F()
  try
    try
      Xpath 'a'
      throw ""
    catch /^$/
      Xpath 'b'
    endtry

    try
      Xpath 'c'
      throw ""
    catch /.*/
      Xpath 'd'
    endtry

    try
      Xpath 'e'
      throw ""
    catch //
      Xpath 'f'
    endtry

    try
      Xpath 'g'
      throw ""
    catch
      Xpath 'h'
    endtry

    try
      Xpath 'i'
      throw "oops"
    catch /^$/
      Xpath 'j'
    catch /.*/
      Xpath 'k'
    endtry

    try
      Xpath 'l'
      throw "arrgh"
    catch /^$/
      Xpath 'm'
    catch //
      Xpath 'n'
    endtry

    try
      Xpath 'o'
      throw "brrr"
    catch /^$/
      Xpath 'p'
    catch
      Xpath 'q'
    endtry

    try | Xpath 'r' | throw "x" | catch /.*/ | Xpath 's' | endtry

    try | Xpath 't' | throw "y" | catch // | Xpath 'u' | endtry

    while 1
      try
        let caught = 0
        let v:errmsg = ""
        " Extra try level:  if ":catch" without arguments below raises
        " a syntax error because it misinterprets the "Xpath" as a pattern,
        " let it be caught by the ":catch /.*/" below.
        try
          try | Xpath 'v' | throw "z" | catch | Xpath 'w' | :
          endtry
        endtry
      catch /.*/
        let caught = 1
        call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
      finally
        if $VIMNOERRTHROW && v:errmsg != ""
          call assert_report(v:errmsg)
        endif
        if caught || $VIMNOERRTHROW && v:errmsg != ""
          Xpath 'x'
        endif
        break		" discard error for $VIMNOERRTHROW
      endtry
    endwhile

    let cologne = 4711
    try
      try
        Xpath 'y'
        throw "throw cologne"
        " Next lines catches all and throws 4711:
      catch |throw cologne|
        Xpath 'z'
      endtry
    catch /4711/
      Xpath 'A'
    endtry

    try
      Xpath 'B'
      throw "plus"
    catch +plus+
      Xpath 'C'
    endtry

    Xpath 'D'
  catch /.*/
    Xpath 'E'
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry
endfunc

func Test_empty_catch()
  XpathINIT
  call T44_F()
  call assert_equal('abcdefghiklnoqrstuvwyABCD', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 45:  Catching exceptions from nested :try blocks			    {{{1
"
"	    When :try blocks are nested, an exception is caught by the innermost
"	    try conditional that has a matching :catch clause.
"-------------------------------------------------------------------------------

func T45_F()
  let loops = 3
  while loops > 0
    try
      try
        try
          try
            if loops == 3
              Xpath 'a' . loops
              throw "a"
              Xpath 'b' . loops
            elseif loops == 2
              Xpath 'c' . loops
              throw "ab"
              Xpath 'd' . loops
            elseif loops == 1
              Xpath 'e' . loops
              throw "abc"
              Xpath 'f' . loops
            endif
          catch /abc/
            Xpath 'g' . loops
          endtry
        catch /ab/
          Xpath 'h' . loops
        endtry
      catch /.*/
        Xpath 'i' . loops
      endtry
    catch /a/
      Xpath 'j' . loops
    endtry

    let loops = loops - 1
  endwhile
  Xpath 'k'
endfunc

func Test_catch_from_nested_try()
  XpathINIT
  call T45_F()
  call assert_equal('a3i3c2h2e1g1k', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 46:  Executing :finally after a :throw in nested :try		    {{{1
"
"	    When an exception is thrown from within nested :try blocks, the
"	    :finally clauses of the non-catching try conditionals should be
"	    executed before the matching :catch of the next surrounding :try
"	    gets the control.  If this also has a :finally clause, it is
"	    executed afterwards.
"-------------------------------------------------------------------------------

func T46_F()
  let sum = 0

  try
    Xpath 'a'
    try
      Xpath 'b'
      try
        Xpath 'c'
        try
          Xpath 'd'
          throw "ABC"
          Xpath 'e'
        catch /xyz/
          Xpath 'f'
        finally
          Xpath 'g'
          if sum != 0
            Xpath 'h'
          endif
          let sum = sum + 1
        endtry
        Xpath 'i'
      catch /123/
        Xpath 'j'
      catch /321/
        Xpath 'k'
      finally
        Xpath 'l'
        if sum != 1
          Xpath 'm'
        endif
        let sum = sum + 2
      endtry
      Xpath 'n'
    finally
      Xpath 'o'
      if sum != 3
        Xpath 'p'
      endif
      let sum = sum + 4
    endtry
    Xpath 'q'
  catch /ABC/
    Xpath 'r'
    if sum != 7
      Xpath 's'
    endif
    let sum = sum + 8
  finally
    Xpath 't'
    if sum != 15
      Xpath 'u'
    endif
    let sum = sum + 16
  endtry
  Xpath 'v'
  if sum != 31
    Xpath 'w'
  endif
endfunc

func Test_finally_after_throw()
  XpathINIT
  call T46_F()
  call assert_equal('abcdglortv', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 47:  Throwing exceptions from a :catch clause			    {{{1
"
"	    When an exception is thrown from a :catch clause, it should not be
"	    caught by a :catch of the same :try conditional.  After executing
"	    the :finally clause (if present), surrounding try conditionals
"	    should be checked for a matching :catch.
"-------------------------------------------------------------------------------

func T47_F()
  Xpath 'a'
  try
    Xpath 'b'
    try
      Xpath 'c'
      try
        Xpath 'd'
        throw "x1"
        Xpath 'e'
      catch /x1/
        Xpath 'f'
        try
          Xpath 'g'
          throw "x2"
          Xpath 'h'
        catch /x1/
          Xpath 'i'
        catch /x2/
          Xpath 'j'
          try
            Xpath 'k'
            throw "x3"
            Xpath 'l'
          catch /x1/
            Xpath 'm'
          catch /x2/
            Xpath 'n'
          finally
            Xpath 'o'
          endtry
          Xpath 'p'
        catch /x3/
          Xpath 'q'
        endtry
        Xpath 'r'
      catch /x1/
        Xpath 's'
      catch /x2/
        Xpath 't'
      catch /x3/
        Xpath 'u'
      finally
        Xpath 'v'
      endtry
      Xpath 'w'
    catch /x1/
      Xpath 'x'
    catch /x2/
      Xpath 'y'
    catch /x3/
      Xpath 'z'
    endtry
    Xpath 'A'
  catch /.*/
    Xpath 'B'
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry
  Xpath 'C'
endfunc

func Test_throw_from_catch()
  XpathINIT
  call T47_F()
  call assert_equal('abcdfgjkovzAC', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 48:  Throwing exceptions from a :finally clause			    {{{1
"
"	    When an exception is thrown from a :finally clause, it should not be
"	    caught by a :catch of the same :try conditional.  Surrounding try
"	    conditionals should be checked for a matching :catch.  A previously
"	    thrown exception is discarded.
"-------------------------------------------------------------------------------

func T48_F()
  try

    try
      try
        Xpath 'a'
      catch /x1/
        Xpath 'b'
      finally
        Xpath 'c'
        throw "x1"
        Xpath 'd'
      endtry
      Xpath 'e'
    catch /x1/
      Xpath 'f'
    endtry
    Xpath 'g'

    try
      try
        Xpath 'h'
        throw "x2"
        Xpath 'i'
      catch /x2/
        Xpath 'j'
      catch /x3/
        Xpath 'k'
      finally
        Xpath 'l'
        throw "x3"
        Xpath 'm'
      endtry
      Xpath 'n'
    catch /x2/
      Xpath 'o'
    catch /x3/
      Xpath 'p'
    endtry
    Xpath 'q'

    try
      try
        try
          Xpath 'r'
          throw "x4"
          Xpath 's'
        catch /x5/
          Xpath 't'
        finally
          Xpath 'u'
          throw "x5"	" discards 'x4'
          Xpath 'v'
        endtry
        Xpath 'w'
      catch /x4/
        Xpath 'x'
      finally
        Xpath 'y'
      endtry
      Xpath 'z'
    catch /x5/
      Xpath 'A'
    endtry
    Xpath 'B'

  catch /.*/
    Xpath 'C'
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry
  Xpath 'D'
endfunc

func Test_throw_from_finally()
  XpathINIT
  call T48_F()
  call assert_equal('acfghjlpqruyABD', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 51:  Throwing exceptions across :execute and user commands	    {{{1
"
"	    A :throw command may be executed under an ":execute" or from
"	    a user command.
"-------------------------------------------------------------------------------

func T51_F()
  command! -nargs=? THROW1    throw <args> | throw 1
  command! -nargs=? THROW2    try | throw <args> | endtry | throw 2
  command! -nargs=? THROW3    try | throw 3 | catch /3/ | throw <args> | endtry
  command! -nargs=? THROW4    try | throw 4 | finally   | throw <args> | endtry

  try

    try
      try
        Xpath 'a'
        THROW1 "A"
      catch /A/
        Xpath 'b'
      endtry
    catch /1/
      Xpath 'c'
    endtry

    try
      try
        Xpath 'd'
        THROW2 "B"
      catch /B/
        Xpath 'e'
      endtry
    catch /2/
      Xpath 'f'
    endtry

    try
      try
        Xpath 'g'
        THROW3 "C"
      catch /C/
        Xpath 'h'
      endtry
    catch /3/
      Xpath 'i'
    endtry

    try
      try
        Xpath 'j'
        THROW4 "D"
      catch /D/
        Xpath 'k'
      endtry
    catch /4/
      Xpath 'l'
    endtry

    try
      try
        Xpath 'm'
        execute 'throw "E" | throw 5'
      catch /E/
        Xpath 'n'
      endtry
    catch /5/
      Xpath 'o'
    endtry

    try
      try
        Xpath 'p'
        execute 'try | throw "F" | endtry | throw 6'
      catch /F/
        Xpath 'q'
      endtry
    catch /6/
      Xpath 'r'
    endtry

    try
      try
        Xpath 's'
        execute'try | throw 7 | catch /7/ | throw "G" | endtry'
      catch /G/
        Xpath 't'
      endtry
    catch /7/
      Xpath 'u'
    endtry

    try
      try
        Xpath 'v'
        execute 'try | throw 8 | finally   | throw "H" | endtry'
      catch /H/
        Xpath 'w'
      endtry
    catch /8/
      Xpath 'x'
    endtry

  catch /.*/
    Xpath 'y'
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry

  Xpath 'z'

  delcommand THROW1
  delcommand THROW2
  delcommand THROW3
  delcommand THROW4
endfunc

func Test_throw_across_commands()
  XpathINIT
  call T51_F()
  call assert_equal('abdeghjkmnpqstvwz', g:Xpath)
endfunc



"-------------------------------------------------------------------------------
" Test 69:  :throw across :if, :elseif, :while				    {{{1
"
"	    On an :if, :elseif, or :while command, an exception might be thrown
"	    during evaluation of the expression to test.  The exception can be
"	    caught by the script.
"-------------------------------------------------------------------------------

func T69_throw(x)
  Xpath 'x'
  throw a:x
endfunc

func Test_throw_ifelsewhile()
  XpathINIT

  try
    try
      Xpath 'a'
      if 111 == T69_throw("if") + 111
        Xpath 'b'
      else
        Xpath 'c'
      endif
      Xpath 'd'
    catch /^if$/
      Xpath 'e'
    catch /.*/
      Xpath 'f'
      call assert_report("if: " . v:exception . " in " . v:throwpoint)
    endtry

    try
      Xpath 'g'
      if v:false
        Xpath 'h'
      elseif 222 == T69_throw("elseif") + 222
        Xpath 'i'
      else
        Xpath 'j'
      endif
      Xpath 'k'
    catch /^elseif$/
      Xpath 'l'
    catch /.*/
      Xpath 'm'
      call assert_report("elseif: " . v:exception . " in " . v:throwpoint)
    endtry

    try
      Xpath 'n'
      while 333 == T69_throw("while") + 333
        Xpath 'o'
        break
      endwhile
      Xpath 'p'
    catch /^while$/
      Xpath 'q'
    catch /.*/
      Xpath 'r'
      call assert_report("while: " .. v:exception .. " in " .. v:throwpoint)
    endtry
  catch /^0$/	    " default return value
    Xpath 's'
    call assert_report(v:throwpoint)
  catch /.*/
    call assert_report(v:exception .. " in " .. v:throwpoint)
    Xpath 't'
  endtry

  call assert_equal('axegxlnxq', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 70:  :throw across :return or :throw				    {{{1
"
"	    On a :return or :throw command, an exception might be thrown during
"	    evaluation of the expression to return or throw, respectively.  The
"	    exception can be caught by the script.
"-------------------------------------------------------------------------------

let T70_taken = ""

func T70_throw(x, n)
    let g:T70_taken = g:T70_taken . "T" . a:n
    throw a:x
endfunc

func T70_F(x, y, n)
    let g:T70_taken = g:T70_taken . "F" . a:n
    return a:x + T70_throw(a:y, a:n)
endfunc

func T70_G(x, y, n)
    let g:T70_taken = g:T70_taken . "G" . a:n
    throw a:x . T70_throw(a:y, a:n)
    return a:x
endfunc

func Test_throwreturn()
  XpathINIT

  try
    try
      Xpath 'a'
      call T70_F(4711, "return", 1)
      Xpath 'b'
    catch /^return$/
      Xpath 'c'
    catch /.*/
      Xpath 'd'
      call assert_report("return: " .. v:exception .. " in " .. v:throwpoint)
    endtry

    try
      Xpath 'e'
      let var = T70_F(4712, "return-var", 2)
      Xpath 'f'
    catch /^return-var$/
      Xpath 'g'
    catch /.*/
      Xpath 'h'
      call assert_report("return-var: " . v:exception . " in " . v:throwpoint)
    finally
      unlet! var
    endtry

    try
      Xpath 'i'
      throw "except1" . T70_throw("throw1", 3)
      Xpath 'j'
    catch /^except1/
      Xpath 'k'
    catch /^throw1$/
      Xpath 'l'
    catch /.*/
      Xpath 'm'
      call assert_report("throw1: " .. v:exception .. " in " .. v:throwpoint)
    endtry

    try
      Xpath 'n'
      call T70_G("except2", "throw2", 4)
      Xpath 'o'
    catch /^except2/
      Xpath 'p'
    catch /^throw2$/
      Xpath 'q'
    catch /.*/
      Xpath 'r'
      call assert_report("throw2: " .. v:exception .. " in " .. v:throwpoint)
    endtry

    try
      Xpath 's'
      let var = T70_G("except3", "throw3", 5)
      Xpath 't'
    catch /^except3/
      Xpath 'u'
    catch /^throw3$/
      Xpath 'v'
    catch /.*/
      Xpath 'w'
      call assert_report("throw3: " .. v:exception .. " in " .. v:throwpoint)
    finally
      unlet! var
    endtry

    call assert_equal('F1T1F2T2T3G4T4G5T5', g:T70_taken)
    Xpath 'x'
  catch /^0$/	    " default return value
    Xpath 'y'
    call assert_report(v:throwpoint)
  catch /.*/
    Xpath 'z'
    call assert_report('Caught' .. v:exception .. ' in ' .. v:throwpoint)
  endtry

  call assert_equal('acegilnqsvx', g:Xpath)
endfunc

"-------------------------------------------------------------------------------
" Test 71:  :throw across :echo variants and :execute			    {{{1
"
"	    On an :echo, :echon, :echomsg, :echoerr, or :execute command, an
"	    exception might be thrown during evaluation of the arguments to
"	    be displayed or executed as a command, respectively.  Any following
"	    arguments are not evaluated, then.  The exception can be caught by
"	    the script.
"-------------------------------------------------------------------------------

let T71_taken = ""

func T71_throw(x, n)
    let g:T71_taken = g:T71_taken . "T" . a:n
    throw a:x
endfunc

func T71_F(n)
    let g:T71_taken = g:T71_taken . "F" . a:n
    return "F" . a:n
endfunc

func Test_throw_echo()
  XpathINIT

  try
    try
      Xpath 'a'
      echo 'echo ' . T71_throw("echo-except", 1) . T71_F(1)
      Xpath 'b'
    catch /^echo-except$/
      Xpath 'c'
    catch /.*/
      Xpath 'd'
      call assert_report("echo: " .. v:exception .. " in " .. v:throwpoint)
    endtry

    try
      Xpath 'e'
      echon "echon " . T71_throw("echon-except", 2) . T71_F(2)
      Xpath 'f'
    catch /^echon-except$/
      Xpath 'g'
    catch /.*/
      Xpath 'h'
      call assert_report('echon: ' . v:exception . ' in ' . v:throwpoint)
    endtry

    try
      Xpath 'i'
      echomsg "echomsg " . T71_throw("echomsg-except", 3) . T71_F(3)
      Xpath 'j'
    catch /^echomsg-except$/
      Xpath 'k'
    catch /.*/
      Xpath 'l'
      call assert_report('echomsg: ' . v:exception . ' in ' . v:throwpoint)
    endtry

    try
      Xpath 'm'
      echoerr "echoerr " . T71_throw("echoerr-except", 4) . T71_F(4)
      Xpath 'n'
    catch /^echoerr-except$/
      Xpath 'o'
    catch /Vim/
      Xpath 'p'
    catch /echoerr/
      Xpath 'q'
    catch /.*/
      Xpath 'r'
      call assert_report('echoerr: ' . v:exception . ' in ' . v:throwpoint)
    endtry

    try
      Xpath 's'
      execute "echo 'execute " . T71_throw("execute-except", 5) . T71_F(5) "'"
      Xpath 't'
    catch /^execute-except$/
      Xpath 'u'
    catch /.*/
      Xpath 'v'
      call assert_report('execute: ' . v:exception . ' in ' . v:throwpoint)
    endtry

    call assert_equal('T1T2T3T4T5', g:T71_taken)
    Xpath 'w'
  catch /^0$/	    " default return value
    Xpath 'x'
    call assert_report(v:throwpoint)
  catch /.*/
    Xpath 'y'
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry

  call assert_equal('acegikmosuw', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 72:  :throw across :let or :unlet				    {{{1
"
"	    On a :let command, an exception might be thrown during evaluation
"	    of the expression to assign.  On an :let or :unlet command, the
"	    evaluation of the name of the variable to be assigned or list or
"	    deleted, respectively, may throw an exception.  Any following
"	    arguments are not evaluated, then.  The exception can be caught by
"	    the script.
"-------------------------------------------------------------------------------

let throwcount = 0

func T72_throw(x)
  let g:throwcount = g:throwcount + 1
  throw a:x
endfunc

let T72_addpath = ''

func T72_addpath(p)
  let g:T72_addpath = g:T72_addpath . a:p
endfunc

func Test_throw_let()
  XpathINIT

  try
    try
      let $VAR = 'old_value'
      Xpath 'a'
      let $VAR = 'let(' . T72_throw('var') . ')'
      Xpath 'b'
    catch /^var$/
      Xpath 'c'
    finally
      call assert_equal('old_value', $VAR)
    endtry

    try
      let @a = 'old_value'
      Xpath 'd'
      let @a = 'let(' . T72_throw('reg') . ')'
      Xpath 'e'
    catch /^reg$/
      try
        Xpath 'f'
        let @A = 'let(' . T72_throw('REG') . ')'
        Xpath 'g'
      catch /^REG$/
        Xpath 'h'
      endtry
    finally
      call assert_equal('old_value', @a)
      call assert_equal('old_value', @A)
    endtry

    try
      let saved_gpath = &g:path
      let saved_lpath = &l:path
      Xpath 'i'
      let &path = 'let(' . T72_throw('opt') . ')'
      Xpath 'j'
    catch /^opt$/
      try
        Xpath 'k'
        let &g:path = 'let(' . T72_throw('gopt') . ')'
        Xpath 'l'
      catch /^gopt$/
        try
          Xpath 'm'
          let &l:path = 'let(' . T72_throw('lopt') . ')'
          Xpath 'n'
        catch /^lopt$/
          Xpath 'o'
        endtry
      endtry
    finally
      call assert_equal(saved_gpath, &g:path)
      call assert_equal(saved_lpath, &l:path)
      let &g:path = saved_gpath
      let &l:path = saved_lpath
    endtry

    unlet! var1 var2 var3

    try
      Xpath 'p'
      let var1 = 'let(' . T72_throw('var1') . ')'
      Xpath 'q'
    catch /^var1$/
      Xpath 'r'
    finally
      call assert_true(!exists('var1'))
    endtry

    try
      let var2 = 'old_value'
      Xpath 's'
      let var2 = 'let(' . T72_throw('var2'). ')'
      Xpath 't'
    catch /^var2$/
      Xpath 'u'
    finally
      call assert_equal('old_value', var2)
    endtry

    try
      Xpath 'v'
      let var{T72_throw('var3')} = 4711
      Xpath 'w'
    catch /^var3$/
      Xpath 'x'
    endtry

    try
      call T72_addpath('T1')
      let var{T72_throw('var4')} var{T72_addpath('T2')} | call T72_addpath('T3')
      call T72_addpath('T4')
    catch /^var4$/
      call T72_addpath('T5')
    endtry

    try
      call T72_addpath('T6')
      unlet var{T72_throw('var5')} var{T72_addpath('T7')}
            \ | call T72_addpath('T8')
      call T72_addpath('T9')
    catch /^var5$/
      call T72_addpath('T10')
    endtry

    call assert_equal('T1T5T6T10', g:T72_addpath)
    call assert_equal(11, g:throwcount)
  catch /.*/
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry

  call assert_equal('acdfhikmoprsuvx', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 73:  :throw across :function, :delfunction			    {{{1
"
"	    The :function and :delfunction commands may cause an expression
"	    specified in braces to be evaluated.  During evaluation, an
"	    exception might be thrown.  The exception can be caught by the
"	    script.
"-------------------------------------------------------------------------------

let T73_taken = ''

func T73_throw(x, n)
  let g:T73_taken = g:T73_taken . 'T' . a:n
  throw a:x
endfunc

func T73_expr(x, n)
  let g:T73_taken = g:T73_taken . 'E' . a:n
  if a:n % 2 == 0
    call T73_throw(a:x, a:n)
  endif
  return 2 - a:n % 2
endfunc

func Test_throw_func()
  XpathINIT

  try
    try
      " Define function.
      Xpath 'a'
      function! F0()
      endfunction
      Xpath 'b'
      function! F{T73_expr('function-def-ok', 1)}()
      endfunction
      Xpath 'c'
      function! F{T73_expr('function-def', 2)}()
      endfunction
      Xpath 'd'
    catch /^function-def-ok$/
      Xpath 'e'
    catch /^function-def$/
      Xpath 'f'
    catch /.*/
      call assert_report('def: ' . v:exception . ' in ' . v:throwpoint)
    endtry

    try
      " List function.
      Xpath 'g'
      function F0
      Xpath 'h'
      function F{T73_expr('function-lst-ok', 3)}
      Xpath 'i'
      function F{T73_expr('function-lst', 4)}
      Xpath 'j'
    catch /^function-lst-ok$/
      Xpath 'k'
    catch /^function-lst$/
      Xpath 'l'
    catch /.*/
      call assert_report('lst: ' . v:exception . ' in ' . v:throwpoint)
    endtry

    try
      " Delete function
      Xpath 'm'
      delfunction F0
      Xpath 'n'
      delfunction F{T73_expr('function-del-ok', 5)}
      Xpath 'o'
      delfunction F{T73_expr('function-del', 6)}
      Xpath 'p'
    catch /^function-del-ok$/
      Xpath 'q'
    catch /^function-del$/
      Xpath 'r'
    catch /.*/
      call assert_report('del: ' . v:exception . ' in ' . v:throwpoint)
    endtry
    call assert_equal('E1E2T2E3E4T4E5E6T6', g:T73_taken)
  catch /.*/
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry

  call assert_equal('abcfghilmnor', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 74:  :throw across builtin functions and commands		    {{{1
"
"	    Some functions like exists(), searchpair() take expression
"	    arguments, other functions or commands like substitute() or
"	    :substitute cause an expression (specified in the regular
"	    expression) to be evaluated.  During evaluation an exception
"	    might be thrown.  The exception can be caught by the script.
"-------------------------------------------------------------------------------

let T74_taken = ""

func T74_throw(x, n)
  let g:T74_taken = g:T74_taken . "T" . a:n
  throw a:x
endfunc

func T74_expr(x, n)
  let g:T74_taken = g:T74_taken . "E" . a:n
  call T74_throw(a:x . a:n, a:n)
  return "EXPR"
endfunc

func T74_skip(x, n)
  let g:T74_taken = g:T74_taken . "S" . a:n . "(" . line(".")
  let theline = getline(".")
  if theline =~ "skip"
    let g:T74_taken = g:T74_taken . "s)"
    return 1
  elseif theline =~ "throw"
    let g:T74_taken = g:T74_taken . "t)"
    call T74_throw(a:x . a:n, a:n)
  else
    let g:T74_taken = g:T74_taken . ")"
    return 0
  endif
endfunc

func T74_subst(x, n)
  let g:T74_taken = g:T74_taken . "U" . a:n . "(" . line(".")
  let theline = getline(".")
  if theline =~ "not"       " T74_subst() should not be called for this line
    let g:T74_taken = g:T74_taken . "n)"
    call T74_throw(a:x . a:n, a:n)
  elseif theline =~ "throw"
    let g:T74_taken = g:T74_taken . "t)"
    call T74_throw(a:x . a:n, a:n)
  else
    let g:T74_taken = g:T74_taken . ")"
    return "replaced"
  endif
endfunc

func Test_throw_builtin_func()
  XpathINIT

  try
    try
      Xpath 'a'
      let result = exists('*{T74_expr("exists", 1)}')
      Xpath 'b'
    catch /^exists1$/
      Xpath 'c'
      try
        let result = exists('{T74_expr("exists", 2)}')
        Xpath 'd'
      catch /^exists2$/
        Xpath 'e'
      catch /.*/
        call assert_report('exists2: ' . v:exception . ' in ' . v:throwpoint)
      endtry
    catch /.*/
      call assert_report('exists1: ' . v:exception . ' in ' . v:throwpoint)
    endtry

    try
      let file = tempname()
      exec "edit" file
      call append(0, [
            \ 'begin',
            \ 'xx',
            \ 'middle 3',
            \ 'xx',
            \ 'middle 5 skip',
            \ 'xx',
            \ 'middle 7 throw',
            \ 'xx',
            \ 'end'])
      normal! gg
      Xpath 'f'
      let result = searchpair("begin", "middle", "end", '',
            \ 'T74_skip("searchpair", 3)')
      Xpath 'g'
      let result = searchpair("begin", "middle", "end", '',
            \ 'T74_skip("searchpair", 4)')
      Xpath 'h'
      let result = searchpair("begin", "middle", "end", '',
            \ 'T74_skip("searchpair", 5)')
      Xpath 'i'
    catch /^searchpair[35]$/
      Xpath 'j'
    catch /^searchpair4$/
      Xpath 'k'
    catch /.*/
      call assert_report('searchpair: ' . v:exception . ' in ' . v:throwpoint)
    finally
      bwipeout!
      call delete(file)
    endtry

    try
      let file = tempname()
      exec "edit" file
      call append(0, [
            \ 'subst 1',
            \ 'subst 2',
            \ 'not',
            \ 'subst 4',
            \ 'subst throw',
            \ 'subst 6'])
      normal! gg
      Xpath 'l'
      1,2substitute/subst/\=T74_subst("substitute", 6)/
      try
        Xpath 'm'
        try
          let v:errmsg = ""
          3substitute/subst/\=T74_subst("substitute", 7)/
        finally
          if v:errmsg != ""
            " If exceptions are not thrown on errors, fake the error
            " exception in order to get the same execution path.
            throw "faked Vim(substitute)"
          endif
        endtry
      catch /Vim(substitute)/	    " Pattern not found ('e' flag missing)
        Xpath 'n'
        3substitute/subst/\=T74_subst("substitute", 8)/e
        Xpath 'o'
      endtry
      Xpath 'p'
      4,6substitute/subst/\=T74_subst("substitute", 9)/
      Xpath 'q'
    catch /^substitute[678]/
      Xpath 'r'
    catch /^substitute9/
      Xpath 's'
    finally
      bwipeout!
      call delete(file)
    endtry

    try
      Xpath 't'
      let var = substitute("sub", "sub", '\=T74_throw("substitute()y", 10)', '')
      Xpath 'u'
    catch /substitute()y/
      Xpath 'v'
    catch /.*/
      call assert_report('substitute()y: ' . v:exception . ' in '
            \ . v:throwpoint)
    endtry

    try
      Xpath 'w'
      let var = substitute("not", "sub", '\=T74_throw("substitute()n", 11)', '')
      Xpath 'x'
    catch /substitute()n/
      Xpath 'y'
    catch /.*/
      call assert_report('substitute()n: ' . v:exception . ' in '
            \ . v:throwpoint)
    endtry

    call assert_equal('E1T1E2T2S3(3)S4(5s)S4(7t)T4U6(1)U6(2)U9(4)U9(5t)T9T10',
          \ g:T74_taken)

  catch /.*/
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  endtry

  call assert_equal('acefgklmnopstvwx', g:Xpath)
endfunc


"-------------------------------------------------------------------------------
" Test 75:  Errors in builtin functions.				    {{{1
"
"	    On an error in a builtin function called inside a :try/:endtry
"	    region, the evaluation of the expression calling that function and
"	    the command containing that expression are abandoned.  The error can
"	    be caught as an exception.
"
"	    A simple :call of the builtin function is a trivial case.  If the
"	    builtin function is called in the argument list of another function,
"	    no further arguments are evaluated, and the other function is not
"	    executed.  If the builtin function is called from the argument of
"	    a :return command, the :return command is not executed.  If the
"	    builtin function is called from the argument of a :throw command,
"	    the :throw command is not executed.  The evaluation of the
"	    expression calling the builtin function is abandoned.
"-------------------------------------------------------------------------------

func T75_F1(arg1)
  Xpath 'a'
endfunc

func T75_F2(arg1, arg2)
  Xpath 'b'
endfunc

func T75_G()
  Xpath 'c'
endfunc

func T75_H()
  Xpath 'd'
endfunc

func T75_R()
  while 1
    try
      let caught = 0
      let v:errmsg = ""
      Xpath 'e'
      return append(1, "s")
    catch /E21/
      let caught = 1
    catch /.*/
      Xpath 'f'
    finally
      Xpath 'g'
      if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
        Xpath 'h'
      endif
      break		" discard error for $VIMNOERRTHROW
    endtry
  endwhile
  Xpath 'i'
endfunc

func Test_builtin_func_error()
  XpathINIT

  try
    set noma	" let append() fail with "E21"

    while 1
      try
        let caught = 0
        let v:errmsg = ""
        Xpath 'j'
        call append(1, "s")
      catch /E21/
        let caught = 1
      catch /.*/
        Xpath 'k'
      finally
        Xpath 'l'
        if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
          Xpath 'm'
        endif
        break		" discard error for $VIMNOERRTHROW
      endtry
    endwhile

    while 1
      try
        let caught = 0
        let v:errmsg = ""
        Xpath 'n'
        call T75_F1('x' . append(1, "s"))
      catch /E21/
        let caught = 1
      catch /.*/
        Xpath 'o'
      finally
        Xpath 'p'
        if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
          Xpath 'q'
        endif
        break		" discard error for $VIMNOERRTHROW
      endtry
    endwhile

    while 1
      try
        let caught = 0
        let v:errmsg = ""
        Xpath 'r'
        call T75_F2('x' . append(1, "s"), T75_G())
      catch /E21/
        let caught = 1
      catch /.*/
        Xpath 's'
      finally
        Xpath 't'
        if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
          Xpath 'u'
        endif
        break		" discard error for $VIMNOERRTHROW
      endtry
    endwhile

    call T75_R()

    while 1
      try
        let caught = 0
        let v:errmsg = ""
        Xpath 'v'
        throw "T" . append(1, "s")
      catch /E21/
        let caught = 1
      catch /^T.*/
        Xpath 'w'
      catch /.*/
        Xpath 'x'
      finally
        Xpath 'y'
        if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
          Xpath 'z'
        endif
        break		" discard error for $VIMNOERRTHROW
      endtry
    endwhile

    while 1
      try
        let caught = 0
        let v:errmsg = ""
        Xpath 'A'
        let x = "a"
        let x = x . "b" . append(1, "s") . T75_H()
      catch /E21/
        let caught = 1
      catch /.*/
        Xpath 'B'
      finally
        Xpath 'C'
        if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
          Xpath 'D'
        endif
        call assert_equal('a', x)
        break		" discard error for $VIMNOERRTHROW
      endtry
    endwhile
  catch /.*/
    call assert_report('Caught ' . v:exception . ' in ' . v:throwpoint)
  finally
    set ma&
  endtry

  call assert_equal('jlmnpqrtueghivyzACD', g:Xpath)
endfunc

func Test_reload_in_try_catch()
  call writefile(['x'], 'Xreload')
  set autoread
  edit Xreload
  tabnew
  call writefile(['xx'], 'Xreload')
  augroup ReLoad
    au FileReadPost Xreload let x = doesnotexist
    au BufReadPost Xreload let x = doesnotexist
  augroup END
  try
    edit Xreload
  catch
  endtry
  tabnew

  tabclose
  tabclose
  autocmd! ReLoad
  set noautoread
  bwipe! Xreload
  call delete('Xreload')
endfunc

" Test for errors with :catch, :throw, :finally                            {{{1
func Test_try_catch_errors()
  call assert_fails('throw |', 'E471:')
  call assert_fails("throw \n ", 'E471:')
  call assert_fails('catch abc', 'E654:')
  call assert_fails('try | let i = 1| finally | catch | endtry', 'E604:')
  call assert_fails('finally', 'E606:')
  call assert_fails('try | finally | finally | endtry', 'E607:')
  call assert_fails('try | for i in range(5) | endif | endtry', 'E580:')
  call assert_fails('try | while v:true | endtry', 'E170:')
  call assert_fails('try | if v:true | endtry', 'E171:')

  " this was using a negative index in cstack[]
  let lines =<< trim END
      try
      for
      if
      endwhile
      if
      finally
  END
  call CheckScriptFailure(lines, 'E690:')

  let lines =<< trim END
      try
      for
      if
      endwhile
      if
      endtry
  END
  call CheckScriptFailure(lines, 'E690:')
endfunc

" Test for verbose messages with :try :catch, and :finally                 {{{1
func Test_try_catch_verbose()
  " This test works only when the language is English
  CheckEnglish

  set verbose=14

  " Test for verbose messages displayed when an exception is caught
  redir => msg
  try
    echo i
  catch /E121:/
  finally
  endtry
  redir END
  let expected = [
        \ 'Exception thrown: Vim(echo):E121: Undefined variable: i', '',
        \ 'Exception caught: Vim(echo):E121: Undefined variable: i', '',
        \ 'Exception finished: Vim(echo):E121: Undefined variable: i']
  call assert_equal(expected, split(msg, "\n"))

  " Test for verbose messages displayed when an exception is discarded
  redir => msg
  try
    try
      throw 'abc'
    finally
      throw 'xyz'
    endtry
  catch
  endtry
  redir END
  let expected = [
        \ 'Exception thrown: abc', '',
        \ 'Exception made pending: abc', '',
        \ 'Exception thrown: xyz', '',
        \ 'Exception discarded: abc', '',
        \ 'Exception caught: xyz', '',
        \ 'Exception finished: xyz']
  call assert_equal(expected, split(msg, "\n"))

  " Test for messages displayed when :throw is resumed after :finally
  redir => msg
  try
    try
      throw 'abc'
    finally
    endtry
  catch
  endtry
  redir END
  let expected = [
        \ 'Exception thrown: abc', '',
        \ 'Exception made pending: abc', '',
        \ 'Exception resumed: abc', '',
        \ 'Exception caught: abc', '',
        \ 'Exception finished: abc']
  call assert_equal(expected, split(msg, "\n"))

  " Test for messages displayed when :break is resumed after :finally
  redir => msg
  for i in range(1)
    try
      break
    finally
    endtry
  endfor
  redir END
  let expected = [':break made pending', '', ':break resumed']
  call assert_equal(expected, split(msg, "\n"))

  " Test for messages displayed when :continue is resumed after :finally
  redir => msg
  for i in range(1)
    try
      continue
    finally
    endtry
  endfor
  redir END
  let expected = [':continue made pending', '', ':continue resumed']
  call assert_equal(expected, split(msg, "\n"))

  " Test for messages displayed when :return is resumed after :finally
  func Xtest()
    try
      return 'vim'
    finally
    endtry
  endfunc
  redir => msg
  call Xtest()
  redir END
  let expected = [
        \ 'calling Xtest()', '',
        \ ':return vim made pending', '',
        \ ':return vim resumed', '',
        \ 'Xtest returning ''vim''', '',
        \ 'continuing in Test_try_catch_verbose']
  call assert_equal(expected, split(msg, "\n"))
  delfunc Xtest

  " Test for messages displayed when :finish is resumed after :finally
  call writefile(['try', 'finish', 'finally', 'endtry'], 'Xscript')
  redir => msg
  source Xscript
  redir END
  let expected = [
        \ ':finish made pending', '',
        \ ':finish resumed', '',
        \ 'finished sourcing Xscript',
        \ 'continuing in Test_try_catch_verbose']
  call assert_equal(expected, split(msg, "\n")[1:])
  call delete('Xscript')

  " Test for messages displayed when a pending :continue is discarded by an
  " exception in a finally handler
  redir => msg
  try
    for i in range(1)
      try
        continue
      finally
        throw 'abc'
      endtry
    endfor
  catch
  endtry
  redir END
  let expected = [
        \ ':continue made pending', '',
        \ 'Exception thrown: abc', '',
        \ ':continue discarded', '',
        \ 'Exception caught: abc', '',
        \ 'Exception finished: abc']
  call assert_equal(expected, split(msg, "\n"))

  set verbose&
endfunc

" Test for throwing an exception from a BufEnter autocmd                   {{{1
func Test_BufEnter_exception()
  augroup bufenter_exception
    au!
    autocmd BufEnter Xfile1 throw 'abc'
  augroup END

  let caught_abc = 0
  try
    sp Xfile1
  catch /^abc/
    let caught_abc = 1
  endtry
  call assert_equal(1, caught_abc)
  call assert_equal(1, winnr('$'))

  augroup bufenter_exception
    au!
  augroup END
  augroup! bufenter_exception
  %bwipe!

  " Test for recursively throwing exceptions in autocmds
  augroup bufenter_exception
    au!
    autocmd BufEnter Xfile1 throw 'bufenter'
    autocmd BufLeave Xfile1 throw 'bufleave'
  augroup END

  let ex_count = 0
  try
    try
      sp Xfile1
    catch /^bufenter/
      let ex_count += 1
    endtry
  catch /^bufleave/
      let ex_count += 10
  endtry
  call assert_equal(10, ex_count)
  call assert_equal(2, winnr('$'))

  augroup bufenter_exception
    au!
  augroup END
  augroup! bufenter_exception
  %bwipe!
endfunc

" Test for using try/catch when lines are joined by "|" or "\n"           {{{1
func Test_try_catch_nextcmd()
  func Throw()
    throw "Failure"
  endfunc

  let lines =<< trim END
    try
      let s:x = Throw()
    catch
      let g:caught = 1
    endtry
  END

  let g:caught = 0
  call execute(lines)
  call assert_equal(1, g:caught)

  let g:caught = 0
  call execute(join(lines, '|'))
  call assert_equal(1, g:caught)

  let g:caught = 0
  call execute(join(lines, "\n"))
  call assert_equal(1, g:caught)

  unlet g:caught
  delfunc Throw
endfunc

" Test for using try/catch in a user command with a failing expression    {{{1
func Test_user_command_try_catch()
  let lines =<< trim END
      function s:throw() abort
        throw 'error'
      endfunction

      command! Execute
      \   try
      \ |   let s:x = s:throw()
      \ | catch
      \ |   let g:caught = 'caught'
      \ | endtry

      let g:caught = 'no'
      Execute
      call assert_equal('caught', g:caught)
  END
  call writefile(lines, 'XtestTryCatch')
  source XtestTryCatch

  call delete('XtestTryCatch')
  unlet g:caught
endfunc

" Test for using throw in a called function with following error    {{{1
func Test_user_command_throw_in_function_call()
  let lines =<< trim END
      function s:get_dict() abort
        throw 'my_error'
      endfunction

      try
        call s:get_dict().foo()
      catch /my_error/
        let caught = 'yes'
      catch
        let caught = v:exception
      endtry
      call assert_equal('yes', caught)
  END
  call writefile(lines, 'XtestThrow')
  source XtestThrow

  call delete('XtestThrow')
  unlet g:caught
endfunc

" Test that after reporting an uncaught exception there is no error for a
" missing :endif
func Test_after_exception_no_endif_error()
  function Throw()
    throw "Failure"
  endfunction

  function Foo()
    if 1
      call Throw()
    endif
  endfunction
  call assert_fails('call Foo()', ['E605:', 'E605:'])
  delfunc Throw
  delfunc Foo
endfunc

" Test for using throw in a called function with following endtry    {{{1
func Test_user_command_function_call_with_endtry()
  let lines =<< trim END
      funct s:throw(msg) abort
        throw a:msg
      endfunc
      func s:main() abort
        try
          try
            throw 'err1'
          catch
            call s:throw('err2') | endtry
          catch
            let s:caught = 'yes'
        endtry
      endfunc

      call s:main()
      call assert_equal('yes', s:caught)
  END
  call writefile(lines, 'XtestThrow')
  source XtestThrow

  call delete('XtestThrow')
endfunc

func ThisWillFail()

endfunc

" This was crashing prior to the fix in 8.2.3478.
func Test_error_in_catch_and_finally()
  let lines =<< trim END
    try
      echo x
    catch
      for l in []
    finally
  END
  call writefile(lines, 'XtestCatchAndFinally')
  try
    source XtestCatchAndFinally
  catch /E600:/
  endtry

  call delete('XtestCatchAndFinally')
endfunc

" This was causing an illegal memory access
func Test_leave_block_in_endtry_not_called()
  let lines =<< trim END
      " vim9script
      " try #
      try "
      for x in []
      if
      endwhile
      if
      endtry
  END
  call writefile(lines, 'XtestEndtry')
  try
    source XtestEndtry
  catch /E171:/
  endtry

  call delete('XtestEndtry')
endfunc

" Modeline								    {{{1
" vim: ts=8 sw=2 sts=2 expandtab tw=80 fdm=marker
