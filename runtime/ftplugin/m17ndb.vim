" Vim filetype plugin
" Language:	m17n database
" Maintainer:	David Mandelberg <david@mandelberg.org>
" Last Change:	2025 Feb 21

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:;;;,:;;,:;
setlocal commentstring=;\ %s
setlocal iskeyword=!-~,@,^34,^(,^),^92
setlocal lisp
setlocal lispwords=

let b:undo_ftplugin = "setlocal comments< commentstring< iskeyword< lisp< lispwords<"
