" tar.vim: Handles browsing tarfiles -  AUTOLOAD PORTION
" Date:		Mar 01, 2025
" Version:	32b  (with modifications from the Vim Project)
" Maintainer:	This runtime file is looking for a new maintainer.
" Former Maintainer: Charles E Campbell
" License:	Vim License  (see vim's :help license)
" Last Change:
"   2024 Jan 08 by Vim Project: fix a few problems (#138331, #12637, #8109)
"   2024 Feb 19 by Vim Project: announce adoption
"   2024 Nov 11 by Vim Project: support permissions (#7379)
"   2025 Feb 06 by Vim Project: add support for lz4 (#16591)
"   2025 Feb 28 by Vim Project: add support for bzip3 (#16755)
"   2025 Mar 01 by Vim Project: fix syntax error in tar#Read()
"   2025 Mar 02 by Vim Project: escape the filename before using :read
"   2025 Mar 02 by Vim Project: determine the compression using readblob()
"                               instead of shelling out to file(1)
"   2025 Apr 16 by Vim Project: decouple from netrw by adding s:WinPath()
"   2025 May 19 by Vim Project: restore working directory after read/write
"   2025 Jul 13 by Vim Project: warn with path traversal attacks
"
"	Contains many ideas from Michael Toren's <tar.vim>
"
" Copyright:    Copyright (C) 2005-2017 Charles E. Campbell {{{1
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               tar.vim and tarPlugin.vim are provided *as is* and comes
"               with no warranty of any kind, either expressed or implied.
"               By using this plugin, you agree that in no event will the
"               copyright holder be liable for any damages resulting from
"               the use of this software.
" ---------------------------------------------------------------------
" Load Once: {{{1
if &cp || exists("g:loaded_tar")
 finish
endif
let g:loaded_tar= "v32b"
if !has('nvim-0.12') && v:version < 900
 echohl WarningMsg
 echo "***warning*** this version of tar needs vim 9.0"
 echohl Normal
 finish
endif
let s:keepcpo= &cpo
set cpo&vim

" ---------------------------------------------------------------------
"  Default Settings: {{{1
if !exists("g:tar_browseoptions")
 let g:tar_browseoptions= "tf"
endif
if !exists("g:tar_readoptions")
 let g:tar_readoptions= "pxf"
endif
if !exists("g:tar_cmd")
 let g:tar_cmd= "tar"
endif
if !exists("g:tar_writeoptions")
 let g:tar_writeoptions= "uf"
endif
if !exists("g:tar_delfile")
 " Note: not supported on BSD
 let g:tar_delfile="--delete -f"
endif
if !exists("g:netrw_cygwin")
 if has("win32") || has("win95") || has("win64") || has("win16")
  if &shell =~ '\%(\<bash\>\|\<zsh\>\)\%(\.exe\)\=$'
   let g:netrw_cygwin= 1
  else
   let g:netrw_cygwin= 0
  endif
 else
  let g:netrw_cygwin= 0
 endif
endif
if !exists("g:tar_copycmd")
 if !exists("g:netrw_localcopycmd")
  if has("win32") || has("win95") || has("win64") || has("win16")
   if g:netrw_cygwin
    let g:netrw_localcopycmd= "cp"
   else
    let g:netrw_localcopycmd= "copy"
   endif
  elseif has("unix") || has("macunix")
   let g:netrw_localcopycmd= "cp"
  else
   let g:netrw_localcopycmd= ""
  endif
 endif
 let g:tar_copycmd= g:netrw_localcopycmd
endif
if !exists("g:tar_extractcmd")
 let g:tar_extractcmd= "tar -pxf"
endif

" set up shell quoting character
if !exists("g:tar_shq")
 if exists("+shq") && exists("&shq") && &shq != ""
  let g:tar_shq= &shq
 elseif has("win32") || has("win95") || has("win64") || has("win16")
  if exists("g:netrw_cygwin") && g:netrw_cygwin
   let g:tar_shq= "'"
  else
   let g:tar_shq= '"'
  endif
 else
  let g:tar_shq= "'"
 endif
endif

let g:tar_secure=' -- '
let g:tar_leading_pat='^\%([.]\{,2\}/\)\+'

" ----------------
"  Functions: {{{1
" ----------------

" ---------------------------------------------------------------------
" s:Msg: {{{2
fun! s:Msg(func, severity, msg)
  redraw!
  if a:severity =~? 'error'
    echohl Error 
  else
    echohl WarningMsg
  endif
  echo $"***{a:severity}*** ({a:func}) {a:msg}"
  echohl None
endfunc

" ---------------------------------------------------------------------
" tar#Browse: {{{2
fun! tar#Browse(tarfile)
  let repkeep= &report
  set report=10

  " sanity checks
  if !executable(g:tar_cmd)
   call s:Msg('tar#Browse', 'error', $"{g:tar_cmd} not available on your system")
   let &report= repkeep
   return
  endif
  if !filereadable(a:tarfile)
   if a:tarfile !~# '^\a\+://'
    " if it's an url, don't complain, let url-handlers such as vim do its thing
    call s:Msg('tar#Browse', 'error', $"File not readable<{a:tarfile}>")
   endif
   let &report= repkeep
   return
  endif
  if &ma != 1
   set ma
  endif
  let b:tarfile= a:tarfile

  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal nobuflisted
  setlocal nowrap
  set ft=tar

  " give header
  let lastline= line("$")
  call setline(lastline+1,'" tar.vim version '.g:loaded_tar)
  call setline(lastline+2,'" Browsing tarfile '.a:tarfile)
  call setline(lastline+3,'" Select a file with cursor and press ENTER, "x" to extract a file')
  keepj $put =''
  keepj sil! 0d
  keepj $

  let tarfile= a:tarfile
  if has("win32unix") && executable("cygpath")
   " assuming cygwin
   let tarfile=substitute(system("cygpath -u ".shellescape(tarfile,0)),'\n$','','e')
  endif
  let curlast= line("$")

  if tarfile =~# '\.\(gz\)$'
   exe "sil! r! gzip -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "

  elseif tarfile =~# '\.\(tgz\)$' || tarfile =~# '\.\(tbz\)$' || tarfile =~# '\.\(txz\)$' ||
                          \ tarfile =~# '\.\(tzst\)$' || tarfile =~# '\.\(tlz4\)$'
   let header= s:Header(tarfile)

   if header =~? 'bzip2'
    exe "sil! r! bzip2 -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   elseif header =~? 'bzip3'
    exe "sil! r! bzip3 -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   elseif header =~? 'xz'
    exe "sil! r! xz -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   elseif header =~? 'zstd'
    exe "sil! r! zstd --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   elseif header =~? 'lz4'
    exe "sil! r! lz4 --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   elseif header =~? 'gzip'
    exe "sil! r! gzip -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   endif

  elseif tarfile =~# '\.lrp'
   exe "sil! r! cat -- ".shellescape(tarfile,1)."|gzip -d -c -|".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.\(bz2\|tbz\|tb2\)$'
   exe "sil! r! bzip2 -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.\(bz3\|tb3\)$'
   exe "sil! r! bzip3 -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.\(lzma\|tlz\)$'
   exe "sil! r! lzma -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.\(xz\|txz\)$'
   exe "sil! r! xz --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.\(zst\|tzst\)$'
   exe "sil! r! zstd --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.\(lz4\|tlz4\)$'
   exe "sil! r! lz4 --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  else
   if tarfile =~ '^\s*-'
    " A file name starting with a dash is taken as an option.  Prepend ./ to avoid that.
    let tarfile = substitute(tarfile, '-', './-', '')
   endif
   exe "sil! r! ".g:tar_cmd." -".g:tar_browseoptions." ".shellescape(tarfile,1)
  endif
  if v:shell_error != 0
   call s:Msg('tar#Browse', 'warning', $"please check your g:tar_browseoptions '<{g:tar_browseoptions}>'")
   return
  endif

  " remove tar: Removing leading '/' from member names
  " Note: the message could be localized
  if search('^tar: ') > 0 || search(g:tar_leading_pat) > 0
    call append(3,'" Note: Path Traversal Attack detected!')
    let b:leading_slash = 1
    " remove the message output
    sil g/^tar: /d
  endif

  " set up maps supported for tar
  setlocal noma nomod ro
  noremap <silent> <buffer>	<cr>		:call <SID>TarBrowseSelect()<cr>
  noremap <silent> <buffer>	x	 	:call tar#Extract()<cr>
  if &mouse != ""
   noremap <silent> <buffer>	<leftmouse>	<leftmouse>:call <SID>TarBrowseSelect()<cr>
  endif

  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" TarBrowseSelect: {{{2
fun! s:TarBrowseSelect()
  let repkeep= &report
  set report=10
  let fname= getline(".")
  let ls= get(b:, 'leading_slash', 0)

  " sanity check
  if fname =~ '^"'
   let &report= repkeep
   return
  endif

  " about to make a new window, need to use b:tarfile
  let tarfile= b:tarfile
  let curfile= expand("%")
  if has("win32unix") && executable("cygpath")
   " assuming cygwin
   let tarfile=substitute(system("cygpath -u ".shellescape(tarfile,0)),'\n$','','e')
  endif

  " open a new window (tar#Read will read a file into it)
  noswapfile new
  if !exists("g:tar_nomax") || g:tar_nomax == 0
   wincmd _
  endif
  let s:tblfile_{winnr()}= curfile
  let b:leading_slash= ls
  call tar#Read("tarfile:".tarfile.'::'.fname)
  filetype detect
  set nomod
  exe 'com! -buffer -nargs=? -complete=file TarDiff	:call tar#Diff(<q-args>,"'.fnameescape(fname).'")'

  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" tar#Read: {{{2
fun! tar#Read(fname)
  let repkeep= &report
  set report=10
  let tarfile = substitute(a:fname,'tarfile:\(.\{-}\)::.*$','\1','')
  let fname   = substitute(a:fname,'tarfile:.\{-}::\(.*\)$','\1','')
  " be careful not to execute special crafted files
  let escape_file = fname->substitute(g:tar_leading_pat, '', '')->fnameescape()

  let curdir= getcwd()
  let b:curdir= curdir
  let tmpdir= tempname()
  let b:tmpdir= tmpdir
  if tmpdir =~ '\.'
   let tmpdir= substitute(tmpdir,'\.[^.]*$','','e')
  endif
  call mkdir(tmpdir,"p")

  " attempt to change to the indicated directory
  try
   exe "lcd ".fnameescape(tmpdir)
  catch /^Vim\%((\a\+)\)\=:E344/
   call s:Msg('tar#Read', 'error', "cannot lcd to temporary directory")
   let &report= repkeep
   return
  endtry

  " place temporary files under .../_ZIPVIM_/
  if isdirectory("_ZIPVIM_")
   call s:Rmdir("_ZIPVIM_")
  endif
  call mkdir("_ZIPVIM_")
  lcd _ZIPVIM_

  if has("win32unix") && executable("cygpath")
   " assuming cygwin
   let tarfile=substitute(system("cygpath -u ".shellescape(tarfile,0)),'\n$','','e')
  endif

  if  fname =~ '\.bz2$' && executable("bzcat")
   let decmp= "|bzcat"
   let doro = 1
  elseif  fname =~ '\.bz3$' && executable("bz3cat")
   let decmp= "|bz3cat"
   let doro = 1
  elseif  fname =~ '\.t\=gz$'  && executable("zcat")
   let decmp= "|zcat"
   let doro = 1
  elseif  fname =~ '\.lzma$' && executable("lzcat")
   let decmp= "|lzcat"
   let doro = 1
  elseif  fname =~ '\.xz$' && executable("xzcat")
   let decmp= "|xzcat"
   let doro = 1
  elseif  fname =~ '\.zst$' && executable("zstdcat")
   let decmp= "|zstdcat"
   let doro = 1
  elseif  fname =~ '\.lz4$' && executable("lz4cat")
   let decmp= "|lz4cat"
   let doro = 1
  else
   let decmp=""
   let doro = 0
   if fname =~ '\.bz2$\|\.bz3$\|\.gz$\|\.lzma$\|\.xz$\|\.zip$\|\.Z$'
    setlocal bin
   endif
  endif


  if tarfile =~# '\.bz2$'
   exe "sil! r! bzip2 -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
   exe "read ".escape_file
  elseif tarfile =~# '\.bz3$'
   exe "sil! r! bzip3 -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
   exe "read ".escape_file
  elseif tarfile =~# '\.\(gz\)$'
   exe "sil! r! gzip -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
   exe "read ".escape_file
  elseif tarfile =~# '\(\.tgz\|\.tbz\|\.txz\)'
   let filekind= s:Header(tarfile)
   if filekind =~? "bzip2"
    exe "sil! r! bzip2 -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
    exe "read ".escape_file
   elseif filekind =~ "bzip3"
    exe "sil! r! bzip3 -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
    exe "read ".escape_file
   elseif filekind =~? "xz"
    exe "sil! r! xz -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
    exe "read ".escape_file
   elseif filekind =~? "zstd"
    exe "sil! r! zstd --decompress --stdout -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
    exe "read ".escape_file
   elseif filekind =~? "gzip"
    exe "sil! r! gzip -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
    exe "read ".escape_file
   endif

  elseif tarfile =~# '\.lrp$'
   exe "sil! r! cat -- ".shellescape(tarfile,1)." | gzip -d -c - | ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
   exe "read ".escape_file
  elseif tarfile =~# '\.lzma$'
   exe "sil! r! lzma -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
   exe "read ".escape_file
  elseif tarfile =~# '\.\(xz\|txz\)$'
   exe "sil! r! xz --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
   exe "read ".escape_file
  elseif tarfile =~# '\.\(lz4\|tlz4\)$'
   exe "sil! r! lz4 --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_readoptions." - ".g:tar_secure.shellescape(fname,1).decmp
   exe "read ".escape_file
  else
   if tarfile =~ '^\s*-'
    " A file name starting with a dash is taken as an option.  Prepend ./ to avoid that.
    let tarfile = substitute(tarfile, '-', './-', '')
   endif
   exe "silent r! ".g:tar_cmd." -".g:tar_readoptions.shellescape(tarfile,1)." ".g:tar_secure.shellescape(fname,1).decmp
   exe "read ".escape_file
  endif
  if get(b:, 'leading_slash', 0)
    sil g/^tar: /d
  endif

   redraw!

  if v:shell_error != 0
   lcd ..
   call s:Rmdir("_ZIPVIM_")
   exe "lcd ".fnameescape(curdir)
   call s:Msg('tar#Read', 'error', $"sorry, unable to open or extract {tarfile} with {fname}")
  endif

  if doro
   " because the reverse process of compressing changed files back into the tarball is not currently supported
   setlocal ro
  endif

  let b:tarfile= a:fname

  " cleanup
  keepj sil! 0d
  set nomod

  let &report= repkeep
  exe "lcd ".fnameescape(curdir)
  silent exe "file tarfile::". fname->fnameescape()
endfun

" ---------------------------------------------------------------------
" tar#Write: {{{2
fun! tar#Write(fname)
  let pwdkeep= getcwd()
  let repkeep= &report
  set report=10
  let curdir= b:curdir
  let tmpdir= b:tmpdir

  " sanity checks
  if !executable(g:tar_cmd)
   redraw!
   let &report= repkeep
   return
  endif
  let tarfile = substitute(b:tarfile,'tarfile:\(.\{-}\)::.*$','\1','')
  let fname   = substitute(b:tarfile,'tarfile:.\{-}::\(.*\)$','\1','')

  if get(b:, 'leading_slash', 0)
   call s:Msg('tar#Write', 'error', $"sorry, not attempting to update {tarfile} with {fname}")
   let &report= repkeep
   return
  endif

  if !isdirectory(fnameescape(tmpdir))
    call mkdir(fnameescape(tmpdir), 'p')
  endif
  exe $"lcd {fnameescape(tmpdir)}"
  if isdirectory("_ZIPVIM_")
    call s:Rmdir("_ZIPVIM_")
  endif
  call mkdir("_ZIPVIM_")
  lcd _ZIPVIM_
  let dir = fnamemodify(fname, ':p:h')
  if dir !~# '_ZIPVIM_$'
    call mkdir(dir)
  endif

  " handle compressed archives
  if tarfile =~# '\.bz2'
   call system("bzip2 -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.bz2','','e')
   let compress= "bzip2 -- ".shellescape(tarfile,0)
  elseif tarfile =~# '\.bz3'
   call system("bzip3 -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.bz3','','e')
   let compress= "bzip3 -- ".shellescape(tarfile,0)
  elseif tarfile =~# '\.gz'
   call system("gzip -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.gz','','e')
   let compress= "gzip -- ".shellescape(tarfile,0)
  elseif tarfile =~# '\.tgz'
   call system("gzip -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.tgz','.tar','e')
   let compress= "gzip -- ".shellescape(tarfile,0)
   let tgz     = 1
  elseif tarfile =~# '\.xz'
   call system("xz -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.xz','','e')
   let compress= "xz -- ".shellescape(tarfile,0)
  elseif tarfile =~# '\.zst'
   call system("zstd --decompress --rm -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.zst','','e')
   let compress= "zstd --rm -- ".shellescape(tarfile,0)
  elseif tarfile =~# '\.lz4'
   call system("lz4 --decompress --rm -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.lz4','','e')
   let compress= "lz4 --rm -- ".shellescape(tarfile,0)
  elseif tarfile =~# '\.lzma'
   call system("lzma -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.lzma','','e')
   let compress= "lzma -- ".shellescape(tarfile,0)
  endif
  " Note: no support for name.tar.tbz/.txz/.tgz/.tlz4/.tzst

  if v:shell_error != 0
   call s:Msg('tar#Write', 'error', $"sorry, unable to update {tarfile} with {fname}")
  else

   if fname =~ '/'
    let dirpath = substitute(fname,'/[^/]\+$','','e')
    if has("win32unix") && executable("cygpath")
     let dirpath = substitute(system("cygpath ".shellescape(dirpath, 0)),'\n','','e')
    endif
    call mkdir(dirpath,"p")
   endif
   if tarfile !~ '/'
    let tarfile= curdir.'/'.tarfile
   endif
   if tarfile =~ '^\s*-'
    " A file name starting with a dash may be taken as an option.  Prepend ./ to avoid that.
    let tarfile = substitute(tarfile, '-', './-', '')
   endif

   " don't overwrite a file forcefully
   exe "w ".fnameescape(fname)
   if has("win32unix") && executable("cygpath")
    let tarfile = substitute(system("cygpath ".shellescape(tarfile,0)),'\n','','e')
   endif

   " delete old file from tarfile
   " Note: BSD tar does not support --delete flag
   call system(g:tar_cmd." ".g:tar_delfile." ".shellescape(tarfile,0).g:tar_secure.shellescape(fname,0))
   if v:shell_error != 0
    call s:Msg('tar#Write', 'error', $"sorry, unable to update {fnameescape(tarfile)} with {fnameescape(fname)} --delete not supported?")
   else
    " update tarfile with new file
    call system(g:tar_cmd." -".g:tar_writeoptions." ".shellescape(tarfile,0).g:tar_secure.shellescape(fname,0))
    if v:shell_error != 0
     call s:Msg('tar#Write', 'error', $"sorry, unable to update {fnameescape(tarfile)} with {fnameescape(fname)}")
    elseif exists("compress")
     call system(compress)
     if exists("tgz")
      call rename(tarfile.".gz",substitute(tarfile,'\.tar$','.tgz','e'))
     endif
    endif
   endif

   " support writing tarfiles across a network
   if s:tblfile_{winnr()} =~ '^\a\+://'
    let tblfile= s:tblfile_{winnr()}
    1split|noswapfile enew
    let binkeep= &l:binary
    let eikeep = &ei
    set binary ei=all
    exe "noswapfile e! ".fnameescape(tarfile)
    call netrw#NetWrite(tblfile)
    let &ei       = eikeep
    let &l:binary = binkeep
    q!
    unlet s:tblfile_{winnr()}
   endif
  endif

  " cleanup and restore current directory
  lcd ..
  call s:Rmdir("_ZIPVIM_")
  exe "lcd ".fnameescape(pwdkeep)
  setlocal nomod

  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" tar#Diff: {{{2
fun! tar#Diff(userfname,fname)
  let fname= a:fname
  if a:userfname != ""
   let fname= a:userfname
  endif
  exe "lcd ".fnameescape(b:tmpdir). '/_ZIPVIM_'
  if filereadable(fname)
   " sets current file (from tarball) for diff'ing
   " splits window vertically
   " opens original file, sets it for diff'ing
   " sets up b:tardiff_otherbuf variables so each buffer knows about the other (for closing purposes)
   diffthis
   wincmd v
   exe "noswapfile e ".fnameescape(fname)
   diffthis
  else
   redraw!
   echo "***warning*** unable to read file<".fname.">"
  endif
endfun

" ---------------------------------------------------------------------
" tar#Extract: extract a file from a (possibly compressed) tar archive {{{2
fun! tar#Extract()

  let repkeep= &report
  set report=10
  let fname= getline(".")

  " sanity check
  if fname =~ '^"'
   let &report= repkeep
   return
  endif

  let tarball = expand("%")
  let tarbase = substitute(tarball,'\..*$','','')

  let extractcmd= s:WinPath(g:tar_extractcmd)
  if filereadable(tarbase.".tar")
   call system(extractcmd." ".shellescape(tarbase).".tar ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tar {fname}: failed!")
   else
    echo "***note*** successfully extracted ". fname
   endif

  elseif filereadable(tarbase.".tgz")
   let extractcmd= substitute(extractcmd,"-","-z","")
   call system(extractcmd." ".shellescape(tarbase).".tgz ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tgz {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.gz")
   let extractcmd= substitute(extractcmd,"-","-z","")
   call system(extractcmd." ".shellescape(tarbase).".tar.gz ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tar.gz {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tbz")
   let extractcmd= substitute(extractcmd,"-","-j","")
   call system(extractcmd." ".shellescape(tarbase).".tbz ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tbz {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.bz2")
   let extractcmd= substitute(extractcmd,"-","-j","")
   call system(extractcmd." ".shellescape(tarbase).".tar.bz2 ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tar.bz2 {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.bz3")
   let extractcmd= substitute(extractcmd,"-","-j","")
   call system(extractcmd." ".shellescape(tarbase).".tar.bz3 ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tar.bz3 {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".txz")
   let extractcmd= substitute(extractcmd,"-","-J","")
   call system(extractcmd." ".shellescape(tarbase).".txz ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.txz {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.xz")
   let extractcmd= substitute(extractcmd,"-","-J","")
   call system(extractcmd." ".shellescape(tarbase).".tar.xz ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tar.xz {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tzst")
   let extractcmd= substitute(extractcmd,"-","--zstd","")
   call system(extractcmd." ".shellescape(tarbase).".tzst ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tzst {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.zst")
   let extractcmd= substitute(extractcmd,"-","--zstd","")
   call system(extractcmd." ".shellescape(tarbase).".tar.zst ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tar.zst {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tlz4")
   let extractcmd= substitute(extractcmd,"-","-I lz4","")
   call system(extractcmd." ".shellescape(tarbase).".tlz4 ".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tlz4 {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.lz4")
   let extractcmd= substitute(extractcmd,"-","-I lz4","")
   call system(extractcmd." ".shellescape(tarbase).".tar.lz4".shellescape(fname))
   if v:shell_error != 0
    call s:Msg('tar#Extract', 'error', $"{extractcmd} {tarbase}.tar.lz4 {fname}: failed!")
   else
    echo "***note*** successfully extracted ".fname
   endif
  endif

  " restore option
  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" s:Rmdir: {{{2
fun! s:Rmdir(fname)
  call delete(a:fname, 'rf')
endfun

" s:FileHeader: {{{2
fun! s:Header(fname)
  let header= readblob(a:fname, 0, 6)
  " Nvim: see https://github.com/neovim/neovim/pull/34968
  if header[0:2] == 0z425A68 " bzip2 header
    return "bzip2"
  elseif header[0:2] == 0z425A33 " bzip3 header
    return "bzip3"
  elseif header == 0zFD377A58.5A00 " xz header
    return "xz"
  elseif header[0:3] == 0z28B52FFD " zstd header
    return "zstd"
  elseif header[0:3] == 0z04224D18 " lz4 header
    return "lz4"
  elseif (header[0:1] == 0z1F9D ||
       \  header[0:1] == 0z1F8B ||
       \  header[0:1] == 0z1F9E ||
       \  header[0:1] == 0z1FA0 ||
       \  header[0:1] == 0z1F1E)
    return "gzip"
  endif
  return "unknown"
endfun

" ---------------------------------------------------------------------
" s:WinPath: {{{2
fun! s:WinPath(path)
  if (!g:netrw_cygwin || &shell !~ '\%(\<bash\>\|\<zsh\>\)\%(\.exe\)\=$') && has("win32")
    " remove cygdrive prefix, if present
    let path = substitute(a:path, '/cygdrive/\(.\)', '\1:', '')
    " remove trailing slash (Win95)
    let path = substitute(path, '\(\\\|/\)$', '', 'g')
    " remove escaped spaces
    let path = substitute(path, '\ ', ' ', 'g')
    " convert slashes to backslashes
    let path = substitute(path, '/', '\', 'g')
  else
    let path = a:path
  endif

  return path
endfun

" =====================================================================
" Modelines And Restoration: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" vim:ts=8 fdm=marker
