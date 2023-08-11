" Vim filetype plugin
" Language:    nix
" Maintainer:  Keith Smiley <keithbsmiley@gmail.com>
" Last Change: 2023 Jul 22

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl commentstring< comments<"

setlocal comments=:#
setlocal commentstring=#\ %s
