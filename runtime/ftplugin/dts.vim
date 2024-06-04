" Vim filetype plugin file
" Language:             dts/dtsi (device tree files)
" Maintainer:           Wu, Zhenyu <wuzhenyu@ustc.edu>
" Latest Revision:      2024 Apr 12
"                       2024 Jun 02 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = 'setl inc< cms< com<'

setlocal include=^\\%(#include\\\|/include/\\)
" same as C
setlocal commentstring=/*\ %s\ */
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://
