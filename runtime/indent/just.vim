" Vim indent file
" Language:	Justfile
" Maintainer:	Peter Benjamin <@pbnj>
" Last Change:	2025 Jan 19
" Credits:	The original author, Noah Bogart <https://github.com/NoahTheDuke/vim-just/>

" Only load this indent file when no other was loaded yet.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetJustfileIndent()
setlocal indentkeys=0},0),!^F,o,O,0=''',0=\"\"\"

let b:undo_indent = "setlocal indentexpr< indentkeys<"

if exists("*GetJustfileIndent")
  finish
endif

function GetJustfileIndent()
  if v:lnum < 2
    return 0
  endif

  let prev_line = getline(v:lnum - 1)
  let last_indent = indent(v:lnum - 1)

  if getline(v:lnum) =~ "\\v^\\s+%([})]|'''$|\"\"\"$)"
    return last_indent - shiftwidth()
  elseif prev_line =~ '\V#'
    return last_indent
  elseif prev_line =~ "\\v%([:{(]|^.*\\S.*%([^']'''|[^\"]\"\"\"))\\s*$"
    return last_indent + shiftwidth()
  elseif prev_line =~ '\\$'
    if v:lnum == 2 || getline(v:lnum - 2) !~ '\\$'
      if prev_line =~ '\v:\=@!'
        return last_indent + shiftwidth() + shiftwidth()
      else
        return last_indent + shiftwidth()
      endif
    endif
  elseif v:lnum > 2 && getline(v:lnum - 2) =~ '\\$'
    return last_indent - shiftwidth()
  elseif prev_line =~ '\v:\s*%(\h|\()' && prev_line !~ '\V:='
    return last_indent + shiftwidth()
  endif

  return last_indent
endfunction
