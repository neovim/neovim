" Elixir filetype plugin
" Language: Elixir
" Maintainer:	Mitchell Hanberg <vimNOSPAM@mitchellhanberg.com>
" Last Change: 2023 Dec 27

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim

" Matchit support
if exists('loaded_matchit') && !exists('b:match_words')
  let b:match_ignorecase = 0

  let b:match_words = '\:\@<!\<\%(do\|fn\)\:\@!\>' .
        \ ':' .
        \ '\<\%(else\|catch\|after\|rescue\)\:\@!\>' .
        \ ':' .
        \ '\:\@<!\<end\>' .
        \ ',{:},\[:\],(:)'
endif

setlocal shiftwidth=2 softtabstop=2 expandtab iskeyword+=!,?
setlocal comments=:#
setlocal commentstring=#\ %s

setlocal indentkeys=0#,!^F,o,O
" Enable keys for blocks
setlocal indentkeys+=0=after,0=catch,0=do,0=else,0=end,0=rescue
" Enable keys that are usually the first keys in a line
setlocal indentkeys+=0->,0\|>,0},0],0),>

let b:undo_ftplugin = 'setlocal sw< sts< et< isk< com< cms< indk<'

let &cpo = s:save_cpo
unlet s:save_cpo
