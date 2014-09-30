" Vim syntax file
" Language:	tpp - Text Presentation Program
" Maintainer:   Debian Vim Maintainers <pkg-vim-maintainers@lists.alioth.debian.org>
" Former Maintainer:	Gerfried Fuchs <alfie@ist.org>
" Last Change:	2007-10-14
" URL: http://git.debian.org/?p=pkg-vim/vim.git;a=blob_plain;f=runtime/syntax/tpp.vim;hb=debian
" Filenames:	*.tpp
" License:	BSD
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

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
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

if main_syntax != 'sh'
  " shell command
  if version < 600
    syn include @tppShExec <sfile>:p:h/sh.vim
  else
    syn include @tppShExec syntax/sh.vim
  endif
  unlet b:current_syntax

  syn region shExec matchgroup=tppPageLocalOptionKey start='^--exec *' keepend end='$' contains=@tppShExec

endif

syn match tppComment "^--##.*$"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_tpp_syn_inits")
  if version < 508
    let did_tpp_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink tppAbstractOptionKey		Special
  HiLink tppPageLocalOptionKey		Keyword
  HiLink tppPageLocalSwitchKey		Keyword
  HiLink tppColorOptionKey		Keyword
  HiLink tppTimeOptionKey		Comment
  HiLink tppNewPageOptionKey		PreProc
  HiLink tppString			String
  HiLink tppColor			String
  HiLink tppTime			Number
  HiLink tppComment			Comment
  HiLink tppAbstractOption		Error
  HiLink tppPageLocalOption		Error
  HiLink tppPageLocalSwitch		Error
  HiLink tppColorOption			Error
  HiLink tppNewPageOption		Error
  HiLink tppTimeOption			Error

  delcommand HiLink
endif

let b:current_syntax = "tpp"

" vim: ts=8 sw=2
