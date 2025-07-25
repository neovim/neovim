" Vim filetype plugin file
" Language:	sudoers(5) configuration files
" Maintainer:	This runtime file is looking for a new maintainer.
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Latest Revision:	2025-07-22 (use :hor term #17822)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments=:# commentstring=#\ %s formatoptions-=t formatoptions+=croql

if has('unix') && executable('less') && exists(':terminal') == 2
  command -buffer -nargs=1 SudoersKeywordPrg
        \ silent exe ':hor term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('\b' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . 'sudoers'
  setlocal iskeyword+=-
  setlocal keywordprg=:SudoersKeywordPrg
  let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer SudoersKeywordPrg'
endif

let &cpo = s:cpo_save
unlet s:cpo_save
