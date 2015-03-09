let s:fs_notify_on = 0

function! fs#notify_turn_on()
    if s:fs_notify_on == 1
    	return
    endif

    for i in range(tabpagenr('$'))
    	for buf in tabpagebuflist(i+1)
            call notify_register(buf)
        endfor
    endfor

    let s:fs_notify_on = 1
endfunction fs#notify_turn_on

augroup fs_notification
    autocmd BufRead        * call notify_register(expand('<afile>'))
    autocmd BufDelete      * call notify_unregister(expand('<afile>'))
    autocmd BufWritePre    * call notify_set(expand('<afile>'), 0)
    autocmd FileWritePre   * call notify_set(expand('<afile>'), 0)
    autocmd FileAppendPre  * call notify_set(expand('<afile>'), 0)
    autocmd BufWritePost   * call notify_register(expand('<afile>'))
    autocmd FileWritePost  * call notify_register(expand('<afile>'))
    autocmd FileAppendPost * call notify_register(expand('<afile>'))

    autocmd BufFilePre     * call notify_unregister(expand('<afile>'))
    autocmd BufFilePost    * call notify_unregister(expand('<afile>'))
augroup END
