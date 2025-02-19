" Vim filetype plugin file
" Language:             modules.conf(5) configuration file
" Maintainer:           This runtime file is looking for a new maintainer.
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2024-09-20 (remove erroneous endif)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< inc< fo<"

setlocal comments=:# commentstring=#\ %s include=^\\s*include
setlocal formatoptions-=t formatoptions+=croql

if has('unix') && executable('less') && exists(':terminal') == 2
  command -buffer -nargs=1 ModconfKeywordPrg
        \ silent exe ':term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s{,8}' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . 'modprobe.d'
  setlocal iskeyword+=-
  setlocal keywordprg=:ModconfKeywordPrg
  let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer ModconfKeywordPrg'
endif

let &cpo = s:cpo_save
unlet s:cpo_save
