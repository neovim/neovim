if exists("b:current_syntax")
    finish
endif

syntax keyword healthError ERROR
highlight link healthError Error

syntax keyword healthInfo INFO
highlight link healthInfo Identifier

let b:current_syntax = "health"
