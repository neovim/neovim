"  vim: set sw=3 sts=3:

" Awk indent script. It can handle multi-line statements and expressions.
" It works up to the point where the distinction between correct/incorrect
" and personal taste gets fuzzy. Drop me an e-mail for bug reports and
" reasonable style suggestions.
"
" Bugs:
" =====
" - Some syntax errors may cause erratic indentation.
" - Same for very unusual but syntacticly correct use of { }
" - In some cases it's confused by the use of ( and { in strings constants
" - This version likes the closing brace of a multiline pattern-action be on
"   character position 1 before the following pattern-action combination is
"   formatted

" Author:
" =======
" Erik Janssen, ejanssen@itmatters.nl
"
" History:
" ========
" 26-04-2002 Got initial version working reasonably well
" 29-04-2002 Fixed problems in function headers and max line width
"	     Added support for two-line if's without curly braces
" Fixed hang: 2011 Aug 31

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif

let b:did_indent = 1

setlocal indentexpr=GetAwkIndent()
" Mmm, copied from the tcl indent program. Is this okay?
setlocal indentkeys-=:,0#

" Only define the function once.
if exists("*GetAwkIndent")
    finish
endif

" This function contains a lot of exit points. It checks for simple cases
" first to get out of the function as soon as possible, thereby reducing the
" number of possibilities later on in the difficult parts

function! GetAwkIndent()

   " Find previous line and get it's indentation
   let prev_lineno = s:Get_prev_line( v:lnum )
   if prev_lineno == 0
      return 0
   endif
   let prev_data = getline( prev_lineno )
   let ind = indent( prev_lineno )

   " Increase indent if the previous line contains an opening brace. Search
   " for this brace the hard way to prevent errors if the previous line is a
   " 'pattern { action }' (simple check match on /{/ increases the indent then)

   if s:Get_brace_balance( prev_data, '{', '}' ) > 0
      return ind + shiftwidth()
   endif

   let brace_balance = s:Get_brace_balance( prev_data, '(', ')' )

   " If prev line has positive brace_balance and starts with a word (keyword
   " or function name), align the current line on the first '(' of the prev
   " line

   if brace_balance > 0 && s:Starts_with_word( prev_data )
      return s:Safe_indent( ind, s:First_word_len(prev_data), getline(v:lnum))
   endif

   " If this line starts with an open brace bail out now before the line
   " continuation checks.

   if getline( v:lnum ) =~ '^\s*{'
      return ind
   endif

   " If prev line seems to be part of multiline statement:
   " 1. Prev line is first line of a multiline statement
   "    -> attempt to indent on first ' ' or '(' of prev line, just like we
   "       indented the positive brace balance case above
   " 2. Prev line is not first line of a multiline statement
   "    -> copy indent of prev line

   let continue_mode = s:Seems_continuing( prev_data )
   if continue_mode > 0
     if s:Seems_continuing( getline(s:Get_prev_line( prev_lineno )) )
       " Case 2
       return ind
     else
       " Case 1
       if continue_mode == 1
	  " Need continuation due to comma, backslash, etc
	  return s:Safe_indent( ind, s:First_word_len(prev_data), getline(v:lnum))
       else
	 " if/for/while without '{'
	 return ind + shiftwidth()
       endif
     endif
   endif

   " If the previous line doesn't need continuation on the current line we are
   " on the start of a new statement.  We have to make sure we align with the
   " previous statement instead of just the previous line. This is a bit
   " complicated because the previous statement might be multi-line.
   "
   " The start of a multiline statement can be found by:
   "
   " 1 If the previous line contains closing braces and has negative brace
   "   balance, search backwards until cumulative brace balance becomes zero,
   "   take indent of that line
   " 2 If the line before the previous needs continuation search backward
   "   until that's not the case anymore. Take indent of one line down.

   " Case 1
   if prev_data =~ ')' && brace_balance < 0
      while brace_balance != 0 && prev_lineno > 0
	 let prev_lineno = s:Get_prev_line( prev_lineno )
	 let prev_data = getline( prev_lineno )
	 let brace_balance=brace_balance+s:Get_brace_balance(prev_data,'(',')' )
      endwhile
      let ind = indent( prev_lineno )
   else
      " Case 2
      if s:Seems_continuing( getline( prev_lineno - 1 ) )
	 let prev_lineno = prev_lineno - 2
	 let prev_data = getline( prev_lineno )
	 while prev_lineno > 0 && (s:Seems_continuing( prev_data ) > 0)
	    let prev_lineno = s:Get_prev_line( prev_lineno )
	    let prev_data = getline( prev_lineno )
	 endwhile
	 let ind = indent( prev_lineno + 1 )
      endif
   endif

   " Decrease indent if this line contains a '}'.
   if getline(v:lnum) =~ '^\s*}'
      let ind = ind - shiftwidth()
   endif

   return ind
endfunction

" Find the open and close braces in this line and return how many more open-
" than close braces there are. It's also used to determine cumulative balance
" across multiple lines.

function! s:Get_brace_balance( line, b_open, b_close )
   let line2 = substitute( a:line, a:b_open, "", "g" )
   let openb = strlen( a:line ) - strlen( line2 )
   let line3 = substitute( line2, a:b_close, "", "g" )
   let closeb = strlen( line2 ) - strlen( line3 )
   return openb - closeb
endfunction

" Find out whether the line starts with a word (i.e. keyword or function
" call). Might need enhancements here.

function! s:Starts_with_word( line )
  if a:line =~ '^\s*[a-zA-Z_0-9]\+\s*('
     return 1
  endif
  return 0
endfunction

" Find the length of the first word in a line. This is used to be able to
" align a line relative to the 'print ' or 'if (' on the previous line in case
" such a statement spans multiple lines.
" Precondition: only to be used on lines where 'Starts_with_word' returns 1.

function! s:First_word_len( line )
   let white_end = matchend( a:line, '^\s*' )
   if match( a:line, '^\s*func' ) != -1
     let word_end = matchend( a:line, '[a-z]\+\s\+[a-zA-Z_0-9]\+[ (]*' )
   else
     let word_end = matchend( a:line, '[a-zA-Z_0-9]\+[ (]*' )
   endif
   return word_end - white_end
endfunction

" Determine if 'line' completes a statement or is continued on the next line.
" This one is far from complete and accepts illegal code. Not important for
" indenting, however.

function! s:Seems_continuing( line )
  " Unfinished lines
  if a:line =~ '\(--\|++\)\s*$'
    return 0
  endif
  if a:line =~ '[\\,\|\&\+\-\*\%\^]\s*$'
    return 1
  endif
  " if/for/while (cond) eol
  if a:line =~ '^\s*\(if\|while\|for\)\s*(.*)\s*$' || a:line =~ '^\s*else\s*'
      return 2
   endif
  return 0
endfunction

" Get previous relevant line. Search back until a line is that is no
" comment or blank and return the line number

function! s:Get_prev_line( lineno )
   let lnum = a:lineno - 1
   let data = getline( lnum )
   while lnum > 0 && (data =~ '^\s*#' || data =~ '^\s*$')
      let lnum = lnum - 1
      let data = getline( lnum )
   endwhile
   return lnum
endfunction

" This function checks whether an indented line exceeds a maximum linewidth
" (hardcoded 80). If so and it is possible to stay within 80 positions (or
" limit num of characters beyond linewidth) by decreasing the indent (keeping
" it > base_indent), do so.

function! s:Safe_indent( base, wordlen, this_line )
   let line_base = matchend( a:this_line, '^\s*' )
   let line_len = strlen( a:this_line ) - line_base
   let indent = a:base
   if (indent + a:wordlen + line_len) > 80
     " Simple implementation good enough for the time being
     let indent = indent + 3
   endif
   return indent + a:wordlen
endfunction
