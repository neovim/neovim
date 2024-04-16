" Vim Compiler File
" Language:             rime_deployer
" Maintainer:           Wu, Zhenyu <wuzhenyu@ustc.edu>
" URL:                  https://rime.im
" Latest Revision:      2024-04-09

if exists('b:current_compiler')
  finish
endif
let b:current_compiler = 'rime_deployer'

let s:save_cpoptions = &cpoptions
set cpoptions&vim

" Android Termux
let s:prefix = getenv('PREFIX')
if s:prefix == v:null
  let s:prefix = '/usr'
endif
" Android, NixOS, GNU/Linux, BSD
for s:shared_data_dir in ['/sdcard/rime-data', '/run/current-system/sw/share/rime-data', '/usr/local/share/rime-data', s:prefix . '/share/rime-data']
  if isdirectory(s:shared_data_dir)
    break
  endif
endfor
execute 'CompilerSet makeprg=rime_deployer\ --build\ %:p:h:S\' s:shared_data_dir
unlet s:prefix s:shared_data_dir

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
