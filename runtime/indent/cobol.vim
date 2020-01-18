" Vim indent file
" Language:	cobol
" Maintainer: Ankit Jain <ajatkj@yahoo.co.in>
"     (formerly Tim Pope <vimNOSPAM@tpope.info>)
" $Id: cobol.vim,v 1.1 2007/05/05 18:08:19 vimboss Exp $
" Last Update:	By Ankit Jain on 22.03.2019
" Ankit Jain      22.03.2019     Changes & fixes:
"                                Allow chars in 1st 6 columns
"                                #C22032019

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal expandtab
setlocal indentexpr=GetCobolIndent(v:lnum)
setlocal indentkeys&
setlocal indentkeys+=0<*>,0/,0$,0=01,=~division,=~section,0=~end,0=~then,0=~else,0=~when,*<Return>,.

" Only define the function once.
if exists("*GetCobolIndent")
    finish
endif

let s:skip = 'getline(".") =~ "^.\\{6\\}[*/$-]\\|\"[^\"]*\""'

function! s:prevgood(lnum)
    " Find a non-blank line above the current line.
    " Skip over comments.
    let lnum = a:lnum
    while lnum > 0
        let lnum = prevnonblank(lnum - 1)
        let line = getline(lnum)
        if line !~? '^\s*[*/$-]' && line !~? '^.\{6\}[*/$CD-]'
            break
        endif
    endwhile
    return lnum
endfunction

function! s:stripped(lnum)
    return substitute(strpart(getline(a:lnum),0,72),'^\s*','','')
endfunction

function! s:optionalblock(lnum,ind,blocks,clauses)
    let ind = a:ind
    let clauses = '\c\<\%(\<NOT\s\+\)\@<!\%(NOT\s\+\)\=\%('.a:clauses.'\)'
    let begin = '\c-\@<!\<\%('.a:blocks.'\)\>'
    let beginfull = begin.'\ze.*\%(\n\%(\s*\%([*/$-].*\)\=\n\)*\)\=\s*\%('.clauses.'\)'
    let end   = '\c\<end-\%('.a:blocks.'\)\>\|\%(\.\%( \|$\)\)\@='
    let cline = s:stripped(a:lnum)
    let line  = s:stripped(s:prevgood(a:lnum))
    if cline =~? clauses "&& line !~? '^search\>'
        call cursor(a:lnum,1)
        let lastclause = searchpair(beginfull,clauses,end,'bWr',s:skip)
        if getline(lastclause) =~? clauses && s:stripped(lastclause) !~? '^'.begin
            let ind = indent(lastclause)
        elseif lastclause > 0
            let ind = indent(lastclause) + shiftwidth()
            "let ind = ind + shiftwidth()
        endif
    elseif line =~? clauses && cline !~? end
        let ind = ind + shiftwidth()
    endif
    return ind
endfunction

function! GetCobolIndent(lnum) abort
    let minshft = 6
    let ashft = minshft + 1
    let bshft = ashft + 4
    " (Obsolete) numbered lines
    " #C22032019: Columns 1-6 could have alphabets as well as numbers
    "if getline(a:lnum) =~? '^\s*\d\{6\}\%($\|[ */$CD-]\)'
    if getline(a:lnum) =~? '^\s*[a-zA-Z0-9]\{6\}\%($\|[ */$CD-]\)'
        return 0
    endif
    let cline = s:stripped(a:lnum)
    " Comments, etc. must start in the 7th column
    if cline =~? '^[*/$-]'
        return minshft
    elseif cline =~# '^[CD]' && indent(a:lnum) == minshft
        return minshft
    endif
    " Divisions, sections, and file descriptions start in area A
    if cline =~? '\<\(DIVISION\|SECTION\)\%($\|\.\)' || cline =~? '^[FS]D\>'
        return ashft
    endif
    " Fields
    if cline =~? '^0*\(1\|77\)\>'
        return ashft
    endif
    if cline =~? '^\d\+\>'
        let cnum = matchstr(cline,'^\d\+\>')
        let default = 0
        let step = -1
        while step < 2
        let lnum = a:lnum
        while lnum > 0 && lnum < line('$') && lnum > a:lnum - 500 && lnum < a:lnum + 500
            let lnum = step > 0 ? nextnonblank(lnum + step) : prevnonblank(lnum + step)
            let line = getline(lnum)
            let lindent = indent(lnum)
            if line =~? '^\s*\d\+\>'
                let num = matchstr(line,'^\s*\zs\d\+\>')
                if 0+cnum == num
                    return lindent
                elseif 0+cnum > num && default < lindent + shiftwidth()
                    let default = lindent + shiftwidth()
                endif
            elseif lindent < bshft && lindent >= ashft
                break
            endif
        endwhile
        let step = step + 2
        endwhile
        return default ? default : bshft
    endif
    let lnum = s:prevgood(a:lnum)
    " Hit the start of the file, use "zero" indent.
    if lnum == 0
        return ashft
    endif
    " Initial spaces are ignored
    let line = s:stripped(lnum)
    let ind = indent(lnum)
    " Paragraphs.  There may be some false positives.
    if cline =~? '^\(\a[A-Z0-9-]*[A-Z0-9]\|\d[A-Z0-9-]*\a\)\.' "\s*$'
        if cline !~? '^EXIT\s*\.' && line =~? '\.\s*$'
            return ashft
        endif
    endif
    " Paragraphs in the identification division.
    "if cline =~? '^\(PROGRAM-ID\|AUTHOR\|INSTALLATION\|' .
                "\ 'DATE-WRITTEN\|DATE-COMPILED\|SECURITY\)\>'
        "return ashft
    "endif
    if line =~? '\.$'
        " XXX
        return bshft
    endif
    if line =~? '^PERFORM\>'
        let perfline = substitute(line, '\c^PERFORM\s*', "", "")
        if perfline =~? '^\%(\k\+\s\+TIMES\)\=\s*$'
            let ind = ind + shiftwidth()
        elseif perfline =~? '^\%(WITH\s\+TEST\|VARYING\|UNTIL\)\>.*[^.]$'
            let ind = ind + shiftwidth()
        endif
    endif
    if line =~? '^\%(IF\|THEN\|ELSE\|READ\|EVALUATE\|SEARCH\|SELECT\)\>'
        let ind = ind + shiftwidth()
    endif
    let ind = s:optionalblock(a:lnum,ind,'ADD\|COMPUTE\|DIVIDE\|MULTIPLY\|SUBTRACT','ON\s\+SIZE\s\+ERROR')
    let ind = s:optionalblock(a:lnum,ind,'STRING\|UNSTRING\|ACCEPT\|DISPLAY\|CALL','ON\s\+OVERFLOW\|ON\s\+EXCEPTION')
    if cline !~? '^AT\s\+END\>' || line !~? '^SEARCH\>'
        let ind = s:optionalblock(a:lnum,ind,'DELETE\|REWRITE\|START\|WRITE\|READ','INVALID\s\+KEY\|AT\s\+END\|NO\s\+DATA\|AT\s\+END-OF-PAGE')
    endif
    if cline =~? '^WHEN\>'
        call cursor(a:lnum,1)
        " We also search for READ so that contained AT ENDs are skipped
        let lastclause = searchpair('\c-\@<!\<\%(SEARCH\|EVALUATE\|READ\)\>','\c\<\%(WHEN\|AT\s\+END\)\>','\c\<END-\%(SEARCH\|EVALUATE\|READ\)\>','bW',s:skip)
        let g:foo = s:stripped(lastclause)
        if s:stripped(lastclause) =~? '\c\<\%(WHEN\|AT\s\+END\)\>'
            "&& s:stripped(lastclause) !~? '^\%(SEARCH\|EVALUATE\|READ\)\>'
            let ind = indent(lastclause)
        elseif lastclause > 0
            let ind = indent(lastclause) + shiftwidth()
        endif
    elseif line =~? '^WHEN\>'
        let ind = ind + shiftwidth()
    endif
    "I'm not sure why I had this
    "if line =~? '^ELSE\>-\@!' && line !~? '\.$'
        "let ind = indent(s:prevgood(lnum))
    "endif
    if cline =~? '^\(END\)\>-\@!'
        " On lines with just END, 'guess' a simple shift left
        let ind = ind - shiftwidth()
    elseif cline =~? '^\(END-IF\|THEN\|ELSE\)\>-\@!'
        call cursor(a:lnum,indent(a:lnum))
        let match = searchpair('\c-\@<!\<IF\>','\c-\@<!\%(THEN\|ELSE\)\>','\c-\@<!\<END-IF\>\zs','bnW',s:skip)
        if match > 0
            let ind = indent(match)
        endif
    elseif cline =~? '^END-[A-Z]'
        let beginword = matchstr(cline,'\c\<END-\zs[A-Z0-9-]\+')
        let endword = 'END-'.beginword
        let first = 0
        let suffix = '.*\%(\n\%(\%(\s*\|.\{6\}\)[*/].*\n\)*\)\=\s*'
        if beginword =~? '^\%(ADD\|COMPUTE\|DIVIDE\|MULTIPLY\|SUBTRACT\)$'
            let beginword = beginword . suffix . '\<\%(NOT\s\+\)\=ON\s\+SIZE\s\+ERROR'
            let g:beginword = beginword
            let first = 1
        elseif beginword =~? '^\%(STRING\|UNSTRING\)$'
            let beginword = beginword . suffix . '\<\%(NOT\s\+\)\=ON\s\+OVERFLOW'
            let first = 1
        elseif beginword =~? '^\%(ACCEPT\|DISPLAY\)$'
            let beginword = beginword . suffix . '\<\%(NOT\s\+\)\=ON\s\+EXCEPTION'
            let first = 1
        elseif beginword ==? 'CALL'
            let beginword = beginword . suffix . '\<\%(NOT\s\+\)\=ON\s\+\%(EXCEPTION\|OVERFLOW\)'
            let first = 1
        elseif beginword =~? '^\%(DELETE\|REWRITE\|START\|READ\|WRITE\)$'
            let first = 1
            let beginword = beginword . suffix . '\<\%(NOT\s\+\)\=\(INVALID\s\+KEY'
            if beginword =~? '^READ'
                let first = 0
                let beginword = beginword . '\|AT\s\+END\|NO\s\+DATA'
            elseif beginword =~? '^WRITE'
                let beginword = beginword . '\|AT\s\+END-OF-PAGE'
            endif
            let beginword = beginword . '\)'
        endif
        call cursor(a:lnum,indent(a:lnum))
        let match = searchpair('\c-\@<!\<'.beginword.'\>','','\c\<'.endword.'\>\zs','bnW'.(first? 'r' : ''),s:skip)
        if match > 0
            let ind = indent(match)
        elseif cline =~? '^\(END-\(READ\|EVALUATE\|SEARCH\|PERFORM\)\)\>'
            let ind = ind - shiftwidth()
        endif
    endif
    return ind < bshft ? bshft : ind
endfunction
