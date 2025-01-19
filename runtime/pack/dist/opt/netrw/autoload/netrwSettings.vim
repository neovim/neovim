" Maintainer: Luca Saccarola <github.e41mv@aleeas.com>
" Former Maintainer: Charles E Campbell
" Upstream: <https://github.com/saccarosium/netrw.vim>
" Copyright:    Copyright (C) 1999-2007 Charles E. Campbell {{{
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               netrwSettings.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. By using
"               this plugin, you agree that in no event will the copyright
"               holder be liable for any damages resulting from the use
"               of this software. }}}

if &cp || exists("g:loaded_netrwSettings")
    finish
endif

let g:loaded_netrwSettings = "v175"
if v:version < 700
 echohl WarningMsg
 echo "***warning*** this version of netrwSettings needs vim 7.0"
 echohl Normal
 finish
endif

" NetrwSettings: {{{

function! netrwSettings#NetrwSettings()
    " this call is here largely just to insure that netrw has been loaded
    call netrw#WinPath("")
    if !exists("g:loaded_netrw")
        echohl WarningMsg
        echomsg "***sorry*** netrw needs to be loaded prior to using NetrwSettings"
        echohl None
        return
    endif

    above wincmd s
    enew
    setlocal noswapfile bh=wipe
    set ft=vim
    file Netrw\ Settings

    " these variables have the following default effects when they don't
    " exist (ie. have not been set by the user in his/her .vimrc)
    if !exists("g:netrw_liststyle")
        let g:netrw_liststyle= 0
        let g:netrw_list_cmd= "ssh HOSTNAME ls -FLa"
    endif
    if !exists("g:netrw_silent")
        let g:netrw_silent= 0
    endif
    if !exists("g:netrw_use_nt_rcp")
        let g:netrw_use_nt_rcp= 0
    endif
    if !exists("g:netrw_ftp")
        let g:netrw_ftp= 0
    endif
    if !exists("g:netrw_ignorenetrc")
        let g:netrw_ignorenetrc= 0
    endif

    put ='+ ---------------------------------------------'
    put ='+  NetrwSettings:  by Charles E. Campbell'
    put ='+ Press <F1> with cursor atop any line for help'
    put ='+ ---------------------------------------------'
    let s:netrw_settings_stop= line(".")

    put =''
    put ='+ Netrw Protocol Commands'
    put = 'let g:netrw_dav_cmd = '.g:netrw_dav_cmd
    put = 'let g:netrw_fetch_cmd = '.g:netrw_fetch_cmd
    put = 'let g:netrw_ftp_cmd = '.g:netrw_ftp_cmd
    put = 'let g:netrw_http_cmd = '.g:netrw_http_cmd
    put = 'let g:netrw_rcp_cmd = '.g:netrw_rcp_cmd
    put = 'let g:netrw_rsync_cmd = '.g:netrw_rsync_cmd
    put = 'let g:netrw_scp_cmd = '.g:netrw_scp_cmd
    put = 'let g:netrw_sftp_cmd = '.g:netrw_sftp_cmd
    put = 'let g:netrw_ssh_cmd = '.g:netrw_ssh_cmd
    let s:netrw_protocol_stop= line(".")
    put = ''

    put ='+Netrw Transfer Control'
    put = 'let g:netrw_cygwin = '.g:netrw_cygwin
    put = 'let g:netrw_ftp = '.g:netrw_ftp
    put = 'let g:netrw_ftpmode = '.g:netrw_ftpmode
    put = 'let g:netrw_ignorenetrc = '.g:netrw_ignorenetrc
    put = 'let g:netrw_sshport = '.g:netrw_sshport
    put = 'let g:netrw_silent = '.g:netrw_silent
    put = 'let g:netrw_use_nt_rcp = '.g:netrw_use_nt_rcp
    let s:netrw_xfer_stop= line(".")
    put =''
    put ='+ Netrw Messages'
    put ='let g:netrw_use_errorwindow = '.g:netrw_use_errorwindow

    put = ''
    put ='+ Netrw Browser Control'
    if exists("g:netrw_altfile")
        put = 'let g:netrw_altfile = '.g:netrw_altfile
    else
        put = 'let g:netrw_altfile = 0'
    endif
    put = 'let g:netrw_alto = '.g:netrw_alto
    put = 'let g:netrw_altv = '.g:netrw_altv
    put = 'let g:netrw_banner = '.g:netrw_banner
    if exists("g:netrw_bannerbackslash")
        put = 'let g:netrw_bannerbackslash = '.g:netrw_bannerbackslash
    else
        put = '\" let g:netrw_bannerbackslash = (not defined)'
    endif
    put = 'let g:netrw_browse_split = '.g:netrw_browse_split
    if exists("g:netrw_browsex_viewer")
        put = 'let g:netrw_browsex_viewer = '.g:netrw_browsex_viewer
    else
        put = '\" let g:netrw_browsex_viewer = (not defined)'
    endif
    put = 'let g:netrw_compress = '.g:netrw_compress
    if exists("g:Netrw_corehandler")
        put = 'let g:Netrw_corehandler = '.g:Netrw_corehandler
    else
        put = '\" let g:Netrw_corehandler = (not defined)'
    endif
    put = 'let g:netrw_ctags = '.g:netrw_ctags
    put = 'let g:netrw_cursor = '.g:netrw_cursor
    let decompressline= line("$")
    put = 'let g:netrw_decompress = '.string(g:netrw_decompress)
    if exists("g:netrw_dynamic_maxfilenamelen")
        put = 'let g:netrw_dynamic_maxfilenamelen='.g:netrw_dynamic_maxfilenamelen
    else
        put = '\" let g:netrw_dynamic_maxfilenamelen= (not defined)'
    endif
    put = 'let g:netrw_dirhistmax = '.g:netrw_dirhistmax
    put = 'let g:netrw_errorlvl = '.g:netrw_errorlvl
    put = 'let g:netrw_fastbrowse = '.g:netrw_fastbrowse
    let fnameescline= line("$")
    put = 'let g:netrw_fname_escape = '.string(g:netrw_fname_escape)
    put = 'let g:netrw_ftp_browse_reject = '.g:netrw_ftp_browse_reject
    put = 'let g:netrw_ftp_list_cmd = '.g:netrw_ftp_list_cmd
    put = 'let g:netrw_ftp_sizelist_cmd = '.g:netrw_ftp_sizelist_cmd
    put = 'let g:netrw_ftp_timelist_cmd = '.g:netrw_ftp_timelist_cmd
    let globescline= line("$")
    put = 'let g:netrw_glob_escape = '.string(g:netrw_glob_escape)
    put = 'let g:netrw_hide = '.g:netrw_hide
    if exists("g:netrw_home")
        put = 'let g:netrw_home = '.g:netrw_home
    else
        put = '\" let g:netrw_home = (not defined)'
    endif
    put = 'let g:netrw_keepdir = '.g:netrw_keepdir
    put = 'let g:netrw_list_cmd = '.g:netrw_list_cmd
    put = 'let g:netrw_list_hide = '.g:netrw_list_hide
    put = 'let g:netrw_liststyle = '.g:netrw_liststyle
    put = 'let g:netrw_localcopycmd = '.g:netrw_localcopycmd
    put = 'let g:netrw_localcopycmdopt = '.g:netrw_localcopycmdopt
    put = 'let g:netrw_localmkdir = '.g:netrw_localmkdir
    put = 'let g:netrw_localmkdiropt = '.g:netrw_localmkdiropt
    put = 'let g:netrw_localmovecmd = '.g:netrw_localmovecmd
    put = 'let g:netrw_localmovecmdopt = '.g:netrw_localmovecmdopt
    put = 'let g:netrw_maxfilenamelen = '.g:netrw_maxfilenamelen
    put = 'let g:netrw_menu = '.g:netrw_menu
    put = 'let g:netrw_mousemaps = '.g:netrw_mousemaps
    put = 'let g:netrw_mkdir_cmd = '.g:netrw_mkdir_cmd
    if exists("g:netrw_nobeval")
        put = 'let g:netrw_nobeval = '.g:netrw_nobeval
    else
        put = '\" let g:netrw_nobeval = (not defined)'
    endif
    put = 'let g:netrw_remote_mkdir = '.g:netrw_remote_mkdir
    put = 'let g:netrw_preview = '.g:netrw_preview
    put = 'let g:netrw_rename_cmd = '.g:netrw_rename_cmd
    put = 'let g:netrw_retmap = '.g:netrw_retmap
    put = 'let g:netrw_rm_cmd = '.g:netrw_rm_cmd
    put = 'let g:netrw_rmdir_cmd = '.g:netrw_rmdir_cmd
    put = 'let g:netrw_rmf_cmd = '.g:netrw_rmf_cmd
    put = 'let g:netrw_sort_by = '.g:netrw_sort_by
    put = 'let g:netrw_sort_direction = '.g:netrw_sort_direction
    put = 'let g:netrw_sort_options = '.g:netrw_sort_options
    put = 'let g:netrw_sort_sequence = '.g:netrw_sort_sequence
    put = 'let g:netrw_servername = '.g:netrw_servername
    put = 'let g:netrw_special_syntax = '.g:netrw_special_syntax
    put = 'let g:netrw_ssh_browse_reject = '.g:netrw_ssh_browse_reject
    put = 'let g:netrw_ssh_cmd = '.g:netrw_ssh_cmd
    put = 'let g:netrw_scpport = '.g:netrw_scpport
    put = 'let g:netrw_sepchr = '.g:netrw_sepchr
    put = 'let g:netrw_sshport = '.g:netrw_sshport
    put = 'let g:netrw_timefmt = '.g:netrw_timefmt
    let tmpfileescline= line("$")
    put ='let g:netrw_tmpfile_escape...'
    put = 'let g:netrw_use_noswf = '.g:netrw_use_noswf
    put = 'let g:netrw_xstrlen = '.g:netrw_xstrlen
    put = 'let g:netrw_winsize = '.g:netrw_winsize

    put =''
    put ='+ For help, place cursor on line and press <F1>'

    1d
    silent %s/^+/"/e
    res 99
    silent %s/= \([^0-9].*\)$/= '\1'/e
    silent %s/= $/= ''/e
    1

    call setline(decompressline, "let g:netrw_decompress = ".substitute(string(g:netrw_decompress),"^'\\(.*\\)'$",'\1',''))
    call setline(fnameescline, "let g:netrw_fname_escape = '".escape(g:netrw_fname_escape,"'")."'")
    call setline(globescline, "let g:netrw_glob_escape = '".escape(g:netrw_glob_escape,"'")."'")
    call setline(tmpfileescline, "let g:netrw_tmpfile_escape = '".escape(g:netrw_tmpfile_escape,"'")."'")

    set nomod

    nmap <buffer> <silent> <F1> :call NetrwSettingHelp()<cr>
    nnoremap <buffer> <silent> <leftmouse> <leftmouse> :call NetrwSettingHelp()<cr>
    let tmpfile= tempname()
    exe 'au BufWriteCmd	Netrw\ Settings	silent w! '.tmpfile.'|so '.tmpfile.'|call delete("'.tmpfile.'")|set nomod'
endfunction

" }}}
" NetrwSettingHelp: {{{

function! NetrwSettingHelp()
    let curline = getline(".")
    if curline =~ '='
        let varhelp = substitute(curline,'^\s*let ','','e')
        let varhelp = substitute(varhelp,'\s*=.*$','','e')
        try
            exe "he ".varhelp
        catch /^Vim\%((\a\+)\)\=:E149/
            echo "***sorry*** no help available for <".varhelp.">"
        endtry
    elseif line(".") < s:netrw_settings_stop
        he netrw-settings
    elseif line(".") < s:netrw_protocol_stop
        he netrw-externapp
    elseif line(".") < s:netrw_xfer_stop
        he netrw-variables
    else
        he netrw-browse-var
    endif
endfunction

" }}}

" vim:ts=8 sts=4 sw=4 et fdm=marker
