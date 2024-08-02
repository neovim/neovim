" netrw.vim: Handles file transfer and remote directory listing across
"            AUTOLOAD SECTION
" Maintainer: This runtime file is looking for a new maintainer.
" Date:		  May 03, 2023
" Version:	173a
" Last Change: {{{1
" 	2023 Nov 21 by Vim Project: ignore wildignore when expanding $COMSPEC	(v173a)
" 	2023 Nov 22 by Vim Project: fix handling of very long filename on longlist style	(v173a)
"   2024 Feb 19 by Vim Project: (announce adoption)
"   2024 Feb 29 by Vim Project: handle symlinks in tree mode correctly
"   2024 Apr 03 by Vim Project: detect filetypes for remote edited files
"   2024 May 08 by Vim Project: cleanup legacy Win9X checks
"   2024 May 09 by Vim Project: remove hard-coded private.ppk
"   2024 May 10 by Vim Project: recursively delete directories by default
"   2024 May 13 by Vim Project: prefer scp over pscp
"   2024 Jun 04 by Vim Project: set bufhidden if buffer changed, nohidden is set and buffer shall be switched (#14915)
"   2024 Jun 13 by Vim Project: glob() on Windows fails when a directory name contains [] (#14952)
"   2024 Jun 23 by Vim Project: save ad restore registers when liststyle = WIDELIST (#15077, #15114)
"   2024 Jul 22 by Vim Project: avoid endless recursion (#15318)
"   2024 Jul 23 by Vim Project: escape filename before trying to delete it (#15330)
"   2024 Jul 30 by Vim Project: handle mark-copy to same target directory (#12112)
"   2024 Aug 02 by Vim Project: honor g:netrw_alt{o,v} for :{S,H,V}explore (#15417)
"   }}}
" Former Maintainer:	Charles E Campbell
" GetLatestVimScripts: 1075 1 :AutoInstall: netrw.vim
" Copyright:    Copyright (C) 2016 Charles E. Campbell {{{1
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               netrw.vim, netrwPlugin.vim, and netrwSettings.vim are provided
"               *as is* and come with no warranty of any kind, either
"               expressed or implied. By using this plugin, you agree that
"               in no event will the copyright holder be liable for any damages
"               resulting from the use of this software.
"
" Note: the code here was started in 1999 under a much earlier version of vim.  The directory browsing
"       code was written using vim v6, which did not have Lists (Lists were first offered with vim-v7).
"
"redraw!|call DechoSep()|call inputsave()|call input("Press <cr> to continue")|call inputrestore()
"
"  But be doers of the Word, and not only hearers, deluding your own selves {{{1
"  (James 1:22 RSV)
" =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
" Load Once: {{{1
if &cp || exists("g:loaded_netrw")
  finish
endif

" Check that vim has patches that netrw requires.
" Patches needed for v7.4: 1557, and 213.
" (netrw will benefit from vim's having patch#656, too)
let s:needspatches=[1557,213]
if exists("s:needspatches")
 for ptch in s:needspatches
  if v:version < 704 || (v:version == 704 && !has("patch".ptch))
   if !exists("s:needpatch{ptch}")
    unsilent echomsg "***sorry*** this version of netrw requires vim v7.4 with patch#".ptch
   endif
   let s:needpatch{ptch}= 1
   finish
  endif
 endfor
endif

let g:loaded_netrw = "v173"
if !exists("s:NOTE")
 let s:NOTE    = 0
 let s:WARNING = 1
 let s:ERROR   = 2
endif

let s:keepcpo= &cpo
setl cpo&vim
"DechoFuncName 1
"DechoRemOn
"call Decho("doing autoload/netrw.vim version ".g:loaded_netrw,'~'.expand("<slnum>"))

" ======================
"  Netrw Variables: {{{1
" ======================

" ---------------------------------------------------------------------
" netrw#ErrorMsg: {{{2
"   0=note     = s:NOTE
"   1=warning  = s:WARNING
"   2=error    = s:ERROR
"   Usage: netrw#ErrorMsg(s:NOTE | s:WARNING | s:ERROR,"some message",error-number)
"          netrw#ErrorMsg(s:NOTE | s:WARNING | s:ERROR,["message1","message2",...],error-number)
"          (this function can optionally take a list of messages)
"  Dec 2, 2019 : max errnum currently is 106
fun! netrw#ErrorMsg(level,msg,errnum)
"  call Dfunc("netrw#ErrorMsg(level=".a:level." msg<".a:msg."> errnum=".a:errnum.") g:netrw_use_errorwindow=".g:netrw_use_errorwindow)

  if a:level < g:netrw_errorlvl
"   call Dret("netrw#ErrorMsg : suppressing level=".a:level." since g:netrw_errorlvl=".g:netrw_errorlvl)
   return
  endif

  if a:level == 1
   let level= "**warning** (netrw) "
  elseif a:level == 2
   let level= "**error** (netrw) "
  else
   let level= "**note** (netrw) "
  endif
"  call Decho("level=".level,'~'.expand("<slnum>"))

  if g:netrw_use_errorwindow == 2 && (v:version > 802 || (v:version == 802 && has("patch486")))
   " use popup window
   if type(a:msg) == 3
    let msg = [level]+a:msg
   else
    let msg= level.a:msg
   endif
   let s:popuperr_id  = popup_atcursor(msg,{})
   let s:popuperr_text= ""
 elseif g:netrw_use_errorwindow
   " (default) netrw creates a one-line window to show error/warning
   " messages (reliably displayed)

   " record current window number
   let s:winBeforeErr= winnr()
"   call Decho("s:winBeforeErr=".s:winBeforeErr,'~'.expand("<slnum>"))

   " getting messages out reliably is just plain difficult!
   " This attempt splits the current window, creating a one line window.
   if bufexists("NetrwMessage") && bufwinnr("NetrwMessage") > 0
"    call Decho("write to NetrwMessage buffer",'~'.expand("<slnum>"))
    exe bufwinnr("NetrwMessage")."wincmd w"
"    call Decho("setl ma noro",'~'.expand("<slnum>"))
    setl ma noro
    if type(a:msg) == 3
     for msg in a:msg
      NetrwKeepj call setline(line("$")+1,level.msg)
     endfor
    else
     NetrwKeepj call setline(line("$")+1,level.a:msg)
    endif
    NetrwKeepj $
   else
"    call Decho("create a NetrwMessage buffer window",'~'.expand("<slnum>"))
    bo 1split
    sil! call s:NetrwEnew()
    sil! NetrwKeepj call s:NetrwOptionsSafe(1)
    setl bt=nofile
    NetrwKeepj file NetrwMessage
"    call Decho("setl ma noro",'~'.expand("<slnum>"))
    setl ma noro
    if type(a:msg) == 3
     for msg in a:msg
      NetrwKeepj call setline(line("$")+1,level.msg)
     endfor
    else
     NetrwKeepj call setline(line("$"),level.a:msg)
    endif
    NetrwKeepj $
   endif
"   call Decho("wrote msg<".level.a:msg."> to NetrwMessage win#".winnr(),'~'.expand("<slnum>"))
   if &fo !~ '[ta]'
    syn clear
    syn match netrwMesgNote	"^\*\*note\*\*"
    syn match netrwMesgWarning	"^\*\*warning\*\*"
    syn match netrwMesgError	"^\*\*error\*\*"
    hi link netrwMesgWarning WarningMsg
    hi link netrwMesgError   Error
   endif
"   call Decho("setl noma ro bh=wipe",'~'.expand("<slnum>"))
   setl ro nomod noma bh=wipe

  else
   " (optional) netrw will show messages using echomsg.  Even if the
   " message doesn't appear, at least it'll be recallable via :messages
"   redraw!
   if a:level == s:WARNING
    echohl WarningMsg
   elseif a:level == s:ERROR
    echohl Error
   endif

   if type(a:msg) == 3
     for msg in a:msg
      unsilent echomsg level.msg
     endfor
   else
    unsilent echomsg level.a:msg
   endif

"   call Decho("echomsg ***netrw*** ".a:msg,'~'.expand("<slnum>"))
   echohl None
  endif

"  call Dret("netrw#ErrorMsg")
endfun

" ---------------------------------------------------------------------
" s:NetrwInit: initializes variables if they haven't been defined {{{2
"            Loosely,  varname = value.
fun s:NetrwInit(varname,value)
" call Decho("varname<".a:varname."> value=".a:value,'~'.expand("<slnum>"))
  if !exists(a:varname)
   if type(a:value) == 0
    exe "let ".a:varname."=".a:value
   elseif type(a:value) == 1 && a:value =~ '^[{[]'
    exe "let ".a:varname."=".a:value
   elseif type(a:value) == 1
    exe "let ".a:varname."="."'".a:value."'"
   else
    exe "let ".a:varname."=".a:value
   endif
  endif
endfun

" ---------------------------------------------------------------------
"  Netrw Constants: {{{2
call s:NetrwInit("g:netrw_dirhistcnt",0)
if !exists("s:LONGLIST")
 call s:NetrwInit("s:THINLIST",0)
 call s:NetrwInit("s:LONGLIST",1)
 call s:NetrwInit("s:WIDELIST",2)
 call s:NetrwInit("s:TREELIST",3)
 call s:NetrwInit("s:MAXLIST" ,4)
endif

" ---------------------------------------------------------------------
" Default option values: {{{2
let g:netrw_localcopycmdopt    = ""
let g:netrw_localcopydircmdopt = ""
let g:netrw_localmkdiropt      = ""
let g:netrw_localmovecmdopt    = ""

" ---------------------------------------------------------------------
" Default values for netrw's global protocol variables {{{2
if !exists("g:netrw_use_errorwindow")
  let g:netrw_use_errorwindow = 0
endif

if !exists("g:netrw_dav_cmd")
 if executable("cadaver")
  let g:netrw_dav_cmd	= "cadaver"
 elseif executable("curl")
  let g:netrw_dav_cmd	= "curl"
 else
  let g:netrw_dav_cmd   = ""
 endif
endif
if !exists("g:netrw_fetch_cmd")
 if executable("fetch")
  let g:netrw_fetch_cmd	= "fetch -o"
 else
  let g:netrw_fetch_cmd	= ""
 endif
endif
if !exists("g:netrw_file_cmd")
 if executable("elinks")
  call s:NetrwInit("g:netrw_file_cmd","elinks")
 elseif executable("links")
  call s:NetrwInit("g:netrw_file_cmd","links")
 endif
endif
if !exists("g:netrw_ftp_cmd")
  let g:netrw_ftp_cmd	= "ftp"
endif
let s:netrw_ftp_cmd= g:netrw_ftp_cmd
if !exists("g:netrw_ftp_options")
 let g:netrw_ftp_options= "-i -n"
endif
if !exists("g:netrw_http_cmd")
 if executable("wget")
  let g:netrw_http_cmd	= "wget"
  call s:NetrwInit("g:netrw_http_xcmd","-q -O")
 elseif executable("curl")
  let g:netrw_http_cmd	= "curl"
  call s:NetrwInit("g:netrw_http_xcmd","-L -o")
 elseif executable("elinks")
  let g:netrw_http_cmd = "elinks"
  call s:NetrwInit("g:netrw_http_xcmd","-source >")
 elseif executable("fetch")
  let g:netrw_http_cmd	= "fetch"
  call s:NetrwInit("g:netrw_http_xcmd","-o")
 elseif executable("links")
  let g:netrw_http_cmd = "links"
  call s:NetrwInit("g:netrw_http_xcmd","-http.extra-header ".shellescape("Accept-Encoding: identity", 1)." -source >")
 else
  let g:netrw_http_cmd	= ""
 endif
endif
call s:NetrwInit("g:netrw_http_put_cmd","curl -T")
call s:NetrwInit("g:netrw_keepj","keepj")
call s:NetrwInit("g:netrw_rcp_cmd"  , "rcp")
call s:NetrwInit("g:netrw_rsync_cmd", "rsync")
call s:NetrwInit("g:netrw_rsync_sep", "/")
if !exists("g:netrw_scp_cmd")
 if executable("scp")
  call s:NetrwInit("g:netrw_scp_cmd" , "scp -q")
 elseif executable("pscp")
  call s:NetrwInit("g:netrw_scp_cmd", 'pscp -q')
 else
  call s:NetrwInit("g:netrw_scp_cmd" , "scp -q")
 endif
endif
call s:NetrwInit("g:netrw_sftp_cmd" , "sftp")
call s:NetrwInit("g:netrw_ssh_cmd"  , "ssh")

if has("win32")
  \ && exists("g:netrw_use_nt_rcp")
  \ && g:netrw_use_nt_rcp
  \ && executable( $SystemRoot .'/system32/rcp.exe')
 let s:netrw_has_nt_rcp = 1
 let s:netrw_rcpmode    = '-b'
else
 let s:netrw_has_nt_rcp = 0
 let s:netrw_rcpmode    = ''
endif

" ---------------------------------------------------------------------
" Default values for netrw's global variables {{{2
" Cygwin Detection ------- {{{3
if !exists("g:netrw_cygwin")
 if has("win32unix") && &shell =~ '\%(\<bash\>\|\<zsh\>\)\%(\.exe\)\=$'
  let g:netrw_cygwin= 1
 else
  let g:netrw_cygwin= 0
 endif
endif
" Default values - a-c ---------- {{{3
call s:NetrwInit("g:netrw_alto"        , &sb)
call s:NetrwInit("g:netrw_altv"        , &spr)
call s:NetrwInit("g:netrw_banner"      , 1)
call s:NetrwInit("g:netrw_browse_split", 0)
call s:NetrwInit("g:netrw_bufsettings" , "noma nomod nonu nobl nowrap ro nornu")
call s:NetrwInit("g:netrw_chgwin"      , -1)
call s:NetrwInit("g:netrw_clipboard"   , 1)
call s:NetrwInit("g:netrw_compress"    , "gzip")
call s:NetrwInit("g:netrw_ctags"       , "ctags")
if exists("g:netrw_cursorline") && !exists("g:netrw_cursor")
 call netrw#ErrorMsg(s:NOTE,'g:netrw_cursorline is deprecated; use g:netrw_cursor instead',77)
 let g:netrw_cursor= g:netrw_cursorline
endif
call s:NetrwInit("g:netrw_cursor"      , 2)
let s:netrw_usercul = &cursorline
let s:netrw_usercuc = &cursorcolumn
"call Decho("(netrw) COMBAK: cuc=".&l:cuc." cul=".&l:cul." initialization of s:netrw_cu[cl]")
call s:NetrwInit("g:netrw_cygdrive","/cygdrive")
" Default values - d-g ---------- {{{3
call s:NetrwInit("s:didstarstar",0)
call s:NetrwInit("g:netrw_dirhistcnt"      , 0)
call s:NetrwInit("g:netrw_decompress"       , '{ ".gz" : "gunzip", ".bz2" : "bunzip2", ".zip" : "unzip", ".tar" : "tar -xf", ".xz" : "unxz" }')
call s:NetrwInit("g:netrw_dirhistmax"       , 10)
call s:NetrwInit("g:netrw_errorlvl"  , s:NOTE)
call s:NetrwInit("g:netrw_fastbrowse"       , 1)
call s:NetrwInit("g:netrw_ftp_browse_reject", '^total\s\+\d\+$\|^Trying\s\+\d\+.*$\|^KERBEROS_V\d rejected\|^Security extensions not\|No such file\|: connect to address [0-9a-fA-F:]*: No route to host$')
if !exists("g:netrw_ftp_list_cmd")
 if has("unix") || (exists("g:netrw_cygwin") && g:netrw_cygwin)
  let g:netrw_ftp_list_cmd     = "ls -lF"
  let g:netrw_ftp_timelist_cmd = "ls -tlF"
  let g:netrw_ftp_sizelist_cmd = "ls -slF"
 else
  let g:netrw_ftp_list_cmd     = "dir"
  let g:netrw_ftp_timelist_cmd = "dir"
  let g:netrw_ftp_sizelist_cmd = "dir"
 endif
endif
call s:NetrwInit("g:netrw_ftpmode",'binary')
" Default values - h-lh ---------- {{{3
call s:NetrwInit("g:netrw_hide",1)
if !exists("g:netrw_ignorenetrc")
 if &shell =~ '\c\<\%(cmd\|4nt\)\.exe$'
  let g:netrw_ignorenetrc= 1
 else
  let g:netrw_ignorenetrc= 0
 endif
endif
call s:NetrwInit("g:netrw_keepdir",1)
if !exists("g:netrw_list_cmd")
 if g:netrw_scp_cmd =~ '^pscp' && executable("pscp")
  if exists("g:netrw_list_cmd_options")
   let g:netrw_list_cmd= g:netrw_scp_cmd." -ls USEPORT HOSTNAME: ".g:netrw_list_cmd_options
  else
   let g:netrw_list_cmd= g:netrw_scp_cmd." -ls USEPORT HOSTNAME:"
  endif
 elseif executable(g:netrw_ssh_cmd)
  " provide a scp-based default listing command
  if exists("g:netrw_list_cmd_options")
   let g:netrw_list_cmd= g:netrw_ssh_cmd." USEPORT HOSTNAME ls -FLa ".g:netrw_list_cmd_options
  else
   let g:netrw_list_cmd= g:netrw_ssh_cmd." USEPORT HOSTNAME ls -FLa"
  endif
 else
"  call Decho(g:netrw_ssh_cmd." is not executable",'~'.expand("<slnum>"))
  let g:netrw_list_cmd= ""
 endif
endif
call s:NetrwInit("g:netrw_list_hide","")
" Default values - lh-lz ---------- {{{3
if exists("g:netrw_local_copycmd")
 let g:netrw_localcopycmd= g:netrw_local_copycmd
 call netrw#ErrorMsg(s:NOTE,"g:netrw_local_copycmd is deprecated in favor of g:netrw_localcopycmd",84)
endif
if !exists("g:netrw_localcmdshell")
 let g:netrw_localcmdshell= ""
endif
if !exists("g:netrw_localcopycmd")
 if has("win32")
  if g:netrw_cygwin
   let g:netrw_localcopycmd= "cp"
  else
   let g:netrw_localcopycmd   = expand("$COMSPEC", v:true)
   let g:netrw_localcopycmdopt= " /c copy"
  endif
 elseif has("unix") || has("macunix")
  let g:netrw_localcopycmd= "cp"
 else
  let g:netrw_localcopycmd= ""
 endif
endif
if !exists("g:netrw_localcopydircmd")
 if has("win32")
  if g:netrw_cygwin
   let g:netrw_localcopydircmd   = "cp"
   let g:netrw_localcopydircmdopt= " -R"
  else
   let g:netrw_localcopydircmd   = expand("$COMSPEC", v:true)
   let g:netrw_localcopydircmdopt= " /c xcopy /e /c /h /i /k"
  endif
 elseif has("unix")
  let g:netrw_localcopydircmd   = "cp"
  let g:netrw_localcopydircmdopt= " -R"
 elseif has("macunix")
  let g:netrw_localcopydircmd   = "cp"
  let g:netrw_localcopydircmdopt= " -R"
 else
  let g:netrw_localcopydircmd= ""
 endif
endif
if exists("g:netrw_local_mkdir")
 let g:netrw_localmkdir= g:netrw_local_mkdir
 call netrw#ErrorMsg(s:NOTE,"g:netrw_local_mkdir is deprecated in favor of g:netrw_localmkdir",87)
endif
if has("win32")
  if g:netrw_cygwin
   call s:NetrwInit("g:netrw_localmkdir","mkdir")
  else
   let g:netrw_localmkdir   = expand("$COMSPEC", v:true)
   let g:netrw_localmkdiropt= " /c mkdir"
  endif
else
 call s:NetrwInit("g:netrw_localmkdir","mkdir")
endif
call s:NetrwInit("g:netrw_remote_mkdir","mkdir")
if exists("g:netrw_local_movecmd")
 let g:netrw_localmovecmd= g:netrw_local_movecmd
 call netrw#ErrorMsg(s:NOTE,"g:netrw_local_movecmd is deprecated in favor of g:netrw_localmovecmd",88)
endif
if !exists("g:netrw_localmovecmd")
 if has("win32")
  if g:netrw_cygwin
   let g:netrw_localmovecmd= "mv"
  else
   let g:netrw_localmovecmd   = expand("$COMSPEC", v:true)
   let g:netrw_localmovecmdopt= " /c move"
  endif
 elseif has("unix") || has("macunix")
  let g:netrw_localmovecmd= "mv"
 else
  let g:netrw_localmovecmd= ""
 endif
endif
" following serves as an example for how to insert a version&patch specific test
"if v:version < 704 || (v:version == 704 && !has("patch1107"))
"endif
call s:NetrwInit("g:netrw_liststyle"  , s:THINLIST)
" sanity checks
if g:netrw_liststyle < 0 || g:netrw_liststyle >= s:MAXLIST
 let g:netrw_liststyle= s:THINLIST
endif
if g:netrw_liststyle == s:LONGLIST && g:netrw_scp_cmd !~ '^pscp'
 let g:netrw_list_cmd= g:netrw_list_cmd." -l"
endif
" Default values - m-r ---------- {{{3
call s:NetrwInit("g:netrw_markfileesc"   , '*./[\~')
call s:NetrwInit("g:netrw_maxfilenamelen", 32)
call s:NetrwInit("g:netrw_menu"          , 1)
call s:NetrwInit("g:netrw_mkdir_cmd"     , g:netrw_ssh_cmd." USEPORT HOSTNAME mkdir")
call s:NetrwInit("g:netrw_mousemaps"     , (exists("+mouse") && &mouse =~# '[anh]'))
call s:NetrwInit("g:netrw_retmap"        , 0)
if has("unix") || (exists("g:netrw_cygwin") && g:netrw_cygwin)
 call s:NetrwInit("g:netrw_chgperm"       , "chmod PERM FILENAME")
elseif has("win32")
 call s:NetrwInit("g:netrw_chgperm"       , "cacls FILENAME /e /p PERM")
else
 call s:NetrwInit("g:netrw_chgperm"       , "chmod PERM FILENAME")
endif
call s:NetrwInit("g:netrw_preview"       , 0)
call s:NetrwInit("g:netrw_scpport"       , "-P")
call s:NetrwInit("g:netrw_servername"    , "NETRWSERVER")
call s:NetrwInit("g:netrw_sshport"       , "-p")
call s:NetrwInit("g:netrw_rename_cmd"    , g:netrw_ssh_cmd." USEPORT HOSTNAME mv")
call s:NetrwInit("g:netrw_rm_cmd"        , g:netrw_ssh_cmd." USEPORT HOSTNAME rm")
call s:NetrwInit("g:netrw_rmdir_cmd"     , g:netrw_ssh_cmd." USEPORT HOSTNAME rmdir")
call s:NetrwInit("g:netrw_rmf_cmd"       , g:netrw_ssh_cmd." USEPORT HOSTNAME rm -f ")
" Default values - q-s ---------- {{{3
call s:NetrwInit("g:netrw_quickhelp",0)
let s:QuickHelp= ["-:go up dir  D:delete  R:rename  s:sort-by  x:special",
   \              "(create new)  %:file  d:directory",
   \              "(windows split&open) o:horz  v:vert  p:preview",
   \              "i:style  qf:file info  O:obtain  r:reverse",
   \              "(marks)  mf:mark file  mt:set target  mm:move  mc:copy",
   \              "(bookmarks)  mb:make  mB:delete  qb:list  gb:go to",
   \              "(history)  qb:list  u:go up  U:go down",
   \              "(targets)  mt:target Tb:use bookmark  Th:use history"]
" g:netrw_sepchr: picking a character that doesn't appear in filenames that can be used to separate priority from filename
call s:NetrwInit("g:netrw_sepchr"        , (&enc == "euc-jp")? "\<Char-0x01>" : "\<Char-0xff>")
if !exists("g:netrw_keepj") || g:netrw_keepj == "keepj"
 call s:NetrwInit("s:netrw_silentxfer"    , (exists("g:netrw_silent") && g:netrw_silent != 0)? "sil keepj " : "keepj ")
else
 call s:NetrwInit("s:netrw_silentxfer"    , (exists("g:netrw_silent") && g:netrw_silent != 0)? "sil " : " ")
endif
call s:NetrwInit("g:netrw_sort_by"       , "name") " alternatives: date                                      , size
call s:NetrwInit("g:netrw_sort_options"  , "")
call s:NetrwInit("g:netrw_sort_direction", "normal") " alternative: reverse  (z y x ...)
if !exists("g:netrw_sort_sequence")
 if has("unix")
  let g:netrw_sort_sequence= '[\/]$,\<core\%(\.\d\+\)\=\>,\.h$,\.c$,\.cpp$,\~\=\*$,*,\.o$,\.obj$,\.info$,\.swp$,\.bak$,\~$'
 else
  let g:netrw_sort_sequence= '[\/]$,\.h$,\.c$,\.cpp$,*,\.o$,\.obj$,\.info$,\.swp$,\.bak$,\~$'
 endif
endif
call s:NetrwInit("g:netrw_special_syntax"   , 0)
call s:NetrwInit("g:netrw_ssh_browse_reject", '^total\s\+\d\+$')
call s:NetrwInit("g:netrw_suppress_gx_mesg",  1)
call s:NetrwInit("g:netrw_use_noswf"        , 1)
call s:NetrwInit("g:netrw_sizestyle"        ,"b")
" Default values - t-w ---------- {{{3
call s:NetrwInit("g:netrw_timefmt","%c")
if !exists("g:netrw_xstrlen")
 if exists("g:Align_xstrlen")
  let g:netrw_xstrlen= g:Align_xstrlen
 elseif exists("g:drawit_xstrlen")
  let g:netrw_xstrlen= g:drawit_xstrlen
 elseif &enc == "latin1" || !has("multi_byte")
  let g:netrw_xstrlen= 0
 else
  let g:netrw_xstrlen= 1
 endif
endif
call s:NetrwInit("g:NetrwTopLvlMenu","Netrw.")
call s:NetrwInit("g:netrw_winsize",50)
call s:NetrwInit("g:netrw_wiw",1)
if g:netrw_winsize > 100|let g:netrw_winsize= 100|endif
" ---------------------------------------------------------------------
" Default values for netrw's script variables: {{{2
call s:NetrwInit("g:netrw_fname_escape",' ?&;%')
if has("win32")
 call s:NetrwInit("g:netrw_glob_escape",'*?`{[]$')
else
 call s:NetrwInit("g:netrw_glob_escape",'*[]?`{~$\')
endif
call s:NetrwInit("g:netrw_menu_escape",'.&? \')
call s:NetrwInit("g:netrw_tmpfile_escape",' &;')
call s:NetrwInit("s:netrw_map_escape","<|\n\r\\\<C-V>\"")
if has("gui_running") && (&enc == 'utf-8' || &enc == 'utf-16' || &enc == 'ucs-4')
 let s:treedepthstring= "│ "
else
 let s:treedepthstring= "| "
endif
call s:NetrwInit("s:netrw_posn",'{}')

" BufEnter event ignored by decho when following variable is true
"  Has a side effect that doau BufReadPost doesn't work, so
"  files read by network transfer aren't appropriately highlighted.
"let g:decho_bufenter = 1	"Decho

" ======================
"  Netrw Initialization: {{{1
" ======================
if v:version >= 700 && has("balloon_eval") && !exists("s:initbeval") && !exists("g:netrw_nobeval") && has("syntax") && exists("g:syntax_on")
" call Decho("installed beval events",'~'.expand("<slnum>"))
 let &l:bexpr = "netrw#BalloonHelp()"
" call Decho("&l:bexpr<".&l:bexpr."> buf#".bufnr())
 au FileType netrw	setl beval
 au WinLeave *		if &ft == "netrw" && exists("s:initbeval")|let &beval= s:initbeval|endif
 au VimEnter * 		let s:initbeval= &beval
"else " Decho
" if v:version < 700           | call Decho("did not install beval events: v:version=".v:version." < 700","~".expand("<slnum>"))     | endif
" if !has("balloon_eval")      | call Decho("did not install beval events: does not have balloon_eval","~".expand("<slnum>"))        | endif
" if exists("s:initbeval")     | call Decho("did not install beval events: s:initbeval exists","~".expand("<slnum>"))                | endif
" if exists("g:netrw_nobeval") | call Decho("did not install beval events: g:netrw_nobeval exists","~".expand("<slnum>"))            | endif
" if !has("syntax")            | call Decho("did not install beval events: does not have syntax highlighting","~".expand("<slnum>")) | endif
" if exists("g:syntax_on")     | call Decho("did not install beval events: g:syntax_on exists","~".expand("<slnum>"))                | endif
endif
au WinEnter *	if &ft == "netrw"|call s:NetrwInsureWinVars()|endif

if g:netrw_keepj =~# "keepj"
 com! -nargs=*	NetrwKeepj	keepj <args>
else
 let g:netrw_keepj= ""
 com! -nargs=*	NetrwKeepj	<args>
endif

" ==============================
"  Netrw Utility Functions: {{{1
" ==============================

" ---------------------------------------------------------------------
" netrw#BalloonHelp: {{{2
if v:version >= 700 && has("balloon_eval") && has("syntax") && exists("g:syntax_on") && !exists("g:netrw_nobeval")
" call Decho("loading netrw#BalloonHelp()",'~'.expand("<slnum>"))
 fun! netrw#BalloonHelp()
   if &ft != "netrw"
    return ""
   endif
   if exists("s:popuperr_id") && popup_getpos(s:popuperr_id) != {}
    " popup error window is still showing
    " s:pouperr_id and s:popuperr_text are set up in netrw#ErrorMsg()
    if exists("s:popuperr_text") && s:popuperr_text != "" && v:beval_text != s:popuperr_text
     " text under mouse hasn't changed; only close window when it changes
     call popup_close(s:popuperr_id)
     unlet s:popuperr_text
    else
     let s:popuperr_text= v:beval_text
    endif
    let mesg= ""
   elseif !exists("w:netrw_bannercnt") || v:beval_lnum >= w:netrw_bannercnt || (exists("g:netrw_nobeval") && g:netrw_nobeval)
    let mesg= ""
   elseif     v:beval_text == "Netrw" || v:beval_text == "Directory" || v:beval_text == "Listing"
    let mesg = "i: thin-long-wide-tree  gh: quick hide/unhide of dot-files   qf: quick file info  %:open new file"
   elseif     getline(v:beval_lnum) =~ '^"\s*/'
    let mesg = "<cr>: edit/enter   o: edit/enter in horiz window   t: edit/enter in new tab   v:edit/enter in vert window"
   elseif     v:beval_text == "Sorted" || v:beval_text == "by"
    let mesg = 's: sort by name, time, file size, extension   r: reverse sorting order   mt: mark target'
   elseif v:beval_text == "Sort"   || v:beval_text == "sequence"
    let mesg = "S: edit sorting sequence"
   elseif v:beval_text == "Hiding" || v:beval_text == "Showing"
    let mesg = "a: hiding-showing-all   ctrl-h: editing hiding list   mh: hide/show by suffix"
   elseif v:beval_text == "Quick" || v:beval_text == "Help"
    let mesg = "Help: press <F1>"
   elseif v:beval_text == "Copy/Move" || v:beval_text == "Tgt"
    let mesg = "mt: mark target   mc: copy marked file to target   mm: move marked file to target"
   else
    let mesg= ""
   endif
   return mesg
 endfun
"else " Decho
" if v:version < 700            |call Decho("did not load netrw#BalloonHelp(): vim version ".v:version." < 700 -","~".expand("<slnum>"))|endif
" if !has("balloon_eval")       |call Decho("did not load netrw#BalloonHelp(): does not have balloon eval","~".expand("<slnum>"))       |endif
" if !has("syntax")             |call Decho("did not load netrw#BalloonHelp(): syntax disabled","~".expand("<slnum>"))                  |endif
" if !exists("g:syntax_on")     |call Decho("did not load netrw#BalloonHelp(): g:syntax_on n/a","~".expand("<slnum>"))                  |endif
" if  exists("g:netrw_nobeval") |call Decho("did not load netrw#BalloonHelp(): g:netrw_nobeval exists","~".expand("<slnum>"))           |endif
endif

" ------------------------------------------------------------------------
" netrw#Explore: launch the local browser in the directory of the current file {{{2
"          indx:  == -1: Nexplore
"                 == -2: Pexplore
"                 ==  +: this is overloaded:
"                      * If Nexplore/Pexplore is in use, then this refers to the
"                        indx'th item in the w:netrw_explore_list[] of items which
"                        matched the */pattern **/pattern *//pattern **//pattern
"                      * If Hexplore or Vexplore, then this will override
"                        g:netrw_winsize to specify the qty of rows or columns the
"                        newly split window should have.
"          dosplit==0: the window will be split iff the current file has been modified and hidden not set
"          dosplit==1: the window will be split before running the local browser
"          style == 0: Explore     style == 1: Explore!
"                == 2: Hexplore    style == 3: Hexplore!
"                == 4: Vexplore    style == 5: Vexplore!
"                == 6: Texplore
fun! netrw#Explore(indx,dosplit,style,...)
"  call Dfunc("netrw#Explore(indx=".a:indx." dosplit=".a:dosplit." style=".a:style.",a:1<".a:1.">) &modified=".&modified." modifiable=".&modifiable." a:0=".a:0." win#".winnr()." buf#".bufnr("%")." ft=".&ft)
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
  if !exists("b:netrw_curdir")
   let b:netrw_curdir= getcwd()
"   call Decho("set b:netrw_curdir<".b:netrw_curdir."> (used getcwd)",'~'.expand("<slnum>"))
  endif

  " record current file for Rexplore's benefit
  if &ft != "netrw"
   let w:netrw_rexfile= expand("%:p")
  endif

  " record current directory
  let curdir     = simplify(b:netrw_curdir)
  let curfiledir = substitute(expand("%:p"),'^\(.*[/\\]\)[^/\\]*$','\1','e')
  if !exists("g:netrw_cygwin") && has("win32")
   let curdir= substitute(curdir,'\','/','g')
  endif
"  call Decho("curdir<".curdir.">  curfiledir<".curfiledir.">",'~'.expand("<slnum>"))

  " using completion, directories with spaces in their names (thanks, Bill Gates, for a truly dumb idea)
  " will end up with backslashes here.  Solution: strip off backslashes that precede white space and
  " try Explore again.
  if a:0 > 0
"   call Decho('considering retry: a:1<'.a:1.'>: '.
     \ ((a:1 =~ "\\\s")?                   'has backslash whitespace' : 'does not have backslash whitespace').', '.
     \ ((filereadable(s:NetrwFile(a:1)))?  'is readable'              : 'is not readable').', '.
     \ ((isdirectory(s:NetrwFile(a:1))))?  'is a directory'           : 'is not a directory',
     \ '~'.expand("<slnum>"))
   if a:1 =~ "\\\s" && !filereadable(s:NetrwFile(a:1)) && !isdirectory(s:NetrwFile(a:1))
    let a1 = substitute(a:1, '\\\(\s\)', '\1', 'g')
    if a1 != a:1
      call netrw#Explore(a:indx, a:dosplit, a:style, a1)
      return
    endif
   endif
  endif

  " save registers
  sil! let keepregslash= @/

  " if   dosplit
  " -or- file has been modified AND file not hidden when abandoned
  " -or- Texplore used
  if a:dosplit || (&modified && &hidden == 0 && &bufhidden != "hide") || a:style == 6
   call s:SaveWinVars()
   let winsz= g:netrw_winsize
   if a:indx > 0
    let winsz= a:indx
   endif

   if a:style == 0      " Explore, Sexplore
    let winsz= (winsz > 0)? (winsz*winheight(0))/100 : -winsz
    if winsz == 0|let winsz= ""|endif
    exe "noswapfile ".(g:netrw_alto ? "below " : "above ").winsz."wincmd s"

   elseif a:style == 1  " Explore!, Sexplore!
    let winsz= (winsz > 0)? (winsz*winwidth(0))/100 : -winsz
    if winsz == 0|let winsz= ""|endif
    exe "keepalt noswapfile ".(g:netrw_altv ? "rightbelow " : "leftabove ").winsz."wincmd v"

   elseif a:style == 2  " Hexplore
    let winsz= (winsz > 0)? (winsz*winheight(0))/100 : -winsz
    if winsz == 0|let winsz= ""|endif
    exe "keepalt noswapfile ".(g:netrw_alto ? "below " : "above ").winsz."wincmd s"

   elseif a:style == 3  " Hexplore!
    let winsz= (winsz > 0)? (winsz*winheight(0))/100 : -winsz
    if winsz == 0|let winsz= ""|endif
    exe "keepalt noswapfile ".(!g:netrw_alto ? "below " : "above ").winsz."wincmd s"

   elseif a:style == 4  " Vexplore
    let winsz= (winsz > 0)? (winsz*winwidth(0))/100 : -winsz
    if winsz == 0|let winsz= ""|endif
    exe "keepalt noswapfile ".(g:netrw_altv ? "rightbelow " : "leftabove ").winsz."wincmd v"

   elseif a:style == 5  " Vexplore!
    let winsz= (winsz > 0)? (winsz*winwidth(0))/100 : -winsz
    if winsz == 0|let winsz= ""|endif
    exe "keepalt noswapfile ".(!g:netrw_altv ? "rightbelow " : "leftabove ").winsz."wincmd v"

   elseif a:style == 6  " Texplore
    call s:SaveBufVars()
    exe "keepalt tabnew ".fnameescape(curdir)
    call s:RestoreBufVars()
   endif
   call s:RestoreWinVars()
  endif
  NetrwKeepj norm! 0

  if a:0 > 0
"   call Decho("case [a:0=".a:0."] > 0: a:1<".a:1.">",'~'.expand("<slnum>"))
   if a:1 =~ '^\~' && (has("unix") || (exists("g:netrw_cygwin") && g:netrw_cygwin))
"    call Decho("..case a:1<".a:1.">: starts with ~ and unix or cygwin",'~'.expand("<slnum>"))
    let dirname= simplify(substitute(a:1,'\~',expand("$HOME"),''))
"    call Decho("..using dirname<".dirname.">  (case: ~ && unix||cygwin)",'~'.expand("<slnum>"))
   elseif a:1 == '.'
"    call Decho("..case a:1<".a:1.">: matches .",'~'.expand("<slnum>"))
    let dirname= simplify(exists("b:netrw_curdir")? b:netrw_curdir : getcwd())
    if dirname !~ '/$'
     let dirname= dirname."/"
    endif
"    call Decho("..using dirname<".dirname.">  (case: ".(exists("b:netrw_curdir")? "b:netrw_curdir" : "getcwd()").")",'~'.expand("<slnum>"))
   elseif a:1 =~ '\$'
"    call Decho("..case a:1<".a:1.">: matches ending $",'~'.expand("<slnum>"))
    let dirname= simplify(expand(a:1))
"    call Decho("..using user-specified dirname<".dirname."> with $env-var",'~'.expand("<slnum>"))
   elseif a:1 !~ '^\*\{1,2}/' && a:1 !~ '^\a\{3,}://'
"    call Decho("..case a:1<".a:1.">: other, not pattern or filepattern",'~'.expand("<slnum>"))
    let dirname= simplify(a:1)
"    call Decho("..using user-specified dirname<".dirname.">",'~'.expand("<slnum>"))
   else
"    call Decho("..case a:1: pattern or filepattern",'~'.expand("<slnum>"))
    let dirname= a:1
   endif
  else
   " clear explore
"   call Decho("case a:0=".a:0.": clearing Explore list",'~'.expand("<slnum>"))
   call s:NetrwClearExplore()
"   call Dret("netrw#Explore : cleared list")
   return
  endif

"  call Decho("dirname<".dirname.">",'~'.expand("<slnum>"))
  if dirname =~ '\.\./\=$'
   let dirname= simplify(fnamemodify(dirname,':p:h'))
  elseif dirname =~ '\.\.' || dirname == '.'
   let dirname= simplify(fnamemodify(dirname,':p'))
  endif
"  call Decho("dirname<".dirname.">  (after simplify)",'~'.expand("<slnum>"))

  if dirname =~ '^\*//'
   " starpat=1: Explore *//pattern   (current directory only search for files containing pattern)
"   call Decho("case starpat=1: Explore *//pattern",'~'.expand("<slnum>"))
   let pattern= substitute(dirname,'^\*//\(.*\)$','\1','')
   let starpat= 1
"   call Decho("..Explore *//pat: (starpat=".starpat.") dirname<".dirname."> -> pattern<".pattern.">",'~'.expand("<slnum>"))
   if &hls | let keepregslash= s:ExplorePatHls(pattern) | endif

  elseif dirname =~ '^\*\*//'
   " starpat=2: Explore **//pattern  (recursive descent search for files containing pattern)
"   call Decho("case starpat=2: Explore **//pattern",'~'.expand("<slnum>"))
   let pattern= substitute(dirname,'^\*\*//','','')
   let starpat= 2
"   call Decho("..Explore **//pat: (starpat=".starpat.") dirname<".dirname."> -> pattern<".pattern.">",'~'.expand("<slnum>"))

  elseif dirname =~ '/\*\*/'
   " handle .../**/.../filepat
"   call Decho("case starpat=4: Explore .../**/.../filepat",'~'.expand("<slnum>"))
   let prefixdir= substitute(dirname,'^\(.\{-}\)\*\*.*$','\1','')
   if prefixdir =~ '^/' || (prefixdir =~ '^\a:/' && has("win32"))
    let b:netrw_curdir = prefixdir
   else
    let b:netrw_curdir= getcwd().'/'.prefixdir
   endif
   let dirname= substitute(dirname,'^.\{-}\(\*\*/.*\)$','\1','')
   let starpat= 4
"   call Decho("..pwd<".getcwd()."> dirname<".dirname.">",'~'.expand("<slnum>"))
"   call Decho("..case Explore ../**/../filepat (starpat=".starpat.")",'~'.expand("<slnum>"))

  elseif dirname =~ '^\*/'
   " case starpat=3: Explore */filepat   (search in current directory for filenames matching filepat)
   let starpat= 3
"   call Decho("case starpat=3: Explore */filepat (starpat=".starpat.")",'~'.expand("<slnum>"))

  elseif dirname=~ '^\*\*/'
   " starpat=4: Explore **/filepat  (recursive descent search for filenames matching filepat)
   let starpat= 4
"   call Decho("case starpat=4: Explore **/filepat (starpat=".starpat.")",'~'.expand("<slnum>"))

  else
   let starpat= 0
"   call Decho("case starpat=0: default",'~'.expand("<slnum>"))
  endif

  if starpat == 0 && a:indx >= 0
   " [Explore Hexplore Vexplore Sexplore] [dirname]
"   call Decho("case starpat==0 && a:indx=".a:indx.": dirname<".dirname.">, handles Explore Hexplore Vexplore Sexplore",'~'.expand("<slnum>"))
   if dirname == ""
    let dirname= curfiledir
"    call Decho("..empty dirname, using current file's directory<".dirname.">",'~'.expand("<slnum>"))
   endif
   if dirname =~# '^scp://' || dirname =~ '^ftp://'
    call netrw#Nread(2,dirname)
   else
    if dirname == ""
     let dirname= getcwd()
    elseif has("win32") && !g:netrw_cygwin
     " Windows : check for a drive specifier, or else for a remote share name ('\\Foo' or '//Foo',
     " depending on whether backslashes have been converted to forward slashes by earlier code).
     if dirname !~ '^[a-zA-Z]:' && dirname !~ '^\\\\\w\+' && dirname !~ '^//\w\+'
      let dirname= b:netrw_curdir."/".dirname
     endif
    elseif dirname !~ '^/'
     let dirname= b:netrw_curdir."/".dirname
    endif
"    call Decho("..calling LocalBrowseCheck(dirname<".dirname.">)",'~'.expand("<slnum>"))
    call netrw#LocalBrowseCheck(dirname)
"    call Decho(" modified=".&modified." modifiable=".&modifiable." readonly=".&readonly,'~'.expand("<slnum>"))
"    call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
   endif
   if exists("w:netrw_bannercnt")
    " done to handle P08-Ingelrest. :Explore will _Always_ go to the line just after the banner.
    " If one wants to return the same place in the netrw window, use :Rex instead.
    exe w:netrw_bannercnt
   endif

"   call Decho("curdir<".curdir.">",'~'.expand("<slnum>"))
   " ---------------------------------------------------------------------
   " Jan 24, 2013: not sure why the following was present.  See P08-Ingelrest
"   if has("win32") || has("win95") || has("win64") || has("win16")
"    NetrwKeepj call search('\<'.substitute(curdir,'^.*[/\\]','','e').'\>','cW')
"   else
"    NetrwKeepj call search('\<'.substitute(curdir,'^.*/','','e').'\>','cW')
"   endif
   " ---------------------------------------------------------------------

  " starpat=1: Explore *//pattern  (current directory only search for files containing pattern)
  " starpat=2: Explore **//pattern (recursive descent search for files containing pattern)
  " starpat=3: Explore */filepat   (search in current directory for filenames matching filepat)
  " starpat=4: Explore **/filepat  (recursive descent search for filenames matching filepat)
  elseif a:indx <= 0
   " Nexplore, Pexplore, Explore: handle starpat
"   call Decho("case a:indx<=0: Nexplore, Pexplore, <s-down>, <s-up> starpat=".starpat." a:indx=".a:indx,'~'.expand("<slnum>"))
   if !mapcheck("<s-up>","n") && !mapcheck("<s-down>","n") && exists("b:netrw_curdir")
"    call Decho("..set up <s-up> and <s-down> maps",'~'.expand("<slnum>"))
    let s:didstarstar= 1
    nnoremap <buffer> <silent> <s-up>	:Pexplore<cr>
    nnoremap <buffer> <silent> <s-down>	:Nexplore<cr>
   endif

   if has("path_extra")
"    call Decho("..starpat=".starpat.": has +path_extra",'~'.expand("<slnum>"))
    if !exists("w:netrw_explore_indx")
     let w:netrw_explore_indx= 0
    endif

    let indx = a:indx
"    call Decho("..starpat=".starpat.": set indx= [a:indx=".indx."]",'~'.expand("<slnum>"))

    if indx == -1
     " Nexplore
"     call Decho("..case Nexplore with starpat=".starpat.": (indx=".indx.")",'~'.expand("<slnum>"))
     if !exists("w:netrw_explore_list") " sanity check
      NetrwKeepj call netrw#ErrorMsg(s:WARNING,"using Nexplore or <s-down> improperly; see help for netrw-starstar",40)
      sil! let @/ = keepregslash
"      call Dret("netrw#Explore")
      return
     endif
     let indx= w:netrw_explore_indx
     if indx < 0                        | let indx= 0                           | endif
     if indx >= w:netrw_explore_listlen | let indx= w:netrw_explore_listlen - 1 | endif
     let curfile= w:netrw_explore_list[indx]
"     call Decho("....indx=".indx." curfile<".curfile.">",'~'.expand("<slnum>"))
     while indx < w:netrw_explore_listlen && curfile == w:netrw_explore_list[indx]
      let indx= indx + 1
"      call Decho("....indx=".indx." (Nexplore while loop)",'~'.expand("<slnum>"))
     endwhile
     if indx >= w:netrw_explore_listlen | let indx= w:netrw_explore_listlen - 1 | endif
"     call Decho("....Nexplore: indx= [w:netrw_explore_indx=".w:netrw_explore_indx."]=".indx,'~'.expand("<slnum>"))

    elseif indx == -2
     " Pexplore
"     call Decho("case Pexplore with starpat=".starpat.": (indx=".indx.")",'~'.expand("<slnum>"))
     if !exists("w:netrw_explore_list") " sanity check
      NetrwKeepj call netrw#ErrorMsg(s:WARNING,"using Pexplore or <s-up> improperly; see help for netrw-starstar",41)
      sil! let @/ = keepregslash
"      call Dret("netrw#Explore")
      return
     endif
     let indx= w:netrw_explore_indx
     if indx < 0                        | let indx= 0                           | endif
     if indx >= w:netrw_explore_listlen | let indx= w:netrw_explore_listlen - 1 | endif
     let curfile= w:netrw_explore_list[indx]
"     call Decho("....indx=".indx." curfile<".curfile.">",'~'.expand("<slnum>"))
     while indx >= 0 && curfile == w:netrw_explore_list[indx]
      let indx= indx - 1
"      call Decho("....indx=".indx." (Pexplore while loop)",'~'.expand("<slnum>"))
     endwhile
     if indx < 0                        | let indx= 0                           | endif
"     call Decho("....Pexplore: indx= [w:netrw_explore_indx=".w:netrw_explore_indx."]=".indx,'~'.expand("<slnum>"))

    else
     " Explore -- initialize
     " build list of files to Explore with Nexplore/Pexplore
"     call Decho("..starpat=".starpat.": case Explore: initialize (indx=".indx.")",'~'.expand("<slnum>"))
     NetrwKeepj keepalt call s:NetrwClearExplore()
     let w:netrw_explore_indx= 0
     if !exists("b:netrw_curdir")
      let b:netrw_curdir= getcwd()
     endif
"     call Decho("....starpat=".starpat.": b:netrw_curdir<".b:netrw_curdir.">",'~'.expand("<slnum>"))

     " switch on starpat to build the w:netrw_explore_list of files
     if starpat == 1
      " starpat=1: Explore *//pattern  (current directory only search for files containing pattern)
"      call Decho("..case starpat=".starpat.": build *//pattern list  (curdir-only srch for files containing pattern)  &hls=".&hls,'~'.expand("<slnum>"))
"      call Decho("....pattern<".pattern.">",'~'.expand("<slnum>"))
      try
       exe "NetrwKeepj noautocmd vimgrep /".pattern."/gj ".fnameescape(b:netrw_curdir)."/*"
      catch /^Vim\%((\a\+)\)\=:E480/
       keepalt call netrw#ErrorMsg(s:WARNING,"no match with pattern<".pattern.">",76)
"       call Dret("netrw#Explore : unable to find pattern<".pattern.">")
       return
      endtry
      let w:netrw_explore_list = s:NetrwExploreListUniq(map(getqflist(),'bufname(v:val.bufnr)'))
      if &hls | let keepregslash= s:ExplorePatHls(pattern) | endif

     elseif starpat == 2
      " starpat=2: Explore **//pattern (recursive descent search for files containing pattern)
"      call Decho("..case starpat=".starpat.": build **//pattern list  (recursive descent files containing pattern)",'~'.expand("<slnum>"))
"      call Decho("....pattern<".pattern.">",'~'.expand("<slnum>"))
      try
       exe "sil NetrwKeepj noautocmd keepalt vimgrep /".pattern."/gj "."**/*"
      catch /^Vim\%((\a\+)\)\=:E480/
       keepalt call netrw#ErrorMsg(s:WARNING,'no files matched pattern<'.pattern.'>',45)
       if &hls | let keepregslash= s:ExplorePatHls(pattern) | endif
       sil! let @/ = keepregslash
"       call Dret("netrw#Explore : no files matched pattern")
       return
      endtry
      let s:netrw_curdir       = b:netrw_curdir
      let w:netrw_explore_list = getqflist()
      let w:netrw_explore_list = s:NetrwExploreListUniq(map(w:netrw_explore_list,'s:netrw_curdir."/".bufname(v:val.bufnr)'))
      if &hls | let keepregslash= s:ExplorePatHls(pattern) | endif

     elseif starpat == 3
      " starpat=3: Explore */filepat   (search in current directory for filenames matching filepat)
"      call Decho("..case starpat=".starpat.": build */filepat list  (curdir-only srch filenames matching filepat)  &hls=".&hls,'~'.expand("<slnum>"))
      let filepat= substitute(dirname,'^\*/','','')
      let filepat= substitute(filepat,'^[%#<]','\\&','')
"      call Decho("....b:netrw_curdir<".b:netrw_curdir.">",'~'.expand("<slnum>"))
"      call Decho("....filepat<".filepat.">",'~'.expand("<slnum>"))
      let w:netrw_explore_list= s:NetrwExploreListUniq(split(expand(b:netrw_curdir."/".filepat),'\n'))
      if &hls | let keepregslash= s:ExplorePatHls(filepat) | endif

     elseif starpat == 4
      " starpat=4: Explore **/filepat  (recursive descent search for filenames matching filepat)
"      call Decho("..case starpat=".starpat.": build **/filepat list  (recursive descent srch filenames matching filepat)  &hls=".&hls,'~'.expand("<slnum>"))
      let w:netrw_explore_list= s:NetrwExploreListUniq(split(expand(b:netrw_curdir."/".dirname),'\n'))
      if &hls | let keepregslash= s:ExplorePatHls(dirname) | endif
     endif " switch on starpat to build w:netrw_explore_list

     let w:netrw_explore_listlen = len(w:netrw_explore_list)
"     call Decho("....w:netrw_explore_list<".string(w:netrw_explore_list).">",'~'.expand("<slnum>"))
"     call Decho("....w:netrw_explore_listlen=".w:netrw_explore_listlen,'~'.expand("<slnum>"))

     if w:netrw_explore_listlen == 0 || (w:netrw_explore_listlen == 1 && w:netrw_explore_list[0] =~ '\*\*\/')
      keepalt NetrwKeepj call netrw#ErrorMsg(s:WARNING,"no files matched",42)
      sil! let @/ = keepregslash
"      call Dret("netrw#Explore : no files matched")
      return
     endif
    endif  " if indx ... endif

    " NetrwStatusLine support - for exploring support
    let w:netrw_explore_indx= indx
"    call Decho("....w:netrw_explore_list<".join(w:netrw_explore_list,',')."> len=".w:netrw_explore_listlen,'~'.expand("<slnum>"))

    " wrap the indx around, but issue a note
    if indx >= w:netrw_explore_listlen || indx < 0
"     call Decho("....wrap indx (indx=".indx." listlen=".w:netrw_explore_listlen.")",'~'.expand("<slnum>"))
     let indx                = (indx < 0)? ( w:netrw_explore_listlen - 1 ) : 0
     let w:netrw_explore_indx= indx
     keepalt NetrwKeepj call netrw#ErrorMsg(s:NOTE,"no more files match Explore pattern",43)
    endif

    exe "let dirfile= w:netrw_explore_list[".indx."]"
"    call Decho("....dirfile=w:netrw_explore_list[indx=".indx."]= <".dirfile.">",'~'.expand("<slnum>"))
    let newdir= substitute(dirfile,'/[^/]*$','','e')
"    call Decho("....newdir<".newdir.">",'~'.expand("<slnum>"))

"    call Decho("....calling LocalBrowseCheck(newdir<".newdir.">)",'~'.expand("<slnum>"))
    call netrw#LocalBrowseCheck(newdir)
    if !exists("w:netrw_liststyle")
     let w:netrw_liststyle= g:netrw_liststyle
    endif
    if w:netrw_liststyle == s:THINLIST || w:netrw_liststyle == s:LONGLIST
     keepalt NetrwKeepj call search('^'.substitute(dirfile,"^.*/","","").'\>',"W")
    else
     keepalt NetrwKeepj call search('\<'.substitute(dirfile,"^.*/","","").'\>',"w")
    endif
    let w:netrw_explore_mtchcnt = indx + 1
    let w:netrw_explore_bufnr   = bufnr("%")
    let w:netrw_explore_line    = line(".")
    keepalt NetrwKeepj call s:SetupNetrwStatusLine('%f %h%m%r%=%9*%{NetrwStatusLine()}')
"    call Decho("....explore: mtchcnt=".w:netrw_explore_mtchcnt." bufnr=".w:netrw_explore_bufnr." line#".w:netrw_explore_line,'~'.expand("<slnum>"))

   else
"    call Decho("..your vim does not have +path_extra",'~'.expand("<slnum>"))
    if !exists("g:netrw_quiet")
     keepalt NetrwKeepj call netrw#ErrorMsg(s:WARNING,"your vim needs the +path_extra feature for Exploring with **!",44)
    endif
    sil! let @/ = keepregslash
"    call Dret("netrw#Explore : missing +path_extra")
    return
   endif

  else
"   call Decho("..default case: Explore newdir<".dirname.">",'~'.expand("<slnum>"))
   if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && dirname =~ '/'
    sil! unlet w:netrw_treedict
    sil! unlet w:netrw_treetop
   endif
   let newdir= dirname
   if !exists("b:netrw_curdir")
    NetrwKeepj call netrw#LocalBrowseCheck(getcwd())
   else
    NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,newdir))
   endif
  endif

  " visual display of **/ **// */ Exploration files
"  call Decho("w:netrw_explore_indx=".(exists("w:netrw_explore_indx")? w:netrw_explore_indx : "doesn't exist"),'~'.expand("<slnum>"))
"  call Decho("b:netrw_curdir<".(exists("b:netrw_curdir")? b:netrw_curdir : "n/a").">",'~'.expand("<slnum>"))
  if exists("w:netrw_explore_indx") && exists("b:netrw_curdir")
"   call Decho("s:explore_prvdir<".(exists("s:explore_prvdir")? s:explore_prvdir : "-doesn't exist-"),'~'.expand("<slnum>"))
   if !exists("s:explore_prvdir") || s:explore_prvdir != b:netrw_curdir
    " only update match list when current directory isn't the same as before
"    call Decho("only update match list when current directory not the same as before",'~'.expand("<slnum>"))
    let s:explore_prvdir = b:netrw_curdir
    let s:explore_match  = ""
    let dirlen           = strlen(b:netrw_curdir)
    if b:netrw_curdir !~ '/$'
     let dirlen= dirlen + 1
    endif
    let prvfname= ""
    for fname in w:netrw_explore_list
"     call Decho("fname<".fname.">",'~'.expand("<slnum>"))
     if fname =~ '^'.b:netrw_curdir
      if s:explore_match == ""
       let s:explore_match= '\<'.escape(strpart(fname,dirlen),g:netrw_markfileesc).'\>'
      else
       let s:explore_match= s:explore_match.'\|\<'.escape(strpart(fname,dirlen),g:netrw_markfileesc).'\>'
      endif
     elseif fname !~ '^/' && fname != prvfname
      if s:explore_match == ""
       let s:explore_match= '\<'.escape(fname,g:netrw_markfileesc).'\>'
      else
       let s:explore_match= s:explore_match.'\|\<'.escape(fname,g:netrw_markfileesc).'\>'
      endif
     endif
     let prvfname= fname
    endfor
"    call Decho("explore_match<".s:explore_match.">",'~'.expand("<slnum>"))
    if has("syntax") && exists("g:syntax_on") && g:syntax_on
     exe "2match netrwMarkFile /".s:explore_match."/"
    endif
   endif
   echo "<s-up>==Pexplore  <s-down>==Nexplore"
  else
   2match none
   if exists("s:explore_match")  | unlet s:explore_match  | endif
   if exists("s:explore_prvdir") | unlet s:explore_prvdir | endif
"   call Decho("cleared explore match list",'~'.expand("<slnum>"))
  endif

  " since Explore may be used to initialize netrw's browser,
  " there's no danger of a late FocusGained event on initialization.
  " Consequently, set s:netrw_events to 2.
  let s:netrw_events= 2
  sil! let @/ = keepregslash
"  call Dret("netrw#Explore : @/<".@/.">")
endfun

" ---------------------------------------------------------------------
" netrw#Lexplore: toggle Explorer window, keeping it on the left of the current tab {{{2
"   Uses  g:netrw_chgwin  : specifies the window where Lexplore files are to be opened
"         t:netrw_lexposn : winsaveview() output (used on Lexplore window)
"         t:netrw_lexbufnr: the buffer number of the Lexplore buffer  (internal to this function)
"         s:lexplore_win  : window number of Lexplore window (serves to indicate which window is a Lexplore window)
"         w:lexplore_buf  : buffer number of Lexplore window (serves to indicate which window is a Lexplore window)
fun! netrw#Lexplore(count,rightside,...)
"  call Dfunc("netrw#Lexplore(count=".a:count." rightside=".a:rightside.",...) a:0=".a:0." ft=".&ft)
  let curwin= winnr()

  if a:0 > 0 && a:1 != ""
   " if a netrw window is already on the left-side of the tab
   " and a directory has been specified, explore with that
   " directory.
"   call Decho("case has input argument(s) (a:1<".a:1.">)")
   let a1 = expand(a:1)
"   call Decho("a:1<".a:1.">  curwin#".curwin,'~'.expand("<slnum>"))
   exe "1wincmd w"
   if &ft == "netrw"
"    call Decho("exe Explore ".fnameescape(a:1),'~'.expand("<slnum>"))
    exe "Explore ".fnameescape(a1)
    exe curwin."wincmd w"
    let s:lexplore_win= curwin
    let w:lexplore_buf= bufnr("%")
    if exists("t:netrw_lexposn")
"     call Decho("forgetting t:netrw_lexposn",'~'.expand("<slnum>"))
     unlet t:netrw_lexposn
    endif
"    call Dret("netrw#Lexplore")
    return
   endif
   exe curwin."wincmd w"
  else
   let a1= ""
"   call Decho("no input arguments")
  endif

  if exists("t:netrw_lexbufnr")
   " check if t:netrw_lexbufnr refers to a netrw window
   let lexwinnr = bufwinnr(t:netrw_lexbufnr)
"   call Decho("lexwinnr= bufwinnr(t:netrw_lexbufnr#".t:netrw_lexbufnr.")=".lexwinnr)
  else
   let lexwinnr= 0
"   call Decho("t:netrw_lexbufnr doesn't exist")
  endif
"  call Decho("lexwinnr=".lexwinnr,'~'.expand("<slnum>"))

  if lexwinnr > 0
   " close down netrw explorer window
"   call Decho("t:netrw_lexbufnr#".t:netrw_lexbufnr.": close down netrw window",'~'.expand("<slnum>"))
   exe lexwinnr."wincmd w"
   let g:netrw_winsize = -winwidth(0)
   let t:netrw_lexposn = winsaveview()
"   call Decho("saving posn to t:netrw_lexposn<".string(t:netrw_lexposn).">",'~'.expand("<slnum>"))
"   call Decho("saving t:netrw_lexposn",'~'.expand("<slnum>"))
   close
   if lexwinnr < curwin
    let curwin= curwin - 1
   endif
   if lexwinnr != curwin
    exe curwin."wincmd w"
   endif
   unlet t:netrw_lexbufnr
"   call Decho("unlet t:netrw_lexbufnr")

  else
   " open netrw explorer window
"   call Decho("t:netrw_lexbufnr<n/a>: open netrw explorer window",'~'.expand("<slnum>"))
   exe "1wincmd w"
   let keep_altv    = g:netrw_altv
   let g:netrw_altv = 0
   if a:count != 0
    let netrw_winsize   = g:netrw_winsize
    let g:netrw_winsize = a:count
   endif
   let curfile= expand("%")
"   call Decho("curfile<".curfile.">",'~'.expand("<slnum>"))
   exe (a:rightside? "botright" : "topleft")." vertical ".((g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize) . " new"
"   call Decho("new buf#".bufnr("%")." win#".winnr())
   if a:0 > 0 && a1 != ""
"    call Decho("case 1: Explore ".a1,'~'.expand("<slnum>"))
    call netrw#Explore(0,0,0,a1)
    exe "Explore ".fnameescape(a1)
   elseif curfile =~ '^\a\{3,}://'
"    call Decho("case 2: Explore ".substitute(curfile,'[^/\\]*$','',''),'~'.expand("<slnum>"))
    call netrw#Explore(0,0,0,substitute(curfile,'[^/\\]*$','',''))
   else
"    call Decho("case 3: Explore .",'~'.expand("<slnum>"))
    call netrw#Explore(0,0,0,".")
   endif
   if a:count != 0
    let g:netrw_winsize = netrw_winsize
   endif
   setlocal winfixwidth
   let g:netrw_altv     = keep_altv
   let t:netrw_lexbufnr = bufnr("%")
   " done to prevent build-up of hidden buffers due to quitting and re-invocation of :Lexplore.
   " Since the intended use of :Lexplore is to have an always-present explorer window, the extra
   " effort to prevent mis-use of :Lex is warranted.
   set bh=wipe
"   call Decho("let t:netrw_lexbufnr=".t:netrw_lexbufnr) 
"   call Decho("t:netrw_lexposn".(exists("t:netrw_lexposn")? string(t:netrw_lexposn) : " n/a"))
   if exists("t:netrw_lexposn")
"    call Decho("restoring to t:netrw_lexposn",'~'.expand("<slnum>"))
"    call Decho("restoring posn to t:netrw_lexposn<".string(t:netrw_lexposn).">",'~'.expand("<slnum>"))
    call winrestview(t:netrw_lexposn)
    unlet t:netrw_lexposn
   endif
  endif

  " set up default window for editing via <cr>
  if exists("g:netrw_chgwin") && g:netrw_chgwin == -1
   if a:rightside
    let g:netrw_chgwin= 1
   else
    let g:netrw_chgwin= 2
   endif
"   call Decho("let g:netrw_chgwin=".g:netrw_chgwin)
  endif

"  call Dret("netrw#Lexplore")
endfun

" ---------------------------------------------------------------------
" netrw#Clean: remove netrw {{{2
" supports :NetrwClean  -- remove netrw from first directory on runtimepath
"          :NetrwClean! -- remove netrw from all directories on runtimepath
fun! netrw#Clean(sys)
"  call Dfunc("netrw#Clean(sys=".a:sys.")")

  if a:sys
   let choice= confirm("Remove personal and system copies of netrw?","&Yes\n&No")
  else
   let choice= confirm("Remove personal copy of netrw?","&Yes\n&No")
  endif
"  call Decho("choice=".choice,'~'.expand("<slnum>"))
  let diddel= 0
  let diddir= ""

  if choice == 1
   for dir in split(&rtp,',')
    if filereadable(dir."/plugin/netrwPlugin.vim")
"     call Decho("removing netrw-related files from ".dir,'~'.expand("<slnum>"))
     if s:NetrwDelete(dir."/plugin/netrwPlugin.vim")        |call netrw#ErrorMsg(1,"unable to remove ".dir."/plugin/netrwPlugin.vim",55)        |endif
     if s:NetrwDelete(dir."/autoload/netrwFileHandlers.vim")|call netrw#ErrorMsg(1,"unable to remove ".dir."/autoload/netrwFileHandlers.vim",55)|endif
     if s:NetrwDelete(dir."/autoload/netrwSettings.vim")    |call netrw#ErrorMsg(1,"unable to remove ".dir."/autoload/netrwSettings.vim",55)    |endif
     if s:NetrwDelete(dir."/autoload/netrw.vim")            |call netrw#ErrorMsg(1,"unable to remove ".dir."/autoload/netrw.vim",55)            |endif
     if s:NetrwDelete(dir."/syntax/netrw.vim")              |call netrw#ErrorMsg(1,"unable to remove ".dir."/syntax/netrw.vim",55)              |endif
     if s:NetrwDelete(dir."/syntax/netrwlist.vim")          |call netrw#ErrorMsg(1,"unable to remove ".dir."/syntax/netrwlist.vim",55)          |endif
     let diddir= dir
     let diddel= diddel + 1
     if !a:sys|break|endif
    endif
   endfor
  endif

   echohl WarningMsg
  if diddel == 0
   echomsg "netrw is either not installed or not removable"
  elseif diddel == 1
   echomsg "removed one copy of netrw from <".diddir.">"
  else
   echomsg "removed ".diddel." copies of netrw"
  endif
   echohl None

"  call Dret("netrw#Clean")
endfun

" ---------------------------------------------------------------------
" netrw#MakeTgt: make a target out of the directory name provided {{{2
fun! netrw#MakeTgt(dname)
"  call Dfunc("netrw#MakeTgt(dname<".a:dname.">)")
   " simplify the target (eg. /abc/def/../ghi -> /abc/ghi)
  let svpos               = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let s:netrwmftgt_islocal= (a:dname !~ '^\a\{3,}://')
"  call Decho("s:netrwmftgt_islocal=".s:netrwmftgt_islocal,'~'.expand("<slnum>"))
  if s:netrwmftgt_islocal
   let netrwmftgt= simplify(a:dname)
  else
   let netrwmftgt= a:dname
  endif
  if exists("s:netrwmftgt") && netrwmftgt == s:netrwmftgt
   " re-selected target, so just clear it
   unlet s:netrwmftgt s:netrwmftgt_islocal
  else
   let s:netrwmftgt= netrwmftgt
  endif
  if g:netrw_fastbrowse <= 1
   call s:NetrwRefresh((b:netrw_curdir !~ '\a\{3,}://'),b:netrw_curdir)
  endif
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))"
  call winrestview(svpos)
"  call Dret("netrw#MakeTgt")
endfun

" ---------------------------------------------------------------------
" netrw#Obtain: {{{2
"   netrw#Obtain(islocal,fname[,tgtdirectory])
"     islocal=0  obtain from remote source
"            =1  obtain from local source
"     fname  :   a filename or a list of filenames
"     tgtdir :   optional place where files are to go  (not present, uses getcwd())
fun! netrw#Obtain(islocal,fname,...)
"  call Dfunc("netrw#Obtain(islocal=".a:islocal." fname<".((type(a:fname) == 1)? a:fname : string(a:fname)).">) a:0=".a:0)
  " NetrwStatusLine support - for obtaining support

  if type(a:fname) == 1
   let fnamelist= [ a:fname ]
  elseif type(a:fname) == 3
   let fnamelist= a:fname
  else
   call netrw#ErrorMsg(s:ERROR,"attempting to use NetrwObtain on something not a filename or a list",62)
"   call Dret("netrw#Obtain")
   return
  endif
"  call Decho("fnamelist<".string(fnamelist).">",'~'.expand("<slnum>"))
  if a:0 > 0
   let tgtdir= a:1
  else
   let tgtdir= getcwd()
  endif
"  call Decho("tgtdir<".tgtdir.">",'~'.expand("<slnum>"))

  if exists("b:netrw_islocal") && b:netrw_islocal
   " obtain a file from local b:netrw_curdir to (local) tgtdir
"   call Decho("obtain a file from local ".b:netrw_curdir." to ".tgtdir,'~'.expand("<slnum>"))
   if exists("b:netrw_curdir") && getcwd() != b:netrw_curdir
    let topath= s:ComposePath(tgtdir,"")
    if has("win32")
     " transfer files one at time
"     call Decho("transfer files one at a time",'~'.expand("<slnum>"))
     for fname in fnamelist
"      call Decho("system(".g:netrw_localcopycmd." ".s:ShellEscape(fname)." ".s:ShellEscape(topath).")",'~'.expand("<slnum>"))
      call system(g:netrw_localcopycmd.g:netrw_localcopycmdopt." ".s:ShellEscape(fname)." ".s:ShellEscape(topath))
      if v:shell_error != 0
       call netrw#ErrorMsg(s:WARNING,"consider setting g:netrw_localcopycmd<".g:netrw_localcopycmd."> to something that works",80)
"       call Dret("s:NetrwObtain 0 : failed: ".g:netrw_localcopycmd." ".s:ShellEscape(fname)." ".s:ShellEscape(topath))
       return
      endif
     endfor
    else
     " transfer files with one command
"     call Decho("transfer files with one command",'~'.expand("<slnum>"))
     let filelist= join(map(deepcopy(fnamelist),"s:ShellEscape(v:val)"))
"     call Decho("system(".g:netrw_localcopycmd." ".filelist." ".s:ShellEscape(topath).")",'~'.expand("<slnum>"))
     call system(g:netrw_localcopycmd.g:netrw_localcopycmdopt." ".filelist." ".s:ShellEscape(topath))
     if v:shell_error != 0
      call netrw#ErrorMsg(s:WARNING,"consider setting g:netrw_localcopycmd<".g:netrw_localcopycmd."> to something that works",80)
"      call Dret("s:NetrwObtain 0 : failed: ".g:netrw_localcopycmd." ".filelist." ".s:ShellEscape(topath))
      return
     endif
    endif
   elseif !exists("b:netrw_curdir")
    call netrw#ErrorMsg(s:ERROR,"local browsing directory doesn't exist!",36)
   else
    call netrw#ErrorMsg(s:WARNING,"local browsing directory and current directory are identical",37)
   endif

  else
   " obtain files from remote b:netrw_curdir to local tgtdir
"   call Decho("obtain a file from remote ".b:netrw_curdir." to ".tgtdir,'~'.expand("<slnum>"))
   if type(a:fname) == 1
    call s:SetupNetrwStatusLine('%f %h%m%r%=%9*Obtaining '.a:fname)
   endif
   call s:NetrwMethod(b:netrw_curdir)

   if b:netrw_method == 4
    " obtain file using scp
"    call Decho("obtain via scp (method#4)",'~'.expand("<slnum>"))
    if exists("g:netrw_port") && g:netrw_port != ""
     let useport= " ".g:netrw_scpport." ".g:netrw_port
    else
     let useport= ""
    endif
    if b:netrw_fname =~ '/'
     let path= substitute(b:netrw_fname,'^\(.*/\).\{-}$','\1','')
    else
     let path= ""
    endif
    let filelist= join(map(deepcopy(fnamelist),'escape(s:ShellEscape(g:netrw_machine.":".path.v:val,1)," ")'))
    call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_scp_cmd.s:ShellEscape(useport,1)." ".filelist." ".s:ShellEscape(tgtdir,1))

   elseif b:netrw_method == 2
    " obtain file using ftp + .netrc
"     call Decho("obtain via ftp+.netrc (method #2)",'~'.expand("<slnum>"))
     call s:SaveBufVars()|sil NetrwKeepj new|call s:RestoreBufVars()
     let tmpbufnr= bufnr("%")
     setl ff=unix
     if exists("g:netrw_ftpmode") && g:netrw_ftpmode != ""
      NetrwKeepj put =g:netrw_ftpmode
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endif

     if exists("b:netrw_fname") && b:netrw_fname != ""
      call setline(line("$")+1,'cd "'.b:netrw_fname.'"')
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endif

     if exists("g:netrw_ftpextracmd")
      NetrwKeepj put =g:netrw_ftpextracmd
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endif
     for fname in fnamelist
      call setline(line("$")+1,'get "'.fname.'"')
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endfor
     if exists("g:netrw_port") && g:netrw_port != ""
      call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1)." ".s:ShellEscape(g:netrw_port,1))
     else
      call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1))
     endif
     " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
     if getline(1) !~ "^$" && !exists("g:netrw_quiet") && getline(1) !~ '^Trying '
      let debugkeep= &debug
      setl debug=msg
      call netrw#ErrorMsg(s:ERROR,getline(1),4)
      let &debug= debugkeep
     endif

   elseif b:netrw_method == 3
    " obtain with ftp + machine, id, passwd, and fname (ie. no .netrc)
"    call Decho("obtain via ftp+mipf (method #3)",'~'.expand("<slnum>"))
    call s:SaveBufVars()|sil NetrwKeepj new|call s:RestoreBufVars()
    let tmpbufnr= bufnr("%")
    setl ff=unix

    if exists("g:netrw_port") && g:netrw_port != ""
     NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
    else
     NetrwKeepj put ='open '.g:netrw_machine
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
    endif

    if exists("g:netrw_uid") && g:netrw_uid != ""
     if exists("g:netrw_ftp") && g:netrw_ftp == 1
      NetrwKeepj put =g:netrw_uid
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
      if exists("s:netrw_passwd") && s:netrw_passwd != ""
       NetrwKeepj put ='\"'.s:netrw_passwd.'\"'
      endif
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     elseif exists("s:netrw_passwd")
      NetrwKeepj put ='user \"'.g:netrw_uid.'\" \"'.s:netrw_passwd.'\"'
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endif
    endif

    if exists("g:netrw_ftpmode") && g:netrw_ftpmode != ""
     NetrwKeepj put =g:netrw_ftpmode
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
    endif

    if exists("b:netrw_fname") && b:netrw_fname != ""
     NetrwKeepj call setline(line("$")+1,'cd "'.b:netrw_fname.'"')
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
    endif

    if exists("g:netrw_ftpextracmd")
     NetrwKeepj put =g:netrw_ftpextracmd
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
    endif

    if exists("g:netrw_ftpextracmd")
     NetrwKeepj put =g:netrw_ftpextracmd
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
    endif
    for fname in fnamelist
     NetrwKeepj call setline(line("$")+1,'get "'.fname.'"')
    endfor
"    call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))

    " perform ftp:
    " -i       : turns off interactive prompting from ftp
    " -n  unix : DON'T use <.netrc>, even though it exists
    " -n  win32: quit being obnoxious about password
    "  Note: using "_dd to delete to the black hole register; avoids messing up @@
    NetrwKeepj norm! 1G"_dd
    call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
    " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
    if getline(1) !~ "^$"
"     call Decho("error<".getline(1).">",'~'.expand("<slnum>"))
     if !exists("g:netrw_quiet")
      NetrwKeepj call netrw#ErrorMsg(s:ERROR,getline(1),5)
     endif
    endif

   elseif b:netrw_method == 9
    " obtain file using sftp
"    call Decho("obtain via sftp (method #9)",'~'.expand("<slnum>"))
    if a:fname =~ '/'
     let localfile= substitute(a:fname,'^.*/','','')
    else
     let localfile= a:fname
    endif
    call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_sftp_cmd." ".s:ShellEscape(g:netrw_machine.":".b:netrw_fname,1).s:ShellEscape(localfile)." ".s:ShellEscape(tgtdir))

   elseif !exists("b:netrw_method") || b:netrw_method < 0
    " probably a badly formed url; protocol not recognized
"    call Dret("netrw#Obtain : unsupported method")
    return

   else
    " protocol recognized but not supported for Obtain (yet?)
    if !exists("g:netrw_quiet")
     NetrwKeepj call netrw#ErrorMsg(s:ERROR,"current protocol not supported for obtaining file",97)
    endif
"    call Dret("netrw#Obtain : current protocol not supported for obtaining file")
    return
   endif

   " restore status line
   if type(a:fname) == 1 && exists("s:netrw_users_stl")
    NetrwKeepj call s:SetupNetrwStatusLine(s:netrw_users_stl)
   endif

  endif

  " cleanup
  if exists("tmpbufnr")
   if bufnr("%") != tmpbufnr
    exe tmpbufnr."bw!"
   else
    q!
   endif
  endif

"  call Dret("netrw#Obtain")
endfun

" ---------------------------------------------------------------------
" netrw#Nread: save position, call netrw#NetRead(), and restore position {{{2
fun! netrw#Nread(mode,fname)
"  call Dfunc("netrw#Nread(mode=".a:mode." fname<".a:fname.">)")
  let svpos= winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  call netrw#NetRead(a:mode,a:fname)
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  call winrestview(svpos)

  if exists("w:netrw_liststyle") && w:netrw_liststyle != s:TREELIST
   if exists("w:netrw_bannercnt")
    " start with cursor just after the banner
    exe w:netrw_bannercnt
   endif
  endif
"  call Dret("netrw#Nread")
endfun

" ------------------------------------------------------------------------
" s:NetrwOptionsSave: save options prior to setting to "netrw-buffer-standard" form {{{2
"             Options get restored by s:NetrwOptionsRestore()
"
"             Option handling:
"              * save user's options                                     (s:NetrwOptionsSave)
"              * set netrw-safe options                                  (s:NetrwOptionsSafe)
"                - change an option only when user option != safe option (s:netrwSetSafeSetting)
"              * restore user's options                                  (s:netrwOPtionsRestore)
"                - restore a user option when != safe option             (s:NetrwRestoreSetting)
"             vt: (variable type) normally its either "w:" or "s:"
fun! s:NetrwOptionsSave(vt)
"  call Dfunc("s:NetrwOptionsSave(vt<".a:vt.">) win#".winnr()." buf#".bufnr("%")."<".bufname(bufnr("%")).">"." winnr($)=".winnr("$")." mod=".&mod." ma=".&ma)
"  call Decho(a:vt."netrw_optionsave".(exists("{a:vt}netrw_optionsave")? ("=".{a:vt}netrw_optionsave) : " doesn't exist"),'~'.expand("<slnum>"))
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo." a:vt=".a:vt." hid=".&hid,'~'.expand("<slnum>"))
"  call Decho("(s:NetrwOptionsSave) lines=".&lines)

  if !exists("{a:vt}netrw_optionsave")
   let {a:vt}netrw_optionsave= 1
  else
"   call Dret("s:NetrwOptionsSave : options already saved")
   return
  endif
"  call Decho("prior to save: fo=".&fo.(exists("+acd")? " acd=".&acd : " acd doesn't exist")." diff=".&l:diff,'~'.expand("<slnum>"))

  " Save current settings and current directory
"  call Decho("saving current settings and current directory",'~'.expand("<slnum>"))
  let s:yykeep          = @@
  if exists("&l:acd")|let {a:vt}netrw_acdkeep  = &l:acd|endif
  let {a:vt}netrw_aikeep    = &l:ai
  let {a:vt}netrw_awkeep    = &l:aw
  let {a:vt}netrw_bhkeep    = &l:bh
  let {a:vt}netrw_blkeep    = &l:bl
  let {a:vt}netrw_btkeep    = &l:bt
  let {a:vt}netrw_bombkeep  = &l:bomb
  let {a:vt}netrw_cedit     = &cedit
  let {a:vt}netrw_cikeep    = &l:ci
  let {a:vt}netrw_cinkeep   = &l:cin
  let {a:vt}netrw_cinokeep  = &l:cino
  let {a:vt}netrw_comkeep   = &l:com
  let {a:vt}netrw_cpokeep   = &l:cpo
  let {a:vt}netrw_cuckeep   = &l:cuc
  let {a:vt}netrw_culkeep   = &l:cul
"  call Decho("(s:NetrwOptionsSave) COMBAK: cuc=".&l:cuc." cul=".&l:cul)
  let {a:vt}netrw_diffkeep  = &l:diff
  let {a:vt}netrw_fenkeep   = &l:fen
  if !exists("g:netrw_ffkeep") || g:netrw_ffkeep
   let {a:vt}netrw_ffkeep    = &l:ff
  endif
  let {a:vt}netrw_fokeep    = &l:fo           " formatoptions
  let {a:vt}netrw_gdkeep    = &l:gd           " gdefault
  let {a:vt}netrw_gokeep    = &go             " guioptions
  let {a:vt}netrw_hidkeep   = &l:hidden
  let {a:vt}netrw_imkeep    = &l:im
  let {a:vt}netrw_iskkeep   = &l:isk
  let {a:vt}netrw_lines     = &lines
  let {a:vt}netrw_lskeep    = &l:ls
  let {a:vt}netrw_makeep    = &l:ma
  let {a:vt}netrw_magickeep = &l:magic
  let {a:vt}netrw_modkeep   = &l:mod
  let {a:vt}netrw_nukeep    = &l:nu
  let {a:vt}netrw_rnukeep   = &l:rnu
  let {a:vt}netrw_repkeep   = &l:report
  let {a:vt}netrw_rokeep    = &l:ro
  let {a:vt}netrw_selkeep   = &l:sel
  let {a:vt}netrw_spellkeep = &l:spell
  if !g:netrw_use_noswf
   let {a:vt}netrw_swfkeep  = &l:swf
  endif
  let {a:vt}netrw_tskeep    = &l:ts
  let {a:vt}netrw_twkeep    = &l:tw           " textwidth
  let {a:vt}netrw_wigkeep   = &l:wig          " wildignore
  let {a:vt}netrw_wrapkeep  = &l:wrap
  let {a:vt}netrw_writekeep = &l:write

  " save a few selected netrw-related variables
"  call Decho("saving a few selected netrw-related variables",'~'.expand("<slnum>"))
  if g:netrw_keepdir
   let {a:vt}netrw_dirkeep  = getcwd()
"   call Decho("saving to ".a:vt."netrw_dirkeep<".{a:vt}netrw_dirkeep.">",'~'.expand("<slnum>"))
  endif
  sil! let {a:vt}netrw_slashkeep= @/

"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo." a:vt=".a:vt,'~'.expand("<slnum>"))
"  call Dret("s:NetrwOptionsSave : tab#".tabpagenr()." win#".winnr())
endfun

" ---------------------------------------------------------------------
" s:NetrwOptionsSafe: sets options to help netrw do its job {{{2
"                     Use  s:NetrwSaveOptions() to save user settings
"                     Use  s:NetrwOptionsRestore() to restore user settings
fun! s:NetrwOptionsSafe(islocal)
"  call Dfunc("s:NetrwOptionsSafe(islocal=".a:islocal.") win#".winnr()." buf#".bufnr("%")."<".bufname(bufnr("%"))."> winnr($)=".winnr("$"))
"  call Decho("win#".winnr()."'s ft=".&ft,'~'.expand("<slnum>"))
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
  if exists("+acd") | call s:NetrwSetSafeSetting("&l:acd",0)|endif
  call s:NetrwSetSafeSetting("&l:ai",0)
  call s:NetrwSetSafeSetting("&l:aw",0)
  call s:NetrwSetSafeSetting("&l:bl",0)
  call s:NetrwSetSafeSetting("&l:bomb",0)
  if a:islocal
   call s:NetrwSetSafeSetting("&l:bt","nofile")
  else
   call s:NetrwSetSafeSetting("&l:bt","acwrite")
  endif
  call s:NetrwSetSafeSetting("&l:ci",0)
  call s:NetrwSetSafeSetting("&l:cin",0)
  if g:netrw_fastbrowse > a:islocal
   call s:NetrwSetSafeSetting("&l:bh","hide")
  else
   call s:NetrwSetSafeSetting("&l:bh","delete")
  endif
  call s:NetrwSetSafeSetting("&l:cino","")
  call s:NetrwSetSafeSetting("&l:com","")
  if &cpo =~ 'a' | call s:NetrwSetSafeSetting("&cpo",substitute(&cpo,'a','','g')) | endif
  if &cpo =~ 'A' | call s:NetrwSetSafeSetting("&cpo",substitute(&cpo,'A','','g')) | endif
  setl fo=nroql2
  if &go =~ 'a' | set go-=a | endif
  if &go =~ 'A' | set go-=A | endif
  if &go =~ 'P' | set go-=P | endif
  call s:NetrwSetSafeSetting("&l:hid",0)
  call s:NetrwSetSafeSetting("&l:im",0)
  setl isk+=@ isk+=* isk+=/
  call s:NetrwSetSafeSetting("&l:magic",1)
  if g:netrw_use_noswf
   call s:NetrwSetSafeSetting("swf",0)
  endif
  call s:NetrwSetSafeSetting("&l:report",10000)
  call s:NetrwSetSafeSetting("&l:sel","inclusive")
  call s:NetrwSetSafeSetting("&l:spell",0)
  call s:NetrwSetSafeSetting("&l:tw",0)
  call s:NetrwSetSafeSetting("&l:wig","")
  setl cedit&

  " set up cuc and cul based on g:netrw_cursor and listing style
  " COMBAK -- cuc cul related
  call s:NetrwCursor(0)

  " allow the user to override safe options
"  call Decho("ft<".&ft."> ei=".&ei,'~'.expand("<slnum>"))
  if &ft == "netrw"
"   call Decho("do any netrw FileType autocmds (doau FileType netrw)",'~'.expand("<slnum>"))
   keepalt NetrwKeepj doau FileType netrw
  endif

"  call Decho("fo=".&fo.(exists("+acd")? " acd=".&acd : " acd doesn't exist")." bh=".&l:bh." bt<".&bt.">",'~'.expand("<slnum>"))
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
"  call Dret("s:NetrwOptionsSafe")
endfun

" ---------------------------------------------------------------------
" s:NetrwOptionsRestore: restore options (based on prior s:NetrwOptionsSave) {{{2
fun! s:NetrwOptionsRestore(vt)
"  call Dfunc("s:NetrwOptionsRestore(vt<".a:vt.">) win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> winnr($)=".winnr("$"))
"  call Decho("(s:NetrwOptionsRestore) lines=".&lines)
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo." a:vt=".a:vt,'~'.expand("<slnum>"))
  if !exists("{a:vt}netrw_optionsave")
"   call Decho("case ".a:vt."netrw_optionsave : doesn't exist",'~'.expand("<slnum>"))

   " filereadable() returns zero for remote files (e.g. scp://localhost//etc/fstab)
   if filereadable(expand("%")) || expand("%") =~# '^\w\+://\f\+/'
"    call Decho("..doing filetype detect anyway")
    filetype detect
"    call Decho("..settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo." a:vt=".a:vt,'~'.expand("<slnum>"))
   else
    setl ft=netrw
   endif
"   call Decho("..ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"   call Dret("s:NetrwOptionsRestore : ".a:vt."netrw_optionsave doesn't exist")
   return
  endif
  unlet {a:vt}netrw_optionsave

  if exists("+acd")
   if exists("{a:vt}netrw_acdkeep")
"    call Decho("g:netrw_keepdir=".g:netrw_keepdir.": getcwd<".getcwd()."> acd=".&acd,'~'.expand("<slnum>"))
    let curdir = getcwd()
    let &l:acd = {a:vt}netrw_acdkeep
    unlet {a:vt}netrw_acdkeep
    if &l:acd
     call s:NetrwLcd(curdir)
    endif
   endif
  endif
"  call Decho("(s:NetrwOptionsRestore) #1 lines=".&lines)
  call s:NetrwRestoreSetting(a:vt."netrw_aikeep","&l:ai")
  call s:NetrwRestoreSetting(a:vt."netrw_awkeep","&l:aw")
  call s:NetrwRestoreSetting(a:vt."netrw_blkeep","&l:bl")
  call s:NetrwRestoreSetting(a:vt."netrw_btkeep","&l:bt")
  call s:NetrwRestoreSetting(a:vt."netrw_bombkeep","&l:bomb")
"  call Decho("(s:NetrwOptionsRestore) #2 lines=".&lines)
  call s:NetrwRestoreSetting(a:vt."netrw_cedit","&cedit")
  call s:NetrwRestoreSetting(a:vt."netrw_cikeep","&l:ci")
  call s:NetrwRestoreSetting(a:vt."netrw_cinkeep","&l:cin")
  call s:NetrwRestoreSetting(a:vt."netrw_cinokeep","&l:cino")
  call s:NetrwRestoreSetting(a:vt."netrw_comkeep","&l:com")
"  call Decho("(s:NetrwOptionsRestore) #3 lines=".&lines)
  call s:NetrwRestoreSetting(a:vt."netrw_cpokeep","&l:cpo")
  call s:NetrwRestoreSetting(a:vt."netrw_diffkeep","&l:diff")
  call s:NetrwRestoreSetting(a:vt."netrw_fenkeep","&l:fen")
  if exists("g:netrw_ffkeep") && g:netrw_ffkeep
   call s:NetrwRestoreSetting(a:vt."netrw_ffkeep")","&l:ff")
  endif
"  call Decho("(s:NetrwOptionsRestore) #4 lines=".&lines)
  call s:NetrwRestoreSetting(a:vt."netrw_fokeep"   ,"&l:fo")
  call s:NetrwRestoreSetting(a:vt."netrw_gdkeep"   ,"&l:gd")
  call s:NetrwRestoreSetting(a:vt."netrw_gokeep"   ,"&go")
  call s:NetrwRestoreSetting(a:vt."netrw_hidkeep"  ,"&l:hidden")
"  call Decho("(s:NetrwOptionsRestore) #5 lines=".&lines)
  call s:NetrwRestoreSetting(a:vt."netrw_imkeep"   ,"&l:im")
  call s:NetrwRestoreSetting(a:vt."netrw_iskkeep"  ,"&l:isk")
"  call Decho("(s:NetrwOptionsRestore) #6 lines=".&lines)
  call s:NetrwRestoreSetting(a:vt."netrw_lines"    ,"&lines")
"  call Decho("(s:NetrwOptionsRestore) #7 lines=".&lines)
  call s:NetrwRestoreSetting(a:vt."netrw_lskeep"   ,"&l:ls")
  call s:NetrwRestoreSetting(a:vt."netrw_makeep"   ,"&l:ma")
  call s:NetrwRestoreSetting(a:vt."netrw_magickeep","&l:magic")
  call s:NetrwRestoreSetting(a:vt."netrw_modkeep"  ,"&l:mod")
  call s:NetrwRestoreSetting(a:vt."netrw_nukeep"   ,"&l:nu")
"  call Decho("(s:NetrwOptionsRestore) #8 lines=".&lines)
  call s:NetrwRestoreSetting(a:vt."netrw_rnukeep"  ,"&l:rnu")
  call s:NetrwRestoreSetting(a:vt."netrw_repkeep"  ,"&l:report")
  call s:NetrwRestoreSetting(a:vt."netrw_rokeep"   ,"&l:ro")
  call s:NetrwRestoreSetting(a:vt."netrw_selkeep"  ,"&l:sel")
"  call Decho("(s:NetrwOptionsRestore) #9 lines=".&lines)
  call s:NetrwRestoreSetting(a:vt."netrw_spellkeep","&l:spell")
  call s:NetrwRestoreSetting(a:vt."netrw_twkeep"   ,"&l:tw")
  call s:NetrwRestoreSetting(a:vt."netrw_wigkeep"  ,"&l:wig")
  call s:NetrwRestoreSetting(a:vt."netrw_wrapkeep" ,"&l:wrap")
  call s:NetrwRestoreSetting(a:vt."netrw_writekeep","&l:write")
"  call Decho("(s:NetrwOptionsRestore) #10 lines=".&lines)
  call s:NetrwRestoreSetting("s:yykeep","@@")
  " former problem: start with liststyle=0; press <i> : result, following line resets l:ts.
  " Fixed; in s:PerformListing, when w:netrw_liststyle is s:LONGLIST, will use a printf to pad filename with spaces
  "        rather than by appending a tab which previously was using "&ts" to set the desired spacing.  (Sep 28, 2018)
  call s:NetrwRestoreSetting(a:vt."netrw_tskeep","&l:ts")

  if exists("{a:vt}netrw_swfkeep")
   if &directory == ""
    " user hasn't specified a swapfile directory;
    " netrw will temporarily set the swapfile directory
    " to the current directory as returned by getcwd().
    let &l:directory= getcwd()
    sil! let &l:swf = {a:vt}netrw_swfkeep
    setl directory=
    unlet {a:vt}netrw_swfkeep
   elseif &l:swf != {a:vt}netrw_swfkeep
    if !g:netrw_use_noswf
     " following line causes a Press ENTER in windows -- can't seem to work around it!!!
     sil! let &l:swf= {a:vt}netrw_swfkeep
    endif
    unlet {a:vt}netrw_swfkeep
   endif
  endif
  if exists("{a:vt}netrw_dirkeep") && isdirectory(s:NetrwFile({a:vt}netrw_dirkeep)) && g:netrw_keepdir
   let dirkeep = substitute({a:vt}netrw_dirkeep,'\\','/','g')
   if exists("{a:vt}netrw_dirkeep")
    call s:NetrwLcd(dirkeep)
    unlet {a:vt}netrw_dirkeep
   endif
  endif
  call s:NetrwRestoreSetting(a:vt."netrw_slashkeep","@/")

"  call Decho("g:netrw_keepdir=".g:netrw_keepdir.": getcwd<".getcwd()."> acd=".&acd,'~'.expand("<slnum>"))
"  call Decho("fo=".&fo.(exists("+acd")? " acd=".&acd : " acd doesn't exist"),'~'.expand("<slnum>"))
"  call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"  call Decho("diff=".&l:diff." win#".winnr()." w:netrw_diffkeep=".(exists("w:netrw_diffkeep")? w:netrw_diffkeep : "doesn't exist"),'~'.expand("<slnum>"))
"  call Decho("ts=".&l:ts,'~'.expand("<slnum>"))
  " Moved the filetype detect here from NetrwGetFile() because remote files
  " were having their filetype detect-generated settings overwritten by
  " NetrwOptionRestore.
  if &ft != "netrw"
"   call Decho("before: filetype detect  (ft=".&ft.")",'~'.expand("<slnum>"))
   filetype detect
"   call Decho("after : filetype detect  (ft=".&ft.")",'~'.expand("<slnum>"))
  endif
"  call Decho("(s:NetrwOptionsRestore) lines=".&lines)
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo." a:vt=".a:vt,'~'.expand("<slnum>"))
"  call Dret("s:NetrwOptionsRestore : tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> modified=".&modified." modifiable=".&modifiable." readonly=".&readonly)
endfun

" ---------------------------------------------------------------------
" s:NetrwSetSafeSetting: sets an option to a safe setting {{{2
"                        but only when the options' value and the safe setting differ
"                        Doing this means that netrw will not come up as having changed a
"                        setting last when it really didn't actually change it.
"
"                        Called from s:NetrwOptionsSafe
"                          ex. call s:NetrwSetSafeSetting("&l:sel","inclusive")
fun! s:NetrwSetSafeSetting(setting,safesetting)
"  call Dfunc("s:NetrwSetSafeSetting(setting<".a:setting."> safesetting<".a:safesetting.">)")

  if a:setting =~ '^&'
"   call Decho("fyi: a:setting starts with &")
   exe "let settingval= ".a:setting
"   call Decho("fyi: settingval<".settingval.">")

   if settingval != a:safesetting
"    call Decho("set setting<".a:setting."> to option value<".a:safesetting.">")
    if type(a:safesetting) == 0
     exe "let ".a:setting."=".a:safesetting
    elseif type(a:safesetting) == 1
     exe "let ".a:setting."= '".a:safesetting."'"
    else
     call netrw#ErrorMsg(s:ERROR,"(s:NetrwRestoreSetting) doesn't know how to restore ".a:setting." with a safesetting of type#".type(a:safesetting),105)
    endif
   endif
  endif

"  call Dret("s:NetrwSetSafeSetting")
endfun

" ------------------------------------------------------------------------
" s:NetrwRestoreSetting: restores specified setting using associated keepvar, {{{2
"                        but only if the setting value differs from the associated keepvar.
"                        Doing this means that netrw will not come up as having changed a
"                        setting last when it really didn't actually change it.
"
"                        Used by s:NetrwOptionsRestore() to restore each netrw-sensitive setting
"                        keepvars are set up by s:NetrwOptionsSave
fun! s:NetrwRestoreSetting(keepvar,setting)
"""  call Dfunc("s:NetrwRestoreSetting(a:keepvar<".a:keepvar."> a:setting<".a:setting.">)")

  " typically called from s:NetrwOptionsRestore
  "   call s:NetrwRestoreSettings(keep-option-variable-name,'associated-option')
  "   ex. call s:NetrwRestoreSetting(a:vt."netrw_selkeep","&l:sel")
  "  Restores option (but only if different) from a:keepvar
  if exists(a:keepvar)
   exe "let keepvarval= ".a:keepvar
   exe "let setting= ".a:setting

""   call Decho("fyi: a:keepvar<".a:keepvar."> exists")
""   call Decho("fyi: keepvarval=".keepvarval)
""   call Decho("fyi: a:setting<".a:setting."> setting<".setting.">")

   if setting != keepvarval
""    call Decho("restore setting<".a:setting."> (currently=".setting.") to keepvarval<".keepvarval.">")
    if type(a:setting) == 0
     exe "let ".a:setting."= ".keepvarval
    elseif type(a:setting) == 1
     exe "let ".a:setting."= '".substitute(keepvarval,"'","''","g")."'"
    else
     call netrw#ErrorMsg(s:ERROR,"(s:NetrwRestoreSetting) doesn't know how to restore ".a:keepvar." with a setting of type#".type(a:setting),105)
    endif
   endif

   exe "unlet ".a:keepvar
  endif

""  call Dret("s:NetrwRestoreSetting")
endfun

" ---------------------------------------------------------------------
" NetrwStatusLine: {{{2
fun! NetrwStatusLine()

" vvv NetrwStatusLine() debugging vvv
"  let g:stlmsg=""
"  if !exists("w:netrw_explore_bufnr")
"   let g:stlmsg="!X<explore_bufnr>"
"  elseif w:netrw_explore_bufnr != bufnr("%")
"   let g:stlmsg="explore_bufnr!=".bufnr("%")
"  endif
"  if !exists("w:netrw_explore_line")
"   let g:stlmsg=" !X<explore_line>"
"  elseif w:netrw_explore_line != line(".")
"   let g:stlmsg=" explore_line!={line(.)<".line(".").">"
"  endif
"  if !exists("w:netrw_explore_list")
"   let g:stlmsg=" !X<explore_list>"
"  endif
" ^^^ NetrwStatusLine() debugging ^^^

  if !exists("w:netrw_explore_bufnr") || w:netrw_explore_bufnr != bufnr("%") || !exists("w:netrw_explore_line") || w:netrw_explore_line != line(".") || !exists("w:netrw_explore_list")
   " restore user's status line
   let &l:stl      = s:netrw_users_stl
   let &laststatus = s:netrw_users_ls
   if exists("w:netrw_explore_bufnr")|unlet w:netrw_explore_bufnr|endif
   if exists("w:netrw_explore_line") |unlet w:netrw_explore_line |endif
   return ""
  else
   return "Match ".w:netrw_explore_mtchcnt." of ".w:netrw_explore_listlen
  endif
endfun

" ===============================
"  Netrw Transfer Functions: {{{1
" ===============================

" ------------------------------------------------------------------------
" netrw#NetRead: responsible for reading a file over the net {{{2
"   mode: =0 read remote file and insert before current line
"         =1 read remote file and insert after current line
"         =2 replace with remote file
"         =3 obtain file, but leave in temporary format
fun! netrw#NetRead(mode,...)
"  call Dfunc("netrw#NetRead(mode=".a:mode.",...) a:0=".a:0." ".g:loaded_netrw.((a:0 > 0)? " a:1<".a:1.">" : ""))

  " NetRead: save options {{{3
  call s:NetrwOptionsSave("w:")
  call s:NetrwOptionsSafe(0)
  call s:RestoreCursorline()
  " NetrwSafeOptions sets a buffer up for a netrw listing, which includes buflisting off.
  " However, this setting is not wanted for a remote editing session.  The buffer should be "nofile", still.
  setl bl
"  call Decho("buf#".bufnr("%")."<".bufname("%")."> bl=".&bl." bt=".&bt." bh=".&bh,'~'.expand("<slnum>"))

  " NetRead: interpret mode into a readcmd {{{3
  if     a:mode == 0 " read remote file before current line
   let readcmd = "0r"
  elseif a:mode == 1 " read file after current line
   let readcmd = "r"
  elseif a:mode == 2 " replace with remote file
   let readcmd = "%r"
  elseif a:mode == 3 " skip read of file (leave as temporary)
   let readcmd = "t"
  else
   exe a:mode
   let readcmd = "r"
  endif
  let ichoice = (a:0 == 0)? 0 : 1
"  call Decho("readcmd<".readcmd."> ichoice=".ichoice,'~'.expand("<slnum>"))

  " NetRead: get temporary filename {{{3
  let tmpfile= s:GetTempfile("")
  if tmpfile == ""
"   call Dret("netrw#NetRead : unable to get a tempfile!")
   return
  endif

  while ichoice <= a:0

   " attempt to repeat with previous host-file-etc
   if exists("b:netrw_lastfile") && a:0 == 0
"    call Decho("using b:netrw_lastfile<" . b:netrw_lastfile . ">",'~'.expand("<slnum>"))
    let choice = b:netrw_lastfile
    let ichoice= ichoice + 1

   else
    exe "let choice= a:" . ichoice
"    call Decho("no lastfile: choice<" . choice . ">",'~'.expand("<slnum>"))

    if match(choice,"?") == 0
     " give help
     echomsg 'NetRead Usage:'
     echomsg ':Nread machine:path                         uses rcp'
     echomsg ':Nread "machine path"                       uses ftp   with <.netrc>'
     echomsg ':Nread "machine id password path"           uses ftp'
     echomsg ':Nread dav://machine[:port]/path            uses cadaver'
     echomsg ':Nread fetch://machine/path                 uses fetch'
     echomsg ':Nread ftp://[user@]machine[:port]/path     uses ftp   autodetects <.netrc>'
     echomsg ':Nread http://[user@]machine/path           uses http  wget'
     echomsg ':Nread file:///path           		  uses elinks'
     echomsg ':Nread https://[user@]machine/path          uses http  wget'
     echomsg ':Nread rcp://[user@]machine/path            uses rcp'
     echomsg ':Nread rsync://machine[:port]/path          uses rsync'
     echomsg ':Nread scp://[user@]machine[[:#]port]/path  uses scp'
     echomsg ':Nread sftp://[user@]machine[[:#]port]/path uses sftp'
     sleep 4
     break

    elseif match(choice,'^"') != -1
     " Reconstruct Choice if choice starts with '"'
"     call Decho("reconstructing choice",'~'.expand("<slnum>"))
     if match(choice,'"$') != -1
      " case "..."
      let choice= strpart(choice,1,strlen(choice)-2)
     else
       "  case "... ... ..."
      let choice      = strpart(choice,1,strlen(choice)-1)
      let wholechoice = ""

      while match(choice,'"$') == -1
       let wholechoice = wholechoice . " " . choice
       let ichoice     = ichoice + 1
       if ichoice > a:0
        if !exists("g:netrw_quiet")
         call netrw#ErrorMsg(s:ERROR,"Unbalanced string in filename '". wholechoice ."'",3)
        endif
"        call Dret("netrw#NetRead :2 getcwd<".getcwd().">")
        return
       endif
       let choice= a:{ichoice}
      endwhile
      let choice= strpart(wholechoice,1,strlen(wholechoice)-1) . " " . strpart(choice,0,strlen(choice)-1)
     endif
    endif
   endif

"   call Decho("choice<" . choice . ">",'~'.expand("<slnum>"))
   let ichoice= ichoice + 1

   " NetRead: Determine method of read (ftp, rcp, etc) {{{3
   call s:NetrwMethod(choice)
   if !exists("b:netrw_method") || b:netrw_method < 0
"    call Dret("netrw#NetRead : unsupported method")
    return
   endif
   let tmpfile= s:GetTempfile(b:netrw_fname) " apply correct suffix

   " Check whether or not NetrwBrowse() should be handling this request
"   call Decho("checking if NetrwBrowse() should handle choice<".choice."> with netrw_list_cmd<".g:netrw_list_cmd.">",'~'.expand("<slnum>"))
   if choice =~ "^.*[\/]$" && b:netrw_method != 5 && choice !~ '^https\=://'
"    call Decho("yes, choice matches '^.*[\/]$'",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwBrowse(0,choice)
"    call Dret("netrw#NetRead :3 getcwd<".getcwd().">")
    return
   endif

   " ============
   " NetRead: Perform Protocol-Based Read {{{3
   " ===========================
   if exists("g:netrw_silent") && g:netrw_silent == 0 && &ch >= 1
    echo "(netrw) Processing your read request..."
   endif

   ".........................................
   " NetRead: (rcp)  NetRead Method #1 {{{3
   if  b:netrw_method == 1 " read with rcp
"    call Decho("read via rcp (method #1)",'~'.expand("<slnum>"))
   " ER: nothing done with g:netrw_uid yet?
   " ER: on Win2K" rcp machine[.user]:file tmpfile
   " ER: when machine contains '.' adding .user is required (use $USERNAME)
   " ER: the tmpfile is full path: rcp sees C:\... as host C
   if s:netrw_has_nt_rcp == 1
    if exists("g:netrw_uid") &&	( g:netrw_uid != "" )
     let uid_machine = g:netrw_machine .'.'. g:netrw_uid
    else
     " Any way needed it machine contains a '.'
     let uid_machine = g:netrw_machine .'.'. $USERNAME
    endif
   else
    if exists("g:netrw_uid") &&	( g:netrw_uid != "" )
     let uid_machine = g:netrw_uid .'@'. g:netrw_machine
    else
     let uid_machine = g:netrw_machine
    endif
   endif
   call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_rcp_cmd." ".s:netrw_rcpmode." ".s:ShellEscape(uid_machine.":".b:netrw_fname,1)." ".s:ShellEscape(tmpfile,1))
   let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
   let b:netrw_lastfile = choice

   ".........................................
   " NetRead: (ftp + <.netrc>)  NetRead Method #2 {{{3
   elseif b:netrw_method  == 2		" read with ftp + <.netrc>
"     call Decho("read via ftp+.netrc (method #2)",'~'.expand("<slnum>"))
     let netrw_fname= b:netrw_fname
     NetrwKeepj call s:SaveBufVars()|new|NetrwKeepj call s:RestoreBufVars()
     let filtbuf= bufnr("%")
     setl ff=unix
     NetrwKeepj put =g:netrw_ftpmode
"     call Decho("filter input: ".getline(line("$")),'~'.expand("<slnum>"))
     if exists("g:netrw_ftpextracmd")
      NetrwKeepj put =g:netrw_ftpextracmd
"      call Decho("filter input: ".getline(line("$")),'~'.expand("<slnum>"))
     endif
     call setline(line("$")+1,'get "'.netrw_fname.'" '.tmpfile)
"     call Decho("filter input: ".getline(line("$")),'~'.expand("<slnum>"))
     if exists("g:netrw_port") && g:netrw_port != ""
      call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1)." ".s:ShellEscape(g:netrw_port,1))
     else
      call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1))
     endif
     " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
     if getline(1) !~ "^$" && !exists("g:netrw_quiet") && getline(1) !~ '^Trying '
      let debugkeep = &debug
      setl debug=msg
      NetrwKeepj call netrw#ErrorMsg(s:ERROR,getline(1),4)
      let &debug    = debugkeep
     endif
     call s:SaveBufVars()
     keepj bd!
     if bufname("%") == "" && getline("$") == "" && line('$') == 1
      " needed when one sources a file in a nolbl setting window via ftp
      q!
     endif
     call s:RestoreBufVars()
     let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
     let b:netrw_lastfile = choice

   ".........................................
   " NetRead: (ftp + machine,id,passwd,filename)  NetRead Method #3 {{{3
   elseif b:netrw_method == 3		" read with ftp + machine, id, passwd, and fname
    " Construct execution string (four lines) which will be passed through filter
"    call Decho("read via ftp+mipf (method #3)",'~'.expand("<slnum>"))
    let netrw_fname= escape(b:netrw_fname,g:netrw_fname_escape)
    NetrwKeepj call s:SaveBufVars()|new|NetrwKeepj call s:RestoreBufVars()
    let filtbuf= bufnr("%")
    setl ff=unix
    if exists("g:netrw_port") && g:netrw_port != ""
     NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
"     call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
    else
     NetrwKeepj put ='open '.g:netrw_machine
"     call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
    endif

    if exists("g:netrw_uid") && g:netrw_uid != ""
     if exists("g:netrw_ftp") && g:netrw_ftp == 1
      NetrwKeepj put =g:netrw_uid
"       call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
      if exists("s:netrw_passwd")
       NetrwKeepj put ='\"'.s:netrw_passwd.'\"'
      endif
"      call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
     elseif exists("s:netrw_passwd")
      NetrwKeepj put ='user \"'.g:netrw_uid.'\" \"'.s:netrw_passwd.'\"'
"      call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
     endif
    endif

    if exists("g:netrw_ftpmode") && g:netrw_ftpmode != ""
     NetrwKeepj put =g:netrw_ftpmode
"     call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
    endif
    if exists("g:netrw_ftpextracmd")
     NetrwKeepj put =g:netrw_ftpextracmd
"     call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
    endif
    NetrwKeepj put ='get \"'.netrw_fname.'\" '.tmpfile
"    call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))

    " perform ftp:
    " -i       : turns off interactive prompting from ftp
    " -n  unix : DON'T use <.netrc>, even though it exists
    " -n  win32: quit being obnoxious about password
    NetrwKeepj norm! 1G"_dd
    call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
    " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
    if getline(1) !~ "^$"
"     call Decho("error<".getline(1).">",'~'.expand("<slnum>"))
     if !exists("g:netrw_quiet")
      call netrw#ErrorMsg(s:ERROR,getline(1),5)
     endif
    endif
    call s:SaveBufVars()|keepj bd!|call s:RestoreBufVars()
    let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
    let b:netrw_lastfile = choice

   ".........................................
   " NetRead: (scp) NetRead Method #4 {{{3
   elseif     b:netrw_method  == 4	" read with scp
"    call Decho("read via scp (method #4)",'~'.expand("<slnum>"))
    if exists("g:netrw_port") && g:netrw_port != ""
     let useport= " ".g:netrw_scpport." ".g:netrw_port
    else
     let useport= ""
    endif
    " 'C' in 'C:\path\to\file' is handled as hostname on windows.
    " This is workaround to avoid mis-handle windows local-path:
    if g:netrw_scp_cmd =~ '^scp' && has("win32")
      let tmpfile_get = substitute(tr(tmpfile, '\', '/'), '^\(\a\):[/\\]\(.*\)$', '/\1/\2', '')
    else
      let tmpfile_get = tmpfile
    endif
    call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_scp_cmd.useport." ".escape(s:ShellEscape(g:netrw_machine.":".b:netrw_fname,1),' ')." ".s:ShellEscape(tmpfile_get,1))
    let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
    let b:netrw_lastfile = choice

   ".........................................
   " NetRead: (http) NetRead Method #5 (wget) {{{3
   elseif     b:netrw_method  == 5
"    call Decho("read via http (method #5)",'~'.expand("<slnum>"))
    if g:netrw_http_cmd == ""
     if !exists("g:netrw_quiet")
      call netrw#ErrorMsg(s:ERROR,"neither the wget nor the fetch command is available",6)
     endif
"     call Dret("netrw#NetRead :4 getcwd<".getcwd().">")
     return
    endif

    if match(b:netrw_fname,"#") == -1 || exists("g:netrw_http_xcmd")
     " using g:netrw_http_cmd (usually elinks, links, curl, wget, or fetch)
"     call Decho('using '.g:netrw_http_cmd.' (# not in b:netrw_fname<'.b:netrw_fname.">)",'~'.expand("<slnum>"))
     if exists("g:netrw_http_xcmd")
      call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_http_cmd." ".s:ShellEscape(b:netrw_http."://".g:netrw_machine.b:netrw_fname,1)." ".g:netrw_http_xcmd." ".s:ShellEscape(tmpfile,1))
     else
      call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_http_cmd." ".s:ShellEscape(tmpfile,1)." ".s:ShellEscape(b:netrw_http."://".g:netrw_machine.b:netrw_fname,1))
     endif
     let result = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)

    else
     " wget/curl/fetch plus a jump to an in-page marker (ie. http://abc/def.html#aMarker)
"     call Decho("wget/curl plus jump (# in b:netrw_fname<".b:netrw_fname.">)",'~'.expand("<slnum>"))
     let netrw_html= substitute(b:netrw_fname,"#.*$","","")
     let netrw_tag = substitute(b:netrw_fname,"^.*#","","")
"     call Decho("netrw_html<".netrw_html.">",'~'.expand("<slnum>"))
"     call Decho("netrw_tag <".netrw_tag.">",'~'.expand("<slnum>"))
     call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_http_cmd." ".s:ShellEscape(tmpfile,1)." ".s:ShellEscape(b:netrw_http."://".g:netrw_machine.netrw_html,1))
     let result = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
"     call Decho('<\s*a\s*name=\s*"'.netrw_tag.'"/','~'.expand("<slnum>"))
     exe 'NetrwKeepj norm! 1G/<\s*a\s*name=\s*"'.netrw_tag.'"/'."\<CR>"
    endif
    let b:netrw_lastfile = choice
"    call Decho("setl ro",'~'.expand("<slnum>"))
    setl ro nomod

   ".........................................
   " NetRead: (dav) NetRead Method #6 {{{3
   elseif     b:netrw_method  == 6
"    call Decho("read via cadaver (method #6)",'~'.expand("<slnum>"))

    if !executable(g:netrw_dav_cmd)
     call netrw#ErrorMsg(s:ERROR,g:netrw_dav_cmd." is not executable",73)
"     call Dret("netrw#NetRead : ".g:netrw_dav_cmd." not executable")
     return
    endif
    if g:netrw_dav_cmd =~ "curl"
     call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_dav_cmd." ".s:ShellEscape("dav://".g:netrw_machine.b:netrw_fname,1)." ".s:ShellEscape(tmpfile,1))
    else
     " Construct execution string (four lines) which will be passed through filter
     let netrw_fname= escape(b:netrw_fname,g:netrw_fname_escape)
     new
     setl ff=unix
     if exists("g:netrw_port") && g:netrw_port != ""
      NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
     else
      NetrwKeepj put ='open '.g:netrw_machine
     endif
     if exists("g:netrw_uid") && exists("s:netrw_passwd") && g:netrw_uid != ""
      NetrwKeepj put ='user '.g:netrw_uid.' '.s:netrw_passwd
     endif
     NetrwKeepj put ='get '.netrw_fname.' '.tmpfile
     NetrwKeepj put ='quit'

     " perform cadaver operation:
     NetrwKeepj norm! 1G"_dd
     call s:NetrwExe(s:netrw_silentxfer."%!".g:netrw_dav_cmd)
     keepj bd!
    endif
    let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
    let b:netrw_lastfile = choice

   ".........................................
   " NetRead: (rsync) NetRead Method #7 {{{3
   elseif     b:netrw_method  == 7
"    call Decho("read via rsync (method #7)",'~'.expand("<slnum>"))
    call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_rsync_cmd." ".s:ShellEscape(g:netrw_machine.g:netrw_rsync_sep.b:netrw_fname,1)." ".s:ShellEscape(tmpfile,1))
    let result		 = s:NetrwGetFile(readcmd,tmpfile, b:netrw_method)
    let b:netrw_lastfile = choice

   ".........................................
   " NetRead: (fetch) NetRead Method #8 {{{3
   "    fetch://[user@]host[:http]/path
   elseif     b:netrw_method  == 8
"    call Decho("read via fetch (method #8)",'~'.expand("<slnum>"))
    if g:netrw_fetch_cmd == ""
     if !exists("g:netrw_quiet")
      NetrwKeepj call netrw#ErrorMsg(s:ERROR,"fetch command not available",7)
     endif
"     call Dret("NetRead")
     return
    endif
    if exists("g:netrw_option") && g:netrw_option =~ ":https\="
     let netrw_option= "http"
    else
     let netrw_option= "ftp"
    endif
"    call Decho("read via fetch for ".netrw_option,'~'.expand("<slnum>"))

    if exists("g:netrw_uid") && g:netrw_uid != "" && exists("s:netrw_passwd") && s:netrw_passwd != ""
     call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_fetch_cmd." ".s:ShellEscape(tmpfile,1)." ".s:ShellEscape(netrw_option."://".g:netrw_uid.':'.s:netrw_passwd.'@'.g:netrw_machine."/".b:netrw_fname,1))
    else
     call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_fetch_cmd." ".s:ShellEscape(tmpfile,1)." ".s:ShellEscape(netrw_option."://".g:netrw_machine."/".b:netrw_fname,1))
    endif

    let result		= s:NetrwGetFile(readcmd,tmpfile, b:netrw_method)
    let b:netrw_lastfile = choice
"    call Decho("setl ro",'~'.expand("<slnum>"))
    setl ro nomod

   ".........................................
   " NetRead: (sftp) NetRead Method #9 {{{3
   elseif     b:netrw_method  == 9
"    call Decho("read via sftp (method #9)",'~'.expand("<slnum>"))
    call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_sftp_cmd." ".s:ShellEscape(g:netrw_machine.":".b:netrw_fname,1)." ".tmpfile)
    let result		= s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
    let b:netrw_lastfile = choice

   ".........................................
   " NetRead: (file) NetRead Method #10 {{{3
  elseif      b:netrw_method == 10 && exists("g:netrw_file_cmd")
"   "    call Decho("read via ".b:netrw_file_cmd." (method #10)",'~'.expand("<slnum>"))
   call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_file_cmd." ".s:ShellEscape(b:netrw_fname,1)." ".tmpfile)
   let result		= s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
   let b:netrw_lastfile = choice

   ".........................................
   " NetRead: Complain {{{3
   else
    call netrw#ErrorMsg(s:WARNING,"unable to comply with your request<" . choice . ">",8)
   endif
  endwhile

  " NetRead: cleanup {{{3
  if exists("b:netrw_method")
"   call Decho("cleanup b:netrw_method and b:netrw_fname",'~'.expand("<slnum>"))
   unlet b:netrw_method
   unlet b:netrw_fname
  endif
  if s:FileReadable(tmpfile) && tmpfile !~ '.tar.bz2$' && tmpfile !~ '.tar.gz$' && tmpfile !~ '.zip' && tmpfile !~ '.tar' && readcmd != 't' && tmpfile !~ '.tar.xz$' && tmpfile !~ '.txz'
"   call Decho("cleanup by deleting tmpfile<".tmpfile.">",'~'.expand("<slnum>"))
   NetrwKeepj call s:NetrwDelete(tmpfile)
  endif
  NetrwKeepj call s:NetrwOptionsRestore("w:")

"  call Dret("netrw#NetRead :5 getcwd<".getcwd().">")
endfun

" ------------------------------------------------------------------------
" netrw#NetWrite: responsible for writing a file over the net {{{2
fun! netrw#NetWrite(...) range
"  call Dfunc("netrw#NetWrite(a:0=".a:0.") ".g:loaded_netrw)

  " NetWrite: option handling {{{3
  let mod= 0
  call s:NetrwOptionsSave("w:")
  call s:NetrwOptionsSafe(0)

  " NetWrite: Get Temporary Filename {{{3
  let tmpfile= s:GetTempfile("")
  if tmpfile == ""
"   call Dret("netrw#NetWrite : unable to get a tempfile!")
   return
  endif

  if a:0 == 0
   let ichoice = 0
  else
   let ichoice = 1
  endif

  let curbufname= expand("%")
"  call Decho("curbufname<".curbufname.">",'~'.expand("<slnum>"))
  if &binary
   " For binary writes, always write entire file.
   " (line numbers don't really make sense for that).
   " Also supports the writing of tar and zip files.
"   call Decho("(write entire file) sil exe w! ".fnameescape(v:cmdarg)." ".fnameescape(tmpfile),'~'.expand("<slnum>"))
   exe "sil NetrwKeepj w! ".fnameescape(v:cmdarg)." ".fnameescape(tmpfile)
  elseif g:netrw_cygwin
   " write (selected portion of) file to temporary
   let cygtmpfile= substitute(tmpfile,g:netrw_cygdrive.'/\(.\)','\1:','')
"   call Decho("(write selected portion) sil exe ".a:firstline."," . a:lastline . "w! ".fnameescape(v:cmdarg)." ".fnameescape(cygtmpfile),'~'.expand("<slnum>"))
   exe "sil NetrwKeepj ".a:firstline."," . a:lastline . "w! ".fnameescape(v:cmdarg)." ".fnameescape(cygtmpfile)
  else
   " write (selected portion of) file to temporary
"   call Decho("(write selected portion) sil exe ".a:firstline."," . a:lastline . "w! ".fnameescape(v:cmdarg)." ".fnameescape(tmpfile),'~'.expand("<slnum>"))
   exe "sil NetrwKeepj ".a:firstline."," . a:lastline . "w! ".fnameescape(v:cmdarg)." ".fnameescape(tmpfile)
  endif

  if curbufname == ""
   " when the file is [No Name], and one attempts to Nwrite it, the buffer takes
   " on the temporary file's name.  Deletion of the temporary file during
   " cleanup then causes an error message.
   0file!
  endif

  " NetWrite: while choice loop: {{{3
  while ichoice <= a:0

   " Process arguments: {{{4
   " attempt to repeat with previous host-file-etc
   if exists("b:netrw_lastfile") && a:0 == 0
"    call Decho("using b:netrw_lastfile<" . b:netrw_lastfile . ">",'~'.expand("<slnum>"))
    let choice = b:netrw_lastfile
    let ichoice= ichoice + 1
   else
    exe "let choice= a:" . ichoice

    " Reconstruct Choice when choice starts with '"'
    if match(choice,"?") == 0
     echomsg 'NetWrite Usage:"'
     echomsg ':Nwrite machine:path                        uses rcp'
     echomsg ':Nwrite "machine path"                      uses ftp with <.netrc>'
     echomsg ':Nwrite "machine id password path"          uses ftp'
     echomsg ':Nwrite dav://[user@]machine/path           uses cadaver'
     echomsg ':Nwrite fetch://[user@]machine/path         uses fetch'
     echomsg ':Nwrite ftp://machine[#port]/path           uses ftp  (autodetects <.netrc>)'
     echomsg ':Nwrite rcp://machine/path                  uses rcp'
     echomsg ':Nwrite rsync://[user@]machine/path         uses rsync'
     echomsg ':Nwrite scp://[user@]machine[[:#]port]/path uses scp'
     echomsg ':Nwrite sftp://[user@]machine/path          uses sftp'
     sleep 4
     break

    elseif match(choice,"^\"") != -1
     if match(choice,"\"$") != -1
       " case "..."
      let choice=strpart(choice,1,strlen(choice)-2)
     else
      "  case "... ... ..."
      let choice      = strpart(choice,1,strlen(choice)-1)
      let wholechoice = ""

      while match(choice,"\"$") == -1
       let wholechoice= wholechoice . " " . choice
       let ichoice    = ichoice + 1
       if choice > a:0
        if !exists("g:netrw_quiet")
         call netrw#ErrorMsg(s:ERROR,"Unbalanced string in filename '". wholechoice ."'",13)
        endif
"        call Dret("netrw#NetWrite")
        return
       endif
       let choice= a:{ichoice}
      endwhile
      let choice= strpart(wholechoice,1,strlen(wholechoice)-1) . " " . strpart(choice,0,strlen(choice)-1)
     endif
    endif
   endif
   let ichoice= ichoice + 1
"   call Decho("choice<" . choice . "> ichoice=".ichoice,'~'.expand("<slnum>"))

   " Determine method of write (ftp, rcp, etc) {{{4
   NetrwKeepj call s:NetrwMethod(choice)
   if !exists("b:netrw_method") || b:netrw_method < 0
"    call Dfunc("netrw#NetWrite : unsupported method")
    return
   endif

   " =============
   " NetWrite: Perform Protocol-Based Write {{{3
   " ============================
   if exists("g:netrw_silent") && g:netrw_silent == 0 && &ch >= 1
    echo "(netrw) Processing your write request..."
"    call Decho("Processing your write request...",'~'.expand("<slnum>"))
   endif

   ".........................................
   " NetWrite: (rcp) NetWrite Method #1 {{{3
   if  b:netrw_method == 1
"    call Decho("write via rcp (method #1)",'~'.expand("<slnum>"))
    if s:netrw_has_nt_rcp == 1
     if exists("g:netrw_uid") &&  ( g:netrw_uid != "" )
      let uid_machine = g:netrw_machine .'.'. g:netrw_uid
     else
      let uid_machine = g:netrw_machine .'.'. $USERNAME
     endif
    else
     if exists("g:netrw_uid") &&  ( g:netrw_uid != "" )
      let uid_machine = g:netrw_uid .'@'. g:netrw_machine
     else
      let uid_machine = g:netrw_machine
     endif
    endif
    call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_rcp_cmd." ".s:netrw_rcpmode." ".s:ShellEscape(tmpfile,1)." ".s:ShellEscape(uid_machine.":".b:netrw_fname,1))
    let b:netrw_lastfile = choice

   ".........................................
   " NetWrite: (ftp + <.netrc>) NetWrite Method #2 {{{3
   elseif b:netrw_method == 2
"    call Decho("write via ftp+.netrc (method #2)",'~'.expand("<slnum>"))
    let netrw_fname = b:netrw_fname

    " formerly just a "new...bd!", that changed the window sizes when equalalways.  Using enew workaround instead
    let bhkeep      = &l:bh
    let curbuf      = bufnr("%")
    setl bh=hide
    keepj keepalt enew

"    call Decho("filter input window#".winnr(),'~'.expand("<slnum>"))
    setl ff=unix
    NetrwKeepj put =g:netrw_ftpmode
"    call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
    if exists("g:netrw_ftpextracmd")
     NetrwKeepj put =g:netrw_ftpextracmd
"     call Decho("filter input: ".getline("$"),'~'.expand("<slnum>"))
    endif
    NetrwKeepj call setline(line("$")+1,'put "'.tmpfile.'" "'.netrw_fname.'"')
"    call Decho("filter input: ".getline("$"),'~'.expand("<slnum>"))
    if exists("g:netrw_port") && g:netrw_port != ""
     call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1)." ".s:ShellEscape(g:netrw_port,1))
    else
"     call Decho("filter input window#".winnr(),'~'.expand("<slnum>"))
     call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1))
    endif
    " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
    if getline(1) !~ "^$"
     if !exists("g:netrw_quiet")
      NetrwKeepj call netrw#ErrorMsg(s:ERROR,getline(1),14)
     endif
     let mod=1
    endif

    " remove enew buffer (quietly)
    let filtbuf= bufnr("%")
    exe curbuf."b!"
    let &l:bh            = bhkeep
    exe filtbuf."bw!"

    let b:netrw_lastfile = choice

   ".........................................
   " NetWrite: (ftp + machine, id, passwd, filename) NetWrite Method #3 {{{3
   elseif b:netrw_method == 3
    " Construct execution string (three or more lines) which will be passed through filter
"    call Decho("read via ftp+mipf (method #3)",'~'.expand("<slnum>"))
    let netrw_fname = b:netrw_fname
    let bhkeep      = &l:bh

    " formerly just a "new...bd!", that changed the window sizes when equalalways.  Using enew workaround instead
    let curbuf      = bufnr("%")
    setl bh=hide
    keepj keepalt enew
    setl ff=unix

    if exists("g:netrw_port") && g:netrw_port != ""
     NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
"     call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
    else
     NetrwKeepj put ='open '.g:netrw_machine
"     call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
    endif
    if exists("g:netrw_uid") && g:netrw_uid != ""
     if exists("g:netrw_ftp") && g:netrw_ftp == 1
      NetrwKeepj put =g:netrw_uid
"      call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
      if exists("s:netrw_passwd") && s:netrw_passwd != ""
       NetrwKeepj put ='\"'.s:netrw_passwd.'\"'
      endif
"      call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
     elseif exists("s:netrw_passwd") && s:netrw_passwd != ""
      NetrwKeepj put ='user \"'.g:netrw_uid.'\" \"'.s:netrw_passwd.'\"'
"      call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
     endif
    endif
    NetrwKeepj put =g:netrw_ftpmode
"    call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
    if exists("g:netrw_ftpextracmd")
     NetrwKeepj put =g:netrw_ftpextracmd
"     call Decho("filter input: ".getline("$"),'~'.expand("<slnum>"))
    endif
    NetrwKeepj put ='put \"'.tmpfile.'\" \"'.netrw_fname.'\"'
"    call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
    " save choice/id/password for future use
    let b:netrw_lastfile = choice

    " perform ftp:
    " -i       : turns off interactive prompting from ftp
    " -n  unix : DON'T use <.netrc>, even though it exists
    " -n  win32: quit being obnoxious about password
    NetrwKeepj norm! 1G"_dd
    call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
    " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
    if getline(1) !~ "^$"
     if  !exists("g:netrw_quiet")
      call netrw#ErrorMsg(s:ERROR,getline(1),15)
     endif
     let mod=1
    endif

    " remove enew buffer (quietly)
    let filtbuf= bufnr("%")
    exe curbuf."b!"
    let &l:bh= bhkeep
    exe filtbuf."bw!"

   ".........................................
   " NetWrite: (scp) NetWrite Method #4 {{{3
   elseif     b:netrw_method == 4
"    call Decho("write via scp (method #4)",'~'.expand("<slnum>"))
    if exists("g:netrw_port") && g:netrw_port != ""
     let useport= " ".g:netrw_scpport." ".fnameescape(g:netrw_port)
    else
     let useport= ""
    endif
    call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_scp_cmd.useport." ".s:ShellEscape(tmpfile,1)." ".s:ShellEscape(g:netrw_machine.":".b:netrw_fname,1))
    let b:netrw_lastfile = choice

   ".........................................
   " NetWrite: (http) NetWrite Method #5 {{{3
   elseif     b:netrw_method == 5
"    call Decho("write via http (method #5)",'~'.expand("<slnum>"))
    let curl= substitute(g:netrw_http_put_cmd,'\s\+.*$',"","")
    if executable(curl)
     let url= g:netrw_choice
     call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_http_put_cmd." ".s:ShellEscape(tmpfile,1)." ".s:ShellEscape(url,1) )
    elseif !exists("g:netrw_quiet")
     call netrw#ErrorMsg(s:ERROR,"can't write to http using <".g:netrw_http_put_cmd.">",16)
    endif

   ".........................................
   " NetWrite: (dav) NetWrite Method #6 (cadaver) {{{3
   elseif     b:netrw_method == 6
"    call Decho("write via cadaver (method #6)",'~'.expand("<slnum>"))

    " Construct execution string (four lines) which will be passed through filter
    let netrw_fname = escape(b:netrw_fname,g:netrw_fname_escape)
    let bhkeep      = &l:bh

    " formerly just a "new...bd!", that changed the window sizes when equalalways.  Using enew workaround instead
    let curbuf      = bufnr("%")
    setl bh=hide
    keepj keepalt enew

    setl ff=unix
    if exists("g:netrw_port") && g:netrw_port != ""
     NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
    else
     NetrwKeepj put ='open '.g:netrw_machine
    endif
    if exists("g:netrw_uid") && exists("s:netrw_passwd") && g:netrw_uid != ""
     NetrwKeepj put ='user '.g:netrw_uid.' '.s:netrw_passwd
    endif
    NetrwKeepj put ='put '.tmpfile.' '.netrw_fname

    " perform cadaver operation:
    NetrwKeepj norm! 1G"_dd
    call s:NetrwExe(s:netrw_silentxfer."%!".g:netrw_dav_cmd)

    " remove enew buffer (quietly)
    let filtbuf= bufnr("%")
    exe curbuf."b!"
    let &l:bh            = bhkeep
    exe filtbuf."bw!"

    let b:netrw_lastfile = choice

   ".........................................
   " NetWrite: (rsync) NetWrite Method #7 {{{3
   elseif     b:netrw_method == 7
"    call Decho("write via rsync (method #7)",'~'.expand("<slnum>"))
    call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_rsync_cmd." ".s:ShellEscape(tmpfile,1)." ".s:ShellEscape(g:netrw_machine.g:netrw_rsync_sep.b:netrw_fname,1))
    let b:netrw_lastfile = choice

   ".........................................
   " NetWrite: (sftp) NetWrite Method #9 {{{3
   elseif     b:netrw_method == 9
"    call Decho("write via sftp (method #9)",'~'.expand("<slnum>"))
    let netrw_fname= escape(b:netrw_fname,g:netrw_fname_escape)
    if exists("g:netrw_uid") &&  ( g:netrw_uid != "" )
     let uid_machine = g:netrw_uid .'@'. g:netrw_machine
    else
     let uid_machine = g:netrw_machine
    endif

    " formerly just a "new...bd!", that changed the window sizes when equalalways.  Using enew workaround instead
    let bhkeep = &l:bh
    let curbuf = bufnr("%")
    setl bh=hide
    keepj keepalt enew

    setl ff=unix
    call setline(1,'put "'.escape(tmpfile,'\').'" '.netrw_fname)
"    call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
    let sftpcmd= substitute(g:netrw_sftp_cmd,"%TEMPFILE%",escape(tmpfile,'\'),"g")
    call s:NetrwExe(s:netrw_silentxfer."%!".sftpcmd.' '.s:ShellEscape(uid_machine,1))
    let filtbuf= bufnr("%")
    exe curbuf."b!"
    let &l:bh            = bhkeep
    exe filtbuf."bw!"
    let b:netrw_lastfile = choice

   ".........................................
   " NetWrite: Complain {{{3
   else
    call netrw#ErrorMsg(s:WARNING,"unable to comply with your request<" . choice . ">",17)
    let leavemod= 1
   endif
  endwhile

  " NetWrite: Cleanup: {{{3
"  call Decho("cleanup",'~'.expand("<slnum>"))
  if s:FileReadable(tmpfile)
"   call Decho("tmpfile<".tmpfile."> readable, will now delete it",'~'.expand("<slnum>"))
   call s:NetrwDelete(tmpfile)
  endif
  call s:NetrwOptionsRestore("w:")

  if a:firstline == 1 && a:lastline == line("$")
   " restore modifiability; usually equivalent to set nomod
   let &l:mod= mod
"   call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
  elseif !exists("leavemod")
   " indicate that the buffer has not been modified since last written
"   call Decho("set nomod",'~'.expand("<slnum>"))
   setl nomod
"   call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
  endif

"  call Dret("netrw#NetWrite")
endfun

" ---------------------------------------------------------------------
" netrw#NetSource: source a remotely hosted vim script {{{2
" uses NetRead to get a copy of the file into a temporarily file,
"              then sources that file,
"              then removes that file.
fun! netrw#NetSource(...)
"  call Dfunc("netrw#NetSource() a:0=".a:0)
  if a:0 > 0 && a:1 == '?'
   " give help
   echomsg 'NetSource Usage:'
   echomsg ':Nsource dav://machine[:port]/path            uses cadaver'
   echomsg ':Nsource fetch://machine/path                 uses fetch'
   echomsg ':Nsource ftp://[user@]machine[:port]/path     uses ftp   autodetects <.netrc>'
   echomsg ':Nsource http[s]://[user@]machine/path        uses http  wget'
   echomsg ':Nsource rcp://[user@]machine/path            uses rcp'
   echomsg ':Nsource rsync://machine[:port]/path          uses rsync'
   echomsg ':Nsource scp://[user@]machine[[:#]port]/path  uses scp'
   echomsg ':Nsource sftp://[user@]machine[[:#]port]/path uses sftp'
   sleep 4
  else
   let i= 1
   while i <= a:0
    call netrw#NetRead(3,a:{i})
"    call Decho("s:netread_tmpfile<".s:netrw_tmpfile.">",'~'.expand("<slnum>"))
    if s:FileReadable(s:netrw_tmpfile)
"     call Decho("exe so ".fnameescape(s:netrw_tmpfile),'~'.expand("<slnum>"))
     exe "so ".fnameescape(s:netrw_tmpfile)
"     call Decho("delete(".s:netrw_tmpfile.")",'~'.expand("<slnum>"))
     if delete(s:netrw_tmpfile)
      call netrw#ErrorMsg(s:ERROR,"unable to delete directory <".s:netrw_tmpfile.">!",103)
     endif
     unlet s:netrw_tmpfile
    else
     call netrw#ErrorMsg(s:ERROR,"unable to source <".a:{i}.">!",48)
    endif
    let i= i + 1
   endwhile
  endif
"  call Dret("netrw#NetSource")
endfun

" ---------------------------------------------------------------------
" netrw#SetTreetop: resets the tree top to the current directory/specified directory {{{2
"                   (implements the :Ntree command)
fun! netrw#SetTreetop(iscmd,...)
"  call Dfunc("netrw#SetTreetop(iscmd=".a:iscmd." ".((a:0 > 0)? a:1 : "").") a:0=".a:0)
"  call Decho("w:netrw_treetop<".w:netrw_treetop.">")

  " iscmd==0: netrw#SetTreetop called using gn mapping
  " iscmd==1: netrw#SetTreetop called using :Ntree from the command line
"  call Decho("(iscmd=".a:iscmd.": called using :Ntree from command line",'~'.expand("<slnum>"))
  " clear out the current tree
  if exists("w:netrw_treetop")
"   call Decho("clearing out current tree",'~'.expand("<slnum>"))
   let inittreetop= w:netrw_treetop
   unlet w:netrw_treetop
  endif
  if exists("w:netrw_treedict")
"   call Decho("freeing w:netrw_treedict",'~'.expand("<slnum>"))
   unlet w:netrw_treedict
  endif
"  call Decho("inittreetop<".(exists("inittreetop")? inittreetop : "n/a").">")

  if (a:iscmd == 0 || a:1 == "") && exists("inittreetop")
   let treedir         = s:NetrwTreePath(inittreetop)
"   call Decho("treedir<".treedir.">",'~'.expand("<slnum>"))
  else
   if isdirectory(s:NetrwFile(a:1))
"    call Decho("a:1<".a:1."> is a directory",'~'.expand("<slnum>"))
    let treedir         = a:1
    let s:netrw_treetop = treedir
   elseif exists("b:netrw_curdir") && (isdirectory(s:NetrwFile(b:netrw_curdir."/".a:1)) || a:1 =~ '^\a\{3,}://')
    let treedir         = b:netrw_curdir."/".a:1
    let s:netrw_treetop = treedir
"    call Decho("a:1<".a:1."> is NOT a directory, using treedir<".treedir.">",'~'.expand("<slnum>"))
   else
    " normally the cursor is left in the message window.
    " However, here this results in the directory being listed in the message window, which is not wanted.
    let netrwbuf= bufnr("%")
    call netrw#ErrorMsg(s:ERROR,"sorry, ".a:1." doesn't seem to be a directory!",95)
    exe bufwinnr(netrwbuf)."wincmd w"
    let treedir         = "."
    let s:netrw_treetop = getcwd()
   endif
  endif
"  call Decho("treedir<".treedir.">",'~'.expand("<slnum>"))

  " determine if treedir is remote or local
  let islocal= expand("%") !~ '^\a\{3,}://'
"  call Decho("islocal=".islocal,'~'.expand("<slnum>"))

  " browse the resulting directory
  if islocal
   call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(islocal,treedir))
  else
   call s:NetrwBrowse(islocal,s:NetrwBrowseChgDir(islocal,treedir))
  endif

"  call Dret("netrw#SetTreetop")
endfun

" ===========================================
" s:NetrwGetFile: Function to read temporary file "tfile" with command "readcmd". {{{2
"    readcmd == %r : replace buffer with newly read file
"            == 0r : read file at top of buffer
"            == r  : read file after current line
"            == t  : leave file in temporary form (ie. don't read into buffer)
fun! s:NetrwGetFile(readcmd, tfile, method)
"  call Dfunc("NetrwGetFile(readcmd<".a:readcmd.">,tfile<".a:tfile."> method<".a:method.">)")

  " readcmd=='t': simply do nothing
  if a:readcmd == 't'
"   call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"   call Dret("NetrwGetFile : skip read of tfile<".a:tfile.">")
   return
  endif

  " get name of remote filename (ie. url and all)
  let rfile= bufname("%")
"  call Decho("rfile<".rfile.">",'~'.expand("<slnum>"))

  if exists("*NetReadFixup")
   " for the use of NetReadFixup (not otherwise used internally)
   let line2= line("$")
  endif

  if a:readcmd[0] == '%'
  " get file into buffer
"   call Decho("get file into buffer",'~'.expand("<slnum>"))

   " rename the current buffer to the temp file (ie. tfile)
   if g:netrw_cygwin
    let tfile= substitute(a:tfile,g:netrw_cygdrive.'/\(.\)','\1:','')
   else
    let tfile= a:tfile
   endif
   call s:NetrwBufRename(tfile)

   " edit temporary file (ie. read the temporary file in)
   if     rfile =~ '\.zip$'
"    call Decho("handling remote zip file with zip#Browse(tfile<".tfile.">)",'~'.expand("<slnum>"))
    call zip#Browse(tfile)
   elseif rfile =~ '\.tar$'
"    call Decho("handling remote tar file with tar#Browse(tfile<".tfile.">)",'~'.expand("<slnum>"))
    call tar#Browse(tfile)
   elseif rfile =~ '\.tar\.gz$'
"    call Decho("handling remote gzip-compressed tar file",'~'.expand("<slnum>"))
    call tar#Browse(tfile)
   elseif rfile =~ '\.tar\.bz2$'
"    call Decho("handling remote bz2-compressed tar file",'~'.expand("<slnum>"))
    call tar#Browse(tfile)
   elseif rfile =~ '\.tar\.xz$'
"    call Decho("handling remote xz-compressed tar file",'~'.expand("<slnum>"))
    call tar#Browse(tfile)
   elseif rfile =~ '\.txz$'
"    call Decho("handling remote xz-compressed tar file (.txz)",'~'.expand("<slnum>"))
    call tar#Browse(tfile)
   else
"    call Decho("edit temporary file",'~'.expand("<slnum>"))
    NetrwKeepj e!
   endif

   " rename buffer back to remote filename
   call s:NetrwBufRename(rfile)

   " Jan 19, 2022: COMBAK -- bram problem with https://github.com/vim/vim/pull/9554.diff filetype
   " Detect filetype of local version of remote file.
   " Note that isk must not include a "/" for scripts.vim
   " to process this detection correctly.
"   call Decho("detect filetype of local version of remote file<".rfile.">",'~'.expand("<slnum>"))
"   call Decho("..did_filetype()=".did_filetype())
"   setl ft=
"   call Decho("..initial filetype<".&ft."> for buf#".bufnr()."<".bufname().">")
   let iskkeep= &isk
   setl isk-=/
   filetype detect
"   call Decho("..local filetype<".&ft."> for buf#".bufnr()."<".bufname().">")
   let &l:isk= iskkeep
"   call Dredir("ls!","NetrwGetFile (renamed buffer back to remote filename<".rfile."> : expand(%)<".expand("%").">)")
   let line1 = 1
   let line2 = line("$")

  elseif !&ma
   " attempting to read a file after the current line in the file, but the buffer is not modifiable
   NetrwKeepj call netrw#ErrorMsg(s:WARNING,"attempt to read<".a:tfile."> into a non-modifiable buffer!",94)
"   call Dret("NetrwGetFile : attempt to read<".a:tfile."> into a non-modifiable buffer!")
   return

  elseif s:FileReadable(a:tfile)
   " read file after current line
"   call Decho("read file<".a:tfile."> after current line",'~'.expand("<slnum>"))
   let curline = line(".")
   let lastline= line("$")
"   call Decho("exe<".a:readcmd." ".fnameescape(v:cmdarg)." ".fnameescape(a:tfile).">  line#".curline,'~'.expand("<slnum>"))
   exe "NetrwKeepj ".a:readcmd." ".fnameescape(v:cmdarg)." ".fnameescape(a:tfile)
   let line1= curline + 1
   let line2= line("$") - lastline + 1

  else
   " not readable
"   call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"   call Decho("tfile<".a:tfile."> not readable",'~'.expand("<slnum>"))
   NetrwKeepj call netrw#ErrorMsg(s:WARNING,"file <".a:tfile."> not readable",9)
"   call Dret("NetrwGetFile : tfile<".a:tfile."> not readable")
   return
  endif

  " User-provided (ie. optional) fix-it-up command
  if exists("*NetReadFixup")
"   call Decho("calling NetReadFixup(method<".a:method."> line1=".line1." line2=".line2.")",'~'.expand("<slnum>"))
   NetrwKeepj call NetReadFixup(a:method, line1, line2)
"  else " Decho
"   call Decho("NetReadFixup() not called, doesn't exist  (line1=".line1." line2=".line2.")",'~'.expand("<slnum>"))
  endif

  if has("gui") && has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu
   " update the Buffers menu
   NetrwKeepj call s:UpdateBuffersMenu()
  endif

"  call Decho("readcmd<".a:readcmd."> cmdarg<".v:cmdarg."> tfile<".a:tfile."> readable=".s:FileReadable(a:tfile),'~'.expand("<slnum>"))

 " make sure file is being displayed
"  redraw!

"  call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"  call Dret("NetrwGetFile")
endfun

" ------------------------------------------------------------------------
" s:NetrwMethod:  determine method of transfer {{{2
" Input:
"   choice = url   [protocol:]//[userid@]hostname[:port]/[path-to-file]
" Output:
"  b:netrw_method= 1: rcp
"                  2: ftp + <.netrc>
"	           3: ftp + machine, id, password, and [path]filename
"	           4: scp
"	           5: http[s] (wget)
"	           6: dav
"	           7: rsync
"	           8: fetch
"	           9: sftp
"	          10: file
"  g:netrw_machine= hostname
"  b:netrw_fname  = filename
"  g:netrw_port   = optional port number (for ftp)
"  g:netrw_choice = copy of input url (choice)
fun! s:NetrwMethod(choice)
"   call Dfunc("s:NetrwMethod(a:choice<".a:choice.">)")

   " sanity check: choice should have at least three slashes in it
   if strlen(substitute(a:choice,'[^/]','','g')) < 3
    call netrw#ErrorMsg(s:ERROR,"not a netrw-style url; netrw uses protocol://[user@]hostname[:port]/[path])",78)
    let b:netrw_method = -1
"    call Dret("s:NetrwMethod : incorrect url format<".a:choice.">")
    return
   endif

   " record current g:netrw_machine, if any
   " curmachine used if protocol == ftp and no .netrc
   if exists("g:netrw_machine")
    let curmachine= g:netrw_machine
"    call Decho("curmachine<".curmachine.">",'~'.expand("<slnum>"))
   else
    let curmachine= "N O T A HOST"
   endif
   if exists("g:netrw_port")
    let netrw_port= g:netrw_port
   endif

   " insure that netrw_ftp_cmd starts off every method determination
   " with the current g:netrw_ftp_cmd
   let s:netrw_ftp_cmd= g:netrw_ftp_cmd

  " initialization
  let b:netrw_method  = 0
  let g:netrw_machine = ""
  let b:netrw_fname   = ""
  let g:netrw_port    = ""
  let g:netrw_choice  = a:choice

  " Patterns:
  " mipf     : a:machine a:id password filename	     Use ftp
  " mf	    : a:machine filename		     Use ftp + <.netrc> or g:netrw_uid s:netrw_passwd
  " ftpurm   : ftp://[user@]host[[#:]port]/filename  Use ftp + <.netrc> or g:netrw_uid s:netrw_passwd
  " rcpurm   : rcp://[user@]host/filename	     Use rcp
  " rcphf    : [user@]host:filename		     Use rcp
  " scpurm   : scp://[user@]host[[#:]port]/filename  Use scp
  " httpurm  : http[s]://[user@]host/filename	     Use wget
  " davurm   : dav[s]://host[:port]/path             Use cadaver/curl
  " rsyncurm : rsync://host[:port]/path              Use rsync
  " fetchurm : fetch://[user@]host[:http]/filename   Use fetch (defaults to ftp, override for http)
  " sftpurm  : sftp://[user@]host/filename  Use scp
  " fileurm  : file://[user@]host/filename	     Use elinks or links
  let mipf     = '^\(\S\+\)\s\+\(\S\+\)\s\+\(\S\+\)\s\+\(\S\+\)$'
  let mf       = '^\(\S\+\)\s\+\(\S\+\)$'
  let ftpurm   = '^ftp://\(\([^/]*\)@\)\=\([^/#:]\{-}\)\([#:]\d\+\)\=/\(.*\)$'
  let rcpurm   = '^rcp://\%(\([^/]*\)@\)\=\([^/]\{-}\)/\(.*\)$'
  let rcphf    = '^\(\(\h\w*\)@\)\=\(\h\w*\):\([^@]\+\)$'
  let scpurm   = '^scp://\([^/#:]\+\)\%([#:]\(\d\+\)\)\=/\(.*\)$'
  let httpurm  = '^https\=://\([^/]\{-}\)\(/.*\)\=$'
  let davurm   = '^davs\=://\([^/]\+\)/\(.*/\)\([-_.~[:alnum:]]\+\)$'
  let rsyncurm = '^rsync://\([^/]\{-}\)/\(.*\)\=$'
  let fetchurm = '^fetch://\(\([^/]*\)@\)\=\([^/#:]\{-}\)\(:http\)\=/\(.*\)$'
  let sftpurm  = '^sftp://\([^/]\{-}\)/\(.*\)\=$'
  let fileurm  = '^file\=://\(.*\)$'

"  call Decho("determine method:",'~'.expand("<slnum>"))
  " Determine Method
  " Method#1: rcp://user@hostname/...path-to-file {{{3
  if match(a:choice,rcpurm) == 0
"   call Decho("rcp://...",'~'.expand("<slnum>"))
   let b:netrw_method  = 1
   let userid          = substitute(a:choice,rcpurm,'\1',"")
   let g:netrw_machine = substitute(a:choice,rcpurm,'\2',"")
   let b:netrw_fname   = substitute(a:choice,rcpurm,'\3',"")
   if userid != ""
    let g:netrw_uid= userid
   endif

  " Method#4: scp://user@hostname/...path-to-file {{{3
  elseif match(a:choice,scpurm) == 0
"   call Decho("scp://...",'~'.expand("<slnum>"))
   let b:netrw_method  = 4
   let g:netrw_machine = substitute(a:choice,scpurm,'\1',"")
   let g:netrw_port    = substitute(a:choice,scpurm,'\2',"")
   let b:netrw_fname   = substitute(a:choice,scpurm,'\3',"")

  " Method#5: http[s]://user@hostname/...path-to-file {{{3
  elseif match(a:choice,httpurm) == 0
"   call Decho("http[s]://...",'~'.expand("<slnum>"))
   let b:netrw_method = 5
   let g:netrw_machine= substitute(a:choice,httpurm,'\1',"")
   let b:netrw_fname  = substitute(a:choice,httpurm,'\2',"")
   let b:netrw_http   = (a:choice =~ '^https:')? "https" : "http"

  " Method#6: dav://hostname[:port]/..path-to-file.. {{{3
  elseif match(a:choice,davurm) == 0
"   call Decho("dav://...",'~'.expand("<slnum>"))
   let b:netrw_method= 6
   if a:choice =~ 'davs:'
    let g:netrw_machine= 'https://'.substitute(a:choice,davurm,'\1/\2',"")
   else
    let g:netrw_machine= 'http://'.substitute(a:choice,davurm,'\1/\2',"")
   endif
   let b:netrw_fname  = substitute(a:choice,davurm,'\3',"")

   " Method#7: rsync://user@hostname/...path-to-file {{{3
  elseif match(a:choice,rsyncurm) == 0
"   call Decho("rsync://...",'~'.expand("<slnum>"))
   let b:netrw_method = 7
   let g:netrw_machine= substitute(a:choice,rsyncurm,'\1',"")
   let b:netrw_fname  = substitute(a:choice,rsyncurm,'\2',"")

   " Methods 2,3: ftp://[user@]hostname[[:#]port]/...path-to-file {{{3
  elseif match(a:choice,ftpurm) == 0
"   call Decho("ftp://...",'~'.expand("<slnum>"))
   let userid	      = substitute(a:choice,ftpurm,'\2',"")
   let g:netrw_machine= substitute(a:choice,ftpurm,'\3',"")
   let g:netrw_port   = substitute(a:choice,ftpurm,'\4',"")
   let b:netrw_fname  = substitute(a:choice,ftpurm,'\5',"")
"   call Decho("g:netrw_machine<".g:netrw_machine.">",'~'.expand("<slnum>"))
   if userid != ""
    let g:netrw_uid= userid
   endif

   if curmachine != g:netrw_machine
    if exists("s:netrw_hup[".g:netrw_machine."]")
     call NetUserPass("ftp:".g:netrw_machine)
    elseif exists("s:netrw_passwd")
     " if there's a change in hostname, require password re-entry
     unlet s:netrw_passwd
    endif
    if exists("netrw_port")
     unlet netrw_port
    endif
   endif

   if exists("g:netrw_uid") && exists("s:netrw_passwd")
    let b:netrw_method = 3
   else
    let host= substitute(g:netrw_machine,'\..*$','','')
    if exists("s:netrw_hup[host]")
     call NetUserPass("ftp:".host)

    elseif has("win32") && s:netrw_ftp_cmd =~# '-[sS]:'
"     call Decho("has -s: : s:netrw_ftp_cmd<".s:netrw_ftp_cmd.">",'~'.expand("<slnum>"))
"     call Decho("          g:netrw_ftp_cmd<".g:netrw_ftp_cmd.">",'~'.expand("<slnum>"))
     if g:netrw_ftp_cmd =~# '-[sS]:\S*MACHINE\>'
      let s:netrw_ftp_cmd= substitute(g:netrw_ftp_cmd,'\<MACHINE\>',g:netrw_machine,'')
"      call Decho("s:netrw_ftp_cmd<".s:netrw_ftp_cmd.">",'~'.expand("<slnum>"))
     endif
     let b:netrw_method= 2
    elseif s:FileReadable(expand("$HOME/.netrc")) && !g:netrw_ignorenetrc
"     call Decho("using <".expand("$HOME/.netrc")."> (readable)",'~'.expand("<slnum>"))
     let b:netrw_method= 2
    else
     if !exists("g:netrw_uid") || g:netrw_uid == ""
      call NetUserPass()
     elseif !exists("s:netrw_passwd") || s:netrw_passwd == ""
      call NetUserPass(g:netrw_uid)
    " else just use current g:netrw_uid and s:netrw_passwd
     endif
     let b:netrw_method= 3
    endif
   endif

  " Method#8: fetch {{{3
  elseif match(a:choice,fetchurm) == 0
"   call Decho("fetch://...",'~'.expand("<slnum>"))
   let b:netrw_method = 8
   let g:netrw_userid = substitute(a:choice,fetchurm,'\2',"")
   let g:netrw_machine= substitute(a:choice,fetchurm,'\3',"")
   let b:netrw_option = substitute(a:choice,fetchurm,'\4',"")
   let b:netrw_fname  = substitute(a:choice,fetchurm,'\5',"")

   " Method#3: Issue an ftp : "machine id password [path/]filename" {{{3
  elseif match(a:choice,mipf) == 0
"   call Decho("(ftp) host id pass file",'~'.expand("<slnum>"))
   let b:netrw_method  = 3
   let g:netrw_machine = substitute(a:choice,mipf,'\1',"")
   let g:netrw_uid     = substitute(a:choice,mipf,'\2',"")
   let s:netrw_passwd  = substitute(a:choice,mipf,'\3',"")
   let b:netrw_fname   = substitute(a:choice,mipf,'\4',"")
   call NetUserPass(g:netrw_machine,g:netrw_uid,s:netrw_passwd)

  " Method#3: Issue an ftp: "hostname [path/]filename" {{{3
  elseif match(a:choice,mf) == 0
"   call Decho("(ftp) host file",'~'.expand("<slnum>"))
   if exists("g:netrw_uid") && exists("s:netrw_passwd")
    let b:netrw_method  = 3
    let g:netrw_machine = substitute(a:choice,mf,'\1',"")
    let b:netrw_fname   = substitute(a:choice,mf,'\2',"")

   elseif s:FileReadable(expand("$HOME/.netrc"))
    let b:netrw_method  = 2
    let g:netrw_machine = substitute(a:choice,mf,'\1',"")
    let b:netrw_fname   = substitute(a:choice,mf,'\2',"")
   endif

  " Method#9: sftp://user@hostname/...path-to-file {{{3
  elseif match(a:choice,sftpurm) == 0
"   call Decho("sftp://...",'~'.expand("<slnum>"))
   let b:netrw_method = 9
   let g:netrw_machine= substitute(a:choice,sftpurm,'\1',"")
   let b:netrw_fname  = substitute(a:choice,sftpurm,'\2',"")

  " Method#1: Issue an rcp: hostname:filename"  (this one should be last) {{{3
  elseif match(a:choice,rcphf) == 0
"   call Decho("(rcp) [user@]host:file) rcphf<".rcphf.">",'~'.expand("<slnum>"))
   let b:netrw_method  = 1
   let userid          = substitute(a:choice,rcphf,'\2',"")
   let g:netrw_machine = substitute(a:choice,rcphf,'\3',"")
   let b:netrw_fname   = substitute(a:choice,rcphf,'\4',"")
"   call Decho('\1<'.substitute(a:choice,rcphf,'\1',"").">",'~'.expand("<slnum>"))
"   call Decho('\2<'.substitute(a:choice,rcphf,'\2',"").">",'~'.expand("<slnum>"))
"   call Decho('\3<'.substitute(a:choice,rcphf,'\3',"").">",'~'.expand("<slnum>"))
"   call Decho('\4<'.substitute(a:choice,rcphf,'\4',"").">",'~'.expand("<slnum>"))
   if userid != ""
    let g:netrw_uid= userid
   endif

   " Method#10: file://user@hostname/...path-to-file {{{3
  elseif match(a:choice,fileurm) == 0 && exists("g:netrw_file_cmd")
"   call Decho("http[s]://...",'~'.expand("<slnum>"))
   let b:netrw_method = 10
   let b:netrw_fname  = substitute(a:choice,fileurm,'\1',"")
"   call Decho('\1<'.substitute(a:choice,fileurm,'\1',"").">",'~'.expand("<slnum>"))

  " Cannot Determine Method {{{3
  else
   if !exists("g:netrw_quiet")
    call netrw#ErrorMsg(s:WARNING,"cannot determine method (format: protocol://[user@]hostname[:port]/[path])",45)
   endif
   let b:netrw_method  = -1
  endif
  "}}}3

  if g:netrw_port != ""
   " remove any leading [:#] from port number
   let g:netrw_port = substitute(g:netrw_port,'[#:]\+','','')
  elseif exists("netrw_port")
   " retain port number as implicit for subsequent ftp operations
   let g:netrw_port= netrw_port
  endif

"  call Decho("a:choice       <".a:choice.">",'~'.expand("<slnum>"))
"  call Decho("b:netrw_method <".b:netrw_method.">",'~'.expand("<slnum>"))
"  call Decho("g:netrw_machine<".g:netrw_machine.">",'~'.expand("<slnum>"))
"  call Decho("g:netrw_port   <".g:netrw_port.">",'~'.expand("<slnum>"))
"  if exists("g:netrw_uid")		"Decho
"   call Decho("g:netrw_uid    <".g:netrw_uid.">",'~'.expand("<slnum>"))
"  endif					"Decho
"  if exists("s:netrw_passwd")		"Decho
"   call Decho("s:netrw_passwd <".s:netrw_passwd.">",'~'.expand("<slnum>"))
"  endif					"Decho
"  call Decho("b:netrw_fname  <".b:netrw_fname.">",'~'.expand("<slnum>"))
"  call Dret("s:NetrwMethod : b:netrw_method=".b:netrw_method." g:netrw_port=".g:netrw_port)
endfun

" ---------------------------------------------------------------------
" NetUserPass: set username and password for subsequent ftp transfer {{{2
"   Usage:  :call NetUserPass()		               -- will prompt for userid and password
"	    :call NetUserPass("uid")	               -- will prompt for password
"	    :call NetUserPass("uid","password")        -- sets global userid and password
"	    :call NetUserPass("ftp:host")              -- looks up userid and password using hup dictionary
"	    :call NetUserPass("host","uid","password") -- sets hup dictionary with host, userid, password
fun! NetUserPass(...)

" call Dfunc("NetUserPass() a:0=".a:0)

 if !exists('s:netrw_hup')
  let s:netrw_hup= {}
 endif

 if a:0 == 0
  " case: no input arguments

  " change host and username if not previously entered; get new password
  if !exists("g:netrw_machine")
   let g:netrw_machine= input('Enter hostname: ')
  endif
  if !exists("g:netrw_uid") || g:netrw_uid == ""
   " get username (user-id) via prompt
   let g:netrw_uid= input('Enter username: ')
  endif
  " get password via prompting
  let s:netrw_passwd= inputsecret("Enter Password: ")

  " set up hup database
  let host = substitute(g:netrw_machine,'\..*$','','')
  if !exists('s:netrw_hup[host]')
   let s:netrw_hup[host]= {}
  endif
  let s:netrw_hup[host].uid    = g:netrw_uid
  let s:netrw_hup[host].passwd = s:netrw_passwd

 elseif a:0 == 1
  " case: one input argument

  if a:1 =~ '^ftp:'
   " get host from ftp:... url
   " access userid and password from hup (host-user-passwd) dictionary
"   call Decho("case a:0=1: a:1<".a:1."> (get host from ftp:... url)",'~'.expand("<slnum>"))
   let host = substitute(a:1,'^ftp:','','')
   let host = substitute(host,'\..*','','')
   if exists("s:netrw_hup[host]")
    let g:netrw_uid    = s:netrw_hup[host].uid
    let s:netrw_passwd = s:netrw_hup[host].passwd
"    call Decho("get s:netrw_hup[".host."].uid   <".s:netrw_hup[host].uid.">",'~'.expand("<slnum>"))
"    call Decho("get s:netrw_hup[".host."].passwd<".s:netrw_hup[host].passwd.">",'~'.expand("<slnum>"))
   else
    let g:netrw_uid    = input("Enter UserId: ")
    let s:netrw_passwd = inputsecret("Enter Password: ")
   endif

  else
   " case: one input argument, not an url.  Using it as a new user-id.
"   call Decho("case a:0=1: a:1<".a:1."> (get host from input argument, not an url)",'~'.expand("<slnum>"))
   if exists("g:netrw_machine")
    if g:netrw_machine =~ '[0-9.]\+'
     let host= g:netrw_machine
    else
     let host= substitute(g:netrw_machine,'\..*$','','')
    endif
   else
    let g:netrw_machine= input('Enter hostname: ')
   endif
   let g:netrw_uid = a:1
"   call Decho("set g:netrw_uid= <".g:netrw_uid.">",'~'.expand("<slnum>"))
   if exists("g:netrw_passwd")
    " ask for password if one not previously entered
    let s:netrw_passwd= g:netrw_passwd
   else
    let s:netrw_passwd = inputsecret("Enter Password: ")
   endif
  endif

"  call Decho("host<".host.">",'~'.expand("<slnum>"))
  if exists("host")
   if !exists('s:netrw_hup[host]')
    let s:netrw_hup[host]= {}
   endif
   let s:netrw_hup[host].uid    = g:netrw_uid
   let s:netrw_hup[host].passwd = s:netrw_passwd
  endif

 elseif a:0 == 2
  let g:netrw_uid    = a:1
  let s:netrw_passwd = a:2

 elseif a:0 == 3
  " enter hostname, user-id, and password into the hup dictionary
  let host = substitute(a:1,'^\a\+:','','')
  let host = substitute(host,'\..*$','','')
  if !exists('s:netrw_hup[host]')
   let s:netrw_hup[host]= {}
  endif
  let s:netrw_hup[host].uid    = a:2
  let s:netrw_hup[host].passwd = a:3
  let g:netrw_uid              = s:netrw_hup[host].uid
  let s:netrw_passwd           = s:netrw_hup[host].passwd
"  call Decho("set s:netrw_hup[".host."].uid   <".s:netrw_hup[host].uid.">",'~'.expand("<slnum>"))
"  call Decho("set s:netrw_hup[".host."].passwd<".s:netrw_hup[host].passwd.">",'~'.expand("<slnum>"))
 endif

" call Dret("NetUserPass : uid<".g:netrw_uid."> passwd<".s:netrw_passwd.">")
endfun

" =================================
"  Shared Browsing Support:    {{{1
" =================================

" ---------------------------------------------------------------------
" s:ExplorePatHls: converts an Explore pattern into a regular expression search pattern {{{2
fun! s:ExplorePatHls(pattern)
"  call Dfunc("s:ExplorePatHls(pattern<".a:pattern.">)")
  let repat= substitute(a:pattern,'^**/\{1,2}','','')
"  call Decho("repat<".repat.">",'~'.expand("<slnum>"))
  let repat= escape(repat,'][.\')
"  call Decho("repat<".repat.">",'~'.expand("<slnum>"))
  let repat= '\<'.substitute(repat,'\*','\\(\\S\\+ \\)*\\S\\+','g').'\>'
"  call Dret("s:ExplorePatHls repat<".repat.">")
  return repat
endfun

" ---------------------------------------------------------------------
"  s:NetrwBookHistHandler: {{{2
"    0: (user: <mb>)   bookmark current directory
"    1: (user: <gb>)   change to the bookmarked directory
"    2: (user: <qb>)   list bookmarks
"    3: (browsing)     records current directory history
"    4: (user: <u>)    go up   (previous) directory, using history
"    5: (user: <U>)    go down (next)     directory, using history
"    6: (user: <mB>)   delete bookmark
fun! s:NetrwBookHistHandler(chg,curdir)
"  call Dfunc("s:NetrwBookHistHandler(chg=".a:chg." curdir<".a:curdir.">) cnt=".v:count." histcnt=".g:netrw_dirhistcnt." histmax=".g:netrw_dirhistmax)
  if !exists("g:netrw_dirhistmax") || g:netrw_dirhistmax <= 0
"   "  call Dret("s:NetrwBookHistHandler - suppressed due to g:netrw_dirhistmax")
   return
  endif

  let ykeep    = @@
  let curbufnr = bufnr("%")

  if a:chg == 0
   " bookmark the current directory
"   call Decho("(user: <b>) bookmark the current directory",'~'.expand("<slnum>"))
   if exists("s:netrwmarkfilelist_{curbufnr}")
    call s:NetrwBookmark(0)
    echo "bookmarked marked files"
   else
    call s:MakeBookmark(a:curdir)
    echo "bookmarked the current directory"
   endif

   try
    call s:NetrwBookHistSave()
   catch
   endtry

  elseif a:chg == 1
   " change to the bookmarked directory
"   call Decho("(user: <".v:count."gb>) change to the bookmarked directory",'~'.expand("<slnum>"))
   if exists("g:netrw_bookmarklist[v:count-1]")
"    call Decho("(user: <".v:count."gb>) bookmarklist=".string(g:netrw_bookmarklist),'~'.expand("<slnum>"))
    exe "NetrwKeepj e ".fnameescape(g:netrw_bookmarklist[v:count-1])
   else
    echomsg "Sorry, bookmark#".v:count." doesn't exist!"
   endif

  elseif a:chg == 2
"   redraw!
   let didwork= 0
   " list user's bookmarks
"   call Decho("(user: <q>) list user's bookmarks",'~'.expand("<slnum>"))
   if exists("g:netrw_bookmarklist")
"    call Decho('list '.len(g:netrw_bookmarklist).' bookmarks','~'.expand("<slnum>"))
    let cnt= 1
    for bmd in g:netrw_bookmarklist
"     call Decho("Netrw Bookmark#".cnt.": ".g:netrw_bookmarklist[cnt-1],'~'.expand("<slnum>"))
     echo printf("Netrw Bookmark#%-2d: %s",cnt,g:netrw_bookmarklist[cnt-1])
     let didwork = 1
     let cnt     = cnt + 1
    endfor
   endif

   " list directory history
   " Note: history is saved only when PerformListing is done;
   "       ie. when netrw can re-use a netrw buffer, the current directory is not saved in the history.
   let cnt     = g:netrw_dirhistcnt
   let first   = 1
   let histcnt = 0
   if g:netrw_dirhistmax > 0
    while ( first || cnt != g:netrw_dirhistcnt )
"    call Decho("first=".first." cnt=".cnt." dirhistcnt=".g:netrw_dirhistcnt,'~'.expand("<slnum>"))
     if exists("g:netrw_dirhist_{cnt}")
"     call Decho("Netrw  History#".histcnt.": ".g:netrw_dirhist_{cnt},'~'.expand("<slnum>"))
      echo printf("Netrw  History#%-2d: %s",histcnt,g:netrw_dirhist_{cnt})
      let didwork= 1
     endif
     let histcnt = histcnt + 1
     let first   = 0
     let cnt     = ( cnt - 1 ) % g:netrw_dirhistmax
     if cnt < 0
      let cnt= cnt + g:netrw_dirhistmax
     endif
    endwhile
   else
    let g:netrw_dirhistcnt= 0
   endif
   if didwork
    call inputsave()|call input("Press <cr> to continue")|call inputrestore()
   endif

  elseif a:chg == 3
   " saves most recently visited directories (when they differ)
"   call Decho("(browsing) record curdir history",'~'.expand("<slnum>"))
   if !exists("g:netrw_dirhistcnt") || !exists("g:netrw_dirhist_{g:netrw_dirhistcnt}") || g:netrw_dirhist_{g:netrw_dirhistcnt} != a:curdir
    if g:netrw_dirhistmax > 0
     let g:netrw_dirhistcnt                   = ( g:netrw_dirhistcnt + 1 ) % g:netrw_dirhistmax
     let g:netrw_dirhist_{g:netrw_dirhistcnt} = a:curdir
    endif
"    call Decho("save dirhist#".g:netrw_dirhistcnt."<".g:netrw_dirhist_{g:netrw_dirhistcnt}.">",'~'.expand("<slnum>"))
   endif

  elseif a:chg == 4
   " u: change to the previous directory stored on the history list
"   call Decho("(user: <u>) chg to prev dir from history",'~'.expand("<slnum>"))
   if g:netrw_dirhistmax > 0
    let g:netrw_dirhistcnt= ( g:netrw_dirhistcnt - v:count1 ) % g:netrw_dirhistmax
    if g:netrw_dirhistcnt < 0
     let g:netrw_dirhistcnt= g:netrw_dirhistcnt + g:netrw_dirhistmax
    endif
   else
    let g:netrw_dirhistcnt= 0
   endif
   if exists("g:netrw_dirhist_{g:netrw_dirhistcnt}")
"    call Decho("changedir u#".g:netrw_dirhistcnt."<".g:netrw_dirhist_{g:netrw_dirhistcnt}.">",'~'.expand("<slnum>"))
    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("b:netrw_curdir")
     setl ma noro
"     call Decho("setl ma noro",'~'.expand("<slnum>"))
     sil! NetrwKeepj %d _
     setl nomod
"     call Decho("setl nomod",'~'.expand("<slnum>"))
"     call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
    endif
"    call Decho("exe e! ".fnameescape(g:netrw_dirhist_{g:netrw_dirhistcnt}),'~'.expand("<slnum>"))
    exe "NetrwKeepj e! ".fnameescape(g:netrw_dirhist_{g:netrw_dirhistcnt})
   else
    if g:netrw_dirhistmax > 0
     let g:netrw_dirhistcnt= ( g:netrw_dirhistcnt + v:count1 ) % g:netrw_dirhistmax
    else
     let g:netrw_dirhistcnt= 0
    endif
    echo "Sorry, no predecessor directory exists yet"
   endif

  elseif a:chg == 5
   " U: change to the subsequent directory stored on the history list
"   call Decho("(user: <U>) chg to next dir from history",'~'.expand("<slnum>"))
   if g:netrw_dirhistmax > 0
    let g:netrw_dirhistcnt= ( g:netrw_dirhistcnt + 1 ) % g:netrw_dirhistmax
    if exists("g:netrw_dirhist_{g:netrw_dirhistcnt}")
"    call Decho("changedir U#".g:netrw_dirhistcnt."<".g:netrw_dirhist_{g:netrw_dirhistcnt}.">",'~'.expand("<slnum>"))
     if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("b:netrw_curdir")
"      call Decho("setl ma noro",'~'.expand("<slnum>"))
      setl ma noro
      sil! NetrwKeepj %d _
"      call Decho("removed all lines from buffer (%d)",'~'.expand("<slnum>"))
"      call Decho("setl nomod",'~'.expand("<slnum>"))
      setl nomod
"      call Decho("(set nomod)  ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
     endif
"    call Decho("exe e! ".fnameescape(g:netrw_dirhist_{g:netrw_dirhistcnt}),'~'.expand("<slnum>"))
     exe "NetrwKeepj e! ".fnameescape(g:netrw_dirhist_{g:netrw_dirhistcnt})
    else
     let g:netrw_dirhistcnt= ( g:netrw_dirhistcnt - 1 ) % g:netrw_dirhistmax
     if g:netrw_dirhistcnt < 0
      let g:netrw_dirhistcnt= g:netrw_dirhistcnt + g:netrw_dirhistmax
     endif
     echo "Sorry, no successor directory exists yet"
    endif
   else
    let g:netrw_dirhistcnt= 0
    echo "Sorry, no successor directory exists yet (g:netrw_dirhistmax is ".g:netrw_dirhistmax.")"
   endif

  elseif a:chg == 6
"   call Decho("(user: <mB>) delete bookmark'd directory",'~'.expand("<slnum>"))
   if exists("s:netrwmarkfilelist_{curbufnr}")
    call s:NetrwBookmark(1)
    echo "removed marked files from bookmarks"
   else
    " delete the v:count'th bookmark
    let iremove = v:count
    let dremove = g:netrw_bookmarklist[iremove - 1]
"    call Decho("delete bookmark#".iremove."<".g:netrw_bookmarklist[iremove - 1].">",'~'.expand("<slnum>"))
    call s:MergeBookmarks()
"    call Decho("remove g:netrw_bookmarklist[".(iremove-1)."]<".g:netrw_bookmarklist[(iremove-1)].">",'~'.expand("<slnum>"))
    NetrwKeepj call remove(g:netrw_bookmarklist,iremove-1)
    echo "removed ".dremove." from g:netrw_bookmarklist"
"    call Decho("g:netrw_bookmarklist=".string(g:netrw_bookmarklist),'~'.expand("<slnum>"))
   endif
"   call Decho("resulting g:netrw_bookmarklist=".string(g:netrw_bookmarklist),'~'.expand("<slnum>"))

   try
    call s:NetrwBookHistSave()
   catch
   endtry
  endif
  call s:NetrwBookmarkMenu()
  call s:NetrwTgtMenu()
  let @@= ykeep
"  call Dret("s:NetrwBookHistHandler")
endfun

" ---------------------------------------------------------------------
" s:NetrwBookHistRead: this function reads bookmarks and history {{{2
"  Will source the history file (.netrwhist) only if the g:netrw_disthistmax is > 0.
"                      Sister function: s:NetrwBookHistSave()
fun! s:NetrwBookHistRead()
"  call Dfunc("s:NetrwBookHistRead()")
  if !exists("g:netrw_dirhistmax") || g:netrw_dirhistmax <= 0
"   call Dret("s:NetrwBookHistRead - nothing read (suppressed due to dirhistmax=".(exists("g:netrw_dirhistmax")? g:netrw_dirhistmax : "n/a").")")
   return
  endif
  let ykeep= @@

  " read bookmarks
  if !exists("s:netrw_initbookhist")
   let home    = s:NetrwHome()
   let savefile= home."/.netrwbook"
   if filereadable(s:NetrwFile(savefile))
"    call Decho("sourcing .netrwbook",'~'.expand("<slnum>"))
    exe "keepalt NetrwKeepj so ".savefile
   endif

   " read history
   if g:netrw_dirhistmax > 0
    let savefile= home."/.netrwhist"
    if filereadable(s:NetrwFile(savefile))
"    call Decho("sourcing .netrwhist",'~'.expand("<slnum>"))
     exe "keepalt NetrwKeepj so ".savefile
    endif
    let s:netrw_initbookhist= 1
    au VimLeave * call s:NetrwBookHistSave()
   endif
  endif

  let @@= ykeep
"  call Decho("dirhistmax=".(exists("g:netrw_dirhistmax")? g:netrw_dirhistmax : "n/a"),'~'.expand("<slnum>"))
"  call Decho("dirhistcnt=".(exists("g:netrw_dirhistcnt")? g:netrw_dirhistcnt : "n/a"),'~'.expand("<slnum>"))
"  call Dret("s:NetrwBookHistRead")
endfun

" ---------------------------------------------------------------------
" s:NetrwBookHistSave: this function saves bookmarks and history to files {{{2
"                      Sister function: s:NetrwBookHistRead()
"                      I used to do this via viminfo but that appears to
"                      be unreliable for long-term storage
"                      If g:netrw_dirhistmax is <= 0, no history or bookmarks
"                      will be saved.
"                      (s:NetrwBookHistHandler(3,...) used to record history)
fun! s:NetrwBookHistSave()
"  call Dfunc("s:NetrwBookHistSave() dirhistmax=".g:netrw_dirhistmax." dirhistcnt=".g:netrw_dirhistcnt)
  if !exists("g:netrw_dirhistmax") || g:netrw_dirhistmax <= 0
"   call Dret("s:NetrwBookHistSave : nothing saved (dirhistmax=".g:netrw_dirhistmax.")")
   return
  endif

  let savefile= s:NetrwHome()."/.netrwhist"
"  call Decho("savefile<".savefile.">",'~'.expand("<slnum>"))
  1split

  " setting up a new buffer which will become .netrwhist
  call s:NetrwEnew()
"  call Decho("case g:netrw_use_noswf=".g:netrw_use_noswf.(exists("+acd")? " +acd" : " -acd"),'~'.expand("<slnum>"))
  if g:netrw_use_noswf
   setl cino= com= cpo-=a cpo-=A fo=nroql2 tw=0 report=10000 noswf
  else
   setl cino= com= cpo-=a cpo-=A fo=nroql2 tw=0 report=10000
  endif
  setl nocin noai noci magic nospell nohid wig= noaw
  setl ma noro write
  if exists("+acd") | setl noacd | endif
  sil! NetrwKeepj keepalt %d _

  " rename enew'd file: .netrwhist -- no attempt to merge
  " record dirhistmax and current dirhistcnt
  " save history
"  call Decho("saving history: dirhistmax=".g:netrw_dirhistmax." dirhistcnt=".g:netrw_dirhistcnt." lastline=".line("$"),'~'.expand("<slnum>"))
  sil! keepalt file .netrwhist
  call setline(1,"let g:netrw_dirhistmax  =".g:netrw_dirhistmax)
  call setline(2,"let g:netrw_dirhistcnt =".g:netrw_dirhistcnt)
  if g:netrw_dirhistmax > 0
   let lastline = line("$")
   let cnt      = g:netrw_dirhistcnt
   let first    = 1
   while ( first || cnt != g:netrw_dirhistcnt )
    let lastline= lastline + 1
    if exists("g:netrw_dirhist_{cnt}")
     call setline(lastline,'let g:netrw_dirhist_'.cnt."='".g:netrw_dirhist_{cnt}."'")
"     call Decho("..".lastline.'let g:netrw_dirhist_'.cnt."='".g:netrw_dirhist_{cnt}."'",'~'.expand("<slnum>"))
    endif
    let first   = 0
    let cnt     = ( cnt - 1 ) % g:netrw_dirhistmax
    if cnt < 0
     let cnt= cnt + g:netrw_dirhistmax
    endif
   endwhile
   exe "sil! w! ".savefile
"   call Decho("exe sil! w! ".savefile,'~'.expand("<slnum>"))
  endif

  " save bookmarks
  sil NetrwKeepj %d _
  if exists("g:netrw_bookmarklist") && g:netrw_bookmarklist != []
"   call Decho("saving bookmarks",'~'.expand("<slnum>"))
   " merge and write .netrwbook
   let savefile= s:NetrwHome()."/.netrwbook"

   if filereadable(s:NetrwFile(savefile))
    let booklist= deepcopy(g:netrw_bookmarklist)
    exe "sil NetrwKeepj keepalt so ".savefile
    for bdm in booklist
     if index(g:netrw_bookmarklist,bdm) == -1
      call add(g:netrw_bookmarklist,bdm)
     endif
    endfor
    call sort(g:netrw_bookmarklist)
   endif

   " construct and save .netrwbook
   call setline(1,"let g:netrw_bookmarklist= ".string(g:netrw_bookmarklist))
   exe "sil! w! ".savefile
"   call Decho("exe sil! w! ".savefile,'~'.expand("<slnum>"))
  endif

  " cleanup -- remove buffer used to construct history
  let bgone= bufnr("%")
  q!
  exe "keepalt ".bgone."bwipe!"

"  call Dret("s:NetrwBookHistSave")
endfun

" ---------------------------------------------------------------------
" s:NetrwBrowse: This function uses the command in g:netrw_list_cmd to provide a {{{2
"  list of the contents of a local or remote directory.  It is assumed that the
"  g:netrw_list_cmd has a string, USEPORT HOSTNAME, that needs to be substituted
"  with the requested remote hostname first.
"    Often called via:  Explore/e dirname/etc -> netrw#LocalBrowseCheck() -> s:NetrwBrowse()
fun! s:NetrwBrowse(islocal,dirname)
  if !exists("w:netrw_liststyle")|let w:netrw_liststyle= g:netrw_liststyle|endif
"  call Dfunc("s:NetrwBrowse(islocal=".a:islocal." dirname<".a:dirname.">) liststyle=".w:netrw_liststyle." ".g:loaded_netrw." buf#".bufnr("%")."<".bufname("%")."> win#".winnr())
"  call Decho("fyi: modified=".&modified." modifiable=".&modifiable." readonly=".&readonly,'~'.expand("<slnum>"))
"  call Decho("fyi: tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
"  call Dredir("ls!","s:NetrwBrowse")

  " save alternate-file's filename if w:netrw_rexlocal doesn't exist
  " This is useful when one edits a local file, then :e ., then :Rex
  if a:islocal && !exists("w:netrw_rexfile") && bufname("#") != ""
   let w:netrw_rexfile= bufname("#")
"   call Decho("setting w:netrw_rexfile<".w:netrw_rexfile."> win#".winnr(),'~'.expand("<slnum>"))
  endif

  " s:NetrwBrowse : initialize history {{{3
  if !exists("s:netrw_initbookhist")
   NetrwKeepj call s:NetrwBookHistRead()
  endif

  " s:NetrwBrowse : simplify the dirname (especially for ".."s in dirnames) {{{3
  if a:dirname !~ '^\a\{3,}://'
   let dirname= simplify(a:dirname)
"   call Decho("simplified dirname<".dirname.">")
  else
   let dirname= a:dirname
  endif

  " repoint t:netrw_lexbufnr if appropriate
  if exists("t:netrw_lexbufnr") && bufnr("%") == t:netrw_lexbufnr
"   call Decho("set repointlexbufnr to true!")
   let repointlexbufnr= 1
  endif

  " s:NetrwBrowse : sanity checks: {{{3
  if exists("s:netrw_skipbrowse")
   unlet s:netrw_skipbrowse
"   call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." filename<".expand("%")."> win#".winnr()." ft<".&ft.">",'~'.expand("<slnum>"))
"   call Dret("s:NetrwBrowse : s:netrw_skipbrowse existed")
   return
  endif
  if !exists("*shellescape")
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"netrw can't run -- your vim is missing shellescape()",69)
"   call Dret("s:NetrwBrowse : missing shellescape()")
   return
  endif
  if !exists("*fnameescape")
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"netrw can't run -- your vim is missing fnameescape()",70)
"   call Dret("s:NetrwBrowse : missing fnameescape()")
   return
  endif

  " s:NetrwBrowse : save options: {{{3
  call s:NetrwOptionsSave("w:")

  " s:NetrwBrowse : re-instate any marked files {{{3
  if has("syntax") && exists("g:syntax_on") && g:syntax_on
   if exists("s:netrwmarkfilelist_{bufnr('%')}")
"    call Decho("clearing marked files",'~'.expand("<slnum>"))
    exe "2match netrwMarkFile /".s:netrwmarkfilemtch_{bufnr("%")}."/"
   endif
  endif

  if a:islocal && exists("w:netrw_acdkeep") && w:netrw_acdkeep
   " s:NetrwBrowse : set up "safe" options for local directory/file {{{3
"   call Decho("handle w:netrw_acdkeep:",'~'.expand("<slnum>"))
"   call Decho("NetrwKeepj lcd ".fnameescape(dirname)." (due to w:netrw_acdkeep=".w:netrw_acdkeep." - acd=".&acd.")",'~'.expand("<slnum>"))
   if s:NetrwLcd(dirname)
"    call Dret("s:NetrwBrowse : lcd failure")
    return
   endif
   "   call s:NetrwOptionsSafe() " tst952 failed with this enabled.
"   call Decho("getcwd<".getcwd().">",'~'.expand("<slnum>"))

  elseif !a:islocal && dirname !~ '[\/]$' && dirname !~ '^"'
   " s:NetrwBrowse :  remote regular file handler {{{3
"   call Decho("handle remote regular file: dirname<".dirname.">",'~'.expand("<slnum>"))
   if bufname(dirname) != ""
"    call Decho("edit buf#".bufname(dirname)." in win#".winnr(),'~'.expand("<slnum>"))
    exe "NetrwKeepj b ".bufname(dirname)
   else
    " attempt transfer of remote regular file
"    call Decho("attempt transfer as regular file<".dirname.">",'~'.expand("<slnum>"))

    " remove any filetype indicator from end of dirname, except for the
    " "this is a directory" indicator (/).
    " There shouldn't be one of those here, anyway.
    let path= substitute(dirname,'[*=@|]\r\=$','','e')
"    call Decho("new path<".path.">",'~'.expand("<slnum>"))
    call s:RemotePathAnalysis(dirname)

    " s:NetrwBrowse : remote-read the requested file into current buffer {{{3
    call s:NetrwEnew(dirname)
    call s:NetrwOptionsSafe(a:islocal)
    setl ma noro
"    call Decho("setl ma noro",'~'.expand("<slnum>"))
    let b:netrw_curdir = dirname
    let url            = s:method."://".((s:user == "")? "" : s:user."@").s:machine.(s:port ? ":".s:port : "")."/".s:path
    call s:NetrwBufRename(url)
    exe "sil! NetrwKeepj keepalt doau BufReadPre ".fnameescape(s:fname)
    sil call netrw#NetRead(2,url)
    " netrw.vim and tar.vim have already handled decompression of the tarball; avoiding gzip.vim error
"    call Decho("url<".url.">",'~'.expand("<slnum>"))
"    call Decho("s:path<".s:path.">",'~'.expand("<slnum>"))
"    call Decho("s:fname<".s:fname.">",'~'.expand("<slnum>"))
    if s:path =~ '.bz2'
     exe "sil NetrwKeepj keepalt doau BufReadPost ".fnameescape(substitute(s:fname,'\.bz2$','',''))
    elseif s:path =~ '.gz'
     exe "sil NetrwKeepj keepalt doau BufReadPost ".fnameescape(substitute(s:fname,'\.gz$','',''))
    elseif s:path =~ '.gz'
     exe "sil NetrwKeepj keepalt doau BufReadPost ".fnameescape(substitute(s:fname,'\.txz$','',''))
    else
     exe "sil NetrwKeepj keepalt doau BufReadPost ".fnameescape(s:fname)
    endif
   endif

   " s:NetrwBrowse : save certain window-oriented variables into buffer-oriented variables {{{3
   call s:SetBufWinVars()
   call s:NetrwOptionsRestore("w:")
"   call Decho("setl ma nomod",'~'.expand("<slnum>"))
   setl ma nomod noro
"   call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))

"   call Dret("s:NetrwBrowse : file<".s:fname.">")
   return
  endif

  " use buffer-oriented WinVars if buffer variables exist but associated window variables don't {{{3
  call s:UseBufWinVars()

  " set up some variables {{{3
  let b:netrw_browser_active = 1
  let dirname                = dirname
  let s:last_sort_by         = g:netrw_sort_by

  " set up menu {{{3
  NetrwKeepj call s:NetrwMenu(1)

  " get/set-up buffer {{{3
"  call Decho("saving position across a buffer refresh",'~'.expand("<slnum>"))
  let svpos  = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let reusing= s:NetrwGetBuffer(a:islocal,dirname)

  " maintain markfile highlighting
  if has("syntax") && exists("g:syntax_on") && g:syntax_on
   if exists("s:netrwmarkfilemtch_{bufnr('%')}") && s:netrwmarkfilemtch_{bufnr("%")} != ""
" "   call Decho("bufnr(%)=".bufnr('%'),'~'.expand("<slnum>"))
" "   call Decho("exe 2match netrwMarkFile /".s:netrwmarkfilemtch_{bufnr("%")}."/",'~'.expand("<slnum>"))
    exe "2match netrwMarkFile /".s:netrwmarkfilemtch_{bufnr("%")}."/"
   else
" "   call Decho("2match none",'~'.expand("<slnum>"))
    2match none
   endif
  endif
  if reusing && line("$") > 1
   call s:NetrwOptionsRestore("w:")
"   call Decho("setl noma nomod nowrap",'~'.expand("<slnum>"))
   setl noma nomod nowrap
"   call Decho("(set noma nomod nowrap)  ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"   call Dret("s:NetrwBrowse : re-using not-cleared buffer")
   return
  endif

  " set b:netrw_curdir to the new directory name {{{3
"  call Decho("set b:netrw_curdir to the new directory name<".dirname."> (buf#".bufnr("%").")",'~'.expand("<slnum>"))
  let b:netrw_curdir= dirname
  if b:netrw_curdir =~ '[/\\]$'
   let b:netrw_curdir= substitute(b:netrw_curdir,'[/\\]$','','e')
  endif
  if b:netrw_curdir =~ '\a:$' && has("win32")
   let b:netrw_curdir= b:netrw_curdir."/"
  endif
  if b:netrw_curdir == ''
   if has("amiga")
    " On the Amiga, the empty string connotes the current directory
    let b:netrw_curdir= getcwd()
   else
    " under unix, when the root directory is encountered, the result
    " from the preceding substitute is an empty string.
    let b:netrw_curdir= '/'
   endif
  endif
  if !a:islocal && b:netrw_curdir !~ '/$'
   let b:netrw_curdir= b:netrw_curdir.'/'
  endif
"  call Decho("b:netrw_curdir<".b:netrw_curdir.">",'~'.expand("<slnum>"))

  " ------------
  " (local only) {{{3
  " ------------
  if a:islocal
"   call Decho("local only:",'~'.expand("<slnum>"))

   " Set up ShellCmdPost handling.  Append current buffer to browselist
   call s:LocalFastBrowser()

  " handle g:netrw_keepdir: set vim's current directory to netrw's notion of the current directory {{{3
   if !g:netrw_keepdir
"    call Decho("handle g:netrw_keepdir=".g:netrw_keepdir.": getcwd<".getcwd()."> acd=".&acd,'~'.expand("<slnum>"))
"    call Decho("l:acd".(exists("&l:acd")? "=".&l:acd : " doesn't exist"),'~'.expand("<slnum>"))
    if !exists("&l:acd") || !&l:acd
     if s:NetrwLcd(b:netrw_curdir)
"      call Dret("s:NetrwBrowse : lcd failure")
      return
     endif
    endif
   endif

  " --------------------------------
  " remote handling: {{{3
  " --------------------------------
  else
"   call Decho("remote only:",'~'.expand("<slnum>"))

   " analyze dirname and g:netrw_list_cmd {{{3
"   call Decho("b:netrw_curdir<".(exists("b:netrw_curdir")? b:netrw_curdir : "doesn't exist")."> dirname<".dirname.">",'~'.expand("<slnum>"))
   if dirname =~# "^NetrwTreeListing\>"
    let dirname= b:netrw_curdir
"    call Decho("(dirname was <NetrwTreeListing>) dirname<".dirname.">",'~'.expand("<slnum>"))
   elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("b:netrw_curdir")
    let dirname= substitute(b:netrw_curdir,'\\','/','g')
    if dirname !~ '/$'
     let dirname= dirname.'/'
    endif
    let b:netrw_curdir = dirname
"    call Decho("(liststyle is TREELIST) dirname<".dirname.">",'~'.expand("<slnum>"))
   else
    let dirname = substitute(dirname,'\\','/','g')
"    call Decho("(normal) dirname<".dirname.">",'~'.expand("<slnum>"))
   endif

   let dirpat  = '^\(\w\{-}\)://\(\w\+@\)\=\([^/]\+\)/\(.*\)$'
   if dirname !~ dirpat
    if !exists("g:netrw_quiet")
     NetrwKeepj call netrw#ErrorMsg(s:ERROR,"netrw doesn't understand your dirname<".dirname.">",20)
    endif
    NetrwKeepj call s:NetrwOptionsRestore("w:")
"    call Decho("setl noma nomod nowrap",'~'.expand("<slnum>"))
    setl noma nomod nowrap
"    call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"    call Dret("s:NetrwBrowse : badly formatted dirname<".dirname.">")
    return
   endif
   let b:netrw_curdir= dirname
"   call Decho("b:netrw_curdir<".b:netrw_curdir."> (remote)",'~'.expand("<slnum>"))
  endif  " (additional remote handling)

  " -------------------------------
  " Perform Directory Listing: {{{3
  " -------------------------------
  NetrwKeepj call s:NetrwMaps(a:islocal)
  NetrwKeepj call s:NetrwCommands(a:islocal)
  NetrwKeepj call s:PerformListing(a:islocal)

  " restore option(s)
  call s:NetrwOptionsRestore("w:")
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))

  " If there is a rexposn: restore position with rexposn
  " Otherwise            : set rexposn
  if exists("s:rexposn_".bufnr("%"))
"   call Decho("restoring posn to s:rexposn_".bufnr('%')."<".string(s:rexposn_{bufnr('%')}).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(s:rexposn_{bufnr('%')})
   if exists("w:netrw_bannercnt") && line(".") < w:netrw_bannercnt
    NetrwKeepj exe w:netrw_bannercnt
   endif
  else
   NetrwKeepj call s:SetRexDir(a:islocal,b:netrw_curdir)
  endif
  if v:version >= 700 && has("balloon_eval") && &beval == 0 && &l:bexpr == "" && !exists("g:netrw_nobeval")
   let &l:bexpr= "netrw#BalloonHelp()"
"   call Decho("set up balloon help: l:bexpr=".&l:bexpr,'~'.expand("<slnum>"))
   setl beval
  endif

  " repoint t:netrw_lexbufnr if appropriate
  if exists("repointlexbufnr")
   let t:netrw_lexbufnr= bufnr("%")
"   call Decho("repoint t:netrw_lexbufnr to #".t:netrw_lexbufnr)
  endif

  " restore position
  if reusing
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   call winrestview(svpos)
  endif

  " The s:LocalBrowseRefresh() function is called by an autocmd
  " installed by s:LocalFastBrowser() when g:netrw_fastbrowse <= 1 (ie. slow or medium speed).
  " However, s:NetrwBrowse() causes the FocusGained event to fire the first time.
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
"  call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"  call Dret("s:NetrwBrowse : did PerformListing  ft<".&ft.">")
  return
endfun

" ---------------------------------------------------------------------
" s:NetrwFile: because of g:netrw_keepdir, isdirectory(), type(), etc may or {{{2
" may not apply correctly; ie. netrw's idea of the current directory may
" differ from vim's.  This function insures that netrw's idea of the current
" directory is used.
" Returns a path to the file specified by a:fname
fun! s:NetrwFile(fname)
"  "" call Dfunc("s:NetrwFile(fname<".a:fname.">) win#".winnr())
"  "" call Decho("g:netrw_keepdir  =".(exists("g:netrw_keepdir")?   g:netrw_keepdir   : 'n/a'),'~'.expand("<slnum>"))
"  "" call Decho("g:netrw_cygwin   =".(exists("g:netrw_cygwin")?    g:netrw_cygwin    : 'n/a'),'~'.expand("<slnum>"))
"  "" call Decho("g:netrw_liststyle=".(exists("g:netrw_liststyle")? g:netrw_liststyle : 'n/a'),'~'.expand("<slnum>"))
"  "" call Decho("w:netrw_liststyle=".(exists("w:netrw_liststyle")? w:netrw_liststyle : 'n/a'),'~'.expand("<slnum>"))

  " clean up any leading treedepthstring
  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
   let fname= substitute(a:fname,'^'.s:treedepthstring.'\+','','')
"   "" call Decho("clean up any leading treedepthstring: fname<".fname.">",'~'.expand("<slnum>"))
  else
   let fname= a:fname
  endif

  if g:netrw_keepdir
   " vim's idea of the current directory possibly may differ from netrw's
   if !exists("b:netrw_curdir")
    let b:netrw_curdir= getcwd()
   endif

   if !exists("g:netrw_cygwin") && has("win32")
    if fname =~ '^\' || fname =~ '^\a:\'
     " windows, but full path given
     let ret= fname
"     "" call Decho("windows+full path: isdirectory(".fname.")",'~'.expand("<slnum>"))
    else
     " windows, relative path given
     let ret= s:ComposePath(b:netrw_curdir,fname)
"     "" call Decho("windows+rltv path: isdirectory(".fname.")",'~'.expand("<slnum>"))
    endif

   elseif fname =~ '^/'
    " not windows, full path given
    let ret= fname
"    "" call Decho("unix+full path: isdirectory(".fname.")",'~'.expand("<slnum>"))
   else
    " not windows, relative path given
    let ret= s:ComposePath(b:netrw_curdir,fname)
"    "" call Decho("unix+rltv path: isdirectory(".fname.")",'~'.expand("<slnum>"))
   endif
  else
   " vim and netrw agree on the current directory
   let ret= fname
"   "" call Decho("vim and netrw agree on current directory (g:netrw_keepdir=".g:netrw_keepdir.")",'~'.expand("<slnum>"))
"   "" call Decho("vim   directory: ".getcwd(),'~'.expand("<slnum>"))
"   "" call Decho("netrw directory: ".(exists("b:netrw_curdir")? b:netrw_curdir : 'n/a'),'~'.expand("<slnum>"))
  endif

"  "" call Dret("s:NetrwFile ".ret)
  return ret
endfun

" ---------------------------------------------------------------------
" s:NetrwFileInfo: supports qf (query for file information) {{{2
fun! s:NetrwFileInfo(islocal,fname)
"  call Dfunc("s:NetrwFileInfo(islocal=".a:islocal." fname<".a:fname.">) b:netrw_curdir<".b:netrw_curdir.">")
  let ykeep= @@
  if a:islocal
   let lsopt= "-lsad"
   if g:netrw_sizestyle =~# 'H'
    let lsopt= "-lsadh"
   elseif g:netrw_sizestyle =~# 'h'
    let lsopt= "-lsadh --si"
   endif
"   call Decho("(s:NetrwFileInfo) lsopt<".lsopt.">")
   if (has("unix") || has("macunix")) && executable("/bin/ls")

    if getline(".") == "../"
     echo system("/bin/ls ".lsopt." ".s:ShellEscape(".."))
"     call Decho("#1: echo system(/bin/ls -lsad ".s:ShellEscape(..).")",'~'.expand("<slnum>"))

    elseif w:netrw_liststyle == s:TREELIST && getline(".") !~ '^'.s:treedepthstring
     echo system("/bin/ls ".lsopt." ".s:ShellEscape(b:netrw_curdir))
"     call Decho("#2: echo system(/bin/ls -lsad ".s:ShellEscape(b:netrw_curdir).")",'~'.expand("<slnum>"))

    elseif exists("b:netrw_curdir")
      echo system("/bin/ls ".lsopt." ".s:ShellEscape(s:ComposePath(b:netrw_curdir,a:fname)))
"      call Decho("#3: echo system(/bin/ls -lsad ".s:ShellEscape(b:netrw_curdir.a:fname).")",'~'.expand("<slnum>"))

    else
"     call Decho('using ls '.a:fname." using cwd<".getcwd().">",'~'.expand("<slnum>"))
     echo system("/bin/ls ".lsopt." ".s:ShellEscape(s:NetrwFile(a:fname)))
"     call Decho("#5: echo system(/bin/ls -lsad ".s:ShellEscape(a:fname).")",'~'.expand("<slnum>"))
    endif
   else
    " use vim functions to return information about file below cursor
"    call Decho("using vim functions to query for file info",'~'.expand("<slnum>"))
    if !isdirectory(s:NetrwFile(a:fname)) && !filereadable(s:NetrwFile(a:fname)) && a:fname =~ '[*@/]'
     let fname= substitute(a:fname,".$","","")
    else
     let fname= a:fname
    endif
    let t  = getftime(s:NetrwFile(fname))
    let sz = getfsize(s:NetrwFile(fname))
    if g:netrw_sizestyle =~# "[hH]"
     let sz= s:NetrwHumanReadable(sz)
    endif
    echo a:fname.":  ".sz."  ".strftime(g:netrw_timefmt,getftime(s:NetrwFile(fname)))
"    call Decho("fname.":  ".sz."  ".strftime(g:netrw_timefmt,getftime(fname)),'~'.expand("<slnum>"))
   endif
  else
   echo "sorry, \"qf\" not supported yet for remote files"
  endif
  let @@= ykeep
"  call Dret("s:NetrwFileInfo")
endfun

" ---------------------------------------------------------------------
" s:NetrwFullPath: returns the full path to a directory and/or file {{{2
fun! s:NetrwFullPath(filename)
"  " call Dfunc("s:NetrwFullPath(filename<".a:filename.">)")
  let filename= a:filename
  if filename !~ '^/'
   let filename= resolve(getcwd().'/'.filename)
  endif
  if filename != "/" && filename =~ '/$'
   let filename= substitute(filename,'/$','','')
  endif
"  " call Dret("s:NetrwFullPath <".filename.">")
  return filename
endfun

" ---------------------------------------------------------------------
" s:NetrwGetBuffer: [get a new|find an old netrw] buffer for a netrw listing {{{2
"   returns 0=cleared buffer
"           1=re-used buffer (buffer not cleared)
"  Nov 09, 2020: tst952 shows that when user does :set hidden that NetrwGetBuffer will come up with a [No Name] buffer (hid fix)
fun! s:NetrwGetBuffer(islocal,dirname)
"  call Dfunc("s:NetrwGetBuffer(islocal=".a:islocal." dirname<".a:dirname.">) liststyle=".g:netrw_liststyle)
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo." hid=".&hid,'~'.expand("<slnum>"))
"  call Decho("netrwbuf dictionary=".(exists("s:netrwbuf")? string(s:netrwbuf) : 'n/a'),'~'.expand("<slnum>"))
"  call Dredir("ls!","s:NetrwGetBuffer")
  let dirname= a:dirname

  " re-use buffer if possible {{{3
"  call Decho("--re-use a buffer if possible--",'~'.expand("<slnum>"))
  if !exists("s:netrwbuf")
"   call Decho("  s:netrwbuf initialized to {}",'~'.expand("<slnum>"))
   let s:netrwbuf= {}
  endif
"  call Decho("  s:netrwbuf         =".string(s:netrwbuf),'~'.expand("<slnum>"))
"  call Decho("  w:netrw_liststyle  =".(exists("w:netrw_liststyle")? w:netrw_liststyle : "n/a"),'~'.expand("<slnum>"))

  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
   let bufnum = -1

   if !empty(s:netrwbuf) && has_key(s:netrwbuf,s:NetrwFullPath(dirname))
    if has_key(s:netrwbuf,"NetrwTreeListing")
     let bufnum= s:netrwbuf["NetrwTreeListing"]
    else
     let bufnum= s:netrwbuf[s:NetrwFullPath(dirname)]
    endif
"    call Decho("  NetrwTreeListing: bufnum#".bufnum,'~'.expand("<slnum>"))
    if !bufexists(bufnum)
     call remove(s:netrwbuf,"NetrwTreeListing"])
     let bufnum= -1
    endif
   elseif bufnr("NetrwTreeListing") != -1
    let bufnum= bufnr("NetrwTreeListing")
"    call Decho("  NetrwTreeListing".": bufnum#".bufnum,'~'.expand("<slnum>"))
   else
"    call Decho("  did not find a NetrwTreeListing buffer",'~'.expand("<slnum>"))
     let bufnum= -1
   endif

  elseif has_key(s:netrwbuf,s:NetrwFullPath(dirname))
   let bufnum= s:netrwbuf[s:NetrwFullPath(dirname)]
"   call Decho("  lookup netrwbuf dictionary: s:netrwbuf[".s:NetrwFullPath(dirname)."]=".bufnum,'~'.expand("<slnum>"))
   if !bufexists(bufnum)
    call remove(s:netrwbuf,s:NetrwFullPath(dirname))
    let bufnum= -1
   endif

  else
"   call Decho("  lookup netrwbuf dictionary: s:netrwbuf[".s:NetrwFullPath(dirname)."] not a key",'~'.expand("<slnum>"))
   let bufnum= -1
  endif
"  call Decho("  bufnum#".bufnum,'~'.expand("<slnum>"))

  " highjack the current buffer
  "   IF the buffer already has the desired name
  "   AND it is empty
  let curbuf = bufname("%")
  if curbuf == '.'
   let curbuf = getcwd()
  endif
"  call Dredir("ls!","NetrwGetFile (renamed buffer back to remote filename<".rfile."> : expand(%)<".expand("%").">)")
"  call Decho("deciding if netrw may highjack the current buffer#".bufnr("%")."<".curbuf.">",'~'.expand("<slnum>"))
"  call Decho("..dirname<".dirname.">  IF dirname == bufname",'~'.expand("<slnum>"))
"  call Decho("..curbuf<".curbuf.">",'~'.expand("<slnum>"))
"  call Decho("..line($)=".line("$")." AND this is 1",'~'.expand("<slnum>"))
"  call Decho("..getline(%)<".getline("%").">  AND this line is empty",'~'.expand("<slnum>"))
  if dirname == curbuf && line("$") == 1 && getline("%") == ""
"   call Dret("s:NetrwGetBuffer 0<cleared buffer> : highjacking buffer#".bufnr("%"))
   return 0
  else  " DEBUG
"   call Decho("..did NOT highjack buffer",'~'.expand("<slnum>"))
  endif
  " Aug 14, 2021: was thinking about looking for a [No Name] buffer here and using it, but that might cause problems

  " get enew buffer and name it -or- re-use buffer {{{3
  if bufnum < 0      " get enew buffer and name it
"   call Decho("--get enew buffer and name it  (bufnum#".bufnum."<0 OR bufexists(".bufnum.")=".bufexists(bufnum)."==0)",'~'.expand("<slnum>"))
   call s:NetrwEnew(dirname)
"   call Decho("  got enew buffer#".bufnr("%")." (altbuf<".expand("#").">)",'~'.expand("<slnum>"))
   " name the buffer
   if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
    " Got enew buffer; transform into a NetrwTreeListing
"    call Decho("--transform enew buffer#".bufnr("%")." into a NetrwTreeListing --",'~'.expand("<slnum>"))
    let w:netrw_treebufnr = bufnr("%")
    call s:NetrwBufRename("NetrwTreeListing")
    if g:netrw_use_noswf
     setl nobl bt=nofile noswf
    else
     setl nobl bt=nofile
    endif
    nnoremap <silent> <buffer> [[       :sil call <SID>TreeListMove('[[')<cr>
    nnoremap <silent> <buffer> ]]       :sil call <SID>TreeListMove(']]')<cr>
    nnoremap <silent> <buffer> []       :sil call <SID>TreeListMove('[]')<cr>
    nnoremap <silent> <buffer> ][       :sil call <SID>TreeListMove('][')<cr>
"    call Decho("  tree listing bufnr=".w:netrw_treebufnr,'~'.expand("<slnum>"))
   else
    call s:NetrwBufRename(dirname)
    " enter the new buffer into the s:netrwbuf dictionary
    let s:netrwbuf[s:NetrwFullPath(dirname)]= bufnr("%")
"    call Decho("update netrwbuf dictionary: s:netrwbuf[".s:NetrwFullPath(dirname)."]=".bufnr("%"),'~'.expand("<slnum>"))
"    call Decho("netrwbuf dictionary=".string(s:netrwbuf),'~'.expand("<slnum>"))
   endif
"   call Decho("  named enew buffer#".bufnr("%")."<".bufname("%").">",'~'.expand("<slnum>"))

  else " Re-use the buffer
"   call Decho("--re-use buffer#".bufnum." (bufnum#".bufnum.">=0 AND bufexists(".bufnum.")=".bufexists(bufnum)."!=0)",'~'.expand("<slnum>"))
   " ignore all events
   let eikeep= &ei
   setl ei=all

   if &ft == "netrw"
"    call Decho("buffer type is netrw; not using keepalt with b ".bufnum)
    exe "sil! NetrwKeepj noswapfile b ".bufnum
"    call Dredir("ls!","one")
   else
"    call Decho("buffer type is not netrw; using keepalt with b ".bufnum)
    call s:NetrwEditBuf(bufnum)
"    call Dredir("ls!","two")
   endif
"   call Decho("  line($)=".line("$"),'~'.expand("<slnum>"))
   if bufname("%") == '.'
    call s:NetrwBufRename(getcwd())
   endif

   " restore ei
   let &ei= eikeep

   if line("$") <= 1 && getline(1) == ""
    " empty buffer
    NetrwKeepj call s:NetrwListSettings(a:islocal)
"    call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
"    call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
"    call Dret("s:NetrwGetBuffer 0<buffer empty> : re-using buffer#".bufnr("%").", but its empty, so refresh it")
    return 0

   elseif g:netrw_fastbrowse == 0 || (a:islocal && g:netrw_fastbrowse == 1)
"    call Decho("g:netrw_fastbrowse=".g:netrw_fastbrowse." a:islocal=".a:islocal.": clear buffer",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwListSettings(a:islocal)
    sil NetrwKeepj %d _
"    call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
"    call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
"    call Dret("s:NetrwGetBuffer 0<cleared buffer> : re-using buffer#".bufnr("%").", but refreshing due to g:netrw_fastbrowse=".g:netrw_fastbrowse)
    return 0

   elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
"    call Decho("--re-use tree listing--",'~'.expand("<slnum>"))
"    call Decho("  clear buffer<".expand("%")."> with :%d",'~'.expand("<slnum>"))
    setl ma
    sil NetrwKeepj %d _
    NetrwKeepj call s:NetrwListSettings(a:islocal)
"    call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
"    call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
"    call Dret("s:NetrwGetBuffer 0<cleared buffer> : re-using buffer#".bufnr("%").", but treelist mode always needs a refresh")
    return 0

   else
"    call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
"    call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
"    call Dret("s:NetrwGetBuffer 1<buffer not cleared>")
    return 1
   endif
  endif

  " do netrw settings: make this buffer not-a-file, modifiable, not line-numbered, etc {{{3
  "     fastbrowse  Local  Remote   Hiding a buffer implies it may be re-used (fast)
  "  slow   0         D      D      Deleting a buffer implies it will not be re-used (slow)
  "  med    1         D      H
  "  fast   2         H      H
"  call Decho("--do netrw settings: make this buffer#".bufnr("%")." not-a-file, modifiable, not line-numbered, etc--",'~'.expand("<slnum>"))
  let fname= expand("%")
  NetrwKeepj call s:NetrwListSettings(a:islocal)
  call s:NetrwBufRename(fname)

  " delete all lines from buffer {{{3
"  call Decho("--delete all lines from buffer--",'~'.expand("<slnum>"))
"  call Decho("  clear buffer<".expand("%")."> with :%d",'~'.expand("<slnum>"))
  sil! keepalt NetrwKeepj %d _

"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
"  call Dret("s:NetrwGetBuffer 0<cleared buffer>")
  return 0
endfun

" ---------------------------------------------------------------------
" s:NetrwGetcwd: get the current directory. {{{2
"   Change backslashes to forward slashes, if any.
"   If doesc is true, escape certain troublesome characters
fun! s:NetrwGetcwd(doesc)
"  call Dfunc("NetrwGetcwd(doesc=".a:doesc.")")
  let curdir= substitute(getcwd(),'\\','/','ge')
  if curdir !~ '[\/]$'
   let curdir= curdir.'/'
  endif
  if a:doesc
   let curdir= fnameescape(curdir)
  endif
"  call Dret("NetrwGetcwd <".curdir.">")
  return curdir
endfun

" ---------------------------------------------------------------------
"  s:NetrwGetWord: it gets the directory/file named under the cursor {{{2
fun! s:NetrwGetWord()
"  call Dfunc("s:NetrwGetWord() liststyle=".s:ShowStyle()." virtcol=".virtcol("."))
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
  let keepsol= &l:sol
  setl nosol

  call s:UseBufWinVars()

  " insure that w:netrw_liststyle is set up
  if !exists("w:netrw_liststyle")
   if exists("g:netrw_liststyle")
    let w:netrw_liststyle= g:netrw_liststyle
   else
    let w:netrw_liststyle= s:THINLIST
   endif
"   call Decho("w:netrw_liststyle=".w:netrw_liststyle,'~'.expand("<slnum>"))
  endif

  if exists("w:netrw_bannercnt") && line(".") < w:netrw_bannercnt
   " Active Banner support
"   call Decho("active banner handling",'~'.expand("<slnum>"))
   NetrwKeepj norm! 0
   let dirname= "./"
   let curline= getline('.')

   if curline =~# '"\s*Sorted by\s'
    NetrwKeepj norm! "_s
    let s:netrw_skipbrowse= 1
    echo 'Pressing "s" also works'

   elseif curline =~# '"\s*Sort sequence:'
    let s:netrw_skipbrowse= 1
    echo 'Press "S" to edit sorting sequence'

   elseif curline =~# '"\s*Quick Help:'
    NetrwKeepj norm! ?
    let s:netrw_skipbrowse= 1

   elseif curline =~# '"\s*\%(Hiding\|Showing\):'
    NetrwKeepj norm! a
    let s:netrw_skipbrowse= 1
    echo 'Pressing "a" also works'

   elseif line("$") > w:netrw_bannercnt
    exe 'sil NetrwKeepj '.w:netrw_bannercnt
   endif

  elseif w:netrw_liststyle == s:THINLIST
"   call Decho("thin column handling",'~'.expand("<slnum>"))
   NetrwKeepj norm! 0
   let dirname= substitute(getline('.'),'\t -->.*$','','')

  elseif w:netrw_liststyle == s:LONGLIST
"   call Decho("long column handling",'~'.expand("<slnum>"))
   NetrwKeepj norm! 0
   let dirname= substitute(getline('.'),'^\(\%(\S\+ \)*\S\+\).\{-}$','\1','e')

  elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
"   call Decho("treelist handling",'~'.expand("<slnum>"))
   let dirname= substitute(getline('.'),'^\('.s:treedepthstring.'\)*','','e')
   let dirname= substitute(dirname,'\t -->.*$','','')

  else
"   call Decho("obtain word from wide listing",'~'.expand("<slnum>"))
   let dirname= getline('.')

   if !exists("b:netrw_cpf")
    let b:netrw_cpf= 0
    exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$g/^./if virtcol("$") > b:netrw_cpf|let b:netrw_cpf= virtcol("$")|endif'
    call histdel("/",-1)
"   "call Decho("computed cpf=".b:netrw_cpf,'~'.expand("<slnum>"))
   endif

"   call Decho("buf#".bufnr("%")."<".bufname("%").">",'~'.expand("<slnum>"))
   let filestart = (virtcol(".")/b:netrw_cpf)*b:netrw_cpf
"   call Decho("filestart= ([virtcol=".virtcol(".")."]/[b:netrw_cpf=".b:netrw_cpf."])*b:netrw_cpf=".filestart."  bannercnt=".w:netrw_bannercnt,'~'.expand("<slnum>"))
"   call Decho("1: dirname<".dirname.">",'~'.expand("<slnum>"))
   if filestart == 0
    NetrwKeepj norm! 0ma
   else
    call cursor(line("."),filestart+1)
    NetrwKeepj norm! ma
   endif

   let dict={}
   " save the unnamed register and register 0-9 and a
   let dict.a=[getreg('a'), getregtype('a')]
   for i in range(0, 9)
     let dict[i] = [getreg(i), getregtype(i)]
   endfor
   let dict.unnamed = [getreg(''), getregtype('')]

   let eofname= filestart + b:netrw_cpf + 1
   if eofname <= col("$")
    call cursor(line("."),filestart+b:netrw_cpf+1)
    NetrwKeepj norm! "ay`a
   else
    NetrwKeepj norm! "ay$
   endif

   let dirname = @a
   call s:RestoreRegister(dict)

"   call Decho("2: dirname<".dirname.">",'~'.expand("<slnum>"))
   let dirname= substitute(dirname,'\s\+$','','e')
"   call Decho("3: dirname<".dirname.">",'~'.expand("<slnum>"))
  endif

  " symlinks are indicated by a trailing "@".  Remove it before further processing.
  let dirname= substitute(dirname,"@$","","")

  " executables are indicated by a trailing "*".  Remove it before further processing.
  let dirname= substitute(dirname,"\*$","","")

  let &l:sol= keepsol

"  call Dret("s:NetrwGetWord <".dirname.">")
  return dirname
endfun

" ---------------------------------------------------------------------
" s:NetrwListSettings: make standard settings for making a netrw listing {{{2
"                      g:netrw_bufsettings will be used after the listing is produced.
"                      Called by s:NetrwGetBuffer()
fun! s:NetrwListSettings(islocal)
"  call Dfunc("s:NetrwListSettings(islocal=".a:islocal.")")
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
  let fname= bufname("%")
"  "  call Decho("setl bt=nofile nobl ma nonu nowrap noro nornu",'~'.expand("<slnum>"))
  "              nobl noma nomod nonu noma nowrap ro   nornu  (std g:netrw_bufsettings)
  setl bt=nofile nobl ma         nonu      nowrap noro nornu
  call s:NetrwBufRename(fname)
  if g:netrw_use_noswf
   setl noswf
  endif
"  call Dredir("ls!","s:NetrwListSettings")
"  call Decho("exe setl ts=".(g:netrw_maxfilenamelen+1),'~'.expand("<slnum>"))
  exe "setl ts=".(g:netrw_maxfilenamelen+1)
  setl isk+=.,~,-
  if g:netrw_fastbrowse > a:islocal
   setl bh=hide
  else
   setl bh=delete
  endif
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
"  call Dret("s:NetrwListSettings")
endfun

" ---------------------------------------------------------------------
"  s:NetrwListStyle: change list style (thin - long - wide - tree) {{{2
"  islocal=0: remote browsing
"         =1: local browsing
fun! s:NetrwListStyle(islocal)
"  call Dfunc("NetrwListStyle(islocal=".a:islocal.") w:netrw_liststyle=".w:netrw_liststyle)

  let ykeep             = @@
  let fname             = s:NetrwGetWord()
  if !exists("w:netrw_liststyle")|let w:netrw_liststyle= g:netrw_liststyle|endif
  let svpos            = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let w:netrw_liststyle = (w:netrw_liststyle + 1) % s:MAXLIST
"  call Decho("fname<".fname.">",'~'.expand("<slnum>"))
"  call Decho("chgd w:netrw_liststyle to ".w:netrw_liststyle,'~'.expand("<slnum>"))
"  call Decho("b:netrw_curdir<".(exists("b:netrw_curdir")? b:netrw_curdir : "doesn't exist").">",'~'.expand("<slnum>"))

  " repoint t:netrw_lexbufnr if appropriate
  if exists("t:netrw_lexbufnr") && bufnr("%") == t:netrw_lexbufnr
"   call Decho("set repointlexbufnr to true!")
   let repointlexbufnr= 1
  endif

  if w:netrw_liststyle == s:THINLIST
   " use one column listing
"   call Decho("use one column list",'~'.expand("<slnum>"))
   let g:netrw_list_cmd = substitute(g:netrw_list_cmd,' -l','','ge')

  elseif w:netrw_liststyle == s:LONGLIST
   " use long list
"   call Decho("use long list",'~'.expand("<slnum>"))
   let g:netrw_list_cmd = g:netrw_list_cmd." -l"

  elseif w:netrw_liststyle == s:WIDELIST
   " give wide list
"   call Decho("use wide list",'~'.expand("<slnum>"))
   let g:netrw_list_cmd = substitute(g:netrw_list_cmd,' -l','','ge')

  elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
"   call Decho("use tree list",'~'.expand("<slnum>"))
   let g:netrw_list_cmd = substitute(g:netrw_list_cmd,' -l','','ge')

  else
   NetrwKeepj call netrw#ErrorMsg(s:WARNING,"bad value for g:netrw_liststyle (=".w:netrw_liststyle.")",46)
   let g:netrw_liststyle = s:THINLIST
   let w:netrw_liststyle = g:netrw_liststyle
   let g:netrw_list_cmd  = substitute(g:netrw_list_cmd,' -l','','ge')
  endif
  setl ma noro
"  call Decho("setl ma noro",'~'.expand("<slnum>"))

  " clear buffer - this will cause NetrwBrowse/LocalBrowseCheck to do a refresh
"  call Decho("clear buffer<".expand("%")."> with :%d",'~'.expand("<slnum>"))
  sil! NetrwKeepj %d _
  " following prevents tree listing buffer from being marked "modified"
"  call Decho("setl nomod",'~'.expand("<slnum>"))
  setl nomod
"  call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))

  " refresh the listing
"  call Decho("refresh the listing",'~'.expand("<slnum>"))
  NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
  NetrwKeepj call s:NetrwCursor(0)

  " repoint t:netrw_lexbufnr if appropriate
  if exists("repointlexbufnr")
   let t:netrw_lexbufnr= bufnr("%")
"   call Decho("repoint t:netrw_lexbufnr to #".t:netrw_lexbufnr)
  endif

  " restore position; keep cursor on the filename
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)
  let @@= ykeep

"  call Dret("NetrwListStyle".(exists("w:netrw_liststyle")? ' : w:netrw_liststyle='.w:netrw_liststyle : ""))
endfun

" ---------------------------------------------------------------------
" s:NetrwBannerCtrl: toggles the display of the banner {{{2
fun! s:NetrwBannerCtrl(islocal)
"  call Dfunc("s:NetrwBannerCtrl(islocal=".a:islocal.") g:netrw_banner=".g:netrw_banner)

  let ykeep= @@
  " toggle the banner (enable/suppress)
  let g:netrw_banner= !g:netrw_banner

  " refresh the listing
  let svpos= winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))

  " keep cursor on the filename
  if g:netrw_banner && exists("w:netrw_bannercnt") && line(".") >= w:netrw_bannercnt
   let fname= s:NetrwGetWord()
   sil NetrwKeepj $
   let result= search('\%(^\%(|\+\s\)\=\|\s\{2,}\)\zs'.escape(fname,'.\[]*$^').'\%(\s\{2,}\|$\)','bc')
" "  call Decho("search result=".result." w:netrw_bannercnt=".(exists("w:netrw_bannercnt")? w:netrw_bannercnt : 'N/A'),'~'.expand("<slnum>"))
   if result <= 0 && exists("w:netrw_bannercnt")
    exe "NetrwKeepj ".w:netrw_bannercnt
   endif
  endif
  let @@= ykeep
"  call Dret("s:NetrwBannerCtrl : g:netrw_banner=".g:netrw_banner)
endfun

" ---------------------------------------------------------------------
" s:NetrwBookmark: supports :NetrwMB[!] [file]s                 {{{2
"
"  No bang: enters files/directories into Netrw's bookmark system
"   No argument and in netrw buffer:
"     if there are marked files: bookmark marked files
"     otherwise                : bookmark file/directory under cursor
"   No argument and not in netrw buffer: bookmarks current open file
"   Has arguments: globs them individually and bookmarks them
"
"  With bang: deletes files/directories from Netrw's bookmark system
fun! s:NetrwBookmark(del,...)
"  call Dfunc("s:NetrwBookmark(del=".a:del.",...) a:0=".a:0)
  if a:0 == 0
   if &ft == "netrw"
    let curbufnr = bufnr("%")

    if exists("s:netrwmarkfilelist_{curbufnr}")
     " for every filename in the marked list
"     call Decho("bookmark every filename in marked list",'~'.expand("<slnum>"))
     let svpos  = winsaveview()
"     call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
     let islocal= expand("%") !~ '^\a\{3,}://'
     for fname in s:netrwmarkfilelist_{curbufnr}
      if a:del|call s:DeleteBookmark(fname)|else|call s:MakeBookmark(fname)|endif
     endfor
     let curdir  = exists("b:netrw_curdir")? b:netrw_curdir : getcwd()
     call s:NetrwUnmarkList(curbufnr,curdir)
     NetrwKeepj call s:NetrwRefresh(islocal,s:NetrwBrowseChgDir(islocal,'./'))
"     call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
     NetrwKeepj call winrestview(svpos)
    else
     let fname= s:NetrwGetWord()
     if a:del|call s:DeleteBookmark(fname)|else|call s:MakeBookmark(fname)|endif
    endif

   else
    " bookmark currently open file
"    call Decho("bookmark currently open file",'~'.expand("<slnum>"))
    let fname= expand("%")
    if a:del|call s:DeleteBookmark(fname)|else|call s:MakeBookmark(fname)|endif
   endif

  else
   " bookmark specified files
   "  attempts to infer if working remote or local
   "  by deciding if the current file begins with an url
   "  Globbing cannot be done remotely.
   let islocal= expand("%") !~ '^\a\{3,}://'
"   call Decho("bookmark specified file".((a:0>1)? "s" : ""),'~'.expand("<slnum>"))
   let i = 1
   while i <= a:0
    if islocal
     if v:version > 704 || (v:version == 704 && has("patch656"))
      let mbfiles= glob(fnameescape(a:{i}),0,1,1)
     else
      let mbfiles= glob(fnameescape(a:{i}),0,1)
     endif
    else
     let mbfiles= [a:{i}]
    endif
"    call Decho("mbfiles".string(mbfiles),'~'.expand("<slnum>"))
    for mbfile in mbfiles
"     call Decho("mbfile<".mbfile.">",'~'.expand("<slnum>"))
     if a:del|call s:DeleteBookmark(mbfile)|else|call s:MakeBookmark(mbfile)|endif
    endfor
    let i= i + 1
   endwhile
  endif

  " update the menu
  call s:NetrwBookmarkMenu()

"  call Dret("s:NetrwBookmark")
endfun

" ---------------------------------------------------------------------
" s:NetrwBookmarkMenu: Uses menu priorities {{{2
"                      .2.[cnt] for bookmarks, and
"                      .3.[cnt] for history
"                      (see s:NetrwMenu())
fun! s:NetrwBookmarkMenu()
  if !exists("s:netrw_menucnt")
   return
  endif
"  call Dfunc("NetrwBookmarkMenu()  histcnt=".g:netrw_dirhistcnt." menucnt=".s:netrw_menucnt)

  " the following test assures that gvim is running, has menus available, and has menus enabled.
  if has("gui") && has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu
   if exists("g:NetrwTopLvlMenu")
"    call Decho("removing ".g:NetrwTopLvlMenu."Bookmarks menu item(s)",'~'.expand("<slnum>"))
    exe 'sil! unmenu '.g:NetrwTopLvlMenu.'Bookmarks'
    exe 'sil! unmenu '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History.Bookmark\ Delete'
   endif
   if !exists("s:netrw_initbookhist")
    call s:NetrwBookHistRead()
   endif

   " show bookmarked places
   if exists("g:netrw_bookmarklist") && g:netrw_bookmarklist != [] && g:netrw_dirhistmax > 0
    let cnt= 1
    for bmd in g:netrw_bookmarklist
"     call Decho('sil! menu '.g:NetrwMenuPriority.".2.".cnt." ".g:NetrwTopLvlMenu.'Bookmark.'.bmd.'	:e '.bmd,'~'.expand("<slnum>"))
     let bmd= escape(bmd,g:netrw_menu_escape)

     " show bookmarks for goto menu
     exe 'sil! menu '.g:NetrwMenuPriority.".2.".cnt." ".g:NetrwTopLvlMenu.'Bookmarks.'.bmd.'	:e '.bmd."\<cr>"

     " show bookmarks for deletion menu
     exe 'sil! menu '.g:NetrwMenuPriority.".8.2.".cnt." ".g:NetrwTopLvlMenu.'Bookmarks\ and\ History.Bookmark\ Delete.'.bmd.'	'.cnt."mB"
     let cnt= cnt + 1
    endfor

   endif

   " show directory browsing history
   if g:netrw_dirhistmax > 0
    let cnt     = g:netrw_dirhistcnt
    let first   = 1
    let histcnt = 0
    while ( first || cnt != g:netrw_dirhistcnt )
     let histcnt  = histcnt + 1
     let priority = g:netrw_dirhistcnt + histcnt
     if exists("g:netrw_dirhist_{cnt}")
      let histdir= escape(g:netrw_dirhist_{cnt},g:netrw_menu_escape)
"     call Decho('sil! menu '.g:NetrwMenuPriority.".3.".priority." ".g:NetrwTopLvlMenu.'History.'.histdir.'	:e '.histdir,'~'.expand("<slnum>"))
      exe 'sil! menu '.g:NetrwMenuPriority.".3.".priority." ".g:NetrwTopLvlMenu.'History.'.histdir.'	:e '.histdir."\<cr>"
     endif
     let first = 0
     let cnt   = ( cnt - 1 ) % g:netrw_dirhistmax
     if cnt < 0
      let cnt= cnt + g:netrw_dirhistmax
     endif
    endwhile
   endif

  endif
"  call Dret("NetrwBookmarkMenu")
endfun

" ---------------------------------------------------------------------
"  s:NetrwBrowseChgDir: constructs a new directory based on the current {{{2
"                       directory and a new directory name.  Also, if the
"                       "new directory name" is actually a file,
"                       NetrwBrowseChgDir() edits the file.
fun! s:NetrwBrowseChgDir(islocal,newdir,...)
"  call Dfunc("s:NetrwBrowseChgDir(islocal=".a:islocal."> newdir<".a:newdir.">) a:0=".a:0." win#".winnr()." curpos<".string(getpos("."))."> b:netrw_curdir<".(exists("b:netrw_curdir")? b:netrw_curdir : "").">")
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))

  let ykeep= @@
  if !exists("b:netrw_curdir")
   " Don't try to change-directory: this can happen, for example, when netrw#ErrorMsg has been called
   " and the current window is the NetrwMessage window.
   let @@= ykeep
"   call Decho("b:netrw_curdir doesn't exist!",'~'.expand("<slnum>"))
"   call Decho("getcwd<".getcwd().">",'~'.expand("<slnum>"))
"   call Dredir("ls!","s:NetrwBrowseChgDir")
"   call Dret("s:NetrwBrowseChgDir")
   return
  endif
"  call Decho("b:netrw_curdir<".b:netrw_curdir.">")

  " NetrwBrowseChgDir; save options and initialize {{{3
"  call Decho("saving options",'~'.expand("<slnum>"))
  call s:SavePosn(s:netrw_posn)
  NetrwKeepj call s:NetrwOptionsSave("s:")
  NetrwKeepj call s:NetrwOptionsSafe(a:islocal)
  if has("win32")
   let dirname = substitute(b:netrw_curdir,'\\','/','ge')
  else
   let dirname = b:netrw_curdir
  endif
  let newdir    = a:newdir
  let dolockout = 0
  let dorestore = 1
"  call Decho("win#".winnr(),'~'.expand("<slnum>"))
"  call Decho("dirname<".dirname.">",'~'.expand("<slnum>"))
"  call Decho("newdir<".newdir.">",'~'.expand("<slnum>"))

  " ignore <cr>s when done in the banner
"  call Decho('(s:NetrwBrowseChgDir) ignore [return]s when done in banner (g:netrw_banner='.g:netrw_banner.")",'~'.expand("<slnum>"))
  if g:netrw_banner
"   call Decho("win#".winnr()." w:netrw_bannercnt=".(exists("w:netrw_bannercnt")? w:netrw_bannercnt : 'n/a')." line(.)#".line('.')." line($)#".line("#"),'~'.expand("<slnum>"))
   if exists("w:netrw_bannercnt") && line(".") < w:netrw_bannercnt && line("$") >= w:netrw_bannercnt
    if getline(".") =~# 'Quick Help'
"     call Decho("#1: quickhelp=".g:netrw_quickhelp." ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
     let g:netrw_quickhelp= (g:netrw_quickhelp + 1)%len(s:QuickHelp)
"     call Decho("#2: quickhelp=".g:netrw_quickhelp." ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
     setl ma noro nowrap
     NetrwKeepj call setline(line('.'),'"   Quick Help: <F1>:help  '.s:QuickHelp[g:netrw_quickhelp])
     setl noma nomod nowrap
     NetrwKeepj call s:NetrwOptionsRestore("s:")
"     call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
    endif
   endif
"  else " Decho
"   call Decho("g:netrw_banner=".g:netrw_banner." (no banner)",'~'.expand("<slnum>"))
  endif

  " set up o/s-dependent directory recognition pattern
  if has("amiga")
   let dirpat= '[\/:]$'
  else
   let dirpat= '[\/]$'
  endif
"  call Decho("set up o/s-dependent directory recognition pattern: dirname<".dirname.">  dirpat<".dirpat.">",'~'.expand("<slnum>"))

  if dirname !~ dirpat
   " apparently vim is "recognizing" that it is in a directory and
   " is removing the trailing "/".  Bad idea, so let's put it back.
   let dirname= dirname.'/'
"   call Decho("adjusting dirname<".dirname.'>  (put trailing "/" back)','~'.expand("<slnum>"))
  endif

"  call Decho("[newdir<".newdir."> ".((newdir =~ dirpat)? "=~" : "!~")." dirpat<".dirpat.">] && [islocal=".a:islocal."] && [newdir is ".(isdirectory(s:NetrwFile(newdir))? "" : "not ")."a directory]",'~'.expand("<slnum>"))
  if newdir !~ dirpat && !(a:islocal && isdirectory(s:NetrwFile(s:ComposePath(dirname,newdir))))
   " ------------------------------
   " NetrwBrowseChgDir: edit a file {{{3
   " ------------------------------
"   call Decho('edit-a-file: case "handling a file": win#'.winnr().' newdir<'.newdir.'> !~ dirpat<'.dirpat.">",'~'.expand("<slnum>"))

   " save position for benefit of Rexplore
   let s:rexposn_{bufnr("%")}= winsaveview()
"   call Decho("edit-a-file: saving posn to s:rexposn_".bufnr("%")."<".string(s:rexposn_{bufnr("%")}).">",'~'.expand("<slnum>"))
"   call Decho("edit-a-file: win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> ft=".&ft,'~'.expand("<slnum>"))
"   call Decho("edit-a-file: w:netrw_liststyle=".(exists("w:netrw_liststyle")? w:netrw_liststyle : 'n/a')." w:netrw_treedict:".(exists("w:netrw_treedict")? "exists" : 'n/a')." newdir<".newdir.">",'~'.expand("<slnum>"))

   if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict") && newdir !~ '^\(/\|\a:\)'
"    call Decho("edit-a-file: handle tree listing: w:netrw_treedict<".(exists("w:netrw_treedict")? string(w:netrw_treedict) : 'n/a').">",'~'.expand("<slnum>"))
"    call Decho("edit-a-file: newdir<".newdir.">",'~'.expand("<slnum>"))
"    let newdir = s:NetrwTreePath(s:netrw_treetop)
"    call Decho("edit-a-file: COMBAK why doesn't this recognize file1's directory???")
    let dirname= s:NetrwTreeDir(a:islocal)
    "COMBAK : not working for a symlink -- but what about a regular file? a directory?
"    call Decho("COMBAK : not working for a symlink -- but what about a regular file? a directory?")
    " Feb 17, 2019: following if-else-endif restored -- wasn't editing a file in tree mode
    if dirname =~ '/$'
     let dirname= dirname.newdir
    else
     let dirname= dirname."/".newdir
    endif
"    call Decho("edit-a-file: dirname<".dirname.">",'~'.expand("<slnum>"))
"    call Decho("edit-a-file: tree listing",'~'.expand("<slnum>"))
   elseif newdir =~ '^\(/\|\a:\)'
"    call Decho("edit-a-file: handle an url or path starting with /: <".newdir.">",'~'.expand("<slnum>"))
    let dirname= newdir
   else
    let dirname= s:ComposePath(dirname,newdir)
   endif
"   call Decho("edit-a-file: handling a file: dirname<".dirname."> (a:0=".a:0.")",'~'.expand("<slnum>"))
   " this lets netrw#BrowseX avoid the edit
   if a:0 < 1
"    call Decho("edit-a-file: (a:0=".a:0."<1) set up windows for editing<".fnameescape(dirname).">  didsplit=".(exists("s:didsplit")? s:didsplit : "doesn't exist"),'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwOptionsRestore("s:")
    let curdir= b:netrw_curdir
    if !exists("s:didsplit")
"     "     call Decho("edit-a-file: s:didsplit does not exist; g:netrw_browse_split=".string(g:netrw_browse_split)." win#".winnr()." g:netrw_chgwin=".g:netrw_chgwin",'~'.expand("<slnum>"))
     if type(g:netrw_browse_split) == 3
      " open file in server
      " Note that g:netrw_browse_split is a List: [servername,tabnr,winnr]
"      call Decho("edit-a-file: open file in server",'~'.expand("<slnum>"))
      call s:NetrwServerEdit(a:islocal,dirname)
"      call Dret("s:NetrwBrowseChgDir")
      return

     elseif g:netrw_browse_split == 1
      " horizontally splitting the window first
"      call Decho("edit-a-file: horizontally splitting window prior to edit",'~'.expand("<slnum>"))
      let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
      exe "keepalt ".(g:netrw_alto? "bel " : "abo ").winsz."wincmd s"
      if !&ea
       keepalt wincmd _
      endif
      call s:SetRexDir(a:islocal,curdir)

     elseif g:netrw_browse_split == 2
      " vertically splitting the window first
"      call Decho("edit-a-file: vertically splitting window prior to edit",'~'.expand("<slnum>"))
      let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize
      exe "keepalt ".(g:netrw_alto? "top " : "bot ")."vert ".winsz."wincmd s"
      if !&ea
       keepalt wincmd |
      endif
      call s:SetRexDir(a:islocal,curdir)

     elseif g:netrw_browse_split == 3
      " open file in new tab
"      call Decho("edit-a-file: opening new tab prior to edit",'~'.expand("<slnum>"))
      keepalt tabnew
      if !exists("b:netrw_curdir")
       let b:netrw_curdir= getcwd()
      endif
      call s:SetRexDir(a:islocal,curdir)

     elseif g:netrw_browse_split == 4
      " act like "P" (ie. open previous window)
"      call Decho("edit-a-file: use previous window for edit",'~'.expand("<slnum>"))
      if s:NetrwPrevWinOpen(2) == 3
       let @@= ykeep
"       call Dret("s:NetrwBrowseChgDir")
       return
      endif
      call s:SetRexDir(a:islocal,curdir)

     else
      " handling a file, didn't split, so remove menu
"      call Decho("edit-a-file: handling a file+didn't split, so remove menu",'~'.expand("<slnum>"))
      call s:NetrwMenu(0)
      " optional change to window
      if g:netrw_chgwin >= 1
"       call Decho("edit-a-file: changing window to #".g:netrw_chgwin.": (due to g:netrw_chgwin)",'~'.expand("<slnum>"))
       if winnr("$")+1 == g:netrw_chgwin
       " if g:netrw_chgwin is set to one more than the last window, then
       " vertically split the last window to make that window available.
       let curwin= winnr()
       exe "NetrwKeepj keepalt ".winnr("$")."wincmd w"
       vs
       exe "NetrwKeepj keepalt ".g:netrw_chgwin."wincmd ".curwin
       endif
       exe "NetrwKeepj keepalt ".g:netrw_chgwin."wincmd w"
      endif
      call s:SetRexDir(a:islocal,curdir)
     endif

    endif

    " the point where netrw actually edits the (local) file
    " if its local only: LocalBrowseCheck() doesn't edit a file, but NetrwBrowse() will
    " use keepalt to support  :e #  to return to a directory listing
    if !&mod
     " if e the new file would fail due to &mod, then don't change any of the flags
     let dolockout= 1
    endif
    if a:islocal
"     call Decho("edit-a-file: edit local file: exe e! ".fnameescape(dirname),'~'.expand("<slnum>"))
     " some like c-^ to return to the last edited file
     " others like c-^ to return to the netrw buffer
     " Apr 30, 2020: used to have e! here.  That can cause loss of a modified file,
     " so emit error E37 instead.
     call s:NetrwEditFile("e","",dirname)
"     call Decho("edit-a-file: after e ".dirname.": hidden=".&hidden." bufhidden<".&bufhidden."> mod=".&mod,'~'.expand("<slnum>"))
     " COMBAK -- cuc cul related
     call s:NetrwCursor(1)
     if &hidden || &bufhidden == "hide"
      " file came from vim's hidden storage.  Don't "restore" options with it.
      let dorestore= 0
     endif
    else
"     call Decho("edit-a-file: remote file: NetrwBrowse will edit it",'~'.expand("<slnum>"))
    endif

    " handle g:Netrw_funcref -- call external-to-netrw functions
    "   This code will handle g:Netrw_funcref as an individual function reference
    "   or as a list of function references.  It will ignore anything that's not
    "   a function reference.  See  :help Funcref  for information about function references.
    if exists("g:Netrw_funcref")
"     call Decho("edit-a-file: handle optional Funcrefs",'~'.expand("<slnum>"))
     if type(g:Netrw_funcref) == 2
"      call Decho("edit-a-file: handling a g:Netrw_funcref",'~'.expand("<slnum>"))
      NetrwKeepj call g:Netrw_funcref()
     elseif type(g:Netrw_funcref) == 3
"      call Decho("edit-a-file: handling a list of g:Netrw_funcrefs",'~'.expand("<slnum>"))
      for Fncref in g:Netrw_funcref
       if type(Fncref) == 2
        NetrwKeepj call Fncref()
       endif
      endfor
     endif
    endif
   endif

  elseif newdir =~ '^/'
   " ----------------------------------------------------
   " NetrwBrowseChgDir: just go to the new directory spec {{{3
   " ----------------------------------------------------
"   call Decho('goto-newdir: case "just go to new directory spec": newdir<'.newdir.'>','~'.expand("<slnum>"))
   let dirname = newdir
   NetrwKeepj call s:SetRexDir(a:islocal,dirname)
   NetrwKeepj call s:NetrwOptionsRestore("s:")
   norm! m`

  elseif newdir == './'
   " ---------------------------------------------
   " NetrwBrowseChgDir: refresh the directory list {{{3
   " ---------------------------------------------
"   call Decho('(s:NetrwBrowseChgDir)refresh-dirlist: case "refresh directory listing": newdir == "./"','~'.expand("<slnum>"))
   NetrwKeepj call s:SetRexDir(a:islocal,dirname)
   norm! m`

  elseif newdir == '../'
   " --------------------------------------
   " NetrwBrowseChgDir: go up one directory {{{3
   " --------------------------------------
"   call Decho('(s:NetrwBrowseChgDir)go-up: case "go up one directory": newdir == "../"','~'.expand("<slnum>"))

   if w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
    " force a refresh
"    call Decho("go-up: clear buffer<".expand("%")."> with :%d",'~'.expand("<slnum>"))
"    call Decho("go-up: setl noro ma",'~'.expand("<slnum>"))
    setl noro ma
    NetrwKeepj %d _
   endif

   if has("amiga")
    " amiga
"    call Decho('go-up: case "go up one directory": newdir == "../" and amiga','~'.expand("<slnum>"))
    if a:islocal
     let dirname= substitute(dirname,'^\(.*[/:]\)\([^/]\+$\)','\1','')
     let dirname= substitute(dirname,'/$','','')
    else
     let dirname= substitute(dirname,'^\(.*[/:]\)\([^/]\+/$\)','\1','')
    endif
"    call Decho("go-up: amiga: dirname<".dirname."> (go up one dir)",'~'.expand("<slnum>"))

   elseif !g:netrw_cygwin && has("win32")
    " windows
    if a:islocal
     let dirname= substitute(dirname,'^\(.*\)/\([^/]\+\)/$','\1','')
     if dirname == ""
      let dirname= '/'
     endif
    else
     let dirname= substitute(dirname,'^\(\a\{3,}://.\{-}/\{1,2}\)\(.\{-}\)\([^/]\+\)/$','\1\2','')
    endif
    if dirname =~ '^\a:$'
     let dirname= dirname.'/'
    endif
"    call Decho("go-up: windows: dirname<".dirname."> (go up one dir)",'~'.expand("<slnum>"))

   else
    " unix or cygwin
"    call Decho('(s:NetrwBrowseChgDir)go-up: case "go up one directory": newdir == "../" and unix or cygwin','~'.expand("<slnum>"))
    if a:islocal
     let dirname= substitute(dirname,'^\(.*\)/\([^/]\+\)/$','\1','')
     if dirname == ""
      let dirname= '/'
     endif
    else
     let dirname= substitute(dirname,'^\(\a\{3,}://.\{-}/\{1,2}\)\(.\{-}\)\([^/]\+\)/$','\1\2','')
    endif
"    call Decho("go-up: unix: dirname<".dirname."> (go up one dir)",'~'.expand("<slnum>"))
   endif
   NetrwKeepj call s:SetRexDir(a:islocal,dirname)
   norm! m`

  elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
   " --------------------------------------
   " NetrwBrowseChgDir: Handle Tree Listing {{{3
   " --------------------------------------
"   call Decho('(s:NetrwBrowseChgDir)tree-list: case liststyle is TREELIST and w:netrw_treedict exists','~'.expand("<slnum>"))
   " force a refresh (for TREELIST, NetrwTreeDir() will force the refresh)
"   call Decho("tree-list: setl noro ma",'~'.expand("<slnum>"))
   setl noro ma
   if !(exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("b:netrw_curdir"))
"    call Decho("tree-list: clear buffer<".expand("%")."> with :%d  (force refresh)",'~'.expand("<slnum>"))
    NetrwKeepj %d _
   endif
   let treedir      = s:NetrwTreeDir(a:islocal)
"   call Decho("tree-list: treedir<".treedir.">",'~'.expand("<slnum>"))
   let s:treecurpos = winsaveview()
   let haskey       = 0
"   call Decho("tree-list: w:netrw_treedict<".string(w:netrw_treedict).">",'~'.expand("<slnum>"))

   " search treedict for tree dir as-is
"   call Decho("tree-list: search treedict for tree dir as-is",'~'.expand("<slnum>"))
   if has_key(w:netrw_treedict,treedir)
"    call Decho('(s:NetrwBrowseChgDir)tree-list: ....searched for treedir<'.treedir.'> : found it!','~'.expand("<slnum>"))
    let haskey= 1
   else
"    call Decho('(s:NetrwBrowseChgDir)tree-list: ....searched for treedir<'.treedir.'> : not found','~'.expand("<slnum>"))
   endif

   " search treedict for treedir with a [/@] appended
"   call Decho("tree-list: search treedict for treedir with a [/@] appended",'~'.expand("<slnum>"))
   if !haskey && treedir !~ '[/@]$'
    if has_key(w:netrw_treedict,treedir."/")
     let treedir= treedir."/"
"     call Decho('(s:NetrwBrowseChgDir)tree-list: ....searched.for treedir<'.treedir.'> found it!','~'.expand("<slnum>"))
     let haskey = 1
    else
"     call Decho('(s:NetrwBrowseChgDir)tree-list: ....searched for treedir<'.treedir.'/> : not found','~'.expand("<slnum>"))
    endif
   endif

   " search treedict for treedir with any trailing / elided
"   call Decho("tree-list: search treedict for treedir with any trailing / elided",'~'.expand("<slnum>"))
   if !haskey && treedir =~ '/$'
    let treedir= substitute(treedir,'/$','','')
    if has_key(w:netrw_treedict,treedir)
"     call Decho('(s:NetrwBrowseChgDir)tree-list: ....searched.for treedir<'.treedir.'> found it!','~'.expand("<slnum>"))
     let haskey = 1
    else
"     call Decho('(s:NetrwBrowseChgDir)tree-list: ....searched for treedir<'.treedir.'> : not found','~'.expand("<slnum>"))
    endif
   endif

"   call Decho("haskey=".haskey,'~'.expand("<slnum>"))
   if haskey
    " close tree listing for selected subdirectory
"    call Decho("tree-list: closing selected subdirectory<".dirname.">",'~'.expand("<slnum>"))
    call remove(w:netrw_treedict,treedir)
"    call Decho("tree-list: removed     entry<".treedir."> from treedict",'~'.expand("<slnum>"))
"    call Decho("tree-list: yielding treedict<".string(w:netrw_treedict).">",'~'.expand("<slnum>"))
    let dirname= w:netrw_treetop
   else
    " go down one directory
    let dirname= substitute(treedir,'/*$','/','')
"    call Decho("tree-list: go down one dir: treedir<".treedir.">",'~'.expand("<slnum>"))
"    call Decho("tree-list: ...            : dirname<".dirname.">",'~'.expand("<slnum>"))
   endif
   NetrwKeepj call s:SetRexDir(a:islocal,dirname)
"   call Decho("setting s:treeforceredraw to true",'~'.expand("<slnum>"))
   let s:treeforceredraw = 1

  else
   " ----------------------------------------
   " NetrwBrowseChgDir: Go down one directory {{{3
   " ----------------------------------------
   let dirname    = s:ComposePath(dirname,newdir)
"   call Decho("go down one dir: dirname<".dirname."> newdir<".newdir.">",'~'.expand("<slnum>"))
   NetrwKeepj call s:SetRexDir(a:islocal,dirname)
   norm! m`
  endif

 " --------------------------------------
 " NetrwBrowseChgDir: Restore and Cleanup {{{3
 " --------------------------------------
  if dorestore
   " dorestore is zero'd when a local file was hidden or bufhidden;
   " in such a case, we want to keep whatever settings it may have.
"   call Decho("doing option restore (dorestore=".dorestore.")",'~'.expand("<slnum>"))
   NetrwKeepj call s:NetrwOptionsRestore("s:")
"  else " Decho
"   call Decho("skipping option restore (dorestore==0): hidden=".&hidden." bufhidden=".&bufhidden." mod=".&mod,'~'.expand("<slnum>"))
  endif
  if dolockout && dorestore
"   call Decho("restore: filewritable(dirname<".dirname.">)=".filewritable(dirname),'~'.expand("<slnum>"))
   if filewritable(dirname)
"    call Decho("restore: doing modification lockout settings: ma nomod noro",'~'.expand("<slnum>"))
"    call Decho("restore: setl ma nomod noro",'~'.expand("<slnum>"))
    setl ma noro nomod
"    call Decho("restore: ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
   else
"    call Decho("restore: doing modification lockout settings: ma nomod ro",'~'.expand("<slnum>"))
"    call Decho("restore: setl ma nomod noro",'~'.expand("<slnum>"))
    setl ma ro nomod
"    call Decho("restore: ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
   endif
  endif
  call s:RestorePosn(s:netrw_posn)
  let @@= ykeep

"  call Dret("s:NetrwBrowseChgDir <".dirname."> : curpos<".string(getpos(".")).">")
  return dirname
endfun

" ---------------------------------------------------------------------
" s:NetrwBrowseUpDir: implements the "-" mappings {{{2
"    for thin, long, and wide: cursor placed just after banner
"    for tree, keeps cursor on current filename
fun! s:NetrwBrowseUpDir(islocal)
"  call Dfunc("s:NetrwBrowseUpDir(islocal=".a:islocal.")")
  if exists("w:netrw_bannercnt") && line(".") < w:netrw_bannercnt-1
   " this test needed because occasionally this function seems to be incorrectly called
   " when multiple leftmouse clicks are taken when atop the one line help in the banner.
   " I'm allowing the very bottom line to permit a "-" exit so that one may escape empty
   " directories.
"   call Dret("s:NetrwBrowseUpDir : cursor not in file area")
   return
  endif

  norm! 0
  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
"   call Decho("case: treestyle",'~'.expand("<slnum>"))
   let curline= getline(".")
   let swwline= winline() - 1
   if exists("w:netrw_treetop")
    let b:netrw_curdir= w:netrw_treetop
   elseif exists("b:netrw_curdir")
    let w:netrw_treetop= b:netrw_curdir
   else
    let w:netrw_treetop= getcwd()
    let b:netrw_curdir = w:netrw_treetop
   endif
   let curfile = getline(".")
   let curpath = s:NetrwTreePath(w:netrw_treetop)
   if a:islocal
    call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,'../'))
   else
    call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,'../'))
   endif
"   call Decho("looking for curfile<^".s:treedepthstring.curfile.">",'~'.expand("<slnum>"))
"   call Decho("having      curpath<".curpath.">",'~'.expand("<slnum>"))
   if w:netrw_treetop == '/'
     keepj call search('^\M'.curfile,"w")
   elseif curfile == '../'
     keepj call search('^\M'.curfile,"wb")
   else
"    call Decho("search(^\\M".s:treedepthstring.curfile.") backwards"))
    while 1
     keepj call search('^\M'.s:treedepthstring.curfile,"wb")
     let treepath= s:NetrwTreePath(w:netrw_treetop)
"     call Decho("..current treepath<".treepath.">",'~'.expand("<slnum>"))
     if treepath == curpath
      break
     endif
    endwhile
   endif

  else
"   call Decho("case: not treestyle",'~'.expand("<slnum>"))
   call s:SavePosn(s:netrw_posn)
   if exists("b:netrw_curdir")
    let curdir= b:netrw_curdir
   else
    let curdir= expand(getcwd())
   endif
   if a:islocal
    call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,'../'))
   else
    call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,'../'))
   endif
   call s:RestorePosn(s:netrw_posn)
   let curdir= substitute(curdir,'^.*[\/]','','')
   let curdir= '\<'. escape(curdir, '~'). '/'
   call search(curdir,'wc')
  endif
"  call Dret("s:NetrwBrowseUpDir")
endfun

" ---------------------------------------------------------------------
" netrw#BrowseX:  (implements "x" and "gx") executes a special "viewer" script or program for the {{{2
"              given filename; typically this means given their extension.
"              0=local, 1=remote
fun! netrw#BrowseX(fname,remote)
  let use_ctrlo= 1
"  call Dfunc("netrw#BrowseX(fname<".a:fname."> remote=".a:remote.")  implements x and gx maps")

  if a:remote == 0 && isdirectory(a:fname)
   " if its really just a local directory, then do a "gf" instead
"   call Decho("remote≡0 and a:fname<".a:fname."> ".(isdirectory(a:fname)? "is a directory" : "is not a directory"),'~'.expand("<slnum>"))
"   call Decho("..appears to be a local directory; using e ".a:fname." instead",'~'.expand("<slnum>"))
   exe "e ".a:fname
"   call Dret("netrw#BrowseX")
   return
  elseif a:remote == 1 && a:fname !~ '^https\=:' && a:fname =~ '/$'
   " remote directory, not a webpage access, looks like an attempt to do a directory listing
"   call Decho("remote≡1 and a:fname<".a:fname.">",'~'.expand("<slnum>"))
"   call Decho("..and fname ".((a:fname =~ '^https\=:')? 'matches' : 'does not match').'^https\=:','~'.expand("<slnum>"))
"   call Decho("..and fname ".((a:fname =~ '/$')?        'matches' : 'does not match').' /$','~'.expand("<slnum>"))
"   call Decho("..appears to be a remote directory listing request; using gf instead",'~'.expand("<slnum>"))
   norm! gf
"   call Dret("netrw#BrowseX")
   return
  endif
"  call Decho("not a local file nor a webpage request",'~'.expand("<slnum>"))

  if exists("g:netrw_browsex_viewer") && exists("g:netrw_browsex_support_remote") && !g:netrw_browsex_support_remote
    let remote = a:remote
  else
    let remote = 0
  endif

  let ykeep      = @@
  let screenposn = winsaveview()
"  call Decho("saving posn to screenposn<".string(screenposn).">",'~'.expand("<slnum>"))

  " need to save and restore aw setting as gx can invoke this function from non-netrw buffers
  let awkeep     = &aw
  set noaw

  " special core dump handler
  if a:fname =~ '/core\(\.\d\+\)\=$'
   if exists("g:Netrw_corehandler")
    if type(g:Netrw_corehandler) == 2
     " g:Netrw_corehandler is a function reference (see :help Funcref)
"     call Decho("g:Netrw_corehandler is a funcref",'~'.expand("<slnum>"))
     call g:Netrw_corehandler(s:NetrwFile(a:fname))
    elseif type(g:Netrw_corehandler) == 3
     " g:Netrw_corehandler is a List of function references (see :help Funcref)
"     call Decho("g:Netrw_corehandler is a List",'~'.expand("<slnum>"))
     for Fncref in g:Netrw_corehandler
      if type(Fncref) == 2
       call Fncref(a:fname)
      endif
     endfor
    endif
"    call Decho("restoring posn: screenposn<".string(screenposn).">,'~'.expand("<slnum>"))"
    call winrestview(screenposn)
    let @@= ykeep
    let &aw= awkeep
"    call Dret("netrw#BrowseX : coredump handler invoked")
    return
   endif
  endif

  " set up the filename
  " (lower case the extension, make a local copy of a remote file)
  let exten= substitute(a:fname,'.*\.\(.\{-}\)','\1','e')
  if has("win32")
   let exten= substitute(exten,'^.*$','\L&\E','')
  endif
  if exten =~ "[\\/]"
   let exten= ""
  endif
"  call Decho("exten<".exten.">",'~'.expand("<slnum>"))

  if remote == 1
   " create a local copy
"   call Decho("remote: remote=".remote.": create a local copy of <".a:fname.">",'~'.expand("<slnum>"))
   setl bh=delete
   call netrw#NetRead(3,a:fname)
   " attempt to rename tempfile
   let basename= substitute(a:fname,'^\(.*\)/\(.*\)\.\([^.]*\)$','\2','')
   let newname = substitute(s:netrw_tmpfile,'^\(.*\)/\(.*\)\.\([^.]*\)$','\1/'.basename.'.\3','')
"   call Decho("basename<".basename.">",'~'.expand("<slnum>"))
"   call Decho("newname <".newname.">",'~'.expand("<slnum>"))
   if s:netrw_tmpfile != newname && newname != ""
    if rename(s:netrw_tmpfile,newname) == 0
     " renaming succeeded
"     call Decho("renaming succeeded (tmpfile<".s:netrw_tmpfile."> to <".newname.">)")
     let fname= newname
    else
     " renaming failed
"     call Decho("renaming failed (tmpfile<".s:netrw_tmpfile."> to <".newname.">)")
     let fname= s:netrw_tmpfile
    endif
   else
    let fname= s:netrw_tmpfile
   endif
  else
"   call Decho("local: remote=".remote.": handling local copy of <".a:fname.">",'~'.expand("<slnum>"))
   let fname= a:fname
   " special ~ handler for local
   if fname =~ '^\~' && expand("$HOME") != ""
"    call Decho('invoking special ~ handler','~'.expand("<slnum>"))
    let fname= s:NetrwFile(substitute(fname,'^\~',expand("$HOME"),''))
   endif
  endif
"  call Decho("fname<".fname.">",'~'.expand("<slnum>"))
"  call Decho("exten<".exten."> "."netrwFileHandlers#NFH_".exten."():exists=".exists("*netrwFileHandlers#NFH_".exten),'~'.expand("<slnum>"))

  " set up redirection (avoids browser messages)
  " by default, g:netrw_suppress_gx_mesg is true
  if g:netrw_suppress_gx_mesg
   if &srr =~ "%s"
    if has("win32")
     let redir= substitute(&srr,"%s","nul","")
    else
     let redir= substitute(&srr,"%s","/dev/null","")
    endif
   elseif has("win32")
    let redir= &srr . "nul"
   else
    let redir= &srr . "/dev/null"
   endif
  else
   let redir= ""
  endif
"  call Decho("set up redirection: redir{".redir."} srr{".&srr."}",'~'.expand("<slnum>"))

  " extract any viewing options.  Assumes that they're set apart by spaces.
  if exists("g:netrw_browsex_viewer")
"   call Decho("extract any viewing options from g:netrw_browsex_viewer<".g:netrw_browsex_viewer.">",'~'.expand("<slnum>"))
   if g:netrw_browsex_viewer =~ '\s'
    let viewer  = substitute(g:netrw_browsex_viewer,'\s.*$','','')
    let viewopt = substitute(g:netrw_browsex_viewer,'^\S\+\s*','','')." "
    let oviewer = ''
    let cnt     = 1
    while !executable(viewer) && viewer != oviewer
     let viewer  = substitute(g:netrw_browsex_viewer,'^\(\(^\S\+\s\+\)\{'.cnt.'}\S\+\)\(.*\)$','\1','')
     let viewopt = substitute(g:netrw_browsex_viewer,'^\(\(^\S\+\s\+\)\{'.cnt.'}\S\+\)\(.*\)$','\3','')." "
     let cnt     = cnt + 1
     let oviewer = viewer
"     call Decho("!exe: viewer<".viewer.">  viewopt<".viewopt.">",'~'.expand("<slnum>"))
    endwhile
   else
    let viewer  = g:netrw_browsex_viewer
    let viewopt = ""
   endif
"   call Decho("viewer<".viewer.">  viewopt<".viewopt.">",'~'.expand("<slnum>"))
  endif

  " execute the file handler
"  call Decho("execute the file handler (if any)",'~'.expand("<slnum>"))
  if exists("g:netrw_browsex_viewer") && g:netrw_browsex_viewer == '-'
"   call Decho("(netrw#BrowseX) g:netrw_browsex_viewer<".g:netrw_browsex_viewer.">",'~'.expand("<slnum>"))
   let ret= netrwFileHandlers#Invoke(exten,fname)

  elseif exists("g:netrw_browsex_viewer") && executable(viewer)
"   call Decho("(netrw#BrowseX) g:netrw_browsex_viewer<".g:netrw_browsex_viewer.">",'~'.expand("<slnum>"))
   call s:NetrwExe("sil !".viewer." ".viewopt.s:ShellEscape(fname,1).redir)
   let ret= v:shell_error

  elseif has("win32")
"   call Decho("(netrw#BrowseX) win".(has("win32")? "32" : "64"),'~'.expand("<slnum>"))
   if executable("start")
    call s:NetrwExe('sil! !start rundll32 url.dll,FileProtocolHandler '.s:ShellEscape(fname,1))
   elseif executable("rundll32")
    call s:NetrwExe('sil! !rundll32 url.dll,FileProtocolHandler '.s:ShellEscape(fname,1))
   else
    call netrw#ErrorMsg(s:WARNING,"rundll32 not on path",74)
   endif
   let ret= v:shell_error

  elseif has("win32unix")
   let winfname= 'c:\cygwin'.substitute(fname,'/','\\','g')
"   call Decho("(netrw#BrowseX) cygwin: winfname<".s:ShellEscape(winfname,1).">",'~'.expand("<slnum>"))
   if executable("start")
"    call Decho("(netrw#BrowseX) win32unix+start",'~'.expand("<slnum>"))
    call s:NetrwExe('sil !start rundll32 url.dll,FileProtocolHandler '.s:ShellEscape(winfname,1))
   elseif executable("rundll32")
"    call Decho("(netrw#BrowseX) win32unix+rundll32",'~'.expand("<slnum>"))
    call s:NetrwExe('sil !rundll32 url.dll,FileProtocolHandler '.s:ShellEscape(winfname,1))
   elseif executable("cygstart")
"    call Decho("(netrw#BrowseX) win32unix+cygstart",'~'.expand("<slnum>"))
    call s:NetrwExe('sil !cygstart '.s:ShellEscape(fname,1))
   else
    call netrw#ErrorMsg(s:WARNING,"rundll32 not on path",74)
   endif
   let ret= v:shell_error

  elseif has("unix") && $DESKTOP_SESSION == "mate" && executable("atril")
"   call Decho("(netrw#BrowseX) unix and atril",'~'.expand("<slnum>"))
   if a:fname =~ '^https\=://'
    " atril does not appear to understand how to handle html -- so use gvim to edit the document
    let use_ctrlo= 0
"    call Decho("fname<".fname.">")
"    call Decho("a:fname<".a:fname.">")
    call s:NetrwExe("sil! !gvim ".fname.' -c "keepj keepalt file '.fnameescape(a:fname).'"')

   else
    call s:NetrwExe("sil !atril ".s:ShellEscape(fname,1).redir)
   endif
   let ret= v:shell_error

  elseif has("unix") && executable("kfmclient") && s:CheckIfKde()
"   call Decho("(netrw#BrowseX) unix and kfmclient",'~'.expand("<slnum>"))
   call s:NetrwExe("sil !kfmclient exec ".s:ShellEscape(fname,1)." ".redir)
   let ret= v:shell_error

  elseif has("unix") && executable("exo-open") && executable("xdg-open") && executable("setsid")
"   call Decho("(netrw#BrowseX) unix, exo-open, xdg-open",'~'.expand("<slnum>"))
   call s:NetrwExe("sil !setsid xdg-open ".s:ShellEscape(fname,1).redir.'&')
   let ret= v:shell_error

  elseif has("unix") && executable("xdg-open")
"   call Decho("(netrw#BrowseX) unix and xdg-open",'~'.expand("<slnum>"))
   call s:NetrwExe("sil !xdg-open ".s:ShellEscape(fname,1).redir.'&')
   let ret= v:shell_error

  elseif has("macunix") && executable("open")
"   call Decho("(netrw#BrowseX) macunix and open",'~'.expand("<slnum>"))
   call s:NetrwExe("sil !open ".s:ShellEscape(fname,1)." ".redir)
   let ret= v:shell_error

  else
   " netrwFileHandlers#Invoke() always returns 0
"   call Decho("(netrw#BrowseX) use netrwFileHandlers",'~'.expand("<slnum>"))
   let ret= netrwFileHandlers#Invoke(exten,fname)
  endif

  " if unsuccessful, attempt netrwFileHandlers#Invoke()
  if ret
"   call Decho("(netrw#BrowseX) ret=".ret," indicates unsuccessful thus far",'~'.expand("<slnum>"))
   let ret= netrwFileHandlers#Invoke(exten,fname)
  endif

  " restoring redraw! after external file handlers
  redraw!

  " cleanup: remove temporary file,
  "          delete current buffer if success with handler,
  "          return to prior buffer (directory listing)
  "          Feb 12, 2008: had to de-activate removal of
  "          temporary file because it wasn't getting seen.
"  if remote == 1 && fname != a:fname
""   call Decho("deleting temporary file<".fname.">",'~'.expand("<slnum>"))
"   call s:NetrwDelete(fname)
"  endif

  if remote == 1
   setl bh=delete bt=nofile
   if g:netrw_use_noswf
    setl noswf
   endif
   if use_ctrlo
    exe "sil! NetrwKeepj norm! \<c-o>"
   endif
  endif
"  call Decho("restoring posn to screenposn<".string(screenposn).">",'~'.expand("<slnum>"))
  call winrestview(screenposn)
  let @@ = ykeep
  let &aw= awkeep

"  call Dret("netrw#BrowseX")
endfun

" ---------------------------------------------------------------------
" netrw#GX: gets word under cursor for gx support {{{2
"           See also: netrw#BrowseXVis
"                     netrw#BrowseX
fun! netrw#GX()
"  call Dfunc("netrw#GX()")
  if &ft == "netrw"
   let fname= s:NetrwGetWord()
  else
   let fname= expand((exists("g:netrw_gx")? g:netrw_gx : '<cfile>'))
  endif
"  call Dret("netrw#GX <".fname.">")
  return fname
endfun

" ---------------------------------------------------------------------
" netrw#BrowseXVis: used by gx in visual mode to select a file for browsing {{{2
fun! netrw#BrowseXVis()
  let dict={}
  let dict.a=[getreg('a'), getregtype('a')]
  norm! gv"ay
  let gxfile= @a
  call s:RestoreRegister(dict)
  call netrw#BrowseX(gxfile,netrw#CheckIfRemote(gxfile))
endfun

" ---------------------------------------------------------------------
" s:NetrwBufRename: renames a buffer without the side effect of retaining an unlisted buffer having the old name {{{2
"                   Using the file command on a "[No Name]" buffer does not seem to cause the old "[No Name]" buffer
"                   to become an unlisted buffer, so in that case don't bwipe it.
fun! s:NetrwBufRename(newname)
"  call Dfunc("s:NetrwBufRename(newname<".a:newname.">) buf(%)#".bufnr("%")."<".bufname(bufnr("%")).">")
"  call Dredir("ls!","s:NetrwBufRename (before rename)")
  let oldbufname= bufname(bufnr("%"))
"  call Decho("buf#".bufnr("%").": oldbufname<".oldbufname.">",'~'.expand("<slnum>"))

  if oldbufname != a:newname
"   call Decho("do buffer rename: oldbufname<".oldbufname."> ≠ a:newname<".a:newname.">",'~'.expand("<slnum>"))
   let b:junk= 1
"   call Decho("rename buffer: sil! keepj keepalt file ".fnameescape(a:newname),'~'.expand("<slnum>"))
   exe 'sil! keepj keepalt file '.fnameescape(a:newname)
"   call Dredir("ls!","s:NetrwBufRename (before bwipe)~".expand("<slnum>"))
   let oldbufnr= bufnr(oldbufname)
"   call Decho("oldbufname<".oldbufname."> oldbufnr#".oldbufnr,'~'.expand("<slnum>"))
"   call Decho("bufnr(%)=".bufnr("%"),'~'.expand("<slnum>"))
   if oldbufname != "" && oldbufnr != -1 && oldbufnr != bufnr("%")
"    call Decho("bwipe ".oldbufnr,'~'.expand("<slnum>"))
    exe "bwipe! ".oldbufnr
"   else " Decho
"    call Decho("did *not* bwipe buf#".oldbufnr,'~'.expand("<slnum>"))
"    call Decho("..reason: if oldbufname<".oldbufname."> is empty",'~'.expand("<slnum>"))"
"    call Decho("..reason: if oldbufnr#".oldbufnr." is -1",'~'.expand("<slnum>"))"
"    call Decho("..reason: if oldbufnr#".oldbufnr." != bufnr(%)#".bufnr("%"),'~'.expand("<slnum>"))"
   endif
"   call Dredir("ls!","s:NetrwBufRename (after rename)")
"  else " Decho
"   call Decho("oldbufname<".oldbufname."> == a:newname: did *not* rename",'~'.expand("<slnum>"))
  endif

"  call Dret("s:NetrwBufRename : buf#".bufnr("%").": oldname<".oldbufname."> newname<".a:newname."> expand(%)<".expand("%").">")
endfun

" ---------------------------------------------------------------------
" netrw#CheckIfRemote: returns 1 if current file looks like an url, 0 else {{{2
fun! netrw#CheckIfRemote(...)
"  call Dfunc("netrw#CheckIfRemote() a:0=".a:0)
  if a:0 > 0
   let curfile= a:1
  else
   let curfile= expand("%")
  endif

  " Ignore terminal buffers
  if &buftype ==# 'terminal'
    return 0
  endif
"  call Decho("curfile<".curfile.">")
  if curfile =~ '^\a\{3,}://'
"   call Dret("netrw#CheckIfRemote 1")
   return 1
  else
"   call Dret("netrw#CheckIfRemote 0")
   return 0
  endif
endfun

" ---------------------------------------------------------------------
" s:NetrwChgPerm: (implements "gp") change file permission {{{2
fun! s:NetrwChgPerm(islocal,curdir)
"  call Dfunc("s:NetrwChgPerm(islocal=".a:islocal." curdir<".a:curdir.">)")
  let ykeep  = @@
  call inputsave()
  let newperm= input("Enter new permission: ")
  call inputrestore()
  let chgperm= substitute(g:netrw_chgperm,'\<FILENAME\>',s:ShellEscape(expand("<cfile>")),'')
  let chgperm= substitute(chgperm,'\<PERM\>',s:ShellEscape(newperm),'')
"  call Decho("chgperm<".chgperm.">",'~'.expand("<slnum>"))
  call system(chgperm)
  if v:shell_error != 0
   NetrwKeepj call netrw#ErrorMsg(1,"changing permission on file<".expand("<cfile>")."> seems to have failed",75)
  endif
  if a:islocal
   NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
  endif
  let @@= ykeep
"  call Dret("s:NetrwChgPerm")
endfun

" ---------------------------------------------------------------------
" s:CheckIfKde: checks if kdeinit is running {{{2
"    Returns 0: kdeinit not running
"            1: kdeinit is  running
fun! s:CheckIfKde()
"  call Dfunc("s:CheckIfKde()")
  " seems kde systems often have gnome-open due to dependencies, even though
  " gnome-open's subsidiary display tools are largely absent.  Kde systems
  " usually have "kdeinit" running, though...  (tnx Mikolaj Machowski)
  if !exists("s:haskdeinit")
   if has("unix") && executable("ps") && !has("win32unix")
    let s:haskdeinit= system("ps -e") =~ '\<kdeinit'
    if v:shell_error
     let s:haskdeinit = 0
    endif
   else
    let s:haskdeinit= 0
   endif
"   call Decho("setting s:haskdeinit=".s:haskdeinit,'~'.expand("<slnum>"))
  endif

"  call Dret("s:CheckIfKde ".s:haskdeinit)
  return s:haskdeinit
endfun

" ---------------------------------------------------------------------
" s:NetrwClearExplore: clear explore variables (if any) {{{2
fun! s:NetrwClearExplore()
"  call Dfunc("s:NetrwClearExplore()")
  2match none
  if exists("s:explore_match")        |unlet s:explore_match        |endif
  if exists("s:explore_indx")         |unlet s:explore_indx         |endif
  if exists("s:netrw_explore_prvdir") |unlet s:netrw_explore_prvdir |endif
  if exists("s:dirstarstar")          |unlet s:dirstarstar          |endif
  if exists("s:explore_prvdir")       |unlet s:explore_prvdir       |endif
  if exists("w:netrw_explore_indx")   |unlet w:netrw_explore_indx   |endif
  if exists("w:netrw_explore_listlen")|unlet w:netrw_explore_listlen|endif
  if exists("w:netrw_explore_list")   |unlet w:netrw_explore_list   |endif
  if exists("w:netrw_explore_bufnr")  |unlet w:netrw_explore_bufnr  |endif
"   redraw!
"  call Dret("s:NetrwClearExplore")
endfun

" ---------------------------------------------------------------------
" s:NetrwEditBuf: decides whether or not to use keepalt to edit a buffer {{{2
fun! s:NetrwEditBuf(bufnum)
"  call Dfunc("s:NetrwEditBuf(fname<".a:bufnum.">)")
  if exists("g:netrw_altfile") && g:netrw_altfile && &ft == "netrw"
"   call Decho("exe sil! NetrwKeepj keepalt noswapfile b ".fnameescape(a:bufnum))
   exe "sil! NetrwKeepj keepalt noswapfile b ".fnameescape(a:bufnum)
  else
"   call Decho("exe sil! NetrwKeepj noswapfile b ".fnameescape(a:bufnum))
   exe "sil! NetrwKeepj noswapfile b ".fnameescape(a:bufnum)
  endif
"  call Dret("s:NetrwEditBuf")
endfun

" ---------------------------------------------------------------------
" s:NetrwEditFile: decides whether or not to use keepalt to edit a file {{{2
"    NetrwKeepj [keepalt] <OPT> <CMD> <FILENAME>
fun! s:NetrwEditFile(cmd,opt,fname)
"  call Dfunc("s:NetrwEditFile(cmd<".a:cmd.">,opt<".a:opt.">,fname<".a:fname.">)  ft<".&ft.">")
  if exists("g:netrw_altfile") && g:netrw_altfile && &ft == "netrw"
"   call Decho("exe NetrwKeepj keepalt ".a:opt." ".a:cmd." ".fnameescape(a:fname))
   exe "NetrwKeepj keepalt ".a:opt." ".a:cmd." ".fnameescape(a:fname)
  else
"   call Decho("exe NetrwKeepj ".a:opt." ".a:cmd." ".fnameescape(a:fname))
    if a:cmd =~# 'e\%[new]!' && !&hidden && getbufvar(bufname('%'), '&modified', 0)
      call setbufvar(bufname('%'), '&bufhidden', 'hide')
    endif
   exe "NetrwKeepj ".a:opt." ".a:cmd." ".fnameescape(a:fname)
  endif
"  call Dret("s:NetrwEditFile")
endfun

" ---------------------------------------------------------------------
" s:NetrwExploreListUniq: {{{2
fun! s:NetrwExploreListUniq(explist)
"  call Dfunc("s:NetrwExploreListUniq(explist<".string(a:explist).">)")

  " this assumes that the list is already sorted
  let newexplist= []
  for member in a:explist
   if !exists("uniqmember") || member != uniqmember
    let uniqmember = member
    let newexplist = newexplist + [ member ]
   endif
  endfor

"  call Dret("s:NetrwExploreListUniq newexplist<".string(newexplist).">")
  return newexplist
endfun

" ---------------------------------------------------------------------
" s:NetrwForceChgDir: (gd support) Force treatment as a directory {{{2
fun! s:NetrwForceChgDir(islocal,newdir)
"  call Dfunc("s:NetrwForceChgDir(islocal=".a:islocal." newdir<".a:newdir.">)")
  let ykeep= @@
  if a:newdir !~ '/$'
   " ok, looks like force is needed to get directory-style treatment
   if a:newdir =~ '@$'
    let newdir= substitute(a:newdir,'@$','/','')
   elseif a:newdir =~ '[*=|\\]$'
    let newdir= substitute(a:newdir,'.$','/','')
   else
    let newdir= a:newdir.'/'
   endif
"   call Decho("adjusting newdir<".newdir."> due to gd",'~'.expand("<slnum>"))
  else
   " should already be getting treatment as a directory
   let newdir= a:newdir
  endif
  let newdir= s:NetrwBrowseChgDir(a:islocal,newdir)
  call s:NetrwBrowse(a:islocal,newdir)
  let @@= ykeep
"  call Dret("s:NetrwForceChgDir")
endfun

" ---------------------------------------------------------------------
" s:NetrwGlob: does glob() if local, remote listing otherwise {{{2
"     direntry: this is the name of the directory.  Will be fnameescape'd to prevent wildcard handling by glob()
"     expr    : this is the expression to follow the directory.  Will use s:ComposePath()
"     pare    =1: remove the current directory from the resulting glob() filelist
"             =0: leave  the current directory   in the resulting glob() filelist
fun! s:NetrwGlob(direntry,expr,pare)
"  call Dfunc("s:NetrwGlob(direntry<".a:direntry."> expr<".a:expr."> pare=".a:pare.")")
  if netrw#CheckIfRemote()
   keepalt 1sp
   keepalt enew
   let keep_liststyle    = w:netrw_liststyle
   let w:netrw_liststyle = s:THINLIST
   if s:NetrwRemoteListing() == 0
    keepj keepalt %s@/@@
    let filelist= getline(1,$)
    q!
   else
    " remote listing error -- leave treedict unchanged
    let filelist= w:netrw_treedict[a:direntry]
   endif
   let w:netrw_liststyle= keep_liststyle
  else
   let path= s:ComposePath(fnameescape(a:direntry),a:expr) 
    if has("win32")
     " escape [ so it is not detected as wildcard character, see :h wildcard
     let path= substitute(path, '[', '[[]', 'g')
    endif
    if v:version > 704 || (v:version == 704 && has("patch656"))
     let filelist= glob(path,0,1,1)
    else
     let filelist= glob(path,0,1)
    endif
    if a:pare
     let filelist= map(filelist,'substitute(v:val, "^.*/", "", "")')
    endif
  endif
"  call Dret("s:NetrwGlob ".string(filelist))
  return filelist
endfun

" ---------------------------------------------------------------------
" s:NetrwForceFile: (gf support) Force treatment as a file {{{2
fun! s:NetrwForceFile(islocal,newfile)
"  call Dfunc("s:NetrwForceFile(islocal=".a:islocal." newdir<".a:newfile.">)")
  if a:newfile =~ '[/@*=|\\]$'
   let newfile= substitute(a:newfile,'.$','','')
  else
   let newfile= a:newfile
  endif
  if a:islocal
   call s:NetrwBrowseChgDir(a:islocal,newfile)
  else
   call s:NetrwBrowse(a:islocal,s:NetrwBrowseChgDir(a:islocal,newfile))
  endif
"  call Dret("s:NetrwForceFile")
endfun

" ---------------------------------------------------------------------
" s:NetrwHide: this function is invoked by the "a" map for browsing {{{2
"          and switches the hiding mode.  The actual hiding is done by
"          s:NetrwListHide().
"             g:netrw_hide= 0: show all
"                           1: show not-hidden files
"                           2: show hidden files only
fun! s:NetrwHide(islocal)
"  call Dfunc("NetrwHide(islocal=".a:islocal.") g:netrw_hide=".g:netrw_hide)
  let ykeep= @@
  let svpos= winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))

  if exists("s:netrwmarkfilelist_{bufnr('%')}")
"   call Decho("((g:netrw_hide == 1)? "unhide" : "hide")." files in markfilelist<".string(s:netrwmarkfilelist_{bufnr("%")}).">",'~'.expand("<slnum>"))
"   call Decho("g:netrw_list_hide<".g:netrw_list_hide.">",'~'.expand("<slnum>"))

   " hide the files in the markfile list
   for fname in s:netrwmarkfilelist_{bufnr("%")}
"    call Decho("match(g:netrw_list_hide<".g:netrw_list_hide.'> fname<\<'.fname.'\>>)='.match(g:netrw_list_hide,'\<'.fname.'\>')." l:isk=".&l:isk,'~'.expand("<slnum>"))
    if match(g:netrw_list_hide,'\<'.fname.'\>') != -1
     " remove fname from hiding list
     let g:netrw_list_hide= substitute(g:netrw_list_hide,'..\<'.escape(fname,g:netrw_fname_escape).'\>..','','')
     let g:netrw_list_hide= substitute(g:netrw_list_hide,',,',',','g')
     let g:netrw_list_hide= substitute(g:netrw_list_hide,'^,\|,$','','')
"     call Decho("unhide: g:netrw_list_hide<".g:netrw_list_hide.">",'~'.expand("<slnum>"))
    else
     " append fname to hiding list
     if exists("g:netrw_list_hide") && g:netrw_list_hide != ""
      let g:netrw_list_hide= g:netrw_list_hide.',\<'.escape(fname,g:netrw_fname_escape).'\>'
     else
      let g:netrw_list_hide= '\<'.escape(fname,g:netrw_fname_escape).'\>'
     endif
"     call Decho("hide: g:netrw_list_hide<".g:netrw_list_hide.">",'~'.expand("<slnum>"))
    endif
   endfor
   NetrwKeepj call s:NetrwUnmarkList(bufnr("%"),b:netrw_curdir)
   let g:netrw_hide= 1

  else

   " switch between show-all/show-not-hidden/show-hidden
   let g:netrw_hide=(g:netrw_hide+1)%3
   exe "NetrwKeepj norm! 0"
   if g:netrw_hide && g:netrw_list_hide == ""
    NetrwKeepj call netrw#ErrorMsg(s:WARNING,"your hiding list is empty!",49)
    let @@= ykeep
"    call Dret("NetrwHide")
    return
   endif
  endif

  NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)
  let @@= ykeep
"  call Dret("NetrwHide")
endfun

" ---------------------------------------------------------------------
" s:NetrwHideEdit: allows user to edit the file/directory hiding list {{{2
fun! s:NetrwHideEdit(islocal)
"  call Dfunc("NetrwHideEdit(islocal=".a:islocal.")")

  let ykeep= @@
  " save current cursor position
  let svpos= winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))

  " get new hiding list from user
  call inputsave()
  let newhide= input("Edit Hiding List: ",g:netrw_list_hide)
  call inputrestore()
  let g:netrw_list_hide= newhide
"  call Decho("new g:netrw_list_hide<".g:netrw_list_hide.">",'~'.expand("<slnum>"))

  " refresh the listing
  sil NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,"./"))

  " restore cursor position
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  call winrestview(svpos)
  let @@= ykeep

"  call Dret("NetrwHideEdit")
endfun

" ---------------------------------------------------------------------
" s:NetrwHidden: invoked by "gh" {{{2
fun! s:NetrwHidden(islocal)
"  call Dfunc("s:NetrwHidden()")
  let ykeep= @@
  "  save current position
  let svpos  = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))

  if g:netrw_list_hide =~ '\(^\|,\)\\(^\\|\\s\\s\\)\\zs\\.\\S\\+'
   " remove .file pattern from hiding list
"   call Decho("remove .file pattern from hiding list",'~'.expand("<slnum>"))
   let g:netrw_list_hide= substitute(g:netrw_list_hide,'\(^\|,\)\\(^\\|\\s\\s\\)\\zs\\.\\S\\+','','')
  elseif s:Strlen(g:netrw_list_hide) >= 1
"   call Decho("add .file pattern from hiding list",'~'.expand("<slnum>"))
   let g:netrw_list_hide= g:netrw_list_hide . ',\(^\|\s\s\)\zs\.\S\+'
  else
"   call Decho("set .file pattern as hiding list",'~'.expand("<slnum>"))
   let g:netrw_list_hide= '\(^\|\s\s\)\zs\.\S\+'
  endif
  if g:netrw_list_hide =~ '^,'
   let g:netrw_list_hide= strpart(g:netrw_list_hide,1)
  endif

  " refresh screen and return to saved position
  NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)
  let @@= ykeep
"  call Dret("s:NetrwHidden")
endfun

" ---------------------------------------------------------------------
"  s:NetrwHome: this function determines a "home" for saving bookmarks and history {{{2
fun! s:NetrwHome()
  if exists("g:netrw_home")
   let home= expand(g:netrw_home)
  else
   let home = stdpath('data')
  endif
  " insure that the home directory exists
  if g:netrw_dirhistmax > 0 && !isdirectory(s:NetrwFile(home))
"   call Decho("insure that the home<".home."> directory exists")
   if exists("g:netrw_mkdir")
"    call Decho("call system(".g:netrw_mkdir." ".s:ShellEscape(s:NetrwFile(home)).")")
    call system(g:netrw_mkdir." ".s:ShellEscape(s:NetrwFile(home)))
   else
"    call Decho("mkdir(".home.")")
    call mkdir(home)
   endif
  endif
  let g:netrw_home= home
  return home
endfun

" ---------------------------------------------------------------------
" s:NetrwLeftmouse: handles the <leftmouse> when in a netrw browsing window {{{2
fun! s:NetrwLeftmouse(islocal)
  if exists("s:netrwdrag")
   return
  endif
  if &ft != "netrw"
   return
  endif
"  call Dfunc("s:NetrwLeftmouse(islocal=".a:islocal.")")

  let ykeep= @@
  " check if the status bar was clicked on instead of a file/directory name
  while getchar(0) != 0
   "clear the input stream
  endwhile
  call feedkeys("\<LeftMouse>")
  let c          = getchar()
  let mouse_lnum = v:mouse_lnum
  let wlastline  = line('w$')
  let lastline   = line('$')
"  call Decho("v:mouse_lnum=".mouse_lnum." line(w$)=".wlastline." line($)=".lastline." v:mouse_win=".v:mouse_win." winnr#".winnr(),'~'.expand("<slnum>"))
"  call Decho("v:mouse_col =".v:mouse_col."     col=".col(".")."  wincol =".wincol()." winwidth   =".winwidth(0),'~'.expand("<slnum>"))
  if mouse_lnum >= wlastline + 1 || v:mouse_win != winnr()
   " appears to be a status bar leftmouse click
   let @@= ykeep
"   call Dret("s:NetrwLeftmouse : detected a status bar leftmouse click")
   return
  endif
   " Dec 04, 2013: following test prevents leftmouse selection/deselection of directories and files in treelist mode
   " Windows are separated by vertical separator bars - but the mouse seems to be doing what it should when dragging that bar
   " without this test when its disabled.
   " May 26, 2014: edit file, :Lex, resize window -- causes refresh.  Reinstated a modified test.  See if problems develop.
"   call Decho("v:mouse_col=".v:mouse_col." col#".col('.')." virtcol#".virtcol('.')." col($)#".col("$")." virtcol($)#".virtcol("$"),'~'.expand("<slnum>"))
   if v:mouse_col > virtcol('.')
    let @@= ykeep
"    call Dret("s:NetrwLeftmouse : detected a vertical separator bar leftmouse click")
    return
   endif

  if a:islocal
   if exists("b:netrw_curdir")
    NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,s:NetrwGetWord()))
   endif
  else
   if exists("b:netrw_curdir")
    NetrwKeepj call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,s:NetrwGetWord()))
   endif
  endif
  let @@= ykeep
"  call Dret("s:NetrwLeftmouse")
endfun

" ---------------------------------------------------------------------
" s:NetrwCLeftmouse: used to select a file/directory for a target {{{2
fun! s:NetrwCLeftmouse(islocal)
  if &ft != "netrw"
   return
  endif
"  call Dfunc("s:NetrwCLeftmouse(islocal=".a:islocal.")")
  call s:NetrwMarkFileTgt(a:islocal)
"  call Dret("s:NetrwCLeftmouse")
endfun

" ---------------------------------------------------------------------
" s:NetrwServerEdit: edit file in a server gvim, usually NETRWSERVER  (implements <c-r>){{{2
"   a:islocal=0 : <c-r> not used, remote
"   a:islocal=1 : <c-r> not used, local
"   a:islocal=2 : <c-r>     used, remote
"   a:islocal=3 : <c-r>     used, local
fun! s:NetrwServerEdit(islocal,fname)
"  call Dfunc("s:NetrwServerEdit(islocal=".a:islocal.",fname<".a:fname.">)")
  let islocal = a:islocal%2      " =0: remote           =1: local
  let ctrlr   = a:islocal >= 2   " =0: <c-r> not used   =1: <c-r> used
"  call Decho("islocal=".islocal." ctrlr=".ctrlr,'~'.expand("<slnum>"))

  if (islocal && isdirectory(s:NetrwFile(a:fname))) || (!islocal && a:fname =~ '/$')
   " handle directories in the local window -- not in the remote vim server
   " user must have closed the NETRWSERVER window.  Treat as normal editing from netrw.
"   call Decho("handling directory in client window",'~'.expand("<slnum>"))
   let g:netrw_browse_split= 0
   if exists("s:netrw_browse_split") && exists("s:netrw_browse_split_".winnr())
    let g:netrw_browse_split= s:netrw_browse_split_{winnr()}
    unlet s:netrw_browse_split_{winnr()}
   endif
   call s:NetrwBrowse(islocal,s:NetrwBrowseChgDir(islocal,a:fname))
"   call Dret("s:NetrwServerEdit")
   return
  endif

"  call Decho("handling file in server window",'~'.expand("<slnum>"))
  if has("clientserver") && executable("gvim")
"   call Decho("has clientserver and gvim",'~'.expand("<slnum>"))

    if exists("g:netrw_browse_split") && type(g:netrw_browse_split) == 3
"     call Decho("g:netrw_browse_split=".string(g:netrw_browse_split),'~'.expand("<slnum>"))
     let srvrname = g:netrw_browse_split[0]
     let tabnum   = g:netrw_browse_split[1]
     let winnum   = g:netrw_browse_split[2]

     if serverlist() !~ '\<'.srvrname.'\>'
"      call Decho("server not available; ctrlr=".ctrlr,'~'.expand("<slnum>"))

      if !ctrlr
       " user must have closed the server window and the user did not use <c-r>, but
       " used something like <cr>.
"       call Decho("user must have closed server AND did not use ctrl-r",'~'.expand("<slnum>"))
       if exists("g:netrw_browse_split")
        unlet g:netrw_browse_split
       endif
       let g:netrw_browse_split= 0
       if exists("s:netrw_browse_split_".winnr())
        let g:netrw_browse_split= s:netrw_browse_split_{winnr()}
       endif
       call s:NetrwBrowseChgDir(islocal,a:fname)
"       call Dret("s:NetrwServerEdit")
       return

      elseif has("win32") && executable("start")
       " start up remote netrw server under windows
"       call Decho("starting up gvim server<".srvrname."> for windows",'~'.expand("<slnum>"))
       call system("start gvim --servername ".srvrname)

      else
       " start up remote netrw server under linux
"       call Decho("starting up gvim server<".srvrname.">",'~'.expand("<slnum>"))
       call system("gvim --servername ".srvrname)
      endif
     endif

"     call Decho("srvrname<".srvrname."> tabnum=".tabnum." winnum=".winnum." server-editing<".a:fname.">",'~'.expand("<slnum>"))
     call remote_send(srvrname,":tabn ".tabnum."\<cr>")
     call remote_send(srvrname,":".winnum."wincmd w\<cr>")
     call remote_send(srvrname,":e ".fnameescape(s:NetrwFile(a:fname))."\<cr>")

    else

     if serverlist() !~ '\<'.g:netrw_servername.'\>'

      if !ctrlr
"       call Decho("server<".g:netrw_servername."> not available and ctrl-r not used",'~'.expand("<slnum>"))
       if exists("g:netrw_browse_split")
        unlet g:netrw_browse_split
       endif
       let g:netrw_browse_split= 0
       call s:NetrwBrowse(islocal,s:NetrwBrowseChgDir(islocal,a:fname))
"       call Dret("s:NetrwServerEdit")
       return

      else
"       call Decho("server<".g:netrw_servername."> not available but ctrl-r used",'~'.expand("<slnum>"))
       if has("win32") && executable("start")
        " start up remote netrw server under windows
"        call Decho("starting up gvim server<".g:netrw_servername."> for windows",'~'.expand("<slnum>"))
        call system("start gvim --servername ".g:netrw_servername)
       else
        " start up remote netrw server under linux
"        call Decho("starting up gvim server<".g:netrw_servername.">",'~'.expand("<slnum>"))
        call system("gvim --servername ".g:netrw_servername)
       endif
      endif
     endif

     while 1
      try
"       call Decho("remote-send: e ".a:fname,'~'.expand("<slnum>"))
       call remote_send(g:netrw_servername,":e ".fnameescape(s:NetrwFile(a:fname))."\<cr>")
       break
      catch /^Vim\%((\a\+)\)\=:E241/
       sleep 200m
      endtry
     endwhile

     if exists("g:netrw_browse_split")
      if type(g:netrw_browse_split) != 3
        let s:netrw_browse_split_{winnr()}= g:netrw_browse_split
       endif
      unlet g:netrw_browse_split
     endif
     let g:netrw_browse_split= [g:netrw_servername,1,1]
    endif

   else
    call netrw#ErrorMsg(s:ERROR,"you need a gui-capable vim and client-server to use <ctrl-r>",98)
   endif

"  call Dret("s:NetrwServerEdit")
endfun

" ---------------------------------------------------------------------
" s:NetrwSLeftmouse: marks the file under the cursor.  May be dragged to select additional files {{{2
fun! s:NetrwSLeftmouse(islocal)
  if &ft != "netrw"
   return
  endif
"  call Dfunc("s:NetrwSLeftmouse(islocal=".a:islocal.")")

  let s:ngw= s:NetrwGetWord()
  call s:NetrwMarkFile(a:islocal,s:ngw)

"  call Dret("s:NetrwSLeftmouse")
endfun

" ---------------------------------------------------------------------
" s:NetrwSLeftdrag: invoked via a shift-leftmouse and dragging {{{2
"                   Used to mark multiple files.
fun! s:NetrwSLeftdrag(islocal)
"  call Dfunc("s:NetrwSLeftdrag(islocal=".a:islocal.")")
  if !exists("s:netrwdrag")
   let s:netrwdrag = winnr()
   if a:islocal
    nno <silent> <s-leftrelease> <leftmouse>:<c-u>call <SID>NetrwSLeftrelease(1)<cr>
   else
    nno <silent> <s-leftrelease> <leftmouse>:<c-u>call <SID>NetrwSLeftrelease(0)<cr>
   endif
  endif
  let ngw = s:NetrwGetWord()
  if !exists("s:ngw") || s:ngw != ngw
   call s:NetrwMarkFile(a:islocal,ngw)
  endif
  let s:ngw= ngw
"  call Dret("s:NetrwSLeftdrag : s:netrwdrag=".s:netrwdrag." buf#".bufnr("%"))
endfun

" ---------------------------------------------------------------------
" s:NetrwSLeftrelease: terminates shift-leftmouse dragging {{{2
fun! s:NetrwSLeftrelease(islocal)
"  call Dfunc("s:NetrwSLeftrelease(islocal=".a:islocal.") s:netrwdrag=".s:netrwdrag." buf#".bufnr("%"))
  if exists("s:netrwdrag")
   nunmap <s-leftrelease>
   let ngw = s:NetrwGetWord()
   if !exists("s:ngw") || s:ngw != ngw
    call s:NetrwMarkFile(a:islocal,ngw)
   endif
   if exists("s:ngw")
    unlet s:ngw
   endif
   unlet s:netrwdrag
  endif
"  call Dret("s:NetrwSLeftrelease")
endfun

" ---------------------------------------------------------------------
" s:NetrwListHide: uses [range]g~...~d to delete files that match       {{{2
"                  comma-separated patterns given in g:netrw_list_hide
fun! s:NetrwListHide()
"  call Dfunc("s:NetrwListHide() g:netrw_hide=".g:netrw_hide." g:netrw_list_hide<".g:netrw_list_hide.">")
"  call Decho("initial: ".string(getline(w:netrw_bannercnt,'$')))
  let ykeep= @@

  " find a character not in the "hide" string to use as a separator for :g and :v commands
  " How-it-works: take the hiding command, convert it into a range.
  " Duplicate characters don't matter.
  " Remove all such characters from the '/~@#...890' string.
  " Use the first character left as a separator character.
"  call Decho("find a character not in the hide string to use as a separator",'~'.expand("<slnum>"))
  let listhide= g:netrw_list_hide
  let sep     = strpart(substitute('~@#$%^&*{};:,<.>?|1234567890','['.escape(listhide,'-]^\').']','','ge'),1,1)
"  call Decho("sep<".sep.">  (sep not in hide string)",'~'.expand("<slnum>"))

  while listhide != ""
   if listhide =~ ','
    let hide     = substitute(listhide,',.*$','','e')
    let listhide = substitute(listhide,'^.\{-},\(.*\)$','\1','e')
   else
    let hide     = listhide
    let listhide = ""
   endif
"   call Decho("..extracted pattern from listhide: hide<".hide."> g:netrw_sort_by<".g:netrw_sort_by.'>','~'.expand("<slnum>"))
   if g:netrw_sort_by =~ '^[ts]'
    if hide =~ '^\^'
"     call Decho("..modify hide to handle a \"^...\" pattern",'~'.expand("<slnum>"))
     let hide= substitute(hide,'^\^','^\(\\d\\+/\)','')
    elseif hide =~ '^\\(\^'
     let hide= substitute(hide,'^\\(\^','\\(^\\(\\d\\+/\\)','')
    endif
"    call Decho("..hide<".hide."> listhide<".listhide.'>','~'.expand("<slnum>"))
   endif

   " Prune the list by hiding any files which match
"   call Decho("..prune the list by hiding any files which ".((g:netrw_hide == 1)? "" : "don't")."match hide<".hide.">")
   if g:netrw_hide == 1
"    call Decho("..hiding<".hide.">",'~'.expand("<slnum>"))
    exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$g'.sep.hide.sep.'d'
   elseif g:netrw_hide == 2
"    call Decho("..showing<".hide.">",'~'.expand("<slnum>"))
    exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$g'.sep.hide.sep.'s@^@ /-KEEP-/ @'
   endif
"   call Decho("..result: ".string(getline(w:netrw_bannercnt,'$')),'~'.expand("<slnum>"))
  endwhile

  if g:netrw_hide == 2
   exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$v@^ /-KEEP-/ @d'
"   call Decho("..v KEEP: ".string(getline(w:netrw_bannercnt,'$')),'~'.expand("<slnum>"))
   exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s@^\%( /-KEEP-/ \)\+@@e'
"   call Decho("..g KEEP: ".string(getline(w:netrw_bannercnt,'$')),'~'.expand("<slnum>"))
  endif

  " remove any blank lines that have somehow remained.
  " This seems to happen under Windows.
  exe 'sil! NetrwKeepj 1,$g@^\s*$@d'

  let @@= ykeep
"  call Dret("s:NetrwListHide")
endfun

" ---------------------------------------------------------------------
" s:NetrwMakeDir: this function makes a directory (both local and remote) {{{2
"                 implements the "d" mapping.
fun! s:NetrwMakeDir(usrhost)
"  call Dfunc("s:NetrwMakeDir(usrhost<".a:usrhost.">)")

  let ykeep= @@
  " get name of new directory from user.  A bare <CR> will skip.
  " if its currently a directory, also request will be skipped, but with
  " a message.
  call inputsave()
  let newdirname= input("Please give directory name: ")
  call inputrestore()
"  call Decho("newdirname<".newdirname.">",'~'.expand("<slnum>"))

  if newdirname == ""
   let @@= ykeep
"   call Dret("s:NetrwMakeDir : user aborted with bare <cr>")
   return
  endif

  if a:usrhost == ""
"   call Decho("local mkdir",'~'.expand("<slnum>"))

   " Local mkdir:
   " sanity checks
   let fullnewdir= b:netrw_curdir.'/'.newdirname
"   call Decho("fullnewdir<".fullnewdir.">",'~'.expand("<slnum>"))
   if isdirectory(s:NetrwFile(fullnewdir))
    if !exists("g:netrw_quiet")
     NetrwKeepj call netrw#ErrorMsg(s:WARNING,"<".newdirname."> is already a directory!",24)
    endif
    let @@= ykeep
"    call Dret("s:NetrwMakeDir : directory<".newdirname."> exists previously")
    return
   endif
   if s:FileReadable(fullnewdir)
    if !exists("g:netrw_quiet")
     NetrwKeepj call netrw#ErrorMsg(s:WARNING,"<".newdirname."> is already a file!",25)
    endif
    let @@= ykeep
"    call Dret("s:NetrwMakeDir : file<".newdirname."> exists previously")
    return
   endif

   " requested new local directory is neither a pre-existing file or
   " directory, so make it!
   if exists("*mkdir")
    if has("unix")
     call mkdir(fullnewdir,"p",xor(0777, system("umask")))
    else
     call mkdir(fullnewdir,"p")
    endif
   else
    let netrw_origdir= s:NetrwGetcwd(1)
    if s:NetrwLcd(b:netrw_curdir)
"    call Dret("s:NetrwMakeDir : lcd failure")
     return
    endif
"    call Decho("netrw_origdir<".netrw_origdir.">: lcd b:netrw_curdir<".fnameescape(b:netrw_curdir).">",'~'.expand("<slnum>"))
    call s:NetrwExe("sil! !".g:netrw_localmkdir.g:netrw_localmkdiropt.' '.s:ShellEscape(newdirname,1))
    if v:shell_error != 0
     let @@= ykeep
     call netrw#ErrorMsg(s:ERROR,"consider setting g:netrw_localmkdir<".g:netrw_localmkdir."> to something that works",80)
"     call Dret("s:NetrwMakeDir : failed: sil! !".g:netrw_localmkdir.' '.s:ShellEscape(newdirname,1))
     return
    endif
    if !g:netrw_keepdir
"     call Decho("restoring netrw_origdir since g:netrw_keepdir=".g:netrw_keepdir,'~'.expand("<slnum>"))
     if s:NetrwLcd(netrw_origdir)
"     call Dret("s:NetrwBrowse : lcd failure")
      return
     endif
    endif
   endif

   if v:shell_error == 0
    " refresh listing
"    call Decho("refresh listing",'~'.expand("<slnum>"))
    let svpos= winsaveview()
"    call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
    call s:NetrwRefresh(1,s:NetrwBrowseChgDir(1,'./'))
"    call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
    call winrestview(svpos)
   elseif !exists("g:netrw_quiet")
    call netrw#ErrorMsg(s:ERROR,"unable to make directory<".newdirname.">",26)
   endif
"   redraw!

  elseif !exists("b:netrw_method") || b:netrw_method == 4
   " Remote mkdir:  using ssh
"   call Decho("remote mkdir",'~'.expand("<slnum>"))
   let mkdircmd  = s:MakeSshCmd(g:netrw_mkdir_cmd)
   let newdirname= substitute(b:netrw_curdir,'^\%(.\{-}/\)\{3}\(.*\)$','\1','').newdirname
   call s:NetrwExe("sil! !".mkdircmd." ".s:ShellEscape(newdirname,1))
   if v:shell_error == 0
    " refresh listing
    let svpos= winsaveview()
"    call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./'))
"    call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
    NetrwKeepj call winrestview(svpos)
   elseif !exists("g:netrw_quiet")
    NetrwKeepj call netrw#ErrorMsg(s:ERROR,"unable to make directory<".newdirname.">",27)
   endif
"   redraw!

  elseif b:netrw_method == 2
   " Remote mkdir:  using ftp+.netrc
   let svpos= winsaveview()
"   call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
"   call Decho("b:netrw_curdir<".b:netrw_curdir.">",'~'.expand("<slnum>"))
   if exists("b:netrw_fname")
"    call Decho("b:netrw_fname<".b:netrw_fname.">",'~'.expand("<slnum>"))
    let remotepath= b:netrw_fname
   else
    let remotepath= ""
   endif
   call s:NetrwRemoteFtpCmd(remotepath,g:netrw_remote_mkdir.' "'.newdirname.'"')
   NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./'))
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(svpos)

  elseif b:netrw_method == 3
   " Remote mkdir: using ftp + machine, id, passwd, and fname (ie. no .netrc)
   let svpos= winsaveview()
"   call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
"   call Decho("b:netrw_curdir<".b:netrw_curdir.">",'~'.expand("<slnum>"))
   if exists("b:netrw_fname")
"    call Decho("b:netrw_fname<".b:netrw_fname.">",'~'.expand("<slnum>"))
    let remotepath= b:netrw_fname
   else
    let remotepath= ""
   endif
   call s:NetrwRemoteFtpCmd(remotepath,g:netrw_remote_mkdir.' "'.newdirname.'"')
   NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./'))
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(svpos)
  endif

  let @@= ykeep
"  call Dret("s:NetrwMakeDir")
endfun

" ---------------------------------------------------------------------
" s:TreeSqueezeDir: allows a shift-cr (gvim only) to squeeze the current tree-listing directory {{{2
fun! s:TreeSqueezeDir(islocal)
"  call Dfunc("s:TreeSqueezeDir(islocal=".a:islocal.")")
  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
   " its a tree-listing style
   let curdepth = substitute(getline('.'),'^\(\%('.s:treedepthstring.'\)*\)[^'.s:treedepthstring.'].\{-}$','\1','e')
   let stopline = (exists("w:netrw_bannercnt")? (w:netrw_bannercnt + 1) : 1)
   let depth    = strchars(substitute(curdepth,' ','','g'))
   let srch     = -1
"   call Decho("curdepth<".curdepth.'>','~'.expand("<slnum>"))
"   call Decho("depth   =".depth,'~'.expand("<slnum>"))
"   call Decho("stopline#".stopline,'~'.expand("<slnum>"))
"   call Decho("curline#".line(".")."<".getline('.').'>','~'.expand("<slnum>"))
   if depth >= 2
    NetrwKeepj norm! 0
    let curdepthm1= substitute(curdepth,'^'.s:treedepthstring,'','')
    let srch      = search('^'.curdepthm1.'\%('.s:treedepthstring.'\)\@!','bW',stopline)
"    call Decho("curdepthm1<".curdepthm1.'>','~'.expand("<slnum>"))
"    call Decho("case depth>=2: srch<".srch.'>','~'.expand("<slnum>"))
   elseif depth == 1
    NetrwKeepj norm! 0
    let treedepthchr= substitute(s:treedepthstring,' ','','')
    let srch        = search('^[^'.treedepthchr.']','bW',stopline)
"    call Decho("case depth==1: srch<".srch.'>','~'.expand("<slnum>"))
   endif
   if srch > 0
"    call Decho("squeezing at line#".line(".").": ".getline('.'),'~'.expand("<slnum>"))
    call s:NetrwBrowse(a:islocal,s:NetrwBrowseChgDir(a:islocal,s:NetrwGetWord()))
    exe srch
   endif
  endif
"  call Dret("s:TreeSqueezeDir")
endfun

" ---------------------------------------------------------------------
" s:NetrwMaps: {{{2
fun! s:NetrwMaps(islocal)
"  call Dfunc("s:NetrwMaps(islocal=".a:islocal.") b:netrw_curdir<".b:netrw_curdir.">")

  " mouse <Plug> maps: {{{3
  if g:netrw_mousemaps && g:netrw_retmap
"   call Decho("set up Rexplore 2-leftmouse",'~'.expand("<slnum>"))
   if !hasmapto("<Plug>NetrwReturn")
    if maparg("<2-leftmouse>","n") == "" || maparg("<2-leftmouse>","n") =~ '^-$'
"     call Decho("making map for 2-leftmouse",'~'.expand("<slnum>"))
     nmap <unique> <silent> <2-leftmouse>	<Plug>NetrwReturn
    elseif maparg("<c-leftmouse>","n") == ""
"     call Decho("making map for c-leftmouse",'~'.expand("<slnum>"))
     nmap <unique> <silent> <c-leftmouse>	<Plug>NetrwReturn
    endif
   endif
   nno <silent> <Plug>NetrwReturn	:Rexplore<cr>
"   call Decho("made <Plug>NetrwReturn map",'~'.expand("<slnum>"))
  endif

  " generate default <Plug> maps {{{3
  if !hasmapto('<Plug>NetrwHide')              |nmap <buffer> <silent> <nowait> a	<Plug>NetrwHide_a|endif
  if !hasmapto('<Plug>NetrwBrowseUpDir')       |nmap <buffer> <silent> <nowait> -	<Plug>NetrwBrowseUpDir|endif
  if !hasmapto('<Plug>NetrwOpenFile')          |nmap <buffer> <silent> <nowait> %	<Plug>NetrwOpenFile|endif
  if !hasmapto('<Plug>NetrwBadd_cb')           |nmap <buffer> <silent> <nowait> cb	<Plug>NetrwBadd_cb|endif
  if !hasmapto('<Plug>NetrwBadd_cB')           |nmap <buffer> <silent> <nowait> cB	<Plug>NetrwBadd_cB|endif
  if !hasmapto('<Plug>NetrwLcd')               |nmap <buffer> <silent> <nowait> cd	<Plug>NetrwLcd|endif
  if !hasmapto('<Plug>NetrwSetChgwin')         |nmap <buffer> <silent> <nowait> C	<Plug>NetrwSetChgwin|endif
  if !hasmapto('<Plug>NetrwRefresh')           |nmap <buffer> <silent> <nowait> <c-l>	<Plug>NetrwRefresh|endif
  if !hasmapto('<Plug>NetrwLocalBrowseCheck')  |nmap <buffer> <silent> <nowait> <cr>	<Plug>NetrwLocalBrowseCheck|endif
  if !hasmapto('<Plug>NetrwServerEdit')        |nmap <buffer> <silent> <nowait> <c-r>	<Plug>NetrwServerEdit|endif
  if !hasmapto('<Plug>NetrwMakeDir')           |nmap <buffer> <silent> <nowait> d	<Plug>NetrwMakeDir|endif
  if !hasmapto('<Plug>NetrwBookHistHandler_gb')|nmap <buffer> <silent> <nowait> gb	<Plug>NetrwBookHistHandler_gb|endif
" ---------------------------------------------------------------------
"  if !hasmapto('<Plug>NetrwForceChgDir')       |nmap <buffer> <silent> <nowait> gd	<Plug>NetrwForceChgDir|endif
"  if !hasmapto('<Plug>NetrwForceFile')         |nmap <buffer> <silent> <nowait> gf	<Plug>NetrwForceFile|endif
"  if !hasmapto('<Plug>NetrwHidden')            |nmap <buffer> <silent> <nowait> gh	<Plug>NetrwHidden|endif
"  if !hasmapto('<Plug>NetrwSetTreetop')        |nmap <buffer> <silent> <nowait> gn	<Plug>NetrwSetTreetop|endif
"  if !hasmapto('<Plug>NetrwChgPerm')           |nmap <buffer> <silent> <nowait> gp	<Plug>NetrwChgPerm|endif
"  if !hasmapto('<Plug>NetrwBannerCtrl')        |nmap <buffer> <silent> <nowait> I	<Plug>NetrwBannerCtrl|endif
"  if !hasmapto('<Plug>NetrwListStyle')         |nmap <buffer> <silent> <nowait> i	<Plug>NetrwListStyle|endif
"  if !hasmapto('<Plug>NetrwMarkMoveMF2Arglist')|nmap <buffer> <silent> <nowait> ma	<Plug>NetrwMarkMoveMF2Arglist|endif
"  if !hasmapto('<Plug>NetrwMarkMoveArglist2MF')|nmap <buffer> <silent> <nowait> mA	<Plug>NetrwMarkMoveArglist2MF|endif
"  if !hasmapto('<Plug>NetrwBookHistHandler_mA')|nmap <buffer> <silent> <nowait> mb	<Plug>NetrwBookHistHandler_mA|endif
"  if !hasmapto('<Plug>NetrwBookHistHandler_mB')|nmap <buffer> <silent> <nowait> mB	<Plug>NetrwBookHistHandler_mB|endif
"  if !hasmapto('<Plug>NetrwMarkFileCopy')      |nmap <buffer> <silent> <nowait> mc	<Plug>NetrwMarkFileCopy|endif
"  if !hasmapto('<Plug>NetrwMarkFileDiff')      |nmap <buffer> <silent> <nowait> md	<Plug>NetrwMarkFileDiff|endif
"  if !hasmapto('<Plug>NetrwMarkFileEdit')      |nmap <buffer> <silent> <nowait> me	<Plug>NetrwMarkFileEdit|endif
"  if !hasmapto('<Plug>NetrwMarkFile')          |nmap <buffer> <silent> <nowait> mf	<Plug>NetrwMarkFile|endif
"  if !hasmapto('<Plug>NetrwUnmarkList')        |nmap <buffer> <silent> <nowait> mF	<Plug>NetrwUnmarkList|endif
"  if !hasmapto('<Plug>NetrwMarkFileGrep')      |nmap <buffer> <silent> <nowait> mg	<Plug>NetrwMarkFileGrep|endif
"  if !hasmapto('<Plug>NetrwMarkHideSfx')       |nmap <buffer> <silent> <nowait> mh	<Plug>NetrwMarkHideSfx|endif
"  if !hasmapto('<Plug>NetrwMarkFileMove')      |nmap <buffer> <silent> <nowait> mm	<Plug>NetrwMarkFileMove|endif
"  if !hasmapto('<Plug>NetrwMarkFileRegexp')    |nmap <buffer> <silent> <nowait> mr	<Plug>NetrwMarkFileRegexp|endif
"  if !hasmapto('<Plug>NetrwMarkFileSource')    |nmap <buffer> <silent> <nowait> ms	<Plug>NetrwMarkFileSource|endif
"  if !hasmapto('<Plug>NetrwMarkFileTag')       |nmap <buffer> <silent> <nowait> mT	<Plug>NetrwMarkFileTag|endif
"  if !hasmapto('<Plug>NetrwMarkFileTgt')       |nmap <buffer> <silent> <nowait> mt	<Plug>NetrwMarkFileTgt|endif
"  if !hasmapto('<Plug>NetrwUnMarkFile')        |nmap <buffer> <silent> <nowait> mu	<Plug>NetrwUnMarkFile|endif
"  if !hasmapto('<Plug>NetrwMarkFileVimCmd')    |nmap <buffer> <silent> <nowait> mv	<Plug>NetrwMarkFileVimCmd|endif
"  if !hasmapto('<Plug>NetrwMarkFileExe_mx')    |nmap <buffer> <silent> <nowait> mx	<Plug>NetrwMarkFileExe_mx|endif
"  if !hasmapto('<Plug>NetrwMarkFileExe_mX')    |nmap <buffer> <silent> <nowait> mX	<Plug>NetrwMarkFileExe_mX|endif
"  if !hasmapto('<Plug>NetrwMarkFileCompress')  |nmap <buffer> <silent> <nowait> mz	<Plug>NetrwMarkFileCompress|endif
"  if !hasmapto('<Plug>NetrwObtain')            |nmap <buffer> <silent> <nowait> O	<Plug>NetrwObtain|endif
"  if !hasmapto('<Plug>NetrwSplit_o')           |nmap <buffer> <silent> <nowait> o	<Plug>NetrwSplit_o|endif
"  if !hasmapto('<Plug>NetrwPreview')           |nmap <buffer> <silent> <nowait> p	<Plug>NetrwPreview|endif
"  if !hasmapto('<Plug>NetrwPrevWinOpen')       |nmap <buffer> <silent> <nowait> P	<Plug>NetrwPrevWinOpen|endif
"  if !hasmapto('<Plug>NetrwBookHistHandler_qb')|nmap <buffer> <silent> <nowait> qb	<Plug>NetrwBookHistHandler_qb|endif
"  if !hasmapto('<Plug>NetrwFileInfo')          |nmap <buffer> <silent> <nowait> qf	<Plug>NetrwFileInfo|endif
"  if !hasmapto('<Plug>NetrwMarkFileQFEL_qF')   |nmap <buffer> <silent> <nowait> qF	<Plug>NetrwMarkFileQFEL_qF|endif
"  if !hasmapto('<Plug>NetrwMarkFileQFEL_qL')   |nmap <buffer> <silent> <nowait> qL	<Plug>NetrwMarkFileQFEL_qL|endif
"  if !hasmapto('<Plug>NetrwSortStyle')         |nmap <buffer> <silent> <nowait> s	<Plug>NetrwSortStyle|endif
"  if !hasmapto('<Plug>NetSortSequence')        |nmap <buffer> <silent> <nowait> S	<Plug>NetSortSequence|endif
"  if !hasmapto('<Plug>NetrwSetTgt_Tb')         |nmap <buffer> <silent> <nowait> Tb	<Plug>NetrwSetTgt_Tb|endif
"  if !hasmapto('<Plug>NetrwSetTgt_Th')         |nmap <buffer> <silent> <nowait> Th	<Plug>NetrwSetTgt_Th|endif
"  if !hasmapto('<Plug>NetrwSplit_t')           |nmap <buffer> <silent> <nowait> t	<Plug>NetrwSplit_t|endif
"  if !hasmapto('<Plug>NetrwBookHistHandler_u') |nmap <buffer> <silent> <nowait> u	<Plug>NetrwBookHistHandler_u|endif
"  if !hasmapto('<Plug>NetrwBookHistHandler_U') |nmap <buffer> <silent> <nowait> U	<Plug>NetrwBookHistHandler_U|endif
"  if !hasmapto('<Plug>NetrwSplit_v')           |nmap <buffer> <silent> <nowait> v	<Plug>NetrwSplit_v|endif
"  if !hasmapto('<Plug>NetrwBrowseX')           |nmap <buffer> <silent> <nowait> x	<Plug>NetrwBrowseX|endif
"  if !hasmapto('<Plug>NetrwLocalExecute')      |nmap <buffer> <silent> <nowait> X	<Plug>NetrwLocalExecute|endif

  if a:islocal
"   call Decho("make local maps",'~'.expand("<slnum>"))
   " local normal-mode maps {{{3
   nnoremap <buffer> <silent> <Plug>NetrwHide_a			:<c-u>call <SID>NetrwHide(1)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwBrowseUpDir		:<c-u>call <SID>NetrwBrowseUpDir(1)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwOpenFile		:<c-u>call <SID>NetrwOpenFile(1)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwBadd_cb		:<c-u>call <SID>NetrwBadd(1,0)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwBadd_cB		:<c-u>call <SID>NetrwBadd(1,1)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwLcd			:<c-u>call <SID>NetrwLcd(b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwSetChgwin		:<c-u>call <SID>NetrwSetChgwin()<cr>
   nnoremap <buffer> <silent> <Plug>NetrwLocalBrowseCheck	:<c-u>call netrw#LocalBrowseCheck(<SID>NetrwBrowseChgDir(1,<SID>NetrwGetWord()))<cr>
   nnoremap <buffer> <silent> <Plug>NetrwServerEdit		:<c-u>call <SID>NetrwServerEdit(3,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <Plug>NetrwMakeDir		:<c-u>call <SID>NetrwMakeDir("")<cr>
   nnoremap <buffer> <silent> <Plug>NetrwBookHistHandler_gb	:<c-u>call <SID>NetrwBookHistHandler(1,b:netrw_curdir)<cr>
" ---------------------------------------------------------------------
   nnoremap <buffer> <silent> <nowait> gd	:<c-u>call <SID>NetrwForceChgDir(1,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <nowait> gf	:<c-u>call <SID>NetrwForceFile(1,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <nowait> gh	:<c-u>call <SID>NetrwHidden(1)<cr>
   nnoremap <buffer> <silent> <nowait> gn	:<c-u>call netrw#SetTreetop(0,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <nowait> gp	:<c-u>call <SID>NetrwChgPerm(1,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> I	:<c-u>call <SID>NetrwBannerCtrl(1)<cr>
   nnoremap <buffer> <silent> <nowait> i	:<c-u>call <SID>NetrwListStyle(1)<cr>
   nnoremap <buffer> <silent> <nowait> ma	:<c-u>call <SID>NetrwMarkFileArgList(1,0)<cr>
   nnoremap <buffer> <silent> <nowait> mA	:<c-u>call <SID>NetrwMarkFileArgList(1,1)<cr>
   nnoremap <buffer> <silent> <nowait> mb	:<c-u>call <SID>NetrwBookHistHandler(0,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> mB	:<c-u>call <SID>NetrwBookHistHandler(6,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> mc	:<c-u>call <SID>NetrwMarkFileCopy(1)<cr>
   nnoremap <buffer> <silent> <nowait> md	:<c-u>call <SID>NetrwMarkFileDiff(1)<cr>
   nnoremap <buffer> <silent> <nowait> me	:<c-u>call <SID>NetrwMarkFileEdit(1)<cr>
   nnoremap <buffer> <silent> <nowait> mf	:<c-u>call <SID>NetrwMarkFile(1,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <nowait> mF	:<c-u>call <SID>NetrwUnmarkList(bufnr("%"),b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> mg	:<c-u>call <SID>NetrwMarkFileGrep(1)<cr>
   nnoremap <buffer> <silent> <nowait> mh	:<c-u>call <SID>NetrwMarkHideSfx(1)<cr>
   nnoremap <buffer> <silent> <nowait> mm	:<c-u>call <SID>NetrwMarkFileMove(1)<cr>
   nnoremap <buffer> <silent> <nowait> mr	:<c-u>call <SID>NetrwMarkFileRegexp(1)<cr>
   nnoremap <buffer> <silent> <nowait> ms	:<c-u>call <SID>NetrwMarkFileSource(1)<cr>
   nnoremap <buffer> <silent> <nowait> mT	:<c-u>call <SID>NetrwMarkFileTag(1)<cr>
   nnoremap <buffer> <silent> <nowait> mt	:<c-u>call <SID>NetrwMarkFileTgt(1)<cr>
   nnoremap <buffer> <silent> <nowait> mu	:<c-u>call <SID>NetrwUnMarkFile(1)<cr>
   nnoremap <buffer> <silent> <nowait> mv	:<c-u>call <SID>NetrwMarkFileVimCmd(1)<cr>
   nnoremap <buffer> <silent> <nowait> mx	:<c-u>call <SID>NetrwMarkFileExe(1,0)<cr>
   nnoremap <buffer> <silent> <nowait> mX	:<c-u>call <SID>NetrwMarkFileExe(1,1)<cr>
   nnoremap <buffer> <silent> <nowait> mz	:<c-u>call <SID>NetrwMarkFileCompress(1)<cr>
   nnoremap <buffer> <silent> <nowait> O	:<c-u>call <SID>NetrwObtain(1)<cr>
   nnoremap <buffer> <silent> <nowait> o	:call <SID>NetrwSplit(3)<cr>
   nnoremap <buffer> <silent> <nowait> p	:<c-u>call <SID>NetrwPreview(<SID>NetrwBrowseChgDir(1,<SID>NetrwGetWord(),1))<cr>
   nnoremap <buffer> <silent> <nowait> P	:<c-u>call <SID>NetrwPrevWinOpen(1)<cr>
   nnoremap <buffer> <silent> <nowait> qb	:<c-u>call <SID>NetrwBookHistHandler(2,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> qf	:<c-u>call <SID>NetrwFileInfo(1,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <nowait> qF	:<c-u>call <SID>NetrwMarkFileQFEL(1,getqflist())<cr>
   nnoremap <buffer> <silent> <nowait> qL	:<c-u>call <SID>NetrwMarkFileQFEL(1,getloclist(v:count))<cr>
   nnoremap <buffer> <silent> <nowait> s	:call <SID>NetrwSortStyle(1)<cr>
   nnoremap <buffer> <silent> <nowait> S	:<c-u>call <SID>NetSortSequence(1)<cr>
   nnoremap <buffer> <silent> <nowait> Tb	:<c-u>call <SID>NetrwSetTgt(1,'b',v:count1)<cr>
   nnoremap <buffer> <silent> <nowait> t	:call <SID>NetrwSplit(4)<cr>
   nnoremap <buffer> <silent> <nowait> Th	:<c-u>call <SID>NetrwSetTgt(1,'h',v:count)<cr>
   nnoremap <buffer> <silent> <nowait> u	:<c-u>call <SID>NetrwBookHistHandler(4,expand("%"))<cr>
   nnoremap <buffer> <silent> <nowait> U	:<c-u>call <SID>NetrwBookHistHandler(5,expand("%"))<cr>
   nnoremap <buffer> <silent> <nowait> v	:call <SID>NetrwSplit(5)<cr>
   nnoremap <buffer> <silent> <nowait> x	:<c-u>call netrw#BrowseX(<SID>NetrwBrowseChgDir(1,<SID>NetrwGetWord(),0),0)"<cr>
   nnoremap <buffer> <silent> <nowait> X	:<c-u>call <SID>NetrwLocalExecute(expand("<cword>"))"<cr>

   nnoremap <buffer> <silent> <nowait> r	:<c-u>let g:netrw_sort_direction= (g:netrw_sort_direction =~# 'n')? 'r' : 'n'<bar>exe "norm! 0"<bar>call <SID>NetrwRefresh(1,<SID>NetrwBrowseChgDir(1,'./'))<cr>
   if !hasmapto('<Plug>NetrwHideEdit')
    nmap <buffer> <unique> <c-h> <Plug>NetrwHideEdit
   endif
   nnoremap <buffer> <silent> <Plug>NetrwHideEdit		:call <SID>NetrwHideEdit(1)<cr>
   if !hasmapto('<Plug>NetrwRefresh')
    nmap <buffer> <unique> <c-l> <Plug>NetrwRefresh
   endif
   nnoremap <buffer> <silent> <Plug>NetrwRefresh		<c-l>:call <SID>NetrwRefresh(1,<SID>NetrwBrowseChgDir(1,(exists("w:netrw_liststyle") && exists("w:netrw_treetop") && w:netrw_liststyle == 3)? w:netrw_treetop : './'))<cr>
   if s:didstarstar || !mapcheck("<s-down>","n")
    nnoremap <buffer> <silent> <s-down>	:Nexplore<cr>
   endif
   if s:didstarstar || !mapcheck("<s-up>","n")
    nnoremap <buffer> <silent> <s-up>	:Pexplore<cr>
   endif
   if !hasmapto('<Plug>NetrwTreeSqueeze')
    nmap <buffer> <silent> <nowait> <s-cr>			<Plug>NetrwTreeSqueeze
   endif
   nnoremap <buffer> <silent> <Plug>NetrwTreeSqueeze		:call <SID>TreeSqueezeDir(1)<cr>
   let mapsafecurdir = escape(b:netrw_curdir, s:netrw_map_escape)
   if g:netrw_mousemaps == 1
    nmap <buffer>			<leftmouse>   		<Plug>NetrwLeftmouse
    nmap <buffer>			<c-leftmouse>		<Plug>NetrwCLeftmouse
    nmap <buffer>			<middlemouse>		<Plug>NetrwMiddlemouse
    nmap <buffer>			<s-leftmouse>		<Plug>NetrwSLeftmouse
    nmap <buffer>			<s-leftdrag>		<Plug>NetrwSLeftdrag
    nmap <buffer>			<2-leftmouse>		<Plug>Netrw2Leftmouse
    imap <buffer>			<leftmouse>		<Plug>ILeftmouse
    imap <buffer>			<middlemouse>		<Plug>IMiddlemouse
    nno  <buffer> <silent>		<Plug>NetrwLeftmouse	:exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwLeftmouse(1)<cr>
    nno  <buffer> <silent>		<Plug>NetrwCLeftmouse	:exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwCLeftmouse(1)<cr>
    nno  <buffer> <silent>		<Plug>NetrwMiddlemouse	:exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwPrevWinOpen(1)<cr>
    nno  <buffer> <silent>		<Plug>NetrwSLeftmouse 	:exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwSLeftmouse(1)<cr>
    nno  <buffer> <silent>		<Plug>NetrwSLeftdrag	:exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwSLeftdrag(1)<cr>
    nmap <buffer> <silent>		<Plug>Netrw2Leftmouse	-
    exe 'nnoremap <buffer> <silent> <rightmouse>  :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
    exe 'vnoremap <buffer> <silent> <rightmouse>  :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
   endif
   exe 'nnoremap <buffer> <silent> <nowait> <del>	:call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
   exe 'nnoremap <buffer> <silent> <nowait> D		:call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
   exe 'nnoremap <buffer> <silent> <nowait> R		:call <SID>NetrwLocalRename("'.mapsafecurdir.'")<cr>'
   exe 'nnoremap <buffer> <silent> <nowait> d		:call <SID>NetrwMakeDir("")<cr>'
   exe 'vnoremap <buffer> <silent> <nowait> <del>	:call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
   exe 'vnoremap <buffer> <silent> <nowait> D		:call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
   exe 'vnoremap <buffer> <silent> <nowait> R		:call <SID>NetrwLocalRename("'.mapsafecurdir.'")<cr>'
   nnoremap <buffer> <F1>			:he netrw-quickhelp<cr>

   " support user-specified maps
   call netrw#UserMaps(1)

  else
   " remote normal-mode maps {{{3
"   call Decho("make remote maps",'~'.expand("<slnum>"))
   call s:RemotePathAnalysis(b:netrw_curdir)
   nnoremap <buffer> <silent> <Plug>NetrwHide_a			:<c-u>call <SID>NetrwHide(0)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwBrowseUpDir		:<c-u>call <SID>NetrwBrowseUpDir(0)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwOpenFile		:<c-u>call <SID>NetrwOpenFile(0)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwBadd_cb		:<c-u>call <SID>NetrwBadd(0,0)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwBadd_cB		:<c-u>call <SID>NetrwBadd(0,1)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwLcd			:<c-u>call <SID>NetrwLcd(b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <Plug>NetrwSetChgwin		:<c-u>call <SID>NetrwSetChgwin()<cr>
   nnoremap <buffer> <silent> <Plug>NetrwRefresh		:<c-u>call <SID>NetrwRefresh(0,<SID>NetrwBrowseChgDir(0,'./'))<cr>
   nnoremap <buffer> <silent> <Plug>NetrwLocalBrowseCheck	:<c-u>call <SID>NetrwBrowse(0,<SID>NetrwBrowseChgDir(0,<SID>NetrwGetWord()))<cr>
   nnoremap <buffer> <silent> <Plug>NetrwServerEdit		:<c-u>call <SID>NetrwServerEdit(2,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <Plug>NetrwBookHistHandler_gb	:<c-u>call <SID>NetrwBookHistHandler(1,b:netrw_curdir)<cr>
" ---------------------------------------------------------------------
   nnoremap <buffer> <silent> <nowait> gd	:<c-u>call <SID>NetrwForceChgDir(0,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <nowait> gf	:<c-u>call <SID>NetrwForceFile(0,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <nowait> gh	:<c-u>call <SID>NetrwHidden(0)<cr>
   nnoremap <buffer> <silent> <nowait> gp	:<c-u>call <SID>NetrwChgPerm(0,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> I	:<c-u>call <SID>NetrwBannerCtrl(1)<cr>
   nnoremap <buffer> <silent> <nowait> i	:<c-u>call <SID>NetrwListStyle(0)<cr>
   nnoremap <buffer> <silent> <nowait> ma	:<c-u>call <SID>NetrwMarkFileArgList(0,0)<cr>
   nnoremap <buffer> <silent> <nowait> mA	:<c-u>call <SID>NetrwMarkFileArgList(0,1)<cr>
   nnoremap <buffer> <silent> <nowait> mb	:<c-u>call <SID>NetrwBookHistHandler(0,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> mB	:<c-u>call <SID>NetrwBookHistHandler(6,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> mc	:<c-u>call <SID>NetrwMarkFileCopy(0)<cr>
   nnoremap <buffer> <silent> <nowait> md	:<c-u>call <SID>NetrwMarkFileDiff(0)<cr>
   nnoremap <buffer> <silent> <nowait> me	:<c-u>call <SID>NetrwMarkFileEdit(0)<cr>
   nnoremap <buffer> <silent> <nowait> mf	:<c-u>call <SID>NetrwMarkFile(0,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <nowait> mF	:<c-u>call <SID>NetrwUnmarkList(bufnr("%"),b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> mg	:<c-u>call <SID>NetrwMarkFileGrep(0)<cr>
   nnoremap <buffer> <silent> <nowait> mh	:<c-u>call <SID>NetrwMarkHideSfx(0)<cr>
   nnoremap <buffer> <silent> <nowait> mm	:<c-u>call <SID>NetrwMarkFileMove(0)<cr>
   nnoremap <buffer> <silent> <nowait> mr	:<c-u>call <SID>NetrwMarkFileRegexp(0)<cr>
   nnoremap <buffer> <silent> <nowait> ms	:<c-u>call <SID>NetrwMarkFileSource(0)<cr>
   nnoremap <buffer> <silent> <nowait> mT	:<c-u>call <SID>NetrwMarkFileTag(0)<cr>
   nnoremap <buffer> <silent> <nowait> mt	:<c-u>call <SID>NetrwMarkFileTgt(0)<cr>
   nnoremap <buffer> <silent> <nowait> mu	:<c-u>call <SID>NetrwUnMarkFile(0)<cr>
   nnoremap <buffer> <silent> <nowait> mv	:<c-u>call <SID>NetrwMarkFileVimCmd(0)<cr>
   nnoremap <buffer> <silent> <nowait> mx	:<c-u>call <SID>NetrwMarkFileExe(0,0)<cr>
   nnoremap <buffer> <silent> <nowait> mX	:<c-u>call <SID>NetrwMarkFileExe(0,1)<cr>
   nnoremap <buffer> <silent> <nowait> mz	:<c-u>call <SID>NetrwMarkFileCompress(0)<cr>
   nnoremap <buffer> <silent> <nowait> O	:<c-u>call <SID>NetrwObtain(0)<cr>
   nnoremap <buffer> <silent> <nowait> o	:call <SID>NetrwSplit(0)<cr>
   nnoremap <buffer> <silent> <nowait> p	:<c-u>call <SID>NetrwPreview(<SID>NetrwBrowseChgDir(1,<SID>NetrwGetWord(),1))<cr>
   nnoremap <buffer> <silent> <nowait> P	:<c-u>call <SID>NetrwPrevWinOpen(0)<cr>
   nnoremap <buffer> <silent> <nowait> qb	:<c-u>call <SID>NetrwBookHistHandler(2,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> qf	:<c-u>call <SID>NetrwFileInfo(0,<SID>NetrwGetWord())<cr>
   nnoremap <buffer> <silent> <nowait> qF	:<c-u>call <SID>NetrwMarkFileQFEL(0,getqflist())<cr>
   nnoremap <buffer> <silent> <nowait> qL	:<c-u>call <SID>NetrwMarkFileQFEL(0,getloclist(v:count))<cr>
   nnoremap <buffer> <silent> <nowait> r	:<c-u>let g:netrw_sort_direction= (g:netrw_sort_direction =~# 'n')? 'r' : 'n'<bar>exe "norm! 0"<bar>call <SID>NetrwBrowse(0,<SID>NetrwBrowseChgDir(0,'./'))<cr>
   nnoremap <buffer> <silent> <nowait> s	:call <SID>NetrwSortStyle(0)<cr>
   nnoremap <buffer> <silent> <nowait> S	:<c-u>call <SID>NetSortSequence(0)<cr>
   nnoremap <buffer> <silent> <nowait> Tb	:<c-u>call <SID>NetrwSetTgt(0,'b',v:count1)<cr>
   nnoremap <buffer> <silent> <nowait> t	:call <SID>NetrwSplit(1)<cr>
   nnoremap <buffer> <silent> <nowait> Th	:<c-u>call <SID>NetrwSetTgt(0,'h',v:count)<cr>
   nnoremap <buffer> <silent> <nowait> u	:<c-u>call <SID>NetrwBookHistHandler(4,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> U	:<c-u>call <SID>NetrwBookHistHandler(5,b:netrw_curdir)<cr>
   nnoremap <buffer> <silent> <nowait> v	:call <SID>NetrwSplit(2)<cr>
   nnoremap <buffer> <silent> <nowait> x	:<c-u>call netrw#BrowseX(<SID>NetrwBrowseChgDir(0,<SID>NetrwGetWord()),1)<cr>
   if !hasmapto('<Plug>NetrwHideEdit')
    nmap <buffer> <c-h> <Plug>NetrwHideEdit
   endif
   nnoremap <buffer> <silent> <Plug>NetrwHideEdit	:call <SID>NetrwHideEdit(0)<cr>
   if !hasmapto('<Plug>NetrwRefresh')
    nmap <buffer> <c-l> <Plug>NetrwRefresh
   endif
   if !hasmapto('<Plug>NetrwTreeSqueeze')
    nmap <buffer> <silent> <nowait> <s-cr>	<Plug>NetrwTreeSqueeze
   endif
   nnoremap <buffer> <silent> <Plug>NetrwTreeSqueeze	:call <SID>TreeSqueezeDir(0)<cr>

   let mapsafepath     = escape(s:path, s:netrw_map_escape)
   let mapsafeusermach = escape(((s:user == "")? "" : s:user."@").s:machine, s:netrw_map_escape)

   nnoremap <buffer> <silent> <Plug>NetrwRefresh	:call <SID>NetrwRefresh(0,<SID>NetrwBrowseChgDir(0,'./'))<cr>
   if g:netrw_mousemaps == 1
    nmap <buffer> <leftmouse>		<Plug>NetrwLeftmouse
    nno  <buffer> <silent>		<Plug>NetrwLeftmouse	:exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwLeftmouse(0)<cr>
    nmap <buffer> <c-leftmouse>		<Plug>NetrwCLeftmouse
    nno  <buffer> <silent>		<Plug>NetrwCLeftmouse	:exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwCLeftmouse(0)<cr>
    nmap <buffer> <s-leftmouse>		<Plug>NetrwSLeftmouse
    nno  <buffer> <silent>		<Plug>NetrwSLeftmouse 	:exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwSLeftmouse(0)<cr>
    nmap <buffer> <s-leftdrag>		<Plug>NetrwSLeftdrag
    nno  <buffer> <silent>		<Plug>NetrwSLeftdrag	:exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwSLeftdrag(0)<cr>
    nmap <middlemouse>			<Plug>NetrwMiddlemouse
    nno  <buffer> <silent>		<middlemouse>		<Plug>NetrwMiddlemouse :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwPrevWinOpen(0)<cr>
    nmap <buffer> <2-leftmouse>		<Plug>Netrw2Leftmouse
    nmap <buffer> <silent>		<Plug>Netrw2Leftmouse	-
    imap <buffer> <leftmouse>		<Plug>ILeftmouse
    imap <buffer> <middlemouse>		<Plug>IMiddlemouse
    imap <buffer> <s-leftmouse>		<Plug>ISLeftmouse
    exe 'nnoremap <buffer> <silent> <rightmouse> :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
    exe 'vnoremap <buffer> <silent> <rightmouse> :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
   endif
   exe 'nnoremap <buffer> <silent> <nowait> <del>	:call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
   exe 'nnoremap <buffer> <silent> <nowait> d		:call <SID>NetrwMakeDir("'.mapsafeusermach.'")<cr>'
   exe 'nnoremap <buffer> <silent> <nowait> D		:call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
   exe 'nnoremap <buffer> <silent> <nowait> R		:call <SID>NetrwRemoteRename("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
   exe 'vnoremap <buffer> <silent> <nowait> <del>	:call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
   exe 'vnoremap <buffer> <silent> <nowait> D		:call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
   exe 'vnoremap <buffer> <silent> <nowait> R		:call <SID>NetrwRemoteRename("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
   nnoremap <buffer> <F1>			:he netrw-quickhelp<cr>

   " support user-specified maps
   call netrw#UserMaps(0)
  endif " }}}3

"  call Dret("s:NetrwMaps")
endfun

" ---------------------------------------------------------------------
" s:NetrwCommands: set up commands 				{{{2
"  If -buffer, the command is only available from within netrw buffers
"  Otherwise, the command is available from any window, so long as netrw
"  has been used at least once in the session.
fun! s:NetrwCommands(islocal)
"  call Dfunc("s:NetrwCommands(islocal=".a:islocal.")")

  com! -nargs=* -complete=file -bang	NetrwMB	call s:NetrwBookmark(<bang>0,<f-args>)
  com! -nargs=*			    	NetrwC	call s:NetrwSetChgwin(<q-args>)
  com! Rexplore if exists("w:netrw_rexlocal")|call s:NetrwRexplore(w:netrw_rexlocal,exists("w:netrw_rexdir")? w:netrw_rexdir : ".")|else|call netrw#ErrorMsg(s:WARNING,"win#".winnr()." not a former netrw window",79)|endif
  if a:islocal
   com! -buffer -nargs=+ -complete=file	MF	call s:NetrwMarkFiles(1,<f-args>)
  else
   com! -buffer -nargs=+ -complete=file	MF	call s:NetrwMarkFiles(0,<f-args>)
  endif
  com! -buffer -nargs=? -complete=file	MT	call s:NetrwMarkTarget(<q-args>)

"  call Dret("s:NetrwCommands")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFiles: apply s:NetrwMarkFile() to named file(s) {{{2
"                   glob()ing only works with local files
fun! s:NetrwMarkFiles(islocal,...)
"  call Dfunc("s:NetrwMarkFiles(islocal=".a:islocal."...) a:0=".a:0)
  let curdir = s:NetrwGetCurdir(a:islocal)
  let i      = 1
  while i <= a:0
   if a:islocal
    if v:version > 704 || (v:version == 704 && has("patch656"))
     let mffiles= glob(a:{i},0,1,1)
    else
     let mffiles= glob(a:{i},0,1)
    endif
   else
    let mffiles= [a:{i}]
   endif
"   call Decho("mffiles".string(mffiles),'~'.expand("<slnum>"))
   for mffile in mffiles
"    call Decho("mffile<".mffile.">",'~'.expand("<slnum>"))
    call s:NetrwMarkFile(a:islocal,mffile)
   endfor
   let i= i + 1
  endwhile
"  call Dret("s:NetrwMarkFiles")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkTarget: implements :MT (mark target) {{{2
fun! s:NetrwMarkTarget(...)
"  call Dfunc("s:NetrwMarkTarget() a:0=".a:0)
  if a:0 == 0 || (a:0 == 1 && a:1 == "")
   let curdir = s:NetrwGetCurdir(1)
   let tgt    = b:netrw_curdir
  else
   let curdir = s:NetrwGetCurdir((a:1 =~ '^\a\{3,}://')? 0 : 1)
   let tgt    = a:1
  endif
"  call Decho("tgt<".tgt.">",'~'.expand("<slnum>"))
  let s:netrwmftgt         = tgt
  let s:netrwmftgt_islocal = tgt !~ '^\a\{3,}://'
  let curislocal           = b:netrw_curdir !~ '^\a\{3,}://'
  let svpos                = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  call s:NetrwRefresh(curislocal,s:NetrwBrowseChgDir(curislocal,'./'))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  call winrestview(svpos)
"  call Dret("s:NetrwMarkTarget")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFile: (invoked by mf) This function is used to both {{{2
"                  mark and unmark files.  If a markfile list exists,
"                  then the rename and delete functions will use it instead
"                  of whatever may happen to be under the cursor at that
"                  moment.  When the mouse and gui are available,
"                  shift-leftmouse may also be used to mark files.
"
"  Creates two lists
"    s:netrwmarkfilelist    -- holds complete paths to all marked files
"    s:netrwmarkfilelist_#  -- holds list of marked files in current-buffer's directory (#==bufnr())
"
"  Creates a marked file match string
"    s:netrwmarfilemtch_#   -- used with 2match to display marked files
"
"  Creates a buffer version of islocal
"    b:netrw_islocal
fun! s:NetrwMarkFile(islocal,fname)
"  call Dfunc("s:NetrwMarkFile(islocal=".a:islocal." fname<".a:fname.">)")
"  call Decho("bufnr(%)=".bufnr("%").": ".bufname("%"),'~'.expand("<slnum>"))

  " sanity check
  if empty(a:fname)
"   call Dret("s:NetrwMarkFile : empty fname")
   return
  endif
  let curdir = s:NetrwGetCurdir(a:islocal)

  let ykeep   = @@
  let curbufnr= bufnr("%")
  if a:fname =~ '^\a'
   let leader= '\<'
  else
   let leader= ''
  endif
  if a:fname =~ '\a$'
   let trailer = '\>[@=|\/\*]\=\ze\%(  \|\t\|$\)'
  else
   let trailer = '[@=|\/\*]\=\ze\%(  \|\t\|$\)'
  endif

  if exists("s:netrwmarkfilelist_".curbufnr)
   " markfile list pre-exists
"   call Decho("case s:netrwmarkfilelist_".curbufnr." already exists",'~'.expand("<slnum>"))
"   call Decho("starting s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}).">",'~'.expand("<slnum>"))
"   call Decho("starting s:netrwmarkfilemtch_".curbufnr."<".s:netrwmarkfilemtch_{curbufnr}.">",'~'.expand("<slnum>"))
   let b:netrw_islocal= a:islocal

   if index(s:netrwmarkfilelist_{curbufnr},a:fname) == -1
    " append filename to buffer's markfilelist
"    call Decho("append filename<".a:fname."> to local markfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}).">",'~'.expand("<slnum>"))
    call add(s:netrwmarkfilelist_{curbufnr},a:fname)
    let s:netrwmarkfilemtch_{curbufnr}= s:netrwmarkfilemtch_{curbufnr}.'\|'.leader.escape(a:fname,g:netrw_markfileesc).trailer

   else
    " remove filename from buffer's markfilelist
"    call Decho("remove filename<".a:fname."> from local markfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}).">",'~'.expand("<slnum>"))
    call filter(s:netrwmarkfilelist_{curbufnr},'v:val != a:fname')
    if s:netrwmarkfilelist_{curbufnr} == []
     " local markfilelist is empty; remove it entirely
"     call Decho("markfile list now empty",'~'.expand("<slnum>"))
     call s:NetrwUnmarkList(curbufnr,curdir)
    else
     " rebuild match list to display markings correctly
"     call Decho("rebuild s:netrwmarkfilemtch_".curbufnr,'~'.expand("<slnum>"))
     let s:netrwmarkfilemtch_{curbufnr}= ""
     let first                         = 1
     for fname in s:netrwmarkfilelist_{curbufnr}
      if first
       let s:netrwmarkfilemtch_{curbufnr}= s:netrwmarkfilemtch_{curbufnr}.leader.escape(fname,g:netrw_markfileesc).trailer
      else
       let s:netrwmarkfilemtch_{curbufnr}= s:netrwmarkfilemtch_{curbufnr}.'\|'.leader.escape(fname,g:netrw_markfileesc).trailer
      endif
      let first= 0
     endfor
"     call Decho("ending s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}).">",'~'.expand("<slnum>"))
    endif
   endif

  else
   " initialize new markfilelist
"   call Decho("case: initialize new markfilelist",'~'.expand("<slnum>"))

"   call Decho("add fname<".a:fname."> to new markfilelist_".curbufnr,'~'.expand("<slnum>"))
   let s:netrwmarkfilelist_{curbufnr}= []
   call add(s:netrwmarkfilelist_{curbufnr},substitute(a:fname,'[|@]$','',''))
"   call Decho("ending s:netrwmarkfilelist_{curbufnr}<".string(s:netrwmarkfilelist_{curbufnr}).">",'~'.expand("<slnum>"))

   " build initial markfile matching pattern
   if a:fname =~ '/$'
    let s:netrwmarkfilemtch_{curbufnr}= leader.escape(a:fname,g:netrw_markfileesc)
   else
    let s:netrwmarkfilemtch_{curbufnr}= leader.escape(a:fname,g:netrw_markfileesc).trailer
   endif
"   call Decho("ending s:netrwmarkfilemtch_".curbufnr."<".s:netrwmarkfilemtch_{curbufnr}.">",'~'.expand("<slnum>"))
  endif

  " handle global markfilelist
  if exists("s:netrwmarkfilelist")
   let dname= s:ComposePath(b:netrw_curdir,a:fname)
   if index(s:netrwmarkfilelist,dname) == -1
    " append new filename to global markfilelist
    call add(s:netrwmarkfilelist,s:ComposePath(b:netrw_curdir,a:fname))
"    call Decho("append filename<".a:fname."> to global s:markfilelist<".string(s:netrwmarkfilelist).">",'~'.expand("<slnum>"))
   else
    " remove new filename from global markfilelist
"    call Decho("remove new filename from global s:markfilelist",'~'.expand("<slnum>"))
"    call Decho("..filter(".string(s:netrwmarkfilelist).",'v:val != '.".dname.")",'~'.expand("<slnum>"))
    call filter(s:netrwmarkfilelist,'v:val != "'.dname.'"')
"    call Decho("..ending s:netrwmarkfilelist  <".string(s:netrwmarkfilelist).">",'~'.expand("<slnum>"))
    if s:netrwmarkfilelist == []
"     call Decho("s:netrwmarkfilelist is empty; unlet it",'~'.expand("<slnum>"))
     unlet s:netrwmarkfilelist
    endif
   endif
  else
   " initialize new global-directory markfilelist
   let s:netrwmarkfilelist= []
   call add(s:netrwmarkfilelist,s:ComposePath(b:netrw_curdir,a:fname))
"   call Decho("init s:netrwmarkfilelist<".string(s:netrwmarkfilelist).">",'~'.expand("<slnum>"))
  endif

  " set up 2match'ing to netrwmarkfilemtch_# list
  if has("syntax") && exists("g:syntax_on") && g:syntax_on
   if exists("s:netrwmarkfilemtch_{curbufnr}") && s:netrwmarkfilemtch_{curbufnr} != ""
" "   call Decho("exe 2match netrwMarkFile /".s:netrwmarkfilemtch_{curbufnr}."/",'~'.expand("<slnum>"))
    if exists("g:did_drchip_netrwlist_syntax")
     exe "2match netrwMarkFile /".s:netrwmarkfilemtch_{curbufnr}."/"
    endif
   else
" "   call Decho("2match none",'~'.expand("<slnum>"))
    2match none
   endif
  endif
  let @@= ykeep
"  call Decho("s:netrwmarkfilelist[".(exists("s:netrwmarkfilelist")? string(s:netrwmarkfilelist) : "")."] (avail in all buffers)",'~'.expand("<slnum>"))
"  call Dret("s:NetrwMarkFile : s:netrwmarkfilelist_".curbufnr."<".(exists("s:netrwmarkfilelist_{curbufnr}")? string(s:netrwmarkfilelist_{curbufnr}) : " doesn't exist").">  (buf#".curbufnr."list)")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileArgList: ma: move the marked file list to the argument list (tomflist=0) {{{2
"                         mA: move the argument list to marked file list     (tomflist=1)
"                            Uses the global marked file list
fun! s:NetrwMarkFileArgList(islocal,tomflist)
"  call Dfunc("s:NetrwMarkFileArgList(islocal=".a:islocal.",tomflist=".a:tomflist.")")

  let svpos    = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curdir   = s:NetrwGetCurdir(a:islocal)
  let curbufnr = bufnr("%")

  if a:tomflist
   " mA: move argument list to marked file list
   while argc()
    let fname= argv(0)
"    call Decho("exe argdel ".fname,'~'.expand("<slnum>"))
    exe "argdel ".fnameescape(fname)
    call s:NetrwMarkFile(a:islocal,fname)
   endwhile

  else
   " ma: move marked file list to argument list
   if exists("s:netrwmarkfilelist")

    " for every filename in the marked list
    for fname in s:netrwmarkfilelist
"     call Decho("exe argadd ".fname,'~'.expand("<slnum>"))
     exe "argadd ".fnameescape(fname)
    endfor	" for every file in the marked list

    " unmark list and refresh
    call s:NetrwUnmarkList(curbufnr,curdir)
    NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"    call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
    NetrwKeepj call winrestview(svpos)
   endif
  endif

"  call Dret("s:NetrwMarkFileArgList")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileCompress: (invoked by mz) This function is used to {{{2
"                          compress/decompress files using the programs
"                          in g:netrw_compress and g:netrw_uncompress,
"                          using g:netrw_compress_suffix to know which to
"                          do.  By default:
"                            g:netrw_compress        = "gzip"
"                            g:netrw_decompress      = { ".gz" : "gunzip" , ".bz2" : "bunzip2" , ".zip" : "unzip" , ".tar" : "tar -xf", ".xz" : "unxz"}
fun! s:NetrwMarkFileCompress(islocal)
"  call Dfunc("s:NetrwMarkFileCompress(islocal=".a:islocal.")")
  let svpos    = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curdir   = s:NetrwGetCurdir(a:islocal)
  let curbufnr = bufnr("%")

  " sanity check
  if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
   NetrwKeepj call netrw#ErrorMsg(2,"there are no marked files in this window (:help netrw-mf)",66)
"   call Dret("s:NetrwMarkFileCompress")
   return
  endif
"  call Decho("sanity chk passed: s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}),'~'.expand("<slnum>"))

  if exists("s:netrwmarkfilelist_{curbufnr}") && exists("g:netrw_compress") && exists("g:netrw_decompress")

   " for every filename in the marked list
   for fname in s:netrwmarkfilelist_{curbufnr}
    let sfx= substitute(fname,'^.\{-}\(\.\a\+\)$','\1','')
"    call Decho("extracted sfx<".sfx.">",'~'.expand("<slnum>"))
    if exists("g:netrw_decompress['".sfx."']")
     " fname has a suffix indicating that its compressed; apply associated decompression routine
     let exe= g:netrw_decompress[sfx]
"     call Decho("fname<".fname."> is compressed so decompress with <".exe.">",'~'.expand("<slnum>"))
     let exe= netrw#WinPath(exe)
     if a:islocal
      if g:netrw_keepdir
       let fname= s:ShellEscape(s:ComposePath(curdir,fname))
      endif
      call system(exe." ".fname)
      if v:shell_error
       NetrwKeepj call netrw#ErrorMsg(s:WARNING,"unable to apply<".exe."> to file<".fname.">",50)
      endif
     else
      let fname= s:ShellEscape(b:netrw_curdir.fname,1)
      NetrwKeepj call s:RemoteSystem(exe." ".fname)
     endif

    endif
    unlet sfx

    if exists("exe")
     unlet exe
    elseif a:islocal
     " fname not a compressed file, so compress it
     call system(netrw#WinPath(g:netrw_compress)." ".s:ShellEscape(s:ComposePath(b:netrw_curdir,fname)))
     if v:shell_error
      call netrw#ErrorMsg(s:WARNING,"consider setting g:netrw_compress<".g:netrw_compress."> to something that works",104)
     endif
    else
     " fname not a compressed file, so compress it
     NetrwKeepj call s:RemoteSystem(netrw#WinPath(g:netrw_compress)." ".s:ShellEscape(fname))
    endif
   endfor	" for every file in the marked list

   call s:NetrwUnmarkList(curbufnr,curdir)
   NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(svpos)
  endif
"  call Dret("s:NetrwMarkFileCompress")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileCopy: (invoked by mc) copy marked files to target {{{2
"                      If no marked files, then set up directory as the
"                      target.  Currently does not support copying entire
"                      directories.  Uses the local-buffer marked file list.
"                      Returns 1=success  (used by NetrwMarkFileMove())
"                              0=failure
fun! s:NetrwMarkFileCopy(islocal,...)
"  call Dfunc("s:NetrwMarkFileCopy(islocal=".a:islocal.") target<".(exists("s:netrwmftgt")? s:netrwmftgt : '---')."> a:0=".a:0)

  let curdir   = s:NetrwGetCurdir(a:islocal)
  let curbufnr = bufnr("%")
  if b:netrw_curdir !~ '/$'
   if !exists("b:netrw_curdir")
    let b:netrw_curdir= curdir
   endif
   let b:netrw_curdir= b:netrw_curdir."/"
  endif

  " sanity check
  if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
   NetrwKeepj call netrw#ErrorMsg(2,"there are no marked files in this window (:help netrw-mf)",66)
"   call Dret("s:NetrwMarkFileCopy")
   return
  endif
"  call Decho("sanity chk passed: s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}),'~'.expand("<slnum>"))

  if !exists("s:netrwmftgt")
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"your marked file target is empty! (:help netrw-mt)",67)
"   call Dret("s:NetrwMarkFileCopy 0")
   return 0
  endif
"  call Decho("sanity chk passed: s:netrwmftgt<".s:netrwmftgt.">",'~'.expand("<slnum>"))

  if a:islocal &&  s:netrwmftgt_islocal
   " Copy marked files, local directory to local directory
"   call Decho("copy from local to local",'~'.expand("<slnum>"))
   if !executable(g:netrw_localcopycmd)
    call netrw#ErrorMsg(s:ERROR,"g:netrw_localcopycmd<".g:netrw_localcopycmd."> not executable on your system, aborting",91)
"    call Dfunc("s:NetrwMarkFileMove : g:netrw_localcopycmd<".g:netrw_localcopycmd."> n/a!")
    return
   endif

   " copy marked files while within the same directory (ie. allow renaming)
   if s:StripTrailingSlash(simplify(s:netrwmftgt)) == s:StripTrailingSlash(simplify(b:netrw_curdir))
    if len(s:netrwmarkfilelist_{bufnr('%')}) == 1
     " only one marked file
"     call Decho("case: only one marked file",'~'.expand("<slnum>"))
     let args    = s:ShellEscape(b:netrw_curdir.s:netrwmarkfilelist_{bufnr('%')}[0])
     let oldname = s:netrwmarkfilelist_{bufnr('%')}[0]
    elseif a:0 == 1
"     call Decho("case: handling one input argument",'~'.expand("<slnum>"))
     " this happens when the next case was used to recursively call s:NetrwMarkFileCopy()
     let args    = s:ShellEscape(b:netrw_curdir.a:1)
     let oldname = a:1
    else
     " copy multiple marked files inside the same directory
"     call Decho("case: handling a multiple marked files",'~'.expand("<slnum>"))
     let s:recursive= 1
     for oldname in s:netrwmarkfilelist_{bufnr("%")}
      let ret= s:NetrwMarkFileCopy(a:islocal,oldname)
      if ret == 0
       break
      endif
     endfor
     unlet s:recursive
     call s:NetrwUnmarkList(curbufnr,curdir)
"     call Dret("s:NetrwMarkFileCopy ".ret)
     return ret
    endif

    call inputsave()
    let newname= input("Copy ".oldname." to : ",oldname,"file")
    call inputrestore()
    if newname == ""
"     call Dret("s:NetrwMarkFileCopy 0")
     return 0
    endif
    let args= s:ShellEscape(oldname)
    let tgt = s:ShellEscape(s:netrwmftgt.'/'.newname)
   else
    let args= join(map(deepcopy(s:netrwmarkfilelist_{bufnr('%')}),"s:ShellEscape(b:netrw_curdir.\"/\".v:val)"))
    let tgt = s:ShellEscape(s:netrwmftgt)
   endif
   if !g:netrw_cygwin && has("win32")
    let args= substitute(args,'/','\\','g')
    let tgt = substitute(tgt, '/','\\','g')
   endif
   if args =~ "'" |let args= substitute(args,"'\\(.*\\)'",'\1','')|endif
   if tgt  =~ "'" |let tgt = substitute(tgt ,"'\\(.*\\)'",'\1','')|endif
   if args =~ '//'|let args= substitute(args,'//','/','g')|endif
   if tgt  =~ '//'|let tgt = substitute(tgt ,'//','/','g')|endif
"   call Decho("args   <".args.">",'~'.expand("<slnum>"))
"   call Decho("tgt    <".tgt.">",'~'.expand("<slnum>"))
   if isdirectory(s:NetrwFile(args))
"    call Decho("args<".args."> is a directory",'~'.expand("<slnum>"))
    let copycmd= g:netrw_localcopydircmd
"    call Decho("using copydircmd<".copycmd.">",'~'.expand("<slnum>"))
    if !g:netrw_cygwin && has("win32")
     " window's xcopy doesn't copy a directory to a target properly.  Instead, it copies a directory's
     " contents to a target.  One must append the source directory name to the target to get xcopy to
     " do the right thing.
     let tgt= tgt.'\'.substitute(a:1,'^.*[\\/]','','')
"     call Decho("modified tgt for xcopy",'~'.expand("<slnum>"))
    endif
   else
    let copycmd= g:netrw_localcopycmd
   endif
   if g:netrw_localcopycmd =~ '\s'
    let copycmd     = substitute(copycmd,'\s.*$','','')
    let copycmdargs = substitute(copycmd,'^.\{-}\(\s.*\)$','\1','')
    let copycmd     = netrw#WinPath(copycmd).copycmdargs
   else
    let copycmd = netrw#WinPath(copycmd)
   endif
"   call Decho("args   <".args.">",'~'.expand("<slnum>"))
"   call Decho("tgt    <".tgt.">",'~'.expand("<slnum>"))
"   call Decho("copycmd<".copycmd.">",'~'.expand("<slnum>"))
"   call Decho("system(".copycmd." '".args."' '".tgt."')",'~'.expand("<slnum>"))
   call system(copycmd.g:netrw_localcopycmdopt." '".args."' '".tgt."'")
   if v:shell_error != 0
    if exists("b:netrw_curdir") && b:netrw_curdir != getcwd() && g:netrw_keepdir
     call netrw#ErrorMsg(s:ERROR,"copy failed; perhaps due to vim's current directory<".getcwd()."> not matching netrw's (".b:netrw_curdir.") (see :help netrw-cd)",101)
    else
     call netrw#ErrorMsg(s:ERROR,"tried using g:netrw_localcopycmd<".g:netrw_localcopycmd.">; it doesn't work!",80)
    endif
"    call Dret("s:NetrwMarkFileCopy 0 : failed: system(".g:netrw_localcopycmd." ".args." ".s:ShellEscape(s:netrwmftgt))
    return 0
   endif

  elseif  a:islocal && !s:netrwmftgt_islocal
   " Copy marked files, local directory to remote directory
"   call Decho("copy from local to remote",'~'.expand("<slnum>"))
   NetrwKeepj call s:NetrwUpload(s:netrwmarkfilelist_{bufnr('%')},s:netrwmftgt)

  elseif !a:islocal &&  s:netrwmftgt_islocal
   " Copy marked files, remote directory to local directory
"   call Decho("copy from remote to local",'~'.expand("<slnum>"))
   NetrwKeepj call netrw#Obtain(a:islocal,s:netrwmarkfilelist_{bufnr('%')},s:netrwmftgt)

  elseif !a:islocal && !s:netrwmftgt_islocal
   " Copy marked files, remote directory to remote directory
"   call Decho("copy from remote to remote",'~'.expand("<slnum>"))
   let curdir = getcwd()
   let tmpdir = s:GetTempfile("")
   if tmpdir !~ '/'
    let tmpdir= curdir."/".tmpdir
   endif
   if exists("*mkdir")
    call mkdir(tmpdir)
   else
    call s:NetrwExe("sil! !".g:netrw_localmkdir.g:netrw_localmkdiropt.' '.s:ShellEscape(tmpdir,1))
    if v:shell_error != 0
     call netrw#ErrorMsg(s:WARNING,"consider setting g:netrw_localmkdir<".g:netrw_localmkdir."> to something that works",80)
"     call Dret("s:NetrwMarkFileCopy : failed: sil! !".g:netrw_localmkdir.' '.s:ShellEscape(tmpdir,1) )
     return
    endif
   endif
   if isdirectory(s:NetrwFile(tmpdir))
    if s:NetrwLcd(tmpdir)
"     call Dret("s:NetrwMarkFileCopy : lcd failure")
     return
    endif
    NetrwKeepj call netrw#Obtain(a:islocal,s:netrwmarkfilelist_{bufnr('%')},tmpdir)
    let localfiles= map(deepcopy(s:netrwmarkfilelist_{bufnr('%')}),'substitute(v:val,"^.*/","","")')
    NetrwKeepj call s:NetrwUpload(localfiles,s:netrwmftgt)
    if getcwd() == tmpdir
     for fname in s:netrwmarkfilelist_{bufnr('%')}
      NetrwKeepj call s:NetrwDelete(fname)
     endfor
     if s:NetrwLcd(curdir)
"      call Dret("s:NetrwMarkFileCopy : lcd failure")
      return
     endif
     if delete(tmpdir,"d")
      call netrw#ErrorMsg(s:ERROR,"unable to delete directory <".tmpdir.">!",103)
     endif
    else
     if s:NetrwLcd(curdir)
"      call Dret("s:NetrwMarkFileCopy : lcd failure")
      return
     endif
    endif
   endif
  endif

  " -------
  " cleanup
  " -------
"  call Decho("cleanup",'~'.expand("<slnum>"))
  " remove markings from local buffer
  call s:NetrwUnmarkList(curbufnr,curdir)                   " remove markings from local buffer
"  call Decho(" g:netrw_fastbrowse  =".g:netrw_fastbrowse,'~'.expand("<slnum>"))
"  call Decho(" s:netrwmftgt        =".s:netrwmftgt,'~'.expand("<slnum>"))
"  call Decho(" s:netrwmftgt_islocal=".s:netrwmftgt_islocal,'~'.expand("<slnum>"))
"  call Decho(" curdir              =".curdir,'~'.expand("<slnum>"))
"  call Decho(" a:islocal           =".a:islocal,'~'.expand("<slnum>"))
"  call Decho(" curbufnr            =".curbufnr,'~'.expand("<slnum>"))
  if exists("s:recursive")
"   call Decho(" s:recursive         =".s:recursive,'~'.expand("<slnum>"))
  else
"   call Decho(" s:recursive         =n/a",'~'.expand("<slnum>"))
  endif
  " see s:LocalFastBrowser() for g:netrw_fastbrowse interpretation (refreshing done for both slow and medium)
  if g:netrw_fastbrowse <= 1
   NetrwKeepj call s:LocalBrowseRefresh()
  else
   " refresh local and targets for fast browsing
   if !exists("s:recursive")
    " remove markings from local buffer
"    call Decho(" remove markings from local buffer",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwUnmarkList(curbufnr,curdir)
   endif

   " refresh buffers
   if s:netrwmftgt_islocal
"    call Decho(" refresh s:netrwmftgt=".s:netrwmftgt,'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwRefreshDir(s:netrwmftgt_islocal,s:netrwmftgt)
   endif
   if a:islocal && s:netrwmftgt != curdir
"    call Decho(" refresh curdir=".curdir,'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwRefreshDir(a:islocal,curdir)
   endif
  endif

"  call Dret("s:NetrwMarkFileCopy 1")
  return 1
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileDiff: (invoked by md) This function is used to {{{2
"                      invoke vim's diff mode on the marked files.
"                      Either two or three files can be so handled.
"                      Uses the global marked file list.
fun! s:NetrwMarkFileDiff(islocal)
"  call Dfunc("s:NetrwMarkFileDiff(islocal=".a:islocal.") b:netrw_curdir<".b:netrw_curdir.">")
  let curbufnr= bufnr("%")

  " sanity check
  if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
   NetrwKeepj call netrw#ErrorMsg(2,"there are no marked files in this window (:help netrw-mf)",66)
"   call Dret("s:NetrwMarkFileDiff")
   return
  endif
  let curdir= s:NetrwGetCurdir(a:islocal)
"  call Decho("sanity chk passed: s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}),'~'.expand("<slnum>"))

  if exists("s:netrwmarkfilelist_{".curbufnr."}")
   let cnt    = 0
   for fname in s:netrwmarkfilelist
    let cnt= cnt + 1
    if cnt == 1
"     call Decho("diffthis: fname<".fname.">",'~'.expand("<slnum>"))
     exe "NetrwKeepj e ".fnameescape(fname)
     diffthis
    elseif cnt == 2 || cnt == 3
     below vsplit
"     call Decho("diffthis: ".fname,'~'.expand("<slnum>"))
     exe "NetrwKeepj e ".fnameescape(fname)
     diffthis
    else
     break
    endif
   endfor
   call s:NetrwUnmarkList(curbufnr,curdir)
  endif

"  call Dret("s:NetrwMarkFileDiff")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileEdit: (invoked by me) put marked files on arg list and start editing them {{{2
"                       Uses global markfilelist
fun! s:NetrwMarkFileEdit(islocal)
"  call Dfunc("s:NetrwMarkFileEdit(islocal=".a:islocal.")")

  let curdir   = s:NetrwGetCurdir(a:islocal)
  let curbufnr = bufnr("%")

  " sanity check
  if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
   NetrwKeepj call netrw#ErrorMsg(2,"there are no marked files in this window (:help netrw-mf)",66)
"   call Dret("s:NetrwMarkFileEdit")
   return
  endif
"  call Decho("sanity chk passed: s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}),'~'.expand("<slnum>"))

  if exists("s:netrwmarkfilelist_{curbufnr}")
   call s:SetRexDir(a:islocal,curdir)
   let flist= join(map(deepcopy(s:netrwmarkfilelist), "fnameescape(v:val)"))
   " unmark markedfile list
"   call s:NetrwUnmarkList(curbufnr,curdir)
   call s:NetrwUnmarkAll()
"   call Decho("exe sil args ".flist,'~'.expand("<slnum>"))
   exe "sil args ".flist
  endif
  echo "(use :bn, :bp to navigate files; :Rex to return)"

"  call Dret("s:NetrwMarkFileEdit")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileQFEL: convert a quickfix-error or location list into a marked file list {{{2
fun! s:NetrwMarkFileQFEL(islocal,qfel)
"  call Dfunc("s:NetrwMarkFileQFEL(islocal=".a:islocal.",qfel)")
  call s:NetrwUnmarkAll()
  let curbufnr= bufnr("%")

  if !empty(a:qfel)
   for entry in a:qfel
    let bufnmbr= entry["bufnr"]
"    call Decho("bufname(".bufnmbr.")<".bufname(bufnmbr)."> line#".entry["lnum"]." text=".entry["text"],'~'.expand("<slnum>"))
    if !exists("s:netrwmarkfilelist_{curbufnr}")
"     call Decho("case: no marked file list",'~'.expand("<slnum>"))
     call s:NetrwMarkFile(a:islocal,bufname(bufnmbr))
    elseif index(s:netrwmarkfilelist_{curbufnr},bufname(bufnmbr)) == -1
     " s:NetrwMarkFile will remove duplicate entries from the marked file list.
     " So, this test lets two or more hits on the same pattern to be ignored.
"     call Decho("case: ".bufname(bufnmbr)." not currently in marked file list",'~'.expand("<slnum>"))
     call s:NetrwMarkFile(a:islocal,bufname(bufnmbr))
    else
"     call Decho("case: ".bufname(bufnmbr)." already in marked file list",'~'.expand("<slnum>"))
    endif
   endfor
   echo "(use me to edit marked files)"
  else
   call netrw#ErrorMsg(s:WARNING,"can't convert quickfix error list; its empty!",92)
  endif

"  call Dret("s:NetrwMarkFileQFEL")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileExe: (invoked by mx and mX) execute arbitrary system command on marked files {{{2
"                     mx enbloc=0: Uses the local marked-file list, applies command to each file individually
"                     mX enbloc=1: Uses the global marked-file list, applies command to entire list
fun! s:NetrwMarkFileExe(islocal,enbloc)
"  call Dfunc("s:NetrwMarkFileExe(islocal=".a:islocal.",enbloc=".a:enbloc.")")
  let svpos    = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curdir   = s:NetrwGetCurdir(a:islocal)
  let curbufnr = bufnr("%")

  if a:enbloc == 0
   " individually apply command to files, one at a time
    " sanity check
    if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
     NetrwKeepj call netrw#ErrorMsg(2,"there are no marked files in this window (:help netrw-mf)",66)
"     call Dret("s:NetrwMarkFileExe")
     return
    endif
"    call Decho("sanity chk passed: s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}),'~'.expand("<slnum>"))

    if exists("s:netrwmarkfilelist_{curbufnr}")
     " get the command
     call inputsave()
     let cmd= input("Enter command: ","","file")
     call inputrestore()
"     call Decho("cmd<".cmd.">",'~'.expand("<slnum>"))
     if cmd == ""
"      call Dret("s:NetrwMarkFileExe : early exit, empty command")
      return
     endif

     " apply command to marked files, individually.  Substitute: filename -> %
     " If no %, then append a space and the filename to the command
     for fname in s:netrwmarkfilelist_{curbufnr}
      if a:islocal
       if g:netrw_keepdir
        let fname= s:ShellEscape(netrw#WinPath(s:ComposePath(curdir,fname)))
       endif
      else
       let fname= s:ShellEscape(netrw#WinPath(b:netrw_curdir.fname))
      endif
      if cmd =~ '%'
       let xcmd= substitute(cmd,'%',fname,'g')
      else
       let xcmd= cmd.' '.fname
      endif
      if a:islocal
"       call Decho("local: xcmd<".xcmd.">",'~'.expand("<slnum>"))
       let ret= system(xcmd)
      else
"       call Decho("remote: xcmd<".xcmd.">",'~'.expand("<slnum>"))
       let ret= s:RemoteSystem(xcmd)
      endif
      if v:shell_error < 0
       NetrwKeepj call netrw#ErrorMsg(s:ERROR,"command<".xcmd."> failed, aborting",54)
       break
      else
       echo ret
      endif
     endfor

   " unmark marked file list
   call s:NetrwUnmarkList(curbufnr,curdir)

   " refresh the listing
   NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(svpos)
  else
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"no files marked!",59)
  endif

 else " apply command to global list of files, en bloc

  call inputsave()
  let cmd= input("Enter command: ","","file")
  call inputrestore()
"  call Decho("cmd<".cmd.">",'~'.expand("<slnum>"))
  if cmd == ""
"   call Dret("s:NetrwMarkFileExe : early exit, empty command")
   return
  endif
  if cmd =~ '%'
   let cmd= substitute(cmd,'%',join(map(s:netrwmarkfilelist,'s:ShellEscape(v:val)'),' '),'g')
  else
   let cmd= cmd.' '.join(map(s:netrwmarkfilelist,'s:ShellEscape(v:val)'),' ')
  endif
  if a:islocal
   call system(cmd)
   if v:shell_error < 0
    NetrwKeepj call netrw#ErrorMsg(s:ERROR,"command<".xcmd."> failed, aborting",54)
   endif
  else
   let ret= s:RemoteSystem(cmd)
  endif
  call s:NetrwUnmarkAll()

  " refresh the listing
  NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)

 endif

"  call Dret("s:NetrwMarkFileExe")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkHideSfx: (invoked by mh) (un)hide files having same suffix
"                  as the marked file(s) (toggles suffix presence)
"                  Uses the local marked file list.
fun! s:NetrwMarkHideSfx(islocal)
"  call Dfunc("s:NetrwMarkHideSfx(islocal=".a:islocal.")")
  let svpos    = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curbufnr = bufnr("%")

  " s:netrwmarkfilelist_{curbufnr}: the List of marked files
  if exists("s:netrwmarkfilelist_{curbufnr}")

   for fname in s:netrwmarkfilelist_{curbufnr}
"     call Decho("s:NetrwMarkFileCopy: fname<".fname.">",'~'.expand("<slnum>"))
     " construct suffix pattern
     if fname =~ '\.'
      let sfxpat= "^.*".substitute(fname,'^.*\(\.[^. ]\+\)$','\1','')
     else
      let sfxpat= '^\%(\%(\.\)\@!.\)*$'
     endif
     " determine if its in the hiding list or not
     let inhidelist= 0
     if g:netrw_list_hide != ""
      let itemnum = 0
      let hidelist= split(g:netrw_list_hide,',')
      for hidepat in hidelist
       if sfxpat == hidepat
        let inhidelist= 1
        break
       endif
       let itemnum= itemnum + 1
      endfor
     endif
"     call Decho("fname<".fname."> inhidelist=".inhidelist." sfxpat<".sfxpat.">",'~'.expand("<slnum>"))
     if inhidelist
      " remove sfxpat from list
      call remove(hidelist,itemnum)
      let g:netrw_list_hide= join(hidelist,",")
     elseif g:netrw_list_hide != ""
      " append sfxpat to non-empty list
      let g:netrw_list_hide= g:netrw_list_hide.",".sfxpat
     else
      " set hiding list to sfxpat
      let g:netrw_list_hide= sfxpat
     endif
    endfor

   " refresh the listing
   NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(svpos)
  else
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"no files marked!",59)
  endif

"  call Dret("s:NetrwMarkHideSfx")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileVimCmd: (invoked by mv) execute arbitrary vim command on marked files, one at a time {{{2
"                     Uses the local marked-file list.
fun! s:NetrwMarkFileVimCmd(islocal)
"  call Dfunc("s:NetrwMarkFileVimCmd(islocal=".a:islocal.")")
  let svpos    = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curdir   = s:NetrwGetCurdir(a:islocal)
  let curbufnr = bufnr("%")

  " sanity check
  if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
   NetrwKeepj call netrw#ErrorMsg(2,"there are no marked files in this window (:help netrw-mf)",66)
"   call Dret("s:NetrwMarkFileVimCmd")
   return
  endif
"  call Decho("sanity chk passed: s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}),'~'.expand("<slnum>"))

  if exists("s:netrwmarkfilelist_{curbufnr}")
   " get the command
   call inputsave()
   let cmd= input("Enter vim command: ","","file")
   call inputrestore()
"   call Decho("cmd<".cmd.">",'~'.expand("<slnum>"))
   if cmd == ""
"    "   call Dret("s:NetrwMarkFileVimCmd : early exit, empty command")
    return
   endif

   " apply command to marked files.  Substitute: filename -> %
   " If no %, then append a space and the filename to the command
   for fname in s:netrwmarkfilelist_{curbufnr}
"    call Decho("fname<".fname.">",'~'.expand("<slnum>"))
    if a:islocal
     1split
     exe "sil! NetrwKeepj keepalt e ".fnameescape(fname)
"     call Decho("local<".fname.">: exe ".cmd,'~'.expand("<slnum>"))
     exe cmd
     exe "sil! keepalt wq!"
    else
"     call Decho("remote<".fname.">: exe ".cmd." : NOT SUPPORTED YET",'~'.expand("<slnum>"))
     echo "sorry, \"mv\" not supported yet for remote files"
    endif
   endfor

   " unmark marked file list
   call s:NetrwUnmarkList(curbufnr,curdir)

   " refresh the listing
   NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(svpos)
  else
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"no files marked!",59)
  endif

"  call Dret("s:NetrwMarkFileVimCmd")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkHideSfx: (invoked by mh) (un)hide files having same suffix
"                  as the marked file(s) (toggles suffix presence)
"                  Uses the local marked file list.
fun! s:NetrwMarkHideSfx(islocal)
"  call Dfunc("s:NetrwMarkHideSfx(islocal=".a:islocal.")")
  let svpos    = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curbufnr = bufnr("%")

  " s:netrwmarkfilelist_{curbufnr}: the List of marked files
  if exists("s:netrwmarkfilelist_{curbufnr}")

   for fname in s:netrwmarkfilelist_{curbufnr}
"     call Decho("s:NetrwMarkFileCopy: fname<".fname.">",'~'.expand("<slnum>"))
     " construct suffix pattern
     if fname =~ '\.'
      let sfxpat= "^.*".substitute(fname,'^.*\(\.[^. ]\+\)$','\1','')
     else
      let sfxpat= '^\%(\%(\.\)\@!.\)*$'
     endif
     " determine if its in the hiding list or not
     let inhidelist= 0
     if g:netrw_list_hide != ""
      let itemnum = 0
      let hidelist= split(g:netrw_list_hide,',')
      for hidepat in hidelist
       if sfxpat == hidepat
        let inhidelist= 1
        break
       endif
       let itemnum= itemnum + 1
      endfor
     endif
"     call Decho("fname<".fname."> inhidelist=".inhidelist." sfxpat<".sfxpat.">",'~'.expand("<slnum>"))
     if inhidelist
      " remove sfxpat from list
      call remove(hidelist,itemnum)
      let g:netrw_list_hide= join(hidelist,",")
     elseif g:netrw_list_hide != ""
      " append sfxpat to non-empty list
      let g:netrw_list_hide= g:netrw_list_hide.",".sfxpat
     else
      " set hiding list to sfxpat
      let g:netrw_list_hide= sfxpat
     endif
    endfor

   " refresh the listing
   NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(svpos)
  else
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"no files marked!",59)
  endif

"  call Dret("s:NetrwMarkHideSfx")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileGrep: (invoked by mg) This function applies vimgrep to marked files {{{2
"                     Uses the global markfilelist
fun! s:NetrwMarkFileGrep(islocal)
"  call Dfunc("s:NetrwMarkFileGrep(islocal=".a:islocal.")")
  let svpos    = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curbufnr = bufnr("%")
  let curdir   = s:NetrwGetCurdir(a:islocal)

  if exists("s:netrwmarkfilelist")
"   call Decho("using s:netrwmarkfilelist".string(s:netrwmarkfilelist).">",'~'.expand("<slnum>"))
   let netrwmarkfilelist= join(map(deepcopy(s:netrwmarkfilelist), "fnameescape(v:val)"))
"   call Decho("keeping copy of s:netrwmarkfilelist in function-local variable,'~'.expand("<slnum>"))"
   call s:NetrwUnmarkAll()
  else
"   call Decho('no marked files, using "*"','~'.expand("<slnum>"))
   let netrwmarkfilelist= "*"
  endif

  " ask user for pattern
"  call Decho("ask user for search pattern",'~'.expand("<slnum>"))
  call inputsave()
  let pat= input("Enter pattern: ","")
  call inputrestore()
  let patbang = ""
  if pat =~ '^!'
   let patbang = "!"
   let pat     = strpart(pat,2)
  endif
  if pat =~ '^\i'
   let pat    = escape(pat,'/')
   let pat    = '/'.pat.'/'
  else
   let nonisi = pat[0]
  endif

  " use vimgrep for both local and remote
"  call Decho("exe vimgrep".patbang." ".pat." ".netrwmarkfilelist,'~'.expand("<slnum>"))
  try
   exe "NetrwKeepj noautocmd vimgrep".patbang." ".pat." ".netrwmarkfilelist
  catch /^Vim\%((\a\+)\)\=:E480/
   NetrwKeepj call netrw#ErrorMsg(s:WARNING,"no match with pattern<".pat.">",76)
"   call Dret("s:NetrwMarkFileGrep : unable to find pattern<".pat.">")
   return
  endtry
  echo "(use :cn, :cp to navigate, :Rex to return)"

  2match none
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)

  if exists("nonisi")
   " original, user-supplied pattern did not begin with a character from isident
"   call Decho("looking for trailing nonisi<".nonisi."> followed by a j, gj, or jg",'~'.expand("<slnum>"))
   if pat =~# nonisi.'j$\|'.nonisi.'gj$\|'.nonisi.'jg$'
    call s:NetrwMarkFileQFEL(a:islocal,getqflist())
   endif
  endif

"  call Dret("s:NetrwMarkFileGrep")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileMove: (invoked by mm) execute arbitrary command on marked files, one at a time {{{2
"                      uses the global marked file list
"                      s:netrwmfloc= 0: target directory is remote
"                                  = 1: target directory is local
fun! s:NetrwMarkFileMove(islocal)
"  call Dfunc("s:NetrwMarkFileMove(islocal=".a:islocal.")")
  let curdir   = s:NetrwGetCurdir(a:islocal)
  let curbufnr = bufnr("%")

  " sanity check
  if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
   NetrwKeepj call netrw#ErrorMsg(2,"there are no marked files in this window (:help netrw-mf)",66)
"   call Dret("s:NetrwMarkFileMove")
   return
  endif
"  call Decho("sanity chk passed: s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}),'~'.expand("<slnum>"))

  if !exists("s:netrwmftgt")
   NetrwKeepj call netrw#ErrorMsg(2,"your marked file target is empty! (:help netrw-mt)",67)
"   call Dret("s:NetrwMarkFileCopy 0")
   return 0
  endif
"  call Decho("sanity chk passed: s:netrwmftgt<".s:netrwmftgt.">",'~'.expand("<slnum>"))

  if      a:islocal &&  s:netrwmftgt_islocal
   " move: local -> local
"   call Decho("move from local to local",'~'.expand("<slnum>"))
"   call Decho("local to local move",'~'.expand("<slnum>"))
   if !executable(g:netrw_localmovecmd)
    call netrw#ErrorMsg(s:ERROR,"g:netrw_localmovecmd<".g:netrw_localmovecmd."> not executable on your system, aborting",90)
"    call Dfunc("s:NetrwMarkFileMove : g:netrw_localmovecmd<".g:netrw_localmovecmd."> n/a!")
    return
   endif
   let tgt = s:ShellEscape(s:netrwmftgt)
"   call Decho("tgt<".tgt.">",'~'.expand("<slnum>"))
   if !g:netrw_cygwin && has("win32")
    let tgt= substitute(tgt, '/','\\','g')
"    call Decho("windows exception: tgt<".tgt.">",'~'.expand("<slnum>"))
    if g:netrw_localmovecmd =~ '\s'
     let movecmd     = substitute(g:netrw_localmovecmd,'\s.*$','','')
     let movecmdargs = substitute(g:netrw_localmovecmd,'^.\{-}\(\s.*\)$','\1','')
     let movecmd     = netrw#WinPath(movecmd).movecmdargs
"     call Decho("windows exception: movecmd<".movecmd."> (#1: had a space)",'~'.expand("<slnum>"))
    else
     let movecmd = netrw#WinPath(g:netrw_localmovecmd)
"     call Decho("windows exception: movecmd<".movecmd."> (#2: no space)",'~'.expand("<slnum>"))
    endif
   else
    let movecmd = netrw#WinPath(g:netrw_localmovecmd)
"    call Decho("movecmd<".movecmd."> (#3 linux or cygwin)",'~'.expand("<slnum>"))
   endif
   for fname in s:netrwmarkfilelist_{bufnr("%")}
    if g:netrw_keepdir
    " Jul 19, 2022: fixing file move when g:netrw_keepdir is 1
     let fname= b:netrw_curdir."/".fname
    endif
    if !g:netrw_cygwin && has("win32")
     let fname= substitute(fname,'/','\\','g')
    endif
"    call Decho("system(".movecmd." ".s:ShellEscape(fname)." ".tgt.")",'~'.expand("<slnum>"))
    let ret= system(movecmd.g:netrw_localmovecmdopt." ".s:ShellEscape(fname)." ".tgt)
    if v:shell_error != 0
     if exists("b:netrw_curdir") && b:netrw_curdir != getcwd() && !g:netrw_keepdir
      call netrw#ErrorMsg(s:ERROR,"move failed; perhaps due to vim's current directory<".getcwd()."> not matching netrw's (".b:netrw_curdir.") (see :help netrw-cd)",100)
     else
      call netrw#ErrorMsg(s:ERROR,"tried using g:netrw_localmovecmd<".g:netrw_localmovecmd.">; it doesn't work!",54)
     endif
     break
    endif
   endfor

  elseif  a:islocal && !s:netrwmftgt_islocal
   " move: local -> remote
"   call Decho("move from local to remote",'~'.expand("<slnum>"))
"   call Decho("copy",'~'.expand("<slnum>"))
   let mflist= s:netrwmarkfilelist_{bufnr("%")}
   NetrwKeepj call s:NetrwMarkFileCopy(a:islocal)
"   call Decho("remove",'~'.expand("<slnum>"))
   for fname in mflist
    let barefname = substitute(fname,'^\(.*/\)\(.\{-}\)$','\2','')
    let ok        = s:NetrwLocalRmFile(b:netrw_curdir,barefname,1)
   endfor
   unlet mflist

  elseif !a:islocal &&  s:netrwmftgt_islocal
   " move: remote -> local
"   call Decho("move from remote to local",'~'.expand("<slnum>"))
"   call Decho("copy",'~'.expand("<slnum>"))
   let mflist= s:netrwmarkfilelist_{bufnr("%")}
   NetrwKeepj call s:NetrwMarkFileCopy(a:islocal)
"   call Decho("remove",'~'.expand("<slnum>"))
   for fname in mflist
    let barefname = substitute(fname,'^\(.*/\)\(.\{-}\)$','\2','')
    let ok        = s:NetrwRemoteRmFile(b:netrw_curdir,barefname,1)
   endfor
   unlet mflist

  elseif !a:islocal && !s:netrwmftgt_islocal
   " move: remote -> remote
"   call Decho("move from remote to remote",'~'.expand("<slnum>"))
"   call Decho("copy",'~'.expand("<slnum>"))
   let mflist= s:netrwmarkfilelist_{bufnr("%")}
   NetrwKeepj call s:NetrwMarkFileCopy(a:islocal)
"   call Decho("remove",'~'.expand("<slnum>"))
   for fname in mflist
    let barefname = substitute(fname,'^\(.*/\)\(.\{-}\)$','\2','')
    let ok        = s:NetrwRemoteRmFile(b:netrw_curdir,barefname,1)
   endfor
   unlet mflist
  endif

  " -------
  " cleanup
  " -------
"  call Decho("cleanup",'~'.expand("<slnum>"))

  " remove markings from local buffer
  call s:NetrwUnmarkList(curbufnr,curdir)                   " remove markings from local buffer

  " refresh buffers
  if !s:netrwmftgt_islocal
"   call Decho("refresh netrwmftgt<".s:netrwmftgt.">",'~'.expand("<slnum>"))
   NetrwKeepj call s:NetrwRefreshDir(s:netrwmftgt_islocal,s:netrwmftgt)
  endif
  if a:islocal
"   call Decho("refresh b:netrw_curdir<".b:netrw_curdir.">",'~'.expand("<slnum>"))
   NetrwKeepj call s:NetrwRefreshDir(a:islocal,b:netrw_curdir)
  endif
  if g:netrw_fastbrowse <= 1
"   call Decho("since g:netrw_fastbrowse=".g:netrw_fastbrowse.", perform shell cmd refresh",'~'.expand("<slnum>"))
   NetrwKeepj call s:LocalBrowseRefresh()
  endif

"  call Dret("s:NetrwMarkFileMove")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileRegexp: (invoked by mr) This function is used to mark {{{2
"                        files when given a regexp (for which a prompt is
"                        issued) (matches to name of files).
fun! s:NetrwMarkFileRegexp(islocal)
"  call Dfunc("s:NetrwMarkFileRegexp(islocal=".a:islocal.")")

  " get the regular expression
  call inputsave()
  let regexp= input("Enter regexp: ","","file")
  call inputrestore()

  if a:islocal
   let curdir= s:NetrwGetCurdir(a:islocal)
"   call Decho("curdir<".fnameescape(curdir).">")
   " get the matching list of files using local glob()
"   call Decho("handle local regexp",'~'.expand("<slnum>"))
   let dirname = escape(b:netrw_curdir,g:netrw_glob_escape)
   if v:version > 704 || (v:version == 704 && has("patch656"))
    let filelist= glob(s:ComposePath(dirname,regexp),0,1,1)
   else
    let files   = glob(s:ComposePath(dirname,regexp),0,0)
    let filelist= split(files,"\n")
   endif
"   call Decho("files<".string(filelist).">",'~'.expand("<slnum>"))

  " mark the list of files
  for fname in filelist
   if fname =~ '^'.fnameescape(curdir)
"    call Decho("fname<".substitute(fname,'^'.fnameescape(curdir).'/','','').">",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwMarkFile(a:islocal,substitute(fname,'^'.fnameescape(curdir).'/','',''))
   else
"    call Decho("fname<".fname.">",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwMarkFile(a:islocal,substitute(fname,'^.*/','',''))
   endif
  endfor

  else
"   call Decho("handle remote regexp",'~'.expand("<slnum>"))

   " convert displayed listing into a filelist
   let eikeep = &ei
   let areg   = @a
   sil NetrwKeepj %y a
   setl ei=all ma
"   call Decho("setl ei=all ma",'~'.expand("<slnum>"))
   1split
   NetrwKeepj call s:NetrwEnew()
   NetrwKeepj call s:NetrwOptionsSafe(a:islocal)
   sil NetrwKeepj norm! "ap
   NetrwKeepj 2
   let bannercnt= search('^" =====','W')
   exe "sil NetrwKeepj 1,".bannercnt."d"
   setl bt=nofile
   if     g:netrw_liststyle == s:LONGLIST
    sil NetrwKeepj %s/\s\{2,}\S.*$//e
    call histdel("/",-1)
   elseif g:netrw_liststyle == s:WIDELIST
    sil NetrwKeepj %s/\s\{2,}/\r/ge
    call histdel("/",-1)
   elseif g:netrw_liststyle == s:TREELIST
    exe 'sil NetrwKeepj %s/^'.s:treedepthstring.' //e'
    sil! NetrwKeepj g/^ .*$/d
    call histdel("/",-1)
    call histdel("/",-1)
   endif
   " convert regexp into the more usual glob-style format
   let regexp= substitute(regexp,'\*','.*','g')
"   call Decho("regexp<".regexp.">",'~'.expand("<slnum>"))
   exe "sil! NetrwKeepj v/".escape(regexp,'/')."/d"
   call histdel("/",-1)
   let filelist= getline(1,line("$"))
   q!
   for filename in filelist
    NetrwKeepj call s:NetrwMarkFile(a:islocal,substitute(filename,'^.*/','',''))
   endfor
   unlet filelist
   let @a  = areg
   let &ei = eikeep
  endif
  echo "  (use me to edit marked files)"

"  call Dret("s:NetrwMarkFileRegexp")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileSource: (invoked by ms) This function sources marked files {{{2
"                        Uses the local marked file list.
fun! s:NetrwMarkFileSource(islocal)
"  call Dfunc("s:NetrwMarkFileSource(islocal=".a:islocal.")")
  let curbufnr= bufnr("%")

  " sanity check
  if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
   NetrwKeepj call netrw#ErrorMsg(2,"there are no marked files in this window (:help netrw-mf)",66)
"   call Dret("s:NetrwMarkFileSource")
   return
  endif
"  call Decho("sanity chk passed: s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}),'~'.expand("<slnum>"))
  let curdir= s:NetrwGetCurdir(a:islocal)

  if exists("s:netrwmarkfilelist_{curbufnr}")
   let netrwmarkfilelist = s:netrwmarkfilelist_{bufnr("%")}
   call s:NetrwUnmarkList(curbufnr,curdir)
   for fname in netrwmarkfilelist
    if a:islocal
     if g:netrw_keepdir
      let fname= s:ComposePath(curdir,fname)
     endif
    else
     let fname= curdir.fname
    endif
    " the autocmds will handle sourcing both local and remote files
"    call Decho("exe so ".fnameescape(fname),'~'.expand("<slnum>"))
    exe "so ".fnameescape(fname)
   endfor
   2match none
  endif
"  call Dret("s:NetrwMarkFileSource")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileTag: (invoked by mT) This function applies g:netrw_ctags to marked files {{{2
"                     Uses the global markfilelist
fun! s:NetrwMarkFileTag(islocal)
"  call Dfunc("s:NetrwMarkFileTag(islocal=".a:islocal.")")
  let svpos    = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curdir   = s:NetrwGetCurdir(a:islocal)
  let curbufnr = bufnr("%")

  " sanity check
  if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
   NetrwKeepj call netrw#ErrorMsg(2,"there are no marked files in this window (:help netrw-mf)",66)
"   call Dret("s:NetrwMarkFileTag")
   return
  endif
"  call Decho("sanity chk passed: s:netrwmarkfilelist_".curbufnr."<".string(s:netrwmarkfilelist_{curbufnr}),'~'.expand("<slnum>"))

  if exists("s:netrwmarkfilelist")
"   call Decho("s:netrwmarkfilelist".string(s:netrwmarkfilelist).">",'~'.expand("<slnum>"))
   let netrwmarkfilelist= join(map(deepcopy(s:netrwmarkfilelist), "s:ShellEscape(v:val,".!a:islocal.")"))
   call s:NetrwUnmarkAll()

   if a:islocal

"    call Decho("call system(".g:netrw_ctags." ".netrwmarkfilelist.")",'~'.expand("<slnum>"))
    call system(g:netrw_ctags." ".netrwmarkfilelist)
    if v:shell_error
     call netrw#ErrorMsg(s:ERROR,"g:netrw_ctags<".g:netrw_ctags."> is not executable!",51)
    endif

   else
    let cmd   = s:RemoteSystem(g:netrw_ctags." ".netrwmarkfilelist)
    call netrw#Obtain(a:islocal,"tags")
    let curdir= b:netrw_curdir
    1split
    NetrwKeepj e tags
    let path= substitute(curdir,'^\(.*\)/[^/]*$','\1/','')
"    call Decho("curdir<".curdir."> path<".path.">",'~'.expand("<slnum>"))
    exe 'NetrwKeepj %s/\t\(\S\+\)\t/\t'.escape(path,"/\n\r\\").'\1\t/e'
    call histdel("/",-1)
    wq!
   endif
   2match none
   call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   call winrestview(svpos)
  endif

"  call Dret("s:NetrwMarkFileTag")
endfun

" ---------------------------------------------------------------------
" s:NetrwMarkFileTgt:  (invoked by mt) This function sets up a marked file target {{{2
"   Sets up two variables,
"     s:netrwmftgt         : holds the target directory
"     s:netrwmftgt_islocal : 0=target directory is remote
"                            1=target directory is local
fun! s:NetrwMarkFileTgt(islocal)
" call Dfunc("s:NetrwMarkFileTgt(islocal=".a:islocal.")")
  let svpos  = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curdir = s:NetrwGetCurdir(a:islocal)
  let hadtgt = exists("s:netrwmftgt")
  if !exists("w:netrw_bannercnt")
   let w:netrw_bannercnt= b:netrw_bannercnt
  endif

  " set up target
  if line(".") < w:netrw_bannercnt
"   call Decho("set up target: line(.) < w:netrw_bannercnt=".w:netrw_bannercnt,'~'.expand("<slnum>"))
   " if cursor in banner region, use b:netrw_curdir for the target unless its already the target
   if exists("s:netrwmftgt") && exists("s:netrwmftgt_islocal") && s:netrwmftgt == b:netrw_curdir
"    call Decho("cursor in banner region, and target already is <".b:netrw_curdir.">: removing target",'~'.expand("<slnum>"))
    unlet s:netrwmftgt s:netrwmftgt_islocal
    if g:netrw_fastbrowse <= 1
     call s:LocalBrowseRefresh()
    endif
    call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"    call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
    call winrestview(svpos)
"    call Dret("s:NetrwMarkFileTgt : removed target")
    return
   else
    let s:netrwmftgt= b:netrw_curdir
"    call Decho("inbanner: s:netrwmftgt<".s:netrwmftgt.">",'~'.expand("<slnum>"))
   endif

  else
   " get word under cursor.
   "  * If directory, use it for the target.
   "  * If file, use b:netrw_curdir for the target
"   call Decho("get word under cursor",'~'.expand("<slnum>"))
   let curword= s:NetrwGetWord()
   let tgtdir = s:ComposePath(curdir,curword)
   if a:islocal && isdirectory(s:NetrwFile(tgtdir))
    let s:netrwmftgt = tgtdir
"    call Decho("local isdir: s:netrwmftgt<".s:netrwmftgt.">",'~'.expand("<slnum>"))
   elseif !a:islocal && tgtdir =~ '/$'
    let s:netrwmftgt = tgtdir
"    call Decho("remote isdir: s:netrwmftgt<".s:netrwmftgt.">",'~'.expand("<slnum>"))
   else
    let s:netrwmftgt = curdir
"    call Decho("isfile: s:netrwmftgt<".s:netrwmftgt.">",'~'.expand("<slnum>"))
   endif
  endif
  if a:islocal
   " simplify the target (eg. /abc/def/../ghi -> /abc/ghi)
   let s:netrwmftgt= simplify(s:netrwmftgt)
"   call Decho("simplify: s:netrwmftgt<".s:netrwmftgt.">",'~'.expand("<slnum>"))
  endif
  if g:netrw_cygwin
   let s:netrwmftgt= substitute(system("cygpath ".s:ShellEscape(s:netrwmftgt)),'\n$','','')
   let s:netrwmftgt= substitute(s:netrwmftgt,'\n$','','')
  endif
  let s:netrwmftgt_islocal= a:islocal

  " need to do refresh so that the banner will be updated
  "  s:LocalBrowseRefresh handles all local-browsing buffers when not fast browsing
  if g:netrw_fastbrowse <= 1
"   call Decho("g:netrw_fastbrowse=".g:netrw_fastbrowse.", so refreshing all local netrw buffers",'~'.expand("<slnum>"))
   call s:LocalBrowseRefresh()
  endif
"  call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
   call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,w:netrw_treetop))
  else
   call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
  endif
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  call winrestview(svpos)
  if !hadtgt
   sil! NetrwKeepj norm! j
  endif

"  call Decho("getmatches=".string(getmatches()),'~'.expand("<slnum>"))
"  call Decho("s:netrwmarkfilelist=".(exists("s:netrwmarkfilelist")? string(s:netrwmarkfilelist) : 'n/a'),'~'.expand("<slnum>"))
"  call Dret("s:NetrwMarkFileTgt : netrwmftgt<".(exists("s:netrwmftgt")? s:netrwmftgt : "").">")
endfun

" ---------------------------------------------------------------------
" s:NetrwGetCurdir: gets current directory and sets up b:netrw_curdir if necessary {{{2
fun! s:NetrwGetCurdir(islocal)
"  call Dfunc("s:NetrwGetCurdir(islocal=".a:islocal.")")

  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
   let b:netrw_curdir = s:NetrwTreePath(w:netrw_treetop)
"   call Decho("set b:netrw_curdir<".b:netrw_curdir."> (used s:NetrwTreeDir)",'~'.expand("<slnum>"))
  elseif !exists("b:netrw_curdir")
   let b:netrw_curdir= getcwd()
"   call Decho("set b:netrw_curdir<".b:netrw_curdir."> (used getcwd)",'~'.expand("<slnum>"))
  endif

"  call Decho("b:netrw_curdir<".b:netrw_curdir."> ".((b:netrw_curdir !~ '\<\a\{3,}://')? "does not match" : "matches")." url pattern",'~'.expand("<slnum>"))
  if b:netrw_curdir !~ '\<\a\{3,}://'
   let curdir= b:netrw_curdir
"   call Decho("g:netrw_keepdir=".g:netrw_keepdir,'~'.expand("<slnum>"))
   if g:netrw_keepdir == 0
    call s:NetrwLcd(curdir)
   endif
  endif

"  call Dret("s:NetrwGetCurdir <".curdir.">")
  return b:netrw_curdir
endfun

" ---------------------------------------------------------------------
" s:NetrwOpenFile: query user for a filename and open it {{{2
fun! s:NetrwOpenFile(islocal)
"  call Dfunc("s:NetrwOpenFile(islocal=".a:islocal.")")
  let ykeep= @@
  call inputsave()
  let fname= input("Enter filename: ")
  call inputrestore()
"  call Decho("(s:NetrwOpenFile) fname<".fname.">",'~'.expand("<slnum>"))

  " determine if Lexplore is in use
  if exists("t:netrw_lexbufnr")
   " check if t:netrw_lexbufnr refers to a netrw window
"   call Decho("(s:netrwOpenFile) ..t:netrw_lexbufnr=".t:netrw_lexbufnr,'~'.expand("<slnum>"))
   let lexwinnr = bufwinnr(t:netrw_lexbufnr)
   if lexwinnr != -1 && exists("g:netrw_chgwin") && g:netrw_chgwin != -1
"    call Decho("(s:netrwOpenFile) ..Lexplore in use",'~'.expand("<slnum>"))
    exe "NetrwKeepj keepalt ".g:netrw_chgwin."wincmd w"
    exe "NetrwKeepj e ".fnameescape(fname)
    let @@= ykeep
"    call Dret("s:NetrwOpenFile : creating a file with Lexplore mode")
   endif
  endif

  " Does the filename contain a path?
  if fname !~ '[/\\]'
   if exists("b:netrw_curdir")
    if exists("g:netrw_quiet")
     let netrw_quiet_keep = g:netrw_quiet
    endif
    let g:netrw_quiet = 1
    " save position for benefit of Rexplore
    let s:rexposn_{bufnr("%")}= winsaveview()
"    call Decho("saving posn to s:rexposn_".bufnr("%")."<".string(s:rexposn_{bufnr("%")}).">",'~'.expand("<slnum>"))
    if b:netrw_curdir =~ '/$'
     exe "NetrwKeepj e ".fnameescape(b:netrw_curdir.fname)
    else
     exe "e ".fnameescape(b:netrw_curdir."/".fname)
    endif
    if exists("netrw_quiet_keep")
     let g:netrw_quiet= netrw_quiet_keep
    else
     unlet g:netrw_quiet
    endif
   endif
  else
   exe "NetrwKeepj e ".fnameescape(fname)
  endif
  let @@= ykeep
"  call Dret("s:NetrwOpenFile")
endfun

" ---------------------------------------------------------------------
" netrw#Shrink: shrinks/expands a netrw or Lexplorer window {{{2
"               For the mapping to this function be made via
"               netrwPlugin, you'll need to have had
"               g:netrw_usetab set to non-zero.
fun! netrw#Shrink()
"  call Dfunc("netrw#Shrink() ft<".&ft."> winwidth=".winwidth(0)." lexbuf#".((exists("t:netrw_lexbufnr"))? t:netrw_lexbufnr : 'n/a'))
  let curwin  = winnr()
  let wiwkeep = &wiw
  set wiw=1

  if &ft == "netrw"
   if winwidth(0) > g:netrw_wiw
    let t:netrw_winwidth= winwidth(0)
    exe "vert resize ".g:netrw_wiw
    wincmd l
    if winnr() == curwin
     wincmd h
    endif
"    call Decho("vert resize 0",'~'.expand("<slnum>"))
   else
    exe "vert resize ".t:netrw_winwidth
"    call Decho("vert resize ".t:netrw_winwidth,'~'.expand("<slnum>"))
   endif

  elseif exists("t:netrw_lexbufnr")
   exe bufwinnr(t:netrw_lexbufnr)."wincmd w"
   if     winwidth(bufwinnr(t:netrw_lexbufnr)) >  g:netrw_wiw
    let t:netrw_winwidth= winwidth(0)
    exe "vert resize ".g:netrw_wiw
    wincmd l
    if winnr() == curwin
     wincmd h
    endif
"    call Decho("vert resize 0",'~'.expand("<slnum>"))
   elseif winwidth(bufwinnr(t:netrw_lexbufnr)) >= 0
    exe "vert resize ".t:netrw_winwidth
"    call Decho("vert resize ".t:netrw_winwidth,'~'.expand("<slnum>"))
   else 
    call netrw#Lexplore(0,0)
   endif

  else
   call netrw#Lexplore(0,0)
  endif
  let wiw= wiwkeep

"  call Dret("netrw#Shrink")
endfun

" ---------------------------------------------------------------------
" s:NetSortSequence: allows user to edit the sorting sequence {{{2
fun! s:NetSortSequence(islocal)
"  call Dfunc("NetSortSequence(islocal=".a:islocal.")")

  let ykeep= @@
  let svpos= winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  call inputsave()
  let newsortseq= input("Edit Sorting Sequence: ",g:netrw_sort_sequence)
  call inputrestore()

  " refresh the listing
  let g:netrw_sort_sequence= newsortseq
  NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)
  let @@= ykeep

"  call Dret("NetSortSequence")
endfun

" ---------------------------------------------------------------------
" s:NetrwUnmarkList: delete local marked file list and remove their contents from the global marked-file list {{{2
"   User access provided by the <mF> mapping. (see :help netrw-mF)
"   Used by many MarkFile functions.
fun! s:NetrwUnmarkList(curbufnr,curdir)
"  call Dfunc("s:NetrwUnmarkList(curbufnr=".a:curbufnr." curdir<".a:curdir.">)")

  "  remove all files in local marked-file list from global list
  if exists("s:netrwmarkfilelist")
   for mfile in s:netrwmarkfilelist_{a:curbufnr}
    let dfile = s:ComposePath(a:curdir,mfile)       " prepend directory to mfile
    let idx   = index(s:netrwmarkfilelist,dfile)    " get index in list of dfile
    call remove(s:netrwmarkfilelist,idx)            " remove from global list
   endfor
   if s:netrwmarkfilelist == []
    unlet s:netrwmarkfilelist
   endif

   " getting rid of the local marked-file lists is easy
   unlet s:netrwmarkfilelist_{a:curbufnr}
  endif
  if exists("s:netrwmarkfilemtch_{a:curbufnr}")
   unlet s:netrwmarkfilemtch_{a:curbufnr}
  endif
  2match none
"  call Dret("s:NetrwUnmarkList")
endfun

" ---------------------------------------------------------------------
" s:NetrwUnmarkAll: remove the global marked file list and all local ones {{{2
fun! s:NetrwUnmarkAll()
"  call Dfunc("s:NetrwUnmarkAll()")
  if exists("s:netrwmarkfilelist")
   unlet s:netrwmarkfilelist
  endif
  sil call s:NetrwUnmarkAll2()
  2match none
"  call Dret("s:NetrwUnmarkAll")
endfun

" ---------------------------------------------------------------------
" s:NetrwUnmarkAll2: unmark all files from all buffers {{{2
fun! s:NetrwUnmarkAll2()
"  call Dfunc("s:NetrwUnmarkAll2()")
  redir => netrwmarkfilelist_let
  let
  redir END
  let netrwmarkfilelist_list= split(netrwmarkfilelist_let,'\n')          " convert let string into a let list
  call filter(netrwmarkfilelist_list,"v:val =~ '^s:netrwmarkfilelist_'") " retain only those vars that start as s:netrwmarkfilelist_
  call map(netrwmarkfilelist_list,"substitute(v:val,'\\s.*$','','')")    " remove what the entries are equal to
  for flist in netrwmarkfilelist_list
   let curbufnr= substitute(flist,'s:netrwmarkfilelist_','','')
   unlet s:netrwmarkfilelist_{curbufnr}
   unlet s:netrwmarkfilemtch_{curbufnr}
  endfor
"  call Dret("s:NetrwUnmarkAll2")
endfun

" ---------------------------------------------------------------------
" s:NetrwUnMarkFile: called via mu map; unmarks *all* marked files, both global and buffer-local {{{2
"
" Marked files are in two types of lists:
"    s:netrwmarkfilelist    -- holds complete paths to all marked files
"    s:netrwmarkfilelist_#  -- holds list of marked files in current-buffer's directory (#==bufnr())
"
" Marked files suitable for use with 2match are in:
"    s:netrwmarkfilemtch_#   -- used with 2match to display marked files
fun! s:NetrwUnMarkFile(islocal)
"  call Dfunc("s:NetrwUnMarkFile(islocal=".a:islocal.")")
  let svpos    = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let curbufnr = bufnr("%")

  " unmark marked file list
  " (although I expect s:NetrwUpload() to do it, I'm just making sure)
  if exists("s:netrwmarkfilelist")
"   "   call Decho("unlet'ing: s:netrwmarkfilelist",'~'.expand("<slnum>"))
   unlet s:netrwmarkfilelist
  endif

  let ibuf= 1
  while ibuf < bufnr("$")
   if exists("s:netrwmarkfilelist_".ibuf)
    unlet s:netrwmarkfilelist_{ibuf}
    unlet s:netrwmarkfilemtch_{ibuf}
   endif
   let ibuf = ibuf + 1
  endwhile
  2match none

"  call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
call winrestview(svpos)
"  call Dret("s:NetrwUnMarkFile")
endfun

" ---------------------------------------------------------------------
" s:NetrwMenu: generates the menu for gvim and netrw {{{2
fun! s:NetrwMenu(domenu)

  if !exists("g:NetrwMenuPriority")
   let g:NetrwMenuPriority= 80
  endif

  if has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu
"   call Dfunc("NetrwMenu(domenu=".a:domenu.")")

   if !exists("s:netrw_menu_enabled") && a:domenu
"    call Decho("initialize menu",'~'.expand("<slnum>"))
    let s:netrw_menu_enabled= 1
    exe 'sil! menu '.g:NetrwMenuPriority.'.1      '.g:NetrwTopLvlMenu.'Help<tab><F1>	<F1>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.5      '.g:NetrwTopLvlMenu.'-Sep1-	:'
    exe 'sil! menu '.g:NetrwMenuPriority.'.6      '.g:NetrwTopLvlMenu.'Go\ Up\ Directory<tab>-	-'
    exe 'sil! menu '.g:NetrwMenuPriority.'.7      '.g:NetrwTopLvlMenu.'Apply\ Special\ Viewer<tab>x	x'
    if g:netrw_dirhistmax > 0
     exe 'sil! menu '.g:NetrwMenuPriority.'.8.1   '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History.Bookmark\ Current\ Directory<tab>mb	mb'
     exe 'sil! menu '.g:NetrwMenuPriority.'.8.4   '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History.Goto\ Prev\ Dir\ (History)<tab>u	u'
     exe 'sil! menu '.g:NetrwMenuPriority.'.8.5   '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History.Goto\ Next\ Dir\ (History)<tab>U	U'
     exe 'sil! menu '.g:NetrwMenuPriority.'.8.6   '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History.List<tab>qb	qb'
    else
     exe 'sil! menu '.g:NetrwMenuPriority.'.8     '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History	:echo "(disabled)"'."\<cr>"
    endif
    exe 'sil! menu '.g:NetrwMenuPriority.'.9.1    '.g:NetrwTopLvlMenu.'Browsing\ Control.Horizontal\ Split<tab>o	o'
    exe 'sil! menu '.g:NetrwMenuPriority.'.9.2    '.g:NetrwTopLvlMenu.'Browsing\ Control.Vertical\ Split<tab>v	v'
    exe 'sil! menu '.g:NetrwMenuPriority.'.9.3    '.g:NetrwTopLvlMenu.'Browsing\ Control.New\ Tab<tab>t	t'
    exe 'sil! menu '.g:NetrwMenuPriority.'.9.4    '.g:NetrwTopLvlMenu.'Browsing\ Control.Preview<tab>p	p'
    exe 'sil! menu '.g:NetrwMenuPriority.'.9.5    '.g:NetrwTopLvlMenu.'Browsing\ Control.Edit\ File\ Hiding\ List<tab><ctrl-h>'."	\<c-h>'"
    exe 'sil! menu '.g:NetrwMenuPriority.'.9.6    '.g:NetrwTopLvlMenu.'Browsing\ Control.Edit\ Sorting\ Sequence<tab>S	S'
    exe 'sil! menu '.g:NetrwMenuPriority.'.9.7    '.g:NetrwTopLvlMenu.'Browsing\ Control.Quick\ Hide/Unhide\ Dot\ Files<tab>'."gh	gh"
    exe 'sil! menu '.g:NetrwMenuPriority.'.9.8    '.g:NetrwTopLvlMenu.'Browsing\ Control.Refresh\ Listing<tab>'."<ctrl-l>	\<c-l>"
    exe 'sil! menu '.g:NetrwMenuPriority.'.9.9    '.g:NetrwTopLvlMenu.'Browsing\ Control.Settings/Options<tab>:NetrwSettings	'.":NetrwSettings\<cr>"
    exe 'sil! menu '.g:NetrwMenuPriority.'.10     '.g:NetrwTopLvlMenu.'Delete\ File/Directory<tab>D	D'
    exe 'sil! menu '.g:NetrwMenuPriority.'.11.1   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.Create\ New\ File<tab>%	%'
    exe 'sil! menu '.g:NetrwMenuPriority.'.11.1   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ Current\ Window<tab><cr>	'."\<cr>"
    exe 'sil! menu '.g:NetrwMenuPriority.'.11.2   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.Preview\ File/Directory<tab>p	p'
    exe 'sil! menu '.g:NetrwMenuPriority.'.11.3   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ Previous\ Window<tab>P	P'
    exe 'sil! menu '.g:NetrwMenuPriority.'.11.4   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ New\ Window<tab>o	o'
    exe 'sil! menu '.g:NetrwMenuPriority.'.11.5   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ New\ Tab<tab>t	t'
    exe 'sil! menu '.g:NetrwMenuPriority.'.11.5   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ New\ Vertical\ Window<tab>v	v'
    exe 'sil! menu '.g:NetrwMenuPriority.'.12.1   '.g:NetrwTopLvlMenu.'Explore.Directory\ Name	:Explore '
    exe 'sil! menu '.g:NetrwMenuPriority.'.12.2   '.g:NetrwTopLvlMenu.'Explore.Filenames\ Matching\ Pattern\ (curdir\ only)<tab>:Explore\ */	:Explore */'
    exe 'sil! menu '.g:NetrwMenuPriority.'.12.2   '.g:NetrwTopLvlMenu.'Explore.Filenames\ Matching\ Pattern\ (+subdirs)<tab>:Explore\ **/	:Explore **/'
    exe 'sil! menu '.g:NetrwMenuPriority.'.12.3   '.g:NetrwTopLvlMenu.'Explore.Files\ Containing\ String\ Pattern\ (curdir\ only)<tab>:Explore\ *//	:Explore *//'
    exe 'sil! menu '.g:NetrwMenuPriority.'.12.4   '.g:NetrwTopLvlMenu.'Explore.Files\ Containing\ String\ Pattern\ (+subdirs)<tab>:Explore\ **//	:Explore **//'
    exe 'sil! menu '.g:NetrwMenuPriority.'.12.4   '.g:NetrwTopLvlMenu.'Explore.Next\ Match<tab>:Nexplore	:Nexplore<cr>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.12.4   '.g:NetrwTopLvlMenu.'Explore.Prev\ Match<tab>:Pexplore	:Pexplore<cr>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.13     '.g:NetrwTopLvlMenu.'Make\ Subdirectory<tab>d	d'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.1   '.g:NetrwTopLvlMenu.'Marked\ Files.Mark\ File<tab>mf	mf'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.2   '.g:NetrwTopLvlMenu.'Marked\ Files.Mark\ Files\ by\ Regexp<tab>mr	mr'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.3   '.g:NetrwTopLvlMenu.'Marked\ Files.Hide-Show-List\ Control<tab>a	a'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.4   '.g:NetrwTopLvlMenu.'Marked\ Files.Copy\ To\ Target<tab>mc	mc'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.5   '.g:NetrwTopLvlMenu.'Marked\ Files.Delete<tab>D	D'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.6   '.g:NetrwTopLvlMenu.'Marked\ Files.Diff<tab>md	md'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.7   '.g:NetrwTopLvlMenu.'Marked\ Files.Edit<tab>me	me'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.8   '.g:NetrwTopLvlMenu.'Marked\ Files.Exe\ Cmd<tab>mx	mx'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.9   '.g:NetrwTopLvlMenu.'Marked\ Files.Move\ To\ Target<tab>mm	mm'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.10  '.g:NetrwTopLvlMenu.'Marked\ Files.Obtain<tab>O	O'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.11  '.g:NetrwTopLvlMenu.'Marked\ Files.Print<tab>mp	mp'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.12  '.g:NetrwTopLvlMenu.'Marked\ Files.Replace<tab>R	R'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.13  '.g:NetrwTopLvlMenu.'Marked\ Files.Set\ Target<tab>mt	mt'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.14  '.g:NetrwTopLvlMenu.'Marked\ Files.Tag<tab>mT	mT'
    exe 'sil! menu '.g:NetrwMenuPriority.'.14.15  '.g:NetrwTopLvlMenu.'Marked\ Files.Zip/Unzip/Compress/Uncompress<tab>mz	mz'
    exe 'sil! menu '.g:NetrwMenuPriority.'.15     '.g:NetrwTopLvlMenu.'Obtain\ File<tab>O	O'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.1.1 '.g:NetrwTopLvlMenu.'Style.Listing.thin<tab>i	:let w:netrw_liststyle=0<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.1.1 '.g:NetrwTopLvlMenu.'Style.Listing.long<tab>i	:let w:netrw_liststyle=1<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.1.1 '.g:NetrwTopLvlMenu.'Style.Listing.wide<tab>i	:let w:netrw_liststyle=2<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.1.1 '.g:NetrwTopLvlMenu.'Style.Listing.tree<tab>i	:let w:netrw_liststyle=3<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.2.1 '.g:NetrwTopLvlMenu.'Style.Normal-Hide-Show.Show\ All<tab>a	:let g:netrw_hide=0<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.2.3 '.g:NetrwTopLvlMenu.'Style.Normal-Hide-Show.Normal<tab>a	:let g:netrw_hide=1<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.2.2 '.g:NetrwTopLvlMenu.'Style.Normal-Hide-Show.Hidden\ Only<tab>a	:let g:netrw_hide=2<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.3   '.g:NetrwTopLvlMenu.'Style.Reverse\ Sorting\ Order<tab>'."r	r"
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.4.1 '.g:NetrwTopLvlMenu.'Style.Sorting\ Method.Name<tab>s       :let g:netrw_sort_by="name"<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.4.2 '.g:NetrwTopLvlMenu.'Style.Sorting\ Method.Time<tab>s       :let g:netrw_sort_by="time"<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.4.3 '.g:NetrwTopLvlMenu.'Style.Sorting\ Method.Size<tab>s       :let g:netrw_sort_by="size"<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.16.4.3 '.g:NetrwTopLvlMenu.'Style.Sorting\ Method.Exten<tab>s      :let g:netrw_sort_by="exten"<cr><c-L>'
    exe 'sil! menu '.g:NetrwMenuPriority.'.17     '.g:NetrwTopLvlMenu.'Rename\ File/Directory<tab>R	R'
    exe 'sil! menu '.g:NetrwMenuPriority.'.18     '.g:NetrwTopLvlMenu.'Set\ Current\ Directory<tab>c	c'
    let s:netrw_menucnt= 28
    call s:NetrwBookmarkMenu() " provide some history!  uses priorities 2,3, reserves 4, 8.2.x
    call s:NetrwTgtMenu()      " let bookmarks and history be easy targets

   elseif !a:domenu
    let s:netrwcnt = 0
    let curwin     = winnr()
    windo if getline(2) =~# "Netrw" | let s:netrwcnt= s:netrwcnt + 1 | endif
    exe curwin."wincmd w"

    if s:netrwcnt <= 1
"     call Decho("clear menus",'~'.expand("<slnum>"))
     exe 'sil! unmenu '.g:NetrwTopLvlMenu
"     call Decho('exe sil! unmenu '.g:NetrwTopLvlMenu.'*','~'.expand("<slnum>"))
     sil! unlet s:netrw_menu_enabled
    endif
   endif
"   call Dret("NetrwMenu")
   return
  endif

endfun

" ---------------------------------------------------------------------
" s:NetrwObtain: obtain file under cursor or from markfile list {{{2
"                Used by the O maps (as <SID>NetrwObtain())
fun! s:NetrwObtain(islocal)
"  call Dfunc("NetrwObtain(islocal=".a:islocal.")")

  let ykeep= @@
  if exists("s:netrwmarkfilelist_{bufnr('%')}")
   let islocal= s:netrwmarkfilelist_{bufnr('%')}[1] !~ '^\a\{3,}://'
   call netrw#Obtain(islocal,s:netrwmarkfilelist_{bufnr('%')})
   call s:NetrwUnmarkList(bufnr('%'),b:netrw_curdir)
  else
   call netrw#Obtain(a:islocal,s:NetrwGetWord())
  endif
  let @@= ykeep

"  call Dret("NetrwObtain")
endfun

" ---------------------------------------------------------------------
" s:NetrwPrevWinOpen: open file/directory in previous window.  {{{2
"   If there's only one window, then the window will first be split.
"   Returns:
"     choice = 0 : didn't have to choose
"     choice = 1 : saved modified file in window first
"     choice = 2 : didn't save modified file, opened window
"     choice = 3 : cancel open
fun! s:NetrwPrevWinOpen(islocal)
"  call Dfunc("s:NetrwPrevWinOpen(islocal=".a:islocal.") win#".winnr())

  let ykeep= @@
  " grab a copy of the b:netrw_curdir to pass it along to newly split windows
  let curdir = b:netrw_curdir
"  call Decho("COMBAK#1: mod=".&mod." win#".winnr())

  " get last window number and the word currently under the cursor
  let origwin   = winnr()
  let lastwinnr = winnr("$")
"  call Decho("origwin#".origwin." lastwinnr#".lastwinnr)
"  call Decho("COMBAK#2: mod=".&mod." win#".winnr())
  let curword      = s:NetrwGetWord()
  let choice       = 0
  let s:prevwinopen= 1	" lets s:NetrwTreeDir() know that NetrwPrevWinOpen called it (s:NetrwTreeDir() will unlet s:prevwinopen)
"  call Decho("COMBAK#3: mod=".&mod." win#".winnr())
  let s:treedir = s:NetrwTreeDir(a:islocal)
"  call Decho("COMBAK#4: mod=".&mod." win#".winnr())
  let curdir    = s:treedir
"  call Decho("COMBAK#5: mod=".&mod." win#".winnr())
"  call Decho("winnr($)#".lastwinnr." curword<".curword.">",'~'.expand("<slnum>"))
"  call Decho("COMBAK#6: mod=".&mod." win#".winnr())

  let didsplit = 0
  if lastwinnr == 1
   " if only one window, open a new one first
"   call Decho("only one window, so open a new one (g:netrw_alto=".g:netrw_alto.")",'~'.expand("<slnum>"))
   " g:netrw_preview=0: preview window shown in a horizontally split window
   " g:netrw_preview=1: preview window shown in a vertically   split window
   if g:netrw_preview
    " vertically split preview window
    let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize
"    call Decho("exe ".(g:netrw_alto? "top " : "bot ")."vert ".winsz."wincmd s",'~'.expand("<slnum>"))
    exe (g:netrw_alto? "top " : "bot ")."vert ".winsz."wincmd s"
   else
    " horizontally split preview window
    let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
"    call Decho("exe ".(g:netrw_alto? "bel " : "abo ").winsz."wincmd s",'~'.expand("<slnum>"))
    exe (g:netrw_alto? "bel " : "abo ").winsz."wincmd s"
   endif
   let didsplit = 1
"   call Decho("did split",'~'.expand("<slnum>"))

  else
"   call Decho("COMBAK#7: mod=".&mod." win#".winnr())
   NetrwKeepj call s:SaveBufVars()
"   call Decho("COMBAK#8: mod=".&mod." win#".winnr())
   let eikeep= &ei
"   call Decho("COMBAK#9: mod=".&mod." win#".winnr())
   setl ei=all
"   call Decho("COMBAK#10: mod=".&mod." win#".winnr())
   wincmd p
"  call Decho("COMBAK#11: mod=".&mod)
"   call Decho("wincmd p  (now in win#".winnr().") curdir<".curdir.">",'~'.expand("<slnum>"))
"  call Decho("COMBAK#12: mod=".&mod)
   
   if exists("s:lexplore_win") && s:lexplore_win == winnr()
    " whoops -- user trying to open file in the Lexplore window.
    " Use Lexplore's opening-file window instead.
"    call Decho("whoops -- user trying to open file in Lexplore Window. Use win#".g:netrw_chgwin." instead")
"    exe g:netrw_chgwin."wincmd w"
     wincmd p
     call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,s:NetrwGetWord()))
   endif

   " prevwinnr: the window number of the "prev" window
   " prevbufnr: the buffer number of the buffer in the "prev" window
   " bnrcnt   : the qty of windows open on the "prev" buffer
   let prevwinnr   = winnr()
   let prevbufnr   = bufnr("%")
   let prevbufname = bufname("%")
   let prevmod     = &mod
   let bnrcnt      = 0
"   call Decho("COMBAK#13: mod=".&mod." win#".winnr())
   NetrwKeepj call s:RestoreBufVars()
"   call Decho("after wincmd p: win#".winnr()." win($)#".winnr("$")." origwin#".origwin." &mod=".&mod." bufname(%)<".bufname("%")."> prevbufnr=".prevbufnr,'~'.expand("<slnum>"))
"   call Decho("COMBAK#14: mod=".&mod." win#".winnr())

   " if the previous window's buffer has been changed (ie. its modified flag is set),
   " and it doesn't appear in any other extant window, then ask the
   " user if s/he wants to abandon modifications therein.
   if prevmod
"    call Decho("detected that prev window's buffer has been modified: prevbufnr=".prevbufnr." winnr()#".winnr(),'~'.expand("<slnum>"))
    windo if winbufnr(0) == prevbufnr | let bnrcnt=bnrcnt+1 | endif
"    call Decho("prevbufnr=".prevbufnr." bnrcnt=".bnrcnt." buftype=".&bt." winnr()=".winnr()." prevwinnr#".prevwinnr,'~'.expand("<slnum>"))
    exe prevwinnr."wincmd w"
"    call Decho("COMBAK#15: mod=".&mod." win#".winnr())

    if bnrcnt == 1 && &hidden == 0
     " only one copy of the modified buffer in a window, and
     " hidden not set, so overwriting will lose the modified file.  Ask first...
     let choice = confirm("Save modified buffer<".prevbufname."> first?","&Yes\n&No\n&Cancel")
"     call Decho("prevbufname<".prevbufname."> choice=".choice." current-winnr#".winnr(),'~'.expand("<slnum>"))
     let &ei= eikeep
"     call Decho("COMBAK#16: mod=".&mod." win#".winnr())

     if choice == 1
      " Yes -- write file & then browse
      let v:errmsg= ""
      sil w
      if v:errmsg != ""
       call netrw#ErrorMsg(s:ERROR,"unable to write <".(exists("prevbufname")? prevbufname : 'n/a').">!",30)
       exe origwin."wincmd w"
       let &ei = eikeep
       let @@  = ykeep
"       call Dret("s:NetrwPrevWinOpen ".choice." : unable to write <".prevbufname.">")
       return choice
      endif

     elseif choice == 2
      " No -- don't worry about changed file, just browse anyway
"      call Decho("don't worry about chgd file, just browse anyway (winnr($)#".winnr("$").")",'~'.expand("<slnum>"))
      echomsg "**note** changes to ".prevbufname." abandoned"

     else
      " Cancel -- don't do this
"      call Decho("cancel, don't browse, switch to win#".origwin,'~'.expand("<slnum>"))
      exe origwin."wincmd w"
      let &ei= eikeep
      let @@ = ykeep
"      call Dret("s:NetrwPrevWinOpen ".choice." : cancelled")
      return choice
     endif
    endif
   endif
   let &ei= eikeep
  endif
"  call Decho("COMBAK#17: mod=".&mod." win#".winnr())

  " restore b:netrw_curdir (window split/enew may have lost it)
  let b:netrw_curdir= curdir
  if a:islocal < 2
   if a:islocal
    call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(a:islocal,curword))
   else
    call s:NetrwBrowse(a:islocal,s:NetrwBrowseChgDir(a:islocal,curword))
   endif
  endif
  let @@= ykeep
"  call Dret("s:NetrwPrevWinOpen ".choice)
  return choice
endfun

" ---------------------------------------------------------------------
" s:NetrwUpload: load fname to tgt (used by NetrwMarkFileCopy()) {{{2
"                Always assumed to be local -> remote
"                call s:NetrwUpload(filename, target)
"                call s:NetrwUpload(filename, target, fromdirectory)
fun! s:NetrwUpload(fname,tgt,...)
"  call Dfunc("s:NetrwUpload(fname<".((type(a:fname) == 1)? a:fname : string(a:fname))."> tgt<".a:tgt.">) a:0=".a:0)

  if a:tgt =~ '^\a\{3,}://'
   let tgtdir= substitute(a:tgt,'^\a\{3,}://[^/]\+/\(.\{-}\)$','\1','')
  else
   let tgtdir= substitute(a:tgt,'^\(.*\)/[^/]*$','\1','')
  endif
"  call Decho("tgtdir<".tgtdir.">",'~'.expand("<slnum>"))

  if a:0 > 0
   let fromdir= a:1
  else
   let fromdir= getcwd()
  endif
"  call Decho("fromdir<".fromdir.">",'~'.expand("<slnum>"))

  if type(a:fname) == 1
   " handle uploading a single file using NetWrite
"   call Decho("handle uploading a single file via NetWrite",'~'.expand("<slnum>"))
   1split
"   call Decho("exe e ".fnameescape(s:NetrwFile(a:fname)),'~'.expand("<slnum>"))
   exe "NetrwKeepj e ".fnameescape(s:NetrwFile(a:fname))
"   call Decho("now locally editing<".expand("%").">, has ".line("$")." lines",'~'.expand("<slnum>"))
   if a:tgt =~ '/$'
    let wfname= substitute(a:fname,'^.*/','','')
"    call Decho("exe w! ".fnameescape(wfname),'~'.expand("<slnum>"))
    exe "w! ".fnameescape(a:tgt.wfname)
   else
"    call Decho("writing local->remote: exe w ".fnameescape(a:tgt),'~'.expand("<slnum>"))
    exe "w ".fnameescape(a:tgt)
"    call Decho("done writing local->remote",'~'.expand("<slnum>"))
   endif
   q!

  elseif type(a:fname) == 3
   " handle uploading a list of files via scp
"   call Decho("handle uploading a list of files via scp",'~'.expand("<slnum>"))
   let curdir= getcwd()
   if a:tgt =~ '^scp:'
    if s:NetrwLcd(fromdir)
"     call Dret("s:NetrwUpload : lcd failure")
     return
    endif
    let filelist= deepcopy(s:netrwmarkfilelist_{bufnr('%')})
    let args    = join(map(filelist,"s:ShellEscape(v:val, 1)"))
    if exists("g:netrw_port") && g:netrw_port != ""
     let useport= " ".g:netrw_scpport." ".g:netrw_port
    else
     let useport= ""
    endif
    let machine = substitute(a:tgt,'^scp://\([^/:]\+\).*$','\1','')
    let tgt     = substitute(a:tgt,'^scp://[^/]\+/\(.*\)$','\1','')
    call s:NetrwExe(s:netrw_silentxfer."!".g:netrw_scp_cmd.s:ShellEscape(useport,1)." ".args." ".s:ShellEscape(machine.":".tgt,1))
    if s:NetrwLcd(curdir)
"     call Dret("s:NetrwUpload : lcd failure")
     return
    endif

   elseif a:tgt =~ '^ftp:'
    call s:NetrwMethod(a:tgt)

    if b:netrw_method == 2
     " handle uploading a list of files via ftp+.netrc
     let netrw_fname = b:netrw_fname
     sil NetrwKeepj new
"     call Decho("filter input window#".winnr(),'~'.expand("<slnum>"))

     NetrwKeepj put =g:netrw_ftpmode
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))

     if exists("g:netrw_ftpextracmd")
      NetrwKeepj put =g:netrw_ftpextracmd
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endif

     NetrwKeepj call setline(line("$")+1,'lcd "'.fromdir.'"')
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))

     if tgtdir == ""
      let tgtdir= '/'
     endif
     NetrwKeepj call setline(line("$")+1,'cd "'.tgtdir.'"')
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))

     for fname in a:fname
      NetrwKeepj call setline(line("$")+1,'put "'.s:NetrwFile(fname).'"')
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endfor

     if exists("g:netrw_port") && g:netrw_port != ""
      call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1)." ".s:ShellEscape(g:netrw_port,1))
     else
"      call Decho("filter input window#".winnr(),'~'.expand("<slnum>"))
      call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1))
     endif
     " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
     sil NetrwKeepj g/Local directory now/d
     call histdel("/",-1)
     if getline(1) !~ "^$" && !exists("g:netrw_quiet") && getline(1) !~ '^Trying '
      call netrw#ErrorMsg(s:ERROR,getline(1),14)
     else
      bw!|q
     endif

    elseif b:netrw_method == 3
     " upload with ftp + machine, id, passwd, and fname (ie. no .netrc)
     let netrw_fname= b:netrw_fname
     NetrwKeepj call s:SaveBufVars()|sil NetrwKeepj new|NetrwKeepj call s:RestoreBufVars()
     let tmpbufnr= bufnr("%")
     setl ff=unix

     if exists("g:netrw_port") && g:netrw_port != ""
      NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     else
      NetrwKeepj put ='open '.g:netrw_machine
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endif

     if exists("g:netrw_uid") && g:netrw_uid != ""
      if exists("g:netrw_ftp") && g:netrw_ftp == 1
       NetrwKeepj put =g:netrw_uid
"       call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
       if exists("s:netrw_passwd")
        NetrwKeepj call setline(line("$")+1,'"'.s:netrw_passwd.'"')
       endif
"       call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
      elseif exists("s:netrw_passwd")
       NetrwKeepj put ='user \"'.g:netrw_uid.'\" \"'.s:netrw_passwd.'\"'
"       call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
      endif
     endif

     NetrwKeepj call setline(line("$")+1,'lcd "'.fromdir.'"')
"     call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))

     if exists("b:netrw_fname") && b:netrw_fname != ""
      NetrwKeepj call setline(line("$")+1,'cd "'.b:netrw_fname.'"')
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endif

     if exists("g:netrw_ftpextracmd")
      NetrwKeepj put =g:netrw_ftpextracmd
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endif

     for fname in a:fname
      NetrwKeepj call setline(line("$")+1,'put "'.fname.'"')
"      call Decho("filter input: ".getline('$'),'~'.expand("<slnum>"))
     endfor

     " perform ftp:
     " -i       : turns off interactive prompting from ftp
     " -n  unix : DON'T use <.netrc>, even though it exists
     " -n  win32: quit being obnoxious about password
     NetrwKeepj norm! 1G"_dd
     call s:NetrwExe(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
     " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
     sil NetrwKeepj g/Local directory now/d
     call histdel("/",-1)
     if getline(1) !~ "^$" && !exists("g:netrw_quiet") && getline(1) !~ '^Trying '
      let debugkeep= &debug
      setl debug=msg
      call netrw#ErrorMsg(s:ERROR,getline(1),15)
      let &debug = debugkeep
      let mod    = 1
     else
      bw!|q
     endif
    elseif !exists("b:netrw_method") || b:netrw_method < 0
"     call Dret("s:#NetrwUpload : unsupported method")
     return
    endif
   else
    call netrw#ErrorMsg(s:ERROR,"can't obtain files with protocol from<".a:tgt.">",63)
   endif
  endif

"  call Dret("s:NetrwUpload")
endfun

" ---------------------------------------------------------------------
" s:NetrwPreview: supports netrw's "p" map {{{2
fun! s:NetrwPreview(path) range
"  call Dfunc("NetrwPreview(path<".a:path.">)")
"  call Decho("g:netrw_alto   =".(exists("g:netrw_alto")?    g:netrw_alto    : 'n/a'),'~'.expand("<slnum>"))
"  call Decho("g:netrw_preview=".(exists("g:netrw_preview")? g:netrw_preview : 'n/a'),'~'.expand("<slnum>"))
  let ykeep= @@
  NetrwKeepj call s:NetrwOptionsSave("s:")
  if a:path !~ '^\*\{1,2}/' && a:path !~ '^\a\{3,}://'
   NetrwKeepj call s:NetrwOptionsSafe(1)
  else
   NetrwKeepj call s:NetrwOptionsSafe(0)
  endif
  if has("quickfix")
"   call Decho("has quickfix",'~'.expand("<slnum>"))
   if !isdirectory(s:NetrwFile(a:path))
"    call Decho("good; not previewing a directory",'~'.expand("<slnum>"))
    if g:netrw_preview
     " vertical split
     let pvhkeep = &pvh
     let winsz   = (g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize
     let &pvh    = winwidth(0) - winsz
"     call Decho("g:netrw_preview: winsz=".winsz." &pvh=".&pvh." (temporarily)  g:netrw_winsize=".g:netrw_winsize,'~'.expand("<slnum>"))
    else
     " horizontal split
     let pvhkeep = &pvh
     let winsz   = (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
     let &pvh    = winheight(0) - winsz
"     call Decho("!g:netrw_preview: winsz=".winsz." &pvh=".&pvh." (temporarily)  g:netrw_winsize=".g:netrw_winsize,'~'.expand("<slnum>"))
    endif
    " g:netrw_preview   g:netrw_alto
    "    1 : vert        1: top       -- preview window is vertically   split off and on the left
    "    1 : vert        0: bot       -- preview window is vertically   split off and on the right
    "    0 :             1: top       -- preview window is horizontally split off and on the top
    "    0 :             0: bot       -- preview window is horizontally split off and on the bottom
    "
    " Note that the file being previewed is already known to not be a directory, hence we can avoid doing a LocalBrowseCheck() check via
    " the BufEnter event set up in netrwPlugin.vim
"    call Decho("exe ".(g:netrw_alto? "top " : "bot ").(g:netrw_preview? "vert " : "")."pedit ".fnameescape(a:path),'~'.expand("<slnum>"))
    let eikeep = &ei
    set ei=BufEnter
    exe (g:netrw_alto? "top " : "bot ").(g:netrw_preview? "vert " : "")."pedit ".fnameescape(a:path)
    let &ei= eikeep
"    call Decho("winnr($)=".winnr("$"),'~'.expand("<slnum>"))
    if exists("pvhkeep")
     let &pvh= pvhkeep
    endif
   elseif !exists("g:netrw_quiet")
    NetrwKeepj call netrw#ErrorMsg(s:WARNING,"sorry, cannot preview a directory such as <".a:path.">",38)
   endif
  elseif !exists("g:netrw_quiet")
   NetrwKeepj call netrw#ErrorMsg(s:WARNING,"sorry, to preview your vim needs the quickfix feature compiled in",39)
  endif
  NetrwKeepj call s:NetrwOptionsRestore("s:")
  let @@= ykeep
"  call Dret("NetrwPreview")
endfun

" ---------------------------------------------------------------------
" s:NetrwRefresh: {{{2
fun! s:NetrwRefresh(islocal,dirname)
"  call Dfunc("s:NetrwRefresh(islocal<".a:islocal.">,dirname=".a:dirname.") g:netrw_hide=".g:netrw_hide." g:netrw_sort_direction=".g:netrw_sort_direction)
  " at the current time (Mar 19, 2007) all calls to NetrwRefresh() call NetrwBrowseChgDir() first.
  setl ma noro
"  call Decho("setl ma noro",'~'.expand("<slnum>"))
"  call Decho("clear buffer<".expand("%")."> with :%d",'~'.expand("<slnum>"))
  let ykeep      = @@
  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
   if !exists("w:netrw_treetop")
    if exists("b:netrw_curdir")
     let w:netrw_treetop= b:netrw_curdir
    else
     let w:netrw_treetop= getcwd()
    endif
   endif
   NetrwKeepj call s:NetrwRefreshTreeDict(w:netrw_treetop)
  endif

  " save the cursor position before refresh.
  let screenposn = winsaveview()
"  call Decho("saving posn to screenposn<".string(screenposn).">",'~'.expand("<slnum>"))

"  call Decho("win#".winnr().": ".winheight(0)."x".winwidth(0)." curfile<".expand("%").">",'~'.expand("<slnum>"))
"  call Decho("clearing buffer prior to refresh",'~'.expand("<slnum>"))
  sil! NetrwKeepj %d _
  if a:islocal
   NetrwKeepj call netrw#LocalBrowseCheck(a:dirname)
  else
   NetrwKeepj call s:NetrwBrowse(a:islocal,a:dirname)
  endif

  " restore position
"  call Decho("restoring posn to screenposn<".string(screenposn).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(screenposn)

  " restore file marks
  if has("syntax") && exists("g:syntax_on") && g:syntax_on
   if exists("s:netrwmarkfilemtch_{bufnr('%')}") && s:netrwmarkfilemtch_{bufnr("%")} != ""
" "   call Decho("exe 2match netrwMarkFile /".s:netrwmarkfilemtch_{bufnr("%")}."/",'~'.expand("<slnum>"))
    exe "2match netrwMarkFile /".s:netrwmarkfilemtch_{bufnr("%")}."/"
   else
" "   call Decho("2match none  (bufnr(%)=".bufnr("%")."<".bufname("%").">)",'~'.expand("<slnum>"))
    2match none
   endif
 endif

"  restore
  let @@= ykeep
"  call Dret("s:NetrwRefresh")
endfun

" ---------------------------------------------------------------------
" s:NetrwRefreshDir: refreshes a directory by name {{{2
"                    Called by NetrwMarkFileCopy()
"                    Interfaces to s:NetrwRefresh() and s:LocalBrowseRefresh()
fun! s:NetrwRefreshDir(islocal,dirname)
"  call Dfunc("s:NetrwRefreshDir(islocal=".a:islocal." dirname<".a:dirname.">) g:netrw_fastbrowse=".g:netrw_fastbrowse)
  if g:netrw_fastbrowse == 0
   " slowest mode (keep buffers refreshed, local or remote)
"   call Decho("slowest mode: keep buffers refreshed, local or remote",'~'.expand("<slnum>"))
   let tgtwin= bufwinnr(a:dirname)
"   call Decho("tgtwin= bufwinnr(".a:dirname.")=".tgtwin,'~'.expand("<slnum>"))

   if tgtwin > 0
    " tgtwin is being displayed, so refresh it
    let curwin= winnr()
"    call Decho("refresh tgtwin#".tgtwin." (curwin#".curwin.")",'~'.expand("<slnum>"))
    exe tgtwin."wincmd w"
    NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
    exe curwin."wincmd w"

   elseif bufnr(a:dirname) > 0
    let bn= bufnr(a:dirname)
"    call Decho("bd bufnr(".a:dirname.")=".bn,'~'.expand("<slnum>"))
    exe "sil keepj bd ".bn
   endif

  elseif g:netrw_fastbrowse <= 1
"   call Decho("medium-speed mode: refresh local buffers only",'~'.expand("<slnum>"))
   NetrwKeepj call s:LocalBrowseRefresh()
  endif
"  call Dret("s:NetrwRefreshDir")
endfun

" ---------------------------------------------------------------------
" s:NetrwSetChgwin: set g:netrw_chgwin; a <cr> will use the specified
" window number to do its editing in.
" Supports   [count]C  where the count, if present, is used to specify
" a window to use for editing via the <cr> mapping.
fun! s:NetrwSetChgwin(...)
"  call Dfunc("s:NetrwSetChgwin() v:count=".v:count)
  if a:0 > 0
"   call Decho("a:1<".a:1.">",'~'.expand("<slnum>"))
   if a:1 == ""    " :NetrwC win#
    let g:netrw_chgwin= winnr()
   else              " :NetrwC
    let g:netrw_chgwin= a:1
   endif
  elseif v:count > 0 " [count]C
   let g:netrw_chgwin= v:count
  else               " C
   let g:netrw_chgwin= winnr()
  endif
  echo "editing window now set to window#".g:netrw_chgwin
"  call Dret("s:NetrwSetChgwin : g:netrw_chgwin=".g:netrw_chgwin)
endfun

" ---------------------------------------------------------------------
" s:NetrwSetSort: sets up the sort based on the g:netrw_sort_sequence {{{2
"          What this function does is to compute a priority for the patterns
"          in the g:netrw_sort_sequence.  It applies a substitute to any
"          "files" that satisfy each pattern, putting the priority / in
"          front.  An "*" pattern handles the default priority.
fun! s:NetrwSetSort()
"  call Dfunc("SetSort() bannercnt=".w:netrw_bannercnt)
  let ykeep= @@
  if w:netrw_liststyle == s:LONGLIST
   let seqlist  = substitute(g:netrw_sort_sequence,'\$','\\%(\t\\|\$\\)','ge')
  else
   let seqlist  = g:netrw_sort_sequence
  endif
  " sanity check -- insure that * appears somewhere
  if seqlist == ""
   let seqlist= '*'
  elseif seqlist !~ '\*'
   let seqlist= seqlist.',*'
  endif
  let priority = 1
  while seqlist != ""
   if seqlist =~ ','
    let seq     = substitute(seqlist,',.*$','','e')
    let seqlist = substitute(seqlist,'^.\{-},\(.*\)$','\1','e')
   else
    let seq     = seqlist
    let seqlist = ""
   endif
   if priority < 10
    let spriority= "00".priority.g:netrw_sepchr
   elseif priority < 100
    let spriority= "0".priority.g:netrw_sepchr
   else
    let spriority= priority.g:netrw_sepchr
   endif
"   call Decho("priority=".priority." spriority<".spriority."> seq<".seq."> seqlist<".seqlist.">",'~'.expand("<slnum>"))

   " sanity check
   if w:netrw_bannercnt > line("$")
    " apparently no files were left after a Hiding pattern was used
"    call Dret("SetSort : no files left after hiding")
    return
   endif
   if seq == '*'
    let starpriority= spriority
   else
    exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$g/'.seq.'/s/^/'.spriority.'/'
    call histdel("/",-1)
    " sometimes multiple sorting patterns will match the same file or directory.
    " The following substitute is intended to remove the excess matches.
    exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$g/^\d\{3}'.g:netrw_sepchr.'\d\{3}\//s/^\d\{3}'.g:netrw_sepchr.'\(\d\{3}\/\).\@=/\1/e'
    NetrwKeepj call histdel("/",-1)
   endif
   let priority = priority + 1
  endwhile
  if exists("starpriority")
   exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$v/^\d\{3}'.g:netrw_sepchr.'/s/^/'.starpriority.'/e'
   NetrwKeepj call histdel("/",-1)
  endif

  " Following line associated with priority -- items that satisfy a priority
  " pattern get prefixed by ###/ which permits easy sorting by priority.
  " Sometimes files can satisfy multiple priority patterns -- only the latest
  " priority pattern needs to be retained.  So, at this point, these excess
  " priority prefixes need to be removed, but not directories that happen to
  " be just digits themselves.
  exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$s/^\(\d\{3}'.g:netrw_sepchr.'\)\%(\d\{3}'.g:netrw_sepchr.'\)\+\ze./\1/e'
  NetrwKeepj call histdel("/",-1)
  let @@= ykeep

"  call Dret("SetSort")
endfun

" ---------------------------------------------------------------------
" s:NetrwSetTgt: sets the target to the specified choice index {{{2
"    Implements [count]Tb  (bookhist<b>)
"               [count]Th  (bookhist<h>)
"               See :help netrw-qb for how to make the choice.
fun! s:NetrwSetTgt(islocal,bookhist,choice)
"  call Dfunc("s:NetrwSetTgt(islocal=".a:islocal." bookhist<".a:bookhist."> choice#".a:choice.")")

  if     a:bookhist == 'b'
   " supports choosing a bookmark as a target using a qb-generated list
   let choice= a:choice - 1
   if exists("g:netrw_bookmarklist[".choice."]")
    call netrw#MakeTgt(g:netrw_bookmarklist[choice])
   else
    echomsg "Sorry, bookmark#".a:choice." doesn't exist!"
   endif

  elseif a:bookhist == 'h'
   " supports choosing a history stack entry as a target using a qb-generated list
   let choice= (a:choice % g:netrw_dirhistmax) + 1
   if exists("g:netrw_dirhist_".choice)
    let histentry = g:netrw_dirhist_{choice}
    call netrw#MakeTgt(histentry)
   else
    echomsg "Sorry, history#".a:choice." not available!"
   endif
  endif

  " refresh the display
  if !exists("b:netrw_curdir")
   let b:netrw_curdir= getcwd()
  endif
  call s:NetrwRefresh(a:islocal,b:netrw_curdir)

"  call Dret("s:NetrwSetTgt")
endfun

" =====================================================================
" s:NetrwSortStyle: change sorting style (name - time - size - exten) and refresh display {{{2
fun! s:NetrwSortStyle(islocal)
"  call Dfunc("s:NetrwSortStyle(islocal=".a:islocal.") netrw_sort_by<".g:netrw_sort_by.">")
  NetrwKeepj call s:NetrwSaveWordPosn()
  let svpos= winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))

  let g:netrw_sort_by= (g:netrw_sort_by =~# '^n')? 'time' : (g:netrw_sort_by =~# '^t')? 'size' : (g:netrw_sort_by =~# '^siz')? 'exten' : 'name'
  NetrwKeepj norm! 0
  NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)

"  call Dret("s:NetrwSortStyle : netrw_sort_by<".g:netrw_sort_by.">")
endfun

" ---------------------------------------------------------------------
" s:NetrwSplit: mode {{{2
"           =0 : net   and o
"           =1 : net   and t
"           =2 : net   and v
"           =3 : local and o
"           =4 : local and t
"           =5 : local and v
fun! s:NetrwSplit(mode)
"  call Dfunc("s:NetrwSplit(mode=".a:mode.") alto=".g:netrw_alto." altv=".g:netrw_altv)

  let ykeep= @@
  call s:SaveWinVars()

  if a:mode == 0
   " remote and o
   let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
   if winsz == 0|let winsz= ""|endif
"   call Decho("exe ".(g:netrw_alto? "bel " : "abo ").winsz."wincmd s",'~'.expand("<slnum>"))
   exe (g:netrw_alto? "bel " : "abo ").winsz."wincmd s"
   let s:didsplit= 1
   NetrwKeepj call s:RestoreWinVars()
   NetrwKeepj call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,s:NetrwGetWord()))
   unlet s:didsplit

  elseif a:mode == 1
   " remote and t
   let newdir  = s:NetrwBrowseChgDir(0,s:NetrwGetWord())
"   call Decho("tabnew",'~'.expand("<slnum>"))
   tabnew
   let s:didsplit= 1
   NetrwKeepj call s:RestoreWinVars()
   NetrwKeepj call s:NetrwBrowse(0,newdir)
   unlet s:didsplit

  elseif a:mode == 2
   " remote and v
   let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize
   if winsz == 0|let winsz= ""|endif
"   call Decho("exe ".(g:netrw_altv? "rightb " : "lefta ").winsz."wincmd v",'~'.expand("<slnum>"))
   exe (g:netrw_altv? "rightb " : "lefta ").winsz."wincmd v"
   let s:didsplit= 1
   NetrwKeepj call s:RestoreWinVars()
   NetrwKeepj call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,s:NetrwGetWord()))
   unlet s:didsplit

  elseif a:mode == 3
   " local and o
   let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
   if winsz == 0|let winsz= ""|endif
"   call Decho("exe ".(g:netrw_alto? "bel " : "abo ").winsz."wincmd s",'~'.expand("<slnum>"))
   exe (g:netrw_alto? "bel " : "abo ").winsz."wincmd s"
   let s:didsplit= 1
   NetrwKeepj call s:RestoreWinVars()
   NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,s:NetrwGetWord()))
   unlet s:didsplit

  elseif a:mode == 4
   " local and t
   let cursorword  = s:NetrwGetWord()
   let eikeep      = &ei
   let netrw_winnr = winnr()
   let netrw_line  = line(".")
   let netrw_col   = virtcol(".")
   NetrwKeepj norm! H0
   let netrw_hline = line(".")
   setl ei=all
   exe "NetrwKeepj norm! ".netrw_hline."G0z\<CR>"
   exe "NetrwKeepj norm! ".netrw_line."G0".netrw_col."\<bar>"
   let &ei          = eikeep
   let netrw_curdir = s:NetrwTreeDir(0)
"   call Decho("tabnew",'~'.expand("<slnum>"))
   tabnew
   let b:netrw_curdir = netrw_curdir
   let s:didsplit     = 1
   NetrwKeepj call s:RestoreWinVars()
   NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,cursorword))
   if &ft == "netrw"
    setl ei=all
    exe "NetrwKeepj norm! ".netrw_hline."G0z\<CR>"
    exe "NetrwKeepj norm! ".netrw_line."G0".netrw_col."\<bar>"
    let &ei= eikeep
   endif
   unlet s:didsplit

  elseif a:mode == 5
   " local and v
   let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize
   if winsz == 0|let winsz= ""|endif
"   call Decho("exe ".(g:netrw_altv? "rightb " : "lefta ").winsz."wincmd v",'~'.expand("<slnum>"))
   exe (g:netrw_altv? "rightb " : "lefta ").winsz."wincmd v"
   let s:didsplit= 1
   NetrwKeepj call s:RestoreWinVars()
   NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,s:NetrwGetWord()))
   unlet s:didsplit

  else
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"(NetrwSplit) unsupported mode=".a:mode,45)
  endif

  let @@= ykeep
"  call Dret("s:NetrwSplit")
endfun

" ---------------------------------------------------------------------
" s:NetrwTgtMenu: {{{2
fun! s:NetrwTgtMenu()
  if !exists("s:netrw_menucnt")
   return
  endif
"  call Dfunc("s:NetrwTgtMenu()")

  " the following test assures that gvim is running, has menus available, and has menus enabled.
  if has("gui") && has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu
   if exists("g:NetrwTopLvlMenu")
"    call Decho("removing ".g:NetrwTopLvlMenu."Bookmarks menu item(s)",'~'.expand("<slnum>"))
    exe 'sil! unmenu '.g:NetrwTopLvlMenu.'Targets'
   endif
   if !exists("s:netrw_initbookhist")
    call s:NetrwBookHistRead()
   endif

   " try to cull duplicate entries
   let tgtdict={}

   " target bookmarked places
   if exists("g:netrw_bookmarklist") && g:netrw_bookmarklist != [] && g:netrw_dirhistmax > 0
"    call Decho("installing bookmarks as easy targets",'~'.expand("<slnum>"))
    let cnt= 1
    for bmd in g:netrw_bookmarklist
     if has_key(tgtdict,bmd)
      let cnt= cnt + 1
      continue
     endif
     let tgtdict[bmd]= cnt
     let ebmd= escape(bmd,g:netrw_menu_escape)
     " show bookmarks for goto menu
"     call Decho("menu: Targets: ".bmd,'~'.expand("<slnum>"))
     exe 'sil! menu <silent> '.g:NetrwMenuPriority.".19.1.".cnt." ".g:NetrwTopLvlMenu.'Targets.'.ebmd."	:call netrw#MakeTgt('".bmd."')\<cr>"
     let cnt= cnt + 1
    endfor
   endif

   " target directory browsing history
   if exists("g:netrw_dirhistmax") && g:netrw_dirhistmax > 0
"    call Decho("installing history as easy targets (histmax=".g:netrw_dirhistmax.")",'~'.expand("<slnum>"))
    let histcnt = 1
    while histcnt <= g:netrw_dirhistmax
     let priority = g:netrw_dirhistcnt + histcnt
     if exists("g:netrw_dirhist_{histcnt}")
      let histentry  = g:netrw_dirhist_{histcnt}
      if has_key(tgtdict,histentry)
       let histcnt = histcnt + 1
       continue
      endif
      let tgtdict[histentry] = histcnt
      let ehistentry         = escape(histentry,g:netrw_menu_escape)
"      call Decho("menu: Targets: ".histentry,'~'.expand("<slnum>"))
      exe 'sil! menu <silent> '.g:NetrwMenuPriority.".19.2.".priority." ".g:NetrwTopLvlMenu.'Targets.'.ehistentry."	:call netrw#MakeTgt('".histentry."')\<cr>"
     endif
     let histcnt = histcnt + 1
    endwhile
   endif
  endif
"  call Dret("s:NetrwTgtMenu")
endfun

" ---------------------------------------------------------------------
" s:NetrwTreeDir: determine tree directory given current cursor position {{{2
" (full path directory with trailing slash returned)
fun! s:NetrwTreeDir(islocal)
"  call Dfunc("s:NetrwTreeDir(islocal=".a:islocal.") getline(".line(".").")"."<".getline('.')."> b:netrw_curdir<".b:netrw_curdir."> tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> ft=".&ft)
"  call Decho("Determine tree directory given current cursor position")
"  call Decho("g:netrw_keepdir  =".(exists("g:netrw_keepdir")?   g:netrw_keepdir   : 'n/a'),'~'.expand("<slnum>"))
"  call Decho("w:netrw_liststyle=".(exists("w:netrw_liststyle")? w:netrw_liststyle : 'n/a'),'~'.expand("<slnum>"))
"  call Decho("w:netrw_treetop  =".(exists("w:netrw_treetop")?   w:netrw_treetop   : 'n/a'),'~'.expand("<slnum>"))
"  call Decho("current line<".getline(".").">")

  if exists("s:treedir") && exists("s:prevwinopen")
   " s:NetrwPrevWinOpen opens a "previous" window -- and thus needs to and does call s:NetrwTreeDir early
"   call Decho('s:NetrwPrevWinOpen opens a "previous" window -- and thus needs to and does call s:NetrwTreeDir early')
   let treedir= s:treedir
   unlet s:treedir
   unlet s:prevwinopen
"   call Dret("s:NetrwTreeDir ".treedir.": early return since s:treedir existed previously")
   return treedir
  endif
  if exists("s:prevwinopen")
   unlet s:prevwinopen
  endif
"  call Decho("COMBAK#18 : mod=".&mod." win#".winnr())

  if !exists("b:netrw_curdir") || b:netrw_curdir == ""
   let b:netrw_curdir= getcwd()
  endif
  let treedir = b:netrw_curdir
"  call Decho("set initial treedir<".treedir.">",'~'.expand("<slnum>"))
"  call Decho("COMBAK#19 : mod=".&mod." win#".winnr())

  let s:treecurpos= winsaveview()
"  call Decho("saving posn to s:treecurpos<".string(s:treecurpos).">",'~'.expand("<slnum>"))
"  call Decho("COMBAK#20 : mod=".&mod." win#".winnr())

  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
"   call Decho("w:netrw_liststyle is TREELIST:",'~'.expand("<slnum>"))
"   call Decho("line#".line(".")." getline(.)<".getline('.')."> treecurpos<".string(s:treecurpos).">",'~'.expand("<slnum>"))
"  call Decho("COMBAK#21 : mod=".&mod." win#".winnr())

   " extract tree directory if on a line specifying a subdirectory (ie. ends with "/")
   let curline= substitute(getline('.'),"\t -->.*$",'','')
   if curline =~ '/$'
"    call Decho("extract tree subdirectory from current line",'~'.expand("<slnum>"))
    let treedir= substitute(getline('.'),'^\%('.s:treedepthstring.'\)*\([^'.s:treedepthstring.'].\{-}\)$','\1','e')
"    call Decho("treedir<".treedir.">",'~'.expand("<slnum>"))
   elseif curline =~ '@$'
"    call Decho("handle symbolic link from current line",'~'.expand("<slnum>"))
    let potentialdir= resolve(substitute(substitute(getline('.'),'@.*$','','e'),'^|*\s*','','e'))
"    call Decho("treedir<".treedir.">",'~'.expand("<slnum>"))
   else
"    call Decho("do not extract tree subdirectory from current line and set treedir to empty",'~'.expand("<slnum>"))
    let treedir= ""
   endif
"  call Decho("COMBAK#22 : mod=".&mod." win#".winnr())

   " detect user attempting to close treeroot
"   call Decho("check if user is attempting to close treeroot",'~'.expand("<slnum>"))
"   call Decho(".win#".winnr()." buf#".bufnr("%")."<".bufname("%").">",'~'.expand("<slnum>"))
"   call Decho(".getline(".line(".").")<".getline('.').'> '.((getline('.') =~# '^'.s:treedepthstring)? '=~#' : '!~').' ^'.s:treedepthstring,'~'.expand("<slnum>"))
   if curline !~ '^'.s:treedepthstring && getline('.') != '..'
"    call Decho(".user may have attempted to close treeroot",'~'.expand("<slnum>"))
    " now force a refresh
"    call Decho(".force refresh: clear buffer<".expand("%")."> with :%d",'~'.expand("<slnum>"))
    sil! NetrwKeepj %d _
"    call Dret("s:NetrwTreeDir <".treedir."> : (side effect) s:treecurpos<".(exists("s:treecurpos")? string(s:treecurpos) : 'n/a').">")
    return b:netrw_curdir
"   else " Decho
"    call Decho(".user not attempting to close treeroot",'~'.expand("<slnum>"))
   endif
"  call Decho("COMBAK#23 : mod=".&mod." win#".winnr())

"   call Decho("islocal=".a:islocal." curline<".curline.">",'~'.expand("<slnum>"))
"   call Decho("potentialdir<".potentialdir."> isdir=".isdirectory(potentialdir),'~'.expand("<slnum>"))
"  call Decho("COMBAK#24 : mod=".&mod." win#".winnr())

   " COMBAK: a symbolic link may point anywhere -- so it will be used to start a new treetop
"   if a:islocal && curline =~ '@$' && isdirectory(s:NetrwFile(potentialdir))
"    let newdir          = w:netrw_treetop.'/'.potentialdir
" "   call Decho("apply NetrwTreePath to newdir<".newdir.">",'~'.expand("<slnum>"))
"    let treedir         = s:NetrwTreePath(newdir)
"    let w:netrw_treetop = newdir
" "   call Decho("newdir <".newdir.">",'~'.expand("<slnum>"))
"   else
"    call Decho("apply NetrwTreePath to treetop<".w:netrw_treetop.">",'~'.expand("<slnum>"))
    if a:islocal && curline =~ '@$'
      if isdirectory(s:NetrwFile(potentialdir))
        let treedir = w:netrw_treetop.'/'.potentialdir.'/'
        let w:netrw_treetop = treedir
      endif
    else
      let potentialdir= s:NetrwFile(substitute(curline,'^'.s:treedepthstring.'\+ \(.*\)@$','\1',''))
      let treedir = s:NetrwTreePath(w:netrw_treetop)
    endif
  endif
"  call Decho("COMBAK#25 : mod=".&mod." win#".winnr())

  " sanity maintenance: keep those //s away...
  let treedir= substitute(treedir,'//$','/','')
"  call Decho("treedir<".treedir.">",'~'.expand("<slnum>"))
"  call Decho("COMBAK#26 : mod=".&mod." win#".winnr())

"  call Dret("s:NetrwTreeDir <".treedir."> : (side effect) s:treecurpos<".(exists("s:treecurpos")? string(s:treecurpos) : 'n/a').">")
  return treedir
endfun

" ---------------------------------------------------------------------
" s:NetrwTreeDisplay: recursive tree display {{{2
fun! s:NetrwTreeDisplay(dir,depth)
"  call Dfunc("NetrwTreeDisplay(dir<".a:dir."> depth<".a:depth.">)")

  " insure that there are no folds
  setl nofen

  " install ../ and shortdir
  if a:depth == ""
   call setline(line("$")+1,'../')
"   call Decho("setline#".line("$")." ../ (depth is zero)",'~'.expand("<slnum>"))
  endif
  if a:dir =~ '^\a\{3,}://'
   if a:dir == w:netrw_treetop
    let shortdir= a:dir
   else
    let shortdir= substitute(a:dir,'^.*/\([^/]\+\)/$','\1/','e')
   endif
   call setline(line("$")+1,a:depth.shortdir)
  else
   let shortdir= substitute(a:dir,'^.*/','','e')
   call setline(line("$")+1,a:depth.shortdir.'/')
  endif
"  call Decho("setline#".line("$")." shortdir<".a:depth.shortdir.">",'~'.expand("<slnum>"))
  " append a / to dir if its missing one
  let dir= a:dir

  " display subtrees (if any)
  let depth= s:treedepthstring.a:depth
"  call Decho("display subtrees with depth<".depth."> and current leaves",'~'.expand("<slnum>"))

  " implement g:netrw_hide for tree listings (uses g:netrw_list_hide)
  if     g:netrw_hide == 1
   " hide given patterns
   let listhide= split(g:netrw_list_hide,',')
"   call Decho("listhide=".string(listhide))
   for pat in listhide
    call filter(w:netrw_treedict[dir],'v:val !~ "'.escape(pat,'\\').'"')
   endfor

  elseif g:netrw_hide == 2
   " show given patterns (only)
   let listhide= split(g:netrw_list_hide,',')
"   call Decho("listhide=".string(listhide))
   let entries=[]
   for entry in w:netrw_treedict[dir]
    for pat in listhide
     if entry =~ pat
      call add(entries,entry)
      break
     endif
    endfor
   endfor
   let w:netrw_treedict[dir]= entries
  endif
  if depth != ""
   " always remove "." and ".." entries when there's depth
   call filter(w:netrw_treedict[dir],'v:val !~ "\\.\\.$"')
   call filter(w:netrw_treedict[dir],'v:val !~ "\\.$"')
  endif

"  call Decho("for every entry in w:netrw_treedict[".dir."]=".string(w:netrw_treedict[dir]),'~'.expand("<slnum>"))
  for entry in w:netrw_treedict[dir]
   if dir =~ '/$'
    let direntry= substitute(dir.entry,'[@/]$','','e')
   else
    let direntry= substitute(dir.'/'.entry,'[@/]$','','e')
   endif
"   call Decho("dir<".dir."> entry<".entry."> direntry<".direntry.">",'~'.expand("<slnum>"))
   if entry =~ '/$' && has_key(w:netrw_treedict,direntry)
"    call Decho("<".direntry."> is a key in treedict - display subtree for it",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwTreeDisplay(direntry,depth)
   elseif entry =~ '/$' && has_key(w:netrw_treedict,direntry.'/')
"    call Decho("<".direntry."/> is a key in treedict - display subtree for it",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwTreeDisplay(direntry.'/',depth)
   elseif entry =~ '@$' && has_key(w:netrw_treedict,direntry.'@')
"    call Decho("<".direntry."/> is a key in treedict - display subtree for it",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwTreeDisplay(direntry.'/',depth)
   else
"    call Decho("<".entry."> is not a key in treedict (no subtree)",'~'.expand("<slnum>"))
    sil! NetrwKeepj call setline(line("$")+1,depth.entry)
   endif
  endfor
"  call Decho("displaying: ".string(getline(w:netrw_bannercnt,'$')))

"  call Dret("NetrwTreeDisplay")
endfun

" ---------------------------------------------------------------------
" s:NetrwRefreshTreeDict: updates the contents information for a tree (w:netrw_treedict) {{{2
fun! s:NetrwRefreshTreeDict(dir)
"  call Dfunc("s:NetrwRefreshTreeDict(dir<".a:dir.">)")
  if !exists("w:netrw_treedict")
"   call Dret("s:NetrwRefreshTreeDict : w:netrw_treedict doesn't exist")
   return
  endif

  for entry in w:netrw_treedict[a:dir]
   let direntry= substitute(a:dir.'/'.entry,'[@/]$','','e')
"   call Decho("a:dir<".a:dir."> entry<".entry."> direntry<".direntry.">",'~'.expand("<slnum>"))

   if entry =~ '/$' && has_key(w:netrw_treedict,direntry)
"    call Decho("<".direntry."> is a key in treedict - display subtree for it",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwRefreshTreeDict(direntry)
    let liststar                   = s:NetrwGlob(direntry,'*',1)
    let listdotstar                = s:NetrwGlob(direntry,'.*',1)
    let w:netrw_treedict[direntry] = liststar + listdotstar
"    call Decho("updating w:netrw_treedict[".direntry.']='.string(w:netrw_treedict[direntry]),'~'.expand("<slnum>"))

   elseif entry =~ '/$' && has_key(w:netrw_treedict,direntry.'/')
"    call Decho("<".direntry."/> is a key in treedict - display subtree for it",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwRefreshTreeDict(direntry.'/')
    let liststar   = s:NetrwGlob(direntry.'/','*',1)
    let listdotstar= s:NetrwGlob(direntry.'/','.*',1)
    let w:netrw_treedict[direntry]= liststar + listdotstar
"    call Decho("updating w:netrw_treedict[".direntry.']='.string(w:netrw_treedict[direntry]),'~'.expand("<slnum>"))

   elseif entry =~ '@$' && has_key(w:netrw_treedict,direntry.'@')
"    call Decho("<".direntry."/> is a key in treedict - display subtree for it",'~'.expand("<slnum>"))
    NetrwKeepj call s:NetrwRefreshTreeDict(direntry.'/')
    let liststar   = s:NetrwGlob(direntry.'/','*',1)
    let listdotstar= s:NetrwGlob(direntry.'/','.*',1)
"    call Decho("updating w:netrw_treedict[".direntry.']='.string(w:netrw_treedict[direntry]),'~'.expand("<slnum>"))

   else
"    call Decho('not updating w:netrw_treedict['.string(direntry).'] with entry<'.string(entry).'> (no subtree)','~'.expand("<slnum>"))
   endif
  endfor
"  call Dret("s:NetrwRefreshTreeDict")
endfun

" ---------------------------------------------------------------------
" s:NetrwTreeListing: displays tree listing from treetop on down, using NetrwTreeDisplay() {{{2
"                     Called by s:PerformListing()
fun! s:NetrwTreeListing(dirname)
  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
"   call Dfunc("s:NetrwTreeListing() bufname<".expand("%").">")
"   call Decho("curdir<".a:dirname.">",'~'.expand("<slnum>"))
"   call Decho("win#".winnr().": w:netrw_treetop ".(exists("w:netrw_treetop")? "exists" : "doesn't exist")." w:netrw_treedict ".(exists("w:netrw_treedict")? "exists" : "doesn't exit"),'~'.expand("<slnum>"))
"   call Decho("g:netrw_banner=".g:netrw_banner.": banner ".(g:netrw_banner? "enabled" : "suppressed").": (line($)=".line("$")." byte2line(1)=".byte2line(1)." bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))

   " update the treetop
   if !exists("w:netrw_treetop")
"    call Decho("update the treetop  (w:netrw_treetop doesn't exist yet)",'~'.expand("<slnum>"))
    let w:netrw_treetop= a:dirname
    let s:netrw_treetop= w:netrw_treetop
"    call Decho("w:netrw_treetop<".w:netrw_treetop."> (reusing)",'~'.expand("<slnum>"))
   elseif (w:netrw_treetop =~ ('^'.a:dirname) && s:Strlen(a:dirname) < s:Strlen(w:netrw_treetop)) || a:dirname !~ ('^'.w:netrw_treetop)
"    call Decho("update the treetop  (override w:netrw_treetop with a:dirname<".a:dirname.">)",'~'.expand("<slnum>"))
    let w:netrw_treetop= a:dirname
    let s:netrw_treetop= w:netrw_treetop
"    call Decho("w:netrw_treetop<".w:netrw_treetop."> (went up)",'~'.expand("<slnum>"))
   endif
   if exists("w:netrw_treetop")
    let s:netrw_treetop= w:netrw_treetop
   else
    let w:netrw_treetop= getcwd()
    let s:netrw_treetop= w:netrw_treetop
   endif

   if !exists("w:netrw_treedict")
    " insure that we have a treedict, albeit empty
"    call Decho("initializing w:netrw_treedict to empty",'~'.expand("<slnum>"))
    let w:netrw_treedict= {}
   endif

   " update the dictionary for the current directory
"   call Decho("updating: w:netrw_treedict[".a:dirname.'] -> [directory listing]','~'.expand("<slnum>"))
"   call Decho("w:netrw_bannercnt=".w:netrw_bannercnt." line($)=".line("$"),'~'.expand("<slnum>"))
   exe "sil! NetrwKeepj ".w:netrw_bannercnt.',$g@^\.\.\=/$@d _'
   let w:netrw_treedict[a:dirname]= getline(w:netrw_bannercnt,line("$"))
"   call Decho("w:treedict[".a:dirname."]= ".string(w:netrw_treedict[a:dirname]),'~'.expand("<slnum>"))
   exe "sil! NetrwKeepj ".w:netrw_bannercnt.",$d _"

   " if past banner, record word
   if exists("w:netrw_bannercnt") && line(".") > w:netrw_bannercnt
    let fname= expand("<cword>")
   else
    let fname= ""
   endif
"   call Decho("fname<".fname.">",'~'.expand("<slnum>"))
"   call Decho("g:netrw_banner=".g:netrw_banner.": banner ".(g:netrw_banner? "enabled" : "suppressed").": (line($)=".line("$")." byte2line(1)=".byte2line(1)." bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))

   " display from treetop on down
"   call Decho("(s:NetrwTreeListing) w:netrw_treetop<".w:netrw_treetop.">")
   NetrwKeepj call s:NetrwTreeDisplay(w:netrw_treetop,"")
"   call Decho("s:NetrwTreeDisplay) setl noma nomod ro",'~'.expand("<slnum>"))

   " remove any blank line remaining as line#1 (happens in treelisting mode with banner suppressed)
   while getline(1) =~ '^\s*$' && byte2line(1) > 0
"    call Decho("deleting blank line",'~'.expand("<slnum>"))
    1d
   endwhile

   exe "setl ".g:netrw_bufsettings

"   call Dret("s:NetrwTreeListing : bufname<".expand("%").">")
   return
  endif
endfun

" ---------------------------------------------------------------------
" s:NetrwTreePath: returns path to current file/directory in tree listing {{{2
"                  Normally, treetop is w:netrw_treetop, but a
"                  user of the function ( netrw#SetTreetop() )
"                  wipes that out prior to calling this function
fun! s:NetrwTreePath(treetop)
"  call Dfunc("s:NetrwTreePath(treetop<".a:treetop.">) line#".line(".")."<".getline(".").">")
  if line(".") < w:netrw_bannercnt + 2
   let treedir= a:treetop
   if treedir !~ '/$'
    let treedir= treedir.'/'
   endif
"   call Dret("s:NetrwTreePath ".treedir." : line#".line(".")." ≤ ".(w:netrw_bannercnt+2))
   return treedir
  endif

  let svpos = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let depth = substitute(getline('.'),'^\(\%('.s:treedepthstring.'\)*\)[^'.s:treedepthstring.'].\{-}$','\1','e')
"  call Decho("depth<".depth."> 1st subst",'~'.expand("<slnum>"))
  let depth = substitute(depth,'^'.s:treedepthstring,'','')
"  call Decho("depth<".depth."> 2nd subst (first depth removed)",'~'.expand("<slnum>"))
  let curline= getline('.')
"  call Decho("curline<".curline.'>','~'.expand("<slnum>"))
  if curline =~ '/$'
"   call Decho("extract tree directory from current line",'~'.expand("<slnum>"))
   let treedir= substitute(curline,'^\%('.s:treedepthstring.'\)*\([^'.s:treedepthstring.'].\{-}\)$','\1','e')
"   call Decho("treedir<".treedir.">",'~'.expand("<slnum>"))
  elseif curline =~ '@\s\+-->'
"   call Decho("extract tree directory using symbolic link",'~'.expand("<slnum>"))
   let treedir= substitute(curline,'^\%('.s:treedepthstring.'\)*\([^'.s:treedepthstring.'].\{-}\)$','\1','e')
   let treedir= substitute(treedir,'@\s\+-->.*$','','e')
"   call Decho("treedir<".treedir.">",'~'.expand("<slnum>"))
  else
"   call Decho("do not extract tree directory from current line and set treedir to empty",'~'.expand("<slnum>"))
   let treedir= ""
  endif
  " construct treedir by searching backwards at correct depth
"  call Decho("construct treedir by searching backwards for correct depth",'~'.expand("<slnum>"))
"  call Decho("initial      treedir<".treedir."> depth<".depth.">",'~'.expand("<slnum>"))
  while depth != "" && search('^'.depth.'[^'.s:treedepthstring.'].\{-}/$','bW')
   let dirname= substitute(getline('.'),'^\('.s:treedepthstring.'\)*','','e')
   let treedir= dirname.treedir
   let depth  = substitute(depth,'^'.s:treedepthstring,'','')
"   call Decho("constructing treedir<".treedir.">: dirname<".dirname."> while depth<".depth.">",'~'.expand("<slnum>"))
  endwhile
"  call Decho("treedir#1<".treedir.">",'~'.expand("<slnum>"))
  if a:treetop =~ '/$'
   let treedir= a:treetop.treedir
  else
   let treedir= a:treetop.'/'.treedir
  endif
"  call Decho("treedir#2<".treedir.">",'~'.expand("<slnum>"))
  let treedir= substitute(treedir,'//$','/','')
"  call Decho("treedir#3<".treedir.">",'~'.expand("<slnum>"))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))"
  call winrestview(svpos)
"  call Dret("s:NetrwTreePath <".treedir.">")
  return treedir
endfun

" ---------------------------------------------------------------------
" s:NetrwWideListing: {{{2
fun! s:NetrwWideListing()

  if w:netrw_liststyle == s:WIDELIST
"   call Dfunc("NetrwWideListing() w:netrw_liststyle=".w:netrw_liststyle.' fo='.&fo.' l:fo='.&l:fo)
   " look for longest filename (cpf=characters per filename)
   " cpf: characters per filename
   " fpl: filenames per line
   " fpc: filenames per column
   setl ma noro
   let dict={}
   " save the unnamed register and register 0-9 and a
   let dict.a=[getreg('a'), getregtype('a')]
   for i in range(0, 9)
     let dict[i] = [getreg(i), getregtype(i)]
   endfor
   let dict.unnamed = [getreg(''), getregtype('')]
"   call Decho("setl ma noro",'~'.expand("<slnum>"))
   let b:netrw_cpf= 0
   if line("$") >= w:netrw_bannercnt
    " determine the maximum filename size; use that to set cpf
    exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$g/^./if virtcol("$") > b:netrw_cpf|let b:netrw_cpf= virtcol("$")|endif'
    NetrwKeepj call histdel("/",-1)
   else
    " restore stored registers
    call s:RestoreRegister(dict)
"    call Dret("NetrwWideListing")
    return
   endif
   " allow for two spaces to separate columns
   let b:netrw_cpf= b:netrw_cpf + 2
"   call Decho("b:netrw_cpf=max_filename_length+2=".b:netrw_cpf,'~'.expand("<slnum>"))

   " determine qty files per line (fpl)
   let w:netrw_fpl= winwidth(0)/b:netrw_cpf
   if w:netrw_fpl <= 0
    let w:netrw_fpl= 1
   endif
"   call Decho("fpl= [winwidth=".winwidth(0)."]/[b:netrw_cpf=".b:netrw_cpf.']='.w:netrw_fpl,'~'.expand("<slnum>"))

   " make wide display
   "   fpc: files per column of wide listing
   exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$s/^.*$/\=escape(printf("%-'.b:netrw_cpf.'S",submatch(0)),"\\")/'
   NetrwKeepj call histdel("/",-1)
   let fpc         = (line("$") - w:netrw_bannercnt + w:netrw_fpl)/w:netrw_fpl
   let newcolstart = w:netrw_bannercnt + fpc
   let newcolend   = newcolstart + fpc - 1
"   call Decho("bannercnt=".w:netrw_bannercnt." fpl=".w:netrw_fpl." fpc=".fpc." newcol[".newcolstart.",".newcolend."]",'~'.expand("<slnum>"))
   while line("$") >= newcolstart
    if newcolend > line("$") | let newcolend= line("$") | endif
    let newcolqty= newcolend - newcolstart
    exe newcolstart
    " COMBAK: both of the visual-mode using lines below are problematic vis-a-vis @*
    if newcolqty == 0
     exe "sil! NetrwKeepj norm! 0\<c-v>$h\"ax".w:netrw_bannercnt."G$\"ap"
    else
     exe "sil! NetrwKeepj norm! 0\<c-v>".newcolqty.'j$h"ax'.w:netrw_bannercnt.'G$"ap'
    endif
    exe "sil! NetrwKeepj ".newcolstart.','.newcolend.'d _'
    exe 'sil! NetrwKeepj '.w:netrw_bannercnt
   endwhile
   exe "sil! NetrwKeepj ".w:netrw_bannercnt.',$s/\s\+$//e'
   NetrwKeepj call histdel("/",-1)
   exe 'nno <buffer> <silent> w	:call search(''^.\\|\s\s\zs\S'',''W'')'."\<cr>"
   exe 'nno <buffer> <silent> b	:call search(''^.\\|\s\s\zs\S'',''bW'')'."\<cr>"
"   call Decho("NetrwWideListing) setl noma nomod ro",'~'.expand("<slnum>"))
   exe "setl ".g:netrw_bufsettings
   call s:RestoreRegister(dict)
"   call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"   call Dret("NetrwWideListing")
   return
  else
   if hasmapto("w","n")
    sil! nunmap <buffer> w
   endif
   if hasmapto("b","n")
    sil! nunmap <buffer> b
   endif
  endif
endfun

" ---------------------------------------------------------------------
" s:PerformListing: {{{2
fun! s:PerformListing(islocal)
"  call Dfunc("s:PerformListing(islocal=".a:islocal.")")
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol()." line($)=".line("$"),'~'.expand("<slnum>"))
"  call Decho("settings: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (enter)"." ei<".&ei.">",'~'.expand("<slnum>"))
  sil! NetrwKeepj %d _
"  call DechoBuf(bufnr("%"))

  " set up syntax highlighting {{{3
"  call Decho("--set up syntax highlighting (ie. setl ft=netrw)",'~'.expand("<slnum>"))
  sil! setl ft=netrw

  NetrwKeepj call s:NetrwOptionsSafe(a:islocal)
  setl noro ma
"  call Decho("setl noro ma bh=".&bh,'~'.expand("<slnum>"))

"  if exists("g:netrw_silent") && g:netrw_silent == 0 && &ch >= 1	" Decho
"   call Decho("Processing your browsing request...",'~'.expand("<slnum>"))
"  endif								" Decho

"  call Decho('w:netrw_liststyle='.(exists("w:netrw_liststyle")? w:netrw_liststyle : 'n/a'),'~'.expand("<slnum>"))
  if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
   " force a refresh for tree listings
"   call Decho("force refresh for treelisting: clear buffer<".expand("%")."> with :%d",'~'.expand("<slnum>"))
   sil! NetrwKeepj %d _
  endif

  " save current directory on directory history list
  NetrwKeepj call s:NetrwBookHistHandler(3,b:netrw_curdir)

  " Set up the banner {{{3
  if g:netrw_banner
"   call Decho("--set up banner",'~'.expand("<slnum>"))
   NetrwKeepj call setline(1,'" ============================================================================')
   if exists("g:netrw_pchk")
    " this undocumented option allows pchk to run with different versions of netrw without causing spurious
    " failure detections.
    NetrwKeepj call setline(2,'" Netrw Directory Listing')
   else
    NetrwKeepj call setline(2,'" Netrw Directory Listing                                        (netrw '.g:loaded_netrw.')')
   endif
   if exists("g:netrw_pchk")
    let curdir= substitute(b:netrw_curdir,expand("$HOME"),'~','')
   else
    let curdir= b:netrw_curdir
   endif
   if exists("g:netrw_bannerbackslash") && g:netrw_bannerbackslash
    NetrwKeepj call setline(3,'"   '.substitute(curdir,'/','\\','g'))
   else
    NetrwKeepj call setline(3,'"   '.curdir)
   endif
   let w:netrw_bannercnt= 3
   NetrwKeepj exe "sil! NetrwKeepj ".w:netrw_bannercnt
  else
"   call Decho("--no banner",'~'.expand("<slnum>"))
   NetrwKeepj 1
   let w:netrw_bannercnt= 1
  endif
"  call Decho("w:netrw_bannercnt=".w:netrw_bannercnt." win#".winnr(),'~'.expand("<slnum>"))
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol()." line($)=".line("$"),'~'.expand("<slnum>"))

  " construct sortby string: [name|time|size|exten] [reversed]
  let sortby= g:netrw_sort_by
  if g:netrw_sort_direction =~# "^r"
   let sortby= sortby." reversed"
  endif

  " Sorted by... {{{3
  if g:netrw_banner
"   call Decho("--handle specified sorting: g:netrw_sort_by<".g:netrw_sort_by.">",'~'.expand("<slnum>"))
   if g:netrw_sort_by =~# "^n"
"   call Decho("directories will be sorted by name",'~'.expand("<slnum>"))
    " sorted by name (also includes the sorting sequence in the banner)
    NetrwKeepj put ='\"   Sorted by      '.sortby
    NetrwKeepj put ='\"   Sort sequence: '.g:netrw_sort_sequence
    let w:netrw_bannercnt= w:netrw_bannercnt + 2
   else
"   call Decho("directories will be sorted by size or time",'~'.expand("<slnum>"))
    " sorted by time, size, exten
    NetrwKeepj put ='\"   Sorted by '.sortby
    let w:netrw_bannercnt= w:netrw_bannercnt + 1
   endif
   exe "sil! NetrwKeepj ".w:netrw_bannercnt
"  else " Decho
"   call Decho("g:netrw_banner=".g:netrw_banner.": banner ".(g:netrw_banner? "enabled" : "suppressed").": (line($)=".line("$")." byte2line(1)=".byte2line(1)." bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))
  endif

  " show copy/move target, if any {{{3
  if g:netrw_banner
   if exists("s:netrwmftgt") && exists("s:netrwmftgt_islocal")
"    call Decho("--show copy/move target<".s:netrwmftgt.">",'~'.expand("<slnum>"))
    NetrwKeepj put =''
    if s:netrwmftgt_islocal
     sil! NetrwKeepj call setline(line("."),'"   Copy/Move Tgt: '.s:netrwmftgt.' (local)')
    else
     sil! NetrwKeepj call setline(line("."),'"   Copy/Move Tgt: '.s:netrwmftgt.' (remote)')
    endif
    let w:netrw_bannercnt= w:netrw_bannercnt + 1
   else
"    call Decho("s:netrwmftgt does not exist, don't make Copy/Move Tgt",'~'.expand("<slnum>"))
   endif
   exe "sil! NetrwKeepj ".w:netrw_bannercnt
  endif

  " Hiding...  -or-  Showing... {{{3
  if g:netrw_banner
"   call Decho("--handle hiding/showing in banner (g:netrw_hide=".g:netrw_hide." g:netrw_list_hide<".g:netrw_list_hide.">)",'~'.expand("<slnum>"))
   if g:netrw_list_hide != "" && g:netrw_hide
    if g:netrw_hide == 1
     NetrwKeepj put ='\"   Hiding:        '.g:netrw_list_hide
    else
     NetrwKeepj put ='\"   Showing:       '.g:netrw_list_hide
    endif
    let w:netrw_bannercnt= w:netrw_bannercnt + 1
   endif
   exe "NetrwKeepj ".w:netrw_bannercnt

"   call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
   let quickhelp   = g:netrw_quickhelp%len(s:QuickHelp)
"   call Decho("quickhelp   =".quickhelp,'~'.expand("<slnum>"))
   NetrwKeepj put ='\"   Quick Help: <F1>:help  '.s:QuickHelp[quickhelp]
"   call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
   NetrwKeepj put ='\" =============================================================================='
   let w:netrw_bannercnt= w:netrw_bannercnt + 2
"  else " Decho
"   call Decho("g:netrw_banner=".g:netrw_banner.": banner ".(g:netrw_banner? "enabled" : "suppressed").": (line($)=".line("$")." byte2line(1)=".byte2line(1)." bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))
  endif

  " bannercnt should index the line just after the banner
  if g:netrw_banner
   let w:netrw_bannercnt= w:netrw_bannercnt + 1
   exe "sil! NetrwKeepj ".w:netrw_bannercnt
"   call Decho("--w:netrw_bannercnt=".w:netrw_bannercnt." (should index line just after banner) line($)=".line("$"),'~'.expand("<slnum>"))
"  else " Decho
"   call Decho("g:netrw_banner=".g:netrw_banner.": banner ".(g:netrw_banner? "enabled" : "suppressed").": (line($)=".line("$")." byte2line(1)=".byte2line(1)." bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))
  endif

  " get list of files
"  call Decho("--Get list of files - islocal=".a:islocal,'~'.expand("<slnum>"))
  if a:islocal
   NetrwKeepj call s:LocalListing()
  else " remote
   NetrwKeepj let badresult= s:NetrwRemoteListing()
   if badresult
"    call Decho("w:netrw_bannercnt=".(exists("w:netrw_bannercnt")? w:netrw_bannercnt : 'n/a')." win#".winnr()." buf#".bufnr("%")."<".bufname("%").">",'~'.expand("<slnum>"))
"    call Dret("s:PerformListing : error detected by NetrwRemoteListing")
    return
   endif
  endif

  " manipulate the directory listing (hide, sort) {{{3
  if !exists("w:netrw_bannercnt")
   let w:netrw_bannercnt= 0
  endif
"  call Decho("--manipulate directory listing (hide, sort)",'~'.expand("<slnum>"))
"  call Decho("g:netrw_banner=".g:netrw_banner." w:netrw_bannercnt=".w:netrw_bannercnt." (banner complete)",'~'.expand("<slnum>"))
"  call Decho("g:netrw_banner=".g:netrw_banner.": banner ".(g:netrw_banner? "enabled" : "suppressed").": (line($)=".line("$")." byte2line(1)=".byte2line(1)." bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))

  if !g:netrw_banner || line("$") >= w:netrw_bannercnt
"   call Decho("manipulate directory listing (support hide)",'~'.expand("<slnum>"))
"   call Decho("g:netrw_hide=".g:netrw_hide." g:netrw_list_hide<".g:netrw_list_hide.">",'~'.expand("<slnum>"))
   if g:netrw_hide && g:netrw_list_hide != ""
    NetrwKeepj call s:NetrwListHide()
   endif
   if !g:netrw_banner || line("$") >= w:netrw_bannercnt
"    call Decho("manipulate directory listing (sort) : g:netrw_sort_by<".g:netrw_sort_by.">",'~'.expand("<slnum>"))

    if g:netrw_sort_by =~# "^n"
     " sort by name
"     call Decho("sort by name",'~'.expand("<slnum>"))
     NetrwKeepj call s:NetrwSetSort()

     if !g:netrw_banner || w:netrw_bannercnt < line("$")
"      call Decho("g:netrw_sort_direction=".g:netrw_sort_direction." (bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))
      if g:netrw_sort_direction =~# 'n'
       " name: sort by name of file
       exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$sort'.' '.g:netrw_sort_options
      else
       " reverse direction sorting
       exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$sort!'.' '.g:netrw_sort_options
      endif
     endif

     " remove priority pattern prefix
"     call Decho("remove priority pattern prefix",'~'.expand("<slnum>"))
     exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^\d\{3}'.g:netrw_sepchr.'//e'
     NetrwKeepj call histdel("/",-1)

    elseif g:netrw_sort_by =~# "^ext"
     " exten: sort by extension
     "   The histdel(...,-1) calls remove the last search from the search history
"     call Decho("sort by extension",'~'.expand("<slnum>"))
     exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$g+/+s/^/001'.g:netrw_sepchr.'/'
     NetrwKeepj call histdel("/",-1)
     exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$v+[./]+s/^/002'.g:netrw_sepchr.'/'
     NetrwKeepj call histdel("/",-1)
     exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$v+['.g:netrw_sepchr.'/]+s/^\(.*\.\)\(.\{-\}\)$/\2'.g:netrw_sepchr.'&/e'
     NetrwKeepj call histdel("/",-1)
     if !g:netrw_banner || w:netrw_bannercnt < line("$")
"      call Decho("g:netrw_sort_direction=".g:netrw_sort_direction." (bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))
      if g:netrw_sort_direction =~# 'n'
       " normal direction sorting
       exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$sort'.' '.g:netrw_sort_options
      else
       " reverse direction sorting
       exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$sort!'.' '.g:netrw_sort_options
      endif
     endif
     exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^.\{-}'.g:netrw_sepchr.'//e'
     NetrwKeepj call histdel("/",-1)

    elseif a:islocal
     if !g:netrw_banner || w:netrw_bannercnt < line("$")
"      call Decho("g:netrw_sort_direction=".g:netrw_sort_direction,'~'.expand("<slnum>"))
      if g:netrw_sort_direction =~# 'n'
"       call Decho('exe sil NetrwKeepj '.w:netrw_bannercnt.',$sort','~'.expand("<slnum>"))
       exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$sort'.' '.g:netrw_sort_options
      else
"       call Decho('exe sil NetrwKeepj '.w:netrw_bannercnt.',$sort!','~'.expand("<slnum>"))
       exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$sort!'.' '.g:netrw_sort_options
      endif
"     call Decho("remove leading digits/ (sorting) information from listing",'~'.expand("<slnum>"))
     exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^\d\{-}\///e'
     NetrwKeepj call histdel("/",-1)
     endif
    endif

   elseif g:netrw_sort_direction =~# 'r'
"    call Decho('(s:PerformListing) reverse the sorted listing','~'.expand("<slnum>"))
    if !g:netrw_banner || w:netrw_bannercnt < line('$')
     exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$g/^/m '.w:netrw_bannercnt
     call histdel("/",-1)
    endif
   endif
  endif
"  call Decho("g:netrw_banner=".g:netrw_banner.": banner ".(g:netrw_banner? "enabled" : "suppressed").": (line($)=".line("$")." byte2line(1)=".byte2line(1)." bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))

  " convert to wide/tree listing {{{3
"  call Decho("--modify display if wide/tree listing style",'~'.expand("<slnum>"))
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (internal#1)",'~'.expand("<slnum>"))
  NetrwKeepj call s:NetrwWideListing()
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (internal#2)",'~'.expand("<slnum>"))
  NetrwKeepj call s:NetrwTreeListing(b:netrw_curdir)
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (internal#3)",'~'.expand("<slnum>"))

  " resolve symbolic links if local and (thin or tree)
  if a:islocal && (w:netrw_liststyle == s:THINLIST || (exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST))
"   call Decho("--resolve symbolic links if local and thin|tree",'~'.expand("<slnum>"))
   sil! g/@$/call s:ShowLink()
  endif

  if exists("w:netrw_bannercnt") && (line("$") >= w:netrw_bannercnt || !g:netrw_banner)
   " place cursor on the top-left corner of the file listing
"   call Decho("--place cursor on top-left corner of file listing",'~'.expand("<slnum>"))
   exe 'sil! '.w:netrw_bannercnt
   sil! NetrwKeepj norm! 0
"   call Decho("  tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol()." line($)=".line("$"),'~'.expand("<slnum>"))
  else
"   call Decho("--did NOT place cursor on top-left corner",'~'.expand("<slnum>"))
"   call Decho("  w:netrw_bannercnt=".(exists("w:netrw_bannercnt")? w:netrw_bannercnt : 'n/a'),'~'.expand("<slnum>"))
"   call Decho("  line($)=".line("$"),'~'.expand("<slnum>"))
"   call Decho("  g:netrw_banner=".(exists("g:netrw_banner")? g:netrw_banner : 'n/a'),'~'.expand("<slnum>"))
  endif

  " record previous current directory
  let w:netrw_prvdir= b:netrw_curdir
"  call Decho("--record netrw_prvdir<".w:netrw_prvdir.">",'~'.expand("<slnum>"))

  " save certain window-oriented variables into buffer-oriented variables {{{3
"  call Decho("--save some window-oriented variables into buffer oriented variables",'~'.expand("<slnum>"))
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (internal#4)",'~'.expand("<slnum>"))
  NetrwKeepj call s:SetBufWinVars()
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (internal#5)",'~'.expand("<slnum>"))
  NetrwKeepj call s:NetrwOptionsRestore("w:")
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (internal#6)",'~'.expand("<slnum>"))

  " set display to netrw display settings
"  call Decho("--set display to netrw display settings (".g:netrw_bufsettings.")",'~'.expand("<slnum>"))
  exe "setl ".g:netrw_bufsettings
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (internal#7)",'~'.expand("<slnum>"))
  if g:netrw_liststyle == s:LONGLIST
"   call Decho("exe setl ts=".(g:netrw_maxfilenamelen+1),'~'.expand("<slnum>"))
   exe "setl ts=".(g:netrw_maxfilenamelen+1)
  endif
"  call Decho("PerformListing buffer:",'~'.expand("<slnum>"))
"  call DechoBuf(bufnr("%"))

  if exists("s:treecurpos")
"   call Decho("s:treecurpos exists; restore posn",'~'.expand("<slnum>"))
"   call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (internal#8)",'~'.expand("<slnum>"))
"   call Decho("restoring posn to s:treecurpos<".string(s:treecurpos).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(s:treecurpos)
   unlet s:treecurpos
  endif

"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo. " (return)",'~'.expand("<slnum>"))
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol()." line($)=".line("$"),'~'.expand("<slnum>"))
"  call Dret("s:PerformListing : curpos<".string(getpos(".")).">")
endfun

" ---------------------------------------------------------------------
" s:SetupNetrwStatusLine: {{{2
fun! s:SetupNetrwStatusLine(statline)
"  call Dfunc("SetupNetrwStatusLine(statline<".a:statline.">)")

  if !exists("s:netrw_setup_statline")
   let s:netrw_setup_statline= 1
"   call Decho("do first-time status line setup",'~'.expand("<slnum>"))

   if !exists("s:netrw_users_stl")
    let s:netrw_users_stl= &stl
   endif
   if !exists("s:netrw_users_ls")
    let s:netrw_users_ls= &laststatus
   endif

   " set up User9 highlighting as needed
  let dict={}
  let dict.a=[getreg('a'), getregtype('a')]
   redir @a
   try
    hi User9
   catch /^Vim\%((\a\{3,})\)\=:E411/
    if &bg == "dark"
     hi User9 ctermfg=yellow ctermbg=blue guifg=yellow guibg=blue
    else
     hi User9 ctermbg=yellow ctermfg=blue guibg=yellow guifg=blue
    endif
   endtry
   redir END
   call s:RestoreRegister(dict)
  endif

  " set up status line (may use User9 highlighting)
  " insure that windows have a statusline
  " make sure statusline is displayed
  let &l:stl=a:statline
  setl laststatus=2
"  call Decho("stl=".&stl,'~'.expand("<slnum>"))
  redraw

"  call Dret("SetupNetrwStatusLine : stl=".&stl)
endfun

" =========================================
"  Remote Directory Browsing Support:  {{{1
" =========================================

" ---------------------------------------------------------------------
" s:NetrwRemoteFtpCmd: unfortunately, not all ftp servers honor options for ls {{{2
"  This function assumes that a long listing will be received.  Size, time,
"  and reverse sorts will be requested of the server but not otherwise
"  enforced here.
fun! s:NetrwRemoteFtpCmd(path,listcmd)
"  call Dfunc("NetrwRemoteFtpCmd(path<".a:path."> listcmd<".a:listcmd.">) w:netrw_method=".(exists("w:netrw_method")? w:netrw_method : (exists("b:netrw_method")? b:netrw_method : "???")))
"  call Decho("line($)=".line("$")." win#".winnr()." w:netrw_bannercnt=".w:netrw_bannercnt,'~'.expand("<slnum>"))
  " sanity check: {{{3
  if !exists("w:netrw_method")
   if exists("b:netrw_method")
    let w:netrw_method= b:netrw_method
   else
    call netrw#ErrorMsg(2,"(s:NetrwRemoteFtpCmd) internal netrw error",93)
"    call Dret("NetrwRemoteFtpCmd")
    return
   endif
  endif

  " WinXX ftp uses unix style input, so set ff to unix	" {{{3
  let ffkeep= &ff
  setl ma ff=unix noro
"  call Decho("setl ma ff=unix noro",'~'.expand("<slnum>"))

  " clear off any older non-banner lines	" {{{3
  " note that w:netrw_bannercnt indexes the line after the banner
"  call Decho('exe sil! NetrwKeepj '.w:netrw_bannercnt.",$d _  (clear off old non-banner lines)",'~'.expand("<slnum>"))
  exe "sil! NetrwKeepj ".w:netrw_bannercnt.",$d _"

  ".........................................
  if w:netrw_method == 2 || w:netrw_method == 5	" {{{3
   " ftp + <.netrc>:  Method #2
   if a:path != ""
    NetrwKeepj put ='cd \"'.a:path.'\"'
   endif
   if exists("g:netrw_ftpextracmd")
    NetrwKeepj put =g:netrw_ftpextracmd
"    call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
   endif
   NetrwKeepj call setline(line("$")+1,a:listcmd)
"   exe "NetrwKeepj ".w:netrw_bannercnt.',$g/^./call Decho("ftp#".line(".").": ".getline("."),''~''.expand("<slnum>"))'
   if exists("g:netrw_port") && g:netrw_port != ""
"    call Decho("exe ".s:netrw_silentxfer.w:netrw_bannercnt.",$!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1)." ".s:ShellEscape(g:netrw_port,1),'~'.expand("<slnum>"))
    exe s:netrw_silentxfer." NetrwKeepj ".w:netrw_bannercnt.",$!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1)." ".s:ShellEscape(g:netrw_port,1)
   else
"    call Decho("exe ".s:netrw_silentxfer.w:netrw_bannercnt.",$!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1),'~'.expand("<slnum>"))
    exe s:netrw_silentxfer." NetrwKeepj ".w:netrw_bannercnt.",$!".s:netrw_ftp_cmd." -i ".s:ShellEscape(g:netrw_machine,1)
   endif

  ".........................................
  elseif w:netrw_method == 3	" {{{3
   " ftp + machine,id,passwd,filename:  Method #3
    setl ff=unix
    if exists("g:netrw_port") && g:netrw_port != ""
     NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
    else
     NetrwKeepj put ='open '.g:netrw_machine
    endif

    " handle userid and password
    let host= substitute(g:netrw_machine,'\..*$','','')
"    call Decho("host<".host.">",'~'.expand("<slnum>"))
    if exists("s:netrw_hup") && exists("s:netrw_hup[host]")
     call NetUserPass("ftp:".host)
    endif
    if exists("g:netrw_uid") && g:netrw_uid != ""
     if exists("g:netrw_ftp") && g:netrw_ftp == 1
      NetrwKeepj put =g:netrw_uid
      if exists("s:netrw_passwd") && s:netrw_passwd != ""
       NetrwKeepj put ='\"'.s:netrw_passwd.'\"'
      endif
     elseif exists("s:netrw_passwd")
      NetrwKeepj put ='user \"'.g:netrw_uid.'\" \"'.s:netrw_passwd.'\"'
     endif
    endif

   if a:path != ""
    NetrwKeepj put ='cd \"'.a:path.'\"'
   endif
   if exists("g:netrw_ftpextracmd")
    NetrwKeepj put =g:netrw_ftpextracmd
"    call Decho("filter input: ".getline('.'),'~'.expand("<slnum>"))
   endif
   NetrwKeepj call setline(line("$")+1,a:listcmd)

   " perform ftp:
   " -i       : turns off interactive prompting from ftp
   " -n  unix : DON'T use <.netrc>, even though it exists
   " -n  win32: quit being obnoxious about password
   if exists("w:netrw_bannercnt")
"    exe w:netrw_bannercnt.',$g/^./call Decho("ftp#".line(".").": ".getline("."),''~''.expand("<slnum>"))'
    call s:NetrwExe(s:netrw_silentxfer.w:netrw_bannercnt.",$!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
"   else " Decho
"    call Decho("WARNING: w:netrw_bannercnt doesn't exist!",'~'.expand("<slnum>"))
"    g/^./call Decho("SKIPPING ftp#".line(".").": ".getline("."),'~'.expand("<slnum>"))
   endif

  ".........................................
  elseif w:netrw_method == 9	" {{{3
   " sftp username@machine: Method #9
   " s:netrw_sftp_cmd
   setl ff=unix

   " restore settings
   let &l:ff= ffkeep
"   call Dret("NetrwRemoteFtpCmd")
   return

  ".........................................
  else	" {{{3
   NetrwKeepj call netrw#ErrorMsg(s:WARNING,"unable to comply with your request<" . bufname("%") . ">",23)
  endif

  " cleanup for Windows " {{{3
  if has("win32")
   sil! NetrwKeepj %s/\r$//e
   NetrwKeepj call histdel("/",-1)
  endif
  if a:listcmd == "dir"
   " infer directory/link based on the file permission string
   sil! NetrwKeepj g/d\%([-r][-w][-x]\)\{3}/NetrwKeepj s@$@/@e
   sil! NetrwKeepj g/l\%([-r][-w][-x]\)\{3}/NetrwKeepj s/$/@/e
   NetrwKeepj call histdel("/",-1)
   NetrwKeepj call histdel("/",-1)
   if w:netrw_liststyle == s:THINLIST || w:netrw_liststyle == s:WIDELIST || (exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST)
    exe "sil! NetrwKeepj ".w:netrw_bannercnt.',$s/^\%(\S\+\s\+\)\{8}//e'
    NetrwKeepj call histdel("/",-1)
   endif
  endif

  " ftp's listing doesn't seem to include ./ or ../ " {{{3
  if !search('^\.\/$\|\s\.\/$','wn')
   exe 'NetrwKeepj '.w:netrw_bannercnt
   NetrwKeepj put ='./'
  endif
  if !search('^\.\.\/$\|\s\.\.\/$','wn')
   exe 'NetrwKeepj '.w:netrw_bannercnt
   NetrwKeepj put ='../'
  endif

  " restore settings " {{{3
  let &l:ff= ffkeep
"  call Dret("NetrwRemoteFtpCmd")
endfun

" ---------------------------------------------------------------------
" s:NetrwRemoteListing: {{{2
fun! s:NetrwRemoteListing()
"  call Dfunc("s:NetrwRemoteListing() b:netrw_curdir<".b:netrw_curdir.">) win#".winnr())

  if !exists("w:netrw_bannercnt") && exists("s:bannercnt")
   let w:netrw_bannercnt= s:bannercnt
  endif
  if !exists("w:netrw_bannercnt") && exists("b:bannercnt")
   let w:netrw_bannercnt= b:bannercnt
  endif

  call s:RemotePathAnalysis(b:netrw_curdir)

  " sanity check:
  if exists("b:netrw_method") && b:netrw_method =~ '[235]'
"   call Decho("b:netrw_method=".b:netrw_method,'~'.expand("<slnum>"))
   if !executable("ftp")
"    call Decho("ftp is not executable",'~'.expand("<slnum>"))
    if !exists("g:netrw_quiet")
     call netrw#ErrorMsg(s:ERROR,"this system doesn't support remote directory listing via ftp",18)
    endif
    call s:NetrwOptionsRestore("w:")
"    call Dret("s:NetrwRemoteListing -1")
    return -1
   endif

  elseif !exists("g:netrw_list_cmd") || g:netrw_list_cmd == ''
"   call Decho("g:netrw_list_cmd<",(exists("g:netrw_list_cmd")? 'n/a' : "-empty-").">",'~'.expand("<slnum>"))
   if !exists("g:netrw_quiet")
    if g:netrw_list_cmd == ""
     NetrwKeepj call netrw#ErrorMsg(s:ERROR,"your g:netrw_list_cmd is empty; perhaps ".g:netrw_ssh_cmd." is not executable on your system",47)
    else
     NetrwKeepj call netrw#ErrorMsg(s:ERROR,"this system doesn't support remote directory listing via ".g:netrw_list_cmd,19)
    endif
   endif

   NetrwKeepj call s:NetrwOptionsRestore("w:")
"   call Dret("s:NetrwRemoteListing -1")
   return -1
  endif  " (remote handling sanity check)
"  call Decho("passed remote listing sanity checks",'~'.expand("<slnum>"))

  if exists("b:netrw_method")
"   call Decho("setting w:netrw_method to b:netrw_method<".b:netrw_method.">",'~'.expand("<slnum>"))
   let w:netrw_method= b:netrw_method
  endif

  if s:method == "ftp"
   " use ftp to get remote file listing {{{3
"   call Decho("use ftp to get remote file listing",'~'.expand("<slnum>"))
   let s:method  = "ftp"
   let listcmd = g:netrw_ftp_list_cmd
   if g:netrw_sort_by =~# '^t'
    let listcmd= g:netrw_ftp_timelist_cmd
   elseif g:netrw_sort_by =~# '^s'
    let listcmd= g:netrw_ftp_sizelist_cmd
   endif
"   call Decho("listcmd<".listcmd."> (using g:netrw_ftp_list_cmd)",'~'.expand("<slnum>"))
   call s:NetrwRemoteFtpCmd(s:path,listcmd)
"   exe "sil! keepalt NetrwKeepj ".w:netrw_bannercnt.',$g/^./call Decho("raw listing: ".getline("."),''~''.expand("<slnum>"))'

   " report on missing file or directory messages
   if search('[Nn]o such file or directory\|Failed to change directory')
    let mesg= getline(".")
    if exists("w:netrw_bannercnt")
     setl ma
     exe w:netrw_bannercnt.",$d _"
     setl noma
    endif
    NetrwKeepj call s:NetrwOptionsRestore("w:")
    call netrw#ErrorMsg(s:WARNING,mesg,96)
"    call Dret("s:NetrwRemoteListing : -1")
    return -1
   endif

   if w:netrw_liststyle == s:THINLIST || w:netrw_liststyle == s:WIDELIST || (exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST)
    " shorten the listing
"    call Decho("generate short listing",'~'.expand("<slnum>"))
    exe "sil! keepalt NetrwKeepj ".w:netrw_bannercnt

    " cleanup
    if g:netrw_ftp_browse_reject != ""
     exe "sil! keepalt NetrwKeepj g/".g:netrw_ftp_browse_reject."/NetrwKeepj d"
     NetrwKeepj call histdel("/",-1)
    endif
    sil! NetrwKeepj %s/\r$//e
    NetrwKeepj call histdel("/",-1)

    " if there's no ../ listed, then put ../ in
    let line1= line(".")
    exe "sil! NetrwKeepj ".w:netrw_bannercnt
    let line2= search('\.\.\/\%(\s\|$\)','cnW')
"    call Decho("search(".'\.\.\/\%(\s\|$\)'."','cnW')=".line2."  w:netrw_bannercnt=".w:netrw_bannercnt,'~'.expand("<slnum>"))
    if line2 == 0
"     call Decho("netrw is putting ../ into listing",'~'.expand("<slnum>"))
     sil! NetrwKeepj put='../'
    endif
    exe "sil! NetrwKeepj ".line1
    sil! NetrwKeepj norm! 0

"    call Decho("line1=".line1." line2=".line2." line(.)=".line("."),'~'.expand("<slnum>"))
    if search('^\d\{2}-\d\{2}-\d\{2}\s','n') " M$ ftp site cleanup
"     call Decho("M$ ftp cleanup",'~'.expand("<slnum>"))
     exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^\d\{2}-\d\{2}-\d\{2}\s\+\d\+:\d\+[AaPp][Mm]\s\+\%(<DIR>\|\d\+\)\s\+//'
     NetrwKeepj call histdel("/",-1)
    else " normal ftp cleanup
"     call Decho("normal ftp cleanup",'~'.expand("<slnum>"))
     exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^\(\%(\S\+\s\+\)\{7}\S\+\)\s\+\(\S.*\)$/\2/e'
     exe "sil! NetrwKeepj ".w:netrw_bannercnt.',$g/ -> /s# -> .*/$#/#e'
     exe "sil! NetrwKeepj ".w:netrw_bannercnt.',$g/ -> /s# -> .*$#/#e'
     NetrwKeepj call histdel("/",-1)
     NetrwKeepj call histdel("/",-1)
     NetrwKeepj call histdel("/",-1)
    endif
   endif

   else
   " use ssh to get remote file listing {{{3
"   call Decho("use ssh to get remote file listing: s:path<".s:path.">",'~'.expand("<slnum>"))
   let listcmd= s:MakeSshCmd(g:netrw_list_cmd)
"   call Decho("listcmd<".listcmd."> (using g:netrw_list_cmd)",'~'.expand("<slnum>"))
   if g:netrw_scp_cmd =~ '^pscp'
"    call Decho("1: exe r! ".s:ShellEscape(listcmd.s:path, 1),'~'.expand("<slnum>"))
    exe "NetrwKeepj r! ".listcmd.s:ShellEscape(s:path, 1)
    " remove rubbish and adjust listing format of 'pscp' to 'ssh ls -FLa' like
    sil! NetrwKeepj g/^Listing directory/NetrwKeepj d
    sil! NetrwKeepj g/^d[-rwx][-rwx][-rwx]/NetrwKeepj s+$+/+e
    sil! NetrwKeepj g/^l[-rwx][-rwx][-rwx]/NetrwKeepj s+$+@+e
    NetrwKeepj call histdel("/",-1)
    NetrwKeepj call histdel("/",-1)
    NetrwKeepj call histdel("/",-1)
    if g:netrw_liststyle != s:LONGLIST
     sil! NetrwKeepj g/^[dlsp-][-rwx][-rwx][-rwx]/NetrwKeepj s/^.*\s\(\S\+\)$/\1/e
     NetrwKeepj call histdel("/",-1)
    endif
   else
    if s:path == ""
"     call Decho("2: exe r! ".listcmd,'~'.expand("<slnum>"))
     exe "NetrwKeepj keepalt r! ".listcmd
    else
"     call Decho("3: exe r! ".listcmd.' '.s:ShellEscape(fnameescape(s:path),1),'~'.expand("<slnum>"))
     exe "NetrwKeepj keepalt r! ".listcmd.' '.s:ShellEscape(fnameescape(s:path),1)
"     call Decho("listcmd<".listcmd."> path<".s:path.">",'~'.expand("<slnum>"))
    endif
   endif

   " cleanup
   if g:netrw_ssh_browse_reject != ""
"    call Decho("cleanup: exe sil! g/".g:netrw_ssh_browse_reject."/NetrwKeepj d",'~'.expand("<slnum>"))
    exe "sil! g/".g:netrw_ssh_browse_reject."/NetrwKeepj d"
    NetrwKeepj call histdel("/",-1)
   endif
  endif

  if w:netrw_liststyle == s:LONGLIST
   " do a long listing; these substitutions need to be done prior to sorting {{{3
"   call Decho("fix long listing:",'~'.expand("<slnum>"))

   if s:method == "ftp"
    " cleanup
    exe "sil! NetrwKeepj ".w:netrw_bannercnt
    while getline('.') =~# g:netrw_ftp_browse_reject
     sil! NetrwKeepj d
    endwhile
    " if there's no ../ listed, then put ../ in
    let line1= line(".")
    sil! NetrwKeepj 1
    sil! NetrwKeepj call search('^\.\.\/\%(\s\|$\)','W')
    let line2= line(".")
    if line2 == 0
     if b:netrw_curdir != '/'
      exe 'sil! NetrwKeepj '.w:netrw_bannercnt."put='../'"
     endif
    endif
    exe "sil! NetrwKeepj ".line1
    sil! NetrwKeepj norm! 0
   endif

   if search('^\d\{2}-\d\{2}-\d\{2}\s','n') " M$ ftp site cleanup
"    call Decho("M$ ftp site listing cleanup",'~'.expand("<slnum>"))
    exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^\(\d\{2}-\d\{2}-\d\{2}\s\+\d\+:\d\+[AaPp][Mm]\s\+\%(<DIR>\|\d\+\)\s\+\)\(\w.*\)$/\2\t\1/'
   elseif exists("w:netrw_bannercnt") && w:netrw_bannercnt <= line("$")
"    call Decho("normal ftp site listing cleanup: bannercnt=".w:netrw_bannercnt." line($)=".line("$"),'~'.expand("<slnum>"))
    exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$s/ -> .*$//e'
    exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$s/^\(\%(\S\+\s\+\)\{7}\S\+\)\s\+\(\S.*\)$/\2 \t\1/e'
    exe 'sil NetrwKeepj '.w:netrw_bannercnt
    NetrwKeepj call histdel("/",-1)
    NetrwKeepj call histdel("/",-1)
    NetrwKeepj call histdel("/",-1)
   endif
  endif

"  if exists("w:netrw_bannercnt") && w:netrw_bannercnt <= line("$") " Decho
"   exe "NetrwKeepj ".w:netrw_bannercnt.',$g/^./call Decho("listing: ".getline("."),''~''.expand("<slnum>"))'
"  endif " Decho

"  call Dret("s:NetrwRemoteListing 0")
  return 0
endfun

" ---------------------------------------------------------------------
" s:NetrwRemoteRm: remove/delete a remote file or directory {{{2
fun! s:NetrwRemoteRm(usrhost,path) range
"  call Dfunc("s:NetrwRemoteRm(usrhost<".a:usrhost."> path<".a:path.">) virtcol=".virtcol("."))
"  call Decho("firstline=".a:firstline." lastline=".a:lastline,'~'.expand("<slnum>"))
  let svpos= winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))

  let all= 0
  if exists("s:netrwmarkfilelist_{bufnr('%')}")
   " remove all marked files
"   call Decho("remove all marked files with bufnr#".bufnr("%"),'~'.expand("<slnum>"))
   for fname in s:netrwmarkfilelist_{bufnr("%")}
    let ok= s:NetrwRemoteRmFile(a:path,fname,all)
    if ok =~# 'q\%[uit]'
     break
    elseif ok =~# 'a\%[ll]'
     let all= 1
    endif
   endfor
   call s:NetrwUnmarkList(bufnr("%"),b:netrw_curdir)

  else
   " remove files specified by range
"   call Decho("remove files specified by range",'~'.expand("<slnum>"))

   " preparation for removing multiple files/directories
   let keepsol = &l:sol
   setl nosol
   let ctr    = a:firstline

   " remove multiple files and directories
   while ctr <= a:lastline
    exe "NetrwKeepj ".ctr
    let ok= s:NetrwRemoteRmFile(a:path,s:NetrwGetWord(),all)
    if ok =~# 'q\%[uit]'
     break
    elseif ok =~# 'a\%[ll]'
     let all= 1
    endif
    let ctr= ctr + 1
   endwhile
   let &l:sol = keepsol
  endif

  " refresh the (remote) directory listing
"  call Decho("refresh remote directory listing",'~'.expand("<slnum>"))
  NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./'))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)

"  call Dret("s:NetrwRemoteRm")
endfun

" ---------------------------------------------------------------------
" s:NetrwRemoteRmFile: {{{2
fun! s:NetrwRemoteRmFile(path,rmfile,all)
"  call Dfunc("s:NetrwRemoteRmFile(path<".a:path."> rmfile<".a:rmfile.">) all=".a:all)

  let all= a:all
  let ok = ""

  if a:rmfile !~ '^"' && (a:rmfile =~ '@$' || a:rmfile !~ '[\/]$')
   " attempt to remove file
"    call Decho("attempt to remove file (all=".all.")",'~'.expand("<slnum>"))
   if !all
    echohl Statement
"    call Decho("case all=0:",'~'.expand("<slnum>"))
    call inputsave()
    let ok= input("Confirm deletion of file<".a:rmfile."> ","[{y(es)},n(o),a(ll),q(uit)] ")
    call inputrestore()
    echohl NONE
    if ok == ""
     let ok="no"
    endif
    let ok= substitute(ok,'\[{y(es)},n(o),a(ll),q(uit)]\s*','','e')
    if ok =~# 'a\%[ll]'
     let all= 1
    endif
   endif

   if all || ok =~# 'y\%[es]' || ok == ""
"    call Decho("case all=".all." or ok<".ok.">".(exists("w:netrw_method")? ': netrw_method='.w:netrw_method : ""),'~'.expand("<slnum>"))
    if exists("w:netrw_method") && (w:netrw_method == 2 || w:netrw_method == 3)
"     call Decho("case ftp:",'~'.expand("<slnum>"))
     let path= a:path
     if path =~ '^\a\{3,}://'
      let path= substitute(path,'^\a\{3,}://[^/]\+/','','')
     endif
     sil! NetrwKeepj .,$d _
     call s:NetrwRemoteFtpCmd(path,"delete ".'"'.a:rmfile.'"')
    else
"     call Decho("case ssh: g:netrw_rm_cmd<".g:netrw_rm_cmd.">",'~'.expand("<slnum>"))
     let netrw_rm_cmd= s:MakeSshCmd(g:netrw_rm_cmd)
"     call Decho("netrw_rm_cmd<".netrw_rm_cmd.">",'~'.expand("<slnum>"))
     if !exists("b:netrw_curdir")
      NetrwKeepj call netrw#ErrorMsg(s:ERROR,"for some reason b:netrw_curdir doesn't exist!",53)
      let ok="q"
     else
      let remotedir= substitute(b:netrw_curdir,'^.\{-}//[^/]\+/\(.*\)$','\1','')
"      call Decho("netrw_rm_cmd<".netrw_rm_cmd.">",'~'.expand("<slnum>"))
"      call Decho("remotedir<".remotedir.">",'~'.expand("<slnum>"))
"      call Decho("rmfile<".a:rmfile.">",'~'.expand("<slnum>"))
      if remotedir != ""
       let netrw_rm_cmd= netrw_rm_cmd." ".s:ShellEscape(fnameescape(remotedir.a:rmfile))
      else
       let netrw_rm_cmd= netrw_rm_cmd." ".s:ShellEscape(fnameescape(a:rmfile))
      endif
"      call Decho("call system(".netrw_rm_cmd.")",'~'.expand("<slnum>"))
      let ret= system(netrw_rm_cmd)
      if v:shell_error != 0
       if exists("b:netrw_curdir") && b:netrw_curdir != getcwd() && !g:netrw_keepdir
        call netrw#ErrorMsg(s:ERROR,"remove failed; perhaps due to vim's current directory<".getcwd()."> not matching netrw's (".b:netrw_curdir.") (see :help netrw-cd)",102)
       else
        call netrw#ErrorMsg(s:WARNING,"cmd<".netrw_rm_cmd."> failed",60)
       endif
      elseif ret != 0
       call netrw#ErrorMsg(s:WARNING,"cmd<".netrw_rm_cmd."> failed",60)
      endif
"      call Decho("returned=".ret." errcode=".v:shell_error,'~'.expand("<slnum>"))
     endif
    endif
   elseif ok =~# 'q\%[uit]'
"    call Decho("ok==".ok,'~'.expand("<slnum>"))
   endif

  else
   " attempt to remove directory
"    call Decho("attempt to remove directory",'~'.expand("<slnum>"))
   if !all
    call inputsave()
    let ok= input("Confirm deletion of directory<".a:rmfile."> ","[{y(es)},n(o),a(ll),q(uit)] ")
    call inputrestore()
    if ok == ""
     let ok="no"
    endif
    let ok= substitute(ok,'\[{y(es)},n(o),a(ll),q(uit)]\s*','','e')
    if ok =~# 'a\%[ll]'
     let all= 1
    endif
   endif

   if all || ok =~# 'y\%[es]' || ok == ""
    if exists("w:netrw_method") && (w:netrw_method == 2 || w:netrw_method == 3)
     NetrwKeepj call s:NetrwRemoteFtpCmd(a:path,"rmdir ".a:rmfile)
    else
     let rmfile          = substitute(a:path.a:rmfile,'/$','','')
     let netrw_rmdir_cmd = s:MakeSshCmd(netrw#WinPath(g:netrw_rmdir_cmd)).' '.s:ShellEscape(netrw#WinPath(rmfile))
"      call Decho("attempt to remove dir: system(".netrw_rmdir_cmd.")",'~'.expand("<slnum>"))
     let ret= system(netrw_rmdir_cmd)
"      call Decho("returned=".ret." errcode=".v:shell_error,'~'.expand("<slnum>"))

     if v:shell_error != 0
"      call Decho("v:shell_error not 0",'~'.expand("<slnum>"))
      let netrw_rmf_cmd= s:MakeSshCmd(netrw#WinPath(g:netrw_rmf_cmd)).' '.s:ShellEscape(netrw#WinPath(substitute(rmfile,'[\/]$','','e')))
"      call Decho("2nd attempt to remove dir: system(".netrw_rmf_cmd.")",'~'.expand("<slnum>"))
      let ret= system(netrw_rmf_cmd)
"      call Decho("returned=".ret." errcode=".v:shell_error,'~'.expand("<slnum>"))

      if v:shell_error != 0 && !exists("g:netrw_quiet")
      	NetrwKeepj call netrw#ErrorMsg(s:ERROR,"unable to remove directory<".rmfile."> -- is it empty?",22)
      endif
     endif
    endif

   elseif ok =~# 'q\%[uit]'
"    call Decho("ok==".ok,'~'.expand("<slnum>"))
   endif
  endif

"  call Dret("s:NetrwRemoteRmFile ".ok)
  return ok
endfun

" ---------------------------------------------------------------------
" s:NetrwRemoteRename: rename a remote file or directory {{{2
fun! s:NetrwRemoteRename(usrhost,path) range
"  call Dfunc("NetrwRemoteRename(usrhost<".a:usrhost."> path<".a:path.">)")

  " preparation for removing multiple files/directories
  let svpos      = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  let ctr        = a:firstline
  let rename_cmd = s:MakeSshCmd(g:netrw_rename_cmd)

  " rename files given by the markfilelist
  if exists("s:netrwmarkfilelist_{bufnr('%')}")
   for oldname in s:netrwmarkfilelist_{bufnr("%")}
"    call Decho("oldname<".oldname.">",'~'.expand("<slnum>"))
    if exists("subfrom")
     let newname= substitute(oldname,subfrom,subto,'')
"     call Decho("subfrom<".subfrom."> subto<".subto."> newname<".newname.">",'~'.expand("<slnum>"))
    else
     call inputsave()
     let newname= input("Moving ".oldname." to : ",oldname)
     call inputrestore()
     if newname =~ '^s/'
      let subfrom = substitute(newname,'^s/\([^/]*\)/.*/$','\1','')
      let subto   = substitute(newname,'^s/[^/]*/\(.*\)/$','\1','')
      let newname = substitute(oldname,subfrom,subto,'')
"      call Decho("subfrom<".subfrom."> subto<".subto."> newname<".newname.">",'~'.expand("<slnum>"))
     endif
    endif

    if exists("w:netrw_method") && (w:netrw_method == 2 || w:netrw_method == 3)
     NetrwKeepj call s:NetrwRemoteFtpCmd(a:path,"rename ".oldname." ".newname)
    else
     let oldname= s:ShellEscape(a:path.oldname)
     let newname= s:ShellEscape(a:path.newname)
"     call Decho("system(netrw#WinPath(".rename_cmd.") ".oldname.' '.newname.")",'~'.expand("<slnum>"))
     let ret    = system(netrw#WinPath(rename_cmd).' '.oldname.' '.newname)
    endif

   endfor
   call s:NetrwUnMarkFile(1)

  else

  " attempt to rename files/directories
   let keepsol= &l:sol
   setl nosol
   while ctr <= a:lastline
    exe "NetrwKeepj ".ctr

    let oldname= s:NetrwGetWord()
"   call Decho("oldname<".oldname.">",'~'.expand("<slnum>"))

    call inputsave()
    let newname= input("Moving ".oldname." to : ",oldname)
    call inputrestore()

    if exists("w:netrw_method") && (w:netrw_method == 2 || w:netrw_method == 3)
     call s:NetrwRemoteFtpCmd(a:path,"rename ".oldname." ".newname)
    else
     let oldname= s:ShellEscape(a:path.oldname)
     let newname= s:ShellEscape(a:path.newname)
"     call Decho("system(netrw#WinPath(".rename_cmd.") ".oldname.' '.newname.")",'~'.expand("<slnum>"))
     let ret    = system(netrw#WinPath(rename_cmd).' '.oldname.' '.newname)
    endif

    let ctr= ctr + 1
   endwhile
   let &l:sol= keepsol
  endif

  " refresh the directory
  NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./'))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)

"  call Dret("NetrwRemoteRename")
endfun

" ==========================================
"  Local Directory Browsing Support:    {{{1
" ==========================================

" ---------------------------------------------------------------------
" netrw#FileUrlEdit: handles editing file://* files {{{2
"   Should accept:   file://localhost/etc/fstab
"                    file:///etc/fstab
"                    file:///c:/WINDOWS/clock.avi
"                    file:///c|/WINDOWS/clock.avi
"                    file://localhost/c:/WINDOWS/clock.avi
"                    file://localhost/c|/WINDOWS/clock.avi
"                    file://c:/foo.txt
"                    file:///c:/foo.txt
" and %XX (where X is [0-9a-fA-F] is converted into a character with the given hexadecimal value
fun! netrw#FileUrlEdit(fname)
"  call Dfunc("netrw#FileUrlEdit(fname<".a:fname.">)")
  let fname = a:fname
  if fname =~ '^file://localhost/'
"   call Decho('converting file://localhost/   -to-  file:///','~'.expand("<slnum>"))
   let fname= substitute(fname,'^file://localhost/','file:///','')
"   call Decho("fname<".fname.">",'~'.expand("<slnum>"))
  endif
  if has("win32")
   if fname  =~ '^file:///\=\a[|:]/'
"    call Decho('converting file:///\a|/   -to-  file://\a:/','~'.expand("<slnum>"))
    let fname = substitute(fname,'^file:///\=\(\a\)[|:]/','file://\1:/','')
"    call Decho("fname<".fname.">",'~'.expand("<slnum>"))
   endif
  endif
  let fname2396 = netrw#RFC2396(fname)
  let fname2396e= fnameescape(fname2396)
  let plainfname= substitute(fname2396,'file://\(.*\)','\1',"")
  if has("win32")
"   call Decho("windows exception for plainfname",'~'.expand("<slnum>"))
   if plainfname =~ '^/\+\a:'
"    call Decho('removing leading "/"s','~'.expand("<slnum>"))
    let plainfname= substitute(plainfname,'^/\+\(\a:\)','\1','')
   endif
  endif

"  call Decho("fname2396<".fname2396.">",'~'.expand("<slnum>"))
"  call Decho("plainfname<".plainfname.">",'~'.expand("<slnum>"))
  exe "sil doau BufReadPre ".fname2396e
  exe 'NetrwKeepj keepalt edit '.plainfname
  exe 'sil! NetrwKeepj keepalt bdelete '.fnameescape(a:fname)

"  call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"  call Dret("netrw#FileUrlEdit")
  exe "sil doau BufReadPost ".fname2396e
endfun

" ---------------------------------------------------------------------
" netrw#LocalBrowseCheck: {{{2
fun! netrw#LocalBrowseCheck(dirname)
  " This function is called by netrwPlugin.vim's s:LocalBrowseCheck(), s:NetrwRexplore(),
  " and by <cr> when atop a listed file/directory (via a buffer-local map)
  "
  " unfortunate interaction -- split window debugging can't be used here, must use
  "                            D-echoRemOn or D-echoTabOn as the BufEnter event triggers
  "                            another call to LocalBrowseCheck() when attempts to write
  "                            to the DBG buffer are made.
  "
  " The &ft == "netrw" test was installed because the BufEnter event
  " would hit when re-entering netrw windows, creating unexpected
  " refreshes (and would do so in the middle of NetrwSaveOptions(), too)
"  call Dfunc("netrw#LocalBrowseCheck(dirname<".a:dirname.">)")
"  call Decho("isdir<".a:dirname."> =".isdirectory(s:NetrwFile(a:dirname)).((exists("s:treeforceredraw")? " treeforceredraw" : "")).'~'.expand("<slnum>"))
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
  " getting E930: Cannot use :redir inside execute
""  call Dredir("ls!","netrw#LocalBrowseCheck")
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
"  call Decho("current buffer#".bufnr("%")."<".bufname("%")."> ft=".&ft,'~'.expand("<slnum>"))

  let ykeep= @@
  if isdirectory(s:NetrwFile(a:dirname))
"   call Decho("is-directory ft<".&ft."> b:netrw_curdir<".(exists("b:netrw_curdir")? b:netrw_curdir : " doesn't exist")."> dirname<".a:dirname.">"." line($)=".line("$")." ft<".&ft."> g:netrw_fastbrowse=".g:netrw_fastbrowse,'~'.expand("<slnum>"))

   if &ft != "netrw" || (exists("b:netrw_curdir") && b:netrw_curdir != a:dirname) || g:netrw_fastbrowse <= 1
"    call Decho("case 1 : ft=".&ft,'~'.expand("<slnum>"))
"    call Decho("s:rexposn_".bufnr("%")."<".bufname("%")."> ".(exists("s:rexposn_".bufnr("%"))? "exists" : "does not exist"),'~'.expand("<slnum>"))
    sil! NetrwKeepj keepalt call s:NetrwBrowse(1,a:dirname)

   elseif &ft == "netrw" && line("$") == 1
"    call Decho("case 2 (ft≡netrw && line($)≡1)",'~'.expand("<slnum>"))
    sil! NetrwKeepj keepalt call s:NetrwBrowse(1,a:dirname)

   elseif exists("s:treeforceredraw")
"    call Decho("case 3 (treeforceredraw)",'~'.expand("<slnum>"))
    unlet s:treeforceredraw
    sil! NetrwKeepj keepalt call s:NetrwBrowse(1,a:dirname)
   endif
"   call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
"   call Dret("netrw#LocalBrowseCheck")
   return
  endif

  " The following code wipes out currently unused netrw buffers
  "       IF g:netrw_fastbrowse is zero (ie. slow browsing selected)
  "   AND IF the listing style is not a tree listing
  if exists("g:netrw_fastbrowse") && g:netrw_fastbrowse == 0 && g:netrw_liststyle != s:TREELIST
"   call Decho("wiping out currently unused netrw buffers",'~'.expand("<slnum>"))
   let ibuf    = 1
   let buflast = bufnr("$")
   while ibuf <= buflast
    if bufwinnr(ibuf) == -1 && isdirectory(s:NetrwFile(bufname(ibuf)))
     exe "sil! keepj keepalt ".ibuf."bw!"
    endif
    let ibuf= ibuf + 1
   endwhile
  endif
  let @@= ykeep
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))
  " not a directory, ignore it
"  call Dret("netrw#LocalBrowseCheck : not a directory, ignoring it; dirname<".a:dirname.">")
endfun

" ---------------------------------------------------------------------
" s:LocalBrowseRefresh: this function is called after a user has {{{2
" performed any shell command.  The idea is to cause all local-browsing
" buffers to be refreshed after a user has executed some shell command,
" on the chance that s/he removed/created a file/directory with it.
fun! s:LocalBrowseRefresh()
"  call Dfunc("s:LocalBrowseRefresh() tabpagenr($)=".tabpagenr("$"))
"  call Decho("s:netrw_browselist =".(exists("s:netrw_browselist")?  string(s:netrw_browselist)  : '<n/a>'),'~'.expand("<slnum>"))
"  call Decho("w:netrw_bannercnt  =".(exists("w:netrw_bannercnt")?   string(w:netrw_bannercnt)   : '<n/a>'),'~'.expand("<slnum>"))

  " determine which buffers currently reside in a tab
  if !exists("s:netrw_browselist")
"   call Dret("s:LocalBrowseRefresh : browselist is empty")
   return
  endif
  if !exists("w:netrw_bannercnt")
"   call Dret("s:LocalBrowseRefresh : don't refresh when focus not on netrw window")
   return
  endif
  if !empty(getcmdwintype())
    " cannot move away from cmdline window, see :h E11
    return
  endif
  if exists("s:netrw_events") && s:netrw_events == 1
   " s:LocalFastBrowser gets called (indirectly) from a
   let s:netrw_events= 2
"   call Dret("s:LocalBrowseRefresh : avoid initial double refresh")
   return
  endif
  let itab       = 1
  let buftablist = []
  let ykeep      = @@
  while itab <= tabpagenr("$")
   let buftablist = buftablist + tabpagebuflist()
   let itab       = itab + 1
   sil! tabn
  endwhile
"  call Decho("buftablist".string(buftablist),'~'.expand("<slnum>"))
"  call Decho("s:netrw_browselist<".(exists("s:netrw_browselist")? string(s:netrw_browselist) : "").">",'~'.expand("<slnum>"))
  "  GO through all buffers on netrw_browselist (ie. just local-netrw buffers):
  "   | refresh any netrw window
  "   | wipe out any non-displaying netrw buffer
  let curwinid = win_getid(winnr())
  let ibl    = 0
  for ibuf in s:netrw_browselist
"   call Decho("bufwinnr(".ibuf.") index(buftablist,".ibuf.")=".index(buftablist,ibuf),'~'.expand("<slnum>"))
   if bufwinnr(ibuf) == -1 && index(buftablist,ibuf) == -1
    " wipe out any non-displaying netrw buffer
    " (ibuf not shown in a current window AND
    "  ibuf not in any tab)
"    call Decho("wiping  buf#".ibuf,"<".bufname(ibuf).">",'~'.expand("<slnum>"))
    exe "sil! keepj bd ".fnameescape(ibuf)
    call remove(s:netrw_browselist,ibl)
"    call Decho("browselist=".string(s:netrw_browselist),'~'.expand("<slnum>"))
    continue
   elseif index(tabpagebuflist(),ibuf) != -1
    " refresh any netrw buffer
"    call Decho("refresh buf#".ibuf.'-> win#'.bufwinnr(ibuf),'~'.expand("<slnum>"))
    exe bufwinnr(ibuf)."wincmd w"
    if getline(".") =~# 'Quick Help'
     " decrement g:netrw_quickhelp to prevent refresh from changing g:netrw_quickhelp
     " (counteracts s:NetrwBrowseChgDir()'s incrementing)
     let g:netrw_quickhelp= g:netrw_quickhelp - 1
    endif
"    call Decho("#3: quickhelp=".g:netrw_quickhelp,'~'.expand("<slnum>"))
    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
     NetrwKeepj call s:NetrwRefreshTreeDict(w:netrw_treetop)
    endif
    NetrwKeepj call s:NetrwRefresh(1,s:NetrwBrowseChgDir(1,'./'))
   endif
   let ibl= ibl + 1
"   call Decho("bottom of s:netrw_browselist for loop: ibl=".ibl,'~'.expand("<slnum>"))
  endfor
"  call Decho("restore window: win_gotoid(".curwinid.")")
  call win_gotoid(curwinid)
  let @@= ykeep

"  call Dret("s:LocalBrowseRefresh")
endfun

" ---------------------------------------------------------------------
" s:LocalFastBrowser: handles setting up/taking down fast browsing for the local browser {{{2
"
"     g:netrw_    Directory Is
"     fastbrowse  Local  Remote
"  slow   0         D      D      D=Deleting a buffer implies it will not be re-used (slow)
"  med    1         D      H      H=Hiding a buffer implies it may be re-used        (fast)
"  fast   2         H      H
"
"  Deleting a buffer means that it will be re-loaded when examined, hence "slow".
"  Hiding   a buffer means that it will be re-used   when examined, hence "fast".
"                       (re-using a buffer may not be as accurate)
"
"  s:netrw_events : doesn't exist, s:LocalFastBrowser() will install autocmds with medium-speed or fast browsing
"                   =1: autocmds installed, but ignore next FocusGained event to avoid initial double-refresh of listing.
"                       BufEnter may be first event, then a FocusGained event.  Ignore the first FocusGained event.
"                       If :Explore used: it sets s:netrw_events to 2, so no FocusGained events are ignored.
"                   =2: autocmds installed (doesn't ignore any FocusGained events)
fun! s:LocalFastBrowser()
"  call Dfunc("s:LocalFastBrowser() g:netrw_fastbrowse=".g:netrw_fastbrowse)
"  call Decho("s:netrw_events        ".(exists("s:netrw_events")? "exists"            : 'n/a'),'~'.expand("<slnum>"))
"  call Decho("autocmd: ShellCmdPost ".(exists("#ShellCmdPost")?  "already installed" : "not installed"),'~'.expand("<slnum>"))
"  call Decho("autocmd: FocusGained  ".(exists("#FocusGained")?   "already installed" : "not installed"),'~'.expand("<slnum>"))

  " initialize browselist, a list of buffer numbers that the local browser has used
  if !exists("s:netrw_browselist")
"   call Decho("initialize s:netrw_browselist",'~'.expand("<slnum>"))
   let s:netrw_browselist= []
  endif

  " append current buffer to fastbrowse list
  if empty(s:netrw_browselist) || bufnr("%") > s:netrw_browselist[-1]
"   call Decho("appendng current buffer to browselist",'~'.expand("<slnum>"))
   call add(s:netrw_browselist,bufnr("%"))
"   call Decho("browselist=".string(s:netrw_browselist),'~'.expand("<slnum>"))
  endif

  " enable autocmd events to handle refreshing/removing local browser buffers
  "    If local browse buffer is currently showing: refresh it
  "    If local browse buffer is currently hidden : wipe it
  "    g:netrw_fastbrowse=0 : slow   speed, never re-use directory listing
  "                      =1 : medium speed, re-use directory listing for remote only
  "                      =2 : fast   speed, always re-use directory listing when possible
  if g:netrw_fastbrowse <= 1 && !exists("#ShellCmdPost") && !exists("s:netrw_events")
   let s:netrw_events= 1
   augroup AuNetrwEvent
    au!
    if has("win32")
"     call Decho("installing autocmd: ShellCmdPost",'~'.expand("<slnum>"))
     au ShellCmdPost			*	call s:LocalBrowseRefresh()
    else
"     call Decho("installing autocmds: ShellCmdPost FocusGained",'~'.expand("<slnum>"))
     au ShellCmdPost,FocusGained	*	call s:LocalBrowseRefresh()
    endif
   augroup END

  " user must have changed fastbrowse to its fast setting, so remove
  " the associated autocmd events
  elseif g:netrw_fastbrowse > 1 && exists("#ShellCmdPost") && exists("s:netrw_events")
"   call Decho("remove AuNetrwEvent autcmd group",'~'.expand("<slnum>"))
   unlet s:netrw_events
   augroup AuNetrwEvent
    au!
   augroup END
   augroup! AuNetrwEvent
  endif

"  call Dret("s:LocalFastBrowser : browselist<".string(s:netrw_browselist).">")
endfun

" ---------------------------------------------------------------------
"  s:LocalListing: does the job of "ls" for local directories {{{2
fun! s:LocalListing()
"  call Dfunc("s:LocalListing()")
"  call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"  call Decho("modified=".&modified." modifiable=".&modifiable." readonly=".&readonly,'~'.expand("<slnum>"))
"  call Decho("tab#".tabpagenr()." win#".winnr()." buf#".bufnr("%")."<".bufname("%")."> line#".line(".")." col#".col(".")." winline#".winline()." wincol#".wincol(),'~'.expand("<slnum>"))

"  if exists("b:netrw_curdir") |call Decho('b:netrw_curdir<'.b:netrw_curdir.">")  |else|call Decho("b:netrw_curdir doesn't exist",'~'.expand("<slnum>")) |endif
"  if exists("g:netrw_sort_by")|call Decho('g:netrw_sort_by<'.g:netrw_sort_by.">")|else|call Decho("g:netrw_sort_by doesn't exist",'~'.expand("<slnum>"))|endif
"  call Decho("g:netrw_banner=".g:netrw_banner.": banner ".(g:netrw_banner? "enabled" : "suppressed").": (line($)=".line("$")." byte2line(1)=".byte2line(1)." bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))

  " get the list of files contained in the current directory
  let dirname    = b:netrw_curdir
  let dirnamelen = strlen(b:netrw_curdir)
  let filelist   = s:NetrwGlob(dirname,"*",0)
  let filelist   = filelist + s:NetrwGlob(dirname,".*",0)
"  call Decho("filelist=".string(filelist),'~'.expand("<slnum>"))

  if g:netrw_cygwin == 0 && has("win32")
"   call Decho("filelist=".string(filelist),'~'.expand("<slnum>"))
  elseif index(filelist,'..') == -1 && b:netrw_curdir !~ '/'
    " include ../ in the glob() entry if its missing
"   call Decho("forcibly including on \"..\"",'~'.expand("<slnum>"))
   let filelist= filelist+[s:ComposePath(b:netrw_curdir,"../")]
"   call Decho("filelist=".string(filelist),'~'.expand("<slnum>"))
  endif

"  call Decho("before while: dirname   <".dirname.">",'~'.expand("<slnum>"))
"  call Decho("before while: dirnamelen<".dirnamelen.">",'~'.expand("<slnum>"))
"  call Decho("before while: filelist  =".string(filelist),'~'.expand("<slnum>"))

  if get(g:, 'netrw_dynamic_maxfilenamelen', 0)
   let filelistcopy           = map(deepcopy(filelist),'fnamemodify(v:val, ":t")')
   let g:netrw_maxfilenamelen = max(map(filelistcopy,'len(v:val)')) + 1
"   call Decho("dynamic_maxfilenamelen: filenames             =".string(filelistcopy),'~'.expand("<slnum>"))
"   call Decho("dynamic_maxfilenamelen: g:netrw_maxfilenamelen=".g:netrw_maxfilenamelen,'~'.expand("<slnum>"))
  endif
"  call Decho("g:netrw_banner=".g:netrw_banner.": banner ".(g:netrw_banner? "enabled" : "suppressed").": (line($)=".line("$")." byte2line(1)=".byte2line(1)." bannercnt=".w:netrw_bannercnt.")",'~'.expand("<slnum>"))

  for filename in filelist
"   call Decho(" ",'~'.expand("<slnum>"))
"   call Decho("for filename in filelist: filename<".filename.">",'~'.expand("<slnum>"))

   if getftype(filename) == "link"
    " indicate a symbolic link
"    call Decho("indicate <".filename."> is a symbolic link with trailing @",'~'.expand("<slnum>"))
    let pfile= filename."@"

   elseif getftype(filename) == "socket"
    " indicate a socket
"    call Decho("indicate <".filename."> is a socket with trailing =",'~'.expand("<slnum>"))
    let pfile= filename."="

   elseif getftype(filename) == "fifo"
    " indicate a fifo
"    call Decho("indicate <".filename."> is a fifo with trailing |",'~'.expand("<slnum>"))
    let pfile= filename."|"

   elseif isdirectory(s:NetrwFile(filename))
    " indicate a directory
"    call Decho("indicate <".filename."> is a directory with trailing /",'~'.expand("<slnum>"))
    let pfile= filename."/"

   elseif exists("b:netrw_curdir") && b:netrw_curdir !~ '^.*://' && !isdirectory(s:NetrwFile(filename))
    if has("win32")
     if filename =~ '\.[eE][xX][eE]$' || filename =~ '\.[cC][oO][mM]$' || filename =~ '\.[bB][aA][tT]$'
      " indicate an executable
"      call Decho("indicate <".filename."> is executable with trailing *",'~'.expand("<slnum>"))
      let pfile= filename."*"
     else
      " normal file
      let pfile= filename
     endif
    elseif executable(filename)
     " indicate an executable
"     call Decho("indicate <".filename."> is executable with trailing *",'~'.expand("<slnum>"))
     let pfile= filename."*"
    else
     " normal file
     let pfile= filename
    endif

   else
    " normal file
    let pfile= filename
   endif
"   call Decho("pfile<".pfile."> (after *@/ appending)",'~'.expand("<slnum>"))

   if pfile =~ '//$'
    let pfile= substitute(pfile,'//$','/','e')
"    call Decho("change // to /: pfile<".pfile.">",'~'.expand("<slnum>"))
   endif
   let pfile= strpart(pfile,dirnamelen)
   let pfile= substitute(pfile,'^[/\\]','','e')
"   call Decho("filename<".filename.">",'~'.expand("<slnum>"))
"   call Decho("pfile   <".pfile.">",'~'.expand("<slnum>"))

   if w:netrw_liststyle == s:LONGLIST
    let longfile = printf("%-".g:netrw_maxfilenamelen."S",pfile)
    let sz       = getfsize(filename)
    let szlen    = 15 - (strdisplaywidth(longfile) - g:netrw_maxfilenamelen)
    let szlen    = (szlen > 0) ? szlen : 0

    if g:netrw_sizestyle =~# "[hH]"
     let sz= s:NetrwHumanReadable(sz)
    endif
    let fsz  = printf("%".szlen."S",sz)
    let pfile= longfile."  ".fsz." ".strftime(g:netrw_timefmt,getftime(filename))
"    call Decho("longlist support: sz=".sz." fsz=".fsz,'~'.expand("<slnum>"))
   endif

   if     g:netrw_sort_by =~# "^t"
    " sort by time (handles time up to 1 quintillion seconds, US)
    " Decorate listing by prepending a timestamp/  .  Sorting will then be done based on time.
"    call Decho("implementing g:netrw_sort_by=".g:netrw_sort_by." (time)")
"    call Decho("getftime(".filename.")=".getftime(filename),'~'.expand("<slnum>"))
    let t  = getftime(filename)
    let ft = printf("%018d",t)
"    call Decho("exe NetrwKeepj put ='".ft.'/'.pfile."'",'~'.expand("<slnum>"))
    let ftpfile= ft.'/'.pfile
    sil! NetrwKeepj put=ftpfile

   elseif g:netrw_sort_by =~ "^s"
    " sort by size (handles file sizes up to 1 quintillion bytes, US)
"    call Decho("implementing g:netrw_sort_by=".g:netrw_sort_by." (size)")
"    call Decho("getfsize(".filename.")=".getfsize(filename),'~'.expand("<slnum>"))
    let sz   = getfsize(filename)
    let fsz  = printf("%018d",sz)
"    call Decho("exe NetrwKeepj put ='".fsz.'/'.filename."'",'~'.expand("<slnum>"))
    let fszpfile= fsz.'/'.pfile
    sil! NetrwKeepj put =fszpfile

   else
    " sort by name
"    call Decho("implementing g:netrw_sort_by=".g:netrw_sort_by." (name)")
"    call Decho("exe NetrwKeepj put ='".pfile."'",'~'.expand("<slnum>"))
    sil! NetrwKeepj put=pfile
   endif
"   call DechoBuf(bufnr("%"),"bufnr(%)")
  endfor

  " cleanup any windows mess at end-of-line
  sil! NetrwKeepj g/^$/d
  sil! NetrwKeepj %s/\r$//e
  call histdel("/",-1)
"  call Decho("exe setl ts=".(g:netrw_maxfilenamelen+1),'~'.expand("<slnum>"))
  exe "setl ts=".(g:netrw_maxfilenamelen+1)

"  call Dret("s:LocalListing")
endfun

" ---------------------------------------------------------------------
" s:NetrwLocalExecute: uses system() to execute command under cursor ("X" command support) {{{2
fun! s:NetrwLocalExecute(cmd)
"  call Dfunc("s:NetrwLocalExecute(cmd<".a:cmd.">)")
  let ykeep= @@
  " sanity check
  if !executable(a:cmd)
   call netrw#ErrorMsg(s:ERROR,"the file<".a:cmd."> is not executable!",89)
   let @@= ykeep
"   call Dret("s:NetrwLocalExecute")
   return
  endif

  let optargs= input(":!".a:cmd,"","file")
"  call Decho("optargs<".optargs.">",'~'.expand("<slnum>"))
  let result= system(a:cmd.optargs)
"  call Decho("result,'~'.expand("<slnum>"))

  " strip any ansi escape sequences off
  let result = substitute(result,"\e\\[[0-9;]*m","","g")

  " show user the result(s)
  echomsg result
  let @@= ykeep

"  call Dret("s:NetrwLocalExecute")
endfun

" ---------------------------------------------------------------------
" s:NetrwLocalRename: rename a local file or directory {{{2
fun! s:NetrwLocalRename(path) range
"  call Dfunc("NetrwLocalRename(path<".a:path.">)")

  if !exists("w:netrw_bannercnt")
   let w:netrw_bannercnt= b:netrw_bannercnt
  endif

  " preparation for removing multiple files/directories
  let ykeep     = @@
  let ctr       = a:firstline
  let svpos     = winsaveview()
  let all       = 0
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))

  " rename files given by the markfilelist
  if exists("s:netrwmarkfilelist_{bufnr('%')}")
   for oldname in s:netrwmarkfilelist_{bufnr("%")}
"    call Decho("oldname<".oldname.">",'~'.expand("<slnum>"))
    if exists("subfrom")
     let newname= substitute(oldname,subfrom,subto,'')
"     call Decho("subfrom<".subfrom."> subto<".subto."> newname<".newname.">",'~'.expand("<slnum>"))
    else
     call inputsave()
     let newname= input("Moving ".oldname." to : ",oldname,"file")
     call inputrestore()
     if newname =~ ''
      " two ctrl-x's : ignore all of string preceding the ctrl-x's
      let newname = substitute(newname,'^.*','','')
     elseif newname =~ ''
      " one ctrl-x : ignore portion of string preceding ctrl-x but after last /
      let newname = substitute(newname,'[^/]*','','')
     endif
     if newname =~ '^s/'
      let subfrom = substitute(newname,'^s/\([^/]*\)/.*/$','\1','')
      let subto   = substitute(newname,'^s/[^/]*/\(.*\)/$','\1','')
"      call Decho("subfrom<".subfrom."> subto<".subto."> newname<".newname.">",'~'.expand("<slnum>"))
      let newname = substitute(oldname,subfrom,subto,'')
     endif
    endif
    if !all && filereadable(newname)
     call inputsave()
      let response= input("File<".newname."> already exists; do you want to overwrite it? (y/all/n) ")
     call inputrestore()
     if response == "all"
      let all= 1
     elseif response != "y" && response != "yes"
      " refresh the directory
"      call Decho("refresh the directory listing",'~'.expand("<slnum>"))
      NetrwKeepj call s:NetrwRefresh(1,s:NetrwBrowseChgDir(1,'./'))
"      call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
      NetrwKeepj call winrestview(svpos)
      let @@= ykeep
"      call Dret("NetrwLocalRename")
      return
     endif
    endif
    call rename(oldname,newname)
   endfor
   call s:NetrwUnmarkList(bufnr("%"),b:netrw_curdir)

  else

   " attempt to rename files/directories
   while ctr <= a:lastline
    exe "NetrwKeepj ".ctr

    " sanity checks
    if line(".") < w:netrw_bannercnt
     let ctr= ctr + 1
     continue
    endif
    let curword= s:NetrwGetWord()
    if curword == "./" || curword == "../"
     let ctr= ctr + 1
     continue
    endif

    NetrwKeepj norm! 0
    let oldname= s:ComposePath(a:path,curword)
"    call Decho("oldname<".oldname.">",'~'.expand("<slnum>"))

    call inputsave()
    let newname= input("Moving ".oldname." to : ",substitute(oldname,'/*$','','e'))
    call inputrestore()

    call rename(oldname,newname)
"    call Decho("renaming <".oldname."> to <".newname.">",'~'.expand("<slnum>"))

    let ctr= ctr + 1
   endwhile
  endif

  " refresh the directory
"  call Decho("refresh the directory listing",'~'.expand("<slnum>"))
  NetrwKeepj call s:NetrwRefresh(1,s:NetrwBrowseChgDir(1,'./'))
"  call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
  NetrwKeepj call winrestview(svpos)
  let @@= ykeep

"  call Dret("NetrwLocalRename")
endfun

" ---------------------------------------------------------------------
" s:NetrwLocalRm: {{{2
fun! s:NetrwLocalRm(path) range
"  call Dfunc("s:NetrwLocalRm(path<".a:path.">)")
"  call Decho("firstline=".a:firstline." lastline=".a:lastline,'~'.expand("<slnum>"))

  if !exists("w:netrw_bannercnt")
   let w:netrw_bannercnt= b:netrw_bannercnt
  endif

  " preparation for removing multiple files/directories
  let ykeep = @@
  let ret   = 0
  let all   = 0
  let svpos = winsaveview()
"  call Decho("saving posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))

  if exists("s:netrwmarkfilelist_{bufnr('%')}")
   " remove all marked files
"   call Decho("remove all marked files",'~'.expand("<slnum>"))
   for fname in s:netrwmarkfilelist_{bufnr("%")}
    let ok= s:NetrwLocalRmFile(a:path,fname,all)
    if ok =~# 'q\%[uit]' || ok == "no"
     break
    elseif ok =~# 'a\%[ll]'
     let all= 1
    endif
   endfor
   call s:NetrwUnMarkFile(1)

  else
  " remove (multiple) files and directories
"   call Decho("remove files in range [".a:firstline.",".a:lastline."]",'~'.expand("<slnum>"))

   let keepsol= &l:sol
   setl nosol
   let ctr = a:firstline
   while ctr <= a:lastline
    exe "NetrwKeepj ".ctr

    " sanity checks
    if line(".") < w:netrw_bannercnt
     let ctr= ctr + 1
     continue
    endif
    let curword= s:NetrwGetWord()
    if curword == "./" || curword == "../"
     let ctr= ctr + 1
     continue
    endif
    let ok= s:NetrwLocalRmFile(a:path,curword,all)
    if ok =~# 'q\%[uit]' || ok == "no"
     break
    elseif ok =~# 'a\%[ll]'
     let all= 1
    endif
    let ctr= ctr + 1
   endwhile
   let &l:sol= keepsol
  endif

  " refresh the directory
"  call Decho("bufname<".bufname("%").">",'~'.expand("<slnum>"))
  if bufname("%") != "NetrwMessage"
   NetrwKeepj call s:NetrwRefresh(1,s:NetrwBrowseChgDir(1,'./'))
"   call Decho("restoring posn to svpos<".string(svpos).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(svpos)
  endif
  let @@= ykeep

"  call Dret("s:NetrwLocalRm")
endfun

" ---------------------------------------------------------------------
" s:NetrwLocalRmFile: remove file fname given the path {{{2
"                     Give confirmation prompt unless all==1
fun! s:NetrwLocalRmFile(path,fname,all)
"  call Dfunc("s:NetrwLocalRmFile(path<".a:path."> fname<".a:fname."> all=".a:all)

  let all= a:all
  let ok = ""
  NetrwKeepj norm! 0
  let rmfile= s:NetrwFile(s:ComposePath(a:path,escape(a:fname, '\\')))
"  call Decho("rmfile<".rmfile.">",'~'.expand("<slnum>"))

  if rmfile !~ '^"' && (rmfile =~ '@$' || rmfile !~ '[\/]$')
   " attempt to remove file
"   call Decho("attempt to remove file<".rmfile.">",'~'.expand("<slnum>"))
   if !all
    echohl Statement
    call inputsave()
    let ok= input("Confirm deletion of file <".rmfile."> ","[{y(es)},n(o),a(ll),q(uit)] ")
    call inputrestore()
    echohl NONE
    if ok == ""
     let ok="no"
    endif
"    call Decho("response: ok<".ok.">",'~'.expand("<slnum>"))
    let ok= substitute(ok,'\[{y(es)},n(o),a(ll),q(uit)]\s*','','e')
"    call Decho("response: ok<".ok."> (after sub)",'~'.expand("<slnum>"))
    if ok =~# 'a\%[ll]'
     let all= 1
    endif
   endif

   if all || ok =~# 'y\%[es]' || ok == ""
    let ret= s:NetrwDelete(rmfile)
"    call Decho("errcode=".v:shell_error." ret=".ret,'~'.expand("<slnum>"))
   endif

  else
   " attempt to remove directory
   if !all
    echohl Statement
    call inputsave()
    let ok= input("Confirm *recursive* deletion of directory <".rmfile."> ","[{y(es)},n(o),a(ll),q(uit)] ")
    call inputrestore()
    let ok= substitute(ok,'\[{y(es)},n(o),a(ll),q(uit)]\s*','','e')
    if ok == ""
     let ok="no"
    endif
    if ok =~# 'a\%[ll]'
     let all= 1
    endif
   endif
   let rmfile= substitute(rmfile,'[\/]$','','e')

   if all || ok =~# 'y\%[es]' || ok == ""
    if delete(rmfile,"rf")
     call netrw#ErrorMsg(s:ERROR,"unable to delete directory <".rmfile.">!",103)
    endif
   endif
  endif

"  call Dret("s:NetrwLocalRmFile ".ok)
  return ok
endfun

" =====================================================================
" Support Functions: {{{1

" ---------------------------------------------------------------------
" netrw#Access: intended to provide access to variable values for netrw's test suite {{{2
"   0: marked file list of current buffer
"   1: marked file target
fun! netrw#Access(ilist)
  if     a:ilist == 0
   if exists("s:netrwmarkfilelist_".bufnr('%'))
    return s:netrwmarkfilelist_{bufnr('%')}
   else
    return "no-list-buf#".bufnr('%')
   endif
  elseif a:ilist == 1
   return s:netrwmftgt
  endif
endfun

" ---------------------------------------------------------------------
" netrw#Call: allows user-specified mappings to call internal netrw functions {{{2
fun! netrw#Call(funcname,...)
  return call("s:".a:funcname,a:000)
endfun

" ---------------------------------------------------------------------
" netrw#Expose: allows UserMaps and pchk to look at otherwise script-local variables {{{2
"               I expect this function to be used in
"                 :PChkAssert netrw#Expose("netrwmarkfilelist")
"               for example.
fun! netrw#Expose(varname)
"   call Dfunc("netrw#Expose(varname<".a:varname.">)")
  if exists("s:".a:varname)
   exe "let retval= s:".a:varname
"   call Decho("retval=".retval,'~'.expand("<slnum>"))
   if exists("g:netrw_pchk")
"    call Decho("type(g:netrw_pchk=".g:netrw_pchk.")=".type(retval),'~'.expand("<slnum>"))
    if type(retval) == 3
     let retval = copy(retval)
     let i      = 0
     while i < len(retval)
      let retval[i]= substitute(retval[i],expand("$HOME"),'~','')
      let i        = i + 1
     endwhile
    endif
"     call Dret("netrw#Expose ".string(retval)),'~'.expand("<slnum>"))
    return string(retval)
   else
"    call Decho("g:netrw_pchk doesn't exist",'~'.expand("<slnum>"))
   endif
  else
"   call Decho("s:".a:varname." doesn't exist",'~'.expand("<slnum>"))
   let retval= "n/a"
  endif

"  call Dret("netrw#Expose ".string(retval))
  return retval
endfun

" ---------------------------------------------------------------------
" netrw#Modify: allows UserMaps to set (modify) script-local variables {{{2
fun! netrw#Modify(varname,newvalue)
"  call Dfunc("netrw#Modify(varname<".a:varname.">,newvalue<".string(a:newvalue).">)")
  exe "let s:".a:varname."= ".string(a:newvalue)
"  call Dret("netrw#Modify")
endfun

" ---------------------------------------------------------------------
"  netrw#RFC2396: converts %xx into characters {{{2
fun! netrw#RFC2396(fname)
"  call Dfunc("netrw#RFC2396(fname<".a:fname.">)")
  let fname = escape(substitute(a:fname,'%\(\x\x\)','\=printf("%c","0x".submatch(1))','ge')," \t")
"  call Dret("netrw#RFC2396 ".fname)
  return fname
endfun

" ---------------------------------------------------------------------
" netrw#UserMaps: supports user-specified maps {{{2
"                 see :help function()
"
"                 g:Netrw_UserMaps is a List with members such as:
"                       [[keymap sequence, function reference],...]
"
"                 The referenced function may return a string,
"                 	refresh : refresh the display
"                 	-other- : this string will be executed
"                 or it may return a List of strings.
"
"                 Each keymap-sequence will be set up with a nnoremap
"                 to invoke netrw#UserMaps(a:islocal).
"                 Related functions:
"                   netrw#Expose(varname)          -- see s:varname variables
"                   netrw#Modify(varname,newvalue) -- modify value of s:varname variable
"                   netrw#Call(funcname,...)       -- call internal netrw function with optional arguments
fun! netrw#UserMaps(islocal)
"  call Dfunc("netrw#UserMaps(islocal=".a:islocal.")")
"  call Decho("g:Netrw_UserMaps ".(exists("g:Netrw_UserMaps")? "exists" : "does NOT exist"),'~'.expand("<slnum>"))

   " set up usermaplist
   if exists("g:Netrw_UserMaps") && type(g:Netrw_UserMaps) == 3
"    call Decho("g:Netrw_UserMaps has type 3<List>",'~'.expand("<slnum>"))
    for umap in g:Netrw_UserMaps
"     call Decho("type(umap[0]<".string(umap[0]).">)=".type(umap[0])." (should be 1=string)",'~'.expand("<slnum>"))
"     call Decho("type(umap[1])=".type(umap[1])." (should be 1=string)",'~'.expand("<slnum>"))
     " if umap[0] is a string and umap[1] is a string holding a function name
     if type(umap[0]) == 1 && type(umap[1]) == 1
"      call Decho("nno <buffer> <silent> ".umap[0]." :call s:UserMaps(".a:islocal.",".string(umap[1]).")<cr>",'~'.expand("<slnum>"))
      exe "nno <buffer> <silent> ".umap[0]." :call <SID>UserMaps(".a:islocal.",'".umap[1]."')<cr>"
      else
       call netrw#ErrorMsg(s:WARNING,"ignoring usermap <".string(umap[0])."> -- not a [string,funcref] entry",99)
     endif
    endfor
   endif
"  call Dret("netrw#UserMaps")
endfun

" ---------------------------------------------------------------------
" netrw#WinPath: tries to insure that the path is windows-acceptable, whether cygwin is used or not {{{2
fun! netrw#WinPath(path)
"  call Dfunc("netrw#WinPath(path<".a:path.">)")
  if (!g:netrw_cygwin || &shell !~ '\%(\<bash\>\|\<zsh\>\)\%(\.exe\)\=$') && has("win32")
   " remove cygdrive prefix, if present
   let path = substitute(a:path,g:netrw_cygdrive.'/\(.\)','\1:','')
   " remove trailing slash (Win95)
   let path = substitute(path, '\(\\\|/\)$', '', 'g')
   " remove escaped spaces
   let path = substitute(path, '\ ', ' ', 'g')
   " convert slashes to backslashes
   let path = substitute(path, '/', '\', 'g')
  else
   let path= a:path
  endif
"  call Dret("netrw#WinPath <".path.">")
  return path
endfun

" ---------------------------------------------------------------------
" s:StripTrailingSlash: removes trailing slashes from a path {{{2
fun! s:StripTrailingSlash(path)
   " remove trailing slash
   return substitute(a:path, '[/\\]$', '', 'g')
endfun

" ---------------------------------------------------------------------
" s:NetrwBadd: adds marked files to buffer list or vice versa {{{2
"              cb : bl2mf=0  add marked files to buffer list
"              cB : bl2mf=1  use bufferlist to mark files
"              (mnemonic: cb = copy (marked files) to buffer list)
fun! s:NetrwBadd(islocal,bl2mf)
"  "  call Dfunc("s:NetrwBadd(islocal=".a:islocal." mf2bl=".mf2bl.")")
  if a:bl2mf
   " cB: add buffer list to marked files
   redir => bufl
    ls
   redir END
   let bufl = map(split(bufl,"\n"),'substitute(v:val,''^.\{-}"\(.*\)".\{-}$'',''\1'','''')')
   for fname in bufl
    call s:NetrwMarkFile(a:islocal,fname)
   endfor
  else
   " cb: add marked files to buffer list
   for fname in s:netrwmarkfilelist_{bufnr("%")}
" "   call Decho("badd ".fname,'~'.expand("<slnum>"))
    exe "badd ".fnameescape(fname)
   endfor
   let curbufnr = bufnr("%")
   let curdir   = s:NetrwGetCurdir(a:islocal)
   call s:NetrwUnmarkList(curbufnr,curdir)                   " remove markings from local buffer
  endif
"  call Dret("s:NetrwBadd")
endfun

" ---------------------------------------------------------------------
"  s:ComposePath: Appends a new part to a path taking different systems into consideration {{{2
fun! s:ComposePath(base,subdir)
"  call Dfunc("s:ComposePath(base<".a:base."> subdir<".a:subdir.">)")

  if has("amiga")
"   call Decho("amiga",'~'.expand("<slnum>"))
   let ec = a:base[s:Strlen(a:base)-1]
   if ec != '/' && ec != ':'
    let ret = a:base."/" . a:subdir
   else
    let ret = a:base.a:subdir
   endif

   " COMBAK: test on windows with changing to root directory: :e C:/
  elseif a:subdir =~ '^\a:[/\\]\([^/\\]\|$\)' && has("win32")
"   call Decho("windows",'~'.expand("<slnum>"))
   let ret= a:subdir

  elseif a:base =~ '^\a:[/\\]\([^/\\]\|$\)' && has("win32")
"   call Decho("windows",'~'.expand("<slnum>"))
   if a:base =~ '[/\\]$'
    let ret= a:base.a:subdir
   else
    let ret= a:base.'/'.a:subdir
   endif

  elseif a:base =~ '^\a\{3,}://'
"   call Decho("remote linux/macos",'~'.expand("<slnum>"))
   let urlbase = substitute(a:base,'^\(\a\+://.\{-}/\)\(.*\)$','\1','')
   let curpath = substitute(a:base,'^\(\a\+://.\{-}/\)\(.*\)$','\2','')
   if a:subdir == '../'
    if curpath =~ '[^/]/[^/]\+/$'
     let curpath= substitute(curpath,'[^/]\+/$','','')
    else
     let curpath=""
    endif
    let ret= urlbase.curpath
   else
    let ret= urlbase.curpath.a:subdir
   endif
"   call Decho("urlbase<".urlbase.">",'~'.expand("<slnum>"))
"   call Decho("curpath<".curpath.">",'~'.expand("<slnum>"))
"   call Decho("ret<".ret.">",'~'.expand("<slnum>"))

  else
"   call Decho("local linux/macos",'~'.expand("<slnum>"))
   let ret = substitute(a:base."/".a:subdir,"//","/","g")
   if a:base =~ '^//'
    " keeping initial '//' for the benefit of network share listing support
    let ret= '/'.ret
   endif
   let ret= simplify(ret)
  endif

"  call Dret("s:ComposePath ".ret)
  return ret
endfun

" ---------------------------------------------------------------------
" s:DeleteBookmark: deletes a file/directory from Netrw's bookmark system {{{2
"   Related Functions: s:MakeBookmark() s:NetrwBookHistHandler() s:NetrwBookmark()
fun! s:DeleteBookmark(fname)
"  call Dfunc("s:DeleteBookmark(fname<".a:fname.">)")
  call s:MergeBookmarks()

  if exists("g:netrw_bookmarklist")
   let indx= index(g:netrw_bookmarklist,a:fname)
   if indx == -1
    let indx= 0
    while indx < len(g:netrw_bookmarklist)
     if g:netrw_bookmarklist[indx] =~ a:fname
      call remove(g:netrw_bookmarklist,indx)
      let indx= indx - 1
     endif
     let indx= indx + 1
    endwhile
   else
    " remove exact match
    call remove(g:netrw_bookmarklist,indx)
   endif
  endif

"  call Dret("s:DeleteBookmark")
endfun

" ---------------------------------------------------------------------
" s:FileReadable: o/s independent filereadable {{{2
fun! s:FileReadable(fname)
"  call Dfunc("s:FileReadable(fname<".a:fname.">)")

  if g:netrw_cygwin
   let ret= filereadable(s:NetrwFile(substitute(a:fname,g:netrw_cygdrive.'/\(.\)','\1:/','')))
  else
   let ret= filereadable(s:NetrwFile(a:fname))
  endif

"  call Dret("s:FileReadable ".ret)
  return ret
endfun

" ---------------------------------------------------------------------
"  s:GetTempfile: gets a tempname that'll work for various o/s's {{{2
"                 Places correct suffix on end of temporary filename,
"                 using the suffix provided with fname
fun! s:GetTempfile(fname)
"  call Dfunc("s:GetTempfile(fname<".a:fname.">)")

  if !exists("b:netrw_tmpfile")
   " get a brand new temporary filename
   let tmpfile= tempname()
"   call Decho("tmpfile<".tmpfile."> : from tempname()",'~'.expand("<slnum>"))

   let tmpfile= substitute(tmpfile,'\','/','ge')
"   call Decho("tmpfile<".tmpfile."> : chgd any \\ -> /",'~'.expand("<slnum>"))

   " sanity check -- does the temporary file's directory exist?
   if !isdirectory(s:NetrwFile(substitute(tmpfile,'[^/]\+$','','e')))
"    call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
    NetrwKeepj call netrw#ErrorMsg(s:ERROR,"your <".substitute(tmpfile,'[^/]\+$','','e')."> directory is missing!",2)
"    call Dret("s:GetTempfile getcwd<".getcwd().">")
    return ""
   endif

   " let netrw#NetSource() know about the tmpfile
   let s:netrw_tmpfile= tmpfile " used by netrw#NetSource() and netrw#BrowseX()
"   call Decho("tmpfile<".tmpfile."> s:netrw_tmpfile<".s:netrw_tmpfile.">",'~'.expand("<slnum>"))

   " o/s dependencies
   if g:netrw_cygwin != 0
    let tmpfile = substitute(tmpfile,'^\(\a\):',g:netrw_cygdrive.'/\1','e')
   elseif has("win32")
    if !exists("+shellslash") || !&ssl
     let tmpfile = substitute(tmpfile,'/','\','g')
    endif
   else
    let tmpfile = tmpfile
   endif
   let b:netrw_tmpfile= tmpfile
"   call Decho("o/s dependent fixed tempname<".tmpfile.">",'~'.expand("<slnum>"))
  else
   " re-use temporary filename
   let tmpfile= b:netrw_tmpfile
"   call Decho("tmpfile<".tmpfile."> re-using",'~'.expand("<slnum>"))
  endif

  " use fname's suffix for the temporary file
  if a:fname != ""
   if a:fname =~ '\.[^./]\+$'
"    call Decho("using fname<".a:fname.">'s suffix",'~'.expand("<slnum>"))
    if a:fname =~ '\.tar\.gz$' || a:fname =~ '\.tar\.bz2$' || a:fname =~ '\.tar\.xz$'
     let suffix = ".tar".substitute(a:fname,'^.*\(\.[^./]\+\)$','\1','e')
    elseif a:fname =~ '.txz$'
     let suffix = ".txz".substitute(a:fname,'^.*\(\.[^./]\+\)$','\1','e')
    else
     let suffix = substitute(a:fname,'^.*\(\.[^./]\+\)$','\1','e')
    endif
"    call Decho("suffix<".suffix.">",'~'.expand("<slnum>"))
    let tmpfile= substitute(tmpfile,'\.tmp$','','e')
"    call Decho("chgd tmpfile<".tmpfile."> (removed any .tmp suffix)",'~'.expand("<slnum>"))
    let tmpfile .= suffix
"    call Decho("chgd tmpfile<".tmpfile."> (added ".suffix." suffix) netrw_fname<".b:netrw_fname.">",'~'.expand("<slnum>"))
    let s:netrw_tmpfile= tmpfile " supports netrw#NetSource()
   endif
  endif

"  call Decho("ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
"  call Dret("s:GetTempfile <".tmpfile.">")
  return tmpfile
endfun

" ---------------------------------------------------------------------
" s:MakeSshCmd: transforms input command using USEPORT HOSTNAME into {{{2
"               a correct command for use with a system() call
fun! s:MakeSshCmd(sshcmd)
"  call Dfunc("s:MakeSshCmd(sshcmd<".a:sshcmd.">) user<".s:user."> machine<".s:machine.">")
  if s:user == ""
   let sshcmd = substitute(a:sshcmd,'\<HOSTNAME\>',s:machine,'')
  else
   let sshcmd = substitute(a:sshcmd,'\<HOSTNAME\>',s:user."@".s:machine,'')
  endif
  if exists("g:netrw_port") && g:netrw_port != ""
   let sshcmd= substitute(sshcmd,"USEPORT",g:netrw_sshport.' '.g:netrw_port,'')
  elseif exists("s:port") && s:port != ""
   let sshcmd= substitute(sshcmd,"USEPORT",g:netrw_sshport.' '.s:port,'')
  else
   let sshcmd= substitute(sshcmd,"USEPORT ",'','')
  endif
"  call Dret("s:MakeSshCmd <".sshcmd.">")
  return sshcmd
endfun

" ---------------------------------------------------------------------
" s:MakeBookmark: enters a bookmark into Netrw's bookmark system   {{{2
fun! s:MakeBookmark(fname)
"  call Dfunc("s:MakeBookmark(fname<".a:fname.">)")

  if !exists("g:netrw_bookmarklist")
   let g:netrw_bookmarklist= []
  endif

  if index(g:netrw_bookmarklist,a:fname) == -1
   " curdir not currently in g:netrw_bookmarklist, so include it
   if isdirectory(s:NetrwFile(a:fname)) && a:fname !~ '/$'
    call add(g:netrw_bookmarklist,a:fname.'/')
   elseif a:fname !~ '/'
    call add(g:netrw_bookmarklist,getcwd()."/".a:fname)
   else
    call add(g:netrw_bookmarklist,a:fname)
   endif
   call sort(g:netrw_bookmarklist)
  endif

"  call Dret("s:MakeBookmark")
endfun

" ---------------------------------------------------------------------
" s:MergeBookmarks: merge current bookmarks with saved bookmarks {{{2
fun! s:MergeBookmarks()
"  call Dfunc("s:MergeBookmarks() : merge current bookmarks into .netrwbook")
  " get bookmarks from .netrwbook file
  let savefile= s:NetrwHome()."/.netrwbook"
  if filereadable(s:NetrwFile(savefile))
"   call Decho("merge bookmarks (active and file)",'~'.expand("<slnum>"))
   NetrwKeepj call s:NetrwBookHistSave()
"   call Decho("bookmark delete savefile<".savefile.">",'~'.expand("<slnum>"))
   NetrwKeepj call delete(savefile)
  endif
"  call Dret("s:MergeBookmarks")
endfun

" ---------------------------------------------------------------------
" s:NetrwBMShow: {{{2
fun! s:NetrwBMShow()
"  call Dfunc("s:NetrwBMShow()")
  redir => bmshowraw
   menu
  redir END
  let bmshowlist = split(bmshowraw,'\n')
  if bmshowlist != []
   let bmshowfuncs= filter(bmshowlist,'v:val =~# "<SNR>\\d\\+_BMShow()"')
   if bmshowfuncs != []
    let bmshowfunc = substitute(bmshowfuncs[0],'^.*:\(call.*BMShow()\).*$','\1','')
    if bmshowfunc =~# '^call.*BMShow()'
     exe "sil! NetrwKeepj ".bmshowfunc
    endif
   endif
  endif
"  call Dret("s:NetrwBMShow : bmshowfunc<".(exists("bmshowfunc")? bmshowfunc : 'n/a').">")
endfun

" ---------------------------------------------------------------------
" s:NetrwCursor: responsible for setting cursorline/cursorcolumn based upon g:netrw_cursor {{{2
fun! s:NetrwCursor(editfile)
  if !exists("w:netrw_liststyle")
   let w:netrw_liststyle= g:netrw_liststyle
  endif
"  call Dfunc("s:NetrwCursor() ft<".&ft."> liststyle=".w:netrw_liststyle." g:netrw_cursor=".g:netrw_cursor." s:netrw_usercuc=".s:netrw_usercuc." s:netrw_usercul=".s:netrw_usercul)

"  call Decho("(s:NetrwCursor) COMBAK: cuc=".&l:cuc." cul=".&l:cul)

  if &ft != "netrw"
   " if the current window isn't a netrw directory listing window, then use user cursorline/column
   " settings.  Affects when netrw is used to read/write a file using scp/ftp/etc.
"   call Decho("case ft!=netrw: use user cul,cuc",'~'.expand("<slnum>"))

  elseif g:netrw_cursor == 8
   if w:netrw_liststyle == s:WIDELIST
    setl cursorline
    setl cursorcolumn
   else
    setl cursorline
   endif
  elseif g:netrw_cursor == 7
    setl cursorline
  elseif g:netrw_cursor == 6
   if w:netrw_liststyle == s:WIDELIST
    setl cursorline
   endif
  elseif g:netrw_cursor == 4
   " all styles: cursorline, cursorcolumn
"   call Decho("case g:netrw_cursor==4: setl cul cuc",'~'.expand("<slnum>"))
   setl cursorline
   setl cursorcolumn

  elseif g:netrw_cursor == 3
   " thin-long-tree: cursorline, user's cursorcolumn
   " wide          : cursorline, cursorcolumn
   if w:netrw_liststyle == s:WIDELIST
"    call Decho("case g:netrw_cursor==3 and wide: setl cul cuc",'~'.expand("<slnum>"))
    setl cursorline
    setl cursorcolumn
   else
"    call Decho("case g:netrw_cursor==3 and not wide: setl cul (use user's cuc)",'~'.expand("<slnum>"))
    setl cursorline
   endif

  elseif g:netrw_cursor == 2
   " thin-long-tree: cursorline, user's cursorcolumn
   " wide          : cursorline, user's cursorcolumn
"   call Decho("case g:netrw_cursor==2: setl cuc (use user's cul)",'~'.expand("<slnum>"))
   setl cursorline

  elseif g:netrw_cursor == 1
   " thin-long-tree: user's cursorline, user's cursorcolumn
   " wide          : cursorline,        user's cursorcolumn
   if w:netrw_liststyle == s:WIDELIST
"    call Decho("case g:netrw_cursor==2 and wide: setl cul (use user's cuc)",'~'.expand("<slnum>"))
    setl cursorline
   else
"    call Decho("case g:netrw_cursor==2 and not wide: (use user's cul,cuc)",'~'.expand("<slnum>"))
   endif

  else
   " all styles: user's cursorline, user's cursorcolumn
"   call Decho("default: (use user's cul,cuc)",'~'.expand("<slnum>"))
   let &l:cursorline   = s:netrw_usercul
   let &l:cursorcolumn = s:netrw_usercuc
  endif

" call Decho("(s:NetrwCursor) COMBAK: cuc=".&l:cuc." cul=".&l:cul)
"  call Dret("s:NetrwCursor : l:cursorline=".&l:cursorline." l:cursorcolumn=".&l:cursorcolumn)
endfun

" ---------------------------------------------------------------------
" s:RestoreCursorline: restores cursorline/cursorcolumn to original user settings {{{2
fun! s:RestoreCursorline()
"  call Dfunc("s:RestoreCursorline() currently, cul=".&l:cursorline." cuc=".&l:cursorcolumn." win#".winnr()." buf#".bufnr("%"))
  if exists("s:netrw_usercul")
   let &l:cursorline   = s:netrw_usercul
  endif
  if exists("s:netrw_usercuc")
   let &l:cursorcolumn = s:netrw_usercuc
  endif
"  call Decho("(s:RestoreCursorline) COMBAK: cuc=".&l:cuc." cul=".&l:cul)
"  call Dret("s:RestoreCursorline : restored cul=".&l:cursorline." cuc=".&l:cursorcolumn)
endfun

" s:RestoreRegister: restores all registers given in the dict {{{2
fun! s:RestoreRegister(dict)
  for [key, val] in items(a:dict)
    if key == 'unnamed'
      let key = ''
    endif
    call setreg(key, val[0], val[1])
  endfor
endfun

" ---------------------------------------------------------------------
" s:NetrwDelete: Deletes a file. {{{2
"           Uses Steve Hall's idea to insure that Windows paths stay
"           acceptable.  No effect on Unix paths.
"  Examples of use:  let result= s:NetrwDelete(path)
fun! s:NetrwDelete(path)
"  call Dfunc("s:NetrwDelete(path<".a:path.">)")

  let path = netrw#WinPath(a:path)
  if !g:netrw_cygwin && has("win32")
   if exists("+shellslash")
    let sskeep= &shellslash
    setl noshellslash
    let result      = delete(path)
    let &shellslash = sskeep
   else
"    call Decho("exe let result= ".a:cmd."('".path."')",'~'.expand("<slnum>"))
    let result= delete(path)
   endif
  else
"   call Decho("let result= delete(".path.")",'~'.expand("<slnum>"))
   let result= delete(path)
  endif
  if result < 0
   NetrwKeepj call netrw#ErrorMsg(s:WARNING,"delete(".path.") failed!",71)
  endif

"  call Dret("s:NetrwDelete ".result)
  return result
endfun

" ---------------------------------------------------------------------
" s:NetrwBufRemover: removes a buffer that: {{{2s
"                    has buffer-id > 1
"                    is unlisted
"                    is unnamed
"                    does not appear in any window
fun! s:NetrwBufRemover(bufid)
"  call Dfunc("s:NetrwBufRemover(".a:bufid.")")
"  call Decho("buf#".a:bufid."           ".((a:bufid > 1)? ">" : "≯")." must be >1 for removal","~".expand("<slnum>"))
"  call Decho("buf#".a:bufid." is        ".(buflisted(a:bufid)? "listed" : "unlisted"),"~".expand("<slnum>"))
"  call Decho("buf#".a:bufid." has name <".bufname(a:bufid).">","~".expand("<slnum>"))
"  call Decho("buf#".a:bufid." has winid#".bufwinid(a:bufid),"~".expand("<slnum>"))

  if a:bufid > 1 && !buflisted(a:bufid) && bufloaded(a:bufid) && bufname(a:bufid) == "" && bufwinid(a:bufid) == -1
"   call Decho("(s:NetrwBufRemover) removing buffer#".a:bufid,"~".expand("<slnum>"))
   exe "sil! bd! ".a:bufid
  endif

"  call Dret("s:NetrwBufRemover")
endfun

" ---------------------------------------------------------------------
" s:NetrwEnew: opens a new buffer, passes netrw buffer variables through {{{2
fun! s:NetrwEnew(...)
"  call Dfunc("s:NetrwEnew() a:0=".a:0." win#".winnr()." winnr($)=".winnr("$")." bufnr($)=".bufnr("$")." expand(%)<".expand("%").">")
"  call Decho("curdir<".((a:0>0)? a:1 : "")."> buf#".bufnr("%")."<".bufname("%").">",'~'.expand("<slnum>"))

  " Clean out the last buffer: 
  " Check if the last buffer has # > 1, is unlisted, is unnamed, and does not appear in a window
  " If so, delete it.
  call s:NetrwBufRemover(bufnr("$"))

  " grab a function-local-variable copy of buffer variables
"  call Decho("make function-local copy of netrw variables",'~'.expand("<slnum>"))
  if exists("b:netrw_bannercnt")      |let netrw_bannercnt       = b:netrw_bannercnt      |endif
  if exists("b:netrw_browser_active") |let netrw_browser_active  = b:netrw_browser_active |endif
  if exists("b:netrw_cpf")            |let netrw_cpf             = b:netrw_cpf            |endif
  if exists("b:netrw_curdir")         |let netrw_curdir          = b:netrw_curdir         |endif
  if exists("b:netrw_explore_bufnr")  |let netrw_explore_bufnr   = b:netrw_explore_bufnr  |endif
  if exists("b:netrw_explore_indx")   |let netrw_explore_indx    = b:netrw_explore_indx   |endif
  if exists("b:netrw_explore_line")   |let netrw_explore_line    = b:netrw_explore_line   |endif
  if exists("b:netrw_explore_list")   |let netrw_explore_list    = b:netrw_explore_list   |endif
  if exists("b:netrw_explore_listlen")|let netrw_explore_listlen = b:netrw_explore_listlen|endif
  if exists("b:netrw_explore_mtchcnt")|let netrw_explore_mtchcnt = b:netrw_explore_mtchcnt|endif
  if exists("b:netrw_fname")          |let netrw_fname           = b:netrw_fname          |endif
  if exists("b:netrw_lastfile")       |let netrw_lastfile        = b:netrw_lastfile       |endif
  if exists("b:netrw_liststyle")      |let netrw_liststyle       = b:netrw_liststyle      |endif
  if exists("b:netrw_method")         |let netrw_method          = b:netrw_method         |endif
  if exists("b:netrw_option")         |let netrw_option          = b:netrw_option         |endif
  if exists("b:netrw_prvdir")         |let netrw_prvdir          = b:netrw_prvdir         |endif

  NetrwKeepj call s:NetrwOptionsRestore("w:")
"  call Decho("generate a buffer with NetrwKeepj enew!",'~'.expand("<slnum>"))
  " when tree listing uses file TreeListing... a new buffer is made.
  " Want the old buffer to be unlisted.
  " COMBAK: this causes a problem, see P43
"  setl nobl
  let netrw_keepdiff= &l:diff
  call s:NetrwEditFile("enew!","","")
  let &l:diff= netrw_keepdiff
"  call Decho("bufnr($)=".bufnr("$")."<".bufname(bufnr("$"))."> winnr($)=".winnr("$"),'~'.expand("<slnum>"))
  NetrwKeepj call s:NetrwOptionsSave("w:")

  " copy function-local-variables to buffer variable equivalents
"  call Decho("copy function-local variables back to buffer netrw variables",'~'.expand("<slnum>"))
  if exists("netrw_bannercnt")      |let b:netrw_bannercnt       = netrw_bannercnt      |endif
  if exists("netrw_browser_active") |let b:netrw_browser_active  = netrw_browser_active |endif
  if exists("netrw_cpf")            |let b:netrw_cpf             = netrw_cpf            |endif
  if exists("netrw_curdir")         |let b:netrw_curdir          = netrw_curdir         |endif
  if exists("netrw_explore_bufnr")  |let b:netrw_explore_bufnr   = netrw_explore_bufnr  |endif
  if exists("netrw_explore_indx")   |let b:netrw_explore_indx    = netrw_explore_indx   |endif
  if exists("netrw_explore_line")   |let b:netrw_explore_line    = netrw_explore_line   |endif
  if exists("netrw_explore_list")   |let b:netrw_explore_list    = netrw_explore_list   |endif
  if exists("netrw_explore_listlen")|let b:netrw_explore_listlen = netrw_explore_listlen|endif
  if exists("netrw_explore_mtchcnt")|let b:netrw_explore_mtchcnt = netrw_explore_mtchcnt|endif
  if exists("netrw_fname")          |let b:netrw_fname           = netrw_fname          |endif
  if exists("netrw_lastfile")       |let b:netrw_lastfile        = netrw_lastfile       |endif
  if exists("netrw_liststyle")      |let b:netrw_liststyle       = netrw_liststyle      |endif
  if exists("netrw_method")         |let b:netrw_method          = netrw_method         |endif
  if exists("netrw_option")         |let b:netrw_option          = netrw_option         |endif
  if exists("netrw_prvdir")         |let b:netrw_prvdir          = netrw_prvdir         |endif

  if a:0 > 0
   let b:netrw_curdir= a:1
   if b:netrw_curdir =~ '/$'
    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
     setl nobl
     file NetrwTreeListing
     setl nobl bt=nowrite bh=hide
     nno <silent> <buffer> [	:sil call <SID>TreeListMove('[')<cr>
     nno <silent> <buffer> ]	:sil call <SID>TreeListMove(']')<cr>
    else
     call s:NetrwBufRename(b:netrw_curdir)
    endif
   endif
  endif
  if v:version >= 700 && has("balloon_eval") && !exists("s:initbeval") && !exists("g:netrw_nobeval") && has("syntax") && exists("g:syntax_on")
   let &l:bexpr = "netrw#BalloonHelp()"
  endif

"  call Dret("s:NetrwEnew : buf#".bufnr("%")."<".bufname("%")."> expand(%)<".expand("%")."> expand(#)<".expand("#")."> bh=".&bh." win#".winnr()." winnr($)#".winnr("$"))
endfun

" ---------------------------------------------------------------------
" s:NetrwExe: executes a string using "!" {{{2
fun! s:NetrwExe(cmd)
"  call Dfunc("s:NetrwExe(a:cmd<".a:cmd.">)")
  if has("win32") && &shell !~? 'cmd\|pwsh\|powershell' && !g:netrw_cygwin
"    call Decho("using win32:",expand("<slnum>"))
    let savedShell=[&shell,&shellcmdflag,&shellxquote,&shellxescape,&shellquote,&shellpipe,&shellredir,&shellslash]
    set shell& shellcmdflag& shellxquote& shellxescape&
    set shellquote& shellpipe& shellredir& shellslash&
    exe a:cmd
    let [&shell,&shellcmdflag,&shellxquote,&shellxescape,&shellquote,&shellpipe,&shellredir,&shellslash] = savedShell
  else
"   call Decho("exe ".a:cmd,'~'.expand("<slnum>"))
   exe a:cmd
  endif
  if v:shell_error
   call netrw#ErrorMsg(s:WARNING,"shell signalled an error",106)
  endif
"  call Dret("s:NetrwExe : v:shell_error=".v:shell_error)
endfun

" ---------------------------------------------------------------------
" s:NetrwInsureWinVars: insure that a netrw buffer has its w: variables in spite of a wincmd v or s {{{2
fun! s:NetrwInsureWinVars()
  if !exists("w:netrw_liststyle")
"   call Dfunc("s:NetrwInsureWinVars() win#".winnr())
   let curbuf = bufnr("%")
   let curwin = winnr()
   let iwin   = 1
   while iwin <= winnr("$")
    exe iwin."wincmd w"
    if winnr() != curwin && bufnr("%") == curbuf && exists("w:netrw_liststyle")
     " looks like ctrl-w_s or ctrl-w_v was used to split a netrw buffer
     let winvars= w:
     break
    endif
    let iwin= iwin + 1
   endwhile
   exe "keepalt ".curwin."wincmd w"
   if exists("winvars")
"    call Decho("copying w#".iwin." window variables to w#".curwin,'~'.expand("<slnum>"))
    for k in keys(winvars)
     let w:{k}= winvars[k]
    endfor
   endif
"   call Dret("s:NetrwInsureWinVars win#".winnr())
  endif
endfun

" ---------------------------------------------------------------------
" s:NetrwLcd: handles changing the (local) directory {{{2
"   Returns: 0=success
"           -1=failed
fun! s:NetrwLcd(newdir)
"  call Dfunc("s:NetrwLcd(newdir<".a:newdir.">)")
"  call Decho("changing local directory",'~'.expand("<slnum>"))

  let err472= 0
  try
   exe 'NetrwKeepj sil lcd '.fnameescape(a:newdir)
  catch /^Vim\%((\a\+)\)\=:E344/
     " Vim's lcd fails with E344 when attempting to go above the 'root' of a Windows share.
     " Therefore, detect if a Windows share is present, and if E344 occurs, just settle at
     " 'root' (ie. '\').  The share name may start with either backslashes ('\\Foo') or
     " forward slashes ('//Foo'), depending on whether backslashes have been converted to
     " forward slashes by earlier code; so check for both.
     if has("win32") && !g:netrw_cygwin
       if a:newdir =~ '^\\\\\w\+' || a:newdir =~ '^//\w\+'
         let dirname = '\'
         exe 'NetrwKeepj sil lcd '.fnameescape(dirname)
       endif
     endif
  catch /^Vim\%((\a\+)\)\=:E472/
   let err472= 1
  endtry

  if err472
   call netrw#ErrorMsg(s:ERROR,"unable to change directory to <".a:newdir."> (permissions?)",61)
   if exists("w:netrw_prvdir")
    let a:newdir= w:netrw_prvdir
   else
    call s:NetrwOptionsRestore("w:")
"    call Decho("setl noma nomod nowrap",'~'.expand("<slnum>"))
    exe "setl ".g:netrw_bufsettings
"    call Decho(" ro=".&l:ro." ma=".&l:ma." mod=".&l:mod." wrap=".&l:wrap." (filename<".expand("%")."> win#".winnr()." ft<".&ft.">)",'~'.expand("<slnum>"))
    let a:newdir= dirname
   endif
"   call Dret("s:NetrwBrowse -1 : reusing buffer#".(exists("bufnum")? bufnum : 'N/A')."<".dirname."> getcwd<".getcwd().">")
   return -1
  endif

"  call Decho("getcwd        <".getcwd().">")
"  call Decho("b:netrw_curdir<".b:netrw_curdir.">")
"  call Dret("s:NetrwLcd 0")
  return 0
endfun

" ------------------------------------------------------------------------
" s:NetrwSaveWordPosn: used to keep cursor on same word after refresh, {{{2
" changed sorting, etc.  Also see s:NetrwRestoreWordPosn().
fun! s:NetrwSaveWordPosn()
"  call Dfunc("NetrwSaveWordPosn()")
  let s:netrw_saveword= '^'.fnameescape(getline('.')).'$'
"  call Dret("NetrwSaveWordPosn : saveword<".s:netrw_saveword.">")
endfun

" ---------------------------------------------------------------------
" s:NetrwHumanReadable: takes a number and makes it "human readable" {{{2
"                       1000 -> 1K, 1000000 -> 1M, 1000000000 -> 1G
fun! s:NetrwHumanReadable(sz)
"  call Dfunc("s:NetrwHumanReadable(sz=".a:sz.") type=".type(a:sz)." style=".g:netrw_sizestyle )

  if g:netrw_sizestyle == 'h'
   if a:sz >= 1000000000 
    let sz = printf("%.1f",a:sz/1000000000.0)."g"
   elseif a:sz >= 10000000
    let sz = printf("%d",a:sz/1000000)."m"
   elseif a:sz >= 1000000
    let sz = printf("%.1f",a:sz/1000000.0)."m"
   elseif a:sz >= 10000
    let sz = printf("%d",a:sz/1000)."k"
   elseif a:sz >= 1000
    let sz = printf("%.1f",a:sz/1000.0)."k"
   else
    let sz= a:sz
   endif

  elseif g:netrw_sizestyle == 'H'
   if a:sz >= 1073741824
    let sz = printf("%.1f",a:sz/1073741824.0)."G"
   elseif a:sz >= 10485760
    let sz = printf("%d",a:sz/1048576)."M"
   elseif a:sz >= 1048576
    let sz = printf("%.1f",a:sz/1048576.0)."M"
   elseif a:sz >= 10240
    let sz = printf("%d",a:sz/1024)."K"
   elseif a:sz >= 1024
    let sz = printf("%.1f",a:sz/1024.0)."K"
   else
    let sz= a:sz
   endif

  else
   let sz= a:sz
  endif

"  call Dret("s:NetrwHumanReadable ".sz)
  return sz
endfun

" ---------------------------------------------------------------------
" s:NetrwRestoreWordPosn: used to keep cursor on same word after refresh, {{{2
"  changed sorting, etc.  Also see s:NetrwSaveWordPosn().
fun! s:NetrwRestoreWordPosn()
"  call Dfunc("NetrwRestoreWordPosn()")
  sil! call search(s:netrw_saveword,'w')
"  call Dret("NetrwRestoreWordPosn")
endfun

" ---------------------------------------------------------------------
" s:RestoreBufVars: {{{2
fun! s:RestoreBufVars()
"  call Dfunc("s:RestoreBufVars()")

  if exists("s:netrw_curdir")        |let b:netrw_curdir         = s:netrw_curdir        |endif
  if exists("s:netrw_lastfile")      |let b:netrw_lastfile       = s:netrw_lastfile      |endif
  if exists("s:netrw_method")        |let b:netrw_method         = s:netrw_method        |endif
  if exists("s:netrw_fname")         |let b:netrw_fname          = s:netrw_fname         |endif
  if exists("s:netrw_machine")       |let b:netrw_machine        = s:netrw_machine       |endif
  if exists("s:netrw_browser_active")|let b:netrw_browser_active = s:netrw_browser_active|endif

"  call Dret("s:RestoreBufVars")
endfun

" ---------------------------------------------------------------------
" s:RemotePathAnalysis: {{{2
fun! s:RemotePathAnalysis(dirname)
"  call Dfunc("s:RemotePathAnalysis(a:dirname<".a:dirname.">)")

  "                method   ://    user  @      machine      :port            /path
  let dirpat  = '^\(\w\{-}\)://\(\(\w\+\)@\)\=\([^/:#]\+\)\%([:#]\(\d\+\)\)\=/\(.*\)$'
  let s:method  = substitute(a:dirname,dirpat,'\1','')
  let s:user    = substitute(a:dirname,dirpat,'\3','')
  let s:machine = substitute(a:dirname,dirpat,'\4','')
  let s:port    = substitute(a:dirname,dirpat,'\5','')
  let s:path    = substitute(a:dirname,dirpat,'\6','')
  let s:fname   = substitute(s:path,'^.*/\ze.','','')
  if s:machine =~ '@'
   let dirpat    = '^\(.*\)@\(.\{-}\)$'
   let s:user    = s:user.'@'.substitute(s:machine,dirpat,'\1','')
   let s:machine = substitute(s:machine,dirpat,'\2','')
  endif

"  call Decho("set up s:method <".s:method .">",'~'.expand("<slnum>"))
"  call Decho("set up s:user   <".s:user   .">",'~'.expand("<slnum>"))
"  call Decho("set up s:machine<".s:machine.">",'~'.expand("<slnum>"))
"  call Decho("set up s:port   <".s:port.">",'~'.expand("<slnum>"))
"  call Decho("set up s:path   <".s:path   .">",'~'.expand("<slnum>"))
"  call Decho("set up s:fname  <".s:fname  .">",'~'.expand("<slnum>"))

"  call Dret("s:RemotePathAnalysis")
endfun

" ---------------------------------------------------------------------
" s:RemoteSystem: runs a command on a remote host using ssh {{{2
"                 Returns status
" Runs system() on
"    [cd REMOTEDIRPATH;] a:cmd
" Note that it doesn't do s:ShellEscape(a:cmd)!
fun! s:RemoteSystem(cmd)
"  call Dfunc("s:RemoteSystem(cmd<".a:cmd.">)")
  if !executable(g:netrw_ssh_cmd)
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"g:netrw_ssh_cmd<".g:netrw_ssh_cmd."> is not executable!",52)
  elseif !exists("b:netrw_curdir")
   NetrwKeepj call netrw#ErrorMsg(s:ERROR,"for some reason b:netrw_curdir doesn't exist!",53)
  else
   let cmd      = s:MakeSshCmd(g:netrw_ssh_cmd." USEPORT HOSTNAME")
   let remotedir= substitute(b:netrw_curdir,'^.*//[^/]\+/\(.*\)$','\1','')
   if remotedir != ""
    let cmd= cmd.' cd '.s:ShellEscape(remotedir).";"
   else
    let cmd= cmd.' '
   endif
   let cmd= cmd.a:cmd
"   call Decho("call system(".cmd.")",'~'.expand("<slnum>"))
   let ret= system(cmd)
  endif
"  call Dret("s:RemoteSystem ".ret)
  return ret
endfun

" ---------------------------------------------------------------------
" s:RestoreWinVars: (used by Explore() and NetrwSplit()) {{{2
fun! s:RestoreWinVars()
"  call Dfunc("s:RestoreWinVars()")
  if exists("s:bannercnt")      |let w:netrw_bannercnt       = s:bannercnt      |unlet s:bannercnt      |endif
  if exists("s:col")            |let w:netrw_col             = s:col            |unlet s:col            |endif
  if exists("s:curdir")         |let w:netrw_curdir          = s:curdir         |unlet s:curdir         |endif
  if exists("s:explore_bufnr")  |let w:netrw_explore_bufnr   = s:explore_bufnr  |unlet s:explore_bufnr  |endif
  if exists("s:explore_indx")   |let w:netrw_explore_indx    = s:explore_indx   |unlet s:explore_indx   |endif
  if exists("s:explore_line")   |let w:netrw_explore_line    = s:explore_line   |unlet s:explore_line   |endif
  if exists("s:explore_listlen")|let w:netrw_explore_listlen = s:explore_listlen|unlet s:explore_listlen|endif
  if exists("s:explore_list")   |let w:netrw_explore_list    = s:explore_list   |unlet s:explore_list   |endif
  if exists("s:explore_mtchcnt")|let w:netrw_explore_mtchcnt = s:explore_mtchcnt|unlet s:explore_mtchcnt|endif
  if exists("s:fpl")            |let w:netrw_fpl             = s:fpl            |unlet s:fpl            |endif
  if exists("s:hline")          |let w:netrw_hline           = s:hline          |unlet s:hline          |endif
  if exists("s:line")           |let w:netrw_line            = s:line           |unlet s:line           |endif
  if exists("s:liststyle")      |let w:netrw_liststyle       = s:liststyle      |unlet s:liststyle      |endif
  if exists("s:method")         |let w:netrw_method          = s:method         |unlet s:method         |endif
  if exists("s:prvdir")         |let w:netrw_prvdir          = s:prvdir         |unlet s:prvdir         |endif
  if exists("s:treedict")       |let w:netrw_treedict        = s:treedict       |unlet s:treedict       |endif
  if exists("s:treetop")        |let w:netrw_treetop         = s:treetop        |unlet s:treetop        |endif
  if exists("s:winnr")          |let w:netrw_winnr           = s:winnr          |unlet s:winnr          |endif
"  call Dret("s:RestoreWinVars")
endfun

" ---------------------------------------------------------------------
" s:Rexplore: implements returning from a buffer to a netrw directory {{{2
"
"             s:SetRexDir() sets up <2-leftmouse> maps (if g:netrw_retmap
"             is true) and a command, :Rexplore, which call this function.
"
"             s:netrw_posn is set up by s:NetrwBrowseChgDir()
"
"             s:rexposn_BUFNR used to save/restore cursor position
fun! s:NetrwRexplore(islocal,dirname)
  if exists("s:netrwdrag")
   return
  endif
"  call Dfunc("s:NetrwRexplore() w:netrw_rexlocal=".w:netrw_rexlocal." w:netrw_rexdir<".w:netrw_rexdir."> win#".winnr())
"  call Decho("currently in bufname<".bufname("%").">",'~'.expand("<slnum>"))
"  call Decho("ft=".&ft." win#".winnr()." w:netrw_rexfile<".(exists("w:netrw_rexfile")? w:netrw_rexfile : 'n/a').">",'~'.expand("<slnum>"))

  if &ft == "netrw" && exists("w:netrw_rexfile") && w:netrw_rexfile != ""
   " a :Rex while in a netrw buffer means: edit the file in w:netrw_rexfile
"   call Decho("in netrw buffer, will edit file<".w:netrw_rexfile.">",'~'.expand("<slnum>"))
   exe "NetrwKeepj e ".w:netrw_rexfile
   unlet w:netrw_rexfile
"   call Dret("s:NetrwRexplore returning from netrw to buf#".bufnr("%")."<".bufname("%").">  (ft=".&ft.")")
   return
"  else " Decho
"   call Decho("treating as not-netrw-buffer: ft=".&ft.((&ft == "netrw")? " == netrw" : "!= netrw"),'~'.expand("<slnum>"))
"   call Decho("treating as not-netrw-buffer: w:netrw_rexfile<".((exists("w:netrw_rexfile"))? w:netrw_rexfile : 'n/a').">",'~'.expand("<slnum>"))
  endif

  " ---------------------------
  " :Rex issued while in a file
  " ---------------------------

  " record current file so :Rex can return to it from netrw
  let w:netrw_rexfile= expand("%")
"  call Decho("set w:netrw_rexfile<".w:netrw_rexfile.">  (win#".winnr().")",'~'.expand("<slnum>"))

  if !exists("w:netrw_rexlocal")
"   call Dret("s:NetrwRexplore w:netrw_rexlocal doesn't exist (".&ft." win#".winnr().")")
   return
  endif
"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
  if w:netrw_rexlocal
   NetrwKeepj call netrw#LocalBrowseCheck(w:netrw_rexdir)
  else
   NetrwKeepj call s:NetrwBrowse(0,w:netrw_rexdir)
  endif
  if exists("s:initbeval")
   setl beval
  endif
  if exists("s:rexposn_".bufnr("%"))
"   call Decho("restore posn, then unlet s:rexposn_".bufnr('%')."<".bufname("%").">",'~'.expand("<slnum>"))
   " restore position in directory listing
"   call Decho("restoring posn to s:rexposn_".bufnr('%')."<".string(s:rexposn_{bufnr('%')}).">",'~'.expand("<slnum>"))
   NetrwKeepj call winrestview(s:rexposn_{bufnr('%')})
   if exists("s:rexposn_".bufnr('%'))
    unlet s:rexposn_{bufnr('%')}
   endif
  else
"   call Decho("s:rexposn_".bufnr('%')."<".bufname("%")."> doesn't exist",'~'.expand("<slnum>"))
  endif

  if has("syntax") && exists("g:syntax_on") && g:syntax_on
   if exists("s:explore_match")
    exe "2match netrwMarkFile /".s:explore_match."/"
   endif
  endif

"  call Decho("settings buf#".bufnr("%")."<".bufname("%").">: ".((&l:ma == 0)? "no" : "")."ma ".((&l:mod == 0)? "no" : "")."mod ".((&l:bl == 0)? "no" : "")."bl ".((&l:ro == 0)? "no" : "")."ro fo=".&l:fo,'~'.expand("<slnum>"))
"  call Dret("s:NetrwRexplore : ft=".&ft)
endfun

" ---------------------------------------------------------------------
" s:SaveBufVars: save selected b: variables to s: variables {{{2
"                use s:RestoreBufVars() to restore b: variables from s: variables
fun! s:SaveBufVars()
"  call Dfunc("s:SaveBufVars() buf#".bufnr("%"))

  if exists("b:netrw_curdir")        |let s:netrw_curdir         = b:netrw_curdir        |endif
  if exists("b:netrw_lastfile")      |let s:netrw_lastfile       = b:netrw_lastfile      |endif
  if exists("b:netrw_method")        |let s:netrw_method         = b:netrw_method        |endif
  if exists("b:netrw_fname")         |let s:netrw_fname          = b:netrw_fname         |endif
  if exists("b:netrw_machine")       |let s:netrw_machine        = b:netrw_machine       |endif
  if exists("b:netrw_browser_active")|let s:netrw_browser_active = b:netrw_browser_active|endif

"  call Dret("s:SaveBufVars")
endfun

" ---------------------------------------------------------------------
" s:SavePosn: saves position associated with current buffer into a dictionary {{{2
fun! s:SavePosn(posndict)
"  call Dfunc("s:SavePosn(posndict) curbuf#".bufnr("%")."<".bufname("%").">")

  if !exists("a:posndict[bufnr('%')]")
   let a:posndict[bufnr("%")]= []
  endif
"  call Decho("before push: a:posndict[buf#".bufnr("%")."]=".string(a:posndict[bufnr('%')]))
  call add(a:posndict[bufnr("%")],winsaveview())
"  call Decho("after  push: a:posndict[buf#".bufnr("%")."]=".string(a:posndict[bufnr('%')]))

"  call Dret("s:SavePosn posndict")
  return a:posndict
endfun

" ---------------------------------------------------------------------
" s:RestorePosn: restores position associated with current buffer using dictionary {{{2
fun! s:RestorePosn(posndict)
"  call Dfunc("s:RestorePosn(posndict) curbuf#".bufnr("%")."<".bufname("%").">")
  if exists("a:posndict")
   if has_key(a:posndict,bufnr("%"))
"    call Decho("before pop: a:posndict[buf#".bufnr("%")."]=".string(a:posndict[bufnr('%')]))
    let posnlen= len(a:posndict[bufnr("%")])
    if posnlen > 0
     let posnlen= posnlen - 1
"     call Decho("restoring posn posndict[".bufnr("%")."][".posnlen."]=".string(a:posndict[bufnr("%")][posnlen]),'~'.expand("<slnum>"))
     call winrestview(a:posndict[bufnr("%")][posnlen])
     call remove(a:posndict[bufnr("%")],posnlen)
"     call Decho("after  pop: a:posndict[buf#".bufnr("%")."]=".string(a:posndict[bufnr('%')]))
    endif
   endif
  endif
"  call Dret("s:RestorePosn")
endfun

" ---------------------------------------------------------------------
" s:SaveWinVars: (used by Explore() and NetrwSplit()) {{{2
fun! s:SaveWinVars()
"  call Dfunc("s:SaveWinVars() win#".winnr())
  if exists("w:netrw_bannercnt")      |let s:bannercnt       = w:netrw_bannercnt      |endif
  if exists("w:netrw_col")            |let s:col             = w:netrw_col            |endif
  if exists("w:netrw_curdir")         |let s:curdir          = w:netrw_curdir         |endif
  if exists("w:netrw_explore_bufnr")  |let s:explore_bufnr   = w:netrw_explore_bufnr  |endif
  if exists("w:netrw_explore_indx")   |let s:explore_indx    = w:netrw_explore_indx   |endif
  if exists("w:netrw_explore_line")   |let s:explore_line    = w:netrw_explore_line   |endif
  if exists("w:netrw_explore_listlen")|let s:explore_listlen = w:netrw_explore_listlen|endif
  if exists("w:netrw_explore_list")   |let s:explore_list    = w:netrw_explore_list   |endif
  if exists("w:netrw_explore_mtchcnt")|let s:explore_mtchcnt = w:netrw_explore_mtchcnt|endif
  if exists("w:netrw_fpl")            |let s:fpl             = w:netrw_fpl            |endif
  if exists("w:netrw_hline")          |let s:hline           = w:netrw_hline          |endif
  if exists("w:netrw_line")           |let s:line            = w:netrw_line           |endif
  if exists("w:netrw_liststyle")      |let s:liststyle       = w:netrw_liststyle      |endif
  if exists("w:netrw_method")         |let s:method          = w:netrw_method         |endif
  if exists("w:netrw_prvdir")         |let s:prvdir          = w:netrw_prvdir         |endif
  if exists("w:netrw_treedict")       |let s:treedict        = w:netrw_treedict       |endif
  if exists("w:netrw_treetop")        |let s:treetop         = w:netrw_treetop        |endif
  if exists("w:netrw_winnr")          |let s:winnr           = w:netrw_winnr          |endif
"  call Dret("s:SaveWinVars")
endfun

" ---------------------------------------------------------------------
" s:SetBufWinVars: (used by NetrwBrowse() and LocalBrowseCheck()) {{{2
"   To allow separate windows to have their own activities, such as
"   Explore **/pattern, several variables have been made window-oriented.
"   However, when the user splits a browser window (ex: ctrl-w s), these
"   variables are not inherited by the new window.  SetBufWinVars() and
"   UseBufWinVars() get around that.
fun! s:SetBufWinVars()
"  call Dfunc("s:SetBufWinVars() win#".winnr())
  if exists("w:netrw_liststyle")      |let b:netrw_liststyle      = w:netrw_liststyle      |endif
  if exists("w:netrw_bannercnt")      |let b:netrw_bannercnt      = w:netrw_bannercnt      |endif
  if exists("w:netrw_method")         |let b:netrw_method         = w:netrw_method         |endif
  if exists("w:netrw_prvdir")         |let b:netrw_prvdir         = w:netrw_prvdir         |endif
  if exists("w:netrw_explore_indx")   |let b:netrw_explore_indx   = w:netrw_explore_indx   |endif
  if exists("w:netrw_explore_listlen")|let b:netrw_explore_listlen= w:netrw_explore_listlen|endif
  if exists("w:netrw_explore_mtchcnt")|let b:netrw_explore_mtchcnt= w:netrw_explore_mtchcnt|endif
  if exists("w:netrw_explore_bufnr")  |let b:netrw_explore_bufnr  = w:netrw_explore_bufnr  |endif
  if exists("w:netrw_explore_line")   |let b:netrw_explore_line   = w:netrw_explore_line   |endif
  if exists("w:netrw_explore_list")   |let b:netrw_explore_list   = w:netrw_explore_list   |endif
"  call Dret("s:SetBufWinVars")
endfun

" ---------------------------------------------------------------------
" s:SetRexDir: set directory for :Rexplore {{{2
fun! s:SetRexDir(islocal,dirname)
"  call Dfunc("s:SetRexDir(islocal=".a:islocal." dirname<".a:dirname.">) win#".winnr())
  let w:netrw_rexdir         = a:dirname
  let w:netrw_rexlocal       = a:islocal
  let s:rexposn_{bufnr("%")} = winsaveview()
"  call Decho("setting w:netrw_rexdir  =".w:netrw_rexdir,'~'.expand("<slnum>"))
"  call Decho("setting w:netrw_rexlocal=".w:netrw_rexlocal,'~'.expand("<slnum>"))
"  call Decho("saving posn to s:rexposn_".bufnr("%")."<".string(s:rexposn_{bufnr("%")}).">",'~'.expand("<slnum>"))
"  call Decho("setting s:rexposn_".bufnr("%")."<".bufname("%")."> to ".string(winsaveview()),'~'.expand("<slnum>"))
"  call Dret("s:SetRexDir : win#".winnr()." ".(a:islocal? "local" : "remote")." dir: ".a:dirname)
endfun

" ---------------------------------------------------------------------
" s:ShowLink: used to modify thin and tree listings to show links {{{2
fun! s:ShowLink()
" "  call Dfunc("s:ShowLink()")
" "  call Decho("b:netrw_curdir<".(exists("b:netrw_curdir")? b:netrw_curdir : "doesn't exist").">",'~'.expand("<slnum>"))
" "  call Decho(printf("line#%4d: %s",line("."),getline(".")),'~'.expand("<slnum>"))
  if exists("b:netrw_curdir")
   norm! $?\a
   let fname   = b:netrw_curdir.'/'.s:NetrwGetWord()
   let resname = resolve(fname)
" "   call Decho("fname         <".fname.">",'~'.expand("<slnum>"))
" "   call Decho("resname       <".resname.">",'~'.expand("<slnum>"))
" "   call Decho("b:netrw_curdir<".b:netrw_curdir.">",'~'.expand("<slnum>"))
   if resname =~ '^\M'.b:netrw_curdir.'/'
    let dirlen  = strlen(b:netrw_curdir)
    let resname = strpart(resname,dirlen+1)
" "    call Decho("resname<".resname.">  (b:netrw_curdir elided)",'~'.expand("<slnum>"))
   endif
   let modline = getline(".")."\t --> ".resname
" "   call Decho("fname  <".fname.">",'~'.expand("<slnum>"))
" "   call Decho("modline<".modline.">",'~'.expand("<slnum>"))
   setl noro ma
   call setline(".",modline)
   setl ro noma nomod
  endif
" "  call Dret("s:ShowLink".((exists("fname")? ' : '.fname : 'n/a')))
endfun

" ---------------------------------------------------------------------
" s:ShowStyle: {{{2
fun! s:ShowStyle()
  if !exists("w:netrw_liststyle")
   let liststyle= g:netrw_liststyle
  else
   let liststyle= w:netrw_liststyle
  endif
  if     liststyle == s:THINLIST
   return s:THINLIST.":thin"
  elseif liststyle == s:LONGLIST
   return s:LONGLIST.":long"
  elseif liststyle == s:WIDELIST
   return s:WIDELIST.":wide"
  elseif liststyle == s:TREELIST
   return s:TREELIST.":tree"
  else
   return 'n/a'
  endif
endfun

" ---------------------------------------------------------------------
" s:Strlen: this function returns the length of a string, even if its using multi-byte characters. {{{2
"           Solution from Nicolai Weibull, vim docs (:help strlen()),
"           Tony Mechelynck, and my own invention.
fun! s:Strlen(x)
"  "" call Dfunc("s:Strlen(x<".a:x."> g:Align_xstrlen=".g:Align_xstrlen.")")

  if v:version >= 703 && exists("*strdisplaywidth")
   let ret= strdisplaywidth(a:x)

  elseif type(g:Align_xstrlen) == 1
   " allow user to specify a function to compute the string length  (ie. let g:Align_xstrlen="mystrlenfunc")
   exe "let ret= ".g:Align_xstrlen."('".substitute(a:x,"'","''","g")."')"

  elseif g:Align_xstrlen == 1
   " number of codepoints (Latin a + combining circumflex is two codepoints)
   " (comment from TM, solution from NW)
   let ret= strlen(substitute(a:x,'.','c','g'))

  elseif g:Align_xstrlen == 2
   " number of spacing codepoints (Latin a + combining circumflex is one spacing
   " codepoint; a hard tab is one; wide and narrow CJK are one each; etc.)
   " (comment from TM, solution from TM)
   let ret=strlen(substitute(a:x, '.\Z', 'x', 'g'))

  elseif g:Align_xstrlen == 3
   " virtual length (counting, for instance, tabs as anything between 1 and
   " 'tabstop', wide CJK as 2 rather than 1, Arabic alif as zero when immediately
   " preceded by lam, one otherwise, etc.)
   " (comment from TM, solution from me)
   let modkeep= &l:mod
   exe "norm! o\<esc>"
   call setline(line("."),a:x)
   let ret= virtcol("$") - 1
   d
   NetrwKeepj norm! k
   let &l:mod= modkeep

  else
   " at least give a decent default
    let ret= strlen(a:x)
  endif
"  "" call Dret("s:Strlen ".ret)
  return ret
endfun

" ---------------------------------------------------------------------
" s:ShellEscape: shellescape(), or special windows handling {{{2
fun! s:ShellEscape(s, ...)
  if has('win32') && $SHELL == '' && &shellslash
    return printf('"%s"', substitute(a:s, '"', '""', 'g'))
  endif 
  let f = a:0 > 0 ? a:1 : 0
  return shellescape(a:s, f)
endfun

" ---------------------------------------------------------------------
" s:TreeListMove: supports [[, ]], [], and ][ in tree mode {{{2
fun! s:TreeListMove(dir)
"  call Dfunc("s:TreeListMove(dir<".a:dir.">)")
  let curline      = getline('.')
  let prvline      = (line(".") > 1)?         getline(line(".")-1) : ''
  let nxtline      = (line(".") < line("$"))? getline(line(".")+1) : ''
  let curindent    = substitute(getline('.'),'^\(\%('.s:treedepthstring.'\)*\)[^'.s:treedepthstring.'].\{-}$','\1','e')
  let indentm1     = substitute(curindent,'^'.s:treedepthstring,'','')
  let treedepthchr = substitute(s:treedepthstring,' ','','g')
  let stopline     = exists("w:netrw_bannercnt")? w:netrw_bannercnt : 1
"  call Decho("prvline  <".prvline."> #".(line(".")-1), '~'.expand("<slnum>"))
"  call Decho("curline  <".curline."> #".line(".")    , '~'.expand("<slnum>"))
"  call Decho("nxtline  <".nxtline."> #".(line(".")+1), '~'.expand("<slnum>"))
"  call Decho("curindent<".curindent.">"              , '~'.expand("<slnum>"))
"  call Decho("indentm1 <".indentm1.">"               , '~'.expand("<slnum>"))
  "  COMBAK : need to handle when on a directory
  "  COMBAK : need to handle ]] and ][.  In general, needs work!!!
  if curline !~ '/$'
   if     a:dir == '[[' && prvline != ''
    NetrwKeepj norm! 0
    let nl = search('^'.indentm1.'\%('.s:treedepthstring.'\)\@!','bWe',stopline) " search backwards
"    call Decho("regfile srch back: ".nl,'~'.expand("<slnum>"))
   elseif a:dir == '[]' && nxtline != ''
    NetrwKeepj norm! 0
"    call Decho('srchpat<'.'^\%('.curindent.'\)\@!'.'>','~'.expand("<slnum>"))
    let nl = search('^\%('.curindent.'\)\@!','We') " search forwards
    if nl != 0
     NetrwKeepj norm! k
    else
     NetrwKeepj norm! G
    endif
"    call Decho("regfile srch fwd: ".nl,'~'.expand("<slnum>"))
   endif
  endif

"  call Dret("s:TreeListMove")
endfun

" ---------------------------------------------------------------------
" s:UpdateBuffersMenu: does emenu Buffers.Refresh (but due to locale, the menu item may not be called that) {{{2
"                      The Buffers.Refresh menu calls s:BMShow(); unfortunately, that means that that function
"                      can't be called except via emenu.  But due to locale, that menu line may not be called
"                      Buffers.Refresh; hence, s:NetrwBMShow() utilizes a "cheat" to call that function anyway.
fun! s:UpdateBuffersMenu()
"  call Dfunc("s:UpdateBuffersMenu()")
  if has("gui") && has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu
   try
    sil emenu Buffers.Refresh\ menu
   catch /^Vim\%((\a\+)\)\=:E/
    let v:errmsg= ""
    sil NetrwKeepj call s:NetrwBMShow()
   endtry
  endif
"  call Dret("s:UpdateBuffersMenu")
endfun

" ---------------------------------------------------------------------
" s:UseBufWinVars: (used by NetrwBrowse() and LocalBrowseCheck() {{{2
"              Matching function to s:SetBufWinVars()
fun! s:UseBufWinVars()
"  call Dfunc("s:UseBufWinVars()")
  if exists("b:netrw_liststyle")       && !exists("w:netrw_liststyle")      |let w:netrw_liststyle       = b:netrw_liststyle      |endif
  if exists("b:netrw_bannercnt")       && !exists("w:netrw_bannercnt")      |let w:netrw_bannercnt       = b:netrw_bannercnt      |endif
  if exists("b:netrw_method")          && !exists("w:netrw_method")         |let w:netrw_method          = b:netrw_method         |endif
  if exists("b:netrw_prvdir")          && !exists("w:netrw_prvdir")         |let w:netrw_prvdir          = b:netrw_prvdir         |endif
  if exists("b:netrw_explore_indx")    && !exists("w:netrw_explore_indx")   |let w:netrw_explore_indx    = b:netrw_explore_indx   |endif
  if exists("b:netrw_explore_listlen") && !exists("w:netrw_explore_listlen")|let w:netrw_explore_listlen = b:netrw_explore_listlen|endif
  if exists("b:netrw_explore_mtchcnt") && !exists("w:netrw_explore_mtchcnt")|let w:netrw_explore_mtchcnt = b:netrw_explore_mtchcnt|endif
  if exists("b:netrw_explore_bufnr")   && !exists("w:netrw_explore_bufnr")  |let w:netrw_explore_bufnr   = b:netrw_explore_bufnr  |endif
  if exists("b:netrw_explore_line")    && !exists("w:netrw_explore_line")   |let w:netrw_explore_line    = b:netrw_explore_line   |endif
  if exists("b:netrw_explore_list")    && !exists("w:netrw_explore_list")   |let w:netrw_explore_list    = b:netrw_explore_list   |endif
"  call Dret("s:UseBufWinVars")
endfun

" ---------------------------------------------------------------------
" s:UserMaps: supports user-defined UserMaps {{{2
"               * calls a user-supplied funcref(islocal,curdir)
"               * interprets result
"             See netrw#UserMaps()
fun! s:UserMaps(islocal,funcname)
"  call Dfunc("s:UserMaps(islocal=".a:islocal.",funcname<".a:funcname.">)")

  if !exists("b:netrw_curdir")
   let b:netrw_curdir= getcwd()
  endif
  let Funcref = function(a:funcname)
  let result  = Funcref(a:islocal)

  if     type(result) == 1
   " if result from user's funcref is a string...
"   call Decho("result string from user funcref<".result.">",'~'.expand("<slnum>"))
   if result == "refresh"
"    call Decho("refreshing display",'~'.expand("<slnum>"))
    call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
   elseif result != ""
"    call Decho("executing result<".result.">",'~'.expand("<slnum>"))
    exe result
   endif

  elseif type(result) == 3
   " if result from user's funcref is a List...
"   call Decho("result List from user funcref<".string(result).">",'~'.expand("<slnum>"))
   for action in result
    if action == "refresh"
"     call Decho("refreshing display",'~'.expand("<slnum>"))
     call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./'))
    elseif action != ""
"     call Decho("executing action<".action.">",'~'.expand("<slnum>"))
     exe action
    endif
   endfor
  endif

"  call Dret("s:UserMaps")
endfun

" ==========================
" Settings Restoration: {{{1
" ==========================
let &cpo= s:keepcpo
unlet s:keepcpo

" ===============
" Modelines: {{{1
" ===============
" vim:ts=8 fdm=marker
" doing autoload/netrw.vim version v172g ~57
" varname<g:netrw_dirhistcnt> value=0 ~1
" varname<s:THINLIST> value=0 ~1
" varname<s:LONGLIST> value=1 ~1
" varname<s:WIDELIST> value=2 ~1
" varname<s:TREELIST> value=3 ~1
" varname<s:MAXLIST> value=4 ~1
" varname<g:netrw_use_errorwindow> value=2 ~1
" varname<g:netrw_http_xcmd> value=-q -O ~1
" varname<g:netrw_http_put_cmd> value=curl -T ~1
" varname<g:netrw_keepj> value=keepj ~1
" varname<g:netrw_rcp_cmd> value=rcp ~1
" varname<g:netrw_rsync_cmd> value=rsync ~1
" varname<g:netrw_rsync_sep> value=/ ~1
" varname<g:netrw_scp_cmd> value=scp -q ~1
" varname<g:netrw_sftp_cmd> value=sftp ~1
" varname<g:netrw_ssh_cmd> value=ssh ~1
" varname<g:netrw_alto> value=0 ~1
" varname<g:netrw_altv> value=1 ~1
" varname<g:netrw_banner> value=1 ~1
" varname<g:netrw_browse_split> value=0 ~1
" varname<g:netrw_bufsettings> value=noma nomod nonu nobl nowrap ro nornu ~1
" varname<g:netrw_chgwin> value=-1 ~1
" varname<g:netrw_clipboard> value=1 ~1
" varname<g:netrw_compress> value=gzip ~1
" varname<g:netrw_ctags> value=ctags ~1
" varname<g:netrw_cursor> value=2 ~1
" (netrw) COMBAK: cuc=0 cul=0 initialization of s:netrw_cu[cl]
" varname<g:netrw_cygdrive> value=/cygdrive ~1
" varname<s:didstarstar> value=0 ~1
" varname<g:netrw_dirhistcnt> value=0 ~1
" varname<g:netrw_decompress> value={ ".gz" : "gunzip", ".bz2" : "bunzip2", ".zip" : "unzip", ".tar" : "tar -xf", ".xz" : "unxz" } ~1
" varname<g:netrw_dirhistmax> value=10 ~1
" varname<g:netrw_errorlvl> value=0 ~1
" varname<g:netrw_fastbrowse> value=1 ~1
" varname<g:netrw_ftp_browse_reject> value=^total\s\+\d\+$\|^Trying\s\+\d\+.*$\|^KERBEROS_V\d rejected\|^Security extensions not\|No such file\|: connect to address [0-9a-fA-F:]*: No route to host$ ~1
" varname<g:netrw_ftpmode> value=binary ~1
" varname<g:netrw_hide> value=1 ~1
" varname<g:netrw_keepdir> value=1 ~1
" varname<g:netrw_list_hide> value= ~1
" varname<g:netrw_localmkdir> value=mkdir ~1
" varname<g:netrw_remote_mkdir> value=mkdir ~1
" varname<g:netrw_liststyle> value=0 ~1
" varname<g:netrw_markfileesc> value=*./[\~ ~1
" varname<g:netrw_maxfilenamelen> value=32 ~1
" varname<g:netrw_menu> value=1 ~1
" varname<g:netrw_mkdir_cmd> value=ssh USEPORT HOSTNAME mkdir ~1
" varname<g:netrw_mousemaps> value=1 ~1
" varname<g:netrw_retmap> value=0 ~1
" varname<g:netrw_chgperm> value=chmod PERM FILENAME ~1
" varname<g:netrw_preview> value=0 ~1
