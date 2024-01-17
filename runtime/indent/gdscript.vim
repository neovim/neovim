" Vim indent file
" Language: gdscript (Godot game engine)
" Maintainer: Maxim Kim <habamax@gmail.com>
" Based on python indent file.
"
" This file has been manually translated from Vim9 script.

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

let s:save_cpo = &cpo
set cpo&vim

let s:undo_opts = "setl indentexpr< indentkeys< lisp< autoindent<"

if exists('b:undo_indent')
    let b:undo_indent ..= "|" .. s:undo_opts
else
    let b:undo_indent = s:undo_opts
endif

setlocal nolisp
setlocal autoindent
setlocal indentexpr=s:GDScriptIndent()
setlocal indentkeys+=<:>,=elif,=except


function s:GDScriptIndent() abort
    " If this line is explicitly joined: If the previous line was also joined,
    " line it up with that one, otherwise add two 'shiftwidth'
    if getline(v:lnum - 1) =~# '\\$'
        if v:lnum > 1 && getline(v:lnum - 2) =~# '\\$'
            return indent(v:lnum - 1)
        endif
        return indent(v:lnum - 1) + (shiftwidth() * 2)
    endif

    " If the start of the line is in a string don't change the indent.
    if has('syntax_items') && synIDattr(synID(v:lnum, 1, 1), "name") =~# "String$"
        return -1
    endif

    " Search backwards for the previous non-empty line.
    let plnum = prevnonblank(v:lnum - 1)

    if plnum == 0
        " This is the first non-empty line, use zero indent.
        return 0
    endif

    let plindent = indent(plnum)
    let plnumstart = plnum

    " Get the line and remove a trailing comment.
    " Use syntax highlighting attributes when possible.
    let pline = getline(plnum)
    let pline_len = strlen(pline)
    if has('syntax_items')
        " If the last character in the line is a comment, do a binary search for
        " the start of the comment.  synID() is slow, a linear search would take
        " too long on a long line.
        if synIDattr(synID(plnum, pline_len, 1), "name") =~# "\\(Comment\\|Todo\\)$"
            let min = 1
            let max = pline_len
            while min < max
                let col = (min + max) / 2
                if synIDattr(synID(plnum, col, 1), "name") =~# "\\(Comment\\|Todo\\)$"
                    let max = col
                else
                    let min = col + 1
                endif
            endwhile
            let pline = strpart(pline, 0, min - 1)
        endif
    else
        let col = 0
        while col < pline_len
            if pline[col] ==# '#'
                let pline = strpart(pline, 0, col)
                break
            endif
            let col = col + 1
        endwhile
    endif


    " When "inside" parenthesis: If at the first line below the parenthesis add
    " one 'shiftwidth' ("inside" is simplified and not really checked)
    " my_var = (
    "     a
    "     + b
    "     + c
    " )
    if pline =~# '[({\[]\s*$'
        return indent(plnum) + shiftwidth()
    endif


    " If the previous line ended with a colon, indent this line
    if pline =~# ':\s*$'
        return plindent + shiftwidth()
    endif

    " If the previous line was a stop-execution statement...
    if getline(plnum) =~# '^\s*\(break\|continue\|raise\|return\|pass\)\>'
        " See if the user has already dedented
        if indent(v:lnum) > indent(plnum) - shiftwidth()
            " If not, recommend one dedent
            return indent(plnum) - shiftwidth()
        endif
        " Otherwise, trust the user
        return -1
    endif

    " If the current line begins with a keyword that lines up with "try"
    if getline(v:lnum) =~# '^\s*\(except\|finally\)\>'
        let lnum = v:lnum - 1
        while lnum >= 1
            if getline(lnum) =~# '^\s*\(try\|except\)\>'
                let ind = indent(lnum)
                if ind >= indent(v:lnum)
                    return -1   " indent is already less than this
                endif
                return ind      " line up with previous try or except
            endif
            let lnum = lnum - 1
        endwhile
        return -1               " no matching "try"!
    endif


    " If the current line begins with a header keyword, dedent
    if getline(v:lnum) =~# '^\s*\(elif\|else\)\>'

        " Unless the previous line was a one-liner
        if getline(plnumstart) =~# '^\s*\(for\|if\|try\)\>'
            return plindent
        endif

        " Or the user has already dedented
        if indent(v:lnum) <= plindent - shiftwidth()
            return -1
        endif

        return plindent - shiftwidth()
    endif

    return -1
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
