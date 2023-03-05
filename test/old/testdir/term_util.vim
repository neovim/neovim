" Functions about terminal shared by several tests

" Only load this script once.
if exists('*CanRunVimInTerminal')
  finish
endif

func CanRunVimInTerminal()
  " Nvim: always false, we use Lua screen-tests instead.
  return 0
endfunc

" vim: shiftwidth=2 sts=2 expandtab
