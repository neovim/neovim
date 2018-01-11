" Vim indent file
" Language: PoV-Ray Scene Description Language
" Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" Last Change: 2017 Jun 13
" URI: http://trific.ath.cx/Ftp/vim/indent/pov.vim

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" Some preliminary settings.
setlocal nolisp " Make sure lisp indenting doesn't supersede us.

setlocal indentexpr=GetPoVRayIndent()
setlocal indentkeys+==else,=end,0]

" Only define the function once.
if exists("*GetPoVRayIndent")
  finish
endif

" Counts matches of a regexp <rexp> in line number <line>.
" Doesn't count matches inside strings and comments (as defined by current
" syntax).
function! s:MatchCount(line, rexp)
  let str = getline(a:line)
  let i = 0
  let n = 0
  while i >= 0
    let i = matchend(str, a:rexp, i)
    if i >= 0 && synIDattr(synID(a:line, i, 0), "name") !~? "string\|comment"
      let n = n + 1
    endif
  endwhile
  return n
endfunction

" The main function.  Returns indent amount.
function GetPoVRayIndent()
  " If we are inside a comment (may be nested in obscure ways), give up
  if synIDattr(synID(v:lnum, indent(v:lnum)+1, 0), "name") =~? "string\|comment"
    return -1
  endif

  " Search backwards for the frist non-empty, non-comment line.
  let plnum = prevnonblank(v:lnum - 1)
  let plind = indent(plnum)
  while plnum > 0 && synIDattr(synID(plnum, plind+1, 0), "name") =~? "comment"
    let plnum = prevnonblank(plnum - 1)
    let plind = indent(plnum)
  endwhile

  " Start indenting from zero
  if plnum == 0
    return 0
  endif

  " Analyse previous nonempty line.
  let chg = 0
  let chg = chg + s:MatchCount(plnum, '[[{(]')
  let chg = chg + s:MatchCount(plnum, '#\s*\%(if\|ifdef\|ifndef\|switch\|while\|macro\|else\)\>')
  let chg = chg - s:MatchCount(plnum, '#\s*end\>')
  let chg = chg - s:MatchCount(plnum, '[]})]')
  " Dirty hack for people writing #if and #else on the same line.
  let chg = chg - s:MatchCount(plnum, '#\s*\%(if\|ifdef\|ifndef\|switch\)\>.*#\s*else\>')
  " When chg > 0, then we opened groups and we should indent more, but when
  " chg < 0, we closed groups and this already affected the previous line,
  " so we should not dedent.  And when everything else fails, scream.
  let chg = chg > 0 ? chg : 0

  " Analyse current line
  " FIXME: If we have to dedent, we should try to find the indentation of the
  " opening line.
  let cur = s:MatchCount(v:lnum, '^\s*\%(#\s*\%(end\|else\)\>\|[]})]\)')
  if cur > 0
    let final = plind + (chg - cur) * shiftwidth()
  else
    let final = plind + chg * shiftwidth()
  endif

  return final < 0 ? 0 : final
endfunction
