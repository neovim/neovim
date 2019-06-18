" Matlab indent file
" Language:	Matlab
" Maintainer:	Christophe Poucet <christophe.poucet@pandora.be>
" Last Change:	6 January, 2001

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" Some preliminary setting
setlocal indentkeys=!,o,O,=else,=elif,=end,=end_try_catch,=end_unwind_protect,=endclassdef,=endenumeration,=endevents,=endfor,=endfunction,=endif,=endmethods,=endparfor,=endproperties,=endswitch,=endwhile

setlocal indentexpr=GetMatlabIndent(v:lnum)

" Only define the function once.
if exists("*GetMatlabIndent")
  finish
endif

function GetMatlabIndent(lnum)
  " don't indent sections
  if getline(a:lnum) =~ '^\s*%% '
    return 0
  endif

  " Search backwards for the first non-empty line that's not a section
  let plnum = a:lnum - 1
  while plnum > 0 && getline(plnum) =~ '^\s*\($\|%% \)'
    let plnum = plnum - 1
  endwhile

  if plnum == 0
    " This is the first non-empty line, use zero indent.
    return 0
  endif

  let curind = indent(plnum)

  " incr indent if previous non-empty line opens a block
  if getline(plnum) =~ '^\s*\(function\|for\|if\|else\|elseif\|case\|while\|switch\|try\|otherwise\|catch\)\>'
    let curind = curind + shiftwidth()
  endif

  " decr indent if current line closes the block
  if getline(a:lnum) =~ '^\s*\(\|else\|elif\|end\|end_try_catch\|end_unwind_protect\|endclassdef\|endenumeration\|endevents\|endfor\|endfunction\|endif\|endmethods\|endparfor\|endproperties\|endswitch\|endwhile\)\>'
    let curind = curind - shiftwidth()
  endif

  return curind
endfunction

" vim:sw=2
