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
if v:version < 702
 echohl WarningMsg
 echo "***warning*** this version of tar needs vim 7.2"
 echohl Normal
 finish
endif
let s:keepcpo= &cpo
set cpo&vim

" ---------------------------------------------------------------------
"  Default Settings: {{{1
if !exists("g:tar_browseoptions")
 let g:tar_browseoptions= "Ptf"
endif
if !exists("g:tar_readoptions")
 let g:tar_readoptions= "pPxf"
endif
if !exists("g:tar_cmd")
 let g:tar_cmd= "tar"
endif
if !exists("g:tar_writeoptions")
 let g:tar_writeoptions= "uf"
endif
if !exists("g:tar_delfile")
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

" ----------------
"  Functions: {{{1
" ----------------

" ---------------------------------------------------------------------
" tar#Browse: {{{2
fun! tar#Browse(tarfile)
  let repkeep= &report
  set report=10

  " sanity checks
  if !executable(g:tar_cmd)
   redraw!
   echohl Error | echo '***error*** (tar#Browse) "'.g:tar_cmd.'" not available on your system'
   let &report= repkeep
   return
  endif
  if !filereadable(a:tarfile)
   if a:tarfile !~# '^\a\+://'
    " if it's an url, don't complain, let url-handlers such as vim do its thing
    redraw!
    echohl Error | echo "***error*** (tar#Browse) File not readable<".a:tarfile.">" | echohl None
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
  call setline(lastline+3,'" Select a file with cursor and press ENTER')
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
   if has("unix") && executable("file")
    let filekind= system("file ".shellescape(tarfile,1))
   else
    let filekind= ""
   endif

   if filekind =~ "bzip2"
    exe "sil! r! bzip2 -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   elseif filekind =~ "bzip3"
    exe "sil! r! bzip3 -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   elseif filekind =~ "XZ"
    exe "sil! r! xz -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   elseif filekind =~ "Zstandard"
    exe "sil! r! zstd --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   elseif filekind =~ "LZ4"
    exe "sil! r! lz4 --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
   else
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
   redraw!
   echohl WarningMsg | echo "***warning*** (tar#Browse) please check your g:tar_browseoptions<".g:tar_browseoptions.">"
   return
  endif
  "
  " The following should not be neccessary, since in case of errors the
  " previous if statement should have caught the problem (because tar exited
  " with a non-zero exit code).
  " if line("$") == curlast || ( line("$") == (curlast + 1) &&
  "       \ getline("$") =~# '\c\<\%(warning\|error\|inappropriate\|unrecognized\)\>' &&
  "       \ getline("$") =~  '\s' )
  "  redraw!
  "  echohl WarningMsg | echo "***warning*** (tar#Browse) ".a:tarfile." doesn't appear to be a tar file" | echohl None
  "  keepj sil! %d
  "  let eikeep= &ei
  "  set ei=BufReadCmd,FileReadCmd
  "  exe "r ".fnameescape(a:tarfile)
  "  let &ei= eikeep
  "  keepj sil! 1d
  "   call Dret("tar#Browse : a:tarfile<".a:tarfile.">")
  "  return
  " endif

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

  if !exists("g:tar_secure") && fname =~ '^\s*-\|\s\+-'
   redraw!
   echohl WarningMsg | echo '***warning*** (tar#BrowseSelect) rejecting tarfile member<'.fname.'> because of embedded "-"'
   return
  endif

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
  call tar#Read("tarfile:".tarfile.'::'.fname,1)
  filetype detect
  set nomod
  exe 'com! -buffer -nargs=? -complete=file TarDiff	:call tar#Diff(<q-args>,"'.fnameescape(fname).'")'

  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" tar#Read: {{{2
fun! tar#Read(fname,mode)
  let repkeep= &report
  set report=10
  let tarfile = substitute(a:fname,'tarfile:\(.\{-}\)::.*$','\1','')
  let fname   = substitute(a:fname,'tarfile:.\{-}::\(.*\)$','\1','')

  " changing the directory to the temporary earlier to allow tar to extract the file with permissions intact
  if !exists("*mkdir")
   redraw!
   echohl Error | echo "***error*** (tar#Write) sorry, mkdir() doesn't work on your system" | echohl None
   let &report= repkeep
   return
  endif

  let curdir= getcwd()
  let tmpdir= tempname()
  let b:curdir= tmpdir
  let b:tmpdir= curdir
  if tmpdir =~ '\.'
   let tmpdir= substitute(tmpdir,'\.[^.]*$','','e')
  endif
  call mkdir(tmpdir,"p")

  " attempt to change to the indicated directory
  try
   exe "cd ".fnameescape(tmpdir)
  catch /^Vim\%((\a\+)\)\=:E344/
   redraw!
   echohl Error | echo "***error*** (tar#Write) cannot cd to temporary directory" | Echohl None
   let &report= repkeep
   return
  endtry

  " place temporary files under .../_ZIPVIM_/
  if isdirectory("_ZIPVIM_")
   call s:Rmdir("_ZIPVIM_")
  endif
  call mkdir("_ZIPVIM_")
  cd _ZIPVIM_

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
  elseif      fname =~ '\.t\=gz$'  && executable("zcat")
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

  if exists("g:tar_secure")
   let tar_secure= " -- "
  else
   let tar_secure= " "
  endif

  if tarfile =~# '\.bz2$'
   exe "sil! r! bzip2 -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
   exe "read ".fname
  elseif tarfile =~# '\.bz3$'
   exe "sil! r! bzip3 -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
   exe "read ".fname
  elseif tarfile =~# '\.\(gz\)$'
   exe "sil! r! gzip -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
   exe "read ".fname
  elseif tarfile =~# '\(\.tgz\|\.tbz\|\.txz\)'
   if has("unix") && executable("file")
    let filekind= system("file ".shellescape(tarfile,1))
   else
    let filekind= ""
   endif
   if filekind =~ "bzip2"
    exe "sil! r! bzip2 -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
    exe "read ".fname
   elseif filekind =~ "bzip3"
    exe "sil! r! bzip3 -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
    exe "read ".fname
   elseif filekind =~ "XZ"
    exe "sil! r! xz -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
    exe "read ".fname
   elseif filekind =~ "Zstandard"
    exe "sil! r! zstd --decompress --stdout -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
    exe "read ".fname
   else
    exe "sil! r! gzip -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
    exe "read ".fname
   endif

  elseif tarfile =~# '\.lrp$'
   exe "sil! r! cat -- ".shellescape(tarfile,1)." | gzip -d -c - | ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
   exe "read ".fname
  elseif tarfile =~# '\.lzma$'
   exe "sil! r! lzma -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
   exe "read ".fname
  elseif tarfile =~# '\.\(xz\|txz\)$'
   exe "sil! r! xz --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
   exe "read ".fname
  elseif tarfile =~# '\.\(lz4\|tlz4\)$'
   exe "sil! r! lz4 --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
   exe "read ".fname
  else
   if tarfile =~ '^\s*-'
    " A file name starting with a dash is taken as an option.  Prepend ./ to avoid that.
    let tarfile = substitute(tarfile, '-', './-', '')
   endif
   exe "silent r! ".g:tar_cmd." -".g:tar_readoptions.shellescape(tarfile,1)." ".tar_secure.shellescape(fname,1).decmp
   exe "read ".fname
  endif

   redraw!

if v:shell_error != 0
   cd ..
   call s:Rmdir("_ZIPVIM_")
   exe "cd ".fnameescape(curdir)
   echohl Error | echo "***error*** (tar#Read) sorry, unable to open or extract ".tarfile." with ".fname | echohl None
  endif

  if doro
   " because the reverse process of compressing changed files back into the tarball is not currently supported
   setlocal ro
  endif

  let b:tarfile= a:fname
  exe "file tarfile::".fnameescape(fname)

  " cleanup
  keepj sil! 0d
  set nomod

  let &report= repkeep
endfun

" ---------------------------------------------------------------------
" tar#Write: {{{2
fun! tar#Write(fname)
  let repkeep= &report
  set report=10
  " temporary buffer variable workaround because too fucking tired. but it works now
  let curdir= b:curdir
  let tmpdir= b:tmpdir

  if !exists("g:tar_secure") && a:fname =~ '^\s*-\|\s\+-'
   redraw!
   echohl WarningMsg | echo '***warning*** (tar#Write) rejecting tarfile member<'.a:fname.'> because of embedded "-"'
   return
  endif

  " sanity checks
  if !executable(g:tar_cmd)
   redraw!
   let &report= repkeep
   return
  endif

  let tarfile = substitute(b:tarfile,'tarfile:\(.\{-}\)::.*$','\1','')
  let fname   = substitute(b:tarfile,'tarfile:.\{-}::\(.*\)$','\1','')

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

  if v:shell_error != 0
   redraw!
   echohl Error | echo "***error*** (tar#Write) sorry, unable to update ".tarfile." with ".fname | echohl None
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

   if exists("g:tar_secure")
    let tar_secure= " -- "
   else
    let tar_secure= " "
   endif
   exe "w! ".fnameescape(fname)
   if has("win32unix") && executable("cygpath")
    let tarfile = substitute(system("cygpath ".shellescape(tarfile,0)),'\n','','e')
   endif

   " delete old file from tarfile
   call system(g:tar_cmd." ".g:tar_delfile." ".shellescape(tarfile,0).tar_secure.shellescape(fname,0))
   if v:shell_error != 0
    redraw!
    echohl Error | echo "***error*** (tar#Write) sorry, unable to update ".fnameescape(tarfile)." with ".fnameescape(fname) | echohl None
   else

    " update tarfile with new file
    call system(g:tar_cmd." -".g:tar_writeoptions." ".shellescape(tarfile,0).tar_secure.shellescape(fname,0))
    if v:shell_error != 0
     redraw!
     echohl Error | echo "***error*** (tar#Write) sorry, unable to update ".fnameescape(tarfile)." with ".fnameescape(fname) | echohl None
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
  cd ..
  call s:Rmdir("_ZIPVIM_")
  exe "cd ".fnameescape(curdir)
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

  if !exists("g:tar_secure") && fname =~ '^\s*-\|\s\+-'
   redraw!
   echohl WarningMsg | echo '***warning*** (tar#BrowseSelect) rejecting tarfile member<'.fname.'> because of embedded "-"'
   return
  endif

  " sanity check
  if fname =~ '^"'
   let &report= repkeep
   return
  endif

  let tarball = expand("%")
  let tarbase = substitute(tarball,'\..*$','','')

  let extractcmd= netrw#WinPath(g:tar_extractcmd)
  if filereadable(tarbase.".tar")
   call system(extractcmd." ".shellescape(tarbase).".tar ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd." ".tarbase.".tar ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tgz")
   let extractcmd= substitute(extractcmd,"-","-z","")
   call system(extractcmd." ".shellescape(tarbase).".tgz ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd." ".tarbase.".tgz ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.gz")
   let extractcmd= substitute(extractcmd,"-","-z","")
   call system(extractcmd." ".shellescape(tarbase).".tar.gz ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd." ".tarbase.".tar.gz ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tbz")
   let extractcmd= substitute(extractcmd,"-","-j","")
   call system(extractcmd." ".shellescape(tarbase).".tbz ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd."j ".tarbase.".tbz ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.bz2")
   let extractcmd= substitute(extractcmd,"-","-j","")
   call system(extractcmd." ".shellescape(tarbase).".tar.bz2 ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd."j ".tarbase.".tar.bz2 ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.bz3")
   let extractcmd= substitute(extractcmd,"-","-j","")
   call system(extractcmd." ".shellescape(tarbase).".tar.bz3 ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd."j ".tarbase.".tar.bz3 ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".txz")
   let extractcmd= substitute(extractcmd,"-","-J","")
   call system(extractcmd." ".shellescape(tarbase).".txz ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd." ".tarbase.".txz ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.xz")
   let extractcmd= substitute(extractcmd,"-","-J","")
   call system(extractcmd." ".shellescape(tarbase).".tar.xz ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd." ".tarbase.".tar.xz ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tzst")
   let extractcmd= substitute(extractcmd,"-","--zstd","")
   call system(extractcmd." ".shellescape(tarbase).".tzst ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd." ".tarbase.".tzst ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.zst")
   let extractcmd= substitute(extractcmd,"-","--zstd","")
   call system(extractcmd." ".shellescape(tarbase).".tar.zst ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd." ".tarbase.".tar.zst ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tlz4")
   let extractcmd= substitute(extractcmd,"-","-I lz4","")
   call system(extractcmd." ".shellescape(tarbase).".tlz4 ".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd." ".tarbase.".tlz4 ".fname.": failed!" | echohl NONE
   else
    echo "***note*** successfully extracted ".fname
   endif

  elseif filereadable(tarbase.".tar.lz4")
   let extractcmd= substitute(extractcmd,"-","-I lz4","")
   call system(extractcmd." ".shellescape(tarbase).".tar.lz4".shellescape(fname))
   if v:shell_error != 0
    echohl Error | echo "***error*** ".extractcmd." ".tarbase.".tar.lz4 ".fname.": failed!" | echohl NONE
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
  if has("unix")
   call system("/bin/rm -rf -- ".shellescape(a:fname,0))
  elseif has("win32") || has("win95") || has("win64") || has("win16")
   if &shell =~? "sh$"
    call system("/bin/rm -rf -- ".shellescape(a:fname,0))
   else
    call system("del /S ".shellescape(a:fname,0))
   endif
  endif
endfun

" =====================================================================
" Modelines And Restoration: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" vim:ts=8 fdm=marker
