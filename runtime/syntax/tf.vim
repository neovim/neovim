" Vim syntax file
" Language:	tf
" Maintainer:	Lutz Eymers <ixtab@polzin.com>
" URL:		http://www.isp.de/data/tf.vim
" Email:	send syntax_vim.tgz
" Last Change:	2001 May 10
"
" Options	lite_minlines = x     to sync at least x lines backwards

" Remove any old syntax stuff hanging around

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case match

if !exists("main_syntax")
  let main_syntax = 'tf'
endif

" Special global variables
syn keyword tfVar  HOME LANG MAIL SHELL TERM TFHELP TFLIBDIR TFLIBRARY TZ  contained
syn keyword tfVar  background backslash  contained
syn keyword tfVar  bamf bg_output borg clearfull cleardone clock connect  contained
syn keyword tfVar  emulation end_color gag gethostbyname gpri hook hilite  contained
syn keyword tfVar  hiliteattr histsize hpri insert isize istrip kecho  contained
syn keyword tfVar  kprefix login lp lpquote maildelay matching max_iter  contained
syn keyword tfVar  max_recur mecho more mprefix oldslash promt_sec  contained
syn keyword tfVar  prompt_usec proxy_host proxy_port ptime qecho qprefix  contained
syn keyword tfVar  quite quitdone redef refreshtime scroll shpause snarf sockmload  contained
syn keyword tfVar  start_color tabsize telopt sub time_format visual  contained
syn keyword tfVar  watch_dog watchname wordpunct wrap wraplog wrapsize  contained
syn keyword tfVar  wrapspace  contained

" Worldvar
syn keyword tfWorld  world_name world_character world_password world_host contained
syn keyword tfWorld  world_port world_mfile world_type contained

" Number
syn match tfNumber  "-\=\<\d\+\>"

" Float
syn match tfFloat  "\(-\=\<\d+\|-\=\)\.\d\+\>"

" Operator
syn match tfOperator  "[-+=?:&|!]"
syn match tfOperator  "/[^*~@]"he=e-1
syn match tfOperator  ":="
syn match tfOperator  "[^/%]\*"hs=s+1
syn match tfOperator  "$\+[([{]"he=e-1,me=e-1
syn match tfOperator  "\^\[\+"he=s+1 contains=tfSpecialCharEsc

" Relational
syn match tfRelation  "&&"
syn match tfRelation  "||"
syn match tfRelation  "[<>/!=]="
syn match tfRelation  "[<>]"
syn match tfRelation  "[!=]\~"
syn match tfRelation  "[=!]/"


" Readonly Var
syn match tfReadonly  "[#*]" contained
syn match tfReadonly  "\<-\=L\=\d\{-}\>" contained
syn match tfReadonly  "\<P\(\d\+\|R\|L\)\>" contained
syn match tfReadonly  "\<R\>" contained

" Identifier
syn match tfIdentifier "%\+[a-zA-Z_#*-0-9]\w*" contains=tfVar,tfReadonly
syn match tfIdentifier "%\+[{]"he=e-1,me=e-1
syn match tfIdentifier "\$\+{[a-zA-Z_#*-0-9]\w*}" contains=tfWorld

" Function names
syn keyword tfFunctions  ascii char columns echo filename ftime fwrite getopts
syn keyword tfFunctions  getpid idle kbdel kbgoto kbhead kblen kbmatch kbpoint
syn keyword tfFunctions  kbtail kbwordleft kbwordright keycode lines mod
syn keyword tfFunctions  moresize pad rand read regmatch send strcat strchr
syn keyword tfFunctions  strcmp strlen strncmp strrchr strrep strstr substr
syn keyword tfFunctions  systype time tolower toupper

syn keyword tfStatement  addworld bamf beep bind break cat changes connect  contained
syn keyword tfStatement  dc def dokey echo edit escape eval export expr fg for  contained
syn keyword tfStatement  gag getfile grab help hilite histsize hook if input  contained
syn keyword tfStatement  kill lcd let list listsockets listworlds load  contained
syn keyword tfStatement  localecho log nohilite not partial paste ps purge  contained
syn keyword tfStatement  purgeworld putfile quit quote recall recordline save  contained
syn keyword tfStatement  saveworld send sh shift sub substitute  contained
syn keyword tfStatement  suspend telnet test time toggle trig trigger unbind  contained
syn keyword tfStatement  undef undefn undeft unhook  untrig unworld  contained
syn keyword tfStatement  version watchdog watchname while world  contained

" Hooks
syn keyword tfHook  ACTIVITY BACKGROUND BAMF CONFAIL CONFLICT CONNECT DISCONNECT
syn keyword tfHook  KILL LOAD LOADFAIL LOG LOGIN MAIL MORE PENDING PENDING
syn keyword tfHook  PROCESS PROMPT PROXY REDEF RESIZE RESUME SEND SHADOW SHELL
syn keyword tfHook  SIGHUP SIGTERM SIGUSR1 SIGUSR2 WORLD

" Conditional
syn keyword tfConditional  if endif then else elseif  contained

" Repeat
syn keyword tfRepeat  while do done repeat for  contained

" Statement
syn keyword tfStatement  break quit contained

" Include
syn keyword  tfInclude require load save loaded contained

" Define
syn keyword  tfDefine bind unbind def undef undefn undefn purge hook unhook trig untrig  contained
syn keyword  tfDefine set unset setenv  contained

" Todo
syn keyword  tfTodo TODO Todo todo  contained

" SpecialChar
syn match tfSpecialChar "\\[abcfnrtyv\\]" contained
syn match tfSpecialChar "\\\d\{3}" contained contains=tfOctalError
syn match tfSpecialChar "\\x[0-9a-fA-F]\{2}" contained
syn match tfSpecialCharEsc "\[\+" contained

syn match tfOctalError "[89]" contained

" Comment
syn region tfComment		start="^;" end="$"  contains=tfTodo

" String
syn region tfString   oneline matchgroup=None start=+'+  skip=+\\\\\|\\'+  end=+'+ contains=tfIdentifier,tfSpecialChar,tfEscape
syn region tfString   matchgroup=None start=+"+  skip=+\\\\\|\\"+  end=+"+ contains=tfIdentifier,tfSpecialChar,tfEscape

syn match tfParentError "[)}\]]"

" Parents
syn region tfParent matchgroup=Delimiter start="(" end=")" contains=ALLBUT,tfReadonly
syn region tfParent matchgroup=Delimiter start="\[" end="\]" contains=ALL
syn region tfParent matchgroup=Delimiter start="{" end="}" contains=ALL

syn match tfEndCommand "%%\{-};"
syn match tfJoinLines "\\$"

" Types

syn match tfType "/[a-zA-Z_~@][a-zA-Z0-9_]*" contains=tfConditional,tfRepeat,tfStatement,tfInclude,tfDefine,tfStatement

" Catch /quote .. '
syn match tfQuotes "/quote .\{-}'" contains=ALLBUT,tfString
" Catch $(/escape   )
syn match tfEscape "(/escape .*)"

" sync
if exists("tf_minlines")
  exec "syn sync minlines=" . tf_minlines
else
  syn sync minlines=100
endif

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_tf_syn_inits")
  if version < 508
    let did_tf_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink tfComment		Comment
  HiLink tfString		String
  HiLink tfNumber		Number
  HiLink tfFloat		Float
  HiLink tfIdentifier		Identifier
  HiLink tfVar			Identifier
  HiLink tfWorld		Identifier
  HiLink tfReadonly		Identifier
  HiLink tfHook		Identifier
  HiLink tfFunctions		Function
  HiLink tfRepeat		Repeat
  HiLink tfConditional		Conditional
  HiLink tfLabel		Label
  HiLink tfStatement		Statement
  HiLink tfType		Type
  HiLink tfInclude		Include
  HiLink tfDefine		Define
  HiLink tfSpecialChar		SpecialChar
  HiLink tfSpecialCharEsc	SpecialChar
  HiLink tfParentError		Error
  HiLink tfTodo		Todo
  HiLink tfEndCommand		Delimiter
  HiLink tfJoinLines		Delimiter
  HiLink tfOperator		Operator
  HiLink tfRelation		Operator

  delcommand HiLink
endif

let b:current_syntax = "tf"

if main_syntax == 'tf'
  unlet main_syntax
endif

" vim: ts=8
