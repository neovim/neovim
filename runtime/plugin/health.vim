function! s:complete(lead, _line, _pos) abort
  return sort(filter(map(globpath(&runtimepath, 'autoload/health/*', 1, 1),
        \ 'fnamemodify(v:val, ":t:r")'),
        \ 'empty(a:lead) || v:val[:strlen(a:lead)-1] ==# a:lead'))
endfunction

command! -nargs=* -complete=customlist,s:complete CheckHealth
      \ call health#check([<f-args>])
