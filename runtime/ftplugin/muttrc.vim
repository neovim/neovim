" Vim filetype plugin file
" Language:             mutt RC File
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2023-10-07

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

if has('unix') && executable('less')
  if !has('gui_running') && !has('nvim')
    command -buffer -nargs=1 MuttrcKeywordPrg
          \ silent exe '!' . 'LESS= MANPAGER="less --pattern=''^\s+' . <q-args> . '\b'' --hilite-search" man ' . 'muttrc' |
          \ redraw!
  elseif exists(':terminal') == 2
    command -buffer -nargs=1 MuttrcKeywordPrg
          \ silent exe 'term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s+' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . 'muttrc'
  endif
  if exists(':MuttrcKeywordPrg') == 2
    setlocal iskeyword+=-
    setlocal keywordprg=:MuttrcKeywordPrg
    let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer MuttrcKeywordPrg'
  endif
endif

let &cpo = s:cpo_save
unlet s:cpo_save
