" FUNCTIONS IN THIS FILE ARE MEANT TO BE USED BY NETRW.VIM AND NETRW.VIM ONLY.
" THESE FUNCTIONS DON'T COMMIT TO ANY BACKWARDS COMPATIBILITY. SO CHANGES AND
" BREAKAGES IF USED OUTSIDE OF NETRW.VIM ARE EXPECTED.

let s:deprecation_msgs = []
function! netrw#own#Deprecate(name, version, alternatives)
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

" vim:ts=8 sts=4 sw=4 et fdm=marker
