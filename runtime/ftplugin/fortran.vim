" Vim settings file
" Language:	Fortran 2023 (and Fortran 2018, 2008, 2003, 95, 90, 77, 66)
" Version:	(v55) 2023 December 22
" Maintainers:	Ajit J. Thakkar <ajit@unb.ca>; <https://ajit.ext.unb.ca/>
" 	        Joshua Hollett <j.hollett@uwinnipeg.ca>
" Usage:	For instructions, do :help fortran-plugin from Vim
" Credits:
"  Version 0.1 was created in September 2000 by Ajit Thakkar.
"  Since then, useful suggestions and contributions have been made, in order, by:
"  Stefano Zacchiroli, Hendrik Merx, Ben Fritz, David Barnett, Eisuke Kawashima,
"  Doug Kearns, and Fritz Reese.
" Last Change:	2023 Dec 22
"		2024 Jan 14 by Vim Project (browsefilter)
"		2024 May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')

" Only do these settings when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

let s:cposet=&cpoptions
set cpoptions&vim

" Don't do other file type settings for this buffer
let b:did_ftplugin = 1

" Determine whether this is a fixed or free format source file
" if this hasn't been done yet using the priority:
" buffer-local value
" > global value
" > file extension as in Intel ifort, gcc (gfortran), NAG, Pathscale, and Cray compilers
if !exists("b:fortran_fixed_source")
  if exists("fortran_free_source")
    " User guarantees free source form
    let b:fortran_fixed_source = 0
  elseif exists("fortran_fixed_source")
    " User guarantees fixed source form
    let b:fortran_fixed_source = 1
  elseif expand("%:e") =~? '^f\%(90\|95\|03\|08\)$'
    " Free-form file extension defaults as in Intel ifort, gcc(gfortran), NAG, Pathscale, and Cray compilers
    let b:fortran_fixed_source = 0
  elseif expand("%:e") =~? '^\%(f\|f77\|for\)$'
    " Fixed-form file extension defaults
    let b:fortran_fixed_source = 1
  else
    " Modern fortran compilers still allow both fixed and free source form
    " Assume fixed source form unless signs of free source form
    " are detected in the first five columns of the first s:lmax lines.
    " Detection becomes more accurate and time-consuming if more lines
    " are checked. Increase the limit below if you keep lots of comments at
    " the very top of each file and you have a fast computer.
    let s:lmax = 500
    if ( s:lmax > line("$") )
      let s:lmax = line("$")
    endif
    let b:fortran_fixed_source = 1
    let s:ln=1
    while s:ln <= s:lmax
      let s:test = strpart(getline(s:ln),0,5)
      if s:test !~ '^[Cc*]' && s:test !~ '^ *[!#]' && s:test =~ '[^ 0-9\t]' && s:test !~ '^[ 0-9]*\t'
	let b:fortran_fixed_source = 0
	break
      endif
      let s:ln = s:ln + 1
    endwhile
    unlet! s:lmax s:ln s:test
  endif
endif

" Set comments and textwidth according to source type
if (b:fortran_fixed_source == 1)
  setlocal comments=:!,:*,:C
  " Fixed format requires a textwidth of 72 for code,
  " but some vendor extensions allow longer lines
  if exists("fortran_extended_line_length")
    setlocal tw=132
  else
  " The use of columns 73-80 for sequence numbers is obsolete
  " so almost all compilers allow a textwidth of 80
    setlocal tw=80
  " If you need to add "&" on continued lines so that the code is
  " compatible with both free and fixed format, then you should do so
  " in column 81 and uncomment the next line
  " setlocal tw=81
  endif
else
  setlocal comments=:!
  " Free format allows a textwidth of 132
  setlocal tw=132
endif

" Set commentstring for foldmethod=marker
setlocal cms=!\ %s

" Tabs are not a good idea in Fortran so the default is to expand tabs
if !exists("fortran_have_tabs")
  setlocal expandtab
endif

" Set 'formatoptions' to break text lines
setlocal fo+=t

setlocal include=^\\c#\\=\\s*include\\s\\+
setlocal suffixesadd+=.f08,.f03,.f95,.f90,.for,.f,.F,.f77,.ftn,.fpp

" Define patterns for the matchit plugin
if !exists("b:match_words")
  let s:notend = '\%(\<end\s\+\)\@<!'
  let s:notselect = '\%(\<select\s\+\)\@<!'
  let s:notelse = '\%(\<end\s\+\|\<else\s\+\)\@<!'
  let s:notprocedure = '\%(\s\+procedure\>\)\@!'
  let s:nothash = '\%(^\s*#\s*\)\@<!'
  let b:match_ignorecase = 1
  let b:match_words =
    \ '(:),' .
    \ s:notend .'\<select\s\+type\>:' . s:notselect. '\<type\|class\>:\<end\s*select\>,' .
    \ s:notend .'\<select\s\+rank\>:' . s:notselect. '\<rank\>:\<end\s*select\>,' .
    \ s:notend .'\<select\>:'         . s:notselect. '\<case\>:\<end\s*select\>,' .
    \ s:notelse . '\<if\s*(.\+)\s*then\>:' .
    \ s:nothash . '\<else\s*\%(if\s*(.\+)\s*then\)\=\>:' . s:nothash . '\<end\s*if\>,'.
    \ 'do\s\+\(\d\+\):\%(^\s*\)\@<=\1\s,'.
    \ s:notend . '\<do\>:\<end\s*do\>,'.
    \ s:notelse . '\<where\>:\<elsewhere\>:\<end\s*where\>,'.
    \ s:notend . '\<type\s*[^(]:\<end\s*type\>,'.
    \ s:notend . '\<forall\>:\<end\s*forall\>,'.
    \ s:notend . '\<associate\>:\<end\s*associate\>,'.
    \ s:notend . '\<change\s\+team\>:\<end\s*team\>,'.
    \ s:notend . '\<critical\>:\<end\s*critical\>,'.
    \ s:notend . '\<block\>:\<end\s*block\>,'.
    \ s:notend . '\<enum\>:\<end\s*enum\>,'.
    \ s:notend . '\<interface\>:\<end\s*interface\>,'.
    \ s:notend . '\<subroutine\>:\<end\s*subroutine\>,'.
    \ s:notend . '\<function\>:\<end\s*function\>,'.
    \ s:notend . '\<module\>' . s:notprocedure . ':\<end\s*module\>,'.
    \ s:notend . '\<program\>:\<end\s*program\>,'.
    \ '\%(^\s*\)\@<=#\s*if\%(def\|ndef\)\=\>:\%(^\s*\)\@<=#\s*\%(elif\|else\)\>:\%(^\s*\)\@<=#\s*endif\>'
endif

" File filters for :browse e
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Fortran Files (*.f, *.for, *.f77, *.f90, *.f95, *.f03, *.f08, *.fpp, *.ftn)\t*.f;*.for;*.f77;*.f90;*.f95;*.f03;*.f08;*.fpp;*.ftn\n"
  if has("win32")
    let b:browsefilter .= "All Files (*.*)\t*\n"
  else
    let b:browsefilter .= "All Files (*)\t*\n"
  endif
endif

let b:undo_ftplugin = "setl fo< com< tw< cms< et< inc< sua<"
	\ . "| unlet! b:match_ignorecase b:match_words b:browsefilter"

let &cpoptions=s:cposet
unlet s:cposet

" vim:sw=2
