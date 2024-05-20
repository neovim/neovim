" Vim filetype plugin file
" Language:	Arduino
" Maintainer:	The Vim Project <https://github.com/vim/vim>
"		Ken Takata <https://github.com/k-takata>
" Last Change:	2024 Apr 12
"
" Most of the part was copied from c.vim.

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Using line continuation here.
let s:cpo_save = &cpo
set cpo-=C

let b:undo_ftplugin = "setl fo< com< ofu< cms< def< inc<"

if !exists("g:arduino_recommended_style") || g:arduino_recommended_style != 0
  " Use the default setting of Arduino IDE.
  setlocal expandtab tabstop=2 softtabstop=2 shiftwidth=2
  let b:undo_ftplugin ..= " et< ts< sts< sw<"
endif

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" These options have the right value as default, but the user may have
" overruled that.
setlocal commentstring& define& include&

" Set completion with CTRL-X CTRL-O to autoloaded function.
if exists('&ofu')
  setlocal ofu=ccomplete#Complete
endif

" Set 'comments' to format dashed lists in comments.
" Also include ///, used for Doxygen.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://

" When the matchit plugin is loaded, this makes the % command skip parens and
" braces in comments properly.
if !exists("b:match_words")
  let b:match_words = '^\s*#\s*if\(\|def\|ndef\)\>:^\s*#\s*elif\>:^\s*#\s*else\>:^\s*#\s*endif\>'
  let b:match_skip = 's:comment\|string\|character\|special'
  let b:undo_ftplugin ..= " | unlet! b:match_skip b:match_words"
endif

" Win32 and GTK can filter files in the browse dialog
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Arduino Source Files (*.ino, *.pde)\t*.ino;*.pde\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
