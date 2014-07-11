" Vim filetype plugin file
" Language:	MS Message files (*.mc)
" Maintainer:	Kevin Locke <kwl7@cornell.edu>
" Last Change:	2008 April 09
" Location:	http://kevinlocke.name/programs/vim/syntax/msmessages.vim

" Based on c.vim

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Using line continuation here.
let s:cpo_save = &cpo
set cpo-=C

let b:undo_ftplugin = "setl fo< com< cms< | unlet! b:browsefilter"

" Set 'formatoptions' to format all lines, including comments
setlocal fo-=ct fo+=roql

" Comments includes both ";" which describes a "comment" which will be
" converted to C code and variants on "; //" which will remain comments
" in the generated C code
setlocal comments=:;,:;//,:;\ //,s:;\ /*\ ,m:;\ \ *\ ,e:;\ \ */
setlocal commentstring=;\ //\ %s

" Win32 can filter files in the browse dialog
if has("gui_win32") && !exists("b:browsefilter")
  let b:browsefilter = "MS Message Files (*.mc)\t*.mc\n" .
	\ "Resource Files (*.rc)\t*.rc\n" .
	\ "All Files (*.*)\t*.*\n"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
