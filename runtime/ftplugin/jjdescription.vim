" Vim filetype plugin
" Language:	jj description
" Maintainer:	Gregory Anders <greg@gpanders.com>
" Last Change:	2024 May 8

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Use the same formatoptions and textwidth as the gitcommit ftplugin
setlocal nomodeline formatoptions+=tl textwidth=72
setlocal formatoptions-=c formatoptions-=r formatoptions-=o formatoptions-=q formatoptions+=n
setlocal formatlistpat=^\\s*\\d\\+[\\]:.)}]\\s\\+\\\|^\\s*[-*+]\\s\\+

setlocal comments=b:JJ:
setlocal commentstring=JJ:\ %s

let b:undo_ftplugin = 'setl modeline< formatoptions< textwidth< formatlistpat< comments< commentstring<'
