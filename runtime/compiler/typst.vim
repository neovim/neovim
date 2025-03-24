" Vim compiler file
" Language:    Typst
" Previous Maintainer:  Gregory Anders
" Maintainer:  Luca Saccarola <github.e41mv@aleeas.com>
" Based On:    https://github.com/kaarmu/typst.vim
" Last Change: 2024 Dec 09
" 2025 Mar 11 by the Vim Project (add comment for Dispatch)

if exists('current_compiler')
    finish
endif
let current_compiler = get(g:, 'typst_cmd', 'typst')

" With `--diagnostic-format` we can use the default errorformat
let s:makeprg = [current_compiler, 'compile', '--diagnostic-format', 'short', '%:S']

" CompilerSet makeprg=typst
execute 'CompilerSet makeprg=' . join(s:makeprg, '\ ')
