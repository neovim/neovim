" Vim syntax file
" Language:     Luau
" Maintainer:   Lopy (@lopi-py)
" Last Change:  2026 Jun 17

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case match
syn sync minlines=300

" comments
syn keyword luauTodo contained TODO FIXME
syn match   luauDirective contained "--!\%(strict\|nonstrict\|nocheck\|nolint\%(Global\)\=\|native\|optimize\)\>.*"

" strings
syn match  luauSpecial contained #\\[[:digit:]]\{1,3}\|\\x[[:xdigit:]]\{2}\|\\u{[[:xdigit:]]\+}\|\\z\s*\|\\\n\|\\[^xu[:digit:]\r\n]#
syn region luauString2 matchgroup=luauStringDelimiter start="\[\z(=*\)\[" end="\]\z1\]" contains=@Spell
syn region luauString  matchgroup=luauStringDelimiter start=+'+ end=+'+ skip=+\\\\\|\\'+ contains=luauSpecial,@Spell
syn region luauString  matchgroup=luauStringDelimiter start=+"+ end=+"+ skip=+\\\\\|\\"+ contains=luauSpecial,@Spell
syn region luauInterpString matchgroup=luauStringDelimiter start=+`+ end=+`+ skip=+\\`+ contains=luauSpecial,luauInterp,@Spell
syn region luauInterp contained transparent matchgroup=luauInterpDelimiter start=+\\\@<!{+ end=+}+ contains=TOP,luauInterpBlock
syn region luauInterpBlock contained transparent start=+{+ end=+}+ contains=TOP,luauInterpBlock

" numbers
syn match luauNumber "\<0_*[xX][[:xdigit:]_]*[[:xdigit:]][[:xdigit:]_]*\>"
syn match luauNumber "\<0_*[bB][01_]*[01][01_]*\>"
syn match luauNumber "\<\d[[:digit:]_]*\%(\.[[:digit:]_]*\)\=\%([eE][-+]\=[[:digit:]_]*\d[[:digit:]_]*\)\=\>"
syn match luauNumber "\.\d[[:digit:]_]*\%([eE][-+]\=[[:digit:]_]*\d[[:digit:]_]*\)\=\>"

" keywords
syn keyword luauStatement return local break end
syn keyword luauStatement do nextgroup=luauStatement skipwhite
syn keyword luauStatement contained continue
syn match   luauStatement "^\s*\zscontinue\>\ze\s*\%(;\|end\>\|else\>\|elseif\>\|until\>\|--.*\|$\)"
syn match   luauStatement ";\s*\zscontinue\>\ze\s*\%(;\|end\>\|else\>\|elseif\>\|until\>\|--.*\|$\)"
syn keyword luauFunction function nextgroup=luauFunctionName,luauGenericParams skipwhite
syn match   luauStatement "^\s*\%(@\%(\h\w*\|\[[^]]*\]\)\s*\)*\zsconst\>\ze\s\+\%(function\>\|\h\)"
syn match   luauStatement "^\s*\%(@\%(\h\w*\|\[[^]]*\]\)\s*\)*\zsdeclare\>\ze\s\+\%(function\>\|class\>\s\+\h\|extern\s\+type\>\|\h\w*\s*:\)" nextgroup=luauStatement,luauDeclareName,luauFunction skipwhite
syn match   luauStatement contained "\<class\>\ze\s\+\h" nextgroup=luauTypedef skipwhite
syn match   luauDeclareName contained "\h\w*\ze\s*:" nextgroup=luauTypeColon skipwhite
syn match   luauStatement "\<export\>\ze\s\+type\>"
syn match   luauStatement contained "\<extern\>\ze\s\+type\>"
syn match   luauStatement "\<extends\>\ze\s\+\h" nextgroup=luauTypeName skipwhite
syn match   luauStatement "\<with\>\ze\s*\%(--.*\)\=$"
syn match   luauModifier "\<public\>\ze\s\+\%(function\|\h\)"
syn match   luauTypeKeyword "\<type\>\ze\s\+\h" nextgroup=luauTypeFunction,luauTypedef skipwhite
syn keyword luauTypeFunction contained function nextgroup=luauFunctionName skipwhite
syn match   luauFunctionName contained transparent "\h\w*\%([.:]\h\w*\)*" nextgroup=luauGenericParams skipwhite
syn keyword luauCond if elseif
syn keyword luauCond then else nextgroup=luauStatement skipwhite
syn keyword luauRepeat while for until in
syn keyword luauRepeat repeat nextgroup=luauStatement skipwhite
syn keyword luauOperator and or not

" operators and punctuation
syn match luauSymbolOperator "[#+*/%^=<>~?-]\|\.\{3}\|\.\.=\="
syn match luauSymbolOperator "->" nextgroup=luauSymbolOperator,luauConstant,luauTableType,luauTypePack,luauTypeName skipwhite
syn match luauSymbolOperator "[|&]" nextgroup=luauConstant,luauTableType,luauTypePack,luauTypeName skipwhite
syn match luauSymbolOperator "::"

" tables
syn region luauTableBlock transparent matchgroup=luauTable start="{" end="}" contains=TOP,luauStatement

syn match   luauComment "--.*$" contains=luauTodo,luauDirective,@Spell
syn region  luauComment matchgroup=luauCommentDelimiter start="--\[\z(=*\)\[" end="\]\z1\]" contains=luauTodo,@Spell

" the first line may start with #!
syn match luauComment "\%^#!.*"

" attributes
syn match   luauAttribute "@\h\w*"
syn region  luauAttributeBlock matchgroup=luauAttributeDelimiter start="@\[" end="\]" contains=luauAttributeName,luauAttributeTable,luauString,luauString2,luauInterpString,luauNumber,luauConstant
syn region  luauAttributeTable contained transparent matchgroup=luauTable start="{" end="}" contains=luauAttributeTable,luauString,luauString2,luauInterpString,luauNumber,luauConstant,luauSymbolOperator
syn keyword luauAttributeName contained checked native deprecated

" constants and types
syn keyword luauConstant nil true false
syn match   luauConstant "\.\.\."
syn keyword luauSelf self
syn match   luauSelf contained "(\s*\zsself\>\ze\s*:"
syn cluster luauTypeCommon contains=luauGenericParams,luauString,luauString2,luauInterpString,luauNumber,luauConstant,luauSymbolOperator
syn cluster luauTypeExpr contains=luauFunctionTypeParams,luauTableType,luauTypeParam,luauType,luauTypeKeyword,@luauTypeCommon
syn region  luauGenericParams contained transparent matchgroup=luauSymbolOperator start="<" end=">" contains=@luauTypeExpr
syn region  luauTypedefGenericParams contained transparent matchgroup=luauSymbolOperator start="<" end=">" contains=@luauTypeExpr nextgroup=luauTypeAliasAssign skipwhite
syn region  luauExplicitTypeArgs transparent matchgroup=luauSymbolOperator start="<<" end=">>" contains=@luauTypeExpr
syn match   luauTypeParam contained "\h\w*\%(\.\.\.\)\="
syn match   luauTypedef "\h\w*" contained nextgroup=luauTypedefGenericParams,luauTypeAliasAssign skipwhite
syn match   luauTypeAliasAssign contained "=" nextgroup=luauSymbolOperator,luauConstant,luauTableType,luauTypeName skipwhite
syn region  luauTableType contained transparent matchgroup=luauTable start="{" end="}" contains=luauFunctionTypeParams,luauTableType,luauSelf,luauTypeIndexer,luauTableElementType,luauTypeColon,luauTypeKeyword,@luauTypeCommon
syn match   luauTypeIndexer "^\s*\[\s*" nextgroup=luauType skipwhite
syn match   luauTypeIndexer contained transparent "\[\s*" nextgroup=luauType skipwhite
syn match   luauType contained "\h\w*\%(\.\h\w*\)*\ze\s*\]\s*:" nextgroup=luauGenericParams skipwhite
syn match   luauTableElementType contained "\h\w*\%(\.\h\w*\)*\ze\s*[<?|&,;})]" nextgroup=luauGenericParams skipwhite
syn match   luauTypeColon transparent ":" nextgroup=luauSymbolOperator,luauConstant,luauTableType,luauTypeAfterColon skipwhite
syn match   luauTypeAfterColon contained "\h\w*\%(\.\h\w*\)*\%(\.\.\.\)\=\ze\s*\%([?=},)\]|&]\|,\|<\|->\|$\)" nextgroup=luauGenericParams skipwhite
syn region  luauFunctionTypeParams transparent start="(\ze\%([^()]*\))\s*->" end=")\ze\s*->" contains=luauFunctionTypeParam,luauTypeColon,luauSelf,@luauTypeCommon
syn match   luauFunctionTypeParam contained "\h\w*\%(\.\h\w*\)*\%(\.\.\.\)\=\ze\s*?\=\s*[,)|&]" nextgroup=luauGenericParams skipwhite
syn match   luauFunctionReturnStart transparent ")\s*:\s*" nextgroup=luauSymbolOperator,luauFunctionTypeParams,luauConstant,luauTableType,luauTypePack,luauTypeName skipwhite
syn region  luauTypePack contained transparent start="(\%([^()]*)\s*->\)\@!" end=")" contains=luauFunctionTypeParams,luauTableType,luauTypeName,@luauTypeCommon
syn match   luauTypeName contained "\h\w*\%(\.\h\w*\)*\%(\.\.\.\)\=" nextgroup=luauGenericParams skipwhite
syn match   luauTypeKeyword "\<\%(read\|write\)\>\ze\s*\%(\[\|\h\+\s*:\)" nextgroup=luauTypeIndexer skipwhite

" metamethods
syn keyword luauMetaMethod __index __newindex __mode __namecall __call __iter __len
syn keyword luauMetaMethod __eq __add __sub __mul __div __idiv __mod __pow __unm
syn keyword luauMetaMethod __lt __le __concat __type __metatable __tostring

" methods
syn match luauMethodColon transparent ":\ze\s*\h\w*\s*\%(<<.\{-}>>\s*\|<[^>]*>\s*\)\=\%((\|{\|'\|\"\|\[\)" nextgroup=luauFunc skipwhite
syn match luauFunc contained "\h\w*\ze\s*\%(<<.\{-}>>\s*\|<[^>]*>\s*\)\=\%((\|{\|'\|\"\|\[\)"

" global functions and values
syn keyword luauFunc assert error gcinfo getfenv getmetatable
syn keyword luauFunc ipairs loadstring newproxy next pairs pcall print
syn keyword luauFunc rawequal rawget rawlen rawset require select setfenv
syn keyword luauFunc setmetatable tonumber tostring unpack xpcall
syn keyword luauGlobal _G
syn keyword luauBuiltinConstant _VERSION
syn match   luauFunc "\<type\>\ze\s*\%(<<.\{-}>>\s*\)\=("
syn match   luauFunc "\<typeof\>\ze\s*\%(<<.\{-}>>\s*\)\=("

" standard library members
syn match luauFunc /\<bit32\.\%(arshift\|band\|bnot\|bor\|btest\|bxor\|byteswap\|countlz\|countrz\|extract\|lrotate\|lshift\|replace\|rrotate\|rshift\)\>/
syn match luauFunc /\<buffer\.\%(copy\|create\|fill\|fromstring\|len\|readbits\|readf32\|readf64\|readi16\|readi32\|readi8\|readstring\|readu16\|readu32\|readu8\)\>/
syn match luauFunc /\<buffer\.\%(tostring\|writebits\|writef32\|writef64\|writei16\|writei32\|writei8\|writestring\|writeu16\|writeu32\|writeu8\)\>/
syn match luauFunc /\<coroutine\.\%(close\|create\|isyieldable\|resume\|running\|status\|wrap\|yield\)\>/
syn match luauFunc /\<debug\.\%(info\|traceback\)\>/
syn match luauFunc /\<math\.\%(abs\|acos\|asin\|atan2\=\|ceil\|clamp\|cosh\=\|deg\|exp\|floor\|fmod\|frexp\)\>/
syn match luauFunc /\<math\.\%(isfinite\|isinf\|isnan\|ldexp\|lerp\|log\|log10\|map\|max\|min\|modf\|noise\)\>/
syn match luauFunc /\<math\.\%(pow\|rad\|random\%(seed\)\=\|round\|sign\|sinh\=\|sqrt\|tanh\=\)\>/
syn match luauBuiltinConstant /\<math\.\%(huge\|pi\)\>/
syn match luauFunc /\<os\.\%(clock\|date\|difftime\|time\)\>/
syn match luauFunc /\<string\.\%(byte\|char\|find\|format\|gmatch\|gsub\|len\|lower\|match\|pack\%(size\)\=\|rep\|reverse\|split\|sub\|unpack\|upper\)\>/
syn match luauFunc /\<table\.\%(clear\|clone\|concat\|create\|find\|foreachi\=\|freeze\|getn\|insert\|isfrozen\|maxn\|move\|pack\|remove\|sort\|unpack\)\>/
syn match luauFunc /\<utf8\.\%(char\|codepoint\|codes\|len\|offset\)\>/
syn match luauBuiltinConstant /\<utf8\.charpattern\>/
syn match luauFunc /\<vector\.\%(abs\|angle\|ceil\|clamp\|create\|cross\|dot\|floor\|lerp\|magnitude\|max\|min\|normalize\|sign\)\>/
syn match luauBuiltinConstant /\<vector\.\%(one\|zero\)\>/
syn match luauFunc /\<types\.\%(any\|boolean\|buffer\|copy\|generic\|intersectionof\|never\|negationof\|newfunction\|newtable\|number\|optional\|singleton\|string\|thread\|unionof\|unknown\)\>/

" define the default highlighting
hi def link luauStatement          Statement
hi def link luauRepeat             Repeat
hi def link luauString             String
hi def link luauString2            String
hi def link luauInterpString       String
hi def link luauStringDelimiter    luauString
hi def link luauInterpDelimiter    Special
hi def link luauNumber             Number
hi def link luauOperator           Operator
hi def link luauSymbolOperator     luauOperator
hi def link luauConstant           Constant
hi def link luauCond               Conditional
hi def link luauFunction           Function
hi def link luauMetaMethod         Function
hi def link luauTable              Structure
hi def link luauComment            Comment
hi def link luauCommentDelimiter   luauComment
hi def link luauDirective          PreProc
hi def link luauTodo               Todo
hi def link luauSpecial            SpecialChar
hi def link luauFunc               Identifier
hi def link luauGlobal             Identifier
hi def link luauBuiltinConstant    Constant
hi def link luauSelf               Identifier
hi def link luauModifier           StorageClass
hi def link luauType               Type
hi def link luauTypeAfterColon     luauType
hi def link luauTableElementType   luauType
hi def link luauTypeAliasAssign    luauSymbolOperator
hi def link luauFunctionTypeParam  luauType
hi def link luauTypeName           luauType
hi def link luauTypedef            Typedef
hi def link luauTypeParam          Type
hi def link luauTypeKeyword        Keyword
hi def link luauTypeFunction       luauFunction
hi def link luauDeclareName        Identifier
hi def link luauAttribute          PreProc
hi def link luauAttributeName      PreProc
hi def link luauAttributeDelimiter PreProc

let b:current_syntax = "luau"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
