" Vim filetype plugin file
" Language:	Modula-2
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Jan 04

" Dialect can be one of pim, iso, r10
function modula2#GetDialect() abort

  if exists("b:modula2.dialect")
    return b:modula2.dialect
  endif

  if exists("g:modula2_default_dialect")
    let dialect = g:modula2_default_dialect
  else
    let dialect = "pim"
  endif

  return dialect
endfunction

function modula2#SetDialect(dialect, extension = "") abort
  if exists("b:modula2")
    unlockvar! b:modula2
  endif

  let b:modula2 = #{ dialect: a:dialect, extension: a:extension }
  lockvar! b:modula2
endfunction

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
