if exists('g:loaded_luahost')
    finish
endif
let g:loaded_luahost = 1

let s:path = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
let s:partial_line = ''

function! s:on_stderr(id, data, event)
    if len(a:data) == 0
        return
    endif
    let s:partial_line = s:partial_line . a:data[0]
    if len(a:data) == 1
        return
    endif
    echo s:partial_line
    for line in a:data[1:len(a:data)-1]
        echo line
    endfor
    let s:partial_line = a:data[len(a:data)-1]
endfunction

function! s:on_exit(id, data, event)
    if a:data == 0
        return
    endif
    echom "Exit" a:data a:event
endfunction

function! s:start(host) abort
    return jobstart([v:progpath, '-u', 'NONE', '-i', 'NONE', '--headless', '-c', 'luafile pmain.lua', '-c', 'qa!'], {
        \   'rpc': 1,
        \   'cwd': s:path,
        \   'on_stderr': function('s:on_stderr'),
        \   'on_exit': function('s:on_exit')
        \ })
endfunction

call remote#host#Register('lua', '*.lua', function('s:start'))
