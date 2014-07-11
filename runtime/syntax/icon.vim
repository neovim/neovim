" Vim syntax file
" Language:	Icon
" Maintainer:	Wendell Turner <wendell@adsi-m4.com>
" URL:		ftp://ftp.halcyon.com/pub/users/wturner/icon.vim
" Last Change:	2003 May 11

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn keyword  iconFunction   abs acos any args asin atan bal
syn keyword  iconFunction   callout center char chdir close collect copy
syn keyword  iconFunction   cos cset delay delete detab display dtor
syn keyword  iconFunction   entab errorclear exit exp find flush function
syn keyword  iconFunction   get getch getche getenv iand icom image
syn keyword  iconFunction   insert integer ior ishift ixor kbhit key
syn keyword  iconFunction   left list loadfunc log many map match
syn keyword  iconFunction   member move name numeric open ord pop
syn keyword  iconFunction   pos proc pull push put read reads
syn keyword  iconFunction   real remove rename repl reverse right rtod
syn keyword  iconFunction   runerr save seek seq set sin sort
syn keyword  iconFunction   sortf sqrt stop string system tab table
syn keyword  iconFunction   tan trim type upto variable where write writes

" Keywords
syn match iconKeyword "&allocated"
syn match iconKeyword "&ascii"
syn match iconKeyword "&clock"
syn match iconKeyword "&collections"
syn match iconKeyword "&cset"
syn match iconKeyword "&current"
syn match iconKeyword "&date"
syn match iconKeyword "&dateline"
syn match iconKeyword "&digits"
syn match iconKeyword "&dump"
syn match iconKeyword "&e"
syn match iconKeyword "&error"
syn match iconKeyword "&errornumber"
syn match iconKeyword "&errortext"
syn match iconKeyword "&errorvalue"
syn match iconKeyword "&errout"
syn match iconKeyword "&fail"
syn match iconKeyword "&features"
syn match iconKeyword "&file"
syn match iconKeyword "&host"
syn match iconKeyword "&input"
syn match iconKeyword "&lcase"
syn match iconKeyword "&letters"
syn match iconKeyword "&level"
syn match iconKeyword "&line"
syn match iconKeyword "&main"
syn match iconKeyword "&null"
syn match iconKeyword "&output"
syn match iconKeyword "&phi"
syn match iconKeyword "&pi"
syn match iconKeyword "&pos"
syn match iconKeyword "&progname"
syn match iconKeyword "&random"
syn match iconKeyword "&regions"
syn match iconKeyword "&source"
syn match iconKeyword "&storage"
syn match iconKeyword "&subject"
syn match iconKeyword "&time"
syn match iconKeyword "&trace"
syn match iconKeyword "&ucase"
syn match iconKeyword "&version"

" Reserved words
syn keyword iconReserved break by case create default do
syn keyword iconReserved else end every fail if
syn keyword iconReserved initial link next not of
syn keyword iconReserved procedure repeat return suspend
syn keyword iconReserved then to until while

" Storage class reserved words
syn keyword	iconStorageClass	global static local record

syn keyword	iconTodo	contained TODO FIXME XXX BUG

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match iconSpecial contained "\\x\x\{2}\|\\\o\{3\}\|\\[bdeflnrtv\"\'\\]\|\\^c[a-zA-Z0-9]\|\\$"
syn region	iconString	start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=iconSpecial
syn region	iconCset	start=+'+ skip=+\\\\\|\\'+ end=+'+ contains=iconSpecial
syn match	iconCharacter	"'[^\\]'"

" not sure about these
"syn match	iconSpecialCharacter "'\\[bdeflnrtv]'"
"syn match	iconSpecialCharacter "'\\\o\{3\}'"
"syn match	iconSpecialCharacter "'\\x\x\{2}'"
"syn match	iconSpecialCharacter "'\\^c\[a-zA-Z0-9]'"

"when wanted, highlight trailing white space
if exists("icon_space_errors")
  syn match	iconSpaceError	"\s*$"
  syn match	iconSpaceError	" \+\t"me=e-1
endif

"catch errors caused by wrong parenthesis
syn cluster	iconParenGroup contains=iconParenError,iconIncluded,iconSpecial,iconTodo,iconUserCont,iconUserLabel,iconBitField

syn region	iconParen	transparent start='(' end=')' contains=ALLBUT,@iconParenGroup
syn match	iconParenError	")"
syn match	iconInParen	contained "[{}]"


syn case ignore

"integer number, or floating point number without a dot
syn match	iconNumber		"\<\d\+\>"

"floating point number, with dot, optional exponent
syn match	iconFloat		"\<\d\+\.\d*\(e[-+]\=\d\+\)\=\>"

"floating point number, starting with a dot, optional exponent
syn match	iconFloat		"\.\d\+\(e[-+]\=\d\+\)\=\>"

"floating point number, without dot, with exponent
syn match	iconFloat		"\<\d\+e[-+]\=\d\+\>"

"radix number
syn match	iconRadix		"\<\d\{1,2}[rR][a-zA-Z0-9]\+\>"


" syn match iconIdentifier	"\<[a-z_][a-z0-9_]*\>"

syn case match

" Comment
syn match	iconComment	"#.*" contains=iconTodo,iconSpaceError

syn region	iconPreCondit start="^\s*$\s*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)" skip="\\$" end="$" contains=iconComment,iconString,iconCharacter,iconNumber,iconCommentError,iconSpaceError

syn region	iconIncluded	contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match	iconIncluded	contained "<[^>]*>"
syn match	iconInclude	"^\s*$\s*include\>\s*["<]" contains=iconIncluded
"syn match iconLineSkip	"\\$"

syn cluster	iconPreProcGroup contains=iconPreCondit,iconIncluded,iconInclude,iconDefine,iconInParen,iconUserLabel

syn region	iconDefine	start="^\s*$\s*\(define\>\|undef\>\)" skip="\\$" end="$" contains=ALLBUT,@iconPreProcGroup

"wt:syn region	iconPreProc "start="^\s*#\s*\(pragma\>\|line\>\|warning\>\|warn\>\|error\>\)" skip="\\$" "end="$" contains=ALLBUT,@iconPreProcGroup

" Highlight User Labels

" syn cluster	iconMultiGroup contains=iconIncluded,iconSpecial,iconTodo,iconUserCont,iconUserLabel,iconBitField

if !exists("icon_minlines")
  let icon_minlines = 15
endif
exec "syn sync ccomment iconComment minlines=" . icon_minlines

" Define the default highlighting.

" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting
if version >= 508 || !exists("did_icon_syn_inits")
  if version < 508
    let did_icon_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default methods for highlighting.  Can be overridden later

  " HiLink iconSpecialCharacter	iconSpecial

  HiLink iconOctalError		iconError
  HiLink iconParenError		iconError
  HiLink iconInParen		iconError
  HiLink iconCommentError	iconError
  HiLink iconSpaceError		iconError
  HiLink iconCommentError	iconError
  HiLink iconIncluded		iconString
  HiLink iconCommentString	iconString
  HiLink iconComment2String	iconString
  HiLink iconCommentSkip	iconComment

  HiLink iconUserLabel		Label
  HiLink iconCharacter		Character
  HiLink iconNumber			Number
  HiLink iconRadix			Number
  HiLink iconFloat			Float
  HiLink iconInclude		Include
  HiLink iconPreProc		PreProc
  HiLink iconDefine			Macro
  HiLink iconError			Error
  HiLink iconStatement		Statement
  HiLink iconPreCondit		PreCondit
  HiLink iconString			String
  HiLink iconCset			String
  HiLink iconComment		Comment
  HiLink iconSpecial		SpecialChar
  HiLink iconTodo			Todo
  HiLink iconStorageClass	StorageClass
  HiLink iconFunction		Statement
  HiLink iconReserved		Label
  HiLink iconKeyword		Operator

  "HiLink iconIdentifier	Identifier

  delcommand HiLink
endif

let b:current_syntax = "icon"

