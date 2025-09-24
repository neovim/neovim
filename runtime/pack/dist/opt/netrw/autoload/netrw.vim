" Creator:    Charles E Campbell
" Previous Maintainer: Luca Saccarola <github.e41mv@aleeas.com>
" Maintainer: This runtime file is looking for a new maintainer.
" Last Change:
" 2025 Aug 07 by Vim Project (use correct "=~#" for netrw_stylesize option #17901)
" 2025 Aug 07 by Vim Project (netrw#BrowseX() distinguishes remote files #17794)
" 2025 Aug 22 by Vim Project netrw#Explore handle terminal correctly #18069
" 2025 Sep 05 by Vim Project ensure netrw#fs#Dirname() returns trailing slash #18199
" 2025 Sep 11 by Vim Project only keep cursor position in tree mode #18275
" 2025 Sep 17 by Vim Project tighten the regex to handle remote compressed archives #18318
" 2025 Sep 18 by Vim Project 'equalalways' not always respected #18358
" Copyright:  Copyright (C) 2016 Charles E. Campbell {{{1
"             Permission is hereby granted to use and distribute this code,
"             with or without modifications, provided that this copyright
"             notice is copied with it. Like anything else that's free,
"             netrw.vim, netrwPlugin.vim, and netrwSettings.vim are provided
"             *as is* and come with no warranty of any kind, either
"             expressed or implied. By using this plugin, you agree that
"             in no event will the copyright holder be liable for any damages
"             resulting from the use of this software.
"
" Note: the code here was started in 1999 under a much earlier version of vim.  The directory browsing
"       code was written using vim v6, which did not have Lists (Lists were first offered with vim-v7).

" Load Once: {{{1
if &cp || exists("g:loaded_netrw")
    finish
endif

let g:loaded_netrw = "v184"

if !has("patch-9.1.1054") && !has('nvim')
    echoerr 'netrw needs Vim v9.1.1054'
    finish
endif

let s:keepcpo= &cpo
setl cpo&vim

"  Netrw Variables: {{{1

" s:NetrwInit: initializes variables if they haven't been defined {{{2

function s:NetrwInit(name, default)
    if !exists(a:name)
        let {a:name} = a:default
    endif
endfunction

"  Netrw Constants: {{{2
call s:NetrwInit("g:netrw_dirhistcnt",0)
if !exists("s:LONGLIST")
  call s:NetrwInit("s:THINLIST",0)
  call s:NetrwInit("s:LONGLIST",1)
  call s:NetrwInit("s:WIDELIST",2)
  call s:NetrwInit("s:TREELIST",3)
  call s:NetrwInit("s:MAXLIST" ,4)
endif

" Default option values: {{{2
call s:NetrwInit("g:netrw_localcopycmdopt","")
call s:NetrwInit("g:netrw_localcopydircmdopt","")
call s:NetrwInit("g:netrw_localmkdiropt","")
call s:NetrwInit("g:netrw_localmovecmdopt","")

" Default values for netrw's global protocol variables {{{2

if !exists("g:netrw_dav_cmd")
  if executable("cadaver")
    let g:netrw_dav_cmd   = "cadaver"
  elseif executable("curl")
    let g:netrw_dav_cmd   = "curl"
  else
    let g:netrw_dav_cmd   = ""
  endif
endif
if !exists("g:netrw_fetch_cmd")
  if executable("fetch")
    let g:netrw_fetch_cmd = "fetch -o"
  else
    let g:netrw_fetch_cmd = ""
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
  let g:netrw_ftp_cmd   = "ftp"
endif
let s:netrw_ftp_cmd= g:netrw_ftp_cmd
if !exists("g:netrw_ftp_options")
  let g:netrw_ftp_options= "-i -n"
endif
if !exists("g:netrw_http_cmd")
  if executable("wget")
    let g:netrw_http_cmd  = "wget"
    call s:NetrwInit("g:netrw_http_xcmd","-q -O")
  elseif executable("curl")
    let g:netrw_http_cmd  = "curl"
    call s:NetrwInit("g:netrw_http_xcmd","-L -o")
  elseif executable("elinks")
    let g:netrw_http_cmd = "elinks"
    call s:NetrwInit("g:netrw_http_xcmd","-source >")
  elseif executable("fetch")
    let g:netrw_http_cmd  = "fetch"
    call s:NetrwInit("g:netrw_http_xcmd","-o")
  elseif executable("links")
    let g:netrw_http_cmd = "links"
    call s:NetrwInit("g:netrw_http_xcmd","-http.extra-header ".shellescape("Accept-Encoding: identity", 1)." -source >")
  else
    let g:netrw_http_cmd  = ""
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
call s:NetrwInit("g:netrw_cursor"      , 2)
let s:netrw_usercul = &cursorline
let s:netrw_usercuc = &cursorcolumn
call s:NetrwInit("g:netrw_cygdrive","/cygdrive")
" Default values - d-g ---------- {{{3
call s:NetrwInit("s:didstarstar",0)
call s:NetrwInit("g:netrw_dirhistcnt"      , 0)
let s:xz_opt = has('unix') ? "XZ_OPT=-T0" :
      \ (has("win32") && &shell =~? '\vcmd(\.exe)?$' ?
      \ "setx XZ_OPT=-T0 &&" : "")
call s:NetrwInit("g:netrw_decompress", {
            \ '.lz4': 'lz4 -d',
            \ '.lzo': 'lzop -d',
            \ '.lz': 'lzip -dk',
            \ '.7z': '7za x',
            \ '.001': '7za x',
            \ '.zip': 'unzip',
            \ '.bz': 'bunzip2 -k',
            \ '.bz2': 'bunzip2 -k',
            \ '.gz': 'gunzip -k',
            \ '.lzma': 'unlzma -T0 -k',
            \ '.xz': 'unxz -T0 -k',
            \ '.zst': 'zstd -T0 -d',
            \ '.Z': 'uncompress -k',
            \ '.tar': 'tar -xvf',
            \ '.tar.bz': 'tar -xvjf',
            \ '.tar.bz2': 'tar -xvjf',
            \ '.tbz': 'tar -xvjf',
            \ '.tbz2': 'tar -xvjf',
            \ '.tar.gz': 'tar -xvzf',
            \ '.tgz': 'tar -xvzf',
            \ '.tar.lzma': s:xz_opt .. ' tar -xvf --lzma',
            \ '.tlz': s:xz_opt .. ' tar -xvf --lzma',
            \ '.tar.xz': s:xz_opt .. ' tar -xvfJ',
            \ '.txz': s:xz_opt .. ' tar -xvfJ',
            \ '.tar.zst': s:xz_opt .. ' tar -xvf --use-compress-program=unzstd',
            \ '.tzst': s:xz_opt .. ' tar -xvf --use-compress-program=unzstd',
            \ '.rar': (executable("unrar")?"unrar x -ad":"rar x -ad"),
            \ })
unlet s:xz_opt
call s:NetrwInit("g:netrw_dirhistmax"       , 10)
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
    let g:netrw_list_cmd= ""
  endif
endif
call s:NetrwInit("g:netrw_list_hide","")
" Default values - lh-lz ---------- {{{3
if !exists("g:netrw_localcmdshell")
  let g:netrw_localcmdshell= ""
endif

if !exists("g:netrw_localcopycmd")
    let g:netrw_localcopycmd = 'cp'
    let g:netrw_localcopycmdopt = ''

    if has("win32") && !g:netrw_cygwin
        let g:netrw_localcopycmd   = expand("$COMSPEC", v:true)
        let g:netrw_localcopycmdopt = '/c copy'
    endif
endif

if !exists("g:netrw_localcopydircmd")
    let g:netrw_localcopydircmd = 'cp'
    let g:netrw_localcopydircmdopt = '-R'

    if has("win32") && !g:netrw_cygwin
        let g:netrw_localcopydircmd   = "cp"
        call s:NetrwInit("g:netrw_localcopydircmdopt", "-R")
    endif
endif

if has("win32")
  if g:netrw_cygwin
    call s:NetrwInit("g:netrw_localmkdir","mkdir")
  else
    call s:NetrwInit("g:netrw_localmkdir",expand("$COMSPEC", v:true))
    call s:NetrwInit("g:netrw_localmkdiropt"," /c mkdir")
  endif
else
  call s:NetrwInit("g:netrw_localmkdir","mkdir")
endif
call s:NetrwInit("g:netrw_remote_mkdir","mkdir")

if !exists("g:netrw_localmovecmd")
  if has("win32")
    if g:netrw_cygwin
      let g:netrw_localmovecmd= "mv"
    else
      let g:netrw_localmovecmd   = expand("$COMSPEC", v:true)
      call s:NetrwInit("g:netrw_localmovecmdopt"," /c move")
    endif
  elseif has("unix") || has("macunix")
    let g:netrw_localmovecmd= "mv"
  else
    let g:netrw_localmovecmd= ""
  endif
endif

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
    let g:netrw_sort_sequence = !empty(&suffixes)
                \ ? printf('[\/]$,*,\%(%s\)[*@]\=$', &suffixes->split(',')->map('escape(v:val, ".*$~")')->join('\|'))
                \ : '[\/]$,*'
endif
call s:NetrwInit("g:netrw_special_syntax"   , 0)
call s:NetrwInit("g:netrw_ssh_browse_reject", '^total\s\+\d\+$')
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
call s:NetrwInit("s:netrw_posn", {})

" BufEnter event ignored by decho when following variable is true
"  Has a side effect that doau BufReadPost doesn't work, so
"  files read by network transfer aren't appropriately highlighted.

"  Netrw Initialization: {{{1

au WinEnter * if &ft == "netrw" | call s:NetrwInsureWinVars() | endif

if g:netrw_keepj =~# "keepj"
  com! -nargs=*  NetrwKeepj      keepj <args>
else
  let g:netrw_keepj= ""
  com! -nargs=*  NetrwKeepj      <args>
endif

"  Netrw Utility Functions: {{{1
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
function netrw#Explore(indx,dosplit,style,...)
  if !exists("b:netrw_curdir")
    let b:netrw_curdir= getcwd()
  endif

  " record current file for Rexplore's benefit
  if &ft != "netrw"
    let w:netrw_rexfile= expand("%:p")
  endif

  " record current directory
  let curdir     = simplify(b:netrw_curdir)
  if !exists("g:netrw_cygwin") && has("win32")
    let curdir= substitute(curdir,'\','/','g')
  endif
  let curfiledir = substitute(expand("%:p"),'^\(.*[/\\]\)[^/\\]*$','\1','e')
  if &buftype == "terminal"
      let curfiledir = curdir
  endif

  " using completion, directories with spaces in their names (thanks, Bill Gates, for a truly dumb idea)
  " will end up with backslashes here.  Solution: strip off backslashes that precede white space and
  " try Explore again.
  if a:0 > 0
    if a:1 =~ "\\\s" && !filereadable(s:NetrwFile(a:1)) && !isdirectory(s:NetrwFile(a:1))
      let a1 = substitute(a:1, '\\\(\s\)', '\1', 'g')
      if a1 != a:1
        call netrw#Explore(a:indx, a:dosplit, a:style, a1)
        return
      endif
    endif
  endif

  " save registers
  if !has('nvim') && has("clipboard") && g:netrw_clipboard
    sil! let keepregstar = @*
    sil! let keepregplus = @+
  endif
  sil! let keepregslash= @/

  " if   dosplit
  " -or- buffer is not a terminal AND file has been modified AND file not hidden when abandoned
  " -or- Texplore used
  if a:dosplit || (&buftype != "terminal" && &modified && &hidden == 0 && &bufhidden != "hide") || a:style == 6
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
    if a:1 =~ '^\~' && (has("unix") || (exists("g:netrw_cygwin") && g:netrw_cygwin))
      let dirname= simplify(substitute(a:1,'\~',expand("$HOME"),''))
    elseif a:1 == '.'
      let dirname= simplify(exists("b:netrw_curdir")? b:netrw_curdir : getcwd())
      if dirname !~ '/$'
        let dirname= dirname."/"
      endif
    elseif a:1 =~ '\$'
      let dirname= simplify(expand(a:1))
    elseif a:1 !~ '^\*\{1,2}/' && a:1 !~ '^\a\{3,}://'
      let dirname= simplify(a:1)
    else
      let dirname= a:1
    endif
  else
    " clear explore
    call s:NetrwClearExplore()
    return
  endif

  if dirname =~ '\.\./\=$'
    let dirname= simplify(fnamemodify(dirname,':p:h'))
  elseif dirname =~ '\.\.' || dirname == '.'
    let dirname= simplify(fnamemodify(dirname,':p'))
  endif

  if dirname =~ '^\*//'
    " starpat=1: Explore *//pattern   (current directory only search for files containing pattern)
    let pattern= substitute(dirname,'^\*//\(.*\)$','\1','')
    let starpat= 1
    if &hls | let keepregslash= s:ExplorePatHls(pattern) | endif

  elseif dirname =~ '^\*\*//'
    " starpat=2: Explore **//pattern  (recursive descent search for files containing pattern)
    let pattern= substitute(dirname,'^\*\*//','','')
    let starpat= 2

  elseif dirname =~ '/\*\*/'
    " handle .../**/.../filepat
    let prefixdir= substitute(dirname,'^\(.\{-}\)\*\*.*$','\1','')
    if prefixdir =~ '^/' || (prefixdir =~ '^\a:/' && has("win32"))
      let b:netrw_curdir = prefixdir
    else
      let b:netrw_curdir= getcwd().'/'.prefixdir
    endif
    let dirname= substitute(dirname,'^.\{-}\(\*\*/.*\)$','\1','')
    let starpat= 4

  elseif dirname =~ '^\*/'
    " case starpat=3: Explore */filepat   (search in current directory for filenames matching filepat)
    let starpat= 3

  elseif dirname=~ '^\*\*/'
    " starpat=4: Explore **/filepat  (recursive descent search for filenames matching filepat)
    let starpat= 4

  else
    let starpat= 0
  endif

  if starpat == 0 && a:indx >= 0
    " [Explore Hexplore Vexplore Sexplore] [dirname]
    if dirname == ""
      let dirname= curfiledir
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
      call netrw#LocalBrowseCheck(dirname)
    endif
    if exists("w:netrw_bannercnt")
      " done to handle P08-Ingelrest. :Explore will _Always_ go to the line just after the banner.
      " If one wants to return the same place in the netrw window, use :Rex instead.
      exe w:netrw_bannercnt
    endif


  " starpat=1: Explore *//pattern  (current directory only search for files containing pattern)
  " starpat=2: Explore **//pattern (recursive descent search for files containing pattern)
  " starpat=3: Explore */filepat   (search in current directory for filenames matching filepat)
  " starpat=4: Explore **/filepat  (recursive descent search for filenames matching filepat)
  elseif a:indx <= 0
    " Nexplore, Pexplore, Explore: handle starpat
    if !mapcheck("<s-up>","n") && !mapcheck("<s-down>","n") && exists("b:netrw_curdir")
      let s:didstarstar= 1
      nnoremap <buffer> <silent> <s-up>   :Pexplore<cr>
      nnoremap <buffer> <silent> <s-down> :Nexplore<cr>
    endif

    if has("path_extra")
      if !exists("w:netrw_explore_indx")
        let w:netrw_explore_indx= 0
      endif

      let indx = a:indx

      if indx == -1
        " Nexplore
        if !exists("w:netrw_explore_list") " sanity check
          call netrw#msg#Notify('WARNING', 'using Nexplore or <s-down> improperly; see help for netrw-starstar')
          if !has('nvim') && has("clipboard") && g:netrw_clipboard
            if @* != keepregstar | sil! let @* = keepregstar | endif
            if @+ != keepregplus | sil! let @+ = keepregplus | endif
          endif
          sil! let @/ = keepregslash
          return
        endif
        let indx= w:netrw_explore_indx
        if indx < 0                        | let indx= 0                           | endif
        if indx >= w:netrw_explore_listlen | let indx= w:netrw_explore_listlen - 1 | endif
        let curfile= w:netrw_explore_list[indx]
        while indx < w:netrw_explore_listlen && curfile == w:netrw_explore_list[indx]
          let indx= indx + 1
        endwhile
        if indx >= w:netrw_explore_listlen | let indx= w:netrw_explore_listlen - 1 | endif

      elseif indx == -2
        " Pexplore
        if !exists("w:netrw_explore_list") " sanity check
          call netrw#msg#Notify('WARNING', 'using Pexplore or <s-up> improperly; see help for netrw-starstar')
          if !has('nvim') && has("clipboard") && g:netrw_clipboard
            if @* != keepregstar | sil! let @* = keepregstar | endif
            if @+ != keepregplus | sil! let @+ = keepregplus | endif
          endif
          sil! let @/ = keepregslash
          return
        endif
        let indx= w:netrw_explore_indx
        if indx < 0                        | let indx= 0                           | endif
        if indx >= w:netrw_explore_listlen | let indx= w:netrw_explore_listlen - 1 | endif
        let curfile= w:netrw_explore_list[indx]
        while indx >= 0 && curfile == w:netrw_explore_list[indx]
          let indx= indx - 1
        endwhile
        if indx < 0                        | let indx= 0                           | endif

      else
        " Explore -- initialize
        " build list of files to Explore with Nexplore/Pexplore
        NetrwKeepj keepalt call s:NetrwClearExplore()
        let w:netrw_explore_indx= 0
        if !exists("b:netrw_curdir")
          let b:netrw_curdir= getcwd()
        endif

        " switch on starpat to build the w:netrw_explore_list of files
        if starpat == 1
          " starpat=1: Explore *//pattern  (current directory only search for files containing pattern)
          try
            exe "NetrwKeepj noautocmd vimgrep /".pattern."/gj ".fnameescape(b:netrw_curdir)."/*"
          catch /^Vim\%((\a\+)\)\=:E480/
            call netrw#msg#Notify('WARNING', printf("no match with pattern<%s>", pattern))
            return
          endtry
          let w:netrw_explore_list = s:NetrwExploreListUniq(map(getqflist(),'bufname(v:val.bufnr)'))
          if &hls | let keepregslash= s:ExplorePatHls(pattern) | endif

        elseif starpat == 2
          " starpat=2: Explore **//pattern (recursive descent search for files containing pattern)
          try
            exe "sil NetrwKeepj noautocmd keepalt vimgrep /".pattern."/gj "."**/*"
          catch /^Vim\%((\a\+)\)\=:E480/
            call netrw#msg#Notify('WARNING', printf('no files matched pattern<%s>', pattern))
            if &hls | let keepregslash= s:ExplorePatHls(pattern) | endif
            if !has('nvim') && has("clipboard") && g:netrw_clipboard
              if @* != keepregstar | sil! let @* = keepregstar | endif
              if @+ != keepregplus | sil! let @+ = keepregplus | endif
            endif
            sil! let @/ = keepregslash
            return
          endtry
          let s:netrw_curdir       = b:netrw_curdir
          let w:netrw_explore_list = getqflist()
          let w:netrw_explore_list = s:NetrwExploreListUniq(map(w:netrw_explore_list,'s:netrw_curdir."/".bufname(v:val.bufnr)'))
          if &hls | let keepregslash= s:ExplorePatHls(pattern) | endif

        elseif starpat == 3
          " starpat=3: Explore */filepat   (search in current directory for filenames matching filepat)
          let filepat= substitute(dirname,'^\*/','','')
          let filepat= substitute(filepat,'^[%#<]','\\&','')
          let w:netrw_explore_list= s:NetrwExploreListUniq(split(expand(b:netrw_curdir."/".filepat),'\n'))
          if &hls | let keepregslash= s:ExplorePatHls(filepat) | endif

        elseif starpat == 4
          " starpat=4: Explore **/filepat  (recursive descent search for filenames matching filepat)
          let w:netrw_explore_list= s:NetrwExploreListUniq(split(expand(b:netrw_curdir."/".dirname),'\n'))
          if &hls | let keepregslash= s:ExplorePatHls(dirname) | endif
        endif " switch on starpat to build w:netrw_explore_list

        let w:netrw_explore_listlen = len(w:netrw_explore_list)

        if w:netrw_explore_listlen == 0 || (w:netrw_explore_listlen == 1 && w:netrw_explore_list[0] =~ '\*\*\/')
          call netrw#msg#Notify('WARNING', 'no files matched')
          if !has('nvim') && has("clipboard") && g:netrw_clipboard
            if @* != keepregstar | sil! let @* = keepregstar | endif
            if @+ != keepregplus | sil! let @+ = keepregplus | endif
          endif
          sil! let @/ = keepregslash
          return
        endif
      endif  " if indx ... endif

      " NetrwStatusLine support - for exploring support
      let w:netrw_explore_indx= indx

      " wrap the indx around, but issue a note
      if indx >= w:netrw_explore_listlen || indx < 0
        let indx                = (indx < 0)? ( w:netrw_explore_listlen - 1 ) : 0
        let w:netrw_explore_indx= indx
        call netrw#msg#Notify('NOTE', 'no more files match Explore pattern')
      endif

      exe "let dirfile= w:netrw_explore_list[".indx."]"
      let newdir= substitute(dirfile,'/[^/]*$','','e')

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

    else
      call netrw#msg#Notify('WARNING', 'your vim needs the +path_extra feature for Exploring with **!')
      if !has('nvim') && has("clipboard") && g:netrw_clipboard
        if @* != keepregstar | sil! let @* = keepregstar | endif
        if @+ != keepregplus | sil! let @+ = keepregplus | endif
      endif
      sil! let @/ = keepregslash
      return
    endif

  else
    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && dirname =~ '/'
      sil! unlet w:netrw_treedict
      sil! unlet w:netrw_treetop
    endif
    let newdir= dirname
    if !exists("b:netrw_curdir")
      NetrwKeepj call netrw#LocalBrowseCheck(getcwd())
    else
      NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,newdir,0))
    endif
  endif

  " visual display of **/ **// */ Exploration files
  if exists("w:netrw_explore_indx") && exists("b:netrw_curdir")
    if !exists("s:explore_prvdir") || s:explore_prvdir != b:netrw_curdir
      " only update match list when current directory isn't the same as before
      let s:explore_prvdir = b:netrw_curdir
      let s:explore_match  = ""
      let dirlen           = strlen(b:netrw_curdir)
      if b:netrw_curdir !~ '/$'
        let dirlen= dirlen + 1
      endif
      let prvfname= ""
      for fname in w:netrw_explore_list
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
      if has("syntax") && exists("g:syntax_on") && g:syntax_on
        exe "2match netrwMarkFile /".s:explore_match."/"
      endif
    endif
    echo "<s-up>==Pexplore  <s-down>==Nexplore"
  else
    2match none
    if exists("s:explore_match")  | unlet s:explore_match  | endif
    if exists("s:explore_prvdir") | unlet s:explore_prvdir | endif
  endif

  " since Explore may be used to initialize netrw's browser,
  " there's no danger of a late FocusGained event on initialization.
  " Consequently, set s:netrw_events to 2.
  let s:netrw_events= 2
  if !has('nvim') && has("clipboard") && g:netrw_clipboard
    if @* != keepregstar | sil! let @* = keepregstar | endif
    if @+ != keepregplus | sil! let @+ = keepregplus | endif
  endif
  sil! let @/ = keepregslash
endfunction

" netrw#Lexplore: toggle Explorer window, keeping it on the left of the current tab {{{2
"   Uses  g:netrw_chgwin  : specifies the window where Lexplore files are to be opened
"         t:netrw_lexposn : winsaveview() output (used on Lexplore window)
"         t:netrw_lexbufnr: the buffer number of the Lexplore buffer  (internal to this function)
"         s:lexplore_win  : window number of Lexplore window (serves to indicate which window is a Lexplore window)
"         w:lexplore_buf  : buffer number of Lexplore window (serves to indicate which window is a Lexplore window)
function netrw#Lexplore(count,rightside,...)
  let curwin= winnr()

  if a:0 > 0 && a:1 != ""
    " if a netrw window is already on the left-side of the tab
    " and a directory has been specified, explore with that
    " directory.
    let a1 = expand(a:1)
    exe "1wincmd w"
    if &ft == "netrw"
      exe "Explore ".fnameescape(a1)
      exe curwin."wincmd w"
      let s:lexplore_win= curwin
      let w:lexplore_buf= bufnr("%")
      if exists("t:netrw_lexposn")
        unlet t:netrw_lexposn
      endif
      return
    endif
    exe curwin."wincmd w"
  else
    let a1= ""
  endif

  if exists("t:netrw_lexbufnr")
    " check if t:netrw_lexbufnr refers to a netrw window
    let lexwinnr = bufwinnr(t:netrw_lexbufnr)
  else
    let lexwinnr= 0
  endif

  if lexwinnr > 0
    " close down netrw explorer window
    exe lexwinnr."wincmd w"
    let g:netrw_winsize = -winwidth(0)
    let t:netrw_lexposn = winsaveview()
    close
    if lexwinnr < curwin
      let curwin= curwin - 1
    endif
    if lexwinnr != curwin
      exe curwin."wincmd w"
    endif
    unlet t:netrw_lexbufnr

  else
    " open netrw explorer window
    exe "1wincmd w"
    let keep_altv    = g:netrw_altv
    let g:netrw_altv = 0
    if a:count != 0
      let netrw_winsize   = g:netrw_winsize
      let g:netrw_winsize = a:count
    endif
    let curfile= expand("%")
    exe (a:rightside? "botright" : "topleft")." vertical ".((g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize) . " new"
    if a:0 > 0 && a1 != ""
      call netrw#Explore(0,0,0,a1)
      exe "Explore ".fnameescape(a1)
    elseif curfile =~ '^\a\{3,}://'
      call netrw#Explore(0,0,0,substitute(curfile,'[^/\\]*$','',''))
    else
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
    if exists("t:netrw_lexposn")
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
  endif

endfunction

" netrw#MakeTgt: make a target out of the directory name provided {{{2
function netrw#MakeTgt(dname)
  " simplify the target (eg. /abc/def/../ghi -> /abc/ghi)
  let svpos               = winsaveview()
  let s:netrwmftgt_islocal= (a:dname !~ '^\a\{3,}://')
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
  call winrestview(svpos)
endfunction

" netrw#Obtain: {{{2
"   netrw#Obtain(islocal,fname[,tgtdirectory])
"     islocal=0  obtain from remote source
"            =1  obtain from local source
"     fname  :   a filename or a list of filenames
"     tgtdir :   optional place where files are to go  (not present, uses getcwd())
function netrw#Obtain(islocal,fname,...)
  " NetrwStatusLine support - for obtaining support

  if type(a:fname) == 1
    let fnamelist= [ a:fname ]
  elseif type(a:fname) == 3
    let fnamelist= a:fname
  else
    call netrw#msg#Notify('ERROR', 'attempting to use NetrwObtain on something not a filename or a list')
    return
  endif
  if a:0 > 0
    let tgtdir= a:1
  else
    let tgtdir= getcwd()
  endif

  if exists("b:netrw_islocal") && b:netrw_islocal
    " obtain a file from local b:netrw_curdir to (local) tgtdir
    if exists("b:netrw_curdir") && getcwd() != b:netrw_curdir
      let topath = netrw#fs#ComposePath(tgtdir,"")
      if has("win32")
        " transfer files one at time
        for fname in fnamelist
          call system(g:netrw_localcopycmd.g:netrw_localcopycmdopt." ".netrw#os#Escape(fname)." ".netrw#os#Escape(topath))
          if v:shell_error != 0
            call netrw#msg#Notify('WARNING', printf('consider setting g:netrw_localcopycmd<%s> to something that works', g:netrw_localcopycmd))
            return
          endif
        endfor
      else
        " transfer files with one command
        let filelist= join(map(deepcopy(fnamelist),"netrw#os#Escape(v:val)"))
        call system(g:netrw_localcopycmd.g:netrw_localcopycmdopt." ".filelist." ".netrw#os#Escape(topath))
        if v:shell_error != 0
          call netrw#msg#Notify('WARNING', printf('consider setting g:netrw_localcopycmd<%s> to something that works', g:netrw_localcopycmd))
          return
        endif
      endif
    elseif !exists("b:netrw_curdir")
      call netrw#msg#Notify('ERROR', "local browsing directory doesn't exist!")
    else
      call netrw#msg#Notify('WARNING', 'local browsing directory and current directory are identical')
    endif

  else
    " obtain files from remote b:netrw_curdir to local tgtdir
    if type(a:fname) == 1
      call s:SetupNetrwStatusLine('%f %h%m%r%=%9*Obtaining '.a:fname)
    endif
    call s:NetrwMethod(b:netrw_curdir)
    if !s:NetrwValidateHostname(g:netrw_machine)
        call netrw#msg#Notify('ERROR', 'Rejecting invalid hostname: <%s>', g:netrw_machine)
        return
    endif

    if b:netrw_method == 4
      " obtain file using scp
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
      let filelist= join(map(deepcopy(fnamelist),'escape(netrw#os#Escape(g:netrw_machine.":".path.v:val,1)," ")'))
      call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_scp_cmd.netrw#os#Escape(useport,1)." ".filelist." ".netrw#os#Escape(tgtdir,1))

    elseif b:netrw_method == 2
      " obtain file using ftp + .netrc
      call s:SaveBufVars()|sil NetrwKeepj new|call s:RestoreBufVars()
      let tmpbufnr= bufnr("%")
      setl ff=unix
      if exists("g:netrw_ftpmode") && g:netrw_ftpmode != ""
        NetrwKeepj put =g:netrw_ftpmode
      endif

      if exists("b:netrw_fname") && b:netrw_fname != ""
        call setline(line("$")+1,'cd "'.b:netrw_fname.'"')
      endif

      if exists("g:netrw_ftpextracmd")
        NetrwKeepj put =g:netrw_ftpextracmd
      endif
      for fname in fnamelist
        call setline(line("$")+1,'get "'.fname.'"')
      endfor
      if exists("g:netrw_port") && g:netrw_port != ""
        call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1)." ".netrw#os#Escape(g:netrw_port,1))
      else
        call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1))
      endif
      " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
      if getline(1) !~ "^$" && getline(1) !~ '^Trying '
        let debugkeep= &debug
        setl debug=msg
        call netrw#msg#Notify('ERROR', getline(1))
        let &debug= debugkeep
      endif

    elseif b:netrw_method == 3
      " obtain with ftp + machine, id, passwd, and fname (ie. no .netrc)
      call s:SaveBufVars()|sil NetrwKeepj new|call s:RestoreBufVars()
      let tmpbufnr= bufnr("%")
      setl ff=unix

      if exists("g:netrw_port") && g:netrw_port != ""
        NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
      else
        NetrwKeepj put ='open '.g:netrw_machine
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

      if exists("g:netrw_ftpmode") && g:netrw_ftpmode != ""
        NetrwKeepj put =g:netrw_ftpmode
      endif

      if exists("b:netrw_fname") && b:netrw_fname != ""
        NetrwKeepj call setline(line("$")+1,'cd "'.b:netrw_fname.'"')
      endif

      if exists("g:netrw_ftpextracmd")
        NetrwKeepj put =g:netrw_ftpextracmd
      endif

      if exists("g:netrw_ftpextracmd")
        NetrwKeepj put =g:netrw_ftpextracmd
      endif
      for fname in fnamelist
        NetrwKeepj call setline(line("$")+1,'get "'.fname.'"')
      endfor

      " perform ftp:
      " -i       : turns off interactive prompting from ftp
      " -n  unix : DON'T use <.netrc>, even though it exists
      " -n  win32: quit being obnoxious about password
      "  Note: using "_dd to delete to the black hole register; avoids messing up @@
      NetrwKeepj norm! 1G"_dd
      call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
      " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
      if getline(1) !~ "^$"
          call netrw#msg#Notify('ERROR', getline(1))
      endif

    elseif b:netrw_method == 9
      " obtain file using sftp
      if a:fname =~ '/'
        let localfile= substitute(a:fname,'^.*/','','')
      else
        let localfile= a:fname
      endif
      call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_sftp_cmd." ".netrw#os#Escape(g:netrw_machine.":".b:netrw_fname,1).netrw#os#Escape(localfile)." ".netrw#os#Escape(tgtdir))

    elseif !exists("b:netrw_method") || b:netrw_method < 0
      " probably a badly formed url; protocol not recognized
      return

    else
      " protocol recognized but not supported for Obtain (yet?)
        call netrw#msg#Notify('ERROR', 'current protocol not supported for obtaining file')
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

endfunction

" netrw#Nread: save position, call netrw#NetRead(), and restore position {{{2
function netrw#Nread(mode,fname)
  let svpos= winsaveview()
  call netrw#NetRead(a:mode,a:fname)
  call winrestview(svpos)

  if exists("w:netrw_liststyle") && w:netrw_liststyle != s:TREELIST
    if exists("w:netrw_bannercnt")
      " start with cursor just after the banner
      exe w:netrw_bannercnt
    endif
  endif
endfunction

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
function s:NetrwOptionsSave(vt)

  if !exists("{a:vt}netrw_optionsave")
    let {a:vt}netrw_optionsave= 1
  else
    return
  endif

  " Save current settings and current directory
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
  if g:netrw_keepdir
    let {a:vt}netrw_dirkeep  = getcwd()
  endif
  if !has('nvim') && has("clipboard") && g:netrw_clipboard
    sil! let {a:vt}netrw_starkeep = @*
    sil! let {a:vt}netrw_pluskeep = @+
  endif
  sil! let {a:vt}netrw_slashkeep= @/

endfunction

" s:NetrwOptionsSafe: sets options to help netrw do its job {{{2
"                     Use  s:NetrwSaveOptions() to save user settings
"                     Use  s:NetrwOptionsRestore() to restore user settings
function s:NetrwOptionsSafe(islocal)
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
  if &ft == "netrw"
    keepalt NetrwKeepj doau FileType netrw
  endif

endfunction

" s:NetrwOptionsRestore: restore options (based on prior s:NetrwOptionsSave) {{{2
function s:NetrwOptionsRestore(vt)
  if !exists("{a:vt}netrw_optionsave")
    " filereadable() returns zero for remote files (e.g. scp://user@localhost//etc/fstab)
    " Note: @ may not be in 'isfname', so '^\w\+://\f\+/' may not match
    if filereadable(expand("%")) || expand("%") =~# '^\w\+://\f\+'
      filetype detect
    else
      setl ft=netrw
    endif
    return
  endif
  unlet {a:vt}netrw_optionsave

  if exists("+acd")
    if exists("{a:vt}netrw_acdkeep")
      let curdir = getcwd()
      let &l:acd = {a:vt}netrw_acdkeep
      unlet {a:vt}netrw_acdkeep
      if &l:acd
        call s:NetrwLcd(curdir)
      endif
    endif
  endif
  call s:NetrwRestoreSetting(a:vt."netrw_aikeep","&l:ai")
  call s:NetrwRestoreSetting(a:vt."netrw_awkeep","&l:aw")
  call s:NetrwRestoreSetting(a:vt."netrw_blkeep","&l:bl")
  call s:NetrwRestoreSetting(a:vt."netrw_btkeep","&l:bt")
  call s:NetrwRestoreSetting(a:vt."netrw_bombkeep","&l:bomb")
  call s:NetrwRestoreSetting(a:vt."netrw_cedit","&cedit")
  call s:NetrwRestoreSetting(a:vt."netrw_cikeep","&l:ci")
  call s:NetrwRestoreSetting(a:vt."netrw_cinkeep","&l:cin")
  call s:NetrwRestoreSetting(a:vt."netrw_cinokeep","&l:cino")
  call s:NetrwRestoreSetting(a:vt."netrw_comkeep","&l:com")
  call s:NetrwRestoreSetting(a:vt."netrw_cpokeep","&l:cpo")
  call s:NetrwRestoreSetting(a:vt."netrw_diffkeep","&l:diff")
  call s:NetrwRestoreSetting(a:vt."netrw_fenkeep","&l:fen")
  if exists("g:netrw_ffkeep") && g:netrw_ffkeep
    call s:NetrwRestoreSetting(a:vt."netrw_ffkeep")","&l:ff")
  endif
  call s:NetrwRestoreSetting(a:vt."netrw_fokeep"   ,"&l:fo")
  call s:NetrwRestoreSetting(a:vt."netrw_gdkeep"   ,"&l:gd")
  call s:NetrwRestoreSetting(a:vt."netrw_gokeep"   ,"&go")
  call s:NetrwRestoreSetting(a:vt."netrw_hidkeep"  ,"&l:hidden")
  call s:NetrwRestoreSetting(a:vt."netrw_imkeep"   ,"&l:im")
  call s:NetrwRestoreSetting(a:vt."netrw_iskkeep"  ,"&l:isk")
  call s:NetrwRestoreSetting(a:vt."netrw_lines"    ,"&lines")
  call s:NetrwRestoreSetting(a:vt."netrw_lskeep"   ,"&l:ls")
  call s:NetrwRestoreSetting(a:vt."netrw_makeep"   ,"&l:ma")
  call s:NetrwRestoreSetting(a:vt."netrw_magickeep","&l:magic")
  call s:NetrwRestoreSetting(a:vt."netrw_modkeep"  ,"&l:mod")
  call s:NetrwRestoreSetting(a:vt."netrw_nukeep"   ,"&l:nu")
  call s:NetrwRestoreSetting(a:vt."netrw_rnukeep"  ,"&l:rnu")
  call s:NetrwRestoreSetting(a:vt."netrw_repkeep"  ,"&l:report")
  call s:NetrwRestoreSetting(a:vt."netrw_rokeep"   ,"&l:ro")
  call s:NetrwRestoreSetting(a:vt."netrw_selkeep"  ,"&l:sel")
  call s:NetrwRestoreSetting(a:vt."netrw_spellkeep","&l:spell")
  call s:NetrwRestoreSetting(a:vt."netrw_twkeep"   ,"&l:tw")
  call s:NetrwRestoreSetting(a:vt."netrw_wigkeep"  ,"&l:wig")
  call s:NetrwRestoreSetting(a:vt."netrw_wrapkeep" ,"&l:wrap")
  call s:NetrwRestoreSetting(a:vt."netrw_writekeep","&l:write")
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
  if !has('nvim') && has("clipboard") && g:netrw_clipboard
    call s:NetrwRestoreSetting(a:vt."netrw_starkeep","@*")
    call s:NetrwRestoreSetting(a:vt."netrw_pluskeep","@+")
  endif
  call s:NetrwRestoreSetting(a:vt."netrw_slashkeep","@/")

  " Moved the filetype detect here from NetrwGetFile() because remote files
  " were having their filetype detect-generated settings overwritten by
  " NetrwOptionRestore.
  if &ft != "netrw"
    filetype detect
  endif
endfunction

" s:NetrwSetSafeSetting: sets an option to a safe setting {{{2
"                        but only when the options' value and the safe setting differ
"                        Doing this means that netrw will not come up as having changed a
"                        setting last when it really didn't actually change it.
"
"                        Called from s:NetrwOptionsSafe
"                          ex. call s:NetrwSetSafeSetting("&l:sel","inclusive")
function s:NetrwSetSafeSetting(setting,safesetting)

  if a:setting =~ '^&'
    exe "let settingval= ".a:setting

    if settingval != a:safesetting
      if type(a:safesetting) == 0
        exe "let ".a:setting."=".a:safesetting
      elseif type(a:safesetting) == 1
        exe "let ".a:setting."= '".a:safesetting."'"
      else
        call netrw#msg#Notify('ERROR', printf("(s:NetrwRestoreSetting) doesn't know how to restore %s with a safesetting of type#%s", a:setting, type(a:safesetting)))
      endif
    endif
  endif

endfunction

" s:NetrwRestoreSetting: restores specified setting using associated keepvar, {{{2
"                        but only if the setting value differs from the associated keepvar.
"                        Doing this means that netrw will not come up as having changed a
"                        setting last when it really didn't actually change it.
"
"                        Used by s:NetrwOptionsRestore() to restore each netrw-sensitive setting
"                        keepvars are set up by s:NetrwOptionsSave
function s:NetrwRestoreSetting(keepvar,setting)

  " typically called from s:NetrwOptionsRestore
  "   call s:NetrwRestoreSettings(keep-option-variable-name,'associated-option')
  "   ex. call s:NetrwRestoreSetting(a:vt."netrw_selkeep","&l:sel")
  "  Restores option (but only if different) from a:keepvar
  if exists(a:keepvar)
    exe "let keepvarval= ".a:keepvar
    exe "let setting= ".a:setting


    if setting != keepvarval
      if type(a:setting) == 0
        exe "let ".a:setting."= ".keepvarval
      elseif type(a:setting) == 1
        exe "let ".a:setting."= '".substitute(keepvarval,"'","''","g")."'"
      else
        call netrw#msg#Notify('ERROR', printf("(s:NetrwRestoreSetting) doesn't know how to restore %s with a setting of type#%s", a:keepvar, type(a:setting)))
      endif
    endif

    exe "unlet ".a:keepvar
  endif

endfunction

" NetrwStatusLine: {{{2

function NetrwStatusLine()
    if !exists("w:netrw_explore_bufnr") || w:netrw_explore_bufnr != bufnr("%") || !exists("w:netrw_explore_line") || w:netrw_explore_line != line(".") || !exists("w:netrw_explore_list")
        let &stl= s:netrw_explore_stl
        unlet! w:netrw_explore_bufnr w:netrw_explore_line
        return ""
    else
        return "Match ".w:netrw_explore_mtchcnt." of ".w:netrw_explore_listlen
    endif
endfunction

"  Netrw Transfer Functions: {{{1

" netrw#NetRead: responsible for reading a file over the net {{{2
"   mode: =0 read remote file and insert before current line
"         =1 read remote file and insert after current line
"         =2 replace with remote file
"         =3 obtain file, but leave in temporary format
function netrw#NetRead(mode,...)

    " NetRead: save options {{{3
    call s:NetrwOptionsSave("w:")
    call s:NetrwOptionsSafe(0)
    call s:RestoreCursorline()
    " NetrwSafeOptions sets a buffer up for a netrw listing, which includes buflisting off.
    " However, this setting is not wanted for a remote editing session.  The buffer should be "nofile", still.
    setl bl

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

    " NetRead: get temporary filename {{{3
    let tmpfile= s:GetTempfile("")
    if tmpfile == ""
        return
    endif

    while ichoice <= a:0

        " attempt to repeat with previous host-file-etc
        if exists("b:netrw_lastfile") && a:0 == 0
            let choice = b:netrw_lastfile
            let ichoice= ichoice + 1

        else
            exe "let choice= a:" . ichoice

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
                echomsg ':Nread file:///path                         uses elinks'
                echomsg ':Nread https://[user@]machine/path          uses http  wget'
                echomsg ':Nread rcp://[user@]machine/path            uses rcp'
                echomsg ':Nread rsync://machine[:port]/path          uses rsync'
                echomsg ':Nread scp://[user@]machine[[:#]port]/path  uses scp'
                echomsg ':Nread sftp://[user@]machine[[:#]port]/path uses sftp'
                sleep 4
                break

            elseif match(choice,'^"') != -1
                " Reconstruct Choice if choice starts with '"'
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
                            call netrw#msg#Notify('ERROR', printf('Unbalanced string in filename "%s"', wholechoice))
                            return
                        endif
                        let choice= a:{ichoice}
                    endwhile
                    let choice= strpart(wholechoice,1,strlen(wholechoice)-1) . " " . strpart(choice,0,strlen(choice)-1)
                endif
            endif
        endif

        let ichoice= ichoice + 1

        " NetRead: Determine method of read (ftp, rcp, etc) {{{3
        call s:NetrwMethod(choice)
        if !exists("b:netrw_method") || b:netrw_method < 0
            return
        endif
        if !s:NetrwValidateHostname(g:netrw_machine)
            call netrw#msg#Notify('ERROR', printf('Rejecting invalid hostname: <%s>', g:netrw_machine))
            return
        endif
        let tmpfile= s:GetTempfile(b:netrw_fname) " apply correct suffix

        " Check whether or not NetrwBrowse() should be handling this request
        if choice =~ "^.*[\/]$" && b:netrw_method != 5 && choice !~ '^https\=://'
            NetrwKeepj call s:NetrwBrowse(0,choice)
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
            " ER: nothing done with g:netrw_uid yet?
            " ER: on Win2K" rcp machine[.user]:file tmpfile
            " ER: when machine contains '.' adding .user is required (use $USERNAME)
            " ER: the tmpfile is full path: rcp sees C:\... as host C
            if s:netrw_has_nt_rcp == 1
                if exists("g:netrw_uid") && ( g:netrw_uid != "" )
                    let uid_machine = g:netrw_machine .'.'. g:netrw_uid
                else
                    " Any way needed it machine contains a '.'
                    let uid_machine = g:netrw_machine .'.'. $USERNAME
                endif
            else
                if exists("g:netrw_uid") && ( g:netrw_uid != "" )
                    let uid_machine = g:netrw_uid .'@'. g:netrw_machine
                else
                    let uid_machine = g:netrw_machine
                endif
            endif
            call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_rcp_cmd." ".s:netrw_rcpmode." ".netrw#os#Escape(uid_machine.":".b:netrw_fname,1)." ".netrw#os#Escape(tmpfile,1))
            let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
            let b:netrw_lastfile = choice

            ".........................................
        " NetRead: (ftp + <.netrc>)  NetRead Method #2 {{{3
        elseif b:netrw_method  == 2          " read with ftp + <.netrc>
            let netrw_fname= b:netrw_fname
            NetrwKeepj call s:SaveBufVars()|new|NetrwKeepj call s:RestoreBufVars()
            let filtbuf= bufnr("%")
            setl ff=unix
            NetrwKeepj put =g:netrw_ftpmode
            if exists("g:netrw_ftpextracmd")
                NetrwKeepj put =g:netrw_ftpextracmd
            endif
            call setline(line("$")+1,'get "'.netrw_fname.'" '.tmpfile)
            if exists("g:netrw_port") && g:netrw_port != ""
                call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1)." ".netrw#os#Escape(g:netrw_port,1))
            else
                call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1))
            endif
            " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
            if getline(1) !~ "^$" && getline(1) !~ '^Trying '
                let debugkeep = &debug
                setl debug=msg
                call netrw#msg#Notify('ERROR', getline(1))
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
        elseif b:netrw_method == 3           " read with ftp + machine, id, passwd, and fname
            " Construct execution string (four lines) which will be passed through filter
            let netrw_fname= escape(b:netrw_fname,g:netrw_fname_escape)
            NetrwKeepj call s:SaveBufVars()|new|NetrwKeepj call s:RestoreBufVars()
            let filtbuf= bufnr("%")
            setl ff=unix
            if exists("g:netrw_port") && g:netrw_port != ""
                NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
            else
                NetrwKeepj put ='open '.g:netrw_machine
            endif

            if exists("g:netrw_uid") && g:netrw_uid != ""
                if exists("g:netrw_ftp") && g:netrw_ftp == 1
                    NetrwKeepj put =g:netrw_uid
                    if exists("s:netrw_passwd")
                        NetrwKeepj put ='\"'.s:netrw_passwd.'\"'
                    endif
                elseif exists("s:netrw_passwd")
                    NetrwKeepj put ='user \"'.g:netrw_uid.'\" \"'.s:netrw_passwd.'\"'
                endif
            endif

            if exists("g:netrw_ftpmode") && g:netrw_ftpmode != ""
                NetrwKeepj put =g:netrw_ftpmode
            endif
            if exists("g:netrw_ftpextracmd")
                NetrwKeepj put =g:netrw_ftpextracmd
            endif
            NetrwKeepj put ='get \"'.netrw_fname.'\" '.tmpfile

            " perform ftp:
            " -i       : turns off interactive prompting from ftp
            " -n  unix : DON'T use <.netrc>, even though it exists
            " -n  win32: quit being obnoxious about password
            NetrwKeepj norm! 1G"_dd
            call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
            " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
            if getline(1) !~ "^$"
                call netrw#msg#Notify('ERROR', getline(1))
            endif
            call s:SaveBufVars()|keepj bd!|call s:RestoreBufVars()
            let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
            let b:netrw_lastfile = choice

            ".........................................
        " NetRead: (scp) NetRead Method #4 {{{3
        elseif     b:netrw_method  == 4      " read with scp
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
            call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_scp_cmd.useport." ".escape(netrw#os#Escape(g:netrw_machine.":".b:netrw_fname,1),' ')." ".netrw#os#Escape(tmpfile_get,1))
            let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
            let b:netrw_lastfile = choice

            ".........................................
        " NetRead: (http) NetRead Method #5 (wget) {{{3
        elseif     b:netrw_method  == 5
            if g:netrw_http_cmd == ""
                call netrw#msg#Notify('ERROR', 'neither the wget nor the fetch command is available')
                return
            endif

            if match(b:netrw_fname,"#") == -1 || exists("g:netrw_http_xcmd")
                " using g:netrw_http_cmd (usually elinks, links, curl, wget, or fetch)
                if exists("g:netrw_http_xcmd")
                    call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_http_cmd." ".netrw#os#Escape(b:netrw_http."://".g:netrw_machine.b:netrw_fname,1)." ".g:netrw_http_xcmd." ".netrw#os#Escape(tmpfile,1))
                else
                    call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_http_cmd." ".netrw#os#Escape(tmpfile,1)." ".netrw#os#Escape(b:netrw_http."://".g:netrw_machine.b:netrw_fname,1))
                endif
                let result = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)

            else
                " wget/curl/fetch plus a jump to an in-page marker (ie. http://abc/def.html#aMarker)
                let netrw_html= substitute(b:netrw_fname,"#.*$","","")
                let netrw_tag = substitute(b:netrw_fname,"^.*#","","")
                call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_http_cmd." ".netrw#os#Escape(tmpfile,1)." ".netrw#os#Escape(b:netrw_http."://".g:netrw_machine.netrw_html,1))
                let result = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
                exe 'NetrwKeepj norm! 1G/<\s*a\s*name=\s*"'.netrw_tag.'"/'."\<CR>"
            endif
            let b:netrw_lastfile = choice
            setl ro nomod

            ".........................................
        " NetRead: (dav) NetRead Method #6 {{{3
        elseif     b:netrw_method  == 6

            if !executable(g:netrw_dav_cmd)
                call netrw#msg#Notify('ERROR', printf('%s is not executable', g:netrw_dav_cmd))
                return
            endif
            if g:netrw_dav_cmd =~ "curl"
                call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_dav_cmd." ".netrw#os#Escape("dav://".g:netrw_machine.b:netrw_fname,1)." ".netrw#os#Escape(tmpfile,1))
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
                call netrw#os#Execute(s:netrw_silentxfer."%!".g:netrw_dav_cmd)
                keepj bd!
            endif
            let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
            let b:netrw_lastfile = choice

            ".........................................
        " NetRead: (rsync) NetRead Method #7 {{{3
        elseif     b:netrw_method  == 7
            call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_rsync_cmd." ".netrw#os#Escape(g:netrw_machine.g:netrw_rsync_sep.b:netrw_fname,1)." ".netrw#os#Escape(tmpfile,1))
            let result           = s:NetrwGetFile(readcmd,tmpfile, b:netrw_method)
            let b:netrw_lastfile = choice

            ".........................................
        " NetRead: (fetch) NetRead Method #8 {{{3
        "    fetch://[user@]host[:http]/path
        elseif     b:netrw_method  == 8
            if g:netrw_fetch_cmd == ""
                call netrw#msg#Notify('ERROR', "fetch command not available")
                return
            endif
            if exists("g:netrw_option") && g:netrw_option =~ ":https\="
                let netrw_option= "http"
            else
                let netrw_option= "ftp"
            endif

            if exists("g:netrw_uid") && g:netrw_uid != "" && exists("s:netrw_passwd") && s:netrw_passwd != ""
                call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_fetch_cmd." ".netrw#os#Escape(tmpfile,1)." ".netrw#os#Escape(netrw_option."://".g:netrw_uid.':'.s:netrw_passwd.'@'.g:netrw_machine."/".b:netrw_fname,1))
            else
                call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_fetch_cmd." ".netrw#os#Escape(tmpfile,1)." ".netrw#os#Escape(netrw_option."://".g:netrw_machine."/".b:netrw_fname,1))
            endif

            let result          = s:NetrwGetFile(readcmd,tmpfile, b:netrw_method)
            let b:netrw_lastfile = choice
            setl ro nomod

            ".........................................
        " NetRead: (sftp) NetRead Method #9 {{{3
        elseif     b:netrw_method  == 9
            call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_sftp_cmd." ".netrw#os#Escape(g:netrw_machine.":".b:netrw_fname,1)." ".tmpfile)
            let result          = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
            let b:netrw_lastfile = choice

            ".........................................
        " NetRead: (file) NetRead Method #10 {{{3
        elseif      b:netrw_method == 10 && exists("g:netrw_file_cmd")
            call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_file_cmd." ".netrw#os#Escape(b:netrw_fname,1)." ".tmpfile)
            let result           = s:NetrwGetFile(readcmd, tmpfile, b:netrw_method)
            let b:netrw_lastfile = choice

            ".........................................
        " NetRead: Complain {{{3
        else
            call netrw#msg#Notify('WARNING', printf('unable to comply with your request<%s>', choice))
        endif
    endwhile

    " NetRead: cleanup {{{3
    if exists("b:netrw_method")
        unlet b:netrw_method
        unlet b:netrw_fname
    endif
    if s:FileReadable(tmpfile) && tmpfile !~ '.tar.bz2$' && tmpfile !~ '.tar.gz$' && tmpfile !~ '.zip' && tmpfile !~ '.tar' && readcmd != 't' && tmpfile !~ '.tar.xz$' && tmpfile !~ '.txz'
        call netrw#fs#Remove(tmpfile)
    endif
    NetrwKeepj call s:NetrwOptionsRestore("w:")

endfunction

" netrw#NetWrite: responsible for writing a file over the net {{{2
function netrw#NetWrite(...) range

    " NetWrite: option handling {{{3
    let mod= 0
    call s:NetrwOptionsSave("w:")
    call s:NetrwOptionsSafe(0)

    " NetWrite: Get Temporary Filename {{{3
    let tmpfile= s:GetTempfile("")
    if tmpfile == ""
        return
    endif

    if a:0 == 0
        let ichoice = 0
    else
        let ichoice = 1
    endif

    let curbufname= expand("%")
    if &binary
        " For binary writes, always write entire file.
        " (line numbers don't really make sense for that).
        " Also supports the writing of tar and zip files.
        exe "sil NetrwKeepj w! ".fnameescape(v:cmdarg)." ".fnameescape(tmpfile)
    elseif g:netrw_cygwin
        " write (selected portion of) file to temporary
        let cygtmpfile= substitute(tmpfile,g:netrw_cygdrive.'/\(.\)','\1:','')
        exe "sil NetrwKeepj ".a:firstline."," . a:lastline . "w! ".fnameescape(v:cmdarg)." ".fnameescape(cygtmpfile)
    else
        " write (selected portion of) file to temporary
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
                            call netrw#msg#Notify('ERROR', printf('Unbalanced string in filename "%s"', wholechoice))
                            return
                        endif
                        let choice= a:{ichoice}
                    endwhile
                    let choice= strpart(wholechoice,1,strlen(wholechoice)-1) . " " . strpart(choice,0,strlen(choice)-1)
                endif
            endif
        endif
        let ichoice= ichoice + 1

        " Determine method of write (ftp, rcp, etc) {{{4
        NetrwKeepj call s:NetrwMethod(choice)
        if !exists("b:netrw_method") || b:netrw_method < 0
            return
        endif
        if !s:NetrwValidateHostname(g:netrw_machine)
            call netrw#msg#Notify('ERROR', printf('Rejecting invalid hostname: <%s>', g:netrw_machine))
            return
        endif

        " =============
        " NetWrite: Perform Protocol-Based Write {{{3
        " ============================
        if exists("g:netrw_silent") && g:netrw_silent == 0 && &ch >= 1
            echo "(netrw) Processing your write request..."
        endif

        ".........................................
        " NetWrite: (rcp) NetWrite Method #1 {{{3
        if  b:netrw_method == 1
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
            call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_rcp_cmd." ".s:netrw_rcpmode." ".netrw#os#Escape(tmpfile,1)." ".netrw#os#Escape(uid_machine.":".b:netrw_fname,1))
            let b:netrw_lastfile = choice

            ".........................................
        " NetWrite: (ftp + <.netrc>) NetWrite Method #2 {{{3
        elseif b:netrw_method == 2
            let netrw_fname = b:netrw_fname

            " formerly just a "new...bd!", that changed the window sizes when equalalways.  Using enew workaround instead
            let bhkeep      = &l:bh
            let curbuf      = bufnr("%")
            setl bh=hide
            keepj keepalt enew

            setl ff=unix
            NetrwKeepj put =g:netrw_ftpmode
            if exists("g:netrw_ftpextracmd")
                NetrwKeepj put =g:netrw_ftpextracmd
            endif
            NetrwKeepj call setline(line("$")+1,'put "'.tmpfile.'" "'.netrw_fname.'"')
            if exists("g:netrw_port") && g:netrw_port != ""
                call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1)." ".netrw#os#Escape(g:netrw_port,1))
            else
                call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1))
            endif
            " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
            if getline(1) !~ "^$"
                call netrw#msg#Notify('ERROR', getline(1))
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
            let netrw_fname = b:netrw_fname
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
            if exists("g:netrw_uid") && g:netrw_uid != ""
                if exists("g:netrw_ftp") && g:netrw_ftp == 1
                    NetrwKeepj put =g:netrw_uid
                    if exists("s:netrw_passwd") && s:netrw_passwd != ""
                        NetrwKeepj put ='\"'.s:netrw_passwd.'\"'
                    endif
                elseif exists("s:netrw_passwd") && s:netrw_passwd != ""
                    NetrwKeepj put ='user \"'.g:netrw_uid.'\" \"'.s:netrw_passwd.'\"'
                endif
            endif
            NetrwKeepj put =g:netrw_ftpmode
            if exists("g:netrw_ftpextracmd")
                NetrwKeepj put =g:netrw_ftpextracmd
            endif
            NetrwKeepj put ='put \"'.tmpfile.'\" \"'.netrw_fname.'\"'
            " save choice/id/password for future use
            let b:netrw_lastfile = choice

            " perform ftp:
            " -i       : turns off interactive prompting from ftp
            " -n  unix : DON'T use <.netrc>, even though it exists
            " -n  win32: quit being obnoxious about password
            NetrwKeepj norm! 1G"_dd
            call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
            " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
            if getline(1) !~ "^$"
                call netrw#msg#Notify('ERROR', getline(1))
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
            if exists("g:netrw_port") && g:netrw_port != ""
                let useport= " ".g:netrw_scpport." ".fnameescape(g:netrw_port)
            else
                let useport= ""
            endif
            call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_scp_cmd.useport." ".netrw#os#Escape(tmpfile,1)." ".netrw#os#Escape(g:netrw_machine.":".b:netrw_fname,1))
            let b:netrw_lastfile = choice

            ".........................................
        " NetWrite: (http) NetWrite Method #5 {{{3
        elseif     b:netrw_method == 5
            let curl= substitute(g:netrw_http_put_cmd,'\s\+.*$',"","")
            if executable(curl)
                let url= g:netrw_choice
                call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_http_put_cmd." ".netrw#os#Escape(tmpfile,1)." ".netrw#os#Escape(url,1) )
            else
                call netrw#msg#Notify('ERROR', printf("can't write to http using <%s>", g:netrw_http_put_cmd))
            endif

            ".........................................
        " NetWrite: (dav) NetWrite Method #6 (cadaver) {{{3
        elseif     b:netrw_method == 6

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
            call netrw#os#Execute(s:netrw_silentxfer."%!".g:netrw_dav_cmd)

            " remove enew buffer (quietly)
            let filtbuf= bufnr("%")
            exe curbuf."b!"
            let &l:bh            = bhkeep
            exe filtbuf."bw!"

            let b:netrw_lastfile = choice

            ".........................................
        " NetWrite: (rsync) NetWrite Method #7 {{{3
        elseif     b:netrw_method == 7
            call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_rsync_cmd." ".netrw#os#Escape(tmpfile,1)." ".netrw#os#Escape(g:netrw_machine.g:netrw_rsync_sep.b:netrw_fname,1))
            let b:netrw_lastfile = choice

            ".........................................
        " NetWrite: (sftp) NetWrite Method #9 {{{3
        elseif     b:netrw_method == 9
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
            let sftpcmd= substitute(g:netrw_sftp_cmd,"%TEMPFILE%",escape(tmpfile,'\'),"g")
            call netrw#os#Execute(s:netrw_silentxfer."%!".sftpcmd.' '.netrw#os#Escape(uid_machine,1))
            let filtbuf= bufnr("%")
            exe curbuf."b!"
            let &l:bh            = bhkeep
            exe filtbuf."bw!"
            let b:netrw_lastfile = choice

            ".........................................
        " NetWrite: Complain {{{3
        else
            call netrw#msg#Notify('WARNING', printf('unable to comply with your request<%s>', choice))
            let leavemod= 1
        endif
    endwhile

    " NetWrite: Cleanup: {{{3
    if s:FileReadable(tmpfile)
        call netrw#fs#Remove(tmpfile)
    endif
    call s:NetrwOptionsRestore("w:")

    if a:firstline == 1 && a:lastline == line("$")
        " restore modifiability; usually equivalent to set nomod
        let &l:mod= mod
    elseif !exists("leavemod")
        " indicate that the buffer has not been modified since last written
        setl nomod
    endif

endfunction

" netrw#NetSource: source a remotely hosted Vim script {{{2
" uses NetRead to get a copy of the file into a temporarily file,
"              then sources that file,
"              then removes that file.
function netrw#NetSource(...)
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
            if s:FileReadable(s:netrw_tmpfile)
                exe "so ".fnameescape(s:netrw_tmpfile)
                if delete(s:netrw_tmpfile)
                    call netrw#msg#Notify('ERROR', 'unable to delete directory <%s>', s:netrw_tmpfile)
                endif
                unlet s:netrw_tmpfile
            else
                call netrw#msg#Notify('ERROR', printf('unable to source <%s>!', a:{i}))
            endif
            let i= i + 1
        endwhile
    endif
endfunction

" netrw#SetTreetop: resets the tree top to the current directory/specified directory {{{2
"                   (implements the :Ntree command)
function netrw#SetTreetop(iscmd,...)

    " iscmd==0: netrw#SetTreetop called using gn mapping
    " iscmd==1: netrw#SetTreetop called using :Ntree from the command line
    " clear out the current tree
    if exists("w:netrw_treetop")
        let inittreetop= w:netrw_treetop
        unlet w:netrw_treetop
    endif
    if exists("w:netrw_treedict")
        unlet w:netrw_treedict
    endif

    if (a:iscmd == 0 || a:1 == "") && exists("inittreetop")
        let treedir         = s:NetrwTreePath(inittreetop)
    else
        if isdirectory(s:NetrwFile(a:1))
            let treedir         = a:1
            let s:netrw_treetop = treedir
        elseif exists("b:netrw_curdir") && (isdirectory(s:NetrwFile(b:netrw_curdir."/".a:1)) || a:1 =~ '^\a\{3,}://')
            let treedir         = b:netrw_curdir."/".a:1
            let s:netrw_treetop = treedir
        else
            " normally the cursor is left in the message window.
            " However, here this results in the directory being listed in the message window, which is not wanted.
            let netrwbuf= bufnr("%")
            call netrw#msg#Notify('ERROR', printf("sorry, %s doesn't seem to be a directory!", a:1))
            exe bufwinnr(netrwbuf)."wincmd w"
            let treedir         = "."
            let s:netrw_treetop = getcwd()
        endif
    endif

    " determine if treedir is remote or local
    let islocal= expand("%") !~ '^\a\{3,}://'

    " browse the resulting directory
    if islocal
        call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(islocal,treedir,0))
    else
        call s:NetrwBrowse(islocal,s:NetrwBrowseChgDir(islocal,treedir,0))
    endif

endfunction

" s:NetrwGetFile: Function to read temporary file "tfile" with command "readcmd". {{{2
"    readcmd == %r : replace buffer with newly read file
"            == 0r : read file at top of buffer
"            == r  : read file after current line
"            == t  : leave file in temporary form (ie. don't read into buffer)
function s:NetrwGetFile(readcmd, tfile, method)

    " readcmd=='t': simply do nothing
    if a:readcmd == 't'
        return
    endif

    " get name of remote filename (ie. url and all)
    let rfile= bufname("%")

    if exists("*NetReadFixup")
        " for the use of NetReadFixup (not otherwise used internally)
        let line2= line("$")
    endif

    if a:readcmd[0] == '%'
        " get file into buffer

        " rename the current buffer to the temp file (ie. tfile)
        if g:netrw_cygwin
            let tfile= substitute(a:tfile,g:netrw_cygdrive.'/\(.\)','\1:','')
        else
            let tfile= a:tfile
        endif
        call s:NetrwBufRename(tfile)

        " edit temporary file (ie. read the temporary file in)
        if     rfile =~ '\.zip$'
            call zip#Browse(tfile)
        elseif rfile =~ '\.tar$'
            call tar#Browse(tfile)
        elseif rfile =~ '\.tar\.gz$'
            call tar#Browse(tfile)
        elseif rfile =~ '\.tar\.bz2$'
            call tar#Browse(tfile)
        elseif rfile =~ '\.tar\.xz$'
            call tar#Browse(tfile)
        elseif rfile =~ '\.txz$'
            call tar#Browse(tfile)
        else
            NetrwKeepj e!
        endif

        " rename buffer back to remote filename
        call s:NetrwBufRename(rfile)

        " Jan 19, 2022: COMBAK -- bram problem with https://github.com/vim/vim/pull/9554.diff filetype
        " Detect filetype of local version of remote file.
        " Note that isk must not include a "/" for scripts.vim
        " to process this detection correctly.
        "   setl ft=
        let iskkeep= &isk
        setl isk-=/
        filetype detect
        let &l:isk= iskkeep
        let line1 = 1
        let line2 = line("$")

    elseif !&ma
        " attempting to read a file after the current line in the file, but the buffer is not modifiable
        call netrw#msg#Notify('WARNING', printf('attempt to read<%s> into a non-modifiable buffer!', a:tfile))
        return

    elseif s:FileReadable(a:tfile)
        " read file after current line
        let curline = line(".")
        let lastline= line("$")
        exe "NetrwKeepj ".a:readcmd." ".fnameescape(v:cmdarg)." ".fnameescape(a:tfile)
        let line1= curline + 1
        let line2= line("$") - lastline + 1

    else
        " not readable
        call netrw#msg#Notify('WARNING', printf('file <%s> not readable', a:tfile))
        return
    endif

    " User-provided (ie. optional) fix-it-up command
    if exists("*NetReadFixup")
        NetrwKeepj call NetReadFixup(a:method, line1, line2)
    endif

    if has("gui") && has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu
        " update the Buffers menu
        NetrwKeepj call s:UpdateBuffersMenu()
    endif


    " make sure file is being displayed
    "  redraw!

endfunction

" s:NetrwMethod:  determine method of transfer {{{2
" Input:
"   choice = url   [protocol:]//[userid@]hostname[:port]/[path-to-file]
" Output:
"  b:netrw_method= 1: rcp
"                  2: ftp + <.netrc>
"                  3: ftp + machine, id, password, and [path]filename
"                  4: scp
"                  5: http[s] (wget)
"                  6: dav
"                  7: rsync
"                  8: fetch
"                  9: sftp
"                 10: file
"  g:netrw_machine= hostname
"  b:netrw_fname  = filename
"  g:netrw_port   = optional port number (for ftp)
"  g:netrw_choice = copy of input url (choice)
function s:NetrwMethod(choice)

    " sanity check: choice should have at least three slashes in it
    if strlen(substitute(a:choice,'[^/]','','g')) < 3
        call netrw#msg#Notify('ERROR', 'not a netrw-style url; netrw uses protocol://[user@]hostname[:port]/[path])')
        let b:netrw_method = -1
        return
    endif

    " record current g:netrw_machine, if any
    " curmachine used if protocol == ftp and no .netrc
    if exists("g:netrw_machine")
        let curmachine= g:netrw_machine
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
    " mipf     : a:machine a:id password filename      Use ftp
    " mf      : a:machine filename                     Use ftp + <.netrc> or g:netrw_uid s:netrw_passwd
    " ftpurm   : ftp://[user@]host[[#:]port]/filename  Use ftp + <.netrc> or g:netrw_uid s:netrw_passwd
    " rcpurm   : rcp://[user@]host/filename            Use rcp
    " rcphf    : [user@]host:filename                  Use rcp
    " scpurm   : scp://[user@]host[[#:]port]/filename  Use scp
    " httpurm  : http[s]://[user@]host/filename        Use wget
    " davurm   : dav[s]://host[:port]/path             Use cadaver/curl
    " rsyncurm : rsync://host[:port]/path              Use rsync
    " fetchurm : fetch://[user@]host[:http]/filename   Use fetch (defaults to ftp, override for http)
    " sftpurm  : sftp://[user@]host/filename  Use scp
    " fileurm  : file://[user@]host/filename           Use elinks or links
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

    " Determine Method
    " Method#1: rcp://user@hostname/...path-to-file {{{3
    if match(a:choice,rcpurm) == 0
        let b:netrw_method  = 1
        let userid          = substitute(a:choice,rcpurm,'\1',"")
        let g:netrw_machine = substitute(a:choice,rcpurm,'\2',"")
        let b:netrw_fname   = substitute(a:choice,rcpurm,'\3',"")
        if userid != ""
            let g:netrw_uid= userid
        endif

    " Method#4: scp://user@hostname/...path-to-file {{{3
    elseif match(a:choice,scpurm) == 0
        let b:netrw_method  = 4
        let g:netrw_machine = substitute(a:choice,scpurm,'\1',"")
        let g:netrw_port    = substitute(a:choice,scpurm,'\2',"")
        let b:netrw_fname   = substitute(a:choice,scpurm,'\3',"")

    " Method#5: http[s]://user@hostname/...path-to-file {{{3
    elseif match(a:choice,httpurm) == 0
        let b:netrw_method = 5
        let g:netrw_machine= substitute(a:choice,httpurm,'\1',"")
        let b:netrw_fname  = substitute(a:choice,httpurm,'\2',"")
        let b:netrw_http   = (a:choice =~ '^https:')? "https" : "http"

    " Method#6: dav://hostname[:port]/..path-to-file.. {{{3
    elseif match(a:choice,davurm) == 0
        let b:netrw_method= 6
        if a:choice =~ 'davs:'
            let g:netrw_machine= 'https://'.substitute(a:choice,davurm,'\1/\2',"")
        else
            let g:netrw_machine= 'http://'.substitute(a:choice,davurm,'\1/\2',"")
        endif
        let b:netrw_fname  = substitute(a:choice,davurm,'\3',"")

    " Method#7: rsync://user@hostname/...path-to-file {{{3
    elseif match(a:choice,rsyncurm) == 0
        let b:netrw_method = 7
        let g:netrw_machine= substitute(a:choice,rsyncurm,'\1',"")
        let b:netrw_fname  = substitute(a:choice,rsyncurm,'\2',"")

    " Methods 2,3: ftp://[user@]hostname[[:#]port]/...path-to-file {{{3
    elseif match(a:choice,ftpurm) == 0
        let userid         = substitute(a:choice,ftpurm,'\2',"")
        let g:netrw_machine= substitute(a:choice,ftpurm,'\3',"")
        let g:netrw_port   = substitute(a:choice,ftpurm,'\4',"")
        let b:netrw_fname  = substitute(a:choice,ftpurm,'\5',"")
        if userid != ""
            let g:netrw_uid= userid
        endif

        if curmachine != g:netrw_machine
            if exists("s:netrw_hup[".g:netrw_machine."]")
                call netrw#NetUserPass("ftp:".g:netrw_machine)
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
                call netrw#NetUserPass("ftp:".host)

            elseif has("win32") && s:netrw_ftp_cmd =~# '-[sS]:'
                if g:netrw_ftp_cmd =~# '-[sS]:\S*MACHINE\>'
                    let s:netrw_ftp_cmd= substitute(g:netrw_ftp_cmd,'\<MACHINE\>',g:netrw_machine,'')
                endif
                let b:netrw_method= 2
            elseif s:FileReadable(expand("$HOME/.netrc")) && !g:netrw_ignorenetrc
                let b:netrw_method= 2
            else
                if !exists("g:netrw_uid") || g:netrw_uid == ""
                    call netrw#NetUserPass()
                elseif !exists("s:netrw_passwd") || s:netrw_passwd == ""
                    call netrw#NetUserPass(g:netrw_uid)
                    " else just use current g:netrw_uid and s:netrw_passwd
                endif
                let b:netrw_method= 3
            endif
        endif

    " Method#8: fetch {{{3
    elseif match(a:choice,fetchurm) == 0
        let b:netrw_method = 8
        let g:netrw_userid = substitute(a:choice,fetchurm,'\2',"")
        let g:netrw_machine= substitute(a:choice,fetchurm,'\3',"")
        let b:netrw_option = substitute(a:choice,fetchurm,'\4',"")
        let b:netrw_fname  = substitute(a:choice,fetchurm,'\5',"")

    " Method#3: Issue an ftp : "machine id password [path/]filename" {{{3
    elseif match(a:choice,mipf) == 0
        let b:netrw_method  = 3
        let g:netrw_machine = substitute(a:choice,mipf,'\1',"")
        let g:netrw_uid     = substitute(a:choice,mipf,'\2',"")
        let s:netrw_passwd  = substitute(a:choice,mipf,'\3',"")
        let b:netrw_fname   = substitute(a:choice,mipf,'\4',"")
        call netrw#NetUserPass(g:netrw_machine,g:netrw_uid,s:netrw_passwd)

    " Method#3: Issue an ftp: "hostname [path/]filename" {{{3
    elseif match(a:choice,mf) == 0
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
        let b:netrw_method = 9
        let g:netrw_machine= substitute(a:choice,sftpurm,'\1',"")
        let b:netrw_fname  = substitute(a:choice,sftpurm,'\2',"")

    " Method#1: Issue an rcp: hostname:filename"  (this one should be last) {{{3
    elseif match(a:choice,rcphf) == 0
        let b:netrw_method  = 1
        let userid          = substitute(a:choice,rcphf,'\2',"")
        let g:netrw_machine = substitute(a:choice,rcphf,'\3',"")
        let b:netrw_fname   = substitute(a:choice,rcphf,'\4',"")
        if userid != ""
            let g:netrw_uid= userid
        endif

    " Method#10: file://user@hostname/...path-to-file {{{3
    elseif match(a:choice,fileurm) == 0 && exists("g:netrw_file_cmd")
        let b:netrw_method = 10
        let b:netrw_fname  = substitute(a:choice,fileurm,'\1',"")

    " Cannot Determine Method {{{3
    else
        call netrw#msg#Notify('WARNING', 'cannot determine method (format: protocol://[user@]hostname[:port]/[path])')
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

endfunction

" s:NetrwValidateHostname:  Validate that the hostname is valid {{{2
" Input:
"   hostname
" Output:
"  true if g:netrw_machine is valid according to RFC1123 #Section 2
function s:NetrwValidateHostname(hostname)
    " RFC1123#section-2 mandates, a valid hostname starts with letters or digits
    " so reject everyhing else
    return a:hostname =~? '^[a-z0-9]'
endfunction

" NetUserPass: set username and password for subsequent ftp transfer {{{2
"   Usage:  :call netrw#NetUserPass()                        -- will prompt for userid and password
"           :call netrw#NetUserPass("uid")                   -- will prompt for password
"           :call netrw#NetUserPass("uid","password")        -- sets global userid and password
"           :call netrw#NetUserPass("ftp:host")              -- looks up userid and password using hup dictionary
"           :call netrw#NetUserPass("host","uid","password") -- sets hup dictionary with host, userid, password
function netrw#NetUserPass(...)


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
            let host = substitute(a:1,'^ftp:','','')
            let host = substitute(host,'\..*','','')
            if exists("s:netrw_hup[host]")
                let g:netrw_uid    = s:netrw_hup[host].uid
                let s:netrw_passwd = s:netrw_hup[host].passwd
            else
                let g:netrw_uid    = input("Enter UserId: ")
                let s:netrw_passwd = inputsecret("Enter Password: ")
            endif

        else
            " case: one input argument, not an url.  Using it as a new user-id.
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
            if exists("g:netrw_passwd")
                " ask for password if one not previously entered
                let s:netrw_passwd= g:netrw_passwd
            else
                let s:netrw_passwd = inputsecret("Enter Password: ")
            endif
        endif

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
    endif

endfunction

"  Shared Browsing Support:    {{{1

" s:ExplorePatHls: converts an Explore pattern into a regular expression search pattern {{{2
function s:ExplorePatHls(pattern)
    let repat= substitute(a:pattern,'^**/\{1,2}','','')
    let repat= escape(repat,'][.\')
    let repat= '\<'.substitute(repat,'\*','\\(\\S\\+ \\)*\\S\\+','g').'\>'
    return repat
endfunction

"  s:NetrwBookHistHandler: {{{2
"    0: (user: <mb>)   bookmark current directory
"    1: (user: <gb>)   change to the bookmarked directory
"    2: (user: <qb>)   list bookmarks
"    3: (browsing)     records current directory history
"    4: (user: <u>)    go up   (previous) directory, using history
"    5: (user: <U>)    go down (next)     directory, using history
"    6: (user: <mB>)   delete bookmark
function s:NetrwBookHistHandler(chg,curdir)
    if !exists("g:netrw_dirhistmax") || g:netrw_dirhistmax <= 0
        return
    endif

    let ykeep    = @@
    let curbufnr = bufnr("%")

    if a:chg == 0
        " bookmark the current directory
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
        if exists("g:netrw_bookmarklist[v:count-1]")
            exe "NetrwKeepj e ".fnameescape(g:netrw_bookmarklist[v:count-1])
        else
            echomsg "Sorry, bookmark#".v:count." doesn't exist!"
        endif

    elseif a:chg == 2
        "   redraw!
        let didwork= 0
        " list user's bookmarks
        if exists("g:netrw_bookmarklist")
            let cnt= 1
            for bmd in g:netrw_bookmarklist
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
                if exists("g:netrw_dirhist_{cnt}")
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
        if !exists("g:netrw_dirhistcnt") || !exists("g:netrw_dirhist_{g:netrw_dirhistcnt}") || g:netrw_dirhist_{g:netrw_dirhistcnt} != a:curdir
            if g:netrw_dirhistmax > 0
                let g:netrw_dirhistcnt                   = ( g:netrw_dirhistcnt + 1 ) % g:netrw_dirhistmax
                let g:netrw_dirhist_{g:netrw_dirhistcnt} = a:curdir
            endif
        endif

    elseif a:chg == 4
        " u: change to the previous directory stored on the history list
        if g:netrw_dirhistmax > 0
            let g:netrw_dirhistcnt= ( g:netrw_dirhistcnt - v:count1 ) % g:netrw_dirhistmax
            if g:netrw_dirhistcnt < 0
                let g:netrw_dirhistcnt= g:netrw_dirhistcnt + g:netrw_dirhistmax
            endif
        else
            let g:netrw_dirhistcnt= 0
        endif
        if exists("g:netrw_dirhist_{g:netrw_dirhistcnt}")
            if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("b:netrw_curdir")
                setl ma noro
                sil! NetrwKeepj %d _
                setl nomod
            endif
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
        if g:netrw_dirhistmax > 0
            let g:netrw_dirhistcnt= ( g:netrw_dirhistcnt + 1 ) % g:netrw_dirhistmax
            if exists("g:netrw_dirhist_{g:netrw_dirhistcnt}")
                if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("b:netrw_curdir")
                    setl ma noro
                    sil! NetrwKeepj %d _
                    setl nomod
                endif
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
        if exists("s:netrwmarkfilelist_{curbufnr}")
            call s:NetrwBookmark(1)
            echo "removed marked files from bookmarks"
        else
            " delete the v:count'th bookmark
            let iremove = v:count
            let dremove = g:netrw_bookmarklist[iremove - 1]
            call s:MergeBookmarks()
            NetrwKeepj call remove(g:netrw_bookmarklist,iremove-1)
            echo "removed ".dremove." from g:netrw_bookmarklist"
        endif

        try
            call s:NetrwBookHistSave()
        catch
        endtry
    endif
    call s:NetrwBookmarkMenu()
    call s:NetrwTgtMenu()
    let @@= ykeep
endfunction

" s:NetrwBookHistRead: this function reads bookmarks and history {{{2
"  Will source the history file (.netrwhist) only if the g:netrw_disthistmax is > 0.
"                      Sister function: s:NetrwBookHistSave()
function s:NetrwBookHistRead()
    if !exists("g:netrw_dirhistmax") || g:netrw_dirhistmax <= 0
        return
    endif
    let ykeep= @@

    " read bookmarks
    if !exists("s:netrw_initbookhist")
        let home    = s:NetrwHome()
        let savefile= home."/.netrwbook"
        if filereadable(s:NetrwFile(savefile))
            exe "keepalt NetrwKeepj so ".savefile
        endif

        " read history
        if g:netrw_dirhistmax > 0
            let savefile= home."/.netrwhist"
            if filereadable(s:NetrwFile(savefile))
                exe "keepalt NetrwKeepj so ".savefile
            endif
            let s:netrw_initbookhist= 1
            au VimLeave * call s:NetrwBookHistSave()
        endif
    endif

    let @@= ykeep
endfunction

" s:NetrwBookHistSave: this function saves bookmarks and history to files {{{2
"                      Sister function: s:NetrwBookHistRead()
"                      I used to do this via viminfo but that appears to
"                      be unreliable for long-term storage
"                      If g:netrw_dirhistmax is <= 0, no history or bookmarks
"                      will be saved.
"                      (s:NetrwBookHistHandler(3,...) used to record history)
function s:NetrwBookHistSave()
    if !exists("g:netrw_dirhistmax") || g:netrw_dirhistmax <= 0
        return
    endif

    let savefile= s:NetrwHome()."/.netrwhist"
    1split

    " setting up a new buffer which will become .netrwhist
    call s:NetrwEnew()
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
            endif
            let first   = 0
            let cnt     = ( cnt - 1 ) % g:netrw_dirhistmax
            if cnt < 0
                let cnt= cnt + g:netrw_dirhistmax
            endif
        endwhile
        exe "sil! w! ".savefile
    endif

    " save bookmarks
    sil NetrwKeepj %d _
    if exists("g:netrw_bookmarklist") && g:netrw_bookmarklist != []
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
    endif

    " cleanup -- remove buffer used to construct history
    let bgone= bufnr("%")
    q!
    exe "keepalt ".bgone."bwipe!"

endfunction

" s:NetrwBrowse: This function uses the command in g:netrw_list_cmd to provide a {{{2
"  list of the contents of a local or remote directory.  It is assumed that the
"  g:netrw_list_cmd has a string, USEPORT HOSTNAME, that needs to be substituted
"  with the requested remote hostname first.
"    Often called via:  Explore/e dirname/etc -> netrw#LocalBrowseCheck() -> s:NetrwBrowse()
function s:NetrwBrowse(islocal,dirname)
    if !exists("w:netrw_liststyle")|let w:netrw_liststyle= g:netrw_liststyle|endif

    " save alternate-file's filename if w:netrw_rexlocal doesn't exist
    " This is useful when one edits a local file, then :e ., then :Rex
    if a:islocal && !exists("w:netrw_rexfile") && bufname("#") != ""
        let w:netrw_rexfile= bufname("#")
    endif

    " s:NetrwBrowse : initialize history {{{3
    if !exists("s:netrw_initbookhist")
        NetrwKeepj call s:NetrwBookHistRead()
    endif

    " s:NetrwBrowse : simplify the dirname (especially for ".."s in dirnames) {{{3
    if a:dirname !~ '^\a\{3,}://'
        let dirname= simplify(a:dirname)
    else
        let dirname= a:dirname
    endif

    " repoint t:netrw_lexbufnr if appropriate
    if exists("t:netrw_lexbufnr") && bufnr("%") == t:netrw_lexbufnr
        let repointlexbufnr= 1
    endif

    " s:NetrwBrowse : sanity checks: {{{3
    if exists("s:netrw_skipbrowse")
        unlet s:netrw_skipbrowse
        return
    endif
    if !exists("*shellescape")
        call netrw#msg#Notify('ERROR', "netrw can't run -- your vim is missing shellescape()")
        return
    endif
    if !exists("*fnameescape")
        call netrw#msg#Notify('ERROR', "netrw can't run -- your vim is missing fnameescape()")
        return
    endif

    " s:NetrwBrowse : save options: {{{3
    call s:NetrwOptionsSave("w:")

    " s:NetrwBrowse : re-instate any marked files {{{3
    if has("syntax") && exists("g:syntax_on") && g:syntax_on
        if exists("s:netrwmarkfilelist_{bufnr('%')}")
            exe "2match netrwMarkFile /".s:netrwmarkfilemtch_{bufnr("%")}."/"
        endif
    endif

    if a:islocal && exists("w:netrw_acdkeep") && w:netrw_acdkeep
        " s:NetrwBrowse : set up "safe" options for local directory/file {{{3
        if s:NetrwLcd(dirname)
            return
        endif

    elseif !a:islocal && dirname !~ '[\/]$' && dirname !~ '^"'
        " s:NetrwBrowse :  remote regular file handler {{{3
        if bufname(dirname) != ""
            exe "NetrwKeepj b ".bufname(dirname)
        else
            " attempt transfer of remote regular file

            " remove any filetype indicator from end of dirname, except for the
            " "this is a directory" indicator (/).
            " There shouldn't be one of those here, anyway.
            let path= substitute(dirname,'[*=@|]\r\=$','','e')
            call s:RemotePathAnalysis(dirname)

            " s:NetrwBrowse : remote-read the requested file into current buffer {{{3
            call s:NetrwEnew(dirname)
            call s:NetrwOptionsSafe(a:islocal)
            setl ma noro
            let b:netrw_curdir = dirname
            let url            = s:method."://".((s:user == "")? "" : s:user."@").s:machine.(s:port ? ":".s:port : "")."/".s:path
            call s:NetrwBufRename(url)
            exe "sil! NetrwKeepj keepalt doau BufReadPre ".fnameescape(s:fname)
            sil call netrw#NetRead(2,url)
            " netrw.vim and tar.vim have already handled decompression of the tarball; avoiding gzip.vim error
            if s:path =~ '\.bz2$'
                exe "sil NetrwKeepj keepalt doau BufReadPost ".fnameescape(substitute(s:fname,'\.bz2$','',''))
            elseif s:path =~ '\.gz$'
                exe "sil NetrwKeepj keepalt doau BufReadPost ".fnameescape(substitute(s:fname,'\.gz$','',''))
            elseif s:path =~ '\.xz$'
                exe "sil NetrwKeepj keepalt doau BufReadPost ".fnameescape(substitute(s:fname,'\.xz$','',''))
            else
                exe "sil NetrwKeepj keepalt doau BufReadPost ".fnameescape(s:fname)
            endif
        endif

        " s:NetrwBrowse : save certain window-oriented variables into buffer-oriented variables {{{3
        call s:SetBufWinVars()
        call s:NetrwOptionsRestore("w:")
        setl ma nomod noro
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
    let svpos  = winsaveview()

    " NetrwGetBuffer might change buffers but s:rexposn_X was set for the
    " previous buffer
    let prevbufnr = bufnr('%')
    let reusing= s:NetrwGetBuffer(a:islocal,dirname)
    if exists("s:rexposn_".prevbufnr) && exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
        let s:rexposn_{bufnr('%')} = s:rexposn_{prevbufnr}
    endif

    " maintain markfile highlighting
    if has("syntax") && exists("g:syntax_on") && g:syntax_on
        if exists("s:netrwmarkfilemtch_{bufnr('%')}") && s:netrwmarkfilemtch_{bufnr("%")} != ""
            exe "2match netrwMarkFile /".s:netrwmarkfilemtch_{bufnr("%")}."/"
        else
            2match none
        endif
    endif
    if reusing && line("$") > 1
        call s:NetrwOptionsRestore("w:")
        setl noma nomod nowrap
        return
    endif

    " set b:netrw_curdir to the new directory name {{{3
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

    " ------------
    " (local only) {{{3
    " ------------
    if a:islocal
        " Set up ShellCmdPost handling.  Append current buffer to browselist
        call s:LocalFastBrowser()

        " handle g:netrw_keepdir: set vim's current directory to netrw's notion of the current directory {{{3
        if !g:netrw_keepdir
            if !exists("&l:acd") || !&l:acd
                if s:NetrwLcd(b:netrw_curdir)
                    return
                endif
            endif
        endif

    " --------------------------------
    " remote handling: {{{3
    " --------------------------------
    else

        " analyze dirname and g:netrw_list_cmd {{{3
        if dirname =~# "^NetrwTreeListing\>"
            let dirname= b:netrw_curdir
        elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("b:netrw_curdir")
            let dirname= substitute(b:netrw_curdir,'\\','/','g')
            if dirname !~ '/$'
                let dirname= dirname.'/'
            endif
            let b:netrw_curdir = dirname
        else
            let dirname = substitute(dirname,'\\','/','g')
        endif

        let dirpat  = '^\(\w\{-}\)://\(\w\+@\)\=\([^/]\+\)/\(.*\)$'
        if dirname !~ dirpat
            call netrw#msg#Notify('ERROR', printf("netrw doesn't understand your dirname<%s>", dirname))
            NetrwKeepj call s:NetrwOptionsRestore("w:")
            setl noma nomod nowrap
            return
        endif
        let b:netrw_curdir= dirname
    endif  " (additional remote handling)

    " -------------------------------
    " Perform Directory Listing: {{{3
    " -------------------------------
    NetrwKeepj call s:NetrwMaps(a:islocal)
    NetrwKeepj call s:NetrwCommands(a:islocal)
    NetrwKeepj call s:PerformListing(a:islocal)

    " restore option(s)
    call s:NetrwOptionsRestore("w:")

    " If there is a rexposn: restore position with rexposn
    " Otherwise            : set rexposn
    if exists("s:rexposn_".bufnr("%"))
        NetrwKeepj call winrestview(s:rexposn_{bufnr('%')})
        if exists("w:netrw_bannercnt") && line(".") < w:netrw_bannercnt
            NetrwKeepj exe w:netrw_bannercnt
        endif
    else
        NetrwKeepj call s:SetRexDir(a:islocal,b:netrw_curdir)
    endif

    " repoint t:netrw_lexbufnr if appropriate
    if exists("repointlexbufnr")
        let t:netrw_lexbufnr= bufnr("%")
    endif

    " restore position
    if reusing
        call winrestview(svpos)
    endif

    " The s:LocalBrowseRefresh() function is called by an autocmd
    " installed by s:LocalFastBrowser() when g:netrw_fastbrowse <= 1 (ie. slow or medium speed).
    " However, s:NetrwBrowse() causes the FocusGained event to fire the first time.
    return
endfunction

" s:NetrwFile: because of g:netrw_keepdir, isdirectory(), type(), etc may or {{{2
" may not apply correctly; ie. netrw's idea of the current directory may
" differ from vim's.  This function insures that netrw's idea of the current
" directory is used.
" Returns a path to the file specified by a:fname
function s:NetrwFile(fname)

    " clean up any leading treedepthstring
    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
        let fname= substitute(a:fname,'^'.s:treedepthstring.'\+','','')
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
            else
                " windows, relative path given
                let ret= netrw#fs#ComposePath(b:netrw_curdir,fname)
            endif

        elseif fname =~ '^/'
            " not windows, full path given
            let ret= fname
        else
            " not windows, relative path given
            let ret= netrw#fs#ComposePath(b:netrw_curdir,fname)
        endif
    else
        " vim and netrw agree on the current directory
        let ret= fname
    endif

    return ret
endfunction

" s:NetrwFileInfo: supports qf (query for file information) {{{2
function s:NetrwFileInfo(islocal,fname)
    let ykeep= @@
    if a:islocal
        let lsopt= "-lsad"
        if g:netrw_sizestyle =~# 'H'
            let lsopt= "-lsadh"
        elseif g:netrw_sizestyle =~# 'h'
            let lsopt= "-lsadh --si"
        endif
        if (has("unix") || has("macunix")) && executable("/bin/ls")

            if getline(".") == "../"
                echo system("/bin/ls ".lsopt." ".netrw#os#Escape(".."))

            elseif w:netrw_liststyle == s:TREELIST && getline(".") !~ '^'.s:treedepthstring
                echo system("/bin/ls ".lsopt." ".netrw#os#Escape(b:netrw_curdir))

            elseif exists("b:netrw_curdir")
                echo system("/bin/ls ".lsopt." ".netrw#os#Escape(netrw#fs#ComposePath(b:netrw_curdir,a:fname)))

            else
                echo system("/bin/ls ".lsopt." ".netrw#os#Escape(s:NetrwFile(a:fname)))
            endif
        else
            " use vim functions to return information about file below cursor
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
        endif
    else
        echo "sorry, \"qf\" not supported yet for remote files"
    endif
    let @@= ykeep
endfunction

" s:NetrwGetBuffer: [get a new|find an old netrw] buffer for a netrw listing {{{2
"   returns 0=cleared buffer
"           1=re-used buffer (buffer not cleared)
"  Nov 09, 2020: tst952 shows that when user does :set hidden that NetrwGetBuffer will come up with a [No Name] buffer (hid fix)
function s:NetrwGetBuffer(islocal,dirname)
    let dirname= a:dirname

    " re-use buffer if possible {{{3
    if !exists("s:netrwbuf")
        let s:netrwbuf= {}
    endif

    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
        let bufnum = -1

        if !empty(s:netrwbuf) && has_key(s:netrwbuf,netrw#fs#AbsPath(dirname))
            if has_key(s:netrwbuf,"NetrwTreeListing")
                let bufnum= s:netrwbuf["NetrwTreeListing"]
            else
                let bufnum= s:netrwbuf[netrw#fs#AbsPath(dirname)]
            endif
            if !bufexists(bufnum)
                call remove(s:netrwbuf,"NetrwTreeListing")
                let bufnum= -1
            endif
        elseif bufnr("NetrwTreeListing") != -1
            let bufnum= bufnr("NetrwTreeListing")
        else
            let bufnum= -1
        endif

    elseif has_key(s:netrwbuf,netrw#fs#AbsPath(dirname))
        let bufnum= s:netrwbuf[netrw#fs#AbsPath(dirname)]
        if !bufexists(bufnum)
            call remove(s:netrwbuf,netrw#fs#AbsPath(dirname))
            let bufnum= -1
        endif

    else
        let bufnum= -1
    endif

    " highjack the current buffer
    "   IF the buffer already has the desired name
    "   AND it is empty
    let curbuf = bufname("%")
    if curbuf == '.'
        let curbuf = getcwd()
    endif
    if dirname == curbuf && line("$") == 1 && getline("%") == ""
        return 0
    else  " DEBUG
    endif
    " Aug 14, 2021: was thinking about looking for a [No Name] buffer here and using it, but that might cause problems

    " get enew buffer and name it -or- re-use buffer {{{3
    if bufnum < 0      " get enew buffer and name it
        call s:NetrwEnew(dirname)
        " name the buffer
        if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
            " Got enew buffer; transform into a NetrwTreeListing
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
        else
            call s:NetrwBufRename(dirname)
            " enter the new buffer into the s:netrwbuf dictionary
            let s:netrwbuf[netrw#fs#AbsPath(dirname)]= bufnr("%")
        endif

    else " Re-use the buffer
        " ignore all events
        let eikeep= &ei
        setl ei=all

        if &ft == "netrw"
            exe "sil! NetrwKeepj noswapfile b ".bufnum
        else
            call s:NetrwEditBuf(bufnum)
        endif
        if bufname("%") == '.'
            call s:NetrwBufRename(getcwd())
        endif

        " restore ei
        let &ei= eikeep

        if line("$") <= 1 && getline(1) == ""
            " empty buffer
            NetrwKeepj call s:NetrwListSettings(a:islocal)
            return 0

        elseif g:netrw_fastbrowse == 0 || (a:islocal && g:netrw_fastbrowse == 1)
            NetrwKeepj call s:NetrwListSettings(a:islocal)
            sil NetrwKeepj %d _
            return 0

        elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
            setl ma
            sil NetrwKeepj %d _
            NetrwKeepj call s:NetrwListSettings(a:islocal)
            return 0

        else
            return 1
        endif
    endif

    " do netrw settings: make this buffer not-a-file, modifiable, not line-numbered, etc {{{3
    "     fastbrowse  Local  Remote   Hiding a buffer implies it may be re-used (fast)
    "  slow   0         D      D      Deleting a buffer implies it will not be re-used (slow)
    "  med    1         D      H
    "  fast   2         H      H
    let fname= expand("%")
    NetrwKeepj call s:NetrwListSettings(a:islocal)
    call s:NetrwBufRename(fname)

    " delete all lines from buffer {{{3
    sil! keepalt NetrwKeepj %d _

    return 0
endfunction

"  s:NetrwGetWord: it gets the directory/file named under the cursor {{{2
function s:NetrwGetWord()
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
    endif

    if exists("w:netrw_bannercnt") && line(".") < w:netrw_bannercnt
        " Active Banner support
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
        NetrwKeepj norm! 0
        let dirname= substitute(getline('.'),'\t -->.*$','','')

    elseif w:netrw_liststyle == s:LONGLIST
        NetrwKeepj norm! 0
        let dirname= substitute(getline('.'),'^\(\%(\S\+ \)*\S\+\).\{-}$','\1','e')

    elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
        let dirname= substitute(getline('.'),'^\('.s:treedepthstring.'\)*','','e')
        let dirname= substitute(dirname,'\t -->.*$','','')

    else
        let dirname= getline('.')

        if !exists("b:netrw_cpf")
            let b:netrw_cpf= 0
            exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$g/^./if virtcol("$") > b:netrw_cpf|let b:netrw_cpf= virtcol("$")|endif'
            call histdel("/",-1)
        endif

        let filestart = (virtcol(".")/b:netrw_cpf)*b:netrw_cpf
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

        let dirname= substitute(dirname,'\s\+$','','e')
    endif

    " symlinks are indicated by a trailing "@".  Remove it before further processing.
    let dirname= substitute(dirname,"@$","","")

    " executables are indicated by a trailing "*".  Remove it before further processing.
    let dirname= substitute(dirname,"\*$","","")

    let &l:sol= keepsol

    return dirname
endfunction

" s:NetrwListSettings: make standard settings for making a netrw listing {{{2
"                      g:netrw_bufsettings will be used after the listing is produced.
"                      Called by s:NetrwGetBuffer()
function s:NetrwListSettings(islocal)
    let fname= bufname("%")
    "              nobl noma nomod nonu noma nowrap ro   nornu  (std g:netrw_bufsettings)
    setl bt=nofile nobl ma         nonu      nowrap noro nornu
    call s:NetrwBufRename(fname)
    if g:netrw_use_noswf
        setl noswf
    endif
    exe "setl ts=".(g:netrw_maxfilenamelen+1)
    setl isk+=.,~,-
    if g:netrw_fastbrowse > a:islocal
        setl bh=hide
    else
        setl bh=delete
    endif
endfunction

"  s:NetrwListStyle: change list style (thin - long - wide - tree) {{{2
"  islocal=0: remote browsing
"         =1: local browsing
function s:NetrwListStyle(islocal)
    let ykeep             = @@
    let fname             = s:NetrwGetWord()
    if !exists("w:netrw_liststyle")|let w:netrw_liststyle= g:netrw_liststyle|endif
    let svpos            = winsaveview()
    let w:netrw_liststyle = (w:netrw_liststyle + 1) % s:MAXLIST

    " repoint t:netrw_lexbufnr if appropriate
    if exists("t:netrw_lexbufnr") && bufnr("%") == t:netrw_lexbufnr
        let repointlexbufnr= 1
    endif

    if w:netrw_liststyle == s:THINLIST
        " use one column listing
        let g:netrw_list_cmd = substitute(g:netrw_list_cmd,' -l','','ge')

    elseif w:netrw_liststyle == s:LONGLIST
        " use long list
        let g:netrw_list_cmd = g:netrw_list_cmd." -l"

    elseif w:netrw_liststyle == s:WIDELIST
        " give wide list
        let g:netrw_list_cmd = substitute(g:netrw_list_cmd,' -l','','ge')

    elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
        let g:netrw_list_cmd = substitute(g:netrw_list_cmd,' -l','','ge')

    else
        call netrw#msg#Notify('WARNING', printf('bad value for g:netrw_liststyle (=%s)', w:netrw_liststyle))
        let g:netrw_liststyle = s:THINLIST
        let w:netrw_liststyle = g:netrw_liststyle
        let g:netrw_list_cmd  = substitute(g:netrw_list_cmd,' -l','','ge')
    endif
    setl ma noro

    " clear buffer - this will cause NetrwBrowse/LocalBrowseCheck to do a refresh
    sil! NetrwKeepj %d _
    " following prevents tree listing buffer from being marked "modified"
    setl nomod

    " refresh the listing
    NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
    NetrwKeepj call s:NetrwCursor(0)

    " repoint t:netrw_lexbufnr if appropriate
    if exists("repointlexbufnr")
        let t:netrw_lexbufnr= bufnr("%")
    endif

    " restore position; keep cursor on the filename
    NetrwKeepj call winrestview(svpos)
    let @@= ykeep

endfunction

" s:NetrwBannerCtrl: toggles the display of the banner {{{2
function s:NetrwBannerCtrl(islocal)
    let ykeep= @@
    " toggle the banner (enable/suppress)
    let g:netrw_banner= !g:netrw_banner

    " refresh the listing
    let svpos= winsaveview()
    call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))

    " keep cursor on the filename
    if g:netrw_banner && exists("w:netrw_bannercnt") && line(".") >= w:netrw_bannercnt
        let fname= s:NetrwGetWord()
        sil NetrwKeepj $
        let result= search('\%(^\%(|\+\s\)\=\|\s\{2,}\)\zs'.escape(fname,'.\[]*$^').'\%(\s\{2,}\|$\)','bc')
        if result <= 0 && exists("w:netrw_bannercnt")
            exe "NetrwKeepj ".w:netrw_bannercnt
        endif
    endif
    let @@= ykeep
endfunction

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
function s:NetrwBookmark(del,...)
    if a:0 == 0
        if &ft == "netrw"
            let curbufnr = bufnr("%")

            if exists("s:netrwmarkfilelist_{curbufnr}")
                " for every filename in the marked list
                let svpos  = winsaveview()
                let islocal= expand("%") !~ '^\a\{3,}://'
                for fname in s:netrwmarkfilelist_{curbufnr}
                    if a:del|call s:DeleteBookmark(fname)|else|call s:MakeBookmark(fname)|endif
                endfor
                let curdir  = exists("b:netrw_curdir")? b:netrw_curdir : getcwd()
                call s:NetrwUnmarkList(curbufnr,curdir)
                NetrwKeepj call s:NetrwRefresh(islocal,s:NetrwBrowseChgDir(islocal,'./',0))
                NetrwKeepj call winrestview(svpos)
            else
                let fname= s:NetrwGetWord()
                if a:del|call s:DeleteBookmark(fname)|else|call s:MakeBookmark(fname)|endif
            endif

        else
            " bookmark currently open file
            let fname= expand("%")
            if a:del|call s:DeleteBookmark(fname)|else|call s:MakeBookmark(fname)|endif
        endif

    else
        " bookmark specified files
        "  attempts to infer if working remote or local
        "  by deciding if the current file begins with an url
        "  Globbing cannot be done remotely.
        let islocal= expand("%") !~ '^\a\{3,}://'
        let i = 1
        while i <= a:0
            if islocal
                let mbfiles = glob(fnameescape(a:{i}), 0, 1, 1)
            else
                let mbfiles = [a:{i}]
            endif
            for mbfile in mbfiles
                if a:del
                    call s:DeleteBookmark(mbfile)
                else
                    call s:MakeBookmark(mbfile)
                endif
            endfor
            let i= i + 1
        endwhile
    endif

    " update the menu
    call s:NetrwBookmarkMenu()
endfunction

" s:NetrwBookmarkMenu: Uses menu priorities {{{2
"                      .2.[cnt] for bookmarks, and
"                      .3.[cnt] for history
"                      (see s:NetrwMenu())
function s:NetrwBookmarkMenu()
    if !exists("s:netrw_menucnt")
        return
    endif

    " the following test assures that gvim is running, has menus available, and has menus enabled.
    if has("gui") && has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu
        if exists("g:NetrwTopLvlMenu")
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
                let bmd= escape(bmd,g:netrw_menu_escape)

                " show bookmarks for goto menu
                exe 'sil! menu '.g:NetrwMenuPriority.".2.".cnt." ".g:NetrwTopLvlMenu.'Bookmarks.'.bmd.'    :e '.bmd."\<cr>"

                " show bookmarks for deletion menu
                exe 'sil! menu '.g:NetrwMenuPriority.".8.2.".cnt." ".g:NetrwTopLvlMenu.'Bookmarks\ and\ History.Bookmark\ Delete.'.bmd.'   '.cnt."mB"
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
                    exe 'sil! menu '.g:NetrwMenuPriority.".3.".priority." ".g:NetrwTopLvlMenu.'History.'.histdir.'    :e '.histdir."\<cr>"
                endif
                let first = 0
                let cnt   = ( cnt - 1 ) % g:netrw_dirhistmax
                if cnt < 0
                    let cnt= cnt + g:netrw_dirhistmax
                endif
            endwhile
        endif

    endif
endfunction

"  s:NetrwBrowseChgDir: constructs a new directory based on the current {{{2
"                       directory and a new directory name.  Also, if the
"                       "new directory name" is actually a file,
"                       NetrwBrowseChgDir() edits the file.
"    cursor=0: newdir is relative to b:netrw_curdir
"          =1: newdir is relative to the path to the word under the cursor in
"              tree view
function s:NetrwBrowseChgDir(islocal, newdir, cursor, ...)
    let ykeep= @@
    if !exists("b:netrw_curdir")
        let @@= ykeep
        return
    endif

    " NetrwBrowseChgDir; save options and initialize {{{3
    call s:SavePosn(s:netrw_posn)
    NetrwKeepj call s:NetrwOptionsSave("s:")
    NetrwKeepj call s:NetrwOptionsSafe(a:islocal)

    let newdir = a:newdir
    let dirname = b:netrw_curdir

    if a:cursor && w:netrw_liststyle == s:TREELIST
        " dirname is the path to the word under the cursor
        let dirname = s:NetrwTreePath(w:netrw_treetop)
        " If the word under the cursor is a directory (except for ../), NetrwTreePath
        " returns the full path, including the word under the cursor, remove it
        if newdir != "../"
            let dirname = fnamemodify(dirname, ":h")
        endif
    endif

    if has("win32")
        let dirname = substitute(dirname, '\\', '/', 'ge')
    endif

    let dolockout = 0
    let dorestore = 1

    " ignore <cr>s when done in the banner
    if g:netrw_banner
        if exists("w:netrw_bannercnt") && line(".") < w:netrw_bannercnt && line("$") >= w:netrw_bannercnt
            if getline(".") =~# 'Quick Help'
                let g:netrw_quickhelp= (g:netrw_quickhelp + 1)%len(s:QuickHelp)
                setl ma noro nowrap
                NetrwKeepj call setline(line('.'),'"   Quick Help: <F1>:help  '.s:QuickHelp[g:netrw_quickhelp])
                setl noma nomod nowrap
                NetrwKeepj call s:NetrwOptionsRestore("s:")
            endif
        endif
    endif

    " set up o/s-dependent directory recognition pattern
    let dirpat = has("amiga") ? '[\/:]$' : '[\/]$'

    if newdir !~ dirpat && !(a:islocal && isdirectory(s:NetrwFile(netrw#fs#ComposePath(dirname, newdir))))
        " ------------------------------
        " NetrwBrowseChgDir: edit a file {{{3
        " ------------------------------

        " save position for benefit of Rexplore
        let s:rexposn_{bufnr("%")}= winsaveview()

        let dirname = isabsolutepath(newdir)
                    \ ? netrw#fs#AbsPath(newdir)
                    \ : netrw#fs#ComposePath(dirname, newdir)

        " this lets netrw#BrowseX avoid the edit
        if a:0 < 1
            NetrwKeepj call s:NetrwOptionsRestore("s:")
            let curdir= b:netrw_curdir
            if !exists("s:didsplit")
                if type(g:netrw_browse_split) == 3
                    " open file in server
                    " Note that g:netrw_browse_split is a List: [servername,tabnr,winnr]
                    call s:NetrwServerEdit(a:islocal,dirname)
                    return

                elseif g:netrw_browse_split == 1
                    " horizontally splitting the window first
                    let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
                    exe "keepalt ".(g:netrw_alto? "bel " : "abo ").winsz."wincmd s"
                    if !&ea
                        keepalt wincmd _
                    else
                        exe "keepalt wincmd ="
                    endif
                    call s:SetRexDir(a:islocal,curdir)

                elseif g:netrw_browse_split == 2
                    " vertically splitting the window first
                    let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize
                    exe "keepalt ".(g:netrw_alto? "top " : "bot ")."vert ".winsz."wincmd s"
                    if !&ea
                        keepalt wincmd |
                    else
                        exe "keepalt wincmd ="
                    endif
                    call s:SetRexDir(a:islocal,curdir)

                elseif g:netrw_browse_split == 3
                    " open file in new tab
                    keepalt tabnew
                    if !exists("b:netrw_curdir")
                        let b:netrw_curdir= getcwd()
                    endif
                    call s:SetRexDir(a:islocal,curdir)

                elseif g:netrw_browse_split == 4
                    " act like "P" (ie. open previous window)
                    if s:NetrwPrevWinOpen(2) == 3
                        let @@= ykeep
                        return
                    endif
                    call s:SetRexDir(a:islocal,curdir)

                else
                    " handling a file, didn't split, so remove menu
                    call s:NetrwMenu(0)
                    " optional change to window
                    if g:netrw_chgwin >= 1
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
                " some like c-^ to return to the last edited file
                " others like c-^ to return to the netrw buffer
                " Apr 30, 2020: used to have e! here.  That can cause loss of a modified file,
                " so emit error E37 instead.
                call s:NetrwEditFile("e","",dirname)
                call s:NetrwCursor(1)
                if &hidden || &bufhidden == "hide"
                    " file came from vim's hidden storage.  Don't "restore" options with it.
                    let dorestore= 0
                endif
            endif

            " handle g:Netrw_funcref -- call external-to-netrw functions
            "   This code will handle g:Netrw_funcref as an individual function reference
            "   or as a list of function references.  It will ignore anything that's not
            "   a function reference.  See  :help Funcref  for information about function references.
            if exists("g:Netrw_funcref")
                if type(g:Netrw_funcref) == 2
                    NetrwKeepj call g:Netrw_funcref()
                elseif type(g:Netrw_funcref) == 3
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
        let dirname = newdir
        NetrwKeepj call s:SetRexDir(a:islocal,dirname)
        NetrwKeepj call s:NetrwOptionsRestore("s:")
        norm! m`

    elseif newdir == './'
        " ---------------------------------------------
        " NetrwBrowseChgDir: refresh the directory list {{{3
        " ---------------------------------------------
        NetrwKeepj call s:SetRexDir(a:islocal,dirname)
        norm! m`

    elseif newdir == '../'
        " --------------------------------------
        " NetrwBrowseChgDir: go up one directory {{{3
        " --------------------------------------

        let dirname = netrw#fs#Dirname(dirname)

        if w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
            " force a refresh
            setl noro ma
            NetrwKeepj %d _
        endif

        if has("amiga")
            " amiga
            if a:islocal
                let dirname= substitute(dirname,'^\(.*[/:]\)\([^/]\+$\)','\1','')
                let dirname= substitute(dirname,'/$','','')
            else
                let dirname= substitute(dirname,'^\(.*[/:]\)\([^/]\+/$\)','\1','')
            endif

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

        else
            " unix or cygwin
            if a:islocal
                let dirname= substitute(dirname,'^\(.*\)/\([^/]\+\)/$','\1','')
                if dirname == ""
                    let dirname= '/'
                endif
            else
                let dirname= substitute(dirname,'^\(\a\{3,}://.\{-}/\{1,2}\)\(.\{-}\)\([^/]\+\)/$','\1\2','')
            endif
        endif
        NetrwKeepj call s:SetRexDir(a:islocal,dirname)
        norm! m`

    elseif exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
        " --------------------------------------
        " NetrwBrowseChgDir: Handle Tree Listing {{{3
        " --------------------------------------
        " force a refresh (for TREELIST, NetrwTreeDir() will force the refresh)
        setl noro ma
        if !(exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("b:netrw_curdir"))
            NetrwKeepj %d _
        endif
        let treedir      = s:NetrwTreeDir(a:islocal)
        let s:treecurpos = winsaveview()
        let haskey       = 0

        " search treedict for tree dir as-is
        if has_key(w:netrw_treedict,treedir)
            let haskey= 1
        else
        endif

        " search treedict for treedir with a [/@] appended
        if !haskey && treedir !~ '[/@]$'
            if has_key(w:netrw_treedict,treedir."/")
                let treedir= treedir."/"
                let haskey = 1
            else
            endif
        endif

        " search treedict for treedir with any trailing / elided
        if !haskey && treedir =~ '/$'
            let treedir= substitute(treedir,'/$','','')
            if has_key(w:netrw_treedict,treedir)
                let haskey = 1
            else
            endif
        endif

        if haskey
            " close tree listing for selected subdirectory
            call remove(w:netrw_treedict,treedir)
            let dirname= w:netrw_treetop
        else
            " go down one directory
            let dirname= substitute(treedir,'/*$','/','')
        endif
        NetrwKeepj call s:SetRexDir(a:islocal,dirname)
        let s:treeforceredraw = 1

    else
        " ----------------------------------------
        " NetrwBrowseChgDir: Go down one directory {{{3
        " ----------------------------------------
        let dirname    = netrw#fs#ComposePath(dirname,newdir)
        NetrwKeepj call s:SetRexDir(a:islocal,dirname)
        norm! m`
    endif

    " --------------------------------------
    " NetrwBrowseChgDir: Restore and Cleanup {{{3
    " --------------------------------------
    if dorestore
        " dorestore is zero'd when a local file was hidden or bufhidden;
        " in such a case, we want to keep whatever settings it may have.
        NetrwKeepj call s:NetrwOptionsRestore("s:")
    endif
    if dolockout && dorestore
        if filewritable(dirname)
            setl ma noro nomod
        else
            setl ma ro nomod
        endif
    endif
    call s:RestorePosn(s:netrw_posn)
    let @@= ykeep

    return dirname
endfunction

" s:NetrwBrowseUpDir: implements the "-" mappings {{{2
"    for thin, long, and wide: cursor placed just after banner
"    for tree, keeps cursor on current filename
function s:NetrwBrowseUpDir(islocal)
    if exists("w:netrw_bannercnt") && line(".") < w:netrw_bannercnt-1
        " this test needed because occasionally this function seems to be incorrectly called
        " when multiple leftmouse clicks are taken when atop the one line help in the banner.
        " I'm allowing the very bottom line to permit a "-" exit so that one may escape empty
        " directories.
        return
    endif

    norm! 0
    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
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
            call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,'../',0))
        else
            call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,'../',0))
        endif
        if w:netrw_treetop == '/'
            keepj call search('^\M'.curfile,"w")
        elseif curfile == '../'
            keepj call search('^\M'.curfile,"wb")
        else
            while 1
                keepj call search('^\M'.s:treedepthstring.curfile,"wb")
                let treepath= s:NetrwTreePath(w:netrw_treetop)
                if treepath == curpath
                    break
                endif
            endwhile
        endif

    else
        call s:SavePosn(s:netrw_posn)
        if exists("b:netrw_curdir")
            let curdir= b:netrw_curdir
        else
            let curdir= expand(getcwd())
        endif
        if a:islocal
            call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,'../',0))
        else
            call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,'../',0))
        endif
        call s:RestorePosn(s:netrw_posn)
        let curdir= substitute(curdir,'^.*[\/]','','')
        let curdir= '\<'. escape(curdir, '~'). '/'
        call search(curdir,'wc')
    endif
endfunction

" netrw#BrowseX:  (implements "x") executes a special "viewer" script or program for the {{{2
"                 given filename; typically this means given their extension.
function netrw#BrowseX(fname)
    " special core dump handler
    if a:fname =~ '/core\(\.\d\+\)\=$' && exists("g:Netrw_corehandler")
        if type(g:Netrw_corehandler) == v:t_func
            " g:Netrw_corehandler is a function reference (see :help Funcref)
            call g:Netrw_corehandler(s:NetrwFile(a:fname))
        elseif type(g:Netrw_corehandler) == v:t_list
            " g:Netrw_corehandler is a List of function references (see :help Funcref)
            for Fncref in g:Netrw_corehandler
                if type(Fncref) == v:t_func
                    call Fncref(a:fname)
                endif
            endfor
        endif
        return
    endif

    let fname = a:fname
    " special ~ handler for local
    if fname =~ '^\~' && expand("$HOME") != ""
        let fname = substitute(fname, '^\~', expand("$HOME"), '')
    endif

    if fname =~ '^[a-z]\+://'
        " open a remote file
        call netrw#os#Open(fname)
    else
        call netrw#os#Open(s:NetrwFile(fname))
    endif
endfunction

" s:NetrwBufRename: renames a buffer without the side effect of retaining an unlisted buffer having the old name {{{2
"                   Using the file command on a "[No Name]" buffer does not seem to cause the old "[No Name]" buffer
"                   to become an unlisted buffer, so in that case don't bwipe it.
function s:NetrwBufRename(newname)
    let oldbufname= bufname(bufnr("%"))

    if oldbufname != a:newname
        let b:junk= 1
        exe 'sil! keepj keepalt file '.fnameescape(a:newname)
        let oldbufnr= bufnr(oldbufname)
        if oldbufname != "" && oldbufnr != -1 && oldbufnr != bufnr("%")
            exe "bwipe! ".oldbufnr
        endif
    endif

endfunction

" netrw#CheckIfRemote: returns 1 if current file looks like an url, 0 else {{{2
function netrw#CheckIfRemote(...)
    if a:0 > 0
        let curfile= a:1
    else
        let curfile= expand("%")
    endif
    " Ignore terminal buffers
    if &buftype ==# 'terminal'
        return 0
    endif
    if curfile =~ '^\a\{3,}://'
        return 1
    else
        return 0
    endif
endfunction

" s:NetrwChgPerm: (implements "gp") change file permission {{{2
function s:NetrwChgPerm(islocal,curdir)
    let ykeep  = @@
    call inputsave()
    let newperm= input("Enter new permission: ")
    call inputrestore()
    let chgperm= substitute(g:netrw_chgperm,'\<FILENAME\>',netrw#os#Escape(expand("<cfile>")),'')
    let chgperm= substitute(chgperm,'\<PERM\>',netrw#os#Escape(newperm),'')
    call system(chgperm)
    if v:shell_error != 0
        NetrwKeepj call netrw#ErrorMsg(1,"changing permission on file<".expand("<cfile>")."> seems to have failed",75)
    endif
    if a:islocal
        NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
    endif
    let @@= ykeep
endfunction

" s:NetrwClearExplore: clear explore variables (if any) {{{2
function s:NetrwClearExplore()
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
endfunction

" s:NetrwEditBuf: decides whether or not to use keepalt to edit a buffer {{{2
function s:NetrwEditBuf(bufnum)
    if exists("g:netrw_altfile") && g:netrw_altfile && &ft == "netrw"
        exe "sil! NetrwKeepj keepalt noswapfile b ".fnameescape(a:bufnum)
    else
        exe "sil! NetrwKeepj noswapfile b ".fnameescape(a:bufnum)
    endif
endfunction

" s:NetrwEditFile: decides whether or not to use keepalt to edit a file {{{2
"    NetrwKeepj [keepalt] <OPT> <CMD> <FILENAME>
function s:NetrwEditFile(cmd,opt,fname)
    if exists("g:netrw_altfile") && g:netrw_altfile && &ft == "netrw"
        exe "NetrwKeepj keepalt ".a:opt." ".a:cmd." ".fnameescape(a:fname)
    else
        if a:cmd =~# 'e\%[new]!' && !&hidden && getbufvar(bufname('%'), '&modified', 0)
            call setbufvar(bufname('%'), '&bufhidden', 'hide')
        endif
        exe "NetrwKeepj ".a:opt." ".a:cmd." ".fnameescape(a:fname)
    endif
endfunction

" s:NetrwExploreListUniq: {{{2
function s:NetrwExploreListUniq(explist)
    " this assumes that the list is already sorted
    let newexplist= []
    for member in a:explist
        if !exists("uniqmember") || member != uniqmember
            let uniqmember = member
            let newexplist = newexplist + [ member ]
        endif
    endfor
    return newexplist
endfunction

" s:NetrwForceChgDir: (gd support) Force treatment as a directory {{{2
function s:NetrwForceChgDir(islocal,newdir)
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
    else
        " should already be getting treatment as a directory
        let newdir= a:newdir
    endif
    let newdir= s:NetrwBrowseChgDir(a:islocal,newdir,0)
    call s:NetrwBrowse(a:islocal,newdir)
    let @@= ykeep
endfunction

" s:NetrwForceFile: (gf support) Force treatment as a file {{{2
function s:NetrwForceFile(islocal,newfile)
    if a:newfile =~ '[/@*=|\\]$'
        let newfile= substitute(a:newfile,'.$','','')
    else
        let newfile= a:newfile
    endif
    if a:islocal
        call s:NetrwBrowseChgDir(a:islocal,newfile,0)
    else
        call s:NetrwBrowse(a:islocal,s:NetrwBrowseChgDir(a:islocal,newfile,0))
    endif
endfunction

" s:NetrwHide: this function is invoked by the "a" map for browsing {{{2
"          and switches the hiding mode.  The actual hiding is done by
"          s:NetrwListHide().
"             g:netrw_hide= 0: show all
"                           1: show not-hidden files
"                           2: show hidden files only
function s:NetrwHide(islocal)
    let ykeep= @@
    let svpos= winsaveview()

    if exists("s:netrwmarkfilelist_{bufnr('%')}")

        " hide the files in the markfile list
        for fname in s:netrwmarkfilelist_{bufnr("%")}
            if match(g:netrw_list_hide,'\<'.fname.'\>') != -1
                " remove fname from hiding list
                let g:netrw_list_hide= substitute(g:netrw_list_hide,'..\<'.escape(fname,g:netrw_fname_escape).'\>..','','')
                let g:netrw_list_hide= substitute(g:netrw_list_hide,',,',',','g')
                let g:netrw_list_hide= substitute(g:netrw_list_hide,'^,\|,$','','')
            else
                " append fname to hiding list
                if exists("g:netrw_list_hide") && g:netrw_list_hide != ""
                    let g:netrw_list_hide= g:netrw_list_hide.',\<'.escape(fname,g:netrw_fname_escape).'\>'
                else
                    let g:netrw_list_hide= '\<'.escape(fname,g:netrw_fname_escape).'\>'
                endif
            endif
        endfor
        NetrwKeepj call s:NetrwUnmarkList(bufnr("%"),b:netrw_curdir)
        let g:netrw_hide= 1

    else

        " switch between show-all/show-not-hidden/show-hidden
        let g:netrw_hide=(g:netrw_hide+1)%3
        exe "NetrwKeepj norm! 0"
        if g:netrw_hide && g:netrw_list_hide == ""
            call netrw#msg#Notify('WARNING', 'your hiding list is empty!')
            let @@= ykeep
            return
        endif
    endif

    NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
    NetrwKeepj call winrestview(svpos)
    let @@= ykeep
endfunction

" s:NetrwHideEdit: allows user to edit the file/directory hiding list {{{2
function s:NetrwHideEdit(islocal)
    let ykeep= @@
    " save current cursor position
    let svpos= winsaveview()

    " get new hiding list from user
    call inputsave()
    let newhide= input("Edit Hiding List: ",g:netrw_list_hide)
    call inputrestore()
    let g:netrw_list_hide= newhide

    " refresh the listing
    sil NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,"./",0))

    " restore cursor position
    call winrestview(svpos)
    let @@= ykeep
endfunction

" s:NetrwHidden: invoked by "gh" {{{2
function s:NetrwHidden(islocal)
    let ykeep= @@
    "  save current position
    let svpos  = winsaveview()

    if g:netrw_list_hide =~ '\(^\|,\)\\(^\\|\\s\\s\\)\\zs\\.\\S\\+'
        " remove .file pattern from hiding list
        let g:netrw_list_hide= substitute(g:netrw_list_hide,'\(^\|,\)\\(^\\|\\s\\s\\)\\zs\\.\\S\\+','','')
    elseif strdisplaywidth(g:netrw_list_hide) >= 1
        let g:netrw_list_hide= g:netrw_list_hide . ',\(^\|\s\s\)\zs\.\S\+'
    else
        let g:netrw_list_hide= '\(^\|\s\s\)\zs\.\S\+'
    endif
    if g:netrw_list_hide =~ '^,'
        let g:netrw_list_hide= strpart(g:netrw_list_hide,1)
    endif

    " refresh screen and return to saved position
    NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
    NetrwKeepj call winrestview(svpos)
    let @@= ykeep
endfunction

"  s:NetrwHome: this function determines a "home" for saving bookmarks and history {{{2
function s:NetrwHome()
    if has('nvim')
        let home = netrw#fs#PathJoin(stdpath('state'), 'netrw')
    elseif exists('g:netrw_home')
        let home = expand(g:netrw_home)
    elseif exists('$MYVIMDIR')
        let home = expand('$MYVIMDIR')->substitute('/$', '', '')
    else
        " Pick the first redable directory in 'runtimepath'
        for path in split(&rtp, ',')
            if isdirectory(s:NetrwFile(path)) && filewritable(s:NetrwFile(path))
                let home = path
                break
            endif
        endfor

        if empty(path)
            " just pick the first directory
            let home = substitute(&rtp, ',.*$', '', '')
        endif
    endif

    " insure that the home directory exists
    if g:netrw_dirhistmax > 0 && !isdirectory(s:NetrwFile(home))
        if exists("g:netrw_mkdir")
            call system(g:netrw_mkdir." ".s:ShellEscape(s:NetrwFile(home)))
        else
            call mkdir(home)
        endif
    endif

    " Normalize directory if on Windows
    if has("win32")
        let home = substitute(home, '/', '\\', 'g')
    endif

    let g:netrw_home = home
    return home
endfunction

" s:NetrwLeftmouse: handles the <leftmouse> when in a netrw browsing window {{{2
function s:NetrwLeftmouse(islocal)
    if exists("s:netrwdrag")
        return
    endif
    if &ft != "netrw"
        return
    endif

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
    if mouse_lnum >= wlastline + 1 || v:mouse_win != winnr()
        " appears to be a status bar leftmouse click
        let @@= ykeep
        return
    endif
    " Dec 04, 2013: following test prevents leftmouse selection/deselection of directories and files in treelist mode
    " Windows are separated by vertical separator bars - but the mouse seems to be doing what it should when dragging that bar
    " without this test when its disabled.
    " May 26, 2014: edit file, :Lex, resize window -- causes refresh.  Reinstated a modified test.  See if problems develop.
    if v:mouse_col > virtcol('.')
        let @@= ykeep
        return
    endif

    if a:islocal
        if exists("b:netrw_curdir")
            NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,s:NetrwGetWord(),1))
        endif
    else
        if exists("b:netrw_curdir")
            NetrwKeepj call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,s:NetrwGetWord(),1))
        endif
    endif
    let @@= ykeep
endfunction

" s:NetrwCLeftmouse: used to select a file/directory for a target {{{2
function s:NetrwCLeftmouse(islocal)
    if &ft != "netrw"
        return
    endif
    call s:NetrwMarkFileTgt(a:islocal)
endfunction

" s:NetrwServerEdit: edit file in a server gvim, usually NETRWSERVER  (implements <c-r>){{{2
"   a:islocal=0 : <c-r> not used, remote
"   a:islocal=1 : <c-r> not used, local
"   a:islocal=2 : <c-r>     used, remote
"   a:islocal=3 : <c-r>     used, local
function s:NetrwServerEdit(islocal,fname)
    let islocal = a:islocal%2      " =0: remote           =1: local
    let ctrlr   = a:islocal >= 2   " =0: <c-r> not used   =1: <c-r> used

    if (islocal && isdirectory(s:NetrwFile(a:fname))) || (!islocal && a:fname =~ '/$')
        " handle directories in the local window -- not in the remote vim server
        " user must have closed the NETRWSERVER window.  Treat as normal editing from netrw.
        let g:netrw_browse_split= 0
        if exists("s:netrw_browse_split") && exists("s:netrw_browse_split_".winnr())
            let g:netrw_browse_split= s:netrw_browse_split_{winnr()}
            unlet s:netrw_browse_split_{winnr()}
        endif
        call s:NetrwBrowse(islocal,s:NetrwBrowseChgDir(islocal,a:fname,0))
        return
    endif

    if has("clientserver") && executable("gvim")

        if exists("g:netrw_browse_split") && type(g:netrw_browse_split) == 3
            let srvrname = g:netrw_browse_split[0]
            let tabnum   = g:netrw_browse_split[1]
            let winnum   = g:netrw_browse_split[2]

            if serverlist() !~ '\<'.srvrname.'\>'
                if !ctrlr
                    " user must have closed the server window and the user did not use <c-r>, but
                    " used something like <cr>.
                    if exists("g:netrw_browse_split")
                        unlet g:netrw_browse_split
                    endif
                    let g:netrw_browse_split= 0
                    if exists("s:netrw_browse_split_".winnr())
                        let g:netrw_browse_split= s:netrw_browse_split_{winnr()}
                    endif
                    call s:NetrwBrowseChgDir(islocal,a:fname,0)
                    return

                elseif has("win32") && executable("start")
                    " start up remote netrw server under windows
                    call system("start gvim --servername ".srvrname)

                else
                    " start up remote netrw server under linux
                    call system("gvim --servername ".srvrname)
                endif
            endif

            call remote_send(srvrname,":tabn ".tabnum."\<cr>")
            call remote_send(srvrname,":".winnum."wincmd w\<cr>")
            call remote_send(srvrname,":e ".fnameescape(s:NetrwFile(a:fname))."\<cr>")
        else

            if serverlist() !~ '\<'.g:netrw_servername.'\>'

                if !ctrlr
                    if exists("g:netrw_browse_split")
                        unlet g:netrw_browse_split
                    endif
                    let g:netrw_browse_split= 0
                    call s:NetrwBrowse(islocal,s:NetrwBrowseChgDir(islocal,a:fname,0))
                    return

                else
                    if has("win32") && executable("start")
                        " start up remote netrw server under windows
                        call system("start gvim --servername ".g:netrw_servername)
                    else
                        " start up remote netrw server under linux
                        call system("gvim --servername ".g:netrw_servername)
                    endif
                endif
            endif

            while 1
                try
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

endfunction

" s:NetrwSLeftmouse: marks the file under the cursor.  May be dragged to select additional files {{{2
function s:NetrwSLeftmouse(islocal)
    if &ft != "netrw"
        return
    endif

    let s:ngw= s:NetrwGetWord()
    call s:NetrwMarkFile(a:islocal,s:ngw)

endfunction

" s:NetrwSLeftdrag: invoked via a shift-leftmouse and dragging {{{2
"                   Used to mark multiple files.
function s:NetrwSLeftdrag(islocal)
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
endfunction

" s:NetrwSLeftrelease: terminates shift-leftmouse dragging {{{2
function s:NetrwSLeftrelease(islocal)
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
endfunction

" s:NetrwListHide: uses [range]g~...~d to delete files that match       {{{2
"                  comma-separated patterns given in g:netrw_list_hide
function s:NetrwListHide()
    let ykeep= @@

    " find a character not in the "hide" string to use as a separator for :g and :v commands
    " How-it-works: take the hiding command, convert it into a range.
    " Duplicate characters don't matter.
    " Remove all such characters from the '/~@#...890' string.
    " Use the first character left as a separator character.
    let listhide= g:netrw_list_hide
    let sep     = strpart(substitute('~@#$%^&*{};:,<.>?|1234567890','['.escape(listhide,'-]^\').']','','ge'),1,1)

    while listhide != ""
        if listhide =~ ','
            let hide     = substitute(listhide,',.*$','','e')
            let listhide = substitute(listhide,'^.\{-},\(.*\)$','\1','e')
        else
            let hide     = listhide
            let listhide = ""
        endif
        if g:netrw_sort_by =~ '^[ts]'
            if hide =~ '^\^'
                let hide= substitute(hide,'^\^','^\(\\d\\+/\)','')
            elseif hide =~ '^\\(\^'
                let hide= substitute(hide,'^\\(\^','\\(^\\(\\d\\+/\\)','')
            endif
        endif

        " Prune the list by hiding any files which match
        if g:netrw_hide == 1
            exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$g'.sep.hide.sep.'d'
        elseif g:netrw_hide == 2
            exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$g'.sep.hide.sep.'s@^@ /-KEEP-/ @'
        endif
    endwhile

    if g:netrw_hide == 2
        exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$v@^ /-KEEP-/ @d'
        exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s@^\%( /-KEEP-/ \)\+@@e'
    endif

    " remove any blank lines that have somehow remained.
    " This seems to happen under Windows.
    exe 'sil! NetrwKeepj 1,$g@^\s*$@d'

    let @@= ykeep
endfunction

" s:NetrwMakeDir: this function makes a directory (both local and remote) {{{2
"                 implements the "d" mapping.
function s:NetrwMakeDir(usrhost)

    let ykeep= @@
    " get name of new directory from user.  A bare <CR> will skip.
    " if its currently a directory, also request will be skipped, but with
    " a message.
    call inputsave()
    let newdirname= input("Please give directory name: ")
    call inputrestore()

    if newdirname == ""
        let @@= ykeep
        return
    endif

    if a:usrhost == ""

        " Local mkdir:
        " sanity checks
        let fullnewdir= b:netrw_curdir.'/'.newdirname
        if isdirectory(s:NetrwFile(fullnewdir))
            call netrw#msg#Notify('WARNING', printf('<%s> is already a directory!', newdirname))
            let @@= ykeep
            return
        endif
        if s:FileReadable(fullnewdir)
            call netrw#msg#Notify('WARNING', printf('<%s> is already a file!', newdirname))
            let @@= ykeep
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
            let netrw_origdir= netrw#fs#Cwd(1)
            if s:NetrwLcd(b:netrw_curdir)
                return
            endif
            call netrw#os#Execute("sil! !".g:netrw_localmkdir.g:netrw_localmkdiropt.' '.netrw#os#Escape(newdirname,1))
            if v:shell_error != 0
                let @@= ykeep
                call netrw#msg#Notify('ERROR', printf('consider setting g:netrw_localmkdir<%s> to something that works', g:netrw_localmkdir))
                return
            endif
            if !g:netrw_keepdir
                if s:NetrwLcd(netrw_origdir)
                    return
                endif
            endif
        endif

        if v:shell_error == 0
            " refresh listing
            let svpos= winsaveview()
            call s:NetrwRefresh(1,s:NetrwBrowseChgDir(1,'./',0))
            call winrestview(svpos)
        else
            call netrw#msg#Notify('ERROR', printf('unable to make directory<%s>', newdirname))
        endif

    elseif !exists("b:netrw_method") || b:netrw_method == 4
        " Remote mkdir:  using ssh
        let mkdircmd  = s:MakeSshCmd(g:netrw_mkdir_cmd)
        let newdirname= substitute(b:netrw_curdir,'^\%(.\{-}/\)\{3}\(.*\)$','\1','').newdirname
        call netrw#os#Execute("sil! !".mkdircmd." ".netrw#os#Escape(newdirname,1))
        if v:shell_error == 0
            " refresh listing
            let svpos= winsaveview()
            NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./',0))
            NetrwKeepj call winrestview(svpos)
        else
            call netrw#msg#Notify('ERROR', printf('unable to make directory<%s>', newdirname))
        endif

    elseif b:netrw_method == 2
        " Remote mkdir:  using ftp+.netrc
        let svpos= winsaveview()
        if exists("b:netrw_fname")
            let remotepath= b:netrw_fname
        else
            let remotepath= ""
        endif
        call s:NetrwRemoteFtpCmd(remotepath,g:netrw_remote_mkdir.' "'.newdirname.'"')
        NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./',0))
        NetrwKeepj call winrestview(svpos)

    elseif b:netrw_method == 3
        " Remote mkdir: using ftp + machine, id, passwd, and fname (ie. no .netrc)
        let svpos= winsaveview()
        if exists("b:netrw_fname")
            let remotepath= b:netrw_fname
        else
            let remotepath= ""
        endif
        call s:NetrwRemoteFtpCmd(remotepath,g:netrw_remote_mkdir.' "'.newdirname.'"')
        NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./',0))
        NetrwKeepj call winrestview(svpos)
    endif

    let @@= ykeep
endfunction

" s:TreeSqueezeDir: allows a shift-cr (gvim only) to squeeze the current tree-listing directory {{{2
function s:TreeSqueezeDir(islocal)
    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
        " its a tree-listing style
        let curdepth = substitute(getline('.'),'^\(\%('.s:treedepthstring.'\)*\)[^'.s:treedepthstring.'].\{-}$','\1','e')
        let stopline = (exists("w:netrw_bannercnt")? (w:netrw_bannercnt + 1) : 1)
        let depth    = strchars(substitute(curdepth,' ','','g'))
        let srch     = -1
        if depth >= 2
            NetrwKeepj norm! 0
            let curdepthm1= substitute(curdepth,'^'.s:treedepthstring,'','')
            let srch      = search('^'.curdepthm1.'\%('.s:treedepthstring.'\)\@!','bW',stopline)
        elseif depth == 1
            NetrwKeepj norm! 0
            let treedepthchr= substitute(s:treedepthstring,' ','','')
            let srch        = search('^[^'.treedepthchr.']','bW',stopline)
        endif
        if srch > 0
            call s:NetrwBrowse(a:islocal,s:NetrwBrowseChgDir(a:islocal,s:NetrwGetWord(),1))
            exe srch
        endif
    endif
endfunction

" s:NetrwMaps: {{{2
function s:NetrwMaps(islocal)

    " mouse <Plug> maps: {{{3
    if g:netrw_mousemaps && g:netrw_retmap
        if !hasmapto("<Plug>NetrwReturn")
            if maparg("<2-leftmouse>","n") == "" || maparg("<2-leftmouse>","n") =~ '^-$'
                nmap <unique> <silent> <2-leftmouse>       <Plug>NetrwReturn
            elseif maparg("<c-leftmouse>","n") == ""
                nmap <unique> <silent> <c-leftmouse>       <Plug>NetrwReturn
            endif
        endif
        nno <silent> <Plug>NetrwReturn       :Rexplore<cr>
    endif

    " generate default <Plug> maps {{{3
    if !hasmapto('<Plug>NetrwHide')              |nmap <buffer> <silent> <nowait> a       <Plug>NetrwHide_a|endif
    if !hasmapto('<Plug>NetrwBrowseUpDir')       |nmap <buffer> <silent> <nowait> -       <Plug>NetrwBrowseUpDir|endif
    if !hasmapto('<Plug>NetrwOpenFile')          |nmap <buffer> <silent> <nowait> %       <Plug>NetrwOpenFile|endif
    if !hasmapto('<Plug>NetrwBadd_cb')           |nmap <buffer> <silent> <nowait> cb      <Plug>NetrwBadd_cb|endif
    if !hasmapto('<Plug>NetrwBadd_cB')           |nmap <buffer> <silent> <nowait> cB      <Plug>NetrwBadd_cB|endif
    if !hasmapto('<Plug>NetrwLcd')               |nmap <buffer> <silent> <nowait> cd      <Plug>NetrwLcd|endif
    if !hasmapto('<Plug>NetrwSetChgwin')         |nmap <buffer> <silent> <nowait> C       <Plug>NetrwSetChgwin|endif
    if !hasmapto('<Plug>NetrwRefresh')           |nmap <buffer> <silent> <nowait> <c-l>   <Plug>NetrwRefresh|endif
    if !hasmapto('<Plug>NetrwLocalBrowseCheck')  |nmap <buffer> <silent> <nowait> <cr>    <Plug>NetrwLocalBrowseCheck|endif
    if !hasmapto('<Plug>NetrwServerEdit')        |nmap <buffer> <silent> <nowait> <c-r>   <Plug>NetrwServerEdit|endif
    if !hasmapto('<Plug>NetrwMakeDir')           |nmap <buffer> <silent> <nowait> d       <Plug>NetrwMakeDir|endif
    if !hasmapto('<Plug>NetrwBookHistHandler_gb')|nmap <buffer> <silent> <nowait> gb      <Plug>NetrwBookHistHandler_gb|endif

    if a:islocal
        " local normal-mode maps {{{3
        nnoremap <buffer> <silent> <Plug>NetrwHide_a                 :<c-u>call <SID>NetrwHide(1)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwBrowseUpDir            :<c-u>call <SID>NetrwBrowseUpDir(1)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwOpenFile               :<c-u>call <SID>NetrwOpenFile(1)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwBadd_cb                :<c-u>call <SID>NetrwBadd(1,0)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwBadd_cB                :<c-u>call <SID>NetrwBadd(1,1)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwLcd                    :<c-u>call <SID>NetrwLcd(b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwSetChgwin              :<c-u>call <SID>NetrwSetChgwin()<cr>
        nnoremap <buffer> <silent> <Plug>NetrwLocalBrowseCheck       :<c-u>call netrw#LocalBrowseCheck(<SID>NetrwBrowseChgDir(1,<SID>NetrwGetWord(),1))<cr>
        nnoremap <buffer> <silent> <Plug>NetrwServerEdit             :<c-u>call <SID>NetrwServerEdit(3,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <Plug>NetrwMakeDir                :<c-u>call <SID>NetrwMakeDir("")<cr>
        nnoremap <buffer> <silent> <Plug>NetrwBookHistHandler_gb     :<c-u>call <SID>NetrwBookHistHandler(1,b:netrw_curdir)<cr>
        " ---------------------------------------------------------------------
        nnoremap <buffer> <silent> <nowait> gd       :<c-u>call <SID>NetrwForceChgDir(1,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <nowait> gf       :<c-u>call <SID>NetrwForceFile(1,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <nowait> gh       :<c-u>call <SID>NetrwHidden(1)<cr>
        nnoremap <buffer> <silent> <nowait> gn       :<c-u>call netrw#SetTreetop(0,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <nowait> gp       :<c-u>call <SID>NetrwChgPerm(1,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> I        :<c-u>call <SID>NetrwBannerCtrl(1)<cr>
        nnoremap <buffer> <silent> <nowait> i        :<c-u>call <SID>NetrwListStyle(1)<cr>
        nnoremap <buffer> <silent> <nowait> ma       :<c-u>call <SID>NetrwMarkFileArgList(1,0)<cr>
        nnoremap <buffer> <silent> <nowait> mA       :<c-u>call <SID>NetrwMarkFileArgList(1,1)<cr>
        nnoremap <buffer> <silent> <nowait> mb       :<c-u>call <SID>NetrwBookHistHandler(0,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> mB       :<c-u>call <SID>NetrwBookHistHandler(6,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> mc       :<c-u>call <SID>NetrwMarkFileCopy(1)<cr>
        nnoremap <buffer> <silent> <nowait> md       :<c-u>call <SID>NetrwMarkFileDiff(1)<cr>
        nnoremap <buffer> <silent> <nowait> me       :<c-u>call <SID>NetrwMarkFileEdit(1)<cr>
        nnoremap <buffer> <silent> <nowait> mf       :<c-u>call <SID>NetrwMarkFile(1,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <nowait> mF       :<c-u>call <SID>NetrwUnmarkList(bufnr("%"),b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> mg       :<c-u>call <SID>NetrwMarkFileGrep(1)<cr>
        nnoremap <buffer> <silent> <nowait> mh       :<c-u>call <SID>NetrwMarkHideSfx(1)<cr>
        nnoremap <buffer> <silent> <nowait> mm       :<c-u>call <SID>NetrwMarkFileMove(1)<cr>
        nnoremap <buffer> <silent> <nowait> mr       :<c-u>call <SID>NetrwMarkFileRegexp(1)<cr>
        nnoremap <buffer> <silent> <nowait> ms       :<c-u>call <SID>NetrwMarkFileSource(1)<cr>
        nnoremap <buffer> <silent> <nowait> mT       :<c-u>call <SID>NetrwMarkFileTag(1)<cr>
        nnoremap <buffer> <silent> <nowait> mt       :<c-u>call <SID>NetrwMarkFileTgt(1)<cr>
        nnoremap <buffer> <silent> <nowait> mu       :<c-u>call <SID>NetrwUnMarkFile(1)<cr>
        nnoremap <buffer> <silent> <nowait> mv       :<c-u>call <SID>NetrwMarkFileVimCmd(1)<cr>
        nnoremap <buffer> <silent> <nowait> mx       :<c-u>call <SID>NetrwMarkFileExe(1,0)<cr>
        nnoremap <buffer> <silent> <nowait> mX       :<c-u>call <SID>NetrwMarkFileExe(1,1)<cr>
        nnoremap <buffer> <silent> <nowait> mz       :<c-u>call <SID>NetrwMarkFileCompress(1)<cr>
        nnoremap <buffer> <silent> <nowait> O        :<c-u>call <SID>NetrwObtain(1)<cr>
        nnoremap <buffer> <silent> <nowait> o        :call <SID>NetrwSplit(3)<cr>
        nnoremap <buffer> <silent> <nowait> p        :<c-u>call <SID>NetrwPreview(<SID>NetrwBrowseChgDir(1,<SID>NetrwGetWord(),1,1))<cr>
        nnoremap <buffer> <silent> <nowait> P        :<c-u>call <SID>NetrwPrevWinOpen(1)<cr>
        nnoremap <buffer> <silent> <nowait> qb       :<c-u>call <SID>NetrwBookHistHandler(2,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> qf       :<c-u>call <SID>NetrwFileInfo(1,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <nowait> qF       :<c-u>call <SID>NetrwMarkFileQFEL(1,getqflist())<cr>
        nnoremap <buffer> <silent> <nowait> qL       :<c-u>call <SID>NetrwMarkFileQFEL(1,getloclist(v:count))<cr>
        nnoremap <buffer> <silent> <nowait> s        :call <SID>NetrwSortStyle(1)<cr>
        nnoremap <buffer> <silent> <nowait> S        :<c-u>call <SID>NetSortSequence(1)<cr>
        nnoremap <buffer> <silent> <nowait> Tb       :<c-u>call <SID>NetrwSetTgt(1,'b',v:count1)<cr>
        nnoremap <buffer> <silent> <nowait> t        :call <SID>NetrwSplit(4)<cr>
        nnoremap <buffer> <silent> <nowait> Th       :<c-u>call <SID>NetrwSetTgt(1,'h',v:count)<cr>
        nnoremap <buffer> <silent> <nowait> u        :<c-u>call <SID>NetrwBookHistHandler(4,expand("%"))<cr>
        nnoremap <buffer> <silent> <nowait> U        :<c-u>call <SID>NetrwBookHistHandler(5,expand("%"))<cr>
        nnoremap <buffer> <silent> <nowait> v        :call <SID>NetrwSplit(5)<cr>
        nnoremap <buffer> <silent> <nowait> x        :<c-u>call netrw#BrowseX(<SID>NetrwBrowseChgDir(1,<SID>NetrwGetWord(),1,0))"<cr>
        nnoremap <buffer> <silent> <nowait> X        :<c-u>call <SID>NetrwLocalExecute(expand("<cword>"))"<cr>

        nnoremap <buffer> <silent> <nowait> r        :<c-u>let g:netrw_sort_direction= (g:netrw_sort_direction =~# 'n')? 'r' : 'n'<bar>exe "norm! 0"<bar>call <SID>NetrwRefresh(1,<SID>NetrwBrowseChgDir(1,'./',0))<cr>
        if !hasmapto('<Plug>NetrwHideEdit')
            nmap <buffer> <unique> <c-h> <Plug>NetrwHideEdit
        endif
        nnoremap <buffer> <silent> <Plug>NetrwHideEdit               :call <SID>NetrwHideEdit(1)<cr>
        if !hasmapto('<Plug>NetrwRefresh')
            nmap <buffer> <unique> <c-l> <Plug>NetrwRefresh
        endif
        nnoremap <buffer> <silent> <Plug>NetrwRefresh                <c-l>:call <SID>NetrwRefresh(1,<SID>NetrwBrowseChgDir(1,(exists("w:netrw_liststyle") && exists("w:netrw_treetop") && w:netrw_liststyle == 3)? w:netrw_treetop : './',0))<cr>
        if s:didstarstar || !mapcheck("<s-down>","n")
            nnoremap <buffer> <silent> <s-down> :Nexplore<cr>
        endif
        if s:didstarstar || !mapcheck("<s-up>","n")
            nnoremap <buffer> <silent> <s-up>   :Pexplore<cr>
        endif
        if !hasmapto('<Plug>NetrwTreeSqueeze')
            nmap <buffer> <silent> <nowait> <s-cr>                      <Plug>NetrwTreeSqueeze
        endif
        nnoremap <buffer> <silent> <Plug>NetrwTreeSqueeze            :call <SID>TreeSqueezeDir(1)<cr>
        let mapsafecurdir = escape(b:netrw_curdir, s:netrw_map_escape)
        if g:netrw_mousemaps == 1
            nmap <buffer>                       <leftmouse>             <Plug>NetrwLeftmouse
            nmap <buffer>                       <c-leftmouse>           <Plug>NetrwCLeftmouse
            nmap <buffer>                       <middlemouse>           <Plug>NetrwMiddlemouse
            nmap <buffer>                       <s-leftmouse>           <Plug>NetrwSLeftmouse
            nmap <buffer>                       <s-leftdrag>            <Plug>NetrwSLeftdrag
            nmap <buffer>                       <2-leftmouse>           <Plug>Netrw2Leftmouse
            imap <buffer>                       <leftmouse>             <Plug>ILeftmouse
            imap <buffer>                       <middlemouse>           <Plug>IMiddlemouse
            nno  <buffer> <silent>              <Plug>NetrwLeftmouse    :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwLeftmouse(1)<cr>
            nno  <buffer> <silent>              <Plug>NetrwCLeftmouse   :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwCLeftmouse(1)<cr>
            nno  <buffer> <silent>              <Plug>NetrwMiddlemouse  :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwPrevWinOpen(1)<cr>
            nno  <buffer> <silent>              <Plug>NetrwSLeftmouse   :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwSLeftmouse(1)<cr>
            nno  <buffer> <silent>              <Plug>NetrwSLeftdrag    :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwSLeftdrag(1)<cr>
            nmap <buffer> <silent>              <Plug>Netrw2Leftmouse   -
                exe 'nnoremap <buffer> <silent> <rightmouse>  :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
            exe 'vnoremap <buffer> <silent> <rightmouse>  :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
        endif
        exe 'nnoremap <buffer> <silent> <nowait> <del>       :call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
        exe 'nnoremap <buffer> <silent> <nowait> D           :call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
        exe 'nnoremap <buffer> <silent> <nowait> R           :call <SID>NetrwLocalRename("'.mapsafecurdir.'")<cr>'
        exe 'nnoremap <buffer> <silent> <nowait> d           :call <SID>NetrwMakeDir("")<cr>'
        exe 'vnoremap <buffer> <silent> <nowait> <del>       :call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
        exe 'vnoremap <buffer> <silent> <nowait> D           :call <SID>NetrwLocalRm("'.mapsafecurdir.'")<cr>'
        exe 'vnoremap <buffer> <silent> <nowait> R           :call <SID>NetrwLocalRename("'.mapsafecurdir.'")<cr>'
        nnoremap <buffer> <F1>                       :he netrw-quickhelp<cr>

        " support user-specified maps
        call netrw#UserMaps(1)

    else
        " remote normal-mode maps {{{3
        call s:RemotePathAnalysis(b:netrw_curdir)
        nnoremap <buffer> <silent> <Plug>NetrwHide_a                 :<c-u>call <SID>NetrwHide(0)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwBrowseUpDir            :<c-u>call <SID>NetrwBrowseUpDir(0)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwOpenFile               :<c-u>call <SID>NetrwOpenFile(0)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwBadd_cb                :<c-u>call <SID>NetrwBadd(0,0)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwBadd_cB                :<c-u>call <SID>NetrwBadd(0,1)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwLcd                    :<c-u>call <SID>NetrwLcd(b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <Plug>NetrwSetChgwin              :<c-u>call <SID>NetrwSetChgwin()<cr>
        nnoremap <buffer> <silent> <Plug>NetrwRefresh                :<c-u>call <SID>NetrwRefresh(0,<SID>NetrwBrowseChgDir(0,'./',0))<cr>
        nnoremap <buffer> <silent> <Plug>NetrwLocalBrowseCheck       :<c-u>call <SID>NetrwBrowse(0,<SID>NetrwBrowseChgDir(0,<SID>NetrwGetWord(),1))<cr>
        nnoremap <buffer> <silent> <Plug>NetrwServerEdit             :<c-u>call <SID>NetrwServerEdit(2,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <Plug>NetrwBookHistHandler_gb     :<c-u>call <SID>NetrwBookHistHandler(1,b:netrw_curdir)<cr>
        " ---------------------------------------------------------------------
        nnoremap <buffer> <silent> <nowait> gd       :<c-u>call <SID>NetrwForceChgDir(0,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <nowait> gf       :<c-u>call <SID>NetrwForceFile(0,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <nowait> gh       :<c-u>call <SID>NetrwHidden(0)<cr>
        nnoremap <buffer> <silent> <nowait> gp       :<c-u>call <SID>NetrwChgPerm(0,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> I        :<c-u>call <SID>NetrwBannerCtrl(1)<cr>
        nnoremap <buffer> <silent> <nowait> i        :<c-u>call <SID>NetrwListStyle(0)<cr>
        nnoremap <buffer> <silent> <nowait> ma       :<c-u>call <SID>NetrwMarkFileArgList(0,0)<cr>
        nnoremap <buffer> <silent> <nowait> mA       :<c-u>call <SID>NetrwMarkFileArgList(0,1)<cr>
        nnoremap <buffer> <silent> <nowait> mb       :<c-u>call <SID>NetrwBookHistHandler(0,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> mB       :<c-u>call <SID>NetrwBookHistHandler(6,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> mc       :<c-u>call <SID>NetrwMarkFileCopy(0)<cr>
        nnoremap <buffer> <silent> <nowait> md       :<c-u>call <SID>NetrwMarkFileDiff(0)<cr>
        nnoremap <buffer> <silent> <nowait> me       :<c-u>call <SID>NetrwMarkFileEdit(0)<cr>
        nnoremap <buffer> <silent> <nowait> mf       :<c-u>call <SID>NetrwMarkFile(0,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <nowait> mF       :<c-u>call <SID>NetrwUnmarkList(bufnr("%"),b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> mg       :<c-u>call <SID>NetrwMarkFileGrep(0)<cr>
        nnoremap <buffer> <silent> <nowait> mh       :<c-u>call <SID>NetrwMarkHideSfx(0)<cr>
        nnoremap <buffer> <silent> <nowait> mm       :<c-u>call <SID>NetrwMarkFileMove(0)<cr>
        nnoremap <buffer> <silent> <nowait> mr       :<c-u>call <SID>NetrwMarkFileRegexp(0)<cr>
        nnoremap <buffer> <silent> <nowait> ms       :<c-u>call <SID>NetrwMarkFileSource(0)<cr>
        nnoremap <buffer> <silent> <nowait> mT       :<c-u>call <SID>NetrwMarkFileTag(0)<cr>
        nnoremap <buffer> <silent> <nowait> mt       :<c-u>call <SID>NetrwMarkFileTgt(0)<cr>
        nnoremap <buffer> <silent> <nowait> mu       :<c-u>call <SID>NetrwUnMarkFile(0)<cr>
        nnoremap <buffer> <silent> <nowait> mv       :<c-u>call <SID>NetrwMarkFileVimCmd(0)<cr>
        nnoremap <buffer> <silent> <nowait> mx       :<c-u>call <SID>NetrwMarkFileExe(0,0)<cr>
        nnoremap <buffer> <silent> <nowait> mX       :<c-u>call <SID>NetrwMarkFileExe(0,1)<cr>
        nnoremap <buffer> <silent> <nowait> mz       :<c-u>call <SID>NetrwMarkFileCompress(0)<cr>
        nnoremap <buffer> <silent> <nowait> O        :<c-u>call <SID>NetrwObtain(0)<cr>
        nnoremap <buffer> <silent> <nowait> o        :call <SID>NetrwSplit(0)<cr>
        nnoremap <buffer> <silent> <nowait> p        :<c-u>call <SID>NetrwPreview(<SID>NetrwBrowseChgDir(1,<SID>NetrwGetWord(),1,1))<cr>
        nnoremap <buffer> <silent> <nowait> P        :<c-u>call <SID>NetrwPrevWinOpen(0)<cr>
        nnoremap <buffer> <silent> <nowait> qb       :<c-u>call <SID>NetrwBookHistHandler(2,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> qf       :<c-u>call <SID>NetrwFileInfo(0,<SID>NetrwGetWord())<cr>
        nnoremap <buffer> <silent> <nowait> qF       :<c-u>call <SID>NetrwMarkFileQFEL(0,getqflist())<cr>
        nnoremap <buffer> <silent> <nowait> qL       :<c-u>call <SID>NetrwMarkFileQFEL(0,getloclist(v:count))<cr>
        nnoremap <buffer> <silent> <nowait> r        :<c-u>let g:netrw_sort_direction= (g:netrw_sort_direction =~# 'n')? 'r' : 'n'<bar>exe "norm! 0"<bar>call <SID>NetrwBrowse(0,<SID>NetrwBrowseChgDir(0,'./',0))<cr>
        nnoremap <buffer> <silent> <nowait> s        :call <SID>NetrwSortStyle(0)<cr>
        nnoremap <buffer> <silent> <nowait> S        :<c-u>call <SID>NetSortSequence(0)<cr>
        nnoremap <buffer> <silent> <nowait> Tb       :<c-u>call <SID>NetrwSetTgt(0,'b',v:count1)<cr>
        nnoremap <buffer> <silent> <nowait> t        :call <SID>NetrwSplit(1)<cr>
        nnoremap <buffer> <silent> <nowait> Th       :<c-u>call <SID>NetrwSetTgt(0,'h',v:count)<cr>
        nnoremap <buffer> <silent> <nowait> u        :<c-u>call <SID>NetrwBookHistHandler(4,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> U        :<c-u>call <SID>NetrwBookHistHandler(5,b:netrw_curdir)<cr>
        nnoremap <buffer> <silent> <nowait> v        :call <SID>NetrwSplit(2)<cr>
        if !hasmapto('<Plug>NetrwHideEdit')
            nmap <buffer> <c-h> <Plug>NetrwHideEdit
        endif
        nnoremap <buffer> <silent> <Plug>NetrwHideEdit       :call <SID>NetrwHideEdit(0)<cr>
        if !hasmapto('<Plug>NetrwRefresh')
            nmap <buffer> <c-l> <Plug>NetrwRefresh
        endif
        if !hasmapto('<Plug>NetrwTreeSqueeze')
            nmap <buffer> <silent> <nowait> <s-cr>      <Plug>NetrwTreeSqueeze
        endif
        nnoremap <buffer> <silent> <Plug>NetrwTreeSqueeze    :call <SID>TreeSqueezeDir(0)<cr>

        let mapsafepath     = escape(s:path, s:netrw_map_escape)
        let mapsafeusermach = escape(((s:user == "")? "" : s:user."@").s:machine, s:netrw_map_escape)

        nnoremap <buffer> <silent> <Plug>NetrwRefresh        :call <SID>NetrwRefresh(0,<SID>NetrwBrowseChgDir(0,'./',0))<cr>
        if g:netrw_mousemaps == 1
            nmap <buffer> <leftmouse>           <Plug>NetrwLeftmouse
            nno  <buffer> <silent>              <Plug>NetrwLeftmouse    :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwLeftmouse(0)<cr>
            nmap <buffer> <c-leftmouse>         <Plug>NetrwCLeftmouse
            nno  <buffer> <silent>              <Plug>NetrwCLeftmouse   :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwCLeftmouse(0)<cr>
            nmap <buffer> <s-leftmouse>         <Plug>NetrwSLeftmouse
            nno  <buffer> <silent>              <Plug>NetrwSLeftmouse   :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwSLeftmouse(0)<cr>
            nmap <buffer> <s-leftdrag>          <Plug>NetrwSLeftdrag
            nno  <buffer> <silent>              <Plug>NetrwSLeftdrag    :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwSLeftdrag(0)<cr>
            nmap <middlemouse>                  <Plug>NetrwMiddlemouse
            nno  <buffer> <silent>              <middlemouse>           <Plug>NetrwMiddlemouse :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwPrevWinOpen(0)<cr>
            nmap <buffer> <2-leftmouse>         <Plug>Netrw2Leftmouse
            nmap <buffer> <silent>              <Plug>Netrw2Leftmouse   -
                imap <buffer> <leftmouse>           <Plug>ILeftmouse
            imap <buffer> <middlemouse>         <Plug>IMiddlemouse
            imap <buffer> <s-leftmouse>         <Plug>ISLeftmouse
            exe 'nnoremap <buffer> <silent> <rightmouse> :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
            exe 'vnoremap <buffer> <silent> <rightmouse> :exec "norm! \<lt>leftmouse>"<bar>call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
        endif
        exe 'nnoremap <buffer> <silent> <nowait> <del>       :call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
        exe 'nnoremap <buffer> <silent> <nowait> d           :call <SID>NetrwMakeDir("'.mapsafeusermach.'")<cr>'
        exe 'nnoremap <buffer> <silent> <nowait> D           :call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
        exe 'nnoremap <buffer> <silent> <nowait> R           :call <SID>NetrwRemoteRename("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
        exe 'vnoremap <buffer> <silent> <nowait> <del>       :call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
        exe 'vnoremap <buffer> <silent> <nowait> D           :call <SID>NetrwRemoteRm("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
        exe 'vnoremap <buffer> <silent> <nowait> R           :call <SID>NetrwRemoteRename("'.mapsafeusermach.'","'.mapsafepath.'")<cr>'
        nnoremap <buffer> <F1>                       :he netrw-quickhelp<cr>

        " support user-specified maps
        call netrw#UserMaps(0)
    endif " }}}3
endfunction

" s:NetrwCommands: set up commands                              {{{2
"  If -buffer, the command is only available from within netrw buffers
"  Otherwise, the command is available from any window, so long as netrw
"  has been used at least once in the session.
function s:NetrwCommands(islocal)

    com! -nargs=* -complete=file -bang    NetrwMB call s:NetrwBookmark(<bang>0,<f-args>)
    com! -nargs=*                         NetrwC  call s:NetrwSetChgwin(<q-args>)
    com! Rexplore if exists("w:netrw_rexlocal")|call s:NetrwRexplore(w:netrw_rexlocal,exists("w:netrw_rexdir")? w:netrw_rexdir : ".")|else|call netrw#msg#Notify('WARNING', "win#".winnr()." not a former netrw window")|endif
    if a:islocal
        com! -buffer -nargs=+ -complete=file MF      call s:NetrwMarkFiles(1,<f-args>)
    else
        com! -buffer -nargs=+ -complete=file MF      call s:NetrwMarkFiles(0,<f-args>)
    endif
    com! -buffer -nargs=? -complete=file  MT      call s:NetrwMarkTarget(<q-args>)

endfunction

" s:NetrwMarkFiles: apply s:NetrwMarkFile() to named file(s) {{{2
"                   glob()ing only works with local files
function s:NetrwMarkFiles(islocal,...)
    let curdir = s:NetrwGetCurdir(a:islocal)
    let i      = 1
    while i <= a:0
        if a:islocal
            let mffiles= glob(a:{i}, 0, 1, 1)
        else
            let mffiles= [a:{i}]
        endif
        for mffile in mffiles
            call s:NetrwMarkFile(a:islocal,mffile)
        endfor
        let i= i + 1
    endwhile
endfunction

" s:NetrwMarkTarget: implements :MT (mark target) {{{2
function s:NetrwMarkTarget(...)
    if a:0 == 0 || (a:0 == 1 && a:1 == "")
        let curdir = s:NetrwGetCurdir(1)
        let tgt    = b:netrw_curdir
    else
        let curdir = s:NetrwGetCurdir((a:1 =~ '^\a\{3,}://')? 0 : 1)
        let tgt    = a:1
    endif
    let s:netrwmftgt         = tgt
    let s:netrwmftgt_islocal = tgt !~ '^\a\{3,}://'
    let curislocal           = b:netrw_curdir !~ '^\a\{3,}://'
    let svpos                = winsaveview()
    call s:NetrwRefresh(curislocal,s:NetrwBrowseChgDir(curislocal,'./',0))
    call winrestview(svpos)
endfunction

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
function s:NetrwMarkFile(islocal,fname)

    " sanity check
    if empty(a:fname)
        return
    endif
    let curdir = s:NetrwGetCurdir(a:islocal)

    let ykeep   = @@
    let curbufnr= bufnr("%")
    let leader= '\%(^\|\s\)\zs'
    if a:fname =~ '\a$'
        let trailer = '\>[@=|\/\*]\=\ze\%(  \|\t\|$\)'
    else
        let trailer = '[@=|\/\*]\=\ze\%(  \|\t\|$\)'
    endif

    if exists("s:netrwmarkfilelist_".curbufnr)
        " markfile list pre-exists
        let b:netrw_islocal= a:islocal

        if index(s:netrwmarkfilelist_{curbufnr},a:fname) == -1
            " append filename to buffer's markfilelist
            call add(s:netrwmarkfilelist_{curbufnr},a:fname)
            let s:netrwmarkfilemtch_{curbufnr}= s:netrwmarkfilemtch_{curbufnr}.'\|'.leader.escape(a:fname,g:netrw_markfileesc).trailer

        else
            " remove filename from buffer's markfilelist
            call filter(s:netrwmarkfilelist_{curbufnr},'v:val != a:fname')
            if s:netrwmarkfilelist_{curbufnr} == []
                " local markfilelist is empty; remove it entirely
                call s:NetrwUnmarkList(curbufnr,curdir)
            else
                " rebuild match list to display markings correctly
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
            endif
        endif

    else
        " initialize new markfilelist

        let s:netrwmarkfilelist_{curbufnr}= []
        call add(s:netrwmarkfilelist_{curbufnr},substitute(a:fname,'[|@]$','',''))

        " build initial markfile matching pattern
        if a:fname =~ '/$'
            let s:netrwmarkfilemtch_{curbufnr}= leader.escape(a:fname,g:netrw_markfileesc)
        else
            let s:netrwmarkfilemtch_{curbufnr}= leader.escape(a:fname,g:netrw_markfileesc).trailer
        endif
    endif

    " handle global markfilelist
    if exists("s:netrwmarkfilelist")
        let dname= netrw#fs#ComposePath(b:netrw_curdir,a:fname)
        if index(s:netrwmarkfilelist,dname) == -1
            " append new filename to global markfilelist
            call add(s:netrwmarkfilelist,netrw#fs#ComposePath(b:netrw_curdir,a:fname))
        else
            " remove new filename from global markfilelist
            call filter(s:netrwmarkfilelist,'v:val != "'.dname.'"')
            if s:netrwmarkfilelist == []
                unlet s:netrwmarkfilelist
            endif
        endif
    else
        " initialize new global-directory markfilelist
        let s:netrwmarkfilelist= []
        call add(s:netrwmarkfilelist,netrw#fs#ComposePath(b:netrw_curdir,a:fname))
    endif

    " set up 2match'ing to netrwmarkfilemtch_# list
    if has("syntax") && exists("g:syntax_on") && g:syntax_on
        if exists("s:netrwmarkfilemtch_{curbufnr}") && s:netrwmarkfilemtch_{curbufnr} != ""
            if exists("g:did_drchip_netrwlist_syntax")
                exe "2match netrwMarkFile /".s:netrwmarkfilemtch_{curbufnr}."/"
            endif
        else
            2match none
        endif
    endif
    let @@= ykeep
endfunction

" s:NetrwMarkFileArgList: ma: move the marked file list to the argument list (tomflist=0) {{{2
"                         mA: move the argument list to marked file list     (tomflist=1)
"                            Uses the global marked file list
function s:NetrwMarkFileArgList(islocal,tomflist)
    let svpos    = winsaveview()
    let curdir   = s:NetrwGetCurdir(a:islocal)
    let curbufnr = bufnr("%")

    if a:tomflist
        " mA: move argument list to marked file list
        while argc()
            let fname= argv(0)
            exe "argdel ".fnameescape(fname)
            call s:NetrwMarkFile(a:islocal,fname)
        endwhile

    else
        " ma: move marked file list to argument list
        if exists("s:netrwmarkfilelist")

            " for every filename in the marked list
            for fname in s:netrwmarkfilelist
                exe "argadd ".fnameescape(fname)
            endfor      " for every file in the marked list

            " unmark list and refresh
            call s:NetrwUnmarkList(curbufnr,curdir)
            NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
            NetrwKeepj call winrestview(svpos)
        endif
    endif
endfunction

" s:NetrwMarkFileCompress: (invoked by mz) This function is used to {{{2
"                          compress/decompress files using the programs
"                          in g:netrw_compress and g:netrw_uncompress,
"                          using g:netrw_compress_suffix to know which to
"                          do.  By default:
"                            g:netrw_compress        = "gzip"
"                            g:netrw_decompress      = { ".gz" : "gunzip" , ".bz2" : "bunzip2" , ".zip" : "unzip" , ".tar" : "tar -xf", ".xz" : "unxz"}
function s:NetrwMarkFileCompress(islocal)
    let svpos    = winsaveview()
    let curdir   = s:NetrwGetCurdir(a:islocal)
    let curbufnr = bufnr("%")

    " sanity check
    if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
        call netrw#msg#Notify('ERROR', 'there are no marked files in this window (:help netrw-mf)')
        return
    endif

    if exists("s:netrwmarkfilelist_{curbufnr}") && exists("g:netrw_compress") && exists("g:netrw_decompress")

        " for every filename in the marked list
        for fname in s:netrwmarkfilelist_{curbufnr}
            let sfx= substitute(fname,'^.\{-}\(\.[[:alnum:]]\+\)$','\1','')
            if exists("g:netrw_decompress['".sfx."']")
                " fname has a suffix indicating that its compressed; apply associated decompression routine
                let exe= g:netrw_decompress[sfx]
                let exe= netrw#fs#WinPath(exe)
                if a:islocal
                    if g:netrw_keepdir
                        let fname= netrw#os#Escape(netrw#fs#ComposePath(curdir,fname))
                    endif
                    call system(exe." ".fname)
                    if v:shell_error
                        call netrw#msg#Notify('WARNING', printf('unable to apply<%s> to file<%s>', exe, fname))
                    endif
                else
                    let fname= netrw#os#Escape(b:netrw_curdir.fname,1)
                    NetrwKeepj call s:RemoteSystem(exe." ".fname)
                endif

            endif
            unlet sfx

            if exists("exe")
                unlet exe
            elseif a:islocal
                " fname not a compressed file, so compress it
                call system(netrw#fs#WinPath(g:netrw_compress)." ".netrw#os#Escape(netrw#fs#ComposePath(b:netrw_curdir,fname)))
                if v:shell_error
                    call netrw#msg#Notify('WARNING', printf('consider setting g:netrw_compress<%s> to something that works', g:netrw_compress))
                endif
            else
                " fname not a compressed file, so compress it
                NetrwKeepj call s:RemoteSystem(netrw#fs#WinPath(g:netrw_compress)." ".netrw#os#Escape(fname))
            endif
        endfor       " for every file in the marked list

        call s:NetrwUnmarkList(curbufnr,curdir)
        NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
        NetrwKeepj call winrestview(svpos)
    endif
endfunction

" s:NetrwMarkFileCopy: (invoked by mc) copy marked files to target {{{2
"                      If no marked files, then set up directory as the
"                      target.  Currently does not support copying entire
"                      directories.  Uses the local-buffer marked file list.
"                      Returns 1=success  (used by NetrwMarkFileMove())
"                              0=failure
function s:NetrwMarkFileCopy(islocal,...)

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
        call netrw#msg#Notify('ERROR', 'there are no marked files in this window (:help netrw-mf)')
        return
    endif

    if !exists("s:netrwmftgt")
        call netrw#msg#Notify('ERROR', 'your marked file target is empty! (:help netrw-mt)')
        return 0
    endif

    if a:islocal &&  s:netrwmftgt_islocal
        " Copy marked files, local directory to local directory
        if !executable(g:netrw_localcopycmd)
            call netrw#msg#Notify('ERROR', printf('g:netrw_localcopycmd<%s> not executable on your system, aborting', g:netrw_localcopycmd))
            return
        endif

        " copy marked files while within the same directory (ie. allow renaming)
        if simplify(s:netrwmftgt) ==# simplify(b:netrw_curdir)
            if len(s:netrwmarkfilelist_{bufnr('%')}) == 1
                " only one marked file
                let args    = netrw#os#Escape(b:netrw_curdir.s:netrwmarkfilelist_{bufnr('%')}[0])
                let oldname = s:netrwmarkfilelist_{bufnr('%')}[0]
            elseif a:0 == 1
                " this happens when the next case was used to recursively call s:NetrwMarkFileCopy()
                let args    = netrw#os#Escape(b:netrw_curdir.a:1)
                let oldname = a:1
            else
                " copy multiple marked files inside the same directory
                let s:recursive= 1
                for oldname in s:netrwmarkfilelist_{bufnr("%")}
                    let ret= s:NetrwMarkFileCopy(a:islocal,oldname)
                    if ret == 0
                        break
                    endif
                endfor
                unlet s:recursive
                call s:NetrwUnmarkList(curbufnr,curdir)
                return ret
            endif

            call inputsave()
            let newname= input(printf("Copy %s to: ", oldname), oldname, 'file')
            call inputrestore()

            if empty(newname)
                return 0
            endif

            let args = netrw#os#Escape(oldname)
            let tgt = netrw#os#Escape(s:netrwmftgt.'/'.newname)
        else
            let args = join(map(deepcopy(s:netrwmarkfilelist_{bufnr('%')}),"netrw#os#Escape(b:netrw_curdir.\"/\".v:val)"))
            let tgt = netrw#os#Escape(s:netrwmftgt)
        endif

        if !g:netrw_cygwin && has("win32")
            let args = substitute(args,'/','\\','g')
            let tgt = substitute(tgt, '/','\\','g')
        endif

        if args =~ "'" |let args= substitute(args,"'\\(.*\\)'",'\1','')|endif
        if tgt  =~ "'" |let tgt = substitute(tgt ,"'\\(.*\\)'",'\1','')|endif
        if args =~ '//'|let args= substitute(args,'//','/','g')|endif
        if tgt  =~ '//'|let tgt = substitute(tgt ,'//','/','g')|endif

        let copycmd = g:netrw_localcopycmd
        let copycmdopt = g:netrw_localcopycmdopt

        if isdirectory(s:NetrwFile(args))
            let copycmd = g:netrw_localcopydircmd
            let copycmdopt = g:netrw_localcopydircmdopt
            if has('win32') && !g:netrw_cygwin
                " window's xcopy doesn't copy a directory to a target properly.  Instead, it copies a directory's
                " contents to a target.  One must append the source directory name to the target to get xcopy to
                " do the right thing.
                let tgt= tgt.'\'.substitute(a:1,'^.*[\\/]','','')
            endif
        endif

        call system(printf("%s %s '%s' '%s'", copycmd, copycmdopt, args, tgt))
        if v:shell_error != 0
            if exists("b:netrw_curdir") && b:netrw_curdir != getcwd() && g:netrw_keepdir
                call netrw#msg#Notify('ERROR', printf("copy failed; perhaps due to vim's current directory<%s> not matching netrw's (%s) (see :help netrw-cd)", getcwd(), b:netrw_curdir))
            else
                call netrw#msg#Notify('ERROR', printf("tried using g:netrw_localcopycmd<%s>; it doesn't work!", g:netrw_localcopycmd))
            endif
            return 0
        endif

    elseif  a:islocal && !s:netrwmftgt_islocal
        " Copy marked files, local directory to remote directory
        NetrwKeepj call s:NetrwUpload(s:netrwmarkfilelist_{bufnr('%')},s:netrwmftgt)

    elseif !a:islocal &&  s:netrwmftgt_islocal
        " Copy marked files, remote directory to local directory
        NetrwKeepj call netrw#Obtain(a:islocal,s:netrwmarkfilelist_{bufnr('%')},s:netrwmftgt)

    elseif !a:islocal && !s:netrwmftgt_islocal
        " Copy marked files, remote directory to remote directory
        let curdir = getcwd()
        let tmpdir = s:GetTempfile("")
        if tmpdir !~ '/'
            let tmpdir= curdir."/".tmpdir
        endif
        if exists("*mkdir")
            call mkdir(tmpdir)
        else
            call netrw#os#Execute("sil! !".g:netrw_localmkdir.g:netrw_localmkdiropt.' '.netrw#os#Escape(tmpdir,1))
            if v:shell_error != 0
                call netrw#msg#Notify('WARNING', printf("consider setting g:netrw_localmkdir<%s> to something that works", g:netrw_localmkdir))
                return
            endif
        endif
        if isdirectory(s:NetrwFile(tmpdir))
            if s:NetrwLcd(tmpdir)
                return
            endif
            NetrwKeepj call netrw#Obtain(a:islocal,s:netrwmarkfilelist_{bufnr('%')},tmpdir)
            let localfiles= map(deepcopy(s:netrwmarkfilelist_{bufnr('%')}),'substitute(v:val,"^.*/","","")')
            NetrwKeepj call s:NetrwUpload(localfiles,s:netrwmftgt)
            if getcwd() == tmpdir
                for fname in s:netrwmarkfilelist_{bufnr('%')}
                    call netrw#fs#Remove(fname)
                endfor
                if s:NetrwLcd(curdir)
                    return
                endif
                if delete(tmpdir,"d")
                    call netrw#msg#Notify('ERROR', printf('unable to delete directory <%s>!', tmpdir))
                endif
            else
                if s:NetrwLcd(curdir)
                    return
                endif
            endif
        endif
    endif

    " -------
    " cleanup
    " -------
    " remove markings from local buffer
    call s:NetrwUnmarkList(curbufnr,curdir)                   " remove markings from local buffer
    if exists("s:recursive")
    else
    endif
    " see s:LocalFastBrowser() for g:netrw_fastbrowse interpretation (refreshing done for both slow and medium)
    if g:netrw_fastbrowse <= 1
        NetrwKeepj call s:LocalBrowseRefresh()
    else
        " refresh local and targets for fast browsing
        if !exists("s:recursive")
            " remove markings from local buffer
            NetrwKeepj call s:NetrwUnmarkList(curbufnr,curdir)
        endif

        " refresh buffers
        if s:netrwmftgt_islocal
            NetrwKeepj call s:NetrwRefreshDir(s:netrwmftgt_islocal,s:netrwmftgt)
        endif
        if a:islocal && s:netrwmftgt != curdir
            NetrwKeepj call s:NetrwRefreshDir(a:islocal,curdir)
        endif
    endif

    return 1
endfunction

" s:NetrwMarkFileDiff: (invoked by md) This function is used to {{{2
"                      invoke vim's diff mode on the marked files.
"                      Either two or three files can be so handled.
"                      Uses the global marked file list.
function s:NetrwMarkFileDiff(islocal)
    let curbufnr= bufnr("%")

    " sanity check
    if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
        call netrw#msg#Notify('ERROR', 'there are no marked files in this window (:help netrw-mf)')
        return
    endif
    let curdir= s:NetrwGetCurdir(a:islocal)

    if exists("s:netrwmarkfilelist_{".curbufnr."}")
        let cnt    = 0
        for fname in s:netrwmarkfilelist
            let cnt= cnt + 1
            if cnt == 1
                exe "NetrwKeepj e ".fnameescape(fname)
                diffthis
            elseif cnt == 2 || cnt == 3
                below vsplit
                exe "NetrwKeepj e ".fnameescape(fname)
                diffthis
            else
                break
            endif
        endfor
        call s:NetrwUnmarkList(curbufnr,curdir)
    endif

endfunction

" s:NetrwMarkFileEdit: (invoked by me) put marked files on arg list and start editing them {{{2
"                       Uses global markfilelist
function s:NetrwMarkFileEdit(islocal)

    let curdir   = s:NetrwGetCurdir(a:islocal)
    let curbufnr = bufnr("%")

    " sanity check
    if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
        call netrw#msg#Notify('ERROR', 'there are no marked files in this window (:help netrw-mf)')
        return
    endif

    if exists("s:netrwmarkfilelist_{curbufnr}")
        call s:SetRexDir(a:islocal,curdir)
        let flist= join(map(deepcopy(s:netrwmarkfilelist), "fnameescape(v:val)"))
        " unmark markedfile list
        "   call s:NetrwUnmarkList(curbufnr,curdir)
        call s:NetrwUnmarkAll()
        exe "sil args ".flist
    endif
    echo "(use :bn, :bp to navigate files; :Rex to return)"

endfunction

" s:NetrwMarkFileQFEL: convert a quickfix-error or location list into a marked file list {{{2
function s:NetrwMarkFileQFEL(islocal,qfel)
    call s:NetrwUnmarkAll()
    let curbufnr= bufnr("%")

    if !empty(a:qfel)
        for entry in a:qfel
            let bufnmbr= entry["bufnr"]
            if !exists("s:netrwmarkfilelist_{curbufnr}")
                call s:NetrwMarkFile(a:islocal,bufname(bufnmbr))
            elseif index(s:netrwmarkfilelist_{curbufnr},bufname(bufnmbr)) == -1
                " s:NetrwMarkFile will remove duplicate entries from the marked file list.
                " So, this test lets two or more hits on the same pattern to be ignored.
                call s:NetrwMarkFile(a:islocal,bufname(bufnmbr))
            else
            endif
        endfor
        echo "(use me to edit marked files)"
    else
        call netrw#msg#Notify('WARNING', "can't convert quickfix error list; its empty!")
    endif

endfunction

" s:NetrwMarkFileExe: (invoked by mx and mX) execute arbitrary system command on marked files {{{2
"                     mx enbloc=0: Uses the local marked-file list, applies command to each file individually
"                     mX enbloc=1: Uses the global marked-file list, applies command to entire list
function s:NetrwMarkFileExe(islocal,enbloc)
    let svpos    = winsaveview()
    let curdir   = s:NetrwGetCurdir(a:islocal)
    let curbufnr = bufnr("%")

    if a:enbloc == 0
        " individually apply command to files, one at a time
        " sanity check
        if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
            call netrw#msg#Notify('ERROR', 'there are no marked files in this window (:help netrw-mf)')
            return
        endif

        if exists("s:netrwmarkfilelist_{curbufnr}")
            " get the command
            call inputsave()
            let cmd= input("Enter command: ","","file")
            call inputrestore()
            if cmd == ""
                return
            endif

            " apply command to marked files, individually.  Substitute: filename -> %
            " If no %, then append a space and the filename to the command
            for fname in s:netrwmarkfilelist_{curbufnr}
                if a:islocal
                    if g:netrw_keepdir
                        let fname= netrw#os#Escape(netrw#fs#WinPath(netrw#fs#ComposePath(curdir,fname)))
                    endif
                else
                    let fname= netrw#os#Escape(netrw#fs#WinPath(b:netrw_curdir.fname))
                endif
                if cmd =~ '%'
                    let xcmd= substitute(cmd,'%',fname,'g')
                else
                    let xcmd= cmd.' '.fname
                endif
                if a:islocal
                    let ret= system(xcmd)
                else
                    let ret= s:RemoteSystem(xcmd)
                endif
                if v:shell_error < 0
                    call netrw#msg#Notify('ERROR', printf('command<%s> failed, aborting', xcmd))
                    break
                else
                    if ret !=# ''
                        echo "\n"
                        " skip trailing new line
                        echo ret[0:-2]
                    else
                        echo ret
                    endif
                endif
            endfor

            " unmark marked file list
            call s:NetrwUnmarkList(curbufnr,curdir)

            " refresh the listing
            NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
            NetrwKeepj call winrestview(svpos)
        else
            call netrw#msg#Notify('ERROR', 'no files marked!')
        endif

    else " apply command to global list of files, en bloc

        call inputsave()
        let cmd= input("Enter command: ","","file")
        call inputrestore()
        if cmd == ""
            return
        endif
        if cmd =~ '%'
            let cmd= substitute(cmd,'%',join(map(s:netrwmarkfilelist,'netrw#os#Escape(v:val)'),' '),'g')
        else
            let cmd= cmd.' '.join(map(s:netrwmarkfilelist,'netrw#os#Escape(v:val)'),' ')
        endif
        if a:islocal
            call system(cmd)
            if v:shell_error < 0
                call netrw#msg#Notify('ERROR', printf('command<%s> failed, aborting',xcmd))
            endif
        else
            let ret= s:RemoteSystem(cmd)
        endif
        call s:NetrwUnmarkAll()

        " refresh the listing
        NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
        NetrwKeepj call winrestview(svpos)

    endif
endfunction

" s:NetrwMarkHideSfx: (invoked by mh) (un)hide files having same suffix
"                  as the marked file(s) (toggles suffix presence)
"                  Uses the local marked file list.
function s:NetrwMarkHideSfx(islocal)
    let svpos    = winsaveview()
    let curbufnr = bufnr("%")

    " s:netrwmarkfilelist_{curbufnr}: the List of marked files
    if exists("s:netrwmarkfilelist_{curbufnr}")

        for fname in s:netrwmarkfilelist_{curbufnr}
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
        NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
        NetrwKeepj call winrestview(svpos)
    else
        call netrw#msg#Notify('ERROR', 'no files marked!')
    endif
endfunction

" s:NetrwMarkFileVimCmd: (invoked by mv) execute arbitrary vim command on marked files, one at a time {{{2
"                     Uses the local marked-file list.
function s:NetrwMarkFileVimCmd(islocal)
    let svpos    = winsaveview()
    let curdir   = s:NetrwGetCurdir(a:islocal)
    let curbufnr = bufnr("%")

    " sanity check
    if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
        call netrw#msg#Notify('ERROR', 'there are no marked files in this window (:help netrw-mf)')
        return
    endif

    if exists("s:netrwmarkfilelist_{curbufnr}")
        " get the command
        call inputsave()
        let cmd= input("Enter vim command: ","","file")
        call inputrestore()
        if cmd == ""
            return
        endif

        " apply command to marked files.  Substitute: filename -> %
        " If no %, then append a space and the filename to the command
        for fname in s:netrwmarkfilelist_{curbufnr}
            if a:islocal
                1split
                exe "sil! NetrwKeepj keepalt e ".fnameescape(fname)
                exe cmd
                exe "sil! keepalt wq!"
            else
                echo "sorry, \"mv\" not supported yet for remote files"
            endif
        endfor

        " unmark marked file list
        call s:NetrwUnmarkList(curbufnr,curdir)

        " refresh the listing
        NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
        NetrwKeepj call winrestview(svpos)
    else
        call netrw#msg#Notify('ERROR', 'no files marked!')
    endif
endfunction

" s:NetrwMarkFileGrep: (invoked by mg) This function applies vimgrep to marked files {{{2
"                     Uses the global markfilelist
function s:NetrwMarkFileGrep(islocal)
    let svpos    = winsaveview()
    let curbufnr = bufnr("%")
    let curdir   = s:NetrwGetCurdir(a:islocal)

    if exists("s:netrwmarkfilelist")
        let netrwmarkfilelist= join(map(deepcopy(s:netrwmarkfilelist), "fnameescape(v:val)"))
        call s:NetrwUnmarkAll()
    else
        let netrwmarkfilelist= "*"
    endif

    " ask user for pattern
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
    try
        exe "NetrwKeepj noautocmd vimgrep".patbang." ".pat." ".netrwmarkfilelist
    catch /^Vim\%((\a\+)\)\=:E480/
        call netrw#msg#Notify('WARNING', printf('no match with pattern<%s>', pat))
        return
    endtry
    echo "(use :cn, :cp to navigate, :Rex to return)"

    2match none
    NetrwKeepj call winrestview(svpos)

    if exists("nonisi")
        " original, user-supplied pattern did not begin with a character from isident
        if pat =~# nonisi.'j$\|'.nonisi.'gj$\|'.nonisi.'jg$'
            call s:NetrwMarkFileQFEL(a:islocal,getqflist())
        endif
    endif

endfunction

" s:NetrwMarkFileMove: (invoked by mm) execute arbitrary command on marked files, one at a time {{{2
"                      uses the global marked file list
"                      s:netrwmfloc= 0: target directory is remote
"                                  = 1: target directory is local
function s:NetrwMarkFileMove(islocal)
    let curdir   = s:NetrwGetCurdir(a:islocal)
    let curbufnr = bufnr("%")

    " sanity check
    if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
        call netrw#msg#Notify('ERROR', 'there are no marked files in this window (:help netrw-mf)')
        return
    endif

    if !exists("s:netrwmftgt")
        call netrw#msg#Notify('ERROR', 'your marked file target is empty! (:help netrw-mt)')
        return 0
    endif

    if      a:islocal &&  s:netrwmftgt_islocal
        " move: local -> local
        if !executable(g:netrw_localmovecmd)
            call netrw#msg#Notify('ERROR', printf('g:netrw_localmovecmd<%s> not executable on your system, aborting', g:netrw_localmovecmd))
            return
        endif
        let tgt = netrw#os#Escape(s:netrwmftgt)
        if !g:netrw_cygwin && has("win32")
            let tgt= substitute(tgt, '/','\\','g')
            if g:netrw_localmovecmd =~ '\s'
                let movecmd     = substitute(g:netrw_localmovecmd,'\s.*$','','')
                let movecmdargs = substitute(g:netrw_localmovecmd,'^.\{-}\(\s.*\)$','\1','')
                let movecmd     = netrw#fs#WinPath(movecmd).movecmdargs
            else
                let movecmd = netrw#fs#WinPath(g:netrw_localmovecmd)
            endif
        else
            let movecmd = netrw#fs#WinPath(g:netrw_localmovecmd)
        endif
        for fname in s:netrwmarkfilelist_{bufnr("%")}
            if g:netrw_keepdir
                " Jul 19, 2022: fixing file move when g:netrw_keepdir is 1
                let fname= b:netrw_curdir."/".fname
            endif
            if !g:netrw_cygwin && has("win32")
                let fname= substitute(fname,'/','\\','g')
            endif
            let ret= system(movecmd.g:netrw_localmovecmdopt." ".netrw#os#Escape(fname)." ".tgt)
            if v:shell_error != 0
                if exists("b:netrw_curdir") && b:netrw_curdir != getcwd() && !g:netrw_keepdir
                    call netrw#msg#Notify('ERROR', printf("move failed; perhaps due to vim's current directory<%s> not matching netrw's (%s) (see :help netrw-cd)", getcwd(), b:netrw_curdir))
                else
                    call netrw#msg#Notify('ERROR', printf("tried using g:netrw_localmovecmd<%s>; it doesn't work!", g:netrw_localmovecmd))
                endif
                break
            endif
        endfor

    elseif  a:islocal && !s:netrwmftgt_islocal
        " move: local -> remote
        let mflist= s:netrwmarkfilelist_{bufnr("%")}
        NetrwKeepj call s:NetrwMarkFileCopy(a:islocal)
        for fname in mflist
            let barefname = substitute(fname,'^\(.*/\)\(.\{-}\)$','\2','')
            let ok        = s:NetrwLocalRmFile(b:netrw_curdir,barefname,1)
        endfor
        unlet mflist

    elseif !a:islocal &&  s:netrwmftgt_islocal
        " move: remote -> local
        let mflist= s:netrwmarkfilelist_{bufnr("%")}
        NetrwKeepj call s:NetrwMarkFileCopy(a:islocal)
        for fname in mflist
            let barefname = substitute(fname,'^\(.*/\)\(.\{-}\)$','\2','')
            let ok        = s:NetrwRemoteRmFile(b:netrw_curdir,barefname,1)
        endfor
        unlet mflist

    elseif !a:islocal && !s:netrwmftgt_islocal
        " move: remote -> remote
        let mflist= s:netrwmarkfilelist_{bufnr("%")}
        NetrwKeepj call s:NetrwMarkFileCopy(a:islocal)
        for fname in mflist
            let barefname = substitute(fname,'^\(.*/\)\(.\{-}\)$','\2','')
            let ok        = s:NetrwRemoteRmFile(b:netrw_curdir,barefname,1)
        endfor
        unlet mflist
    endif

    " -------
    " cleanup
    " -------

    " remove markings from local buffer
    call s:NetrwUnmarkList(curbufnr,curdir)                   " remove markings from local buffer

    " refresh buffers
    if !s:netrwmftgt_islocal
        NetrwKeepj call s:NetrwRefreshDir(s:netrwmftgt_islocal,s:netrwmftgt)
    endif
    if a:islocal
        NetrwKeepj call s:NetrwRefreshDir(a:islocal,b:netrw_curdir)
    endif
    if g:netrw_fastbrowse <= 1
        NetrwKeepj call s:LocalBrowseRefresh()
    endif

endfunction

" s:NetrwMarkFileRegexp: (invoked by mr) This function is used to mark {{{2
"                        files when given a regexp (for which a prompt is
"                        issued) (matches to name of files).
function s:NetrwMarkFileRegexp(islocal)

    " get the regular expression
    call inputsave()
    let regexp= input("Enter regexp: ","","file")
    call inputrestore()

    if a:islocal
        let curdir= s:NetrwGetCurdir(a:islocal)
        " get the matching list of files using local glob()
        let dirname = escape(b:netrw_curdir,g:netrw_glob_escape)
        let filelist= glob(netrw#fs#ComposePath(dirname,regexp),0,1,1)

        " mark the list of files
        for fname in filelist
            if fname =~ '^'.fnameescape(curdir)
                NetrwKeepj call s:NetrwMarkFile(a:islocal,substitute(fname,'^'.fnameescape(curdir).'/','',''))
            else
                NetrwKeepj call s:NetrwMarkFile(a:islocal,substitute(fname,'^.*/','',''))
            endif
        endfor

    else

        " convert displayed listing into a filelist
        let eikeep = &ei
        let areg   = @a
        sil NetrwKeepj %y a
        setl ei=all ma
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

endfunction

" s:NetrwMarkFileSource: (invoked by ms) This function sources marked files {{{2
"                        Uses the local marked file list.
function s:NetrwMarkFileSource(islocal)
    let curbufnr= bufnr("%")

    " sanity check
    if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
        call netrw#msg#Notify('ERROR', 'there are no marked files in this window (:help netrw-mf)')
        return
    endif
    let curdir= s:NetrwGetCurdir(a:islocal)

    if exists("s:netrwmarkfilelist_{curbufnr}")
        let netrwmarkfilelist = s:netrwmarkfilelist_{bufnr("%")}
        call s:NetrwUnmarkList(curbufnr,curdir)
        for fname in netrwmarkfilelist
            if a:islocal
                if g:netrw_keepdir
                    let fname= netrw#fs#ComposePath(curdir,fname)
                endif
            else
                let fname= curdir.fname
            endif
            " the autocmds will handle sourcing both local and remote files
            exe "so ".fnameescape(fname)
        endfor
        2match none
    endif
endfunction

" s:NetrwMarkFileTag: (invoked by mT) This function applies g:netrw_ctags to marked files {{{2
"                     Uses the global markfilelist
function s:NetrwMarkFileTag(islocal)
    let svpos    = winsaveview()
    let curdir   = s:NetrwGetCurdir(a:islocal)
    let curbufnr = bufnr("%")

    " sanity check
    if !exists("s:netrwmarkfilelist_{curbufnr}") || empty(s:netrwmarkfilelist_{curbufnr})
        call netrw#msg#Notify('ERROR', 'there are no marked files in this window (:help netrw-mf)')
        return
    endif

    if exists("s:netrwmarkfilelist")
        let netrwmarkfilelist= join(map(deepcopy(s:netrwmarkfilelist), "netrw#os#Escape(v:val,".!a:islocal.")"))
        call s:NetrwUnmarkAll()

        if a:islocal

            call system(g:netrw_ctags." ".netrwmarkfilelist)
            if v:shell_error
                call netrw#msg#Notify('ERROR', printf('g:netrw_ctags<%s> is not executable!', g:netrw_ctags))
            endif

        else
            let cmd   = s:RemoteSystem(g:netrw_ctags." ".netrwmarkfilelist)
            call netrw#Obtain(a:islocal,"tags")
            let curdir= b:netrw_curdir
            1split
            NetrwKeepj e tags
            let path= substitute(curdir,'^\(.*\)/[^/]*$','\1/','')
            exe 'NetrwKeepj %s/\t\(\S\+\)\t/\t'.escape(path,"/\n\r\\").'\1\t/e'
            call histdel("/",-1)
            wq!
        endif
        2match none
        call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
        call winrestview(svpos)
    endif
endfunction

" s:NetrwMarkFileTgt:  (invoked by mt) This function sets up a marked file target {{{2
"   Sets up two variables,
"     s:netrwmftgt         : holds the target directory
"     s:netrwmftgt_islocal : 0=target directory is remote
"                            1=target directory is local
function s:NetrwMarkFileTgt(islocal)
    let svpos  = winsaveview()
    let curdir = s:NetrwGetCurdir(a:islocal)
    let hadtgt = exists("s:netrwmftgt")
    if !exists("w:netrw_bannercnt")
        let w:netrw_bannercnt= b:netrw_bannercnt
    endif

    " set up target
    if line(".") < w:netrw_bannercnt
        " if cursor in banner region, use b:netrw_curdir for the target unless its already the target
        if exists("s:netrwmftgt") && exists("s:netrwmftgt_islocal") && s:netrwmftgt == b:netrw_curdir
            unlet s:netrwmftgt s:netrwmftgt_islocal
            if g:netrw_fastbrowse <= 1
                call s:LocalBrowseRefresh()
            endif
            call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
            call winrestview(svpos)
            return
        else
            let s:netrwmftgt= b:netrw_curdir
        endif

    else
        " get word under cursor.
        "  * If directory, use it for the target.
        "  * If file, use b:netrw_curdir for the target
        let curword= s:NetrwGetWord()
        let tgtdir = netrw#fs#ComposePath(curdir,curword)
        if a:islocal && isdirectory(s:NetrwFile(tgtdir))
            let s:netrwmftgt = tgtdir
        elseif !a:islocal && tgtdir =~ '/$'
            let s:netrwmftgt = tgtdir
        else
            let s:netrwmftgt = curdir
        endif
    endif
    if a:islocal
        " simplify the target (eg. /abc/def/../ghi -> /abc/ghi)
        let s:netrwmftgt= simplify(s:netrwmftgt)
    endif
    if g:netrw_cygwin
        let s:netrwmftgt= substitute(system("cygpath ".netrw#os#Escape(s:netrwmftgt)),'\n$','','')
        let s:netrwmftgt= substitute(s:netrwmftgt,'\n$','','')
    endif
    let s:netrwmftgt_islocal= a:islocal

    " need to do refresh so that the banner will be updated
    "  s:LocalBrowseRefresh handles all local-browsing buffers when not fast browsing
    if g:netrw_fastbrowse <= 1
        call s:LocalBrowseRefresh()
    endif
    "  call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
        call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,w:netrw_treetop,0))
    else
        call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
    endif
    call winrestview(svpos)
    if !hadtgt
        sil! NetrwKeepj norm! j
    endif
endfunction

" s:NetrwGetCurdir: gets current directory and sets up b:netrw_curdir if necessary {{{2
function s:NetrwGetCurdir(islocal)

    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
        let b:netrw_curdir = s:NetrwTreePath(w:netrw_treetop)
    elseif !exists("b:netrw_curdir")
        let b:netrw_curdir= getcwd()
    endif

    if b:netrw_curdir !~ '\<\a\{3,}://'
        let curdir= b:netrw_curdir
        if g:netrw_keepdir == 0
            call s:NetrwLcd(curdir)
        endif
    endif

    return b:netrw_curdir
endfunction

" s:NetrwOpenFile: query user for a filename and open it {{{2
function s:NetrwOpenFile(islocal)
    call inputsave()
    let fname = input("Enter filename: ")
    call inputrestore()

    if empty(fname)
        return
    endif

    " save position for benefit of Rexplore
    let s:rexposn_{bufnr("%")}= winsaveview()

    execute "NetrwKeepj e " . fnameescape(!isabsolutepath(fname)
                \ ? netrw#fs#ComposePath(b:netrw_curdir, fname)
                \ : fname)
endfunction

" netrw#Shrink: shrinks/expands a netrw or Lexplorer window {{{2
"               For the mapping to this function be made via
"               netrwPlugin, you'll need to have had
"               g:netrw_usetab set to non-zero.
function netrw#Shrink()
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
        else
            exe "vert resize ".t:netrw_winwidth
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
        elseif winwidth(bufwinnr(t:netrw_lexbufnr)) >= 0
            exe "vert resize ".t:netrw_winwidth
        else
            call netrw#Lexplore(0,0)
        endif

    else
        call netrw#Lexplore(0,0)
    endif
    let wiw= wiwkeep

endfunction

" s:NetSortSequence: allows user to edit the sorting sequence {{{2
function s:NetSortSequence(islocal)
    let ykeep= @@
    let svpos= winsaveview()
    call inputsave()
    let newsortseq= input("Edit Sorting Sequence: ",g:netrw_sort_sequence)
    call inputrestore()

    " refresh the listing
    let g:netrw_sort_sequence= newsortseq
    NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
    NetrwKeepj call winrestview(svpos)
    let @@= ykeep
endfunction

" s:NetrwUnmarkList: delete local marked file list and remove their contents from the global marked-file list {{{2
"   User access provided by the <mF> mapping. (see :help netrw-mF)
"   Used by many MarkFile functions.
function s:NetrwUnmarkList(curbufnr,curdir)

    "  remove all files in local marked-file list from global list
    if exists("s:netrwmarkfilelist")
        for mfile in s:netrwmarkfilelist_{a:curbufnr}
            let dfile = netrw#fs#ComposePath(a:curdir,mfile)       " prepend directory to mfile
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
endfunction

" s:NetrwUnmarkAll: remove the global marked file list and all local ones {{{2
function s:NetrwUnmarkAll()
    if exists("s:netrwmarkfilelist")
        unlet s:netrwmarkfilelist
    endif
    sil call s:NetrwUnmarkAll2()
    2match none
endfunction

" s:NetrwUnmarkAll2: unmark all files from all buffers {{{2
function s:NetrwUnmarkAll2()
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
endfunction

" s:NetrwUnMarkFile: called via mu map; unmarks *all* marked files, both global and buffer-local {{{2
"
" Marked files are in two types of lists:
"    s:netrwmarkfilelist    -- holds complete paths to all marked files
"    s:netrwmarkfilelist_#  -- holds list of marked files in current-buffer's directory (#==bufnr())
"
" Marked files suitable for use with 2match are in:
"    s:netrwmarkfilemtch_#   -- used with 2match to display marked files
function s:NetrwUnMarkFile(islocal)
    let svpos    = winsaveview()
    let curbufnr = bufnr("%")

    " unmark marked file list
    " (although I expect s:NetrwUpload() to do it, I'm just making sure)
    if exists("s:netrwmarkfilelist")
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

    "  call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
    call winrestview(svpos)
endfunction

" s:NetrwMenu: generates the menu for gvim and netrw {{{2
function s:NetrwMenu(domenu)

    if !exists("g:NetrwMenuPriority")
        let g:NetrwMenuPriority= 80
    endif

    if has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu

        if !exists("s:netrw_menu_enabled") && a:domenu
            let s:netrw_menu_enabled= 1
            exe 'sil! menu '.g:NetrwMenuPriority.'.1      '.g:NetrwTopLvlMenu.'Help<tab><F1>    <F1>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.5      '.g:NetrwTopLvlMenu.'-Sep1-   :'
            exe 'sil! menu '.g:NetrwMenuPriority.'.6      '.g:NetrwTopLvlMenu.'Go\ Up\ Directory<tab>-  -'
            exe 'sil! menu '.g:NetrwMenuPriority.'.7      '.g:NetrwTopLvlMenu.'Apply\ Special\ Viewer<tab>x     x'
            if g:netrw_dirhistmax > 0
                exe 'sil! menu '.g:NetrwMenuPriority.'.8.1   '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History.Bookmark\ Current\ Directory<tab>mb      mb'
                exe 'sil! menu '.g:NetrwMenuPriority.'.8.4   '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History.Goto\ Prev\ Dir\ (History)<tab>u u'
                exe 'sil! menu '.g:NetrwMenuPriority.'.8.5   '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History.Goto\ Next\ Dir\ (History)<tab>U U'
                exe 'sil! menu '.g:NetrwMenuPriority.'.8.6   '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History.List<tab>qb      qb'
            else
                exe 'sil! menu '.g:NetrwMenuPriority.'.8     '.g:NetrwTopLvlMenu.'Bookmarks\ and\ History  :echo "(disabled)"'."\<cr>"
            endif
            exe 'sil! menu '.g:NetrwMenuPriority.'.9.1    '.g:NetrwTopLvlMenu.'Browsing\ Control.Horizontal\ Split<tab>o        o'
            exe 'sil! menu '.g:NetrwMenuPriority.'.9.2    '.g:NetrwTopLvlMenu.'Browsing\ Control.Vertical\ Split<tab>v  v'
            exe 'sil! menu '.g:NetrwMenuPriority.'.9.3    '.g:NetrwTopLvlMenu.'Browsing\ Control.New\ Tab<tab>t t'
            exe 'sil! menu '.g:NetrwMenuPriority.'.9.4    '.g:NetrwTopLvlMenu.'Browsing\ Control.Preview<tab>p  p'
            exe 'sil! menu '.g:NetrwMenuPriority.'.9.5    '.g:NetrwTopLvlMenu.'Browsing\ Control.Edit\ File\ Hiding\ List<tab><ctrl-h>'."       \<c-h>'"
            exe 'sil! menu '.g:NetrwMenuPriority.'.9.6    '.g:NetrwTopLvlMenu.'Browsing\ Control.Edit\ Sorting\ Sequence<tab>S  S'
            exe 'sil! menu '.g:NetrwMenuPriority.'.9.7    '.g:NetrwTopLvlMenu.'Browsing\ Control.Quick\ Hide/Unhide\ Dot\ Files<tab>'."gh       gh"
            exe 'sil! menu '.g:NetrwMenuPriority.'.9.8    '.g:NetrwTopLvlMenu.'Browsing\ Control.Refresh\ Listing<tab>'."<ctrl-l>       \<c-l>"
            exe 'sil! menu '.g:NetrwMenuPriority.'.9.9    '.g:NetrwTopLvlMenu.'Browsing\ Control.Settings/Options<tab>:NetrwSettings    '.":NetrwSettings\<cr>"
            exe 'sil! menu '.g:NetrwMenuPriority.'.10     '.g:NetrwTopLvlMenu.'Delete\ File/Directory<tab>D     D'
            exe 'sil! menu '.g:NetrwMenuPriority.'.11.1   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.Create\ New\ File<tab>%   %'
            exe 'sil! menu '.g:NetrwMenuPriority.'.11.1   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ Current\ Window<tab><cr>      '."\<cr>"
            exe 'sil! menu '.g:NetrwMenuPriority.'.11.2   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.Preview\ File/Directory<tab>p     p'
            exe 'sil! menu '.g:NetrwMenuPriority.'.11.3   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ Previous\ Window<tab>P        P'
            exe 'sil! menu '.g:NetrwMenuPriority.'.11.4   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ New\ Window<tab>o     o'
            exe 'sil! menu '.g:NetrwMenuPriority.'.11.5   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ New\ Tab<tab>t        t'
            exe 'sil! menu '.g:NetrwMenuPriority.'.11.5   '.g:NetrwTopLvlMenu.'Edit\ File/Dir.In\ New\ Vertical\ Window<tab>v   v'
            exe 'sil! menu '.g:NetrwMenuPriority.'.12.1   '.g:NetrwTopLvlMenu.'Explore.Directory\ Name  :Explore '
            exe 'sil! menu '.g:NetrwMenuPriority.'.12.2   '.g:NetrwTopLvlMenu.'Explore.Filenames\ Matching\ Pattern\ (curdir\ only)<tab>:Explore\ */    :Explore */'
            exe 'sil! menu '.g:NetrwMenuPriority.'.12.2   '.g:NetrwTopLvlMenu.'Explore.Filenames\ Matching\ Pattern\ (+subdirs)<tab>:Explore\ **/       :Explore **/'
            exe 'sil! menu '.g:NetrwMenuPriority.'.12.3   '.g:NetrwTopLvlMenu.'Explore.Files\ Containing\ String\ Pattern\ (curdir\ only)<tab>:Explore\ *//     :Explore *//'
            exe 'sil! menu '.g:NetrwMenuPriority.'.12.4   '.g:NetrwTopLvlMenu.'Explore.Files\ Containing\ String\ Pattern\ (+subdirs)<tab>:Explore\ **//        :Explore **//'
            exe 'sil! menu '.g:NetrwMenuPriority.'.12.4   '.g:NetrwTopLvlMenu.'Explore.Next\ Match<tab>:Nexplore        :Nexplore<cr>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.12.4   '.g:NetrwTopLvlMenu.'Explore.Prev\ Match<tab>:Pexplore        :Pexplore<cr>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.13     '.g:NetrwTopLvlMenu.'Make\ Subdirectory<tab>d d'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.1   '.g:NetrwTopLvlMenu.'Marked\ Files.Mark\ File<tab>mf  mf'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.2   '.g:NetrwTopLvlMenu.'Marked\ Files.Mark\ Files\ by\ Regexp<tab>mr     mr'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.3   '.g:NetrwTopLvlMenu.'Marked\ Files.Hide-Show-List\ Control<tab>a      a'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.4   '.g:NetrwTopLvlMenu.'Marked\ Files.Copy\ To\ Target<tab>mc    mc'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.5   '.g:NetrwTopLvlMenu.'Marked\ Files.Delete<tab>D       D'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.6   '.g:NetrwTopLvlMenu.'Marked\ Files.Diff<tab>md        md'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.7   '.g:NetrwTopLvlMenu.'Marked\ Files.Edit<tab>me        me'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.8   '.g:NetrwTopLvlMenu.'Marked\ Files.Exe\ Cmd<tab>mx    mx'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.9   '.g:NetrwTopLvlMenu.'Marked\ Files.Move\ To\ Target<tab>mm    mm'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.10  '.g:NetrwTopLvlMenu.'Marked\ Files.Obtain<tab>O       O'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.12  '.g:NetrwTopLvlMenu.'Marked\ Files.Replace<tab>R      R'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.13  '.g:NetrwTopLvlMenu.'Marked\ Files.Set\ Target<tab>mt mt'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.14  '.g:NetrwTopLvlMenu.'Marked\ Files.Tag<tab>mT mT'
            exe 'sil! menu '.g:NetrwMenuPriority.'.14.15  '.g:NetrwTopLvlMenu.'Marked\ Files.Zip/Unzip/Compress/Uncompress<tab>mz       mz'
            exe 'sil! menu '.g:NetrwMenuPriority.'.15     '.g:NetrwTopLvlMenu.'Obtain\ File<tab>O       O'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.1.1 '.g:NetrwTopLvlMenu.'Style.Listing.thin<tab>i :let w:netrw_liststyle=0<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.1.1 '.g:NetrwTopLvlMenu.'Style.Listing.long<tab>i :let w:netrw_liststyle=1<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.1.1 '.g:NetrwTopLvlMenu.'Style.Listing.wide<tab>i :let w:netrw_liststyle=2<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.1.1 '.g:NetrwTopLvlMenu.'Style.Listing.tree<tab>i :let w:netrw_liststyle=3<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.2.1 '.g:NetrwTopLvlMenu.'Style.Normal-Hide-Show.Show\ All<tab>a   :let g:netrw_hide=0<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.2.3 '.g:NetrwTopLvlMenu.'Style.Normal-Hide-Show.Normal<tab>a      :let g:netrw_hide=1<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.2.2 '.g:NetrwTopLvlMenu.'Style.Normal-Hide-Show.Hidden\ Only<tab>a        :let g:netrw_hide=2<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.3   '.g:NetrwTopLvlMenu.'Style.Reverse\ Sorting\ Order<tab>'."r   r"
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.4.1 '.g:NetrwTopLvlMenu.'Style.Sorting\ Method.Name<tab>s       :let g:netrw_sort_by="name"<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.4.2 '.g:NetrwTopLvlMenu.'Style.Sorting\ Method.Time<tab>s       :let g:netrw_sort_by="time"<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.4.3 '.g:NetrwTopLvlMenu.'Style.Sorting\ Method.Size<tab>s       :let g:netrw_sort_by="size"<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.16.4.3 '.g:NetrwTopLvlMenu.'Style.Sorting\ Method.Exten<tab>s      :let g:netrw_sort_by="exten"<cr><c-L>'
            exe 'sil! menu '.g:NetrwMenuPriority.'.17     '.g:NetrwTopLvlMenu.'Rename\ File/Directory<tab>R     R'
            exe 'sil! menu '.g:NetrwMenuPriority.'.18     '.g:NetrwTopLvlMenu.'Set\ Current\ Directory<tab>c    c'
            let s:netrw_menucnt= 28
            call s:NetrwBookmarkMenu() " provide some history!  uses priorities 2,3, reserves 4, 8.2.x
            call s:NetrwTgtMenu()      " let bookmarks and history be easy targets

        elseif !a:domenu
            let s:netrwcnt = 0
            let curwin     = winnr()
            windo if getline(2) =~# "Netrw" | let s:netrwcnt= s:netrwcnt + 1 | endif
        endif
        exe curwin."wincmd w"

        if s:netrwcnt <= 1
            exe 'sil! unmenu '.g:NetrwTopLvlMenu
            sil! unlet s:netrw_menu_enabled
        endif
    endif
    return
  endif

endfunction

" s:NetrwObtain: obtain file under cursor or from markfile list {{{2
"                Used by the O maps (as <SID>NetrwObtain())
function s:NetrwObtain(islocal)

    let ykeep= @@
    if exists("s:netrwmarkfilelist_{bufnr('%')}")
        let islocal= s:netrwmarkfilelist_{bufnr('%')}[1] !~ '^\a\{3,}://'
        call netrw#Obtain(islocal,s:netrwmarkfilelist_{bufnr('%')})
        call s:NetrwUnmarkList(bufnr('%'),b:netrw_curdir)
    else
        call netrw#Obtain(a:islocal,s:NetrwGetWord())
    endif
    let @@= ykeep

endfunction

" s:NetrwPrevWinOpen: open file/directory in previous window.  {{{2
"   If there's only one window, then the window will first be split.
"   Returns:
"     choice = 0 : didn't have to choose
"     choice = 1 : saved modified file in window first
"     choice = 2 : didn't save modified file, opened window
"     choice = 3 : cancel open
function s:NetrwPrevWinOpen(islocal)
    let ykeep= @@
    " grab a copy of the b:netrw_curdir to pass it along to newly split windows
    let curdir = b:netrw_curdir

    " get last window number and the word currently under the cursor
    let origwin   = winnr()
    let lastwinnr = winnr("$")
    let curword      = s:NetrwGetWord()
    let choice       = 0
    let s:prevwinopen= 1  " lets s:NetrwTreeDir() know that NetrwPrevWinOpen called it (s:NetrwTreeDir() will unlet s:prevwinopen)
    let s:treedir = s:NetrwTreeDir(a:islocal)
    let curdir    = s:treedir

    let didsplit = 0
    if lastwinnr == 1
        " if only one window, open a new one first
        " g:netrw_preview=0: preview window shown in a horizontally split window
        " g:netrw_preview=1: preview window shown in a vertically   split window
        if g:netrw_preview
            " vertically split preview window
            let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize
            exe (g:netrw_alto? "top " : "bot ")."vert ".winsz."wincmd s"
        else
            " horizontally split preview window
            let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
            exe (g:netrw_alto? "bel " : "abo ").winsz."wincmd s"
        endif
        let didsplit = 1

    else
        NetrwKeepj call s:SaveBufVars()
        let eikeep= &ei
        setl ei=all
        wincmd p

        if exists("s:lexplore_win") && s:lexplore_win == winnr()
            " whoops -- user trying to open file in the Lexplore window.
            " Use Lexplore's opening-file window instead.
            "    exe g:netrw_chgwin."wincmd w"
            wincmd p
            call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,s:NetrwGetWord(),1))
        endif

        " prevwinnr: the window number of the "prev" window
        " prevbufnr: the buffer number of the buffer in the "prev" window
        " bnrcnt   : the qty of windows open on the "prev" buffer
        let prevwinnr   = winnr()
        let prevbufnr   = bufnr("%")
        let prevbufname = bufname("%")
        let prevmod     = &mod
        let bnrcnt      = 0
        NetrwKeepj call s:RestoreBufVars()

        " if the previous window's buffer has been changed (ie. its modified flag is set),
        " and it doesn't appear in any other extant window, then ask the
        " user if s/he wants to abandon modifications therein.
        if prevmod
            windo if winbufnr(0) == prevbufnr | let bnrcnt=bnrcnt+1 | endif
            exe prevwinnr."wincmd w"

            if bnrcnt == 1 && &hidden == 0
                " only one copy of the modified buffer in a window, and
                " hidden not set, so overwriting will lose the modified file.  Ask first...
                let choice = confirm("Save modified buffer<".prevbufname."> first?","&Yes\n&No\n&Cancel")
                let &ei= eikeep

                if choice == 1
                    " Yes -- write file & then browse
                    let v:errmsg= ""
                    sil w
                    if v:errmsg != ""
                        call netrw#msg#Notify('ERROR', printf('unable to write <%s>!', (exists("prevbufname") ? prevbufname : 'n/a')))
                        exe origwin."wincmd w"
                        let &ei = eikeep
                        let @@  = ykeep
                        return choice
                    endif

                elseif choice == 2
                    " No -- don't worry about changed file, just browse anyway
                    echomsg "**note** changes to ".prevbufname." abandoned"

                else
                    " Cancel -- don't do this
                    exe origwin."wincmd w"
                    let &ei= eikeep
                    let @@ = ykeep
                    return choice
                endif
            endif
        endif
        let &ei= eikeep
    endif

    " restore b:netrw_curdir (window split/enew may have lost it)
    let b:netrw_curdir= curdir
    if a:islocal < 2
        if a:islocal
            call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(a:islocal,curword,0))
        else
            call s:NetrwBrowse(a:islocal,s:NetrwBrowseChgDir(a:islocal,curword,0))
        endif
    endif
    let @@= ykeep
    return choice
endfunction

" s:NetrwUpload: load fname to tgt (used by NetrwMarkFileCopy()) {{{2
"                Always assumed to be local -> remote
"                call s:NetrwUpload(filename, target)
"                call s:NetrwUpload(filename, target, fromdirectory)
function s:NetrwUpload(fname,tgt,...)

    if a:tgt =~ '^\a\{3,}://'
        let tgtdir= substitute(a:tgt,'^\a\{3,}://[^/]\+/\(.\{-}\)$','\1','')
    else
        let tgtdir= substitute(a:tgt,'^\(.*\)/[^/]*$','\1','')
    endif

    if a:0 > 0
        let fromdir= a:1
    else
        let fromdir= getcwd()
    endif

    if type(a:fname) == 1
        " handle uploading a single file using NetWrite
        1split
        exe "NetrwKeepj e ".fnameescape(s:NetrwFile(a:fname))
        if a:tgt =~ '/$'
            let wfname= substitute(a:fname,'^.*/','','')
            exe "w! ".fnameescape(a:tgt.wfname)
        else
            exe "w ".fnameescape(a:tgt)
        endif
        q!

    elseif type(a:fname) == 3
        " handle uploading a list of files via scp
        let curdir= getcwd()
        if a:tgt =~ '^scp:'
            if s:NetrwLcd(fromdir)
                return
            endif
            let filelist= deepcopy(s:netrwmarkfilelist_{bufnr('%')})
            let args    = join(map(filelist,"netrw#os#Escape(v:val, 1)"))
            if exists("g:netrw_port") && g:netrw_port != ""
                let useport= " ".g:netrw_scpport." ".g:netrw_port
            else
                let useport= ""
            endif
            let machine = substitute(a:tgt,'^scp://\([^/:]\+\).*$','\1','')
            let tgt     = substitute(a:tgt,'^scp://[^/]\+/\(.*\)$','\1','')
            call netrw#os#Execute(s:netrw_silentxfer."!".g:netrw_scp_cmd.netrw#os#Escape(useport,1)." ".args." ".netrw#os#Escape(machine.":".tgt,1))
            if s:NetrwLcd(curdir)
                return
            endif

        elseif a:tgt =~ '^ftp:'
            call s:NetrwMethod(a:tgt)
            if !s:NetrwValidateHostname(g:netrw_machine)
                call netrw#msg#Notify('ERROR', printf('Rejecting invalid hostname: <%s>', g:netrw_machine))
                return
            endif

            if b:netrw_method == 2
                " handle uploading a list of files via ftp+.netrc
                let netrw_fname = b:netrw_fname
                sil NetrwKeepj new

                NetrwKeepj put =g:netrw_ftpmode

                if exists("g:netrw_ftpextracmd")
                    NetrwKeepj put =g:netrw_ftpextracmd
                endif

                NetrwKeepj call setline(line("$")+1,'lcd "'.fromdir.'"')

                if tgtdir == ""
                    let tgtdir= '/'
                endif
                NetrwKeepj call setline(line("$")+1,'cd "'.tgtdir.'"')

                for fname in a:fname
                    NetrwKeepj call setline(line("$")+1,'put "'.s:NetrwFile(fname).'"')
                endfor

                if exists("g:netrw_port") && g:netrw_port != ""
                    call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1)." ".netrw#os#Escape(g:netrw_port,1))
                else
                    call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1))
                endif
                " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
                sil NetrwKeepj g/Local directory now/d
                call histdel("/",-1)
                if getline(1) !~ "^$" && getline(1) !~ '^Trying '
                    call netrw#msg#Notify('ERROR', getline(1))
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
                else
                    NetrwKeepj put ='open '.g:netrw_machine
                endif

                if exists("g:netrw_uid") && g:netrw_uid != ""
                    if exists("g:netrw_ftp") && g:netrw_ftp == 1
                        NetrwKeepj put =g:netrw_uid
                        if exists("s:netrw_passwd")
                            NetrwKeepj call setline(line("$")+1,'"'.s:netrw_passwd.'"')
                        endif
                    elseif exists("s:netrw_passwd")
                        NetrwKeepj put ='user \"'.g:netrw_uid.'\" \"'.s:netrw_passwd.'\"'
                    endif
                endif

                NetrwKeepj call setline(line("$")+1,'lcd "'.fromdir.'"')

                if exists("b:netrw_fname") && b:netrw_fname != ""
                    NetrwKeepj call setline(line("$")+1,'cd "'.b:netrw_fname.'"')
                endif

                if exists("g:netrw_ftpextracmd")
                    NetrwKeepj put =g:netrw_ftpextracmd
                endif

                for fname in a:fname
                    NetrwKeepj call setline(line("$")+1,'put "'.fname.'"')
                endfor

                " perform ftp:
                " -i       : turns off interactive prompting from ftp
                " -n  unix : DON'T use <.netrc>, even though it exists
                " -n  win32: quit being obnoxious about password
                NetrwKeepj norm! 1G"_dd
                call netrw#os#Execute(s:netrw_silentxfer."%!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
                " If the result of the ftp operation isn't blank, show an error message (tnx to Doug Claar)
                sil NetrwKeepj g/Local directory now/d
                call histdel("/",-1)
                if getline(1) !~ "^$" && getline(1) !~ '^Trying '
                    let debugkeep= &debug
                    setl debug=msg
                    call netrw#msg#Notify('ERROR', getline(1))
                    let &debug = debugkeep
                    let mod    = 1
                else
                    bw!|q
                endif
            elseif !exists("b:netrw_method") || b:netrw_method < 0
                return
            endif
        else
            call netrw#msg#Notify('ERROR', printf("can't obtain files with protocol from<%s>", a:tgt))
        endif
    endif

endfunction

" s:NetrwPreview: supports netrw's "p" map {{{2
function s:NetrwPreview(path) range
    let ykeep= @@
    NetrwKeepj call s:NetrwOptionsSave("s:")
    if a:path !~ '^\*\{1,2}/' && a:path !~ '^\a\{3,}://'
        NetrwKeepj call s:NetrwOptionsSafe(1)
    else
        NetrwKeepj call s:NetrwOptionsSafe(0)
    endif
    if has("quickfix")
        if !isdirectory(s:NetrwFile(a:path))
            if g:netrw_preview
                " vertical split
                let pvhkeep = &pvh
                let winsz   = (g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize
                let &pvh    = winwidth(0) - winsz
            else
                " horizontal split
                let pvhkeep = &pvh
                let winsz   = (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
                let &pvh    = winheight(0) - winsz
            endif
            " g:netrw_preview   g:netrw_alto
            "    1 : vert        1: top       -- preview window is vertically   split off and on the left
            "    1 : vert        0: bot       -- preview window is vertically   split off and on the right
            "    0 :             1: top       -- preview window is horizontally split off and on the top
            "    0 :             0: bot       -- preview window is horizontally split off and on the bottom
            "
            " Note that the file being previewed is already known to not be a directory, hence we can avoid doing a LocalBrowseCheck() check via
            " the BufEnter event set up in netrwPlugin.vim
            let eikeep = &ei
            set ei=BufEnter
            exe (g:netrw_alto? "top " : "bot ").(g:netrw_preview? "vert " : "")."pedit ".fnameescape(a:path)
            let &ei= eikeep
            if exists("pvhkeep")
                let &pvh= pvhkeep
            endif
        else
            call netrw#msg#Notify('WARNING', printf('sorry, cannot preview a directory such as <%s>', a:path))
        endif
    else
        call netrw#msg#Notify('WARNING', 'sorry, to preview your vim needs the quickfix feature compiled in')
    endif
    NetrwKeepj call s:NetrwOptionsRestore("s:")
    let @@= ykeep
endfunction

" s:NetrwRefresh: {{{2
function s:NetrwRefresh(islocal,dirname)
    " at the current time (Mar 19, 2007) all calls to NetrwRefresh() call NetrwBrowseChgDir() first.
    setl ma noro
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

    sil! NetrwKeepj %d _
    if a:islocal
        NetrwKeepj call netrw#LocalBrowseCheck(a:dirname)
    else
        NetrwKeepj call s:NetrwBrowse(a:islocal,a:dirname)
    endif

    " restore position
    NetrwKeepj call winrestview(screenposn)

    " restore file marks
    if has("syntax") && exists("g:syntax_on") && g:syntax_on
        if exists("s:netrwmarkfilemtch_{bufnr('%')}") && s:netrwmarkfilemtch_{bufnr("%")} != ""
            exe "2match netrwMarkFile /".s:netrwmarkfilemtch_{bufnr("%")}."/"
        else
            2match none
        endif
    endif

    "  restore
    let @@= ykeep
endfunction

" s:NetrwRefreshDir: refreshes a directory by name {{{2
"                    Called by NetrwMarkFileCopy()
"                    Interfaces to s:NetrwRefresh() and s:LocalBrowseRefresh()
function s:NetrwRefreshDir(islocal,dirname)
    if g:netrw_fastbrowse == 0
        " slowest mode (keep buffers refreshed, local or remote)
        let tgtwin= bufwinnr(a:dirname)

        if tgtwin > 0
            " tgtwin is being displayed, so refresh it
            let curwin= winnr()
            exe tgtwin."wincmd w"
            NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
            exe curwin."wincmd w"

        elseif bufnr(a:dirname) > 0
            let bn= bufnr(a:dirname)
            exe "sil keepj bd ".bn
        endif

    elseif g:netrw_fastbrowse <= 1
        NetrwKeepj call s:LocalBrowseRefresh()
    endif
endfunction

" s:NetrwSetChgwin: set g:netrw_chgwin; a <cr> will use the specified
" window number to do its editing in.
" Supports   [count]C  where the count, if present, is used to specify
" a window to use for editing via the <cr> mapping.
function s:NetrwSetChgwin(...)
    if a:0 > 0
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
endfunction

" s:NetrwSetSort: sets up the sort based on the g:netrw_sort_sequence {{{2
"          What this function does is to compute a priority for the patterns
"          in the g:netrw_sort_sequence.  It applies a substitute to any
"          "files" that satisfy each pattern, putting the priority / in
"          front.  An "*" pattern handles the default priority.
function s:NetrwSetSort()
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

        " sanity check
        if w:netrw_bannercnt > line("$")
            " apparently no files were left after a Hiding pattern was used
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

endfunction

" s:NetrwSetTgt: sets the target to the specified choice index {{{2
"    Implements [count]Tb  (bookhist<b>)
"               [count]Th  (bookhist<h>)
"               See :help netrw-qb for how to make the choice.
function s:NetrwSetTgt(islocal,bookhist,choice)

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

endfunction

" s:NetrwSortStyle: change sorting style (name - time - size - exten) and refresh display {{{2
function s:NetrwSortStyle(islocal)
    NetrwKeepj call s:NetrwSaveWordPosn()
    let svpos= winsaveview()

    let g:netrw_sort_by= (g:netrw_sort_by =~# '^n')? 'time' : (g:netrw_sort_by =~# '^t')? 'size' : (g:netrw_sort_by =~# '^siz')? 'exten' : 'name'
    NetrwKeepj norm! 0
    NetrwKeepj call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
    NetrwKeepj call winrestview(svpos)
endfunction

" s:NetrwSplit: mode {{{2
"           =0 : net   and o
"           =1 : net   and t
"           =2 : net   and v
"           =3 : local and o
"           =4 : local and t
"           =5 : local and v
function s:NetrwSplit(mode)

    let ykeep= @@
    call s:SaveWinVars()

    if a:mode == 0
        " remote and o
        let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
        if winsz == 0|let winsz= ""|endif
        exe (g:netrw_alto? "bel " : "abo ").winsz."wincmd s"
        let s:didsplit= 1
        NetrwKeepj call s:RestoreWinVars()
        NetrwKeepj call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,s:NetrwGetWord(),1))
        unlet s:didsplit

    elseif a:mode == 1
        " remote and t
        let newdir  = s:NetrwBrowseChgDir(0,s:NetrwGetWord(),1)
        tabnew
        let s:didsplit= 1
        NetrwKeepj call s:RestoreWinVars()
        NetrwKeepj call s:NetrwBrowse(0,newdir)
        unlet s:didsplit

    elseif a:mode == 2
        " remote and v
        let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winwidth(0))/100 : -g:netrw_winsize
        if winsz == 0|let winsz= ""|endif
        exe (g:netrw_altv? "rightb " : "lefta ").winsz."wincmd v"
        let s:didsplit= 1
        NetrwKeepj call s:RestoreWinVars()
        NetrwKeepj call s:NetrwBrowse(0,s:NetrwBrowseChgDir(0,s:NetrwGetWord(),1))
        unlet s:didsplit

    elseif a:mode == 3
        " local and o
        let winsz= (g:netrw_winsize > 0)? (g:netrw_winsize*winheight(0))/100 : -g:netrw_winsize
        if winsz == 0|let winsz= ""|endif
        exe (g:netrw_alto? "bel " : "abo ").winsz."wincmd s"
        let s:didsplit= 1
        NetrwKeepj call s:RestoreWinVars()
        NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,s:NetrwGetWord(),1))
        unlet s:didsplit
        if &ea
            exe "keepalt wincmd ="
        endif

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
        tabnew
        let b:netrw_curdir = netrw_curdir
        let s:didsplit     = 1
        NetrwKeepj call s:RestoreWinVars()
        NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,cursorword,0))
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
        exe (g:netrw_altv? "rightb " : "lefta ").winsz."wincmd v"
        let s:didsplit= 1
        NetrwKeepj call s:RestoreWinVars()
        NetrwKeepj call netrw#LocalBrowseCheck(s:NetrwBrowseChgDir(1,s:NetrwGetWord(),1))
        unlet s:didsplit
        if &ea
            exe "keepalt wincmd ="
        endif

    else
        call netrw#msg#Notify('ERROR', '(NetrwSplit) unsupported mode='.a:mode)
    endif

    let @@= ykeep
endfunction

" s:NetrwTgtMenu: {{{2
function s:NetrwTgtMenu()
    if !exists("s:netrw_menucnt")
        return
    endif

    " the following test assures that gvim is running, has menus available, and has menus enabled.
    if has("gui") && has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu
        if exists("g:NetrwTopLvlMenu")
            exe 'sil! unmenu '.g:NetrwTopLvlMenu.'Targets'
        endif
        if !exists("s:netrw_initbookhist")
            call s:NetrwBookHistRead()
        endif

        " try to cull duplicate entries
        let tgtdict={}

        " target bookmarked places
        if exists("g:netrw_bookmarklist") && g:netrw_bookmarklist != [] && g:netrw_dirhistmax > 0
            let cnt= 1
            for bmd in g:netrw_bookmarklist
                if has_key(tgtdict,bmd)
                    let cnt= cnt + 1
                    continue
                endif
                let tgtdict[bmd]= cnt
                let ebmd= escape(bmd,g:netrw_menu_escape)
                " show bookmarks for goto menu
                exe 'sil! menu <silent> '.g:NetrwMenuPriority.".19.1.".cnt." ".g:NetrwTopLvlMenu.'Targets.'.ebmd." :call netrw#MakeTgt('".bmd."')\<cr>"
                let cnt= cnt + 1
            endfor
        endif

        " target directory browsing history
        if exists("g:netrw_dirhistmax") && g:netrw_dirhistmax > 0
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
                    exe 'sil! menu <silent> '.g:NetrwMenuPriority.".19.2.".priority." ".g:NetrwTopLvlMenu.'Targets.'.ehistentry."     :call netrw#MakeTgt('".histentry."')\<cr>"
                endif
                let histcnt = histcnt + 1
            endwhile
        endif
    endif
endfunction

" s:NetrwTreeDir: determine tree directory given current cursor position {{{2
" (full path directory with trailing slash returned)
function s:NetrwTreeDir(islocal)

    if exists("s:treedir") && exists("s:prevwinopen")
        " s:NetrwPrevWinOpen opens a "previous" window -- and thus needs to and does call s:NetrwTreeDir early
        let treedir= s:treedir
        unlet s:treedir
        unlet s:prevwinopen
        return treedir
    endif
    if exists("s:prevwinopen")
        unlet s:prevwinopen
    endif

    if !exists("b:netrw_curdir") || b:netrw_curdir == ""
        let b:netrw_curdir= getcwd()
    endif
    let treedir = b:netrw_curdir
    let s:treecurpos= winsaveview()

    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST

        " extract tree directory if on a line specifying a subdirectory (ie. ends with "/")
        let curline= substitute(getline('.'),"\t -->.*$",'','')
        if curline =~ '/$'
            let treedir= substitute(getline('.'),'^\%('.s:treedepthstring.'\)*\([^'.s:treedepthstring.'].\{-}\)$','\1','e')
        elseif curline =~ '@$'
            let potentialdir= resolve(s:NetrwTreePath(w:netrw_treetop))
        else
            let treedir= ""
        endif

        " detect user attempting to close treeroot
        if curline !~ '^'.s:treedepthstring && getline('.') != '..'
            " now force a refresh
            sil! NetrwKeepj %d _
            return b:netrw_curdir
        endif

        " COMBAK: a symbolic link may point anywhere -- so it will be used to start a new treetop
        "   if a:islocal && curline =~ '@$' && isdirectory(s:NetrwFile(potentialdir))
        "    let newdir          = w:netrw_treetop.'/'.potentialdir
        if a:islocal && curline =~ '@$'
            if isdirectory(s:NetrwFile(potentialdir))
                let treedir = potentialdir
                let w:netrw_treetop = treedir
            endif
        else
            let potentialdir= s:NetrwFile(substitute(curline,'^'.s:treedepthstring.'\+ \(.*\)@$','\1',''))
            let treedir = s:NetrwTreePath(w:netrw_treetop)
        endif
    endif

    " sanity maintenance: keep those //s away...
    let treedir= substitute(treedir,'//$','/','')
    return treedir
endfunction

" s:NetrwTreeDisplay: recursive tree display {{{2
function s:NetrwTreeDisplay(dir,depth)
    " ensure that there are no folds
    setl nofen

    " install ../ and shortdir
    if a:depth == ""
        call setline(line("$")+1,'../')
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
    " append a / to dir if its missing one
    let dir= a:dir

    " display subtrees (if any)
    let depth= s:treedepthstring.a:depth

    " implement g:netrw_hide for tree listings (uses g:netrw_list_hide)
    if     g:netrw_hide == 1
        " hide given patterns
        let listhide= split(g:netrw_list_hide,',')
        for pat in listhide
            call filter(w:netrw_treedict[dir],'v:val !~ "'.escape(pat,'\\').'"')
        endfor

    elseif g:netrw_hide == 2
        " show given patterns (only)
        let listhide= split(g:netrw_list_hide,',')
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
        call filter(w:netrw_treedict[dir],'v:val !~ "\\.\\./$"')
        call filter(w:netrw_treedict[dir],'v:val !~ "\\.$"')
        call filter(w:netrw_treedict[dir],'v:val !~ "\\./$"')
    endif

    for entry in w:netrw_treedict[dir]
        if dir =~ '/$'
            let direntry= substitute(dir.entry,'[@/]$','','e')
        else
            let direntry= substitute(dir.'/'.entry,'[@/]$','','e')
        endif
        if entry =~ '/$' && has_key(w:netrw_treedict,direntry)
            NetrwKeepj call s:NetrwTreeDisplay(direntry,depth)
        elseif entry =~ '/$' && has_key(w:netrw_treedict,direntry.'/')
            NetrwKeepj call s:NetrwTreeDisplay(direntry.'/',depth)
        elseif entry =~ '@$' && has_key(w:netrw_treedict,direntry.'@')
            NetrwKeepj call s:NetrwTreeDisplay(direntry.'@',depth)
        else
            sil! NetrwKeepj call setline(line("$")+1,depth.entry)
        endif
    endfor
endfunction

" s:NetrwRefreshTreeDict: updates the contents information for a tree (w:netrw_treedict) {{{2
function s:NetrwRefreshTreeDict(dir)
    if !exists("w:netrw_treedict")
        return
    endif

    for entry in w:netrw_treedict[a:dir]
        let direntry= substitute(a:dir.'/'.entry,'[@/]$','','e')

        if entry =~ '/$' && has_key(w:netrw_treedict,direntry)
            NetrwKeepj call s:NetrwRefreshTreeDict(direntry)
            let filelist = s:NetrwLocalListingList(direntry,0)
            let w:netrw_treedict[direntry] = sort(filelist)

        elseif entry =~ '/$' && has_key(w:netrw_treedict,direntry.'/')
            NetrwKeepj call s:NetrwRefreshTreeDict(direntry.'/')
            let filelist = s:NetrwLocalListingList(direntry.'/',0)
            let w:netrw_treedict[direntry] = sort(filelist)

        elseif entry =~ '@$' && has_key(w:netrw_treedict,direntry.'@')
            NetrwKeepj call s:NetrwRefreshTreeDict(direntry.'/')
            let liststar   = netrw#fs#Glob(direntry.'/','*',1)
            let listdotstar= netrw#fs#Glob(direntry.'/','.*',1)

        else
        endif
    endfor
endfunction

" s:NetrwTreeListing: displays tree listing from treetop on down, using NetrwTreeDisplay() {{{2
"                     Called by s:PerformListing()
function s:NetrwTreeListing(dirname)
    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST

        " update the treetop
        if !exists("w:netrw_treetop")
            let w:netrw_treetop= a:dirname
            let s:netrw_treetop= w:netrw_treetop
        " use \V in case the directory contains specials chars like '$' or '~'
        elseif (w:netrw_treetop =~ ('^'.'\V'.a:dirname)
                    \ && strdisplaywidth(a:dirname) < strdisplaywidth(w:netrw_treetop))
                    \ || a:dirname !~ ('^'.'\V'.w:netrw_treetop)
            let w:netrw_treetop= a:dirname
            let s:netrw_treetop= w:netrw_treetop
        endif
        if exists("w:netrw_treetop")
            let s:netrw_treetop= w:netrw_treetop
        else
            let w:netrw_treetop= getcwd()
            let s:netrw_treetop= w:netrw_treetop
        endif

        if !exists("w:netrw_treedict")
            " insure that we have a treedict, albeit empty
            let w:netrw_treedict= {}
        endif

        " update the dictionary for the current directory
        exe "sil! NetrwKeepj keepp ".w:netrw_bannercnt.',$g@^\.\.\=/$@d _'
        let w:netrw_treedict[a:dirname]= getline(w:netrw_bannercnt,line("$"))
        exe "sil! NetrwKeepj ".w:netrw_bannercnt.",$d _"

        " if past banner, record word
        if exists("w:netrw_bannercnt") && line(".") > w:netrw_bannercnt
            let fname= expand("<cword>")
        else
            let fname= ""
        endif

        " display from treetop on down
        NetrwKeepj call s:NetrwTreeDisplay(w:netrw_treetop,"")

        " remove any blank line remaining as line#1 (happens in treelisting mode with banner suppressed)
        while getline(1) =~ '^\s*$' && byte2line(1) > 0
            1d
        endwhile

        exe "setl ".g:netrw_bufsettings

        return
    endif
endfunction

" s:NetrwTreePath: returns path to current file/directory in tree listing {{{2
"                  Normally, treetop is w:netrw_treetop, but a
"                  user of the function ( netrw#SetTreetop() )
"                  wipes that out prior to calling this function
function s:NetrwTreePath(treetop)
    if line(".") < w:netrw_bannercnt + 2
        let treedir= a:treetop
        if treedir !~ '/$'
            let treedir= treedir.'/'
        endif
        return treedir
    endif

    let svpos = winsaveview()
    let depth = substitute(getline('.'),'^\(\%('.s:treedepthstring.'\)*\)[^'.s:treedepthstring.'].\{-}$','\1','e')
    let depth = substitute(depth,'^'.s:treedepthstring,'','')
    let curline= getline('.')
    if curline =~ '/$'
        let treedir= substitute(curline,'^\%('.s:treedepthstring.'\)*\([^'.s:treedepthstring.'].\{-}\)$','\1','e')
    elseif curline =~ '@\s\+-->'
        let treedir= substitute(curline,'^\%('.s:treedepthstring.'\)*\([^'.s:treedepthstring.'].\{-}\)$','\1','e')
        let treedir= substitute(treedir,'@\s\+-->.*$','','e')
    else
        let treedir= ""
    endif
    " construct treedir by searching backwards at correct depth
    while depth != "" && search('^'.depth.'[^'.s:treedepthstring.'].\{-}/$','bW')
        let dirname= substitute(getline('.'),'^\('.s:treedepthstring.'\)*','','e')
        let treedir= dirname.treedir
        let depth  = substitute(depth,'^'.s:treedepthstring,'','')
    endwhile
    if a:treetop =~ '/$'
        let treedir= a:treetop.treedir
    else
        let treedir= a:treetop.'/'.treedir
    endif
    let treedir= substitute(treedir,'//$','/','')
    call winrestview(svpos)
    return treedir
endfunction

" s:NetrwWideListing: {{{2
function s:NetrwWideListing()

    if w:netrw_liststyle == s:WIDELIST
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
        let b:netrw_cpf= 0
        if line("$") >= w:netrw_bannercnt
            " determine the maximum filename size; use that to set cpf
            exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$g/^./if virtcol("$") > b:netrw_cpf|let b:netrw_cpf= virtcol("$")|endif'
            NetrwKeepj call histdel("/",-1)
        else
            " restore stored registers
            call s:RestoreRegister(dict)
            return
        endif
        " allow for two spaces to separate columns
        let b:netrw_cpf= b:netrw_cpf + 2

        " determine qty files per line (fpl)
        let w:netrw_fpl= winwidth(0)/b:netrw_cpf
        if w:netrw_fpl <= 0
            let w:netrw_fpl= 1
        endif

        " make wide display
        "   fpc: files per column of wide listing
        exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$s/^.*$/\=escape(printf("%-'.b:netrw_cpf.'S",submatch(0)),"\\")/'
        NetrwKeepj call histdel("/",-1)
        let fpc         = (line("$") - w:netrw_bannercnt + w:netrw_fpl)/w:netrw_fpl
        let newcolstart = w:netrw_bannercnt + fpc
        let newcolend   = newcolstart + fpc - 1
        if !has('nvim') && has("clipboard") && g:netrw_clipboard
            sil! let keepregstar = @*
            sil! let keepregplus = @+
        endif
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
        if !has('nvim') && has("clipboard")
            if @* != keepregstar | sil! let @* = keepregstar | endif
            if @+ != keepregplus | sil! let @+ = keepregplus | endif
        endif
        exe "sil! NetrwKeepj ".w:netrw_bannercnt.',$s/\s\+$//e'
        NetrwKeepj call histdel("/",-1)
        exe 'nno <buffer> <silent> w :call search(''^.\\|\s\s\zs\S'',''W'')'."\<cr>"
        exe 'nno <buffer> <silent> b :call search(''^.\\|\s\s\zs\S'',''bW'')'."\<cr>"
        exe "setl ".g:netrw_bufsettings
        call s:RestoreRegister(dict)
        return
    else
        if hasmapto("w","n")
            sil! nunmap <buffer> w
        endif
        if hasmapto("b","n")
            sil! nunmap <buffer> b
        endif
    endif
endfunction

" s:PerformListing: {{{2
function s:PerformListing(islocal)
    sil! NetrwKeepj %d _
    "  call DechoBuf(bufnr("%"))

    " set up syntax highlighting {{{3
    sil! setl ft=netrw

    NetrwKeepj call s:NetrwOptionsSafe(a:islocal)
    setl noro ma


    if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treedict")
        " force a refresh for tree listings
        sil! NetrwKeepj %d _
    endif

    " save current directory on directory history list
    NetrwKeepj call s:NetrwBookHistHandler(3,b:netrw_curdir)

    " Set up the banner {{{3
    if g:netrw_banner
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
        NetrwKeepj 1
        let w:netrw_bannercnt= 1
    endif

    " construct sortby string: [name|time|size|exten] [reversed]
    let sortby= g:netrw_sort_by
    if g:netrw_sort_direction =~# "^r"
        let sortby= sortby." reversed"
    endif

    " Sorted by... {{{3
    if g:netrw_banner
        if g:netrw_sort_by =~# "^n"
            " sorted by name (also includes the sorting sequence in the banner)
            NetrwKeepj put ='\"   Sorted by      '.sortby
            NetrwKeepj put ='\"   Sort sequence: '.g:netrw_sort_sequence
            let w:netrw_bannercnt= w:netrw_bannercnt + 2
        else
            " sorted by time, size, exten
            NetrwKeepj put ='\"   Sorted by '.sortby
            let w:netrw_bannercnt= w:netrw_bannercnt + 1
        endif
        exe "sil! NetrwKeepj ".w:netrw_bannercnt
    endif

    " show copy/move target, if any {{{3
    if g:netrw_banner
        if exists("s:netrwmftgt") && exists("s:netrwmftgt_islocal")
            NetrwKeepj put =''
            if s:netrwmftgt_islocal
                sil! NetrwKeepj call setline(line("."),'"   Copy/Move Tgt: '.s:netrwmftgt.' (local)')
            else
                sil! NetrwKeepj call setline(line("."),'"   Copy/Move Tgt: '.s:netrwmftgt.' (remote)')
            endif
            let w:netrw_bannercnt= w:netrw_bannercnt + 1
        else
        endif
        exe "sil! NetrwKeepj ".w:netrw_bannercnt
    endif

    " Hiding...  -or-  Showing... {{{3
    if g:netrw_banner
        if g:netrw_list_hide != "" && g:netrw_hide
            if g:netrw_hide == 1
                NetrwKeepj put ='\"   Hiding:        '.g:netrw_list_hide
            else
                NetrwKeepj put ='\"   Showing:       '.g:netrw_list_hide
            endif
            let w:netrw_bannercnt= w:netrw_bannercnt + 1
        endif
        exe "NetrwKeepj ".w:netrw_bannercnt

        let quickhelp   = g:netrw_quickhelp%len(s:QuickHelp)
        NetrwKeepj put ='\"   Quick Help: <F1>:help  '.s:QuickHelp[quickhelp]
        NetrwKeepj put ='\" =============================================================================='
        let w:netrw_bannercnt= w:netrw_bannercnt + 2
    endif

    " bannercnt should index the line just after the banner
    if g:netrw_banner
        let w:netrw_bannercnt= w:netrw_bannercnt + 1
        exe "sil! NetrwKeepj ".w:netrw_bannercnt
    endif

    " get list of files
    if a:islocal
        let filelist = s:NetrwLocalListingList(b:netrw_curdir, 1)
        call append(w:netrw_bannercnt - 1, filelist)
        silent! NetrwKeepj g/^$/d
        silent! NetrwKeepj %s/\r$//e
        execute printf("setl ts=%d", g:netrw_maxfilenamelen + 1)
    else " remote
        NetrwKeepj let badresult= s:NetrwRemoteListing()
        if badresult
            return
        endif
    endif

    " manipulate the directory listing (hide, sort) {{{3
    if !exists("w:netrw_bannercnt")
        let w:netrw_bannercnt= 0
    endif

    if !g:netrw_banner || line("$") >= w:netrw_bannercnt
        if g:netrw_hide && g:netrw_list_hide != ""
            NetrwKeepj call s:NetrwListHide()
        endif
        if !g:netrw_banner || line("$") >= w:netrw_bannercnt

            if g:netrw_sort_by =~# "^n"
                " sort by name
                NetrwKeepj call s:NetrwSetSort()

                if !g:netrw_banner || w:netrw_bannercnt < line("$")
                    if g:netrw_sort_direction =~# 'n'
                        " name: sort by name of file
                        exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$sort'.' '.g:netrw_sort_options
                    else
                        " reverse direction sorting
                        exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$sort!'.' '.g:netrw_sort_options
                    endif
                endif

                " remove priority pattern prefix
                exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^\d\{3}'.g:netrw_sepchr.'//e'
                NetrwKeepj call histdel("/",-1)

            elseif g:netrw_sort_by =~# "^ext"
                " exten: sort by extension
                "   The histdel(...,-1) calls remove the last search from the search history
                exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$g+/+s/^/001'.g:netrw_sepchr.'/'
                NetrwKeepj call histdel("/",-1)
                exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$v+[./]+s/^/002'.g:netrw_sepchr.'/'
                NetrwKeepj call histdel("/",-1)
                exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$v+['.g:netrw_sepchr.'/]+s/^\(.*\.\)\(.\{-\}\)$/\2'.g:netrw_sepchr.'&/e'
                NetrwKeepj call histdel("/",-1)
                if !g:netrw_banner || w:netrw_bannercnt < line("$")
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
                    if g:netrw_sort_direction =~# 'n'
                        exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$sort'.' '.g:netrw_sort_options
                    else
                        exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$sort!'.' '.g:netrw_sort_options
                    endif
                    exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^\d\{-}\///e'
                    NetrwKeepj call histdel("/",-1)
                endif
            endif

        elseif g:netrw_sort_direction =~# 'r'
            if !g:netrw_banner || w:netrw_bannercnt < line('$')
                exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$g/^/m '.w:netrw_bannercnt
                call histdel("/",-1)
            endif
        endif
    endif

    " convert to wide/tree listing {{{3
    NetrwKeepj call s:NetrwWideListing()
    NetrwKeepj call s:NetrwTreeListing(b:netrw_curdir)

    " resolve symbolic links if local and (thin or tree)
    if a:islocal && (w:netrw_liststyle == s:THINLIST || (exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST))
        sil! keepp g/@$/call s:ShowLink()
    endif

    if exists("w:netrw_bannercnt") && (line("$") >= w:netrw_bannercnt || !g:netrw_banner)
        " place cursor on the top-left corner of the file listing
        exe 'sil! '.w:netrw_bannercnt
        sil! NetrwKeepj norm! 0
    else
    endif

    " record previous current directory
    let w:netrw_prvdir= b:netrw_curdir

    " save certain window-oriented variables into buffer-oriented variables {{{3
    NetrwKeepj call s:SetBufWinVars()
    NetrwKeepj call s:NetrwOptionsRestore("w:")

    " set display to netrw display settings
    exe "setl ".g:netrw_bufsettings
    if g:netrw_liststyle == s:LONGLIST
        exe "setl ts=".(g:netrw_maxfilenamelen+1)
    endif
    "  call DechoBuf(bufnr("%"))

    if exists("s:treecurpos")
        NetrwKeepj call winrestview(s:treecurpos)
        unlet s:treecurpos
    endif

endfunction

" s:SetupNetrwStatusLine: {{{2
function s:SetupNetrwStatusLine(statline)

    if !exists("s:netrw_setup_statline")
        let s:netrw_setup_statline= 1

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
    redraw

endfunction

"  Remote Directory Browsing Support:  {{{1

" s:NetrwRemoteFtpCmd: unfortunately, not all ftp servers honor options for ls {{{2
"  This function assumes that a long listing will be received.  Size, time,
"  and reverse sorts will be requested of the server but not otherwise
"  enforced here.
function s:NetrwRemoteFtpCmd(path,listcmd)
    " sanity check: {{{3
    if !exists("w:netrw_method")
        if exists("b:netrw_method")
            let w:netrw_method= b:netrw_method
        else
            call netrw#msg#Notify('ERROR', '(s:NetrwRemoteFtpCmd) internal netrw error')
            return
        endif
    endif

    " WinXX ftp uses unix style input, so set ff to unix  " {{{3
    let ffkeep= &ff
    setl ma ff=unix noro

    " clear off any older non-banner lines        " {{{3
    " note that w:netrw_bannercnt indexes the line after the banner
    exe "sil! NetrwKeepj ".w:netrw_bannercnt.",$d _"

    ".........................................
    if w:netrw_method == 2 || w:netrw_method == 5 " {{{3
        " ftp + <.netrc>:  Method #2
        if a:path != ""
            NetrwKeepj put ='cd \"'.a:path.'\"'
        endif
        if exists("g:netrw_ftpextracmd")
            NetrwKeepj put =g:netrw_ftpextracmd
        endif
        NetrwKeepj call setline(line("$")+1,a:listcmd)
        if exists("g:netrw_port") && g:netrw_port != ""
            exe s:netrw_silentxfer." NetrwKeepj ".w:netrw_bannercnt.",$!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1)." ".netrw#os#Escape(g:netrw_port,1)
        else
            exe s:netrw_silentxfer." NetrwKeepj ".w:netrw_bannercnt.",$!".s:netrw_ftp_cmd." -i ".netrw#os#Escape(g:netrw_machine,1)
        endif

        ".........................................
    elseif w:netrw_method == 3    " {{{3
        " ftp + machine,id,passwd,filename:  Method #3
        setl ff=unix
        if exists("g:netrw_port") && g:netrw_port != ""
            NetrwKeepj put ='open '.g:netrw_machine.' '.g:netrw_port
        else
            NetrwKeepj put ='open '.g:netrw_machine
        endif

        " handle userid and password
        let host= substitute(g:netrw_machine,'\..*$','','')
        if exists("s:netrw_hup") && exists("s:netrw_hup[host]")
            call netrw#NetUserPass("ftp:".host)
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
        endif
        NetrwKeepj call setline(line("$")+1,a:listcmd)

        " perform ftp:
        " -i       : turns off interactive prompting from ftp
        " -n  unix : DON'T use <.netrc>, even though it exists
        " -n  win32: quit being obnoxious about password
        if exists("w:netrw_bannercnt")
            call netrw#os#Execute(s:netrw_silentxfer.w:netrw_bannercnt.",$!".s:netrw_ftp_cmd." ".g:netrw_ftp_options)
        endif

        ".........................................
    elseif w:netrw_method == 9    " {{{3
        " sftp username@machine: Method #9
        " s:netrw_sftp_cmd
        setl ff=unix

        " restore settings
        let &l:ff= ffkeep
        return

        ".........................................
    else  " {{{3
        call netrw#msg#Notify('WARNING', printf('unable to comply with your request<%s>', bufname("%")))
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
endfunction

" s:NetrwRemoteListing: {{{2
function s:NetrwRemoteListing()

    if !exists("w:netrw_bannercnt") && exists("s:bannercnt")
        let w:netrw_bannercnt= s:bannercnt
    endif
    if !exists("w:netrw_bannercnt") && exists("b:bannercnt")
        let w:netrw_bannercnt= b:bannercnt
    endif

    call s:RemotePathAnalysis(b:netrw_curdir)

    " sanity check:
    if exists("b:netrw_method") && b:netrw_method =~ '[235]'
        if !executable("ftp")
            call netrw#msg#Notify('ERROR', "this system doesn't support remote directory listing via ftp")
            call s:NetrwOptionsRestore("w:")
            return -1
        endif

    elseif !exists("g:netrw_list_cmd") || g:netrw_list_cmd == ''
        if g:netrw_list_cmd == ""
            call netrw#msg#Notify('ERROR', printf('your g:netrw_list_cmd is empty; perhaps %s is not executable on your system', g:netrw_ssh_cmd))
        else
            call netrw#msg#Notify('ERROR', "this system doesn't support remote directory listing via ".g:netrw_list_cmd)
        endif

        NetrwKeepj call s:NetrwOptionsRestore("w:")
        return -1
    endif  " (remote handling sanity check)

    if exists("b:netrw_method")
        let w:netrw_method= b:netrw_method
    endif

    if s:method == "ftp"
        " use ftp to get remote file listing {{{3
        let s:method  = "ftp"
        let listcmd = g:netrw_ftp_list_cmd
        if g:netrw_sort_by =~# '^t'
            let listcmd= g:netrw_ftp_timelist_cmd
        elseif g:netrw_sort_by =~# '^s'
            let listcmd= g:netrw_ftp_sizelist_cmd
        endif
        call s:NetrwRemoteFtpCmd(s:path,listcmd)

        " report on missing file or directory messages
        if search('[Nn]o such file or directory\|Failed to change directory')
            let mesg= getline(".")
            if exists("w:netrw_bannercnt")
                setl ma
                exe w:netrw_bannercnt.",$d _"
                setl noma
            endif
            NetrwKeepj call s:NetrwOptionsRestore("w:")
            call netrw#msg#Notify('WARNING', mesg)
            return -1
        endif

        if w:netrw_liststyle == s:THINLIST || w:netrw_liststyle == s:WIDELIST || (exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST)
            " shorten the listing
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
            if line2 == 0
                sil! NetrwKeepj put='../'
            endif
            exe "sil! NetrwKeepj ".line1
            sil! NetrwKeepj norm! 0

            if search('^\d\{2}-\d\{2}-\d\{2}\s','n') " M$ ftp site cleanup
                exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^\d\{2}-\d\{2}-\d\{2}\s\+\d\+:\d\+[AaPp][Mm]\s\+\%(<DIR>\|\d\+\)\s\+//'
                NetrwKeepj call histdel("/",-1)
            else " normal ftp cleanup
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
        let listcmd= s:MakeSshCmd(g:netrw_list_cmd)
        if g:netrw_scp_cmd =~ '^pscp'
            exe "NetrwKeepj r! ".listcmd.netrw#os#Escape(s:path, 1)
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
                exe "NetrwKeepj keepalt r! ".listcmd
            else
                exe "NetrwKeepj keepalt r! ".listcmd.' '.netrw#os#Escape(fnameescape(s:path),1)
            endif
        endif

        " cleanup
        if g:netrw_ssh_browse_reject != ""
            exe "sil! g/".g:netrw_ssh_browse_reject."/NetrwKeepj d"
            NetrwKeepj call histdel("/",-1)
        endif
    endif

    if w:netrw_liststyle == s:LONGLIST
        " do a long listing; these substitutions need to be done prior to sorting {{{3

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
            exe 'sil! NetrwKeepj '.w:netrw_bannercnt.',$s/^\(\d\{2}-\d\{2}-\d\{2}\s\+\d\+:\d\+[AaPp][Mm]\s\+\%(<DIR>\|\d\+\)\s\+\)\(\w.*\)$/\2\t\1/'
        elseif exists("w:netrw_bannercnt") && w:netrw_bannercnt <= line("$")
            exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$s/ -> .*$//e'
            exe 'sil NetrwKeepj '.w:netrw_bannercnt.',$s/^\(\%(\S\+\s\+\)\{7}\S\+\)\s\+\(\S.*\)$/\2 \t\1/e'
            exe 'sil NetrwKeepj '.w:netrw_bannercnt
            NetrwKeepj call histdel("/",-1)
            NetrwKeepj call histdel("/",-1)
            NetrwKeepj call histdel("/",-1)
        endif
    endif


    return 0
endfunction

" s:NetrwRemoteRm: remove/delete a remote file or directory {{{2
function s:NetrwRemoteRm(usrhost,path) range
    let svpos= winsaveview()

    let all= 0
    if exists("s:netrwmarkfilelist_{bufnr('%')}")
        " remove all marked files
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
    NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./',0))
    NetrwKeepj call winrestview(svpos)
endfunction

" s:NetrwRemoteRmFile: {{{2
function s:NetrwRemoteRmFile(path,rmfile,all)

    let all= a:all
    let ok = ""

    if a:rmfile !~ '^"' && (a:rmfile =~ '@$' || a:rmfile !~ '[\/]$')
        " attempt to remove file
        if !all
            echohl Statement
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
            if exists("w:netrw_method") && (w:netrw_method == 2 || w:netrw_method == 3)
                let path= a:path
                if path =~ '^\a\{3,}://'
                    let path= substitute(path,'^\a\{3,}://[^/]\+/','','')
                endif
                sil! NetrwKeepj .,$d _
                call s:NetrwRemoteFtpCmd(path,"delete ".'"'.a:rmfile.'"')
            else
                let netrw_rm_cmd= s:MakeSshCmd(g:netrw_rm_cmd)
                if !exists("b:netrw_curdir")
                    call netrw#msg#Notify('ERROR', "for some reason b:netrw_curdir doesn't exist!")
                    let ok="q"
                else
                    let remotedir= substitute(b:netrw_curdir,'^.\{-}//[^/]\+/\(.*\)$','\1','')
                    if remotedir != ""
                        let netrw_rm_cmd= netrw_rm_cmd." ".netrw#os#Escape(fnameescape(remotedir.a:rmfile))
                    else
                        let netrw_rm_cmd= netrw_rm_cmd." ".netrw#os#Escape(fnameescape(a:rmfile))
                    endif
                    let ret= system(netrw_rm_cmd)
                    if v:shell_error != 0
                        if exists("b:netrw_curdir") && b:netrw_curdir != getcwd() && !g:netrw_keepdir
                            call netrw#msg#Notify('ERROR', printf("remove failed; perhaps due to vim's current directory<%s> not matching netrw's (%s) (see :help netrw-cd)", getcwd(), b:netrw_curdir))
                        else
                            call netrw#msg#Notify('WARNING', printf('cmd<%s> failed', netrw_rm_cmd))
                        endif
                    elseif ret != 0
                        call netrw#msg#Notify('WARNING', printf('cmd<%s> failed', netrw_rm_cmd))
                    endif
                endif
            endif
        elseif ok =~# 'q\%[uit]'
        endif

    else
        " attempt to remove directory
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
                let netrw_rmdir_cmd = s:MakeSshCmd(netrw#fs#WinPath(g:netrw_rmdir_cmd)).' '.netrw#os#Escape(netrw#fs#WinPath(rmfile))
                let ret= system(netrw_rmdir_cmd)

                if v:shell_error != 0
                    let netrw_rmf_cmd= s:MakeSshCmd(netrw#fs#WinPath(g:netrw_rmf_cmd)).' '.netrw#os#Escape(netrw#fs#WinPath(substitute(rmfile,'[\/]$','','e')))
                    let ret= system(netrw_rmf_cmd)

                    if v:shell_error != 0
                        call netrw#msg#Notify('ERROR', printf('unable to remove directory<%s> -- is it empty?', rmfile))
                    endif
                endif
            endif

        elseif ok =~# 'q\%[uit]'
        endif
    endif

    return ok
endfunction

" s:NetrwRemoteRename: rename a remote file or directory {{{2
function s:NetrwRemoteRename(usrhost,path) range

    " preparation for removing multiple files/directories
    let svpos      = winsaveview()
    let ctr        = a:firstline
    let rename_cmd = s:MakeSshCmd(g:netrw_rename_cmd)

    " rename files given by the markfilelist
    if exists("s:netrwmarkfilelist_{bufnr('%')}")
        for oldname in s:netrwmarkfilelist_{bufnr("%")}
            if exists("subfrom")
                let newname= substitute(oldname,subfrom,subto,'')
            else
                call inputsave()
                let newname= input("Moving ".oldname." to : ",oldname)
                call inputrestore()
                if newname =~ '^s/'
                    let subfrom = substitute(newname,'^s/\([^/]*\)/.*/$','\1','')
                    let subto   = substitute(newname,'^s/[^/]*/\(.*\)/$','\1','')
                    let newname = substitute(oldname,subfrom,subto,'')
                endif
            endif

            if exists("w:netrw_method") && (w:netrw_method == 2 || w:netrw_method == 3)
                NetrwKeepj call s:NetrwRemoteFtpCmd(a:path,"rename ".oldname." ".newname)
            else
                let oldname= netrw#os#Escape(a:path.oldname)
                let newname= netrw#os#Escape(a:path.newname)
                let ret    = system(netrw#fs#WinPath(rename_cmd).' '.oldname.' '.newname)
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

            call inputsave()
            let newname= input("Moving ".oldname." to : ",oldname)
            call inputrestore()

            if exists("w:netrw_method") && (w:netrw_method == 2 || w:netrw_method == 3)
                call s:NetrwRemoteFtpCmd(a:path,"rename ".oldname." ".newname)
            else
                let oldname= netrw#os#Escape(a:path.oldname)
                let newname= netrw#os#Escape(a:path.newname)
                let ret    = system(netrw#fs#WinPath(rename_cmd).' '.oldname.' '.newname)
            endif

            let ctr= ctr + 1
        endwhile
        let &l:sol= keepsol
    endif

    " refresh the directory
    NetrwKeepj call s:NetrwRefresh(0,s:NetrwBrowseChgDir(0,'./',0))
    NetrwKeepj call winrestview(svpos)
endfunction

"  Local Directory Browsing Support:    {{{1

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
function netrw#FileUrlEdit(fname)
    let fname = a:fname
    if fname =~ '^file://localhost/'
        let fname= substitute(fname,'^file://localhost/','file:///','')
    endif
    if has("win32")
        if fname  =~ '^file:///\=\a[|:]/'
            let fname = substitute(fname,'^file:///\=\(\a\)[|:]/','file://\1:/','')
        endif
    endif
    let fname2396 = netrw#RFC2396(fname)
    let fname2396e= fnameescape(fname2396)
    let plainfname= substitute(fname2396,'file://\(.*\)','\1',"")
    if has("win32")
        if plainfname =~ '^/\+\a:'
            let plainfname= substitute(plainfname,'^/\+\(\a:\)','\1','')
        endif
    endif

    exe "sil doau BufReadPre ".fname2396e
    exe 'NetrwKeepj keepalt edit '.plainfname
    exe 'sil! NetrwKeepj keepalt bdelete '.fnameescape(a:fname)

    exe "sil doau BufReadPost ".fname2396e
endfunction

" netrw#LocalBrowseCheck: {{{2
function netrw#LocalBrowseCheck(dirname)
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
    " getting E930: Cannot use :redir inside execute

    let ykeep= @@
    if isdirectory(s:NetrwFile(a:dirname))

        if &ft != "netrw" || (exists("b:netrw_curdir") && b:netrw_curdir != a:dirname) || g:netrw_fastbrowse <= 1
            sil! NetrwKeepj keepalt call s:NetrwBrowse(1,a:dirname)

        elseif &ft == "netrw" && line("$") == 1
            sil! NetrwKeepj keepalt call s:NetrwBrowse(1,a:dirname)

        elseif exists("s:treeforceredraw")
            unlet s:treeforceredraw
            sil! NetrwKeepj keepalt call s:NetrwBrowse(1,a:dirname)
        endif
        return
    endif

    " The following code wipes out currently unused netrw buffers
    "       IF g:netrw_fastbrowse is zero (ie. slow browsing selected)
    "   AND IF the listing style is not a tree listing
    if exists("g:netrw_fastbrowse") && g:netrw_fastbrowse == 0 && g:netrw_liststyle != s:TREELIST
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
    " not a directory, ignore it
endfunction

" s:LocalBrowseRefresh: this function is called after a user has {{{2
" performed any shell command.  The idea is to cause all local-browsing
" buffers to be refreshed after a user has executed some shell command,
" on the chance that s/he removed/created a file/directory with it.
function s:LocalBrowseRefresh()
    " determine which buffers currently reside in a tab
    if !exists("s:netrw_browselist")
        return
    endif
    if !exists("w:netrw_bannercnt")
        return
    endif
    if !empty(getcmdwintype())
        " cannot move away from cmdline window, see :h E11
        return
    endif
    if exists("s:netrw_events") && s:netrw_events == 1
        " s:LocalFastBrowser gets called (indirectly) from a
        let s:netrw_events= 2
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
    "  GO through all buffers on netrw_browselist (ie. just local-netrw buffers):
    "   | refresh any netrw window
    "   | wipe out any non-displaying netrw buffer
    let curwinid = win_getid(winnr())
    let ibl    = 0
    for ibuf in s:netrw_browselist
        if bufwinnr(ibuf) == -1 && index(buftablist,ibuf) == -1
            " wipe out any non-displaying netrw buffer
            " (ibuf not shown in a current window AND
            "  ibuf not in any tab)
            exe "sil! keepj bd ".fnameescape(ibuf)
            call remove(s:netrw_browselist,ibl)
            continue
        elseif index(tabpagebuflist(),ibuf) != -1
            " refresh any netrw buffer
            exe bufwinnr(ibuf)."wincmd w"
            if getline(".") =~# 'Quick Help'
                " decrement g:netrw_quickhelp to prevent refresh from changing g:netrw_quickhelp
                " (counteracts s:NetrwBrowseChgDir()'s incrementing)
                let g:netrw_quickhelp= g:netrw_quickhelp - 1
            endif
            if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST
                NetrwKeepj call s:NetrwRefreshTreeDict(w:netrw_treetop)
            endif
            NetrwKeepj call s:NetrwRefresh(1,s:NetrwBrowseChgDir(1,'./',0))
        endif
        let ibl= ibl + 1
    endfor
    call win_gotoid(curwinid)
    let @@= ykeep
endfunction

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
function s:LocalFastBrowser()

    " initialize browselist, a list of buffer numbers that the local browser has used
    if !exists("s:netrw_browselist")
        let s:netrw_browselist= []
    endif

    " append current buffer to fastbrowse list
    if empty(s:netrw_browselist) || bufnr("%") > s:netrw_browselist[-1]
        call add(s:netrw_browselist,bufnr("%"))
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
                au ShellCmdPost                    *       call s:LocalBrowseRefresh()
            else
                au ShellCmdPost,FocusGained        *       call s:LocalBrowseRefresh()
            endif
        augroup END

    " user must have changed fastbrowse to its fast setting, so remove
    " the associated autocmd events
    elseif g:netrw_fastbrowse > 1 && exists("#ShellCmdPost") && exists("s:netrw_events")
        unlet s:netrw_events
        augroup AuNetrwEvent
            au!
        augroup END
        augroup! AuNetrwEvent
    endif
endfunction

function s:NetrwLocalListingList(dirname,setmaxfilenamelen)
    " get the list of files contained in the current directory
    let dirname    = a:dirname
    let dirnamelen = strlen(dirname)
    let filelist   = map(['.', '..'] + readdir(dirname), 'netrw#fs#PathJoin(dirname, v:val)')

    if g:netrw_cygwin == 0 && has("win32")
    elseif index(filelist,'..') == -1 && dirname !~ '/'
        " include ../ in the glob() entry if its missing
        let filelist= filelist+[netrw#fs#ComposePath(dirname,"../")]
    endif

    if a:setmaxfilenamelen && get(g:, 'netrw_dynamic_maxfilenamelen', 0)
        let filelistcopy           = map(deepcopy(filelist),'fnamemodify(v:val, ":t")')
        let g:netrw_maxfilenamelen = max(map(filelistcopy,'len(v:val)')) + 1
    endif

    let resultfilelist = []
    for filename in filelist

        let ftype = getftype(filename)
        if ftype ==# "link"
            " indicate a symbolic link
            let pfile= filename."@"

        elseif ftype ==# "socket"
            " indicate a socket
            let pfile= filename."="

        elseif ftype ==# "fifo"
            " indicate a fifo
            let pfile= filename."|"

        elseif ftype ==# "dir"
            " indicate a directory
            let pfile= filename."/"

        elseif exists("b:netrw_curdir") && b:netrw_curdir !~ '^.*://' && !isdirectory(s:NetrwFile(filename))
            if has("win32")
                if filename =~ '\.[eE][xX][eE]$' || filename =~ '\.[cC][oO][mM]$' || filename =~ '\.[bB][aA][tT]$'
                    " indicate an executable
                    let pfile= filename."*"
                else
                    " normal file
                    let pfile= filename
                endif
            elseif executable(filename)
                " indicate an executable
                let pfile= filename."*"
            else
                " normal file
                let pfile= filename
            endif

        else
            " normal file
            let pfile= filename
        endif

        if pfile =~ '//$'
            let pfile= substitute(pfile,'//$','/','e')
        endif
        let pfile= strpart(pfile,dirnamelen)
        let pfile= substitute(pfile,'^[/\\]','','e')

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
        endif

        if     g:netrw_sort_by =~# "^t"
            " sort by time (handles time up to 1 quintillion seconds, US)
            " Decorate listing by prepending a timestamp/  .  Sorting will then be done based on time.
            let t  = getftime(filename)
            let ft = printf("%018d",t)
            let ftpfile= ft.'/'.pfile
            let resultfilelist += [ftpfile]

        elseif g:netrw_sort_by =~ "^s"
            " sort by size (handles file sizes up to 1 quintillion bytes, US)
            let sz   = getfsize(filename)
            let fsz  = printf("%018d",sz)
            let fszpfile= fsz.'/'.pfile
            let resultfilelist += [fszpfile]

        else
            " sort by name
            let resultfilelist += [pfile]
        endif
    endfor

    return resultfilelist
endfunction

" s:NetrwLocalExecute: uses system() to execute command under cursor ("X" command support) {{{2
function s:NetrwLocalExecute(cmd)
    let ykeep= @@
    " sanity check
    if !executable(a:cmd)
        call netrw#msg#Notify('ERROR', printf("the file<%s> is not executable!", a:cmd))
        let @@= ykeep
        return
    endif

    let optargs= input(":!".a:cmd,"","file")
    let result= system(a:cmd.optargs)

    " strip any ansi escape sequences off
    let result = substitute(result,"\e\\[[0-9;]*m","","g")

    " show user the result(s)
    echomsg result
    let @@= ykeep

endfunction

" s:NetrwLocalRename: rename a local file or directory {{{2
function s:NetrwLocalRename(path) range

    if !exists("w:netrw_bannercnt")
        let w:netrw_bannercnt= b:netrw_bannercnt
    endif

    " preparation for removing multiple files/directories
    let ykeep     = @@
    let ctr       = a:firstline
    let svpos     = winsaveview()
    let all       = 0

    " rename files given by the markfilelist
    if exists("s:netrwmarkfilelist_{bufnr('%')}")
        for oldname in s:netrwmarkfilelist_{bufnr("%")}
            if exists("subfrom")
                let newname= substitute(oldname,subfrom,subto,'')
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
                    NetrwKeepj call s:NetrwRefresh(1,s:NetrwBrowseChgDir(1,'./',0))
                    NetrwKeepj call winrestview(svpos)
                    let @@= ykeep
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
            let oldname= netrw#fs#ComposePath(a:path,curword)

            call inputsave()
            let newname= input("Moving ".oldname." to : ",substitute(oldname,'/*$','','e'))
            call inputrestore()

            call rename(oldname,newname)
            let ctr= ctr + 1
        endwhile
    endif

    " refresh the directory
    NetrwKeepj call s:NetrwRefresh(1,s:NetrwBrowseChgDir(1,'./',0))
    NetrwKeepj call winrestview(svpos)
    let @@= ykeep
endfunction

" s:NetrwLocalRm: {{{2
function s:NetrwLocalRm(path) range
    if !exists("w:netrw_bannercnt")
        let w:netrw_bannercnt = b:netrw_bannercnt
    endif

    " preparation for removing multiple files/directories
    let ykeep = @@
    let ret = 0
    let all = 0
    let svpos = winsaveview()

    if exists("s:netrwmarkfilelist_{bufnr('%')}")
        " remove all marked files
        for fname in s:netrwmarkfilelist_{bufnr("%")}
            let ok = s:NetrwLocalRmFile(a:path, fname, all)
            if ok =~# '^a\%[ll]$'
                let all = 1
            elseif ok =~# "n\%[o]"
                break
            endif
        endfor
        call s:NetrwUnMarkFile(1)

    else
        " remove (multiple) files and directories

        let keepsol = &l:sol
        setl nosol
        let ctr = a:firstline
        while ctr <= a:lastline
            exe "NetrwKeepj ".ctr

            " sanity checks
            if line(".") < w:netrw_bannercnt
                let ctr = ctr + 1
                continue
            endif

            let curword = s:NetrwGetWord()
            if curword == "./" || curword == "../"
                let ctr = ctr + 1
                continue
            endif

            let ok = s:NetrwLocalRmFile(a:path, curword, all)
            if ok =~# '^a\%[ll]$'
                let all = 1
            elseif ok =~# "n\%[o]"
                break
            endif

            let ctr = ctr + 1
        endwhile

        let &l:sol = keepsol
    endif

    " refresh the directory
    if bufname("%") != "NetrwMessage"
        NetrwKeepj call s:NetrwRefresh(1, s:NetrwBrowseChgDir(1, './', 0))
        NetrwKeepj call winrestview(svpos)
    endif

    let @@= ykeep
endfunction

" s:NetrwLocalRmFile: remove file fname given the path {{{2
"                     Give confirmation prompt unless all==1
function s:NetrwLocalRmFile(path, fname, all)
    let all = a:all
    let ok = ""
    let dir = 0
    NetrwKeepj norm! 0
    let rmfile = s:NetrwFile(netrw#fs#ComposePath(a:path, escape(a:fname, '\\')))->fnamemodify(':.')

    " if not a directory
    if rmfile !~ '^"' && (rmfile =~ '@$' || rmfile !~ '[\/]$')
        let msg = "Confirm deletion of file <%s> [{y(es)},n(o),a(ll)]: "
    else
        let msg = "Confirm *recursive* deletion of directory <%s> [{y(es)},n(o),a(ll)]: "
        let dir = 1
    endif

    " Ask confirmation
    if !all
        echohl Statement
        call inputsave()
        let ok = input(printf(msg, rmfile))
        call inputrestore()
        echohl NONE
        if ok =~# '^a\%[ll]$' || ok =~# '^y\%[es]$'
            let all = 1
        else
            let ok = 'no'
        endif
    endif

    if !dir && (all || empty(ok))
        " This works because delete return 0 if successful
        if netrw#fs#Remove(rmfile)
            call netrw#msg#Notify('ERROR', printf("unable to delete <%s>!", rmfile))
        else
            " Remove file only if there are no pending changes
            execute printf('silent! bwipeout %s', rmfile)
        endif

    elseif dir && (all || empty(ok))
        " Remove trailing /
        let rmfile = substitute(rmfile, '[\/]$', '', 'e')
        if delete(rmfile, "rf")
            call netrw#msg#Notify('ERROR', printf("unable to delete directory <%s>!", rmfile))
        endif

    endif

    return ok
endfunction

" Support Functions: {{{1

" netrw#Call: allows user-specified mappings to call internal netrw functions {{{2
function netrw#Call(funcname,...)
    return call("s:".a:funcname,a:000)
endfunction

" netrw#Expose: allows UserMaps and pchk to look at otherwise script-local variables {{{2
"               I expect this function to be used in
"                 :PChkAssert netrw#Expose("netrwmarkfilelist")
"               for example.
function netrw#Expose(varname)
    if exists("s:".a:varname)
        exe "let retval= s:".a:varname
        if exists("g:netrw_pchk")
            if type(retval) == 3
                let retval = copy(retval)
                let i      = 0
                while i < len(retval)
                    let retval[i]= substitute(retval[i],expand("$HOME"),'~','')
                    let i        = i + 1
                endwhile
            endif
            return string(retval)
        else
        endif
    else
        let retval= "n/a"
    endif

    return retval
endfunction

" netrw#Modify: allows UserMaps to set (modify) script-local variables {{{2
function netrw#Modify(varname,newvalue)
    exe "let s:".a:varname."= ".string(a:newvalue)
endfunction

"  netrw#RFC2396: converts %xx into characters {{{2
function netrw#RFC2396(fname)
    let fname = escape(substitute(a:fname,'%\(\x\x\)','\=printf("%c","0x".submatch(1))','ge')," \t")
    return fname
endfunction

" netrw#UserMaps: supports user-specified maps {{{2
"                 see :help function()
"
"                 g:Netrw_UserMaps is a List with members such as:
"                       [[keymap sequence, function reference],...]
"
"                 The referenced function may return a string,
"                       refresh : refresh the display
"                       -other- : this string will be executed
"                 or it may return a List of strings.
"
"                 Each keymap-sequence will be set up with a nnoremap
"                 to invoke netrw#UserMaps(a:islocal).
"                 Related functions:
"                   netrw#Expose(varname)          -- see s:varname variables
"                   netrw#Modify(varname,newvalue) -- modify value of s:varname variable
"                   netrw#Call(funcname,...)       -- call internal netrw function with optional arguments
function netrw#UserMaps(islocal)

    " set up usermaplist
    if exists("g:Netrw_UserMaps") && type(g:Netrw_UserMaps) == 3
        for umap in g:Netrw_UserMaps
            " if umap[0] is a string and umap[1] is a string holding a function name
            if type(umap[0]) == 1 && type(umap[1]) == 1
                exe "nno <buffer> <silent> ".umap[0]." :call <SID>UserMaps(".a:islocal.",'".umap[1]."')<cr>"
            else
                call netrw#msg#Notify('WARNING', printf('ignoring usermap <%s> -- not a [string,funcref] entry', string(umap[0])))
            endif
        endfor
    endif
endfunction

" s:NetrwBadd: adds marked files to buffer list or vice versa {{{2
"              cb : bl2mf=0  add marked files to buffer list
"              cB : bl2mf=1  use bufferlist to mark files
"              (mnemonic: cb = copy (marked files) to buffer list)
function s:NetrwBadd(islocal,bl2mf)
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
            exe "badd ".fnameescape(fname)
        endfor
        let curbufnr = bufnr("%")
        let curdir   = s:NetrwGetCurdir(a:islocal)
        call s:NetrwUnmarkList(curbufnr,curdir)                   " remove markings from local buffer
    endif
endfunction

" s:DeleteBookmark: deletes a file/directory from Netrw's bookmark system {{{2
"   Related Functions: s:MakeBookmark() s:NetrwBookHistHandler() s:NetrwBookmark()
function s:DeleteBookmark(fname)
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

endfunction

" s:FileReadable: o/s independent filereadable {{{2
function s:FileReadable(fname)
    if g:netrw_cygwin
        let ret = filereadable(s:NetrwFile(substitute(a:fname,g:netrw_cygdrive.'/\(.\)','\1:/','')))
    else
        let ret = filereadable(s:NetrwFile(a:fname))
    endif

    return ret
endfunction

"  s:GetTempfile: gets a tempname that'll work for various o/s's {{{2
"                 Places correct suffix on end of temporary filename,
"                 using the suffix provided with fname
function s:GetTempfile(fname)

    if !exists("b:netrw_tmpfile")
        " get a brand new temporary filename
        let tmpfile= tempname()

        let tmpfile= substitute(tmpfile,'\','/','ge')

        " sanity check -- does the temporary file's directory exist?
        if !isdirectory(s:NetrwFile(substitute(tmpfile,'[^/]\+$','','e')))
            call netrw#msg#Notify('ERROR', printf('your <%s> directory is missing!', substitute(tmpfile,'[^/]\+$','','e')))
            return ""
        endif

        " let netrw#NetSource() know about the tmpfile
        let s:netrw_tmpfile= tmpfile " used by netrw#NetSource() and netrw#BrowseX()

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
    else
        " re-use temporary filename
        let tmpfile= b:netrw_tmpfile
    endif

    " use fname's suffix for the temporary file
    if a:fname != ""
        if a:fname =~ '\.[^./]\+$'
            if a:fname =~ '\.tar\.gz$' || a:fname =~ '\.tar\.bz2$' || a:fname =~ '\.tar\.xz$'
                let suffix = ".tar".substitute(a:fname,'^.*\(\.[^./]\+\)$','\1','e')
            elseif a:fname =~ '.txz$'
                let suffix = ".txz".substitute(a:fname,'^.*\(\.[^./]\+\)$','\1','e')
            else
                let suffix = substitute(a:fname,'^.*\(\.[^./]\+\)$','\1','e')
            endif
            let tmpfile= substitute(tmpfile,'\.tmp$','','e')
            let tmpfile .= suffix
            let s:netrw_tmpfile= tmpfile " supports netrw#NetSource()
        endif
    endif

    return tmpfile
endfunction

" s:MakeSshCmd: transforms input command using USEPORT HOSTNAME into {{{2
"               a correct command for use with a system() call
function s:MakeSshCmd(sshcmd)
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
    return sshcmd
endfunction

" s:MakeBookmark: enters a bookmark into Netrw's bookmark system   {{{2
function s:MakeBookmark(fname)

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

endfunction

" s:MergeBookmarks: merge current bookmarks with saved bookmarks {{{2
function s:MergeBookmarks()
    " get bookmarks from .netrwbook file
    let savefile= s:NetrwHome()."/.netrwbook"
    if filereadable(s:NetrwFile(savefile))
        NetrwKeepj call s:NetrwBookHistSave()
        NetrwKeepj call delete(savefile)
    endif
endfunction

" s:NetrwBMShow: {{{2
function s:NetrwBMShow()
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
endfunction

" s:NetrwCursor: responsible for setting cursorline/cursorcolumn based upon g:netrw_cursor {{{2
function s:NetrwCursor(editfile)
    if !exists("w:netrw_liststyle")
        let w:netrw_liststyle= g:netrw_liststyle
    endif


    if &ft != "netrw"
    " if the current window isn't a netrw directory listing window, then use user cursorline/column
    " settings.  Affects when netrw is used to read/write a file using scp/ftp/etc.

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
        setl cursorline
        setl cursorcolumn

    elseif g:netrw_cursor == 3
        " thin-long-tree: cursorline, user's cursorcolumn
        " wide          : cursorline, cursorcolumn
        if w:netrw_liststyle == s:WIDELIST
            setl cursorline
            setl cursorcolumn
        else
            setl cursorline
        endif

    elseif g:netrw_cursor == 2
        " thin-long-tree: cursorline, user's cursorcolumn
        " wide          : cursorline, user's cursorcolumn
        setl cursorline

    elseif g:netrw_cursor == 1
        " thin-long-tree: user's cursorline, user's cursorcolumn
        " wide          : cursorline,        user's cursorcolumn
        if w:netrw_liststyle == s:WIDELIST
            setl cursorline
        else
        endif

    else
        " all styles: user's cursorline, user's cursorcolumn
        let &l:cursorline   = s:netrw_usercul
        let &l:cursorcolumn = s:netrw_usercuc
    endif

endfunction

" s:RestoreCursorline: restores cursorline/cursorcolumn to original user settings {{{2
function s:RestoreCursorline()
    if exists("s:netrw_usercul")
        let &l:cursorline   = s:netrw_usercul
    endif
    if exists("s:netrw_usercuc")
        let &l:cursorcolumn = s:netrw_usercuc
    endif
endfunction

" s:RestoreRegister: restores all registers given in the dict {{{2
function s:RestoreRegister(dict)
    for [key, val] in items(a:dict)
        if key == 'unnamed'
            let key = ''
        endif
        call setreg(key, val[0], val[1])
    endfor
endfunction

" s:NetrwEnew: opens a new buffer, passes netrw buffer variables through {{{2
function s:NetrwEnew(...)

    " Clean out the last buffer:
    " Check if the last buffer has # > 1, is unlisted, is unnamed, and does not appear in a window
    " If so, delete it.
    let bufid = bufnr('$')
    if bufid > 1 && !buflisted(bufid) && bufloaded(bufid) && bufname(bufid) == "" && bufwinid(bufid) == -1
        execute printf("silent! bdelete! %s", bufid)
    endif

    " grab a function-local-variable copy of buffer variables
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
    " when tree listing uses file TreeListing... a new buffer is made.
    " Want the old buffer to be unlisted.
    " COMBAK: this causes a problem, see P43
    "  setl nobl
    let netrw_keepdiff= &l:diff
    call s:NetrwEditFile("enew!","","")
    let &l:diff= netrw_keepdiff
    NetrwKeepj call s:NetrwOptionsSave("w:")

    " copy function-local-variables to buffer variable equivalents
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
                nno <silent> <buffer> [    :sil call <SID>TreeListMove('[')<cr>
                nno <silent> <buffer> ]    :sil call <SID>TreeListMove(']')<cr>
            else
                call s:NetrwBufRename(b:netrw_curdir)
            endif
        endif
    endif
endfunction

" s:NetrwInsureWinVars: insure that a netrw buffer has its w: variables in spite of a wincmd v or s {{{2
function s:NetrwInsureWinVars()
    if !exists("w:netrw_liststyle")
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
            for k in keys(winvars)
                let w:{k}= winvars[k]
            endfor
        endif
    endif
endfunction

" s:NetrwLcd: handles changing the (local) directory {{{2
"   Returns: 0=success
"           -1=failed
function s:NetrwLcd(newdir)

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
        call netrw#msg#Notify('ERROR', printf('unable to change directory to <%s> (permissions?)', a:newdir))
        if exists("w:netrw_prvdir")
            let a:newdir= w:netrw_prvdir
        else
            call s:NetrwOptionsRestore("w:")
            exe "setl ".g:netrw_bufsettings
            let a:newdir= dirname
        endif
        return -1
    endif

    return 0
endfunction

" s:NetrwSaveWordPosn: used to keep cursor on same word after refresh, {{{2
" changed sorting, etc.  Also see s:NetrwRestoreWordPosn().
function s:NetrwSaveWordPosn()
    let s:netrw_saveword= '^'.fnameescape(getline('.')).'$'
endfunction

" s:NetrwHumanReadable: takes a number and makes it "human readable" {{{2
"                       1000 -> 1K, 1000000 -> 1M, 1000000000 -> 1G
function s:NetrwHumanReadable(sz)

    if g:netrw_sizestyle ==# 'h'
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

    elseif g:netrw_sizestyle ==# 'H'
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

    return sz
endfunction

" s:NetrwRestoreWordPosn: used to keep cursor on same word after refresh, {{{2
"  changed sorting, etc.  Also see s:NetrwSaveWordPosn().
function s:NetrwRestoreWordPosn()
    sil! call search(s:netrw_saveword,'w')
endfunction

" s:RestoreBufVars: {{{2
function s:RestoreBufVars()

    if exists("s:netrw_curdir")        |let b:netrw_curdir         = s:netrw_curdir        |endif
    if exists("s:netrw_lastfile")      |let b:netrw_lastfile       = s:netrw_lastfile      |endif
    if exists("s:netrw_method")        |let b:netrw_method         = s:netrw_method        |endif
    if exists("s:netrw_fname")         |let b:netrw_fname          = s:netrw_fname         |endif
    if exists("s:netrw_machine")       |let b:netrw_machine        = s:netrw_machine       |endif
    if exists("s:netrw_browser_active")|let b:netrw_browser_active = s:netrw_browser_active|endif

endfunction

" s:RemotePathAnalysis: {{{2
function s:RemotePathAnalysis(dirname)

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


endfunction

" s:RemoteSystem: runs a command on a remote host using ssh {{{2
"                 Returns status
" Runs system() on
"    [cd REMOTEDIRPATH;] a:cmd
" Note that it doesn't do netrw#os#Escape(a:cmd)!
function s:RemoteSystem(cmd)
    if !executable(g:netrw_ssh_cmd)
        call netrw#msg#Notify('ERROR', printf('g:netrw_ssh_cmd<%s> is not executable!', g:netrw_ssh_cmd))
    elseif !exists("b:netrw_curdir")
        call netrw#msg#Notify('ERROR', "for some reason b:netrw_curdir doesn't exist!")
    else
        let cmd      = s:MakeSshCmd(g:netrw_ssh_cmd." USEPORT HOSTNAME")
        let remotedir= substitute(b:netrw_curdir,'^.*//[^/]\+/\(.*\)$','\1','')
        if remotedir != ""
            let cmd= cmd.' cd '.netrw#os#Escape(remotedir).";"
        else
            let cmd= cmd.' '
        endif
        let cmd= cmd.a:cmd
        let ret= system(cmd)
    endif
    return ret
endfunction

" s:RestoreWinVars: (used by Explore() and NetrwSplit()) {{{2
function s:RestoreWinVars()
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
endfunction

" s:Rexplore: implements returning from a buffer to a netrw directory {{{2
"
"             s:SetRexDir() sets up <2-leftmouse> maps (if g:netrw_retmap
"             is true) and a command, :Rexplore, which call this function.
"
"             s:netrw_posn is set up by s:NetrwBrowseChgDir()
"
"             s:rexposn_BUFNR used to save/restore cursor position
function s:NetrwRexplore(islocal,dirname)
    if exists("s:netrwdrag")
        return
    endif

    if &ft == "netrw" && exists("w:netrw_rexfile") && w:netrw_rexfile != ""
        " a :Rex while in a netrw buffer means: edit the file in w:netrw_rexfile
        exe "NetrwKeepj e ".w:netrw_rexfile
        unlet w:netrw_rexfile
        return
    endif

    " ---------------------------
    " :Rex issued while in a file
    " ---------------------------

    " record current file so :Rex can return to it from netrw
    let w:netrw_rexfile= expand("%")

    if !exists("w:netrw_rexlocal")
        return
    endif
    if w:netrw_rexlocal
        NetrwKeepj call netrw#LocalBrowseCheck(w:netrw_rexdir)
    else
        NetrwKeepj call s:NetrwBrowse(0,w:netrw_rexdir)
    endif
    if exists("s:initbeval")
        setl beval
    endif
    if exists("s:rexposn_".bufnr("%"))
        " restore position in directory listing
        NetrwKeepj call winrestview(s:rexposn_{bufnr('%')})
        if exists("s:rexposn_".bufnr('%'))
            unlet s:rexposn_{bufnr('%')}
        endif
    else
    endif

    if has("syntax") && exists("g:syntax_on") && g:syntax_on
        if exists("s:explore_match")
            exe "2match netrwMarkFile /".s:explore_match."/"
        endif
    endif

endfunction

" s:SaveBufVars: save selected b: variables to s: variables {{{2
"                use s:RestoreBufVars() to restore b: variables from s: variables
function s:SaveBufVars()

    if exists("b:netrw_curdir")        |let s:netrw_curdir         = b:netrw_curdir        |endif
    if exists("b:netrw_lastfile")      |let s:netrw_lastfile       = b:netrw_lastfile      |endif
    if exists("b:netrw_method")        |let s:netrw_method         = b:netrw_method        |endif
    if exists("b:netrw_fname")         |let s:netrw_fname          = b:netrw_fname         |endif
    if exists("b:netrw_machine")       |let s:netrw_machine        = b:netrw_machine       |endif
    if exists("b:netrw_browser_active")|let s:netrw_browser_active = b:netrw_browser_active|endif

endfunction

" s:SavePosn: saves position associated with current buffer into a dictionary {{{2
function s:SavePosn(posndict)

    if !exists("a:posndict[bufnr('%')]")
        let a:posndict[bufnr("%")]= []
    endif
    call add(a:posndict[bufnr("%")],winsaveview())

    return a:posndict
endfunction

" s:RestorePosn: restores position associated with current buffer using dictionary {{{2
function s:RestorePosn(posndict)
    if exists("a:posndict")
        if has_key(a:posndict,bufnr("%"))
            let posnlen= len(a:posndict[bufnr("%")])
            if posnlen > 0
                let posnlen= posnlen - 1
                call winrestview(a:posndict[bufnr("%")][posnlen])
                call remove(a:posndict[bufnr("%")],posnlen)
            endif
        endif
    endif
endfunction

" s:SaveWinVars: (used by Explore() and NetrwSplit()) {{{2
function s:SaveWinVars()
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
endfunction

" s:SetBufWinVars: (used by NetrwBrowse() and LocalBrowseCheck()) {{{2
"   To allow separate windows to have their own activities, such as
"   Explore **/pattern, several variables have been made window-oriented.
"   However, when the user splits a browser window (ex: ctrl-w s), these
"   variables are not inherited by the new window.  SetBufWinVars() and
"   UseBufWinVars() get around that.
function s:SetBufWinVars()
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
endfunction

" s:SetRexDir: set directory for :Rexplore {{{2
function s:SetRexDir(islocal,dirname)
    let w:netrw_rexdir         = a:dirname
    let w:netrw_rexlocal       = a:islocal
    let s:rexposn_{bufnr("%")} = winsaveview()
endfunction

" s:ShowLink: used to modify thin and tree listings to show links {{{2
function s:ShowLink()
    if exists("b:netrw_curdir")
        keepp :norm! $?\a
        "call histdel("/",-1)
        if exists("w:netrw_liststyle") && w:netrw_liststyle == s:TREELIST && exists("w:netrw_treetop")
            let basedir = s:NetrwTreePath(w:netrw_treetop)
        else
            let basedir = b:netrw_curdir.'/'
        endif
        let fname = basedir.s:NetrwGetWord()
        let resname = resolve(fname)
        if resname =~ '^\M'.basedir
            let dirlen  = strlen(basedir)
            let resname = strpart(resname,dirlen)
        endif
        let modline = getline(".")."\t --> ".resname
        setl noro ma
        call setline(".",modline)
        setl ro noma nomod
    endif
endfunction

" s:ShowStyle: {{{2
function s:ShowStyle()
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
endfunction

" s:TreeListMove: supports [[, ]], [], and ][ in tree mode {{{2
function s:TreeListMove(dir)
    let curline      = getline('.')
    let prvline      = (line(".") > 1)?         getline(line(".")-1) : ''
    let nxtline      = (line(".") < line("$"))? getline(line(".")+1) : ''
    let curindent    = substitute(getline('.'),'^\(\%('.s:treedepthstring.'\)*\)[^'.s:treedepthstring.'].\{-}$','\1','e')
    let indentm1     = substitute(curindent,'^'.s:treedepthstring,'','')
    let treedepthchr = substitute(s:treedepthstring,' ','','g')
    let stopline     = exists("w:netrw_bannercnt")? w:netrw_bannercnt : 1
    "  COMBAK : need to handle when on a directory
    "  COMBAK : need to handle ]] and ][.  In general, needs work!!!
    if curline !~ '/$'
        if     a:dir == '[[' && prvline != ''
            NetrwKeepj norm! 0
            let nl = search('^'.indentm1.'\%('.s:treedepthstring.'\)\@!','bWe',stopline) " search backwards
        elseif a:dir == '[]' && nxtline != ''
            NetrwKeepj norm! 0
            let nl = search('^\%('.curindent.'\)\@!','We') " search forwards
            if nl != 0
                NetrwKeepj norm! k
            else
                NetrwKeepj norm! G
            endif
        endif
    endif

endfunction

" s:UpdateBuffersMenu: does emenu Buffers.Refresh (but due to locale, the menu item may not be called that) {{{2
"                      The Buffers.Refresh menu calls s:BMShow(); unfortunately, that means that that function
"                      can't be called except via emenu.  But due to locale, that menu line may not be called
"                      Buffers.Refresh; hence, s:NetrwBMShow() utilizes a "cheat" to call that function anyway.
function s:UpdateBuffersMenu()
    if has("gui") && has("menu") && has("gui_running") && &go =~# 'm' && g:netrw_menu
        try
            sil emenu Buffers.Refresh\ menu
        catch /^Vim\%((\a\+)\)\=:E/
            let v:errmsg= ""
            sil NetrwKeepj call s:NetrwBMShow()
        endtry
    endif
endfunction

" s:UseBufWinVars: (used by NetrwBrowse() and LocalBrowseCheck() {{{2
"              Matching function to s:SetBufWinVars()
function s:UseBufWinVars()
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
endfunction

" s:UserMaps: supports user-defined UserMaps {{{2
"               * calls a user-supplied funcref(islocal,curdir)
"               * interprets result
"             See netrw#UserMaps()
function s:UserMaps(islocal,funcname)
    if !exists("b:netrw_curdir")
        let b:netrw_curdir= getcwd()
    endif
    let Funcref = function(a:funcname)
    let result  = Funcref(a:islocal)

    if     type(result) == 1
        " if result from user's funcref is a string...
        if result == "refresh"
            call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
        elseif result != ""
            exe result
        endif

    elseif type(result) == 3
        " if result from user's funcref is a List...
        for action in result
            if action == "refresh"
                call s:NetrwRefresh(a:islocal,s:NetrwBrowseChgDir(a:islocal,'./',0))
            elseif action != ""
                exe action
            endif
        endfor
    endif
endfunction

" Deprecated: {{{1

" }}}
" Settings Restoration: {{{1

let &cpo= s:keepcpo
unlet s:keepcpo

" }}}

" vim:ts=8 sts=4 sw=4 et fdm=marker
