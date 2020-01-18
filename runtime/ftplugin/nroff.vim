" Vim filetype plugin
" Language:	roff(7)
" Maintainer:	Chris Spiegel <cspiegel@gmail.com>
" Last Change:	2019 Apr 24

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=.\\\"%s
