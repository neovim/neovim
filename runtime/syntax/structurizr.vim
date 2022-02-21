" Vim syntax file
" Language:      Structurizr DSL
" Maintainer:    Bastian Venthur <venthur@debian.org>
" Last Change:   2022-02-15
" Remark:        For a language reference, see
"                https://github.com/structurizr/dsl


if exists("b:current_syntax")
    finish
endif

syn case ignore

" comments
syn match scomment "#.*$"
syn match scomment "//.*$"
syn region scomment start="/\*" end="\*/"

" keywords
syn keyword skeyword animation
syn keyword skeyword autoLayout
syn keyword skeyword branding
syn keyword skeyword component
syn keyword skeyword configuration
syn keyword skeyword container
syn keyword skeyword containerinstance
syn keyword skeyword custom
syn keyword skeyword deployment
syn keyword skeyword deploymentenvironment
syn keyword skeyword deploymentgroup
syn keyword skeyword deploymentnode
syn keyword skeyword description
syn keyword skeyword dynamic
syn keyword skeyword element
syn keyword skeyword enterprise
syn keyword skeyword exclude
syn keyword skeyword filtered
syn keyword skeyword group
syn keyword skeyword healthcheck
syn keyword skeyword include
syn keyword skeyword infrastructurenode
syn keyword skeyword model
syn keyword skeyword person
syn keyword skeyword perspectives
syn keyword skeyword properties
syn keyword skeyword relationship
syn keyword skeyword softwaresystem
syn keyword skeyword softwaresysteminstance
syn keyword skeyword styles
syn keyword skeyword systemcontext
syn keyword skeyword systemlandscape
syn keyword skeyword tags
syn keyword skeyword technology
syn keyword skeyword terminology
syn keyword skeyword theme
syn keyword skeyword title
syn keyword skeyword url
syn keyword skeyword users
syn keyword skeyword views
syn keyword skeyword workspace

syn match skeyword "\!adrs\s\+"
syn match skeyword "\!constant\s\+"
syn match skeyword "\!docs\s\+"
syn match skeyword "\!identifiers\s\+"
syn match skeyword "\!impliedrelationships\s\+"
syn match skeyword "\!include\s\+"
syn match skeyword "\!plugin\s\+"
syn match skeyword "\!ref\s\+"
syn match skeyword "\!script\s\+"

syn region sstring oneline start='"' end='"'

syn region sblock start='{' end='}' fold transparent

hi def link sstring string
hi def link scomment comment
hi def link skeyword keyword

let b:current_syntax = "structurizr"
