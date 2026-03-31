" Vim filetype plugin file
" Language:             Sieve filtering language input file
" Maintainer:           This runtime file is looking for a new maintainer.
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2025 Feb 20
" 2026 Jan 09 by Vim Project: preserve line endings for existing files #19144

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl com< cms< fo< ff<"

setlocal comments=s1:/*,mb:*,ex:*/,:# commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

" https://datatracker.ietf.org/doc/html/rfc5228#section-2.2 says
" "newlines (CRLF, never just CR or LF)"
" Use CRLF for new files only; preserve existing line endings
if expand('%:p') !=# '' && !filereadable(expand('%:p'))
  setlocal fileformat=dos
endif
