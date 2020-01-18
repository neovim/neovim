"     Language: xml
"   Repository: https://github.com/chrisbra/vim-xml-ftplugin
" Last Changed: July 27, 2019
"   Maintainer: Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Johannes Zellner <johannes@zellner.org>
" Last Change:
" 20190726 - Correctly handle non-tagged data
" 20190204 - correctly handle wrap tags
"            https://github.com/chrisbra/vim-xml-ftplugin/issues/5
" 20190128 - Make sure to find previous tag
"            https://github.com/chrisbra/vim-xml-ftplugin/issues/4
" 20181116 - Fix indentation when tags start with a colon or an underscore
"            https://github.com/vim/vim/pull/926
" 20181022 - Do not overwrite indentkeys setting
"            https://github.com/chrisbra/vim-xml-ftplugin/issues/1
" 20180724 - Correctly indent xml comments https://github.com/vim/vim/issues/3200
"
" Notes:
"   1) does not indent pure non-xml code (e.g. embedded scripts)
"       2) will be confused by unbalanced tags in comments
"       or CDATA sections.
"       2009-05-26 patch by Nikolai Weibull
" TODO:     implement pre-like tags, see xml_indent_open / xml_indent_close

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1
let s:keepcpo= &cpo
set cpo&vim

" [-- local settings (must come before aborting the script) --]
" Attention: Parameter use_syntax_check is used by the docbk.vim indent script
setlocal indentexpr=XmlIndentGet(v:lnum,1)
setlocal indentkeys=o,O,*<Return>,<>>,<<>,/,{,},!^F
" autoindent: used when the indentexpr returns -1
setlocal autoindent

if !exists('b:xml_indent_open')
    let b:xml_indent_open = '.\{-}<[:A-Z_a-z]'
    " pre tag, e.g. <address>
    " let b:xml_indent_open = '.\{-}<[/]\@!\(address\)\@!'
endif

if !exists('b:xml_indent_close')
    let b:xml_indent_close = '.\{-}</'
    " end pre tag, e.g. </address>
    " let b:xml_indent_close = '.\{-}</\(address\)\@!'
endif

let &cpo = s:keepcpo
unlet s:keepcpo

" [-- finish, if the function already exists --]
if exists('*XmlIndentGet')
    finish
endif

let s:keepcpo= &cpo
set cpo&vim

fun! <SID>XmlIndentWithPattern(line, pat)
    let s = substitute('x'.a:line, a:pat, "\1", 'g')
    return strlen(substitute(s, "[^\1].*$", '', ''))
endfun

" [-- check if it's xml --]
fun! <SID>XmlIndentSynCheck(lnum)
    if &syntax != ''
        let syn1 = synIDattr(synID(a:lnum, 1, 1), 'name')
        let syn2 = synIDattr(synID(a:lnum, strlen(getline(a:lnum)) - 1, 1), 'name')
        if syn1 != '' && syn1 !~ 'xml' && syn2 != '' && syn2 !~ 'xml'
            " don't indent pure non-xml code
            return 0
        endif
    endif
    return 1
endfun

" [-- return the sum of indents of a:lnum --]
fun! <SID>XmlIndentSum(line, style, add)
    if <SID>IsXMLContinuation(a:line) && a:style == 0
        " no complete tag, add one additional indent level
        " but only for the current line
        return a:add + shiftwidth()
    elseif <SID>HasNoTagEnd(a:line)
        " no complete tag, return initial indent
        return a:add
    endif
    if a:style == match(a:line, '^\s*</')
        return (shiftwidth() *
        \  (<SID>XmlIndentWithPattern(a:line, b:xml_indent_open)
        \ - <SID>XmlIndentWithPattern(a:line, b:xml_indent_close)
        \ - <SID>XmlIndentWithPattern(a:line, '.\{-}/>'))) + a:add
    else
        return a:add
    endif
endfun

" Main indent function
fun! XmlIndentGet(lnum, use_syntax_check)
    " Find a non-empty line above the current line.
    if prevnonblank(a:lnum - 1) == 0
        " Hit the start of the file, use zero indent.
        return 0
    endif
    " Find previous line with a tag (regardless whether open or closed,
    " but always restrict the match to a line before the current one
    " Note: xml declaration: <?xml version="1.0"?>
    "       won't be found, as it is not a legal tag name
    let ptag_pattern = '\%(.\{-}<[/:A-Z_a-z]\)'. '\%(\&\%<'. a:lnum .'l\)'
    let ptag = search(ptag_pattern, 'bnW')
    " no previous tag
    if ptag == 0
        return 0
    endif

    let pline = getline(ptag)
    let pind  = indent(ptag)

    let syn_name_start = '' " Syntax element at start of line (excluding whitespace)
    let syn_name_end = ''   " Syntax element at end of line
    let curline = getline(a:lnum)
    if a:use_syntax_check
        let check_lnum = <SID>XmlIndentSynCheck(ptag)
        let check_alnum = <SID>XmlIndentSynCheck(a:lnum)
        if check_lnum == 0 || check_alnum == 0
            return indent(a:lnum)
        endif
        let syn_name_end   = synIDattr(synID(a:lnum, strlen(curline) - 1, 1), 'name')
        let syn_name_start = synIDattr(synID(a:lnum, match(curline, '\S') + 1, 1), 'name')
    endif

    if syn_name_end =~ 'Comment' && syn_name_start =~ 'Comment'
        return <SID>XmlIndentComment(a:lnum)
    elseif empty(syn_name_start) && empty(syn_name_end)
        " non-xml tag content: use indent from 'autoindent'
        return pind + shiftwidth()
    endif

    " Get indent from previous tag line
    let ind = <SID>XmlIndentSum(pline, -1, pind)
    " Determine indent from current line
    let ind = <SID>XmlIndentSum(curline, 0, ind)
    return ind
endfun

func! <SID>IsXMLContinuation(line)
    " Checks, whether or not the line matches a start-of-tag
    return a:line !~ '^\s*<'
endfunc

func! <SID>HasNoTagEnd(line)
    " Checks whether or not the line matches '>' (so finishes a tag)
    return a:line !~ '>\s*$'
endfunc

" return indent for a commented line,
" the middle part might be indented one additional level
func! <SID>XmlIndentComment(lnum)
    let ptagopen = search(b:xml_indent_open, 'bnW')
    let ptagclose = search(b:xml_indent_close, 'bnW')
    if getline(a:lnum) =~ '<!--'
        " if previous tag was a closing tag, do not add
        " one additional level of indent
        if ptagclose > ptagopen && a:lnum > ptagclose
            return indent(ptagclose)
        else
            " start of comment, add one indentation level
            return indent(ptagopen) + shiftwidth()
        endif
    elseif getline(a:lnum) =~ '-->'
        " end of comment, same as start of comment
        return indent(search('<!--', 'bnW'))
    else
        " middle part of comment, add one additional level
        return indent(search('<!--', 'bnW')) + shiftwidth()
    endif
endfunc

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:ts=4 et sts=-1 sw=0
