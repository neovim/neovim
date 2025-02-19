if exists('g:loaded_shada_plugin')
  finish
endif
let g:loaded_shada_plugin = 1

augroup ShaDaCommands
  autocmd!
  autocmd BufReadCmd *.shada,*.shada.tmp.[a-z]
        \ :if !empty(v:cmdarg)|throw '++opt not supported'|endif
        \ |call setline('.', shada#get_strings(readfile(expand('<afile>'),'b')))
        \ |setlocal filetype=shada
  autocmd FileReadCmd *.shada,*.shada.tmp.[a-z]
        \ :if !empty(v:cmdarg)|throw '++opt not supported'|endif
        \ |call append("'[", shada#get_strings(readfile(expand('<afile>'), 'b')))
  autocmd BufWriteCmd *.shada,*.shada.tmp.[a-z]
        \ :if !empty(v:cmdarg)|throw '++opt not supported'|endif
        \ |if writefile(shada#get_binstrings(getline(1, '$')),
                       \expand('<afile>'), 'b') == 0
        \ |  let &l:modified = (expand('<afile>') is# bufname(+expand('<abuf>'))
                               \? 0
                               \: stridx(&cpoptions, '+') != -1)
        \ |endif
  autocmd FileWriteCmd *.shada,*.shada.tmp.[a-z]
        \ :if !empty(v:cmdarg)|throw '++opt not supported'|endif
        \ |call writefile(
              \shada#get_binstrings(getline(min([line("'["), line("']")]),
                                           \max([line("'["), line("']")]))),
              \expand('<afile>'),
              \'b')
  autocmd FileAppendCmd *.shada,*.shada.tmp.[a-z]
        \ :if !empty(v:cmdarg)|throw '++opt not supported'|endif
        \ |call writefile(
              \shada#get_binstrings(getline(min([line("'["), line("']")]),
                                           \max([line("'["), line("']")]))),
              \expand('<afile>'),
              \'ab')
  autocmd SourceCmd *.shada,*.shada.tmp.[a-z]
        \ :execute 'rshada' fnameescape(expand('<afile>'))
augroup END
