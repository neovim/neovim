" Vim filetype plugin file
" Language:		readline(3) configuration file
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		2024 Sep 19 (simplify keywordprg #15696)
" 2024 Jul 22 by Vim project (use :hor term #17822)

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

if has('unix') && executable('less') && exists(':terminal') == 2
  command -buffer -nargs=1 ReadlineKeywordPrg
        \ silent exe 'hor term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s+' . <q-args> . '\b', '\') . ''' --hilite-search" man ' . '3 readline'
  setlocal iskeyword+=-
  setlocal keywordprg=:ReadlineKeywordPrg
  let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer ReadlineKeywordPrg'
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
