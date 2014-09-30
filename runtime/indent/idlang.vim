" IDL (Interactive Data Language) indent file.
" Language: IDL (ft=idlang)
" Last change:	2012 May 18
" Maintainer: Aleksandar Jelenak <ajelenak AT yahoo.com>

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

setlocal indentkeys=o,O,0=endif,0=ENDIF,0=endelse,0=ENDELSE,0=endwhile,0=ENDWHILE,0=endfor,0=ENDFOR,0=endrep,0=ENDREP

setlocal indentexpr=GetIdlangIndent(v:lnum)

" Only define the function once.
if exists("*GetIdlangIndent")
   finish
endif

function GetIdlangIndent(lnum)
   " First non-empty line above the current line.
   let pnum = prevnonblank(v:lnum-1)
   " v:lnum is the first non-empty line -- zero indent.
   if pnum == 0
      return 0
   endif
   " Second non-empty line above the current line.
   let pnum2 = prevnonblank(pnum-1)

   " Current indent.
   let curind = indent(pnum)

   " Indenting of continued lines.
   if getline(pnum) =~ '\$\s*\(;.*\)\=$'
      if getline(pnum2) !~ '\$\s*\(;.*\)\=$'
	 let curind = curind+&sw
      endif
   else
      if getline(pnum2) =~ '\$\s*\(;.*\)\=$'
	 let curind = curind-&sw
      endif
   endif

   " Indenting blocks of statements.
   if getline(v:lnum) =~? '^\s*\(endif\|endelse\|endwhile\|endfor\|endrep\)\>'
      if getline(pnum) =~? 'begin\>'
      elseif indent(v:lnum) > curind-&sw
	 let curind = curind-&sw
      else
	 return -1
      endif
   elseif getline(pnum) =~? 'begin\>'
      if indent(v:lnum) < curind+&sw
	 let curind = curind+&sw
      else
	 return -1
      endif
   endif
   return curind
endfunction

