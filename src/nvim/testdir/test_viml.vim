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
" Modelines								    {{{1
" vim: ts=8 sw=4 tw=80 fdm=marker
" vim: fdt=substitute(substitute(foldtext(),\ '\\%(^+--\\)\\@<=\\(\\s*\\)\\(.\\{-}\\)\:\ \\%(\"\ \\)\\=\\(Test\ \\d*\\)\:\\s*',\ '\\3\ (\\2)\:\ \\1',\ \"\"),\ '\\(Test\\s*\\)\\(\\d\\)\\D\\@=',\ '\\1\ \\2',\ "")
"-------------------------------------------------------------------------------
