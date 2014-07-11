" Vim syntax file
" Language:         Quake[1-3] configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-06-17
"               quake_is_quake1 - the syntax is to be used for quake1 configs
"               quake_is_quake2 - the syntax is to be used for quake2 configs
"               quake_is_quake3 - the syntax is to be used for quake3 configs
" Credits:          Tomasz Kalkosinski wrote the original quake3Colors stuff

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-,+

syn keyword quakeTodo         contained TODO FIXME XXX NOTE

syn region  quakeComment      display oneline start='//' end='$' end=';'
                              \ keepend contains=quakeTodo,@Spell

syn region  quakeString       display oneline start=+"+ skip=+\\\\\|\\"+
                              \ end=+"\|$+ contains=quakeNumbers,
                              \ @quakeCommands,@quake3Colors

syn case ignore

syn match quakeNumbers        display transparent '\<-\=\d\|\.\d'
                              \ contains=quakeNumber,quakeFloat,
                              \ quakeOctalError,quakeOctal
syn match quakeNumber         contained display '\d\+\>'
syn match quakeFloat          contained display '\d\+\.\d*'
syn match quakeFloat          contained display '\.\d\+\>'

if exists("quake_is_quake1") || exists("quake_is_quake2")
  syn match quakeOctal        contained display '0\o\+\>'
                              \ contains=quakeOctalZero
  syn match quakeOctalZero    contained display '\<0'
  syn match quakeOctalError   contained display '0\o*[89]\d*'
endif

syn cluster quakeCommands     contains=quakeCommand,quake1Command,
                              \ quake12Command,Quake2Command,Quake23Command,
                              \ Quake3Command

syn keyword quakeCommand      +attack +back +forward +left +lookdown +lookup
syn keyword quakeCommand      +mlook +movedown +moveleft +moveright +moveup
syn keyword quakeCommand      +right +speed +strafe -attack -back bind
syn keyword quakeCommand      bindlist centerview clear connect cvarlist dir
syn keyword quakeCommand      disconnect dumpuser echo error exec -forward
syn keyword quakeCommand      god heartbeat joy_advancedupdate kick kill
syn keyword quakeCommand      killserver -left -lookdown -lookup map
syn keyword quakeCommand      messagemode messagemode2 -mlook modellist
syn keyword quakeCommand      -movedown -moveleft -moveright -moveup play
syn keyword quakeCommand      quit rcon reconnect record -right say say_team
syn keyword quakeCommand      screenshot serverinfo serverrecord serverstop
syn keyword quakeCommand      set sizedown sizeup snd_restart soundinfo
syn keyword quakeCommand      soundlist -speed spmap status -strafe stopsound
syn keyword quakeCommand      toggleconsole unbind unbindall userinfo pause
syn keyword quakeCommand      vid_restart viewpos wait weapnext weapprev

if exists("quake_is_quake1")
  syn keyword quake1Command   sv
endif

if exists("quake_is_quake1") || exists("quake_is_quake2")
  syn keyword quake12Command  +klook alias cd impulse link load save
  syn keyword quake12Command  timerefresh changing info loading
  syn keyword quake12Command  pingservers playerlist players score
endif

if exists("quake_is_quake2")
  syn keyword quake2Command   cmd demomap +use condump download drop gamemap
  syn keyword quake2Command   give gun_model setmaster sky sv_maplist wave
  syn keyword quake2Command   cmdlist gameversiona gun_next gun_prev invdrop
  syn keyword quake2Command   inven invnext invnextp invnextw invprev
  syn keyword quake2Command   invprevp invprevw invuse menu_addressbook
  syn keyword quake2Command   menu_credits menu_dmoptions menu_game
  syn keyword quake2Command   menu_joinserver menu_keys menu_loadgame
  syn keyword quake2Command   menu_main menu_multiplayer menu_options
  syn keyword quake2Command   menu_playerconfig menu_quit menu_savegame
  syn keyword quake2Command   menu_startserver menu_video
  syn keyword quake2Command   notarget precache prog togglechat vid_front
  syn keyword quake2Command   weaplast
endif

if exists("quake_is_quake2") || exists("quake_is_quake3")
  syn keyword quake23Command  imagelist modellist path z_stats
endif

if exists("quake_is_quake3")
  syn keyword quake3Command   +info +scores +zoom addbot arena banClient
  syn keyword quake3Command   banUser callteamvote callvote changeVectors
  syn keyword quake3Command   cinematic clientinfo clientkick cmd cmdlist
  syn keyword quake3Command   condump configstrings crash cvar_restart devmap
  syn keyword quake3Command   fdir follow freeze fs_openedList Fs_pureList
  syn keyword quake3Command   Fs_referencedList gfxinfo globalservers
  syn keyword quake3Command   hunk_stats in_restart -info levelshot
  syn keyword quake3Command   loaddeferred localservers map_restart mem_info
  syn keyword quake3Command   messagemode3 messagemode4 midiinfo model music
  syn keyword quake3Command   modelist net_restart nextframe nextskin noclip
  syn keyword quake3Command   notarget ping prevframe prevskin reset restart
  syn keyword quake3Command   s_disable_a3d s_enable_a3d s_info s_list s_stop
  syn keyword quake3Command   scanservers -scores screenshotJPEG sectorlist
  syn keyword quake3Command   serverstatus seta setenv sets setu setviewpos
  syn keyword quake3Command   shaderlist showip skinlist spdevmap startOribt
  syn keyword quake3Command   stats stopdemo stoprecord systeminfo togglemenu
  syn keyword quake3Command   tcmd team teamtask teamvote tell tell_attacker
  syn keyword quake3Command   tell_target testgun testmodel testshader toggle
  syn keyword quake3Command   touchFile vminfo vmprofile vmtest vosay
  syn keyword quake3Command   vosay_team vote votell vsay vsay_team vstr
  syn keyword quake3Command   vtaunt vtell vtell_attacker vtell_target weapon
  syn keyword quake3Command   writeconfig -zoom
  syn match   quake3Command   display "\<[+-]button\(\d\|1[0-4]\)\>"
endif

if exists("quake_is_quake3")
  syn cluster quake3Colors    contains=quake3Red,quake3Green,quake3Yellow,
                              \ quake3Blue,quake3Cyan,quake3Purple,quake3White,
                              \ quake3Orange,quake3Grey,quake3Black,quake3Shadow

  syn region quake3Red        contained start=+\^1+hs=e+1 end=+[$^"\n]+he=e-1
  syn region quake3Green      contained start=+\^2+hs=e+1 end=+[$^"\n]+he=e-1
  syn region quake3Yellow     contained start=+\^3+hs=e+1 end=+[$^"\n]+he=e-1
  syn region quake3Blue       contained start=+\^4+hs=e+1 end=+[$^"\n]+he=e-1
  syn region quake3Cyan       contained start=+\^5+hs=e+1 end=+[$^"\n]+he=e-1
  syn region quake3Purple     contained start=+\^6+hs=e+1 end=+[$^"\n]+he=e-1
  syn region quake3White      contained start=+\^7+hs=e+1 end=+[$^"\n]+he=e-1
  syn region quake3Orange     contained start=+\^8+hs=e+1 end=+[$^\"\n]+he=e-1
  syn region quake3Grey       contained start=+\^9+hs=e+1 end=+[$^"\n]+he=e-1
  syn region quake3Black      contained start=+\^0+hs=e+1 end=+[$^"\n]+he=e-1
  syn region quake3Shadow     contained start=+\^[Xx]+hs=e+1 end=+[$^"\n]+he=e-1
endif

hi def link quakeComment      Comment
hi def link quakeTodo         Todo
hi def link quakeString       String
hi def link quakeNumber       Number
hi def link quakeOctal        Number
hi def link quakeOctalZero    PreProc
hi def link quakeFloat        Number
hi def link quakeOctalError   Error
hi def link quakeCommand      quakeCommands
hi def link quake1Command     quakeCommands
hi def link quake12Command    quakeCommands
hi def link quake2Command     quakeCommands
hi def link quake23Command    quakeCommands
hi def link quake3Command     quakeCommands
hi def link quakeCommands     Keyword

if exists("quake_is_quake3")
  hi quake3Red                ctermfg=Red         guifg=Red
  hi quake3Green              ctermfg=Green       guifg=Green
  hi quake3Yellow             ctermfg=Yellow      guifg=Yellow
  hi quake3Blue               ctermfg=Blue        guifg=Blue
  hi quake3Cyan               ctermfg=Cyan        guifg=Cyan
  hi quake3Purple             ctermfg=DarkMagenta guifg=Purple
  hi quake3White              ctermfg=White       guifg=White
  hi quake3Black              ctermfg=Black       guifg=Black
  hi quake3Orange             ctermfg=Brown       guifg=Orange
  hi quake3Grey               ctermfg=LightGrey   guifg=LightGrey
  hi quake3Shadow             cterm=underline     gui=underline
endif

let b:current_syntax = "quake"

let &cpo = s:cpo_save
unlet s:cpo_save
