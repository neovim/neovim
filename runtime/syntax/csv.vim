" Maintainer: Maxim Kim <habamax@gmail.com>
" Converted from vim9script
" Last Update: 2024-06-18

if exists("b:current_syntax")
    finish
endif

let s:delimiter = get(b:, "csv_delimiter", ",")

" generate bunch of following syntaxes:
" syntax match csvCol8 /.\{-}\(,\|$\)/ nextgroup=escCsvCol0,csvCol0
" syntax region escCsvCol8 start=/ *"\([^"]*""\)*[^"]*/ end=/" *\(,\|$\)/ nextgroup=escCsvCol0,csvCol0
for s:col in range(8, 0, -1)
    let s:ncol = (s:col == 8 ? 0 : s:col + 1)
    exe $'syntax match csvCol{s:col}' .. ' /.\{-}\(' .. s:delimiter .. '\|$\)/ nextgroup=escCsvCol' .. s:ncol .. ',csvCol' .. s:ncol
    exe $'syntax region escCsvCol{s:col}' .. ' start=/ *"\([^"]*""\)*[^"]*/ end=/" *\(' .. s:delimiter .. '\|$\)/ nextgroup=escCsvCol' .. s:ncol .. ',csvCol' .. s:ncol
endfor

hi def link csvCol1 Statement
hi def link csvCol2 Constant
hi def link csvCol3 Type
hi def link csvCol4 PreProc
hi def link csvCol5 Identifier
hi def link csvCol6 Special
hi def link csvCol7 String
hi def link csvCol8 Comment

hi def link escCsvCol1 csvCol1
hi def link escCsvCol2 csvCol2
hi def link escCsvCol3 csvCol3
hi def link escCsvCol4 csvCol4
hi def link escCsvCol5 csvCol5
hi def link escCsvCol6 csvCol6
hi def link escCsvCol7 csvCol7
hi def link escCsvCol8 csvCol8

let b:current_syntax = "csv"
