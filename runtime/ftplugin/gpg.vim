" Vim filetype plugin file
" Language:             gpg(1) configuration file
" Maintainer:           This runtime file is looking for a new maintainer.
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2025-07-22 (use :hor term #17822)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments=:# commentstring=#\ %s formatoptions-=t formatoptions+=croql

if has('unix') && executable('less') && exists(':terminal') == 2
  command -buffer -nargs=1 GpgKeywordPrg
        \ silent exe ':hor term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s+--' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . 'gpg'
  setlocal iskeyword+=-
  setlocal keywordprg=:GpgKeywordPrg
  let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer GpgKeywordPrg'
endif

let &cpo = s:cpo_save
unlet s:cpo_save

