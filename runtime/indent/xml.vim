"     Language: xml
"   Repository: https://github.com/chrisbra/vim-xml-ftplugin
" Last Changed: Jan 28, 2019
"   Maintainer: Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Johannes Zellner <johannes@zellner.org>
" Last Change:
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
fun! <SID>XmlIndentSum(lnum, style, add)
    let line = getline(a:lnum)
    if a:style == match(line, '^\s*</')
        return (shiftwidth() *
        \  (<SID>XmlIndentWithPattern(line, b:xml_indent_open)
        \ - <SID>XmlIndentWithPattern(line, b:xml_indent_close)
        \ - <SID>XmlIndentWithPattern(line, '.\{-}/>'))) + a:add
    else
        return a:add
    endif
endfun

" Main indent function
fun! XmlIndentGet(lnum, use_syntax_check)
    " Find a non-empty line above the current line.
    let plnum = prevnonblank(a:lnum - 1)
    " Hit the start of the file, use zero indent.
    if plnum == 0
        return 0
    endif
    " Find previous line with a tag (regardless whether open or closed,
    " but always start restrict the match to a line before the current one
    let ptag_pattern = '\%(.\{-}<[/:A-Z_a-z]\)'. '\%(\&\%<'. line('.').'l\)'
    let ptag = search(ptag_pattern, 'bnw')

    let syn_name = ''
    if a:use_syntax_check
        let check_lnum = <SID>XmlIndentSynCheck(plnum)
        let check_alnum = <SID>XmlIndentSynCheck(a:lnum)
        if check_lnum == 0 || check_alnum == 0
            return indent(a:lnum)
        endif
        let syn_name = synIDattr(synID(a:lnum, strlen(getline(a:lnum)) - 1, 1), 'name')
    endif

    if syn_name =~ 'Comment'
        return <SID>XmlIndentComment(a:lnum)
    endif

    " Get indent from previous tag line
    let ind = <SID>XmlIndentSum(ptag, -1, indent(ptag))
    " Determine indent from current line
    let ind = <SID>XmlIndentSum(a:lnum, 0, ind)
    return ind
endfun

" return indent for a commented line,
" the middle part might be indented on additional level
func! <SID>XmlIndentComment(lnum)
    let ptagopen = search(b:xml_indent_open, 'bnw')
    let ptagclose = search(b:xml_indent_close, 'bnw')
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
        return indent(search('<!--', 'bnw'))
    else
        " middle part of comment, add one additional level
        return indent(search('<!--', 'bnw')) + shiftwidth()
    endif
endfunc

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:ts=4 et sts=-1 sw=0
