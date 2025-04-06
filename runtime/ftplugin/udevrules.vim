" Vim filetype plugin file
" Language:	udev(8) rules file
" Maintainer:	This runtime file is looking for a new maintainer.
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Latest Revision:	2024-09-19 (simplify keywordprg #15696)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments=:# commentstring=#\ %s formatoptions-=t formatoptions+=croql

if has('unix') && executable('less') && exists(':terminal') == 2
  command -buffer -nargs=1 UdevrulesKeywordPrg
        \ silent exe ':term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s{,8}' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . 'udev'
  setlocal iskeyword+=-
  setlocal keywordprg=:UdevrulesKeywordPrg
  let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer UdevrulesKeywordPrg'
endif

let &cpo = s:cpo_save
unlet s:cpo_save
