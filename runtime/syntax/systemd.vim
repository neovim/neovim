" Vim syntax file
" Language:  systemd.unit(5)

if !exists('b:current_syntax')
  " Looks a lot like dosini files.
  runtime! syntax/dosini.vim
  let b:current_syntax = 'systemd'
endif
