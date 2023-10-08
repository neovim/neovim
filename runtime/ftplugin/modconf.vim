" Vim filetype plugin file
" Language:             modules.conf(5) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2023-10-07

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< inc< fo<"

setlocal comments=:# commentstring=#\ %s include=^\\s*include
setlocal formatoptions-=t formatoptions+=croql

if has('unix') && executable('less')
  if !has('gui_running')
    command -buffer -nargs=1 ModconfKeywordPrg
          \ silent exe '!' . 'LESS= MANPAGER="less --pattern=''^\s{,8}' . <q-args> . '\b'' --hilite-search" man ' . 'modprobe.d' |
          \ redraw!
  elseif has('terminal')
    command -buffer -nargs=1 ModconfKeywordPrg
          \ silent exe ':term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s{,8}' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . 'modprobe.d'
  endif
  if exists(':ModconfKeywordPrg') == 2
    setlocal iskeyword+=-
    setlocal keywordprg=:ModconfKeywordPrg
    let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer ModconfKeywordPrg'
  endif
endif

let &cpo = s:cpo_save
unlet s:cpo_save
