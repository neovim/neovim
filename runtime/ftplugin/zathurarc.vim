" Vim filetype plugin file
" Language:             Zathurarc
" Maintainer:           Wu, Zhenyu <wuzhenyu@ustc.edu>
" Documentation:        https://pwmt.org/projects/zathura/documentation/
" Upstream:             https://github.com/Freed-Wu/zathurarc.vim
" Latest Revision:      2024-04-02

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpoptions = &cpoptions
set cpoptions&vim

let b:undo_ftplugin = 'setlocal comments< commentstring< include<'
setlocal comments=:#
setlocal commentstring=#\ %s
setlocal include=^\sinclude

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
