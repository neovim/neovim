" Vim syntax file
" Language:             cgdbrc
" Maintainer:           Wu, Zhenyu <wuzhenyu@ustc.edu>
" Documentation:        https://cgdb.github.io/docs/Configuring-CGDB.html
" Latest Revision:      2024-04-09

if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'cgdbrc'

runtime! syntax/vim.vim

syn region cgdbComment		start="^\s*\#" skip="\\$" end="$" contains=@Spell

highlight default link cgdbComment Comment
