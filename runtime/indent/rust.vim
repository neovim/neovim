" Vim indent file
" Language:         Rust
" Author:           Chris Morgan <me@chrismorgan.info>
" Last Change:      2023-09-11
" For bugs, patches and license go to https://github.com/rust-lang/rust.vim

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal cindent
setlocal cinoptions=L0,(s,Ws,J1,j1,m1
setlocal cinkeys=0{,0},!^F,o,O,0[,0],0(,0)
" Don't think cinwords will actually do anything at all... never mind
setlocal cinwords=for,if,else,while,loop,impl,mod,unsafe,trait,struct,enum,fn,extern,macro

" Some preliminary settings
setlocal nolisp		" Make sure lisp indenting doesn't supersede us
setlocal autoindent	" indentexpr isn't much help otherwise
" Also do indentkeys, otherwise # gets shoved to column 0 :-/
setlocal indentkeys=0{,0},!^F,o,O,0[,0],0(,0)

setlocal indentexpr=GetRustIndent(v:lnum)

let b:undo_indent = "setlocal cindent< cinoptions< cinkeys< cinwords< lisp< autoindent< indentkeys< indentexpr<"

" Only define the function once.
if exists("*GetRustIndent")
    finish
endif

" vint: -ProhibitAbbreviationOption
let s:save_cpo = &cpo
set cpo&vim
" vint: +ProhibitAbbreviationOption

" Come here when loading the script the first time.

function! s:get_line_trimmed(lnum)
    " Get the line and remove a trailing comment.
    " Use syntax highlighting attributes when possible.
    " NOTE: this is not accurate; /* */ or a line continuation could trick it
    let line = getline(a:lnum)
    let line_len = strlen(line)
    if has('syntax_items')
        " If the last character in the line is a comment, do a binary search for
        " the start of the comment.  synID() is slow, a linear search would take
        " too long on a long line.
        if synIDattr(synID(a:lnum, line_len, 1), "name") =~? 'Comment\|Todo'
            let min = 1
            let max = line_len
            while min < max
                let col = (min + max) / 2
                if synIDattr(synID(a:lnum, col, 1), "name") =~? 'Comment\|Todo'
                    let max = col
                else
                    let min = col + 1
                endif
            endwhile
            let line = strpart(line, 0, min - 1)
        endif
        return substitute(line, "\s*$", "", "")
    else
        " Sorry, this is not complete, nor fully correct (e.g. string "//").
        " Such is life.
        return substitute(line, "\s*//.*$", "", "")
    endif
endfunction

function! s:is_string_comment(lnum, col)
    if has('syntax_items')
        for id in synstack(a:lnum, a:col)
            let synname = synIDattr(id, "name")
            if synname ==# "rustString" || synname =~# "^rustComment"
                return 1
            endif
        endfor
    else
        " without syntax, let's not even try
        return 0
    endif
endfunction

if exists('*shiftwidth')
    function! s:shiftwidth()
        return shiftwidth()
    endfunc
else
    function! s:shiftwidth()
        return &shiftwidth
    endfunc
endif

function GetRustIndent(lnum)
    " Starting assumption: cindent (called at the end) will do it right
    " normally. We just want to fix up a few cases.

    let line = getline(a:lnum)

    if has('syntax_items')
        let synname = synIDattr(synID(a:lnum, 1, 1), "name")
        if synname ==# "rustString"
            " If the start of the line is in a string, don't change the indent
            return -1
        elseif synname =~? '\(Comment\|Todo\)'
                    \ && line !~# '^\s*/\*'  " not /* opening line
            if synname =~? "CommentML" " multi-line
                if line !~# '^\s*\*' && getline(a:lnum - 1) =~# '^\s*/\*'
                    " This is (hopefully) the line after a /*, and it has no
                    " leader, so the correct indentation is that of the
                    " previous line.
                    return GetRustIndent(a:lnum - 1)
                endif
            endif
            " If it's in a comment, let cindent take care of it now. This is
            " for cases like "/*" where the next line should start " * ", not
            " "* " as the code below would otherwise cause for module scope
            " Fun fact: "  /*\n*\n*/" takes two calls to get right!
            return cindent(a:lnum)
        endif
    endif

    " cindent gets second and subsequent match patterns/struct members wrong,
    " as it treats the comma as indicating an unfinished statement::
    "
    " match a {
    "     b => c,
    "         d => e,
    "         f => g,
    " };

    " Search backwards for the previous non-empty line.
    let prevlinenum = prevnonblank(a:lnum - 1)
    let prevline = s:get_line_trimmed(prevlinenum)
    while prevlinenum > 1 && prevline !~# '[^[:blank:]]'
        let prevlinenum = prevnonblank(prevlinenum - 1)
        let prevline = s:get_line_trimmed(prevlinenum)
    endwhile

    " A standalone '{', '}', or 'where'
    let l:standalone_open = line =~# '\V\^\s\*{\s\*\$'
    let l:standalone_close = line =~# '\V\^\s\*}\s\*\$'
    let l:standalone_where = line =~# '\V\^\s\*where\s\*\$'
    if l:standalone_open || l:standalone_close || l:standalone_where
        " ToDo: we can search for more items than 'fn' and 'if'.
        let [l:found_line, l:col, l:submatch] =
                    \ searchpos('\<\(fn\)\|\(if\)\>', 'bnWp')
        if l:found_line !=# 0
            " Now we count the number of '{' and '}' in between the match
            " locations and the current line (there is probably a better
            " way to compute this).
            let l:i = l:found_line
            let l:search_line = strpart(getline(l:i), l:col - 1)
            let l:opens = 0
            let l:closes = 0
            while l:i < a:lnum
                let l:search_line2 = substitute(l:search_line, '\V{', '', 'g')
                let l:opens += strlen(l:search_line) - strlen(l:search_line2)
                let l:search_line3 = substitute(l:search_line2, '\V}', '', 'g')
                let l:closes += strlen(l:search_line2) - strlen(l:search_line3)
                let l:i += 1
                let l:search_line = getline(l:i)
            endwhile
            if l:standalone_open || l:standalone_where
                if l:opens ==# l:closes
                    return indent(l:found_line)
                endif
            else
                " Expect to find just one more close than an open
                if l:opens ==# l:closes + 1
                    return indent(l:found_line)
                endif
            endif
        endif
    endif

    " A standalone 'where' adds a shift.
    let l:standalone_prevline_where = prevline =~# '\V\^\s\*where\s\*\$'
    if l:standalone_prevline_where
        return indent(prevlinenum) + 4
    endif

    " Handle where clauses nicely: subsequent values should line up nicely.
    if prevline[len(prevline) - 1] ==# ","
                \ && prevline =~# '^\s*where\s'
        return indent(prevlinenum) + 6
    endif

    let l:last_prevline_character = prevline[len(prevline) - 1]

    " A line that ends with '.<expr>;' is probably an end of a long list
    " of method operations.
    if prevline =~# '\V\^\s\*.' && l:last_prevline_character ==# ';'
        call cursor(a:lnum - 1, 1)
        let l:scope_start = searchpair('{\|(', '', '}\|)', 'nbW',
                    \ 's:is_string_comment(line("."), col("."))')
        if l:scope_start != 0 && l:scope_start < a:lnum
            return indent(l:scope_start) + 4
        endif
    endif

    if l:last_prevline_character ==# ","
                \ && s:get_line_trimmed(a:lnum) !~# '^\s*[\[\]{})]'
                \ && prevline !~# '^\s*fn\s'
                \ && prevline !~# '([^()]\+,$'
                \ && s:get_line_trimmed(a:lnum) !~# '^\s*\S\+\s*=>'
        " Oh ho! The previous line ended in a comma! I bet cindent will try to
        " take this too far... For now, let's normally use the previous line's
        " indent.

        " One case where this doesn't work out is where *this* line contains
        " square or curly brackets; then we normally *do* want to be indenting
        " further.
        "
        " Another case where we don't want to is one like a function
        " definition with arguments spread over multiple lines:
        "
        " fn foo(baz: Baz,
        "        baz: Baz) // <-- cindent gets this right by itself
        "
        " Another case is similar to the previous, except calling a function
        " instead of defining it, or any conditional expression that leaves
        " an open paren:
        "
        " foo(baz,
        "     baz);
        "
        " if baz && (foo ||
        "            bar) {
        "
        " Another case is when the current line is a new match arm.
        "
        " There are probably other cases where we don't want to do this as
        " well. Add them as needed.
        return indent(prevlinenum)
    endif

    if !has("patch-7.4.355")
        " cindent before 7.4.355 doesn't do the module scope well at all; e.g.::
        "
        " static FOO : &'static [bool] = [
        " true,
        "	 false,
        "	 false,
        "	 true,
        "	 ];
        "
        "	 uh oh, next statement is indented further!

        " Note that this does *not* apply the line continuation pattern properly;
        " that's too hard to do correctly for my liking at present, so I'll just
        " start with these two main cases (square brackets and not returning to
        " column zero)

        call cursor(a:lnum, 1)
        if searchpair('{\|(', '', '}\|)', 'nbW',
                    \ 's:is_string_comment(line("."), col("."))') == 0
            if searchpair('\[', '', '\]', 'nbW',
                        \ 's:is_string_comment(line("."), col("."))') == 0
                " Global scope, should be zero
                return 0
            else
                " At the module scope, inside square brackets only
                "if getline(a:lnum)[0] == ']' || search('\[', '', '\]', 'nW') == a:lnum
                if line =~# "^\\s*]"
                    " It's the closing line, dedent it
                    return 0
                else
                    return &shiftwidth
                endif
            endif
        endif
    endif

    " Fall back on cindent, which does it mostly right
    return cindent(a:lnum)
endfunction

" vint: -ProhibitAbbreviationOption
let &cpo = s:save_cpo
unlet s:save_cpo
" vint: +ProhibitAbbreviationOption

" vim: set et sw=4 sts=4 ts=8:
