" plain TeX filetype plugin
" Language:     plain TeX (ft=plaintex)
" Maintainer:   Benji Fisher, Ph.D. <benji@member.AMS.org>
" Version:	1.1
" Last Change:	Wed 19 Apr 2006

" Only do this when not done yet for this buffer.
if exists("b:did_ftplugin")
  finish
endif

" Start with initex.  This will also define b:did_ftplugin and b:undo_ftplugin .
source $VIMRUNTIME/ftplugin/initex.vim

" Avoid problems if running in 'compatible' mode.
let s:save_cpo = &cpo
set cpo&vim

let b:undo_ftplugin .= "| unlet! b:match_ignorecase b:match_skip b:match_words"

" Allow "[d" to be used to find a macro definition:
let &l:define .= '\|\\new\(count\|dimen\|skip\|muskip\|box\|toks\|read\|write'
	\ .	'\|fam\|insert\)'

" The following lines enable the macros/matchit.vim plugin for
" extended matching with the % key.
" There is no default meaning for \(...\) etc., but many users define one.
if exists("loaded_matchit")
  let b:match_ignorecase = 0
    \ | let b:match_skip = 'r:\\\@<!\%(\\\\\)*%'
    \ | let b:match_words = '(:),\[:],{:},\\(:\\),\\\[:\\],\\{:\\}'
endif " exists("loaded_matchit")

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:sts=2:sw=2:
