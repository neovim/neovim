" Vim syntax file
" Language:      Structurizr DSL
" Maintainer:    Bastian Venthur <venthur@debian.org>
" Last Change:   2024-11-06
" Remark:        For a language reference, see
"                https://docs.structurizr.com/dsl/language

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
syn keyword skeyword background
syn keyword skeyword border
syn keyword skeyword branding
syn keyword skeyword color
syn keyword skeyword colour
syn keyword skeyword component
syn keyword skeyword configuration
syn keyword skeyword container
syn keyword skeyword containerinstance
syn keyword skeyword custom
syn keyword skeyword default
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
syn keyword skeyword font
syn keyword skeyword fontsize
syn keyword skeyword group
syn keyword skeyword healthcheck
syn keyword skeyword height
syn keyword skeyword icon
syn keyword skeyword image
syn keyword skeyword include
syn keyword skeyword infrastructurenode
syn keyword skeyword instances
syn keyword skeyword logo
syn keyword skeyword metadata
syn keyword skeyword model
syn keyword skeyword opacity
syn keyword skeyword person
syn keyword skeyword perspectives
syn keyword skeyword properties
syn keyword skeyword relationship
syn keyword skeyword routing
syn keyword skeyword scope
syn keyword skeyword shape
syn keyword skeyword softwaresystem
syn keyword skeyword softwaresysteminstance
syn keyword skeyword stroke
syn keyword skeyword strokewidth
syn keyword skeyword styles
syn keyword skeyword systemcontext
syn keyword skeyword systemlandscape
syn keyword skeyword tag
syn keyword skeyword tags
syn keyword skeyword technology
syn keyword skeyword terminology
syn keyword skeyword theme
syn keyword skeyword themes
syn keyword skeyword thickness
syn keyword skeyword this
syn keyword skeyword title
syn keyword skeyword url
syn keyword skeyword users
syn keyword skeyword views
syn keyword skeyword visibility
syn keyword skeyword width
syn keyword skeyword workspace

syn match skeyword "\!adrs\s\+"
syn match skeyword "\!components\s\+"
syn match skeyword "\!docs\s\+"
syn match skeyword "\!element\s\+"
syn match skeyword "\!elements\s\+"
syn match skeyword "\!extend\s\+"
syn match skeyword "\!identifiers\s\+"
syn match skeyword "\!impliedrelationships\s\+"
syn match skeyword "\!include\s\+"
syn match skeyword "\!plugin\s\+"
syn match skeyword "\!ref\s\+"
syn match skeyword "\!relationship\s\+"
syn match skeyword "\!relationships\s\+"
syn match skeyword "\!script\s\+"

syn region sstring oneline start='"' end='"'

syn region sblock start='{' end='}' fold transparent

syn match soperator "\->\s+"

hi def link sstring string
hi def link scomment comment
hi def link skeyword keyword
hi def link soperator operator

let b:current_syntax = "structurizr"
