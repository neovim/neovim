" Language:    HCL
" Maintainer:  Gregory Anders
" Last Change: 2024-09-03
" Based on:    https://github.com/hashivim/vim-terraform

function! hcl#indentexpr(lnum)
  " Beginning of the file should have no indent
  if a:lnum == 0
    return 0
  endif

  " Usual case is to continue at the same indent as the previous non-blank line.
  let prevlnum = prevnonblank(a:lnum-1)
  let thisindent = indent(prevlnum)

  " If that previous line is a non-comment ending in [ { (, increase the
  " indent level.
  let prevline = getline(prevlnum)
  if prevline !~# '^\s*\(#\|//\)' && prevline =~# '[\[{\(]\s*$'
    let thisindent += &shiftwidth
  endif

  " If the current line ends a block, decrease the indent level.
  let thisline = getline(a:lnum)
  if thisline =~# '^\s*[\)}\]]'
    let thisindent -= &shiftwidth
  endif

  " If the previous line starts a block comment /*, increase by one
  if prevline =~# '/\*'
    let thisindent += 1
  endif

  " If the previous line ends a block comment */, decrease by one
  if prevline =~# '\*/'
    let thisindent -= 1
  endif

  return thisindent
endfunction
