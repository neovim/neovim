" Vim syntax file
" Language: tpp - Text Presentation Program
" Maintainer: Debian Vim Maintainers
" Former Maintainer: Gerfried Fuchs <alfie@ist.org>
" Last Change: 2018 Dec 27
" URL: https://salsa.debian.org/vim-team/vim-debian/master/syntax/tpp.vim
" Filenames: *.tpp
" License: BSD
"
" XXX This file is in need of a new maintainer, Debian VIM Maintainers maintain
"     it only because patches have been submitted for it by Debian users and the
"     former maintainer was MIA (Missing In Action), taking over its
"     maintenance was thus the only way to include those patches.
"     If you care about this file, and have time to maintain it please do so!
"
" Comments are very welcome - but please make sure that you are commenting on
" the latest version of this file.
" SPAM is _NOT_ welcome - be ready to be reported!

" quit when a syntax file was already loaded
if exists('b:current_syntax')
  finish
endif

if !exists('main_syntax')
  let main_syntax = 'tpp'
endif


"" list of the legal switches/options
syn match tppAbstractOptionKey contained "^--\%(author\|title\|date\|footer\) *" nextgroup=tppString
syn match tppPageLocalOptionKey contained "^--\%(heading\|center\|right\|huge\|sethugefont\|exec\) *" nextgroup=tppString
syn match tppPageLocalSwitchKey contained "^--\%(horline\|-\|\%(begin\|end\)\%(\%(shell\)\?output\|slide\%(left\|right\|top\|bottom\)\)\|\%(bold\|rev\|ul\)\%(on\|off\)\|withborder\)"
syn match tppNewPageOptionKey contained "^--newpage *" nextgroup=tppString
syn match tppColorOptionKey contained "^--\%(\%(bg\|fg\)\?color\) *"
syn match tppTimeOptionKey contained "^--sleep *"

syn match tppString contained ".*"
syn match tppColor contained "\%(white\|yellow\|red\|green\|blue\|cyan\|magenta\|black\|default\)"
syn match tppTime contained "\d\+"

syn region tppPageLocalSwitch start="^--" end="$" contains=tppPageLocalSwitchKey oneline
syn region tppColorOption start="^--\%(\%(bg\|fg\)\?color\)" end="$" contains=tppColorOptionKey,tppColor oneline
syn region tppTimeOption start="^--sleep" end="$" contains=tppTimeOptionKey,tppTime oneline
syn region tppNewPageOption start="^--newpage" end="$" contains=tppNewPageOptionKey oneline
syn region tppPageLocalOption start="^--\%(heading\|center\|right\|huge\|sethugefont\|exec\)" end="$" contains=tppPageLocalOptionKey oneline
syn region tppAbstractOption start="^--\%(author\|title\|date\|footer\)" end="$" contains=tppAbstractOptionKey oneline

if main_syntax !=# 'sh'
  " shell command
  syn include @tppShExec syntax/sh.vim
  unlet b:current_syntax

  syn region shExec matchgroup=tppPageLocalOptionKey start='^--exec *' keepend end='$' contains=@tppShExec

endif

syn match tppComment "^--##.*$"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link tppAbstractOptionKey		Special
hi def link tppPageLocalOptionKey		Keyword
hi def link tppPageLocalSwitchKey		Keyword
hi def link tppColorOptionKey		Keyword
hi def link tppTimeOptionKey		Comment
hi def link tppNewPageOptionKey		PreProc
hi def link tppString			String
hi def link tppColor			String
hi def link tppTime			Number
hi def link tppComment			Comment
hi def link tppAbstractOption		Error
hi def link tppPageLocalOption		Error
hi def link tppPageLocalSwitch		Error
hi def link tppColorOption			Error
hi def link tppNewPageOption		Error
hi def link tppTimeOption			Error


let b:current_syntax = 'tpp'

" vim: ts=8 sw=2
