
""
" A function for finding the base directory containing a file
function! lsp#util#find_root_uri(pattern) abort
  let current_path = expand('%:p')

  while len(current_path) > 3
    let current_path = fnamemodify(current_path, ':h')
    let current_file = current_path . '/' . a:pattern

    if (filereadable(current_file) || isdirectory(current_file))
      return 'file://' . current_path . '/'
    endif
  endwhile

  return 'file:///tmp/'
endfunction
