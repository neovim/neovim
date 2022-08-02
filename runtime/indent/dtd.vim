" Vim indent file
" Language:		DTD (Document Type Definition for XML)
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		24 Sep 2021

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetDTDIndent()
setlocal indentkeys=!^F,o,O,>
setlocal nosmartindent

let b:undo_indent = "setl inde< indk< si<"

if exists("*GetDTDIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" TODO: Needs to be adjusted to stop at [, <, and ].
let s:token_pattern = '^[^[:space:]]\+'

function s:lex1(input, start, ...)
  let pattern = a:0 > 0 ? a:1 : s:token_pattern
  let start = matchend(a:input, '^\_s*', a:start)
  if start == -1
    return ["", a:start]
  endif
  let end = matchend(a:input, pattern, start)
  if end == -1
    return ["", a:start]
  endif
  let token = strpart(a:input, start, end - start)
  return [token, end]
endfunction

function s:lex(input, start, ...)
  let pattern = a:0 > 0 ? a:1 : s:token_pattern
  let info = s:lex1(a:input, a:start, pattern)
  while info[0] == '--'
    let info = s:lex1(a:input, info[1], pattern)
    while info[0] != "" && info[0] != '--'
      let info = s:lex1(a:input, info[1], pattern)
    endwhile
    if info[0] == ""
      return info
    endif
    let info = s:lex1(a:input, info[1], pattern)
  endwhile
  return info
endfunction

function s:indent_to_innermost_parentheses(line, end)
  let token = '('
  let end = a:end
  let parentheses = [end - 1]
  while token != ""
    let [token, end] = s:lex(a:line, end, '^\%([(),|]\|[A-Za-z0-9_-]\+\|#P\=CDATA\|%[A-Za-z0-9_-]\+;\)[?*+]\=')
    if token[0] == '('
      call add(parentheses, end - 1)
    elseif token[0] == ')'
      if len(parentheses) == 1
        return [-1, end]
      endif
      call remove(parentheses, -1)
    endif
  endwhile
  return [parentheses[-1] - strridx(a:line, "\n", parentheses[-1]), end]
endfunction

" TODO: Line and end could be script global (think OO members).
function GetDTDIndent()
  if v:lnum == 1
    return 0
  endif
  
  " Begin by searching back for a <! that isn’t inside a comment.
  " From here, depending on what follows immediately after, parse to
  " where we’re at to determine what to do.
  if search('<!', 'bceW') == 0
    return indent(v:lnum - 1)
  endif
  let lnum = line('.')
  let col = col('.')
  let indent = indent('.')
  let line = lnum == v:lnum ? getline(lnum) : join(getline(lnum, v:lnum - 1), "\n")

  let [declaration, end] = s:lex1(line, col)
  if declaration == ""
    return indent + shiftwidth()
  elseif declaration == '--'
    " We’re looking at a comment.  Now, simply determine if the comment is
    " terminated or not.  If it isn’t, let Vim take care of that using
    " 'comments' and 'autoindent'. Otherwise, indent to the first lines level.
    while declaration != ""
      let [declaration, end] = s:lex(line, end)
      if declaration == "-->"
        return indent
      endif
    endwhile
    return -1
  elseif declaration == 'ELEMENT'
    " Check for element name.  If none exists, indent one level.
    let [name, end] = s:lex(line, end)
    if name == ""
      return indent + shiftwidth()
    endif

    " Check for token following element name.  This can be a specification of
    " whether the start or end tag may be omitted.  If nothing is found, indent
    " one level.
    let [token, end] = s:lex(line, end, '^\%([-O(]\|ANY\|EMPTY\)')
    let n = 0
    while token =~ '[-O]' && n < 2
      let [token, end] = s:lex(line, end, '^\%([-O(]\|ANY\|EMPTY\)')
      let n += 1
    endwhile
    if token == ""
      return indent + shiftwidth()
    endif

    " Next comes the content model.  If the token we’ve found isn’t a
    " parenthesis it must be either ANY, EMPTY or some random junk.  Either
    " way, we’re done indenting this element, so set it to that of the first
    " line so that the terminating “>” winds up having the same indentation.
    if token != '('
      return indent
    endif

    " Now go through the content model.  We need to keep track of the nesting
    " of parentheses.  As soon as we hit 0 we’re done.  If that happens we must
    " have a complete content model.  Thus set indentation to be the same as that
    " of the first line so that the terminating “>” winds up having the same
    " indentation.  Otherwise, we’ll indent to the innermost parentheses not yet
    " matched.
    let [indent_of_innermost, end] = s:indent_to_innermost_parentheses(line, end)
    if indent_of_innermost != -1
      return indent_of_innermost
    endif

    " Finally, look for any additions and/or exceptions to the content model.
    " This is defined by a “+” or “-” followed by another content model
    " declaration.
    " TODO: Can the “-” be separated by whitespace from the “(”?
    let seen = { '+(': 0, '-(': 0 }
    while 1
      let [additions_exceptions, end] = s:lex(line, end, '^[+-](')
      if additions_exceptions != '+(' && additions_exceptions != '-('
        let [token, end] = s:lex(line, end)
        if token == '>'
          return indent
        endif
        " TODO: Should use s:lex here on getline(v:lnum) and check for >.
        return getline(v:lnum) =~ '^\s*>' || count(values(seen), 0) == 0 ? indent : (indent + shiftwidth())
      endif

      " If we’ve seen an addition or exception already and this is of the same
      " kind, the user is writing a broken DTD.  Time to bail.
      if seen[additions_exceptions]
        return indent
      endif
      let seen[additions_exceptions] = 1

      let [indent_of_innermost, end] = s:indent_to_innermost_parentheses(line, end)
      if indent_of_innermost != -1
        return indent_of_innermost
      endif
    endwhile
  elseif declaration == 'ATTLIST'
    " Check for element name.  If none exists, indent one level.
    let [name, end] = s:lex(line, end)
    if name == ""
      return indent + shiftwidth()
    endif

    " Check for any number of attributes.
    while 1
      " Check for attribute name.  If none exists, indent one level, unless the
      " current line is a lone “>”, in which case we indent to the same level
      " as the first line.  Otherwise, if the attribute name is “>”, we have
      " actually hit the end of the attribute list, in which case we indent to
      " the same level as the first line.
      let [name, end] = s:lex(line, end)
      if name == ""
        " TODO: Should use s:lex here on getline(v:lnum) and check for >.
        return getline(v:lnum) =~ '^\s*>' ? indent : (indent + shiftwidth())
      elseif name == ">"
        return indent
      endif

      " Check for attribute value declaration.  If none exists, indent two
      " levels.  Otherwise, if it’s an enumerated value, check for nested
      " parentheses and indent to the innermost one if we don’t reach the end
      " of the listc.  Otherwise, just continue with looking for the default
      " attribute value.
      " TODO: Do validation of keywords
      " (CDATA|NMTOKEN|NMTOKENS|ID|IDREF|IDREFS|ENTITY|ENTITIES)?
      let [value, end] = s:lex(line, end, '^\%((\|[^[:space:]]\+\)')
      if value == ""
        return indent + shiftwidth() * 2
      elseif value == 'NOTATION'
        " If this is a enumerated value based on notations, read another token
        " for the actual value.  If it doesn’t exist, indent three levels.
        " TODO: If validating according to above, value must be equal to '('.
        let [value, end] = s:lex(line, end, '^\%((\|[^[:space:]]\+\)')
        if value == ""
          return indent + shiftwidth() * 3
        endif
      endif

      if value == '('
        let [indent_of_innermost, end] = s:indent_to_innermost_parentheses(line, end)
        if indent_of_innermost != -1
          return indent_of_innermost
        endif
      endif

      " Finally look for the attribute’s default value.  If non exists, indent
      " two levels.
      let [default, end] = s:lex(line, end, '^\%("\_[^"]*"\|#\(REQUIRED\|IMPLIED\|FIXED\)\)')
      if default == ""
        return indent + shiftwidth() * 2
      elseif default == '#FIXED'
        " We need to look for the fixed value.  If non exists, indent three
        " levels.
        let [default, end] = s:lex(line, end, '^"\_[^"]*"')
        if default == ""
          return indent + shiftwidth() * 3
        endif
      endif
    endwhile
  elseif declaration == 'ENTITY'
    " Check for entity name.  If none exists, indent one level.  Otherwise, if
    " the name actually turns out to be a percent sign, “%”, this is a
    " parameter entity.  Read another token to determine the entity name and,
    " again, if none exists, indent one level.
    let [name, end] = s:lex(line, end)
    if name == ""
      return indent + shiftwidth()
    elseif name == '%'
      let [name, end] = s:lex(line, end)
      if name == ""
        return indent + shiftwidth()
      endif
    endif

    " Now check for the entity value.  If none exists, indent one level.  If it
    " does exist, indent to same level as first line, as we’re now done with
    " this entity.
    "
    " The entity value can be a string in single or double quotes (no escapes
    " to worry about, as entities are used instead).  However, it can also be
    " that this is an external unparsed entity.  In that case we have to look
    " further for (possibly) a public ID and an URI followed by the NDATA
    " keyword and the actual notation name.  For the public ID and URI, indent
    " two levels, if they don’t exist.  If the NDATA keyword doesn’t exist,
    " indent one level.  Otherwise, if the actual notation name doesn’t exist,
    " indent two level.  If it does, indent to same level as first line, as
    " we’re now done with this entity.
    let [value, end] = s:lex(line, end)
    if value == ""
      return indent + shiftwidth()
    elseif value == 'SYSTEM' || value == 'PUBLIC'
      let [quoted_string, end] = s:lex(line, end, '\%("[^"]\+"\|''[^'']\+''\)')
      if quoted_string == ""
        return indent + shiftwidth() * 2
      endif

      if value == 'PUBLIC'
        let [quoted_string, end] = s:lex(line, end, '\%("[^"]\+"\|''[^'']\+''\)')
        if quoted_string == ""
          return indent + shiftwidth() * 2
        endif
      endif

      let [ndata, end] = s:lex(line, end)
      if ndata == ""
        return indent + shiftwidth()
      endif

      let [name, end] = s:lex(line, end)
      return name == "" ? (indent + shiftwidth() * 2) : indent
    else
      return indent
    endif
  elseif declaration == 'NOTATION'
    " Check for notation name.  If none exists, indent one level.
    let [name, end] = s:lex(line, end)
    if name == ""
      return indent + shiftwidth()
    endif

    " Now check for the external ID.  If none exists, indent one level.
    let [id, end] = s:lex(line, end)
    if id == ""
      return indent + shiftwidth()
    elseif id == 'SYSTEM' || id == 'PUBLIC'
      let [quoted_string, end] = s:lex(line, end, '\%("[^"]\+"\|''[^'']\+''\)')
      if quoted_string == ""
        return indent + shiftwidth() * 2
      endif

      if id == 'PUBLIC'
        let [quoted_string, end] = s:lex(line, end, '\%("[^"]\+"\|''[^'']\+''\|>\)')
        if quoted_string == ""
          " TODO: Should use s:lex here on getline(v:lnum) and check for >.
          return getline(v:lnum) =~ '^\s*>' ? indent : (indent + shiftwidth() * 2)
        elseif quoted_string == '>'
          return indent
        endif
      endif
    endif

    return indent
  endif

  " TODO: Processing directives could be indented I suppose.  But perhaps it’s
  " just as well to let the user decide how to indent them (perhaps extending
  " this function to include proper support for whatever processing directive
  " language they want to use).

  " Conditional sections are simply passed along to let Vim decide what to do
  " (and hence the user).
  return -1
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
