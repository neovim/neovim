" tar.vim: Handles browsing tarfiles
"            AUTOLOAD PORTION
" Date:			Apr 17, 2013
" Version:		29
" Maintainer:	Charles E Campbell <NdrOchip@ScampbellPfamily.AbizM-NOSPAM>
" License:		Vim License  (see vim's :help license)
"
"	Contains many ideas from Michael Toren's <tar.vim>
"
" Copyright:    Copyright (C) 2005-2011 Charles E. Campbell {{{1
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               tar.vim and tarPlugin.vim are provided *as is* and comes
"               with no warranty of any kind, either expressed or implied.
"               By using this plugin, you agree that in no event will the
"               copyright holder be liable for any damages resulting from
"               the use of this software.
"     call inputsave()|call input("Press <cr> to continue")|call inputrestore()
" ---------------------------------------------------------------------
" Load Once: {{{1
if &cp || exists("g:loaded_tar")
 finish
endif
let g:loaded_tar= "v29"
if v:version < 702
 echohl WarningMsg
 echo "***warning*** this version of tar needs vim 7.2"
 echohl Normal
 finish
endif
let s:keepcpo= &cpo
set cpo&vim
"DechoTabOn
"call Decho("loading autoload/tar.vim")

" ---------------------------------------------------------------------
"  Default Settings: {{{1
if !exists("g:tar_browseoptions")
 let g:tar_browseoptions= "Ptf"
endif
if !exists("g:tar_readoptions")
 let g:tar_readoptions= "OPxf"
endif
if !exists("g:tar_cmd")
 let g:tar_cmd= "tar"
endif
if !exists("g:tar_writeoptions")
 let g:tar_writeoptions= "uf"
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
 let g:tar_extractcmd= "tar -xf"
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
" call Decho("g:tar_shq<".g:tar_shq.">")
endif

" ----------------
"  Functions: {{{1
" ----------------

" ---------------------------------------------------------------------
" tar#Browse: {{{2
fun! tar#Browse(tarfile)
"  call Dfunc("tar#Browse(tarfile<".a:tarfile.">)")
  let repkeep= &report
  set report=10

  " sanity checks
  if !executable(g:tar_cmd)
   redraw!
   echohl Error | echo '***error*** (tar#Browse) "'.g:tar_cmd.'" not available on your system'
   let &report= repkeep
"   call Dret("tar#Browse")
   return
  endif
  if !filereadable(a:tarfile)
"   call Decho('a:tarfile<'.a:tarfile.'> not filereadable')
   if a:tarfile !~# '^\a\+://'
    " if it's an url, don't complain, let url-handlers such as vim do its thing
    redraw!
    echohl Error | echo "***error*** (tar#Browse) File not readable<".a:tarfile.">" | echohl None
   endif
   let &report= repkeep
"   call Dret("tar#Browse : file<".a:tarfile."> not readable")
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
"  call Decho("printing header")
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

  let gzip_command = s:get_gzip_command(tarfile)

  let curlast= line("$")
  if tarfile =~# '\.\(gz\|tgz\)$'
"   call Decho("1: exe silent r! gzip -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - ")
   exe "sil! r! " . gzip_command . " -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.lrp'
"   call Decho("2: exe silent r! cat -- ".shellescape(tarfile,1)."|gzip -d -c -|".g:tar_cmd." -".g:tar_browseoptions." - ")
   exe "sil! r! cat -- ".shellescape(tarfile,1)."|" . gzip_command . " -d -c -|".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.\(bz2\|tbz\|tb2\)$'
"   call Decho("3: exe silent r! bzip2 -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - ")
   exe "sil! r! bzip2 -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.\(lzma\|tlz\)$'
"   call Decho("3: exe silent r! lzma -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - ")
   exe "sil! r! lzma -d -c -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  elseif tarfile =~# '\.\(xz\|txz\)$'
"   call Decho("3: exe silent r! xz --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - ")
   exe "sil! r! xz --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_browseoptions." - "
  else
   if tarfile =~ '^\s*-'
    " A file name starting with a dash is taken as an option.  Prepend ./ to avoid that.
    let tarfile = substitute(tarfile, '-', './-', '')
   endif
"   call Decho("4: exe silent r! ".g:tar_cmd." -".g:tar_browseoptions." ".shellescape(tarfile,0))
   exe "sil! r! ".g:tar_cmd." -".g:tar_browseoptions." ".shellescape(tarfile,1)
  endif
  if v:shell_error != 0
   redraw!
   echohl WarningMsg | echo "***warning*** (tar#Browse) please check your g:tar_browseoptions<".g:tar_browseoptions.">"
"   call Dret("tar#Browse : a:tarfile<".a:tarfile.">")
   return
  endif
  if line("$") == curlast || ( line("$") == (curlast + 1) && getline("$") =~ '\c\%(warning\|error\|inappropriate\|unrecognized\)')
   redraw!
   echohl WarningMsg | echo "***warning*** (tar#Browse) ".a:tarfile." doesn't appear to be a tar file" | echohl None
   keepj sil! %d
   let eikeep= &ei
   set ei=BufReadCmd,FileReadCmd
   exe "r ".fnameescape(a:tarfile)
   let &ei= eikeep
   keepj sil! 1d
"   call Dret("tar#Browse : a:tarfile<".a:tarfile.">")
   return
  endif

  setlocal noma nomod ro
  noremap <silent> <buffer> <cr> :call <SID>TarBrowseSelect()<cr>

  let &report= repkeep
"  call Dret("tar#Browse : b:tarfile<".b:tarfile.">")
endfun

" ---------------------------------------------------------------------
" TarBrowseSelect: {{{2
fun! s:TarBrowseSelect()
"  call Dfunc("TarBrowseSelect() b:tarfile<".b:tarfile."> curfile<".expand("%").">")
  let repkeep= &report
  set report=10
  let fname= getline(".")
"  call Decho("fname<".fname.">")

  if !exists("g:tar_secure") && fname =~ '^\s*-\|\s\+-'
   redraw!
   echohl WarningMsg | echo '***warning*** (tar#BrowseSelect) rejecting tarfile member<'.fname.'> because of embedded "-"'
"   call Dret('tar#BrowseSelect : rejecting tarfile member<'.fname.'> because of embedded "-"')
   return
  endif

  " sanity check
  if fname =~ '^"'
   let &report= repkeep
"   call Dret("TarBrowseSelect")
   return
  endif

  " about to make a new window, need to use b:tarfile
  let tarfile= b:tarfile
  let curfile= expand("%")
  if has("win32unix") && executable("cygpath")
   " assuming cygwin
   let tarfile=substitute(system("cygpath -u ".shellescape(tarfile,0)),'\n$','','e')
  endif

  new
  if !exists("g:tar_nomax") || g:tar_nomax == 0
   wincmd _
  endif
  let s:tblfile_{winnr()}= curfile
  call tar#Read("tarfile:".tarfile.'::'.fname,1)
  filetype detect
  set nomod
  exe 'com! -buffer -nargs=? -complete=file TarDiff	:call tar#Diff(<q-args>,"'.fnameescape(fname).'")'

  let &report= repkeep
"  call Dret("TarBrowseSelect : s:tblfile_".winnr()."<".s:tblfile_{winnr()}.">")
endfun

" ---------------------------------------------------------------------
" tar#Read: {{{2
fun! tar#Read(fname,mode)
"  call Dfunc("tar#Read(fname<".a:fname.">,mode=".a:mode.")")
  let repkeep= &report
  set report=10
  let tarfile = substitute(a:fname,'tarfile:\(.\{-}\)::.*$','\1','')
  let fname   = substitute(a:fname,'tarfile:.\{-}::\(.*\)$','\1','')
  if has("win32unix") && executable("cygpath")
   " assuming cygwin
   let tarfile=substitute(system("cygpath -u ".shellescape(tarfile,0)),'\n$','','e')
  endif
"  call Decho("tarfile<".tarfile.">")
"  call Decho("fname<".fname.">")

  if  fname =~ '\.bz2$' && executable("bzcat")
   let decmp= "|bzcat"
   let doro = 1
  elseif      fname =~ '\.gz$'  && executable("zcat")
   let decmp= "|zcat"
   let doro = 1
  elseif  fname =~ '\.lzma$' && executable("lzcat")
   let decmp= "|lzcat"
   let doro = 1
  elseif  fname =~ '\.xz$' && executable("xzcat")
   let decmp= "|xzcat"
   let doro = 1
  else
   let decmp=""
   let doro = 0
   if fname =~ '\.bz2$\|\.gz$\|\.lzma$\|\.xz$\|\.zip$\|\.Z$'
    setlocal bin
   endif
  endif

  if exists("g:tar_secure")
   let tar_secure= " -- "
  else
   let tar_secure= " "
  endif

  let gzip_command = s:get_gzip_command(tarfile)

  if tarfile =~# '\.bz2$'
"   call Decho("7: exe silent r! bzip2 -d -c ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp)
   exe "sil! r! bzip2 -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
  elseif tarfile =~# '\.\(gz\|tgz\)$'
"   call Decho("5: exe silent r! gzip -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd.' -'.g:tar_readoptions.' - '.tar_secure.shellescape(fname,1))
   exe "sil! r! " . gzip_command . " -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
  elseif tarfile =~# '\.lrp$'
"   call Decho("6: exe silent r! cat ".shellescape(tarfile,1)." | gzip -d -c - | ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp)
   exe "sil! r! cat -- ".shellescape(tarfile,1)." | " . gzip_command . " -d -c - | ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
  elseif tarfile =~# '\.lzma$'
"   call Decho("7: exe silent r! lzma -d -c ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp)
   exe "sil! r! lzma -d -c -- ".shellescape(tarfile,1)."| ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
  elseif tarfile =~# '\.\(xz\|txz\)$'
"   call Decho("3: exe silent r! xz --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp)
   exe "sil! r! xz --decompress --stdout -- ".shellescape(tarfile,1)." | ".g:tar_cmd." -".g:tar_readoptions." - ".tar_secure.shellescape(fname,1).decmp
  else
   if tarfile =~ '^\s*-'
    " A file name starting with a dash is taken as an option.  Prepend ./ to avoid that.
    let tarfile = substitute(tarfile, '-', './-', '')
   endif
"   call Decho("8: exe silent r! ".g:tar_cmd." -".g:tar_readoptions.tar_secure.shellescape(tarfile,1)." ".shellescape(fname,1).decmp)
   exe "silent r! ".g:tar_cmd." -".g:tar_readoptions.shellescape(tarfile,1)." ".tar_secure.shellescape(fname,1).decmp
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
"  call Dret("tar#Read : b:tarfile<".b:tarfile.">")
endfun

" ---------------------------------------------------------------------
" tar#Write: {{{2
fun! tar#Write(fname)
"  call Dfunc("tar#Write(fname<".a:fname.">) b:tarfile<".b:tarfile."> tblfile_".winnr()."<".s:tblfile_{winnr()}.">")
  let repkeep= &report
  set report=10

  if !exists("g:tar_secure") && a:fname =~ '^\s*-\|\s\+-'
   redraw!
   echohl WarningMsg | echo '***warning*** (tar#Write) rejecting tarfile member<'.a:fname.'> because of embedded "-"'
"   call Dret('tar#Write : rejecting tarfile member<'.fname.'> because of embedded "-"')
   return
  endif

  " sanity checks
  if !executable(g:tar_cmd)
   redraw!
   echohl Error | echo '***error*** (tar#Browse) "'.g:tar_cmd.'" not available on your system'
   let &report= repkeep
"   call Dret("tar#Write")
   return
  endif
  if !exists("*mkdir")
   redraw!
   echohl Error | echo "***error*** (tar#Write) sorry, mkdir() doesn't work on your system" | echohl None
   let &report= repkeep
"   call Dret("tar#Write")
   return
  endif

  let curdir= getcwd()
  let tmpdir= tempname()
"  call Decho("orig tempname<".tmpdir.">")
  if tmpdir =~ '\.'
   let tmpdir= substitute(tmpdir,'\.[^.]*$','','e')
  endif
"  call Decho("tmpdir<".tmpdir.">")
  call mkdir(tmpdir,"p")

  " attempt to change to the indicated directory
  try
   exe "cd ".fnameescape(tmpdir)
  catch /^Vim\%((\a\+)\)\=:E344/
   redraw!
   echohl Error | echo "***error*** (tar#Write) cannot cd to temporary directory" | Echohl None
   let &report= repkeep
"   call Dret("tar#Write")
   return
  endtry
"  call Decho("current directory now: ".getcwd())

  " place temporary files under .../_ZIPVIM_/
  if isdirectory("_ZIPVIM_")
   call s:Rmdir("_ZIPVIM_")
  endif
  call mkdir("_ZIPVIM_")
  cd _ZIPVIM_
"  call Decho("current directory now: ".getcwd())

  let tarfile = substitute(b:tarfile,'tarfile:\(.\{-}\)::.*$','\1','')
  let fname   = substitute(b:tarfile,'tarfile:.\{-}::\(.*\)$','\1','')

  let gzip_command = s:get_gzip_command(tarfile)

  " handle compressed archives
  if tarfile =~# '\.bz2'
   call system("bzip2 -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.bz2','','e')
   let compress= "bzip2 -- ".shellescape(tarfile,0)
"   call Decho("compress<".compress.">")
  elseif tarfile =~# '\.gz'
   call system(gzip_command . " -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.gz','','e')
   let compress= "gzip -- ".shellescape(tarfile,0)
"   call Decho("compress<".compress.">")
  elseif tarfile =~# '\.tgz'
   call system(gzip_command . " -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.tgz','.tar','e')
   let compress= "gzip -- ".shellescape(tarfile,0)
   let tgz     = 1
"   call Decho("compress<".compress.">")
  elseif tarfile =~# '\.xz'
   call system("xz -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.xz','','e')
   let compress= "xz -- ".shellescape(tarfile,0)
"   call Decho("compress<".compress.">")
  elseif tarfile =~# '\.lzma'
   call system("lzma -d -- ".shellescape(tarfile,0))
   let tarfile = substitute(tarfile,'\.lzma','','e')
   let compress= "lzma -- ".shellescape(tarfile,0)
"   call Decho("compress<".compress.">")
  endif
"  call Decho("tarfile<".tarfile.">")

  if v:shell_error != 0
   redraw!
   echohl Error | echo "***error*** (tar#Write) sorry, unable to update ".tarfile." with ".fname | echohl None
  else

"   call Decho("tarfile<".tarfile."> fname<".fname.">")
 
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
"   call Decho("tarfile<".tarfile."> fname<".fname.">")
 
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
"   call Decho("system(".g:tar_cmd." --delete -f ".shellescape(tarfile,0)." -- ".shellescape(fname,0).")")
   call system(g:tar_cmd." --delete -f ".shellescape(tarfile,0).tar_secure.shellescape(fname,0))
   if v:shell_error != 0
    redraw!
    echohl Error | echo "***error*** (tar#Write) sorry, unable to update ".fnameescape(tarfile)." with ".fnameescape(fname) | echohl None
   else
 
    " update tarfile with new file 
"    call Decho(g:tar_cmd." -".g:tar_writeoptions." ".shellescape(tarfile,0).tar_secure.shellescape(fname,0))
    call system(g:tar_cmd." -".g:tar_writeoptions." ".shellescape(tarfile,0).tar_secure.shellescape(fname,0))
    if v:shell_error != 0
     redraw!
     echohl Error | echo "***error*** (tar#Write) sorry, unable to update ".fnameescape(tarfile)." with ".fnameescape(fname) | echohl None
    elseif exists("compress")
"     call Decho("call system(".compress.")")
     call system(compress)
     if exists("tgz")
"      call Decho("rename(".tarfile.".gz,".substitute(tarfile,'\.tar$','.tgz','e').")")
      call rename(tarfile.".gz",substitute(tarfile,'\.tar$','.tgz','e'))
     endif
    endif
   endif

   " support writing tarfiles across a network
   if s:tblfile_{winnr()} =~ '^\a\+://'
"    call Decho("handle writing <".tarfile."> across network to <".s:tblfile_{winnr()}.">")
    let tblfile= s:tblfile_{winnr()}
    1split|enew
    let binkeep= &l:binary
    let eikeep = &ei
    set binary ei=all
    exe "e! ".fnameescape(tarfile)
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
"  call Dret("tar#Write")
endfun

" ---------------------------------------------------------------------
" tar#Diff: {{{2
fun! tar#Diff(userfname,fname)
"  call Dfunc("tar#Diff(userfname<".a:userfname."> fname<".a:fname.")")
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
   exe "e ".fnameescape(fname)
   diffthis
  else
   redraw!
   echo "***warning*** unable to read file<".fname.">"
  endif
"  call Dret("tar#Diff")
endfun

" ---------------------------------------------------------------------
" s:Rmdir: {{{2
fun! s:Rmdir(fname)
"  call Dfunc("Rmdir(fname<".a:fname.">)")
  if has("unix")
   call system("/bin/rm -rf -- ".shellescape(a:fname,0))
  elseif has("win32") || has("win95") || has("win64") || has("win16")
   if &shell =~? "sh$"
    call system("/bin/rm -rf -- ".shellescape(a:fname,0))
   else
    call system("del /S ".shellescape(a:fname,0))
   endif
  endif
"  call Dret("Rmdir")
endfun

" ---------------------------------------------------------------------
" tar#Vimuntar: installs a tarball in the user's .vim / vimfiles directory {{{2
fun! tar#Vimuntar(...)
"  call Dfunc("tar#Vimuntar() a:0=".a:0." a:1<".(exists("a:1")? a:1 : "-n/a-").">")
  let tarball = expand("%")
"  call Decho("tarball<".tarball.">")
  let tarbase = substitute(tarball,'\..*$','','')
"  call Decho("tarbase<".tarbase.">")
  let tarhome = expand("%:p")
  if has("win32") || has("win95") || has("win64") || has("win16")
   let tarhome= substitute(tarhome,'\\','/','g')
  endif
  let tarhome= substitute(tarhome,'/[^/]*$','','')
"  call Decho("tarhome<".tarhome.">")
  let tartail = expand("%:t")
"  call Decho("tartail<".tartail.">")
  let curdir  = getcwd()
"  call Decho("curdir <".curdir.">")
  " set up vimhome
  if a:0 > 0 && a:1 != ""
   let vimhome= a:1
  else
   let vimhome= vimball#VimballHome()
  endif
"  call Decho("vimhome<".vimhome.">")

"  call Decho("curdir<".curdir."> vimhome<".vimhome.">")
  if simplify(curdir) != simplify(vimhome)
   " copy (possibly compressed) tarball to .vim/vimfiles
"   call Decho(netrw#WinPath(g:tar_copycmd)." ".shellescape(tartail)." ".shellescape(vimhome))
   call system(netrw#WinPath(g:tar_copycmd)." ".shellescape(tartail)." ".shellescape(vimhome))
"   call Decho("exe cd ".fnameescape(vimhome))
   exe "cd ".fnameescape(vimhome)
  endif
"  call Decho("getcwd<".getcwd().">")

  " if necessary, decompress the tarball; then, extract it
  if tartail =~ '\.tgz'
   if executable("bzip2")
    silent exe "!bzip2 -d ".shellescape(tartail)
   elseif executable("gunzip")
    silent exe "!gunzip ".shellescape(tartail)
   elseif executable("gzip")
    silent exe "!gzip -d ".shellescape(tartail)
   else
    echoerr "unable to decompress<".tartail."> on this sytem"
    if simplify(curdir) != simplify(tarhome)
     " remove decompressed tarball, restore directory
"     call Decho("delete(".tartail.".tar)")
     call delete(tartail.".tar")
"     call Decho("exe cd ".fnameescape(curdir))
     exe "cd ".fnameescape(curdir)
    endif
"    call Dret("tar#Vimuntar")
    return
   endif
  else
   call vimball#Decompress(tartail,0)
  endif
  let extractcmd= netrw#WinPath(g:tar_extractcmd)
"  call Decho("system(".extractcmd." ".shellescape(tarbase.".tar").")")
  call system(extractcmd." ".shellescape(tarbase.".tar"))

  " set up help
  if filereadable("doc/".tarbase.".txt")
"   call Decho("exe helptags ".getcwd()."/doc")
   exe "helptags ".getcwd()."/doc"
  endif

  if simplify(tarhome) != simplify(vimhome)
   " remove decompressed tarball, restore directory
   call delete(vimhome."/".tarbase.".tar")
   exe "cd ".fnameescape(curdir)
  endif

"  call Dret("tar#Vimuntar")
endfun

func s:get_gzip_command(file)
  if a:file =~# 'z$' && executable('bzip2')
    " Some .tgz files are actually compressed with bzip2.  Since bzip2 can
    " handle the format from gzip, use it if the command exists.
    return 'bzip2'
  endif
  return 'gzip'
endfunc

" =====================================================================
" Modelines And Restoration: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" vim:ts=8 fdm=marker
