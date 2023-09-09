" Vim filetype plugin file
" Language:             mutt RC File
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

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
  if !has('gui_running')
    command -buffer -nargs=1 Sman
          \ silent exe '!' . 'LESS= MANPAGER="less --pattern=''^\s+' . <q-args> . '\b'' --hilite-search" man ' . 'muttrc' |
          \ redraw!
  elseif has('terminal')
    command -buffer -nargs=1 Sman
          \ silent exe 'term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s+' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . 'muttrc'
  endif
  if exists(':Sman') == 2
    setlocal iskeyword+=-
    setlocal keywordprg=:Sman
    let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer Sman'
  endif
endif

let &cpo = s:cpo_save
unlet s:cpo_save
