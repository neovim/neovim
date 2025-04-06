" Vim ftplugin file
" Language: fstab file
" Maintainer: Radu Dineiu <radu.dineiu@gmail.com>
" URL: https://raw.github.com/rid9/vim-fstab/master/ftplugin/fstab.vim
" Last Change: 2025 Mar 31
" Version: 1.0.1
"
" Changelog:
" - 2024 May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')
" - 2025 Mar 31 added setlocal formatoptions-=t
"
" Credits:
"   Subhaditya Nath <sn03.general@gmail.com>

if exists("b:did_ftplugin")
	finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s
setlocal formatoptions-=t

let b:undo_ftplugin = "setlocal commentstring< formatoptions<"

" vim: ts=8 ft=vim
