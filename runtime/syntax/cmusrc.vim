" Vim syntax file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-06-17

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-

syn keyword cmusrcTodo          contained TODO FIXME XXX NOTE

syn match   cmusrcComment       contained display '^\s*#.*$'

syn match   cmusrcBegin         display '^'
                                \ nextgroup=cmusrcKeyword,cmusrcComment
                                \ skipwhite

syn keyword cmusrcKeyword       contained add
                                \ nextgroup=cmusrcAddSwitches,cmusrcURI
                                \ skipwhite

syn match   cmusrcAddSwitches   contained display '-[lpqQ]'
                                \ nextgroup=cmusrcURI
                                \ skipwhite

syn match   cmusrcURI           contained display '.\+'

syn keyword cmusrcKeyword       contained bind
                                \ nextgroup=cmusrcBindSwitches,
                                \           cmusrcBindContext
                                \ skipwhite

syn match   cmusrcBindSwitches  contained display '-[f]'
                                \ nextgroup=cmusrcBindContext
                                \ skipwhite

syn keyword cmusrcBindContext   contained common library playlist queue
                                \ browser filters
                                \ nextgroup=cmusrcBindKey
                                \ skipwhite

syn match   cmusrcBindKey       contained display '\S\+'
                                \ nextgroup=cmusrcKeyword
                                \ skipwhite

syn keyword cmusrcKeyword       contained browser-up colorscheme echo factivate
                                \ filter invert player-next player-pause
                                \ player-play player-prev player-stop quit
                                \ refresh run search-next search-prev shuffle
                                \ unmark win-activate win-add-l win-add-p
                                \ win-add-Q win-add-q win-bottom win-down
                                \ win-mv-after win-mv-before win-next
                                \ win-page-down win-page-up win-remove
                                \ win-sel-cur win-toggle win-top win-up
                                \ win-update

syn keyword cmusrcKeyword       contained cd
                                \ nextgroup=cmusrcDirectory
                                \ skipwhite

syn match   cmusrcDirectory     contained display '.\+'

syn keyword cmusrcKeyword       contained clear
                                \ nextgroup=cmusrcClearSwitches

syn match   cmusrcClearSwitches contained display '-[lpq]'

syn keyword cmusrcKeyword       contained fset
                                \ nextgroup=cmusrcFSetName
                                \ skipwhite

syn match   cmusrcFSetName      contained display '[^=]\+'
                                \ nextgroup=cmusrcFSetEq

syn match   cmusrcFSetEq        contained display '='
                                \ nextgroup=cmusrcFilterExpr

syn match   cmusrcFilterExpr    contained display '.\+'

syn keyword cmusrcKeyword       contained load
                                \ nextgroup=cmusrcLoadSwitches,cmusrcURI
                                \ skipwhite

syn match   cmusrcLoadSwitches  contained display '-[lp]'
                                \ nextgroup=cmusrcURI
                                \ skipwhite

syn keyword cmusrcKeyword       contained mark
                                \ nextgroup=cmusrcFilterExpr

syn keyword cmusrcKeyword       contained save
                                \ nextgroup=cmusrcSaveSwitches,cmusrcFile
                                \ skipwhite

syn match   cmusrcSaveSwitches  contained display '-[lp]'
                                \ nextgroup=cmusrcFile
                                \ skipwhite

syn match   cmusrcFile          contained display '.\+'

syn keyword cmusrcKeyword       contained seek
                                \ nextgroup=cmusrcSeekOffset
                                \ skipwhite

syn match   cmusrcSeekOffset    contained display
      \ '[+-]\=\%(\d\+[mh]\=\|\%(\%(0\=\d\|[1-5]\d\):\)\=\%(0\=\d\|[1-5]\d\):\%(0\=\d\|[1-5]\d\)\)'

syn keyword cmusrcKeyword       contained set
                                \ nextgroup=cmusrcOption
                                \ skipwhite

syn keyword cmusrcOption        contained auto_reshuffle confirm_run
                                \ continue play_library play_sorted repeat
                                \ show_hidden show_remaining_time shuffle
                                \ nextgroup=cmusrcSetTest,cmusrcOptEqBoolean

syn match   cmusrcSetTest       contained display '?'

syn match   cmusrcOptEqBoolean  contained display '='
                                \ nextgroup=cmusrcOptBoolean

syn keyword cmusrcOptBoolean    contained true false

syn keyword cmusrcOption        contained aaa_mode
                                \ nextgroup=cmusrcOptEqAAA

syn match   cmusrcOptEqAAA      contained display '='
                                \ nextgroup=cmusrcOptAAA

syn keyword cmusrcOptAAA        contained all artist album

syn keyword cmusrcOption        contained buffer_seconds
                                \ nextgroup=cmusrcOptEqNumber

syn match   cmusrcOptEqNumber   contained display '='
                                \ nextgroup=cmusrcOptNumber

syn match   cmusrcOptNumber     contained display '\d\+'

syn keyword cmusrcOption        contained altformat_current altformat_playlist
                                \ altformat_title altformat_trackwin
                                \ format_current format_playlist format_title
                                \ format_trackwin
                                \ nextgroup=cmusrcOptEqFormat

syn match   cmusrcOptEqFormat   contained display '='
                                \ nextgroup=cmusrcOptFormat

syn match   cmusrcOptFormat     contained display '.\+'
                                \ contains=cmusrcFormatSpecial

syn match   cmusrcFormatSpecial contained display '%[0-]*\d*[alDntgydfF=%]'

syn keyword cmusrcOption        contained color_cmdline_bg color_cmdline_fg
                                \ color_error color_info color_separator
                                \ color_statusline_bg color_statusline_fg
                                \ color_titleline_bg color_titleline_fg
                                \ color_win_bg color_win_cur
                                \ color_win_cur_sel_bg color_win_cur_sel_fg
                                \ color_win_dir color_win_fg
                                \ color_win_inactive_cur_sel_bg
                                \ color_win_inactive_cur_sel_fg
                                \ color_win_inactive_sel_bg
                                \ color_win_inactive_sel_fg
                                \ color_win_sel_bg color_win_sel_fg
                                \ color_win_title_bg color_win_title_fg
                                \ nextgroup=cmusrcOptEqColor

syn match   cmusrcOptEqColor    contained display '='
                                \ nextgroup=@cmusrcOptColor

syn cluster cmusrcOptColor      contains=cmusrcOptColorName,cmusrcOptColorValue

syn keyword cmusrcOptColorName  contained default black red green yellow blue
                                \ magenta cyan gray darkgray lightred lightred
                                \ lightgreen lightyellow lightblue lightmagenta
                                \ lightcyan white

syn match   cmusrcOptColorValue contained display
                        \ '-1\|0*\%(\d\|[1-9]\d\|1\d\d\|2\%([0-4]\d\|5[0-5]\)\)'

syn keyword cmusrcOption        contained id3_default_charset output_plugin
                                \ status_display_program
                                \ nextgroup=cmusrcOptEqString

syn match   cmusrcOption        contained
                    \ '\%(dsp\|mixer\)\.\%(alsa\|oss\|sun\)\.\%(channel\|device\)'
                    \ nextgroup=cmusrcOptEqString

syn match   cmusrcOption        contained
                    \ 'dsp\.ao\.\%(buffer_size\|driver\|wav_counter\|wav_dir\)'
                    \ nextgroup=cmusrcOptEqString

syn match   cmusrcOptEqString   contained display '='
                                \ nextgroup=cmusrcOptString

syn match   cmusrcOptString     contained display '.\+'

syn keyword cmusrcOption        contained lib_sort pl_sort
                                \ nextgroup=cmusrcOptEqSortKeys

syn match   cmusrcOptEqSortKeys contained display '='
                                \ nextgroup=cmusrcOptSortKeys

syn keyword cmusrcOptSortKeys   contained artist album title tracknumber
                                \ discnumber date genre filename
                                \ nextgroup=cmusrcOptSortKeys
                                \ skipwhite

syn keyword cmusrcKeyword       contained showbind
                                \ nextgroup=cmusrcSBindContext
                                \ skipwhite

syn keyword cmusrcSBindContext  contained common library playlist queue
                                \ browser filters
                                \ nextgroup=cmusrcSBindKey
                                \ skipwhite

syn match   cmusrcSBindKey      contained display '\S\+'

syn keyword cmusrcKeyword       contained toggle
                                \ nextgroup=cmusrcTogglableOpt
                                \ skipwhite

syn keyword cmusrcTogglableOpt  contained auto_reshuffle aaa_mode
                                \ confirm_run continue play_library play_sorted
                                \ repeat show_hidden show_remaining_time shuffle

syn keyword cmusrcKeyword       contained unbind
                                \ nextgroup=cmusrcUnbindSwitches,
                                \           cmusrcSBindContext
                                \ skipwhite

syn match   cmusrcUnbindSwitches  contained display '-[f]'
                                  \ nextgroup=cmusrcSBindContext
                                  \ skipwhite

syn keyword cmusrcKeyword       contained view
                                \ nextgroup=cmusrcView
                                \ skipwhite

syn keyword cmusrcView          contained library playlist queue browser filters
syn match   cmusrcView          contained display '[1-6]'

syn keyword cmusrcKeyword       contained vol
                                \ nextgroup=cmusrcVolume1
                                \ skipwhite

syn match   cmusrcVolume1       contained display '[+-]\=\d\+%'
                                \ nextgroup=cmusrcVolume2
                                \ skipwhite

syn match   cmusrcVolume2       contained display '[+-]\=\d\+%'

hi def link cmusrcTodo            Todo
hi def link cmusrcComment         Comment
hi def link cmusrcKeyword         Keyword
hi def link cmusrcSwitches        Special
hi def link cmusrcAddSwitches     cmusrcSwitches
hi def link cmusrcURI             Normal
hi def link cmusrcBindSwitches    cmusrcSwitches
hi def link cmusrcContext         Type
hi def link cmusrcBindContext     cmusrcContext
hi def link cmusrcKey             String
hi def link cmusrcBindKey         cmusrcKey
hi def link cmusrcDirectory       Normal
hi def link cmusrcClearSwitches   cmusrcSwitches
hi def link cmusrcFSetName        PreProc
hi def link cmusrcEq              Normal
hi def link cmusrcFSetEq          cmusrcEq
hi def link cmusrcFilterExpr      Normal
hi def link cmusrcLoadSwitches    cmusrcSwitches
hi def link cmusrcSaveSwitches    cmusrcSwitches
hi def link cmusrcFile            Normal
hi def link cmusrcSeekOffset      Number
hi def link cmusrcOption          PreProc
hi def link cmusrcSetTest         Normal
hi def link cmusrcOptBoolean      Boolean
hi def link cmusrcOptEqAAA        cmusrcEq
hi def link cmusrcOptAAA          Identifier
hi def link cmusrcOptEqNumber     cmusrcEq
hi def link cmusrcOptNumber       Number
hi def link cmusrcOptEqFormat     cmusrcEq
hi def link cmusrcOptFormat       String
hi def link cmusrcFormatSpecial   SpecialChar
hi def link cmusrcOptEqColor      cmusrcEq
hi def link cmusrcOptColor        Normal
hi def link cmusrcOptColorName    cmusrcOptColor
hi def link cmusrcOptColorValue   cmusrcOptColor
hi def link cmusrcOptEqString     cmusrcEq
hi def link cmusrcOptString       Normal
hi def link cmusrcOptEqSortKeys   cmusrcEq
hi def link cmusrcOptSortKeys     Identifier
hi def link cmusrcSBindContext    cmusrcContext
hi def link cmusrcSBindKey        cmusrcKey
hi def link cmusrcTogglableOpt    cmusrcOption
hi def link cmusrcUnbindSwitches  cmusrcSwitches
hi def link cmusrcView            Normal
hi def link cmusrcVolume1         Number
hi def link cmusrcVolume2         Number

let b:current_syntax = "cmusrc"

let &cpo = s:cpo_save
unlet s:cpo_save
