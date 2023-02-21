" Vim filetype plugin file
" Language:    MS-DOS/Windows .bat files
" Maintainer:  Mike Williams <mrmrdubya@gmail.com>
" Last Change: 12th February 2023
"
" Options Flags:
" dosbatch_colons_comment       - any value to treat :: as comment line

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" BAT comment formatting
setlocal comments=b:rem,b:@rem,b:REM,b:@REM
if exists("dosbatch_colons_comment")
  setlocal comments+=:::
  setlocal commentstring=::\ %s
else
  setlocal commentstring=REM\ %s
endif
setlocal formatoptions-=t formatoptions+=rol

" Lookup DOS keywords using Windows command help.
if executable('help.exe')
  if has('terminal')
    setlocal keywordprg=:term\ help.exe
  else
    setlocal keywordprg=help.exe
  endif
endif

" Define patterns for the browse file filter
if has("gui_win32") && !exists("b:browsefilter")
  let b:browsefilter = "DOS Batch Files (*.bat, *.cmd)\t*.bat;*.cmd\nAll Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setlocal comments< formatoptions< keywordprg<"
    \ . "| unlet! b:browsefiler"

let &cpo = s:cpo_save
unlet s:cpo_save
