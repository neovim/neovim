" Vim filetype plugin
" Language:     Nvim :checkhealth buffer

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
