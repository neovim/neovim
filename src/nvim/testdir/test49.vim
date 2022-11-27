" Vim script language tests
" Author:	Servatius Brandt <Servatius.Brandt@fujitsu-siemens.com>
" Last Change:	2020 Jun 07

"-------------------------------------------------------------------------------
" Test environment							    {{{1
"-------------------------------------------------------------------------------


" Adding new tests easily.						    {{{2
"
" Writing new tests is eased considerably with the following functions and
" abbreviations (see "Commands for recording the execution path", "Automatic
" argument generation").
"
" To get the abbreviations, execute the command
"
"    :let test49_set_env = 1 | source test49.vim
"
" To get them always (from src/nvim/testdir), put a line
"
"    au! BufRead test49.vim let test49_set_env = 1 | source test49.vim
"
" into the local .vimrc file in the src/nvim/testdir directory.
"
if exists("test49_set_env") && test49_set_env

    " Automatic argument generation for the test environment commands.

    function! Xsum()
	let addend = substitute(getline("."), '^.*"\s*X:\s*\|^.*', '', "")
	" Evaluate arithmetic expression.
	if addend != ""
	    exec "let g:Xsum = g:Xsum + " . addend
	endif
    endfunction

    function! Xcheck()
	let g:Xsum=0
	?XpathINIT?,.call Xsum()
	exec "norm A "
	return g:Xsum
    endfunction

    iab Xcheck Xcheck<Space><C-R>=Xcheck()<CR><C-O>x

    function! Xcomment(num)
	let str = ""
	let tabwidth = &sts ? &sts : &ts
	let tabs = (48+tabwidth - a:num - virtcol(".")) / tabwidth
	while tabs > 0
	    let str = str . "\t"
	    let tabs = tabs - 1
	endwhile
	let str = str . '" X:'
	return str
    endfunction

    function! Xloop()
	let back = line(".") . "|norm" . virtcol(".") . "|"
	norm 0
	let last = search('X\(loop\|path\)INIT\|Xloop\>', "bW")
	exec back
	let theline = getline(last)
	if theline =~ 'X\(loop\|path\)INIT'
	    let num = 1
	else
	    let num = 2 * substitute(theline, '.*Xloop\s*\(\d\+\).*', '\1', "")
	endif
	?X\(loop\|path\)INIT?
	    \s/\(XloopINIT!\=\s*\d\+\s\+\)\@<=\(\d\+\)/\=2*submatch(2)/
	exec back
	exec "norm a "
	return num . Xcomment(strlen(num))
    endfunction

    iab Xloop Xloop<Space><C-R>=Xloop()<CR><C-O>x

    function! Xpath(loopinit)
	let back = line(".") . "|norm" . virtcol(".") . "|"
	norm 0
	let last = search('XpathINIT\|Xpath\>\|XloopINIT', "bW")
	exec back
	let theline = getline(last)
	if theline =~ 'XpathINIT'
	    let num = 1
	elseif theline =~ 'Xpath\>'
	    let num = 2 * substitute(theline, '.*Xpath\s*\(\d\+\).*', '\1', "")
	else
	    let pattern = '.*XloopINIT!\=\s*\(\d\+\)\s*\(\d\+\).*'
	    let num = substitute(theline, pattern, '\1', "")
	    let factor = substitute(theline, pattern, '\2', "")
	    " The "<C-O>x" from the "Xpath" iab and the character triggering its
	    " expansion are in the input buffer.  Save and clear typeahead so
	    " that it is not read away by the call to "input()" below.  Restore
	    " afterwards.
	    call inputsave()
	    let loops = input("Number of iterations in previous loop? ")
	    call inputrestore()
	    while (loops > 0)
		let num = num * factor
		let loops = loops - 1
	    endwhile
	endif
	exec "norm a "
	if a:loopinit
	    return num . " 1"
	endif
	return num . Xcomment(strlen(num))
    endfunction

    iab Xpath Xpath<Space><C-R>=Xpath(0)<CR><C-O>x
    iab XloopINIT XloopINIT<Space><C-R>=Xpath(1)<CR><C-O>x

    " Also useful (see ExtraVim below):
    aug ExtraVim
	au!
	au  BufEnter <sfile> syn region ExtraVim
		    \ start=+^if\s\+ExtraVim(.*)+ end=+^endif+
		    \ transparent keepend
	au  BufEnter <sfile> syn match ExtraComment /^"/
		    \ contained containedin=ExtraVim
	au  BufEnter <sfile> hi link ExtraComment vimComment
    aug END

    aug Xpath
	au  BufEnter <sfile> syn keyword Xpath
		    \ XpathINIT Xpath XloopINIT Xloop XloopNEXT Xcheck Xout
	au  BufEnter <sfile> hi link Xpath Special
    aug END

    do BufEnter <sfile>

    " Do not execute the tests when sourcing this file for getting the functions
    " and abbreviations above, which are intended for easily adding new test
    " cases; they are not needed for test execution.  Unlet the variable
    " controlling this so that an explicit ":source" command for this file will
    " execute the tests.
    unlet test49_set_env
    finish

endif


" Commands for recording the execution path.				    {{{2
"
" The Xpath/Xloop commands can be used for computing the eXecution path by
" adding (different) powers of 2 from those script lines, for which the
" execution should be checked.  Xloop provides different addends for each
" execution of a loop.  Permitted values are 2^0 to 2^30, so that 31 execution
" points (multiply counted inside loops) can be tested.
"
" Note that the arguments of the following commands can be generated
" automatically, see below.
"
" Usage:								    {{{3
"
"   - Use XpathINIT at the beginning of the test.
"
"   - Use Xpath to check if a line is executed.
"     Argument: power of 2 (decimal).
"
"   - To check multiple execution of loops use Xloop for automatically
"     computing Xpath values:
"
"	- Use XloopINIT before the loop.
"	  Two arguments:
"		- the first Xpath value (power of 2) to be used (Xnext),
"		- factor for computing a new Xnext value when reexecuting a loop
"		  (by a ":continue" or ":endwhile"); this should be 2^n where
"		  n is the number of Xloop commands inside the loop.
"	  If XloopINIT! is used, the first execution of XloopNEXT is
"	  a no-operation.
"
"       - Use Xloop inside the loop:
"	  One argument:
"		The argument and the Xnext value are multiplied to build the
"		next Xpath value.  No new Xnext value is prepared.  The argument
"		should be 2^(n-1) for the nth Xloop command inside the loop.
"		If the loop has only one Xloop command, the argument can be
"		omitted (default: 1).
"
"	- Use XloopNEXT before ":continue" and ":endwhile".  This computes a new
"	  Xnext value for the next execution of the loop by multiplying the old
"	  one with the factor specified in the XloopINIT command.  No Argument.
"	  Alternatively, when XloopINIT! is used, a single XloopNEXT at the
"	  beginning of the loop can be used.
"
"     Nested loops are not supported.
"
"   - Use Xcheck at end of each test.  It prints the test number, the expected
"     execution path value, the test result ("OK" or "FAIL"), and, if the tests
"     fails, the actual execution path.
"     One argument:
"	    Expected Xpath/Xloop sum for the correct execution path.
"	    In order that this value can be computed automatically, do the
"	    following: For each line in the test with an Xpath and Xloop
"	    command, add a comment starting with "X:" and specifying an
"	    expression that evaluates to the value contributed by this line to
"	    the correct execution path.  (For copying an Xpath argument of at
"	    least two digits into the comment, press <C-P>.)  At the end of the
"	    test, just type "Xcheck" and press <Esc>.
"
"   - In order to add additional information to the test output file, use the
"     Xout command.  Argument(s) like ":echo".
"
" Automatic argument generation:					    {{{3
"
"   The arguments of the Xpath, XloopINIT, Xloop, and Xcheck commands can be
"   generated automatically, so that new tests can easily be written without
"   mental arithmetic.  The Xcheck argument is computed from the "X:" comments
"   of the preceding Xpath and Xloop commands.  See the commands and
"   abbreviations at the beginning of this file.
"
" Implementation:							    {{{3
"     XpathINIT, Xpath, XloopINIT, Xloop, XloopNEXT, Xcheck, Xout.
"
" The variants for existing g:ExtraVimResult are needed when executing a script
" in an extra Vim process, see ExtraVim below.

" EXTRA_VIM_START - do not change or remove this line.

com!		    XpathINIT	let g:Xpath = 0

if exists("g:ExtraVimResult")
    com! -count -bar    Xpath	exec "!echo <count> >>" . g:ExtraVimResult
else
    com! -count -bar    Xpath	let g:Xpath = g:Xpath + <count>
endif

com! -count -nargs=1 -bang
		  \ XloopINIT	let g:Xnext = <count> |
				    \ let g:Xfactor = <args> |
				    \ let g:Xskip = strlen("<bang>")

if exists("g:ExtraVimResult")
    com! -count=1 -bar  Xloop	exec "!echo " . (g:Xnext * <count>) . " >>" .
				    \ g:ExtraVimResult
else
    com! -count=1 -bar  Xloop	let g:Xpath = g:Xpath + g:Xnext * <count>
endif

com!		    XloopNEXT	let g:Xnext = g:Xnext *
				    \ (g:Xskip ? 1 : g:Xfactor) |
				    \ let g:Xskip = 0

let @r = ""
let Xtest = 1
com! -count	    Xcheck	let Xresult = "*** Test " .
				    \ (Xtest<10?"  ":Xtest<100?" ":"") .
				    \ Xtest . ": " . (
				    \ (Xpath==<count>) ? "OK (".Xpath.")" :
					\ "FAIL (".Xpath." instead of <count>)"
				    \ ) |
				    \ let @R = Xresult . "\n" |
				    \ echo Xresult |
				    \ let Xtest = Xtest + 1

if exists("g:ExtraVimResult")
    com! -nargs=+    Xoutq	exec "!echo @R:'" .
				    \ substitute(substitute(<q-args>,
				    \ "'", '&\\&&', "g"), "\n", "@NL@", "g")
				    \ . "' >>" . g:ExtraVimResult
else
    com! -nargs=+    Xoutq	let @R = "--- Test " .
				    \ (g:Xtest<10?"  ":g:Xtest<100?" ":"") .
				    \ g:Xtest . ": " . substitute(<q-args>,
				    \ "\n", "&\t      ", "g") . "\n"
endif
com! -nargs=+	    Xout	exec 'Xoutq' <args>

" Switch off storing of lines for undoing changes.  Speeds things up a little.
set undolevels=-1

" EXTRA_VIM_STOP - do not change or remove this line.


" ExtraVim() - Run a script file in an extra Vim process.		    {{{2
"
" This is useful for testing immediate abortion of the script processing due to
" an error in a command dynamically enclosed by a :try/:tryend region or when an
" exception is thrown but not caught or when an interrupt occurs.  It can also
" be used for testing :finish.
"
" An interrupt location can be specified by an "INTERRUPT" comment.  A number
" telling how often this location is reached (in a loop or in several function
" calls) should be specified as argument.  When missing, once per script
" invocation or function call is assumed.  INTERRUPT locations are tested by
" setting a breakpoint in that line and using the ">quit" debug command when
" the breakpoint is reached.  A function for which an INTERRUPT location is
" specified must be defined before calling it (or executing it as a script by
" using ExecAsScript below).
"
" This function is only called in normal modus ("g:ExtraVimResult" undefined).
"
" Tests to be executed as an extra script should be written as follows:
"
"	column 1			column 1
"	|				|
"	v				v
"
"	XpathINIT			XpathINIT
"	if ExtraVim()			if ExtraVim()
"	    ...				"   ...
"	    ...				"   ...
"	endif				endif
"	Xcheck <number>			Xcheck <number>
"
" Double quotes in column 1 are removed before the script is executed.
" They should be used if the test has unbalanced conditionals (:if/:endif,
" :while:/endwhile, :try/:endtry) or for a line with a syntax error.  The
" extra script may use Xpath, XloopINIT, Xloop, XloopNEXT, and Xout as usual.
"
" A file name may be specified as argument.  All messages of the extra Vim
" process are then redirected to the file.  An existing file is overwritten.
"
let ExtraVimCount = 0
let ExtraVimBase = expand("<sfile>")
let ExtraVimTestEnv = ""
"
function ExtraVim(...)
    " Count how often this function is called.
    let g:ExtraVimCount = g:ExtraVimCount + 1

    " Disable folds to prevent that the ranges in the ":write" commands below
    " are extended up to the end of a closed fold.  This also speeds things up
    " considerably.
    set nofoldenable

    " Open a buffer for this test script and copy the test environment to
    " a temporary file.  Take account of parts relevant for the extra script
    " execution only.
    let current_buffnr = bufnr("%")
    execute "view +1" g:ExtraVimBase
    if g:ExtraVimCount == 1
	let g:ExtraVimTestEnv = tempname()
	execute "/E" . "XTRA_VIM_START/+,/E" . "XTRA_VIM_STOP/-w"
		    \ g:ExtraVimTestEnv "|']+"
	execute "/E" . "XTRA_VIM_START/+,/E" . "XTRA_VIM_STOP/-w >>"
		    \ g:ExtraVimTestEnv "|']+"
	execute "/E" . "XTRA_VIM_START/+,/E" . "XTRA_VIM_STOP/-w >>"
		    \ g:ExtraVimTestEnv "|']+"
	execute "/E" . "XTRA_VIM_START/+,/E" . "XTRA_VIM_STOP/-w >>"
		    \ g:ExtraVimTestEnv "|']+"
    endif

    " Start the extra Vim script with a ":source" command for the test
    " environment.  The source line number where the extra script will be
    " appended, needs to be passed as variable "ExtraVimBegin" to the script.
    let extra_script = tempname()
    exec "!echo 'source " . g:ExtraVimTestEnv . "' >" . extra_script
    let extra_begin = 1

    " Starting behind the test environment, skip over the first g:ExtraVimCount
    " occurrences of "if ExtraVim()" and copy the following lines up to the
    " matching "endif" to the extra Vim script.
    execute "/E" . "ND_OF_TEST_ENVIRONMENT/"
    exec 'norm ' . g:ExtraVimCount . '/^\s*if\s\+ExtraVim(.*)/+' . "\n"
    execute ".,/^endif/-write >>" . extra_script

    " Open a buffer for the extra Vim script, delete all ^", and write the
    " script if was actually modified.
    execute "edit +" . (extra_begin + 1) extra_script
    ,$s/^"//e
    update

    " Count the INTERRUPTs and build the breakpoint and quit commands.
    let breakpoints = ""
    let debug_quits = ""
    let in_func = 0
    exec extra_begin
    while search(
	    \ '"\s*INTERRUPT\h\@!\|^\s*fu\%[nction]\>!\=\s*\%(\u\|s:\)\w*\s*(\|'
	    \ . '^\s*\\\|^\s*endf\%[unction]\>\|'
	    \ . '\%(^\s*fu\%[nction]!\=\s*\)\@<!\%(\u\|s:\)\w*\s*(\|'
	    \ . 'ExecAsScript\s\+\%(\u\|s:\)\w*',
	    \ "W") > 0
	let theline = getline(".")
	if theline =~ '^\s*fu'
	    " Function definition.
	    let in_func = 1
	    let func_start = line(".")
	    let func_name = substitute(theline,
		\ '^\s*fu\%[nction]!\=\s*\(\%(\u\|s:\)\w*\).*', '\1', "")
	elseif theline =~ '^\s*endf'
	    " End of function definition.
	    let in_func = 0
	else
	    let finding = substitute(theline, '.*\(\%' . col(".") . 'c.*\)',
		\ '\1', "")
	    if finding =~ '^"\s*INTERRUPT\h\@!'
		" Interrupt comment.  Compose as many quit commands as
		" specified.
		let cnt = substitute(finding,
		    \ '^"\s*INTERRUPT\s*\(\d*\).*$', '\1', "")
		let quits = ""
		while cnt > 0
		    " Use "\r" rather than "\n" to separate the quit commands.
		    " "\r" is not interpreted as command separator by the ":!"
		    " command below but works to separate commands in the
		    " external vim.
		    let quits = quits . "q\r"
		    let cnt = cnt - 1
		endwhile
		if in_func
		    " Add the function breakpoint and note the number of quits
		    " to be used, if specified, or one for every call else.
		    let breakpoints = breakpoints . " -c 'breakadd func " .
			\ (line(".") - func_start) . " " .
			\ func_name . "'"
		    if quits != ""
			let debug_quits = debug_quits . quits
		    elseif !exists("quits{func_name}")
			let quits{func_name} = "q\r"
		    else
			let quits{func_name} = quits{func_name} . "q\r"
		    endif
		else
		    " Add the file breakpoint and the quits to be used for it.
		    let breakpoints = breakpoints . " -c 'breakadd file " .
			\ line(".") . " " . extra_script . "'"
		    if quits == ""
			let quits = "q\r"
		    endif
		    let debug_quits = debug_quits . quits
		endif
	    else
		" Add the quits to be used for calling the function or executing
		" it as script file.
		if finding =~ '^ExecAsScript'
		    " Sourcing function as script.
		    let finding = substitute(finding,
			\ '^ExecAsScript\s\+\(\%(\u\|s:\)\w*\).*', '\1', "")
		else
		    " Function call.
		    let finding = substitute(finding,
			\ '^\(\%(\u\|s:\)\w*\).*', '\1', "")
		endif
		if exists("quits{finding}")
		    let debug_quits = debug_quits . quits{finding}
		endif
	    endif
	endif
    endwhile

    " Close the buffer for the script and create an (empty) resultfile.
    bwipeout
    let resultfile = tempname()
    exec "!>" . resultfile

    " Run the script in an extra vim.  Switch to extra modus by passing the
    " resultfile in ExtraVimResult.  Redirect messages to the file specified as
    " argument if any.  Use ":debuggreedy" so that the commands provided on the
    " pipe are consumed at the debug prompt.  Use "-N" to enable command-line
    " continuation ("C" in 'cpo').  Add "nviminfo" to 'viminfo' to avoid
    " messing up the user's viminfo file.
    let redirect = a:0 ?
	\ " -c 'au VimLeave * redir END' -c 'redir\\! >" . a:1 . "'" : ""
    exec "!echo '" . debug_quits . "q' | " .. v:progpath .. " -u NONE -N -Xes" . redirect .
	\ " -c 'debuggreedy|set viminfo+=nviminfo'" .
	\ " -c 'let ExtraVimBegin = " . extra_begin . "'" .
	\ " -c 'let ExtraVimResult = \"" . resultfile . "\"'" . breakpoints .
	\ " -S " . extra_script

    " Build the resulting sum for resultfile and add it to g:Xpath.  Add Xout
    " information provided by the extra Vim process to the test output.
    let sum = 0
    exec "edit" resultfile
    let line = 1
    while line <= line("$")
	let theline = getline(line)
	if theline =~ '^@R:'
	    exec 'Xout "' . substitute(substitute(
		\ escape(escape(theline, '"'), '\"'),
		\ '^@R:', '', ""), '@NL@', "\n", "g") . '"'
	else
	    let sum = sum + getline(line)
	endif
	let line = line + 1
    endwhile
    bwipeout
    let g:Xpath = g:Xpath + sum

    " Delete the extra script and the resultfile.
    call delete(extra_script)
    call delete(resultfile)

    " Switch back to the buffer that was active when this function was entered.
    exec "buffer" current_buffnr

    " Return 0.  This protects extra scripts from being run in the main Vim
    " process.
    return 0
endfunction


" ExtraVimThrowpoint() - Relative throwpoint in ExtraVim script		    {{{2
"
" Evaluates v:throwpoint and returns the throwpoint relative to the beginning of
" an ExtraVim script as passed by ExtraVim() in ExtraVimBegin.
"
" EXTRA_VIM_START - do not change or remove this line.
function ExtraVimThrowpoint()
    if !exists("g:ExtraVimBegin")
	Xout "ExtraVimThrowpoint() used outside ExtraVim() script."
	return v:throwpoint
    endif

    if v:throwpoint =~ '^function\>'
	return v:throwpoint
    endif

    return "line " .
	\ (substitute(v:throwpoint, '.*, line ', '', "") - g:ExtraVimBegin) .
	\ " of ExtraVim() script"
endfunction
" EXTRA_VIM_STOP - do not change or remove this line.


" MakeScript() - Make a script file from a function.			    {{{2
"
" Create a script that consists of the body of the function a:funcname.
" Replace any ":return" by a ":finish", any argument variable by a global
" variable, and every ":call" by a ":source" for the next following argument
" in the variable argument list.  This function is useful if similar tests are
" to be made for a ":return" from a function call or a ":finish" in a script
" file.
"
" In order to execute a function specifying an INTERRUPT location (see ExtraVim)
" as a script file, use ExecAsScript below.
"
" EXTRA_VIM_START - do not change or remove this line.
function MakeScript(funcname, ...)
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
" EXTRA_VIM_STOP - do not change or remove this line.


" ExecAsScript - Source a temporary script made from a function.	    {{{2
"
" Make a temporary script file from the function a:funcname, ":source" it, and
" delete it afterwards.
"
" When inside ":if ExtraVim()", add a file breakpoint for each INTERRUPT
" location specified in the function.
"
" EXTRA_VIM_START - do not change or remove this line.
function ExecAsScript(funcname)
    " Make a script from the function passed as argument.
    let script = MakeScript(a:funcname)

    " When running in an extra Vim process, add a file breakpoint for each
    " function breakpoint set when the extra Vim process was invoked by
    " ExtraVim().
    if exists("g:ExtraVimResult")
	let bplist = tempname()
	execute "redir! >" . bplist
	breaklist
	redir END
	execute "edit" bplist
	" Get the line number from the function breakpoint.  Works also when
	" LANG is set.
	execute 'v/^\s*\d\+\s\+func\s\+' . a:funcname . '\s.*/d'
	%s/^\s*\d\+\s\+func\s\+\%(\u\|s:\)\w*\s\D*\(\d*\).*/\1/e
	let cnt = 0
	while cnt < line("$")
	    let cnt = cnt + 1
	    if getline(cnt) != ""
		execute "breakadd file" getline(cnt) script
	    endif
	endwhile
	bwipeout!
	call delete(bplist)
    endif

    " Source and delete the script.
    exec "source" script
    call delete(script)
endfunction

com! -nargs=1 -bar ExecAsScript call ExecAsScript(<f-args>)
" EXTRA_VIM_STOP - do not change or remove this line.


" END_OF_TEST_ENVIRONMENT - do not change or remove this line.

function! MESSAGES(...)
    try
	exec "edit" g:msgfile
    catch /^Vim(edit):/
	return 0
    endtry

    let english = v:lang == "C" || v:lang =~ '^[Ee]n'
    let match = 1
    norm gg

    let num = a:0 / 2
    let cnt = 1
    while cnt <= num
	let enr = a:{2*cnt - 1}
	let emsg= a:{2*cnt}
	let cnt = cnt + 1

	if enr == ""
	    Xout "TODO: Add message number for:" emsg
	elseif enr == "INT"
	    let enr = ""
	endif
	if enr == "" && !english
	    continue
	endif
	let pattern = (enr != "") ? enr . ':.*' : ''
	if english
	    let pattern = pattern . emsg
	endif
	if !search(pattern, "W")
	    let match = 0
	    Xout "No match for:" pattern
	endif
	norm $
    endwhile

    bwipeout!
    return match
endfunction

" Following tests were moved to test_vimscript.vim:
"     1-24, 27-31, 34-40, 49-50, 52-68, 76-81, 87
" Following tests were moved to test_trycatch.vim:
"     25-26, 32-33, 41-48, 51, 69-75
let Xtest = 82

"-------------------------------------------------------------------------------
" Test 82:  Ignoring :catch clauses after an error or interrupt		    {{{1
"
"	    When an exception is thrown and an error or interrupt occurs before
"	    the matching :catch clause is reached, the exception is discarded
"	    and the :catch clause is ignored (also for the error or interrupt
"	    exception being thrown then).
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    try
	try
	    Xpath 1				" X: 1
	    throw "arrgh"
	    Xpath 2				" X: 0
"	    if 1
		Xpath 4				" X: 0
		" error after :throw: missing :endif
	catch /.*/
	    Xpath 8				" X: 0
	    Xout v:exception "in" ExtraVimThrowpoint()
	catch /.*/
	    Xpath 16				" X: 0
	    Xout v:exception "in" ExtraVimThrowpoint()
	endtry
	Xpath 32				" X: 0
    catch /arrgh/
	Xpath 64				" X: 0
    endtry
    Xpath 128					" X: 0
endif

if ExtraVim()
    function! E()
	try
	    try
		Xpath 256			" X: 256
		throw "arrgh"
		Xpath 512			" X: 0
"		if 1
		    Xpath 1024			" X: 0
		    " error after :throw: missing :endif
	    catch /.*/
		Xpath 2048			" X: 0
		Xout v:exception "in" ExtraVimThrowpoint()
	    catch /.*/
		Xpath 4096			" X: 0
		Xout v:exception "in" ExtraVimThrowpoint()
	    endtry
	    Xpath 8192				" X: 0
	catch /arrgh/
	    Xpath 16384				" X: 0
	endtry
    endfunction

    call E()
    Xpath 32768					" X: 0
endif

if ExtraVim()
    try
	try
	    Xpath 65536				" X: 65536
	    throw "arrgh"
	    Xpath 131072			" X: 0
	catch /.*/	"INTERRUPT
	    Xpath 262144			" X: 0
	    Xout v:exception "in" ExtraVimThrowpoint()
	catch /.*/
	    Xpath 524288			" X: 0
	    Xout v:exception "in" ExtraVimThrowpoint()
	endtry
	Xpath 1048576				" X: 0
    catch /arrgh/
	Xpath 2097152				" X: 0
    endtry
    Xpath 4194304				" X: 0
endif

if ExtraVim()
    function I()
	try
	    try
		Xpath 8388608			" X: 8388608
		throw "arrgh"
		Xpath 16777216			" X: 0
	    catch /.*/	"INTERRUPT
		Xpath 33554432			" X: 0
		Xout v:exception "in" ExtraVimThrowpoint()
	    catch /.*/
		Xpath 67108864			" X: 0
		Xout v:exception "in" ExtraVimThrowpoint()
	    endtry
	    Xpath 134217728			" X: 0
	catch /arrgh/
	    Xpath 268435456			" X: 0
	endtry
    endfunction

    call I()
    Xpath 536870912				" X: 0
endif

Xcheck 8454401


"-------------------------------------------------------------------------------
" Test 83:  Executing :finally clauses after an error or interrupt	    {{{1
"
"	    When an exception is thrown and an error or interrupt occurs before
"	    the :finally of the innermost :try is reached, the exception is
"	    discarded and the :finally clause is executed.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    try
	Xpath 1					" X: 1
	try
	    Xpath 2				" X: 2
	    throw "arrgh"
	    Xpath 4				" X: 0
"	    if 1
		Xpath 8				" X: 0
	    " error after :throw: missing :endif
	finally
	    Xpath 16				" X: 16
	endtry
	Xpath 32				" X: 0
    catch /arrgh/
	Xpath 64				" X: 0
    endtry
    Xpath 128					" X: 0
endif

if ExtraVim()
    try
	Xpath 256				" X: 256
	try
	    Xpath 512				" X: 512
	    throw "arrgh"
	    Xpath 1024				" X: 0
	finally		"INTERRUPT
	    Xpath 2048				" X: 2048
	endtry
	Xpath 4096				" X: 0
    catch /arrgh/
	Xpath 8192				" X: 0
    endtry
    Xpath 16384					" X: 0
endif

Xcheck 2835


"-------------------------------------------------------------------------------
" Test 84:  Exceptions in autocommand sequences.			    {{{1
"
"	    When an exception occurs in a sequence of autocommands for
"	    a specific event, the rest of the sequence is not executed.  The
"	    command that triggered the autocommand execution aborts, and the
"	    exception is propagated to the caller.
"
"	    For the FuncUndefined event under a function call expression or
"	    :call command, the function is not executed, even when it has
"	    been defined by the autocommands before the exception occurred.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    function! INT()
	"INTERRUPT
	let dummy = 0
    endfunction

    aug TMP
	autocmd!

	autocmd User x1 Xpath 1			" X: 1
	autocmd User x1 throw "x1"
	autocmd User x1 Xpath 2			" X: 0

	autocmd User x2 Xpath 4			" X: 4
	autocmd User x2 asdf
	autocmd User x2 Xpath 8			" X: 0

	autocmd User x3 Xpath 16		" X: 16
	autocmd User x3 call INT()
	autocmd User x3 Xpath 32		" X: 0

	autocmd FuncUndefined U1 function! U1()
	autocmd FuncUndefined U1     Xpath 64	" X: 0
	autocmd FuncUndefined U1 endfunction
	autocmd FuncUndefined U1 Xpath 128	" X: 128
	autocmd FuncUndefined U1 throw "U1"
	autocmd FuncUndefined U1 Xpath 256	" X: 0

	autocmd FuncUndefined U2 function! U2()
	autocmd FuncUndefined U2     Xpath 512	" X: 0
	autocmd FuncUndefined U2 endfunction
	autocmd FuncUndefined U2 Xpath 1024	" X: 1024
	autocmd FuncUndefined U2 ASDF
	autocmd FuncUndefined U2 Xpath 2048	" X: 0

	autocmd FuncUndefined U3 function! U3()
	autocmd FuncUndefined U3     Xpath 4096	" X: 0
	autocmd FuncUndefined U3 endfunction
	autocmd FuncUndefined U3 Xpath 8192	" X: 8192
	autocmd FuncUndefined U3 call INT()
	autocmd FuncUndefined U3 Xpath 16384	" X: 0
    aug END

    try
	try
	    Xpath 32768				" X: 32768
	    doautocmd User x1
	catch /x1/
	    Xpath 65536				" X: 65536
	endtry

	while 1
	    try
		Xpath 131072			" X: 131072
		let caught = 0
		doautocmd User x2
	    catch /asdf/
		let caught = 1
	    finally
		Xpath 262144			" X: 262144
		if !caught && !$VIMNOERRTHROW
		    Xpath 524288		" X: 0
		    " Propagate uncaught error exception,
		else
		    " ... but break loop for caught error exception,
		    " or discard error and break loop if $VIMNOERRTHROW
		    break
		endif
	    endtry
	endwhile

	while 1
	    try
		Xpath 1048576			" X: 1048576
		let caught = 0
		doautocmd User x3
	    catch /Vim:Interrupt/
		let caught = 1
	    finally
		Xpath 2097152			" X: 2097152
		if !caught && !$VIMNOINTTHROW
		    Xpath 4194304		" X: 0
		    " Propagate uncaught interrupt exception,
		else
		    " ... but break loop for caught interrupt exception,
		    " or discard interrupt and break loop if $VIMNOINTTHROW
		    break
		endif
	    endtry
	endwhile

	if exists("*U1") | delfunction U1 | endif
	if exists("*U2") | delfunction U2 | endif
	if exists("*U3") | delfunction U3 | endif

	try
	    Xpath 8388608			" X: 8388608
	    call U1()
	catch /U1/
	    Xpath 16777216			" X: 16777216
	endtry

	while 1
	    try
		Xpath 33554432			" X: 33554432
		let caught = 0
		call U2()
	    catch /ASDF/
		let caught = 1
	    finally
		Xpath 67108864			" X: 67108864
		if !caught && !$VIMNOERRTHROW
		    Xpath 134217728		" X: 0
		    " Propagate uncaught error exception,
		else
		    " ... but break loop for caught error exception,
		    " or discard error and break loop if $VIMNOERRTHROW
		    break
		endif
	    endtry
	endwhile

	while 1
	    try
		Xpath 268435456			" X: 268435456
		let caught = 0
		call U3()
	    catch /Vim:Interrupt/
		let caught = 1
	    finally
		Xpath 536870912			" X: 536870912
		if !caught && !$VIMNOINTTHROW
		    Xpath 1073741824		" X: 0
		    " Propagate uncaught interrupt exception,
		else
		    " ... but break loop for caught interrupt exception,
		    " or discard interrupt and break loop if $VIMNOINTTHROW
		    break
		endif
	    endtry
	endwhile
    catch /.*/
	" The Xpath command does not accept 2^31 (negative); display explicitly:
	exec "!echo 2147483648 >>" . g:ExtraVimResult
	Xout "Caught" v:exception "in" v:throwpoint
    endtry

    unlet caught
    delfunction INT
    delfunction U1
    delfunction U2
    delfunction U3
    au! TMP
    aug! TMP
endif

Xcheck 934782101


"-------------------------------------------------------------------------------
" Test 85:  Error exceptions in autocommands for I/O command events	    {{{1
"
"	    When an I/O command is inside :try/:endtry, autocommands to be
"	    executed after it should be skipped on an error (exception) in the
"	    command itself or in autocommands to be executed before the command.
"	    In the latter case, the I/O command should not be executed either.
"	    Example 1: BufWritePre, :write, BufWritePost
"	    Example 2: FileReadPre, :read, FileReadPost.
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

" Remove the autocommands for the events specified as arguments in all used
" autogroups.
function Delete_autocommands(...)
    let augfile = tempname()
    while 1
	try
	    exec "redir >" . augfile
	    aug
	    redir END
	    exec "edit" augfile
	    g/^$/d
	    norm G$
	    let wrap = "w"
	    while search('\%(  \|^\)\@<=.\{-}\%(  \)\@=', wrap) > 0
		let wrap = "W"
		exec "norm y/  \n"
		let argno = 1
		while argno <= a:0
		    exec "au!" escape(@", " ") a:{argno}
		    let argno = argno + 1
		endwhile
	    endwhile
	catch /.*/
	finally
	    bwipeout!
	    call delete(augfile)
	    break		" discard errors for $VIMNOERRTHROW
	endtry
    endwhile
endfunction

call Delete_autocommands("BufWritePre", "BufWritePost")

while 1
    try
	try
	    let post = 0
	    aug TMP
		au! BufWritePost * let post = 1
	    aug END
	    let caught = 0
	    write /n/o/n/e/x/i/s/t/e/n/t
	catch /^Vim(write):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(write):', '', "")
	finally
	    Xpath 1				" X: 1
	    if !caught && !$VIMNOERRTHROW
		Xpath 2				" X: 0
	    endif
	    let v:errmsg = substitute(v:errmsg, '^"/n/o/n/e/x/i/s/t/e/n/t" ',
		\ '', "")
	    if !MSG('E212', "Can't open file for writing")
		Xpath 4				" X: 0
	    endif
	    if post
		Xpath 8				" X: 0
		Xout "BufWritePost commands executed after write error"
	    endif
	    au! TMP
	    aug! TMP
	endtry
    catch /.*/
	Xpath 16				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let post = 0
	    aug TMP
		au! BufWritePre  * asdf
		au! BufWritePost * let post = 1
	    aug END
	    let tmpfile = tempname()
	    let caught = 0
	    exec "write" tmpfile
	catch /^Vim\((write)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((write)\)\=:', '', "")
	finally
	    Xpath 32				" X: 32
	    if !caught && !$VIMNOERRTHROW
		Xpath 64			" X: 0
	    endif
	    let v:errmsg = substitute(v:errmsg, '^"'.tmpfile.'" ', '', "")
	    if !MSG('E492', "Not an editor command")
		Xpath 128			" X: 0
	    endif
	    if filereadable(tmpfile)
		Xpath 256			" X: 0
		Xout ":write command not suppressed after BufWritePre error"
	    endif
	    if post
		Xpath 512			" X: 0
		Xout "BufWritePost commands executed after BufWritePre error"
	    endif
	    au! TMP
	    aug! TMP
	endtry
    catch /.*/
	Xpath 1024				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

call delete(tmpfile)

call Delete_autocommands("BufWritePre", "BufWritePost",
    \ "BufReadPre", "BufReadPost", "FileReadPre", "FileReadPost")

while 1
    try
	try
	    let post = 0
	    aug TMP
		au! FileReadPost * let post = 1
	    aug END
	    let caught = 0
	    read /n/o/n/e/x/i/s/t/e/n/t
	catch /^Vim(read):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(read):', '', "")
	finally
	    Xpath 2048				" X: 2048
	    if !caught && !$VIMNOERRTHROW
		Xpath 4096			" X: 0
	    endif
	    let v:errmsg = substitute(v:errmsg, ' /n/o/n/e/x/i/s/t/e/n/t$',
		\ '', "")
	    if !MSG('E484', "Can't open file")
		Xpath 8192			" X: 0
	    endif
	    if post
		Xpath 16384			" X: 0
		Xout "FileReadPost commands executed after write error"
	    endif
	    au! TMP
	    aug! TMP
	endtry
    catch /.*/
	Xpath 32768				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	let infile = tempname()
	let tmpfile = tempname()
	exec "!echo XYZ >" . infile
	exec "edit" tmpfile
	try
	    Xpath 65536				" X: 65536
	    try
		let post = 0
		aug TMP
		    au! FileReadPre  * asdf
		    au! FileReadPost * let post = 1
		aug END
		let caught = 0
		exec "0read" infile
	    catch /^Vim\((read)\)\=:/
		let caught = 1
		let v:errmsg = substitute(v:exception, '^Vim\((read)\)\=:', '',
		    \ "")
	    finally
		Xpath 131072			" X: 131072
		if !caught && !$VIMNOERRTHROW
		    Xpath 262144		" X: 0
		endif
		let v:errmsg = substitute(v:errmsg, ' '.infile.'$', '', "")
		if !MSG('E492', "Not an editor command")
		    Xpath 524288		" X: 0
		endif
		if getline("1") == "XYZ"
		    Xpath 1048576		" X: 0
		    Xout ":read command not suppressed after FileReadPre error"
		endif
		if post
		    Xpath 2097152		" X: 0
		    Xout "FileReadPost commands executed after " .
			\ "FileReadPre error"
		endif
		au! TMP
		aug! TMP
	    endtry
	finally
	    bwipeout!
	endtry
    catch /.*/
	Xpath 4194304				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

call delete(infile)
call delete(tmpfile)
unlet! caught post infile tmpfile
delfunction MSG
delfunction Delete_autocommands

Xcheck 198689

"-------------------------------------------------------------------------------
" Test 86:  setloclist crash						    {{{1
"
"	    Executing a setloclist() on BufUnload shouldn't crash Vim
"-------------------------------------------------------------------------------

func F
    au BufUnload * :call setloclist(0, [{'bufnr':1, 'lnum':1, 'col':1, 'text': 'tango down'}])

    :lvimgrep /.*/ *.mak
endfunc

XpathINIT

ExecAsScript F

delfunction F
Xout  "No Crash for vimgrep on BufUnload"
Xcheck 0 

" Test 87 was moved to test_vimscript.vim
let Xtest = 88


"-------------------------------------------------------------------------------
" Test 88:  $VIMNOERRTHROW and $VIMNOINTTHROW support			    {{{1
"
"	    It is possible to configure Vim for throwing exceptions on error
"	    or interrupt, controlled by variables $VIMNOERRTHROW and
"	    $VIMNOINTTHROW.  This is just for increasing the number of tests.
"	    All tests here should run for all four combinations of setting
"	    these variables to 0 or 1.  The variables are intended for the
"	    development phase only.  In the final release, Vim should be
"	    configured to always use error and interrupt exceptions.
"
"	    The test result is "OK",
"
"		- if the $VIMNOERRTHROW and the $VIMNOINTTHROW control are not
"		  configured and exceptions are thrown on error and on
"		  interrupt.
"
"		- if the $VIMNOERRTHROW or the $VIMNOINTTHROW control is
"		  configured and works as intended.
"
"	    What actually happens, is shown in the test output.
"
"	    Otherwise, the test result is "FAIL", and the test output describes
"	    the problem.
"
" IMPORTANT:  This must be the last test because it sets $VIMNOERRTHROW and
"	      $VIMNOINTTHROW.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    function! ThrowOnError()
	XloopNEXT
	let caught = 0
	try
	    Xloop 1				" X: 1 + 8 + 64
	    asdf
	catch /.*/
	    let caught = 1	" error exception caught
	finally
	    Xloop 2				" X: 2 + 16 + 128
	    return caught	" discard aborting error
	endtry
	Xloop 4					" X: 0
    endfunction

    let quits_skipped = 0

    function! ThrowOnInterrupt()
	XloopNEXT
	let caught = 0
	try
	    Xloop 1				" X: (1 + 8 + 64) * 512
	    "INTERRUPT3
	    let dummy = 0
	    let g:quits_skipped = g:quits_skipped + 1
	catch /.*/
	    let caught = 1	" interrupt exception caught
	finally
	    Xloop 2				" X: (2 + 16 + 128) * 512
	    return caught	" discard interrupt
	endtry
	Xloop 4					" X: 0
    endfunction

    function! CheckThrow(Type)
	execute 'return ThrowOn' . a:Type . '()'
    endfunction

    function! CheckConfiguration(type)	    " type is "error" or "interrupt"

	let type = a:type
	let Type = substitute(type, '.*', '\u&', "")
	let VAR = '$VIMNO' . substitute(type, '\(...\).*', '\U\1', "") . 'THROW'

	if type == "error"
	    XloopINIT! 1 8
	elseif type == "interrupt"
	    XloopINIT! 512 8
	endif

	exec 'let requested_for_tests = exists(VAR) && ' . VAR . ' == 0'
	exec 'let suppressed_for_tests = ' . VAR . ' != 0'
	let used_in_tests = CheckThrow(Type)

	exec 'let ' . VAR . ' = 0'
	let request_works = CheckThrow(Type)

	exec 'let ' . VAR . ' = 1'
	let suppress_works = !CheckThrow(Type)

	if type == "error"
	    XloopINIT! 262144 8
	elseif type == "interrupt"
	    XloopINIT! 2097152 8

	    if g:quits_skipped != 0
		Xloop 1				" X: 0*2097152
		Xout "Test environment error.  Interrupt breakpoints skipped: "
		    \ . g:quits_skipped . ".\n"
		    \ . "Cannot check whether interrupt exceptions are thrown."
		return
	    endif
	endif

	let failure =
	    \ !suppressed_for_tests && !used_in_tests
	    \ || !request_works

	let contradiction =
	    \ used_in_tests
		\ ? suppressed_for_tests && !request_works
		\ : !suppressed_for_tests

	if failure
	    " Failure in configuration.
	    Xloop 2				" X: 0 * 2*  (262144 + 2097152)
	elseif contradiction
	    " Failure in test logic.  Should not happen.
	    Xloop 4				" X: 0 * 4 * (262144 + 2097152)
	endif

	let var_control_configured =
	    \ request_works != used_in_tests
	    \ || suppress_works == used_in_tests

	let var_control_not_configured =
	    \ requested_for_tests || suppressed_for_tests
		\ ? request_works && !suppress_works
		\ : request_works == used_in_tests
		    \ && suppress_works != used_in_tests

	let with = used_in_tests ? "with" : "without"

	let set = suppressed_for_tests ? "non-zero" :
	    \ requested_for_tests ? "0" : "unset"

	let although = contradiction && !var_control_not_configured
	    \ ? ",\nalthough "
	    \ : ".\n"

	let output = "All tests were run " . with . " throwing exceptions on "
	    \ . type . although

	if !var_control_not_configured
	    let output = output . VAR . " was " . set . "."

	    if !request_works && !requested_for_tests
		let output = output .
		    \ "\n" . Type . " exceptions are not thrown when " . VAR .
		    \ " is\nset to 0."
	    endif

	    if !suppress_works && (!used_in_tests ||
	    \ !request_works &&
	    \ !requested_for_tests && !suppressed_for_tests)
		let output = output .
		    \ "\n" . Type . " exceptions are thrown when " . VAR .
		    \ " is set to 1."
	    endif

	    if !failure && var_control_configured
		let output = output .
		    \ "\nRun tests also with " . substitute(VAR, '^\$', '', "")
		    \ . "=" . used_in_tests . "."
		    \ . "\nThis is for testing in the development phase only."
		    \ . "  Remove the \n"
		    \ . VAR . " control in the final release."
	    endif
	else
	    let output = output .
		\ "The " . VAR . " control is not configured."
	endif

	Xout output
    endfunction

    call CheckConfiguration("error")
    Xpath 16777216				" X: 16777216
    call CheckConfiguration("interrupt")
    Xpath 33554432				" X: 33554432
endif

Xcheck 50443995

" IMPORTANT: No test should be added after this test because it changes
"	     $VIMNOERRTHROW and $VIMNOINTTHROW.


"-------------------------------------------------------------------------------
" Modelines								    {{{1
" vim: ts=8 sw=4 tw=80 fdm=marker
"-------------------------------------------------------------------------------
