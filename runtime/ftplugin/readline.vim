" Vim filetype plugin file
" Language:		readline(3) configuration file
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		2023 Aug 22

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl com< cms< fo<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  let b:match_words = '$if:$else:$endif'
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Readline Intialization Files (inputrc, .inputrc)\tinputrc;*.inputrc\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

if has('unix') && executable('less')
  if !has('gui_running')
    command -buffer -nargs=1 ReadlineKeywordPrg
          \ silent exe '!' . 'LESS= MANPAGER="less --pattern=''^\s+' . <q-args> . '\b'' --hilite-search" man ' . '3 readline' |
          \ redraw!
  elseif has('terminal')
    command -buffer -nargs=1 ReadlineKeywordPrg
          \ silent exe 'term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s+' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . '3 readline'
  endif
  if exists(':ReadlineKeywordPrg') == 2
    setlocal iskeyword+=-
    setlocal keywordprg=:ReadlineKeywordPrg
    let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer ReadlineKeywordPrg'
  endif
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
