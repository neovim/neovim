" Vim filetype plugin
" Language:     Nvim :checkhealth buffer
" Last Change:  2022 Nov 10

if exists("b:did_ftplugin")
  finish
endif

runtime! ftplugin/help.vim

setlocal wrap breakindent linebreak
setlocal foldexpr=getline(v:lnum-1)=~'^=\\{78}$'?'>1':(getline(v:lnum)=~'^=\\{78}'?0:'=')
setlocal foldmethod=expr
setlocal foldtext=v:lua.require('vim.health').foldtext()
let &l:iskeyword='!-~,^*,^|,^",192-255'

if exists("b:undo_ftplugin")
  let b:undo_ftplugin .= "|setl wrap< bri< lbr< kp< isk<"
else
  let b:undo_ftplugin = "setl wrap< bri< lbr< kp< isk<"
endif
