" Vim syntax file
" Language:		Icon
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Wendell Turner <wendell@adsi-m4.com> (invalid last known address)
" Last Change:		2022 Jun 16
" Contributor:		eschen@alumni.princeton.edu 2002.09.18

" Prelude {{{1
if exists("b:current_syntax")
  finish
endif

syn iskeyword @,48-57,_,192-255,&

" Not Top {{{1
syn cluster iconNotTop contains=iconDocField,iconIncluded,iconStringSpecial,iconTodo,@Spell

" Whitespace errors {{{1
if exists("icon_space_errors")
  if !exists("icon_no_trail_space_error")
    syn match iconSpaceError "\s\+$"       display excludenl
  endif
  if !exists("icon_no_tab_space_error")
    syn match iconSpaceError " \+\t"me=e-1 display
  endif
endif

" Reserved words {{{1
syn keyword iconReserved break by case create default do else every fail if
syn keyword iconReserved initial next not of repeat return suspend then to
syn keyword iconReserved until while

syn keyword iconStorageClass global static local record invocable

syn keyword iconLink link

" Procedure definitions {{{1
if exists("icon_no_procedure_fold")
  syn region iconProcedure matchgroup=iconReserved start="\<procedure\>" end="\<end\>" contains=ALLBUT,@iconNotTop
else
  syn region iconProcedure matchgroup=iconReserved start="\<procedure\>" end="\<end\>" contains=ALLBUT,@iconNotTop fold
endif

" Keywords {{{1
syn keyword iconKeyword &allocated &ascii &clock &collections &cset &current
syn keyword iconKeyword &date &dateline &digits &dump &e &error &errornumber
syn keyword iconKeyword &errortext &errorvalue &errout &fail &features &file
syn keyword iconKeyword &host &input &lcase &letters &level &line &main &null
syn keyword iconKeyword &output &phi &pi &pos &progname &random &regions
syn keyword iconKeyword &source &storage &subject &time &trace &ucase &version

" Graphics keywords
syn keyword iconKeyword &col &control &interval &ldrag &lpress &lrelease
syn keyword iconKeyword &mdrag &meta &mpress &mrelease &rdrag &resize &row
syn keyword iconKeyword &rpress &rrelease &shift &window &x &y

" Functions {{{1
syn keyword iconFunction abs acos any args asin atan bal callout center char
syn keyword iconFunction chdir close collect copy cos cset delay delete detab
syn keyword iconFunction display dtor entab errorclear exit exp find flush
syn keyword iconFunction function get getch getche getenv iand icom image
syn keyword iconFunction insert integer ior ishift ixor kbhit key left list
syn keyword iconFunction loadfunc log many map match member move name numeric
syn keyword iconFunction open ord pop pos proc pull push put read reads real
syn keyword iconFunction remove rename repl reverse right rtod runerr save
syn keyword iconFunction seek self seq serial set sin sort sortf sqrt stop
syn keyword iconFunction string system tab table tan trim type upto variable
syn keyword iconFunction where write writes

" Graphics functions
syn keyword iconFunction Active Alert Bg CenterString Clip Clone Color
syn keyword iconFunction ColorDialog ColorValue CopyArea Couple DrawArc
syn keyword iconFunction DrawCircle DrawCurve DrawImage DrawLine DrawPoint
syn keyword iconFunction DrawPolygon DrawRectangle DrawSegment DrawString
syn keyword iconFunction Enqueue EraseArea Event Fg FillArc FillCircle
syn keyword iconFunction FillPolygon FillRectangle Font FreeColor GotoRC
syn keyword iconFunction GotoXY LeftString Lower NewColor Notice OpenDialog
syn keyword iconFunction PaletteChars PaletteColor PaletteGrays PaletteKey
syn keyword iconFunction Pattern Pending Pixel Raise ReadImage RightString
syn keyword iconFunction SaveDialog SelectDialog Shade TextDialog TextWidth
syn keyword iconFunction ToggleDialog Uncouple WAttrib WClose WDefault WDelay
syn keyword iconFunction WDone WFlush WOpen WQuit WRead WReads WriteImage
syn keyword iconFunction WSync WWrite WWrites

" String and character constants {{{1
syn match  iconStringSpecial "\\x\x\{2}\|\\\o\{3\}\|\\[bdeflnrtv\"\'\\]\|\\^[a-zA-Z0-9]" contained 
syn match  iconStringSpecial "\\$"							 contained
syn match  iconStringSpecial "_\ze\s*$"						         contained

syn region iconString start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=iconStringSpecial
syn region iconCset   start=+'+ skip=+\\\\\|\\'+ end=+'+ contains=iconStringSpecial

" Bracket errors {{{1

if !exists("icon_no_bracket_errors")
  " catch errors caused by wrong brackets (ACE 2002.09.18)
  syn cluster iconBracketGroup contains=iconBracketError,iconIncluded
  syn region  iconBracket      start='\[' end='\]' contains=ALLBUT,@iconBracketGroup,@iconNotTop transparent 
  syn match   iconBracketError "]"
  
  "catch errors caused by wrong braces (ACE 2002.09.18)
  syn cluster iconBraceGroup contains=iconBraceError,iconIncluded
  syn region  iconBrace	     start='{' end='}' contains=ALLBUT,@iconBraceGroup,@iconNotTop transparent 
  syn match   iconBraceError "}"
  
  "catch errors caused by wrong parenthesis
  syn cluster iconParenGroup contains=iconParenError,iconIncluded
  syn region  iconParen	     start='(' end=')' contains=ALLBUT,@iconParenGroup,@iconNotTop transparent 
  syn match   iconParenError ")"
end

" Numbers {{{1
syn case ignore

" integer
syn match iconInteger "\<\d\+\>"
syn match iconInteger "\<\d\{1,2}[rR][a-zA-Z0-9]\+\>"

" real with trailing dot
syn match iconReal    "\<\d\+\."

" real, with dot, optional exponent
syn match iconReal    "\<\d\+\.\d*\%(e[-+]\=\d\+\)\=\>"

" real, with leading dot, optional exponent
syn match iconReal    "\.\d\+\%(e[-+]\=\d\+\)\=\>"

" real, without dot, with exponent
syn match iconReal    "\<\d\+e[-+]\=\d\+\>"

syn cluster iconNumber contains=iconInteger,iconReal

syn case match

" Comments {{{1
syn keyword iconTodo	 TODO FIXME XXX BUG contained
syn match   iconComment	 "#.*" contains=iconTodo,iconSpaceError,@Spell
syn match   iconDocField "^#\s\+\zs\%(File\|Subject\|Authors\=\|Date\|Version\|Links\|Requires\|See also\):" contained

if exists("icon_no_comment_fold")
  syn region iconDocumentation	  start="\%^#\{2,}\%(\n#\+\%(\s\+.*\)\=\)\+"   end="^#\+\n\s*$"		  contains=iconDocField keepend
else
  syn region iconMultilineComment start="^\s*#.*\n\%(^\s*#\)\@=" end="^\s*#.*\n\%(^\s*#\)\@!" contains=iconComment  keepend fold transparent 
  syn region iconDocumentation	  start="\%^#\{2,}\%(\n#\)\+"	 end="^#\+\n\%([^#]\|$\)"     contains=iconDocField keepend fold
endif

" Preprocessor {{{1
syn match iconPreInclude  '^\s*\zs$\s*include\>\ze\s*"' nextgroup=iconIncluded skipwhite
syn match iconIncluded '"[^"]\+"' contained

syn region iconPreDefine      start="^\s*\zs$\s*\%(define\|undef\)\>"			     end="$" oneline contains=ALLBUT,@iconPreGroup
syn region iconPreProc	      start="^\s*\zs$\s*\%(error\|line\)\>"			     end="$" oneline contains=ALLBUT,@iconPreGroup
syn region iconPreConditional start="^\s*\zs$\s*\%(if\|ifdef\|ifndef\|elif\|else\|endif\)\>" end="$" oneline contains=iconComment,iconString,iconCset,iconNumber,iconSpaceError

syn cluster iconPreGroup contains=iconPreCondit,iconPreInclude,iconIncluded,iconPreDefine

syn match   iconPreSymbol "_V\d\+"
syn keyword iconPreSymbol _ACORN _AMIGA _ARM_FUNCTIONS _ASCII _CALLING
syn keyword iconPreSymbol _CO_EXPRESSIONS _COMPILED _DIRECT_EXECUTION
syn keyword iconPreSymbol _DOS_FUNCTIONS _EBCDIC _EVENT_MONITOR
syn keyword iconPreSymbol _EXECUTABLE_IMAGES _EXTERNAL_FUNCTIONS
syn keyword iconPreSymbol _EXTERNAL_VALUES _INTERPRETED _KEYBOARD_FUNCTIONS
syn keyword iconPreSymbol _LARGE_INTEGERS _MACINTOSH _MEMORY_MONITOR _MSDOS
syn keyword iconPreSymbol _MSDOS_386 _MULTIREGION _MULTITASKING _OS2 _PIPES
syn keyword iconPreSymbol _PORT _PRESENTATION_MGR _RECORD_IO _STRING_INVOKE
syn keyword iconPreSymbol _SYSTEM_FUNCTION _UNIX _VISUALIZATION _VMS
syn keyword iconPreSymbol _WINDOW_FUNCTIONS _X_WINDOW_SYSTEM 

" Syncing {{{1
if !exists("icon_minlines")
  let icon_minlines = 250
endif
exec "syn sync ccomment iconComment minlines=" . icon_minlines

" Default Highlighting  {{{1

hi def link iconParenError	iconError
hi def link iconBracketError	iconError
hi def link iconBraceError	iconError
hi def link iconSpaceError	iconError
hi def link iconError		Error

hi def link iconInteger		Number
hi def link iconReal		Float
hi def link iconString		String
hi def link iconCset		String
hi def link iconStringSpecial	SpecialChar

hi def link iconPreProc		PreProc
hi def link iconIncluded	iconString
hi def link iconPreInclude	Include
hi def link iconPreSymbol	iconPreProc
hi def link iconPreDefine	Define
hi def link iconPreConditional	PreCondit

hi def link iconStatement	Statement
hi def link iconStorageClass	StorageClass
hi def link iconFunction	Function
hi def link iconReserved	Label
hi def link iconLink		Include
hi def link iconKeyword		Keyword

hi def link iconComment		Comment
hi def link iconTodo		Todo
hi def link iconDocField	SpecialComment
hi def link iconDocumentation	Comment

" Postscript  {{{1
let b:current_syntax = "icon"

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
