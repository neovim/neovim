" Vim syntax file
" Language:     Lua 4.0, Lua 5.0, Lua 5.1, Lua 5.2 and Lua 5.3
" Maintainer:   Marcus Aurelius Farias <masserahguard-lua 'at' yahoo com>
" First Author: Carlos Augusto Teixeira Mendes <cmendes 'at' inf puc-rio br>
" Last Change:  2022 Sep 07
" Options:      lua_version = 4 or 5
"               lua_subversion = 0 (for 4.0 or 5.0)
"                               or 1, 2, 3 (for 5.1, 5.2 or 5.3)
"               the default is 5.3

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

if !exists("lua_version")
  " Default is lua 5.3
  let lua_version = 5
  let lua_subversion = 3
elseif !exists("lua_subversion")
  " lua_version exists, but lua_subversion doesn't. In this case set it to 0
  let lua_subversion = 0
endif

syn case match

" syncing method
syn sync minlines=1000

if lua_version >= 5
  syn keyword luaMetaMethod __add __sub __mul __div __pow __unm __concat
  syn keyword luaMetaMethod __eq __lt __le
  syn keyword luaMetaMethod __index __newindex __call
  syn keyword luaMetaMethod __metatable __mode __gc __tostring
endif

if lua_version > 5 || (lua_version == 5 && lua_subversion >= 1)
  syn keyword luaMetaMethod __mod __len
endif

if lua_version > 5 || (lua_version == 5 && lua_subversion >= 2)
  syn keyword luaMetaMethod __pairs
endif

if lua_version > 5 || (lua_version == 5 && lua_subversion >= 3)
  syn keyword luaMetaMethod __idiv __name
  syn keyword luaMetaMethod __band __bor __bxor __bnot __shl __shr
endif

if lua_version > 5 || (lua_version == 5 && lua_subversion >= 4)
  syn keyword luaMetaMethod __close
endif

" catch errors caused by wrong parenthesis and wrong curly brackets or
" keywords placed outside their respective blocks

syn region luaParen transparent start='(' end=')' contains=TOP,luaParenError
syn match  luaParenError ")"
syn match  luaError "}"
syn match  luaError "\<\%(end\|else\|elseif\|then\|until\|in\)\>"

" Function declaration
syn region luaFunctionBlock transparent matchgroup=luaFunction start="\<function\>" end="\<end\>" contains=TOP

" else
syn keyword luaCondElse matchgroup=luaCond contained containedin=luaCondEnd else

" then ... end
syn region luaCondEnd contained transparent matchgroup=luaCond start="\<then\>" end="\<end\>" contains=TOP

" elseif ... then
syn region luaCondElseif contained containedin=luaCondEnd transparent matchgroup=luaCond start="\<elseif\>" end="\<then\>" contains=TOP

" if ... then
syn region luaCondStart transparent matchgroup=luaCond start="\<if\>" end="\<then\>"me=e-4 contains=TOP nextgroup=luaCondEnd skipwhite skipempty

" do ... end
syn region luaBlock transparent matchgroup=luaStatement start="\<do\>" end="\<end\>" contains=TOP
" repeat ... until
syn region luaRepeatBlock transparent matchgroup=luaRepeat start="\<repeat\>" end="\<until\>" contains=TOP

" while ... do
syn region luaWhile transparent matchgroup=luaRepeat start="\<while\>" end="\<do\>"me=e-2 contains=TOP nextgroup=luaBlock skipwhite skipempty

" for ... do and for ... in ... do
syn region luaFor transparent matchgroup=luaRepeat start="\<for\>" end="\<do\>"me=e-2 contains=TOP nextgroup=luaBlock skipwhite skipempty

syn keyword luaFor contained containedin=luaFor in

" other keywords
syn keyword luaStatement return local break
if lua_version > 5 || (lua_version == 5 && lua_subversion >= 2)
  syn keyword luaStatement goto
  syn match luaLabel "::\I\i*::"
endif

" operators
syn keyword luaOperator and or not

if (lua_version == 5 && lua_subversion >= 3) || lua_version > 5
  syn match luaSymbolOperator "[#<>=~^&|*/%+-]\|\.\{2,3}"
elseif lua_version == 5 && (lua_subversion == 1 || lua_subversion == 2)
  syn match luaSymbolOperator "[#<>=~^*/%+-]\|\.\{2,3}"
else
  syn match luaSymbolOperator "[<>=~^*/+-]\|\.\{2,3}"
endif

" comments
syn keyword luaTodo            contained TODO FIXME XXX
syn match   luaComment         "--.*$" contains=luaTodo,@Spell
if lua_version == 5 && lua_subversion == 0
  syn region luaComment        matchgroup=luaCommentDelimiter start="--\[\[" end="\]\]" contains=luaTodo,luaInnerComment,@Spell
  syn region luaInnerComment   contained transparent start="\[\[" end="\]\]"
elseif lua_version > 5 || (lua_version == 5 && lua_subversion >= 1)
  " Comments in Lua 5.1: --[[ ... ]], [=[ ... ]=], [===[ ... ]===], etc.
  syn region luaComment        matchgroup=luaCommentDelimiter start="--\[\z(=*\)\[" end="\]\z1\]" contains=luaTodo,@Spell
endif

" first line may start with #!
syn match luaComment "\%^#!.*"

syn keyword luaConstant nil
if lua_version > 4
  syn keyword luaConstant true false
endif

" strings
syn match  luaSpecial contained #\\[\\abfnrtv'"[\]]\|\\[[:digit:]]\{,3}#
if lua_version == 5
  if lua_subversion == 0
    syn region luaString2 matchgroup=luaStringDelimiter start=+\[\[+ end=+\]\]+ contains=luaString2,@Spell
  else
    if lua_subversion >= 2
      syn match  luaSpecial contained #\\z\|\\x[[:xdigit:]]\{2}#
    endif
    if lua_subversion >= 3
      syn match  luaSpecial contained #\\u{[[:xdigit:]]\+}#
    endif
    syn region luaString2 matchgroup=luaStringDelimiter start="\[\z(=*\)\[" end="\]\z1\]" contains=@Spell
  endif
endif
syn region luaString matchgroup=luaStringDelimiter start=+'+ end=+'+ skip=+\\\\\|\\'+ contains=luaSpecial,@Spell
syn region luaString matchgroup=luaStringDelimiter start=+"+ end=+"+ skip=+\\\\\|\\"+ contains=luaSpecial,@Spell

" integer number
syn match luaNumber "\<\d\+\>"
" floating point number, with dot, optional exponent
syn match luaNumber  "\<\d\+\.\d*\%([eE][-+]\=\d\+\)\="
" floating point number, starting with a dot, optional exponent
syn match luaNumber  "\.\d\+\%([eE][-+]\=\d\+\)\=\>"
" floating point number, without dot, with exponent
syn match luaNumber  "\<\d\+[eE][-+]\=\d\+\>"

" hex numbers
if lua_version >= 5
  if lua_subversion == 1
    syn match luaNumber "\<0[xX]\x\+\>"
  elseif lua_subversion >= 2
    syn match luaNumber "\<0[xX][[:xdigit:].]\+\%([pP][-+]\=\d\+\)\=\>"
  endif
endif

" tables
syn region luaTableBlock transparent matchgroup=luaTable start="{" end="}" contains=TOP,luaStatement

" methods
syntax match luaFunc ":\@<=\k\+"

" built-in functions
syn keyword luaFunc assert collectgarbage dofile error next
syn keyword luaFunc print rawget rawset self tonumber tostring type _VERSION

if lua_version == 4
  syn keyword luaFunc _ALERT _ERRORMESSAGE gcinfo
  syn keyword luaFunc call copytagmethods dostring
  syn keyword luaFunc foreach foreachi getglobal getn
  syn keyword luaFunc gettagmethod globals newtag
  syn keyword luaFunc setglobal settag settagmethod sort
  syn keyword luaFunc tag tinsert tremove
  syn keyword luaFunc _INPUT _OUTPUT _STDIN _STDOUT _STDERR
  syn keyword luaFunc openfile closefile flush seek
  syn keyword luaFunc setlocale execute remove rename tmpname
  syn keyword luaFunc getenv date clock exit
  syn keyword luaFunc readfrom writeto appendto read write
  syn keyword luaFunc PI abs sin cos tan asin
  syn keyword luaFunc acos atan atan2 ceil floor
  syn keyword luaFunc mod frexp ldexp sqrt min max log
  syn keyword luaFunc log10 exp deg rad random
  syn keyword luaFunc randomseed strlen strsub strlower strupper
  syn keyword luaFunc strchar strrep ascii strbyte
  syn keyword luaFunc format strfind gsub
  syn keyword luaFunc getinfo getlocal setlocal setcallhook setlinehook
elseif lua_version == 5
  syn keyword luaFunc getmetatable setmetatable
  syn keyword luaFunc ipairs pairs
  syn keyword luaFunc pcall xpcall
  syn keyword luaFunc _G loadfile rawequal require
  if lua_subversion == 0
    syn keyword luaFunc getfenv setfenv
    syn keyword luaFunc loadstring unpack
    syn keyword luaFunc gcinfo loadlib LUA_PATH _LOADED _REQUIREDNAME
  else
    syn keyword luaFunc load select
    syn match   luaFunc /\<package\.cpath\>/
    syn match   luaFunc /\<package\.loaded\>/
    syn match   luaFunc /\<package\.loadlib\>/
    syn match   luaFunc /\<package\.path\>/
    syn match   luaFunc /\<package\.preload\>/
    if lua_subversion == 1
      syn keyword luaFunc getfenv setfenv
      syn keyword luaFunc loadstring module unpack
      syn match   luaFunc /\<package\.loaders\>/
      syn match   luaFunc /\<package\.seeall\>/
    elseif lua_subversion >= 2
      syn keyword luaFunc _ENV rawlen
      syn match   luaFunc /\<package\.config\>/
      syn match   luaFunc /\<package\.preload\>/
      syn match   luaFunc /\<package\.searchers\>/
      syn match   luaFunc /\<package\.searchpath\>/
    endif

    if lua_subversion >= 3
      syn match luaFunc /\<coroutine\.isyieldable\>/
    endif
    if lua_subversion >= 4
      syn keyword luaFunc warn
      syn match luaFunc /\<coroutine\.close\>/
    endif
    syn match luaFunc /\<coroutine\.running\>/
  endif
  syn match   luaFunc /\<coroutine\.create\>/
  syn match   luaFunc /\<coroutine\.resume\>/
  syn match   luaFunc /\<coroutine\.status\>/
  syn match   luaFunc /\<coroutine\.wrap\>/
  syn match   luaFunc /\<coroutine\.yield\>/

  syn match   luaFunc /\<string\.byte\>/
  syn match   luaFunc /\<string\.char\>/
  syn match   luaFunc /\<string\.dump\>/
  syn match   luaFunc /\<string\.find\>/
  syn match   luaFunc /\<string\.format\>/
  syn match   luaFunc /\<string\.gsub\>/
  syn match   luaFunc /\<string\.len\>/
  syn match   luaFunc /\<string\.lower\>/
  syn match   luaFunc /\<string\.rep\>/
  syn match   luaFunc /\<string\.sub\>/
  syn match   luaFunc /\<string\.upper\>/
  if lua_subversion == 0
    syn match luaFunc /\<string\.gfind\>/
  else
    syn match luaFunc /\<string\.gmatch\>/
    syn match luaFunc /\<string\.match\>/
    syn match luaFunc /\<string\.reverse\>/
  endif
  if lua_subversion >= 3
    syn match luaFunc /\<string\.pack\>/
    syn match luaFunc /\<string\.packsize\>/
    syn match luaFunc /\<string\.unpack\>/
    syn match luaFunc /\<utf8\.char\>/
    syn match luaFunc /\<utf8\.charpattern\>/
    syn match luaFunc /\<utf8\.codes\>/
    syn match luaFunc /\<utf8\.codepoint\>/
    syn match luaFunc /\<utf8\.len\>/
    syn match luaFunc /\<utf8\.offset\>/
  endif

  if lua_subversion == 0
    syn match luaFunc /\<table\.getn\>/
    syn match luaFunc /\<table\.setn\>/
    syn match luaFunc /\<table\.foreach\>/
    syn match luaFunc /\<table\.foreachi\>/
  elseif lua_subversion == 1
    syn match luaFunc /\<table\.maxn\>/
  elseif lua_subversion >= 2
    syn match luaFunc /\<table\.pack\>/
    syn match luaFunc /\<table\.unpack\>/
    if lua_subversion >= 3
      syn match luaFunc /\<table\.move\>/
    endif
  endif
  syn match   luaFunc /\<table\.concat\>/
  syn match   luaFunc /\<table\.insert\>/
  syn match   luaFunc /\<table\.sort\>/
  syn match   luaFunc /\<table\.remove\>/

  if lua_subversion == 2
    syn match   luaFunc /\<bit32\.arshift\>/
    syn match   luaFunc /\<bit32\.band\>/
    syn match   luaFunc /\<bit32\.bnot\>/
    syn match   luaFunc /\<bit32\.bor\>/
    syn match   luaFunc /\<bit32\.btest\>/
    syn match   luaFunc /\<bit32\.bxor\>/
    syn match   luaFunc /\<bit32\.extract\>/
    syn match   luaFunc /\<bit32\.lrotate\>/
    syn match   luaFunc /\<bit32\.lshift\>/
    syn match   luaFunc /\<bit32\.replace\>/
    syn match   luaFunc /\<bit32\.rrotate\>/
    syn match   luaFunc /\<bit32\.rshift\>/
  endif

  syn match   luaFunc /\<math\.abs\>/
  syn match   luaFunc /\<math\.acos\>/
  syn match   luaFunc /\<math\.asin\>/
  syn match   luaFunc /\<math\.atan\>/
  if lua_subversion < 3
    syn match   luaFunc /\<math\.atan2\>/
  endif
  syn match   luaFunc /\<math\.ceil\>/
  syn match   luaFunc /\<math\.sin\>/
  syn match   luaFunc /\<math\.cos\>/
  syn match   luaFunc /\<math\.tan\>/
  syn match   luaFunc /\<math\.deg\>/
  syn match   luaFunc /\<math\.exp\>/
  syn match   luaFunc /\<math\.floor\>/
  syn match   luaFunc /\<math\.log\>/
  syn match   luaFunc /\<math\.max\>/
  syn match   luaFunc /\<math\.min\>/
  if lua_subversion == 0
    syn match luaFunc /\<math\.mod\>/
    syn match luaFunc /\<math\.log10\>/
  elseif lua_subversion == 1
    syn match luaFunc /\<math\.log10\>/
  endif
  if lua_subversion >= 1
    syn match luaFunc /\<math\.huge\>/
    syn match luaFunc /\<math\.fmod\>/
    syn match luaFunc /\<math\.modf\>/
    if lua_subversion == 1 || lua_subversion == 2
      syn match luaFunc /\<math\.cosh\>/
      syn match luaFunc /\<math\.sinh\>/
      syn match luaFunc /\<math\.tanh\>/
    endif
  endif
  syn match   luaFunc /\<math\.rad\>/
  syn match   luaFunc /\<math\.sqrt\>/
  if lua_subversion < 3
    syn match   luaFunc /\<math\.pow\>/
    syn match   luaFunc /\<math\.frexp\>/
    syn match   luaFunc /\<math\.ldexp\>/
  else
    syn match   luaFunc /\<math\.maxinteger\>/
    syn match   luaFunc /\<math\.mininteger\>/
    syn match   luaFunc /\<math\.tointeger\>/
    syn match   luaFunc /\<math\.type\>/
    syn match   luaFunc /\<math\.ult\>/
  endif
  syn match   luaFunc /\<math\.random\>/
  syn match   luaFunc /\<math\.randomseed\>/
  syn match   luaFunc /\<math\.pi\>/

  syn match   luaFunc /\<io\.close\>/
  syn match   luaFunc /\<io\.flush\>/
  syn match   luaFunc /\<io\.input\>/
  syn match   luaFunc /\<io\.lines\>/
  syn match   luaFunc /\<io\.open\>/
  syn match   luaFunc /\<io\.output\>/
  syn match   luaFunc /\<io\.popen\>/
  syn match   luaFunc /\<io\.read\>/
  syn match   luaFunc /\<io\.stderr\>/
  syn match   luaFunc /\<io\.stdin\>/
  syn match   luaFunc /\<io\.stdout\>/
  syn match   luaFunc /\<io\.tmpfile\>/
  syn match   luaFunc /\<io\.type\>/
  syn match   luaFunc /\<io\.write\>/

  syn match   luaFunc /\<os\.clock\>/
  syn match   luaFunc /\<os\.date\>/
  syn match   luaFunc /\<os\.difftime\>/
  syn match   luaFunc /\<os\.execute\>/
  syn match   luaFunc /\<os\.exit\>/
  syn match   luaFunc /\<os\.getenv\>/
  syn match   luaFunc /\<os\.remove\>/
  syn match   luaFunc /\<os\.rename\>/
  syn match   luaFunc /\<os\.setlocale\>/
  syn match   luaFunc /\<os\.time\>/
  syn match   luaFunc /\<os\.tmpname\>/

  syn match   luaFunc /\<debug\.debug\>/
  syn match   luaFunc /\<debug\.gethook\>/
  syn match   luaFunc /\<debug\.getinfo\>/
  syn match   luaFunc /\<debug\.getlocal\>/
  syn match   luaFunc /\<debug\.getupvalue\>/
  syn match   luaFunc /\<debug\.setlocal\>/
  syn match   luaFunc /\<debug\.setupvalue\>/
  syn match   luaFunc /\<debug\.sethook\>/
  syn match   luaFunc /\<debug\.traceback\>/
  if lua_subversion == 1
    syn match luaFunc /\<debug\.getfenv\>/
    syn match luaFunc /\<debug\.setfenv\>/
  endif
  if lua_subversion >= 1
    syn match luaFunc /\<debug\.getmetatable\>/
    syn match luaFunc /\<debug\.setmetatable\>/
    syn match luaFunc /\<debug\.getregistry\>/
    if lua_subversion >= 2
      syn match luaFunc /\<debug\.getuservalue\>/
      syn match luaFunc /\<debug\.setuservalue\>/
      syn match luaFunc /\<debug\.upvalueid\>/
      syn match luaFunc /\<debug\.upvaluejoin\>/
    endif
    if lua_subversion >= 4
      syn match luaFunc /\<debug.setcstacklimit\>/
    endif
  endif
endif

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link luaStatement        Statement
hi def link luaRepeat           Repeat
hi def link luaFor              Repeat
hi def link luaString           String
hi def link luaString2          String
hi def link luaStringDelimiter  luaString
hi def link luaNumber           Number
hi def link luaOperator         Operator
hi def link luaSymbolOperator   luaOperator
hi def link luaConstant         Constant
hi def link luaCond             Conditional
hi def link luaCondElse         Conditional
hi def link luaFunction         Function
hi def link luaMetaMethod       Function
hi def link luaComment          Comment
hi def link luaCommentDelimiter luaComment
hi def link luaTodo             Todo
hi def link luaTable            Structure
hi def link luaError            Error
hi def link luaParenError       Error
hi def link luaSpecial          SpecialChar
hi def link luaFunc             Identifier
hi def link luaLabel            Label


let b:current_syntax = "lua"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: et ts=8 sw=2
