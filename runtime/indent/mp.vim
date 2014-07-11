" MetaPost indent file
" Language:	MetaPost
" Maintainer:	Eugene Minkovskii <emin@mccme.ru>
" Last Change:	2012 May 18
" Version: 0.1
" ==========================================================================

" Identation Rules: {{{1
" First of all, MetaPost language don't expect any identation rules.
" This screept need for you only if you (not MetaPost) need to do
" exactly code. If you don't need to use indentation, see
" :help filetype-indent-off
"
" Note: Every rules of identation in MetaPost or TeX languages (and in some
" other of course) is very subjective. I can release only my vision of this
" promlem.
"
" ..........................................................................
" Example of correct (by me) identation {{{2
" shiftwidth=4
" ==========================================================================
" for i=0 upto 99:
"     z[i] = (0,1u) rotated (i*360/100);
" endfor
" draw z0 -- z10 -- z20
"         withpen ...     % <- 2sw because breaked line
"         withcolor ...;  % <- same as previous
" draw z0 for i=1 upto 99:
"             -- z[i]             % <- 1sw from left end of 'for' satement
"         endfor withpen ...      % <- 0sw from left end of 'for' satement
"                 withcolor ...;  % <- 2sw because breaked line
" draw if One:     % <- This is internal if (like 'for' above)
"          one
"      elsif Other:
"          other
"      fi withpen ...;
" if one:          % <- This is external if
"     draw one;
" elseif other:
"     draw other;
" fi
" draw z0; draw z1;
" }}}
" }}}

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetMetaPostIndent()
setlocal indentkeys+=;,<:>,=if,=for,=def,=end,=else,=fi

" Only define the function once.
if exists("*GetMetaPostIndent")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

" Auxiliary Definitions: {{{1
function! MetaNextNonblankNoncomment(pos)
  " Like nextnonblank() but ignore comment lines
  let tmp = nextnonblank(a:pos)
  while tmp && getline(tmp) =~ '^\s*%'
    let tmp = nextnonblank(tmp+1)
  endwhile
  return tmp
endfunction

function! MetaPrevNonblankNoncomment(pos)
  " Like prevnonblank() but ignore comment lines
  let tmp = prevnonblank(a:pos)
  while tmp && getline(tmp) =~ '^\s*%'
    let tmp = prevnonblank(tmp-1)
  endwhile
  return tmp
endfunction

function! MetaSearchNoncomment(pattern, ...)
  " Like search() but ignore commented areas
  if a:0
    let flags = a:1
  elseif &wrapscan
    let flags = "w"
  else
    let flags = "W"
  endif
  let cl  = line(".")
  let cc  = col(".")
  let tmp = search(a:pattern, flags)
  while tmp && synIDattr(synID(line("."), col("."), 1), "name") =~
        \ 'm[fp]\(Comment\|TeXinsert\|String\)'
    let tmp = search(a:pattern, flags)
  endwhile
  if !tmp
    call cursor(cl,cc)
  endif
  return tmp
endfunction
" }}}

function! GetMetaPostIndent()
  " not indent in comment ???
  if synIDattr(synID(line("."), col("."), 1), "name") =~
        \ 'm[fp]\(Comment\|TeXinsert\|String\)'
    return -1
  endif
  " Some RegExps: {{{1
  " end_of_item: all of end by ';'
  "            + all of end by :endfor, :enddef, :endfig, :endgroup, :fi
  "            + all of start by :beginfig(num), :begingroup
  "            + all of start by :for, :if, :else, :elseif and end by ':'
  "            + all of start by :def, :vardef             and end by '='
  let end_of_item = '\('                              .
        \ ';\|'                                       .
        \ '\<\(end\(for\|def\|fig\|group\)\|fi\)\>\|' .
        \ '\<begin\(group\>\|fig\s*(\s*\d\+\s*)\)\|'  .
        \ '\<\(for\|if\|else\(if\)\=\)\>.\+:\|'       .
        \ '\<\(var\)\=def\>.\+='                      . '\)'
  " }}}
  " Save: current position {{{1
  let cl = line   (".")
  let cc = col    (".")
  let cs = getline(".")
  " if it is :beginfig or :endfig use zero indent
  if  cs =~ '^\s*\(begin\|end\)fig\>'
    return 0
  endif
  " }}}
  " Initialise: ind variable {{{1
  " search previous item not in current line
  let p_semicol_l = MetaSearchNoncomment(end_of_item,"bW")
  while p_semicol_l == cl
    let p_semicol_l = MetaSearchNoncomment(end_of_item,"bW")
  endwhile
  " if this is first item in program use zero indent
  if !p_semicol_l
    return 0
  endif
  " if this is multiline item, remember first indent
  if MetaNextNonblankNoncomment(p_semicol_l+1) < cl
    let ind = indent(MetaNextNonblankNoncomment(p_semicol_l+1))
  " else --- search pre-previous item for search first line in previous item
  else
    " search pre-previous item not in current line
    let pp_semicol_l = MetaSearchNoncomment(end_of_item,"bW")
    while pp_semicol_l == p_semicol_l
      let pp_semicol_l = MetaSearchNoncomment(end_of_item,"bW")
    endwhile
    " if we find pre-previous item, remember indent of previous item
    " else --- remember zero
    if pp_semicol_l
      let ind = indent(MetaNextNonblankNoncomment(line(".")+1))
    else
      let ind = 0
    endif
  endif
  " }}}
  " Increase Indent: {{{1
  " if it is an internal/external :for or :if statements {{{2
  let pnn_s = getline(MetaPrevNonblankNoncomment(cl-1))
  if  pnn_s =~ '\<\(for\|if\)\>.\+:\s*\($\|%\)'
    let ind = match(pnn_s, '\<\(for\|if\)\>.\+:\s*\($\|%\)') + &sw
  " }}}
  " if it is a :def, :vardef, :beginfig, :begingroup, :else, :elseif {{{2
  elseif pnn_s =~ '^\s*\('                       .
        \ '\(var\)\=def\|'                       .
        \ 'begin\(group\|fig\s*(\s*\d\+\s*)\)\|' .
        \ 'else\(if\)\='                         . '\)\>'
    let ind = ind + &sw
  " }}}
  " if it is a broken line {{{2
  elseif pnn_s !~ end_of_item.'\s*\($\|%\)'
    let ind = ind + (2 * &sw)
  endif
  " }}}
  " }}}
  " Decrease Indent: {{{1
  " if this is :endfor or :enddef statements {{{2
  " this is correct because :def cannot be inside :for
  if  cs  =~ '\<end\(for\|def\)\=\>'
    call MetaSearchNoncomment('\<for\>.\+:\s*\($\|%\)' . '\|' .
                            \ '^\s*\(var\)\=def\>',"bW")
    if col(".") > 1
      let ind = col(".") - 1
    else
      let ind = indent(".")
    endif
  " }}}
  " if this is :fi, :else, :elseif statements {{{2
  elseif cs =~ '\<\(else\(if\)\=\|fi\)\>'
    call MetaSearchNoncomment('\<if\>.\+:\s*\($\|%\)',"bW")
    let ind = col(".") - 1
  " }}}
  " if this is :endgroup statement {{{2
  elseif cs =~ '^\s*endgroup\>'
    let ind = ind - &sw
  endif
  " }}}
  " }}}

  return ind
endfunction
"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2:fdm=marker
