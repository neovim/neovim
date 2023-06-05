" Vim indent file
" Language:		Device Tree
" Maintainer:		Roland Hieber, Pengutronix <rhi@pengutronix.de>
"
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal nosmartindent
setlocal indentkeys=o,O,0},0<>>,!<Ctrl-F>
setlocal indentexpr=GetDTSIndent()
setlocal nolisp

let b:undo_indent = 'setl autoindent< smartindent< indentkeys< indentexpr< lisp<'

function GetDTSIndent()
    let sw        = shiftwidth()
    let lnum      = v:lnum
    let line      = getline(lnum)
    let prevline  = getline(prevnonblank(lnum-1))
    let prevind   = indent(prevnonblank(lnum-1))

    if prevnonblank(lnum-1) < 1
        return 0
    endif

    " Don't indent header and preprocessor directives
    if line =~ '^\s*\(/dts-\|#\(include\|define\|undef\|warn\(ing\)\?\|error\|if\(n\?def\)\?\|else\|elif\|endif\)\)'
        return 0

    " Don't indent /node and &label blocks
    elseif line =~ '^\s*[/&].\+{\s*$'
        return 0

    " Indent to matching bracket or remove one shiftwidth if line begins with } or >
    elseif line =~ '^\s*[}>]'
        " set cursor to closing bracket on current line
        let col = matchend(line, '^\s*[>}]')
        call cursor(lnum, col)
        
        " determine bracket type, {} or <>
        let pair = strpart('{}<>', stridx('}>', line[col-1]) * 2, 2)

        " find matching bracket pair
        let pairline = searchpair(pair[0], '', pair[1], 'bW')

        if pairline > 0 
            return indent(pairline)
        else
            return prevind - sw
        endif

    " else, add one level of indent if line ends in { or < or = or ,
    elseif prevline =~ '[{<=,]$'
        return prevind + sw

    else
        return prevind
    endif

endfunction
