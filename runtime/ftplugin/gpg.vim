" Vim filetype plugin file
" Language:             gpg(1) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2023-10-07

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments=:# commentstring=#\ %s formatoptions-=t formatoptions+=croql

if has('unix') && executable('less')
  if !has('gui_running') && !has('nvim')
    command -buffer -nargs=1 GpgKeywordPrg
          \ silent exe '!' . 'LESS= MANPAGER="less --pattern=''^\s+--' . <q-args> . '\b'' --hilite-search" man ' . 'gpg' |
          \ redraw!
  elseif exists(':terminal') == 2
    command -buffer -nargs=1 GpgKeywordPrg
          \ silent exe ':term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s+--' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . 'gpg'
  endif
  if exists(':GpgKeywordPrg') == 2
    setlocal iskeyword+=-
    setlocal keywordprg=:GpgKeywordPrg
    let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer GpgKeywordPrg'
  endif
endif

let &cpo = s:cpo_save
unlet s:cpo_save

