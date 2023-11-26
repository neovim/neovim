" Vim filetype plugin file
" Language:     Fennel
" Maintainer:   Gregory Anders <greg[NOSPAM]@gpanders.com>
" Last Update:  2023 Jun 9

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=;%s
setlocal comments=:;;,:;
setlocal formatoptions-=t
setlocal suffixesadd=.fnl
setlocal lisp
setlocal lispwords=accumulate,case,case-try,collect,do,doto,each,eval-compiler,faccumulate,fcollect,fn,for,icollect,lambda,let,macro,macros,match,match-try,when,while,with-open

let b:undo_ftplugin = 'setlocal commentstring< comments< formatoptions< suffixesadd< lisp< lispwords<'
