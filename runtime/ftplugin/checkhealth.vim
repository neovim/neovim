" Vim filetype plugin
" Language:     Nvim :checkhealth buffer
" Last Change:  2022 Nov 10

if exists("b:did_ftplugin")
  finish
endif

runtime! ftplugin/help.vim

setlocal wrap breakindent linebreak nolist
let &l:iskeyword='!-~,^*,^|,^",192-255'

if exists("b:undo_ftplugin")
  let b:undo_ftplugin .= "|setl wrap< bri< lbr< kp< isk< list<"
else
  let b:undo_ftplugin = "setl wrap< bri< lbr< kp< isk< list<"
endif
