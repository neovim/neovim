" Vim syntax file
" Language:	CTRL-H (e.g., ASCII manpages)
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Existing syntax is kept, this file can be used as an addition

" Recognize underlined text: _^Hx
syntax match CtrlHUnderline /_\b./  contains=CtrlHHide

" Recognize bold text: x^Hx
syntax match CtrlHBold /\(.\)\b\1/  contains=CtrlHHide

" Hide the CTRL-H (backspace)
syntax match CtrlHHide /.\b/  contained

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link CtrlHHide Ignore
hi def CtrlHUnderline term=underline cterm=underline gui=underline
hi def CtrlHBold term=bold cterm=bold gui=bold

" vim: ts=8
