" FUNCTIONS IN THIS FILE ARE MEANT TO BE USED BY NETRW.VIM AND NETRW.VIM ONLY.
" THESE FUNCTIONS DON'T COMMIT TO ANY BACKWARDS COMPATIBILITY. SO CHANGES AND
" BREAKAGES IF USED OUTSIDE OF NETRW.VIM ARE EXPECTED.

let s:deprecation_msgs = []
function! netrw#msg#Deprecate(name, version, alternatives)
    " If running on neovim use vim.deprecate
    if has('nvim')
        let s:alternative = a:alternatives->get('nvim', v:null)
        call v:lua.vim.deprecate(a:name, s:alternative, a:version, "netrw", v:false)
        return
    endif

    " If we did notify for something only do it once
    if s:deprecation_msgs->index(a:name) >= 0
        return
    endif

    let s:alternative = a:alternatives->get('vim', v:null)
    echohl WarningMsg
    echomsg s:alternative != v:null
                \ ? printf('%s is deprecated, use %s instead.', a:name, s:alternative)
                \ : printf('%s is deprecated.', a:name)
    echomsg printf('Feature will be removed in netrw %s', a:version)
    echohl None

    call add(s:deprecation_msgs, a:name)
endfunction

" netrw#msg#Notify: {{{
"   Usage: netrw#msg#Notify('ERROR'|'WARNING'|'NOTE', 'some message')
"          netrw#msg#Notify('ERROR'|'WARNING'|'NOTE', ["message1","message2",...])
"          (this function can optionally take a list of messages)
function! netrw#msg#Notify(level, msg)
    if has('nvim')
        " Convert string to corresponding vim.log.level value
        if a:level ==# 'ERROR'
            let level = 4
        elseif a:level ==# 'WARNING'
            let level = 3
        elseif a:level ==# 'NOTE'
            let level = 2
        endif
        call v:lua.vim.notify(a:msg, level)
        return
    endif

    if a:level ==# 'WARNING'
        echohl WarningMsg
    elseif a:level ==# 'ERROR'
        echohl ErrorMsg
    else
        echoerr printf('"%s" is not a valid level', a:level)
        return
    endif

    if type(a:msg) == v:t_list
        for msg in a:msg
            echomsg msg
        endfor
    else
        echomsg a:msg
    endif

    echohl None
endfunction

" }}}

" vim:ts=8 sts=4 sw=4 et fdm=marker
