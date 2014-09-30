" Vim syntax file
" Language:	NQC - Not Quite C, for LEGO mindstorms
"		NQC homepage: http://www.enteract.com/~dbaum/nqc/
" Maintainer:	Stefan Scherer <stefan@enotes.de>
" Last Change:	2001 May 10
" URL:		http://www.enotes.de/twiki/pub/Home/LegoMindstorms/nqc.vim
" Filenames:	.nqc

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Statements
syn keyword	nqcStatement	break return continue start stop abs sign
syn keyword     nqcStatement	sub task
syn keyword     nqcLabel	case default
syn keyword	nqcConditional	if else switch
syn keyword	nqcRepeat	while for do until repeat

" Scout and RCX2
syn keyword	nqcEvents	acquire catch monitor

" types and classes
syn keyword	nqcType		int true false void
syn keyword	nqcStorageClass	asm const inline



" Sensors --------------------------------------------
" Input Sensors
syn keyword     nqcConstant	SENSOR_1 SENSOR_2 SENSOR_3

" Types for SetSensorType()
syn keyword     nqcConstant	SENSOR_TYPE_TOUCH SENSOR_TYPE_TEMPERATURE
syn keyword     nqcConstant	SENSOR_TYPE_LIGHT SENSOR_TYPE_ROTATION
syn keyword     nqcConstant	SENSOR_LIGHT SENSOR_TOUCH

" Modes for SetSensorMode()
syn keyword     nqcConstant	SENSOR_MODE_RAW SENSOR_MODE_BOOL
syn keyword     nqcConstant	SENSOR_MODE_EDGE SENSOR_MODE_PULSE
syn keyword     nqcConstant	SENSOR_MODE_PERCENT SENSOR_MODE_CELSIUS
syn keyword     nqcConstant	SENSOR_MODE_FAHRENHEIT SENSOR_MODE_ROTATION

" Sensor configurations for SetSensor()
syn keyword     nqcConstant	SENSOR_TOUCH SENSOR_LIGHT SENSOR_ROTATION
syn keyword     nqcConstant	SENSOR_CELSIUS SENSOR_FAHRENHEIT SENSOR_PULSE
syn keyword     nqcConstant	SENSOR_EDGE

" Functions - All
syn keyword	nqcFunction	ClearSensor
syn keyword	nqcFunction	SensorValue SensorType

" Functions - RCX
syn keyword	nqcFunction	SetSensor SetSensorType
syn keyword	nqcFunction	SensorValueBool

" Functions - RCX, CyberMaster
syn keyword	nqcFunction	SetSensorMode SensorMode

" Functions - RCX, Scout
syn keyword	nqcFunction	SensorValueRaw

" Functions - Scout
syn keyword	nqcFunction	SetSensorLowerLimit SetSensorUpperLimit
syn keyword	nqcFunction	SetSensorHysteresis CalibrateSensor


" Outputs --------------------------------------------
" Outputs for On(), Off(), etc.
syn keyword     nqcConstant	OUT_A OUT_B OUT_C

" Modes for SetOutput()
syn keyword     nqcConstant	OUT_ON OUT_OFF OUT_FLOAT

" Directions for SetDirection()
syn keyword     nqcConstant	OUT_FWD OUT_REV OUT_TOGGLE

" Output power for SetPower()
syn keyword     nqcConstant	OUT_LOW OUT_HALF OUT_FULL

" Functions - All
syn keyword	nqcFunction	SetOutput SetDirection SetPower OutputStatus
syn keyword	nqcFunction	On Off Float Fwd Rev Toggle
syn keyword	nqcFunction	OnFwd OnRev OnFor

" Functions - RXC2, Scout
syn keyword	nqcFunction	SetGlobalOutput SetGlobalDirection SetMaxPower
syn keyword	nqcFunction	GlobalOutputStatus


" Sound ----------------------------------------------
" Sounds for PlaySound()
syn keyword     nqcConstant	SOUND_CLICK SOUND_DOUBLE_BEEP SOUND_DOWN
syn keyword     nqcConstant	SOUND_UP SOUND_LOW_BEEP SOUND_FAST_UP

" Functions - All
syn keyword	nqcFunction	PlaySound PlayTone

" Functions - RCX2, Scout
syn keyword	nqcFunction	MuteSound UnmuteSound ClearSound
syn keyword	nqcFunction	SelectSounds


" LCD ------------------------------------------------
" Modes for SelectDisplay()
syn keyword     nqcConstant	DISPLAY_WATCH DISPLAY_SENSOR_1 DISPLAY_SENSOR_2
syn keyword     nqcConstant	DISPLAY_SENSOR_3 DISPLAY_OUT_A DISPLAY_OUT_B
syn keyword     nqcConstant	DISPLAY_OUT_C
" RCX2
syn keyword     nqcConstant	DISPLAY_USER

" Functions - RCX
syn keyword	nqcFunction	SelectDisplay
" Functions - RCX2
syn keyword	nqcFunction	SetUserDisplay


" Communication --------------------------------------
" Messages - RCX, Scout ------------------------------
" Tx power level for SetTxPower()
syn keyword     nqcConstant	TX_POWER_LO TX_POWER_HI

" Functions - RCX, Scout
syn keyword	nqcFunction	Message ClearMessage SendMessage SetTxPower

" Serial - RCX2 --------------------------------------
" for SetSerialComm()
syn keyword     nqcConstant	SERIAL_COMM_DEFAULT SERIAL_COMM_4800
syn keyword     nqcConstant	SERIAL_COMM_DUTY25 SERIAL_COMM_76KHZ

" for SetSerialPacket()
syn keyword     nqcConstant	SERIAL_PACKET_DEFAULT SERIAL_PACKET_PREAMBLE
syn keyword     nqcConstant	SERIAL_PACKET_NEGATED SERIAL_PACKET_CHECKSUM
syn keyword     nqcConstant	SERIAL_PACKET_RCX

" Functions - RCX2
syn keyword	nqcFunction	SetSerialComm SetSerialPacket SetSerialData
syn keyword	nqcFunction	SerialData SendSerial

" VLL - Scout ----------------------------------------
" Functions - Scout
syn keyword	nqcFunction	SendVLL


" Timers ---------------------------------------------
" Functions - All
syn keyword	nqcFunction	ClearTimer Timer

" Functions - RCX2
syn keyword	nqcFunction	SetTimer FastTimer


" Counters -------------------------------------------
" Functions - RCX2, Scout
syn keyword	nqcFunction	ClearCounter IncCounter DecCounter Counter


" Access Control -------------------------------------
syn keyword     nqcConstant	ACQUIRE_OUT_A ACQUIRE_OUT_B ACQUIRE_OUT_C
syn keyword     nqcConstant	ACQUIRE_SOUND
" RCX2 only
syn keyword     nqcConstant	ACQUIRE_USER_1 ACQUIRE_USER_2 ACQUIRE_USER_3
syn keyword     nqcConstant	ACQUIRE_USER_4

" Functions - RCX2, Scout
syn keyword	nqcFunction	SetPriority


" Events ---------------------------------------------
" RCX2 Events
syn keyword     nqcConstant	EVENT_TYPE_PRESSED EVENT_TYPE_RELEASED
syn keyword     nqcConstant	EVENT_TYPE_PULSE EVENT_TYPE_EDGE
syn keyword     nqcConstant	EVENT_TYPE_FAST_CHANGE EVENT_TYPE_LOW
syn keyword     nqcConstant	EVENT_TYPE_NORMAL EVENT_TYPE_HIGH
syn keyword     nqcConstant	EVENT_TYPE_CLICK EVENT_TYPE_DOUBLECLICK
syn keyword     nqcConstant	EVENT_TYPE_MESSAGE

" Scout Events
syn keyword     nqcConstant	EVENT_1_PRESSED EVENT_1_RELEASED
syn keyword     nqcConstant	EVENT_2_PRESSED EVENT_2_RELEASED
syn keyword     nqcConstant	EVENT_LIGHT_HIGH EVENT_LIGHT_NORMAL
syn keyword     nqcConstant	EVENT_LIGHT_LOW EVENT_LIGHT_CLICK
syn keyword     nqcConstant	EVENT_LIGHT_DOUBLECLICK EVENT_COUNTER_0
syn keyword     nqcConstant	EVENT_COUNTER_1 EVENT_TIMER_0 EVENT_TIMER_1
syn keyword     nqcConstant	EVENT_TIMER_2 EVENT_MESSAGE

" Functions - RCX2, Scout
syn keyword	nqcFunction	ActiveEvents Event

" Functions - RCX2
syn keyword	nqcFunction	CurrentEvents
syn keyword	nqcFunction	SetEvent ClearEvent ClearAllEvents EventState
syn keyword	nqcFunction	CalibrateEvent SetUpperLimit UpperLimit
syn keyword	nqcFunction	SetLowerLimit LowerLimit SetHysteresis
syn keyword	nqcFunction	Hysteresis
syn keyword	nqcFunction	SetClickTime ClickTime SetClickCounter
syn keyword	nqcFunction	ClickCounter

" Functions - Scout
syn keyword	nqcFunction	SetSensorClickTime SetCounterLimit
syn keyword	nqcFunction	SetTimerLimit


" Data Logging ---------------------------------------
" Functions - RCX
syn keyword	nqcFunction	CreateDatalog AddToDatalog
syn keyword	nqcFunction	UploadDatalog


" General Features -----------------------------------
" Functions - All
syn keyword	nqcFunction	Wait StopAllTasks Random
syn keyword	nqcFunction	SetSleepTime SleepNow

" Functions - RCX
syn keyword	nqcFunction	Program Watch SetWatch

" Functions - RCX2
syn keyword	nqcFunction	SetRandomSeed SelectProgram
syn keyword	nqcFunction	BatteryLevel FirmwareVersion

" Functions - Scout
" Parameters for SetLight()
syn keyword     nqcConstant	LIGHT_ON LIGHT_OFF
syn keyword	nqcFunction	SetScoutRules ScoutRules SetScoutMode
syn keyword	nqcFunction	SetEventFeedback EventFeedback SetLight

" additional CyberMaster defines
syn keyword     nqcConstant	OUT_L OUT_R OUT_X
syn keyword     nqcConstant	SENSOR_L SENSOR_M SENSOR_R
" Functions - CyberMaster
syn keyword	nqcFunction	Drive OnWait OnWaitDifferent
syn keyword	nqcFunction	ClearTachoCounter TachoCount TachoSpeed
syn keyword	nqcFunction	ExternalMotorRunning AGC



" nqcCommentGroup allows adding matches for special things in comments
syn keyword	nqcTodo		contained TODO FIXME XXX
syn cluster	nqcCommentGroup	contains=nqcTodo

"when wanted, highlight trailing white space
if exists("nqc_space_errors")
  if !exists("nqc_no_trail_space_error")
    syn match	nqcSpaceError	display excludenl "\s\+$"
  endif
  if !exists("nqc_no_tab_space_error")
    syn match	nqcSpaceError	display " \+\t"me=e-1
  endif
endif

"catch errors caused by wrong parenthesis and brackets
syn cluster	nqcParenGroup	contains=nqcParenError,nqcIncluded,nqcCommentSkip,@nqcCommentGroup,nqcCommentStartError,nqcCommentSkip,nqcCppOut,nqcCppOut2,nqcCppSkip,nqcNumber,nqcFloat,nqcNumbers
if exists("nqc_no_bracket_error")
  syn region	nqcParen	transparent start='(' end=')' contains=ALLBUT,@nqcParenGroup,nqcCppParen
  " nqcCppParen: same as nqcParen but ends at end-of-line; used in nqcDefine
  syn region	nqcCppParen	transparent start='(' skip='\\$' excludenl end=')' end='$' contained contains=ALLBUT,@nqcParenGroup,nqcParen
  syn match	nqcParenError	display ")"
  syn match	nqcErrInParen	display contained "[{}]"
else
  syn region	nqcParen		transparent start='(' end=')' contains=ALLBUT,@nqcParenGroup,nqcCppParen,nqcErrInBracket,nqcCppBracket
  " nqcCppParen: same as nqcParen but ends at end-of-line; used in nqcDefine
  syn region	nqcCppParen	transparent start='(' skip='\\$' excludenl end=')' end='$' contained contains=ALLBUT,@nqcParenGroup,nqcErrInBracket,nqcParen,nqcBracket
  syn match	nqcParenError	display "[\])]"
  syn match	nqcErrInParen	display contained "[\]{}]"
  syn region	nqcBracket	transparent start='\[' end=']' contains=ALLBUT,@nqcParenGroup,nqcErrInParen,nqcCppParen,nqcCppBracket
  " nqcCppBracket: same as nqcParen but ends at end-of-line; used in nqcDefine
  syn region	nqcCppBracket	transparent start='\[' skip='\\$' excludenl end=']' end='$' contained contains=ALLBUT,@nqcParenGroup,nqcErrInParen,nqcParen,nqcBracket
  syn match	nqcErrInBracket	display contained "[);{}]"
endif

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match	nqcNumbers	display transparent "\<\d\|\.\d" contains=nqcNumber,nqcFloat
" Same, but without octal error (for comments)
syn match	nqcNumber	display contained "\d\+\(u\=l\{0,2}\|ll\=u\)\>"
"hex number
syn match	nqcNumber	display contained "0x\x\+\(u\=l\{0,2}\|ll\=u\)\>"
" Flag the first zero of an octal number as something special
syn match	nqcFloat	display contained "\d\+f"
"floating point number, with dot, optional exponent
syn match	nqcFloat	display contained "\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\="
"floating point number, starting with a dot, optional exponent
syn match	nqcFloat	display contained "\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match	nqcFloat	display contained "\d\+e[-+]\=\d\+[fl]\=\>"
" flag an octal number with wrong digits
syn case match

syn region	nqcCommentL	start="//" skip="\\$" end="$" keepend contains=@nqcCommentGroup,nqcSpaceError
syn region	nqcComment	matchgroup=nqcCommentStart start="/\*" matchgroup=NONE end="\*/" contains=@nqcCommentGroup,nqcCommentStartError,nqcSpaceError

" keep a // comment separately, it terminates a preproc. conditional
syntax match	nqcCommentError	display "\*/"
syntax match	nqcCommentStartError display "/\*" contained





syn region	nqcPreCondit	start="^\s*#\s*\(if\|ifdef\|ifndef\|elif\)\>" skip="\\$" end="$" end="//"me=s-1 contains=nqcComment,nqcCharacter,nqcCppParen,nqcParenError,nqcNumbers,nqcCommentError,nqcSpaceError
syn match	nqcPreCondit	display "^\s*#\s*\(else\|endif\)\>"
if !exists("nqc_no_if0")
  syn region	nqcCppOut		start="^\s*#\s*if\s\+0\>" end=".\|$" contains=nqcCppOut2
  syn region	nqcCppOut2	contained start="0" end="^\s*#\s*\(endif\>\|else\>\|elif\>\)" contains=nqcSpaceError,nqcCppSkip
  syn region	nqcCppSkip	contained start="^\s*#\s*\(if\>\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*#\s*endif\>" contains=nqcSpaceError,nqcCppSkip
endif
syn region	nqcIncluded	display contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match	nqcInclude	display "^\s*#\s*include\>\s*["]" contains=nqcIncluded
"syn match nqcLineSkip	"\\$"
syn cluster	nqcPreProcGroup	contains=nqcPreCondit,nqcIncluded,nqcInclude,nqcDefine,nqcErrInParen,nqcErrInBracket,nqcCppOut,nqcCppOut2,nqcCppSkip,nqcNumber,nqcFloat,nqcNumbers,nqcCommentSkip,@nqcCommentGroup,nqcCommentStartError,nqcParen,nqcBracket
syn region	nqcDefine	start="^\s*#\s*\(define\|undef\)\>" skip="\\$" end="$" contains=ALLBUT,@nqcPreProcGroup
syn region	nqcPreProc	start="^\s*#\s*\(pragma\>\)" skip="\\$" end="$" keepend contains=ALLBUT,@nqcPreProcGroup

if !exists("nqc_minlines")
  if !exists("nqc_no_if0")
    let nqc_minlines = 50	    " #if 0 constructs can be long
  else
    let nqc_minlines = 15	    " mostly for () constructs
  endif
endif
exec "syn sync ccomment nqcComment minlines=" . nqc_minlines

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_nqc_syn_inits")
  if version < 508
    let did_nqc_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default methods for highlighting.  Can be overridden later
  HiLink nqcLabel		Label
  HiLink nqcConditional		Conditional
  HiLink nqcRepeat		Repeat
  HiLink nqcCharacter		Character
  HiLink nqcNumber		Number
  HiLink nqcFloat		Float
  HiLink nqcFunction		Function
  HiLink nqcParenError		nqcError
  HiLink nqcErrInParen		nqcError
  HiLink nqcErrInBracket	nqcError
  HiLink nqcCommentL		nqcComment
  HiLink nqcCommentStart	nqcComment
  HiLink nqcCommentError	nqcError
  HiLink nqcCommentStartError	nqcError
  HiLink nqcSpaceError		nqcError
  HiLink nqcStorageClass	StorageClass
  HiLink nqcInclude		Include
  HiLink nqcPreProc		PreProc
  HiLink nqcDefine		Macro
  HiLink nqcIncluded		String
  HiLink nqcError		Error
  HiLink nqcStatement		Statement
  HiLink nqcEvents		Statement
  HiLink nqcPreCondit		PreCondit
  HiLink nqcType		Type
  HiLink nqcConstant		Constant
  HiLink nqcCommentSkip		nqcComment
  HiLink nqcComment		Comment
  HiLink nqcTodo		Todo
  HiLink nqcCppSkip		nqcCppOut
  HiLink nqcCppOut2		nqcCppOut
  HiLink nqcCppOut		Comment

  delcommand HiLink
endif

let b:current_syntax = "nqc"

" vim: ts=8
