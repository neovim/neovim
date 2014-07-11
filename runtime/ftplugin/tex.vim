" LaTeX filetype plugin
" Language:     LaTeX (ft=tex)
" Maintainer:   Benji Fisher, Ph.D. <benji@member.AMS.org>
" Version:	1.4
" Last Change:	Wed 19 Apr 2006
"  URL:		http://www.vim.org/script.php?script_id=411

" Only do this when not done yet for this buffer.
if exists("b:did_ftplugin")
  finish
endif

" Start with plain TeX.  This will also define b:did_ftplugin .
source $VIMRUNTIME/ftplugin/plaintex.vim

" Avoid problems if running in 'compatible' mode.
let s:save_cpo = &cpo
set cpo&vim

let b:undo_ftplugin .= "| setl inex<"

" Allow "[d" to be used to find a macro definition:
" Recognize plain TeX \def as well as LaTeX \newcommand and \renewcommand .
" I may as well add the AMS-LaTeX DeclareMathOperator as well.
let &l:define .= '\|\\\(re\)\=new\(boolean\|command\|counter\|environment\|font'
	\ . '\|if\|length\|savebox\|theorem\(style\)\=\)\s*\*\=\s*{\='
	\ . '\|DeclareMathOperator\s*{\=\s*'

" Tell Vim how to recognize LaTeX \include{foo} and plain \input bar :
let &l:include .= '\|\\include{'
" On some file systems, "{" and "}" are inluded in 'isfname'.  In case the
" TeX file has \include{fname} (LaTeX only), strip everything except "fname".
let &l:includeexpr = "substitute(v:fname, '^.\\{-}{\\|}.*', '', 'g')"

" The following lines enable the macros/matchit.vim plugin for
" extended matching with the % key.
" ftplugin/plaintex.vim already defines b:match_skip and b:match_ignorecase
" and matches \(, \), \[, \], \{, and \} .
if exists("loaded_matchit")
  let b:match_words .= ',\\begin\s*\({\a\+\*\=}\):\\end\s*\1'
endif " exists("loaded_matchit")

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:sts=2:sw=2:
