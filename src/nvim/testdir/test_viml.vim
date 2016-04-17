" Test various aspects of the Vim language.
" This was formerly in test49.

"-------------------------------------------------------------------------------
" Test environment							    {{{1
"-------------------------------------------------------------------------------

com!               XpathINIT  let g:Xpath = ''
com! -nargs=1 -bar Xpath      let g:Xpath = g:Xpath . <args>

" Append a message to the "messages" file
func! Xout(text)
    split messages
    $put =a:text
    wq
endfunc

com! -nargs=1	     Xout     call Xout(<args>)

" MakeScript() - Make a script file from a function.			    {{{2
"
" Create a script that consists of the body of the function a:funcname.
" Replace any ":return" by a ":finish", any argument variable by a global
" variable, and and every ":call" by a ":source" for the next following argument
" in the variable argument list.  This function is useful if similar tests are
" to be made for a ":return" from a function call or a ":finish" in a script
" file.
function! MakeScript(funcname, ...)
    let script = tempname()
    execute "redir! >" . script
    execute "function" a:funcname
    redir END
    execute "edit" script
    " Delete the "function" and the "endfunction" lines.  Do not include the
    " word "function" in the pattern since it might be translated if LANG is
    " set.  When MakeScript() is being debugged, this deletes also the debugging
    " output of its line 3 and 4.
    exec '1,/.*' . a:funcname . '(.*)/d'
    /^\d*\s*endfunction\>/,$d
    %s/^\d*//e
    %s/return/finish/e
    %s/\<a:\(\h\w*\)/g:\1/ge
    normal gg0
    let cnt = 0
    while search('\<call\s*\%(\u\|s:\)\w*\s*(.*)', 'W') > 0
	let cnt = cnt + 1
	s/\<call\s*\%(\u\|s:\)\w*\s*(.*)/\='source ' . a:{cnt}/
    endwhile
    g/^\s*$/d
    write
    bwipeout
    return script
endfunction

" ExecAsScript - Source a temporary script made from a function.	    {{{2
"
" Make a temporary script file from the function a:funcname, ":source" it, and
" delete it afterwards.
function! ExecAsScript(funcname)
    " Make a script from the function passed as argument.
    let script = MakeScript(a:funcname)

    " Source and delete the script.
    exec "source" script
    call delete(script)
endfunction

com! -nargs=1 -bar ExecAsScript call ExecAsScript(<f-args>)


"-------------------------------------------------------------------------------
" Test 1:   :endwhile in function					    {{{1
"
"	    Detect if a broken loop is (incorrectly) reactivated by the
"	    :endwhile.  Use a :return to prevent an endless loop, and make
"	    this test first to get a meaningful result on an error before other
"	    tests will hang.
"-------------------------------------------------------------------------------

function! T1_F()
    Xpath 'a'
    let first = 1
    while 1
	Xpath 'b'
	if first
	    Xpath 'c'
	    let first = 0
	    break
	else
	    Xpath 'd'
	    return
	endif
    endwhile
endfunction

function! T1_G()
    Xpath 'h'
    let first = 1
    while 1
	Xpath 'i'
	if first
	    Xpath 'j'
	    let first = 0
	    break
	else
	    Xpath 'k'
	    return
	endif
	if 1	" unmatched :if
    endwhile
endfunction

func Test_endwhile_function()
  XpathINIT
  call T1_F()
  Xpath 'F'

  try
    call T1_G()
  catch
    " Catch missing :endif
    call assert_true(v:exception =~ 'E171')
    Xpath 'x'
  endtry
  Xpath 'G'

  call assert_equal('abcFhijxG', g:Xpath)
endfunc

"-------------------------------------------------------------------------------
" Test 2:   :endwhile in script						    {{{1
"
"	    Detect if a broken loop is (incorrectly) reactivated by the
"	    :endwhile.  Use a :finish to prevent an endless loop, and place
"	    this test before others that might hang to get a meaningful result
"	    on an error.
"
"	    This test executes the bodies of the functions T1_F and T1_G from
"	    the previous test as script files (:return replaced by :finish).
"-------------------------------------------------------------------------------

func Test_endwhile_script()
  XpathINIT
  ExecAsScript T1_F
  Xpath 'F'

  try
    ExecAsScript T1_G
  catch
    " Catch missing :endif
    call assert_true(v:exception =~ 'E171')
    Xpath 'x'
  endtry
  Xpath 'G'

  call assert_equal('abcFhijxG', g:Xpath)
endfunc

"-------------------------------------------------------------------------------
" Test 3:   :if, :elseif, :while, :continue, :break			    {{{1
"-------------------------------------------------------------------------------

function Test_if_while()
    XpathINIT
    if 1
	Xpath 'a'
	let loops = 3
	while loops > -1	    " main loop: loops == 3, 2, 1 (which breaks)
	    if loops <= 0
		let break_err = 1
		let loops = -1
	    else
		Xpath 'b' . loops
	    endif
	    if (loops == 2)
		while loops == 2 " dummy loop
		    Xpath 'c' . loops
		    let loops = loops - 1
		    continue    " stop dummy loop
		    Xpath 'd' . loops
		endwhile
		continue	    " continue main loop
		Xpath 'e' . loops
	    elseif (loops == 1)
		let p = 1
		while p	    " dummy loop
		    Xpath 'f' . loops
		    let p = 0
		    break	    " break dummy loop
		    Xpath 'g' . loops
		endwhile
		Xpath 'h' . loops
		unlet p
		break	    " break main loop
		Xpath 'i' . loops
	    endif
	    if (loops > 0)
		Xpath 'j' . loops
	    endif
	    while loops == 3    " dummy loop
		let loops = loops - 1
	    endwhile	    " end dummy loop
	endwhile		    " end main loop
	Xpath 'k'
    else
	Xpath 'l'
    endif
    Xpath 'm'
    if exists("break_err")
	Xpath 'm'
	unlet break_err
    endif

    unlet loops

    call assert_equal('ab3j3b2c2b1f1h1km', g:Xpath)
endfunc

"-------------------------------------------------------------------------------
" Test 4:   :return							    {{{1
"-------------------------------------------------------------------------------

function! T4_F()
    if 1
	Xpath 'a'
	let loops = 3
	while loops > 0				"    3:  2:     1:
	    Xpath 'b' . loops
	    if (loops == 2)
		Xpath 'c' . loops
		return
		Xpath 'd' . loops
	    endif
	    Xpath 'e' . loops
	    let loops = loops - 1
	endwhile
	Xpath 'f'
    else
	Xpath 'g'
    endif
endfunction

function Test_return()
    XpathINIT
    call T4_F()
    Xpath '4'

    call assert_equal('ab3e3b2c24', g:Xpath)
endfunction


"-------------------------------------------------------------------------------
" Test 5:   :finish							    {{{1
"
"	    This test executes the body of the function T4_F from the previous
"	    test as a script file (:return replaced by :finish).
"-------------------------------------------------------------------------------

function Test_finish()
    XpathINIT
    ExecAsScript T4_F
    Xpath '5'

    call assert_equal('ab3e3b2c25', g:Xpath)
endfunction



"-------------------------------------------------------------------------------
" Test 6:   Defining functions in :while loops				    {{{1
"
"	     Functions can be defined inside other functions.  An inner function
"	     gets defined when the outer function is executed.  Functions may
"	     also be defined inside while loops.  Expressions in braces for
"	     defining the function name are allowed.
"
"	     The functions are defined when sourcing the script, only the
"	     resulting path is checked in the test function.
"-------------------------------------------------------------------------------

XpathINIT

" The command CALL collects the argument of all its invocations in "calls"
" when used from a function (that is, when the global variable "calls" needs
" the "g:" prefix).  This is to check that the function code is skipped when
" the function is defined.  For inner functions, do so only if the outer
" function is not being executed.
"
let calls = ""
com! -nargs=1 CALL
    	\ if !exists("calls") && !exists("outer") |
    	\ let g:calls = g:calls . <args> |
    	\ endif

let i = 0
while i < 3
    let i = i + 1
    if i == 1
	Xpath 'a'
	function! F1(arg)
	    CALL a:arg
	    let outer = 1

	    let j = 0
	    while j < 1
		Xpath 'b'
		let j = j + 1
		function! G1(arg)
		    CALL a:arg
		endfunction
		Xpath 'c'
	    endwhile
	endfunction
	Xpath 'd'

	continue
    endif

    Xpath 'e' . i
    function! F{i}(i, arg)
	CALL a:arg
	let outer = 1

	if a:i == 3
	    Xpath 'f'
	endif
	let k = 0
	while k < 3
	    Xpath 'g' . k
	    let k = k + 1
	    function! G{a:i}{k}(arg)
		CALL a:arg
	    endfunction
	    Xpath 'h' . k
	endwhile
    endfunction
    Xpath 'i'

endwhile

if exists("*G1")
    Xpath 'j'
endif
if exists("*F1")
    call F1("F1")
    if exists("*G1")
        call G1("G1")
    endif
endif

if exists("G21") || exists("G22") || exists("G23")
    Xpath 'k'
endif
if exists("*F2")
    call F2(2, "F2")
    if exists("*G21")
        call G21("G21")
    endif
    if exists("*G22")
        call G22("G22")
    endif
    if exists("*G23")
        call G23("G23")
    endif
endif

if exists("G31") || exists("G32") || exists("G33")
    Xpath 'l'
endif
if exists("*F3")
    call F3(3, "F3")
    if exists("*G31")
        call G31("G31")
    endif
    if exists("*G32")
        call G32("G32")
    endif
    if exists("*G33")
        call G33("G33")
    endif
endif

Xpath 'm'

let g:test6_result = g:Xpath
let g:test6_calls = calls

unlet calls
delfunction F1
delfunction G1
delfunction F2
delfunction G21
delfunction G22
delfunction G23
delfunction G31
delfunction G32
delfunction G33

function Test_defining_functions()
    call assert_equal('ade2ie3ibcg0h1g1h2g2h3fg0h1g1h2g2h3m', g:test6_result)
    call assert_equal('F1G1F2G21G22G23F3G31G32G33', g:test6_calls)
endfunc

"-------------------------------------------------------------------------------
" Test 7:   Continuing on errors outside functions			    {{{1
"
"	    On an error outside a function, the script processing continues
"	    at the line following the outermost :endif or :endwhile.  When not
"	    inside an :if or :while, the script processing continues at the next
"	    line.
"-------------------------------------------------------------------------------

XpathINIT

if 1
    Xpath 'a'
    while 1
	Xpath 'b'
	asdf
	Xpath 'c'
	break
    endwhile | Xpath 'd'
    Xpath 'e'
endif | Xpath 'f'
Xpath 'g'

while 1
    Xpath 'h'
    if 1
	Xpath 'i'
	asdf
	Xpath 'j'
    endif | Xpath 'k'
    Xpath 'l'
    break
endwhile | Xpath 'm'
Xpath 'n'

asdf
Xpath 'o'

asdf | Xpath 'p'
Xpath 'q'

let g:test7_result = g:Xpath

func Test_error_in_script()
    call assert_equal('abghinoq', g:test7_result)
endfunc

"-------------------------------------------------------------------------------
" Test 8:   Aborting and continuing on errors inside functions		    {{{1
"
"	    On an error inside a function without the "abort" attribute, the
"	    script processing continues at the next line (unless the error was
"	    in a :return command).  On an error inside a function with the
"	    "abort" attribute, the function is aborted and the script processing
"	    continues after the function call; the value -1 is returned then.
"-------------------------------------------------------------------------------

XpathINIT

function! T8_F()
    if 1
	Xpath 'a'
	while 1
	    Xpath 'b'
	    asdf
	    Xpath 'c'
	    asdf | Xpath 'd'
	    Xpath 'e'
	    break
	endwhile
	Xpath 'f'
    endif | Xpath 'g'
    Xpath 'h'

    while 1
	Xpath 'i'
	if 1
	    Xpath 'j'
	    asdf
	    Xpath 'k'
	    asdf | Xpath 'l'
	    Xpath 'm'
	endif
	Xpath 'n'
	break
    endwhile | Xpath 'o'
    Xpath 'p'

    return novar		" returns (default return value 0)
    Xpath 'q'
    return 1			" not reached
endfunction

function! T8_G() abort
    if 1
	Xpath 'r'
	while 1
	    Xpath 's'
	    asdf		" returns -1
	    Xpath 't'
	    break
	endwhile
	Xpath 'v'
    endif | Xpath 'w'
    Xpath 'x'

    return -4			" not reached
endfunction

function! T8_H() abort
    while 1
	Xpath 'A'
	if 1
	    Xpath 'B'
	    asdf		" returns -1
	    Xpath 'C'
	endif
	Xpath 'D'
	break
    endwhile | Xpath 'E'
    Xpath 'F'

    return -4			" not reached
endfunction

" Aborted functions (T8_G and T8_H) return -1.
let g:test8_sum = (T8_F() + 1) - 4 * T8_G() - 8 * T8_H()
Xpath 'X'
let g:test8_result = g:Xpath

func Test_error_in_function()
    call assert_equal(13, g:test8_sum)
    call assert_equal('abcefghijkmnoprsABX', g:test8_result)

    delfunction T8_F
    delfunction T8_G
    delfunction T8_H
endfunc


"-------------------------------------------------------------------------------
" Test 9:   Continuing after aborted functions				    {{{1
"
"	    When a function with the "abort" attribute is aborted due to an
"	    error, the next function back in the call hierarchy without an
"	    "abort" attribute continues; the value -1 is returned then.
"-------------------------------------------------------------------------------

XpathINIT

function! F() abort
    Xpath 'a'
    let result = G()	" not aborted
    Xpath 'b'
    if result != 2
	Xpath 'c'
    endif
    return 1
endfunction

function! G()		" no abort attribute
    Xpath 'd'
    if H() != -1	" aborted
	Xpath 'e'
    endif
    Xpath 'f'
    return 2
endfunction

function! H() abort
    Xpath 'g'
    call I()		" aborted
    Xpath 'h'
    return 4
endfunction

function! I() abort
    Xpath 'i'
    asdf		" error
    Xpath 'j'
    return 8
endfunction

if F() != 1
    Xpath 'k'
endif

let g:test9_result = g:Xpath

delfunction F
delfunction G
delfunction H
delfunction I

func Test_func_abort()
    call assert_equal('adgifb', g:test9_result)
endfunc


"-------------------------------------------------------------------------------
" Test 10:  :if, :elseif, :while argument parsing			    {{{1
"
"	    A '"' or '|' in an argument expression must not be mixed up with
"	    a comment or a next command after a bar.  Parsing errors should
"	    be recognized.
"-------------------------------------------------------------------------------

XpathINIT

function! MSG(enr, emsg)
    let english = v:lang == "C" || v:lang =~ '^[Ee]n'
    if a:enr == ""
	Xout "TODO: Add message number for:" a:emsg
	let v:errmsg = ":" . v:errmsg
    endif
    let match = 1
    if v:errmsg !~ '^'.a:enr.':' || (english && v:errmsg !~ a:emsg)
	let match = 0
	if v:errmsg == ""
	    Xout "Message missing."
	else
	    let v:errmsg = escape(v:errmsg, '"')
	    Xout "Unexpected message:" v:errmsg
	endif
    endif
    return match
endfunction

if 1 || strlen("\"") | Xpath 'a'
    Xpath 'b'
endif
Xpath 'c'

if 0
elseif 1 || strlen("\"") | Xpath 'd'
    Xpath 'e'
endif
Xpath 'f'

while 1 || strlen("\"") | Xpath 'g'
    Xpath 'h'
    break
endwhile
Xpath 'i'

let v:errmsg = ""
if 1 ||| strlen("\"") | Xpath 'j'
    Xpath 'k'
endif
Xpath 'l'
if !MSG('E15', "Invalid expression")
    Xpath 'm'
endif

let v:errmsg = ""
if 0
elseif 1 ||| strlen("\"") | Xpath 'n'
    Xpath 'o'
endif
Xpath 'p'
if !MSG('E15', "Invalid expression")
    Xpath 'q'
endif

let v:errmsg = ""
while 1 ||| strlen("\"") | Xpath 'r'
    Xpath 's'
    break
endwhile
Xpath 't'
if !MSG('E15', "Invalid expression")
    Xpath 'u'
endif

let g:test10_result = g:Xpath
delfunction MSG

func Test_expr_parsing()
    call assert_equal('abcdefghilpt', g:test10_result)
endfunc


"-------------------------------------------------------------------------------
" Test 11:  :if, :elseif, :while argument evaluation after abort	    {{{1
"
"	    When code is skipped over due to an error, the boolean argument to
"	    an :if, :elseif, or :while must not be evaluated.
"-------------------------------------------------------------------------------

XpathINIT

let calls = 0

function! P(num)
    let g:calls = g:calls + a:num   " side effect on call
    return 0
endfunction

if 1
    Xpath 'a'
    asdf		" error
    Xpath 'b'
    if P(1)		" should not be called
	Xpath 'c'
    elseif !P(2)	" should not be called
	Xpath 'd'
    else
	Xpath 'e'
    endif
    Xpath 'f'
    while P(4)		" should not be called
	Xpath 'g'
    endwhile
    Xpath 'h'
endif
Xpath 'x'

let g:test11_calls = calls
let g:test11_result = g:Xpath

unlet calls
delfunction P

func Test_arg_abort()
    call assert_equal(0, g:test11_calls)
    call assert_equal('ax', g:test11_result)
endfunc


"-------------------------------------------------------------------------------
" Test 12:  Expressions in braces in skipped code			    {{{1
"
"	    In code skipped over due to an error or inactive conditional,
"	    an expression in braces as part of a variable or function name
"	    should not be evaluated.
"-------------------------------------------------------------------------------

XpathINIT

function! NULL()
    Xpath 'a'
    return 0
endfunction

function! ZERO()
    Xpath 'b'
    return 0
endfunction

function! F0()
    Xpath 'c'
endfunction

function! F1(arg)
    Xpath 'e'
endfunction

let V0 = 1

Xpath 'f'
echo 0 ? F{NULL() + V{ZERO()}}() : 1

Xpath 'g'
if 0
    Xpath 'h'
    call F{NULL() + V{ZERO()}}()
endif

Xpath 'i'
if 1
    asdf		" error
    Xpath 'j'
    call F1(F{NULL() + V{ZERO()}}())
endif

Xpath 'k'
if 1
    asdf		" error
    Xpath 'l'
    call F{NULL() + V{ZERO()}}()
endif

let g:test12_result = g:Xpath

func Test_braces_skipped()
    call assert_equal('fgik', g:test12_result)
endfunc


"-------------------------------------------------------------------------------
" Test 13:  Failure in argument evaluation for :while			    {{{1
"
"	    A failure in the expression evaluation for the condition of a :while
"	    causes the whole :while loop until the matching :endwhile being
"	    ignored.  Continuation is at the next following line.
"-------------------------------------------------------------------------------

XpathINIT

Xpath 'a'
while asdf
    Xpath 'b'
    while 1
	Xpath 'c'
	break
    endwhile
    Xpath 'd'
    break
endwhile
Xpath 'e'

while asdf | Xpath 'f' | endwhile | Xpath 'g'
Xpath 'h'
let g:test13_result = g:Xpath

func Test_while_fail()
    call assert_equal('aeh', g:test13_result)
endfunc


"-------------------------------------------------------------------------------
" Test 14:  Failure in argument evaluation for :if			    {{{1
"
"	    A failure in the expression evaluation for the condition of an :if
"	    does not cause the corresponding :else or :endif being matched to
"	    a previous :if/:elseif.  Neither of both branches of the failed :if
"	    are executed.
"-------------------------------------------------------------------------------

XpathINIT

function! F()
    Xpath 'a'
    let x = 0
    if x		" false
	Xpath 'b'
    elseif !x		" always true
	Xpath 'c'
	let x = 1
	if g:boolvar	" possibly undefined
	    Xpath 'd'
	else
	    Xpath 'e'
	endif
	Xpath 'f'
    elseif x		" never executed
	Xpath 'g'
    endif
    Xpath 'h'
endfunction

let boolvar = 1
call F()
Xpath '-'

unlet boolvar
call F()
let g:test14_result = g:Xpath

delfunction F

func Test_if_fail()
    call assert_equal('acdfh-acfh', g:test14_result)
endfunc


"-------------------------------------------------------------------------------
" Test 15:  Failure in argument evaluation for :if (bar)		    {{{1
"
"	    Like previous test, except that the failing :if ... | ... | :endif
"	    is in a single line.
"-------------------------------------------------------------------------------

XpathINIT

function! F()
    Xpath 'a'
    let x = 0
    if x		" false
	Xpath 'b'
    elseif !x		" always true
	Xpath 'c'
	let x = 1
	if g:boolvar | Xpath 'd' | else | Xpath 'e' | endif
	Xpath 'f'
    elseif x		" never executed
	Xpath 'g'
    endif
    Xpath 'h'
endfunction

let boolvar = 1
call F()
Xpath '-'

unlet boolvar
call F()
let g:test15_result = g:Xpath

delfunction F

func Test_if_bar_fail()
    call assert_equal('acdfh-acfh', g:test15_result)
endfunc


"-------------------------------------------------------------------------------
" Modelines								    {{{1
" vim: ts=8 sw=4 tw=80 fdm=marker
" vim: fdt=substitute(substitute(foldtext(),\ '\\%(^+--\\)\\@<=\\(\\s*\\)\\(.\\{-}\\)\:\ \\%(\"\ \\)\\=\\(Test\ \\d*\\)\:\\s*',\ '\\3\ (\\2)\:\ \\1',\ \"\"),\ '\\(Test\\s*\\)\\(\\d\\)\\D\\@=',\ '\\1\ \\2',\ "")
"-------------------------------------------------------------------------------
