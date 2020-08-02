source shared.vim
source term_util.vim

" Command to check that making screendumps is supported.
" Caller must source screendump.vim
command CheckScreendump call CheckScreendump()
func CheckScreendump()
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps'
  endif
endfunc
