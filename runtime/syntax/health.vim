if exists("b:current_syntax")
    finish
endif

syntax keyword healthError ERROR
highlight link healthError Error

syntax keyword healthWarning WARNING
highlight link healthWarning Todo

syntax keyword healthInfo INFO
highlight link healthInfo Identifier

syntax keyword healthSuccess SUCCESS
highlight link healthSuccess Function

syntax keyword healthSuggestion SUGGESTION
highlight link healthSuggestion String

let b:current_syntax = "health"
