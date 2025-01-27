" Vim syntax file
" Language:		Idris 2
" Maintainer:		Idris Hackers (https://github.com/edwinb/idris2-vim), Serhii Khoma <srghma@gmail.com>
" Last Change:		2024 Nov 05
" Original Author:	raichoo (raichoo@googlemail.com)
" License:		Vim (see :h license)
" Repository:		https://github.com/ShinKage/idris2-nvim
"

if exists("b:current_syntax")
  finish
endif

syn match idris2TypeDecl "[a-zA-Z][a-zA-z0-9_']*\s\+:\s\+" contains=idris2Identifier,idris2Operators
syn region idris2Parens matchgroup=idris2Delimiter start="(" end=")" contains=TOP,idris2TypeDecl
syn region idris2Brackets matchgroup=idris2Delimiter start="\[" end="]" contains=TOP,idris2TypeDecl
syn region idris2Block matchgroup=idris2Delimiter start="{" end="}" contains=TOP,idris2TypeDecl
syn region idris2SnocBrackets matchgroup=idris2Delimiter start="\[<" end="]" contains=TOP
syn region idris2ListBrackets matchgroup=idris2Delimiter start="\[>" end="]" contains=TOP
syn keyword idris2Module module namespace
syn keyword idris2Import import
syn keyword idris2Structure data record interface implementation
syn keyword idris2Where where
syn keyword idris2Visibility public abstract private export
syn keyword idris2Block parameters mutual using
syn keyword idris2Totality total partial covering
syn keyword idris2Annotation auto impossible default constructor
syn keyword idris2Statement do case of rewrite with proof
syn keyword idris2Let let in
syn keyword idris2Forall forall
syn keyword idris2DataOpt noHints uniqueSearch search external noNewtype containedin=idris2Brackets
syn keyword idris2Conditional if then else
syn match idris2Number "\<[0-9]\+\>\|\<0[xX][0-9a-fA-F]\+\>\|\<0[oO][0-7]\+\>"
syn match idris2Float "\<[0-9]\+\.[0-9]\+\([eE][-+]\=[0-9]\+\)\=\>"
syn match idris2Delimiter  "[,;]"
syn keyword idris2Infix prefix infix infixl infixr
syn match idris2Operators "\([-!#$%&\*\+./<=>\?@\\^|~:]\|\<_\>\)"
syn match idris2Type "\<[A-Z][a-zA-Z0-9_']*\>"
syn keyword idris2Todo TODO FIXME XXX HACK contained
syn match idris2LineComment "---*\([^-!#$%&\*\+./<=>\?@\\^|~].*\)\?$" contains=idris2Todo,@Spell
syn match idris2DocComment "|||\([^-!#$%&\*\+./<=>\?@\\^|~].*\)\?$" contains=idris2Todo,@Spell
syn match idris2MetaVar "?[a-zA-Z_][A-Za-z0-9_']*"
syn match idris2Pragma "%\(hide\|logging\|auto_lazy\|unbound_implicits\|prefix_record_projections\|ambiguity_depth\|nf_metavar_threshold\|search_timeout\|pair\|rewrite\|integerLit\|stringLit\|charLit\|doubleLit\|name\|start\|allow_overloads\|language\|default\|transform\|hint\|globalhint\|defaulthint\|inline\|noinline\|extern\|macro\|spec\|foreign\|nomangle\|builtin\|MkWorld\|World\|search\|runElab\|tcinline\|auto_implicit_depth\)"
syn match idris2Char "'[^'\\]'\|'\\.'\|'\\u[0-9a-fA-F]\{4}'"
syn match idris2Backtick "`[A-Za-z][A-Za-z0-9_']*`"
syn region idris2String start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell
syn region idris2BlockComment start="{-" end="-}" contains=idris2BlockComment,idris2Todo,@Spell
syn match idris2Identifier "[a-zA-Z][a-zA-z0-9_']*" contained

" Default Highlighting  {{{1

highlight def link idris2Deprecated Error
highlight def link idris2Identifier Identifier
highlight def link idris2Import Structure
highlight def link idris2Module Structure
highlight def link idris2Structure Structure
highlight def link idris2Statement Statement
highlight def link idris2Forall Structure
highlight def link idris2DataOpt Statement
highlight def link idris2DSL Statement
highlight def link idris2Block Statement
highlight def link idris2Annotation Statement
highlight def link idris2Where Structure
highlight def link idris2Let Structure
highlight def link idris2Totality Statement
highlight def link idris2Visibility Statement
highlight def link idris2Conditional Conditional
highlight def link idris2Pragma Statement
highlight def link idris2Number Number
highlight def link idris2Float Float
highlight def link idris2Delimiter Delimiter
highlight def link idris2Infix PreProc
highlight def link idris2Operators Operator
highlight def link idris2Type Include
highlight def link idris2DocComment Comment
highlight def link idris2LineComment Comment
highlight def link idris2BlockComment Comment
highlight def link idris2Todo Todo
highlight def link idris2MetaVar Macro
highlight def link idris2String String
highlight def link idris2Char String
highlight def link idris2Backtick Operator

let b:current_syntax = "idris2"

" vim: nowrap sw=2 sts=2 ts=8 noexpandtab ft=vim
