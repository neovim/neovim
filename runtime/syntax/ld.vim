" Vim syntax file
" Language:             ld(1) script
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword ldTodo          contained TODO FIXME XXX NOTE

syn region  ldComment       start='/\*' end='\*/' contains=ldTodo,@Spell

syn region  ldFileName      start=+"+ end=+"+

syn keyword ldPreProc       SECTIONS MEMORY OVERLAY PHDRS VERSION INCLUDE
syn match   ldPreProc       '\<VERS_\d\+\.\d\+'

syn keyword ldFunction      ABSOLUTE ADDR ALIGN BLOCK DATA_SEGMENT_ALIGN
                            \ DATA_SEGMENT_END DATA_SEGMENT_RELRO_END DEFINED
                            \ LOADADDR MAX MIN NEXT SIZEOF SIZEOF_HEADERS
                            \ sizeof_headers

syn keyword ldKeyword       ENTRY INPUT GROUP OUTPUT
                            \ SEARCH_DIR STARTUP OUTPUT_FORMAT TARGET
                            \ ASSERT EXTERN FORCE_COMMON_ALLOCATION
                            \ INHIBIT_COMMON_ALLOCATION NOCROSSREFS OUTPUT_ARCH
                            \ PROVIDE EXCLUDE_FILE SORT KEEP FILL
                            \ CREATE_OBJECT_SYMBOLS CONSTRUCTORS SUBALIGN
                            \ FILEHDR AT __asm__ ABSOLUTE

syn keyword ldDataType      BYTE SHORT LONG QUAD SQUAD
syn keyword ldOutputType    NOLOAD DSECT COPY INFO OVERLAY
syn keyword ldPTType        PT_NULL PT_LOAD PT_DYNAMIC PT_INTERP
                            \ PT_NOTE PT_SHLIB PT_PHDR

syn keyword ldSpecial       COMMON
syn match   ldSpecial       '/DISCARD/'

syn keyword ldIdentifier    ORIGIN LENGTH

syn match   ldSpecSections  '\.'
syn match   ldSections      '\.\S\+'
syn match   ldSpecSections  '\.\%(text\|data\|bss\|symver\)\>'

syn match   ldNumber        display '\<0[xX]\x\+\>'
syn match   ldNumber        display '\d\+[KM]\>' contains=ldNumberMult
syn match   ldNumberMult    display '\(\d\+\)\@<=[KM]\>'
syn match   ldOctal         contained display '\<0\o\+\>'
                            \ contains=ldOctalZero
syn match   ldOctalZero     contained display '\<0'
syn match   ldOctalError    contained display '\<0\o*[89]\d*\>'


hi def link ldTodo          Todo
hi def link ldComment       Comment
hi def link ldFileName      String
hi def link ldPreProc       PreProc
hi def link ldFunction      Identifier
hi def link ldKeyword       Keyword
hi def link ldType          Type
hi def link ldDataType      ldType
hi def link ldOutputType    ldType
hi def link ldPTType        ldType
hi def link ldSpecial       Special
hi def link ldIdentifier    Identifier
hi def link ldSections      Constant
hi def link ldSpecSections  Special
hi def link ldNumber        Number
hi def link ldNumberMult    PreProc
hi def link ldOctal         ldNumber
hi def link ldOctalZero     PreProc
hi def link ldOctalError    Error

let b:current_syntax = "ld"

let &cpo = s:cpo_save
unlet s:cpo_save
