" Vim filetype plugin file
" Language:             cgdbrc
" Maintainer:           Wu, Zhenyu <wuzhenyu@ustc.edu>
" Documentation:        https://cgdb.github.io/docs/Configuring-CGDB.html
" Latest Revision:      2024-04-09
"                       2024-05-23 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpoptions = &cpoptions
set cpoptions&vim

let b:undo_ftplugin = 'setl com< cms<'

setlocal commentstring=#\ %s
setlocal comments=:#

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
