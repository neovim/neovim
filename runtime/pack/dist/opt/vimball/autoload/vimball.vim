" vimball.vim : construct a file containing both paths and files
" Author:	Charles E. Campbell, Jr.
" Date:		Jan 17, 2012
" Version:	35
" GetLatestVimScripts: 1502 1 :AutoInstall: vimball.vim
" Copyright: (c) 2004-2011 by Charles E. Campbell, Jr.
"            The VIM LICENSE applies to Vimball.vim, and Vimball.txt
"            (see |copyright|) except use "Vimball" instead of "Vim".
"            No warranty, express or implied.
"  *** ***   Use At-Your-Own-Risk!   *** ***

" ---------------------------------------------------------------------
"  Load Once: {{{1
if &cp || exists("g:loaded_vimball")
 finish
endif
let g:loaded_vimball = "v35"
if v:version < 702
 echohl WarningMsg
 echo "***warning*** this version of vimball needs vim 7.2"
 echohl Normal
 finish
endif
let s:keepcpo= &cpo
set cpo&vim
"DechoTabOn

" =====================================================================
" Constants: {{{1
if !exists("s:USAGE")
 let s:USAGE   = 0
 let s:WARNING = 1
 let s:ERROR   = 2

 " determine if cygwin is in use or not
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

 " set up g:vimball_mkdir if the mkdir() call isn't defined
 if !exists("*mkdir")
  if exists("g:netrw_local_mkdir")
   let g:vimball_mkdir= g:netrw_local_mkdir
  elseif executable("mkdir")
   let g:vimball_mkdir= "mkdir"
  elseif executable("makedir")
   let g:vimball_mkdir= "makedir"
  endif
  if !exists(g:vimball_mkdir)
   call vimball#ShowMesg(s:WARNING,"(vimball) g:vimball_mkdir undefined")
  endif
 endif
endif

" =====================================================================
"  Functions: {{{1

" ---------------------------------------------------------------------
" vimball#MkVimball: creates a vimball given a list of paths to files {{{2
" Input:
"     line1,line2: a range of lines containing paths to files to be included in the vimball
"     writelevel : if true, force a write to filename.vmb, even if it exists
"                  (usually accomplished with :MkVimball! ...
"     filename   : base name of file to be created (ie. filename.vmb)
" Output: a filename.vmb using vimball format:
"     path
"     filesize
"     [file]
"     path
"     filesize
"     [file]
fun! vimball#MkVimball(line1,line2,writelevel,...) range
"  call Dfunc("MkVimball(line1=".a:line1." line2=".a:line2." writelevel=".a:writelevel." vimballname<".a:1.">) a:0=".a:0)
  if a:1 =~ '\.vim$' || a:1 =~ '\.txt$'
   let vbname= substitute(a:1,'\.\a\{3}$','.vmb','')
  else
   let vbname= a:1
  endif
  if vbname !~ '\.vmb$'
   let vbname= vbname.'.vmb'
  endif
"  call Decho("vbname<".vbname.">")
  if !a:writelevel && a:1 =~ '[\/]'
   call vimball#ShowMesg(s:ERROR,"(MkVimball) vimball name<".a:1."> should not include slashes; use ! to insist")
"   call Dret("MkVimball : vimball name<".a:1."> should not include slashes")
   return
  endif
  if !a:writelevel && filereadable(vbname)
   call vimball#ShowMesg(s:ERROR,"(MkVimball) file<".vbname."> exists; use ! to insist")
"   call Dret("MkVimball : file<".vbname."> already exists; use ! to insist")
   return
  endif

  " user option bypass
  call vimball#SaveSettings()

  if a:0 >= 2
   " allow user to specify where to get the files
   let home= expand(a:2)
  else
   " use first existing directory from rtp
   let home= vimball#VimballHome()
  endif

  " save current directory
  let curdir = getcwd()
  call s:ChgDir(home)

  " record current tab, initialize while loop index
  let curtabnr = tabpagenr()
  let linenr   = a:line1
"  call Decho("curtabnr=".curtabnr)

  while linenr <= a:line2
   let svfile  = getline(linenr)
"   call Decho("svfile<".svfile.">")
 
   if !filereadable(svfile)
    call vimball#ShowMesg(s:ERROR,"unable to read file<".svfile.">")
	call s:ChgDir(curdir)
	call vimball#RestoreSettings()
"    call Dret("MkVimball")
    return
   endif
 
   " create/switch to mkvimball tab
   if !exists("vbtabnr")
    tabnew
    sil! file Vimball
    let vbtabnr= tabpagenr()
   else
    exe "tabn ".vbtabnr
   endif
 
   let lastline= line("$") + 1
   if lastline == 2 && getline("$") == ""
	call setline(1,'" Vimball Archiver by Charles E. Campbell, Jr., Ph.D.')
	call setline(2,'UseVimball')
	call setline(3,'finish')
	let lastline= line("$") + 1
   endif
   call setline(lastline  ,substitute(svfile,'$','	[[[1',''))
   call setline(lastline+1,0)

   " write the file from the tab
"   call Decho("exe $r ".fnameescape(svfile))
   exe "$r ".fnameescape(svfile)

   call setline(lastline+1,line("$") - lastline - 1)
"   call Decho("lastline=".lastline." line$=".line("$"))

  " restore to normal tab
   exe "tabn ".curtabnr
   let linenr= linenr + 1
  endwhile

  " write the vimball
  exe "tabn ".vbtabnr
  call s:ChgDir(curdir)
  setlocal ff=unix
  if a:writelevel
"   call Decho("exe w! ".fnameescape(vbname))
   exe "w! ".fnameescape(vbname)
  else
"   call Decho("exe w ".fnameescape(vbname))
   exe "w ".fnameescape(vbname)
  endif
"  call Decho("Vimball<".vbname."> created")
  echo "Vimball<".vbname."> created"

  " remove the evidence
  setlocal nomod bh=wipe
  exe "tabn ".curtabnr
  exe "tabc ".vbtabnr

  " restore options
  call vimball#RestoreSettings()

"  call Dret("MkVimball")
endfun

" ---------------------------------------------------------------------
" vimball#Vimball: extract and distribute contents from a vimball {{{2
"                  (invoked the the UseVimball command embedded in 
"                  vimballs' prologue)
fun! vimball#Vimball(really,...)
"  call Dfunc("vimball#Vimball(really=".a:really.") a:0=".a:0)

  if v:version < 701 || (v:version == 701 && !exists('*fnameescape'))
   echoerr "your vim is missing the fnameescape() function (pls upgrade to vim 7.2 or later)"
"   call Dret("vimball#Vimball : needs 7.1 with patch 299 or later")
   return
  endif

  if getline(1) !~ '^" Vimball Archiver'
   echoerr "(Vimball) The current file does not appear to be a Vimball!"
"   call Dret("vimball#Vimball")
   return
  endif

  " set up standard settings
  call vimball#SaveSettings()
  let curtabnr    = tabpagenr()
  let vimballfile = expand("%:tr")

  " set up vimball tab
"  call Decho("setting up vimball tab")
  tabnew
  sil! file Vimball
  let vbtabnr= tabpagenr()
  let didhelp= ""

  " go to vim plugin home
  if a:0 > 0
   " let user specify the directory where the vimball is to be unpacked.
   " If, however, the user did not specify a full path, set the home to be below the current directory
   let home= expand(a:1)
   if has("win32") || has("win95") || has("win64") || has("win16")
	if home !~ '^\a:[/\\]'
	 let home= getcwd().'/'.a:1
	endif
   elseif home !~ '^/'
	let home= getcwd().'/'.a:1
   endif
  else
   let home= vimball#VimballHome()
  endif
"  call Decho("home<".home.">")

  " save current directory and remove older same-named vimball, if any
  let curdir = getcwd()
"  call Decho("home<".home.">")
"  call Decho("curdir<".curdir.">")

  call s:ChgDir(home)
  let s:ok_unablefind= 1
  call vimball#RmVimball(vimballfile)
  unlet s:ok_unablefind

  let linenr  = 4
  let filecnt = 0

  " give title to listing of (extracted) files from Vimball Archive
  if a:really
   echohl Title     | echomsg "Vimball Archive"         | echohl None
  else             
   echohl Title     | echomsg "Vimball Archive Listing" | echohl None
   echohl Statement | echomsg "files would be placed under: ".home | echohl None
  endif

  " apportion vimball contents to various files
"  call Decho("exe tabn ".curtabnr)
  exe "tabn ".curtabnr
"  call Decho("linenr=".linenr." line$=".line("$"))
  while 1 < linenr && linenr < line("$")
   let fname   = substitute(getline(linenr),'\t\[\[\[1$','','')
   let fname   = substitute(fname,'\\','/','g')
   let fsize   = substitute(getline(linenr+1),'^\(\d\+\).\{-}$','\1','')+0
   let fenc    = substitute(getline(linenr+1),'^\d\+\s*\(\S\{-}\)$','\1','')
   let filecnt = filecnt + 1
"   call Decho("fname<".fname."> fsize=".fsize." filecnt=".filecnt. " fenc=".fenc)

   if a:really
    echomsg "extracted <".fname.">: ".fsize." lines"
   else
    echomsg "would extract <".fname.">: ".fsize." lines"
   endif
"   call Decho("using L#".linenr.": will extract file<".fname.">")
"   call Decho("using L#".(linenr+1).": fsize=".fsize)

   " Allow AsNeeded/ directory to take place of plugin/ directory
   " when AsNeeded/filename is filereadable or was present in VimballRecord
   if fname =~ '\<plugin/'
   	let anfname= substitute(fname,'\<plugin/','AsNeeded/','')
	if filereadable(anfname) || (exists("s:VBRstring") && s:VBRstring =~ anfname)
"	 call Decho("using anfname<".anfname."> instead of <".fname.">")
	 let fname= anfname
	endif
   endif

   " make directories if they don't exist yet
   if a:really
"    call Decho("making directories if they don't exist yet (fname<".fname.">)")
    let fnamebuf= substitute(fname,'\\','/','g')
	let dirpath = substitute(home,'\\','/','g')
"	call Decho("init: fnamebuf<".fnamebuf.">")
"	call Decho("init: dirpath <".dirpath.">")
    while fnamebuf =~ '/'
     let dirname  = dirpath."/".substitute(fnamebuf,'/.*$','','')
	 let dirpath  = dirname
     let fnamebuf = substitute(fnamebuf,'^.\{-}/\(.*\)$','\1','')
"	 call Decho("dirname<".dirname.">")
"	 call Decho("dirpath<".dirpath.">")
     if !isdirectory(dirname)
"      call Decho("making <".dirname.">")
      if exists("g:vimball_mkdir")
	   call system(g:vimball_mkdir." ".shellescape(dirname))
      else
       call mkdir(dirname)
      endif
	  call s:RecordInVar(home,"rmdir('".dirname."')")
     endif
    endwhile
   endif
   call s:ChgDir(home)

   " grab specified qty of lines and place into "a" buffer
   " (skip over path/filename and qty-lines)
   let linenr   = linenr + 2
   let lastline = linenr + fsize - 1
"   call Decho("exe ".linenr.",".lastline."yank a")
   " no point in handling a zero-length file
   if lastline >= linenr
    exe "silent ".linenr.",".lastline."yank a"

    " copy "a" buffer into tab
"   call Decho('copy "a buffer into tab#'.vbtabnr)
    exe "tabn ".vbtabnr
    setlocal ma
    sil! %d
    silent put a
    1
    sil! d

    " write tab to file
    if a:really
     let fnamepath= home."/".fname
"    call Decho("exe w! ".fnameescape(fnamepath))
	if fenc != ""
	 exe "silent w! ++enc=".fnameescape(fenc)." ".fnameescape(fnamepath)
	else
	 exe "silent w! ".fnameescape(fnamepath)
	endif
	echo "wrote ".fnameescape(fnamepath)
	call s:RecordInVar(home,"call delete('".fnamepath."')")
    endif

    " return to tab with vimball
"   call Decho("exe tabn ".curtabnr)
    exe "tabn ".curtabnr

    " set up help if its a doc/*.txt file
"   call Decho("didhelp<".didhelp."> fname<".fname.">")
    if a:really && didhelp == "" && fname =~ 'doc/[^/]\+\.\(txt\|..x\)$'
    	let didhelp= substitute(fname,'^\(.*\<doc\)[/\\][^.]*\.\(txt\|..x\)$','\1','')
"	call Decho("didhelp<".didhelp.">")
    endif
   endif

   " update for next file
"   call Decho("update linenr= [linenr=".linenr."] + [fsize=".fsize."] = ".(linenr+fsize))
   let linenr= linenr + fsize
  endwhile

  " set up help
"  call Decho("about to set up help: didhelp<".didhelp.">")
  if didhelp != ""
   let htpath= home."/".didhelp
"   call Decho("exe helptags ".htpath)
   exe "helptags ".fnameescape(htpath)
   echo "did helptags"
  endif

  " make sure a "Press ENTER..." prompt appears to keep the messages showing!
  while filecnt <= &ch
   echomsg " "
   let filecnt= filecnt + 1
  endwhile

  " record actions in <.VimballRecord>
  call s:RecordInFile(home)

  " restore events, delete tab and buffer
  exe "tabn ".vbtabnr
  setlocal nomod bh=wipe
  exe "tabn ".curtabnr
  exe "tabc ".vbtabnr
  call vimball#RestoreSettings()
  call s:ChgDir(curdir)

"  call Dret("vimball#Vimball")
endfun

" ---------------------------------------------------------------------
" vimball#RmVimball: remove any files, remove any directories made by any {{{2
"               previous vimball extraction based on a file of the current
"               name.
"  Usage:  RmVimball  (assume current file is a vimball; remove)
"          RmVimball vimballname
fun! vimball#RmVimball(...)
"  call Dfunc("vimball#RmVimball() a:0=".a:0)
  if exists("g:vimball_norecord")
"   call Dret("vimball#RmVimball : (g:vimball_norecord)")
   return
  endif

  if a:0 == 0
   let curfile= expand("%:tr")
"   call Decho("case a:0=0: curfile<".curfile."> (used expand(%:tr))")
  else
   if a:1 =~ '[\/]'
    call vimball#ShowMesg(s:USAGE,"RmVimball vimballname [path]")
"    call Dret("vimball#RmVimball : suspect a:1<".a:1.">")
    return
   endif
   let curfile= a:1
"   call Decho("case a:0=".a:0.": curfile<".curfile.">")
  endif
  if curfile =~ '\.vmb$'
   let curfile= substitute(curfile,'\.vmb','','')
  elseif curfile =~ '\.vba$'
   let curfile= substitute(curfile,'\.vba','','')
  endif
  if a:0 >= 2
   let home= expand(a:2)
  else
   let home= vimball#VimballHome()
  endif
  let curdir = getcwd()
"  call Decho("home   <".home.">")
"  call Decho("curfile<".curfile.">")
"  call Decho("curdir <".curdir.">")

  call s:ChgDir(home)
  if filereadable(".VimballRecord")
"   call Decho(".VimballRecord is readable")
"   call Decho("curfile<".curfile.">")
   keepalt keepjumps 1split 
   sil! keepalt keepjumps e .VimballRecord
   let keepsrch= @/
"   call Decho('search for ^\M'.curfile.'.\m: ')
"   call Decho('search for ^\M'.curfile.'.\m{vba|vmb}: ')
"   call Decho('search for ^\M'.curfile.'\m[-0-9.]*\.{vba|vmb}: ')
   if search('^\M'.curfile."\m: ".'cw')
	let foundit= 1
   elseif search('^\M'.curfile.".\mvmb: ",'cw')
	let foundit= 2
   elseif search('^\M'.curfile.'\m[-0-9.]*\.vmb: ','cw')
	let foundit= 2
   elseif search('^\M'.curfile.".\mvba: ",'cw')
	let foundit= 1
   elseif search('^\M'.curfile.'\m[-0-9.]*\.vba: ','cw')
	let foundit= 1
   else
    let foundit = 0
   endif
   if foundit
	if foundit == 1
	 let exestring  = substitute(getline("."),'^\M'.curfile.'\m\S\{-}\.vba: ','','')
	else
	 let exestring  = substitute(getline("."),'^\M'.curfile.'\m\S\{-}\.vmb: ','','')
	endif
    let s:VBRstring= substitute(exestring,'call delete(','','g')
    let s:VBRstring= substitute(s:VBRstring,"[')]",'','g')
"	call Decho("exe ".exestring)
	sil! keepalt keepjumps exe exestring
	sil! keepalt keepjumps d
	let exestring= strlen(substitute(exestring,'call delete(.\{-})|\=',"D","g"))
"	call Decho("exestring<".exestring.">")
	echomsg "removed ".exestring." files"
   else
    let s:VBRstring= ''
	let curfile    = substitute(curfile,'\.vmb','','')
"    call Decho("unable to find <".curfile."> in .VimballRecord")
	if !exists("s:ok_unablefind")
     call vimball#ShowMesg(s:WARNING,"(RmVimball) unable to find <".curfile."> in .VimballRecord")
	endif
   endif
   sil! keepalt keepjumps g/^\s*$/d
   sil! keepalt keepjumps wq!
   let @/= keepsrch
  endif
  call s:ChgDir(curdir)

"  call Dret("vimball#RmVimball")
endfun

" ---------------------------------------------------------------------
" vimball#Decompress: attempts to automatically decompress vimballs {{{2
fun! vimball#Decompress(fname,...)
"  call Dfunc("Decompress(fname<".a:fname.">) a:0=".a:0)

  " decompression:
  if     expand("%") =~ '.*\.gz'  && executable("gunzip")
   " handle *.gz with gunzip
   silent exe "!gunzip ".shellescape(a:fname)
   if v:shell_error != 0
	call vimball#ShowMesg(s:WARNING,"(vimball#Decompress) gunzip may have failed with <".a:fname.">")
   endif
   let fname= substitute(a:fname,'\.gz$','','')
   exe "e ".escape(fname,' \')
   if a:0 == 0| call vimball#ShowMesg(s:USAGE,"Source this file to extract it! (:so %)") | endif

  elseif expand("%") =~ '.*\.gz' && executable("gzip")
   " handle *.gz with gzip -d
   silent exe "!gzip -d ".shellescape(a:fname)
   if v:shell_error != 0
	call vimball#ShowMesg(s:WARNING,'(vimball#Decompress) "gzip -d" may have failed with <'.a:fname.">")
   endif
   let fname= substitute(a:fname,'\.gz$','','')
   exe "e ".escape(fname,' \')
   if a:0 == 0| call vimball#ShowMesg(s:USAGE,"Source this file to extract it! (:so %)") | endif

  elseif expand("%") =~ '.*\.bz2' && executable("bunzip2")
   " handle *.bz2 with bunzip2
   silent exe "!bunzip2 ".shellescape(a:fname)
   if v:shell_error != 0
	call vimball#ShowMesg(s:WARNING,"(vimball#Decompress) bunzip2 may have failed with <".a:fname.">")
   endif
   let fname= substitute(a:fname,'\.bz2$','','')
   exe "e ".escape(fname,' \')
   if a:0 == 0| call vimball#ShowMesg(s:USAGE,"Source this file to extract it! (:so %)") | endif

  elseif expand("%") =~ '.*\.bz2' && executable("bzip2")
   " handle *.bz2 with bzip2 -d
   silent exe "!bzip2 -d ".shellescape(a:fname)
   if v:shell_error != 0
	call vimball#ShowMesg(s:WARNING,'(vimball#Decompress) "bzip2 -d" may have failed with <'.a:fname.">")
   endif
   let fname= substitute(a:fname,'\.bz2$','','')
   exe "e ".escape(fname,' \')
   if a:0 == 0| call vimball#ShowMesg(s:USAGE,"Source this file to extract it! (:so %)") | endif

  elseif expand("%") =~ '.*\.zip' && executable("unzip")
   " handle *.zip with unzip
   silent exe "!unzip ".shellescape(a:fname)
   if v:shell_error != 0
	call vimball#ShowMesg(s:WARNING,"(vimball#Decompress) unzip may have failed with <".a:fname.">")
   endif
   let fname= substitute(a:fname,'\.zip$','','')
   exe "e ".escape(fname,' \')
   if a:0 == 0| call vimball#ShowMesg(s:USAGE,"Source this file to extract it! (:so %)") | endif
  endif

  if a:0 == 0| setlocal noma bt=nofile fmr=[[[,]]] fdm=marker | endif

"  call Dret("Decompress")
endfun

" ---------------------------------------------------------------------
" vimball#ShowMesg: {{{2
fun! vimball#ShowMesg(level,msg)
"  call Dfunc("vimball#ShowMesg(level=".a:level." msg<".a:msg.">)")

  let rulerkeep   = &ruler
  let showcmdkeep = &showcmd
  set noruler noshowcmd
  redraw!

  if &fo =~ '[ta]'
   echomsg "***vimball*** ".a:msg
  else
   if a:level == s:WARNING || a:level == s:USAGE
    echohl WarningMsg
   elseif a:level == s:ERROR
    echohl Error
   endif
   echomsg "***vimball*** ".a:msg
   echohl None
  endif

  if a:level != s:USAGE
   call inputsave()|let ok= input("Press <cr> to continue")|call inputrestore()
  endif

  let &ruler   = rulerkeep
  let &showcmd = showcmdkeep

"  call Dret("vimball#ShowMesg")
endfun
" =====================================================================
" s:ChgDir: change directory (in spite of Windoze) {{{2
fun! s:ChgDir(newdir)
"  call Dfunc("ChgDir(newdir<".a:newdir.">)")
  if (has("win32") || has("win95") || has("win64") || has("win16"))
   try
    exe 'silent cd '.fnameescape(substitute(a:newdir,'/','\\','g'))
   catch  /^Vim\%((\a\+)\)\=:E/
    call mkdir(fnameescape(substitute(a:newdir,'/','\\','g')))
    exe 'silent cd '.fnameescape(substitute(a:newdir,'/','\\','g'))
   endtry
  else
   try
    exe 'silent cd '.fnameescape(a:newdir)
   catch  /^Vim\%((\a\+)\)\=:E/
    call mkdir(fnameescape(a:newdir))
    exe 'silent cd '.fnameescape(a:newdir)
   endtry
  endif
"  call Dret("ChgDir : curdir<".getcwd().">")
endfun

" ---------------------------------------------------------------------
" s:RecordInVar: record a un-vimball command in the .VimballRecord file {{{2
fun! s:RecordInVar(home,cmd)
"  call Dfunc("RecordInVar(home<".a:home."> cmd<".a:cmd.">)")
  if a:cmd =~ '^rmdir'
"   if !exists("s:recorddir")
"    let s:recorddir= substitute(a:cmd,'^rmdir',"call s:Rmdir",'')
"   else
"    let s:recorddir= s:recorddir."|".substitute(a:cmd,'^rmdir',"call s:Rmdir",'')
"   endif
  elseif !exists("s:recordfile")
   let s:recordfile= a:cmd
  else
   let s:recordfile= s:recordfile."|".a:cmd
  endif
"  call Dret("RecordInVar : s:recordfile<".(exists("s:recordfile")? s:recordfile : "")."> s:recorddir<".(exists("s:recorddir")? s:recorddir : "").">")
endfun

" ---------------------------------------------------------------------
" s:RecordInFile: {{{2
fun! s:RecordInFile(home)
"  call Dfunc("s:RecordInFile()")
  if exists("g:vimball_norecord")
"   call Dret("s:RecordInFile : g:vimball_norecord")
   return
  endif

  if exists("s:recordfile") || exists("s:recorddir")
   let curdir= getcwd()
   call s:ChgDir(a:home)
   keepalt keepjumps 1split 

   let cmd= expand("%:tr").": "
"   call Decho("cmd<".cmd.">")

   sil! keepalt keepjumps e .VimballRecord
   setlocal ma
   $
   if exists("s:recordfile") && exists("s:recorddir")
   	let cmd= cmd.s:recordfile."|".s:recorddir
   elseif exists("s:recorddir")
   	let cmd= cmd.s:recorddir
   elseif exists("s:recordfile")
   	let cmd= cmd.s:recordfile
   else
"    call Dret("s:RecordInFile : neither recordfile nor recorddir exist")
	return
   endif
"   call Decho("cmd<".cmd.">")

   " put command into buffer, write .VimballRecord `file
   keepalt keepjumps put=cmd
   sil! keepalt keepjumps g/^\s*$/d
   sil! keepalt keepjumps wq!
   call s:ChgDir(curdir)

   if exists("s:recorddir")
"	call Decho("unlet s:recorddir<".s:recorddir.">")
   	unlet s:recorddir
   endif
   if exists("s:recordfile")
"	call Decho("unlet s:recordfile<".s:recordfile.">")
   	unlet s:recordfile
   endif
  else
"   call Decho("s:record[file|dir] doesn't exist")
  endif

"  call Dret("s:RecordInFile")
endfun

" ---------------------------------------------------------------------
" vimball#VimballHome: determine/get home directory path (usually from rtp) {{{2
fun! vimball#VimballHome()
"  call Dfunc("vimball#VimballHome()")
  if exists("g:vimball_home")
   let home= g:vimball_home
  else
   " go to vim plugin home
   for home in split(&rtp,',') + ['']
    if isdirectory(home) && filewritable(home) | break | endif
	let basehome= substitute(home,'[/\\]\.vim$','','')
    if isdirectory(basehome) && filewritable(basehome)
	 let home= basehome."/.vim"
	 break
	endif
   endfor
   if home == ""
    " just pick the first directory
    let home= substitute(&rtp,',.*$','','')
   endif
   if (has("win32") || has("win95") || has("win64") || has("win16"))
    let home= substitute(home,'/','\\','g')
   endif
  endif
  " insure that the home directory exists
"  call Decho("picked home<".home.">")
  if !isdirectory(home)
   if exists("g:vimball_mkdir")
"	call Decho("home<".home."> isn't a directory -- making it now with g:vimball_mkdir<".g:vimball_mkdir.">")
"    call Decho("system(".g:vimball_mkdir." ".shellescape(home).")")
    call system(g:vimball_mkdir." ".shellescape(home))
   else
"	call Decho("home<".home."> isn't a directory -- making it now with mkdir()")
    call mkdir(home)
   endif
  endif
"  call Dret("vimball#VimballHome <".home.">")
  return home
endfun

" ---------------------------------------------------------------------
" vimball#SaveSettings: {{{2
fun! vimball#SaveSettings()
"  call Dfunc("SaveSettings()")
  let s:makeep  = getpos("'a")
  let s:regakeep= @a
  if exists("&acd")
   let s:acdkeep = &acd
  endif
  let s:eikeep  = &ei
  let s:fenkeep = &l:fen
  let s:hidkeep = &hidden
  let s:ickeep  = &ic
  let s:lzkeep  = &lz
  let s:pmkeep  = &pm
  let s:repkeep = &report
  let s:vekeep  = &ve
  let s:ffkeep  = &l:ff
  let s:swfkeep = &l:swf
  if exists("&acd")
   setlocal ei=all ve=all noacd nofen noic report=999 nohid bt= ma lz pm= ff=unix noswf
  else
   setlocal ei=all ve=all       nofen noic report=999 nohid bt= ma lz pm= ff=unix noswf
  endif
  " vimballs should be in unix format
  setlocal ff=unix
"  call Dret("SaveSettings")
endfun

" ---------------------------------------------------------------------
" vimball#RestoreSettings: {{{2
fun! vimball#RestoreSettings()
"  call Dfunc("RestoreSettings()")
  let @a      = s:regakeep
  if exists("&acd")
   let &acd   = s:acdkeep
  endif
  let &l:fen  = s:fenkeep
  let &hidden = s:hidkeep
  let &ic     = s:ickeep
  let &lz     = s:lzkeep
  let &pm     = s:pmkeep
  let &report = s:repkeep
  let &ve     = s:vekeep
  let &ei     = s:eikeep
  let &l:ff   = s:ffkeep
  if s:makeep[0] != 0
   " restore mark a
"   call Decho("restore mark-a: makeep=".string(makeep))
   call setpos("'a",s:makeep)
  endif
  if exists("&acd")
   unlet s:acdkeep
  endif
  unlet s:regakeep s:eikeep s:fenkeep s:hidkeep s:ickeep s:repkeep s:vekeep s:makeep s:lzkeep s:pmkeep s:ffkeep
"  call Dret("RestoreSettings")
endfun

let &cpo = s:keepcpo
unlet s:keepcpo

" ---------------------------------------------------------------------
" Modelines: {{{1
" vim: fdm=marker
