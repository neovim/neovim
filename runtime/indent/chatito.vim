" Vim indent file
" Language:	Chatito
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Last Change:	2022 Sep 20

if exists('b:did_indent')
    finish
endif
let b:did_indent = 1

setlocal indentexpr=GetChatitoIndent()
setlocal indentkeys=o,O,*<Return>,0#,!^F

let b:undo_indent = 'setl inde< indk<'

if exists('*GetChatitoIndent')
    finish
endif

function GetChatitoIndent()
    let l:prev = v:lnum - 1
    if getline(prevnonblank(l:prev)) =~# '^[~%@]\['
        " shift indent after definitions
        return shiftwidth()
    elseif getline(l:prev) !~# '^\s*$'
        " maintain indent in sentences
        return indent(l:prev)
    else
        " reset indent after a blank line
        return 0
    end
endfunction
