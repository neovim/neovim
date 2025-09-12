" FUNCTIONS IN THIS FILE ARE MEANT TO BE USED BY NETRW.VIM AND NETRW.VIM ONLY.
" THESE FUNCTIONS DON'T COMMIT TO ANY BACKWARDS COMPATIBILITY. SO CHANGES AND
" BREAKAGES IF USED OUTSIDE OF NETRW.VIM ARE EXPECTED.

" netrw#os#Execute: executes a string using "!" {{{

function! netrw#os#Execute(cmd)
    if has("win32") && exepath(&shell) !~? '\v[\/]?(cmd|pwsh|powershell)(\.exe)?$' && !g:netrw_cygwin
        let savedShell=[&shell,&shellcmdflag,&shellxquote,&shellxescape,&shellquote,&shellpipe,&shellredir,&shellslash]
        set shell& shellcmdflag& shellxquote& shellxescape&
        set shellquote& shellpipe& shellredir& shellslash&
        try
            execute a:cmd
        finally
            let [&shell,&shellcmdflag,&shellxquote,&shellxescape,&shellquote,&shellpipe,&shellredir,&shellslash] = savedShell
        endtry
    else
        execute a:cmd
    endif

    if v:shell_error
        call netrw#ErrorMsg(netrw#LogLevel('ERROR'), "shell signalled an error", 106)
    endif
endfunction

" }}}
" netrw#os#Escape: shellescape(), or special windows handling {{{

function! netrw#os#Escape(string, ...)
    return has('win32') && empty($SHELL) && &shellslash
        \ ? printf('"%s"', substitute(a:string, '"', '""', 'g'))
        \ : shellescape(a:string, a:0 > 0 ? a:1 : 0)
endfunction

" }}}
" netrw#os#Open: open file with os viewer (eg. xdg-open) {{{

function! netrw#os#Open(file) abort
    if has('nvim')
        call luaeval('vim.ui.open(_A[1]) and nil', [a:file])
    else
        call dist#vim9#Open(a:file)
    endif
endfunction

" }}}

" vim:ts=8 sts=4 sw=4 et fdm=marker
