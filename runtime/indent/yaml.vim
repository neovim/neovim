" Vim indent file
" Language:	YAML
" Maintainer:	Nikolai Pavlov <zyx.vim@gmail.com>
" Last Update:	Lukas Reineke
" Last Change:	2021 Aug 13

" Only load this indent file when no other was loaded.
if exists('b:did_indent')
  finish
endif

let b:did_indent = 1

setlocal indentexpr=GetYAMLIndent(v:lnum)
setlocal indentkeys=!^F,o,O,0#,0},0],<:>,0-
setlocal nosmartindent

let b:undo_indent = 'setlocal indentexpr< indentkeys< smartindent<'

" Only define the function once.
if exists('*GetYAMLIndent')
    finish
endif

let s:save_cpo = &cpo
set cpo&vim

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

let s:mapkeyregex='\v^\s*\#@!\S@=%(\''%([^'']|\''\'')*\'''.
                \                 '|\"%([^"\\]|\\.)*\"'.
                \                 '|%(%(\:\ )@!.)*)\:%(\ |$)'
let s:liststartregex='\v^\s*%(\-%(\ |$))'

let s:c_ns_anchor_char = '\v%([\n\r\uFEFF \t,[\]{}]@!\p)'
let s:c_ns_anchor_name = s:c_ns_anchor_char.'+'
let s:c_ns_anchor_property =  '\v\&'.s:c_ns_anchor_name

let s:ns_word_char = '\v[[:alnum:]_\-]'
let s:ns_tag_char  = '\v%('.s:ns_word_char.'|[#/;?:@&=+$.~*''()])'
let s:c_named_tag_handle     = '\v\!'.s:ns_word_char.'+\!'
let s:c_secondary_tag_handle = '\v\!\!'
let s:c_primary_tag_handle   = '\v\!'
let s:c_tag_handle = '\v%('.s:c_named_tag_handle.
            \            '|'.s:c_secondary_tag_handle.
            \            '|'.s:c_primary_tag_handle.')'
let s:c_ns_shorthand_tag = '\v'.s:c_tag_handle . s:ns_tag_char.'+'
let s:c_non_specific_tag = '\v\!'
let s:ns_uri_char  = '\v%('.s:ns_word_char.'\v|[#/;?:@&=+$,.!~*''()[\]])'
let s:c_verbatim_tag = '\v\!\<'.s:ns_uri_char.'+\>'
let s:c_ns_tag_property = '\v'.s:c_verbatim_tag.
            \               '\v|'.s:c_ns_shorthand_tag.
            \               '\v|'.s:c_non_specific_tag

let s:block_scalar_header = '\v[|>]%([+-]?[1-9]|[1-9]?[+-])?'

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
        return previndent+shiftwidth()
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
    elseif prevline =~# s:mapkeyregex . '\v\s*%(%('.s:c_ns_tag_property.
                \                              '\v|'.s:c_ns_anchor_property.
                \                              '\v|'.s:block_scalar_header.
                \                             '\v)%(\s+|\s*%(\#.*)?$))*'
        " Mapping with: value
        "     that is multiline scalar
        return previndent+shiftwidth()
    endif
    return previndent
endfunction

let &cpo = s:save_cpo
