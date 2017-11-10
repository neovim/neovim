" Vim syntax file
" Language:             grub(8) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword grubTodo          contained TODO FIXME XXX NOTE

syn region  grubComment       display oneline start='^#' end='$'
                              \ contains=grubTodo,@Spell

syn match   grubDevice        display
                              \ '(\([fh]d\d\|\d\+\|0x\x\+\)\(,\d\+\)\=\(,\l\)\=)'

syn match   grubBlock         display '\(\d\+\)\=+\d\+\(,\(\d\+\)\=+\d\+\)*'

syn match   grubNumbers       display '+\=\<\d\+\|0x\x\+\>'

syn match   grubBegin         display '^'
                              \ nextgroup=@grubCommands,grubComment skipwhite

syn cluster grubCommands      contains=grubCommand,grubTitleCommand

syn keyword grubCommand       contained default fallback hiddenmenu timeout

syn keyword grubTitleCommand  contained title nextgroup=grubTitle skipwhite

syn match   grubTitle         contained display '.*'

syn keyword grubCommand       contained bootp color device dhcp hide ifconfig
                              \ pager partnew parttype password rarp serial setkey
                              \ terminal tftpserver unhide blocklist boot cat
                              \ chainloader cmp configfile debug displayapm
                              \ displaymem embed find fstest geometry halt help
                              \ impsprobe initrd install ioprobe kernel lock
                              \ makeactive map md5crypt module modulenounzip pause
                              \ quit reboot read root rootnoverify savedefault setup
                              \ testload testvbe uppermem vbeprobe

syn keyword grubSpecial       saved

syn match   grubBlink         display 'blink-'
syn keyword grubBlack         black
syn keyword grubBlue          blue
syn keyword grubGreen         green
syn keyword grubRed           red
syn keyword grubMagenta       magenta
syn keyword grubBrown         brown yellow
syn keyword grubWhite         white
syn match   grubLightGray     display 'light-gray'
syn match   grubLightBlue     display 'light-blue'
syn match   grubLightGreen    display 'light-green'
syn match   grubLightCyan     display 'light-cyan'
syn match   grubLightRed      display 'light-red'
syn match   grubLightMagenta  display 'light-magenta'
syn match   grubDarkGray      display 'dark-gray'

hi def link grubComment       Comment
hi def link grubTodo          Todo
hi def link grubNumbers       Number
hi def link grubDevice        Identifier
hi def link grubBlock         Identifier
hi def link grubCommand       Keyword
hi def link grubTitleCommand  grubCommand
hi def link grubTitle         String
hi def link grubSpecial       Special

hi def      grubBlink         cterm=inverse
hi def      grubBlack         ctermfg=Black ctermbg=White guifg=Black guibg=White
hi def      grubBlue          ctermfg=DarkBlue guifg=DarkBlue
hi def      grubGreen         ctermfg=DarkGreen guifg=DarkGreen
hi def      grubRed           ctermfg=DarkRed guifg=DarkRed
hi def      grubMagenta       ctermfg=DarkMagenta guifg=DarkMagenta
hi def      grubBrown         ctermfg=Brown guifg=Brown
hi def      grubWhite         ctermfg=White ctermbg=Black guifg=White guibg=Black
hi def      grubLightGray     ctermfg=LightGray guifg=LightGray
hi def      grubLightBlue     ctermfg=LightBlue guifg=LightBlue
hi def      grubLightGreen    ctermfg=LightGreen guifg=LightGreen
hi def      grubLightCyan     ctermfg=LightCyan guifg=LightCyan
hi def      grubLightRed      ctermfg=LightRed guifg=LightRed
hi def      grubLightMagenta  ctermfg=LightMagenta guifg=LightMagenta
hi def      grubDarkGray      ctermfg=DarkGray guifg=DarkGray

let b:current_syntax = "grub"

let &cpo = s:cpo_save
unlet s:cpo_save
