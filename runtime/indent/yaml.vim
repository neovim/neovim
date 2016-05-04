" Vim indent file
" Language:         YAML
" Maintainer:       Nikolai Pavlov <zyx.vim@gmail.com>
" Last Change:	    2015 Nov 01

" Only load this indent file when no other was loaded.
if exists('b:did_indent')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

let b:did_indent = 1

setlocal indentexpr=GetYAMLIndent(v:lnum)
setlocal indentkeys=!^F,o,O,0#,0},0],<:>,0-
setlocal nosmartindent

let b:undo_indent = 'setlocal indentexpr< indentkeys< smartindent<'

" Only define the function once.
if exists('*GetYAMLIndent')
    finish
endif

if exists('*shiftwidth')
    let s:shiftwidth = function('shiftwidth')
else
    function s:shiftwidth()
        return &shiftwidth
    endfunction
endif

function s:FindPrevLessIndentedLine(lnum, ...)
    let prevlnum = prevnonblank(a:lnum-1)
    let curindent = a:0 ? a:1 : indent(a:lnum)
    while           prevlnum
                \&&  indent(prevlnum) >=  curindent
                \&& getline(prevlnum) !~# '^\s*#'
        let prevlnum = prevnonblank(prevlnum-1)
    endwhile
    return prevlnum
endfunction

function s:FindPrevLEIndentedLineMatchingRegex(lnum, regex)
    let plilnum = s:FindPrevLessIndentedLine(a:lnum, indent(a:lnum)+1)
    while plilnum && getline(plilnum) !~# a:regex
        let plilnum = s:FindPrevLessIndentedLine(plilnum)
    endwhile
    return plilnum
endfunction

let s:mapkeyregex='\v^\s*%(\''%([^'']|'''')*\'''.
                \        '|\"%([^"\\]|\\.)*\"'.
                \        '|%(%(\:\ )@!.)*)\:%(\ |$)'
let s:liststartregex='\v^\s*%(\-%(\ |$))'

function GetYAMLIndent(lnum)
    if a:lnum == 1 || !prevnonblank(a:lnum-1)
        return 0
    endif

    let prevlnum = prevnonblank(a:lnum-1)
    let previndent = indent(prevlnum)

    let line = getline(a:lnum)
    if line =~# '^\s*#' && getline(a:lnum-1) =~# '^\s*#'
        " Comment blocks should have identical indent
        return previndent
    elseif line =~# '^\s*[\]}]'
        " Lines containing only closing braces should have previous indent
        return indent(s:FindPrevLessIndentedLine(a:lnum))
    endif

    " Ignore comment lines when calculating indent
    while getline(prevlnum) =~# '^\s*#'
        let prevlnum = prevnonblank(prevlnum-1)
        if !prevlnum
            return previndent
        endif
    endwhile

    let prevline = getline(prevlnum)
    let previndent = indent(prevlnum)

    " Any examples below assume that shiftwidth=2
    if prevline =~# '\v[{[:]$|[:-]\ [|>][+\-]?%(\s+\#.*|\s*)$'
        " Mapping key:
        "     nested mapping: ...
        "
        " - {
        "     key: [
        "         list value
        "     ]
        " }
        "
        " - |-
        "     Block scalar without indentation indicator
        return previndent+s:shiftwidth()
    elseif prevline =~# '\v[:-]\ [|>]%(\d+[+\-]?|[+\-]?\d+)%(\#.*|\s*)$'
        " - |+2
        "   block scalar with indentation indicator
        "#^^ indent+2, not indent+shiftwidth
        return previndent + str2nr(matchstr(prevline,
                    \'\v([:-]\ [|>])@<=[+\-]?\d+%([+\-]?%(\s+\#.*|\s*)$)@='))
    elseif prevline =~# '\v\"%([^"\\]|\\.)*\\$'
        "    "Multiline string \
        "     with escaped end"
        let qidx = match(prevline, '\v\"%([^"\\]|\\.)*\\')
        return virtcol([prevlnum, qidx+1])
    elseif line =~# s:liststartregex
        " List line should have indent equal to previous list line unless it was 
        " caught by one of the previous rules
        return indent(s:FindPrevLEIndentedLineMatchingRegex(a:lnum,
                    \                                       s:liststartregex))
    elseif line =~# s:mapkeyregex
        " Same for line containing mapping key
        let prevmapline = s:FindPrevLEIndentedLineMatchingRegex(a:lnum,
                    \                                           s:mapkeyregex)
        if getline(prevmapline) =~# '^\s*- '
            return indent(prevmapline) + 2
        else
            return indent(prevmapline)
        endif
    elseif prevline =~# '^\s*- '
        " - List with
        "   multiline scalar
        return previndent+2
    elseif prevline =~# s:mapkeyregex
        " Mapping with: value
        "     that is multiline scalar
        return previndent+s:shiftwidth()
    endif
    return previndent
endfunction

let &cpo = s:save_cpo
