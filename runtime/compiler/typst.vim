" Vim compiler file
" Language:    Typst
" Maintainer:  Gregory Anders
" Last Change: 2024-07-14
" Based on:    https://github.com/kaarmu/typst.vim

if exists('current_compiler')
    finish
endif
let current_compiler = get(g:, 'typst_cmd', 'typst')

" With `--diagnostic-format` we can use the default errorformat
let s:makeprg = [current_compiler, 'compile', '--diagnostic-format', 'short', '%:S']

execute 'CompilerSet makeprg=' . join(s:makeprg, '\ ')
