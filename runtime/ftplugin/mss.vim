" Vim filetype plugin file
" Language:	Vivado mss file
" Last Change:	2024 Oct 22
" Document:	https://docs.amd.com/r/2020.2-English/ug1400-vitis-embedded/Microprocessor-Software-Specification-MSS
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal comments=b:#,fb:-
setlocal commentstring=#\ %s

let b:match_words = '\<BEGIN\>:\<END\>'
let b:undo_ftplugin = "setl com< cms< | unlet b:match_words"
