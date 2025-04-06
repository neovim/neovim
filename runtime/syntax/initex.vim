" Vim syntax file
" Language:             TeX (core definition)
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" This follows the grouping (sort of) found at
" http: //www.tug.org/utilities/plain/cseq.html#top-fam

syn keyword initexTodo                          TODO FIXME XXX NOTE

syn match initexComment                         display contains=initexTodo
      \ '\\\@<!\%(\\\\\)*\zs%.*$'

syn match   initexDimension                     display contains=@NoSpell
      \ '[+-]\=\s*\%(\d\+\%([.,]\d*\)\=\|[.,]\d\+\)\s*\%(true\)\=\s*\%(p[tc]\|in\|bp\|c[mc]\|m[mu]\|dd\|sp\|e[mx]\)\>'

syn cluster initexBox
      \ contains=initexBoxCommand,initexBoxInternalQuantity,
      \ initexBoxParameterDimen,initexBoxParameterInteger,
      \ initexBoxParameterToken

syn cluster initexCharacter
      \ contains=initexCharacterCommand,initexCharacterInternalQuantity,
      \ initexCharacterParameterInteger

syn cluster initexDebugging
      \ contains=initexDebuggingCommand,initexDebuggingParameterInteger,
      \ initexDebuggingParameterToken

syn cluster initexFileIO
      \ contains=initexFileIOCommand,initexFileIOInternalQuantity,
      \ initexFileIOParameterToken

syn cluster initexFonts
      \ contains=initexFontsCommand,initexFontsInternalQuantity

syn cluster initexGlue
      \ contains=initexGlueCommand,initexGlueDerivedCommand

syn cluster initexHyphenation
      \ contains=initexHyphenationCommand,initexHyphenationDerivedCommand,
      \ initexHyphenationInternalQuantity,initexHyphenationParameterInteger

syn cluster initexInserts
      \ contains=initexInsertsCommand,initexInsertsParameterDimen,
      \ initexInsertsParameterGlue,initexInsertsParameterInteger

syn cluster initexJob
      \ contains=initexJobCommand,initexJobInternalQuantity,
      \ initexJobParameterInteger

syn cluster initexKern
      \ contains=initexKernCommand,initexKernInternalQuantity

syn cluster initexLogic
      \ contains=initexLogicCommand

syn cluster initexMacro
      \ contains=initexMacroCommand,initexMacroDerivedCommand,
      \ initexMacroParameterInteger

syn cluster initexMarks
      \ contains=initexMarksCommand

syn cluster initexMath
      \ contains=initexMathCommand,initexMathDerivedCommand,
      \ initexMathInternalQuantity,initexMathParameterDimen,
      \ initexMathParameterGlue,initexMathParameterInteger,
      \ initexMathParameterMuglue,initexMathParameterToken

syn cluster initexPage
      \ contains=initexPageInternalQuantity,initexPageParameterDimen,
      \ initexPageParameterGlue

syn cluster initexParagraph
      \ contains=initexParagraphCommand,initexParagraphInternalQuantity,
      \ initexParagraphParameterDimen,initexParagraphParameterGlue,
      \ initexParagraphParameterInteger,initexParagraphParameterToken

syn cluster initexPenalties
      \ contains=initexPenaltiesCommand,initexPenaltiesInternalQuantity,
      \ initexPenaltiesParameterInteger

syn cluster initexRegisters
      \ contains=initexRegistersCommand,initexRegistersInternalQuantity

syn cluster initexTables
      \ contains=initexTablesCommand,initexTablesParameterGlue,
      \ initexTablesParameterToken

syn cluster initexCommand
      \ contains=initexBoxCommand,initexCharacterCommand,
      \ initexDebuggingCommand,initexFileIOCommand,
      \ initexFontsCommand,initexGlueCommand,
      \ initexHyphenationCommand,initexInsertsCommand,
      \ initexJobCommand,initexKernCommand,initexLogicCommand,
      \ initexMacroCommand,initexMarksCommand,initexMathCommand,
      \ initexParagraphCommand,initexPenaltiesCommand,initexRegistersCommand,
      \ initexTablesCommand

syn match   initexBoxCommand                    display contains=@NoSpell
      \ '\\\%([hv]\=box\|[cx]\=leaders\|copy\|[hv]rule\|lastbox\|setbox\|un[hv]\%(box\|copy\)\|vtop\)\>'
syn match   initexCharacterCommand              display contains=@NoSpell
      \ '\\\%([] ]\|\%(^^M\|accent\|char\|\%(lower\|upper\)case\|number\|romannumeral\|string\)\>\)'
syn match   initexDebuggingCommand              display contains=@NoSpell
      \ '\\\%(\%(batch\|\%(non\|error\)stop\|scroll\)mode\|\%(err\)\=message\|meaning\|show\%(box\%(breadth\|depth\)\=\|lists\|the\)\)\>'
syn match   initexFileIOCommand                 display contains=@NoSpell
      \ '\\\%(\%(close\|open\)\%(in\|out\)\|endinput\|immediate\|input\|read\|shipout\|special\|write\)\>'
syn match   initexFontsCommand                  display contains=@NoSpell
      \ '\\\%(/\|fontname\)\>'
syn match   initexGlueCommand                   display contains=@NoSpell
      \ '\\\%([hv]\|un\)skip\>'
syn match   initexHyphenationCommand            display contains=@NoSpell
      \ '\\\%(discretionary\|hyphenation\|patterns\|setlanguage\)\>'
syn match   initexInsertsCommand                display contains=@NoSpell
      \ '\\\%(insert\|split\%(bot\|first\)mark\|vsplit\)\>'
syn match   initexJobCommand                    display contains=@NoSpell
      \ '\\\%(dump\|end\|jobname\)\>'
syn match   initexKernCommand                   display contains=@NoSpell
      \ '\\\%(kern\|lower\|move\%(left\|right\)\|raise\|unkern\)\>'
syn match   initexLogicCommand                  display contains=@NoSpell
      \ '\\\%(else\|fi\|if[a-zA-Z@]\+\|or\)\>'
"      \ '\\\%(else\|fi\|if\%(case\|cat\|dim\|eof\|false\|[hv]box\|[hmv]mode\|inner\|num\|odd\|true\|void\|x\)\=\|or\)\>'
syn match   initexMacroCommand                  display contains=@NoSpell
      \ '\\\%(after\%(assignment\|group\)\|\%(begin\|end\)group\|\%(end\)\=csname\|e\=def\|expandafter\|futurelet\|global\|let\|long\|noexpand\|outer\|relax\|the\)\>'
syn match   initexMarksCommand                  display contains=@NoSpell
      \ '\\\%(bot\|first\|top\)\=mark\>'
syn match   initexMathCommand                   display contains=@NoSpell
      \ '\\\%(abovewithdelims\|delimiter\|display\%(limits\|style\)\|l\=eqno\|left\|\%(no\)\=limits\|math\%(accent\|bin\|char\|choice\|close\|code\|inner\|op\|open\|ord\|punct\|rel\)\|mkern\|mskip\|muskipdef\|nonscript\|\%(over\|under\)line\|radical\|right\|\%(\%(script\)\{1,2}\|text\)style\|vcenter\)\>'
syn match   initexParagraphCommand              display contains=@NoSpell
      \ '\\\%(ignorespaces\|indent\|no\%(boundary\|indent\)\|par\|vadjust\)\>'
syn match   initexPenaltiesCommand              display contains=@NoSpell
      \ '\\\%(un\)\=penalty\>'
syn match   initexRegistersCommand              display contains=@NoSpell
      \ '\\\%(advance\|\%(count\|dimen\|skip\|toks\)def\|divide\|multiply\)\>'
syn match   initexTablesCommand                 display contains=@NoSpell
      \ '\\\%(cr\|crcr\|[hv]align\|noalign\|omit\|span\)\>'

syn cluster initexDerivedCommand
      \ contains=initexGlueDerivedCommand,initexHyphenationDerivedCommand,
      \ initexMacroDerivedCommand,initexMathDerivedCommand

syn match   initexGlueDerivedCommand            display contains=@NoSpell
      \ '\\\%([hv]fil\%(l\|neg\)\=\|[hv]ss\)\>'
syn match   initexHyphenationDerivedCommand     display contains=@NoSpell
      \ '\\-'
syn match   initexMacroDerivedCommand           display contains=@NoSpell
      \ '\\[gx]def\>'
syn match   initexMathDerivedCommand            display contains=@NoSpell
      \ '\\\%(above\|atop\%(withdelims\)\=\|mathchardef\|over\|overwithdelims\)\>'

syn cluster initexInternalQuantity
      \ contains=initexBoxInternalQuantity,initexCharacterInternalQuantity,
      \ initexFileIOInternalQuantity,initexFontsInternalQuantity,
      \ initexHyphenationInternalQuantity,initexJobInternalQuantity,
      \ initexKernInternalQuantity,initexMathInternalQuantity,
      \ initexPageInternalQuantity,initexParagraphInternalQuantity,
      \ initexPenaltiesInternalQuantity,initexRegistersInternalQuantity

syn match   initexBoxInternalQuantity           display contains=@NoSpell
      \ '\\\%(badness\|dp\|ht\|prevdepth\|wd\)\>'
syn match   initexCharacterInternalQuantity     display contains=@NoSpell
      \ '\\\%(catcode\|chardef\|\%([ul]c\|sf\)code\)\>'
syn match   initexFileIOInternalQuantity        display contains=@NoSpell
      \ '\\inputlineno\>'
syn match   initexFontsInternalQuantity         display contains=@NoSpell
      \ '\\\%(font\%(dimen\)\=\|nullfont\)\>'
syn match   initexHyphenationInternalQuantity   display contains=@NoSpell
      \ '\\hyphenchar\>'
syn match   initexJobInternalQuantity           display contains=@NoSpell
      \ '\\deadcycles\>'
syn match   initexKernInternalQuantity          display contains=@NoSpell
      \ '\\lastkern\>'
syn match   initexMathInternalQuantity          display contains=@NoSpell
      \ '\\\%(delcode\|mathcode\|muskip\|\%(\%(script\)\{1,2}\|text\)font\|skewchar\)\>'
syn match   initexPageInternalQuantity          display contains=@NoSpell
      \ '\\page\%(depth\|fil\{1,3}stretch\|goal\|shrink\|stretch\|total\)\>'
syn match   initexParagraphInternalQuantity     display contains=@NoSpell
      \ '\\\%(prevgraf\|spacefactor\)\>'
syn match   initexPenaltiesInternalQuantity     display contains=@NoSpell
      \ '\\lastpenalty\>'
syn match   initexRegistersInternalQuantity     display contains=@NoSpell
      \ '\\\%(count\|dimen\|skip\|toks\)\d\+\>'

syn cluster initexParameterDimen
      \ contains=initexBoxParameterDimen,initexInsertsParameterDimen,
      \ initexMathParameterDimen,initexPageParameterDimen,
      \ initexParagraphParameterDimen

syn match   initexBoxParameterDimen             display contains=@NoSpell
      \ '\\\%(boxmaxdepth\|[hv]fuzz\|overfullrule\)\>'
syn match   initexInsertsParameterDimen         display contains=@NoSpell
      \ '\\splitmaxdepth\>'
syn match   initexMathParameterDimen            display contains=@NoSpell
      \ '\\\%(delimitershortfall\|display\%(indent\|width\)\|mathsurround\|nulldelimiterspace\|predisplaysize\|scriptspace\)\>'
syn match   initexPageParameterDimen            display contains=@NoSpell
      \ '\\\%([hv]offset\|maxdepth\|vsize\)\>'
syn match   initexParagraphParameterDimen       display contains=@NoSpell
      \ '\\\%(emergencystretch\|\%(hang\|par\)indent\|hsize\|lineskiplimit\)\>'

syn cluster initexParameterGlue
      \ contains=initexInsertsParameterGlue,initexMathParameterGlue,
      \ initexPageParameterGlue,initexParagraphParameterGlue,
      \ initexTablesParameterGlue

syn match   initexInsertsParameterGlue          display contains=@NoSpell
      \ '\\splittopskip\>'
syn match   initexMathParameterGlue             display contains=@NoSpell
      \ '\\\%(above\|below\)display\%(short\)\=skip\>'
syn match   initexPageParameterGlue             display contains=@NoSpell
      \ '\\topskip\>'
syn match   initexParagraphParameterGlue        display contains=@NoSpell
      \ '\\\%(baseline\|left\|line\|par\%(fill\)\=\|right\|x\=space\)skip\>'
syn match   initexTablesParameterGlue           display contains=@NoSpell
      \ '\\tabskip\>'

syn cluster initexParameterInteger
      \ contains=initexBoxParameterInteger,initexCharacterParameterInteger,
      \ initexDebuggingParameterInteger,initexHyphenationParameterInteger,
      \ initexInsertsParameterInteger,initexJobParameterInteger,
      \ initexMacroParameterInteger,initexMathParameterInteger,
      \ initexParagraphParameterInteger,initexPenaltiesParameterInteger,

syn match   initexBoxParameterInteger           display contains=@NoSpell
      \ '\\[hv]badness\>'
syn match   initexCharacterParameterInteger     display contains=@NoSpell
      \ '\\\%(\%(endline\|escape\|newline\)char\)\>'
syn match   initexDebuggingParameterInteger     display contains=@NoSpell
      \ '\\\%(errorcontextlines\|pausing\|tracing\%(commands\|lostchars\|macros\|online\|output\|pages\|paragraphs\|restores|stats\)\)\>'
syn match   initexHyphenationParameterInteger   display contains=@NoSpell
      \ '\\\%(defaulthyphenchar\|language\|\%(left\|right\)hyphenmin\|uchyph\)\>'
syn match   initexInsertsParameterInteger       display contains=@NoSpell
      \ '\\\%(holdinginserts\)\>'
syn match   initexJobParameterInteger           display contains=@NoSpell
      \ '\\\%(day\|mag\|maxdeadcycles\|month\|time\|year\)\>'
syn match   initexMacroParameterInteger         display contains=@NoSpell
      \ '\\globaldefs\>'
syn match   initexMathParameterInteger          display contains=@NoSpell
      \ '\\\%(binoppenalty\|defaultskewchar\|delimiterfactor\|displaywidowpenalty\|fam\|\%(post\|pre\)displaypenalty\|relpenalty\)\>'
syn match   initexParagraphParameterInteger     display contains=@NoSpell
      \ '\\\%(\%(adj\|\%(double\|final\)hyphen\)demerits\|looseness\|\%(pre\)\=tolerance\)\>'
syn match   initexPenaltiesParameterInteger     display contains=@NoSpell
      \ '\\\%(broken\|club\|exhyphen\|floating\|hyphen\|interline\|line\|output\|widow\)penalty\>'

syn cluster initexParameterMuglue
      \ contains=initexMathParameterMuglue

syn match   initexMathParameterMuglue           display contains=@NoSpell
      \ '\\\%(med\|thick\|thin\)muskip\>'

syn cluster initexParameterDimen
      \ contains=initexBoxParameterToken,initexDebuggingParameterToken,
      \ initexFileIOParameterToken,initexMathParameterToken,
      \ initexParagraphParameterToken,initexTablesParameterToken

syn match   initexBoxParameterToken             display contains=@NoSpell
      \ '\\every[hv]box\>'
syn match   initexDebuggingParameterToken       display contains=@NoSpell
      \ '\\errhelp\>'
syn match   initexFileIOParameterToken          display contains=@NoSpell
      \ '\\output\>'
syn match   initexMathParameterToken            display contains=@NoSpell
      \ '\\every\%(display\|math\)\>'
syn match   initexParagraphParameterToken       display contains=@NoSpell
      \ '\\everypar\>'
syn match   initexTablesParameterToken          display contains=@NoSpell
      \ '\\everycr\>'


hi def link initexCharacter                     Character
hi def link initexNumber                        Number

hi def link initexIdentifier                    Identifier

hi def link initexStatement                     Statement
hi def link initexConditional                   Conditional

hi def link initexPreProc                       PreProc
hi def link initexMacro                         Macro

hi def link initexType                          Type

hi def link initexDebug                         Debug

hi def link initexTodo                          Todo
hi def link initexComment                       Comment
hi def link initexDimension                     initexNumber

hi def link initexCommand                       initexStatement
hi def link initexBoxCommand                    initexCommand
hi def link initexCharacterCommand              initexCharacter
hi def link initexDebuggingCommand              initexDebug
hi def link initexFileIOCommand                 initexCommand
hi def link initexFontsCommand                  initexType
hi def link initexGlueCommand                   initexCommand
hi def link initexHyphenationCommand            initexCommand
hi def link initexInsertsCommand                initexCommand
hi def link initexJobCommand                    initexPreProc
hi def link initexKernCommand                   initexCommand
hi def link initexLogicCommand                  initexConditional
hi def link initexMacroCommand                  initexMacro
hi def link initexMarksCommand                  initexCommand
hi def link initexMathCommand                   initexCommand
hi def link initexParagraphCommand              initexCommand
hi def link initexPenaltiesCommand              initexCommand
hi def link initexRegistersCommand              initexCommand
hi def link initexTablesCommand                 initexCommand

hi def link initexDerivedCommand                initexStatement
hi def link initexGlueDerivedCommand            initexDerivedCommand
hi def link initexHyphenationDerivedCommand     initexDerivedCommand
hi def link initexMacroDerivedCommand           initexDerivedCommand
hi def link initexMathDerivedCommand            initexDerivedCommand

hi def link initexInternalQuantity              initexIdentifier
hi def link initexBoxInternalQuantity           initexInternalQuantity
hi def link initexCharacterInternalQuantity     initexInternalQuantity
hi def link initexFileIOInternalQuantity        initexInternalQuantity
hi def link initexFontsInternalQuantity         initexInternalQuantity
hi def link initexHyphenationInternalQuantity   initexInternalQuantity
hi def link initexJobInternalQuantity           initexInternalQuantity
hi def link initexKernInternalQuantity          initexInternalQuantity
hi def link initexMathInternalQuantity          initexInternalQuantity
hi def link initexPageInternalQuantity          initexInternalQuantity
hi def link initexParagraphInternalQuantity     initexInternalQuantity
hi def link initexPenaltiesInternalQuantity     initexInternalQuantity
hi def link initexRegistersInternalQuantity     initexInternalQuantity

hi def link initexParameterDimen                initexNumber
hi def link initexBoxParameterDimen             initexParameterDimen
hi def link initexInsertsParameterDimen         initexParameterDimen
hi def link initexMathParameterDimen            initexParameterDimen
hi def link initexPageParameterDimen            initexParameterDimen
hi def link initexParagraphParameterDimen       initexParameterDimen

hi def link initexParameterGlue                 initexNumber
hi def link initexInsertsParameterGlue          initexParameterGlue
hi def link initexMathParameterGlue             initexParameterGlue
hi def link initexPageParameterGlue             initexParameterGlue
hi def link initexParagraphParameterGlue        initexParameterGlue
hi def link initexTablesParameterGlue           initexParameterGlue

hi def link initexParameterInteger              initexNumber
hi def link initexBoxParameterInteger           initexParameterInteger
hi def link initexCharacterParameterInteger     initexParameterInteger
hi def link initexDebuggingParameterInteger     initexParameterInteger
hi def link initexHyphenationParameterInteger   initexParameterInteger
hi def link initexInsertsParameterInteger       initexParameterInteger
hi def link initexJobParameterInteger           initexParameterInteger
hi def link initexMacroParameterInteger         initexParameterInteger
hi def link initexMathParameterInteger          initexParameterInteger
hi def link initexParagraphParameterInteger     initexParameterInteger
hi def link initexPenaltiesParameterInteger     initexParameterInteger

hi def link initexParameterMuglue               initexNumber
hi def link initexMathParameterMuglue           initexParameterMuglue

hi def link initexParameterToken                initexIdentifier
hi def link initexBoxParameterToken             initexParameterToken
hi def link initexDebuggingParameterToken       initexParameterToken
hi def link initexFileIOParameterToken          initexParameterToken
hi def link initexMathParameterToken            initexParameterToken
hi def link initexParagraphParameterToken       initexParameterToken
hi def link initexTablesParameterToken          initexParameterToken

let b:current_syntax = "initex"

let &cpo = s:cpo_save
unlet s:cpo_save
