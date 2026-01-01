" Vim syntax file.
" Language:    Hare
" Maintainer:  Amelia Clarke <selene@perilune.dev>
" Last Change: 2024-05-10
" Upstream:    https://git.sr.ht/~sircmpwn/hare.vim

if exists('b:current_syntax')
  finish
endif
syn include @haredoc syntax/haredoc.vim
let b:current_syntax = 'hare'

" Syntax {{{1
syn case match
syn iskeyword @,48-57,@-@,_

" Keywords {{{2
syn keyword hareConditional else if match switch
syn keyword hareDefine def
syn keyword hareInclude use
syn keyword hareKeyword break continue return yield
syn keyword hareKeyword case
syn keyword hareKeyword const let
syn keyword hareKeyword defer
syn keyword hareKeyword export static
syn keyword hareKeyword fn
syn keyword hareOperator as is
syn keyword hareRepeat for
syn keyword hareTypedef type

" Attributes.
syn keyword hareAttribute @fini @init @test
syn keyword hareAttribute @offset @packed
syn keyword hareAttribute @symbol
syn keyword hareAttribute @threadlocal

" Builtins.
syn keyword hareBuiltin abort assert
syn keyword hareBuiltin align len offset
syn keyword hareBuiltin alloc free
syn keyword hareBuiltin append delete insert
syn keyword hareBuiltin vaarg vaend vastart

" Types {{{2
syn keyword hareType bool
syn keyword hareType done
syn keyword hareType f32 f64
syn keyword hareType i8 i16 i32 i64 int
syn keyword hareType never
syn keyword hareType opaque
syn keyword hareType rune str
syn keyword hareType u8 u16 u32 u64 uint
syn keyword hareType uintptr
syn keyword hareType valist
syn keyword hareType void

" Other types.
syn keyword hareStorageClass nullable
syn keyword hareStructure enum struct union

" Literals {{{2
syn keyword hareBoolean false true
syn keyword hareConstant null

" Integer literals.
syn match hareNumber '\v<%(0|[1-9]%(_?\d)*)%([Ee]\+?\d+)?%([iu]%(8|16|32|64)?|z)?>' display
syn match hareNumber '\v<0b[01]%(_?[01])*%([iu]%(8|16|32|64)?|z)?>' display
syn match hareNumber '\v<0o\o%(_?\o)*%([iu]%(8|16|32|64)?|z)?>' display
syn match hareNumber '\v<0x\x%(_?\x)*%([iu]%(8|16|32|64)?|z)?>' display

" Floating-point literals.
syn match hareFloat '\v<%(0|[1-9]%(_?\d)*)\.\d%(_?\d)*%([Ee][+-]?\d+)?%(f32|f64)?>' display
syn match hareFloat '\v<%(0|[1-9]%(_?\d)*)%([Ee][+-]?\d+)?%(f32|f64)>' display
syn match hareFloat '\v<0x\x%(_?\x)*%(\.\x%(_?\x)*)?[Pp][+-]?\d+%(f32|f64)?>' display

" Rune and string literals.
syn region hareRune start="'" skip="\\'" end="'" contains=hareEscape
syn region hareString start='"' skip='\\"' end='"' contains=hareEscape,hareFormat
syn region hareString start='`' end='`' contains=hareFormat

" Escape sequences.
syn match hareEscape '\\[0abfnrtv\\'"]' contained
syn match hareEscape '\v\\%(x\x{2}|u\x{4}|U\x{8})' contained display

" Format sequences.
syn match hareFormat '\v\{\d*%(:%(\.?\d+|[ +\-=Xbefgox]|F[.2ESUs]|_%(.|\\%([0abfnrtv\\'"]|x\x{2}|u\x{4}|U\x{8})))*)?}' contained contains=hareEscape display
syn match hareFormat '{\d*%\d*}' contained display
syn match hareFormat '{{\|}}' contained display

" Miscellaneous {{{2

" Comments.
syn region hareComment start='//' end='$' contains=hareTodo,@haredoc,@Spell display
syn keyword hareTodo FIXME TODO XXX contained

" Identifiers.
syn match hareDelimiter '::' display
syn match hareName '\<\h\w*\>' nextgroup=@harePostfix skipempty skipwhite transparent

" Labels.
syn match hareLabel ':\h\w*\>' display

" Match `size` as a type unless it is followed by an open paren.
syn match hareType '\<size\>' display
syn match hareBuiltin '\<size\ze(' display

" Postfix expressions.
syn cluster harePostfix contains=hareErrorTest,hareField,hareIndex,hareParens
syn match hareErrorTest '!=\@!' contained nextgroup=@harePostfix skipempty skipwhite
syn match hareErrorTest '?' nextgroup=@harePostfix skipempty skipwhite
syn match hareField '\.\w*\>'hs=s+1 contained contains=hareNumber nextgroup=@harePostfix skipempty skipwhite
syn region hareIndex start='\[' end=']' contained nextgroup=@harePostfix skipempty skipwhite transparent
syn region hareParens start='(' end=')' nextgroup=@harePostfix skipempty skipwhite transparent

" Whitespace errors.
syn match hareSpaceError '^ \+\ze\t' display
syn match hareSpaceError excludenl '\s\+$' containedin=ALL display

" Folding {{{3
syn region hareBlock start='{' end='}' fold transparent

" Default highlighting {{{1
hi def link hareAttribute PreProc
hi def link hareBoolean Boolean
hi def link hareBuiltin Operator
hi def link hareComment Comment
hi def link hareConditional Conditional
hi def link hareConstant Constant
hi def link hareDefine Define
hi def link hareDelimiter Delimiter
hi def link hareErrorTest Special
hi def link hareEscape SpecialChar
hi def link hareFloat Float
hi def link hareFormat SpecialChar
hi def link hareInclude Include
hi def link hareKeyword Keyword
hi def link hareLabel Special
hi def link hareNumber Number
hi def link hareOperator Operator
hi def link hareRepeat Repeat
hi def link hareRune Character
hi def link hareStorageClass StorageClass
hi def link hareString String
hi def link hareStructure Structure
hi def link hareTodo Todo
hi def link hareType Type
hi def link hareTypedef Typedef

" Highlight embedded haredoc references.
hi! def link haredocRefValid SpecialComment

" Highlight whitespace errors by default.
if get(g:, 'hare_space_error', 1)
  hi def link hareSpaceError Error
endif

" vim: et sts=2 sw=2 ts=8
