" Vim compiler file
" Compiler:     ConTeXt typesetting engine
" Maintainer:   Nicola Vitacolonna <nvitacolonna@gmail.com>
" Last Change:  2016 Oct 21

if exists("current_compiler")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

if exists(":CompilerSet") != 2    " older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

" If makefile exists and we are not asked to ignore it, we use standard make
" (do not redefine makeprg)
if get(b:, 'context_ignore_makefile', get(g:, 'context_ignore_makefile', 0)) ||
      \ (!filereadable('Makefile') && !filereadable('makefile'))
  let current_compiler = 'context'
  " The following assumes that the current working directory is set to the
  " directory of the file to be typeset
  let &l:makeprg = get(b:, 'context_mtxrun', get(g:, 'context_mtxrun', 'mtxrun'))
        \ . ' --script context --autogenerate --nonstopmode --synctex='
        \ . (get(b:, 'context_synctex', get(g:, 'context_synctex', 0)) ? '1' : '0')
        \ . ' ' . get(b:, 'context_extra_options', get(g:, 'context_extra_options', ''))
        \ . ' ' . shellescape(expand('%:p:t'))
else
  let current_compiler = 'make'
endif

let b:context_errorformat = ''
      \ . '%-Popen source%.%#> %f,'
      \ . '%-Qclose source%.%#> %f,'
      \ . "%-Popen source%.%#name '%f',"
      \ . "%-Qclose source%.%#name '%f',"
      \ . '%Etex %trror%.%#mp error on line %l in file %f:%.%#,'
      \ . 'tex %trror%.%#error on line %l in file %f: %m,'
      \ . '%Elua %trror%.%#error on line %l in file %f:,'
      \ . '%+Emetapost %#> error: %#,'
      \ . '! error: %#%m,'
      \ . '%-C %#,'
      \ . '%C! %m,'
      \ . '%Z[ctxlua]%m,'
      \ . '%+C<*> %.%#,'
      \ . '%-C%.%#,'
      \ . '%Z...%m,'
      \ . '%-Zno-error,'
      \ . '%-G%.%#' " Skip remaining lines

execute 'CompilerSet errorformat=' . escape(b:context_errorformat, ' ')

let &cpo = s:keepcpo
unlet s:keepcpo
