" Vim indent file
" Language:	Dylan
" Version:	0.01
" Last Change:	2003 Feb 04
" Maintainer:	Brent A. Fulgham <bfulgham@debian.org>

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentkeys+==~begin,=~block,=~case,=~cleanup,=~define,=~end,=~else,=~elseif,=~exception,=~for,=~finally,=~if,=~otherwise,=~select,=~unless,=~while

" Define the appropriate indent function but only once
setlocal indentexpr=DylanGetIndent()
if exists("*DylanGetIndent")
  finish
endif

function DylanGetIndent()
  " Get the line to be indented
  let cline = getline(v:lnum)

  " Don't reindent comments on first column
  if cline =~ '^/\[/\*]'
    return 0
  endif

  "Find the previous non-blank line
  let lnum = prevnonblank(v:lnum - 1)
  "Use zero indent at the top of the file
  if lnum == 0
    return 0
  endif

  let prevline=getline(lnum)
  let ind = indent(lnum)
  let chg = 0

  " If previous line was a comment, use its indent
  if prevline =~ '^\s*//'
    return ind
  endif

  " If previous line was a 'define', indent
  if prevline =~? '\(^\s*\(begin\|block\|case\|define\|else\|elseif\|for\|finally\|if\|select\|unless\|while\)\|\s*\S*\s*=>$\)'
    let chg = &sw
  " local methods indent the shift-width, plus 6 for the 'local'
  elseif prevline =~? '^\s*local'
    let chg = &sw + 6
  " If previous line was a let with no closing semicolon, indent
  elseif prevline =~? '^\s*let.*[^;]\s*$'
    let chg = &sw
  " If previous line opened a parenthesis, and did not close it, indent
  elseif prevline =~ '^.*(\s*[^)]*\((.*)\)*[^)]*$'
    return = match( prevline, '(.*\((.*)\|[^)]\)*.*$') + 1
  "elseif prevline =~ '^.*(\s*[^)]*\((.*)\)*[^)]*$'
  elseif prevline =~ '^[^(]*)\s*$'
    " This line closes a parenthesis.  Find opening
    let curr_line = prevnonblank(lnum - 1)
    while curr_line >= 0
      let str = getline(curr_line)
      if str !~ '^.*(\s*[^)]*\((.*)\)*[^)]*$'
	let curr_line = prevnonblank(curr_line - 1)
      else
	break
      endif
    endwhile
    if curr_line < 0
      return -1
    endif
    let ind = indent(curr_line)
    " Although we found the closing parenthesis, make sure this
    " line doesn't start with an indentable command:
    let curr_str = getline(curr_line)
    if curr_str =~? '^\s*\(begin\|block\|case\|define\|else\|elseif\|for\|finally\|if\|select\|unless\|while\)'
      let chg = &sw
    endif
  endif

  " If a line starts with end, un-indent (even if we just indented!)
  if cline =~? '^\s*\(cleanup\|end\|else\|elseif\|exception\|finally\|otherwise\)'
    let chg = chg - &sw
  endif

  return ind + chg
endfunction

" vim:sw=2 tw=130
