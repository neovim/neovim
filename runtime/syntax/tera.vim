" Vim syntax file
" Language:	Tera
" Maintainer:	Muntasir Mahmud <muntasir.joypurhat@gmail.com>
" Last Change:	2025 Mar 09

if exists("b:current_syntax")
  finish
endif

" Detect the underlying language based on filename pattern
" For files like file.html.tera, we want to load html syntax
let s:filename = expand("%:t")
let s:dotpos = strridx(s:filename, '.', strridx(s:filename, '.tera') - 1)
let s:underlying_filetype = ""

if s:dotpos != -1
  let s:underlying_ext = s:filename[s:dotpos+1:strridx(s:filename, '.tera')-1]
  if s:underlying_ext != "" && s:underlying_ext != "tera"
    let s:underlying_filetype = s:underlying_ext
  endif
endif

" Load the underlying language syntax if detected
if s:underlying_filetype != ""
  execute "runtime! syntax/" . s:underlying_filetype . ".vim"
  unlet! b:current_syntax
else
  " Default to HTML if no specific language detected
  runtime! syntax/html.vim
  unlet! b:current_syntax
endif

" Tera comment blocks: {# comment #}
syn region teraCommentBlock start="{#" end="#}" contains=@Spell containedin=cssDefinition,cssStyle,htmlHead,htmlTitle

" Tera statements: {% if condition %}
syn region teraStatement start="{%" end="%}" contains=teraKeyword,teraString,teraNumber,teraFunction,teraBoolean,teraFilter,teraOperator containedin=cssDefinition,cssStyle,htmlHead,htmlTitle

" Tera expressions: {{ variable }}
syn region teraExpression start="{{" end="}}" contains=teraString,teraNumber,teraFunction,teraBoolean,teraFilter,teraOperator,teraIdentifier containedin=cssDefinition,cssStyle,htmlHead,htmlTitle

" Special handling for raw blocks - content inside shouldn't be processed
syn region teraRawBlock start="{% raw %}" end="{% endraw %}" contains=TOP,teraCommentBlock,teraStatement,teraExpression

" Control structure keywords
syn keyword teraKeyword contained if else elif endif for endfor in macro endmacro
syn keyword teraKeyword contained block endblock extends include import set endset
syn keyword teraKeyword contained break continue filter endfilter raw endraw with endwith

" Identifiers - define before operators for correct priority
syn match teraIdentifier contained "\<\w\+\>"

" Operators used in expressions and statements
syn match teraOperator contained "==\|!=\|>=\|<=\|>\|<\|+\|-\|*\|/"
syn match teraOperator contained "{\@<!%}\@!" " Match % but not when part of {% or %}
syn keyword teraOperator contained and or not is as

" Functions and filters
syn match teraFunction contained "\<\w\+\ze("
syn match teraFilter contained "|\_s*\w\+"

" String literals - both single and double quoted
syn region teraString contained start=+"+ skip=+\\"+ end=+"+ contains=@Spell
syn region teraString contained start=+'+ skip=+\\'+ end=+'+ contains=@Spell

" Numeric literals - both integer and float
syn match teraNumber contained "\<\d\+\>"
syn match teraNumber contained "\<\d\+\.\d\+\>"

" Boolean values
syn keyword teraBoolean contained true false

" Highlighting links
hi def link teraCommentBlock Comment
hi def link teraKeyword Statement
hi def link teraOperator Operator
hi def link teraFunction Function
hi def link teraIdentifier Identifier
hi def link teraString String
hi def link teraNumber Number
hi def link teraBoolean Boolean
hi def link teraFilter PreProc

" Special highlighting for blocks and expressions
hi def link teraStatement PreProc
hi def link teraExpression PreProc

" Clean up script-local variables
unlet s:filename
unlet s:dotpos
if exists("s:underlying_ext")
  unlet s:underlying_ext
endif
unlet s:underlying_filetype

let b:current_syntax = "tera"
