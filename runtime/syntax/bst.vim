" Vim syntax file
" Language:     BibTeX Bibliography Style
" Maintainer:   Tim Pope <vimNOSPAM@tpope.info>
" Filenames:    *.bst
" $Id: bst.vim,v 1.2 2007/05/05 18:24:42 vimboss Exp $

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

if version < 600
    command -nargs=1 SetIsk set iskeyword=<args>
else
    command -nargs=1 SetIsk setlocal iskeyword=<args>
endif
SetIsk 48-57,#,$,',.,A-Z,a-z
delcommand SetIsk

syn case ignore

syn match   bstString +"[^"]*\%("\|$\)+ contains=bstField,bstType,bstError
" Highlight the last character of an unclosed string, but only when the cursor
" is not beyond it (i.e., it is still being edited). Imperfect.
syn match   bstError     '[^"]\%#\@!$' contained

syn match   bstNumber         "#-\=\d\+\>"
syn keyword bstNumber         entry.max$ global.max$
syn match   bstComment        "%.*"

syn keyword bstCommand        ENTRY FUNCTION INTEGERS MACRO STRINGS
syn keyword bstCommand        READ EXECUTE ITERATE REVERSE SORT
syn match   bstBuiltIn        "\s[-<>=+*]\|\s:="
syn keyword bstBuiltIn        add.period$
syn keyword bstBuiltIn        call.type$ change.case$ chr.to.int$ cite$
syn keyword bstBuiltIn        duplicate$ empty$ format.name$
syn keyword bstBuiltIn        if$ int.to.chr$ int.to.str$
syn keyword bstBuiltIn        missing$
syn keyword bstBuiltIn        newline$ num.names$
syn keyword bstBuiltIn        pop$ preamble$ purify$ quote$
syn keyword bstBuiltIn        skip$ stack$ substring$ swap$
syn keyword bstBuiltIn        text.length$ text.prefix$ top$ type$
syn keyword bstBuiltIn        warning$ while$ width$ write$
syn match   bstIdentifier     "'\k*"
syn keyword bstType           article book booklet conference
syn keyword bstType           inbook incollection inproceedings
syn keyword bstType           manual mastersthesis misc
syn keyword bstType           phdthesis proceedings
syn keyword bstType           techreport unpublished
syn keyword bstField          abbr address annote author
syn keyword bstField          booktitle chapter crossref comment
syn keyword bstField          edition editor
syn keyword bstField          howpublished institution journal key month
syn keyword bstField          note number
syn keyword bstField          organization
syn keyword bstField          pages publisher
syn keyword bstField          school series
syn keyword bstField          title type
syn keyword bstField          volume year

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_bst_syn_inits")
    if version < 508
        let did_bst_syn_inits = 1
        command -nargs=+ HiLink hi link <args>
    else
        command -nargs=+ HiLink hi def link <args>
    endif

    HiLink bstComment           Comment
    HiLink bstString            String
    HiLink bstCommand           PreProc
    HiLink bstBuiltIn           Statement
    HiLink bstField             Special
    HiLink bstNumber            Number
    HiLink bstType              Type
    HiLink bstIdentifier        Identifier
    HiLink bstError             Error
    delcommand HiLink
endif

let b:current_syntax = "bst"

" vim:set ft=vim sts=4 sw=4:
