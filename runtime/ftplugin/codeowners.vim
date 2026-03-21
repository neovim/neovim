" Vim filetype plugin
" Language:	codeowners
" Maintainer:	Jon Parise <jon@indelible.org>
" Last Change:	2025 Sep 14
"
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl comments=:# commentstring=#\ %s
setl formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = 'setl com< cms< fo<'
