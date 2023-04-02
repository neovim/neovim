" Vim filetype plugin
" Language:     Nvim :checkhealth buffer
" Last Change:  2022 Nov 10

if exists("b:did_ftplugin")
  finish
endif

runtime! ftplugin/help.vim

setlocal wrap breakindent linebreak
if get(g:, 'checkhealth_folding_enable', v:true)
  setlocal foldenable
  setlocal foldexpr=getline(v:lnum-1)=~'^=\\{78}$'?'>1':(getline(v:lnum)=~'^=\\{78}'?0:'=')
  setlocal foldmethod=expr
endif
let &l:iskeyword='!-~,^*,^|,^",192-255'

if exists("b:undo_ftplugin")
  let b:undo_ftplugin .= "|setl wrap< bri< lbr< kp< isk<"
else
  let b:undo_ftplugin = "setl wrap< bri< lbr< kp< isk<"
endif
