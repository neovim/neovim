" LogiPat:
"   Author:  Charles E. Campbell
"   Date:    Mar 13, 2013
"   Version: 3
"   Purpose: to do Boolean-logic based regular expression pattern matching
" Copyright:    Copyright (C) 1999-2011 Charles E. Campbell {{{1
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like most anything else that's free,
"               LogiPat.vim is provided *as is* and comes with no warranty
"               of any kind, either expressed or implied. By using this
"               plugin, you agree that in no event will the copyright
"               holder be liable for any damages resulting from the use
"               of this software.
"
"   Usage: {{{1
"       :LogiPat ...
"
"         Boolean logic supported:
"            () grouping operators
"            !  not the following pattern
"            |  logical or
"            &  logical and
"            "..pattern.."
"	Example: {{{1
"		:LogiPat !("january"|"february")
"		  would match all strings not containing the strings january
"		  or february
"	GetLatestVimScripts: 1290 1 :AutoInstall: LogiPat.vim
"
"  Behold, you will conceive in your womb, and bring forth a son, {{{1
"  and will call his name Jesus. He will be great, and will be
"  called the Son of the Most High. The Lord God will give him the
"  throne of his father, David, and he will reign over the house of
"  Jacob forever. There will be no end to his kingdom. (Luke 1:31-33 WEB)

" ---------------------------------------------------------------------
" Load Once: {{{1
if &cp || exists("loaded_logipat")
 finish
endif
let g:loaded_LogiPat = "v3"
let s:keepcpo        = &cpo
set cpo&vim
"DechoRemOn

" ---------------------------------------------------------------------
" Public Interface: {{{1
com!        -nargs=* LogiPat		call   LogiPat(<q-args>,1)
silent! com -nargs=* LP				call   LogiPat(<q-args>,1)
com!        -nargs=+ ELP			echomsg   LogiPat(<q-args>)
com!        -nargs=+ LogiPatFlags	let  s:LogiPatFlags="<args>"
silent! com -nargs=+ LPF			let  s:LogiPatFlags="<args>"

" =====================================================================
" Functions: {{{1

" ---------------------------------------------------------------------
" LogiPat: this function interprets the boolean-logic pattern {{{2
fun! LogiPat(pat,...)
"  call Dfunc("LogiPat(pat<".a:pat.">)")

  " LogiPat(pat,dosearch)
  if a:0 > 0
   let dosearch= a:1
  else
   let dosearch= 0
  endif

  let s:npatstack = 0
  let s:nopstack  = 0
  let s:preclvl   = 0
  let expr        = a:pat

  " Lexer/Parser
  while expr != ""
"   call Decho("expr<".expr.">")

   if expr =~ '^"'
	" push a Pattern; accept "" as a single " in the pattern
    let expr = substitute(expr,'^\s*"','','')
    let pat  = substitute(expr,'^\(\%([^"]\|\"\"\)\{-}\)"\([^"].*$\|$\)','\1','')
	let pat  = substitute(pat,'""','"','g')
    let expr = substitute(expr,'^\(\%([^"]\|\"\"\)\{-}\)"\([^"].*$\|$\)','\2','')
    let expr = substitute(expr,'^\s*','','')
"    call Decho("pat<".pat."> expr<".expr.">")

    call s:LP_PatPush('.*'.pat.'.*')

   elseif expr =~ '^[!()|&]'
    " push an operator
    let op   = strpart(expr,0,1)
    let expr = strpart(expr,strlen(op))
	" allow for those who can't resist doubling their and/or operators
	if op =~ '[|&]' && expr[0] == op
     let expr = strpart(expr,strlen(op))
	endif
    call s:LP_OpPush(op)

   elseif expr =~ '^\s'
    " skip whitespace
    let expr= strpart(expr,1)

   else
    echoerr "operator<".strpart(expr,0,1)."> not supported (yet)"
    let expr= strpart(expr,1)
   endif

  endwhile

  " Final Execution
  call s:LP_OpPush('Z')

  let result= s:LP_PatPop(1)
"  call Decho("result=".result)

  " sanity checks and cleanup
  if s:npatstack > 0
   echoerr s:npatstack." patterns left on stack!"
   let s:npatstack= 0
  endif
  if s:nopstack > 0
   echoerr s:nopstack." operators left on stack!"
   let s:nopstack= 0
  endif

  " perform the indicated search
  if dosearch
   if exists("s:LogiPatFlags")
"  call Decho("search(result<".result."> LogiPatFlags<".s:LogiPatFlags.">)")
    call search(result,s:LogiPatFlags)
   else
"  call Decho("search(result<".result.">)")
    call search(result)
   endif
   let @/= result
  endif

"  call Dret("LogiPat ".result)
  return result
endfun

" ---------------------------------------------------------------------
" s:String: Vim6.4 doesn't have string() {{{2
func! s:String(str)
  return "'".escape(a:str, '"')."'"
endfunc

" ---------------------------------------------------------------------
" LP_PatPush: {{{2
fun! s:LP_PatPush(pat)
"  call Dfunc("LP_PatPush(pat<".a:pat.">)")
  let s:npatstack              = s:npatstack + 1
  let s:patstack_{s:npatstack} = a:pat
"  call s:StackLook("patpush") "Decho
"  call Dret("LP_PatPush : npatstack=".s:npatstack)
endfun

" ---------------------------------------------------------------------
" LP_PatPop: pop a number/variable from LogiPat's pattern stack {{{2
fun! s:LP_PatPop(lookup)
"  call Dfunc("LP_PatPop(lookup=".a:lookup.")")
  if s:npatstack > 0
   let ret         = s:patstack_{s:npatstack}
   let s:npatstack = s:npatstack - 1
  else
   let ret= "---error---"
   echoerr "(LogiPat) invalid expression"
  endif
"  call s:StackLook("patpop") "Decho
"  call Dret("LP_PatPop ".ret)
  return ret
endfun

" ---------------------------------------------------------------------
" LP_OpPush: {{{2
fun! s:LP_OpPush(op)
"  call Dfunc("LP_OpPush(op<".a:op.">)")

  " determine new operator's precedence level
  if a:op == '('
  	let s:preclvl= s:preclvl + 10
	let preclvl  = s:preclvl
  elseif a:op == ')'
  	let s:preclvl= s:preclvl - 10
   if s:preclvl < 0
    let s:preclvl= 0
    echoerr "too many )s"
   endif
   let preclvl= s:preclvl
  elseif a:op =~ '|'
   let preclvl= s:preclvl + 2
  elseif a:op =~ '&'
   let preclvl= s:preclvl + 4
  elseif a:op == '!'
   let preclvl= s:preclvl + 6
  elseif a:op == 'Z'
   let preclvl= -1
  else
   echoerr "expr<".expr."> not supported (yet)"
   let preclvl= s:preclvl
  endif
"  call Decho("new operator<".a:op."> preclvl=".preclvl)

  " execute higher-precdence operators
"  call Decho("execute higher-precedence operators")
  call s:LP_Execute(preclvl)

  " push new operator onto operator-stack
"  call Decho("push new operator<".a:op."> onto stack with preclvl=".preclvl." at nopstack=".(s:nopstack+1))
  if a:op =~ '!'
   let s:nopstack             = s:nopstack + 1
   let s:opprec_{s:nopstack}  = preclvl
   let s:opstack_{s:nopstack} = a:op
  elseif a:op =~ '|'
   let s:nopstack             = s:nopstack + 1
   let s:opprec_{s:nopstack}  = preclvl
   let s:opstack_{s:nopstack} = a:op
  elseif a:op == '&'
   let s:nopstack             = s:nopstack + 1
   let s:opprec_{s:nopstack}  = preclvl
   let s:opstack_{s:nopstack} = a:op
  endif

"  call s:StackLook("oppush") "Decho
"  call Dret("LP_OpPush : s:preclvl=".s:preclvl)
endfun

" ---------------------------------------------------------------------
" LP_Execute: execute operators from opstack using pattern stack {{{2
fun! s:LP_Execute(preclvl)
"  call Dfunc("LP_Execute(preclvl=".a:preclvl.") npatstack=".s:npatstack." nopstack=".s:nopstack)

  " execute all higher precedence operators
  while s:nopstack > 0 && a:preclvl < s:opprec_{s:nopstack}
   let op= s:opstack_{s:nopstack}
"   call Decho("op<".op."> nop=".s:nopstack." [preclvl=".a:preclvl."] < [opprec_".s:nopstack."=".s:opprec_{s:nopstack}."]")

   let s:nopstack = s:nopstack - 1
 
   if     op == '!'
    let n1= s:LP_PatPop(1)
	call s:LP_PatPush(s:LP_Not(n1))
 
   elseif op == '|'
    let n1= s:LP_PatPop(1)
    let n2= s:LP_PatPop(1)
    call s:LP_PatPush(s:LP_Or(n2,n1))
 
   elseif op =~ '&'
    let n1= s:LP_PatPop(1)
    let n2= s:LP_PatPop(1)
    call s:LP_PatPush(s:LP_And(n2,n1))
   endif
 
"   call s:StackLook("execute") "Decho
  endwhile

"  call Dret("LP_Execute")
endfun

" ---------------------------------------------------------------------
" LP_Not: writes a logical-not for a pattern {{{2
fun! s:LP_Not(pat)
"  call Dfunc("LP_Not(pat<".a:pat.">)")
  if a:pat =~ '^\.\*' && a:pat =~ '\.\*$'
   let pat= substitute(a:pat,'^\.\*\(.*\)\.\*$','\1','')
   let ret= '^\%(\%('.pat.'\)\@!.\)*$'
  else
   let ret= '^\%(\%('.a:pat.'\)\@!.\)*$'
  endif
"  call Dret("LP_Not ".ret)
  return ret
endfun

" ---------------------------------------------------------------------
" LP_Or: writes a logical-or branch using two patterns {{{2
fun! s:LP_Or(pat1,pat2)
"  call Dfunc("LP_Or(pat1<".a:pat1."> pat2<".a:pat2.">)")
  let ret= '\%('.a:pat1.'\|'.a:pat2.'\)'
"  call Dret("LP_Or ".ret)
  return ret
endfun

" ---------------------------------------------------------------------
" LP_And: writes a logical-and concat using two patterns {{{2
fun! s:LP_And(pat1,pat2)
"  call Dfunc("LP_And(pat1<".a:pat1."> pat2<".a:pat2.">)")
  let ret= '\%('.a:pat1.'\&'.a:pat2.'\)'
"  call Dret("LP_And ".ret)
  return ret
endfun

" ---------------------------------------------------------------------
" StackLook: {{{2
fun! s:StackLook(description)
"  call Dfunc("StackLook(description<".a:description.">)")
  let iop = 1
  let ifp = 1
"  call Decho("Pattern                       Operator")

  " print both pattern and operator
  while ifp <= s:npatstack && iop <= s:nopstack
   let fp = s:patstack_{ifp}
   let op = s:opstack_{iop}." (P".s:opprec_{s:nopstack}.')'
   let fplen= strlen(fp)
   if fplen < 30
   	let fp= fp.strpart("                              ",1,30-fplen)
   endif
"   call Decho(fp.op)
   let ifp = ifp + 1
   let iop = iop + 1
  endwhile

  " print just pattern
  while ifp <= s:npatstack
   let fp  = s:patstack_{ifp}
"   call Decho(fp)
   let ifp = ifp + 1
  endwhile

  " print just operator
  while iop <= s:nopstack
   let op  = s:opstack_{iop}." (P".s:opprec_{s:nopstack}.')'
"   call Decho("                              ".op)
   let iop = iop + 1
  endwhile
"  call Dret("StackLook")
endfun

" ---------------------------------------------------------------------
"  Cleanup And Modeline: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" vim: ts=4 fdm=marker
