" Vim syntax file
" Language:	HTML and M4
" Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" URL:		http://www.fleiner.com/vim/syntax/htmlm4.vim
" Last Change:	2001 Apr 30

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" we define it here so that included files can test for it
if !exists("main_syntax")
  let main_syntax='htmlm4'
endif

if version < 600
  so <sfile>:p:h/html.vim
else
  runtime! syntax/html.vim
endif
unlet b:current_syntax
syn case match

if version < 600
  so <sfile>:p:h/m4.vim
else
  runtime! syntax/m4.vim
endif
unlet b:current_syntax
syn cluster htmlPreproc add=@m4Top
syn cluster m4StringContents add=htmlTag,htmlEndTag

let b:current_syntax = "htmlm4"

if main_syntax == 'htmlm4'
  unlet main_syntax
endif
