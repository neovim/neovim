" Vim syntax support file
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" This file is used for ":syntax off".
" It removes the autocommands and stops highlighting for all buffers.

if !has("syntax")
  finish
endif

" Remove all autocommands for the Syntax event.  This also avoids that
" "syntax=foo" in a modeline triggers the SynSet() function of synload.vim.
au! Syntax

" remove all syntax autocommands and remove the syntax for each buffer
augroup syntaxset
  au!
  au BufEnter * syn clear
  au BufEnter * if exists("b:current_syntax") | unlet b:current_syntax | endif
  doautoall syntaxset BufEnter *
  au!
augroup END

if exists("syntax_on")
  unlet syntax_on
endif
if exists("syntax_manual")
  unlet syntax_manual
endif
