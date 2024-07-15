" Language:    Typst
" Maintainer:  Gregory Anders
" Last Change: 2024-07-14
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
