" Language:    gprof
" Maintainer:  Dominique Pelle <dominique.pelle@gmail.com>
" Last Change: 2021 Apr 08

" When cursor is on one line of the gprof call graph,
" calling this function jumps to this function in the call graph.
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin=1

fun! <SID>GprofJumpToFunctionIndex()
  let l:line = getline('.')
  if l:line =~ '[\d\+\]$'
    " We're in a line in the call graph.
    norm! $y%
    call search('^' . escape(@", '[]'), 'sw')
    norm! zz
  elseif l:line =~ '^\(\s*[0-9\.]\+\)\{3}\s\+'
    " We're in line in the flat profile.
    norm! 55|eby$
    call search('^\[\d\+\].*\d\s\+' .  escape(@", '[]*.') . '\>', 'sW')
    norm! zz
  endif
endfun

" Pressing <C-]> on a line in the gprof flat profile or in
" the call graph, jumps to the corresponding function inside
" the flat profile.
map <buffer> <silent> <C-]> :call <SID>GprofJumpToFunctionIndex()<CR>

" vim:sw=2 fdm=indent
