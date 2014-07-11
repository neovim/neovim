" Vim syntax file
" Language:	HTML with Cheetah tags
" Maintainer:	Max Ischenko <mfi@ukr.net>
" Last Change: 2003-05-11

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'html'
endif

if version < 600
  so <sfile>:p:h/cheetah.vim
  so <sfile>:p:h/html.vim
else
  runtime! syntax/cheetah.vim
  runtime! syntax/html.vim
  unlet b:current_syntax
endif

syntax cluster htmlPreproc add=cheetahPlaceHolder
syntax cluster htmlString add=cheetahPlaceHolder

let b:current_syntax = "htmlcheetah"


