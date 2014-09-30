" Vim syntax file
" Language:         calendar(1) input file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword calendarTodo          contained TODO FIXME XXX NOTE

syn region  calendarComment       start='/\*' end='\*/'
                                  \ contains=calendarTodo,@Spell

syn region  calendarCppString     start=+L\="+ skip=+\\\\\|\\"\|\\$+ excludenl
                                  \ end=+"+ end='$' contains=calendarSpecial
syn match   calendarSpecial       display contained '\\\%(x\x\+\|\o\{1,3}\|.\|$\)'
syn match   calendarSpecial       display contained "\\\(u\x\{4}\|U\x\{8}\)"

syn region  calendarPreCondit     start='^\s*#\s*\%(if\|ifdef\|ifndef\|elif\)\>'
                                  \ skip='\\$' end='$'
                                  \ contains=calendarComment,calendarCppString
syn match   calendarPreCondit     display '^\s*#\s*\%(else\|endif\)\>'
syn region  calendarCppOut        start='^\s*#\s*if\s\+0\+' end='.\@=\|$'
                                  \ contains=calendarCppOut2
syn region  calendarCppOut2       contained start='0'
                                  \ end='^\s*#\s*\%(endif\|else\|elif\)\>'
                                  \ contains=calendarSpaceError,calendarCppSkip
syn region  calendarCppSkip       contained
                                  \ start='^\s*#\s*\%(if\|ifdef\|ifndef\)\>'
                                  \ skip='\\$' end='^\s*#\s*endif\>'
                                  \ contains=calendarSpaceError,calendarCppSkip
syn region  calendarIncluded      display contained start=+"+ skip=+\\\\\|\\"+
                                  \ end=+"+
syn match   calendarIncluded      display contained '<[^>]*>'
syn match   calendarInclude       display '^\s*#\s*include\>\s*["<]'
                                  \ contains=calendarIncluded
syn cluster calendarPreProcGroup  contains=calendarPreCondit,calendarIncluded,
                                  \ calendarInclude,calendarDefine,
                                  \ calendarCppOut,calendarCppOut2,
                                  \ calendarCppSkip,calendarString,
                                  \ calendarSpecial,calendarTodo
syn region  calendarDefine        start='^\s*#\s*\%(define\|undef\)\>'
                                  \ skip='\\$' end='$'
                                  \ contains=ALLBUT,@calendarPreProcGroup
syn region  calendarPreProc       start='^\s*#\s*\%(pragma\|line\|warning\|warn\|error\)\>'
                                  \ skip='\\$' end='$' keepend
                                  \ contains=ALLBUT,@calendarPreProcGroup

syn keyword calendarKeyword       CHARSET BODUN LANG
syn case ignore
syn keyword calendarKeyword       Easter Pashka
syn case match

syn case ignore
syn match   calendarNumber        display '\<\d\+\>'
syn keyword calendarMonth         Jan[uary] Feb[ruary] Mar[ch] Apr[il] May
                                  \ Jun[e] Jul[y] Aug[ust] Sep[tember]
                                  \ Oct[ober] Nov[ember] Dec[ember]
syn match   calendarMonth         display '\<\%(Jan\|Feb\|Mar\|Apr\|May\|Jun\|Jul\|Aug\|Sep\|Oct\|Nov\|Dec\)\.'
syn keyword calendarWeekday       Mon[day] Tue[sday] Wed[nesday] Thu[rsday]
syn keyword calendarWeekday       Fri[day] Sat[urday] Sun[day]
syn match   calendarWeekday       display '\<\%(Mon\|Tue\|Wed\|Thu\|Fri\|Sat\|Sun\)\.'
                                  \ nextgroup=calendarWeekdayMod
syn match   calendarWeekdayMod    display '[+-]\d\+\>'
syn case match

syn match   calendarTime          display '\<\%([01]\=\d\|2[0-3]\):[0-5]\d\%(:[0-5]\d\)\='
syn match   calendarTime          display '\<\%(0\=[1-9]\|1[0-2]\):[0-5]\d\%(:[0-5]\d\)\=\s*[AaPp][Mm]'

syn match calendarVariable        '\*'

if exists("c_minlines")
  let b:c_minlines = c_minlines
else
  if !exists("c_no_if0")
    let b:c_minlines = 50       " #if 0 constructs can be long
  else
    let b:c_minlines = 15       " mostly for () constructs
  endif
endif
exec "syn sync ccomment calendarComment minlines=" . b:c_minlines

hi def link calendarTodo          Todo
hi def link calendarComment       Comment
hi def link calendarCppString     String
hi def link calendarSpecial       SpecialChar
hi def link calendarPreCondit     PreCondit
hi def link calendarCppOut        Comment
hi def link calendarCppOut2       calendarCppOut
hi def link calendarCppSkip       calendarCppOut
hi def link calendarIncluded      String
hi def link calendarInclude       Include
hi def link calendarDefine        Macro
hi def link calendarPreProc       PreProc
hi def link calendarKeyword       Keyword
hi def link calendarNumber        Number
hi def link calendarMonth         String
hi def link calendarWeekday       String
hi def link calendarWeekdayMod    Special
hi def link calendarTime          Number
hi def link calendarVariable      Identifier

let b:current_syntax = "calendar"

let &cpo = s:cpo_save
unlet s:cpo_save
