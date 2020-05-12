" Vim syntax file
" Language:             pinfo(1) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2007-06-17

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-

syn case ignore

syn keyword pinfoTodo             contained FIXME TODO XXX NOTE

syn region  pinfoComment          start='^#' end='$' contains=pinfoTodo,@Spell

syn keyword pinfoOptions          MANUAL CUT-MAN-HEADERS CUT-EMPTY-MAN-LINES
                                  \ RAW-FILENAME APROPOS
                                  \ DONT-HANDLE-WITHOUT-TAG-TABLE HTTPVIEWER
                                  \ FTPVIEWER MAILEDITOR PRINTUTILITY MANLINKS
                                  \ INFOPATH MAN-OPTIONS STDERR-REDIRECTION
                                  \ LONG-MANUAL-LINKS FILTER-0xB7
                                  \ QUIT-CONFIRMATION QUIT-CONFIRM-DEFAULT
                                  \ CLEAR-SCREEN-AT-EXIT CALL-READLINE-HISTORY
                                  \ HIGHLIGHTREGEXP SAFE-USER SAFE-GROUP

syn keyword pinfoColors           COL_NORMAL COL_TOPLINE COL_BOTTOMLINE
                                  \ COL_MENU COL_MENUSELECTED COL_NOTE
                                  \ COL_NOTESELECTED COL_URL COL_URLSELECTED
                                  \ COL_INFOHIGHLIGHT COL_MANUALBOLD
                                  \ COL_MANUALITALIC COL_SEARCHHIGHLIGHT

syn keyword pinfoColorDefault     COLOR_DEFAULT
syn keyword pinfoColorBold        BOLD
syn keyword pinfoColorNoBold      NO_BOLD
syn keyword pinfoColorBlink       BLINK
syn keyword pinfoColorNoBlink     NO_BLINK
syn keyword pinfoColorBlack       COLOR_BLACK
syn keyword pinfoColorRed         COLOR_RED
syn keyword pinfoColorGreen       COLOR_GREEN
syn keyword pinfoColorYellow      COLOR_YELLOW
syn keyword pinfoColorBlue        COLOR_BLUE
syn keyword pinfoColorMagenta     COLOR_MAGENTA
syn keyword pinfoColorCyan        COLOR_CYAN
syn keyword pinfoColorWhite       COLOR_WHITE

syn keyword pinfoKeys             KEY_TOTALSEARCH_1 KEY_TOTALSEARCH_2
                                  \ KEY_SEARCH_1 KEY_SEARCH_2
                                  \ KEY_SEARCH_AGAIN_1 KEY_SEARCH_AGAIN_2
                                  \ KEY_GOTO_1 KEY_GOTO_2 KEY_PREVNODE_1
                                  \ KEY_PREVNODE_2 KEY_NEXTNODE_1
                                  \ KEY_NEXTNODE_2 KEY_UP_1 KEY_UP_2 KEY_END_1
                                  \ KEY_END_2 KEY_PGDN_1 KEY_PGDN_2
                                  \ KEY_PGDN_AUTO_1 KEY_PGDN_AUTO_2 KEY_HOME_1
                                  \ KEY_HOME_2 KEY_PGUP_1 KEY_PGUP_2
                                  \ KEY_PGUP_AUTO_1 KEY_PGUP_AUTO_2 KEY_DOWN_1
                                  \ KEY_DOWN_2 KEY_TOP_1 KEY_TOP_2 KEY_BACK_1
                                  \ KEY_BACK_2 KEY_FOLLOWLINK_1
                                  \ KEY_FOLLOWLINK_2 KEY_REFRESH_1
                                  \ KEY_REFRESH_2 KEY_SHELLFEED_1
                                  \ KEY_SHELLFEED_2 KEY_QUIT_1 KEY_QUIT_2
                                  \ KEY_GOLINE_1 KEY_GOLINE_2 KEY_PRINT_1
                                  \ KEY_PRINT_2 KEY_DIRPAGE_1 KEY_DIRPAGE_2
                                  \ KEY_TWODOWN_1 KEY_TWODOWN_2 KEY_TWOUP_1
                                  \ KEY_TWOUP_2

syn keyword pinfoSpecialKeys      KEY_BREAK KEY_DOWN KEY_UP KEY_LEFT KEY_RIGHT
                                  \ KEY_DOWN KEY_HOME KEY_BACKSPACE KEY_NPAGE
                                  \ KEY_PPAGE KEY_END KEY_IC KEY_DC
syn region  pinfoSpecialKeys      matchgroup=pinfoSpecialKeys transparent
                                  \ start=+KEY_\%(F\|CTRL\|ALT\)(+ end=+)+
syn region  pinfoSimpleKey        start=+'+ skip=+\\'+ end=+'+
                                  \ contains=pinfoSimpleKeyEscape
syn match   pinfoSimpleKeyEscape  +\\[\\nt']+
syn match   pinfoKeycode          '\<\d\+\>'

syn keyword pinfoConstants        TRUE FALSE YES NO

hi def link pinfoTodo             Todo
hi def link pinfoComment          Comment
hi def link pinfoOptions          Keyword
hi def link pinfoColors           Keyword
hi def link pinfoColorDefault     Normal
hi def link pinfoSpecialKeys      SpecialChar
hi def link pinfoSimpleKey        String
hi def link pinfoSimpleKeyEscape  SpecialChar
hi def link pinfoKeycode          Number
hi def link pinfoConstants        Constant
hi def link pinfoKeys             Keyword
hi def      pinfoColorBold        cterm=bold
hi def      pinfoColorNoBold      cterm=none
hi def      pinfoColorBlink       cterm=inverse
hi def      pinfoColorNoBlink     cterm=none
hi def      pinfoColorBlack       ctermfg=Black       guifg=Black
hi def      pinfoColorRed         ctermfg=DarkRed     guifg=DarkRed
hi def      pinfoColorGreen       ctermfg=DarkGreen   guifg=DarkGreen
hi def      pinfoColorYellow      ctermfg=DarkYellow  guifg=DarkYellow
hi def      pinfoColorBlue        ctermfg=DarkBlue    guifg=DarkBlue
hi def      pinfoColorMagenta     ctermfg=DarkMagenta guifg=DarkMagenta
hi def      pinfoColorCyan        ctermfg=DarkCyan    guifg=DarkCyan
hi def      pinfoColorWhite       ctermfg=LightGray   guifg=LightGray

let b:current_syntax = "pinfo"

let &cpo = s:cpo_save
unlet s:cpo_save
