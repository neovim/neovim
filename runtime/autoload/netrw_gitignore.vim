" netrw_gitignore#Hide: gitignore-based hiding
"  Function returns a string of comma separated patterns convenient for
"  assignment to `g:netrw_list_hide` option.
"  Function can take additional filenames as arguments, example:
"  netrw_gitignore#Hide('custom_gitignore1', 'custom_gitignore2')
"
" Usage examples:
"  let g:netrw_list_hide = netrw_gitignore#Hide()
"  let g:netrw_list_hide = netrw_gitignore#Hide() . 'more,hide,patterns'
"
" Copyright:    Copyright (C) 2013 Bruno Sutic {{{1
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               netrw_gitignore.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. By using
"               this plugin, you agree that in no event will the copyright
"               holder be liable for any damages resulting from the use
"               of this software.
function! netrw_gitignore#Hide(...)
  let additional_files = a:000

  let default_files = ['.gitignore', '.git/info/exclude']

  " get existing global/system gitignore files
  let global_gitignore = expand(substitute(system("git config --global core.excludesfile"), '\n', '', 'g'))
  if global_gitignore !=# ''
    let default_files = add(default_files, global_gitignore)
  endif
  let system_gitignore = expand(substitute(system("git config --system core.excludesfile"), '\n', '', 'g'))
  if system_gitignore !=# ''
    let default_files = add(default_files, system_gitignore)
  endif

  " append additional files if given as function arguments
  if additional_files !=# []
    let files = extend(default_files, additional_files)
  else
    let files = default_files
  endif

  " keep only existing/readable files
  let gitignore_files = []
  for file in files
    if filereadable(file)
      let gitignore_files = add(gitignore_files, file)
    endif
  endfor

  " get contents of gitignore patterns from those files
  let gitignore_lines = []
  for file in gitignore_files
    for line in readfile(file)
      " filter empty lines and comments
      if line !~# '^#' && line !~# '^$'
        let gitignore_lines = add(gitignore_lines, line)
      endif
    endfor
  endfor

  " convert gitignore patterns to Netrw/Vim regex patterns
  let escaped_lines = []
  for line in gitignore_lines
    let escaped       = line
    let escaped       = substitute(escaped, '\.', '\\.', 'g')
    let escaped       = substitute(escaped, '*', '.*', 'g')
    let escaped_lines = add(escaped_lines, escaped)
  endfor

  return join(escaped_lines, ',')
endfunction
