" Vim filetype plugin file
" Language:	Slang
" Maintainer:	Austin Shijo <epestr@proton.me>
" Last Change:	2025 Jan 05

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Using line continuation here.
let s:cpo_save = &cpo
set cpo-=C

let b:undo_ftplugin = "setl fo< com< cms< inc<"

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" Set comment string (Slang uses C-style comments)
setlocal commentstring=//\ %s

" Set 'comments' to format dashed lists in comments
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://

" When the matchit plugin is loaded, this makes the % command skip parens and
" braces in comments properly, and adds support for shader-specific keywords
if exists("loaded_matchit")
  " Add common shader control structures
  let b:match_words = '{\|^\s*\<\(if\|for\|while\|switch\|struct\|class\)\>:}\|^\s*\<break\>,' ..
        \ '^\s*#\s*if\(\|def\|ndef\)\>:^\s*#\s*elif\>:^\s*#\s*else\>:^\s*#\s*endif\>,' ..
        \ '\[:\]'
  let b:match_skip = 's:comment\|string\|character\|special'
  let b:match_ignorecase = 0
  let b:undo_ftplugin ..= " | unlet! b:match_skip b:match_words b:match_ignorecase"
endif

" Win32 and GTK can filter files in the browse dialog
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Slang Source Files (*.slang)\t*.slang\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
