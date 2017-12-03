" Vim syntax file
" Language:             nanorc(5) - GNU nano configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword nanorcTodo          contained TODO FIXME XXX NOTE

syn region  nanorcComment       display oneline start='^\s*#' end='$'
                                \ contains=nanorcTodo,@Spell

syn match   nanorcBegin         display '^'
                                \ nextgroup=nanorcKeyword,nanorcComment
                                \ skipwhite

syn keyword nanorcKeyword       contained set unset
                                \ nextgroup=nanorcBoolOption,
                                \ nanorcStringOption,nanorcNumberOption
                                \ skipwhite

syn keyword nanorcKeyword       contained syntax
                                \ nextgroup=nanorcSynGroupName skipwhite

syn keyword nanorcKeyword       contained color
                                \ nextgroup=@nanorcFGColor skipwhite

syn keyword nanorcBoolOption    contained autoindent backup const cut
                                \ historylog morespace mouse multibuffer
                                \ noconvert nofollow nohelp nowrap preserve
                                \ rebinddelete regexp smarthome smooth suspend
                                \ tempfile view

syn keyword nanorcStringOption  contained backupdir brackets operatingdir
                                \ punct quotestr speller whitespace
                                \ nextgroup=nanorcString skipwhite

syn keyword nanorcNumberOption  contained fill tabsize
                                \ nextgroup=nanorcNumber skipwhite

syn region  nanorcSynGroupName  contained display oneline start=+"+
                                \ end=+"\ze\%([[:blank:]]\|$\)+
                                \ nextgroup=nanorcRegexes skipwhite

syn match   nanorcString        contained display '".*"'

syn region  nanorcRegexes       contained display oneline start=+"+
                                \ end=+"\ze\%([[:blank:]]\|$\)+
                                \ nextgroup=nanorcRegexes skipwhite

syn match   nanorcNumber        contained display '[+-]\=\<\d\+\>'

syn cluster nanorcFGColor       contains=nanorcFGWhite,nanorcFGBlack,
                                \ nanorcFGRed,nanorcFGBlue,nanorcFGGreen,
                                \ nanorcFGYellow,nanorcFGMagenta,nanorcFGCyan,
                                \ nanorcFGBWhite,nanorcFGBBlack,nanorcFGBRed,
                                \ nanorcFGBBlue,nanorcFGBGreen,nanorcFGBYellow,
                                \ nanorcFGBMagenta,nanorcFGBCyan

syn keyword nanorcFGWhite       contained white
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBlack       contained black
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGRed         contained red
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBlue        contained blue
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGGreen       contained green
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGYellow      contained yellow
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGMagenta     contained magenta
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGCyan        contained cyan
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBWhite      contained brightwhite
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBBlack      contained brightblack
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBRed        contained brightred
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBBlue       contained brightblue
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBGreen      contained brightgreen
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBYellow     contained brightyellow
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBMagenta    contained brightmagenta
                                \ nextgroup=@nanorcFGSpec skipwhite

syn keyword nanorcFGBCyan       contained brightcyan
                                \ nextgroup=@nanorcFGSpec skipwhite

syn cluster nanorcBGColor       contains=nanorcBGWhite,nanorcBGBlack,
                                \ nanorcBGRed,nanorcBGBlue,nanorcBGGreen,
                                \ nanorcBGYellow,nanorcBGMagenta,nanorcBGCyan,
                                \ nanorcBGBWhite,nanorcBGBBlack,nanorcBGBRed,
                                \ nanorcBGBBlue,nanorcBGBGreen,nanorcBGBYellow,
                                \ nanorcBGBMagenta,nanorcBGBCyan

syn keyword nanorcBGWhite       contained white
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBlack       contained black
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGRed         contained red
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBlue        contained blue
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGGreen       contained green
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGYellow      contained yellow
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGMagenta     contained magenta
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGCyan        contained cyan
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBWhite      contained brightwhite
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBBlack      contained brightblack
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBRed        contained brightred
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBBlue       contained brightblue
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBGreen      contained brightgreen
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBYellow     contained brightyellow
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBMagenta    contained brightmagenta
                                \ nextgroup=@nanorcBGSpec skipwhite

syn keyword nanorcBGBCyan       contained brightcyan
                                \ nextgroup=@nanorcBGSpec skipwhite

syn match   nanorcBGColorSep    contained ',' nextgroup=@nanorcBGColor

syn cluster nanorcFGSpec        contains=nanorcBGColorSep,nanorcRegexes,
                                \ nanorcStartRegion

syn cluster nanorcBGSpec        contains=nanorcRegexes,nanorcStartRegion

syn keyword nanorcStartRegion   contained start nextgroup=nanorcStartRegionEq

syn match   nanorcStartRegionEq contained '=' nextgroup=nanorcRegion

syn region  nanorcRegion        contained display oneline start=+"+
                                \ end=+"\ze\%([[:blank:]]\|$\)+
                                \ nextgroup=nanorcEndRegion skipwhite

syn keyword nanorcEndRegion     contained end nextgroup=nanorcStartRegionEq

syn match   nanorcEndRegionEq   contained '=' nextgroup=nanorcRegex

syn region  nanorcRegex         contained display oneline start=+"+
                                \ end=+"\ze\%([[:blank:]]\|$\)+

hi def link nanorcTodo          Todo
hi def link nanorcComment       Comment
hi def link nanorcKeyword       Keyword
hi def link nanorcBoolOption    Identifier
hi def link nanorcStringOption  Identifier
hi def link nanorcNumberOption  Identifier
hi def link nanorcSynGroupName  String
hi def link nanorcString        String
hi def link nanorcRegexes       nanorcString
hi def link nanorcNumber        Number
hi def      nanorcFGWhite       ctermfg=Gray guifg=Gray
hi def      nanorcFGBlack       ctermfg=Black guifg=Black
hi def      nanorcFGRed         ctermfg=DarkRed guifg=DarkRed
hi def      nanorcFGBlue        ctermfg=DarkBlue guifg=DarkBlue
hi def      nanorcFGGreen       ctermfg=DarkGreen guifg=DarkGreen
hi def      nanorcFGYellow      ctermfg=Brown guifg=Brown
hi def      nanorcFGMagenta     ctermfg=DarkMagenta guifg=DarkMagenta
hi def      nanorcFGCyan        ctermfg=DarkCyan guifg=DarkCyan
hi def      nanorcFGBWhite      ctermfg=White guifg=White
hi def      nanorcFGBBlack      ctermfg=DarkGray guifg=DarkGray
hi def      nanorcFGBRed        ctermfg=Red guifg=Red
hi def      nanorcFGBBlue       ctermfg=Blue guifg=Blue
hi def      nanorcFGBGreen      ctermfg=Green guifg=Green
hi def      nanorcFGBYellow     ctermfg=Yellow guifg=Yellow
hi def      nanorcFGBMagenta    ctermfg=Magenta guifg=Magenta
hi def      nanorcFGBCyan       ctermfg=Cyan guifg=Cyan
hi def link nanorcBGColorSep    Normal
hi def      nanorcBGWhite       ctermbg=Gray guibg=Gray
hi def      nanorcBGBlack       ctermbg=Black guibg=Black
hi def      nanorcBGRed         ctermbg=DarkRed guibg=DarkRed
hi def      nanorcBGBlue        ctermbg=DarkBlue guibg=DarkBlue
hi def      nanorcBGGreen       ctermbg=DarkGreen guibg=DarkGreen
hi def      nanorcBGYellow      ctermbg=Brown guibg=Brown
hi def      nanorcBGMagenta     ctermbg=DarkMagenta guibg=DarkMagenta
hi def      nanorcBGCyan        ctermbg=DarkCyan guibg=DarkCyan
hi def      nanorcBGBWhite      ctermbg=White guibg=White
hi def      nanorcBGBBlack      ctermbg=DarkGray guibg=DarkGray
hi def      nanorcBGBRed        ctermbg=Red guibg=Red
hi def      nanorcBGBBlue       ctermbg=Blue guibg=Blue
hi def      nanorcBGBGreen      ctermbg=Green guibg=Green
hi def      nanorcBGBYellow     ctermbg=Yellow guibg=Yellow
hi def      nanorcBGBMagenta    ctermbg=Magenta guibg=Magenta
hi def      nanorcBGBCyan       ctermbg=Cyan guibg=Cyan
hi def link nanorcStartRegion   Type
hi def link nanorcStartRegionEq Operator
hi def link nanorcRegion        nanorcString
hi def link nanorcEndRegion     Type
hi def link nanorcEndRegionEq   Operator
hi def link nanorcRegex         nanoRegexes

let b:current_syntax = "nanorc"

let &cpo = s:cpo_save
unlet s:cpo_save
