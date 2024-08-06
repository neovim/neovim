" zip.vim: Handles browsing zipfiles
" AUTOLOAD PORTION
" Date:		Aug 05, 2024
" Version:	33
" Maintainer:	This runtime file is looking for a new maintainer.
" Former Maintainer:	Charles E Campbell
" Last Change:
" 2024 Jun 16 by Vim Project: handle whitespace on Windows properly (#14998)
" 2024 Jul 23 by Vim Project: fix 'x' command
" 2024 Jul 24 by Vim Project: use delete() function
" 2024 Jul 30 by Vim Project: fix opening remote zipfile
" 2024 Aug 04 by Vim Project: escape '[' in name of file to be extracted
" 2024 Aug 05 by Vim Project: workaround for the FreeBSD's unzip
" 2024 Aug 05 by Vim Project: clean-up and make it work with shellslash on Windows
" License:	Vim License  (see vim's :help license)
" Copyright:	Copyright (C) 2005-2019 Charles E. Campbell {{{1
"		Permission is hereby granted to use and distribute this code,
"		with or without modifications, provided that this copyright
"		notice is copied with it. Like anything else that's free,
"		zip.vim and zipPlugin.vim are provided *as is* and comes with
"		no warranty of any kind, either expressed or implied. By using
"		this plugin, you agree that in no event will the copyright
"		holder be liable for any damages resulting from the use
"		of this software.

" ---------------------------------------------------------------------
" Load Once: {{{1
if &cp || exists("g:loaded_zip")
 finish
endif
let g:loaded_zip= "v33"
if v:version < 702
 echohl WarningMsg
 echomsg "***warning*** this version of zip needs vim 7.2 or later"
 echohl Normal
 finish
endif
let s:keepcpo= &cpo
set cpo&vim

let s:zipfile_escape = ' ?&;\'
let s:ERROR          = 2
let s:WARNING        = 1
let s:NOTE           = 0

" ---------------------------------------------------------------------
"  Global Values: {{{1
if !exists("g:zip_shq")
 if &shq != ""
  let g:zip_shq= &shq
 elseif has("unix")
  let g:zip_shq= "'"
 else
  let g:zip_shq= '"'
 endif
endif
if !exists("g:zip_zipcmd")
 let g:zip_zipcmd= "zip"
endif
if !exists("g:zip_unzipcmd")
 let g:zip_unzipcmd= "unzip"
endif
if !exists("g:zip_extractcmd")
 let g:zip_extractcmd= g:zip_unzipcmd
endif

if !dist#vim#IsSafeExecutable('zip', g:zip_unzipcmd)
 echoerr "Warning: NOT executing " .. g:zip_unzipcmd .. " from current directory!"
 finish
endif

" ----------------
"  Functions: {{{1
" ----------------

" ---------------------------------------------------------------------
" zip#Browse: {{{2
fun! zip#Browse(zipfile)
  " sanity check: ensure that the zipfile has "PK" as its first two letters
  "               (zip files have a leading PK as a "magic cookie")
  if filereadable(a:zipfile) && readblob(a:zipfile, 0, 2) != 0z50.4B
   exe "noswapfile noautocmd e " .. fnameescape(a:zipfile)
   return
  endif

  let repkeep= &report
  set report=10

  " sanity checks
  if !exists("*fnameescape")
   if &verbose > 1
    echoerr "the zip plugin is not available (your vim doesn't support fnameescape())"
   endif
   return
  endif
  if !executable(g:zip_unzipcmd)
   redraw!
   echohl Error | echomsg "***error*** (zip#Browse) unzip not available on your system"
   let &report= repkeep
   return
  endif
  if !filereadable(a:zipfile)
   if a:zipfile !~# '^\a\+://'
    " if it's an url, don't complain, let url-handlers such as vim do its thing
    redraw!
    echohl Error | echomsg "***error*** (zip#Browse) File not readable<".a:zipfile.">" | echohl None
   endif
   let &report= repkeep
   return
  endif
  if &ma != 1
   set ma
  endif
  let b:zipfile= a:zipfile

  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal nobuflisted
  setlocal nowrap

  " Oct 12, 2021: need to re-use Bram's syntax/tar.vim.
  " Setting the filetype to zip doesn't do anything (currently),
  " but it is perhaps less confusing to curious perusers who do
  " a :echo &ft
  setf zip
  run! syntax/tar.vim

  " give header
  call append(0, ['" zip.vim version '.g:loaded_zip,
 \                '" Browsing zipfile '.a:zipfile,
 \                '" Select a file with cursor and press ENTER'])
  keepj $

  exe $"keepj sil r! {g:zip_unzipcmd} -Z1 -- {s:Escape(a:zipfile, 1)}"
  if v:shell_error != 0
   redraw!
   echohl WarningMsg | echomsg "***warning*** (zip#Browse) ".fnameescape(a:zipfile)." is not a zip file" | echohl None
   keepj sil! %d
   let eikeep= &ei
   set ei=BufReadCmd,FileReadCmd
   exe "keepj r ".fnameescape(a:zipfile)
   let &ei= eikeep
   keepj 1d
   return
  endif

  " Maps associated with zip plugin
  setlocal noma nomod ro
  noremap <silent> <buffer>	<cr>		:call <SID>ZipBrowseSelect()<cr>
  noremap <silent> <buffer>	x		:call zip#Extract()<cr>
  if &mouse != ""
   noremap <silent> <buffer>	<leftmouse>	<leftmouse>:call <SID>ZipBrowseSelect()<cr>
  endif

  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" ZipBrowseSelect: {{{2
fun! s:ZipBrowseSelect()
  let repkeep= &report
  set report=10
  let fname= getline(".")
  if !exists("b:zipfile")
   return
  endif

  " sanity check
  if fname =~ '^"'
   let &report= repkeep
   return
  endif
  if fname =~ '/$'
   redraw!
   echohl Error | echomsg "***error*** (zip#Browse) Please specify a file, not a directory" | echohl None
   let &report= repkeep
   return
  endif

  " get zipfile to the new-window
  let zipfile = b:zipfile
  let curfile = expand("%")

  noswapfile new
  if !exists("g:zip_nomax") || g:zip_nomax == 0
   wincmd _
  endif
  let s:zipfile_{winnr()}= curfile
  exe "noswapfile e ".fnameescape("zipfile://".zipfile.'::'.fname)
  filetype detect

  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" zip#Read: {{{2
fun! zip#Read(fname,mode)
  let repkeep= &report
  set report=10

  if has("unix")
   let zipfile = substitute(a:fname,'zipfile://\(.\{-}\)::[^\\].*$','\1','')
   let fname   = substitute(a:fname,'zipfile://.\{-}::\([^\\].*\)$','\1','')
  else
   let zipfile = substitute(a:fname,'^.\{-}zipfile://\(.\{-}\)::[^\\].*$','\1','')
   let fname   = substitute(a:fname,'^.\{-}zipfile://.\{-}::\([^\\].*\)$','\1','')
  endif
  let fname    = substitute(fname, '[', '[[]', 'g')
  " sanity check
  if !executable(substitute(g:zip_unzipcmd,'\s\+.*$','',''))
   redraw!
   echohl Error | echomsg "***error*** (zip#Read) sorry, your system doesn't appear to have the ".g:zip_unzipcmd." program" | echohl None
   let &report= repkeep
   return
  endif

  " the following code does much the same thing as
  "   exe "keepj sil! r! ".g:zip_unzipcmd." -p -- ".s:Escape(zipfile,1)." ".s:Escape(fname,1)
  " but allows zipfile://... entries in quickfix lists
  let temp = tempname()
  let fn   = expand('%:p')
  exe "sil !".g:zip_unzipcmd." -p -- ".s:Escape(zipfile,1)." ".s:Escape(fname,1).' > '.temp
  sil exe 'keepalt file '.temp
  sil keepj e!
  sil exe 'keepalt file '.fnameescape(fn)
  call delete(temp)

  filetype detect

  " cleanup
  set nomod

  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" zip#Write: {{{2
fun! zip#Write(fname)
  let repkeep= &report
  set report=10

  " sanity checks
  if !executable(substitute(g:zip_zipcmd,'\s\+.*$','',''))
   redraw!
   echohl Error | echomsg "***error*** (zip#Write) sorry, your system doesn't appear to have the ".g:zip_zipcmd." program" | echohl None
   let &report= repkeep
   return
  endif
  if !exists("*mkdir")
   redraw!
   echohl Error | echomsg "***error*** (zip#Write) sorry, mkdir() doesn't work on your system" | echohl None
   let &report= repkeep
   return
  endif

  let curdir= getcwd()
  let tmpdir= tempname()
  if tmpdir =~ '\.'
   let tmpdir= substitute(tmpdir,'\.[^.]*$','','e')
  endif
  call mkdir(tmpdir,"p")

  " attempt to change to the indicated directory
  if s:ChgDir(tmpdir,s:ERROR,"(zip#Write) cannot cd to temporary directory")
   let &report= repkeep
   return
  endif

  " place temporary files under .../_ZIPVIM_/
  if isdirectory("_ZIPVIM_")
   call delete("_ZIPVIM_", "rf")
  endif
  call mkdir("_ZIPVIM_")
  cd _ZIPVIM_

  if has("unix")
   let zipfile = substitute(a:fname,'zipfile://\(.\{-}\)::[^\\].*$','\1','')
   let fname   = substitute(a:fname,'zipfile://.\{-}::\([^\\].*\)$','\1','')
  else
   let zipfile = substitute(a:fname,'^.\{-}zipfile://\(.\{-}\)::[^\\].*$','\1','')
   let fname   = substitute(a:fname,'^.\{-}zipfile://.\{-}::\([^\\].*\)$','\1','')
  endif

  if fname =~ '/'
   let dirpath = substitute(fname,'/[^/]\+$','','e')
   if has("win32unix") && executable("cygpath")
    let dirpath = substitute(system("cygpath ".s:Escape(dirpath,0)),'\n','','e')
   endif
   call mkdir(dirpath,"p")
  endif
  if zipfile !~ '/'
   let zipfile= curdir.'/'.zipfile
  endif

  exe "w! ".fnameescape(fname)
  if has("win32unix") && executable("cygpath")
   let zipfile = substitute(system("cygpath ".s:Escape(zipfile,0)),'\n','','e')
  endif

  if (has("win32") || has("win95") || has("win64") || has("win16")) && &shell !~? 'sh$'
    let fname = substitute(fname, '[', '[[]', 'g')
  endif

  call system(g:zip_zipcmd." -u ".s:Escape(fnamemodify(zipfile,":p"),0)." ".s:Escape(fname,0))
  if v:shell_error != 0
   redraw!
   echohl Error | echomsg "***error*** (zip#Write) sorry, unable to update ".zipfile." with ".fname | echohl None

  elseif s:zipfile_{winnr()} =~ '^\a\+://'
   " support writing zipfiles across a network
   let netzipfile= s:zipfile_{winnr()}
   1split|enew
   let binkeep= &binary
   let eikeep = &ei
   set binary ei=all
   exe "noswapfile e! ".fnameescape(zipfile)
   call netrw#NetWrite(netzipfile)
   let &ei     = eikeep
   let &binary = binkeep
   q!
   unlet s:zipfile_{winnr()}
  endif

  " cleanup and restore current directory
  cd ..
  call delete("_ZIPVIM_", "rf")
  call s:ChgDir(curdir,s:WARNING,"(zip#Write) unable to return to ".curdir."!")
  call delete(tmpdir, "rf")
  setlocal nomod

  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" zip#Extract: extract a file from a zip archive {{{2
fun! zip#Extract()

  let repkeep= &report
  set report=10
  let fname= getline(".")

  " sanity check
  if fname =~ '^"'
   let &report= repkeep
   return
  endif
  if fname =~ '/$'
   redraw!
   echohl Error | echomsg "***error*** (zip#Extract) Please specify a file, not a directory" | echohl None
   let &report= repkeep
   return
  endif

  " extract the file mentioned under the cursor
  call system($"{g:zip_extractcmd} {shellescape(b:zipfile)} {shellescape(fname)}")
  if v:shell_error != 0
   echohl Error | echomsg "***error*** ".g:zip_extractcmd." ".b:zipfile." ".fname.": failed!" | echohl NONE
  elseif !filereadable(fname)
   echohl Error | echomsg "***error*** attempted to extract ".fname." but it doesn't appear to be present!"
  else
   echomsg "***note*** successfully extracted ".fname
  endif

  " restore option
  let &report= repkeep

endfun

" ---------------------------------------------------------------------
" s:Escape: {{{2
fun! s:Escape(fname,isfilt)
  if exists("*shellescape")
   if a:isfilt
    let qnameq= shellescape(a:fname,1)
   else
    let qnameq= shellescape(a:fname)
   endif
  else
   let qnameq= g:zip_shq.escape(a:fname,g:zip_shq).g:zip_shq
  endif
  if exists("+shellslash") && &shellslash && &shell =~ "cmd.exe"
   " renormalize directory separator on Windows
   let qnameq=substitute(qnameq, '/', '\\', 'g')
  endif
  return qnameq
endfun

" ---------------------------------------------------------------------
" ChgDir: {{{2
fun! s:ChgDir(newdir,errlvl,errmsg)
  try
   exe "cd ".fnameescape(a:newdir)
  catch /^Vim\%((\a\+)\)\=:E344/
   redraw!
   if a:errlvl == s:NOTE
    echomsg "***note*** ".a:errmsg
   elseif a:errlvl == s:WARNING
    echohl WarningMsg | echomsg "***warning*** ".a:errmsg | echohl NONE
   elseif a:errlvl == s:ERROR
    echohl Error | echomsg "***error*** ".a:errmsg | echohl NONE
   endif
   return 1
  endtry

  return 0
endfun

" ------------------------------------------------------------------------
" Modelines And Restoration: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" vim:ts=8 fdm=marker
