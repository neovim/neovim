" Vim filetype plugin file
" Language:		Rnoweb
" Maintainer:		This runtime file is looking for a new maintainer.
" Former Maintainer:	Jakson Alves de Aquino <jalvesaq@gmail.com>
" Former Repository:	https://github.com/jalvesaq/R-Vim-runtime
" Last Change:		2024 Feb 28 by Vim Project

" Only do this when not yet done for this buffer
if exists("b:did_ftplugin")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

runtime! ftplugin/tex.vim

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Enables Vim-Latex-Suite, LaTeX-Box if installed
runtime ftplugin/tex_*.vim

setlocal iskeyword=@,48-57,_,.
setlocal suffixesadd=.bib,.tex
setlocal comments=b:%,b:#,b:##,b:###,b:#'

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "R Source Files (*.R, *.Rnw, *.Rd, *.Rmd, *.Rrst, *.qmd)\t*.R;*.Rnw;*.Rd;*.Rmd;*.Rrst;*.qmd\n"
  if has("win32")
    let b:browsefilter .= "All Files (*.*)\t*\n"
  else
    let b:browsefilter .= "All Files (*)\t*\n"
  endif
endif

function SetRnwCommentStr()
    if (search("^\s*<<.*>>=", "bncW") > search("^@", "bncW"))
        set commentstring=#\ %s
    else
        set commentstring=%\ %s
    endif
endfunction

" If you do not want both 'comments' and 'commentstring' dynamically defined,
" put in your vimrc: let g:rnw_dynamic_comments = 0
if !exists("g:rnw_dynamic_comments") || (exists("g:rnw_dynamic_comments") && g:rnw_dynamic_comments == 1)
  augroup RnwCStr
    autocmd!
    autocmd CursorMoved <buffer> call SetRnwCommentStr()
  augroup END
endif

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= " | setl isk< sua< com< cms< | unlet! b:browsefilter"
else
  let b:undo_ftplugin = "setl isk< sua< com< cms< | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2
