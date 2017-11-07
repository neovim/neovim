" netrwPlugin.vim: Handles file transfer and remote directory listing across a network
"            PLUGIN SECTION
" Date:		Feb 08, 2016
" Maintainer:	Charles E Campbell <NdrOchip@ScampbellPfamily.AbizM-NOSPAM>
" GetLatestVimScripts: 1075 1 :AutoInstall: netrw.vim
" Copyright:    Copyright (C) 1999-2013 Charles E. Campbell {{{1
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               netrw.vim, netrwPlugin.vim, and netrwSettings.vim are provided
"               *as is* and comes with no warranty of any kind, either
"               expressed or implied. By using this plugin, you agree that
"               in no event will the copyright holder be liable for any damages
"               resulting from the use of this software.
"
"  But be doers of the Word, and not only hearers, deluding your own selves {{{1
"  (James 1:22 RSV)
" =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
" Load Once: {{{1
if &cp || exists("g:loaded_netrwPlugin")
 finish
endif
let g:loaded_netrwPlugin = "v162"
let s:keepcpo = &cpo
set cpo&vim
"DechoRemOn

" ---------------------------------------------------------------------
" Public Interface: {{{1

" Local Browsing Autocmds: {{{2
augroup FileExplorer
 au!
 au BufLeave *  if &ft != "netrw"|let w:netrw_prvfile= expand("%:p")|endif
 au BufEnter *	sil call s:LocalBrowse(expand("<amatch>"))
 au VimEnter *	sil call s:VimEnter(expand("<amatch>"))
 if has("win32") || has("win95") || has("win64") || has("win16")
  au BufEnter .* sil call s:LocalBrowse(expand("<amatch>"))
 endif
augroup END

" Network Browsing Reading Writing: {{{2
augroup Network
 au!
 au BufReadCmd   file://*											call netrw#FileUrlEdit(expand("<amatch>"))
 au BufReadCmd   ftp://*,rcp://*,scp://*,http://*,https://*,dav://*,davs://*,rsync://*,sftp://*	exe "sil doau BufReadPre ".fnameescape(expand("<amatch>"))|call netrw#Nread(2,expand("<amatch>"))|exe "sil doau BufReadPost ".fnameescape(expand("<amatch>"))
 au FileReadCmd  ftp://*,rcp://*,scp://*,http://*,file://*,https://*,dav://*,davs://*,rsync://*,sftp://*	exe "sil doau FileReadPre ".fnameescape(expand("<amatch>"))|call netrw#Nread(1,expand("<amatch>"))|exe "sil doau FileReadPost ".fnameescape(expand("<amatch>"))
 au BufWriteCmd  ftp://*,rcp://*,scp://*,http://*,file://*,dav://*,davs://*,rsync://*,sftp://*			exe "sil doau BufWritePre ".fnameescape(expand("<amatch>"))|exe 'Nwrite '.fnameescape(expand("<amatch>"))|exe "sil doau BufWritePost ".fnameescape(expand("<amatch>"))
 au FileWriteCmd ftp://*,rcp://*,scp://*,http://*,file://*,dav://*,davs://*,rsync://*,sftp://*			exe "sil doau FileWritePre ".fnameescape(expand("<amatch>"))|exe "'[,']".'Nwrite '.fnameescape(expand("<amatch>"))|exe "sil doau FileWritePost ".fnameescape(expand("<amatch>"))
 try                                                       
  au SourceCmd   ftp://*,rcp://*,scp://*,http://*,file://*,https://*,dav://*,davs://*,rsync://*,sftp://*	exe 'Nsource '.fnameescape(expand("<amatch>"))
 catch /^Vim\%((\a\+)\)\=:E216/                            
  au SourcePre   ftp://*,rcp://*,scp://*,http://*,file://*,https://*,dav://*,davs://*,rsync://*,sftp://*	exe 'Nsource '.fnameescape(expand("<amatch>"))
 endtry
augroup END

" Commands: :Nread, :Nwrite, :NetUserPass {{{2
com! -count=1 -nargs=*	Nread		let s:svpos= winsaveview()<bar>call netrw#NetRead(<count>,<f-args>)<bar>call winrestview(s:svpos)
com! -range=% -nargs=*	Nwrite		let s:svpos= winsaveview()<bar><line1>,<line2>call netrw#NetWrite(<f-args>)<bar>call winrestview(s:svpos)
com! -nargs=*		NetUserPass	call NetUserPass(<f-args>)
com! -nargs=*	        Nsource		let s:svpos= winsaveview()<bar>call netrw#NetSource(<f-args>)<bar>call winrestview(s:svpos)
com! -nargs=?		Ntree		call netrw#SetTreetop(1,<q-args>)

" Commands: :Explore, :Sexplore, Hexplore, Vexplore, Lexplore {{{2
com! -nargs=* -bar -bang -count=0 -complete=dir	Explore		call netrw#Explore(<count>,0,0+<bang>0,<q-args>)
com! -nargs=* -bar -bang -count=0 -complete=dir	Sexplore	call netrw#Explore(<count>,1,0+<bang>0,<q-args>)
com! -nargs=* -bar -bang -count=0 -complete=dir	Hexplore	call netrw#Explore(<count>,1,2+<bang>0,<q-args>)
com! -nargs=* -bar -bang -count=0 -complete=dir	Vexplore	call netrw#Explore(<count>,1,4+<bang>0,<q-args>)
com! -nargs=* -bar       -count=0 -complete=dir	Texplore	call netrw#Explore(<count>,0,6        ,<q-args>)
com! -nargs=* -bar -bang			Nexplore	call netrw#Explore(-1,0,0,<q-args>)
com! -nargs=* -bar -bang			Pexplore	call netrw#Explore(-2,0,0,<q-args>)
com! -nargs=* -bar -bang -count=0 -complete=dir Lexplore	call netrw#Lexplore(<count>,<bang>0,<q-args>)

" Commands: NetrwSettings {{{2
com! -nargs=0	NetrwSettings	call netrwSettings#NetrwSettings()
com! -bang	NetrwClean	call netrw#Clean(<bang>0)

" Maps:
if !exists("g:netrw_nogx")
 if maparg('gx','n') == ""
  if !hasmapto('<Plug>NetrwBrowseX')
   nmap <unique> gx <Plug>NetrwBrowseX
  endif
  nno <silent> <Plug>NetrwBrowseX :call netrw#BrowseX(netrw#GX(),netrw#CheckIfRemote(netrw#GX()))<cr>
 endif
 if maparg('gx','v') == ""
  if !hasmapto('<Plug>NetrwBrowseXVis')
   vmap <unique> gx <Plug>NetrwBrowseXVis
  endif
  vno <silent> <Plug>NetrwBrowseXVis :<c-u>call netrw#BrowseXVis()<cr>
 endif
endif
if exists("g:netrw_usetab") && g:netrw_usetab
 if maparg('<c-tab>','n') == ""
  nmap <unique> <c-tab> <Plug>NetrwShrink
 endif
 nno <silent> <Plug>NetrwShrink :call netrw#Shrink()<cr>
endif

" ---------------------------------------------------------------------
" LocalBrowse: invokes netrw#LocalBrowseCheck() on directory buffers {{{2
fun! s:LocalBrowse(dirname)
  " Unfortunate interaction -- only DechoMsg debugging calls can be safely used here.
  " Otherwise, the BufEnter event gets triggered when attempts to write to
  " the DBG buffer are made.
  
  if !exists("s:vimentered")
   " If s:vimentered doesn't exist, then the VimEnter event hasn't fired.  It will,
   " and so s:VimEnter() will then be calling this routine, but this time with s:vimentered defined.
"   call Dfunc("s:LocalBrowse(dirname<".a:dirname.">)  (s:vimentered doesn't exist)")
"   call Dret("s:LocalBrowse")
   return
  endif

"  call Dfunc("s:LocalBrowse(dirname<".a:dirname.">)  (s:vimentered=".s:vimentered.")")

  if has("amiga")
   " The check against '' is made for the Amiga, where the empty
   " string is the current directory and not checking would break
   " things such as the help command.
"   call Decho("(LocalBrowse) dirname<".a:dirname.">  (isdirectory, amiga)")
   if a:dirname != '' && isdirectory(a:dirname)
    sil! call netrw#LocalBrowseCheck(a:dirname)
    if exists("w:netrw_bannercnt") && line('.') < w:netrw_bannercnt
     exe w:netrw_bannercnt
    endif
   endif

  elseif isdirectory(a:dirname)
"   call Decho("(LocalBrowse) dirname<".a:dirname."> ft=".&ft."  (isdirectory, not amiga)")
"   call Dredir("LocalBrowse ft last set: ","verbose set ft")
   sil! call netrw#LocalBrowseCheck(a:dirname)
   if exists("w:netrw_bannercnt") && line('.') < w:netrw_bannercnt
    exe w:netrw_bannercnt
   endif

  else
   " not a directory, ignore it
"   call Decho("(LocalBrowse) dirname<".a:dirname."> not a directory, ignoring...")
  endif

"  call Dret("s:LocalBrowse")
endfun

" ---------------------------------------------------------------------
" s:VimEnter: after all vim startup stuff is done, this function is called. {{{2
"             Its purpose: to look over all windows and run s:LocalBrowse() on
"             them, which checks if they're directories and will create a directory
"             listing when appropriate.
"             It also sets s:vimentered, letting s:LocalBrowse() know that s:VimEnter()
"             has already been called.
fun! s:VimEnter(dirname)
"  call Dfunc("s:VimEnter(dirname<".a:dirname.">) expand(%)<".expand("%").">")
  let curwin       = winnr()
  let s:vimentered = 1
  windo call s:LocalBrowse(expand("%:p"))
  exe curwin."wincmd w"
"  call Dret("s:VimEnter")
endfun

" ---------------------------------------------------------------------
" NetrwStatusLine: {{{1
fun! NetrwStatusLine()
"  let g:stlmsg= "Xbufnr=".w:netrw_explore_bufnr." bufnr=".bufnr("%")." Xline#".w:netrw_explore_line." line#".line(".")
  if !exists("w:netrw_explore_bufnr") || w:netrw_explore_bufnr != bufnr("%") || !exists("w:netrw_explore_line") || w:netrw_explore_line != line(".") || !exists("w:netrw_explore_list")
   let &stl= s:netrw_explore_stl
   if exists("w:netrw_explore_bufnr")|unlet w:netrw_explore_bufnr|endif
   if exists("w:netrw_explore_line")|unlet w:netrw_explore_line|endif
   return ""
  else
   return "Match ".w:netrw_explore_mtchcnt." of ".w:netrw_explore_listlen
  endif
endfun

" ------------------------------------------------------------------------
" NetUserPass: set username and password for subsequent ftp transfer {{{1
"   Usage:  :call NetUserPass()			-- will prompt for userid and password
"	    :call NetUserPass("uid")		-- will prompt for password
"	    :call NetUserPass("uid","password") -- sets global userid and password
fun! NetUserPass(...)

 " get/set userid
 if a:0 == 0
"  call Dfunc("NetUserPass(a:0<".a:0.">)")
  if !exists("g:netrw_uid") || g:netrw_uid == ""
   " via prompt
   let g:netrw_uid= input('Enter username: ')
  endif
 else	" from command line
"  call Dfunc("NetUserPass(a:1<".a:1.">) {")
  let g:netrw_uid= a:1
 endif

 " get password
 if a:0 <= 1 " via prompt
"  call Decho("a:0=".a:0." case <=1:")
  let g:netrw_passwd= inputsecret("Enter Password: ")
 else " from command line
"  call Decho("a:0=".a:0." case >1: a:2<".a:2.">")
  let g:netrw_passwd=a:2
 endif
"  call Dret("NetUserPass")
endfun

" ------------------------------------------------------------------------
" Modelines And Restoration: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" vim:ts=8 fdm=marker
