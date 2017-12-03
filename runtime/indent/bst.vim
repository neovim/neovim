" Vim indent file
" Language:	bst
" Author:	Tim Pope <vimNOSPAM@tpope.info>
" $Id: bst.vim,v 1.1 2007/05/05 18:11:12 vimboss Exp $

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal expandtab
setlocal indentexpr=GetBstIndent(v:lnum)
"setlocal smartindent
setlocal cinkeys&
setlocal cinkeys-=0#
setlocal indentkeys&
"setlocal indentkeys+=0%

" Only define the function once.
if exists("*GetBstIndent")
    finish
endif

function! s:prevgood(lnum)
    " Find a non-blank line above the current line.
    " Skip over comments.
    let lnum = a:lnum
    while lnum > 0
        let lnum = prevnonblank(lnum - 1)
        if getline(lnum) !~ '^\s*%.*$'
            break
        endif
    endwhile
    return lnum
endfunction

function! s:strip(lnum)
    let line = getline(a:lnum)
    let line = substitute(line,'"[^"]*"','""','g')
    let line = substitute(line,'%.*','','')
    let line = substitute(line,'^\s\+','','')
    return line
endfunction

function! s:count(string,char)
    let str = substitute(a:string,'[^'.a:char.']','','g')
    return strlen(str)
endfunction

function! GetBstIndent(lnum) abort
    if a:lnum == 1
        return 0
    endif
    let lnum = s:prevgood(a:lnum)
    if lnum <= 0
        return indent(a:lnum - 1)
    endif
    let line = s:strip(lnum)
    let cline = s:strip(a:lnum)
    if cline =~ '^}' && exists("b:current_syntax")
        call cursor(a:lnum,indent(a:lnum))
        if searchpair('{','','}','bW',"synIDattr(synID(line('.'),col('.'),1),'name') =~? 'comment\\|string'")
            if col('.')+1 == col('$')
                return indent('.')
            else
                return virtcol('.')-1
            endif
        endif
    endif
    let fakeline = substitute(line,'^}','','').matchstr(cline,'^}')
    let ind = indent(lnum)
    let ind = ind + shiftwidth() * s:count(line,'{')
    let ind = ind - shiftwidth() * s:count(fakeline,'}')
    return ind
endfunction
