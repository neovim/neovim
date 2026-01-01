" Vim syntax file
" Language:	Chatito
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	*.chatito
" Last Change:	2022 Sep 19

if exists('b:current_syntax')
    finish
endif

" Comment
syn keyword chatitoTodo contained TODO FIXME XXX
syn match chatitoComment /^#.*/ contains=chatitoTodo,@Spell
syn match chatitoComment +^//.*+ contains=chatitoTodo,@Spell

" Import
syn match chatitoImport /^import \+.*$/ transparent contains=chatitoImportKeyword,chatitoImportFile
syn keyword chatitoImportKeyword import contained nextgroup=chatitoImportFile
syn match chatitoImportFile /.*$/ contained skipwhite

" Intent
syn match chatitoIntent /^%\[[^\]?]\+\]\((.\+)\)\=$/ contains=chatitoArgs

" Slot
syn match chatitoSlot /^@\[[^\]?#]\+\(#[^\]?#]\+\)\=\]\((.\+)\)\=$/ contains=chatitoArgs,chatitoVariation
syn match chatitoSlot /@\[[^\]?#]\+\(#[^\]?#]\+\)\=?\=\]/ contained contains=chatitoOpt,chatitoVariation

" Alias
syn match chatitoAlias /^\~\[[^\]?]\+\]\=$/
syn match chatitoAlias /\~\[[^\]?]\+?\=\]/ contained contains=chatitoOpt

" Probability
syn match chatitoProbability /\*\[\d\+\(\.\d\+\)\=%\=\]/ contained

" Optional
syn match chatitoOpt '?' contained

" Arguments
syn match chatitoArgs /(.\+)/ contained

" Variation
syn match chatitoVariation /#[^\]?#]\+/ contained

" Value
syn match chatitoValue /^ \{4\}\zs.\+$/ contains=chatitoProbability,chatitoSlot,chatitoAlias,@Spell

" Errors
syn match chatitoError /^\t/

hi def link chatitoAlias String
hi def link chatitoArgs Special
hi def link chatitoComment Comment
hi def link chatitoError Error
hi def link chatitoImportKeyword Include
hi def link chatitoIntent Statement
hi def link chatitoOpt SpecialChar
hi def link chatitoProbability Number
hi def link chatitoSlot Identifier
hi def link chatitoTodo Todo
hi def link chatitoVariation Special

let b:current_syntax = 'chatito'
