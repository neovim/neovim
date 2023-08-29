" Vim indent file
" Language:     fish
" Maintainer:   Nicholas Boyle (github.com/nickeb96)
" Repository:   https://github.com/nickeb96/fish.vim
" Last Change:  February 4, 2023
"               2023 Aug 28 by Vim Project (undo_indent)

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal indentexpr=GetFishIndent(v:lnum)
setlocal indentkeys+==end,=else,=case

let b:undo_indent = "setlocal indentexpr< indentkeys<"

function s:PrevCmdStart(linenum)
    let l:linenum = a:linenum
    " look for the first line that isn't a line continuation
    while l:linenum > 1 && getline(l:linenum - 1) =~# '\\$'
        let l:linenum = l:linenum - 1
    endwhile
    return l:linenum
endfunction

function GetFishIndent(lnum)
    let l:shiftwidth = shiftwidth()

    let l:prevlnum = prevnonblank(a:lnum - 1)
    if l:prevlnum ==# 0
        return 0
    endif

    " if the previous line ended with a line continuation
    if getline(a:lnum - 1) =~# '\\$'
        if a:lnum ==# 0 || getline(a:lnum - 2) !~# '\\$'
            " this is the first line continuation in a chain, so indent it
            return indent(a:lnum - 1) + l:shiftwidth
        else
            " use the same indentation as the previous continued line
            return indent(a:lnum - 1)
        endif
    endif

    let l:prevlnum = s:PrevCmdStart(l:prevlnum)

    let l:prevline = getline(l:prevlnum)
    if l:prevline =~# '^\s*\(begin\|if\|else\|while\|for\|function\|case\|switch\)\>'
        let l:indent = l:shiftwidth
    else
        let l:indent = 0
    endif

    let l:line = getline(a:lnum)
    if l:line =~# '^\s*end\>'
        " find end's matching start
        let l:depth = 1
        let l:currentlnum = a:lnum
        while l:depth > 0 && l:currentlnum > 0
            let l:currentlnum = s:PrevCmdStart(prevnonblank(l:currentlnum - 1))
            let l:currentline = getline(l:currentlnum)
            if l:currentline =~# '^\s*end\>'
                let l:depth = l:depth + 1
            elseif l:currentline =~# '^\s*\(begin\|if\|while\|for\|function\|switch\)\>'
                let l:depth = l:depth - 1
            endif
        endwhile
        if l:currentline =~# '^\s*switch\>'
            return indent(l:currentlnum)
        else
            return indent(l:prevlnum) + l:indent - l:shiftwidth
        endif
    elseif l:line =~# '^\s*else\>'
        return indent(l:prevlnum) + l:indent - l:shiftwidth
    elseif l:line =~# '^\s*case\>'
        if getline(l:prevlnum) =~# '^\s*switch\>'
            return indent(l:prevlnum) + l:indent
        else
            return indent(l:prevlnum) + l:indent - l:shiftwidth
        endif
    else
        return indent(l:prevlnum) + l:indent
    endif
endfunction
