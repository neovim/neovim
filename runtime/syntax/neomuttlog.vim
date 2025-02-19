" Vim syntax file
" Language:  NeoMutt log files
" Maintainer:  Richard Russon <rich@flatcap.org>
" Last Change:  2024 Oct 12

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syntax match neolog_date     "\v^\[\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\] *" conceal
syntax match neolog_version  "\v<NeoMutt-\d{8}(-\d+-\x+)*(-dirty)*>"
syntax match neolog_banner   "\v^\[\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\] .*" contains=neolog_date,neolog_version
syntax match neolog_function "\v%26v\i+\(\)"

syntax match neolog_perror_key  "\v%22v\<P\> " conceal transparent
syntax match neolog_error_key   "\v%22v\<E\> " conceal transparent
syntax match neolog_warning_key "\v%22v\<W\> " conceal transparent
syntax match neolog_message_key "\v%22v\<M\> " conceal transparent
syntax match neolog_debug1_key  "\v%22v\<1\> " conceal transparent
syntax match neolog_debug2_key  "\v%22v\<2\> " conceal transparent
syntax match neolog_debug3_key  "\v%22v\<3\> " conceal transparent
syntax match neolog_debug4_key  "\v%22v\<4\> " conceal transparent
syntax match neolog_debug5_key  "\v%22v\<5\> " conceal transparent
syntax match neolog_notify_key  "\v%22v\<N\> " conceal transparent

syntax match neolog_perror  "\v%22v\<P\> .*" contains=neolog_perror_key,neolog_function
syntax match neolog_error   "\v%22v\<E\> .*" contains=neolog_error_key,neolog_function
syntax match neolog_warning "\v%22v\<W\> .*" contains=neolog_warning_key,neolog_function
syntax match neolog_message "\v%22v\<M\> .*" contains=neolog_message_key,neolog_function
syntax match neolog_debug1  "\v%22v\<1\> .*" contains=neolog_debug1_key,neolog_function
syntax match neolog_debug2  "\v%22v\<2\> .*" contains=neolog_debug2_key,neolog_function
syntax match neolog_debug3  "\v%22v\<3\> .*" contains=neolog_debug3_key,neolog_function
syntax match neolog_debug4  "\v%22v\<4\> .*" contains=neolog_debug4_key,neolog_function
syntax match neolog_debug5  "\v%22v\<5\> .*" contains=neolog_debug5_key,neolog_function
syntax match neolog_notify  "\v%22v\<N\> .*" contains=neolog_notify_key,neolog_function

if !exists('g:neolog_disable_default_colors')
  highlight neolog_date     ctermfg=cyan    guifg=#40ffff
  highlight neolog_banner   ctermfg=magenta guifg=#ff00ff
  highlight neolog_version  cterm=reverse   gui=reverse
  highlight neolog_function                 guibg=#282828

  highlight neolog_perror  ctermfg=red    guifg=#ff8080
  highlight neolog_error   ctermfg=red    guifg=#ff8080
  highlight neolog_warning ctermfg=yellow guifg=#ffff80
  highlight neolog_message ctermfg=green  guifg=#80ff80
  highlight neolog_debug1  ctermfg=white  guifg=#ffffff
  highlight neolog_debug2  ctermfg=white  guifg=#ffffff
  highlight neolog_debug3  ctermfg=grey   guifg=#c0c0c0
  highlight neolog_debug4  ctermfg=grey   guifg=#c0c0c0
  highlight neolog_debug5  ctermfg=grey   guifg=#c0c0c0
  highlight neolog_notify  ctermfg=grey   guifg=#c0c0c0
endif

highlight link neolog_perror_key  neolog_perror
highlight link neolog_error_key   neolog_error
highlight link neolog_warning_key neolog_warning
highlight link neolog_message_key neolog_message
highlight link neolog_debug1_key  neolog_debug1
highlight link neolog_debug2_key  neolog_debug2
highlight link neolog_debug3_key  neolog_debug3
highlight link neolog_debug4_key  neolog_debug4
highlight link neolog_debug5_key  neolog_debug5
highlight link neolog_notify_key  neolog_notify

let b:current_syntax = "neomuttlog"

" vim: ts=2 et tw=100 sw=2 sts=0 ft=vim
