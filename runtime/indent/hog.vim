" Vim indent file
" Language:     hog (Snort.conf)
" Maintainer:   Victor Roemer, <vroemer@badsec.org>
" Last Change:  Mar 7, 2013

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1
let b:undo_indent = 'setlocal smartindent< indentexpr< indentkeys<'

setlocal nosmartindent
setlocal indentexpr=GetHogIndent()
setlocal indentkeys+=!^F,o,O,0#

" Only define the function once.
if exists("*GetHogIndent")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:syn_blocks = '\<SnortRuleTypeBody\>'

function s:IsInBlock(lnum)
    return synIDattr(synID(a:lnum, 1, 1), 'name') =~ s:syn_blocks 
endfunction

function GetHogIndent()
    let prevlnum = prevnonblank(v:lnum-1)

    " Comment blocks have identical indent
    if getline(v:lnum) =~ '^\s*#' && getline(prevlnum) =~ '^\s*#'
            return indent(prevlnum)
    endif

    " Ignore comment lines when calculating indent
    while getline(prevlnum) =~ '^\s*#'
        let prevlnum = prevnonblank(prevlnum-1)
        if !prevlnum
            return previndent
        endif
    endwhile

    " Continuation of a line that wasn't indented
    let prevline = getline(prevlnum)
    if prevline =~ '^\k\+.*\\\s*$'
        return &sw 
    endif

    " Continuation of a line that was indented
    if prevline =~ '\k\+.*\\\s*$'
        return indent(prevlnum)
    endif

    " Indent the next line if previous line contained a start of a block
    " definition ('{' or '(').
    if prevline =~ '^\k\+[^#]*{}\@!\s*$' " TODO || prevline =~ '^\k\+[^#]*()\@!\s*$'
        return &sw
    endif

    " Match inside of a block
    if s:IsInBlock(v:lnum)
        if prevline =~ "^\k\+.*$"
            return &sw
        else
            return indent(prevlnum)
        endif
    endif

    return 0 
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
