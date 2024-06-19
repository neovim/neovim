" nohlsearch.vim: Auto turn off hlsearch
" Last Change: 2024-06-19
" Maintainer: Maxim Kim <habamax@gmail.com>
"
" turn off hlsearch after:
" - doing nothing for 'updatetime'
" - getting into insert mode
augroup nohlsearch
    au!
    noremap <Plug>(nohlsearch) <cmd>nohlsearch<cr>
    noremap! <Plug>(nohlsearch) <cmd>nohlsearch<cr>
    au CursorHold * call feedkeys("\<Plug>(nohlsearch)", 'm')
    au InsertEnter * call feedkeys("\<Plug>(nohlsearch)", 'm')
augroup END
