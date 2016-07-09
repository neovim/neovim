" vimballPlugin : construct a file containing both paths and files
" Author: Charles E. Campbell
" Copyright: (c) 2004-2014 by Charles E. Campbell
"            The VIM LICENSE applies to Vimball.vim, and Vimball.txt
"            (see |copyright|) except use "Vimball" instead of "Vim".
"            No warranty, express or implied.
"  *** ***   Use At-Your-Own-Risk!   *** ***
"
" (Rom 2:1 WEB) Therefore you are without excuse, O man, whoever you are who
"      judge. For in that which you judge another, you condemn yourself. For
"      you who judge practice the same things.
" GetLatestVimScripts: 1502 1 :AutoInstall: vimball.vim

" ---------------------------------------------------------------------
"  Load Once: {{{1
if &cp || exists("g:loaded_vimballPlugin")
 finish
endif
let g:loaded_vimballPlugin = "v37"
let s:keepcpo              = &cpo
set cpo&vim

" ------------------------------------------------------------------------------
" Public Interface: {{{1
com! -range   -complete=file -nargs=+ -bang MkVimball		call vimball#MkVimball(<line1>,<line2>,<bang>0,<f-args>)
com! -nargs=? -complete=dir  UseVimball						call vimball#Vimball(1,<f-args>)
com! -nargs=0                VimballList					call vimball#Vimball(0)
com! -nargs=* -complete=dir  RmVimball						call vimball#SaveSettings()|call vimball#RmVimball(<f-args>)|call vimball#RestoreSettings()
augroup Vimball
 au!
 au BufEnter  *.vba,*.vba.gz,*.vba.bz2,*.vba.zip,*.vba.xz	setlocal bt=nofile fmr=[[[,]]] fdm=marker|if &ff != 'unix'|setlocal ma ff=unix noma|endif|if line('$') > 1|call vimball#ShowMesg(0,"Source this file to extract it! (:so %)")|endif
 au SourceCmd *.vba.gz,*.vba.bz2,*.vba.zip,*.vba.xz			let s:origfile=expand("%")|if expand("%")!=expand("<afile>") | exe "1sp" fnameescape(expand("<afile>"))|endif|call vimball#Decompress(expand("<amatch>"))|so %|if s:origfile!=expand("<afile>")|close|endif
 au SourceCmd *.vba											if expand("%")!=expand("<afile>") | exe "1sp" fnameescape(expand("<afile>"))|call vimball#Vimball(1)|close|else|call vimball#Vimball(1)|endif
 au BufEnter  *.vmb,*.vmb.gz,*.vmb.bz2,*.vmb.zip,*.vmb.xz	setlocal bt=nofile fmr=[[[,]]] fdm=marker|if &ff != 'unix'|setlocal ma ff=unix noma|endif|if line('$') > 1|call vimball#ShowMesg(0,"Source this file to extract it! (:so %)")|endif
 au SourceCmd *.vmb.gz,*.vmb.bz2,*.vmb.zip,*.vmb.xz			let s:origfile=expand("%")|if expand("%")!=expand("<afile>") | exe "1sp" fnameescape(expand("<afile>"))|endif|call vimball#Decompress(expand("<amatch>"))|so %|if s:origfile!=expand("<afile>")|close|endif
 au SourceCmd *.vmb											if expand("%")!=expand("<afile>") | exe "1sp" fnameescape(expand("<afile>"))|call vimball#Vimball(1)|close|else|call vimball#Vimball(1)|endif
augroup END

" =====================================================================
" Restoration And Modelines: {{{1
" vim: fdm=marker
let &cpo= s:keepcpo
unlet s:keepcpo
