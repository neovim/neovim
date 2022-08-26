" Vim filetype plugin file
" Vim syntax file
" Maintainer:           Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2015-05-29
" License:              Vim (see :h license)
" Repository:		https://github.com/chrisbra/vim-kconfig

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments=:# commentstring=#\ %s formatoptions-=t formatoptions+=croql

" For matchit.vim
if exists("loaded_matchit")
  let b:match_words = '^\<menu\>:\<endmenu\>,^\<if\>:\<endif\>,^\<choice\>:\<endchoice\>'
endif

let &cpo = s:cpo_save
unlet s:cpo_save
