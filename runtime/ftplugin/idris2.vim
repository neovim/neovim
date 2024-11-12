" Vim ftplugin file
" Language:	   Idris 2
" Last Change: 2024 Nov 05
" Maintainer:  Idris Hackers (https://github.com/edwinb/idris2-vim), Serhii Khoma <srghma@gmail.com>
" License:     Vim (see :h license)
" Repository:  https://github.com/ShinKage/idris2-nvim
"
" Based on ftplugin/idris2.vim from https://github.com/edwinb/idris2-vim

if exists("b:did_ftplugin")
  finish
endif

setlocal shiftwidth=2
setlocal tabstop=2

" Set g:idris2#allow_tabchar = 1 to use tabs instead of spaces
if exists('g:idris2#allow_tabchar') && g:idris2#allow_tabchar != 0
  setlocal noexpandtab
else
  setlocal expandtab
endif

setlocal comments=s1:{-,mb:-,ex:-},:\|\|\|,:--
setlocal commentstring=--\ %s

" makes ? a part of a word, e.g. for named holes `vzipWith f [] [] = ?vzipWith_rhs_3`, uncomment if want to reenable
" setlocal iskeyword+=?

setlocal wildignore+=*.ibc

let b:undo_ftplugin = "setlocal shiftwidth< tabstop< expandtab< comments< commentstring< iskeyword< wildignore<"

let b:did_ftplugin = 1
