" Vim syntax file
" Language:	Rexx
" Maintainer:	Thomas Geulig <geulig@nentec.de>
" Last Change:  2012 Sep 14, added support for new ooRexx 4.0 features
" URL:		http://www.geulig.de/vim/rexx.vim
" Special Thanks to Dan Sharp <dwsharp@hotmail.com> and Rony G. Flatscher
" <Rony.Flatscher@wu-wien.ac.at> for comments and additions

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

" add to valid identifier chars
setlocal iskeyword+=.
setlocal iskeyword+=!
setlocal iskeyword+=?

" ---rgf, position important: must be before comments etc. !
syn match rexxOperator "[=|\/\\\+\*\[\],;:<>&\~%\-]"

" rgf syn match rexxIdentifier        "\<[a-zA-Z\!\?_]\([a-zA-Z0-9._?!]\)*\>"
syn match rexxIdentifier        "\<\K\k*\>"
syn match rexxEnvironmentSymbol "\<\.\k\+\>"

" A Keyword is the first symbol in a clause.  A clause begins at the start
" of a line or after a semicolon.  THEN, ELSE, OTHERWISE, and colons are always
" followed by an implied semicolon.
syn match rexxClause "\(^\|;\|:\|then \|else \|when \|otherwise \)\s*\S*" contains=ALLBUT,rexxParse2,rexxRaise2,rexxForward2

" Considered keywords when used together in a phrase and begin a clause
syn match rexxParse "\<parse\s*\(\(upper\|lower\|caseless\)\s*\)\?\(arg\|linein\|pull\|source\|var\|\<value\>\|version\)\>" containedin=rexxClause contains=rexxParse2
syn match rexxParse2 "\<with\>" containedin=rexxParse

syn match rexxKeyword contained "\<numeric \(digits\|form \(scientific\|engineering\|value\)\|fuzz\)\>"
syn match rexxKeyword contained "\<\(address\|trace\)\( value\)\?\>"
syn match rexxKeyword contained "\<procedure\(\s*expose\)\?\>"

syn match rexxKeyword contained "\<\(do\|loop\)\>\(\s\+label\s\+\k*\)\?\(\s\+forever\)\?\>"
syn match rexxKeyword contained "\<use\>\s*\(strict\s*\)\?\<arg\>"

" Another keyword phrase, separated to aid highlighting in rexxFunction
syn match rexxRegularCallSignal contained "\<\(call\|signal\)\s\(\s*on\>\|\s*off\>\)\@!\(\k\+\ze\|\ze(\)\(\s*\|;\|$\|(\)"
syn region rexxLabel contained start="\<\(call\|signal\)\>\s*\zs\(\k*\|(\)" end="\ze\(\s*\|;\|$\|(\)" containedin=rexxRegularCallSignal

syn match rexxExceptionHandling contained "\<\(call\|signal\)\>\s\+\<\(on\|off\)\>.*\(;\|$\)" contains=rexxComment

" hilite label given after keyword "name"
syn match rexxLabel "name\s\+\zs\k\+\ze" containedin=rexxExceptionHandling
" hilite condition name (serves as label)
syn match rexxLabel "\<\(call\|signal\)\>\s\+\<\(on\|off\)\>\s*\zs\k\+\ze\s*\(;\|$\)" containedin=rexxExceptionHandling
" user exception handling, hilite user defined name
syn region rexxLabel contained start="user\s\+\zs\k" end="\ze\(\s\|;\|$\)" containedin=rexxExceptionHandling

" Considered keywords when they begin a clause
syn match rexxKeywordStatements "\<\(arg\|catch\|do\|drop\|end\|exit\|expose\|finally\|forward\|if\|interpret\|iterate\|leave\|loop\|nop\)\>"
syn match rexxKeywordStatements "\<\(options\|pull\|push\|queue\|raise\|reply\|return\|say\|select\|trace\)\>"

" Conditional keywords starting a new statement
syn match rexxConditional "\<\(then\|else\|when\|otherwise\)\(\s*\|;\|\_$\|\)\>" contains=rexxKeywordStatements

" Conditional phrases
syn match rexxLoopKeywords "\<\(to\|by\|for\|until\|while\|over\)\>" containedin=doLoopSelectLabelRegion

" must be after Conditional phrases!
syn match doLoopSelectLabelRegion "\<\(do\|loop\|select\)\>\s\+\(label\s\+\)\?\(\s\+\k\+\s\+\zs\<over\>\)\?\k*\(\s\+forever\)\?\(\s\|;\|$\)" contains=doLoopSelectLabelRegion,rexxStartValueAssignment,rexxLoopKeywords

" color label's name
syn match rexxLabel2 "\<\(do\|loop\|select\)\>\s\+label\s\+\zs\k*\ze" containedin=doLoopSelectLabelRegion

" make sure control variable is normal
" TODO: re-activate ?
"rgf syn match rexxControlVariable        "\<\(do\|loop\)\>\(\s\+label\s\+\k*\)\?\s\+\zs.*\ze\s\+\<over\>" containedin=doLoopSelectLabelRegion

" make sure control variable assignment is normal
syn match rexxStartValueAssignment       "\<\(do\|loop\)\>\(\s\+label\s\+\k*\)\?\s\+\zs.*\ze\(=.*\)\?\s\+\<to\>" containedin=doLoopSelectLabelRegion

" highlight label name
syn match endIterateLeaveLabelRegion "\<\(end\|leave\|iterate\)\>\(\s\+\K\k*\)" contains=rexxLabel2
syn match rexxLabel2 "\<\(end\|leave\|iterate\)\>\s\+\zs\k*\ze" containedin=endIterateLeaveLabelRegion

" Guard statement
syn match rexxGuard "\(^\|;\|:\)\s*\<guard\>\s\+\<\(on\|off\)\>"

" Trace statement
syn match rexxTrace "\(^\|;\|:\)\s*\<trace\>\s\+\<\K\k*\>"

" Raise statement
" syn match rexxRaise "\(^\|;\|:\)\s\+\<raise\>\s*\<\(propagate\|error\|failure\|syntax\|user\)\>\?" contains=rexxRaise2
syn match rexxRaise "\(^\|;\|:\)\s*\<raise\>\s*\<\(propagate\|error\|failure\|syntax\|user\)\>\?" contains=rexxRaise2
syn match rexxRaise2 "\<\(additional\|array\|description\|exit\|propagate\|return\)\>" containedin=rexxRaise

" Forward statement
syn match rexxForward  "\(^\|;\|:\)\<forward\>\s*" contains=rexxForward2
syn match rexxForward2 "\<\(arguments\|array\|continue\|message\|class\|to\)\>" contained

" Functions/Procedures
syn match rexxFunction 	"\<\<[a-zA-Z\!\?_]\k*\>("me=e-1
syn match rexxFunction "[()]"

" String constants
syn region rexxString	start=+"+ skip=+""+ end=+"\(x\|b\)\?+ oneline
syn region rexxString	start=+'+ skip=+''+ end=+'\(x\|b\)\?+ oneline

syn region rexxParen transparent start='(' end=')' contains=ALLBUT,rexxParenError,rexxTodo,rexxLabel,rexxKeyword
" Catch errors caused by wrong parenthesis
syn match rexxParenError	 ")"
syn match rexxInParen		"[\\[\\]{}]"

" Comments
syn region	rexxComment	start="/\*"	end="\*/" contains=rexxTodo,rexxComment
syn match	rexxCommentError "\*/"
syn region	rexxLineComment	start="--"	end="\_$" oneline

" Highlight User Labels
" check for labels between comments, labels stated in a statement in the middle of a line
syn match rexxLabel		 "\(\_^\|;\)\s*\(\/\*.*\*\/\)*\s*\k\+\s*\(\/\*.*\*\/\)*\s*:"me=e-1 contains=rexxTodo,rexxComment

syn keyword rexxTodo contained	TODO FIXME XXX

" ooRexx messages
syn region rexxMessageOperator start="\(\~\|\~\~\)" end="\(\S\|\s\)"me=e-1
syn match rexxMessage "\(\~\|\~\~\)\s*\<\.*[a-zA-Z]\([a-zA-Z0-9._?!]\)*\>" contains=rexxMessageOperator

" line continuations, take care of (line-)comments after it
syn match rexxLineContinue ",\ze\s*\(--.*\|\/\*.*\)*$"

" the following is necessary, otherwise three consecutive dashes will cause it to highlight the first one
syn match rexxLineContinue "-\ze-\@!\s*\(--.*\|\s*\/\*.*\)\?$"

" Special Variables
syn keyword rexxSpecialVariable  sigl rc result self super
syn keyword rexxSpecialVariable  .environment .error .input .local .methods .output .rs .stderr .stdin .stdout .stdque

" Constants
syn keyword rexxConst .true .false .nil .endOfLine .line .context

" Rexx numbers
" int like number
syn match rexxNumber '\d\+' contained
syn match rexxNumber '[-+]\s*\d\+' contained

" Floating point number with decimal
syn match rexxNumber '\d\+\.\d*' contained
syn match rexxNumber '[-+]\s*\d\+\.\d*' contained

" Floating point like number with E
syn match rexxNumber '[-+]\s*\d*[eE][\-+]\d\+' contained
syn match rexxNumber '\d*[eE][\-+]\d\+' contained

" Floating point like number with E and decimal point (+,-)
syn match rexxNumber '[-+]\s*\d*\.\d*[eE][\-+]\d\+' contained
syn match rexxNumber '\d*\.\d*[eE][\-+]\d\+' contained


" ooRexx builtin classes (as of version 3.2.0, fall 2007), first define dot to be o.k. in keywords
syn keyword rexxBuiltinClass .Alarm .ArgUtil .Array .Bag .CaselessColumnComparator
syn keyword rexxBuiltinClass .CaselessComparator .CaselessDescendingComparator .CircularQueue
syn keyword rexxBuiltinClass .Class .Collection .ColumnComparator .Comparable .Comparator
syn keyword rexxBuiltinClass .DateTime .DescendingComparator .Directory .File .InputOutputStream
syn keyword rexxBuiltinClass .InputStream .InvertingComparator .List .MapCollection
syn keyword rexxBuiltinClass .Message .Method .Monitor .MutableBuffer .Object
syn keyword rexxBuiltinClass .OrderedCollection .OutputStream .Package .Properties .Queue
syn keyword rexxBuiltinClass .RegularExpression .Relation .RexxContext .RexxQueue .Routine
syn keyword rexxBuiltinClass .Set .SetCollection .Stem .Stream
syn keyword rexxBuiltinClass .StreamSupplier .String .Supplier .Table .TimeSpan

" Windows-only classes
syn keyword rexxBuiltinClass .AdvancedControls .AnimatedButton .BaseDialog .ButtonControl
syn keyword rexxBuiltinClass .CategoryDialog .CheckBox .CheckList .ComboBox .DialogControl
syn keyword rexxBuiltinClass .DialogExtensions .DlgArea .DlgAreaU .DynamicDialog
syn keyword rexxBuiltinClass .EditControl .InputBox .IntegerBox .ListBox .ListChoice
syn keyword rexxBuiltinClass .ListControl .MenuObject .MessageExtensions .MultiInputBox
syn keyword rexxBuiltinClass .MultiListChoice .OLEObject .OLEVariant
syn keyword rexxBuiltinClass .PasswordBox .PlainBaseDialog .PlainUserDialog
syn keyword rexxBuiltinClass .ProgressBar .ProgressIndicator .PropertySheet .RadioButton
syn keyword rexxBuiltinClass .RcDialog .ResDialog .ScrollBar .SingleSelection .SliderControl
syn keyword rexxBuiltinClass .StateIndicator .StaticControl .TabControl .TimedMessage
syn keyword rexxBuiltinClass .TreeControl .UserDialog .VirtualKeyCodes .WindowBase
syn keyword rexxBuiltinClass .WindowExtensions .WindowObject .WindowsClassesBase .WindowsClipboard
syn keyword rexxBuiltinClass .WindowsEventLog .WindowsManager .WindowsProgramManager .WindowsRegistry

" BSF4ooRexx classes
syn keyword rexxBuiltinClass .BSF .bsf.dialog .bsf_proxy
syn keyword rexxBuiltinClass .UNO .UNO_ENUM .UNO_CONSTANTS .UNO_PROPERTIES

" ooRexx directives, ---rgf location important, otherwise directives in top of file not matched!
syn region rexxClassDirective     start="::\s*class\s*"ms=e+1    end="\ze\(\s\|;\|$\)"
syn region rexxMethodDirective    start="::\s*method\s*"ms=e+1   end="\ze\(\s\|;\|$\)"
syn region rexxRequiresDirective  start="::\s*requires\s*"ms=e+1 end="\ze\(\s\|;\|$\)"
syn region rexxRoutineDirective   start="::\s*routine\s*"ms=e+1  end="\ze\(\s\|;\|$\)"
syn region rexxAttributeDirective start="::\s*attribute\s*"ms=e+1  end="\ze\(\s\|;\|$\)"
" rgf, 2012-09-09
syn region rexxOptionsDirective   start="::\s*options\s*"ms=e+1  end="\ze\(\s\|;\|$\)"
syn region rexxConstantDirective  start="::\s*constant\s*"ms=e+1  end="\ze\(\s\|;\|$\)"

syn region rexxDirective start="\(^\|;\)\s*::\s*\w\+"  end="\($\|;\)" contains=rexxString,rexxNumber,rexxComment,rexxLineComment,rexxClassDirective,rexxMethodDirective,rexxRoutineDirective,rexxRequiresDirective,rexxAttributeDirective,rexxOptionsDirective,rexxConstantDirective keepend

syn match rexxOptionsDirective2 "\<\(digits\|form\|fuzz\|trace\)\>" containedin = rexxOptionsDirective3
syn region rexxOptionsDirective3 start="\(^\|;\)\s*::\s*options\s"ms=e+1  end="\($\|;\)" contains=rexxString,rexxNumber,rexxVariable,rexxComment,rexxLineComment containedin = rexxDirective


syn region rexxVariable start="\zs\<\(\.\)\@!\K\k\+\>\ze\s*\(=\|,\|)\|%\|\]\|\\\||\|&\|+=\|-=\|<\|>\)" end="\(\_$\|.\)"me=e-1
syn match rexxVariable "\(=\|,\|)\|%\|\]\|\\\||\|&\|+=\|-=\|<\|>\)\s*\zs\K\k*\ze"

" rgf, 2007-07-22: unfortunately, the entire region is colored (not only the
" patterns), hence useless (vim 7.0)! (syntax-docs hint that that should work)
" attempt: just colorize the parenthesis in matching colors, keep content
"          transparent to keep the formatting already done to it!
" TODO: test on 7.3
" syn region par1 matchgroup=par1 start="(" matchgroup=par1 end=")" transparent contains=par2
" syn region par2 matchgroup=par2 start="(" matchgroup=par2 end=")" transparent contains=par3 contained
" syn region par3 matchgroup=par3 start="(" matchgroup=par3 end=")" transparent contains=par4 contained
" syn region par4 matchgroup=par4 start="(" matchgroup=par4 end=")" transparent contains=par5 contained
" syn region par5 matchgroup=par5 start="(" matchgroup=par5 end=")" transparent contains=par1 contained

" this will colorize the entire region, removing any colorizing already done!
" syn region par1 matchgroup=par1 start="(" end=")" contains=par2
" syn region par2 matchgroup=par2 start="(" end=")" contains=par3 contained
" syn region par3 matchgroup=par3 start="(" end=")" contains=par4 contained
" syn region par4 matchgroup=par4 start="(" end=")" contains=par5 contained
" syn region par5 matchgroup=par5 start="(" end=")" contains=par1 contained

hi par1 ctermfg=red 		guifg=red          "guibg=grey
hi par2 ctermfg=blue 		guifg=blue         "guibg=grey
hi par3 ctermfg=darkgreen 	guifg=darkgreen    "guibg=grey
hi par4 ctermfg=darkyellow	guifg=darkyellow   "guibg=grey
hi par5 ctermfg=darkgrey 	guifg=darkgrey     "guibg=grey

" line continuation (trailing comma or single dash)
syn sync linecont "\(,\|-\ze-\@!\)\ze\s*\(--.*\|\/\*.*\)*$"

" if !exists("rexx_minlines")
"   let rexx_minlines = 500
" endif
" exec "syn sync ccomment rexxComment minlines=" . rexx_minlines

" always scan from start, PCs have long become to be powerful enough for that
exec "syn sync fromstart"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_rexx_syn_inits")
  if version < 508
    let did_rexx_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " make binary and hex strings stand out
  hi rexxStringConstant term=bold,underline ctermfg=5 cterm=bold guifg=darkMagenta gui=bold

  HiLink rexxLabel2		Function
  HiLink doLoopSelectLabelRegion	rexxKeyword
  HiLink endIterateLeaveLabelRegion	rexxKeyword
  HiLink rexxLoopKeywords	rexxKeyword " Todo

  HiLink rexxNumber		Normal "DiffChange
"  HiLink rexxIdentifier		DiffChange

  HiLink rexxRegularCallSignal	Statement
  HiLink rexxExceptionHandling	Statement

  HiLink rexxLabel		Function
  HiLink rexxCharacter		Character
  HiLink rexxParenError		rexxError
  HiLink rexxInParen		rexxError
  HiLink rexxCommentError	rexxError
  HiLink rexxError		Error
  HiLink rexxKeyword		Statement
  HiLink rexxKeywordStatements	Statement

  HiLink rexxFunction		Function
  HiLink rexxString		String
  HiLink rexxComment		Comment
  HiLink rexxTodo		Todo
  HiLink rexxSpecialVariable	Special
  HiLink rexxConditional	rexxKeyword

  HiLink rexxOperator		Operator
  HiLink rexxMessageOperator	rexxOperator
  HiLink rexxLineComment	Comment

  HiLink rexxLineContinue	WildMenu

  HiLink rexxDirective		rexxKeyword
  HiLink rexxClassDirective	Type
  HiLink rexxMethodDirective	rexxFunction
  HiLink rexxAttributeDirective	rexxFunction
  HiLink rexxRequiresDirective	Include
  HiLink rexxRoutineDirective	rexxFunction

" rgf, 2012-09-09
  HiLink rexxOptionsDirective	rexxFunction
  HiLink rexxOptionsDirective2  rexxOptionsDirective
  HiLink rexxOptionsDirective3  Normal " rexxOptionsDirective

  HiLink rexxConstantDirective	rexxFunction

  HiLink rexxConst		Constant
  HiLink rexxTypeSpecifier	Type
  HiLink rexxBuiltinClass	rexxTypeSpecifier

  HiLink rexxEnvironmentSymbol  rexxConst
  HiLink rexxMessage		rexxFunction

  HiLink rexxParse              rexxKeyword
  HiLink rexxParse2             rexxParse

  HiLink rexxGuard              rexxKeyword
  HiLink rexxTrace              rexxKeyword

  HiLink rexxRaise              rexxKeyword
  HiLink rexxRaise2             rexxRaise

  HiLink rexxForward            rexxKeyword
  HiLink rexxForward2           rexxForward

  delcommand HiLink
endif

let b:current_syntax = "rexx"

"vim: ts=8
