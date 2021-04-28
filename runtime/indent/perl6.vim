" Vim indent file
" Language:      Perl 6
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" Last Change:   2020 Apr 15
" Contributors:  Andy Lester <andy@petdance.com>
"                Hinrik Örn Sigurðsson <hinrik.sig@gmail.com>
"
" Adapted from indent/perl.vim by Rafael Garcia-Suarez <rgarciasuarez@free.fr>

" Suggestions and improvements by :
"   Aaron J. Sherman (use syntax for hints)
"   Artem Chuprina (play nice with folding)
" TODO:
" This file still relies on stuff from the Perl 5 syntax file, which Perl 6
" does not use.
"
" Things that are not or not properly indented (yet) :
" - Continued statements
"     print "foo",
"       "bar";
"     print "foo"
"       if bar();
" - Multiline regular expressions (m//x)
" (The following probably needs modifying the perl syntax file)
" - qw() lists
" - Heredocs with terminators that don't match \I\i*

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

" Is syntax highlighting active ?
let b:indent_use_syntax = has("syntax")

setlocal indentexpr=GetPerl6Indent()

" we reset it first because the Perl 5 indent file might have been loaded due
" to a .pl/pm file extension, and indent files don't clean up afterwards
setlocal indentkeys&

setlocal indentkeys+=0=,0),0],0>,0»,0=or,0=and
if !b:indent_use_syntax
    setlocal indentkeys+=0=EO
endif

let s:cpo_save = &cpo
set cpo-=C

function! GetPerl6Indent()

    " Get the line to be indented
    let cline = getline(v:lnum)

    " Indent POD markers to column 0
    if cline =~ '^\s*=\L\@!'
        return 0
    endif

    " Don't reindent coments on first column
    if cline =~ '^#'
        return 0
    endif

    " Get current syntax item at the line's first char
    let csynid = ''
    if b:indent_use_syntax
        let csynid = synIDattr(synID(v:lnum,1,0),"name")
    endif

    " Don't reindent POD and heredocs
    if csynid =~ "^p6Pod"
        return indent(v:lnum)
    endif


    " Now get the indent of the previous perl line.

    " Find a non-blank line above the current line.
    let lnum = prevnonblank(v:lnum - 1)
    " Hit the start of the file, use zero indent.
    if lnum == 0
        return 0
    endif
    let line = getline(lnum)
    let ind = indent(lnum)
    " Skip heredocs, POD, and comments on 1st column
    if b:indent_use_syntax
        let skippin = 2
        while skippin
            let synid = synIDattr(synID(lnum,1,0),"name")
            if (synid =~ "^p6Pod" || synid =~ "p6Comment")
                let lnum = prevnonblank(lnum - 1)
                if lnum == 0
                    return 0
                endif
                let line = getline(lnum)
                let ind = indent(lnum)
                let skippin = 1
            else
                let skippin = 0
            endif
        endwhile
    endif

        if line =~ '[<«\[{(]\s*\(#[^)}\]»>]*\)\=$'
            let ind = ind + shiftwidth()
        endif
        if cline =~ '^\s*[)}\]»>]'
            let ind = ind - shiftwidth()
        endif

    " Indent lines that begin with 'or' or 'and'
    if cline =~ '^\s*\(or\|and\)\>'
        if line !~ '^\s*\(or\|and\)\>'
            let ind = ind + shiftwidth()
        endif
    elseif line =~ '^\s*\(or\|and\)\>'
        let ind = ind - shiftwidth()
    endif

    return ind

endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:ts=8:sts=4:sw=4:expandtab:ft=vim
