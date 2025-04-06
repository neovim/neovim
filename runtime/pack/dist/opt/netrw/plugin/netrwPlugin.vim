" Maintainer: Luca Saccarola <github.e41mv@aleeas.com>
" Former Maintainer: Charles E Campbell
" Upstream: <https://github.com/saccarosium/netrw.vim>
" Copyright:    Copyright (C) 1999-2021 Charles E. Campbell {{{
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               netrw.vim, netrwPlugin.vim, and netrwSettings.vim are provided
"               *as is* and comes with no warranty of any kind, either
"               expressed or implied. By using this plugin, you agree that
"               in no event will the copyright holder be liable for any damages
"               resulting from the use of this software. }}}

if &cp || exists("g:loaded_netrwPlugin")
    finish
endif

let g:loaded_netrwPlugin = "v175"

let s:keepcpo = &cpo
set cpo&vim

" Local Browsing Autocmds: {{{

augroup FileExplorer
    au!
    au BufLeave * if &ft != "netrw"|let w:netrw_prvfile= expand("%:p")|endif
    au BufEnter * sil call s:LocalBrowse(expand("<amatch>"))
    au VimEnter * sil call s:VimEnter(expand("<amatch>"))
    if has("win32")
        au BufEnter .* sil call s:LocalBrowse(expand("<amatch>"))
    endif
augroup END

" }}}
" Network Browsing Reading Writing: {{{

augroup Network
    au!
    au BufReadCmd file://* call netrw#FileUrlEdit(expand("<amatch>"))
    au BufReadCmd ftp://*,rcp://*,scp://*,http://*,https://*,dav://*,davs://*,rsync://*,sftp://* exe "sil doau BufReadPre ".fnameescape(expand("<amatch>"))|call netrw#Nread(2,expand("<amatch>"))|exe "sil doau BufReadPost ".fnameescape(expand("<amatch>"))
    au FileReadCmd ftp://*,rcp://*,scp://*,http://*,file://*,https://*,dav://*,davs://*,rsync://*,sftp://* exe "sil doau FileReadPre ".fnameescape(expand("<amatch>"))|call netrw#Nread(1,expand("<amatch>"))|exe "sil doau FileReadPost ".fnameescape(expand("<amatch>"))
    au BufWriteCmd ftp://*,rcp://*,scp://*,http://*,file://*,dav://*,davs://*,rsync://*,sftp://* exe "sil doau BufWritePre ".fnameescape(expand("<amatch>"))|exe 'Nwrite '.fnameescape(expand("<amatch>"))|exe "sil doau BufWritePost ".fnameescape(expand("<amatch>"))
    au FileWriteCmd ftp://*,rcp://*,scp://*,http://*,file://*,dav://*,davs://*,rsync://*,sftp://* exe "sil doau FileWritePre ".fnameescape(expand("<amatch>"))|exe "'[,']".'Nwrite '.fnameescape(expand("<amatch>"))|exe "sil doau FileWritePost ".fnameescape(expand("<amatch>"))
    try
        au SourceCmd   ftp://*,rcp://*,scp://*,http://*,file://*,https://*,dav://*,davs://*,rsync://*,sftp://* exe 'Nsource '.fnameescape(expand("<amatch>"))
    catch /^Vim\%((\a\+)\)\=:E216/
        au SourcePre   ftp://*,rcp://*,scp://*,http://*,file://*,https://*,dav://*,davs://*,rsync://*,sftp://* exe 'Nsource '.fnameescape(expand("<amatch>"))
    endtry
augroup END

" }}}
" Commands: :Nread, :Nwrite, :NetUserPass {{{

command! -count=1 -nargs=* Nread let s:svpos= winsaveview()<bar>call netrw#NetRead(<count>,<f-args>)<bar>call winrestview(s:svpos)
command! -range=% -nargs=* Nwrite let s:svpos= winsaveview()<bar><line1>,<line2>call netrw#NetWrite(<f-args>)<bar>call winrestview(s:svpos)
command! -nargs=* NetUserPass call NetUserPass(<f-args>)
command! -nargs=* Nsource let s:svpos= winsaveview()<bar>call netrw#NetSource(<f-args>)<bar>call winrestview(s:svpos)
command! -nargs=? Ntree call netrw#SetTreetop(1,<q-args>)

" }}}
" Commands: :Explore, :Sexplore, Hexplore, Vexplore, Lexplore {{{

command! -nargs=* -bar -bang -count=0 -complete=dir Explore call netrw#Explore(<count>, 0, 0+<bang>0, <q-args>)
command! -nargs=* -bar -bang -count=0 -complete=dir Sexplore call netrw#Explore(<count>, 1, 0+<bang>0, <q-args>)
command! -nargs=* -bar -bang -count=0 -complete=dir Hexplore call netrw#Explore(<count>, 1, 2+<bang>0, <q-args>)
command! -nargs=* -bar -bang -count=0 -complete=dir Vexplore call netrw#Explore(<count>, 1, 4+<bang>0, <q-args>)
command! -nargs=* -bar -count=0 -complete=dir Texplore call netrw#Explore(<count>, 0, 6, <q-args>)
command! -nargs=* -bar -bang -count=0 -complete=dir Lexplore call netrw#Lexplore(<count>, <bang>0, <q-args>)
command! -nargs=* -bar -bang Nexplore call netrw#Explore(-1, 0, 0, <q-args>)
command! -nargs=* -bar -bang Pexplore call netrw#Explore(-2, 0, 0, <q-args>)

" }}}
" Commands: NetrwSettings {{{

command! -nargs=0 NetrwSettings call netrwSettings#NetrwSettings()
command! -bang NetrwClean call netrw#Clean(<bang>0)

" }}}
" Maps: {{{

if exists("g:netrw_usetab") && g:netrw_usetab
    if maparg('<c-tab>','n') == ""
        nmap <unique> <c-tab> <Plug>NetrwShrink
    endif
    nno <silent> <Plug>NetrwShrink :call netrw#Shrink()<cr>
endif

" }}}
" LocalBrowse: invokes netrw#LocalBrowseCheck() on directory buffers {{{

function! s:LocalBrowse(dirname)
    " do not trigger in the terminal
    " https://github.com/vim/vim/issues/16463
    if &buftype ==# 'terminal'
        return
    endif

    if !exists("s:vimentered")
        " If s:vimentered doesn't exist, then the VimEnter event hasn't fired.  It will,
        " and so s:VimEnter() will then be calling this routine, but this time with s:vimentered defined.
        return
    endif

    if has("amiga")
        " The check against '' is made for the Amiga, where the empty
        " string is the current directory and not checking would break
        " things such as the help command.
        if a:dirname != '' && isdirectory(a:dirname)
            sil! call netrw#LocalBrowseCheck(a:dirname)
            if exists("w:netrw_bannercnt") && line('.') < w:netrw_bannercnt
                exe w:netrw_bannercnt
            endif
        endif
    elseif isdirectory(a:dirname)
        " Jul 13, 2021: for whatever reason, preceding the following call with
        " a   sil!  causes an unbalanced if-endif vim error
        call netrw#LocalBrowseCheck(a:dirname)
        if exists("w:netrw_bannercnt") && line('.') < w:netrw_bannercnt
            exe w:netrw_bannercnt
        endif
    endif
endfunction

" }}}
" s:VimEnter: after all vim startup stuff is done, this function is called. {{{
"             Its purpose: to look over all windows and run s:LocalBrowse() on
"             them, which checks if they're directories and will create a directory
"             listing when appropriate.
"             It also sets s:vimentered, letting s:LocalBrowse() know that s:VimEnter()
"             has already been called.
function! s:VimEnter(dirname)
    if has('nvim') || v:version < 802
        " Johann Höchtl: reported that the call range... line causes an E488: Trailing characters
        "                error with neovim. I suspect its because neovim hasn't updated with recent
        "                vim patches. As is, this code will have problems with popup terminals
        "                instantiated before the VimEnter event runs.
        " Ingo Karkat  : E488 also in Vim 8.1.1602
        let curwin       = winnr()
        let s:vimentered = 1
        windo call s:LocalBrowse(expand("%:p"))
        exe curwin."wincmd w"
    else
        " the following complicated expression comes courtesy of lacygoill; largely does the same thing as the windo and
        " wincmd which are commented out, but avoids some side effects. Allows popup terminal before VimEnter.
        let s:vimentered = 1
        call range(1, winnr('$'))->map({_, v -> win_execute(win_getid(v), 'call expand("%:p")->s:LocalBrowse()')})
    endif
endfunction

" }}}
" NetrwStatusLine: {{{

function! NetrwStatusLine()
    if !exists("w:netrw_explore_bufnr") || w:netrw_explore_bufnr != bufnr("%") || !exists("w:netrw_explore_line") || w:netrw_explore_line != line(".") || !exists("w:netrw_explore_list")
        let &stl= s:netrw_explore_stl
        unlet! w:netrw_explore_bufnr w:netrw_explore_line
        return ""
    else
        return "Match ".w:netrw_explore_mtchcnt." of ".w:netrw_explore_listlen
    endif
endfunction

" }}}
" NetUserPass: set username and password for subsequent ftp transfer {{{
"   Usage:  :call NetUserPass()                 -- will prompt for userid and password
"           :call NetUserPass("uid")            -- will prompt for password
"           :call NetUserPass("uid","password") -- sets global userid and password
function! NetUserPass(...)
    " get/set userid
    if a:0 == 0
        if !exists("g:netrw_uid") || g:netrw_uid == ""
            " via prompt
            let g:netrw_uid= input('Enter username: ')
        endif
    else  " from command line
        let g:netrw_uid= a:1
    endif

    " get password
    if a:0 <= 1 " via prompt
        let g:netrw_passwd= inputsecret("Enter Password: ")
    else " from command line
        let g:netrw_passwd=a:2
    endif
endfunction

" }}}

let &cpo= s:keepcpo
unlet s:keepcpo

" vim:ts=8 sts=4 sw=4 et fdm=marker
