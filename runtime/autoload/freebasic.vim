" Vim filetype plugin file
" Language:	FreeBASIC
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2022 June 24

" Dialects can be one of fb, qb, fblite, or deprecated
" Precedence is forcelang > #lang > lang
function! freebasic#GetDialect() abort
  if exists("g:freebasic_forcelang")
    return g:freebasic_forcelang
  endif

  if exists("g:freebasic_lang")
    let dialect = g:freebasic_lang
  else
    let dialect = "fb"
  endif

  " override with #lang directive or metacommand

  let pat = '\c^\s*\%(#\s*lang\s\+\|''\s*$lang\s*:\s*\)"\([^"]*\)"'

  let save_cursor = getcurpos()
  call cursor(1, 1)
  let lnum = search(pat, 'cn')
  call setpos('.', save_cursor)

  if lnum
    let word = matchlist(getline(lnum), pat)[1]
    if word =~? '\<\%(fb\|deprecated\|fblite\|qb\)\>'
      let dialect = word
    else
      echomsg "freebasic#GetDialect: Invalid lang, found '" .. word .. "' at line " .. lnum .. " " .. getline(lnum)
    endif
  endif

  return dialect
endfunction

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
