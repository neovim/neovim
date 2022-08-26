" Vim syntax file
" Language:	julia
" Maintainer:	Carlo Baldassi <carlobaldassi@gmail.com>
" Homepage:	https://github.com/JuliaEditorSupport/julia-vim
" Last Change:	2013 feb 11

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

if version < 704
  " this is used to disable regex syntax like `\@3<='
  " on older vim versions
  function! s:d(x)
    return ''
  endfunction
else
  function! s:d(x)
    return string(a:x)
  endfunction
endif

scriptencoding utf-8

let s:julia_spellcheck_strings = get(g:, "julia_spellcheck_strings", 0)
let s:julia_spellcheck_docstrings = get(g:, "julia_spellcheck_docstrings", 1)
let s:julia_spellcheck_comments = get(g:, "julia_spellcheck_comments", 1)

let s:julia_highlight_operators = get(g:, "julia_highlight_operators", 1)

" List of characters, up to \UFF, which cannot be used in identifiers.
" (It includes operator characters; we don't consider them identifiers.)
" This is used mostly in lookbehinds with `\@<=`, e.g. when we need to check
" that that we're not in the middle of an identifier.
" It doesn't include a few characters (spaces and all closing parentheses)
" because those may or may not be valid in the lookbehind on a case-by-case
" basis.
let s:nonid_chars = '\U00-\U08' . '\U0A-\U1F'
      \             . '\U21-\U28' . '\U2A-\U2F' . '\U3A-\U40' . '\U5B-\U5E' . '\U60' . '\U7B\U7C'
      \             . '\U7E-\UA1' . '\UA7\UA8' . '\UAB-\UAD' . '\UAF\UB1\UB4' . '\UB6-\UB8' . '\UBB\UBF' . '\UD7\UF7'

" The complete list
let s:nonidS_chars = '[:space:])\U5D}' . s:nonid_chars


" List of all valid operator chars up to \UFF (NOTE: they must all be included
" in s:nonidS_chars, so that if we include that, then this is redundant)
" It does not include '!' since it can be used in an identifier.
" The list contains the following characters: '%&*+-/<=>\\^|~¬±×÷'
let s:op_chars = '\U25\U26\U2A\U2B\U2D\U2F\U3C-\U3E\U5C\U5E\U7C\U7E\UAC\UB1\UD7\UF7'

" List of all valid operator chars above \UFF
" Written with ranges for performance reasons
" The list contains the following characters: '…⁝⅋←↑→↓↔↚↛↜↝↞↠↢↣↤↦↩↪↫↬↮↶↷↺↻↼↽⇀⇁⇄⇆⇇⇉⇋⇌⇍⇎⇏⇐⇒⇔⇚⇛⇜⇝⇠⇢⇴⇵⇶⇷⇸⇹⇺⇻⇼⇽⇾⇿∈∉∊∋∌∍∓∔∗∘∙√∛∜∝∤∥∦∧∨∩∪∷∸∺∻∽∾≀≁≂≃≄≅≆≇≈≉≊≋≌≍≎≏≐≑≒≓≔≕≖≗≘≙≚≛≜≝≞≟≠≡≢≣≤≥≦≧≨≩≪≫≬≭≮≯≰≱≲≳≴≵≶≷≸≹≺≻≼≽≾≿⊀⊁⊂⊃⊄⊅⊆⊇⊈⊉⊊⊋⊍⊎⊏⊐⊑⊒⊓⊔⊕⊖⊗⊘⊙⊚⊛⊜⊞⊟⊠⊡⊢⊣⊩⊬⊮⊰⊱⊲⊳⊴⊵⊶⊷⊻⊼⊽⋄⋅⋆⋇⋉⋊⋋⋌⋍⋎⋏⋐⋑⋒⋓⋕⋖⋗⋘⋙⋚⋛⋜⋝⋞⋟⋠⋡⋢⋣⋤⋥⋦⋧⋨⋩⋪⋫⋬⋭⋮⋯⋰⋱⋲⋳⋴⋵⋶⋷⋸⋹⋺⋻⋼⋽⋾⋿⌿▷⟂⟈⟉⟑⟒⟕⟖⟗⟰⟱⟵⟶⟷⟹⟺⟻⟼⟽⟾⟿⤀⤁⤂⤃⤄⤅⤆⤇⤈⤉⤊⤋⤌⤍⤎⤏⤐⤑⤒⤓⤔⤕⤖⤗⤘⤝⤞⤟⤠⥄⥅⥆⥇⥈⥉⥊⥋⥌⥍⥎⥏⥐⥑⥒⥓⥔⥕⥖⥗⥘⥙⥚⥛⥜⥝⥞⥟⥠⥡⥢⥣⥤⥥⥦⥧⥨⥩⥪⥫⥬⥭⥮⥯⥰⦷⦸⦼⦾⦿⧀⧁⧡⧣⧤⧥⧴⧶⧷⧺⧻⨇⨈⨝⨟⨢⨣⨤⨥⨦⨧⨨⨩⨪⨫⨬⨭⨮⨰⨱⨲⨳⨴⨵⨶⨷⨸⨹⨺⨻⨼⨽⩀⩁⩂⩃⩄⩅⩊⩋⩌⩍⩎⩏⩐⩑⩒⩓⩔⩕⩖⩗⩘⩚⩛⩜⩝⩞⩟⩠⩡⩢⩣⩦⩧⩪⩫⩬⩭⩮⩯⩰⩱⩲⩳⩴⩵⩶⩷⩸⩹⩺⩻⩼⩽⩾⩿⪀⪁⪂⪃⪄⪅⪆⪇⪈⪉⪊⪋⪌⪍⪎⪏⪐⪑⪒⪓⪔⪕⪖⪗⪘⪙⪚⪛⪜⪝⪞⪟⪠⪡⪢⪣⪤⪥⪦⪧⪨⪩⪪⪫⪬⪭⪮⪯⪰⪱⪲⪳⪴⪵⪶⪷⪸⪹⪺⪻⪼⪽⪾⪿⫀⫁⫂⫃⫄⫅⫆⫇⫈⫉⫊⫋⫌⫍⫎⫏⫐⫑⫒⫓⫔⫕⫖⫗⫘⫙⫛⫷⫸⫹⫺⬰⬱⬲⬳⬴⬵⬶⬷⬸⬹⬺⬻⬼⬽⬾⬿⭀⭁⭂⭃⭄⭇⭈⭉⭊⭋⭌￩￪￫￬'
let s:op_chars_wc = '\U2026\U205D\U214B\U2190-\U2194\U219A-\U219E\U21A0\U21A2-\U21A4\U21A6\U21A9-\U21AC\U21AE\U21B6\U21B7\U21BA-\U21BD\U21C0\U21C1\U21C4\U21C6\U21C7\U21C9\U21CB-\U21D0\U21D2\U21D4\U21DA-\U21DD\U21E0\U21E2\U21F4-\U21FF\U2208-\U220D\U2213\U2214\U2217-\U221D\U2224-\U222A\U2237\U2238\U223A\U223B\U223D\U223E\U2240-\U228B\U228D-\U229C\U229E-\U22A3\U22A9\U22AC\U22AE\U22B0-\U22B7\U22BB-\U22BD\U22C4-\U22C7\U22C9-\U22D3\U22D5-\U22FF\U233F\U25B7\U27C2\U27C8\U27C9\U27D1\U27D2\U27D5-\U27D7\U27F0\U27F1\U27F5-\U27F7\U27F9-\U27FF\U2900-\U2918\U291D-\U2920\U2944-\U2970\U29B7\U29B8\U29BC\U29BE-\U29C1\U29E1\U29E3-\U29E5\U29F4\U29F6\U29F7\U29FA\U29FB\U2A07\U2A08\U2A1D\U2A1F\U2A22-\U2A2E\U2A30-\U2A3D\U2A40-\U2A45\U2A4A-\U2A58\U2A5A-\U2A63\U2A66\U2A67\U2A6A-\U2AD9\U2ADB\U2AF7-\U2AFA\U2B30-\U2B44\U2B47-\U2B4C\UFFE9-\UFFEC'

" Full operators regex
let s:operators = '\%(' . '\.\%([-+*/^÷%|&⊻]\|//\|\\\|>>\|>>>\?\)\?=' .
      \           '\|'  . '[:<>]=\|||\|&&\||>\|<|\|[<>:]:\|<<\|>>>\?\|//\|[-=]>\|\.\.\.\?' .
      \           '\|'  . '\.\?[!' . s:op_chars . s:op_chars_wc . ']' .
      \           '\)'


" Characters that can be used to start an identifier. Above \UBF we don't
" bother checking. (If a UTF8 operator is used, it will take precedence anyway.)
let s:id_charsH = '\%([A-Za-z_\UA2-\UA6\UA9\UAA\UAE\UB0\UB5\UBA]\|[^\U00-\UBF]\)'
" Characters that can appear in an identifier, starting in 2nd position. Above
" \UBF we check for operators since we need to stop the identifier if one
" appears. We don't check for invalid characters though.
let s:id_charsW = '\%([0-9A-Za-z_!\UA2-\UA6\UA9\UAA\UAE-\UB0\UB2-\UB5\UB8-\UBA\UBC-\UBE]\|[^\U00-\UBF]\@=[^' . s:op_chars_wc . ']\)'

" A valid julia identifier, more or less
let s:idregex = '\%(' . s:id_charsH . s:id_charsW . '*\)'



syn case match

syntax cluster juliaExpressions		contains=@juliaParItems,@juliaStringItems,@juliaKeywordItems,@juliaBlocksItems,@juliaTypesItems,@juliaConstItems,@juliaMacroItems,@juliaSymbolItems,@juliaOperatorItems,@juliaNumberItems,@juliaCommentItems,@juliaErrorItems,@juliaSyntaxRegions
syntax cluster juliaExprsPrintf		contains=@juliaExpressions,@juliaPrintfItems
syntax cluster juliaExprsNodot		contains=@juliaParItems,@juliaStringItems,@juliaMacroItems,@juliaSymbolItems,@juliaOperatorItems,@juliaCommentItems,juliaIdSymbol

syntax cluster juliaParItems		contains=juliaParBlock,juliaSqBraIdxBlock,juliaSqBraBlock,juliaCurBraBlock,juliaQuotedParBlock,juliaQuotedQMarkPar
syntax cluster juliaKeywordItems	contains=juliaKeyword,juliaWhereKeyword,juliaImportLine,juliaInfixKeyword,juliaRepKeyword
syntax cluster juliaBlocksItems		contains=juliaConditionalBlock,juliaWhileBlock,juliaForBlock,juliaBeginBlock,juliaFunctionBlock,juliaMacroBlock,juliaQuoteBlock,juliaTypeBlock,juliaImmutableBlock,juliaExceptionBlock,juliaLetBlock,juliaDoBlock,juliaModuleBlock,juliaStructBlock,juliaMutableStructBlock,juliaAbstractBlock,juliaPrimitiveBlock
syntax cluster juliaTypesItems		contains=juliaBaseTypeBasic,juliaBaseTypeNum,juliaBaseTypeC,juliaBaseTypeError,juliaBaseTypeIter,juliaBaseTypeString,juliaBaseTypeArray,juliaBaseTypeDict,juliaBaseTypeSet,juliaBaseTypeIO,juliaBaseTypeProcess,juliaBaseTypeRange,juliaBaseTypeRegex,juliaBaseTypeFact,juliaBaseTypeFact,juliaBaseTypeSort,juliaBaseTypeRound,juliaBaseTypeSpecial,juliaBaseTypeRandom,juliaBaseTypeDisplay,juliaBaseTypeTime,juliaBaseTypeOther

syntax cluster juliaConstItems  	contains=juliaConstNum,juliaConstBool,juliaConstEnv,juliaConstMMap,juliaConstC,juliaConstGeneric,juliaConstIO,juliaPossibleEuler

syntax cluster juliaMacroItems		contains=juliaPossibleMacro,juliaDollarVar,juliaDollarPar,juliaDollarSqBra
syntax cluster juliaSymbolItems		contains=juliaPossibleSymbol
syntax cluster juliaNumberItems		contains=juliaNumbers
syntax cluster juliaStringItems		contains=juliaChar,juliaString,juliabString,juliasString,juliaShellString,juliaDocString,juliaRegEx
syntax cluster juliaPrintfItems		contains=juliaPrintfParBlock,juliaPrintfString
syntax cluster juliaOperatorItems	contains=juliaOperator,juliaRangeOperator,juliaCTransOperator,juliaTernaryRegion,juliaColon,juliaSemicolon,juliaComma
syntax cluster juliaCommentItems	contains=juliaCommentL,juliaCommentM
syntax cluster juliaErrorItems		contains=juliaErrorPar,juliaErrorEnd,juliaErrorElse,juliaErrorCatch,juliaErrorFinally

syntax cluster juliaSyntaxRegions	contains=juliaIdSymbol,juliaTypeOperatorR2,juliaTypeOperatorR3,juliaWhereR,juliaDotted

syntax cluster juliaSpellcheckStrings		contains=@spell
syntax cluster juliaSpellcheckDocStrings	contains=@spell
syntax cluster juliaSpellcheckComments		contains=@spell

if !s:julia_spellcheck_docstrings
  syntax cluster juliaSpellcheckDocStrings	remove=@spell
endif
if !s:julia_spellcheck_strings
  syntax cluster juliaSpellcheckStrings		remove=@spell
endif
if !s:julia_spellcheck_comments
  syntax cluster juliaSpellcheckComments	remove=@spell
endif

syntax match   juliaSemicolon		display ";"
syntax match   juliaComma		display ","
syntax match   juliaColon		display ":"

" A dot can introduce a sort of 'environment' such that words after it are not
" recognized as keywords. This has low precedence so that it can be overridden
" by operators
syntax match   juliaDotted		transparent "\.\s*[^])}.]" contains=@juliaExprsNodot
syntax match   juliaDottedT		contained transparent "\.\s*[^])}.]" contains=@juliaExprsNodot,juliaType

syntax match   juliaErrorPar		display "[])}]"
syntax match   juliaErrorEnd		display "\<end\>"
syntax match   juliaErrorElse		display "\<\%(else\|elseif\)\>"
syntax match   juliaErrorCatch		display "\<catch\>"
syntax match   juliaErrorFinally	display "\<finally\>"
syntax match   juliaErrorSemicol	display contained ";"

syntax region  juliaParBlock		matchgroup=juliaParDelim start="(" end=")" contains=@juliaExpressions,juliaComprehensionFor
syntax region  juliaParBlockInRange	matchgroup=juliaParDelim contained start="(" end=")" contains=@juliaExpressions,juliaParBlockInRange,juliaRangeKeyword,juliaComprehensionFor
syntax region  juliaSqBraIdxBlock	matchgroup=juliaParDelim start="\[" end="\]" contains=@juliaExpressions,juliaParBlockInRange,juliaRangeKeyword,juliaComprehensionFor,juliaSymbolS,juliaQuotedParBlockS,juliaQuotedQMarkParS
exec 'syntax region  juliaSqBraBlock	matchgroup=juliaParDelim start="\%(^\|\s\|' . s:operators . '\)\@'.s:d(3).'<=\[" end="\]" contains=@juliaExpressions,juliaComprehensionFor,juliaSymbolS,juliaQuotedParBlockS,juliaQuotedQMarkParS'
syntax region  juliaCurBraBlock		matchgroup=juliaParDelim start="{" end="}" contains=juliaType,juliaDottedT,@juliaExpressions

exec 'syntax match   juliaType		contained "\%(' . s:idregex . '\.\)*\zs' . s:idregex . '"'

" This is a generic identifier followed by some symbol, either a type
" operator (<: or >:), or an open parenthesis, or an open curly bracket.
" It's used to recognize one of the contained regions looking for identifiers
" only once. Once recognized, those regions no longer need to use the
" expensive s:idregex.
exec 'syntax match   juliaIdSymbol	transparent "' . s:idregex . '\%(\s*[<>]:\|\.\?(\|{\|\"\)\@=" contains=juliaFunctionCall,juliaParamType,juliaStringPrefixed,juliaTypeOperatorR1'

syntax match  juliaFunctionCall		contained "[^{([:space:]<>\"]\+(\@=" nextgroup=juliaParBlock

exec 'syntax match   juliaFunctionDef	contained transparent "\%(\<\%(function\|macro\)\)\@'.s:d(8).'<=\s\+\zs' . s:idregex . '\%(\.' . s:idregex . '\)*\ze\s*\%((\|\send\>\|$\)" contains=juliaFunctionName'
exec 'syntax match   juliaFunctionName	contained "\%(\<\%(function\|macro\)\s\+\)\@'.s:d(20).'<=\%(' . s:idregex . '\.\)*\zs' . s:idregex . '"'

exec 'syntax match   juliaStructR	contained transparent "\%(\<\%(\%(mutable\s\+\)\?struct\|\%(abstract\|primitive\)\s\+type\)\s\+\)\@'.s:d(20).'<=\%(' . s:idregex . '\.\)*' . s:idregex . '\>\(\s*(\)\@!" contains=juliaType'

syntax match   juliaKeyword		display "\<\%(return\|local\|global\|const\)\>"
syntax match   juliaInfixKeyword	display "\%(=\s*\)\@<!\<\%(in\|isa\)\>\S\@!\%(\s*=\)\@!"

" The import/export/using keywords introduce a sort of special parsing
" environment with its own rules
exec 'syntax region  juliaImportLine		matchgroup=juliaKeyword excludenl start="\<\%(import\|using\|export\)\>" skip="\%(\%(\<\%(import\|using\|export\)\>\)\|^\)\@'.s:d(6).'<=$" end="$" end="\%([])}]\)\@=" contains=@juliaExpressions,juliaAsKeyword,@juliaContinuationItems,juliaMacroName'
syntax match   juliaAsKeyword		display contained "\<as\>"

syntax match   juliaRepKeyword		display "\<\%(break\|continue\)\>"
syntax region  juliaConditionalBlock	matchgroup=juliaConditional start="\<if\>" end="\<end\>" contains=@juliaExpressions,juliaConditionalEIBlock,juliaConditionalEBlock fold
syntax region  juliaConditionalEIBlock	matchgroup=juliaConditional transparent contained start="\<elseif\>" end="\<\%(end\|else\|elseif\)\>"me=s-1 contains=@juliaExpressions,juliaConditionalEIBlock,juliaConditionalEBlock
syntax region  juliaConditionalEBlock	matchgroup=juliaConditional transparent contained start="\<else\>" end="\<end\>"me=s-1 contains=@juliaExpressions
syntax region  juliaWhileBlock		matchgroup=juliaRepeat start="\<while\>" end="\<end\>" contains=@juliaExpressions fold
syntax region  juliaForBlock		matchgroup=juliaRepeat start="\<for\>" end="\<end\>" contains=@juliaExpressions,juliaOuter fold
syntax region  juliaBeginBlock		matchgroup=juliaBlKeyword start="\<begin\>" end="\<end\>" contains=@juliaExpressions fold
syntax region  juliaFunctionBlock	matchgroup=juliaBlKeyword start="\<function\>" end="\<end\>" contains=@juliaExpressions,juliaFunctionDef fold
syntax region  juliaMacroBlock		matchgroup=juliaBlKeyword start="\<macro\>" end="\<end\>" contains=@juliaExpressions,juliaFunctionDef fold
syntax region  juliaQuoteBlock		matchgroup=juliaBlKeyword start="\<quote\>" end="\<end\>" contains=@juliaExpressions fold
syntax region  juliaStructBlock		matchgroup=juliaBlKeyword start="\<struct\>" end="\<end\>" contains=@juliaExpressions,juliaStructR fold
syntax region  juliaMutableStructBlock	matchgroup=juliaBlKeyword start="\<mutable\s\+struct\>" end="\<end\>" contains=@juliaExpressions,juliaStructR fold
syntax region  juliaLetBlock		matchgroup=juliaBlKeyword start="\<let\>" end="\<end\>" contains=@juliaExpressions fold
syntax region  juliaDoBlock		matchgroup=juliaBlKeyword start="\<do\>" end="\<end\>" contains=@juliaExpressions fold
syntax region  juliaModuleBlock		matchgroup=juliaBlKeyword start="\<\%(bare\)\?module\>" end="\<end\>" contains=@juliaExpressions fold
syntax region  juliaExceptionBlock	matchgroup=juliaException start="\<try\>" end="\<end\>" contains=@juliaExpressions,juliaCatchBlock,juliaFinallyBlock fold
syntax region  juliaCatchBlock		matchgroup=juliaException transparent contained start="\<catch\>" end="\<end\>"me=s-1 contains=@juliaExpressions,juliaFinallyBlock
syntax region  juliaFinallyBlock	matchgroup=juliaException transparent contained start="\<finally\>" end="\<end\>"me=s-1 contains=@juliaExpressions
syntax region  juliaAbstractBlock	matchgroup=juliaBlKeyword start="\<abstract\s\+type\>" end="\<end\>" fold contains=@juliaExpressions,juliaStructR
syntax region  juliaPrimitiveBlock	matchgroup=juliaBlKeyword start="\<primitive\s\+type\>" end="\<end\>" fold contains=@juliaExpressions,juliaStructR

exec 'syntax region  juliaComprehensionFor	matchgroup=juliaComprehensionFor transparent contained start="\%([^[:space:],;:({[]\_s*\)\@'.s:d(80).'<=\<for\>" end="\ze[]);]" contains=@juliaExpressions,juliaComprehensionIf,juliaComprehensionFor'
syntax match   juliaComprehensionIf	contained "\<if\>"

exec 'syntax match   juliaOuter		contained "\<outer\ze\s\+' . s:idregex . '\>"'

syntax match   juliaRangeKeyword	contained "\<\%(begin\|end\)\>"

syntax match   juliaBaseTypeBasic	display "\<\%(\%(N\|Named\)\?Tuple\|Symbol\|Function\|Union\%(All\)\?\|Type\%(Name\|Var\)\?\|Any\|ANY\|Vararg\|Ptr\|Exception\|Module\|Expr\|DataType\|\%(LineNumber\|Quote\)Node\|\%(Weak\|Global\)\?Ref\|Method\|Pair\|Val\|Nothing\|Some\|Missing\)\>"
syntax match   juliaBaseTypeNum		display "\<\%(U\?Int\%(8\|16\|32\|64\|128\)\?\|Float\%(16\|32\|64\)\|Complex\|Bool\|Char\|Number\|Signed\|Unsigned\|Integer\|AbstractFloat\|Real\|Rational\|\%(Abstract\)\?Irrational\|Enum\|BigInt\|BigFloat\|MathConst\|ComplexF\%(16\|32\|64\)\)\>"
syntax match   juliaBaseTypeC		display "\<\%(FileOffset\|C\%(u\?\%(char\|short\|int\|long\(long\)\?\|w\?string\)\|float\|double\|\%(ptrdiff\|s\?size\|wchar\|off\|u\?intmax\)_t\|void\)\)\>"
syntax match   juliaBaseTypeError	display "\<\%(\%(Bounds\|Divide\|Domain\|\%(Stack\)\?Overflow\|EOF\|Undef\%(Ref\|Var\)\|System\|Type\|Parse\|Argument\|Key\|Load\|Method\|Inexact\|OutOfMemory\|Init\|Assertion\|ReadOnlyMemory\|StringIndex\)Error\|\%(Interrupt\|Error\|ProcessExited\|Captured\|Composite\|InvalidState\|Missing\|\%(Process\|Task\)Failed\)Exception\|DimensionMismatch\|SegmentationFault\)\>"
syntax match   juliaBaseTypeIter	display "\<\%(EachLine\|Enumerate\|Cartesian\%(Index\|Range\)\|LinSpace\|CartesianIndices\)\>"
syntax match   juliaBaseTypeString	display "\<\%(DirectIndex\|Sub\|Rep\|Rev\|Abstract\|Substitution\)\?String\>"
syntax match   juliaBaseTypeArray	display "\<\%(\%(Sub\)\?Array\|\%(Abstract\|Dense\|Strided\)\?\%(Array\|Matrix\|Vec\%(tor\|OrMat\)\)\|SparseMatrixCSC\|\%(AbstractSparse\|Bit\|Shared\)\%(Array\|Vector\|Matrix\)\|\%\(D\|Bid\|\%(Sym\)\?Trid\)iagonal\|Hermitian\|Symmetric\|UniformScaling\|\%(Lower\|Upper\)Triangular\|\%(Sparse\|Row\)Vector\|VecElement\|Conj\%(Array\|Matrix\|Vector\)\|Index\%(Cartesian\|Linear\|Style\)\|PermutedDimsArray\|Broadcasted\|Adjoint\|Transpose\|LinearIndices\)\>"
syntax match   juliaBaseTypeDict	display "\<\%(WeakKey\|Id\|Abstract\)\?Dict\>"
syntax match   juliaBaseTypeSet		display "\<\%(\%(Abstract\|Bit\)\?Set\)\>"
syntax match   juliaBaseTypeIO		display "\<\%(IO\%(Stream\|Buffer\|Context\)\?\|RawFD\|StatStruct\|FileMonitor\|PollingFileWatcher\|Timer\|Base64\%(Decode\|Encode\)Pipe\|\%(UDP\|TCP\)Socket\|\%(Abstract\)\?Channel\|BufferStream\|ReentrantLock\|GenericIOBuffer\)\>"
syntax match   juliaBaseTypeProcess	display "\<\%(Pipe\|Cmd\|PipeBuffer\)\>"
syntax match   juliaBaseTypeRange	display "\<\%(Dims\|RangeIndex\|\%(Abstract\|Lin\|Ordinal\|Step\|\%(Abstract\)\?Unit\)Range\|Colon\|ExponentialBackOff\|StepRangeLen\)\>"
syntax match   juliaBaseTypeRegex	display "\<Regex\%(Match\)\?\>"
syntax match   juliaBaseTypeFact	display "\<\%(Factorization\|BunchKaufman\|\%(Cholesky\|QR\)\%(Pivoted\)\?\|\%(Generalized\)\?\%(Eigen\|SVD\|Schur\)\|Hessenberg\|LDLt\|LQ\|LU\)\>"
syntax match   juliaBaseTypeSort	display "\<\%(Insertion\|\(Partial\)\?Quick\|Merge\)Sort\>"
syntax match   juliaBaseTypeRound	display "\<Round\%(ingMode\|FromZero\|Down\|Nearest\%(Ties\%(Away\|Up\)\)\?\|ToZero\|Up\)\>"
syntax match   juliaBaseTypeSpecial	display "\<\%(LocalProcess\|ClusterManager\)\>"
syntax match   juliaBaseTypeRandom	display "\<\%(AbstractRNG\|MersenneTwister\|RandomDevice\)\>"
syntax match   juliaBaseTypeDisplay	display "\<\%(Text\(Display\)\?\|\%(Abstract\)\?Display\|MIME\|HTML\)\>"
syntax match   juliaBaseTypeTime	display "\<\%(Date\%(Time\)\?\|DateFormat\)\>"
syntax match   juliaBaseTypeOther	display "\<\%(RemoteRef\|Task\|Condition\|VersionNumber\|IPv[46]\|SerializationState\|WorkerConfig\|Future\|RemoteChannel\|IPAddr\|Stack\%(Trace\|Frame\)\|\(Caching\|Worker\)Pool\|AbstractSerializer\)\>"

syntax match   juliaConstNum		display "\%(\<\%(\%(NaN\|Inf\)\%(16\|32\|64\)\?\|pi\|π\)\>\)"
" Note: recognition of ℯ, which Vim does not consider a valid identifier, is
" complicated. We detect possible uses by just looking for the character (for
" performance) and then check that it's actually used by its own.
" (This also tries to detect preceding number constants; it does so in a crude
" way.)
syntax match   juliaPossibleEuler	"ℯ" contains=juliaEuler
exec 'syntax match   juliaEuler		contained "\%(\%(^\|[' . s:nonidS_chars . s:op_chars_wc . ']\)\%(.\?[0-9][.0-9eEf_]*\d\)\?\)\@'.s:d(80).'<=ℯ\ze[' . s:nonidS_chars . s:op_chars_wc . ']"'
syntax match   juliaConstBool		display "\<\%(true\|false\)\>"
syntax match   juliaConstEnv		display "\<\%(ARGS\|ENV\|ENDIAN_BOM\|LOAD_PATH\|VERSION\|PROGRAM_FILE\|DEPOT_PATH\)\>"
syntax match   juliaConstIO		display "\<\%(std\%(out\|in\|err\)\|devnull\)\>"
syntax match   juliaConstC		display "\<\%(C_NULL\)\>"
syntax match   juliaConstGeneric	display "\<\%(nothing\|Main\|undef\|missing\)\>"

syntax match   juliaParamType		contained "[^{([:space:]<>\"]\+\ze{" nextgroup=juliaCurBraBlock

syntax match   juliaPossibleMacro	transparent "@" contains=juliaMacroCall,juliaMacroCallP,juliaPrintfMacro,juliaDocMacro,juliaDocMacroPre

exec 'syntax match   juliaMacro		contained "@' . s:idregex . '\%(\.' . s:idregex . '\)*"'
syntax match   juliaMacro		contained "@[!.~$%^*/\\|<>+-]\ze[^0-9]"
exec 'syntax region  juliaMacroCall	contained transparent start="\(@' . s:idregex . '\%(\.' . s:idregex . '\)*\)\@=\1\%([^(]\|$\)" end="\ze\%([])};#]\|$\|\<for\>\|\<end\>\)" contains=@juliaExpressions,juliaMacro,juliaSymbolS,juliaQuotedParBlockS'
exec 'syntax region  juliaMacroCall	contained transparent start="\(@.\)\@=\1\%([^(]\|$\)" end="\ze\%([])};#]\|$\|\<for\>\|\<end\>\)" contains=@juliaExpressions,juliaMacro,juliaSymbolS,juliaQuotedParBlockS'
exec 'syntax region  juliaMacroCallP	contained transparent start="@' . s:idregex . '\%(\.' . s:idregex . '\)*(" end=")\@'.s:d(1).'<=" contains=juliaMacro,juliaParBlock'
exec 'syntax region  juliaMacroCallP	contained transparent start="@.(" end=")\@'.s:d(1).'<=" contains=juliaMacro,juliaParBlock'

exec 'syntax match   juliaNumbers	transparent "\%(^\|[' . s:nonidS_chars . s:op_chars_wc . ']\)\@'.s:d(1).'<=\d\|\.\d\|im\>" contains=juliaNumber,juliaFloat,juliaComplexUnit'

"integer regexes
let s:dec_regex = '\d\%(_\?\d\)*\%(\>\|im\>\|\ze\D\)'
let s:hex_regex = '0x\x\%(_\?\x\)*\%(\>\|im\>\|\ze\X\)'
let s:bin_regex = '0b[01]\%(_\?[01]\)*\%(\>\|im\>\|\ze[^01]\)'
let s:oct_regex = '0o\o\%(_\?\o\)*\%(\>\|im\>\|\ze\O\)'

let s:int_regex = '\%(' . s:hex_regex .
      \           '\|'  . s:bin_regex .
      \           '\|'  . s:oct_regex .
      \           '\|'  . s:dec_regex .
      \           '\)'

"floating point regexes
"  starting with a dot, optional exponent
let s:float_regex1 = '\.\d\%(_\?\d\)*\%([eEf][-+]\?\d\+\)\?\%(\>\|im\>\|\ze\D\)'
"  with dot, optional exponent
let s:float_regex2 = '\d\%(_\?\d\)*\.\%(\d\%(_\?\d\)*\)\?\%([eEf][-+]\?\d\+\)\?\%(\>\|im\>\|\ze\D\)'
"  without dot, with exponent
let s:float_regex3 = '\d\%(_\?\d\)*[eEf][-+]\?\d\+\%(\>\|im\>\|\ze\D\)'

"hex floating point numbers
"  starting with a dot
let s:hexfloat_regex1 = '0x\.\%\(\x\%(_\?\x\)*\)\?[pP][-+]\?\d\+\%(\>\|im\>\|\ze\X\)'
"  starting with a digit
let s:hexfloat_regex2 = '0x\x\%(_\?\x\)*\%\(\.\%\(\x\%(_\?\x\)*\)\?\)\?[pP][-+]\?\d\+\%(\>\|im\>\|\ze\X\)'

let s:float_regex = '\%(' . s:float_regex3 .
      \             '\|'  . s:float_regex2 .
      \             '\|'  . s:float_regex1 .
      \             '\|'  . s:hexfloat_regex2 .
      \             '\|'  . s:hexfloat_regex1 .
      \             '\)'

exec 'syntax match   juliaNumber	contained "' . s:int_regex . '" contains=juliaComplexUnit'
exec 'syntax match   juliaFloat		contained "' . s:float_regex . '" contains=juliaComplexUnit'
syntax match   juliaComplexUnit		display	contained "\<im\>"

syntax match   juliaRangeOperator	display ":"
exec 'syntax match   juliaOperator	"' . s:operators . '"'

exec 'syntax region  juliaTernaryRegion	matchgroup=juliaTernaryOperator start="\s\zs?\ze\s" skip="\%(:\(:\|[^:[:space:]'."'".'"({[]\+\s*\ze:\)\|\%(?\s*\)\@'.s:d(6).'<=:(\)" end=":" contains=@juliaExpressions,juliaErrorSemicol'

let s:interp_dollar = '\([' . s:nonidS_chars . s:op_chars_wc . '!]\|^\)\@'.s:d(1).'<=\$'

exec 'syntax match   juliaDollarVar	display contained "' . s:interp_dollar . s:idregex . '"'
exec 'syntax region  juliaDollarPar	matchgroup=juliaDollarVar contained start="' .s:interp_dollar . '(" end=")" contains=@juliaExpressions'
exec 'syntax region  juliaDollarSqBra	matchgroup=juliaDollarVar contained start="' .s:interp_dollar . '\[" end="\]" contains=@juliaExpressions,juliaComprehensionFor,juliaSymbolS,juliaQuotedParBlockS'

syntax match   juliaChar		"'\\\?.'" contains=juliaSpecialChar
syntax match   juliaChar		display "'\\\o\{3\}'" contains=juliaOctalEscapeChar
syntax match   juliaChar		display "'\\x\x\{2\}'" contains=juliaHexEscapeChar
syntax match   juliaChar		display "'\\u\x\{1,4\}'" contains=juliaUniCharSmall
syntax match   juliaChar		display "'\\U\x\{1,8\}'" contains=juliaUniCharLarge

exec 'syntax match   juliaCTransOperator	"[[:space:]}' . s:nonid_chars . s:op_chars_wc . '!]\@'.s:d(1).'<!\.\?' . "'" . 'ᵀ\?"'

" TODO: some of these might be specialized; the rest could be just left to the
"       generic juliaStringPrefixed fallback
syntax region  juliaString		matchgroup=juliaStringDelim start=+\z("\(""\)\?\)+ skip=+\%(\\\\\)*\\"+ end=+\z1+ contains=@juliaStringVars,@juliaSpecialChars,@juliaSpellcheckStrings
syntax region  juliaStringPrefixed	contained matchgroup=juliaStringDelim start=+[^{([:space:]<>"]\+\z("\(""\)\?\)+ skip=+\%(\\\\\)*\\"+ end=+\z1+ contains=@juliaSpecialCharsRaw
syntax region  juliabString		matchgroup=juliaStringDelim start=+\<b\z("\(""\)\?\)+ skip=+\%(\\\\\)*\\"+ end=+\z1+ contains=@juliaSpecialChars
syntax region  juliasString		matchgroup=juliaStringDelim start=+\<s\z("\(""\)\?\)+ skip=+\%(\\\\\)*\\"+ end=+\z1+ contains=@juliaSpecialChars

syntax region  juliaDocString		matchgroup=juliaDocStringDelim fold start=+^"""+ skip=+\%(\\\\\)*\\"+ end=+"""+ contains=@juliaStringVars,@juliaSpecialChars,@juliaSpellcheckDocStrings

exec 'syntax region  juliaPrintfMacro		contained transparent start="@s\?printf(" end=")\@'.s:d(1).'<=" contains=juliaMacro,juliaPrintfParBlock'
syntax region  juliaPrintfMacro		contained transparent start="@s\?printf\s\+" end="\ze\%([])};#]\|$\|\<for\>\)" contains=@juliaExprsPrintf,juliaMacro,juliaSymbolS,juliaQuotedParBlockS
syntax region  juliaPrintfParBlock	contained matchgroup=juliaParDelim start="(" end=")" contains=@juliaExprsPrintf
syntax region  juliaPrintfString	contained matchgroup=juliaStringDelim start=+"+ skip=+\%(\\\\\)*\\"+ end=+"+ contains=@juliaSpecialChars,@juliaPrintfChars

exec 'syntax region  juliaDocMacroPre	contained transparent start=+@doc\s\+\%(' . s:idregex . '\%(\.' . s:idregex . '\)*\)\z("\%(""\)\?\)+ skip=+\%(\\\\\)*\\"+ end=+\(\z1\)\@'.s:d(3).'<=+ contains=juliaMacro,juliaDocStringMRaw'
exec 'syntax region  juliaDocMacro	contained transparent start=+@doc\s\+\z("\%(""\)\?\)+ skip=+\%(\\\\\)*\\"+ end=+\(\z1\)\@'.s:d(3).'<=+ contains=juliaMacro,juliaDocStringM'
syntax region  juliaDocStringMRaw	contained fold matchgroup=juliaDocStringDelim fold start=+\z\("\(""\)\?\)+ skip=+\%(\\\\\)*\\"+ end=+\z1+ contains=@juliaSpellcheckDocStrings
syntax region  juliaDocStringM		contained fold matchgroup=juliaDocStringDelim fold start=+\z\("\(""\)\?\)+ skip=+\%(\\\\\)*\\"+ end=+\z1+ contains=@juliaStringVars,@juliaSpecialChars,@juliaSpellcheckDocStrings

syntax region  juliaShellString		matchgroup=juliaStringDelim start=+`+ skip=+\%(\\\\\)*\\`+ end=+`+ contains=@juliaStringVars,juliaSpecialChar

syntax cluster juliaStringVars		contains=juliaStringVarsPar,juliaStringVarsSqBra,juliaStringVarsCurBra,juliaStringVarsPla
syntax region  juliaStringVarsPar	contained matchgroup=juliaStringVarDelim start="$(" end=")" contains=@juliaExpressions
syntax region  juliaStringVarsSqBra	contained matchgroup=juliaStringVarDelim start="$\[" end="\]" contains=@juliaExpressions,juliaComprehensionFor,juliaSymbolS,juliaQuotedParBlockS
syntax region  juliaStringVarsCurBra	contained matchgroup=juliaStringVarDelim start="${" end="}" contains=@juliaExpressions
exec 'syntax match   juliaStringVarsPla	contained "\$' . s:idregex . '"'

" TODO improve RegEx
syntax region  juliaRegEx		matchgroup=juliaStringDelim start=+\<r\z("\(""\)\?\)+ skip=+\%(\\\\\)*\\"+ end=+\z1[imsx]*+

syntax cluster juliaSpecialChars	contains=juliaSpecialChar,juliaDoubleBackslash,juliaEscapedQuote,juliaOctalEscapeChar,juliaHexEscapeChar,juliaUniCharSmall,juliaUniCharLarge
syntax match   juliaSpecialChar		display contained "\\."
syntax match   juliaOctalEscapeChar	display contained "\\\o\{3\}"
syntax match   juliaHexEscapeChar	display contained "\\x\x\{2\}"
syntax match   juliaUniCharSmall	display contained "\\u\x\{1,4\}"
syntax match   juliaUniCharLarge	display contained "\\U\x\{1,8\}"
syntax cluster juliaSpecialCharsRaw	contains=juliaDoubleBackslash,juliaEscapedQuote
syntax match   juliaDoubleBackslash	contained "\\\\"
syntax match   juliaEscapedQuote	contained "\\\""

syntax cluster juliaPrintfChars		contains=juliaErrorPrintfFmt,juliaPrintfFmt
syntax match   juliaErrorPrintfFmt	display contained "\\\?%."
syntax match   juliaPrintfFmt		display contained "%\%(\d\+\$\)\=[-+' #0]*\%(\d*\|\*\|\*\d\+\$\)\%(\.\%(\d*\|\*\|\*\d\+\$\)\)\=\%([hlLjqzt]\|ll\|hh\)\=[aAbdiuoxXDOUfFeEgGcCsSpn]"
syntax match   juliaPrintfFmt		display contained "%%"
syntax match   juliaPrintfFmt		display contained "\\%\%(\d\+\$\)\=[-+' #0]*\%(\d*\|\*\|\*\d\+\$\)\%(\.\%(\d*\|\*\|\*\d\+\$\)\)\=\%([hlLjqzt]\|ll\|hh\)\=[aAbdiuoxXDOUfFeEgGcCsSpn]"hs=s+1
syntax match   juliaPrintfFmt		display contained "\\%%"hs=s+1

" this is used to restrict the search for Symbols to when colons appear at all
" (for performance reasons)
syntax match   juliaPossibleSymbol	transparent ":\ze[^:]" contains=juliaSymbol,juliaQuotedParBlock,juliaQuotedQMarkPar,juliaColon

let s:quotable = '\%(' . s:idregex . '\|' . s:operators . '\|[?.]\|' . s:float_regex . '\|' . s:int_regex . '\)'
let s:quoting_colon = '\%(\%(^\s*\|\s\{6,\}\|[' . s:nonid_chars . s:op_chars_wc . ']\s*\)\@'.s:d(6).'<=\|\%(\<\%(return\|if\|else\%(if\)\?\|while\|try\|begin\)\s\+\)\@'.s:d(9).'<=\)\zs:'
let s:quoting_colonS = '\s\@'.s:d(1).'<=:'

" note: juliaSymbolS only works within whitespace-sensitive contexts,
" such as in macro calls without parentheses, or within square brackets.
" It is used to override the recognition of expressions like `a :b` as
" ranges rather than symbols in those contexts.
" (Note that such `a :b` expressions only allows at most 5 spaces between
" the identifier and the colon anyway.)

exec 'syntax match   juliaSymbol	contained "' . s:quoting_colon . s:quotable . '"'
exec 'syntax match   juliaSymbolS	contained "' . s:quoting_colonS . s:quotable . '"'

" same as above for quoted expressions such as :(expr)
exec 'syntax region   juliaQuotedParBlock	matchgroup=juliaQParDelim start="' . s:quoting_colon . '(" end=")" contains=@juliaExpressions'
exec 'syntax match    juliaQuotedQMarkPar	"' . s:quoting_colon . '(\s*?\s*)" contains=juliaQuotedQMark'
exec 'syntax region   juliaQuotedParBlockS	matchgroup=juliaQParDelim contained start="' . s:quoting_colonS . '(" end=")" contains=@juliaExpressions'


syntax match   juliaTypeOperatorR1	contained "[^{([:space:]<>\"]\+\%(\s*[<>]:\)\@="

" force precedence over Symbols
syntax match   juliaTypeOperator	contained "[<>:]:"
exec 'syntax match   juliaTypeOperatorR2	transparent "[<>:]:\s*\%(' . s:idregex . '\.\)*' . s:idregex . '" contains=juliaTypeOperator,juliaType,juliaDottedT,@juliaExpressions nextgroup=juliaTypeOperator'
syntax match   juliaIsaKeyword		contained "\<isa\>"
exec 'syntax match   juliaTypeOperatorR3	transparent "\<isa\s\+\%(' . s:idregex . '\.\)*' . s:idregex . '" contains=juliaIsaKeyword,juliaType,juliaDottedT,@juliaExpressions nextgroup=juliaIsaKeyword'

syntax match   juliaWhereKeyword       	"\<where\>"
exec 'syntax match   juliaWhereR	transparent "\<where\s\+' . s:idregex . '" contains=juliaWhereKeyword,juliaType,juliaDottedT,juliaIdSymbol'

syntax region  juliaCommentL		matchgroup=juliaCommentDelim excludenl start="#\ze\%([^=]\|$\)" end="$" contains=juliaTodo,@juliaSpellcheckComments
syntax region  juliaCommentM		matchgroup=juliaCommentDelim fold start="#=\ze\%([^#]\|$\)" end="=#" contains=juliaTodo,juliaCommentM,@juliaSpellcheckComments
syntax keyword juliaTodo		contained TODO FIXME XXX

" detect an end-of-line with only whitespace or comments before it
let s:eol = '\s*\%(\%(\%(#=\%(=#\@!\|[^=]\|\n\)\{-}=#\)\s*\)\+\)\?\%(#=\@!.*\)\?\n'

" a trailing comma, or colon, or an empty line in an import/using/export
" multi-line command. Used to recognize the as keyword, and for indentation
" (this needs to take precedence over normal commas and colons, and comments)
syntax cluster juliaContinuationItems	contains=juliaContinuationComma,juliaContinuationColon,juliaContinuationNone
exec 'syntax region  juliaContinuationComma	matchgroup=juliaComma contained start=",\ze'.s:eol.'" end="\n\+\ze." contains=@juliaCommentItems'
exec 'syntax region  juliaContinuationColon	matchgroup=juliaColon contained start=":\ze'.s:eol.'" end="\n\+\ze." contains=@juliaCommentItems'
exec 'syntax region  juliaContinuationNone	matchgroup=NONE contained start="\%(\<\%(import\|using\|export\)\>\|^\)\@'.s:d(6).'<=\ze'.s:eol.'" end="\n\+\ze." contains=@juliaCommentItems,juliaAsKeyword'
exec 'syntax match   juliaMacroName		contained "@' . s:idregex . '\%(\.' . s:idregex . '\)*"'

" the following are disabled by default, but
" can be enabled by entering e.g.
"   :hi link juliaParDelim Delimiter
hi def link juliaParDelim		juliaNone
hi def link juliaSemicolon		juliaNone
hi def link juliaComma			juliaNone
hi def link juliaFunctionCall		juliaNone

hi def link juliaColon			juliaOperator

hi def link juliaFunctionName		juliaFunction
hi def link juliaFunctionName1		juliaFunction
hi def link juliaMacroName		juliaMacro


hi def link juliaKeyword		Keyword
hi def link juliaWhereKeyword		Keyword
hi def link juliaInfixKeyword		Keyword
hi def link juliaIsaKeyword		Keyword
hi def link juliaAsKeyword		Keyword
hi def link juliaRepKeyword		Keyword
hi def link juliaBlKeyword		Keyword
hi def link juliaConditional		Conditional
hi def link juliaRepeat			Repeat
hi def link juliaException		Exception
hi def link juliaOuter			Keyword
hi def link juliaBaseTypeBasic		Type
hi def link juliaBaseTypeNum		Type
hi def link juliaBaseTypeC		Type
hi def link juliaBaseTypeError		Type
hi def link juliaBaseTypeIter		Type
hi def link juliaBaseTypeString		Type
hi def link juliaBaseTypeArray		Type
hi def link juliaBaseTypeDict		Type
hi def link juliaBaseTypeSet		Type
hi def link juliaBaseTypeIO		Type
hi def link juliaBaseTypeProcess	Type
hi def link juliaBaseTypeRange		Type
hi def link juliaBaseTypeRegex		Type
hi def link juliaBaseTypeFact		Type
hi def link juliaBaseTypeSort		Type
hi def link juliaBaseTypeRound		Type
hi def link juliaBaseTypeSpecial	Type
hi def link juliaBaseTypeRandom		Type
hi def link juliaBaseTypeDisplay	Type
hi def link juliaBaseTypeTime		Type
hi def link juliaBaseTypeOther		Type

hi def link juliaType			Type
hi def link juliaParamType		Type
hi def link juliaTypeOperatorR1		Type

" NOTE: deprecated constants are not highlighted as such. For once,
" one can still legitimately use them by importing Base.MathConstants.
" Plus, one-letter variables like `e` and `γ` can be used with other
" meanings.
hi def link juliaConstNum		Constant
hi def link juliaEuler			Constant

hi def link juliaConstEnv		Constant
hi def link juliaConstC			Constant
hi def link juliaConstLimits		Constant
hi def link juliaConstGeneric		Constant
hi def link juliaRangeKeyword		Constant
hi def link juliaConstBool		Boolean
hi def link juliaConstIO		Boolean

hi def link juliaComprehensionFor	Keyword
hi def link juliaComprehensionIf	Keyword

hi def link juliaDollarVar		Identifier

hi def link juliaFunction		Function
hi def link juliaMacro			Macro
hi def link juliaSymbol			Identifier
hi def link juliaSymbolS		Identifier
hi def link juliaQParDelim		Identifier
hi def link juliaQuotedQMarkPar		Identifier
hi def link juliaQuotedQMark		juliaOperatorHL

hi def link juliaNumber			Number
hi def link juliaFloat			Float
hi def link juliaComplexUnit		Constant

hi def link juliaChar			Character

hi def link juliaString			String
hi def link juliaStringPrefixed		juliaString
hi def link juliabString		juliaString
hi def link juliasString		juliaString
hi def link juliavString		juliaString
hi def link juliarString		juliaString
hi def link juliaipString		juliaString
hi def link juliabigString		juliaString
hi def link juliaMIMEString		juliaString
hi def link juliarawString		juliaString
hi def link juliatestString		juliaString
hi def link juliahtmlString		juliaString
hi def link juliaint128String		juliaString
hi def link juliaPrintfString		juliaString
hi def link juliaShellString		juliaString
hi def link juliaDocString		juliaString
hi def link juliaDocStringM		juliaDocString
hi def link juliaDocStringMRaw		juliaDocString
hi def link juliaStringDelim		juliaString
hi def link juliaDocStringDelim		juliaDocString
hi def link juliaStringVarsPla		Identifier
hi def link juliaStringVarDelim		Identifier

hi def link juliaRegEx			String

hi def link juliaSpecialChar		SpecialChar
hi def link juliaOctalEscapeChar	SpecialChar
hi def link juliaHexEscapeChar		SpecialChar
hi def link juliaUniCharSmall		SpecialChar
hi def link juliaUniCharLarge		SpecialChar
hi def link juliaDoubleBackslash	SpecialChar
hi def link juliaEscapedQuote		SpecialChar

hi def link juliaPrintfFmt		SpecialChar

if s:julia_highlight_operators
  hi! def link juliaOperatorHL		Operator
else
  hi! def link juliaOperatorHL		juliaNone
endif
hi def link juliaOperator		juliaOperatorHL
hi def link juliaRangeOperator		juliaOperatorHL
hi def link juliaCTransOperator		juliaOperatorHL
hi def link juliaTernaryOperator	juliaOperatorHL
hi def link juliaTypeOperator		juliaOperatorHL

hi def link juliaCommentL		Comment
hi def link juliaCommentM		Comment
hi def link juliaCommentDelim		Comment
hi def link juliaTodo			Todo

hi def link juliaErrorPar		juliaError
hi def link juliaErrorEnd		juliaError
hi def link juliaErrorElse		juliaError
hi def link juliaErrorCatch		juliaError
hi def link juliaErrorFinally		juliaError
hi def link juliaErrorSemicol		juliaError
hi def link juliaErrorPrintfFmt		juliaError

hi def link juliaError			Error

syntax sync fromstart

let b:current_syntax = "julia"

let &cpo = s:cpo_save
unlet s:cpo_save
