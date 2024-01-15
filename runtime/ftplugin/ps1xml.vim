" Vim filetype plugin file
" Language:    Windows PowerShell
" URL:         https://github.com/PProvost/vim-ps1
" Last Change: 2021 Apr 02
"              2024 Jan 14 by Vim Project (browsefilter)

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin") | finish | endif

" Don't load another plug-in for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal tw=0
setlocal commentstring=#%s
setlocal formatoptions=tcqro

" Change the browse dialog on Win32 and GTK to show mainly PowerShell-related files
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = 
        \ "All PowerShell Files (*.ps1, *.psd1, *.psm1, *.ps1xml)\t*.ps1;*.psd1;*.psm1;*.ps1xml\n" .
        \ "PowerShell Script Files (*.ps1)\t*.ps1\n" .
        \ "PowerShell Module Files (*.psd1, *.psm1)\t*.psd1;*.psm1\n" .
        \ "PowerShell XML Files (*.ps1xml)\t*.ps1xml\n"
  if has("win32")
    let b:browsefilter .= "All Files (*.*)\t*\n"
  else
    let b:browsefilter .= "All Files (*)\t*\n"
  endif
endif

" Undo the stuff we changed
let b:undo_ftplugin = "setlocal tw< cms< fo<" .
      \ " | unlet! b:browsefilter"

let &cpo = s:cpo_save
unlet s:cpo_save
