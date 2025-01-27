" zip.vim: Handles browsing zipfiles
" AUTOLOAD PORTION
" Date:		2024 Aug 21
" Version:	34
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
" 2024 Aug 18 by Vim Project: correctly handle special globbing chars
" 2024 Aug 21 by Vim Project: simplify condition to detect MS-Windows
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
let g:loaded_zip= "v34"
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

" ---------------------------------------------------------------------
"  required early
" s:Mess: {{{2
fun! s:Mess(group, msg)
  redraw!
  exe "echohl " . a:group
  echomsg a:msg
  echohl Normal
endfun

if v:version < 702
 call s:Mess('WarningMsg', "***warning*** this version of zip needs vim 7.2 or later")
 finish
endif
" sanity checks
if !executable(g:zip_unzipcmd)
 call s:Mess('Error', "***error*** (zip#Browse) unzip not available on your system")
 finish
endif
if !dist#vim#IsSafeExecutable('zip', g:zip_unzipcmd)
 call s:Mess('Error', "Warning: NOT executing " .. g:zip_unzipcmd .. " from current directory!")
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

  let dict = s:SetSaneOpts()
  defer s:RestoreOpts(dict)

  " sanity checks
  if !executable(g:zip_unzipcmd)
   call s:Mess('Error', "***error*** (zip#Browse) unzip not available on your system")
   return
  endif
  if !filereadable(a:zipfile)
   if a:zipfile !~# '^\a\+://'
    " if it's an url, don't complain, let url-handlers such as vim do its thing
    call s:Mess('Error', "***error*** (zip#Browse) File not readable <".a:zipfile.">")
   endif
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
   call s:Mess('WarningMsg', "***warning*** (zip#Browse) ".fnameescape(a:zipfile)." is not a zip file")
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

endfun

" ---------------------------------------------------------------------
" ZipBrowseSelect: {{{2
fun! s:ZipBrowseSelect()
  let dict = s:SetSaneOpts()
  defer s:RestoreOpts(dict)
  let fname= getline(".")
  if !exists("b:zipfile")
   return
  endif

  " sanity check
  if fname =~ '^"'
   return
  endif
  if fname =~ '/$'
   call s:Mess('Error', "***error*** (zip#Browse) Please specify a file, not a directory")
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

endfun

" ---------------------------------------------------------------------
" zip#Read: {{{2
fun! zip#Read(fname,mode)
  let dict = s:SetSaneOpts()
  defer s:RestoreOpts(dict)

  if has("unix")
   let zipfile = substitute(a:fname,'zipfile://\(.\{-}\)::[^\\].*$','\1','')
   let fname   = substitute(a:fname,'zipfile://.\{-}::\([^\\].*\)$','\1','')
  else
   let zipfile = substitute(a:fname,'^.\{-}zipfile://\(.\{-}\)::[^\\].*$','\1','')
   let fname   = substitute(a:fname,'^.\{-}zipfile://.\{-}::\([^\\].*\)$','\1','')
  endif
  let fname    = fname->substitute('[', '[[]', 'g')->escape('?*\\')
  " sanity check
  if !executable(substitute(g:zip_unzipcmd,'\s\+.*$','',''))
   call s:Mess('Error', "***error*** (zip#Read) sorry, your system doesn't appear to have the ".g:zip_unzipcmd." program")
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

endfun

" ---------------------------------------------------------------------
" zip#Write: {{{2
fun! zip#Write(fname)
  let dict = s:SetSaneOpts()
  defer s:RestoreOpts(dict)

  " sanity checks
  if !executable(substitute(g:zip_zipcmd,'\s\+.*$','',''))
   call s:Mess('Error', "***error*** (zip#Write) sorry, your system doesn't appear to have the ".g:zip_zipcmd." program")
   return
  endif
  if !exists("*mkdir")
   call s:Mess('Error', "***error*** (zip#Write) sorry, mkdir() doesn't work on your system")
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
   call s:Mess('Error', "***error*** (zip#Write) sorry, unable to update ".zipfile." with ".fname)

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

endfun

" ---------------------------------------------------------------------
" zip#Extract: extract a file from a zip archive {{{2
fun! zip#Extract()

  let dict = s:SetSaneOpts()
  defer s:RestoreOpts(dict)
  let fname= getline(".")

  " sanity check
  if fname =~ '^"'
   return
  endif
  if fname =~ '/$'
   call s:Mess('Error', "***error*** (zip#Extract) Please specify a file, not a directory")
   return
  endif
  if filereadable(fname)
   call s:Mess('Error', "***error*** (zip#Extract) <" .. fname .."> already exists in directory, not overwriting!")
   return
  endif
  let target = fname->substitute('\[', '[[]', 'g')
  if &shell =~ 'cmd' && has("win32")
    let target = target
		\ ->substitute('[?*]', '[&]', 'g')
		\ ->substitute('[\\]', '?', 'g')
		\ ->shellescape()
    " there cannot be a file name with '\' in its name, unzip replaces it by _
    let fname = fname->substitute('[\\?*]', '_', 'g')
  else
    let target = target->escape('*?\\')->shellescape()
  endif

  " extract the file mentioned under the cursor
  call system($"{g:zip_extractcmd} -o {shellescape(b:zipfile)} {target}")
  if v:shell_error != 0
   call s:Mess('Error', "***error*** ".g:zip_extractcmd." ".b:zipfile." ".fname.": failed!")
  elseif !filereadable(fname)
   call s:Mess('Error', "***error*** attempted to extract ".fname." but it doesn't appear to be present!")
  else
   echomsg "***note*** successfully extracted ".fname
  endif

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
  return qnameq
endfun

" ---------------------------------------------------------------------
" s:ChgDir: {{{2
fun! s:ChgDir(newdir,errlvl,errmsg)
  try
   exe "cd ".fnameescape(a:newdir)
  catch /^Vim\%((\a\+)\)\=:E344/
   redraw!
   if a:errlvl == s:NOTE
    echomsg "***note*** ".a:errmsg
   elseif a:errlvl == s:WARNING
    call s:Mess("WarningMsg", "***warning*** ".a:errmsg)
   elseif a:errlvl == s:ERROR
    call s:Mess("Error", "***error*** ".a:errmsg)
   endif
   return 1
  endtry

  return 0
endfun

" ---------------------------------------------------------------------
" s:SetSaneOpts: {{{2
fun! s:SetSaneOpts()
  let dict = {}
  let dict.report = &report
  let dict.shellslash = &shellslash

  let &report = 10
  if exists('+shellslash')
    let &shellslash = 0
  endif

  return dict
endfun

" ---------------------------------------------------------------------
" s:RestoreOpts: {{{2
fun! s:RestoreOpts(dict)
  for [key, val] in items(a:dict)
    exe $"let &{key} = {val}"
  endfor
endfun

" ------------------------------------------------------------------------
" Modelines And Restoration: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" vim:ts=8 fdm=marker
