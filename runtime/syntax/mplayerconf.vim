" Vim syntax file
" Language:             mplayer(1) configuration file
" Maintainer:           Dmitri Vereshchagin <dmitri.vereshchagin@gmail.com>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2015-01-24

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-

syn keyword mplayerconfTodo     contained TODO FIXME XXX NOTE

syn region mplayerconfComment   display oneline start='#' end='$'
                                \ contains=mplayerconfTodo,@Spell

syn keyword mplayerconfPreProc  include

syn keyword mplayerconfBoolean  yes no true false

syn match   mplayerconfNumber   '\<\d\+\>'

syn keyword mplayerconfOption   hardframedrop nomouseinput bandwidth dumpstream
                                \ rtsp-stream-over-tcp tv overlapsub
                                \ sub-bg-alpha subfont-outline unicode format
                                \ vo edl cookies fps zrfd af-adv nosound
                                \ audio-density passlogfile vobsuboutindex autoq
                                \ autosync benchmark colorkey nocolorkey edlout
                                \ enqueue fixed-vo framedrop h identify input
                                \ lircconf list-options loop menu menu-cfg
                                \ menu-root nojoystick nolirc nortc playlist
                                \ quiet really-quiet shuffle skin slave
                                \ softsleep speed sstep use-stdin aid alang
                                \ audio-demuxer audiofile audiofile-cache
                                \ cdrom-device cache cdda channels chapter
                                \ cookies-file demuxer dumpaudio dumpfile
                                \ dumpvideo dvbin dvd-device dvdangle forceidx
                                \ frames hr-mp3-seek idx ipv4-only-proxy
                                \ loadidx mc mf ni nobps noextbased
                                \ passwd prefer-ipv4 prefer-ipv6 rawaudio
                                \ rawvideo saveidx sb srate ss tskeepbroken
                                \ tsprog tsprobe user user-agent vid vivo
                                \ dumpjacosub dumpmicrodvdsub dumpmpsub dumpsami
                                \ dumpsrtsub dumpsub ffactor flip-hebrew font
                                \ forcedsubsonly fribidi-charset ifo noautosub
                                \ osdlevel sid slang spuaa spualign spugauss
                                \ sub sub-bg-color sub-demuxer sub-fuzziness
                                \ sub-no-text-pp subalign subcc subcp subdelay
                                \ subfile subfont-autoscale subfont-blur
                                \ subfont-encoding subfont-osd-scale
                                \ subfont-text-scale subfps subpos subwidth
                                \ utf8 vobsub vobsubid abs ao aofile aop delay
                                \ mixer nowaveheader aa bpp brightness contrast
                                \ dfbopts display double dr dxr2 fb fbmode
                                \ fbmodeconfig forcexv fs fsmode-dontuse fstype
                                \ geometry guiwid hue jpeg monitor-dotclock
                                \ monitor-hfreq monitor-vfreq monitoraspect
                                \ nograbpointer nokeepaspect noxv ontop panscan
                                \ rootwin saturation screenw stop-xscreensaver
                                \ vm vsync wid xineramascreen z zrbw zrcrop
                                \ zrdev zrhelp zrnorm zrquality zrvdec zrxdoff
                                \ ac af afm aspect flip lavdopts noaspect
                                \ noslices novideo oldpp pp pphelp ssf stereo
                                \ sws vc vfm x xvidopts xy y zoom vf vop
                                \ audio-delay audio-preload endpos ffourcc
                                \ include info noautoexpand noskip o oac of
                                \ ofps ovc skiplimit v vobsubout vobsuboutid
                                \ lameopts lavcopts nuvopts xvidencopts a52drc
                                \ adapter af-add af-clr af-del af-pre
                                \ allow-dangerous-playlist-parsing ass
                                \ ass-border-color ass-bottom-margin ass-color
                                \ ass-font-scale ass-force-style ass-hinting
                                \ ass-line-spacing ass-styles ass-top-margin
                                \ ass-use-margins ausid bluray-angle
                                \ bluray-device border border-pos-x border-pos-y
                                \ cache-min cache-seek-min capture codecpath
                                \ codecs-file correct-pts crash-debug
                                \ doubleclick-time dvd-speed edl-backward-delay
                                \ edl-start-pts embeddedfonts fafmttag
                                \ field-dominance fontconfig force-avi-aspect
                                \ force-key-frames frameno-file fullscreen gamma
                                \ gui gui-include gui-wid heartbeat-cmd
                                \ heartbeat-interval hr-edl-seek
                                \ http-header-fields idle ignore-start
                                \ key-fifo-size list-properties menu-chroot
                                \ menu-keepdir menu-startup mixer-channel
                                \ monitor-orientation monitorpixelaspect
                                \ mouse-movements msgcharset msgcolor msglevel
                                \ msgmodule name noar nocache noconfig
                                \ noconsolecontrols nocorrect-pts nodouble
                                \ noedl-start-pts noencodedups
                                \ noflip-hebrew-commas nogui noidx noodml
                                \ nostop-xscreensaver nosub noterm-osd
                                \ osd-duration osd-fractions panscanrange
                                \ pausing playing-msg priority profile
                                \ progbar-align psprobe pvr radio referrer
                                \ refreshrate reuse-socket rtc rtc-device
                                \ rtsp-destination rtsp-port
                                \ rtsp-stream-over-http screenh show-profile
                                \ softvol softvol-max sub-paths subfont
                                \ term-osd-esc title tvscan udp-ip udp-master
                                \ udp-port udp-seek-threshold udp-slave
                                \ unrarexec use-filedir-conf use-filename-title
                                \ vf-add vf-clr vf-del vf-pre volstep volume
                                \ zrhdec zrydoff

syn region  mplayerconfString   display oneline start=+"+ end=+"+
syn region  mplayerconfString   display oneline start=+'+ end=+'+

syn region  mplayerconfProfile  display oneline start='^\s*\[' end='\]'

hi def link mplayerconfTodo     Todo
hi def link mplayerconfComment  Comment
hi def link mplayerconfPreProc  PreProc
hi def link mplayerconfBoolean  Boolean
hi def link mplayerconfNumber   Number
hi def link mplayerconfOption   Keyword
hi def link mplayerconfString   String
hi def link mplayerconfProfile  Special

let b:current_syntax = "mplayerconf"

let &cpo = s:cpo_save
unlet s:cpo_save
