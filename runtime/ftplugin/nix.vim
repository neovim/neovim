" Vim filetype plugin
" Language:    nix
" Maintainer:  Keith Smiley <keithbsmiley@gmail.com>
" Last Change: 2023 Jul 22
" 2025 Apr 18 by Vim Project (set 'iskeyword' and b:match_words #17154)

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl commentstring< comments< iskeyword< | unlet! b:match_words"

let b:match_words = "\<if\>:\<then\>:\<else\>,\<let\>:\<in\>"

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal iskeyword+=-
