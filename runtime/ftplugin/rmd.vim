" Vim filetype plugin file
" Language:		R Markdown file
" Maintainer:		This runtime file is looking for a new maintainer.
" Former Maintainer:	Jakson Alves de Aquino <jalvesaq@gmail.com>
" Former Repository:	https://github.com/jalvesaq/R-Vim-runtime
" Last Change:
"  2024 Feb 28 by Vim Project
"  2024 Sep 23 by Vim Project: properly restore fex option
" Original work by Alex Zvoleff (adjusted from R help for rmd by Michel Kuhlmann)

" Only do this when not yet done for this buffer
if exists("b:did_ftplugin")
  finish
endif

if exists('g:rmd_include_html') && g:rmd_include_html
  runtime! ftplugin/html.vim ftplugin/html_*.vim ftplugin/html/*.vim
endif

setlocal comments=fb:*,fb:-,fb:+,n:>
setlocal commentstring=#\ %s
setlocal formatoptions+=tcqln
setlocal formatlistpat=^\\s*\\d\\+\\.\\s\\+\\\|^\\s*[-*+]\\s\\+
setlocal iskeyword=@,48-57,_,.

let s:cpo_save = &cpo
set cpo&vim

function FormatRmd()
  if search("^[ \t]*```[ ]*{r", "bncW") > search("^[ \t]*```$", "bncW")
    setlocal comments=:#',:###,:##,:#
  else
    setlocal comments=fb:*,fb:-,fb:+,n:>
  endif
  return 1
endfunction

let s:last_line = 0
function SetRmdCommentStr()
  if line('.') == s:last_line
    return
  endif
  let s:last_line = line('.')

  if (search("^[ \t]*```[ ]*{r", "bncW") > search("^[ \t]*```$", "bncW")) || ((search('^---$', 'Wn') || search('^\.\.\.$', 'Wn')) && search('^---$', 'bnW'))
    set commentstring=#\ %s
  else
    set commentstring=<!--\ %s\ -->
  endif
endfunction

" If you do not want both 'comments' and 'commentstring' dynamically defined,
" put in your vimrc: let g:rmd_dynamic_comments = 0
if !exists("g:rmd_dynamic_comments") || (exists("g:rmd_dynamic_comments") && g:rmd_dynamic_comments == 1)
  setlocal formatexpr=FormatRmd()
  augroup RmdCStr
    autocmd!
    autocmd CursorMoved <buffer> call SetRmdCommentStr()
  augroup END
endif

" Enables pandoc if it is installed
unlet! b:did_ftplugin
runtime ftplugin/pandoc.vim

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

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
