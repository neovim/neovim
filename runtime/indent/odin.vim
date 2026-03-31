" Vim indent plugin file
" Language: Odin
" Maintainer: Maxim Kim <habamax@gmail.com>
" Website: https://github.com/habamax/vim-odin
" Last Change: 2024-01-15
"
" This file has been manually translated from Vim9 script.

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_indent = 'setlocal cindent< cinoptions< cinkeys< indentexpr<'

setlocal cindent
setlocal cinoptions=L0,m1,(s,j1,J1,l1,+0,:0,#1
setlocal cinkeys=0{,0},0),0],!^F,:,o,O

setlocal indentexpr=s:GetOdinIndent(v:lnum)

function s:PrevLine(lnum) abort
    let plnum = a:lnum - 1
    while plnum > 1
        let plnum = prevnonblank(plnum)
        let pline = getline(plnum)
        " XXX: take into account nested multiline /* /* */ */ comments
        if pline =~# '\*/\s*$'
            while getline(plnum) !~# '/\*' && plnum > 1
                let plnum -= 1
            endwhile
            if getline(plnum) =~# '^\s*/\*'
                let plnum -= 1
            else
                break
            endif
        elseif pline =~# '^\s*//'
            let plnum -= 1
        else
            break
        endif
    endwhile
    return plnum
endfunction

function s:GetOdinIndent(lnum) abort
    let plnum = s:PrevLine(a:lnum)
    let pline = getline(plnum)
    let pindent = indent(plnum)
    " workaround of cindent "hang"
    " if the previous line looks like:
    " : #{}
    " : #whatever{whateverelse}
    " and variations where : # { } are in the string
    " cindent(lnum) hangs
    if pline =~# ':\s\+#.*{.*}'
        return pindent
    endif

    let indent = cindent(a:lnum)
    let line = getline(a:lnum)

    if line =~# '^\s*#\k\+'
        if pline =~# '[{:]\s*$'
            let indent = pindent + shiftwidth()
        else
            let indent = pindent
        endif
    elseif pline =~# 'switch\s.*{\s*$'
        let indent = pindent
    elseif pline =~# 'case\s*.*,\s*\(//.*\)\?$' " https://github.com/habamax/vim-odin/issues/8
        let indent = pindent + matchstr(pline, 'case\s*')->strcharlen()
    elseif line =~# '^\s*case\s\+.*,\s*$'
        let indent = pindent - shiftwidth()
    elseif pline =~# 'case\s*.*:\s*\(//.*\)\?$'
        if line !~# '^\s*}\s*$' && line !~# '^\s*case[[:space:]:]'
            let indent = pindent + shiftwidth()
        endif
    elseif pline =~# '^\s*@.*' && line !~# '^\s*}'
        let indent = pindent
    elseif pline =~# ':[:=].*}\s*$'
        let indent = pindent
    elseif pline =~# '^\s*}\s*$'
        if line !~# '^\s*}' && line !~# 'case\s*.*:\s*$'
            let indent = pindent
        else
            let indent = pindent - shiftwidth()
        endif
    elseif pline =~# '\S:\s*$'
        " looking up for a case something,
        "                       whatever,
        "                       anything:
        " ... 20 lines before
        for idx in range(plnum - 1, plnum - 21, -1)
            if plnum < 1
                break
            endif
            if getline(idx) =~# '^\s*case\s.*,\s*$'
                let indent = indent(idx) + shiftwidth()
                break
            endif
        endfor
    elseif pline =~# '{[^{]*}\s*$' && line !~# '^\s*[})]\s*$' " https://github.com/habamax/vim-odin/issues/2
        let indent = pindent
    elseif pline =~# '^\s*}\s*$' " https://github.com/habamax/vim-odin/issues/3
        " Find line with opening { and check if there is a label:
        " If there is, return indent of the closing }
        call cursor(plnum, 1)
        silent normal! %
        let brlnum = line('.')
        let brline = getline('.')
        if plnum != brlnum && (brline =~# '^\s*\k\+:\s\+for' || brline =~# '^\s*\k\+\s*:=')
            let indent = pindent
        endif
    endif

    return indent
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
