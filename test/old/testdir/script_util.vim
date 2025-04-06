" Functions shared by the tests for Vim script

" Commands to track the execution path of a script
com!		   XpathINIT  let g:Xpath = ''
com! -nargs=1 -bar Xpath      let g:Xpath ..= <args>
com!               XloopINIT  let g:Xloop = 1
com! -nargs=1 -bar Xloop      let g:Xpath ..= <args> .. g:Xloop
com!               XloopNEXT  let g:Xloop += 1

" MakeScript() - Make a script file from a function.			    {{{2
"
" Create a script that consists of the body of the function a:funcname.
" Replace any ":return" by a ":finish", any argument variable by a global
" variable, and every ":call" by a ":source" for the next following argument
" in the variable argument list.  This function is useful if similar tests are
" to be made for a ":return" from a function call or a ":finish" in a script
" file.
func MakeScript(funcname, ...)
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
endfunc

" ExecAsScript - Source a temporary script made from a function.	    {{{2
"
" Make a temporary script file from the function a:funcname, ":source" it, and
" delete it afterwards.  However, if an exception is thrown the file may remain,
" the caller should call DeleteTheScript() afterwards.
let s:script_name = ''
func ExecAsScript(funcname)
    " Make a script from the function passed as argument.
    let s:script_name = MakeScript(a:funcname)

    " Source and delete the script.
    exec "source" s:script_name
    call delete(s:script_name)
    let s:script_name = ''
endfunc

func DeleteTheScript()
    if s:script_name
	call delete(s:script_name)
	let s:script_name = ''
    endif
endfunc

com! -nargs=1 -bar ExecAsScript call ExecAsScript(<f-args>)

