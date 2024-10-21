" Language:    Typst
" Maintainer:  Gregory Anders
" Last Change: 2024 Oct 21
" Based on:    https://github.com/kaarmu/typst.vim

function! typst#indentexpr() abort
    let l:lnum = v:lnum
    let s:sw = shiftwidth()

    let [l:plnum, l:pline] = s:get_prev_nonblank(l:lnum - 1)
    if l:plnum == 0 | return 0 | endif

    let l:line = getline(l:lnum)
    let l:ind = indent(l:plnum)

    let l:synname = synIDattr(synID(l:lnum, 1, 1), 'name')

    " Use last indent for block comments
    if l:synname == 'typstCommentBlock'
        return l:ind
    endif

    if l:pline =~ '\v[{[(]\s*$'
        let l:ind += s:sw
    endif

    if l:line =~ '\v^\s*[}\])]'
        let l:ind -= s:sw
    endif

    return l:ind
endfunction

function typst#foldexpr()
    let line = getline(v:lnum)

    " Whenever the user wants to fold nested headers under the parent
    let nested = get(g:, "typst_foldnested", 1)

    " Regular headers
    let depth = match(line, '\(^=\+\)\@<=\( .*$\)\@=')

    " Do not fold nested regular headers
    if depth > 1 && !nested
        let depth = 1
    endif

    if depth > 0
        " check syntax, it should be typstMarkupHeading
        let syncode = synstack(v:lnum, 1)
        if len(syncode) > 0 && synIDattr(syncode[0], 'name') ==# 'typstMarkupHeading'
            return ">" . depth
        endif
    endif

    return "="
endfunction

" Gets the previous non-blank line that is not a comment.
function! s:get_prev_nonblank(lnum) abort
    let l:lnum = prevnonblank(a:lnum)
    let l:line = getline(l:lnum)

    while l:lnum > 0 && l:line =~ '^\s*//'
        let l:lnum = prevnonblank(l:lnum - 1)
        let l:line = getline(l:lnum)
    endwhile

    return [l:lnum, s:remove_comments(l:line)]
endfunction

" Removes comments from the given line.
function! s:remove_comments(line) abort
    return substitute(a:line, '\s*//.*', '', '')
endfunction
