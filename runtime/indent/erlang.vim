" Vim indent file
" Language:     Erlang (http://www.erlang.org)
" Author:       Csaba Hoch <csaba.hoch@gmail.com>
" Contributors: Edwin Fine <efine145_nospam01 at usa dot net>
"               Pawel 'kTT' Salata <rockplayer.pl@gmail.com>
"               Ricardo Catalinas Jiménez <jimenezrick@gmail.com>
" Last Update:  2013-Jul-21
" License:      Vim license
" URL:          https://github.com/hcs42/vim-erlang

" Note About Usage:
"   This indentation script works best with the Erlang syntax file created by
"   Kreąimir Marľić (Kresimir Marzic) and maintained by Csaba Hoch.

" Notes About Implementation:
"
" - LTI = Line to indent.
" - The index of the first line is 1, but the index of the first column is 0.


" Initialization {{{1
" ==============

" Only load this indent file when no other was loaded
" Vim 7 or later is needed
if exists("b:did_indent") || version < 700
  finish
else
  let b:did_indent = 1
endif

setlocal indentexpr=ErlangIndent()
setlocal indentkeys+=0=end,0=of,0=catch,0=after,0=when,0=),0=],0=},0=>>

" Only define the functions once
if exists("*ErlangIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Logging library {{{1
" ===============

" Purpose:
"   Logs the given string using the ErlangIndentLog function if it exists.
" Parameters:
"   s: string
function! s:Log(s)
  if exists("*ErlangIndentLog")
    call ErlangIndentLog(a:s)
  endif
endfunction

" Line tokenizer library {{{1
" ======================

" Indtokens are "indentation tokens".

" Purpose:
"   Calculate the new virtual column after the given segment of a line.
" Parameters:
"   line: string
"   first_index: integer -- the index of the first character of the segment
"   last_index: integer -- the index of the last character of the segment
"   vcol: integer -- the virtual column of the first character of the token
"   tabstop: integer -- the value of the 'tabstop' option to be used
" Returns:
"   vcol: integer
" Example:
"   " index:    0 12 34567
"   " vcol:     0 45 89
"   s:CalcVCol("\t'\tx', b", 1, 4, 4)  -> 10
function! s:CalcVCol(line, first_index, last_index, vcol, tabstop)

  " We copy the relevent segment of the line, otherwise if the line were
  " e.g. `"\t", term` then the else branch below would consume the `", term`
  " part at once.
  let line = a:line[a:first_index : a:last_index]

  let i = 0
  let last_index = a:last_index - a:first_index
  let vcol = a:vcol

  while 0 <= i && i <= last_index

    if line[i] ==# "\t"
      " Example (when tabstop == 4):
      "
      " vcol + tab -> next_vcol
      " 0 + tab -> 4
      " 1 + tab -> 4
      " 2 + tab -> 4
      " 3 + tab -> 4
      " 4 + tab -> 8
      "
      " next_i - i == the number of tabs
      let next_i = matchend(line, '\t*', i + 1)
      let vcol = (vcol / a:tabstop + (next_i - i)) * a:tabstop
      call s:Log('new vcol after tab: '. vcol)
    else
      let next_i = matchend(line, '[^\t]*', i + 1)
      let vcol += next_i - i
      call s:Log('new vcol after other: '. vcol)
    endif
    let i = next_i
  endwhile

  return vcol
endfunction

" Purpose:
"   Go through the whole line and return the tokens in the line.
" Parameters:
"   line: string -- the line to be examined
"   string_continuation: bool
"   atom_continuation: bool
" Returns:
"   indtokens = [indtoken]
"   indtoken = [token, vcol, col]
"   token = string (examples: 'begin', '<variable>', '}')
"   vcol = integer (the virtual column of the first character of the token)
"   col = integer
function! s:GetTokensFromLine(line, string_continuation, atom_continuation,
                             \tabstop)

  let linelen = strlen(a:line) " The length of the line
  let i = 0 " The index of the current character in the line
  let vcol = 0 " The virtual column of the current character
  let indtokens = []

  if a:string_continuation
    let i = matchend(a:line, '^\%([^"\\]\|\\.\)*"', 0)
    if i ==# -1
      call s:Log('    Whole line is string continuation -> ignore')
      return []
    else
      let vcol = s:CalcVCol(a:line, 0, i - 1, 0, a:tabstop)
      call add(indtokens, ['<string_end>', vcol, i])
    endif
  elseif a:atom_continuation
    let i = matchend(a:line, "^\\%([^'\\\\]\\|\\\\.\\)*'", 0)
    if i ==# -1
      call s:Log('    Whole line is quoted atom continuation -> ignore')
      return []
    else
      let vcol = s:CalcVCol(a:line, 0, i - 1, 0, a:tabstop)
      call add(indtokens, ['<quoted_atom_end>', vcol, i])
    endif
  endif

  while 0 <= i && i < linelen

    let next_vcol = ''

    " Spaces
    if a:line[i] ==# ' '
      let next_i = matchend(a:line, ' *', i + 1)

    " Tabs
    elseif a:line[i] ==# "\t"
      let next_i = matchend(a:line, '\t*', i + 1)

      " See example in s:CalcVCol
      let next_vcol = (vcol / a:tabstop + (next_i - i)) * a:tabstop

    " Comment
    elseif a:line[i] ==# '%'
      let next_i = linelen

    " String token: "..."
    elseif a:line[i] ==# '"'
      let next_i = matchend(a:line, '\%([^"\\]\|\\.\)*"', i + 1)
      if next_i ==# -1
        call add(indtokens, ['<string_start>', vcol, i])
      else
        let next_vcol = s:CalcVCol(a:line, i, next_i - 1, vcol, a:tabstop)
        call add(indtokens, ['<string>', vcol, i])
      endif

    " Quoted atom token: '...'
    elseif a:line[i] ==# "'"
      let next_i = matchend(a:line, "\\%([^'\\\\]\\|\\\\.\\)*'", i + 1)
      if next_i ==# -1
        call add(indtokens, ['<quoted_atom_start>', vcol, i])
      else
        let next_vcol = s:CalcVCol(a:line, i, next_i - 1, vcol, a:tabstop)
        call add(indtokens, ['<quoted_atom>', vcol, i])
      endif

    " Keyword or atom or variable token or number
    elseif a:line[i] =~# '[a-zA-Z_@0-9]'
      let next_i = matchend(a:line,
                           \'[[:alnum:]_@:]*\%(\s*#\s*[[:alnum:]_@:]*\)\=',
                           \i + 1)
      call add(indtokens, [a:line[(i):(next_i - 1)], vcol, i])

    " Character token: $<char> (as in: $a)
    elseif a:line[i] ==# '$'
      call add(indtokens, ['$.', vcol, i])
      let next_i = i + 2

    " Dot token: .
    elseif a:line[i] ==# '.'

      let next_i = i + 1

      if i + 1 ==# linelen || a:line[i + 1] =~# '[[:blank:]%]'
        " End of clause token: . (as in: f() -> ok.)
        call add(indtokens, ['<end_of_clause>', vcol, i])

      else
        " Possibilities:
        " - Dot token in float: . (as in: 3.14)
        " - Dot token in record: . (as in: #myrec.myfield)
        call add(indtokens, ['.', vcol, i])
      endif

    " Equal sign
    elseif a:line[i] ==# '='
      " This is handled separately so that "=<<" will be parsed as
      " ['=', '<<'] instead of ['=<', '<']. Although Erlang parses it
      " currently in the latter way, that may be fixed some day.
      call add(indtokens, [a:line[i], vcol, i])
      let next_i = i + 1

    " Three-character tokens
    elseif i + 1 < linelen &&
         \ index(['=:=', '=/='], a:line[i : i + 1]) != -1
      call add(indtokens, [a:line[i : i + 1], vcol, i])
      let next_i = i + 2

    " Two-character tokens
    elseif i + 1 < linelen &&
         \ index(['->', '<<', '>>', '||', '==', '/=', '=<', '>=', '++', '--',
         \        '::'],
         \       a:line[i : i + 1]) != -1
      call add(indtokens, [a:line[i : i + 1], vcol, i])
      let next_i = i + 2

    " Other character: , ; < > ( ) [ ] { } # + - * / : ? = ! |
    else
      call add(indtokens, [a:line[i], vcol, i])
      let next_i = i + 1

    endif

    if next_vcol ==# ''
      let vcol += next_i - i
    else
      let vcol = next_vcol
    endif

    let i = next_i

  endwhile

  return indtokens

endfunction

" TODO: doc, handle "not found" case
function! s:GetIndtokenAtCol(indtokens, col)
  let i = 0
  while i < len(a:indtokens)
    if a:indtokens[i][2] ==# a:col
      return [1, i]
    elseif a:indtokens[i][2] > a:col
      return [0, s:IndentError('No token at col ' . a:col . ', ' .
                              \'indtokens = ' . string(a:indtokens),
                              \'', '')]
    endif
    let i += 1
  endwhile
  return [0, s:IndentError('No token at col ' . a:col . ', ' .
                           \'indtokens = ' . string(a:indtokens),
                           \'', '')]
endfunction

" Stack library {{{1
" =============

" Purpose:
"   Push a token onto the parser's stack.
" Parameters:
"   stack: [token]
"   token: string
function! s:Push(stack, token)
  call s:Log('    Stack Push: "' . a:token . '" into ' . string(a:stack))
  call insert(a:stack, a:token)
endfunction

" Purpose:
"   Pop a token from the parser's stack.
" Parameters:
"   stack: [token]
"   token: string
" Returns:
"   token: string -- the removed element
function! s:Pop(stack)
  let head = remove(a:stack, 0)
  call s:Log('    Stack Pop: "' . head . '" from ' . string(a:stack))
  return head
endfunction

" Library for accessing and storing tokenized lines {{{1
" =================================================

" The Erlang token cache: an `lnum -> indtokens` dictionary that stores the
" tokenized lines.
let s:all_tokens = {}
let s:file_name = ''
let s:last_changedtick = -1

" Purpose:
"   Clear the Erlang token cache if we have a different file or the file has
"   been changed since the last indentation.
function! s:ClearTokenCacheIfNeeded()
  let file_name = expand('%:p')
  if file_name != s:file_name ||
   \ b:changedtick != s:last_changedtick
    let s:file_name = file_name
    let s:last_changedtick = b:changedtick
    let s:all_tokens = {}
  endif
endfunction

" Purpose:
"   Return the tokens of line `lnum`, if that line is not empty. If it is
"   empty, find the first non-empty line in the given `direction` and return
"   the tokens of that line.
" Parameters:
"   lnum: integer
"   direction: 'up' | 'down'
" Returns:
"   result: [] -- the result is an empty list if we hit the beginning or end
"                  of the file
"           | [lnum, indtokens]
"   lnum: integer -- the index of the non-empty line that was found and
"                    tokenized
"   indtokens: [indtoken] -- the tokens of line `lnum`
function! s:TokenizeLine(lnum, direction)

  call s:Log('Tokenizing starts from line ' . a:lnum)
  if a:direction ==# 'up'
    let lnum = prevnonblank(a:lnum)
  else " a:direction ==# 'down'
    let lnum = nextnonblank(a:lnum)
  endif

  " We hit the beginning or end of the file
  if lnum ==# 0
    let indtokens = []
    call s:Log('  We hit the beginning or end of the file.')

    " The line has already been parsed
  elseif has_key(s:all_tokens, lnum)
    let indtokens = s:all_tokens[lnum]
    call s:Log('Cached line ' . lnum . ': ' . getline(lnum))
    call s:Log("  Tokens in the line:\n    - " . join(indtokens, "\n    - "))

    " The line should be parsed now
  else

    " Parse the line
    let line = getline(lnum)
    let string_continuation = s:IsLineStringContinuation(lnum)
    let atom_continuation = s:IsLineAtomContinuation(lnum)
    let indtokens = s:GetTokensFromLine(line, string_continuation,
                                       \atom_continuation, &tabstop)
    let s:all_tokens[lnum] = indtokens
    call s:Log('Tokenizing line ' . lnum . ': ' . line)
    call s:Log("  Tokens in the line:\n    - " . join(indtokens, "\n    - "))

  endif

  return [lnum, indtokens]
endfunction

" Purpose:
"   As a helper function for PrevIndToken and NextIndToken, the FindIndToken
"   function finds the first line with at least one token in the given
"   direction.
" Parameters:
"   lnum: integer
"   direction: 'up' | 'down'
" Returns:
"   result: [] -- the result is an empty list if we hit the beginning or end
"                  of the file
"           | indtoken
function! s:FindIndToken(lnum, dir)
  let lnum = a:lnum
  while 1
    let lnum += (a:dir ==# 'up' ? -1 : 1)
    let [lnum, indtokens] = s:TokenizeLine(lnum, a:dir)
    if lnum ==# 0
      " We hit the beginning or end of the file
      return []
    elseif !empty(indtokens)
      return indtokens[a:dir ==# 'up' ? -1 : 0]
    endif
  endwhile
endfunction

" Purpose:
"   Find the token that directly precedes the given token.
" Parameters:
"   lnum: integer -- the line of the given token
"   i: the index of the given token within line `lnum`
" Returns:
"   result = [] -- the result is an empty list if the given token is the first
"                  token of the file
"          | indtoken
function! s:PrevIndToken(lnum, i)
  call s:Log('    PrevIndToken called: lnum=' . a:lnum . ', i =' . a:i)

  " If the current line has a previous token, return that
  if a:i > 0
    return s:all_tokens[a:lnum][a:i - 1]
  else
    return s:FindIndToken(a:lnum, 'up')
  endif
endfunction

" Purpose:
"   Find the token that directly succeeds the given token.
" Parameters:
"   lnum: integer -- the line of the given token
"   i: the index of the given token within line `lnum`
" Returns:
"   result = [] -- the result is an empty list if the given token is the last
"                  token of the file
"          | indtoken
function! s:NextIndToken(lnum, i)
  call s:Log('    NextIndToken called: lnum=' . a:lnum . ', i =' . a:i)

  " If the current line has a next token, return that
  if len(s:all_tokens[a:lnum]) > a:i + 1
    return s:all_tokens[a:lnum][a:i + 1]
  else
    return s:FindIndToken(a:lnum, 'down')
  endif
endfunction

" ErlangCalcIndent helper functions {{{1
" =================================

" Purpose:
"   This function is called when the parser encounters a syntax error.
"
"   If we encounter a syntax error, we return
"   g:erlang_unexpected_token_indent, which is -1 by default. This means that
"   the indentation of the LTI will not be changed.
" Parameter:
"   msg: string
"   token: string
"   stack: [token]
" Returns:
"   indent: integer
function! s:IndentError(msg, token, stack)
  call s:Log('Indent error: ' . a:msg . ' -> return')
  call s:Log('  Token = ' . a:token . ', ' .
            \'  stack = ' . string(a:stack))
  return g:erlang_unexpected_token_indent
endfunction

" Purpose:
"   This function is called when the parser encounters an unexpected token,
"   and the parser will return the number given back by UnexpectedToken.
"
"   If we encounter an unexpected token, we return
"   g:erlang_unexpected_token_indent, which is -1 by default. This means that
"   the indentation of the LTI will not be changed.
" Parameter:
"   token: string
"   stack: [token]
" Returns:
"   indent: integer
function! s:UnexpectedToken(token, stack)
  call s:Log('    Unexpected token ' . a:token . ', stack = ' .
            \string(a:stack) . ' -> return')
  return g:erlang_unexpected_token_indent
endfunction

if !exists('g:erlang_unexpected_token_indent')
  let g:erlang_unexpected_token_indent = -1
endif

" Purpose:
"   Return whether the given line starts with a string continuation.
" Parameter:
"   lnum: integer
" Returns:
"   result: bool
" Example:
"   f() ->           % IsLineStringContinuation = false
"       "This is a   % IsLineStringContinuation = false
"       multiline    % IsLineStringContinuation = true
"       string".     % IsLineStringContinuation = true
function! s:IsLineStringContinuation(lnum)
  if has('syntax_items')
    return synIDattr(synID(a:lnum, 1, 0), 'name') =~# '^erlangString'
  else
    return 0
  endif
endfunction

" Purpose:
"   Return whether the given line starts with an atom continuation.
" Parameter:
"   lnum: integer
" Returns:
"   result: bool
" Example:
"   'function with   % IsLineAtomContinuation = true, but should be false
"   weird name'() -> % IsLineAtomContinuation = true
"       ok.          % IsLineAtomContinuation = false
function! s:IsLineAtomContinuation(lnum)
  if has('syntax_items')
    return synIDattr(synID(a:lnum, 1, 0), 'name') =~# '^erlangQuotedAtom'
  else
    return 0
  endif
endfunction

" Purpose:
"   Return whether the 'catch' token (which should be the `i`th token in line
"   `lnum`) is standalone or part of a try-catch block, based on the preceding
"   token.
" Parameters:
"   lnum: integer
"   i: integer
" Return:
"   is_standalone: bool
function! s:IsCatchStandalone(lnum, i)
  call s:Log('    IsCatchStandalone called: lnum=' . a:lnum . ', i=' . a:i)
  let prev_indtoken = s:PrevIndToken(a:lnum, a:i)

  " If we hit the beginning of the file, it is not a catch in a try block
  if prev_indtoken == []
    return 1
  endif

  let prev_token = prev_indtoken[0]

  if prev_token =~# '[A-Z_@0-9]'
    let is_standalone = 0
  elseif prev_token =~# '[a-z]'
    if index(['after', 'and', 'andalso', 'band', 'begin', 'bnot', 'bor', 'bsl',
            \ 'bsr', 'bxor', 'case', 'catch', 'div', 'not', 'or', 'orelse',
            \ 'rem', 'try', 'xor'], prev_token) != -1
      " If catch is after these keywords, it is standalone
      let is_standalone = 1
    else
      " If catch is after another keyword (e.g. 'end') or an atom, it is
      " part of try-catch.
      "
      " Keywords:
      " - may precede 'catch': end
      " - may not precede 'catch': fun if of receive when
      " - unused: cond let query
      let is_standalone = 0
    endif
  elseif index([')', ']', '}', '<string>', '<string_end>', '<quoted_atom>',
              \ '<quoted_atom_end>', '$.'], prev_token) != -1
    let is_standalone = 0
  else
    " This 'else' branch includes the following tokens:
    "   -> == /= =< < >= > =:= =/= + - * / ++ -- :: < > ; ( [ { ? = ! . |
    let is_standalone = 1
  endif

  call s:Log('   "catch" preceded by "' . prev_token  . '" -> catch ' .
            \(is_standalone ? 'is standalone' : 'belongs to try-catch'))
  return is_standalone

endfunction

" Purpose:
"   This function is called when a begin-type element ('begin', 'case',
"   '[', '<<', etc.) is found. It asks the caller to return if the stack
" Parameters:
"   stack: [token]
"   token: string
"   curr_vcol: integer
"   stored_vcol: integer
"   sw: integer -- number of spaces to be used after the begin element as
"                  indentation
" Returns:
"   result: [should_return, indent]
"   should_return: bool -- if true, the caller should return `indent` to Vim
"   indent -- integer
function! s:BeginElementFoundIfEmpty(stack, token, curr_vcol, stored_vcol, sw)
  if empty(a:stack)
    if a:stored_vcol ==# -1
      call s:Log('    "' . a:token . '" directly preceeds LTI -> return')
      return [1, a:curr_vcol + a:sw]
    else
      call s:Log('    "' . a:token .
                \'" token (whose expression includes LTI) found -> return')
      return [1, a:stored_vcol]
    endif
  else
    return [0, 0]
  endif
endfunction

" Purpose:
"   This function is called when a begin-type element ('begin', 'case', '[',
"   '<<', etc.) is found, and in some cases when 'after' and 'when' is found.
"   It asks the caller to return if the stack is already empty.
" Parameters:
"   stack: [token]
"   token: string
"   curr_vcol: integer
"   stored_vcol: integer
"   end_token: end token that belongs to the begin element found (e.g. if the
"              begin element is 'begin', the end token is 'end')
"   sw: integer -- number of spaces to be used after the begin element as
"                  indentation
" Returns:
"   result: [should_return, indent]
"   should_return: bool -- if true, the caller should return `indent` to Vim
"   indent -- integer
function! s:BeginElementFound(stack, token, curr_vcol, stored_vcol, end_token, sw)

  " Return 'return' if the stack is empty
  let [ret, res] = s:BeginElementFoundIfEmpty(a:stack, a:token, a:curr_vcol,
                                             \a:stored_vcol, a:sw)
  if ret | return [ret, res] | endif

  if a:stack[0] ==# a:end_token
    call s:Log('    "' . a:token . '" pops "' . a:end_token . '"')
    call s:Pop(a:stack)
    if !empty(a:stack) && a:stack[0] ==# 'align_to_begin_element'
      call s:Pop(a:stack)
      if empty(a:stack)
        return [1, a:curr_vcol]
      else
        return [1, s:UnexpectedToken(a:token, a:stack)]
      endif
    else
      return [0, 0]
    endif
  else
    return [1, s:UnexpectedToken(a:token, a:stack)]
  endif
endfunction

" Purpose:
"   This function is called when we hit the beginning of a file or an
"   end-of-clause token -- i.e. when we found the beginning of the current
"   clause.
"
"   If the stack contains an '->' or 'when', this means that we can return
"   now, since we were looking for the beginning of the clause.
" Parameters:
"   stack: [token]
"   token: string
"   stored_vcol: integer
" Returns:
"   result: [should_return, indent]
"   should_return: bool -- if true, the caller should return `indent` to Vim
"   indent -- integer
function! s:BeginningOfClauseFound(stack, token, stored_vcol)
  if !empty(a:stack) && a:stack[0] ==# 'when'
    call s:Log('    BeginningOfClauseFound: "when" found in stack')
    call s:Pop(a:stack)
    if empty(a:stack)
      call s:Log('    Stack is ["when"], so LTI is in a guard -> return')
      return [1, a:stored_vcol + shiftwidth() + 2]
    else
      return [1, s:UnexpectedToken(a:token, a:stack)]
    endif
  elseif !empty(a:stack) && a:stack[0] ==# '->'
    call s:Log('    BeginningOfClauseFound: "->" found in stack')
    call s:Pop(a:stack)
    if empty(a:stack)
      call s:Log('    Stack is ["->"], so LTI is in function body -> return')
      return [1, a:stored_vcol + shiftwidth()]
    elseif a:stack[0] ==# ';'
      call s:Pop(a:stack)
      if empty(a:stack)
        call s:Log('    Stack is ["->", ";"], so LTI is in a function head ' .
                  \'-> return')
        return [0, a:stored_vcol]
      else
        return [1, s:UnexpectedToken(a:token, a:stack)]
      endif
    else
      return [1, s:UnexpectedToken(a:token, a:stack)]
    endif
  else
    return [0, 0]
  endif
endfunction

let g:erlang_indent_searchpair_timeout = 2000

" TODO
function! s:SearchPair(lnum, curr_col, start, middle, end)
  call cursor(a:lnum, a:curr_col + 1)
  let [lnum_new, col1_new] = 
      \searchpairpos(a:start, a:middle, a:end, 'bW',
                    \'synIDattr(synID(line("."), col("."), 0), "name") ' .
                    \'=~? "string\\|quotedatom\\|todo\\|comment\\|' . 
                    \'erlangmodifier"',
                    \0, g:erlang_indent_searchpair_timeout)
  return [lnum_new, col1_new - 1]
endfunction

function! s:SearchEndPair(lnum, curr_col)
  return s:SearchPair(
         \ a:lnum, a:curr_col,
         \ '\C\<\%(case\|try\|begin\|receive\|if\)\>\|' .
         \ '\<fun\>\%(\s\|\n\|%.*$\)*(',
         \ '',
         \ '\<end\>')
endfunction

" ErlangCalcIndent {{{1
" ================

" Purpose:
"   Calculate the indentation of the given line.
" Parameters:
"   lnum: integer -- index of the line for which the indentation should be
"                    calculated
"   stack: [token] -- initial stack
" Return:
"   indent: integer -- if -1, that means "don't change the indentation";
"                      otherwise it means "indent the line with `indent`
"                      number of spaces or equivalent tabs"
function! s:ErlangCalcIndent(lnum, stack)
  let res = s:ErlangCalcIndent2(a:lnum, a:stack)
  call s:Log("ErlangCalcIndent returned: " . res)
  return res
endfunction

function! s:ErlangCalcIndent2(lnum, stack)

  let lnum = a:lnum
  let stored_vcol = -1 " Virtual column of the first character of the token that
                   " we currently think we might align to.
  let mode = 'normal'
  let stack = a:stack
  let semicolon_abscol = ''

  " Walk through the lines of the buffer backwards (starting from the
  " previous line) until we can decide how to indent the current line.
  while 1

    let [lnum, indtokens] = s:TokenizeLine(lnum, 'up')

    " Hit the start of the file
    if lnum ==# 0
      let [ret, res] = s:BeginningOfClauseFound(stack, 'beginning_of_file',
                                               \stored_vcol)
      if ret | return res | endif

      return 0
    endif

    let i = len(indtokens) - 1
    let last_token_of_line = 1

    while i >= 0

      let [token, curr_vcol, curr_col] = indtokens[i]
      call s:Log('  Analyzing the following token: ' . string(indtokens[i]))

      if len(stack) > 256 " TODO: magic number
        return s:IndentError('Stack too long', token, stack)
      endif

      if token ==# '<end_of_clause>'
        let [ret, res] = s:BeginningOfClauseFound(stack, token, stored_vcol)
        if ret | return res | endif

        if stored_vcol ==# -1
          call s:Log('    End of clause directly preceeds LTI -> return')
          return 0
        else
          call s:Log('    End of clause (but not end of line) -> return')
          return stored_vcol
        endif

      elseif stack == ['prev_term_plus']
        if token =~# '[a-zA-Z_@]' ||
         \ token ==# '<string>' || token ==# '<string_start>' ||
         \ token ==# '<quoted_atom>' || token ==# '<quoted_atom_start>'
          call s:Log('    previous token found: curr_vcol + plus = ' .
                    \curr_vcol . " + " . plus)
          return curr_vcol + plus
        endif

      elseif token ==# 'begin'
        let [ret, res] = s:BeginElementFound(stack, token, curr_vcol,
                                            \stored_vcol, 'end', shiftwidth())
        if ret | return res | endif

      " case EXPR of BRANCHES end
      " try EXPR catch BRANCHES end
      " try EXPR after BODY end
      " try EXPR catch BRANCHES after BODY end
      " try EXPR of BRANCHES catch BRANCHES end
      " try EXPR of BRANCHES after BODY end
      " try EXPR of BRANCHES catch BRANCHES after BODY end
      " receive BRANCHES end
      " receive BRANCHES after BRANCHES end

      " This branch is not Emacs-compatible
      elseif (index(['of', 'receive', 'after', 'if'], token) != -1 ||
           \  (token ==# 'catch' && !s:IsCatchStandalone(lnum, i))) &&
           \ !last_token_of_line &&
           \ (empty(stack) || stack ==# ['when'] || stack ==# ['->'] ||
           \  stack ==# ['->', ';'])

        " If we are after of/receive, but these are not the last
        " tokens of the line, we want to indent like this:
        "
        "   % stack == []
        "   receive stored_vcol,
        "           LTI
        "
        "   % stack == ['->', ';']
        "   receive stored_vcol ->
        "               B;
        "           LTI
        "
        "   % stack == ['->']
        "   receive stored_vcol ->
        "               LTI
        "
        "   % stack == ['when']
        "   receive stored_vcol when
        "               LTI

        " stack = []  =>  LTI is a condition
        " stack = ['->']  =>  LTI is a branch
        " stack = ['->', ';']  =>  LTI is a condition
        " stack = ['when']  =>  LTI is a guard
        if empty(stack) || stack == ['->', ';']
          call s:Log('    LTI is in a condition after ' .
                    \'"of/receive/after/if/catch" -> return')
          return stored_vcol
        elseif stack == ['->']
          call s:Log('    LTI is in a branch after ' .
                    \'"of/receive/after/if/catch" -> return')
          return stored_vcol + shiftwidth()
        elseif stack == ['when']
          call s:Log('    LTI is in a guard after ' .
                    \'"of/receive/after/if/catch" -> return')
          return stored_vcol + shiftwidth()
        else
          return s:UnexpectedToken(token, stack)
        endif

      elseif index(['case', 'if', 'try', 'receive'], token) != -1

        " stack = []  =>  LTI is a condition
        " stack = ['->']  =>  LTI is a branch
        " stack = ['->', ';']  =>  LTI is a condition
        " stack = ['when']  =>  LTI is in a guard
        if empty(stack)
          " pass
        elseif (token ==# 'case' && stack[0] ==# 'of') ||
             \ (token ==# 'if') ||
             \ (token ==# 'try' && (stack[0] ==# 'of' ||
             \                     stack[0] ==# 'catch' ||
             \                     stack[0] ==# 'after')) ||
             \ (token ==# 'receive')

          " From the indentation point of view, the keyword
          " (of/catch/after/end) before the LTI is what counts, so
          " when we reached these tokens, and the stack already had
          " a catch/after/end, we didn't modify it.
          "
          " This way when we reach case/try/receive (i.e. now),
          " there is at most one of/catch/after/end token in the
          " stack.
          if token ==# 'case' || token ==# 'try' ||
           \ (token ==# 'receive' && stack[0] ==# 'after')
            call s:Pop(stack)
          endif

          if empty(stack)
            call s:Log('    LTI is in a condition; matching ' .
                      \'"case/if/try/receive" found')
            let stored_vcol = curr_vcol + shiftwidth()
          elseif stack[0] ==# 'align_to_begin_element'
            call s:Pop(stack)
            let stored_vcol = curr_vcol
          elseif len(stack) > 1 && stack[0] ==# '->' && stack[1] ==# ';'
            call s:Log('    LTI is in a condition; matching ' .
                      \'"case/if/try/receive" found')
            call s:Pop(stack)
            call s:Pop(stack)
            let stored_vcol = curr_vcol + shiftwidth()
          elseif stack[0] ==# '->'
            call s:Log('    LTI is in a branch; matching ' .
                      \'"case/if/try/receive" found')
            call s:Pop(stack)
            let stored_vcol = curr_vcol + 2 * shiftwidth()
          elseif stack[0] ==# 'when'
            call s:Log('    LTI is in a guard; matching ' .
                      \'"case/if/try/receive" found')
            call s:Pop(stack)
            let stored_vcol = curr_vcol + 2 * shiftwidth() + 2
          endif

        endif

        let [ret, res] = s:BeginElementFound(stack, token, curr_vcol,
                                            \stored_vcol, 'end', shiftwidth())
        if ret | return res | endif

      elseif token ==# 'fun'
        let next_indtoken = s:NextIndToken(lnum, i)
        call s:Log('    Next indtoken = ' . string(next_indtoken))

        if !empty(next_indtoken) && next_indtoken[0] ==# '('
          " We have an anonymous function definition
          " (e.g. "fun () -> ok end")

          " stack = []  =>  LTI is a condition
          " stack = ['->']  =>  LTI is a branch
          " stack = ['->', ';']  =>  LTI is a condition
          " stack = ['when']  =>  LTI is in a guard
          if empty(stack)
            call s:Log('    LTI is in a condition; matching "fun" found')
            let stored_vcol = curr_vcol + shiftwidth()
          elseif len(stack) > 1 && stack[0] ==# '->' && stack[1] ==# ';'
            call s:Log('    LTI is in a condition; matching "fun" found')
            call s:Pop(stack)
            call s:Pop(stack)
          elseif stack[0] ==# '->'
            call s:Log('    LTI is in a branch; matching "fun" found')
            call s:Pop(stack)
            let stored_vcol = curr_vcol + 2 * shiftwidth()
          elseif stack[0] ==# 'when'
            call s:Log('    LTI is in a guard; matching "fun" found')
            call s:Pop(stack)
            let stored_vcol = curr_vcol + 2 * shiftwidth() + 2
          endif

          let [ret, res] = s:BeginElementFound(stack, token, curr_vcol,
                                              \stored_vcol, 'end', shiftwidth())
          if ret | return res | endif
        else
          " Pass: we have a function reference (e.g. "fun f/0")
        endif

      elseif token ==# '['
        " Emacs compatibility
        let [ret, res] = s:BeginElementFound(stack, token, curr_vcol,
                                            \stored_vcol, ']', 1)
        if ret | return res | endif

      elseif token ==# '<<'
        " Emacs compatibility
        let [ret, res] = s:BeginElementFound(stack, token, curr_vcol,
                                            \stored_vcol, '>>', 2)
        if ret | return res | endif

      elseif token ==# '(' || token ==# '{'

        let end_token = (token ==# '(' ? ')' :
                        \token ==# '{' ? '}' : 'error')

        if empty(stack)
          " We found the opening paren whose block contains the LTI.
          let mode = 'inside'
        elseif stack[0] ==# end_token
          call s:Log('    "' . token . '" pops "' . end_token . '"')
          call s:Pop(stack)

          if !empty(stack) && stack[0] ==# 'align_to_begin_element'
            " We found the opening paren whose closing paren
            " starts LTI
            let mode = 'align_to_begin_element'
          else
            " We found the opening pair for a closing paren that
            " was already in the stack.
            let mode = 'outside'
          endif
        else
          return s:UnexpectedToken(token, stack)
        endif

        if mode ==# 'inside' || mode ==# 'align_to_begin_element'

          if last_token_of_line && i != 0
            " Examples: {{{
            "
            " mode == 'inside':
            "
            "     my_func(
            "       LTI
            "
            "     [Variable, {
            "        LTI
            "
            " mode == 'align_to_begin_element':
            "
            "     my_func(
            "       Params
            "      ) % LTI
            "
            "     [Variable, {
            "        Terms
            "       } % LTI
            " }}}
            let stack = ['prev_term_plus']
            let plus = (mode ==# 'inside' ? 2 : 1)
            call s:Log('    "' . token .
                      \'" token found at end of line -> find previous token')
          elseif mode ==# 'align_to_begin_element'
            " Examples: {{{
            "
            " mode == 'align_to_begin_element' && !last_token_of_line
            "
            "     my_func(stored_vcol
            "            ) % LTI
            "
            "     [Variable, {stored_vcol
            "                } % LTI
            "
            " mode == 'align_to_begin_element' && i == 0
            "
            "     (
            "       stored_vcol
            "     ) % LTI
            "
            "     {
            "       stored_vcol
            "     } % LTI
            " }}}
            call s:Log('    "' . token . '" token (whose closing token ' .
                      \'starts LTI) found -> return')
            return curr_vcol
          elseif stored_vcol ==# -1
            " Examples: {{{
            "
            " mode == 'inside' && stored_vcol == -1 && !last_token_of_line
            "
            "     my_func(
            "             LTI
            "     [Variable, {
            "                 LTI
            "
            " mode == 'inside' && stored_vcol == -1 && i == 0
            "
            "     (
            "      LTI
            "
            "     {
            "      LTI
            " }}}
            call s:Log('    "' . token .
                      \'" token (which directly precedes LTI) found -> return')
            return curr_vcol + 1
          else
            " Examples: {{{
            "
            " mode == 'inside' && stored_vcol != -1 && !last_token_of_line
            "
            "     my_func(stored_vcol,
            "             LTI
            "
            "     [Variable, {stored_vcol,
            "                 LTI
            "
            " mode == 'inside' && stored_vcol != -1 && i == 0
            "
            "     (stored_vcol,
            "      LTI
            "
            "     {stored_vcol,
            "      LTI
            " }}}
            call s:Log('    "' . token .
                      \'" token (whose block contains LTI) found -> return')
            return stored_vcol
          endif
        endif

      elseif index(['end', ')', ']', '}', '>>'], token) != -1

        " If we can be sure that there is synchronization in the Erlang
        " syntax, we use searchpair to make the script quicker. Otherwise we
        " just push the token onto the stack and keep parsing.
    
        " No synchronization -> no searchpair optimization
        if !exists('b:erlang_syntax_synced')
          call s:Push(stack, token)

        " We don't have searchpair optimization for '>>'
        elseif token ==# '>>'
          call s:Push(stack, token)

        elseif token ==# 'end'
          let [lnum_new, col_new] = s:SearchEndPair(lnum, curr_col)

          if lnum_new ==# 0
            return s:IndentError('Matching token for "end" not found',
                                \token, stack)
          else
            if lnum_new != lnum
              call s:Log('    Tokenize for "end" <<<<')
              let [lnum, indtokens] = s:TokenizeLine(lnum_new, 'up')
              call s:Log('    >>>> Tokenize for "end"')
            endif

            let [success, i] = s:GetIndtokenAtCol(indtokens, col_new)
            if !success | return i | endif
            let [token, curr_vcol, curr_col] = indtokens[i]
            call s:Log('    Match for "end" in line ' . lnum_new . ': ' .
                      \string(indtokens[i]))
          endif

        else " token is one of the following: ')', ']', '}'

          call s:Push(stack, token)

          " We have to escape '[', because this string will be interpreted as a
          " regexp
          let open_paren = (token ==# ')' ? '(' :
                           \token ==# ']' ? '\[' :
                           \               '{')

          let [lnum_new, col_new] = s:SearchPair(lnum, curr_col,
                                                \open_paren, '', token)

          if lnum_new ==# 0
            return s:IndentError('Matching token not found',
                                \token, stack)
          else
            if lnum_new != lnum
              call s:Log('    Tokenize the opening paren <<<<')
              let [lnum, indtokens] = s:TokenizeLine(lnum_new, 'up')
              call s:Log('    >>>>')
            endif

            let [success, i] = s:GetIndtokenAtCol(indtokens, col_new)
            if !success | return i | endif
            let [token, curr_vcol, curr_col] = indtokens[i]
            call s:Log('    Match in line ' . lnum_new . ': ' .
                      \string(indtokens[i]))

            " Go back to the beginning of the loop and handle the opening paren
            continue
          endif
        endif

      elseif token ==# ';'

        if empty(stack)
          call s:Push(stack, ';')
        elseif index([';', '->', 'when', 'end', 'after', 'catch'],
                    \stack[0]) != -1
          " Pass:
          "
          " - If the stack top is another ';', then one ';' is
          "   enough.
          " - If the stack top is an '->' or a 'when', then we
          "   should keep that, because they signify the type of the
          "   LTI (branch, condition or guard).
          " - From the indentation point of view, the keyword
          "   (of/catch/after/end) before the LTI is what counts, so
          "   if the stack already has a catch/after/end, we don't
          "   modify it. This way when we reach case/try/receive,
          "   there will be at most one of/catch/after/end token in
          "   the stack.
        else
          return s:UnexpectedToken(token, stack)
        endif

      elseif token ==# '->'

        if empty(stack) && !last_token_of_line
          call s:Log('    LTI is in expression after arrow -> return')
          return stored_vcol
        elseif empty(stack) || stack[0] ==# ';' || stack[0] ==# 'end'
          " stack = [';']  -> LTI is either a branch or in a guard
          " stack = ['->']  ->  LTI is a condition
          " stack = ['->', ';']  -> LTI is a branch
          call s:Push(stack, '->')
        elseif index(['->', 'when', 'end', 'after', 'catch'], stack[0]) != -1
          " Pass:
          "
          " - If the stack top is another '->', then one '->' is
          "   enough.
          " - If the stack top is a 'when', then we should keep
          "   that, because this signifies that LTI is a in a guard.
          " - From the indentation point of view, the keyword
          "   (of/catch/after/end) before the LTI is what counts, so
          "   if the stack already has a catch/after/end, we don't
          "   modify it. This way when we reach case/try/receive,
          "   there will be at most one of/catch/after/end token in
          "   the stack.
        else
          return s:UnexpectedToken(token, stack)
        endif

      elseif token ==# 'when'

        " Pop all ';' from the top of the stack
        while !empty(stack) && stack[0] ==# ';'
          call s:Pop(stack)
        endwhile

        if empty(stack)
          if semicolon_abscol != ''
            let stored_vcol = semicolon_abscol
          endif
          if !last_token_of_line
            " Example:
            "   when A,
            "        LTI
            let [ret, res] = s:BeginElementFoundIfEmpty(stack, token, curr_vcol,
                                                       \stored_vcol, shiftwidth())
            if ret | return res | endif
          else
            " Example:
            "   when
            "       LTI
            call s:Push(stack, token)
          endif
        elseif index(['->', 'when', 'end', 'after', 'catch'], stack[0]) != -1
          " Pass:
          " - If the stack top is another 'when', then one 'when' is
          "   enough.
          " - If the stack top is an '->' or a 'when', then we
          "   should keep that, because they signify the type of the
          "   LTI (branch, condition or guard).
          " - From the indentation point of view, the keyword
          "   (of/catch/after/end) before the LTI is what counts, so
          "   if the stack already has a catch/after/end, we don't
          "   modify it. This way when we reach case/try/receive,
          "   there will be at most one of/catch/after/end token in
          "   the stack.
        else
          return s:UnexpectedToken(token, stack)
        endif

      elseif token ==# 'of' || token ==# 'after' ||
           \ (token ==# 'catch' && !s:IsCatchStandalone(lnum, i))

        if token ==# 'after'
          " If LTI is between an 'after' and the corresponding
          " 'end', then let's return
          let [ret, res] = s:BeginElementFoundIfEmpty(stack, token, curr_vcol,
                                                     \stored_vcol, shiftwidth())
          if ret | return res | endif
        endif

        if empty(stack) || stack[0] ==# '->' || stack[0] ==# 'when'
          call s:Push(stack, token)
        elseif stack[0] ==# 'catch' || stack[0] ==# 'after' || stack[0] ==# 'end'
          " Pass: From the indentation point of view, the keyword
          " (of/catch/after/end) before the LTI is what counts, so
          " if the stack already has a catch/after/end, we don't
          " modify it. This way when we reach case/try/receive,
          " there will be at most one of/catch/after/end token in
          " the stack.
        else
          return s:UnexpectedToken(token, stack)
        endif

      elseif token ==# '||' && empty(stack) && !last_token_of_line

        call s:Log('    LTI is in expression after "||" -> return')
        return stored_vcol

      else
        call s:Log('    Misc token, stack unchanged = ' . string(stack))

      endif

      if empty(stack) || stack[0] ==# '->' || stack[0] ==# 'when'
        let stored_vcol = curr_vcol
        let semicolon_abscol = ''
        call s:Log('    Misc token when the stack is empty or has "->" ' .
                  \'-> setting stored_vcol to ' . stored_vcol)
      elseif stack[0] ==# ';'
        let semicolon_abscol = curr_vcol
        call s:Log('    Setting semicolon-stored_vcol to ' . stored_vcol)
      endif

      let i -= 1
      call s:Log('    Token processed. stored_vcol=' . stored_vcol)

      let last_token_of_line = 0

    endwhile " iteration on tokens in a line

    call s:Log('  Line analyzed. stored_vcol=' . stored_vcol)

    if empty(stack) && stored_vcol != -1 &&
     \ (!empty(indtokens) && indtokens[0][0] != '<string_end>' &&
     \                       indtokens[0][0] != '<quoted_atom_end>')
      call s:Log('    Empty stack at the beginning of the line -> return')
      return stored_vcol
    endif

    let lnum -= 1

  endwhile " iteration on lines

endfunction

" ErlangIndent function {{{1
" =====================

function! ErlangIndent()

  call s:ClearTokenCacheIfNeeded()

  let currline = getline(v:lnum)
  call s:Log('Indenting line ' . v:lnum . ': ' . currline)

  if s:IsLineStringContinuation(v:lnum) || s:IsLineAtomContinuation(v:lnum)
    call s:Log('String or atom continuation found -> ' .
              \'leaving indentation unchanged')
    return -1
  endif

  let ml = matchlist(currline,
                    \'^\(\s*\)\(\%(end\|of\|catch\|after\)\>\|[)\]}]\|>>\)')

  " If the line has a special beginning, but not a standalone catch
  if !empty(ml) && !(ml[2] ==# 'catch' && s:IsCatchStandalone(v:lnum, 0))

    let curr_col = len(ml[1])

    " If we can be sure that there is synchronization in the Erlang
    " syntax, we use searchpair to make the script quicker.
    if ml[2] ==# 'end' && exists('b:erlang_syntax_synced')

      let [lnum, col] = s:SearchEndPair(v:lnum, curr_col)

      if lnum ==# 0
        return s:IndentError('Matching token for "end" not found',
                            \'end', [])
      else
        call s:Log('    Tokenize for "end" <<<<')
        let [lnum, indtokens] = s:TokenizeLine(lnum, 'up')
        call s:Log('    >>>> Tokenize for "end"')

        let [success, i] = s:GetIndtokenAtCol(indtokens, col)
        if !success | return i | endif
        let [token, curr_vcol, curr_col] = indtokens[i]
        call s:Log('    Match for "end" in line ' . lnum . ': ' .
                   \string(indtokens[i]))
        return curr_vcol
      endif

    else

      call s:Log("  Line type = 'end'")
      let new_col = s:ErlangCalcIndent(v:lnum - 1,
                                      \[ml[2], 'align_to_begin_element'])
    endif
  else
    call s:Log("  Line type = 'normal'")

    let new_col = s:ErlangCalcIndent(v:lnum - 1, [])
    if currline =~# '^\s*when\>'
      let new_col += 2
    endif
  endif

  if new_col < -1
    call s:Log('WARNING: returning new_col == ' . new_col)
    return g:erlang_unexpected_token_indent
  endif

  return new_col

endfunction

" Cleanup {{{1
" =======

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2 et fdm=marker
