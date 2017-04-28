" MetaPost indent file
" Language:           MetaPost
" Maintainer:         Nicola Vitacolonna <nvitacolonna@gmail.com>
" Former Maintainers: Eugene Minkovskii <emin@mccme.ru>
" Last Change:        2016 Oct 01
" Version: 0.2

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetMetaPostIndent()
setlocal indentkeys+==end,=else,=fi,=fill,0),0]

let b:undo_indent = "setl indentkeys< indentexpr<"

" Only define the function once.
if exists("*GetMetaPostIndent")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

function GetMetaPostIndent()
  let ignorecase_save = &ignorecase
  try
    let &ignorecase = 0
    return GetMetaPostIndentIntern()
  finally
    let &ignorecase = ignorecase_save
  endtry
endfunc

" Regexps {{{
" Note: the next three variables are made global so that a user may add
" further keywords.
"
" Example:
"
"    Put these in ~/.vim/after/indent/mp.vim
"
"    let g:mp_open_tag .= '\|\<begintest\>'
"    let g:mp_close_tag .= '\|\<endtest\>'

" Expressions starting indented blocks
let g:mp_open_tag = ''
      \ . '\<if\>'
      \ . '\|\<else\%[if]\>'
      \ . '\|\<for\%(\|ever\|suffixes\)\>'
      \ . '\|\<begingroup\>'
      \ . '\|\<\%(\|var\|primary\|secondary\|tertiary\)def\>'
      \ . '\|^\s*\<begin\%(fig\|graph\|glyph\|char\|logochar\)\>'
      \ . '\|[([{]'

" Expressions ending indented blocks
let g:mp_close_tag = ''
      \ . '\<fi\>'
      \ . '\|\<else\%[if]\>'
      \ . '\|\<end\%(\|for\|group\|def\|fig\|char\|logochar\|glyph\|graph\)\>'
      \ . '\|[)\]}]'

" Statements that may span multiple lines and are ended by a semicolon. To
" keep this list short, statements that are unlikely to be very long or are
" not very common (e.g., keywords like `interim` or `showtoken`) are not
" included.
"
" The regex for assignments and equations (the last branch) is tricky, because
" it must not match things like `for i :=`, `if a=b`, `def...=`, etc... It is
" not perfect, but it works reasonably well.
let g:mp_statement = ''
      \ . '\<\%(\|un\|cut\)draw\>'
      \ . '\|\<\%(\|un\)fill\%[draw]\>'
      \ . '\|\<draw\%(dbl\)\=arrow\>'
      \ . '\|\<clip\>'
      \ . '\|\<addto\>'
      \ . '\|\<save\>'
      \ . '\|\<setbounds\>'
      \ . '\|\<message\>'
      \ . '\|\<errmessage\>'
      \ . '\|\<errhelp\>'
      \ . '\|\<fontmapline\>'
      \ . '\|\<pickup\>'
      \ . '\|\<show\>'
      \ . '\|\<special\>'
      \ . '\|\<write\>'
      \ . '\|\%(^\|;\)\%([^;=]*\%('.g:mp_open_tag.'\)\)\@!.\{-}:\=='

" A line ends with zero or more spaces, possibly followed by a comment.
let s:eol = '\s*\%($\|%\)'
" }}}

" Auxiliary functions {{{
" Returns 1 if (0-based) position immediately preceding `pos` in `line` is
" inside a string or a comment; returns 0 otherwise.

" This is the function that is called more often when indenting, so it is
" critical that it is efficient. The method we use is significantly faster
" than using syntax attributes, and more general (it does not require
" syntax_items). It is also faster than using a single regex matching an even
" number of quotes. It helps that MetaPost strings cannot span more than one
" line and cannot contain escaped quotes.
function! s:CommentOrString(line, pos)
  let in_string = 0
  let q = stridx(a:line, '"')
  let c = stridx(a:line, '%')
  while q >= 0 && q < a:pos
    if c >= 0 && c < q
      if in_string " Find next percent symbol
        let c = stridx(a:line, '%', q + 1)
      else " Inside comment
        return 1
      endif
    endif
    let in_string = 1 - in_string
    let q = stridx(a:line, '"', q + 1) " Find next quote
  endwhile
  return in_string || (c >= 0 && c <= a:pos)
endfunction

" Find the first non-comment non-blank line before the current line. Skip also
" verbatimtex/btex... etex blocks.
function! s:PrevNonBlankNonComment(lnum)
  let l:lnum = prevnonblank(a:lnum - 1)
  while getline(l:lnum) =~# '^\s*%' ||
        \ synIDattr(synID(a:lnum, 1, 1), "name") =~# '^mpTeXinsert$\|^tex\|^Delimiter'
    let l:lnum = prevnonblank(l:lnum - 1)
  endwhile
  return l:lnum
endfunction

" Returns true if the last tag appearing in the line is an open tag; returns
" false otherwise.
function! s:LastTagIsOpen(line)
  let o = s:LastValidMatchEnd(a:line, g:mp_open_tag, 0)
  if o == - 1 | return v:false | endif
  return s:LastValidMatchEnd(a:line, g:mp_close_tag, o) < 0
endfunction

" A simple, efficient and quite effective heuristics is used to test whether
" a line should cause the next line to be indented: count the "opening tags"
" (if, for, def, ...) in the line, count the "closing tags" (endif, endfor,
" ...) in the line, and compute the difference. We call the result the
" "weight" of the line. If the weight is positive, then the next line should
" most likely be indented. Note that `else` and `elseif` are both opening and
" closing tags, so they "cancel out" in almost all cases, the only exception
" being a leading `else[if]`, which is counted as an opening tag, but not as
" a closing tag (so that, for instance, a line containing a single `else:`
" will have weight equal to one, not zero). We do not treat a trailing
" `else[if]` in any special way, because lines ending with an open tag are
" dealt with separately before this function is called (see
" GetMetaPostIndentIntern()).
"
" Example:
"
"     forsuffixes $=a,b: if x.$ = y.$ : draw else: fill fi
"       % This line will be indented because |{forsuffixes,if,else}| > |{else,fi}| (3 > 2)
"     endfor

function! s:Weight(line)
  let [o, i] = [0, s:ValidMatchEnd(a:line, g:mp_open_tag, 0)]
  while i > 0
    let o += 1
    let i = s:ValidMatchEnd(a:line, g:mp_open_tag, i)
  endwhile
  let [c, i] = [0, matchend(a:line, '^\s*\<else\%[if]\>')] " Skip a leading else[if]
  let i = s:ValidMatchEnd(a:line, g:mp_close_tag, i)
  while i > 0
    let c += 1
    let i = s:ValidMatchEnd(a:line, g:mp_close_tag, i)
  endwhile
  return o - c
endfunction

" Similar to matchend(), but skips strings and comments.
" line: a String
function! s:ValidMatchEnd(line, pat, start)
  let i = matchend(a:line, a:pat, a:start)
  while i > 0 && s:CommentOrString(a:line, i)
    let i = matchend(a:line, a:pat, i)
  endwhile
  return i
endfunction

" Like s:ValidMatchEnd(), but returns the end position of the last (i.e.,
" rightmost) match.
function! s:LastValidMatchEnd(line, pat, start)
  let last_found = -1
  let i = matchend(a:line, a:pat, a:start)
  while i > 0
    if !s:CommentOrString(a:line, i)
      let last_found = i
    endif
    let i = matchend(a:line, a:pat, i)
  endwhile
  return last_found
endfunction

function! s:DecreaseIndentOnClosingTag(curr_indent)
  let cur_text = getline(v:lnum)
  if cur_text =~# '^\s*\%('.g:mp_close_tag.'\)'
    return max([a:curr_indent - shiftwidth(), 0])
  endif
  return a:curr_indent
endfunction
" }}}

" Main function {{{
"
" Note: Every rule of indentation in MetaPost is very subjective. We might get
" creative, but things get murky very soon (there are too many corner cases).
" So, we provide a means for the user to decide what to do when this script
" doesn't get it. We use a simple idea: use '%>', '%<' and '%=' to explicitly
" control indentation. The '<' and '>' symbols may be repeated many times
" (e.g., '%>>' will cause the next line to be indented twice).
"
" By using '%>...', '%<...' and '%=', the indentation the user wants is
" preserved by commands like gg=G, even if it does not follow the rules of
" this script.
"
" Example:
"
"    shiftwidth=4
"    def foo =
"        makepen(subpath(T-n,t) of r %>
"            shifted .5down %>
"                --subpath(t,T) of r shifted .5up -- cycle) %<<
"        withcolor black
"    enddef
"
" The default indentation of the previous example would be:
"
"    def foo =
"        makepen(subpath(T-n,t) of r
"        shifted .5down
"        --subpath(t,T) of r shifted .5up -- cycle)
"        withcolor black
"    enddef
"
" Personally, I prefer the latter, but anyway...
function! GetMetaPostIndentIntern()

  " This is the reference line relative to which the current line is indented
  " (but see below).
  let lnum = s:PrevNonBlankNonComment(v:lnum)

  " At the start of the file use zero indent.
  if lnum == 0
    return 0
  endif

  let prev_text = getline(lnum)

  " User-defined overrides take precedence over anything else.
  " See above for an example.
  let j = match(prev_text, '%[<>=]')
  if j > 0
    let i = strlen(matchstr(prev_text, '%>\+', j)) - 1
    if i > 0
      return indent(lnum) + i * shiftwidth()
    endif

    let i = strlen(matchstr(prev_text, '%<\+', j)) - 1
    if i > 0
      return max([indent(lnum) - i * shiftwidth(), 0])
    endif

    if match(prev_text, '%=', j)
      return indent(lnum)
    endif
  endif

  " If the reference line ends with an open tag, indent.
  "
  " Example:
  "
  " if c:
  "     0
  " else:
  "     1
  " fi if c2: % Note that this line has weight equal to zero.
  "     ...   % This line will be indented
  if s:LastTagIsOpen(prev_text)
    return s:DecreaseIndentOnClosingTag(indent(lnum) + shiftwidth())
  endif

  " Lines with a positive weight are unbalanced and should likely be indented.
  "
  " Example:
  "
  " def f = enddef for i = 1 upto 5: if x[i] > 0: 1 else: 2 fi
  "     ... % This line will be indented (because of the unterminated `for`)
  if s:Weight(prev_text) > 0
    return s:DecreaseIndentOnClosingTag(indent(lnum) + shiftwidth())
  endif

  " Unterminated statements cause indentation to kick in.
  "
  " Example:
  "
  " draw unitsquare
  "     withcolor black; % This line is indented because of `draw`.
  " x := a + b + c
  "     + d + e;         % This line is indented because of `:=`.
  "
  let i = s:LastValidMatchEnd(prev_text, g:mp_statement, 0)
  if i >= 0 " Does the line contain a statement?
    if s:ValidMatchEnd(prev_text, ';', i) < 0 " Is the statement unterminated?
      return indent(lnum) + shiftwidth()
    else
      return s:DecreaseIndentOnClosingTag(indent(lnum))
    endif
  endif

  " Deal with the special case of a statement spanning multiple lines. If the
  " current reference line L ends with a semicolon, search backwards for
  " another semicolon or a statement keyword. If the latter is found first,
  " its line is used as the reference line for indenting the current line
  " instead of L.
  "
  "  Example:
  "
  "  if cond:
  "    draw if a: z0 else: z1 fi
  "        shifted S
  "        scaled T;      % L
  "
  "    for i = 1 upto 3:  % <-- Current line: this gets the same indent as `draw ...`
  "
  " NOTE: we get here if and only if L does not contain a statement (among
  " those listed in g:mp_statement).
  if s:ValidMatchEnd(prev_text, ';'.s:eol, 0) >= 0 " L ends with a semicolon
    let stm_lnum = s:PrevNonBlankNonComment(lnum)
    while stm_lnum > 0
      let prev_text = getline(stm_lnum)
      let sc_pos = s:LastValidMatchEnd(prev_text, ';', 0)
      let stm_pos = s:ValidMatchEnd(prev_text, g:mp_statement, sc_pos)
      if stm_pos > sc_pos
        let lnum = stm_lnum
        break
      elseif sc_pos > stm_pos
        break
      endif
      let stm_lnum = s:PrevNonBlankNonComment(stm_lnum)
    endwhile
  endif

  return s:DecreaseIndentOnClosingTag(indent(lnum))
endfunction
" }}}

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2:fdm=marker
