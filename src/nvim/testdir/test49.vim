" Vim script language tests
" Author:	Servatius Brandt <Servatius.Brandt@fujitsu-siemens.com>
" Last Change:	2019 May 24

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
"		ommitted (default: 1).
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
function! ExtraVim(...)
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
    exec "!echo '" . debug_quits . "q' | $NVIM_PRG -u NONE -N -es" . redirect .
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
function! ExtraVimThrowpoint()
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
" variable, and and every ":call" by a ":source" for the next following argument
" in the variable argument list.  This function is useful if similar tests are
" to be made for a ":return" from a function call or a ":finish" in a script
" file.
"
" In order to execute a function specifying an INTERRUPT location (see ExtraVim)
" as a script file, use ExecAsScript below.
"
" EXTRA_VIM_START - do not change or remove this line.
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
function! ExecAsScript(funcname)
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


" Tests 1 to 15 were moved to test_vimscript.vim
let Xtest = 16

"-------------------------------------------------------------------------------
" Test 16:  Double :else or :elseif after :else				    {{{1
"
"	    Multiple :elses or an :elseif after an :else are forbidden.
"-------------------------------------------------------------------------------

XpathINIT

function! F() abort
    if 0
	Xpath 1					" X: 0
    else
	Xpath 2					" X: 2
    else		" aborts function
	Xpath 4					" X: 0
    endif
endfunction

function! G() abort
    if 0
	Xpath 8					" X: 0
    else
	Xpath 16				" X: 16
    elseif 1		" aborts function
	Xpath 32				" X: 0
    else
	Xpath 64				" X: 0
    endif
endfunction

function! H() abort
    if 0
	Xpath 128				" X: 0
    elseif 0
	Xpath 256				" X: 0
    else
	Xpath 512				" X: 512
    else		" aborts function
	Xpath 1024				" X: 0
    endif
endfunction

function! I() abort
    if 0
	Xpath 2048				" X: 0
    elseif 0
	Xpath 4096				" X: 0
    else
	Xpath 8192				" X: 8192
    elseif 1		" aborts function
	Xpath 16384				" X: 0
    else
	Xpath 32768				" X: 0
    endif
endfunction

call F()
call G()
call H()
call I()

delfunction F
delfunction G
delfunction H
delfunction I

Xcheck 8722


"-------------------------------------------------------------------------------
" Test 17:  Nesting of unmatched :if or :endif inside a :while		    {{{1
"
"	    The :while/:endwhile takes precedence in nesting over an unclosed
"	    :if or an unopened :endif.
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

let messages = ""

" While loops inside a function are continued on error.
function! F()
    let v:errmsg = ""
    XloopINIT 1 16
    let loops = 3
    while loops > 0
	let loops = loops - 1			"    2:  1:     0:
	Xloop 1					" X: 1 + 1*16 + 1*16*16
	if (loops == 1)
	    Xloop 2				" X:     2*16
	    XloopNEXT
	    continue
	elseif (loops == 0)
	    Xloop 4				" X:		4*16*16
	    break
	elseif 1
	    Xloop 8				" X: 8
	    XloopNEXT
	" endif missing!
    endwhile	" :endwhile after :if 1
    Xpath 4096					" X: 16*16*16
    if MSG('E171', "Missing :endif")
	let g:messages = g:messages . "A"
    endif

    let v:errmsg = ""
    XloopINIT! 8192 4
    let loops = 2
    while loops > 0				"    2:     1:
	XloopNEXT
	let loops = loops - 1
	Xloop 1					" X: 8192 + 8192*4
	if 0
	    Xloop 2				" X: 0
	" endif missing
    endwhile	" :endwhile after :if 0
    Xpath 131072				" X: 8192*4*4
    if MSG('E171', "Missing :endif")
	let g:messages = g:messages . "B"
    endif

    let v:errmsg = ""
    XloopINIT 262144 4
    let loops = 2
    while loops > 0				"    2:     1:
	let loops = loops - 1
	Xloop 1					" X: 262144 + 262144 * 4
	" if missing!
	endif	" :endif without :if in while
	Xloop 2					" X: 524288 + 524288 * 4
	XloopNEXT
    endwhile
    Xpath 4194304				" X: 262144*4*4
    if MSG('E580', ":endif without :if")
	let g:messages = g:messages . "C"
    endif
endfunction

call F()

" Error continuation outside a function is at the outermost :endwhile or :endif.
let v:errmsg = ""
XloopINIT! 8388608 4
let loops = 2
while loops > 0					"    2:		1:
    XloopNEXT
    let loops = loops - 1
    Xloop 1					" X: 8388608 + 0 * 4
    if 0
	Xloop 2					" X: 0
    " endif missing! Following :endwhile fails.
endwhile | Xpath 134217728			" X: 0
Xpath 268435456					" X: 2*8388608*4*4
if MSG('E171', "Missing :endif")
    let messages = g:messages . "D"
endif

if messages != "ABCD"
    Xpath 536870912				" X: 0
    Xout "messages is" messages "instead of ABCD"
endif

unlet loops messages
delfunction F
delfunction MSG

Xcheck 285127993


"-------------------------------------------------------------------------------
" Test 18:  Interrupt (Ctrl-C pressed)					    {{{1
"
"	    On an interrupt, the script processing is terminated immediately.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    if 1
	Xpath 1					" X: 1
	while 1
	    Xpath 2				" X: 2
	    if 1
		Xpath 4				" X: 4
		"INTERRUPT
		Xpath 8				" X: 0
		break
		finish
	    endif | Xpath 16			" X: 0
	    Xpath 32				" X: 0
	endwhile | Xpath 64			" X: 0
	Xpath 128				" X: 0
    endif | Xpath 256				" X: 0
    Xpath 512					" X: 0
endif

if ExtraVim()
    try
	Xpath 1024				" X: 1024
	"INTERRUPT
	Xpath 2048				" X: 0
    endtry | Xpath 4096				" X: 0
    Xpath 8192					" X: 0
endif

if ExtraVim()
    function! F()
	if 1
	    Xpath 16384				" X: 16384
	    while 1
		Xpath 32768			" X: 32768
		if 1
		    Xpath 65536			" X: 65536
		    "INTERRUPT
		    Xpath 131072		" X: 0
		    break
		    return
		endif | Xpath 262144		" X: 0
		Xpath Xpath 524288		" X: 0
	    endwhile | Xpath 1048576		" X: 0
	    Xpath Xpath 2097152			" X: 0
	endif | Xpath Xpath 4194304		" X: 0
	Xpath Xpath 8388608			" X: 0
    endfunction

    call F() | Xpath 16777216			" X: 0
    Xpath 33554432				" X: 0
endif

if ExtraVim()
    function! G()
	try
	    Xpath 67108864			" X: 67108864
	    "INTERRUPT
	    Xpath 134217728			" X: 0
	endtry | Xpath 268435456		" X: 0
	Xpath 536870912				" X: 0
    endfunction

    call G() | Xpath 1073741824			" X: 0
    " The Xpath command does not accept 2^31 (negative); display explicitly:
    exec "!echo 2147483648 >>" . g:ExtraVimResult
						" X: 0
endif

Xcheck 67224583


"-------------------------------------------------------------------------------
" Test 19:  Aborting on errors inside :try/:endtry			    {{{1
"
"	    An error in a command dynamically enclosed in a :try/:endtry region
"	    aborts script processing immediately.  It does not matter whether
"	    the failing command is outside or inside a function and whether a
"	    function has an "abort" attribute.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    function! F() abort
	Xpath 1					" X: 1
	asdf
	Xpath 2					" X: 0
    endfunction

    try
	Xpath 4					" X: 4
	call F()
	Xpath 8					" X: 0
    endtry | Xpath 16				" X: 0
    Xpath 32					" X: 0
endif

if ExtraVim()
    function! G()
	Xpath 64				" X: 64
	asdf
	Xpath 128				" X: 0
    endfunction

    try
	Xpath 256				" X: 256
	call G()
	Xpath 512				" X: 0
    endtry | Xpath 1024				" X: 0
    Xpath 2048					" X: 0
endif

if ExtraVim()
    try
	Xpath 4096				" X: 4096
	asdf
	Xpath 8192				" X: 0
    endtry | Xpath 16384			" X: 0
    Xpath 32768					" X: 0
endif

if ExtraVim()
    if 1
	try
	    Xpath 65536				" X: 65536
	    asdf
	    Xpath 131072			" X: 0
	endtry | Xpath 262144			" X: 0
    endif | Xpath 524288			" X: 0
    Xpath 1048576				" X: 0
endif

if ExtraVim()
    let p = 1
    while p
	let p = 0
	try
	    Xpath 2097152			" X: 2097152
	    asdf
	    Xpath 4194304			" X: 0
	endtry | Xpath 8388608			" X: 0
    endwhile | Xpath 16777216			" X: 0
    Xpath 33554432				" X: 0
endif

if ExtraVim()
    let p = 1
    while p
	let p = 0
"	try
	    Xpath 67108864			" X: 67108864
    endwhile | Xpath 134217728			" X: 0
    Xpath 268435456				" X: 0
endif

Xcheck 69275973
"-------------------------------------------------------------------------------
" Test 20:  Aborting on errors after :try/:endtry			    {{{1
"
"	    When an error occurs after the last active :try/:endtry region has
"	    been left, termination behavior is as if no :try/:endtry has been
"	    seen.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    let p = 1
    while p
	let p = 0
	try
	    Xpath 1				" X: 1
	endtry
	asdf
    endwhile | Xpath 2				" X: 0
    Xpath 4					" X: 4
endif

if ExtraVim()
    while 1
	try
	    Xpath 8				" X: 8
	    break
	    Xpath 16				" X: 0
	endtry
    endwhile
    Xpath 32					" X: 32
    asdf
    Xpath 64					" X: 64
endif

if ExtraVim()
    while 1
	try
	    Xpath 128				" X: 128
	    break
	    Xpath 256				" X: 0
	finally
	    Xpath 512				" X: 512
	endtry
    endwhile
    Xpath 1024					" X: 1024
    asdf
    Xpath 2048					" X: 2048
endif

if ExtraVim()
    while 1
	try
	    Xpath 4096				" X: 4096
	finally
	    Xpath 8192				" X: 8192
	    break
	    Xpath 16384				" X: 0
	endtry
    endwhile
    Xpath 32768					" X: 32768
    asdf
    Xpath 65536					" X: 65536
endif

if ExtraVim()
    let p = 1
    while p
	let p = 0
	try
	    Xpath 131072			" X: 131072
	    continue
	    Xpath 262144			" X: 0
	endtry
    endwhile
    Xpath 524288				" X: 524288
    asdf
    Xpath 1048576				" X: 1048576
endif

if ExtraVim()
    let p = 1
    while p
	let p = 0
	try
	    Xpath 2097152			" X: 2097152
	    continue
	    Xpath 4194304			" X: 0
	finally
	    Xpath 8388608			" X: 8388608
	endtry
    endwhile
    Xpath 16777216				" X: 16777216
    asdf
    Xpath 33554432				" X: 33554432
endif

if ExtraVim()
    let p = 1
    while p
	let p = 0
	try
	    Xpath 67108864			" X: 67108864
	finally
	    Xpath 134217728			" X: 134217728
	    continue
	    Xpath 268435456			" X: 0
	endtry
    endwhile
    Xpath 536870912				" X: 536870912
    asdf
    Xpath 1073741824				" X: 1073741824
endif

Xcheck 1874575085


"-------------------------------------------------------------------------------
" Test 21:  :finally for :try after :continue/:break/:return/:finish	    {{{1
"
"	    If a :try conditional stays inactive due to a preceding :continue,
"	    :break, :return, or :finish, its :finally clause should not be
"	    executed.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    function F()
	let loops = 2
	XloopINIT! 1 256
	while loops > 0
	    XloopNEXT
	    let loops = loops - 1
	    try
		if loops == 1
		    Xloop 1			" X: 1
		    continue
		    Xloop 2			" X: 0
		elseif loops == 0
		    Xloop 4			" X: 4*256
		    break
		    Xloop 8			" X: 0
		endif

		try		" inactive
		    Xloop 16			" X: 0
		finally
		    Xloop 32			" X: 0
		endtry
	    finally
		Xloop 64			" X: 64 + 64*256
	    endtry
	    Xloop 128				" X: 0
	endwhile

	try
	    Xpath 65536				" X: 65536
	    return
	    Xpath 131072			" X: 0
	    try		    " inactive
		Xpath 262144			" X: 0
	    finally
		Xpath 524288			" X: 0
	    endtry
	finally
	    Xpath 1048576			" X: 1048576
	endtry
	Xpath 2097152				" X: 0
    endfunction

    try
	Xpath 4194304				" X: 4194304
	call F()
	Xpath 8388608				" X: 8388608
	finish
	Xpath 16777216				" X: 0
	try		" inactive
	    Xpath 33554432			" X: 0
	finally
	    Xpath 67108864			" X: 0
	endtry
    finally
	Xpath 134217728				" X: 134217728
    endtry
    Xpath 268435456				" X: 0
endif

Xcheck 147932225


"-------------------------------------------------------------------------------
" Test 22:  :finally for a :try after an error/interrupt/:throw		    {{{1
"
"	    If a :try conditional stays inactive due to a preceding error or
"	    interrupt or :throw, its :finally clause should not be executed.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    function! Error()
	try
	    asdf    " aborting error, triggering error exception
	endtry
    endfunction

    Xpath 1					" X: 1
    call Error()
    Xpath 2					" X: 0

    if 1	" not active due to error
	try	" not active since :if inactive
	    Xpath 4				" X: 0
	finally
	    Xpath 8				" X: 0
	endtry
    endif

    try		" not active due to error
	Xpath 16				" X: 0
    finally
	Xpath 32				" X: 0
    endtry
endif

if ExtraVim()
    function! Interrupt()
	try
	    "INTERRUPT	" triggering interrupt exception
	endtry
    endfunction

    Xpath 64					" X: 64
    call Interrupt()
    Xpath 128					" X: 0

    if 1	" not active due to interrupt
	try	" not active since :if inactive
	    Xpath 256				" X: 0
	finally
	    Xpath 512				" X: 0
	endtry
    endif

    try		" not active due to interrupt
	Xpath 1024				" X: 0
    finally
	Xpath 2048				" X: 0
    endtry
endif

if ExtraVim()
    function! Throw()
	throw "xyz"
    endfunction

    Xpath 4096					" X: 4096
    call Throw()
    Xpath 8192					" X: 0

    if 1	" not active due to :throw
	try	" not active since :if inactive
	    Xpath 16384				" X: 0
	finally
	    Xpath 32768				" X: 0
	endtry
    endif

    try		" not active due to :throw
	Xpath 65536				" X: 0
    finally
	Xpath 131072				" X: 0
    endtry
endif

Xcheck 4161


"-------------------------------------------------------------------------------
" Test 23:  :catch clauses for a :try after a :throw			    {{{1
"
"	    If a :try conditional stays inactive due to a preceding :throw,
"	    none of its :catch clauses should be executed.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    try
	Xpath 1					" X: 1
	throw "xyz"
	Xpath 2					" X: 0

	if 1	" not active due to :throw
	    try	" not active since :if inactive
		Xpath 4				" X: 0
	    catch /xyz/
		Xpath 8				" X: 0
	    endtry
	endif
    catch /xyz/
	Xpath 16				" X: 16
    endtry

    Xpath 32					" X: 32
    throw "abc"
    Xpath 64					" X: 0

    try		" not active due to :throw
	Xpath 128				" X: 0
    catch /abc/
	Xpath 256				" X: 0
    endtry
endif

Xcheck 49


"-------------------------------------------------------------------------------
" Test 24:  :endtry for a :try after a :throw				    {{{1
"
"	    If a :try conditional stays inactive due to a preceding :throw,
"	    its :endtry should not rethrow the exception to the next surrounding
"	    active :try conditional.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    try			" try 1
	try		" try 2
	    Xpath 1				" X: 1
	    throw "xyz"	" makes try 2 inactive
	    Xpath 2				" X: 0

	    try		" try 3
		Xpath 4				" X: 0
	    endtry	" no rethrow to try 1
	catch /xyz/	" should catch although try 2 inactive
	    Xpath 8				" X: 8
	endtry
    catch /xyz/		" try 1 active, but exception already caught
	Xpath 16				" X: 0
    endtry
    Xpath 32					" X: 32
endif

Xcheck 41


"-------------------------------------------------------------------------------
" Test 25:  Executing :finally clauses on normal control flow		    {{{1
"
"	    Control flow in a :try conditional should always fall through to its
"	    :finally clause.  A :finally clause of a :try conditional inside an
"	    inactive conditional should never be executed.
"-------------------------------------------------------------------------------

XpathINIT

function! F()
    let loops = 3
    XloopINIT 1 256
    while loops > 0				"     3:   2:       1:
	Xloop 1					" X:  1 +  1*256 + 1*256*256
	if loops >= 2
	    try
		Xloop 2				" X:  2 +  2*256
		if loops == 2
		    try
			Xloop 4			" X:       4*256
		    finally
			Xloop 8			" X:       8*256
		    endtry
		endif
	    finally
		Xloop 16			" X: 16 + 16*256
		if loops == 2
		    try
			Xloop 32		" X:      32*256
		    finally
			Xloop 64		" X:      64*256
		    endtry
		endif
	    endtry
	endif
	Xloop 128				" X: 128 + 128*256 + 128*256*256
	let loops = loops - 1
	XloopNEXT
    endwhile
    Xpath 16777216				" X: 16777216
endfunction

if 1
    try
	Xpath 33554432				" X: 33554432
	call F()
	Xpath 67108864				" X: 67108864
    finally
	Xpath 134217728				" X: 134217728
    endtry
else
    try
	Xpath 268435456				" X: 0
    finally
	Xpath 536870912				" X: 0
    endtry
endif

delfunction F

Xcheck 260177811


"-------------------------------------------------------------------------------
" Test 26:  Executing :finally clauses after :continue or :break	    {{{1
"
"	    For a :continue or :break dynamically enclosed in a :try/:endtry
"	    region inside the next surrounding :while/:endwhile, if the
"	    :continue/:break is before the :finally, the :finally clause is
"	    executed first.  If the :continue/:break is after the :finally, the
"	    :finally clause is broken (like an :if/:endif region).
"-------------------------------------------------------------------------------

XpathINIT

try
    let loops = 3
    XloopINIT! 1 32
    while loops > 0
	XloopNEXT
	try
	    try
		if loops == 2			"    3:   2:     1:
		    Xloop 1			" X:      1*32
		    let loops = loops - 1
		    continue
		elseif loops == 1
		    Xloop 2			" X:		 2*32*32
		    break
		    finish
		endif
		Xloop 4				" X: 4
	    endtry
	finally
	    Xloop 8				" X: 8  + 8*32 + 8*32*32
	endtry
	Xloop 16				" X: 16
	let loops = loops - 1
    endwhile
    Xpath 32768					" X: 32768
finally
    Xpath 65536					" X: 65536
    let loops = 3
    XloopINIT 131072 16
    while loops > 0
	try
	finally
	    try
		if loops == 2
		    Xloop 1			" X: 131072*16
		    let loops = loops - 1
		    XloopNEXT
		    continue
		elseif loops == 1
		    Xloop 2			" X: 131072*2*16*16
		    break
		    finish
		endif
	    endtry
	    Xloop 4				" X: 131072*4
	endtry
	Xloop 8					" X: 131072*8
	let loops = loops - 1
	XloopNEXT
    endwhile
    Xpath 536870912				" X: 536870912
endtry
Xpath 1073741824				" X: 1073741824

unlet loops

Xcheck 1681500476


"-------------------------------------------------------------------------------
" Test 27:  Executing :finally clauses after :return			    {{{1
"
"	    For a :return command dynamically enclosed in a :try/:endtry region,
"	    :finally clauses are executed and the called function is ended.
"-------------------------------------------------------------------------------

XpathINIT

function! F()
    try
	Xpath 1					" X: 1
	try
	    Xpath 2				" X: 2
	    return
	    Xpath 4				" X: 0
	finally
	    Xpath 8				" X: 8
	endtry
	Xpath 16				" X: 0
    finally
	Xpath 32				" X: 32
    endtry
    Xpath 64					" X: 0
endfunction

function! G()
    try
	Xpath 128				" X: 128
	return
	Xpath 256				" X: 0
    finally
	Xpath 512				" X: 512
	call F()
	Xpath 1024				" X: 1024
    endtry
    Xpath 2048					" X: 0
endfunction

function! H()
    try
	Xpath 4096				" X: 4096
	call G()
	Xpath 8192				" X: 8192
    finally
	Xpath 16384				" X: 16384
	return
	Xpath 32768				" X: 0
    endtry
    Xpath 65536					" X: 0
endfunction

try
    Xpath 131072				" X: 131072
    call H()
    Xpath 262144				" X: 262144
finally
    Xpath 524288				" X: 524288
endtry
Xpath 1048576					" X: 1048576

Xcheck 1996459

" Leave F, G, and H for execution as scripts in the next test.


"-------------------------------------------------------------------------------
" Test 28:  Executing :finally clauses after :finish			    {{{1
"
"	    For a :finish command dynamically enclosed in a :try/:endtry region,
"	    :finally clauses are executed and the sourced file is finished.
"
"	    This test executes the bodies of the functions F, G, and H from the
"	    previous test as script files (:return replaced by :finish).
"-------------------------------------------------------------------------------

XpathINIT

let scriptF = MakeScript("F")			" X: 1 + 2 + 8 + 32
let scriptG = MakeScript("G", scriptF)		" X: 128 + 512 + 1024
let scriptH = MakeScript("H", scriptG)		" X: 4096 + 8192 + 16384

try
    Xpath 131072				" X: 131072
    exec "source" scriptH
    Xpath 262144				" X: 262144
finally
    Xpath 524288				" X: 524288
endtry
Xpath 1048576					" X: 1048576

call delete(scriptF)
call delete(scriptG)
call delete(scriptH)
unlet scriptF scriptG scriptH
delfunction F
delfunction G
delfunction H

Xcheck 1996459


"-------------------------------------------------------------------------------
" Test 29:  Executing :finally clauses on errors			    {{{1
"
"	    After an error in a command dynamically enclosed in a :try/:endtry
"	    region, :finally clauses are executed and the script processing is
"	    terminated.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    function! F()
	while 1
	    try
		Xpath 1				" X: 1
		while 1
		    try
			Xpath 2			" X: 2
			asdf	    " error
			Xpath 4			" X: 0
		    finally
			Xpath 8			" X: 8
		    endtry | Xpath 16		" X: 0
		    Xpath 32			" X: 0
		    break
		endwhile
		Xpath 64			" X: 0
	    finally
		Xpath 128			" X: 128
	    endtry | Xpath 256			" X: 0
	    Xpath 512				" X: 0
	    break
	endwhile
	Xpath 1024				" X: 0
    endfunction

    while 1
	try
	    Xpath 2048				" X: 2048
	    while 1
		call F()
		Xpath 4096			" X: 0
		break
	    endwhile  | Xpath 8192		" X: 0
	    Xpath 16384				" X: 0
	finally
	    Xpath 32768				" X: 32768
	endtry | Xpath 65536			" X: 0
    endwhile | Xpath 131072			" X: 0
    Xpath 262144				" X: 0
endif

if ExtraVim()
    function! G() abort
	if 1
	    try
		Xpath 524288			" X: 524288
		asdf	    " error
		Xpath 1048576			" X: 0
	    finally
		Xpath 2097152			" X: 2097152
	    endtry | Xpath 4194304		" X: 0
	endif | Xpath 8388608			" X: 0
	Xpath 16777216				" X: 0
    endfunction

    if 1
	try
	    Xpath 33554432			" X: 33554432
	    call G()
	    Xpath 67108864			" X: 0
	finally
	    Xpath 134217728			" X: 134217728
	endtry | Xpath 268435456		" X: 0
    endif | Xpath 536870912			" X: 0
    Xpath 1073741824				" X: 0
endif

Xcheck 170428555


"-------------------------------------------------------------------------------
" Test 30:  Executing :finally clauses on interrupt			    {{{1
"
"	    After an interrupt in a command dynamically enclosed in
"	    a :try/:endtry region, :finally clauses are executed and the
"	    script processing is terminated.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    XloopINIT 1 16

    function! F()
	try
	    Xloop 1				" X: 1 + 1*16
	    "INTERRUPT
	    Xloop 2				" X: 0
	finally
	    Xloop 4				" X: 4 + 4*16
	endtry
	Xloop 8					" X: 0
    endfunction

    try
	Xpath 256				" X: 256
	try
	    Xpath 512				" X: 512
	    "INTERRUPT
	    Xpath 1024				" X: 0
	finally
	    Xpath 2048				" X: 2048
	    try
		Xpath 4096			" X: 4096
		try
		    Xpath 8192			" X: 8192
		finally
		    Xpath 16384			" X: 16384
		    try
			Xpath 32768		" X: 32768
			"INTERRUPT
			Xpath 65536		" X: 0
		    endtry
		    Xpath 131072		" X: 0
		endtry
		Xpath 262144			" X: 0
	    endtry
	    Xpath 524288			" X: 0
	endtry
	Xpath 1048576				" X: 0
    finally
	Xpath 2097152				" X: 2097152
	try
	    Xpath 4194304			" X: 4194304
	    call F()
	    Xpath 8388608			" X: 0
	finally
	    Xpath 16777216			" X: 16777216
	    try
		Xpath 33554432			" X: 33554432
		XloopNEXT
		ExecAsScript F
		Xpath 67108864			" X: 0
	    finally
		Xpath 134217728			" X: 134217728
	    endtry
	    Xpath 268435456			" X: 0
	endtry
	Xpath 536870912				" X: 0
    endtry
    Xpath 1073741824				" X: 0
endif

Xcheck 190905173


"-------------------------------------------------------------------------------
" Test 31:  Executing :finally clauses after :throw			    {{{1
"
"	    After a :throw dynamically enclosed in a :try/:endtry region,
"	    :finally clauses are executed and the script processing is
"	    terminated.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    XloopINIT 1 16

    function! F()
	try
	    Xloop 1				" X: 1 + 1*16
	    throw "exception"
	    Xloop 2				" X: 0
	finally
	    Xloop 4				" X: 4 + 4*16
	endtry
	Xloop 8					" X: 0
    endfunction

    try
	Xpath 256				" X: 256
	try
	    Xpath 512				" X: 512
	    throw "exception"
	    Xpath 1024				" X: 0
	finally
	    Xpath 2048				" X: 2048
	    try
		Xpath 4096			" X: 4096
		try
		    Xpath 8192			" X: 8192
		finally
		    Xpath 16384			" X: 16384
		    try
			Xpath 32768		" X: 32768
			throw "exception"
			Xpath 65536		" X: 0
		    endtry
		    Xpath 131072		" X: 0
		endtry
		Xpath 262144			" X: 0
	    endtry
	    Xpath 524288			" X: 0
	endtry
	Xpath 1048576				" X: 0
    finally
	Xpath 2097152				" X: 2097152
	try
	    Xpath 4194304			" X: 4194304
	    call F()
	    Xpath 8388608			" X: 0
	finally
	    Xpath 16777216			" X: 16777216
	    try
		Xpath 33554432			" X: 33554432
		XloopNEXT
		ExecAsScript F
		Xpath 67108864			" X: 0
	    finally
		Xpath 134217728			" X: 134217728
	    endtry
	    Xpath 268435456			" X: 0
	endtry
	Xpath 536870912				" X: 0
    endtry
    Xpath 1073741824				" X: 0
endif

Xcheck 190905173


"-------------------------------------------------------------------------------
" Test 32:  Remembering the :return value on :finally			    {{{1
"
"	    If a :finally clause is executed due to a :return specifying
"	    a value, this is the value visible to the caller if not overwritten
"	    by a new :return in the :finally clause.  A :return without a value
"	    in the :finally clause overwrites with value 0.
"-------------------------------------------------------------------------------

XpathINIT

function! F()
    try
	Xpath 1					" X: 1
	try
	    Xpath 2				" X: 2
	    return "ABCD"
	    Xpath 4				" X: 0
	finally
	    Xpath 8				" X: 8
	endtry
	Xpath 16				" X: 0
    finally
	Xpath 32				" X: 32
    endtry
    Xpath 64					" X: 0
endfunction

function! G()
    try
	Xpath 128				" X: 128
	return 8
	Xpath 256				" X: 0
    finally
	Xpath 512				" X: 512
	return 16 + strlen(F())
	Xpath 1024				" X: 0
    endtry
    Xpath 2048					" X: 0
endfunction

function! H()
    try
	Xpath 4096				" X: 4096
	return 32
	Xpath 8192				" X: 0
    finally
	Xpath 16384				" X: 16384
	return
	Xpath 32768				" X: 0
    endtry
    Xpath 65536					" X: 0
endfunction

function! I()
    try
	Xpath 131072				" X: 131072
    finally
	Xpath 262144				" X: 262144
	return G() + H() + 64
	Xpath 524288				" X: 0
    endtry
    Xpath 1048576				" X: 0
endfunction

let retcode = I()
Xpath 2097152					" X: 2097152

if retcode < 0
    Xpath 4194304				" X: 0
endif
if retcode % 4
    Xpath 8388608				" X: 0
endif
if (retcode/4) % 2
    Xpath 16777216				" X: 16777216
endif
if (retcode/8) % 2
    Xpath 33554432				" X: 0
endif
if (retcode/16) % 2
    Xpath 67108864				" X: 67108864
endif
if (retcode/32) % 2
    Xpath 134217728				" X: 0
endif
if (retcode/64) % 2
    Xpath 268435456				" X: 268435456
endif
if retcode/128
    Xpath 536870912				" X: 0
endif

unlet retcode
delfunction F
delfunction G
delfunction H
delfunction I

Xcheck 354833067


"-------------------------------------------------------------------------------
" Test 33:  :return under :execute or user command and :finally		    {{{1
"
"	    A :return command may be executed under an ":execute" or from
"	    a user command.  Executing of :finally clauses and passing through
"	    the return code works also then.
"-------------------------------------------------------------------------------
XpathINIT

command! -nargs=? RETURN
    \ try | return <args> | finally | return <args> * 2 | endtry

function! F()
    try
	RETURN 8
	Xpath 1					" X: 0
    finally
	Xpath 2					" X: 2
    endtry
    Xpath 4					" X: 0
endfunction

function! G()
    try
	RETURN 32
	Xpath 8					" X: 0
    finally
	Xpath 16				" X: 16
	RETURN 128
	Xpath 32				" X: 0
    endtry
    Xpath 64					" X: 0
endfunction

function! H()
    try
	execute "try | return 512 | finally | return 1024 | endtry"
	Xpath 128				" X: 0
    finally
	Xpath 256				" X: 256
    endtry
    Xpath 512					" X: 0
endfunction

function! I()
    try
	execute "try | return 2048 | finally | return 4096 | endtry"
	Xpath 1024				" X: 0
    finally
	Xpath 2048				" X: 2048
	execute "try | return 8192 | finally | return 16384 | endtry"
	Xpath 4096				" X: 0
    endtry
    Xpath 8192					" X: 0
endfunction

function! J()
    try
	RETURN 32768
	Xpath 16384				" X: 0
    finally
	Xpath 32768				" X: 32768
	return
	Xpath 65536				" X: 0
    endtry
    Xpath 131072				" X: 0
endfunction

function! K()
    try
	execute "try | return 131072 | finally | return 262144 | endtry"
	Xpath 262144				" X: 0
    finally
	Xpath 524288				" X: 524288
	execute "try | return 524288 | finally | return | endtry"
	Xpath 1048576				" X: 0
    endtry
    Xpath 2097152				" X: 0
endfunction

function! L()
    try
	return
	Xpath 4194304				" X: 0
    finally
	Xpath 8388608				" X: 8388608
	RETURN 1048576
	Xpath 16777216				" X: 0
    endtry
    Xpath 33554432				" X: 0
endfunction

function! M()
    try
	return
	Xpath 67108864				" X: 0
    finally
	Xpath 134217728				" X: 134217728
	execute "try | return 4194304 | finally | return 8388608 | endtry"
	Xpath 268435456				" X: 0
    endtry
    Xpath 536870912				" X: 0
endfunction

function! N()
    RETURN 16777216
endfunction

function! O()
    execute "try | return 67108864 | finally | return 134217728 | endtry"
endfunction

let sum	     = F() + G() + H()  + I()   + J() + K() + L()     + M()
let expected = 16  + 256 + 1024 + 16384 + 0   + 0   + 2097152 + 8388608
let sum	     = sum      + N()      + O()
let expected = expected + 33554432 + 134217728

if sum == expected
    Xout "sum = " . sum . " (ok)"
else
    Xout "sum = " . sum . ", expected: " . expected
endif

Xpath 1073741824				" X: 1073741824

if sum != expected
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
endif

unlet sum expected
delfunction F
delfunction G
delfunction H
delfunction I
delfunction J
delfunction K
delfunction L
delfunction M
delfunction N
delfunction O

Xcheck 1216907538


"-------------------------------------------------------------------------------
" Test 34:  :finally reason discarded by :continue			    {{{1
"
"	    When a :finally clause is executed due to a :continue, :break,
"	    :return, :finish, error, interrupt or :throw, the jump reason is
"	    discarded by a :continue in the finally clause.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    XloopINIT! 1 8

    function! C(jump)
	XloopNEXT
	let loop = 0
	while loop < 2
	    let loop = loop + 1
	    if loop == 1
		try
		    if a:jump == "continue"
			continue
		    elseif a:jump == "break"
			break
		    elseif a:jump == "return" || a:jump == "finish"
			return
		    elseif a:jump == "error"
			asdf
		    elseif a:jump == "interrupt"
			"INTERRUPT
			let dummy = 0
		    elseif a:jump == "throw"
			throw "abc"
		    endif
		finally
		    continue	" discards jump that caused the :finally
		    Xloop 1		" X: 0
		endtry
		Xloop 2			" X: 0
	    elseif loop == 2
		Xloop 4			" X: 4*(1+8+64+512+4096+32768+262144)
	    endif
	endwhile
    endfunction

    call C("continue")
    Xpath 2097152				" X: 2097152
    call C("break")
    Xpath 4194304				" X: 4194304
    call C("return")
    Xpath 8388608				" X: 8388608
    let g:jump = "finish"
    ExecAsScript C
    unlet g:jump
    Xpath 16777216				" X: 16777216
    try
	call C("error")
	Xpath 33554432				" X: 33554432
    finally
	Xpath 67108864				" X: 67108864
	try
	    call C("interrupt")
	    Xpath 134217728			" X: 134217728
	finally
	    Xpath 268435456			" X: 268435456
	    call C("throw")
	    Xpath 536870912			" X: 536870912
	endtry
    endtry
    Xpath 1073741824				" X: 1073741824

    delfunction C

endif

Xcheck 2146584868


"-------------------------------------------------------------------------------
" Test 35:  :finally reason discarded by :break				    {{{1
"
"	    When a :finally clause is executed due to a :continue, :break,
"	    :return, :finish, error, interrupt or :throw, the jump reason is
"	    discarded by a :break in the finally clause.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    XloopINIT! 1 8

    function! B(jump)
	XloopNEXT
	let loop = 0
	while loop < 2
	    let loop = loop + 1
	    if loop == 1
		try
		    if a:jump == "continue"
			continue
		    elseif a:jump == "break"
			break
		    elseif a:jump == "return" || a:jump == "finish"
			return
		    elseif a:jump == "error"
			asdf
		    elseif a:jump == "interrupt"
			"INTERRUPT
			let dummy = 0
		    elseif a:jump == "throw"
			throw "abc"
		    endif
		finally
		    break	" discards jump that caused the :finally
		    Xloop 1		" X: 0
		endtry
	    elseif loop == 2
		Xloop 2			" X: 0
	    endif
	endwhile
	Xloop 4				" X: 4*(1+8+64+512+4096+32768+262144)
    endfunction

    call B("continue")
    Xpath 2097152				" X: 2097152
    call B("break")
    Xpath 4194304				" X: 4194304
    call B("return")
    Xpath 8388608				" X: 8388608
    let g:jump = "finish"
    ExecAsScript B
    unlet g:jump
    Xpath 16777216				" X: 16777216
    try
	call B("error")
	Xpath 33554432				" X: 33554432
    finally
	Xpath 67108864				" X: 67108864
	try
	    call B("interrupt")
	    Xpath 134217728			" X: 134217728
	finally
	    Xpath 268435456			" X: 268435456
	    call B("throw")
	    Xpath 536870912			" X: 536870912
	endtry
    endtry
    Xpath 1073741824				" X: 1073741824

    delfunction B

endif

Xcheck 2146584868


"-------------------------------------------------------------------------------
" Test 36:  :finally reason discarded by :return			    {{{1
"
"	    When a :finally clause is executed due to a :continue, :break,
"	    :return, :finish, error, interrupt or :throw, the jump reason is
"	    discarded by a :return in the finally clause.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    XloopINIT! 1 8

    function! R(jump, retval) abort
	XloopNEXT
	let loop = 0
	while loop < 2
	    let loop = loop + 1
	    if loop == 1
		try
		    if a:jump == "continue"
			continue
		    elseif a:jump == "break"
			break
		    elseif a:jump == "return"
			return
		    elseif a:jump == "error"
			asdf
		    elseif a:jump == "interrupt"
			"INTERRUPT
			let dummy = 0
		    elseif a:jump == "throw"
			throw "abc"
		    endif
		finally
		    return a:retval	" discards jump that caused the :finally
		    Xloop 1			" X: 0
		endtry
	    elseif loop == 2
		Xloop 2				" X: 0
	    endif
	endwhile
	Xloop 4					" X: 0
    endfunction

    let sum =  -R("continue", -8)
    Xpath 2097152				" X: 2097152
    let sum = sum - R("break", -16)
    Xpath 4194304				" X: 4194304
    let sum = sum - R("return", -32)
    Xpath 8388608				" X: 8388608
    try
	let sum = sum - R("error", -64)
	Xpath 16777216				" X: 16777216
    finally
	Xpath 33554432				" X: 33554432
	try
	    let sum = sum - R("interrupt", -128)
	    Xpath 67108864			" X: 67108864
	finally
	    Xpath 134217728			" X: 134217728
	    let sum = sum - R("throw", -256)
	    Xpath 268435456			" X: 268435456
	endtry
    endtry
    Xpath 536870912				" X: 536870912

    let expected = 8 + 16 + 32 + 64 + 128 + 256
    if sum != expected
	Xpath 1073741824			" X: 0
	Xout "sum =" . sum . ", expected: " . expected
    endif

    unlet sum expected
    delfunction R

endif

Xcheck 1071644672


"-------------------------------------------------------------------------------
" Test 37:  :finally reason discarded by :finish			    {{{1
"
"	    When a :finally clause is executed due to a :continue, :break,
"	    :return, :finish, error, interrupt or :throw, the jump reason is
"	    discarded by a :finish in the finally clause.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    XloopINIT! 1 8

    function! F(jump)	" not executed as function, transformed to a script
	XloopNEXT
	let loop = 0
	while loop < 2
	    let loop = loop + 1
	    if loop == 1
		try
		    if a:jump == "continue"
			continue
		    elseif a:jump == "break"
			break
		    elseif a:jump == "finish"
			finish
		    elseif a:jump == "error"
			asdf
		    elseif a:jump == "interrupt"
			"INTERRUPT
			let dummy = 0
		    elseif a:jump == "throw"
			throw "abc"
		    endif
		finally
		    finish	" discards jump that caused the :finally
		    Xloop 1			" X: 0
		endtry
	    elseif loop == 2
		Xloop 2				" X: 0
	    endif
	endwhile
	Xloop 4					" X: 0
    endfunction

    let scriptF = MakeScript("F")
    delfunction F

    let g:jump = "continue"
    exec "source" scriptF
    Xpath 2097152				" X: 2097152
    let g:jump = "break"
    exec "source" scriptF
    Xpath 4194304				" X: 4194304
    let g:jump = "finish"
    exec "source" scriptF
    Xpath 8388608				" X: 8388608
    try
	let g:jump = "error"
	exec "source" scriptF
	Xpath 16777216				" X: 16777216
    finally
	Xpath 33554432				" X: 33554432
	try
	    let g:jump = "interrupt"
	    exec "source" scriptF
	    Xpath 67108864			" X: 67108864
	finally
	    Xpath 134217728			" X: 134217728
	    try
		let g:jump = "throw"
		exec "source" scriptF
		Xpath 268435456			" X: 268435456
	    finally
		Xpath 536870912			" X: 536870912
	    endtry
	endtry
    endtry
    unlet g:jump

    call delete(scriptF)
    unlet scriptF

endif

Xcheck 1071644672


"-------------------------------------------------------------------------------
" Test 38:  :finally reason discarded by an error			    {{{1
"
"	    When a :finally clause is executed due to a :continue, :break,
"	    :return, :finish, error, interrupt or :throw, the jump reason is
"	    discarded by an error in the finally clause.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    XloopINIT! 1 4

    function! E(jump)
	XloopNEXT
	let loop = 0
	while loop < 2
	    let loop = loop + 1
	    if loop == 1
		try
		    if a:jump == "continue"
			continue
		    elseif a:jump == "break"
			break
		    elseif a:jump == "return" || a:jump == "finish"
			return
		    elseif a:jump == "error"
			asdf
		    elseif a:jump == "interrupt"
			"INTERRUPT
			let dummy = 0
		    elseif a:jump == "throw"
			throw "abc"
		    endif
		finally
		    asdf	" error; discards jump that caused the :finally
		endtry
	    elseif loop == 2
		Xloop 1				" X: 0
	    endif
	endwhile
	Xloop 2					" X: 0
    endfunction

    try
	Xpath 16384				" X: 16384
	call E("continue")
	Xpath 32768				" X: 0
    finally
	try
	    Xpath 65536				" X: 65536
	    call E("break")
	    Xpath 131072			" X: 0
	finally
	    try
		Xpath 262144			" X: 262144
		call E("return")
		Xpath 524288			" X: 0
	    finally
		try
		    Xpath 1048576		" X: 1048576
		    let g:jump = "finish"
		    ExecAsScript E
		    Xpath 2097152		" X: 0
		finally
		    unlet g:jump
		    try
			Xpath 4194304		" X: 4194304
			call E("error")
			Xpath 8388608		" X: 0
		    finally
			try
			    Xpath 16777216	" X: 16777216
			    call E("interrupt")
			    Xpath 33554432	" X: 0
			finally
			    try
				Xpath 67108864	" X: 67108864
				call E("throw")
				Xpath 134217728	" X: 0
			    finally
				Xpath 268435456	" X: 268435456
				delfunction E
			    endtry
			endtry
		    endtry
		endtry
	    endtry
	endtry
    endtry
    Xpath 536870912				" X: 0

endif

Xcheck 357908480


"-------------------------------------------------------------------------------
" Test 39:  :finally reason discarded by an interrupt			    {{{1
"
"	    When a :finally clause is executed due to a :continue, :break,
"	    :return, :finish, error, interrupt or :throw, the jump reason is
"	    discarded by an interrupt in the finally clause.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    XloopINIT! 1 4

    function! I(jump)
	XloopNEXT
	let loop = 0
	while loop < 2
	    let loop = loop + 1
	    if loop == 1
		try
		    if a:jump == "continue"
			continue
		    elseif a:jump == "break"
			break
		    elseif a:jump == "return" || a:jump == "finish"
			return
		    elseif a:jump == "error"
			asdf
		    elseif a:jump == "interrupt"
			"INTERRUPT
			let dummy = 0
		    elseif a:jump == "throw"
			throw "abc"
		    endif
		finally
		    "INTERRUPT - discards jump that caused the :finally
		    let dummy = 0
		endtry
	    elseif loop == 2
		Xloop 1				" X: 0
	    endif
	endwhile
	Xloop 2					" X: 0
    endfunction

    try
	Xpath 16384				" X: 16384
	call I("continue")
	Xpath 32768				" X: 0
    finally
	try
	    Xpath 65536				" X: 65536
	    call I("break")
	    Xpath 131072			" X: 0
	finally
	    try
		Xpath 262144			" X: 262144
		call I("return")
		Xpath 524288			" X: 0
	    finally
		try
		    Xpath 1048576		" X: 1048576
		    let g:jump = "finish"
		    ExecAsScript I
		    Xpath 2097152		" X: 0
		finally
		    unlet g:jump
		    try
			Xpath 4194304		" X: 4194304
			call I("error")
			Xpath 8388608		" X: 0
		    finally
			try
			    Xpath 16777216	" X: 16777216
			    call I("interrupt")
			    Xpath 33554432	" X: 0
			finally
			    try
				Xpath 67108864	" X: 67108864
				call I("throw")
				Xpath 134217728	" X: 0
			    finally
				Xpath 268435456	" X: 268435456
				delfunction I
			    endtry
			endtry
		    endtry
		endtry
	    endtry
	endtry
    endtry
    Xpath 536870912				" X: 0

endif

Xcheck 357908480


"-------------------------------------------------------------------------------
" Test 40:  :finally reason discarded by :throw				    {{{1
"
"	    When a :finally clause is executed due to a :continue, :break,
"	    :return, :finish, error, interrupt or :throw, the jump reason is
"	    discarded by a :throw in the finally clause.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    XloopINIT! 1 4

    function! T(jump)
	XloopNEXT
	let loop = 0
	while loop < 2
	    let loop = loop + 1
	    if loop == 1
		try
		    if a:jump == "continue"
			continue
		    elseif a:jump == "break"
			break
		    elseif a:jump == "return" || a:jump == "finish"
			return
		    elseif a:jump == "error"
			asdf
		    elseif a:jump == "interrupt"
			"INTERRUPT
			let dummy = 0
		    elseif a:jump == "throw"
			throw "abc"
		    endif
		finally
		    throw "xyz"	" discards jump that caused the :finally
		endtry
	    elseif loop == 2
		Xloop 1				" X: 0
	    endif
	endwhile
	Xloop 2					" X: 0
    endfunction

    try
	Xpath 16384				" X: 16384
	call T("continue")
	Xpath 32768				" X: 0
    finally
	try
	    Xpath 65536				" X: 65536
	    call T("break")
	    Xpath 131072			" X: 0
	finally
	    try
		Xpath 262144			" X: 262144
		call T("return")
		Xpath 524288			" X: 0
	    finally
		try
		    Xpath 1048576		" X: 1048576
		    let g:jump = "finish"
		    ExecAsScript T
		    Xpath 2097152		" X: 0
		finally
		    unlet g:jump
		    try
			Xpath 4194304		" X: 4194304
			call T("error")
			Xpath 8388608		" X: 0
		    finally
			try
			    Xpath 16777216	" X: 16777216
			    call T("interrupt")
			    Xpath 33554432	" X: 0
			finally
			    try
				Xpath 67108864	" X: 67108864
				call T("throw")
				Xpath 134217728	" X: 0
			    finally
				Xpath 268435456	" X: 268435456
				delfunction T
			    endtry
			endtry
		    endtry
		endtry
	    endtry
	endtry
    endtry
    Xpath 536870912				" X: 0

endif

Xcheck 357908480


"-------------------------------------------------------------------------------
" Test 41:  Skipped :throw finding next command				    {{{1
"
"	    A :throw in an inactive conditional must not hide a following
"	    command.
"-------------------------------------------------------------------------------

XpathINIT

function! F()
    Xpath 1					" X: 1
    if 0 | throw "never" | endif | Xpath 2	" X: 2
    Xpath 4					" X: 4
endfunction

function! G()
    Xpath 8					    " X: 8
    while 0 | throw "never" | endwhile | Xpath 16   " X: 16
    Xpath 32					    " X: 32
endfunction

function H()
    Xpath 64						    " X: 64
    if 0 | try | throw "never" | endtry | endif | Xpath 128 " X: 128
    Xpath 256						    " X: 256
endfunction

Xpath 512					" X: 512

try
    Xpath 1024					" X: 1024
    call F()
    Xpath 2048					" X: 2048
catch /.*/
    Xpath 4096					" X: 0
    Xout v:exception "in" v:throwpoint
endtry

Xpath 8192					" X: 8192

try
    Xpath 16384					" X: 16384
    call G()
    Xpath 32768					" X: 32768
catch /.*/
    Xpath 65536					" X: 0
    Xout v:exception "in" v:throwpoint
endtry

Xpath 131072					" X: 131072

try
    Xpath 262144				" X: 262144
    call H()
    Xpath 524288				" X: 524288
catch /.*/
    Xpath 1048576				" X: 0
    Xout v:exception "in" v:throwpoint
endtry

Xpath 2097152					" X: 2097152

delfunction F
delfunction G
delfunction H

Xcheck 3076095


"-------------------------------------------------------------------------------
" Test 42:  Catching number and string exceptions			    {{{1
"
"	    When a number is thrown, it is converted to a string exception.
"	    Numbers and strings may be caught by specifying a regular exception
"	    as argument to the :catch command.
"-------------------------------------------------------------------------------

XpathINIT

try

    try
	Xpath 1					" X: 1
	throw 4711
	Xpath 2					" X: 0
    catch /4711/
	Xpath 4					" X: 4
    endtry

    try
	Xpath 8					" X: 8
	throw 4711
	Xpath 16				" X: 0
    catch /^4711$/
	Xpath 32				" X: 32
    endtry

    try
	Xpath 64				" X: 64
	throw 4711
	Xpath 128				" X: 0
    catch /\d/
	Xpath 256				" X: 256
    endtry

    try
	Xpath 512				" X: 512
	throw 4711
	Xpath 1024				" X: 0
    catch /^\d\+$/
	Xpath 2048				" X: 2048
    endtry

    try
	Xpath 4096				" X: 4096
	throw "arrgh"
	Xpath 8192				" X: 0
    catch /arrgh/
	Xpath 16384				" X: 16384
    endtry

    try
	Xpath 32768				" X: 32768
	throw "arrgh"
	Xpath 65536				" X: 0
    catch /^arrgh$/
	Xpath 131072				" X: 131072
    endtry

    try
	Xpath 262144				" X: 262144
	throw "arrgh"
	Xpath 524288				" X: 0
    catch /\l/
	Xpath 1048576				" X: 1048576
    endtry

    try
	Xpath 2097152				" X: 2097152
	throw "arrgh"
	Xpath 4194304				" X: 0
    catch /^\l\+$/
	Xpath 8388608				" X: 8388608
    endtry

    try
	try
	    Xpath 16777216			" X: 16777216
	    throw "ARRGH"
	    Xpath 33554432			" X: 0
	catch /^arrgh$/
	    Xpath 67108864			" X: 0
	endtry
    catch /^\carrgh$/
	Xpath 134217728				" X: 134217728
    endtry

    try
	Xpath 268435456				" X: 268435456
	throw ""
	Xpath 536870912				" X: 0
    catch /^$/
	Xpath 1073741824			" X: 1073741824
    endtry

catch /.*/
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
    Xout v:exception "in" v:throwpoint
endtry

Xcheck 1505155949


"-------------------------------------------------------------------------------
" Test 43:  Selecting the correct :catch clause				    {{{1
"
"	    When an exception is thrown and there are multiple :catch clauses,
"	    the first matching one is taken.
"-------------------------------------------------------------------------------

XpathINIT

XloopINIT 1 1024
let loops = 3
while loops > 0
    try
	if loops == 3
	    Xloop 1				" X: 1
	    throw "a"
	    Xloop 2				" X: 0
	elseif loops == 2
	    Xloop 4				" X: 4*1024
	    throw "ab"
	    Xloop 8				" X: 0
	elseif loops == 1
	    Xloop 16				" X: 16*1024*1024
	    throw "abc"
	    Xloop 32				" X: 0
	endif
    catch /abc/
	Xloop 64				" X: 64*1024*1024
    catch /ab/
	Xloop 128				" X: 128*1024
    catch /.*/
	Xloop 256				" X: 256
    catch /a/
	Xloop 512				" X: 0
    endtry

    let loops = loops - 1
    XloopNEXT
endwhile
Xpath 1073741824				" X: 1073741824

unlet loops

Xcheck 1157763329


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

XpathINIT

try
    try
	Xpath 1					" X: 1
	throw ""
    catch /^$/
	Xpath 2					" X: 2
    endtry

    try
	Xpath 4					" X: 4
	throw ""
    catch /.*/
	Xpath 8					" X: 8
    endtry

    try
	Xpath 16				" X: 16
	throw ""
    catch //
	Xpath 32				" X: 32
    endtry

    try
	Xpath 64				" X: 64
	throw ""
    catch
	Xpath 128				" X: 128
    endtry

    try
	Xpath 256				" X: 256
	throw "oops"
    catch /^$/
	Xpath 512				" X: 0
    catch /.*/
	Xpath 1024				" X: 1024
    endtry

    try
	Xpath 2048				" X: 2048
	throw "arrgh"
    catch /^$/
	Xpath 4096				" X: 0
    catch //
	Xpath 8192				" X: 8192
    endtry

    try
	Xpath 16384				" X: 16384
	throw "brrr"
    catch /^$/
	Xpath 32768				" X: 0
    catch
	Xpath 65536				" X: 65536
    endtry

    try | Xpath 131072 | throw "x" | catch /.*/ | Xpath 262144 | endtry
						" X: 131072 + 262144

    try | Xpath 524288 | throw "y" | catch // | Xpath 1048576 | endtry
						" X: 524288 + 1048576

    while 1
	try
	    let caught = 0
	    let v:errmsg = ""
	    " Extra try level:  if ":catch" without arguments below raises
	    " a syntax error because it misinterprets the "Xpath" as a pattern,
	    " let it be caught by the ":catch /.*/" below.
	    try
		try | Xpath 2097152 | throw "z" | catch | Xpath 4194304 | :
		endtry				" X: 2097152 + 4194304
	    endtry
	catch /.*/
	    let caught = 1
	    Xout v:exception "in" v:throwpoint
	finally
	    if $VIMNOERRTHROW && v:errmsg != ""
		Xout v:errmsg
	    endif
	    if caught || $VIMNOERRTHROW && v:errmsg != ""
		Xpath 8388608				" X: 0
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    let cologne = 4711
    try
	try
	    Xpath 16777216			" X: 16777216
	    throw "throw cologne"
	" Next lines catches all and throws 4711:
	catch |throw cologne|
	    Xpath 33554432			" X: 0
	endtry
    catch /4711/
	Xpath 67108864				" X: 67108864
    endtry

    try
	Xpath 134217728				" X: 134217728
	throw "plus"
    catch +plus+
	Xpath 268435456				" X: 268435456
    endtry

    Xpath 536870912				" X: 536870912
catch /.*/
    Xpath 1073741824				" X: 0
    Xout v:exception "in" v:throwpoint
endtry

unlet! caught cologne

Xcheck 1031761407


"-------------------------------------------------------------------------------
" Test 45:  Catching exceptions from nested :try blocks			    {{{1
"
"	    When :try blocks are nested, an exception is caught by the innermost
"	    try conditional that has a matching :catch clause.
"-------------------------------------------------------------------------------

XpathINIT

XloopINIT 1 1024
let loops = 3
while loops > 0
    try
	try
	    try
		try
		    if loops == 3
			Xloop 1			" X: 1
			throw "a"
			Xloop 2			" X: 0
		    elseif loops == 2
			Xloop 4			" X: 4*1024
			throw "ab"
			Xloop 8			" X: 0
		    elseif loops == 1
			Xloop 16		" X: 16*1024*1024
			throw "abc"
			Xloop 32		" X: 0
		    endif
		catch /abc/
		    Xloop 64			" X: 64*1024*1024
		endtry
	    catch /ab/
		Xloop 128			" X: 128*1024
	    endtry
	catch /.*/
	    Xloop 256				" X: 256
	endtry
    catch /a/
	Xloop 512				" X: 0
    endtry

    let loops = loops - 1
    XloopNEXT
endwhile
Xpath 1073741824				" X: 1073741824

unlet loops

Xcheck 1157763329


"-------------------------------------------------------------------------------
" Test 46:  Executing :finally after a :throw in nested :try		    {{{1
"
"	    When an exception is thrown from within nested :try blocks, the
"	    :finally clauses of the non-catching try conditionals should be
"	    executed before the matching :catch of the next surrounding :try
"	    gets the control.  If this also has a :finally clause, it is
"	    executed afterwards.
"-------------------------------------------------------------------------------

XpathINIT

let sum = 0

try
    Xpath 1					" X: 1
    try
	Xpath 2					" X: 2
	try
	    Xpath 4				" X: 4
	    try
		Xpath 8				" X: 8
		throw "ABC"
		Xpath 16			" X: 0
	    catch /xyz/
		Xpath 32			" X: 0
	    finally
		Xpath 64			" X: 64
		if sum != 0
		    Xpath 128			" X: 0
		endif
		let sum = sum + 1
	    endtry
	    Xpath 256				" X: 0
	catch /123/
	    Xpath 512				" X: 0
	catch /321/
	    Xpath 1024				" X: 0
	finally
	    Xpath 2048				" X: 2048
	    if sum != 1
		Xpath 4096			" X: 0
	    endif
	    let sum = sum + 2
	endtry
	Xpath 8192				" X: 0
    finally
	Xpath 16384				" X: 16384
	if sum != 3
	    Xpath 32768				" X: 0
	endif
	let sum = sum + 4
    endtry
    Xpath 65536					" X: 0
catch /ABC/
    Xpath 131072				" X: 131072
    if sum != 7
	Xpath 262144				" X: 0
    endif
    let sum = sum + 8
finally
    Xpath 524288				" X: 524288
    if sum != 15
	Xpath 1048576				" X: 0
    endif
    let sum = sum + 16
endtry
Xpath 65536					" X: 65536
if sum != 31
    Xpath 131072				" X: 0
endif

unlet sum

Xcheck 739407


"-------------------------------------------------------------------------------
" Test 47:  Throwing exceptions from a :catch clause			    {{{1
"
"	    When an exception is thrown from a :catch clause, it should not be
"	    caught by a :catch of the same :try conditional.  After executing
"	    the :finally clause (if present), surrounding try conditionals
"	    should be checked for a matching :catch.
"-------------------------------------------------------------------------------

XpathINIT

Xpath 1						" X: 1
try
    Xpath 2					" X: 2
    try
	Xpath 4					" X: 4
	try
	    Xpath 8				" X: 8
	    throw "x1"
	    Xpath 16				" X: 0
	catch /x1/
	    Xpath 32				" X: 32
	    try
		Xpath 64			" X: 64
		throw "x2"
		Xpath 128			" X: 0
	    catch /x1/
		Xpath 256			" X: 0
	    catch /x2/
		Xpath 512			" X: 512
		try
		    Xpath 1024			" X: 1024
		    throw "x3"
		    Xpath 2048			" X: 0
		catch /x1/
		    Xpath 4096			" X: 0
		catch /x2/
		    Xpath 8192			" X: 0
		finally
		    Xpath 16384			" X: 16384
		endtry
		Xpath 32768			" X: 0
	    catch /x3/
		Xpath 65536			" X: 0
	    endtry
	    Xpath 131072			" X: 0
	catch /x1/
	    Xpath 262144			" X: 0
	catch /x2/
	    Xpath 524288			" X: 0
	catch /x3/
	    Xpath 1048576			" X: 0
	finally
	    Xpath 2097152			" X: 2097152
	endtry
	Xpath 4194304				" X: 0
    catch /x1/
	Xpath 8388608				" X: 0
    catch /x2/
	Xpath 16777216				" X: 0
    catch /x3/
	Xpath 33554432				" X: 33554432
    endtry
    Xpath 67108864				" X: 67108864
catch /.*/
    Xpath 134217728				" X: 0
    Xout v:exception "in" v:throwpoint
endtry
Xpath 268435456					" X: 268435456

Xcheck 371213935


"-------------------------------------------------------------------------------
" Test 48:  Throwing exceptions from a :finally clause			    {{{1
"
"	    When an exception is thrown from a :finally clause, it should not be
"	    caught by a :catch of the same :try conditional.  Surrounding try
"	    conditionals should be checked for a matching :catch.  A previously
"	    thrown exception is discarded.
"-------------------------------------------------------------------------------

XpathINIT

try

    try
	try
	    Xpath 1				" X: 1
	catch /x1/
	    Xpath 2				" X: 0
	finally
	    Xpath 4				" X: 4
	    throw "x1"
	    Xpath 8				" X: 0
	endtry
	Xpath 16				" X: 0
    catch /x1/
	Xpath 32				" X: 32
    endtry
    Xpath 64					" X: 64

    try
	try
	    Xpath 128				" X: 128
	    throw "x2"
	    Xpath 256				" X: 0
	catch /x2/
	    Xpath 512				" X: 512
	catch /x3/
	    Xpath 1024				" X: 0
	finally
	    Xpath 2048				" X: 2048
	    throw "x3"
	    Xpath 4096				" X: 0
	endtry
	Xpath 8192				" X: 0
    catch /x2/
	Xpath 16384				" X: 0
    catch /x3/
	Xpath 32768				" X: 32768
    endtry
    Xpath 65536					" X: 65536

    try
	try
	    try
		Xpath 131072			" X: 131072
		throw "x4"
		Xpath 262144			" X: 0
	    catch /x5/
		Xpath 524288			" X: 0
	    finally
		Xpath 1048576			" X: 1048576
		throw "x5"	" discards "x4"
		Xpath 2097152			" X: 0
	    endtry
	    Xpath 4194304			" X: 0
	catch /x4/
	    Xpath 8388608			" X: 0
	finally
	    Xpath 16777216			" X: 16777216
	endtry
	Xpath 33554432				" X: 0
    catch /x5/
	Xpath 67108864				" X: 67108864
    endtry
    Xpath 134217728				" X: 134217728

catch /.*/
    Xpath 268435456				" X: 0
    Xout v:exception "in" v:throwpoint
endtry
Xpath 536870912					" X: 536870912

Xcheck 756255461


"-------------------------------------------------------------------------------
" Test 49:  Throwing exceptions across functions			    {{{1
"
"	    When an exception is thrown but not caught inside a function, the
"	    caller is checked for a matching :catch clause.
"-------------------------------------------------------------------------------

XpathINIT

function! C()
    try
	Xpath 1					" X: 1
	throw "arrgh"
	Xpath 2					" X: 0
    catch /arrgh/
	Xpath 4					" X: 4
    endtry
    Xpath 8					" X: 8
endfunction

XloopINIT! 16 16

function! T1()
    XloopNEXT
    try
	Xloop 1					" X: 16 + 16*16
	throw "arrgh"
	Xloop 2					" X: 0
    finally
	Xloop 4					" X: 64 + 64*16
    endtry
    Xloop 8					" X: 0
endfunction

function! T2()
    try
	Xpath 4096				" X: 4096
	call T1()
	Xpath 8192				" X: 0
    finally
	Xpath 16384				" X: 16384
    endtry
    Xpath 32768					" X: 0
endfunction

try
    Xpath 65536					" X: 65536
    call C()	" throw and catch
    Xpath 131072				" X: 131072
catch /.*/
    Xpath 262144				" X: 0
    Xout v:exception "in" v:throwpoint
endtry

try
    Xpath 524288				" X: 524288
    call T1()  " throw, one level
    Xpath 1048576				" X: 0
catch /arrgh/
    Xpath 2097152				" X: 2097152
catch /.*/
    Xpath 4194304				" X: 0
    Xout v:exception "in" v:throwpoint
endtry

try
    Xpath 8388608				" X: 8388608
    call T2()	" throw, two levels
    Xpath 16777216				" X: 0
catch /arrgh/
    Xpath 33554432				" X: 33554432
catch /.*/
    Xpath 67108864				" X: 0
    Xout v:exception "in" v:throwpoint
endtry
Xpath 134217728					" X: 134217728

Xcheck 179000669

" Leave C, T1, and T2 for execution as scripts in the next test.


"-------------------------------------------------------------------------------
" Test 50:  Throwing exceptions across script files			    {{{1
"
"	    When an exception is thrown but not caught inside a script file,
"	    the sourcing script or function is checked for a matching :catch
"	    clause.
"
"	    This test executes the bodies of the functions C, T1, and T2 from
"	    the previous test as script files (:return replaced by :finish).
"-------------------------------------------------------------------------------

XpathINIT

let scriptC = MakeScript("C")			" X: 1 + 4 + 8
delfunction C

XloopINIT! 16 16

let scriptT1 = MakeScript("T1")			" X: 16 + 64 + 16*16 + 64*16
delfunction T1

let scriptT2 = MakeScript("T2", scriptT1)	" X: 4096 + 16384
delfunction T2

function! F()
    try
	Xpath 65536				" X: 65536
	exec "source" g:scriptC
	Xpath 131072				" X: 131072
    catch /.*/
	Xpath 262144				" X: 0
	Xout v:exception "in" v:throwpoint
    endtry

    try
	Xpath 524288				" X: 524288
	exec "source" g:scriptT1
	Xpath 1048576				" X: 0
    catch /arrgh/
	Xpath 2097152				" X: 2097152
    catch /.*/
	Xpath 4194304				" X: 0
	Xout v:exception "in" v:throwpoint
    endtry
endfunction

try
    Xpath 8388608				" X: 8388608
    call F()
    Xpath 16777216				" X: 16777216
    exec "source" scriptT2
    Xpath 33554432				" X: 0
catch /arrgh/
    Xpath 67108864				" X: 67108864
catch /.*/
    Xpath 134217728				" X: 0
    Xout v:exception "in" v:throwpoint
endtry
Xpath 268435456					" X: 268435456

call delete(scriptC)
call delete(scriptT1)
call delete(scriptT2)
unlet scriptC scriptT1 scriptT2
delfunction F

Xcheck 363550045


"-------------------------------------------------------------------------------
" Test 51:  Throwing exceptions across :execute and user commands	    {{{1
"
"	    A :throw command may be executed under an ":execute" or from
"	    a user command.
"-------------------------------------------------------------------------------

XpathINIT

command! -nargs=? THROW1    throw <args> | throw 1
command! -nargs=? THROW2    try | throw <args> | endtry | throw 2
command! -nargs=? THROW3    try | throw 3 | catch /3/ | throw <args> | endtry
command! -nargs=? THROW4    try | throw 4 | finally   | throw <args> | endtry

try

    try
	try
	    Xpath 1				" X: 1
	    THROW1 "A"
	catch /A/
	    Xpath 2				" X: 2
	endtry
    catch /1/
	Xpath 4					" X: 0
    endtry

    try
	try
	    Xpath 8				" X: 8
	    THROW2 "B"
	catch /B/
	    Xpath 16				" X: 16
	endtry
    catch /2/
	Xpath 32				" X: 0
    endtry

    try
	try
	    Xpath 64				" X: 64
	    THROW3 "C"
	catch /C/
	    Xpath 128				" X: 128
	endtry
    catch /3/
	Xpath 256				" X: 0
    endtry

    try
	try
	    Xpath 512				" X: 512
	    THROW4 "D"
	catch /D/
	    Xpath 1024				" X: 1024
	endtry
    catch /4/
	Xpath 2048				" X: 0
    endtry

    try
	try
	    Xpath 4096				" X: 4096
	    execute 'throw "E" | throw 5'
	catch /E/
	    Xpath 8192				" X: 8192
	endtry
    catch /5/
	Xpath 16384				" X: 0
    endtry

    try
	try
	    Xpath 32768				" X: 32768
	    execute 'try | throw "F" | endtry | throw 6'
	catch /F/
	    Xpath 65536				" X: 65536
	endtry
    catch /6/
	Xpath 131072				" X: 0
    endtry

    try
	try
	    Xpath 262144			" X: 262144
	    execute'try | throw 7 | catch /7/ | throw "G" | endtry'
	catch /G/
	    Xpath 524288			" X: 524288
	endtry
    catch /7/
	Xpath 1048576				" X: 0
    endtry

    try
	try
	    Xpath 2097152			" X: 2097152
	    execute 'try | throw 8 | finally   | throw "H" | endtry'
	catch /H/
	    Xpath 4194304			" X: 4194304
	endtry
    catch /8/
	Xpath 8388608				" X: 0
    endtry

catch /.*/
    Xpath 16777216				" X: 0
    Xout v:exception "in" v:throwpoint
endtry

Xpath 33554432					" X: 33554432

delcommand THROW1
delcommand THROW2
delcommand THROW3
delcommand THROW4

Xcheck 40744667


"-------------------------------------------------------------------------------
" Test 52:  Uncaught exceptions						    {{{1
"
"	    When an exception is thrown but not caught, an error message is
"	    displayed when the script is terminated.  In case of an interrupt
"	    or error exception, the normal interrupt or error message(s) are
"	    displayed.
"-------------------------------------------------------------------------------

XpathINIT

let msgfile = tempname()

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

if ExtraVim(msgfile)
    Xpath 1					" X: 1
    throw "arrgh"
endif

Xpath 2						" X: 2
if !MESSAGES('E605', "Exception not caught")
    Xpath 4					" X: 0
endif

if ExtraVim(msgfile)
    try
	Xpath 8					" X: 8
	throw "oops"
    catch /arrgh/
	Xpath 16				" X: 0
    endtry
    Xpath 32					" X: 0
endif

Xpath 64					" X: 64
if !MESSAGES('E605', "Exception not caught")
    Xpath 128					" X: 0
endif

if ExtraVim(msgfile)
    function! T()
	throw "brrr"
    endfunction

    try
	Xpath 256				" X: 256
	throw "arrgh"
    catch /.*/
	Xpath 512				" X: 512
	call T()
    endtry
    Xpath 1024					" X: 0
endif

Xpath 2048					" X: 2048
if !MESSAGES('E605', "Exception not caught")
    Xpath 4096					" X: 0
endif

if ExtraVim(msgfile)
    try
	Xpath 8192				" X: 8192
	throw "arrgh"
    finally
	Xpath 16384				" X: 16384
	throw "brrr"
    endtry
    Xpath 32768					" X: 0
endif

Xpath 65536					" X: 65536
if !MESSAGES('E605', "Exception not caught")
    Xpath 131072				" X: 0
endif

if ExtraVim(msgfile)
    try
	Xpath 262144				" X: 262144
	"INTERRUPT
    endtry
    Xpath 524288				" X: 0
endif

Xpath 1048576					" X: 1048576
if !MESSAGES('INT', "Interrupted")
    Xpath 2097152				" X: 0
endif

if ExtraVim(msgfile)
    try
	Xpath 4194304				" X: 4194304
	let x = novar	" error E121/E15; exception: E121
    catch /E15:/	" should not catch
	Xpath 8388608				" X: 0
    endtry
    Xpath 16777216				" X: 0
endif

Xpath 33554432					" X: 33554432
if !MESSAGES('E121', "Undefined variable", 'E15', "Invalid expression")
    Xpath 67108864				" X: 0
endif

if ExtraVim(msgfile)
    try
	Xpath 134217728				" X: 134217728
"	unlet novar #	" error E108/E488; exception: E488
    catch /E108:/	" should not catch
	Xpath 268435456				" X: 0
    endtry
    Xpath 536870912				" X: 0
endif

Xpath 1073741824				" X: 1073741824
if !MESSAGES('E108', "No such variable", 'E488', "Trailing characters")
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
endif

call delete(msgfile)
unlet msgfile

Xcheck 1247112011

" Leave MESSAGES() for the next tests.


"-------------------------------------------------------------------------------
" Test 53:  Nesting errors: :endif/:else/:elseif			    {{{1
"
"	    For nesting errors of :if conditionals the correct error messages
"	    should be given.
"
"	    This test reuses the function MESSAGES() from the previous test.
"	    This functions checks the messages in g:msgfile.
"-------------------------------------------------------------------------------

XpathINIT

let msgfile = tempname()

if ExtraVim(msgfile)
"   endif
endif
if MESSAGES('E580', ":endif without :if")
    Xpath 1					" X: 1
endif

if ExtraVim(msgfile)
"   while 1
"       endif
"   endwhile
endif
if MESSAGES('E580', ":endif without :if")
    Xpath 2					" X: 2
endif

if ExtraVim(msgfile)
"   try
"   finally
"       endif
"   endtry
endif
if MESSAGES('E580', ":endif without :if")
    Xpath 4					" X: 4
endif

if ExtraVim(msgfile)
"   try
"       endif
"   endtry
endif
if MESSAGES('E580', ":endif without :if")
    Xpath 8					" X: 8
endif

if ExtraVim(msgfile)
"   try
"       throw "a"
"   catch /a/
"       endif
"   endtry
endif
if MESSAGES('E580', ":endif without :if")
    Xpath 16					" X: 16
endif

if ExtraVim(msgfile)
"   else
endif
if MESSAGES('E581', ":else without :if")
    Xpath 32					" X: 32
endif

if ExtraVim(msgfile)
"   while 1
"       else
"   endwhile
endif
if MESSAGES('E581', ":else without :if")
    Xpath 64					" X: 64
endif

if ExtraVim(msgfile)
"   try
"   finally
"       else
"   endtry
endif
if MESSAGES('E581', ":else without :if")
    Xpath 128					" X: 128
endif

if ExtraVim(msgfile)
"   try
"       else
"   endtry
endif
if MESSAGES('E581', ":else without :if")
    Xpath 256					" X: 256
endif

if ExtraVim(msgfile)
"   try
"       throw "a"
"   catch /a/
"       else
"   endtry
endif
if MESSAGES('E581', ":else without :if")
    Xpath 512					" X: 512
endif

if ExtraVim(msgfile)
"   elseif
endif
if MESSAGES('E582', ":elseif without :if")
    Xpath 1024					" X: 1024
endif

if ExtraVim(msgfile)
"   while 1
"       elseif
"   endwhile
endif
if MESSAGES('E582', ":elseif without :if")
    Xpath 2048					" X: 2048
endif

if ExtraVim(msgfile)
"   try
"   finally
"       elseif
"   endtry
endif
if MESSAGES('E582', ":elseif without :if")
    Xpath 4096					" X: 4096
endif

if ExtraVim(msgfile)
"   try
"       elseif
"   endtry
endif
if MESSAGES('E582', ":elseif without :if")
    Xpath 8192					" X: 8192
endif

if ExtraVim(msgfile)
"   try
"       throw "a"
"   catch /a/
"       elseif
"   endtry
endif
if MESSAGES('E582', ":elseif without :if")
    Xpath 16384					" X: 16384
endif

if ExtraVim(msgfile)
"   if 1
"   else
"   else
"   endif
endif
if MESSAGES('E583', "multiple :else")
    Xpath 32768					" X: 32768
endif

if ExtraVim(msgfile)
"   if 1
"   else
"   elseif 1
"   endif
endif
if MESSAGES('E584', ":elseif after :else")
    Xpath 65536					" X: 65536
endif

call delete(msgfile)
unlet msgfile

Xcheck 131071

" Leave MESSAGES() for the next test.


"-------------------------------------------------------------------------------
" Test 54:  Nesting errors: :while/:endwhile				    {{{1
"
"	    For nesting errors of :while conditionals the correct error messages
"	    should be given.
"
"	    This test reuses the function MESSAGES() from the previous test.
"	    This functions checks the messages in g:msgfile.
"-------------------------------------------------------------------------------

XpathINIT

let msgfile = tempname()

if ExtraVim(msgfile)
"   endwhile
endif
if MESSAGES('E588', ":endwhile without :while")
    Xpath 1					" X: 1
endif

if ExtraVim(msgfile)
"   if 1
"       endwhile
"   endif
endif
if MESSAGES('E588', ":endwhile without :while")
    Xpath 2					" X: 2
endif

if ExtraVim(msgfile)
"   while 1
"       if 1
"   endwhile
endif
if MESSAGES('E171', "Missing :endif")
    Xpath 4					" X: 4
endif

if ExtraVim(msgfile)
"   try
"   finally
"       endwhile
"   endtry
endif
if MESSAGES('E588', ":endwhile without :while")
    Xpath 8					" X: 8
endif

if ExtraVim(msgfile)
"   while 1
"       try
"       finally
"   endwhile
endif
if MESSAGES('E600', "Missing :endtry")
    Xpath 16					" X: 16
endif

if ExtraVim(msgfile)
"   while 1
"       if 1
"	    try
"	    finally
"   endwhile
endif
if MESSAGES('E600', "Missing :endtry")
    Xpath 32					" X: 32
endif

if ExtraVim(msgfile)
"   while 1
"       try
"       finally
"	    if 1
"   endwhile
endif
if MESSAGES('E171', "Missing :endif")
    Xpath 64					" X: 64
endif

if ExtraVim(msgfile)
"   try
"       endwhile
"   endtry
endif
if MESSAGES('E588', ":endwhile without :while")
    Xpath 128					" X: 128
endif

if ExtraVim(msgfile)
"   while 1
"       try
"	    endwhile
"       endtry
"   endwhile
endif
if MESSAGES('E588', ":endwhile without :while")
    Xpath 256					" X: 256
endif

if ExtraVim(msgfile)
"   try
"       throw "a"
"   catch /a/
"       endwhile
"   endtry
endif
if MESSAGES('E588', ":endwhile without :while")
    Xpath 512					" X: 512
endif

if ExtraVim(msgfile)
"   while 1
"       try
"	    throw "a"
"	catch /a/
"	    endwhile
"       endtry
"   endwhile
endif
if MESSAGES('E588', ":endwhile without :while")
    Xpath 1024					" X: 1024
endif


call delete(msgfile)
unlet msgfile

Xcheck 2047

" Leave MESSAGES() for the next test.


"-------------------------------------------------------------------------------
" Test 55:  Nesting errors: :continue/:break				    {{{1
"
"	    For nesting errors of :continue and :break commands the correct
"	    error messages should be given.
"
"	    This test reuses the function MESSAGES() from the previous test.
"	    This functions checks the messages in g:msgfile.
"-------------------------------------------------------------------------------

XpathINIT

let msgfile = tempname()

if ExtraVim(msgfile)
"   continue
endif
if MESSAGES('E586', ":continue without :while")
    Xpath 1					" X: 1
endif

if ExtraVim(msgfile)
"   if 1
"       continue
"   endif
endif
if MESSAGES('E586', ":continue without :while")
    Xpath 2					" X: 2
endif

if ExtraVim(msgfile)
"   try
"   finally
"       continue
"   endtry
endif
if MESSAGES('E586', ":continue without :while")
    Xpath 4					" X: 4
endif

if ExtraVim(msgfile)
"   try
"       continue
"   endtry
endif
if MESSAGES('E586', ":continue without :while")
    Xpath 8					" X: 8
endif

if ExtraVim(msgfile)
"   try
"       throw "a"
"   catch /a/
"       continue
"   endtry
endif
if MESSAGES('E586', ":continue without :while")
    Xpath 16					" X: 16
endif

if ExtraVim(msgfile)
"   break
endif
if MESSAGES('E587', ":break without :while")
    Xpath 32					" X: 32
endif

if ExtraVim(msgfile)
"   if 1
"       break
"   endif
endif
if MESSAGES('E587', ":break without :while")
    Xpath 64					" X: 64
endif

if ExtraVim(msgfile)
"   try
"   finally
"       break
"   endtry
endif
if MESSAGES('E587', ":break without :while")
    Xpath 128					" X: 128
endif

if ExtraVim(msgfile)
"   try
"       break
"   endtry
endif
if MESSAGES('E587', ":break without :while")
    Xpath 256					" X: 256
endif

if ExtraVim(msgfile)
"   try
"       throw "a"
"   catch /a/
"       break
"   endtry
endif
if MESSAGES('E587', ":break without :while")
    Xpath 512					" X: 512
endif

call delete(msgfile)
unlet msgfile

Xcheck 1023

" Leave MESSAGES() for the next test.


"-------------------------------------------------------------------------------
" Test 56:  Nesting errors: :endtry					    {{{1
"
"	    For nesting errors of :try conditionals the correct error messages
"	    should be given.
"
"	    This test reuses the function MESSAGES() from the previous test.
"	    This functions checks the messages in g:msgfile.
"-------------------------------------------------------------------------------

XpathINIT

let msgfile = tempname()

if ExtraVim(msgfile)
"   endtry
endif
if MESSAGES('E602', ":endtry without :try")
    Xpath 1					" X: 1
endif

if ExtraVim(msgfile)
"   if 1
"       endtry
"   endif
endif
if MESSAGES('E602', ":endtry without :try")
    Xpath 2					" X: 2
endif

if ExtraVim(msgfile)
"   while 1
"       endtry
"   endwhile
endif
if MESSAGES('E602', ":endtry without :try")
    Xpath 4					" X: 4
endif

if ExtraVim(msgfile)
"   try
"       if 1
"   endtry
endif
if MESSAGES('E171', "Missing :endif")
    Xpath 8					" X: 8
endif

if ExtraVim(msgfile)
"   try
"       while 1
"   endtry
endif
if MESSAGES('E170', "Missing :endwhile")
    Xpath 16					" X: 16
endif

if ExtraVim(msgfile)
"   try
"   finally
"       if 1
"   endtry
endif
if MESSAGES('E171', "Missing :endif")
    Xpath 32					" X: 32
endif

if ExtraVim(msgfile)
"   try
"   finally
"       while 1
"   endtry
endif
if MESSAGES('E170', "Missing :endwhile")
    Xpath 64					" X: 64
endif

if ExtraVim(msgfile)
"   try
"       throw "a"
"   catch /a/
"       if 1
"   endtry
endif
if MESSAGES('E171', "Missing :endif")
    Xpath 128					" X: 128
endif

if ExtraVim(msgfile)
"   try
"       throw "a"
"   catch /a/
"       while 1
"   endtry
endif
if MESSAGES('E170', "Missing :endwhile")
    Xpath 256					" X: 256
endif

call delete(msgfile)
unlet msgfile

delfunction MESSAGES

Xcheck 511


"-------------------------------------------------------------------------------
" Test 57:  v:exception and v:throwpoint for user exceptions		    {{{1
"
"	    v:exception evaluates to the value of the exception that was caught
"	    most recently and is not finished.  (A caught exception is finished
"	    when the next ":catch", ":finally", or ":endtry" is reached.)
"	    v:throwpoint evaluates to the script/function name and line number
"	    where that exception has been thrown.
"-------------------------------------------------------------------------------

XpathINIT

function! FuncException()
    let g:exception = v:exception
endfunction

function! FuncThrowpoint()
    let g:throwpoint = v:throwpoint
endfunction

let scriptException  = MakeScript("FuncException")
let scriptThrowPoint = MakeScript("FuncThrowpoint")

command! CmdException  let g:exception  = v:exception
command! CmdThrowpoint let g:throwpoint = v:throwpoint

XloopINIT! 1 2

function! CHECK(n, exception, throwname, throwline)
    XloopNEXT
    let error = 0
    if v:exception != a:exception
	Xout a:n.": v:exception is" v:exception "instead of" a:exception
	let error = 1
    endif
    if v:throwpoint !~ a:throwname
	let name = escape(a:throwname, '\')
	Xout a:n.": v:throwpoint (".v:throwpoint.") does not match" name
	let error = 1
    endif
    if v:throwpoint !~ a:throwline
	let line = escape(a:throwline, '\')
	Xout a:n.": v:throwpoint (".v:throwpoint.") does not match" line
	let error = 1
    endif
    if error
	Xloop 1					" X: 0
    endif
endfunction

function! T(arg, line)
    if a:line == 2
	throw a:arg		" in line 2
    elseif a:line == 4
	throw a:arg		" in line 4
    elseif a:line == 6
	throw a:arg		" in line 6
    elseif a:line == 8
	throw a:arg		" in line 8
    endif
endfunction

function! G(arg, line)
    call T(a:arg, a:line)
endfunction

function! F(arg, line)
    call G(a:arg, a:line)
endfunction

let scriptT = MakeScript("T")
let scriptG = MakeScript("G", scriptT)
let scriptF = MakeScript("F", scriptG)

try
    Xpath 32768					" X: 32768
    call F("oops", 2)
catch /.*/
    Xpath 65536					" X: 65536
    let exception  = v:exception
    let throwpoint = v:throwpoint
    call CHECK(1, "oops", '\<F\[1]\.\.G\[1]\.\.T\>', '\<2\>')
    exec "let exception  = v:exception"
    exec "let throwpoint = v:throwpoint"
    call CHECK(2, "oops", '\<F\[1]\.\.G\[1]\.\.T\>', '\<2\>')
    CmdException
    CmdThrowpoint
    call CHECK(3, "oops", '\<F\[1]\.\.G\[1]\.\.T\>', '\<2\>')
    call FuncException()
    call FuncThrowpoint()
    call CHECK(4, "oops", '\<F\[1]\.\.G\[1]\.\.T\>', '\<2\>')
    exec "source" scriptException
    exec "source" scriptThrowPoint
    call CHECK(5, "oops", '\<F\[1]\.\.G\[1]\.\.T\>', '\<2\>')
    try
	Xpath 131072				" X: 131072
	call G("arrgh", 4)
    catch /.*/
	Xpath 262144				" X: 262144
	let exception  = v:exception
	let throwpoint = v:throwpoint
	call CHECK(6, "arrgh", '\<G\[1]\.\.T\>', '\<4\>')
	try
	    Xpath 524288			" X: 524288
	    let g:arg = "autsch"
	    let g:line = 6
	    exec "source" scriptF
	catch /.*/
	    Xpath 1048576			" X: 1048576
	    let exception  = v:exception
	    let throwpoint = v:throwpoint
	    " Symbolic links in tempname()s are not resolved, whereas resolving
	    " is done for v:throwpoint.  Resolve the temporary file name for
	    " scriptT, so that it can be matched against v:throwpoint.
	    call CHECK(7, "autsch", resolve(scriptT), '\<6\>')
	finally
	    Xpath 2097152			" X: 2097152
	    let exception  = v:exception
	    let throwpoint = v:throwpoint
	    call CHECK(8, "arrgh", '\<G\[1]\.\.T\>', '\<4\>')
	    try
		Xpath 4194304			" X: 4194304
		let g:arg = "brrrr"
		let g:line = 8
		exec "source" scriptG
	    catch /.*/
		Xpath 8388608			" X: 8388608
		let exception  = v:exception
		let throwpoint = v:throwpoint
		" Resolve scriptT for matching it against v:throwpoint.
		call CHECK(9, "brrrr", resolve(scriptT), '\<8\>')
	    finally
		Xpath 16777216			" X: 16777216
		let exception  = v:exception
		let throwpoint = v:throwpoint
		call CHECK(10, "arrgh", '\<G\[1]\.\.T\>', '\<4\>')
	    endtry
	    Xpath 33554432			" X: 33554432
	    let exception  = v:exception
	    let throwpoint = v:throwpoint
	    call CHECK(11, "arrgh", '\<G\[1]\.\.T\>', '\<4\>')
	endtry
	Xpath 67108864				" X: 67108864
	let exception  = v:exception
	let throwpoint = v:throwpoint
	call CHECK(12, "arrgh", '\<G\[1]\.\.T\>', '\<4\>')
    finally
	Xpath 134217728				" X: 134217728
	let exception  = v:exception
	let throwpoint = v:throwpoint
	call CHECK(13, "oops", '\<F\[1]\.\.G\[1]\.\.T\>', '\<2\>')
    endtry
    Xpath 268435456				" X: 268435456
    let exception  = v:exception
    let throwpoint = v:throwpoint
    call CHECK(14, "oops", '\<F\[1]\.\.G\[1]\.\.T\>', '\<2\>')
finally
    Xpath 536870912				" X: 536870912
    let exception  = v:exception
    let throwpoint = v:throwpoint
    call CHECK(15, "", '^$', '^$')
endtry

Xpath 1073741824				" X: 1073741824

unlet exception throwpoint
delfunction FuncException
delfunction FuncThrowpoint
call delete(scriptException)
call delete(scriptThrowPoint)
unlet scriptException scriptThrowPoint
delcommand CmdException
delcommand CmdThrowpoint
delfunction T
delfunction G
delfunction F
call delete(scriptT)
call delete(scriptG)
call delete(scriptF)
unlet scriptT scriptG scriptF

Xcheck 2147450880


"-------------------------------------------------------------------------------
"
" Test 58:  v:exception and v:throwpoint for error/interrupt exceptions	    {{{1
"
"	    v:exception and v:throwpoint work also for error and interrupt
"	    exceptions.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    function! T(line)
	if a:line == 2
	    delfunction T		" error (function in use) in line 2
	elseif a:line == 4
	    let dummy = 0		" INTERRUPT1 - interrupt in line 4
	endif
    endfunction

    while 1
	try
	    Xpath 1				" X: 1
	    let caught = 0
	    call T(2)
	catch /.*/
	    let caught = 1
	    if v:exception !~ 'Vim(delfunction):'
		Xpath 2				" X: 0
	    endif
	    if v:throwpoint !~ '\<T\>'
		Xpath 4				" X: 0
	    endif
	    if v:throwpoint !~ '\<2\>'
		Xpath 8				" X: 0
	    endif
	finally
	    Xpath 16				" X: 16
	    if caught || $VIMNOERRTHROW
		Xpath 32			" X: 32
	    endif
	    if v:exception != ""
		Xpath 64			" X: 0
	    endif
	    if v:throwpoint != ""
		Xpath 128			" X: 0
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    Xpath 256					" X: 256
    if v:exception != ""
	Xpath 512				" X: 0
    endif
    if v:throwpoint != ""
	Xpath 1024				" X: 0
    endif

    while 1
	try
	    Xpath 2048				" X: 2048
	    let caught = 0
	    call T(4)
	catch /.*/
	    let caught = 1
	    if v:exception != 'Vim:Interrupt'
		Xpath 4096			" X: 0
	    endif
	    if v:throwpoint !~ '\<T\>'
		Xpath 8192			" X: 0
	    endif
	    if v:throwpoint !~ '\<4\>'
		Xpath 16384			" X: 0
	    endif
	finally
	    Xpath 32768				" X: 32768
	    if caught || $VIMNOINTTHROW
		Xpath 65536			" X: 65536
	    endif
	    if v:exception != ""
		Xpath 131072			" X: 0
	    endif
	    if v:throwpoint != ""
		Xpath 262144			" X: 0
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    Xpath 524288				" X: 524288
    if v:exception != ""
	Xpath 1048576				" X: 0
    endif
    if v:throwpoint != ""
	Xpath 2097152				" X: 0
    endif

endif

Xcheck 624945


"-------------------------------------------------------------------------------
"
" Test 59:  v:exception and v:throwpoint when discarding exceptions	    {{{1
"
"	    When a :catch clause is left by a ":break" etc or an error or
"	    interrupt exception, v:exception and v:throwpoint are reset.  They
"	    are not affected by an exception that is discarded before being
"	    caught.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    XloopINIT! 1 2

    let sfile = expand("<sfile>")

    function! LineNumber()
	return substitute(substitute(v:throwpoint, g:sfile, '', ""),
	    \ '\D*\(\d*\).*', '\1', "")
    endfunction

    command! -nargs=1 SetLineNumber
	\ try | throw "line" | catch /.*/ | let <args> =  LineNumber() | endtry

    " Check v:exception/v:throwpoint against second/fourth parameter if
    " specified, check for being empty else.
    function! CHECK(n, ...)
	XloopNEXT
	let exception = a:0 != 0 ? a:1 : ""	" second parameter (optional)
	let emsg      = a:0 != 0 ? a:2 : ""	" third parameter (optional)
	let line      = a:0 != 0 ? a:3 : 0	" fourth parameter (optional)
	let error = 0
	if emsg != ""
	    " exception is the error number, emsg the English error message text
	    if exception !~ '^E\d\+$'
		Xout "TODO: Add message number for:" emsg
	    elseif v:lang == "C" || v:lang =~ '^[Ee]n'
		if exception == "E492" && emsg == "Not an editor command"
		    let exception = '^Vim:' . exception . ': ' . emsg
		else
		    let exception = '^Vim(\a\+):' . exception . ': ' . emsg
		endif
	    else
		if exception == "E492"
		    let exception = '^Vim:' . exception
		else
		    let exception = '^Vim(\a\+):' . exception
		endif
	    endif
	endif
	if exception == "" && v:exception != ""
	    Xout a:n.": v:exception is set:" v:exception
	    let error = 1
	elseif exception != "" && v:exception !~ exception
	    Xout a:n.": v:exception (".v:exception.") does not match" exception
	    let error = 1
	endif
	if line == 0 && v:throwpoint != ""
	    Xout a:n.": v:throwpoint is set:" v:throwpoint
	    let error = 1
	elseif line != 0 && v:throwpoint !~ '\<' . line . '\>'
	    Xout a:n.": v:throwpoint (".v:throwpoint.") does not match" line
	    let error = 1
	endif
	if !error
	    Xloop 1				" X: 2097151
	endif
    endfunction

    while 1
	try
	    throw "x1"
	catch /.*/
	    break
	endtry
    endwhile
    call CHECK(1)

    while 1
	try
	    throw "x2"
	catch /.*/
	    break
	finally
	    call CHECK(2)
	endtry
	break
    endwhile
    call CHECK(3)

    while 1
	try
	    let errcaught = 0
	    try
		try
		    throw "x3"
		catch /.*/
		    SetLineNumber line_before_error
		    asdf
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(4, 'E492', "Not an editor command",
		    \ line_before_error + 1)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(4)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(5)

    Xpath 2097152				" X: 2097152

    while 1
	try
	    let intcaught = 0
	    try
		try
		    throw "x4"
		catch /.*/
		    SetLineNumber two_lines_before_interrupt
		    "INTERRUPT
		    let dummy = 0
		endtry
	    catch /.*/
		let intcaught = 1
		call CHECK(6, "Vim:Interrupt", '',
		    \ two_lines_before_interrupt + 2)
	    endtry
	finally
	    if !intcaught && $VIMNOINTTHROW
		call CHECK(6)
	    endif
	    break		" discard interrupt for $VIMNOINTTHROW
	endtry
    endwhile
    call CHECK(7)

    Xpath 4194304				" X: 4194304

    while 1
	try
	    let errcaught = 0
	    try
		try
"		    if 1
			SetLineNumber line_before_throw
			throw "x5"
		    " missing endif
		catch /.*/
		    Xpath 8388608			" X: 0
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(8, 'E171', "Missing :endif", line_before_throw + 3)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(8)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(9)

    Xpath 16777216				" X: 16777216

    try
	while 1
	    try
		throw "x6"
	    finally
		break
	    endtry
	    break
	endwhile
    catch /.*/
	Xpath 33554432				" X: 0
    endtry
    call CHECK(10)

    try
	while 1
	    try
		throw "x7"
	    finally
		break
	    endtry
	    break
	endwhile
    catch /.*/
	Xpath 67108864				" X: 0
    finally
	call CHECK(11)
    endtry
    call CHECK(12)

    while 1
	try
	    let errcaught = 0
	    try
		try
		    throw "x8"
		finally
		    SetLineNumber line_before_error
		    asdf
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(13, 'E492', "Not an editor command",
		    \ line_before_error + 1)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(13)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(14)

    Xpath 134217728				" X: 134217728

    while 1
	try
	    let intcaught = 0
	    try
		try
		    throw "x9"
		finally
		    SetLineNumber two_lines_before_interrupt
		    "INTERRUPT
		endtry
	    catch /.*/
		let intcaught = 1
		call CHECK(15, "Vim:Interrupt", '',
		    \ two_lines_before_interrupt + 2)
	    endtry
	finally
	    if !intcaught && $VIMNOINTTHROW
		call CHECK(15)
	    endif
	    break		" discard interrupt for $VIMNOINTTHROW
	endtry
    endwhile
    call CHECK(16)

    Xpath 268435456				" X: 268435456

    while 1
	try
	    let errcaught = 0
	    try
		try
"		    if 1
			SetLineNumber line_before_throw
			throw "x10"
		    " missing endif
		finally
		    call CHECK(17)
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(18, 'E171', "Missing :endif", line_before_throw + 3)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(18)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(19)

    Xpath 536870912				" X: 536870912

    while 1
	try
	    let errcaught = 0
	    try
		try
"		    if 1
			SetLineNumber line_before_throw
			throw "x11"
		    " missing endif
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(20, 'E171', "Missing :endif", line_before_throw + 3)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(20)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(21)

    Xpath 1073741824				" X: 1073741824

endif

Xcheck 2038431743


"-------------------------------------------------------------------------------
"
" Test 60:  (Re)throwing v:exception; :echoerr.				    {{{1
"
"	    A user exception can be rethrown after catching by throwing
"	    v:exception.  An error or interrupt exception cannot be rethrown
"	    because Vim exceptions cannot be faked.  A Vim exception using the
"	    value of v:exception can, however, be triggered by the :echoerr
"	    command.
"-------------------------------------------------------------------------------

XpathINIT

try
    try
	Xpath 1					" X: 1
	throw "oops"
    catch /oops/
	Xpath 2					" X: 2
	throw v:exception	" rethrow user exception
    catch /.*/
	Xpath 4					" X: 0
    endtry
catch /^oops$/			" catches rethrown user exception
    Xpath 8					" X: 8
catch /.*/
    Xpath 16					" X: 0
endtry

function! F()
    try
	let caught = 0
	try
	    Xpath 32				" X: 32
	    write /n/o/n/w/r/i/t/a/b/l/e/_/f/i/l/e
	    Xpath 64				" X: 0
	    Xout "did_emsg was reset before executing " .
		\ "BufWritePost autocommands."
	catch /^Vim(write):/
	    let caught = 1
	    throw v:exception	" throw error: cannot fake Vim exception
	catch /.*/
	    Xpath 128				" X: 0
	finally
	    Xpath 256				" X: 256
	    if !caught && !$VIMNOERRTHROW
		Xpath 512			" X: 0
	    endif
	endtry
    catch /^Vim(throw):/	" catches throw error
	let caught = caught + 1
    catch /.*/
	Xpath 1024				" X: 0
    finally
	Xpath 2048				" X: 2048
	if caught != 2
	    if !caught && !$VIMNOERRTHROW
		Xpath 4096			" X: 0
	    elseif caught
		Xpath 8192			" X: 0
	    endif
	    return		| " discard error for $VIMNOERRTHROW
	endif
    endtry
endfunction

call F()
delfunction F

function! G()
    try
	let caught = 0
	try
	    Xpath 16384				" X: 16384
	    asdf
	catch /^Vim/		" catch error exception
	    let caught = 1
	    " Trigger Vim error exception with value specified after :echoerr
	    let value = substitute(v:exception, '^Vim\((.*)\)\=:', '', "")
	    echoerr value
	catch /.*/
	    Xpath 32768				" X: 0
	finally
	    Xpath 65536				" X: 65536
	    if !caught
		if !$VIMNOERRTHROW
		    Xpath 131072		" X: 0
		else
		    let value = "Error"
		    echoerr value
		endif
	    endif
	endtry
    catch /^Vim(echoerr):/
	let caught = caught + 1
	if v:exception !~ value
	    Xpath 262144			" X: 0
	endif
    catch /.*/
	Xpath 524288				" X: 0
    finally
	Xpath 1048576				" X: 1048576
	if caught != 2
	    if !caught && !$VIMNOERRTHROW
		Xpath 2097152			" X: 0
	    elseif caught
		Xpath 4194304			" X: 0
	    endif
	    return		| " discard error for $VIMNOERRTHROW
	endif
    endtry
endfunction

call G()
delfunction G

unlet! value caught

if ExtraVim()
    try
	let errcaught = 0
	try
	    Xpath 8388608			" X: 8388608
	    let intcaught = 0
	    "INTERRUPT
	catch /^Vim:/		" catch interrupt exception
	    let intcaught = 1
	    " Trigger Vim error exception with value specified after :echoerr
	    echoerr substitute(v:exception, '^Vim\((.*)\)\=:', '', "")
	catch /.*/
	    Xpath 16777216			" X: 0
	finally
	    Xpath 33554432			" X: 33554432
	    if !intcaught
		if !$VIMNOINTTHROW
		    Xpath 67108864		" X: 0
		else
		    echoerr "Interrupt"
		endif
	    endif
	endtry
    catch /^Vim(echoerr):/
	let errcaught = 1
	if v:exception !~ "Interrupt"
	    Xpath 134217728			" X: 0
	endif
    finally
	Xpath 268435456				" X: 268435456
	if !errcaught && !$VIMNOERRTHROW
	    Xpath 536870912			" X: 0
	endif
    endtry
endif

Xcheck 311511339


"-------------------------------------------------------------------------------
" Test 61:  Catching interrupt exceptions				    {{{1
"
"	    When an interrupt occurs inside a :try/:endtry region, an
"	    interrupt exception is thrown and can be caught.  Its value is
"	    "Vim:Interrupt".  If the interrupt occurs after an error or a :throw
"	    but before a matching :catch is reached, all following :catches of
"	    that try block are ignored, but the interrupt exception can be
"	    caught by the next surrounding try conditional.  An interrupt is
"	    ignored when there is a previous interrupt that has not been caught
"	    or causes a :finally clause to be executed.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    while 1
	try
	    try
		Xpath 1				" X: 1
		let caught = 0
		"INTERRUPT
		Xpath 2				" X: 0
	    catch /^Vim:Interrupt$/
		let caught = 1
	    finally
		Xpath 4				" X: 4
		if caught || $VIMNOINTTHROW
		    Xpath 8			" X: 8
		endif
	    endtry
	catch /.*/
	    Xpath 16				" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard interrupt for $VIMNOINTTHROW
	endtry
    endwhile

    while 1
	try
	    try
		let caught = 0
		try
		    Xpath 32			" X: 32
		    asdf
		    Xpath 64			" X: 0
		catch /do_not_catch/
		    Xpath 128			" X: 0
		catch /.*/	"INTERRUPT - throw interrupt if !$VIMNOERRTHROW
		    Xpath 256			" X: 0
		catch /.*/
		    Xpath 512			" X: 0
		finally		"INTERRUPT - throw interrupt if $VIMNOERRTHROW
		    Xpath 1024			" X: 1024
		endtry
	    catch /^Vim:Interrupt$/
		let caught = 1
	    finally
		Xpath 2048			" X: 2048
		if caught || $VIMNOINTTHROW
		    Xpath 4096			" X: 4096
		endif
	    endtry
	catch /.*/
	    Xpath 8192				" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard interrupt for $VIMNOINTTHROW
	endtry
    endwhile

    while 1
	try
	    try
		let caught = 0
		try
		    Xpath 16384			" X: 16384
		    throw "x"
		    Xpath 32768			" X: 0
		catch /do_not_catch/
		    Xpath 65536			" X: 0
		catch /x/	"INTERRUPT
		    Xpath 131072		" X: 0
		catch /.*/
		    Xpath 262144		" X: 0
		endtry
	    catch /^Vim:Interrupt$/
		let caught = 1
	    finally
		Xpath 524288			" X: 524288
		if caught || $VIMNOINTTHROW
		    Xpath 1048576		" X: 1048576
		endif
	    endtry
	catch /.*/
	    Xpath 2097152			" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard interrupt for $VIMNOINTTHROW
	endtry
    endwhile

    while 1
	try
	    let caught = 0
	    try
		Xpath 4194304			" X: 4194304
		"INTERRUPT
		Xpath 8388608			" X: 0
	    catch /do_not_catch/ "INTERRUPT
		Xpath 16777216			" X: 0
	    catch /^Vim:Interrupt$/
		let caught = 1
	    finally
		Xpath 33554432			" X: 33554432
		if caught || $VIMNOINTTHROW
		    Xpath 67108864		" X: 67108864
		endif
	    endtry
	catch /.*/
	    Xpath 134217728			" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard interrupt for $VIMNOINTTHROW
	endtry
    endwhile

    Xpath 268435456				" X: 268435456

endif

Xcheck 374889517


"-------------------------------------------------------------------------------
" Test 62:  Catching error exceptions					    {{{1
"
"	    An error inside a :try/:endtry region is converted to an exception
"	    and can be caught.  The error exception has a "Vim(cmdname):" prefix
"	    where cmdname is the name of the failing command, or a "Vim:" prefix
"	    if no command name is known.  The "Vim" prefixes cannot be faked.
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

while 1
    try
	try
	    let caught = 0
	    unlet novar
	catch /^Vim(unlet):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(unlet):', '', "")
	finally
	    Xpath 1				" X: 1
	    if !caught && !$VIMNOERRTHROW
		Xpath 2				" X: 0
	    endif
	    if !MSG('E108', "No such variable")
		Xpath 4				" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 8					" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let caught = 0
	    throw novar			" error in :throw
	catch /^Vim(throw):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(throw):', '', "")
	finally
	    Xpath 16				" X: 16
	    if !caught && !$VIMNOERRTHROW
		Xpath 32			" X: 0
	    endif
	    if caught ? !MSG('E121', "Undefined variable")
			\ : !MSG('E15', "Invalid expression")
		Xpath 64			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 128				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let caught = 0
	    throw "Vim:faked"		" error: cannot fake Vim exception
	catch /^Vim(throw):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(throw):', '', "")
	finally
	    Xpath 256				" X: 256
	    if !caught && !$VIMNOERRTHROW
		Xpath 512			" X: 0
	    endif
	    if !MSG('E608', "Cannot :throw exceptions with 'Vim' prefix")
		Xpath 1024			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 2048				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

function! F()
    while 1
    " Missing :endwhile
endfunction

while 1
    try
	try
	    let caught = 0
	    call F()
	catch /^Vim(endfunction):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(endfunction):', '', "")
	finally
	    Xpath 4096				" X: 4096
	    if !caught && !$VIMNOERRTHROW
		Xpath 8192			" X: 0
	    endif
	    if !MSG('E170', "Missing :endwhile")
		Xpath 16384			" X: 0
	    endif
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
	try
	    let caught = 0
	    ExecAsScript F
	catch /^Vim:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim:', '', "")
	finally
	    Xpath 65536				" X: 65536
	    if !caught && !$VIMNOERRTHROW
		Xpath 131072			" X: 0
	    endif
	    if !MSG('E170', "Missing :endwhile")
		Xpath 262144			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 524288				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

function! G()
    call G()
endfunction

while 1
    try
	let mfd_save = &mfd
	set mfd=3
	try
	    let caught = 0
	    call G()
	catch /^Vim(call):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(call):', '', "")
	finally
	    Xpath 1048576			" X: 1048576
	    if !caught && !$VIMNOERRTHROW
		Xpath 2097152			" X: 0
	    endif
	    if !MSG('E132', "Function call depth is higher than 'maxfuncdepth'")
		Xpath 4194304			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 8388608				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	let &mfd = mfd_save
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

function! H()
    return H()
endfunction

while 1
    try
	let mfd_save = &mfd
	set mfd=3
	try
	    let caught = 0
	    call H()
	catch /^Vim(return):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(return):', '', "")
	finally
	    Xpath 16777216			" X: 16777216
	    if !caught && !$VIMNOERRTHROW
		Xpath 33554432			" X: 0
	    endif
	    if !MSG('E132', "Function call depth is higher than 'maxfuncdepth'")
		Xpath 67108864			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 134217728				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	let &mfd = mfd_save
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

unlet! caught mfd_save
delfunction F
delfunction G
delfunction H
Xpath 268435456					" X: 268435456

Xcheck 286331153

" Leave MSG() for the next test.


"-------------------------------------------------------------------------------
" Test 63:  Suppressing error exceptions by :silent!.			    {{{1
"
"	    A :silent! command inside a :try/:endtry region suppresses the
"	    conversion of errors to an exception and the immediate abortion on
"	    error.  When the commands executed by the :silent! themselves open
"	    a new :try/:endtry region, conversion of errors to exception and
"	    immediate abortion is switched on again - until the next :silent!
"	    etc.  The :silent! has the effect of setting v:errmsg to the error
"	    message text (without displaying it) and continuing with the next
"	    script line.
"
"	    When a command triggering autocommands is executed by :silent!
"	    inside a :try/:endtry, the autocommand execution is not suppressed
"	    on error.
"
"	    This test reuses the function MSG() from the previous test.
"-------------------------------------------------------------------------------

XpathINIT

XloopINIT! 1 4

let taken = ""

function! S(n) abort
    XloopNEXT
    let g:taken = g:taken . "E" . a:n
    let v:errmsg = ""
    exec "asdf" . a:n

    " Check that ":silent!" continues:
    Xloop 1

    " Check that ":silent!" sets "v:errmsg":
    if MSG('E492', "Not an editor command")
	Xloop 2
    endif
endfunction

function! Foo()
    while 1
	try
	    try
		let caught = 0
		" This is not silent:
		call S(3)				" X: 0 * 16
	    catch /^Vim:/
		let caught = 1
		let errmsg3 = substitute(v:exception, '^Vim:', '', "")
		silent! call S(4)			" X: 3 * 64
	    finally
		if !caught
		    let errmsg3 = v:errmsg
		    " Do call S(4) here if not executed in :catch.
		    silent! call S(4)
		endif
		Xpath 1048576			" X: 1048576
		if !caught && !$VIMNOERRTHROW
		    Xpath 2097152		" X: 0
		endif
		let v:errmsg = errmsg3
		if !MSG('E492', "Not an editor command")
		    Xpath 4194304		" X: 0
		endif
		silent! call S(5)			" X: 3 * 256
		" Break out of try conditionals that cover ":silent!".  This also
		" discards the aborting error when $VIMNOERRTHROW is non-zero.
		break
	    endtry
	catch /.*/
	    Xpath 8388608			" X: 0
	    Xout v:exception "in" v:throwpoint
	endtry
    endwhile
    " This is a double ":silent!" (see caller).
    silent! call S(6)					" X: 3 * 1024
endfunction

function! Bar()
    try
	silent! call S(2)				" X: 3 * 4
							" X: 3 * 4096
	silent! execute "call Foo() | call S(7)"
	silent! call S(8)				" X: 3 * 16384
    endtry	" normal end of try cond that covers ":silent!"
    " This has a ":silent!" from the caller:
    call S(9)						" X: 3 * 65536
endfunction

silent! call S(1)					" X: 3 * 1
silent! call Bar()
silent! call S(10)					" X: 3 * 262144

let expected = "E1E2E3E4E5E6E7E8E9E10"
if taken != expected
    Xpath 16777216				" X: 0
    Xout "'taken' is" taken "instead of" expected
endif

augroup TMP
    autocmd BufWritePost * Xpath 33554432	" X: 33554432
augroup END

Xpath 67108864					" X: 67108864
write /i/m/p/o/s/s/i/b/l/e
Xpath 134217728					" X: 134217728

autocmd! TMP
unlet! caught errmsg3 taken expected
delfunction S
delfunction Foo
delfunction Bar
delfunction MSG

Xcheck 236978127


"-------------------------------------------------------------------------------
" Test 64:  Error exceptions after error, interrupt or :throw		    {{{1
"
"	    When an error occurs after an interrupt or a :throw but before
"	    a matching :catch is reached, all following :catches of that try
"	    block are ignored, but the error exception can be caught by the next
"	    surrounding try conditional.  Any previous error exception is
"	    discarded.  An error is ignored when there is a previous error that
"	    has not been caught.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    while 1
	try
	    try
		Xpath 1				" X: 1
		let caught = 0
		while 1
"		    if 1
		    " Missing :endif
		endwhile	" throw error exception
	    catch /^Vim(/
		let caught = 1
	    finally
		Xpath 2				" X: 2
		if caught || $VIMNOERRTHROW
		    Xpath 4			" X: 4
		endif
	    endtry
	catch /.*/
	    Xpath 8				" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    try
		Xpath 16			" X: 16
		let caught = 0
		try
"		    if 1
		    " Missing :endif
		catch /.*/	" throw error exception
		    Xpath 32			" X: 0
		catch /.*/
		    Xpath 64			" X: 0
		endtry
	    catch /^Vim(/
		let caught = 1
	    finally
		Xpath 128			" X: 128
		if caught || $VIMNOERRTHROW
		    Xpath 256			" X: 256
		endif
	    endtry
	catch /.*/
	    Xpath 512				" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    try
		let caught = 0
		try
		    Xpath 1024			" X: 1024
		    "INTERRUPT
		catch /do_not_catch/
		    Xpath 2048			" X: 0
"		    if 1
		    " Missing :endif
		catch /.*/	" throw error exception
		    Xpath 4096			" X: 0
		catch /.*/
		    Xpath 8192			" X: 0
		endtry
	    catch /^Vim(/
		let caught = 1
	    finally
		Xpath 16384			" X: 16384
		if caught || $VIMNOERRTHROW
		    Xpath 32768			" X: 32768
		endif
	    endtry
	catch /.*/
	    Xpath 65536				" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    try
		let caught = 0
		try
		    Xpath 131072		" X: 131072
		    throw "x"
		catch /do_not_catch/
		    Xpath 262144		" X: 0
"		    if 1
		    " Missing :endif
		catch /x/	" throw error exception
		    Xpath 524288		" X: 0
		catch /.*/
		   Xpath 1048576		" X: 0
		endtry
	    catch /^Vim(/
		let caught = 1
	    finally
		Xpath 2097152			" X: 2097152
		if caught || $VIMNOERRTHROW
		    Xpath 4194304		" X: 4194304
		endif
	    endtry
	catch /.*/
	    Xpath 8388608			" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    try
		let caught = 0
		Xpath 16777216			" X: 16777216
"		endif		" :endif without :if; throw error exception
"		if 1
		" Missing :endif
	    catch /do_not_catch/ " ignore new error
		Xpath 33554432			" X: 0
	    catch /^Vim(endif):/
		let caught = 1
	    catch /^Vim(/
		Xpath 67108864			" X: 0
	    finally
		Xpath 134217728			" X: 134217728
		if caught || $VIMNOERRTHROW
		    Xpath 268435456		" X: 268435456
		endif
	    endtry
	catch /.*/
	    Xpath 536870912			" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    Xpath 1073741824				" X: 1073741824

endif

Xcheck 1499645335


"-------------------------------------------------------------------------------
" Test 65:  Errors in the /pattern/ argument of a :catch		    {{{1
"
"	    On an error in the /pattern/ argument of a :catch, the :catch does
"	    not match.  Any following :catches of the same :try/:endtry don't
"	    match either.  Finally clauses are executed.
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

try
    try
	Xpath 1					" X: 1
	throw "oops"
    catch /^oops$/
	Xpath 2					" X: 2
    catch /\)/		" not checked; exception has already been caught
	Xpath 4					" X: 0
    endtry
    Xpath 8					" X: 8
catch /.*/
    Xpath 16					" X: 0
    Xout v:exception "in" v:throwpoint
endtry

function! F()
    try
	let caught = 0
	try
	    try
		Xpath 32			" X: 32
		throw "ab"
	    catch /abc/	" does not catch
		Xpath 64			" X: 0
	    catch /\)/	" error; discards exception
		Xpath 128			" X: 0
	    catch /.*/	" not checked
		Xpath 256			" X: 0
	    finally
		Xpath 512			" X: 512
	    endtry
	    Xpath 1024				" X: 0
	catch /^ab$/	" checked, but original exception is discarded
	    Xpath 2048				" X: 0
	catch /^Vim(catch):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(catch):', '', "")
	finally
	    Xpath 4096				" X: 4096
	    if !caught && !$VIMNOERRTHROW
		Xpath 8192			" X: 0
	    endif
	    if !MSG('E475', "Invalid argument")
		Xpath 16384			" X: 0
	    endif
	    if !caught
		return	| " discard error
	    endif
	endtry
    catch /.*/
	Xpath 32768				" X: 0
	Xout v:exception "in" v:throwpoint
    endtry
endfunction

call F()
Xpath 65536					" X: 65536

delfunction MSG
delfunction F
unlet! caught

Xcheck 70187


"-------------------------------------------------------------------------------
" Test 66:  Stop range :call on error, interrupt, or :throw		    {{{1
"
"	    When a function which is multiply called for a range since it
"	    doesn't handle the range itself has an error in a command
"	    dynamically enclosed by :try/:endtry or gets an interrupt or
"	    executes a :throw, no more calls for the remaining lines in the
"	    range are made.  On an error in a command not dynamically enclosed
"	    by :try/:endtry, the function is executed again for the remaining
"	    lines in the range.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    let file = tempname()
    exec "edit" file

    insert
line 1
line 2
line 3
.

    XloopINIT! 1 2

    let taken = ""
    let expected = "G1EF1E(1)F1E(2)F1E(3)G2EF2E(1)G3IF3I(1)G4TF4T(1)G5AF5A(1)"

    function! F(reason, n) abort
	let g:taken = g:taken . "F" . a:n .
	    \ substitute(a:reason, '\(\l\).*', '\u\1', "") .
	    \ "(" . line(".") . ")"

	if a:reason == "error"
	    asdf
	elseif a:reason == "interrupt"
	    "INTERRUPT
	    let dummy = 0
	elseif a:reason == "throw"
	    throw "xyz"
	elseif a:reason == "aborting error"
	    XloopNEXT
	    if g:taken != g:expected
		Xloop 1				" X: 0
		Xout "'taken' is" g:taken "instead of" g:expected
	    endif
	    try
		bwipeout!
		call delete(file)
		asdf
	    endtry
	endif
    endfunction

    function! G(reason, n)
	let g:taken = g:taken . "G" . a:n .
	    \ substitute(a:reason, '\(\l\).*', '\u\1', "")
	1,3call F(a:reason, a:n)
    endfunction

    Xpath 8					" X: 8
    call G("error", 1)
    try
	Xpath 16				" X: 16
	try
	    call G("error", 2)
	    Xpath 32				" X: 0
	finally
	    Xpath 64				" X: 64
	    try
		call G("interrupt", 3)
		Xpath 128			" X: 0
	    finally
		Xpath 256			" X: 256
		try
		    call G("throw", 4)
		    Xpath 512			" X: 0
		endtry
	    endtry
	endtry
    catch /xyz/
	Xpath 1024				" X: 1024
    catch /.*/
	Xpath 2048				" X: 0
	Xout v:exception "in" ExtraVimThrowpoint()
    endtry
    Xpath 4096					" X: 4096
    call G("aborting error", 5)
    Xpath 8192					" X: 0
    Xout "'taken' is" taken "instead of" expected

endif

Xcheck 5464


"-------------------------------------------------------------------------------
" Test 67:  :throw across :call command					    {{{1
"
"	    On a call command, an exception might be thrown when evaluating the
"	    function name, during evaluation of the arguments, or when the
"	    function is being executed.  The exception can be caught by the
"	    caller.
"-------------------------------------------------------------------------------

XpathINIT

function! THROW(x, n)
    if a:n == 1
	Xpath 1						" X: 1
    elseif a:n == 2
	Xpath 2						" X: 2
    elseif a:n == 3
	Xpath 4						" X: 4
    endif
    throw a:x
endfunction

function! NAME(x, n)
    if a:n == 1
	Xpath 8						" X: 0
    elseif a:n == 2
	Xpath 16					" X: 16
    elseif a:n == 3
	Xpath 32					" X: 32
    elseif a:n == 4
	Xpath 64					" X: 64
    endif
    return a:x
endfunction

function! ARG(x, n)
    if a:n == 1
	Xpath 128					" X: 0
    elseif a:n == 2
	Xpath 256					" X: 0
    elseif a:n == 3
	Xpath 512					" X: 512
    elseif a:n == 4
	Xpath 1024					" X: 1024
    endif
    return a:x
endfunction

function! F(x, n)
    if a:n == 2
	Xpath 2048					" X: 0
    elseif a:n == 4
	Xpath 4096					" X: 4096
    endif
endfunction

while 1
    try
	let error = 0
	let v:errmsg = ""

	while 1
	    try
		Xpath 8192				" X: 8192
		call {NAME(THROW("name", 1), 1)}(ARG(4711, 1), 1)
		Xpath 16384				" X: 0
	    catch /^name$/
		Xpath 32768				" X: 32768
	    catch /.*/
		let error = 1
		Xout "1:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "1:" v:errmsg
		endif
		if error
		    Xpath 65536				" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 131072				" X: 131072
		call {NAME("F", 2)}(ARG(THROW("arg", 2), 2), 2)
		Xpath 262144				" X: 0
	    catch /^arg$/
		Xpath 524288				" X: 524288
	    catch /.*/
		let error = 1
		Xout "2:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "2:" v:errmsg
		endif
		if error
		    Xpath 1048576			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 2097152				" X: 2097152
		call {NAME("THROW", 3)}(ARG("call", 3), 3)
		Xpath 4194304				" X: 0
	    catch /^call$/
		Xpath 8388608				" X: 8388608
	    catch /^0$/	    " default return value
		Xpath 16777216				" X: 0
		Xout "3:" v:throwpoint
	    catch /.*/
		let error = 1
		Xout "3:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "3:" v:errmsg
		endif
		if error
		    Xpath 33554432			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 67108864				" X: 67108864
		call {NAME("F", 4)}(ARG(4711, 4), 4)
		Xpath 134217728				" X: 134217728
	    catch /.*/
		let error = 1
		Xout "4:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "4:" v:errmsg
		endif
		if error
		    Xpath 268435456			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

    catch /^0$/	    " default return value
	Xpath 536870912					" X: 0
	Xout v:throwpoint
    catch /.*/
	let error = 1
	Xout v:exception "in" v:throwpoint
    finally
	if !error && $VIMNOERRTHROW && v:errmsg != ""
	    let error = 1
	    Xout v:errmsg
	endif
	if error
	    Xpath 1073741824				" X: 0
	endif
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

unlet error
delfunction F

Xcheck 212514423

" Leave THROW(), NAME(), and ARG() for the next test.


"-------------------------------------------------------------------------------
" Test 68:  :throw across function calls in expressions			    {{{1
"
"	    On a function call within an expression, an exception might be
"	    thrown when evaluating the function name, during evaluation of the
"	    arguments, or when the function is being executed.  The exception
"	    can be caught by the caller.
"
"	    This test reuses the functions THROW(), NAME(), and ARG() from the
"	    previous test.
"-------------------------------------------------------------------------------

XpathINIT

function! F(x, n)
    if a:n == 2
	Xpath 2048					" X: 0
    elseif a:n == 4
	Xpath 4096					" X: 4096
    endif
    return a:x
endfunction

unlet! var1 var2 var3 var4

while 1
    try
	let error = 0
	let v:errmsg = ""

	while 1
	    try
		Xpath 8192				" X: 8192
		let var1 = {NAME(THROW("name", 1), 1)}(ARG(4711, 1), 1)
		Xpath 16384				" X: 0
	    catch /^name$/
		Xpath 32768				" X: 32768
	    catch /.*/
		let error = 1
		Xout "1:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "1:" v:errmsg
		endif
		if error
		    Xpath 65536				" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 131072				" X: 131072
		let var2 = {NAME("F", 2)}(ARG(THROW("arg", 2), 2), 2)
		Xpath 262144				" X: 0
	    catch /^arg$/
		Xpath 524288				" X: 524288
	    catch /.*/
		let error = 1
		Xout "2:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "2:" v:errmsg
		endif
		if error
		    Xpath 1048576			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 2097152				" X: 2097152
		let var3 = {NAME("THROW", 3)}(ARG("call", 3), 3)
		Xpath 4194304				" X: 0
	    catch /^call$/
		Xpath 8388608				" X: 8388608
	    catch /^0$/	    " default return value
		Xpath 16777216				" X: 0
		Xout "3:" v:throwpoint
	    catch /.*/
		let error = 1
		Xout "3:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "3:" v:errmsg
		endif
		if error
		    Xpath 33554432			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 67108864				" X: 67108864
		let var4 = {NAME("F", 4)}(ARG(4711, 4), 4)
		Xpath 134217728				" X: 134217728
	    catch /.*/
		let error = 1
		Xout "4:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "4:" v:errmsg
		endif
		if error
		    Xpath 268435456			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

    catch /^0$/	    " default return value
	Xpath 536870912					" X: 0
	Xout v:throwpoint
    catch /.*/
	let error = 1
	Xout v:exception "in" v:throwpoint
    finally
	if !error && $VIMNOERRTHROW && v:errmsg != ""
	    let error = 1
	    Xout v:errmsg
	endif
	if error
	    Xpath 1073741824				" X: 0
	endif
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

if exists("var1") || exists("var2") || exists("var3") ||
	    \ !exists("var4") || var4 != 4711
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648			" X: 0
    if exists("var1")
	Xout "var1 =" var1
    endif
    if exists("var2")
	Xout "var2 =" var2
    endif
    if exists("var3")
	Xout "var3 =" var3
    endif
    if !exists("var4")
	Xout "var4 unset"
    elseif var4 != 4711
	Xout "var4 =" var4
    endif
endif

unlet! error var1 var2 var3 var4
delfunction THROW
delfunction NAME
delfunction ARG
delfunction F

Xcheck 212514423


"-------------------------------------------------------------------------------
" Test 69:  :throw across :if, :elseif, :while				    {{{1
"
"	    On an :if, :elseif, or :while command, an exception might be thrown
"	    during evaluation of the expression to test.  The exception can be
"	    caught by the script.
"-------------------------------------------------------------------------------

XpathINIT

XloopINIT! 1 2

function! THROW(x)
    XloopNEXT
    Xloop 1					" X: 1 + 2 + 4
    throw a:x
endfunction

try

    try
	Xpath 8					" X: 8
	if 4711 == THROW("if") + 111
	    Xpath 16				" X: 0
	else
	    Xpath 32				" X: 0
	endif
	Xpath 64				" X: 0
    catch /^if$/
	Xpath 128				" X: 128
    catch /.*/
	Xpath 256				" X: 0
	Xout "if:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 512				" X: 512
	if 4711 == 4 + 7 + 1 + 1
	    Xpath 1024				" X: 0
	elseif 4711 == THROW("elseif") + 222
	    Xpath 2048				" X: 0
	else
	    Xpath 4096				" X: 0
	endif
	Xpath 8192				" X: 0
    catch /^elseif$/
	Xpath 16384				" X: 16384
    catch /.*/
	Xpath 32768				" X: 0
	Xout "elseif:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 65536				" X: 65536
	while 4711 == THROW("while") + 4711
	    Xpath 131072			" X: 0
	    break
	endwhile
	Xpath 262144				" X: 0
    catch /^while$/
	Xpath 524288				" X: 524288
    catch /.*/
	Xpath 1048576				" X: 0
	Xout "while:" v:exception "in" v:throwpoint
    endtry

catch /^0$/	    " default return value
    Xpath 2097152				" X: 0
    Xout v:throwpoint
catch /.*/
    Xout v:exception "in" v:throwpoint
    Xpath 4194304				" X: 0
endtry

Xpath 8388608					" X: 8388608

delfunction THROW

Xcheck 8995471


"-------------------------------------------------------------------------------
" Test 70:  :throw across :return or :throw				    {{{1
"
"	    On a :return or :throw command, an exception might be thrown during
"	    evaluation of the expression to return or throw, respectively.  The
"	    exception can be caught by the script.
"-------------------------------------------------------------------------------

XpathINIT

let taken = ""

function! THROW(x, n)
    let g:taken = g:taken . "T" . a:n
    throw a:x
endfunction

function! F(x, y, n)
    let g:taken = g:taken . "F" . a:n
    return a:x + THROW(a:y, a:n)
endfunction

function! G(x, y, n)
    let g:taken = g:taken . "G" . a:n
    throw a:x . THROW(a:y, a:n)
    return a:x
endfunction

try
    try
	Xpath 1					" X: 1
	call F(4711, "return", 1)
	Xpath 2					" X: 0
    catch /^return$/
	Xpath 4					" X: 4
    catch /.*/
	Xpath 8					" X: 0
	Xout "return:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 16				" X: 16
	let var = F(4712, "return-var", 2)
	Xpath 32				" X: 0
    catch /^return-var$/
	Xpath 64				" X: 64
    catch /.*/
	Xpath 128				" X: 0
	Xout "return-var:" v:exception "in" v:throwpoint
    finally
	unlet! var
    endtry

    try
	Xpath 256				" X: 256
	throw "except1" . THROW("throw1", 3)
	Xpath 512				" X: 0
    catch /^except1/
	Xpath 1024				" X: 0
    catch /^throw1$/
	Xpath 2048				" X: 2048
    catch /.*/
	Xpath 4096				" X: 0
	Xout "throw1:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 8192				" X: 8192
	call G("except2", "throw2", 4)
	Xpath 16384				" X: 0
    catch /^except2/
	Xpath 32768				" X: 0
    catch /^throw2$/
	Xpath 65536				" X: 65536
    catch /.*/
	Xpath 131072				" X: 0
	Xout "throw2:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 262144				" X: 262144
	let var = G("except3", "throw3", 5)
	Xpath 524288				" X: 0
    catch /^except3/
	Xpath 1048576				" X: 0
    catch /^throw3$/
	Xpath 2097152				" X: 2097152
    catch /.*/
	Xpath 4194304				" X: 0
	Xout "throw3:" v:exception "in" v:throwpoint
    finally
	unlet! var
    endtry

    let expected = "F1T1F2T2T3G4T4G5T5"
    if taken != expected
	Xpath 8388608				" X: 0
	Xout "'taken' is" taken "instead of" expected
    endif

catch /^0$/	    " default return value
    Xpath 16777216				" X: 0
    Xout v:throwpoint
catch /.*/
    Xpath 33554432				" X: 0
    Xout v:exception "in" v:throwpoint
endtry

Xpath 67108864					" X: 67108864

unlet taken expected
delfunction THROW
delfunction F
delfunction G

Xcheck 69544277


"-------------------------------------------------------------------------------
" Test 71:  :throw across :echo variants and :execute			    {{{1
"
"	    On an :echo, :echon, :echomsg, :echoerr, or :execute command, an
"	    exception might be thrown during evaluation of the arguments to
"	    be displayed or executed as a command, respectively.  Any following
"	    arguments are not evaluated, then.  The exception can be caught by
"	    the script.
"-------------------------------------------------------------------------------

XpathINIT

let taken = ""

function! THROW(x, n)
    let g:taken = g:taken . "T" . a:n
    throw a:x
endfunction

function! F(n)
    let g:taken = g:taken . "F" . a:n
    return "F" . a:n
endfunction

try
    try
	Xpath 1					" X: 1
	echo "echo" . THROW("echo-except", 1) F(1)
	Xpath 2					" X: 0
    catch /^echo-except$/
	Xpath 4					" X: 4
    catch /.*/
	Xpath 8					" X: 0
	Xout "echo:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 16				" X: 16
	echon "echon" . THROW("echon-except", 2) F(2)
	Xpath 32				" X: 0
    catch /^echon-except$/
	Xpath 64				" X: 64
    catch /.*/
	Xpath 128				" X: 0
	Xout "echon:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 256				" X: 256
	echomsg "echomsg" . THROW("echomsg-except", 3) F(3)
	Xpath 512				" X: 0
    catch /^echomsg-except$/
	Xpath 1024				" X: 1024
    catch /.*/
	Xpath 2048				" X: 0
	Xout "echomsg:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 4096				" X: 4096
	echoerr "echoerr" . THROW("echoerr-except", 4) F(4)
	Xpath 8192				" X: 0
    catch /^echoerr-except$/
	Xpath 16384				" X: 16384
    catch /Vim/
	Xpath 32768				" X: 0
    catch /echoerr/
	Xpath 65536				" X: 0
    catch /.*/
	Xpath 131072				" X: 0
	Xout "echoerr:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 262144				" X: 262144
	execute "echo 'execute" . THROW("execute-except", 5) F(5) "'"
	Xpath 524288				" X: 0
    catch /^execute-except$/
	Xpath 1048576				" X: 1048576
    catch /.*/
	Xpath 2097152				" X: 0
	Xout "execute:" v:exception "in" v:throwpoint
    endtry

    let expected = "T1T2T3T4T5"
    if taken != expected
	Xpath 4194304				" X: 0
	Xout "'taken' is" taken "instead of" expected
    endif

catch /^0$/	    " default return value
    Xpath 8388608				" X: 0
    Xout v:throwpoint
catch /.*/
    Xpath 16777216				" X: 0
    Xout v:exception "in" v:throwpoint
endtry

Xpath 33554432					" X: 33554432

unlet taken expected
delfunction THROW
delfunction F

Xcheck 34886997


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

XpathINIT

let throwcount = 0

function! THROW(x)
    let g:throwcount = g:throwcount + 1
    throw a:x
endfunction

try
    try
	let $VAR = "old_value"
	Xpath 1					" X: 1
	let $VAR = "let(" . THROW("var") . ")"
	Xpath 2					" X: 0
    catch /^var$/
	Xpath 4					" X: 4
    finally
	if $VAR != "old_value"
	    Xpath 8				" X: 0
	endif
    endtry

    try
	let @a = "old_value"
	Xpath 16				" X: 16
	let @a = "let(" . THROW("reg") . ")"
	Xpath 32				" X: 0
    catch /^reg$/
	try
	    Xpath 64				" X: 64
	    let @A = "let(" . THROW("REG") . ")"
	    Xpath 128				" X: 0
	catch /^REG$/
	    Xpath 256				" X: 256
	endtry
    finally
	if @a != "old_value"
	    Xpath 512				" X: 0
	endif
	if @A != "old_value"
	    Xpath 1024				" X: 0
	endif
    endtry

    try
	let saved_gpath = &g:path
	let saved_lpath = &l:path
	Xpath 2048				" X: 2048
	let &path = "let(" . THROW("opt") . ")"
	Xpath 4096				" X: 0
    catch /^opt$/
	try
	    Xpath 8192				" X: 8192
	    let &g:path = "let(" . THROW("gopt") . ")"
	    Xpath 16384				" X: 0
	catch /^gopt$/
	    try
		Xpath 32768			" X: 32768
		let &l:path = "let(" . THROW("lopt") . ")"
		Xpath 65536			" X: 0
	    catch /^lopt$/
		Xpath 131072			" X: 131072
	    endtry
	endtry
    finally
	if &g:path != saved_gpath || &l:path != saved_lpath
	    Xpath 262144			" X: 0
	endif
	let &g:path = saved_gpath
	let &l:path = saved_lpath
    endtry

    unlet! var1 var2 var3

    try
	Xpath 524288				" X: 524288
	let var1 = "let(" . THROW("var1") . ")"
	Xpath 1048576				" X: 0
    catch /^var1$/
	Xpath 2097152				" X: 2097152
    finally
	if exists("var1")
	    Xpath 4194304			" X: 0
	endif
    endtry

    try
	let var2 = "old_value"
	Xpath 8388608				" X: 8388608
	let var2 = "let(" . THROW("var2"). ")"
	Xpath 16777216				" X: 0
    catch /^var2$/
	Xpath 33554432				" X: 33554432
    finally
	if var2 != "old_value"
	    Xpath 67108864			" X: 0
	endif
    endtry

    try
	Xpath 134217728				" X: 134217728
	let var{THROW("var3")} = 4711
	Xpath 268435456				" X: 0
    catch /^var3$/
	Xpath 536870912				" X: 536870912
    endtry

    let addpath = ""

    function ADDPATH(p)
	let g:addpath = g:addpath . a:p
    endfunction

    try
	call ADDPATH("T1")
	let var{THROW("var4")} var{ADDPATH("T2")} | call ADDPATH("T3")
	call ADDPATH("T4")
    catch /^var4$/
	call ADDPATH("T5")
    endtry

    try
	call ADDPATH("T6")
	unlet var{THROW("var5")} var{ADDPATH("T7")} | call ADDPATH("T8")
	call ADDPATH("T9")
    catch /^var5$/
	call ADDPATH("T10")
    endtry

    if addpath != "T1T5T6T10" || throwcount != 11
	throw "addpath: " . addpath . ", throwcount: " . throwcount
    endif

    Xpath 1073741824				" X: 1073741824

catch /.*/
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
    Xout v:exception "in" v:throwpoint
endtry

unlet! var1 var2 var3 addpath throwcount
delfunction THROW

Xcheck 1789569365


"-------------------------------------------------------------------------------
" Test 73:  :throw across :function, :delfunction			    {{{1
"
"	    The :function and :delfunction commands may cause an expression
"	    specified in braces to be evaluated.  During evaluation, an
"	    exception might be thrown.  The exception can be caught by the
"	    script.
"-------------------------------------------------------------------------------

XpathINIT

let taken = ""

function! THROW(x, n)
    let g:taken = g:taken . "T" . a:n
    throw a:x
endfunction

function! EXPR(x, n)
    let g:taken = g:taken . "E" . a:n
    if a:n % 2 == 0
	call THROW(a:x, a:n)
    endif
    return 2 - a:n % 2
endfunction

try
    try
	" Define function.
	Xpath 1					" X: 1
	function! F0()
	endfunction
	Xpath 2					" X: 2
	function! F{EXPR("function-def-ok", 1)}()
	endfunction
	Xpath 4					" X: 4
	function! F{EXPR("function-def", 2)}()
	endfunction
	Xpath 8					" X: 0
    catch /^function-def-ok$/
	Xpath 16				" X: 0
    catch /^function-def$/
	Xpath 32				" X: 32
    catch /.*/
	Xpath 64				" X: 0
	Xout "def:" v:exception "in" v:throwpoint
    endtry

    try
	" List function.
	Xpath 128				" X: 128
	function F0
	Xpath 256				" X: 256
	function F{EXPR("function-lst-ok", 3)}
	Xpath 512				" X: 512
	function F{EXPR("function-lst", 4)}
	Xpath 1024				" X: 0
    catch /^function-lst-ok$/
	Xpath 2048				" X: 0
    catch /^function-lst$/
	Xpath 4096				" X: 4096
    catch /.*/
	Xpath 8192				" X: 0
	Xout "lst:" v:exception "in" v:throwpoint
    endtry

    try
	" Delete function
	Xpath 16384				" X: 16384
	delfunction F0
	Xpath 32768				" X: 32768
	delfunction F{EXPR("function-del-ok", 5)}
	Xpath 65536				" X: 65536
	delfunction F{EXPR("function-del", 6)}
	Xpath 131072				" X: 0
    catch /^function-del-ok$/
	Xpath 262144				" X: 0
    catch /^function-del$/
	Xpath 524288				" X: 524288
    catch /.*/
	Xpath 1048576				" X: 0
	Xout "del:" v:exception "in" v:throwpoint
    endtry

    let expected = "E1E2T2E3E4T4E5E6T6"
    if taken != expected
	Xpath 2097152				" X: 0
	Xout "'taken' is" taken "instead of" expected
    endif

catch /.*/
    Xpath 4194304				" X: 0
    Xout v:exception "in" v:throwpoint
endtry

Xpath 8388608					" X: 8388608

unlet taken expected
delfunction THROW
delfunction EXPR

Xcheck 9032615


"-------------------------------------------------------------------------------
" Test 74:  :throw across builtin functions and commands		    {{{1
"
"	    Some functions like exists(), searchpair() take expression
"	    arguments, other functions or commands like substitute() or
"	    :substitute cause an expression (specified in the regular
"	    expression) to be evaluated.  During evaluation an exception
"	    might be thrown.  The exception can be caught by the script.
"-------------------------------------------------------------------------------

XpathINIT

let taken = ""

function! THROW(x, n)
    let g:taken = g:taken . "T" . a:n
    throw a:x
endfunction

function! EXPR(x, n)
    let g:taken = g:taken . "E" . a:n
    call THROW(a:x . a:n, a:n)
    return "EXPR"
endfunction

function! SKIP(x, n)
    let g:taken = g:taken . "S" . a:n . "(" . line(".")
    let theline = getline(".")
    if theline =~ "skip"
	let g:taken = g:taken . "s)"
	return 1
    elseif theline =~ "throw"
	let g:taken = g:taken . "t)"
	call THROW(a:x . a:n, a:n)
    else
	let g:taken = g:taken . ")"
	return 0
    endif
endfunction

function! SUBST(x, n)
    let g:taken = g:taken . "U" . a:n . "(" . line(".")
    let theline = getline(".")
    if theline =~ "not"	    " SUBST() should not be called for this line
	let g:taken = g:taken . "n)"
	call THROW(a:x . a:n, a:n)
    elseif theline =~ "throw"
	let g:taken = g:taken . "t)"
	call THROW(a:x . a:n, a:n)
    else
	let g:taken = g:taken . ")"
	return "replaced"
    endif
endfunction

try
    try
	Xpath 1					" X: 1
	let result = exists('*{EXPR("exists", 1)}')
	Xpath 2					" X: 0
    catch /^exists1$/
	Xpath 4					" X: 4
	try
	    let result = exists('{EXPR("exists", 2)}')
	    Xpath 8				" X: 0
	catch /^exists2$/
	    Xpath 16				" X: 16
	catch /.*/
	    Xpath 32				" X: 0
	    Xout "exists2:" v:exception "in" v:throwpoint
	endtry
    catch /.*/
	Xpath 64				" X: 0
	Xout "exists1:" v:exception "in" v:throwpoint
    endtry

    try
	let file = tempname()
	exec "edit" file
	insert
begin
    xx
middle 3
    xx
middle 5 skip
    xx
middle 7 throw
    xx
end
.
	normal! gg
	Xpath 128				" X: 128
	let result =
	    \ searchpair("begin", "middle", "end", '', 'SKIP("searchpair", 3)')
	Xpath 256				" X: 256
	let result =
	    \ searchpair("begin", "middle", "end", '', 'SKIP("searchpair", 4)')
	Xpath 512				" X: 0
	let result =
	    \ searchpair("begin", "middle", "end", '', 'SKIP("searchpair", 5)')
	Xpath 1024				" X: 0
    catch /^searchpair[35]$/
	Xpath 2048				" X: 0
    catch /^searchpair4$/
	Xpath 4096				" X: 4096
    catch /.*/
	Xpath 8192				" X: 0
	Xout "searchpair:" v:exception "in" v:throwpoint
    finally
	bwipeout!
	call delete(file)
    endtry

    try
	let file = tempname()
	exec "edit" file
	insert
subst 1
subst 2
not
subst 4
subst throw
subst 6
.
	normal! gg
	Xpath 16384				" X: 16384
	1,2substitute/subst/\=SUBST("substitute", 6)/
	try
	    Xpath 32768				" X: 32768
	    try
		let v:errmsg = ""
		3substitute/subst/\=SUBST("substitute", 7)/
	    finally
		if v:errmsg != ""
		    " If exceptions are not thrown on errors, fake the error
		    " exception in order to get the same execution path.
		    throw "faked Vim(substitute)"
		endif
	    endtry
	catch /Vim(substitute)/	    " Pattern not found ('e' flag missing)
	    Xpath 65536				" X: 65536
	    3substitute/subst/\=SUBST("substitute", 8)/e
	    Xpath 131072			" X: 131072
	endtry
	Xpath 262144				" X: 262144
	4,6substitute/subst/\=SUBST("substitute", 9)/
	Xpath 524288				" X: 0
    catch /^substitute[678]/
	Xpath 1048576				" X: 0
    catch /^substitute9/
	Xpath 2097152				" X: 2097152
    finally
	bwipeout!
	call delete(file)
    endtry

    try
	Xpath 4194304				" X: 4194304
	let var = substitute("sub", "sub", '\=THROW("substitute()y", 10)', '')
	Xpath 8388608				" X: 0
    catch /substitute()y/
	Xpath 16777216				" X: 16777216
    catch /.*/
	Xpath 33554432				" X: 0
	Xout "substitute()y:" v:exception "in" v:throwpoint
    endtry

    try
	Xpath 67108864				" X: 67108864
	let var = substitute("not", "sub", '\=THROW("substitute()n", 11)', '')
	Xpath 134217728				" X: 134217728
    catch /substitute()n/
	Xpath 268435456				" X: 0
    catch /.*/
	Xpath 536870912				" X: 0
	Xout "substitute()n:" v:exception "in" v:throwpoint
    endtry

    let expected = "E1T1E2T2S3(3)S4(5s)S4(7t)T4U6(1)U6(2)U9(4)U9(5t)T9T10"
    if taken != expected
	Xpath 1073741824			" X: 0
	Xout "'taken' is" taken "instead of" expected
    endif

catch /.*/
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
    Xout v:exception "in" v:throwpoint
endtry

unlet result var taken expected
delfunction THROW
delfunction EXPR
delfunction SKIP
delfunction SUBST

Xcheck 224907669


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

XpathINIT

function! F1(arg1)
    Xpath 1					" X: 0
endfunction

function! F2(arg1, arg2)
    Xpath 2					" X: 0
endfunction

function! G()
    Xpath 4					" X: 0
endfunction

function! H()
    Xpath 8					" X: 0
endfunction

function! R()
    while 1
	try
	    let caught = 0
	    let v:errmsg = ""
	    Xpath 16				" X: 16
	    return append(1, "s")
	catch /E21/
	    let caught = 1
	catch /.*/
	    Xpath 32				" X: 0
	finally
	    Xpath 64				" X: 64
	    if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
		Xpath 128			" X: 128
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    Xpath 256					" X: 256
endfunction

try
    set noma	" let append() fail with "E21"

    while 1
	try
	    let caught = 0
	    let v:errmsg = ""
	    Xpath 512				" X: 512
	    call append(1, "s")
	catch /E21/
	    let caught = 1
	catch /.*/
	    Xpath 1024				" X: 0
	finally
	    Xpath 2048				" X: 2048
	    if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
		Xpath 4096			" X: 4096
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    let caught = 0
	    let v:errmsg = ""
	    Xpath 8192				" X: 8192
	    call F1('x' . append(1, "s"))
	catch /E21/
	    let caught = 1
	catch /.*/
	    Xpath 16384				" X: 0
	finally
	    Xpath 32768				" X: 32768
	    if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
		Xpath 65536			" X: 65536
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    let caught = 0
	    let v:errmsg = ""
	    Xpath 131072			" X: 131072
	    call F2('x' . append(1, "s"), G())
	catch /E21/
	    let caught = 1
	catch /.*/
	    Xpath 262144			" X: 0
	finally
	    Xpath 524288			" X: 524288
	    if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
		Xpath 1048576			" X: 1048576
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    call R()

    while 1
	try
	    let caught = 0
	    let v:errmsg = ""
	    Xpath 2097152			" X: 2097152
	    throw "T" . append(1, "s")
	catch /E21/
	    let caught = 1
	catch /^T.*/
	    Xpath 4194304			" X: 0
	catch /.*/
	    Xpath 8388608			" X: 0
	finally
	    Xpath 16777216			" X: 16777216
	    if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
		Xpath 33554432			" X: 33554432
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    let caught = 0
	    let v:errmsg = ""
	    Xpath 67108864			" X: 67108864
	    let x = "a"
	    let x = x . "b" . append(1, "s") . H()
	catch /E21/
	    let caught = 1
	catch /.*/
	    Xpath 134217728			" X: 0
	finally
	    Xpath 268435456			" X: 268435456
	    if caught || $VIMNOERRTHROW && v:errmsg =~ 'E21'
		Xpath 536870912			" X: 536870912
	    endif
	    if x == "a"
		Xpath 1073741824		" X: 1073741824
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
catch /.*/
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
    Xout v:exception "in" v:throwpoint
finally
    set ma&
endtry

unlet! caught x
delfunction F1
delfunction F2
delfunction G
delfunction H
delfunction R

Xcheck 2000403408


"-------------------------------------------------------------------------------
" Test 76:  Errors, interrupts, :throw during expression evaluation	    {{{1
"
"	    When a function call made during expression evaluation is aborted
"	    due to an error inside a :try/:endtry region or due to an interrupt
"	    or a :throw, the expression evaluation is aborted as well.	No
"	    message is displayed for the cancelled expression evaluation.  On an
"	    error not inside :try/:endtry, the expression evaluation continues.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    let taken = ""

    function! ERR(n)
	let g:taken = g:taken . "E" . a:n
	asdf
    endfunction

    function! ERRabort(n) abort
	let g:taken = g:taken . "A" . a:n
	asdf
    endfunction	" returns -1; may cause follow-up msg for illegal var/func name

    function! WRAP(n, arg)
	let g:taken = g:taken . "W" . a:n
	let g:saved_errmsg = v:errmsg
	return arg
    endfunction

    function! INT(n)
	let g:taken = g:taken . "I" . a:n
	"INTERRUPT9
	let dummy = 0
    endfunction

    function! THR(n)
	let g:taken = g:taken . "T" . a:n
	throw "should not be caught"
    endfunction

    function! CONT(n)
	let g:taken = g:taken . "C" . a:n
    endfunction

    function! MSG(n)
	let g:taken = g:taken . "M" . a:n
	let errmsg = (a:n >= 37 && a:n <= 44) ? g:saved_errmsg : v:errmsg
	let msgptn = (a:n >= 10 && a:n <= 27) ? "^$" : "asdf"
	if errmsg !~ msgptn
	    let g:taken = g:taken . "x"
	    Xout "Expr" a:n.": Unexpected message:" v:errmsg
	endif
	let v:errmsg = ""
	let g:saved_errmsg = ""
    endfunction

    let v:errmsg = ""

    try
	let t = 1
	XloopINIT 1 2
	while t <= 9
	    Xloop 1				" X: 511
	    try
		if t == 1
		    let v{ERR(t) + CONT(t)} = 0
		elseif t == 2
		    let v{ERR(t) + CONT(t)}
		elseif t == 3
		    let var = exists('v{ERR(t) + CONT(t)}')
		elseif t == 4
		    unlet v{ERR(t) + CONT(t)}
		elseif t == 5
		    function F{ERR(t) + CONT(t)}()
		    endfunction
		elseif t == 6
		    function F{ERR(t) + CONT(t)}
		elseif t == 7
		    let var = exists('*F{ERR(t) + CONT(t)}')
		elseif t == 8
		    delfunction F{ERR(t) + CONT(t)}
		elseif t == 9
		    let var = ERR(t) + CONT(t)
		endif
	    catch /asdf/
		" v:errmsg is not set when the error message is converted to an
		" exception.  Set it to the original error message.
		let v:errmsg = substitute(v:exception, '^Vim:', '', "")
	    catch /^Vim\((\a\+)\)\=:/
		" An error exception has been thrown after the original error.
		let v:errmsg = ""
	    finally
		call MSG(t)
		let t = t + 1
		XloopNEXT
		continue	" discard an aborting error
	    endtry
	endwhile
    catch /.*/
	Xpath 512				" X: 0
	Xout v:exception "in" ExtraVimThrowpoint()
    endtry

    try
	let t = 10
	XloopINIT 1024 2
	while t <= 18
	    Xloop 1				" X: 1024 * 511
	    try
		if t == 10
		    let v{INT(t) + CONT(t)} = 0
		elseif t == 11
		    let v{INT(t) + CONT(t)}
		elseif t == 12
		    let var = exists('v{INT(t) + CONT(t)}')
		elseif t == 13
		    unlet v{INT(t) + CONT(t)}
		elseif t == 14
		    function F{INT(t) + CONT(t)}()
		    endfunction
		elseif t == 15
		    function F{INT(t) + CONT(t)}
		elseif t == 16
		    let var = exists('*F{INT(t) + CONT(t)}')
		elseif t == 17
		    delfunction F{INT(t) + CONT(t)}
		elseif t == 18
		    let var = INT(t) + CONT(t)
		endif
	    catch /^Vim\((\a\+)\)\=:\(Interrupt\)\@!/
		" An error exception has been triggered after the interrupt.
		let v:errmsg = substitute(v:exception,
		    \ '^Vim\((\a\+)\)\=:', '', "")
	    finally
		call MSG(t)
		let t = t + 1
		XloopNEXT
		continue	" discard interrupt
	    endtry
	endwhile
    catch /.*/
	Xpath 524288				" X: 0
	Xout v:exception "in" ExtraVimThrowpoint()
    endtry

    try
	let t = 19
	XloopINIT 1048576 2
	while t <= 27
	    Xloop 1				" X: 1048576 * 511
	    try
		if t == 19
		    let v{THR(t) + CONT(t)} = 0
		elseif t == 20
		    let v{THR(t) + CONT(t)}
		elseif t == 21
		    let var = exists('v{THR(t) + CONT(t)}')
		elseif t == 22
		    unlet v{THR(t) + CONT(t)}
		elseif t == 23
		    function F{THR(t) + CONT(t)}()
		    endfunction
		elseif t == 24
		    function F{THR(t) + CONT(t)}
		elseif t == 25
		    let var = exists('*F{THR(t) + CONT(t)}')
		elseif t == 26
		    delfunction F{THR(t) + CONT(t)}
		elseif t == 27
		    let var = THR(t) + CONT(t)
		endif
	    catch /^Vim\((\a\+)\)\=:/
		" An error exception has been triggered after the :throw.
		let v:errmsg = substitute(v:exception,
		    \ '^Vim\((\a\+)\)\=:', '', "")
	    finally
		call MSG(t)
		let t = t + 1
		XloopNEXT
		continue	" discard exception
	    endtry
	endwhile
    catch /.*/
	Xpath 536870912				" X: 0
	Xout v:exception "in" ExtraVimThrowpoint()
    endtry

    let v{ERR(28) + CONT(28)} = 0
    call MSG(28)
    let v{ERR(29) + CONT(29)}
    call MSG(29)
    let var = exists('v{ERR(30) + CONT(30)}')
    call MSG(30)
    unlet v{ERR(31) + CONT(31)}
    call MSG(31)
    function F{ERR(32) + CONT(32)}()
    endfunction
    call MSG(32)
    function F{ERR(33) + CONT(33)}
    call MSG(33)
    let var = exists('*F{ERR(34) + CONT(34)}')
    call MSG(34)
    delfunction F{ERR(35) + CONT(35)}
    call MSG(35)
    let var = ERR(36) + CONT(36)
    call MSG(36)

    let saved_errmsg = ""

    let v{WRAP(37, ERRabort(37)) + CONT(37)} = 0
    call MSG(37)
    let v{WRAP(38, ERRabort(38)) + CONT(38)}
    call MSG(38)
    let var = exists('v{WRAP(39, ERRabort(39)) + CONT(39)}')
    call MSG(39)
    unlet v{WRAP(40, ERRabort(40)) + CONT(40)}
    call MSG(40)
    function F{WRAP(41, ERRabort(41)) + CONT(41)}()
    endfunction
    call MSG(41)
    function F{WRAP(42, ERRabort(42)) + CONT(42)}
    call MSG(42)
    let var = exists('*F{WRAP(43, ERRabort(43)) + CONT(43)}')
    call MSG(43)
    delfunction F{WRAP(44, ERRabort(44)) + CONT(44)}
    call MSG(44)
    let var = ERRabort(45) + CONT(45)
    call MSG(45)

    Xpath 1073741824				" X: 1073741824

    let expected = ""
	\ . "E1M1E2M2E3M3E4M4E5M5E6M6E7M7E8M8E9M9"
	\ . "I10M10I11M11I12M12I13M13I14M14I15M15I16M16I17M17I18M18"
	\ . "T19M19T20M20T21M21T22M22T23M23T24M24T25M25T26M26T27M27"
	\ . "E28C28M28E29C29M29E30C30M30E31C31M31E32C32M32E33C33M33"
	\ . "E34C34M34E35C35M35E36C36M36"
	\ . "A37W37C37M37A38W38C38M38A39W39C39M39A40W40C40M40A41W41C41M41"
	\ . "A42W42C42M42A43W43C43M43A44W44C44M44A45C45M45"

    if taken != expected
	" The Xpath command does not accept 2^31 (negative); display explicitly:
	exec "!echo 2147483648 >>" . g:ExtraVimResult
						" X: 0
	Xout "'taken' is" taken "instead of" expected
	if substitute(taken,
	\ '\(.*\)E3C3M3x\(.*\)E30C30M30x\(.*\)A39C39M39x\(.*\)',
	\ '\1E3M3\2E30C30M30\3A39C39M39\4',
	\ "") == expected
	    Xout "Is ++emsg_skip for var with expr_start non-NULL"
		\ "in f_exists ok?"
	endif
    endif

    unlet! v var saved_errmsg taken expected
    call delete(WA_t5)
    call delete(WA_t14)
    call delete(WA_t23)
    unlet! WA_t5 WA_t14 WA_t23
    delfunction WA_t5
    delfunction WA_t14
    delfunction WA_t23

endif

Xcheck 1610087935


"-------------------------------------------------------------------------------
" Test 77:  Errors, interrupts, :throw in name{brace-expression}	    {{{1
"
"	    When a function call made during evaluation of an expression in
"	    braces as part of a function name after ":function" is aborted due
"	    to an error inside a :try/:endtry region or due to an interrupt or
"	    a :throw, the expression evaluation is aborted as well, and the
"	    function definition is ignored, skipping all commands to the
"	    ":endfunction".  On an error not inside :try/:endtry, the expression
"	    evaluation continues and the function gets defined, and can be
"	    called and deleted.
"-------------------------------------------------------------------------------

XpathINIT

XloopINIT 1 4

function! ERR() abort
    Xloop 1					" X: 1 + 4 + 16 + 64
    asdf
endfunction		" returns -1

function! OK()
    Xloop 2					" X: 2 * (1 + 4 + 16)
    let v:errmsg = ""
    return 0
endfunction

let v:errmsg = ""

Xpath 4096					" X: 4096
function! F{1 + ERR() + OK()}(arg)
    " F0 should be defined.
    if exists("a:arg") && a:arg == "calling"
	Xpath 8192				" X: 8192
    else
	Xpath 16384				" X: 0
    endif
endfunction
if v:errmsg != ""
    Xpath 32768					" X: 0
endif
XloopNEXT

Xpath 65536					" X: 65536
call F{1 + ERR() + OK()}("calling")
if v:errmsg != ""
    Xpath 131072				" X: 0
endif
XloopNEXT

Xpath 262144					" X: 262144
delfunction F{1 + ERR() + OK()}
if v:errmsg != ""
    Xpath 524288				" X: 0
endif
XloopNEXT

try
    while 1
	let caught = 0
	try
	    Xpath 1048576			" X: 1048576
	    function! G{1 + ERR() + OK()}(arg)
		" G0 should not be defined, and the function body should be
		" skipped.
		if exists("a:arg") && a:arg == "calling"
		    Xpath 2097152		" X: 0
		else
		    Xpath 4194304		" X: 0
		endif
		" Use an unmatched ":finally" to check whether the body is
		" skipped when an error occurs in ERR().  This works whether or
		" not the exception is converted to an exception.
		finally
		    Xpath 8388608		" X: 0
		    Xout "Body of G{1 + ERR() + OK()}() not skipped"
		    " Discard the aborting error or exception, and break the
		    " while loop.
		    break
		" End the try conditional and start a new one to avoid
		" ":catch after :finally" errors.
		endtry
		try
		Xpath 16777216			" X: 0
	    endfunction

	    " When the function was not defined, this won't be reached - whether
	    " the body was skipped or not.  When the function was defined, it
	    " can be called and deleted here.
	    Xpath 33554432			" X: 0
	    Xout "G0() has been defined"
	    XloopNEXT
	    try
		call G{1 + ERR() + OK()}("calling")
	    catch /.*/
		Xpath 67108864			" X: 0
	    endtry
	    Xpath 134217728			" X: 0
	    XloopNEXT
	    try
		delfunction G{1 + ERR() + OK()}
	    catch /.*/
		Xpath 268435456			" X: 0
	    endtry
	catch /asdf/
	    " Jumped to when the function is not defined and the body is
	    " skipped.
	    let caught = 1
	catch /.*/
	    Xpath 536870912			" X: 0
	finally
	    if !caught && !$VIMNOERRTHROW
		Xpath 1073741824		" X: 0
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry			" jumped to when the body is not skipped
    endwhile
catch /.*/
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
    Xout "Body of G{1 + ERR() + OK()}() not skipped, exception caught"
    Xout v:exception "in" v:throwpoint
endtry

Xcheck 1388671


"-------------------------------------------------------------------------------
" Test 78:  Messages on parsing errors in expression evaluation		    {{{1
"
"	    When an expression evaluation detects a parsing error, an error
"	    message is given and converted to an exception, and the expression
"	    evaluation is aborted.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    let taken = ""

    function! F(n)
	let g:taken = g:taken . "F" . a:n
    endfunction

    function! MSG(n, enr, emsg)
	let g:taken = g:taken . "M" . a:n
	let english = v:lang == "C" || v:lang =~ '^[Ee]n'
	if a:enr == ""
	    Xout "TODO: Add message number for:" a:emsg
	    let v:errmsg = ":" . v:errmsg
	endif
	if v:errmsg !~ '^'.a:enr.':' || (english && v:errmsg !~ a:emsg)
	    if v:errmsg == ""
		Xout "Expr" a:n.": Message missing."
		let g:taken = g:taken . "x"
	    else
		let v:errmsg = escape(v:errmsg, '"')
		Xout "Expr" a:n.": Unexpected message:" v:errmsg
		Xout "Expected: " . a:enr . ': ' . a:emsg
		let g:taken = g:taken . "X"
	    endif
	endif
    endfunction

    function! CONT(n)
	let g:taken = g:taken . "C" . a:n
    endfunction

    let v:errmsg = ""
    XloopINIT 1 2

    try
	let t = 1
	while t <= 14
	    let g:taken = g:taken . "T" . t
	    let v:errmsg = ""
	    try
		let caught = 0
		if t == 1
		    let v{novar + CONT(t)} = 0
		elseif t == 2
		    let v{novar + CONT(t)}
		elseif t == 3
		    let var = exists('v{novar + CONT(t)}')
		elseif t == 4
		    unlet v{novar + CONT(t)}
		elseif t == 5
		    function F{novar + CONT(t)}()
		    endfunction
		elseif t == 6
		    function F{novar + CONT(t)}
		elseif t == 7
		    let var = exists('*F{novar + CONT(t)}')
		elseif t == 8
		    delfunction F{novar + CONT(t)}
		elseif t == 9
		    echo novar + CONT(t)
		elseif t == 10
		    echo v{novar + CONT(t)}
		elseif t == 11
		    echo F{novar + CONT(t)}
		elseif t == 12
		    let var = novar + CONT(t)
		elseif t == 13
		    let var = v{novar + CONT(t)}
		elseif t == 14
		    let var = F{novar + CONT(t)}()
		endif
	    catch /^Vim\((\a\+)\)\=:/
		" v:errmsg is not set when the error message is converted to an
		" exception.  Set it to the original error message.
		let v:errmsg = substitute(v:exception,
		    \ '^Vim\((\a\+)\)\=:', '', "")
		let caught = 1
	    finally
		if t <= 8 && t != 3 && t != 7
		    call MSG(t, 'E475', 'Invalid argument\>')
		else
		    if !caught	" no error exceptions ($VIMNOERRTHROW set)
			call MSG(t, 'E15', "Invalid expression")
		    else
			call MSG(t, 'E121', "Undefined variable")
		    endif
		endif
		let t = t + 1
		XloopNEXT
		continue	" discard an aborting error
	    endtry
	endwhile
    catch /.*/
	Xloop 1					" X: 0
	Xout t.":" v:exception "in" ExtraVimThrowpoint()
    endtry

    function! T(n, expr, enr, emsg)
	try
	    let g:taken = g:taken . "T" . a:n
	    let v:errmsg = ""
	    try
		let caught = 0
		execute "let var = " . a:expr
	    catch /^Vim\((\a\+)\)\=:/
		" v:errmsg is not set when the error message is converted to an
		" exception.  Set it to the original error message.
		let v:errmsg = substitute(v:exception,
		    \ '^Vim\((\a\+)\)\=:', '', "")
		let caught = 1
	    finally
		if !caught	" no error exceptions ($VIMNOERRTHROW set)
		    call MSG(a:n, 'E15', "Invalid expression")
		else
		    call MSG(a:n, a:enr, a:emsg)
		endif
		XloopNEXT
		" Discard an aborting error:
		return
	    endtry
	catch /.*/
	    Xloop 1				" X: 0
	    Xout a:n.":" v:exception "in" ExtraVimThrowpoint()
	endtry
    endfunction

    call T(15, 'Nofunc() + CONT(15)',	'E117',	"Unknown function")
    call T(16, 'F(1 2 + CONT(16))',	'E116',	"Invalid arguments")
    call T(17, 'F(1, 2) + CONT(17)',	'E118',	"Too many arguments")
    call T(18, 'F() + CONT(18)',	'E119',	"Not enough arguments")
    call T(19, '{(1} + CONT(19)',	'E110',	"Missing ')'")
    call T(20, '("abc"[1) + CONT(20)',	'E111',	"Missing ']'")
    call T(21, '(1 +) + CONT(21)',	'E15',	"Invalid expression")
    call T(22, '1 2 + CONT(22)',	'E15',	"Invalid expression")
    call T(23, '(1 ? 2) + CONT(23)',	'E109',	"Missing ':' after '?'")
    call T(24, '("abc) + CONT(24)',	'E114',	"Missing quote")
    call T(25, "('abc) + CONT(25)",	'E115',	"Missing quote")
    call T(26, '& + CONT(26)',		'E112', "Option name missing")
    call T(27, '&asdf + CONT(27)',	'E113', "Unknown option")

    Xpath 134217728				" X: 134217728

    let expected = ""
	\ . "T1M1T2M2T3M3T4M4T5M5T6M6T7M7T8M8T9M9T10M10T11M11T12M12T13M13T14M14"
	\ . "T15M15T16M16T17M17T18M18T19M19T20M20T21M21T22M22T23M23T24M24T25M25"
	\ . "T26M26T27M27"

    if taken != expected
	Xpath 268435456				" X: 0
	Xout "'taken' is" taken "instead of" expected
	if substitute(taken, '\(.*\)T3M3x\(.*\)', '\1T3M3\2', "") == expected
	    Xout "Is ++emsg_skip for var with expr_start non-NULL"
		\ "in f_exists ok?"
	endif
    endif

    unlet! var caught taken expected
    call delete(WA_t5)
    unlet! WA_t5
    delfunction WA_t5

endif

Xcheck 134217728


"-------------------------------------------------------------------------------
" Test 79:  Throwing one of several errors for the same command		    {{{1
"
"	    When several errors appear in a row (for instance during expression
"	    evaluation), the first as the most specific one is used when
"	    throwing an error exception.  If, however, a syntax error is
"	    detected afterwards, this one is used for the error exception.
"	    On a syntax error, the next command is not executed, on a normal
"	    error, however, it is (relevant only in a function without the
"	    "abort" flag).  v:errmsg is not set.
"
"	    If throwing error exceptions is configured off, v:errmsg is always
"	    set to the latest error message, that is, to the more general
"	    message or the syntax error, respectively.
"-------------------------------------------------------------------------------

XpathINIT

XloopINIT 1 2

function! NEXT(cmd)
    exec a:cmd . " | Xloop 1"
endfunction

call NEXT('echo novar')				" X: 1 *  1  (checks nextcmd)
XloopNEXT
call NEXT('let novar #')			" X: 0 *  2  (skips nextcmd)
XloopNEXT
call NEXT('unlet novar #')			" X: 0 *  4  (skips nextcmd)
XloopNEXT
call NEXT('let {novar}')			" X: 0 *  8  (skips nextcmd)
XloopNEXT
call NEXT('unlet{ novar}')			" X: 0 * 16  (skips nextcmd)

function! EXEC(cmd)
    exec a:cmd
endfunction

function! MATCH(expected, msg, enr, emsg)
    let msg = a:msg
    if a:enr == ""
	Xout "TODO: Add message number for:" a:emsg
	let msg = ":" . msg
    endif
    let english = v:lang == "C" || v:lang =~ '^[Ee]n'
    if msg !~ '^'.a:enr.':' || (english && msg !~ a:emsg)
	let match =  0
	if a:expected		" no match although expected
	    if a:msg == ""
		Xout "Message missing."
	    else
		let msg = escape(msg, '"')
		Xout "Unexpected message:" msg
		Xout "Expected:" a:enr . ": " . a:emsg
	    endif
	endif
    else
	let match =  1
	if !a:expected		" match although not expected
	    let msg = escape(msg, '"')
	    Xout "Unexpected message:" msg
	    Xout "Expected none."
	endif
    endif
    return match
endfunction

try

    while 1				" dummy loop
	try
	    let v:errmsg = ""
	    let caught = 0
	    let thrmsg = ""
	    call EXEC('echo novar')	" normal error
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let thrmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 32				" X: 32
	    if !caught
		if !$VIMNOERRTHROW
		    Xpath 64			" X: 0
		endif
	    elseif !MATCH(1, thrmsg, 'E121', "Undefined variable")
	    \ || v:errmsg != ""
		Xpath 128			" X: 0
	    endif
	    if !caught && !MATCH(1, v:errmsg, 'E15', "Invalid expression")
		Xpath 256			" X: 0
	    endif
	    break			" discard error if $VIMNOERRTHROW == 1
	endtry
    endwhile

    Xpath 512					" X: 512
    let cmd = "let"
    XloopINIT 1024 32
    while cmd != ""
	try
	    let v:errmsg = ""
	    let caught = 0
	    let thrmsg = ""
	    call EXEC(cmd . ' novar #')		" normal plus syntax error
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let thrmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xloop 1				" X: 1024 * (1 + 32)
	    if !caught
		if !$VIMNOERRTHROW
		    Xloop 2			" X: 0
		endif
	    else
		if cmd == "let"
		    let match = MATCH(0, thrmsg, 'E121', "Undefined variable")
		elseif cmd == "unlet"
		    let match = MATCH(0, thrmsg, 'E108', "No such variable")
		endif
		if match					" normal error
		    Xloop 4			" X: 0
		endif
		if !MATCH(1, thrmsg, 'E488', "Trailing characters")
		\|| v:errmsg != ""
								" syntax error
		    Xloop 8			" X: 0
		endif
	    endif
	    if !caught && !MATCH(1, v:errmsg, 'E488', "Trailing characters")
								" last error
		Xloop 16			" X: 0
	    endif
	    if cmd == "let"
		let cmd = "unlet"
	    else
		let cmd = ""
	    endif
	    XloopNEXT
	    continue			" discard error if $VIMNOERRTHROW == 1
	endtry
    endwhile

    Xpath 1048576				" X: 1048576
    let cmd = "let"
    XloopINIT 2097152 32
    while cmd != ""
	try
	    let v:errmsg = ""
	    let caught = 0
	    let thrmsg = ""
	    call EXEC(cmd . ' {novar}')		" normal plus syntax error
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let thrmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xloop 1				" X: 2097152 * (1 + 32)
	    if !caught
		if !$VIMNOERRTHROW
		    Xloop 2			" X: 0
		endif
	    else
		if MATCH(0, thrmsg, 'E121', "Undefined variable") " normal error
		    Xloop 4			" X: 0
		endif
		if !MATCH(1, thrmsg, 'E475', 'Invalid argument\>')
		\ || v:errmsg != ""				  " syntax error
		    Xloop 8			" X: 0
		endif
	    endif
	    if !caught && !MATCH(1, v:errmsg, 'E475', 'Invalid argument\>')
								" last error
		Xloop 16			" X: 0
	    endif
	    if cmd == "let"
		let cmd = "unlet"
	    else
		let cmd = ""
	    endif
	    XloopNEXT
	    continue			" discard error if $VIMNOERRTHROW == 1
	endtry
    endwhile

catch /.*/
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
    Xout v:exception "in" v:throwpoint
endtry

unlet! next_command thrmsg match
delfunction NEXT
delfunction EXEC
delfunction MATCH

Xcheck 70288929


"-------------------------------------------------------------------------------
" Test 80:  Syntax error in expression for illegal :elseif		    {{{1
"
"	    If there is a syntax error in the expression after an illegal
"	    :elseif, an error message is given (or an error exception thrown)
"	    for the illegal :elseif rather than the expression error.
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

let v:errmsg = ""
if 0
else
elseif 1 ||| 2
endif
Xpath 1						" X: 1
if !MSG('E584', ":elseif after :else")
    Xpath 2					" X: 0
endif

let v:errmsg = ""
if 1
else
elseif 1 ||| 2
endif
Xpath 4						" X: 4
if !MSG('E584', ":elseif after :else")
    Xpath 8					" X: 0
endif

let v:errmsg = ""
elseif 1 ||| 2
Xpath 16					" X: 16
if !MSG('E582', ":elseif without :if")
    Xpath 32					" X: 0
endif

let v:errmsg = ""
while 1
    elseif 1 ||| 2
endwhile
Xpath 64					" X: 64
if !MSG('E582', ":elseif without :if")
    Xpath 128					" X: 0
endif

while 1
    try
	try
	    let v:errmsg = ""
	    let caught = 0
	    if 0
	    else
	    elseif 1 ||| 2
	    endif
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 256				" X: 256
	    if !caught && !$VIMNOERRTHROW
		Xpath 512			" X: 0
	    endif
	    if !MSG('E584', ":elseif after :else")
		Xpath 1024			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 2048				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let v:errmsg = ""
	    let caught = 0
	    if 1
	    else
	    elseif 1 ||| 2
	    endif
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 4096				" X: 4096
	    if !caught && !$VIMNOERRTHROW
		Xpath 8192			" X: 0
	    endif
	    if !MSG('E584', ":elseif after :else")
		Xpath 16384			" X: 0
	    endif
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
	try
	    let v:errmsg = ""
	    let caught = 0
	    elseif 1 ||| 2
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 65536				" X: 65536
	    if !caught && !$VIMNOERRTHROW
		Xpath 131072			" X: 0
	    endif
	    if !MSG('E582', ":elseif without :if")
		Xpath 262144			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 524288				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let v:errmsg = ""
	    let caught = 0
	    while 1
		elseif 1 ||| 2
	    endwhile
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 1048576			" X: 1048576
	    if !caught && !$VIMNOERRTHROW
		Xpath 2097152			" X: 0
	    endif
	    if !MSG('E582', ":elseif without :if")
		Xpath 4194304			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 8388608				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

Xpath 16777216					" X: 16777216

unlet! caught
delfunction MSG

Xcheck 17895765


"-------------------------------------------------------------------------------
" Test 81:  Discarding exceptions after an error or interrupt		    {{{1
"
"	    When an exception is thrown from inside a :try conditional without
"	    :catch and :finally clauses and an error or interrupt occurs before
"	    the :endtry is reached, the exception is discarded.
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
	endtry
	Xpath 16				" X: 0
    catch /arrgh/
	Xpath 32				" X: 0
    endtry
    Xpath 64					" X: 0
endif

if ExtraVim()
    try
	Xpath 128				" X: 128
	try
	    Xpath 256				" X: 256
	    throw "arrgh"
	    Xpath 512				" X: 0
	endtry		" INTERRUPT
	Xpath 1024				" X: 0
    catch /arrgh/
	Xpath 2048				" X: 0
    endtry
    Xpath 4096					" X: 0
endif

Xcheck 387


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
function! Delete_autocommands(...)
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

"-------------------------------------------------------------------------------
" Test 87   using (expr) ? funcref : funcref				    {{{1
"
"	    Vim needs to correctly parse the funcref and even when it does
"	    not execute the funcref, it needs to consume the trailing ()
"-------------------------------------------------------------------------------

XpathINIT

func Add2(x1, x2)
    return a:x1 + a:x2
endfu

func GetStr()
    return "abcdefghijklmnopqrstuvwxyp"
endfu

echo function('Add2')(2,3)

Xout 1 ? function('Add2')(1,2) : function('Add2')(2,3)
Xout 0 ? function('Add2')(1,2) : function('Add2')(2,3)
" Make sure, GetStr() still works.
Xout GetStr()[0:10]


delfunction GetStr
delfunction Add2
Xout  "Successfully executed funcref Add2"

Xcheck 0 

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
