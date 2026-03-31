" nohlsearch.vim: Auto turn off hlsearch
" Last Change: 2025-03-08
" Maintainer: Maxim Kim <habamax@gmail.com>
"
" turn off hlsearch after:
" - doing nothing for 'updatetime'
" - getting into insert mode

if exists('g:loaded_nohlsearch')
    finish
endif
let g:loaded_nohlsearch = 1

func! s:Nohlsearch()
    if v:hlsearch
        call feedkeys("\<cmd>nohlsearch\<cr>", 'm')
    endif
endfunc

augroup nohlsearch
    au!
    au CursorHold * call s:Nohlsearch()
    au InsertEnter * call s:Nohlsearch()
augroup END
