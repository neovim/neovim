" Vim filetype plugin file
" Language:	C
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 22
"		2024 Jun 02 by Riley Bruins <ribru17@gmail.com> ('commentstring')
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

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

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" These options have the right value as default, but the user may have
" overruled that.
setlocal commentstring=/*\ %s\ */ define& include&

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
  if &ft == "cpp"
    let b:browsefilter = "C++ Source Files (*.cpp, *.c++)\t*.cpp;*.c++\n" ..
	  \ "C Header Files (*.h)\t*.h\n" ..
	  \ "C Source Files (*.c)\t*.c\n"
  elseif &ft == "ch"
    let b:browsefilter = "Ch Source Files (*.ch, *.chf)\t*.ch;*.chf\n" ..
	  \ "C Header Files (*.h)\t*.h\n" ..
	  \ "C Source Files (*.c)\t*.c\n"
  else
    let b:browsefilter = "C Source Files (*.c)\t*.c\n" ..
	  \ "C Header Files (*.h)\t*.h\n" ..
	  \ "Ch Source Files (*.ch, *.chf)\t*.ch;*.chf\n" ..
	  \ "C++ Source Files (*.cpp, *.c++)\t*.cpp;*.c++\n"
  endif
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let b:man_default_sects = '3,2'

let &cpo = s:cpo_save
unlet s:cpo_save
