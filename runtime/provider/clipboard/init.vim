" The clipboard provider uses shell commands to communicate with the clipboard.
" The ProviderCall autocommands will only be set if one of the supported
" commands are available.
let s:copy = ''
let s:paste = ''

if executable('pbcopy')
  let s:copy = 'pbcopy'
  let s:paste = 'pbpaste'
elseif executable('xsel')
  let s:copy = 'xsel -i -b'
  let s:paste = 'xsel -o -b'
elseif executable('xclip')
  let s:copy = 'xclip -i -selection clipboard'
  let s:paste = 'xclip -o -selection clipboard'
endif

if s:copy == ''
  finish
endif

au ProviderCall clipboard_set call systemlist(s:copy, v:provider_args)
au ProviderCall clipboard_get let v:provider_result = systemlist(s:paste)

