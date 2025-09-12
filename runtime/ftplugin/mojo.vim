" Vim filetype plugin
" Language:	Mojo
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Jul 07
" 2025 Apr 16 by Vim Project (set 'cpoptions' for line continuation, #17121)

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal include=^\\s*\\(from\\\|import\\)
setlocal define=^\\s*\\(\\(async\\s\\+\\)\\?def\\\|class\\)

" For imports with leading .., append / and replace additional .s with ../
let b:grandparent_match = '^\(.\.\)\(\.*\)'
let b:grandparent_sub = '\=submatch(1)."/".repeat("../",strlen(submatch(2)))'

" For imports with a single leading ., replace it with ./
let b:parent_match = '^\.\(\.\)\@!'
let b:parent_sub = './'

" Replace any . sandwiched between word characters with /
let b:child_match = '\(\w\)\.\(\w\)'
let b:child_sub = '\1/\2'

setlocal includeexpr=substitute(substitute(substitute(
      \v:fname,
      \b:grandparent_match,b:grandparent_sub,''),
      \b:parent_match,b:parent_sub,''),
      \b:child_match,b:child_sub,'g')

setlocal suffixesadd=.mojo
setlocal comments=b:#,fb:-
setlocal commentstring=#\ %s

let b:undo_ftplugin = 'setlocal include<'
      \ . '|setlocal define<'
      \ . '|setlocal includeexpr<'
      \ . '|setlocal suffixesadd<'
      \ . '|setlocal comments<'
      \ . '|setlocal commentstring<'

let &cpo = s:cpo_save
unlet s:cpo_save
