" Vim indent file
" Language:    SQL
" Maintainer:  David Fishburn <dfishburn dot vim at gmail dot com>
" Last Change: 2017 Jun 13
" Version:     3.0
" Download:    http://vim.sourceforge.net/script.php?script_id=495

" Notes:
"    Indenting keywords are based on Oracle and Sybase Adaptive Server
"    Anywhere (ASA).  Test indenting was done with ASA stored procedures and
"    fuctions and Oracle packages which contain stored procedures and
"    functions.
"    This has not been tested against Microsoft SQL Server or
"    Sybase Adaptive Server Enterprise (ASE) which use the Transact-SQL
"    syntax.  That syntax does not have end tags for IF's, which makes
"    indenting more difficult.
"
" Known Issues:
"    The Oracle MERGE statement does not have an end tag associated with
"    it, this can leave the indent hanging to the right one too many.
"
" History:
"    3.0 (Dec 2012)
"        Added cpo check
"
"    2.0
"        Added the FOR keyword to SQLBlockStart to handle (Alec Tica):
"            for i in 1..100 loop
"              |<-- I expect to have indentation here
"            end loop;
"

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent     = 1
let b:current_indent = "sqlanywhere"

setlocal indentkeys-=0{
setlocal indentkeys-=0}
setlocal indentkeys-=:
setlocal indentkeys-=0#
setlocal indentkeys-=e

" This indicates formatting should take place when one of these
" expressions is used.  These expressions would normally be something
" you would type at the BEGINNING of a line
" SQL is generally case insensitive, so this files assumes that
" These keywords are something that would trigger an indent LEFT, not
" an indent right, since the SQLBlockStart is used for those keywords
setlocal indentkeys+==~end,=~else,=~elseif,=~elsif,0=~when,0=)

" GetSQLIndent is executed whenever one of the expressions
" in the indentkeys is typed
setlocal indentexpr=GetSQLIndent()

" Only define the functions once.
if exists("*GetSQLIndent")
    finish
endif
let s:keepcpo= &cpo
set cpo&vim

" List of all the statements that start a new block.
" These are typically words that start a line.
" IS is excluded, since it is difficult to determine when the
" ending block is (especially for procedures/functions).
let s:SQLBlockStart = '^\s*\%('.
                \ 'if\|else\|elseif\|elsif\|'.
                \ 'while\|loop\|do\|for\|'.
                \ 'begin\|'.
                \ 'case\|when\|merge\|exception'.
                \ '\)\>'
let s:SQLBlockEnd = '^\s*\(end\)\>'

" The indent level is also based on unmatched paranethesis
" If a line has an extra "(" increase the indent
" If a line has an extra ")" decrease the indent
function! s:CountUnbalancedParan( line, paran_to_check )
    let l = a:line
    let lp = substitute(l, '[^(]', '', 'g')
    let l = a:line
    let rp = substitute(l, '[^)]', '', 'g')

    if a:paran_to_check =~ ')'
        " echom 'CountUnbalancedParan ) returning: ' .
        " \ (strlen(rp) - strlen(lp))
        return (strlen(rp) - strlen(lp))
    elseif a:paran_to_check =~ '('
        " echom 'CountUnbalancedParan ( returning: ' .
        " \ (strlen(lp) - strlen(rp))
        return (strlen(lp) - strlen(rp))
    else
        " echom 'CountUnbalancedParan unknown paran to check: ' .
        " \ a:paran_to_check
        return 0
    endif
endfunction

" Unindent commands based on previous indent level
function! s:CheckToIgnoreRightParan( prev_lnum, num_levels )
    let lnum = a:prev_lnum
    let line = getline(lnum)
    let ends = 0
    let num_right_paran = a:num_levels
    let ignore_paran = 0
    let vircol = 1

    while num_right_paran > 0
        silent! exec 'norm! '.lnum."G\<bar>".vircol."\<bar>"
        let right_paran = search( ')', 'W' )
        if right_paran != lnum
            " This should not happen since there should be at least
            " num_right_paran matches for this line
            break
        endif
        let vircol      = virtcol(".")

        " if getline(".") =~ '^)'
        let matching_paran = searchpair('(', '', ')', 'bW',
                    \ 's:IsColComment(line("."), col("."))')

        if matching_paran < 1
            " No match found
            " echom 'CTIRP - no match found, ignoring'
            break
        endif

        if matching_paran == lnum
            " This was not an unmatched parantenses, start the search again
            " again after this column
            " echom 'CTIRP - same line match, ignoring'
            continue
        endif

        " echom 'CTIRP - match: ' . line(".") . '  ' . getline(".")

        if getline(matching_paran) =~? '\(if\|while\)\>'
            " echom 'CTIRP - if/while ignored: ' . line(".") . '  ' . getline(".")
            let ignore_paran = ignore_paran + 1
        endif

        " One match found, decrease and check for further matches
        let num_right_paran = num_right_paran - 1

    endwhile

    " Fallback - just move back one
    " return a:prev_indent - shiftwidth()
    return ignore_paran
endfunction

" Based on the keyword provided, loop through previous non empty
" non comment lines to find the statement that initated the keyword.
" Return its indent level
"    CASE ..
"    WHEN ...
" Should return indent level of CASE
"    EXCEPTION ..
"    WHEN ...
"         something;
"    WHEN ...
" Should return indent level of exception.
function! s:GetStmtStarterIndent( keyword, curr_lnum )
    let lnum  = a:curr_lnum

    " Default - reduce indent by 1
    let ind = indent(a:curr_lnum) - shiftwidth()

    if a:keyword =~? 'end'
        exec 'normal! ^'
        let stmts = '^\s*\%('.
                    \ '\<begin\>\|' .
                    \ '\%(\%(\<end\s\+\)\@<!\<loop\>\)\|' .
                    \ '\%(\%(\<end\s\+\)\@<!\<case\>\)\|' .
                    \ '\%(\%(\<end\s\+\)\@<!\<for\>\)\|' .
                    \ '\%(\%(\<end\s\+\)\@<!\<if\>\)'.
                    \ '\)'
        let matching_lnum = searchpair(stmts, '', '\<end\>\zs', 'bW',
                    \ 's:IsColComment(line("."), col(".")) == 1')
        exec 'normal! $'
        if matching_lnum > 0 && matching_lnum < a:curr_lnum
            let ind = indent(matching_lnum)
        endif
    elseif a:keyword =~? 'when'
        exec 'normal! ^'
        let matching_lnum = searchpair(
                    \ '\%(\<end\s\+\)\@<!\<case\>\|\<exception\>\|\<merge\>',
                    \ '',
                    \ '\%(\%(\<when\s\+others\>\)\|\%(\<end\s\+case\>\)\)',
                    \ 'bW',
                    \ 's:IsColComment(line("."), col(".")) == 1')
        exec 'normal! $'
        if matching_lnum > 0 && matching_lnum < a:curr_lnum
            let ind = indent(matching_lnum)
        else
            let ind = indent(a:curr_lnum)
        endif
    endif

    return ind
endfunction


" Check if the line is a comment
function! s:IsLineComment(lnum)
    let rc = synIDattr(
                \ synID(a:lnum,
                \     match(getline(a:lnum), '\S')+1, 0)
                \ , "name")
                \ =~? "comment"

    return rc
endfunction


" Check if the column is a comment
function! s:IsColComment(lnum, cnum)
    let rc = synIDattr(synID(a:lnum, a:cnum, 0), "name")
                \           =~? "comment"

    return rc
endfunction


" Instead of returning a column position, return
" an appropriate value as a factor of shiftwidth.
function! s:ModuloIndent(ind)
    let ind = a:ind

    if ind > 0
        let modulo = ind % shiftwidth()

        if modulo > 0
            let ind = ind - modulo
        endif
    endif

    return ind
endfunction


" Find correct indent of a new line based upon the previous line
function! GetSQLIndent()
    let lnum = v:lnum
    let ind = indent(lnum)

    " If the current line is a comment, leave the indent as is
    " Comment out this additional check since it affects the
    " indenting of =, and will not reindent comments as it should
    " if s:IsLineComment(lnum) == 1
    "     return ind
    " endif

    " Get previous non-blank line
    let prevlnum = prevnonblank(lnum - 1)
    if prevlnum <= 0
        return ind
    endif

    if s:IsLineComment(prevlnum) == 1
        if getline(v:lnum) =~ '^\s*\*'
            let ind = s:ModuloIndent(indent(prevlnum))
            return ind + 1
        endif
        " If the previous line is a comment, then return -1
        " to tell Vim to use the formatoptions setting to determine
        " the indent to use
        " But only if the next line is blank.  This would be true if
        " the user is typing, but it would not be true if the user
        " is reindenting the file
        if getline(v:lnum) =~ '^\s*$'
            return -1
        endif
    endif

    " echom 'PREVIOUS INDENT: ' . indent(prevlnum) . '  LINE: ' . getline(prevlnum)

    " This is the line you just hit return on, it is not the current line
    " which is new and empty
    " Based on this line, we can determine how much to indent the new
    " line

    " Get default indent (from prev. line)
    let ind      = indent(prevlnum)
    let prevline = getline(prevlnum)

    " Now check what's on the previous line to determine if the indent
    " should be changed, for example IF, BEGIN, should increase the indent
    " where END IF, END, should decrease the indent.
    if prevline =~? s:SQLBlockStart
        " Move indent in
        let ind = ind + shiftwidth()
        " echom 'prevl - SQLBlockStart - indent ' . ind . '  line: ' . prevline
    elseif prevline =~ '[()]'
        if prevline =~ '('
            let num_unmatched_left = s:CountUnbalancedParan( prevline, '(' )
        else
            let num_unmatched_left = 0
        endif
        if prevline =~ ')'
            let num_unmatched_right  = s:CountUnbalancedParan( prevline, ')' )
        else
            let num_unmatched_right  = 0
            " let num_unmatched_right  = s:CountUnbalancedParan( prevline, ')' )
        endif
        if num_unmatched_left > 0
            " There is a open left paranethesis
            " increase indent
            let ind = ind + ( shiftwidth() * num_unmatched_left )
        elseif num_unmatched_right > 0
            " if it is an unbalanced paranethesis only unindent if
            " it was part of a command (ie create table(..)  )
            " instead of part of an if (ie if (....) then) which should
            " maintain the indent level
            let ignore = s:CheckToIgnoreRightParan( prevlnum, num_unmatched_right )
            " echom 'prevl - ) unbalanced - CTIRP - ignore: ' . ignore

            if prevline =~ '^\s*)'
                let ignore = ignore + 1
                " echom 'prevl - begins ) unbalanced ignore: ' . ignore
            endif

            if (num_unmatched_right - ignore) > 0
                let ind = ind - ( shiftwidth() * (num_unmatched_right - ignore) )
            endif

        endif
    endif


    " echom 'CURRENT INDENT: ' . ind . '  LINE: '  . getline(v:lnum)

    " This is a new blank line since we just typed a carriage return
    " Check current line; search for simplistic matching start-of-block
    let line = getline(v:lnum)

    if line =~? '^\s*els'
        " Any line when you type else will automatically back up one
        " ident level  (ie else, elseif, elsif)
        let ind = ind - shiftwidth()
        " echom 'curr - else - indent ' . ind
    elseif line =~? '^\s*end\>'
        let ind = s:GetStmtStarterIndent('end', v:lnum)
        " General case for end
        " let ind = ind - shiftwidth()
        " echom 'curr - end - indent ' . ind
    elseif line =~? '^\s*when\>'
        let ind = s:GetStmtStarterIndent('when', v:lnum)
        " If the WHEN clause is used with a MERGE or EXCEPTION
        " clause, do not change the indent level, since these
        " statements do not have a corresponding END statement.
        " if stmt_starter =~? 'case'
        "    let ind = ind - shiftwidth()
        " endif
        " elseif line =~ '^\s*)\s*;\?\s*$'
        " elseif line =~ '^\s*)'
    elseif line =~ '^\s*)'
        let num_unmatched_right  = s:CountUnbalancedParan( line, ')' )
        let ignore = s:CheckToIgnoreRightParan( v:lnum, num_unmatched_right )
        " If the line ends in a ), then reduce the indent
        " This catches items like:
        " CREATE TABLE T1(
        "    c1 int,
        "    c2 int
        "    );
        " But we do not want to unindent a line like:
        " IF ( c1 = 1
        " AND  c2 = 3 ) THEN
        " let num_unmatched_right  = s:CountUnbalancedParan( line, ')' )
        " if num_unmatched_right > 0
        " elseif strpart( line, strlen(line)-1, 1 ) =~ ')'
        " let ind = ind - shiftwidth()
        if line =~ '^\s*)'
            " let ignore = ignore + 1
            " echom 'curr - begins ) unbalanced ignore: ' . ignore
        endif

        if (num_unmatched_right - ignore) > 0
            let ind = ind - ( shiftwidth() * (num_unmatched_right - ignore) )
        endif
        " endif
    endif

    " echom 'final - indent ' . ind
    return s:ModuloIndent(ind)
endfunction

"  Restore:
let &cpo= s:keepcpo
unlet s:keepcpo
" vim: ts=4 fdm=marker sw=4
