" Vim ftplugin file
" Language: Oracle Procedural SQL (PL/SQL)
" Maintainer: Lee Lindley (lee dot lindley at gmail dot com)
" Previous Maintainer: Jeff Lanzarotta (jefflanzarotta at yahoo dot com)
" Previous Maintainer: C. Laurence Gonsalves (clgonsal@kami.com)
" URL: https://github.com/lee-lindley/vim_plsql_syntax
" Last Change: Feb 19, 2025
" History:  Enno Konfekt move handling of optional syntax folding from syntax
"               file to ftplugin

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

if get(g:,"plsql_fold",0) == 1
    setlocal foldmethod=syntax
    let b:undo_ftplugin = "setl fdm< "
endif
