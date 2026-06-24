" Beancount specific formatting
" Language: beancount
" Maintainer: Nathan Grigg
" Latest Revision: 2021-03-06

" Align currency on decimal point.
function! beancount#align_commodity(line1, line2) abort
    " Save cursor position to adjust it if necessary.
    let l:cursor_col = col('.')
    let l:cursor_line = line('.')

    " Increment at start of loop, because of continue statements.
    let l:current_line = a:line1 - 1
    while l:current_line < a:line2
        let l:current_line += 1
        let l:line = getline(l:current_line)
        " This matches an account name followed by a space in one of the two
        " following cases:
        "  - A posting line, i.e., the line starts with indentation followed
        "    by an optional flag and the account.
        "  - A balance directive, i.e., the line starts with a date followed
        "    by the 'balance' keyword and the account.
        "  - A price directive, i.e., the line starts with a date followed by
        "    the 'price' keyword and a currency.
        let l:end_account = matchend(l:line, '\v' .
            \ '^[\-/[:digit:]]+\s+balance\s+([A-Z][A-Za-z0-9\-]+)(:[A-Z0-9][A-Za-z0-9\-]*)+ ' .
            \ '|^[\-/[:digit:]]+\s+price\s+\S+ ' .
            \ '|^\s+([!&#?%PSTCURM]\s+)?([A-Z][A-Za-z0-9\-]+)(:[A-Z0-9][A-Za-z0-9\-]*)+ '
            \ )
        if l:end_account < 0
            continue
        endif

        " Where does the number begin?
        let l:begin_number = matchend(l:line, '^ *', l:end_account)

        " Look for a minus sign and a number (possibly containing commas) and
        " align on the next column.
        let l:separator = matchend(l:line, '^\v([-+])?[,[:digit:]]+', l:begin_number) + 1
        if l:separator < 0 | continue | endif
        let l:has_spaces = l:begin_number - l:end_account
        let l:need_spaces = g:beancount_separator_col - l:separator + l:has_spaces
        if l:need_spaces < 0 | continue | endif
        call setline(l:current_line, l:line[0 : l:end_account - 1] . repeat(' ', l:need_spaces) . l:line[ l:begin_number : -1])
        if l:current_line == l:cursor_line && l:cursor_col >= l:end_account
            " Adjust cursor position for continuity.
            call cursor(0, l:cursor_col + l:need_spaces - l:has_spaces)
        endif
    endwhile
endfunction

" Call bean-doctor on the current line and dump output into a scratch buffer
function! beancount#get_context() abort
    let l:context = system('bean-doctor context ' . shellescape(expand('%')) . ' ' . line('.'))
    botright new
    setlocal buftype=nofile bufhidden=hide noswapfile
    call append(0, split(l:context, '\v\n'))
    normal! gg
endfunction
