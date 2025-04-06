" vim compiler file
" Compiler:	cppcheck (C++ static checker)
" Maintainer:   Vincent B. (twinside@free.fr)
" Last Change:  2024 Nov 19 by @Konfekt

if exists("current_compiler") | finish | endif
let current_compiler = "cppcheck"

let s:cpo_save = &cpo
set cpo&vim

let s:slash = has('win32')? '\' : '/'

if !exists('g:c_cppcheck_params')
  let g:c_cppcheck_params = '--verbose --force --inline-suppr'
        \ ..' '..'--enable=warning,style,performance,portability,information,missingInclude'
        \ ..' '..(executable('getconf') ? '-j' .. systemlist('getconf _NPROCESSORS_ONLN')[0] : '')
  let s:undo_compiler = 'unlet! g:c_cppcheck_params'
endif

let &l:makeprg = 'cppcheck --quiet'
      \ ..' --template="{file}:{line}:{column}: {severity}: [{id}] {message} {callstack}"'
      \ ..' '..get(b:, 'c_cppcheck_params', get(g:, 'c_cppcheck_params', (&filetype ==# 'cpp' ? ' --language=c++' : '')))
      \ ..' '..get(b:, 'c_cppcheck_includes', get(g:, 'c_cppcheck_includes',
      \	          (filereadable('compile_commands.json') ? '--project=compile_commands.json' :
      \           (!empty(glob('*'..s:slash..'compile_commands.json', 1, 1)) ? '--project='..glob('*'..s:slash..'compile_commands.json', 1, 1)[0] :
      \	          (empty(&path) ? '' : '-I')..join(map(filter(split(&path, ','), 'isdirectory(v:val)'),'shellescape(v:val)'), ' -I')))))
exe 'CompilerSet makeprg='..escape(&l:makeprg, ' \|"')

CompilerSet errorformat=
  \%f:%l:%c:\ %tarning:\ %m,
  \%f:%l:%c:\ %trror:\ %m,
  \%f:%l:%c:\ %tnformation:\ %m,
  \%f:%l:%c:\ %m,
  \%.%#\ :\ [%f:%l]\ %m

exe get(s:, 'undo_compiler', '')

let &cpo = s:cpo_save
unlet s:cpo_save
