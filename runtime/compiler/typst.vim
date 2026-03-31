" Vim compiler file
" Language:    Typst
" Previous Maintainer:  Luca Saccarola <github.e41mv@aleeas.com>
" Maintainer:  This runtime file is looking for a new maintainer.
" Based On:    https://github.com/kaarmu/typst.vim
" Last Change: 2025 Aug 05

if exists('current_compiler')
    finish
endif
let current_compiler = get(g:, 'typst_cmd', 'typst')

" With `--diagnostic-format` we can use the default errorformat
let s:makeprg = [current_compiler, 'compile', '--diagnostic-format', 'short', '%:S']

" CompilerSet makeprg=typst
execute 'CompilerSet makeprg=' . join(s:makeprg, '\ ')
