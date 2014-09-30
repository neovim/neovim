" Vim syntax file
" Language:         TeX (plain.tex format)
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-10-26

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   plaintexControlSequence         display contains=@NoSpell
      \ '\\[a-zA-Z@]\+'

runtime! syntax/initex.vim
unlet b:current_syntax

syn match   plaintexComment                 display
      \ contains=ALLBUT,initexComment,plaintexComment
      \ '^\s*%[CDM].*$'

if exists("g:plaintex_delimiters")
  syn match   plaintexDelimiter             display '[][{}]'
endif

syn match   plaintexRepeat                  display contains=@NoSpell
      \ '\\\%(loop\|repeat\)\>'

syn match   plaintexCommand                 display contains=@NoSpell
      \ '\\\%(plainoutput\|TeX\)\>'
syn match   plaintexBoxCommand              display contains=@NoSpell
      \ '\\\%(null\|strut\)\>'
syn match   plaintexDebuggingCommand        display contains=@NoSpell
      \ '\\\%(showhyphens\|tracingall\|wlog\)\>'
syn match   plaintexFontsCommand            display contains=@NoSpell
      \ '\\\%(bf\|\%(five\|seven\)\%(bf\|i\|rm\|sy\)\|it\|oldstyle\|rm\|sl\|ten\%(bf\|ex\|it\=\|rm\|sl\|sy\|tt\)\|tt\)\>'
syn match   plaintexGlueCommand             display contains=@NoSpell
      \ '\\\%(\%(big\|en\|med\|\%(no\|off\)interline\|small\)skip\|\%(center\|left\|right\)\=line\|\%(dot\|\%(left\|right\)arrow\)fill\|[hv]glue\|[lr]lap\|q\=quad\|space\|topglue\)\>'
syn match   plaintexInsertsCommand          display contains=@NoSpell
      \ '\\\%(\%(end\|top\)insert\|v\=footnote\)\>'
syn match   plaintexJobCommand              display contains=@NoSpell
      \ '\\\%(bye\|fmt\%(name\|version\)\)\>'
syn match   plaintexInsertsCommand          display contains=@NoSpell
      \ '\\\%(mid\|page\)insert\>'
syn match   plaintexKernCommand             display contains=@NoSpell
      \ '\\\%(en\|\%(neg\)\=thin\)space\>'
syn match   plaintexMacroCommand            display contains=@NoSpell
      \ '\\\%(active\|[be]group\|empty\)\>'
syn match   plaintexPageCommand             display contains=@NoSpell
      \ '\\\%(\%(super\)\=eject\|nopagenumbers\|\%(normal\|ragged\)bottom\)\>'
syn match   plaintexParagraphCommand        display contains=@NoSpell
      \ '\\\%(endgraf\|\%(non\)\=frenchspacing\|hang\|item\%(item\)\=\|narrower\|normalbaselines\|obey\%(lines\|spaces\)\|openup\|proclaim\|\%(tt\)\=raggedright\|textindent\)\>'
syn match   plaintexPenaltiesCommand        display contains=@NoSpell
      \ '\\\%(allow\|big\|fil\|good\|med\|no\|small\)\=break\>'
syn match   plaintexRegistersCommand        display contains=@NoSpell
      \ '\\\%(advancepageno\|new\%(box\|count\|dimen\|fam\|help\|if\|insert\|language\|muskip\|read\|skip\|toks\|write\)\)\>'
syn match   plaintexTablesCommand           display contains=@NoSpell
      \ '&\|\\+\|\\\%(cleartabs\|endline\|hidewidth\|ialign\|multispan\|settabs\|tabalign\)\>'

if !exists("g:plaintex_no_math")
  syn region  plaintexMath                  matchgroup=plaintexMath
      \ contains=@plaintexMath,@NoSpell
      \ start='\$' skip='\\\\\|\\\$' end='\$'
  syn region  plaintexMath                  matchgroup=plaintexMath
      \ contains=@plaintexMath,@NoSpell keepend
      \ start='\$\$' skip='\\\\\|\\\$' end='\$\$'
endif

" Keep this after plaintexMath, as we don’t want math mode started at a \$.
syn match   plaintexCharacterCommand        display contains=@NoSpell
      \ /\\\%(["#$%&'.=^_`~]\|``\|''\|-\{2,3}\|[?!]`\|^^L\|\~\|\%(a[ae]\|A[AE]\|acute\|[cdHoOPStuvijlL]\|copyright\|d\=dag\|folio\|ldotp\|[lr]q\|oe\|OE\|slash\|ss\|underbar\)\>\)/

syn cluster plaintexMath
      \ contains=plaintexMathCommand,plaintexMathBoxCommand,
      \ plaintexMathCharacterCommand,plaintexMathDelimiter,
      \ plaintexMathFontsCommand,plaintexMathLetter,plaintexMathSymbol,
      \ plaintexMathFunction,plaintexMathOperator,plaintexMathPunctuation,
      \ plaintexMathRelation

syn match   plaintexMathCommand             display contains=@NoSpell contained
      \ '\\\%([!*,;>{}|_^]\|\%([aA]rrowvert\|[bB]ig\%(g[lmr]\=\|r\)\=\|\%(border\|p\)\=matrix\|displaylines\|\%(down\|up\)bracefill\|eqalign\%(no\)\|leqalignno\|[lr]moustache\|mathpalette\|root\|s[bp]\|skew\|sqrt\)\>\)'
syn match   plaintexMathBoxCommand          display contains=@NoSpell contained
      \ '\\\%([hv]\=phantom\|mathstrut\|smash\)\>'
syn match   plaintexMathCharacterCommand    display contains=@NoSpell contained
      \ '\\\%(b\|bar\|breve\|check\|d\=dots\=\|grave\|hat\|[lv]dots\|tilde\|vec\|wide\%(hat\|tilde\)\)\>'
syn match   plaintexMathDelimiter           display contains=@NoSpell contained
      \ '\\\%(brace\%(vert\)\=\|brack\|cases\|choose\|[lr]\%(angle\|brace\|brack\|ceil\|floor\|group\)\|over\%(brace\|\%(left\|right\)arrow\)\|underbrace\)\>'
syn match   plaintexMathFontsCommand        display contains=@NoSpell contained
      \ '\\\%(\%(bf\|it\|sl\|tt\)fam\|cal\|mit\)\>'
syn match   plaintexMathLetter              display contains=@NoSpell contained
      \ '\\\%(aleph\|alpha\|beta\|chi\|[dD]elta\|ell\|epsilon\|eta\|[gG]amma\|[ij]math\|iota\|kappa\|[lL]ambda\|[mn]u\|[oO]mega\|[pP][hs]\=i\|rho\|[sS]igma\|tau\|[tT]heta\|[uU]psilon\|var\%(epsilon\|ph\=i\|rho\|sigma\|theta\)\|[xX]i\|zeta\)\>'
syn match   plaintexMathSymbol              display contains=@NoSpell contained
      \ '\\\%(angle\|backslash\|bot\|clubsuit\|emptyset\|epsilon\|exists\|flat\|forall\|hbar\|heartsuit\|Im\|infty\|int\|lnot\|nabla\|natural\|neg\|pmod\|prime\|Re\|sharp\|smallint\|spadesuit\|surd\|top\|triangle\%(left\|right\)\=\|vdash\|wp\)\>'
syn match   plaintexMathFunction            display contains=@NoSpell contained
      \ '\\\%(arc\%(cos\|sin\|tan\)\|arg\|\%(cos\|sin\|tan\)h\=\|coth\=\|csc\|de[gt]\|dim\|exp\|gcd\|hom\|inf\|ker\|lo\=g\|lim\%(inf\|sup\)\=\|ln\|max\|min\|Pr\|sec\|sup\)\>'
syn match   plaintexMathOperator            display contains=@NoSpell contained
      \ '\\\%(amalg\|ast\|big\%(c[au]p\|circ\|o\%(dot\|plus\|times\|sqcup\)\|triangle\%(down\|up\)\|uplus\|vee\|wedge\|bmod\|bullet\)\|c[au]p\|cdot[ps]\=\|circ\|coprod\|d\=dagger\|diamond\%(suit\)\=\|div\|land\|lor\|mp\|o\%(dot\|int\|minus\|plus\|slash\|times\)pm\|prod\|setminus\|sqc[au]p\|sqsu[bp]seteq\|star\|su[bp]set\%(eq\)\=\|sum\|times\|uplus\|vee\|wedge\|wr\)\>'
syn match   plaintexMathPunctuation         display contains=@NoSpell contained
      \ '\\\%(colon\)\>'
syn match   plaintexMathRelation            display contains=@NoSpell contained
      \ '\\\%(approx\|asymp\|bowtie\|buildrel\|cong\|dashv\|doteq\|[dD]ownarrow\|equiv\|frown\|geq\=\|gets\|gg\|hook\%(left\|right\)arrow\|iff\|in\|leq\=\|[lL]eftarrow\|\%(left\|right\)harpoon\%(down\|up\)\|[lL]eftrightarrow\|ll\|[lL]ongleftrightarrow\|longmapsto\|[lL]ongrightarrow\|mapsto\|mid\|models\|[ns][ew]arrow\|neq\=\|ni\|not\%(in\)\=\|owns\|parallel\|perp\|prec\%(eq\)\=\|propto\|[rR]ightarrow\|rightleftharpoons\|sim\%(eq\)\=\|smile\|succ\%(eq\)\=\|to\|[uU]parrow\|[uU]pdownarrow\|[vV]ert\)\>'

syn match   plaintexParameterDimen          display contains=@NoSpell
      \ '\\maxdimen\>'
syn match   plaintexMathParameterDimen      display contains=@NoSpell
      \ '\\jot\>'
syn match   plaintexParagraphParameterGlue  display contains=@NoSpell
      \ '\\\%(\%(big\|med\|small\)skipamount\|normalbaselineskip\|normallineskip\%(limit\)\=\)\>'

syn match   plaintexFontParameterInteger    display contains=@NoSpell
      \ '\\magstep\%(half\)\=\>'
syn match   plaintexJobParameterInteger     display contains=@NoSpell
      \ '\\magnification\>'
syn match   plaintexPageParameterInteger    display contains=@NoSpell
      \ '\\pageno\>'

syn match   plaintexPageParameterToken      display contains=@NoSpell
      \ '\\\%(foot\|head\)line\>'

hi def link plaintexOperator                Operator

hi def link plaintexDelimiter               Delimiter

hi def link plaintexControlSequence         Identifier
hi def link plaintexComment                 Comment
hi def link plaintexInclude                 Include
hi def link plaintexRepeat                  Repeat

hi def link plaintexCommand                 initexCommand
hi def link plaintexBoxCommand              plaintexCommand
hi def link plaintexCharacterCommand        initexCharacterCommand
hi def link plaintexDebuggingCommand        initexDebuggingCommand
hi def link plaintexFontsCommand            initexFontsCommand
hi def link plaintexGlueCommand             plaintexCommand
hi def link plaintexInsertsCommand          plaintexCommand
hi def link plaintexJobCommand              initexJobCommand
hi def link plaintexKernCommand             plaintexCommand
hi def link plaintexMacroCommand            initexMacroCommand
hi def link plaintexPageCommand             plaintexCommand
hi def link plaintexParagraphCommand        plaintexCommand
hi def link plaintexPenaltiesCommand        plaintexCommand
hi def link plaintexRegistersCommand        plaintexCommand
hi def link plaintexTablesCommand           plaintexCommand

hi def link plaintexMath                    String
hi def link plaintexMathCommand             plaintexCommand
hi def link plaintexMathBoxCommand          plaintexBoxCommand
hi def link plaintexMathCharacterCommand    plaintexCharacterCommand
hi def link plaintexMathDelimiter           plaintexDelimiter
hi def link plaintexMathFontsCommand        plaintexFontsCommand
hi def link plaintexMathLetter              plaintexMathCharacterCommand
hi def link plaintexMathSymbol              plaintexMathLetter
hi def link plaintexMathFunction            Function
hi def link plaintexMathOperator            plaintexOperator
hi def link plaintexMathPunctuation         plaintexCharacterCommand
hi def link plaintexMathRelation            plaintexOperator

hi def link plaintexParameterDimen          initexParameterDimen
hi def link plaintexMathParameterDimen      initexMathParameterDimen
hi def link plaintexParagraphParameterGlue  initexParagraphParameterGlue
hi def link plaintexFontParameterInteger    initexFontParameterInteger
hi def link plaintexJobParameterInteger     initexJobParameterInteger
hi def link plaintexPageParameterInteger    initexPageParameterInteger
hi def link plaintexPageParameterToken      initexParameterToken

let b:current_syntax = "plaintex"

let &cpo = s:cpo_save
unlet s:cpo_save
