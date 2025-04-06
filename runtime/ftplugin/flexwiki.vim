" Vim filetype plugin file
" Language:     FlexWiki, http://www.flexwiki.com/
" Maintainer:   George V. Reilly  <george@reilly.org>
" Home:         http://www.georgevreilly.com/vim/flexwiki/
" Other Home:   http://www.vim.org/scripts/script.php?script_id=1529
" Author:       George V. Reilly
" Filenames:    *.wiki
" Last Change: Wed Apr 26 11:00 PM 2006 P
" Version:      0.3

if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1  " Don't load another plugin for this buffer

" Reset the following options to undo this plugin.
let b:undo_ftplugin = "setl tw< wrap< lbr< et< ts< fenc< bomb< ff<"

" Allow lines of unlimited length. Do NOT want automatic linebreaks,
" as a newline starts a new paragraph in FlexWiki.
setlocal textwidth=0
" Wrap long lines, rather than using horizontal scrolling.
setlocal wrap
" Wrap at a character in 'breakat' rather than at last char on screen
setlocal linebreak
" Don't transform <TAB> characters into spaces, as they are significant
" at the beginning of the line for numbered and bulleted lists.
setlocal noexpandtab
" 4-char tabstops, per flexwiki.el
setlocal tabstop=4
" Save *.wiki files in UTF-8
setlocal fileencoding=utf-8
" Add the UTF-8 Byte Order Mark to the beginning of the file
setlocal bomb
" Save <EOL>s as \n, not \r\n
setlocal fileformat=unix

if exists("g:flexwiki_maps")
  " Move up and down by display lines, to account for screen wrapping
  " of very long lines
  nmap <buffer> <Up>   gk
  nmap <buffer> k      gk
  vmap <buffer> <Up>   gk
  vmap <buffer> k      gk

  nmap <buffer> <Down> gj
  nmap <buffer> j      gj
  vmap <buffer> <Down> gj
  vmap <buffer> j      gj

  " for earlier versions - for when 'wrap' is set
  imap <buffer> <S-Down>   <C-o>gj
  imap <buffer> <S-Up>     <C-o>gk
  if v:version >= 700
      imap <buffer> <Down>   <C-o>gj
      imap <buffer> <Up>     <C-o>gk
  endif
endif
