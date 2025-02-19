" Vim syntax file
" Language:	QB64
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2022 Jan 21

" Prelude {{{1
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" syn iskeyword set after sourcing of basic.vim

syn case ignore

let s:prefix = search('\c^\s*$NOPREFIX\>', 'n') ? '_\=' : '_'

" Statements {{{1

let s:statements =<< trim EOL " {{{2
  acceptfiledrop
  allowfullscreen
  assert
  console
  consolecursor
  consolefont
  consoletitle
  continue
  copypalette
  define
  delay
  depthbuffer
  displayorder
  dontblend
  echo
  exit\s\+\%(select\|case\)
  finishdrop
  freefont
  freeimage
  icon
  keyclear
  limit
  maptriangle
  memcopy
  memfill
  memfree
  memput
  mousehide
  mousemove
  mouseshow
  printimage
  printstring
  putimage
  screenclick
  screenhide
  screenmove
  screenprint
  screenshow
  setalpha
  sndbal
  sndclose
  sndlimit
  sndloop
  sndpause
  sndplay
  sndplaycopy
  sndplayfile
  sndraw
  sndrawdone
  sndsetpos
  sndstop
  sndvol
  title
EOL
" }}}

for s in s:statements
  exe 'syn match qb64Statement "\<' .. s:prefix .. s .. '\>" contained contains=qb64Underscore'
endfor

" Functions {{{1

let s:functions =<< trim EOL " {{{2
  acos
  acosh
  alpha
  alpha32
  arccot
  arccsc
  arcsec
  asin
  asinh
  atan2
  atanh
  axis
  backgroundcolor
  blue
  blue32
  button
  buttonchange
  ceil
  cinp
  commandcount
  connected
  connectionaddress
  connectionaddress$
  consoleinput
  copyimage
  cot
  coth
  cosh
  csc
  csch
  cv
  cwd$
  d2g
  d2r
  defaultcolor
  deflate$
  desktopheight
  desktopwidth
  device$
  deviceinput
  devices
  dir$
  direxists
  droppedfile
  droppedfile$
  errorline
  errormessage$
  exit
  fileexists
  fontheight
  fontwidth
  freetimer
  g2d
  g2r
  green
  green32
  height
  hypot
  inclerrorfile$
  inclerrorline
  inflate$
  instrrev
  keyhit
  keydown
  lastaxis
  lastbutton
  lastwheel
  loadfont
  loadimage
  mem
  memelement
  memexists
  memimage
  memnew
  memsound
  mk$
  mousebutton
  mouseinput
  mousemovementx
  mousemovementy
  mousepipeopen
  mousewheel
  mousex
  mousey
  newimage
  offset
  openclient
  os$
  pi
  pixelsize
  printwidth
  r2d
  r2g
  red
  red32
  readbit
  resetbit
  resizeheight
  resizewidth
  rgb
  rgb32
  rgba
  rgba32
  round
  sec
  sech
  screenexists
  screenimage
  screenx
  screeny
  setbit
  shellhide
  shl
  shr
  sinh
  sndcopy
  sndgetpos
  sndlen
  sndopen
  sndopenraw
  sndpaused
  sndplaying
  sndrate
  sndrawlen
  startdir$
  strcmp
  stricmp
  tanh
  title$
  togglebit
  totaldroppedfiles
  trim$
  wheel
  width
  windowhandle
  windowhasfocus
EOL
" }}}

for f in s:functions
  exe 'syn match qb64Function "\<' .. s:prefix .. f .. '\>" contains=qb64Underscore'
endfor

" Functions and statements (same name) {{{1

let s:common =<< trim EOL " {{{2
  autodisplay
  blend
  blink
  capslock
  clearcolor
  clipboard$
  clipboardimage
  controlchr
  dest
  display
  font
  fullscreen
  mapunicode
  memget
  numlock
  palettecolor
  printmode
  resize
  screenicon
  scrolllock
  source
EOL
" }}}

for c in s:common
  exe 'syn match qb64Statement "\<' .. s:prefix .. c .. '\>" contains=qb64Underscore contained'
  exe 'syn match qb64Function  "\<' .. s:prefix .. c .. '\>" contains=qb64Underscore'
endfor

" Keywords {{{1

" Non-prefixed keywords {{{2
" TIMER FREE
" _DEPTH_BUFFER LOCK
syn keyword qb64Keyword free lock

let s:keywords  =<< trim EOL " {{{2
  all
  anticlockwise
  behind
  clear
  clip
  console
  dontwait
  explicit
  explicitarray
  fillbackground
  hardware
  hardware1
  hide
  keepbackground
  middle
  none
  off
  only
  onlybackground
  ontop
  openconnection
  openhost
  preserve
  seamless
  smooth
  smoothshrunk
  smoothstretched
  software
  squarepixels
  stretch
  toggle
EOL
" }}}

for k in s:keywords
  exe 'syn match qb64Keyword "\<' .. s:prefix .. k .. '\>" contains=qb64Underscore'
endfor

syn match qb64Underscore "\<_" contained conceal transparent

" Source QuickBASIC syntax {{{1
runtime! syntax/basic.vim

" add after the BASIC syntax file is sourced so cluster already exists
syn cluster basicStatements	add=qb64Statement,qb64Metacommand,qb64IfMetacommand
syn cluster basicLineIdentifier add=qb64LineLabel
syn cluster qb64NotTop		contains=@basicNotTop,qb64Metavariable

syn iskeyword @,48-57,.,_,!,#,$,%,&,`

" Unsupported QuickBASIC features {{{1
" TODO: add linux only missing features
syn keyword qb64Unsupported alias any byval calls cdecl erdev erdev$ fileattr
syn keyword qb64Unsupported fre ioctl ioctl$ pen play setmem signal uevent
syn keyword qb64Unsupported tron troff
syn match   qb64Unsupported "\<declare\%(\s\+\%(sub\|function\)\>\)\@="
syn match   qb64Unsupported "\<\%(date\|time\)$\ze\s*=" " statements only
syn match   qb64Unsupported "\<def\zs\s\+FN"
syn match   qb64Unsupported "\<\%(exit\|end\)\s\+def\>"
syn match   qb64Unsupported "\<width\s\+lprint\>"

" Types {{{1
syn keyword qb64Type _BIT _BYTE _FLOAT _INTEGER64 _MEM _OFFSET _UNSIGNED

" Type suffixes {{{1
if exists("basic_type_suffixes")
  " TODO: handle leading word boundary and __+ prefix
  syn match qb64TypeSuffix "\%(\a[[:alnum:]._]*\)\@<=\~\=`\%(\d\+\)\="
  syn match qb64TypeSuffix "\%(\a[[:alnum:]._]*\)\@<=\~\=\%(%\|%%\|&\|&&\|%&\)"
  syn match qb64TypeSuffix "\%(\a[[:alnum:]._]*\)\@<=\%(!\|##\|#\)"
  syn match qb64TypeSuffix "\%(\a[[:alnum:]._]*\)\@<=$\%(\d\+\)\="
endif

" Numbers {{{1

" Integers
syn match qb64Number "-\=&b[01]\+&\>\="

syn match qb64Number "-\=\<[01]\~\=`\>"
syn match qb64Number "-\=\<\d\+`\d\+\>"

syn match qb64Number "-\=\<\d\+\%(%%\|&&\|%&\)\>"
syn match qb64Number  "\<\d\+\~\%(%%\|&&\|%&\)\>"

syn match qb64Number "-\=\<&b[01]\+\%(%%\|&&\|%&\)\>"
syn match qb64Number  "\<&b[01]\+\~\%(%%\|&&\|%&\)\>"

syn match qb64Number "-\=\<&o\=\o\+\%(%%\|&&\|%&\)\>"
syn match qb64Number  "\<&o\=\o\+\~\%(%%\|&&\|%&\)\>"

syn match qb64Number "-\=\<&h\x\+\%(%%\|&&\|%&\)\>"
syn match qb64Number  "\<&h\x\+\~\%(%%\|&&\|%&\)\>"

" Floats
syn match qb64Float "-\=\<\d\+\.\=\d*##\>"
syn match qb64Float "-\=\<\.\d\+##\>"

" Line numbers and labels {{{1
syn match qb64LineLabel  "\%(_\{2,}\)\=\a[[:alnum:]._]*[[:alnum:]]\ze\s*:" nextgroup=@basicStatements skipwhite contained

" Metacommands {{{1
syn match qb64Metacommand contained "$NOPREFIX\>"
syn match qb64Metacommand contained "$ASSERTS\%(:CONSOLE\)\=\>"
syn match qb64Metacommand contained "$CHECKING:\%(ON\|OFF\)\>"
syn match qb64Metacommand contained "$COLOR:\%(0\|32\)\>"
syn match qb64Metacommand contained "$CONSOLE\%(:ONLY\)\=\>"
syn match qb64Metacommand contained "$EXEICON\s*:\s*'[^']\+'"
syn match qb64Metacommand contained "$ERROR\>"
syn match qb64Metacommand contained "$LET\>"
syn match qb64Metacommand contained "$RESIZE:\%(ON\|OFF\|STRETCH\|SMOOTH\)\>"
syn match qb64Metacommand contained "$SCREEN\%(HIDE\|SHOW\)\>"
syn match qb64Metacommand contained "$VERSIONINFO\s*:.*"
syn match qb64Metacommand contained "$VIRTUALKEYBOARD:\%(ON\|OFF\)\>"

syn region qb64IfMetacommand contained matchgroup=qb64Metacommand start="$\%(IF\|ELSEIF\)\>" end="\<THEN\>" oneline transparent contains=qb64Metavariable
syn match  qb64Metacommand contained "$\%(ELSE\|END\s*IF\)\>"

syn keyword qb64Metavariable contained defined undefined
syn keyword qb64Metavariable contained windows win linux mac maxosx
syn keyword qb64Metavariable contained 32bit 64bit version

" Default Highlighting {{{1
hi def link qb64Float	      basicFloat
hi def link qb64Function      Function
hi def link qb64Keyword       Keyword
hi def link qb64LineLabel     basicLineLabel
hi def link qb64Metacommand   PreProc
hi def link qb64Metavariable  Identifier
hi def link qb64Number	      basicNumber
hi def link qb64Statement     Statement
hi def link qb64TypeSuffix    basicTypeSuffix
hi def link qb64Type	      Type
hi def link qb64Unsupported   Error

" Postscript {{{1
let b:current_syntax = "qb64"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
