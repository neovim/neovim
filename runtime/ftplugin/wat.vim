" Vim filetype plugin file
" Language:     WebAssembly
" Maintainer:   rhysd <lin90162@yahoo.co.jp>
" Last Change:  Nov 14, 2023
"               May 24, 2024 by Riley Bruins <ribru17@gmail.com> ('commentstring')
" For bugs, patches and license go to https://github.com/rhysd/vim-wasm

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

setlocal comments=s:(;,e:;),:;;
setlocal commentstring=(;\ %s\ ;)
setlocal formatoptions-=t
setlocal iskeyword+=$,.,/

let b:undo_ftplugin = "setlocal comments< commentstring< formatoptions< iskeyword<"
