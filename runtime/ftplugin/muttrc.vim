" Vim filetype plugin file
" Language:             mutt RC File
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2024-09-19 (simplify keywordprg #15696)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< inc< fo<"

setlocal comments=:# commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let &l:include = '^\s*source\>'

if has('unix') && executable('less') && exists(':terminal') == 2
  command -buffer -nargs=1 MuttrcKeywordPrg
        \ silent exe 'term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s+' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . 'muttrc'
  setlocal iskeyword+=-
  setlocal keywordprg=:MuttrcKeywordPrg
  let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer MuttrcKeywordPrg'
endif

let &cpo = s:cpo_save
unlet s:cpo_save
