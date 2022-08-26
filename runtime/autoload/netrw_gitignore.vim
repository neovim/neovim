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
  return substitute(substitute(system('git ls-files --other --ignored --exclude-standard --directory'), '\n', ',', 'g'), ',$', '', '')
endfunction
