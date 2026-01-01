" Vim indent file
" Language:      Perl
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2022 Jun 14

" Suggestions and improvements by :
"   Aaron J. Sherman (use syntax for hints)
"   Artem Chuprina (play nice with folding)

" TODO things that are not or not properly indented (yet) :
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

setlocal indentexpr=GetPerlIndent()
setlocal indentkeys+=0=,0),0],0=or,0=and
if !b:indent_use_syntax
    setlocal indentkeys+=0=EO
endif

let b:undo_indent = "setl inde< indk<"

let s:cpo_save = &cpo
set cpo-=C

function! GetPerlIndent()

    " Get the line to be indented
    let cline = getline(v:lnum)

    " Indent POD markers to column 0
    if cline =~ '^\s*=\L\@!'
        return 0
    endif

    " Get current syntax item at the line's first char
    let csynid = ''
    if b:indent_use_syntax
        let csynid = synIDattr(synID(v:lnum,1,0),"name")
    endif

    " Don't reindent POD and heredocs
    if csynid == "perlPOD" || csynid == "perlHereDoc" || csynid =~ "^pod"
        return indent(v:lnum)
    endif

    " Indent end-of-heredocs markers to column 0
    if b:indent_use_syntax
        " Assumes that an end-of-heredoc marker matches \I\i* to avoid
        " confusion with other types of strings
        if csynid == "perlStringStartEnd" && cline =~ '^\I\i*$'
            return 0
        endif
    else
        " Without syntax hints, assume that end-of-heredocs markers begin with EO
        if cline =~ '^\s*EO'
            return 0
        endif
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
            if (synid == "perlStringStartEnd" && line =~ '^\I\i*$')
                        \ || (skippin != 2 && synid == "perlPOD")
                        \ || (skippin != 2 && synid == "perlHereDoc")
                        \ || synid == "perlComment"
                        \ || synid =~ "^pod"
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
    else
        if line =~ "^EO"
            let lnum = search("<<[\"']\\=EO", "bW")
            let line = getline(lnum)
            let ind = indent(lnum)
        endif
    endif

    " Indent blocks enclosed by {}, (), or []
    if b:indent_use_syntax
        " Find a real opening brace
        " NOTE: Unlike Perl character classes, we do NOT need to escape the
        " closing brackets with a backslash.  Doing so just puts a backslash
        " in the character class and causes sorrow.  Instead, put the closing
        " bracket as the first character in the class.
        let braceclass = '[][(){}]'
        let bracepos = match(line, braceclass, matchend(line, '^\s*[])}]'))
        while bracepos != -1
            let synid = synIDattr(synID(lnum, bracepos + 1, 0), "name")
            " If the brace is highlighted in one of those groups, indent it.
            " 'perlHereDoc' is here only to handle the case '&foo(<<EOF)'.
            if synid == ""
                        \ || synid == "perlMatchStartEnd"
                        \ || synid == "perlHereDoc"
                        \ || synid == "perlBraces"
                        \ || synid == "perlStatementIndirObj"
                        \ || synid == "perlSubDeclaration"
                        \ || synid =~ "^perlFiledescStatement"
                        \ || synid =~ '^perl\(Sub\|Block\|Package\)Fold'
                let brace = strpart(line, bracepos, 1)
                if brace == '(' || brace == '{' || brace == '['
                    let ind = ind + shiftwidth()
                else
                    let ind = ind - shiftwidth()
                endif
            endif
            let bracepos = match(line, braceclass, bracepos + 1)
        endwhile
        let bracepos = matchend(cline, '^\s*[])}]')
        if bracepos != -1
            let synid = synIDattr(synID(v:lnum, bracepos, 0), "name")
            if synid == ""
                        \ || synid == "perlMatchStartEnd"
                        \ || synid == "perlBraces"
                        \ || synid == "perlStatementIndirObj"
                        \ || synid =~ '^perl\(Sub\|Block\|Package\)Fold'
                let ind = ind - shiftwidth()
            endif
        endif
    else
        if line =~ '[{[(]\s*\(#[^])}]*\)\=$'
            let ind = ind + shiftwidth()
        endif
        if cline =~ '^\s*[])}]'
            let ind = ind - shiftwidth()
        endif
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
