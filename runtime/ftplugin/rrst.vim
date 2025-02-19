" Vim filetype plugin file
" Language:		reStructuredText documentation format with R code
" Maintainer:		This runtime file is looking for a new maintainer.
" Former Maintainer:	Jakson Alves de Aquino <jalvesaq@gmail.com>
" Former Repository:	https://github.com/jalvesaq/R-Vim-runtime
" Last Change:
"  2024 Feb 28 by Vim Project
"  2024 Sep 23 by Vim Project: properly restore fex option
" Original work by Alex Zvoleff

" Only do this when not yet done for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=fb:*,fb:-,fb:+,n:>
setlocal commentstring=#\ %s
setlocal formatoptions+=tcqln
setlocal formatlistpat=^\\s*\\d\\+\\.\\s\\+\\\|^\\s*[-*+]\\s\\+
setlocal iskeyword=@,48-57,_,.

function FormatRrst()
  if search('^\.\. {r', "bncW") > search('^\.\. \.\.$', "bncW")
    setlocal comments=:#',:###,:##,:#
  else
    setlocal comments=fb:*,fb:-,fb:+,n:>
  endif
  return 1
endfunction

" If you do not want 'comments' dynamically defined, put in your vimrc:
" let g:rrst_dynamic_comments = 0
if !exists("g:rrst_dynamic_comments") || (exists("g:rrst_dynamic_comments") && g:rrst_dynamic_comments == 1)
  setlocal formatexpr=FormatRrst()
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "R Source Files (*.R, *.Rnw, *.Rd, *.Rmd, *.Rrst, *.qmd)\t*.R;*.Rnw;*.Rd;*.Rmd;*.Rrst;*.qmd\n"
  if has("win32")
    let b:browsefilter .= "All Files (*.*)\t*\n"
  else
    let b:browsefilter .= "All Files (*)\t*\n"
  endif
endif

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= " | setl cms< com< fo< flp< isk< fex< | unlet! b:browsefilter"
else
  let b:undo_ftplugin = "setl cms< com< fo< flp< isk< fex< | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2
