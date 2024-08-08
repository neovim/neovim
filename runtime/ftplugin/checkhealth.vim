" Nvim :checkhealth buffer

if exists("b:did_ftplugin")
  finish
endif

runtime! ftplugin/help.vim

setlocal wrap breakindent linebreak
let &l:iskeyword='!-~,^*,^|,^",192-255'

if exists("b:undo_ftplugin")
  let b:undo_ftplugin .= "|setl wrap< bri< lbr< kp< isk<"
else
  let b:undo_ftplugin = "setl wrap< bri< lbr< kp< isk<"
endif
