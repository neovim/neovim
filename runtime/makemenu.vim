" Script to define the syntax menu in synmenu.vim
" Maintainer:		The Vim Project <https://github.com/vim/vim>
" Last Change:		2026 Aug 03
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" This is used by "make menu" in the src directory.
edit <sfile>:p:h/synmenu.vim

/The Start Of The Syntax Menu/+1,/The End Of The Syntax Menu/-1d
let s:lnum = line(".") - 1
call append(s:lnum, "")
let s:lnum = s:lnum + 1

" Use the SynMenu command and function to define all menu entries
command! -nargs=* SynMenu call <SID>Syn(<q-args>)

let s:cur_menu_name = ""
let s:cur_menu_nr = 0
let s:cur_menu_item = 0
let s:cur_menu_char = ""

fun! <SID>Syn(arg)
  " isolate menu name: until the first dot
  let i = match(a:arg, '\.')
  let menu_name = strpart(a:arg, 0, i)
  let r = strpart(a:arg, i + 1, 999)
  " isolate submenu name: until the colon
  let i = match(r, ":")
  let submenu_name = strpart(r, 0, i)
  " after the colon is the syntax name
  let syntax_name = strpart(r, i + 1, 999)

  if s:cur_menu_name != menu_name
    let s:cur_menu_name = menu_name
    let s:cur_menu_nr = s:cur_menu_nr + 10
    let s:cur_menu_item = 100
    let s:cur_menu_char = submenu_name[0]
  else
    " When starting a new letter, insert a menu separator.
    let c = submenu_name[0]
    if c != s:cur_menu_char
      exe 'an 50.' . s:cur_menu_nr . '.' . s:cur_menu_item . ' &Syntax.' . menu_name . ".-" . c . '- <nul>'
      let s:cur_menu_item = s:cur_menu_item + 10
      let s:cur_menu_char = c
    endif
  endif
  call append(s:lnum, 'an 50.' . s:cur_menu_nr . '.' . s:cur_menu_item . ' &Syntax.' . menu_name . "." . submenu_name . ' :cal SetSyn("' . syntax_name . '")<CR>')
  let s:cur_menu_item = s:cur_menu_item + 10
  let s:lnum = s:lnum + 1
endfun

SynMenu AB.A2ps\ config:a2ps
SynMenu AB.Aap:aap
SynMenu AB.ABAP/4:abap
SynMenu AB.Abaqus:abaqus
SynMenu AB.ABC\ music\ notation:abc
SynMenu AB.ABEL:abel
SynMenu AB.ABNF:abnf
SynMenu AB.AceDB\ model:acedb
SynMenu AB.Ada:ada
SynMenu AB.AfLex:aflex
SynMenu AB.Aidl:aidl
SynMenu AB.Algol68:algol68
SynMenu AB.ALSA\ config:alsaconf
SynMenu AB.Altera\ AHDL:ahdl
SynMenu AB.Amiga\ DOS:amiga
SynMenu AB.AMPL:ampl
SynMenu AB.Ant\ build\ file:ant
SynMenu AB.ANTLR:antlr
SynMenu AB.ANTLR4:antlr4
SynMenu AB.Apache\ config:apache
SynMenu AB.Apache-style\ config:apachestyle
SynMenu AB.Apkbuild:apkbuild
SynMenu AB.Applix\ ELF:elf
SynMenu AB.APT\ config:aptconf
SynMenu AB.Arc\ Macro\ Language:aml
SynMenu AB.Arch\ inventory:arch
SynMenu AB.Arduino:arduino
SynMenu AB.ART:art
SynMenu AB.Ascii\ Doc:asciidoc
SynMenu AB.ASP\ with\ VBScript:aspvbs
SynMenu AB.ASP\ with\ Perl:aspperl
SynMenu AB.Assembly.680x0:asm68k
SynMenu AB.Assembly.AVR:avra
SynMenu AB.Assembly.Flat:fasm
SynMenu AB.Assembly.GNU:asm
SynMenu AB.Assembly.GNU\ H-8300:asmh8300
SynMenu AB.Assembly.Intel\ IA-64:ia64
SynMenu AB.Assembly.Microsoft:masm
SynMenu AB.Assembly.Netwide:nasm
SynMenu AB.Assembly.PIC:pic
SynMenu AB.Assembly.Turbo:tasm
SynMenu AB.Assembly.VAX\ Macro\ Assembly:vmasm
SynMenu AB.Assembly.Z-80:z8a
SynMenu AB.Assembly.xa\ 6502\ cross\ assembler:a65
SynMenu AB.ASN\.1:asn
SynMenu AB.Asterisk\ config:asterisk
SynMenu AB.Asterisk\ voicemail\ config:asteriskvm
SynMenu AB.Astro:astro
SynMenu AB.Asy:asy
SynMenu AB.Atlas:atlas
SynMenu AB.Autodoc:autodoc
SynMenu AB.AutoHotKey:autohotkey
SynMenu AB.AutoIt:autoit
SynMenu AB.Automake:automake
SynMenu AB.Autopkgtest:autopkgtest
SynMenu AB.Avenue:ave
SynMenu AB.Awk:awk
SynMenu AB.AYacc:ayacc

SynMenu AB.B:b
SynMenu AB.Baan:baan
SynMenu AB.Bash:bash
SynMenu AB.Basic.FreeBasic:freebasic
SynMenu AB.Basic.IBasic:ibasic
SynMenu AB.Basic.QBasic:basic
SynMenu AB.Basic.Visual\ Basic:vb
SynMenu AB.Bazaar\ commit\ file:bzr
SynMenu AB.Bazel:bzl
SynMenu AB.BC\ calculator:bc
SynMenu AB.BDF\ font:bdf
SynMenu AB.Beancount:beancount
SynMenu AB.BibTeX.Bibliography\ database:bib
SynMenu AB.BibTeX.Bibliography\ Style:bst
SynMenu AB.BIND.BIND\ config:named
SynMenu AB.BIND.BIND\ zone:bindzone
SynMenu AB.Bitbake:bitbake
SynMenu AB.Blank:blank
SynMenu AB.Bpftrace:bpftrace
SynMenu AB.Bsdl:bsdl

SynMenu C.C:c
SynMenu C.C++:cpp
SynMenu C.C#:cs
SynMenu C.Cabal\ Haskell\ build\ file:cabal
SynMenu C.Cabal\ Config:cabalconfig
SynMenu C.Cabal\ Project:cabalproject
SynMenu C.Calendar:calendar
SynMenu C.Cangjie:cangjie
SynMenu C.Cascading\ Style\ Sheets:css
SynMenu C.CDL:cdl
SynMenu C.Cdrdao\ TOC:cdrtoc
SynMenu C.Cdrdao\ config:cdrdaoconf
SynMenu C.Century\ Term:cterm
SynMenu C.Cgdbrc:cgdbrc
SynMenu C.CH\ script:ch
SynMenu C.Chatito:chatito
SynMenu C.ChaiScript:chaiscript
SynMenu C.ChangeLog:changelog
SynMenu C.CHILL:chill
SynMenu C.Cheetah\ template:cheetah
SynMenu C.Chicken:chicken
SynMenu C.ChordPro:chordpro
SynMenu C.Chuck:chuck
SynMenu C.Clean:clean
SynMenu C.Clever:cl
SynMenu C.Clipper:clipper
SynMenu C.Clojure:clojure
SynMenu C.Cmacro:cmacro
SynMenu C.Cmake:cmake
SynMenu C.Cmake\ Cache\ file:cmakecache
SynMenu C.Cmod:cmod
SynMenu C.Cmusrc:cmusrc
SynMenu C.Cobol:cobol
SynMenu C.Coco/R:coco
SynMenu C.Codeowners:codeowners
SynMenu C.Cold\ Fusion:cf
SynMenu C.Conary\ Recipe:conaryrecipe
SynMenu C.Config.Cfg\ Config\ file:cfg
SynMenu C.Config.Configure\.in:config
SynMenu C.Config.Generic\ Config\ file:conf
SynMenu C.Confini:confini
SynMenu C.CRM114:crm
SynMenu C.Crontab:crontab
SynMenu C.CSDL:csdl
SynMenu C.CSP:csp
SynMenu C.CSV.CSV:csv
SynMenu C.CSV.TSV:tsv
SynMenu C.Ctrl-H:ctrlh
SynMenu C.Cucumber:cucumber
SynMenu C.CUDA:cuda
SynMenu C.CUPL.CUPL:cupl
SynMenu C.CUPL.Simulation:cuplsim
SynMenu C.CVS.commit\ file:cvs
SynMenu C.CVS.cvsrc:cvsrc
SynMenu C.Cyn++:cynpp
SynMenu C.Cynlib:cynlib

SynMenu DE.D:d
SynMenu DE.Dart:dart
SynMenu DE.Datascript:datascript
SynMenu DE.Dax:dax
SynMenu DE.Debian.Debian\ 822sources:deb822sources
SynMenu DE.Debian.Debian\ ChangeLog:debchangelog
SynMenu DE.Debian.Debian\ Control:debcontrol
SynMenu DE.Debian.Debian\ Copyright:debcopyright
SynMenu DE.Debian.Debian\ Sources\.list:debsources
SynMenu DE.Denyhosts:denyhosts
SynMenu DE.Dep3patch:dep3patch
SynMenu DE.Desktop:desktop
SynMenu DE.Dict\ config:dictconf
SynMenu DE.Dictd\ config:dictdconf
SynMenu DE.Diff:diff
SynMenu DE.Digital\ Command\ Lang:dcl
SynMenu DE.Dircolors:dircolors
SynMenu DE.Dirpager:dirpager
SynMenu DE.Django\ template:django
SynMenu DE.DNS/BIND\ zone:bindzone
SynMenu DE.Dns:dns
SynMenu DE.Dnsmasq\ config:dnsmasq
SynMenu DE.DocBook.auto-detect:docbk
SynMenu DE.DocBook.SGML:docbksgml
SynMenu DE.DocBook.XML:docbkxml
SynMenu DE.Dockerfile:dockerfile
SynMenu DE.Dot:dot
SynMenu DE.Doxygen.C\ with\ doxygen:c.doxygen
SynMenu DE.Doxygen.C++\ with\ doxygen:cpp.doxygen
SynMenu DE.Doxygen.IDL\ with\ doxygen:idl.doxygen
SynMenu DE.Doxygen.Java\ with\ doxygen:java.doxygen
SynMenu DE.Doxygen.DataScript\ with\ doxygen:datascript.doxygen
SynMenu DE.Dracula:dracula
SynMenu DE.DSSSL:dsl
SynMenu DE.DTD:dtd
SynMenu DE.DTML\ (Zope):dtml
SynMenu DE.DTrace:dtrace
SynMenu DE.Dts/dtsi:dts
SynMenu DE.Dune:dune
SynMenu DE.Dylan.Dylan:dylan
SynMenu DE.Dylan.Dylan\ interface:dylanintr
SynMenu DE.Dylan.Dylan\ lid:dylanlid

SynMenu DE.EDIF:edif
SynMenu DE.Ed:ed
SynMenu DE.Editorconfig:editorconfig
SynMenu DE.Eiffel:eiffel
SynMenu DE.Eight:8th
SynMenu DE.Elinks\ config:elinks
SynMenu DE.Elm:elm
SynMenu DE.Elm\ filter\ rules:elmfilt
SynMenu DE.Embedix\ Component\ Description:ecd
SynMenu DE.ENV:env
SynMenu DE.ERicsson\ LANGuage:erlang
SynMenu DE.ESMTP\ rc:esmtprc
SynMenu DE.ESQL-C:esqlc
SynMenu DE.Essbase\ script:csc
SynMenu DE.Esterel:esterel
SynMenu DE.Eterm\ config:eterm
SynMenu DE.Euphoria\ 3:euphoria3
SynMenu DE.Euphoria\ 4:euphoria4
SynMenu DE.Eviews:eviews
SynMenu DE.Exim\ conf:exim
SynMenu DE.Expect:expect
SynMenu DE.Exports:exports

SynMenu FG.Falcon:falcon
SynMenu FG.Fantom:fan
SynMenu FG.Fetchmail:fetchmail
SynMenu FG.Fish:fish
SynMenu FG.FlexWiki:flexwiki
SynMenu FG.Focus\ Executable:focexec
SynMenu FG.Focus\ Master:master
SynMenu FG.FORM:form
SynMenu FG.Forth:forth
SynMenu FG.Fortran:fortran
SynMenu FG.FoxPro:foxpro
SynMenu FG.Fpcmake:fpcmake
SynMenu FG.FrameScript:framescript
SynMenu FG.Fstab:fstab
SynMenu FG.Fvwm.Fvwm\ configuration:fvwm1
SynMenu FG.Fvwm.Fvwm2\ configuration:fvwm2
SynMenu FG.Fvwm.Fvwm2\ configuration\ with\ M4:fvwm2m4

SynMenu FG.GDB\ command\ file:gdb
SynMenu FG.GDMO:gdmo
SynMenu FG.Gdresource:gdresource
SynMenu FG.Gdscript:gdscript
SynMenu FG.Gdshader:gdshader
SynMenu FG.Gedcom:gedcom
SynMenu FG.Gel:gel
SynMenu FG.Gemtext:gemtext
SynMenu FG.Gift:gift
SynMenu FG.Git.Output:git
SynMenu FG.Git.Attributes:gitattributes
SynMenu FG.Git.Commit:gitcommit
SynMenu FG.Git.Config:gitconfig
SynMenu FG.Git.Ignore:gitignore
SynMenu FG.Git.Rebase:gitrebase
SynMenu FG.Git.Revlist:gitrevlist
SynMenu FG.Git.Send\ Email:gitsendemail
SynMenu FG.Gitolite:gitolite
SynMenu FG.Gkrellmrc:gkrellmrc
SynMenu FG.Gleam:gleam
SynMenu FG.Glimmer:glimmer
SynMenu FG.Glsl:glsl
SynMenu FG.Gnash:gnash
SynMenu FG.Go.Access:goaccess
SynMenu FG.Go.Doc:godoc
SynMenu FG.Go.Go:go
SynMenu FG.GP:gp
SynMenu FG.GPG:gpg
SynMenu FG.Graphql:graphql
SynMenu FG.Grof:gprof
SynMenu FG.Group\ file:group
SynMenu FG.Grub:grub
SynMenu FG.GNU\ Server\ Pages:gsp
SynMenu FG.GNUplot:gnuplot
SynMenu FG.GrADS\ scripts:grads
SynMenu FG.Gretl:gretl
SynMenu FG.Groff:groff
SynMenu FG.Groovy:groovy
SynMenu FG.GTKrc:gtkrc
SynMenu FG.Gvpr:gvpr
SynMenu FG.Gyp:gyp

SynMenu HIJK.Haml:haml
SynMenu HIJK.Hamster:hamster
SynMenu HIJK.Handlebars:handlebars
SynMenu HIJK.Hare.Hare:hare
SynMenu HIJK.Hare.Doc:haredoc
SynMenu HIJK.Haskell.Haskell:haskell
SynMenu HIJK.Haskell.Haskell-c2hs:chaskell
SynMenu HIJK.Haskell.Haskell-literate:lhaskell
SynMenu HIJK.HASTE:haste
SynMenu HIJK.HASTE\ preproc:hastepreproc
SynMenu HIJK.HCL:hcl
SynMenu HIJK.Hercules:hercules
SynMenu HIJK.Hex\ dump.XXD:xxd
SynMenu HIJK.Hex\ dump.Intel\ MCS51:hex
SynMenu HIJK.Hg\ commit:hgcommit
SynMenu HIJK.HIP:hip
SynMenu HIJK.HLSPlaylist:hlsplaylist
SynMenu HIJK.Hollywood:hollywood
SynMenu HIJK.HTML.HTML:html
SynMenu HIJK.HTML.HTMLAngular:htmlangular
SynMenu HIJK.HTML.HTML\ with\ M4:htmlm4
SynMenu HIJK.HTML.HTML\ with\ Ruby\ (eRuby):eruby
SynMenu HIJK.HTML.Cheetah\ HTML\ template:htmlcheetah
SynMenu HIJK.HTML.Django\ HTML\ template:htmldjango
SynMenu HIJK.HTML.Vue.js\ HTML\ template:vuejs
SynMenu HIJK.HTML.HTML/OS:htmlos
SynMenu HIJK.HTML.XHTML:xhtml
SynMenu HIJK.Host\.conf:hostconf
SynMenu HIJK.Hosts\ access:hostsaccess
SynMenu HIJK.Hyper\ Builder:hb
SynMenu HIJK.Hyprlang:hyprlang
SynMenu HIJK.I3Config:i3config
SynMenu HIJK.Icewm\ menu:icemenu
SynMenu HIJK.Icon:icon
SynMenu HIJK.IDL\Generic\ IDL:idl
SynMenu HIJK.IDL\Microsoft\ IDL:msidl
SynMenu HIJK.Idris2:idris2
SynMenu HIJK.Indent\ profile:indent
SynMenu HIJK.Inform:inform
SynMenu HIJK.Informix\ 4GL:fgl
SynMenu HIJK.Initng:initng
SynMenu HIJK.Inittab:inittab
SynMenu HIJK.Inno\ setup:iss
SynMenu HIJK.Innovation\ Data\ Processing.Upstream\ dat:upstreamdat
SynMenu HIJK.Innovation\ Data\ Processing.Upstream\ log:upstreamlog
SynMenu HIJK.Innovation\ Data\ Processing.Upstream\ rpt:upstreamrpt
SynMenu HIJK.Innovation\ Data\ Processing.Upstream\ Install\ log:upstreaminstalllog
SynMenu HIJK.Innovation\ Data\ Processing.Usserver\ log:usserverlog
SynMenu HIJK.Innovation\ Data\ Processing.USW2KAgt\ log:usw2kagtlog
SynMenu HIJK.InstallShield\ script:ishd
SynMenu HIJK.Interactive\ Data\ Lang:idlang
SynMenu HIJK.Ipkg:ipkg
SynMenu HIJK.IPfilter:ipfilter
SynMenu HIJK.J:j
SynMenu HIJK.JAL:jal
SynMenu HIJK.JAM:jam
SynMenu HIJK.Jargon:jargon
SynMenu HIJK.Java.Java:java
SynMenu HIJK.Java.JavaCC:javacc
SynMenu HIJK.Java.Java\ Server\ Pages:jsp
SynMenu HIJK.Java.Java\ Properties:jproperties
SynMenu HIJK.JavaScript:javascript
SynMenu HIJK.JavaScriptReact:javascriptreact
SynMenu HIJK.Jess:jess
SynMenu HIJK.Jgraph:jgraph
SynMenu HIJK.Jinja:jinja
SynMenu HIJK.JJdescription:jjdescription
SynMenu HIJK.Jovial:jovial
SynMenu HIJK.JQ:jq
SynMenu HIJK.JSON.JSON:json
SynMenu HIJK.JSON.JSON5:json5
SynMenu HIJK.JSON.JSONC:jsonc
SynMenu HIJK.Julia:julia
SynMenu HIJK.Just:just
SynMenu HIJK.Karel:karel
SynMenu HIJK.Kconfig:kconfig
SynMenu HIJK.KDE\ script:kscript
SynMenu HIJK.Kdl:kdl
SynMenu HIJK.Kimwitu++:kwt
SynMenu HIJK.Kitty:kitty
SynMenu HIJK.Kivy:kivy
SynMenu HIJK.KixTart:kix
SynMenu HIJK.Kotlin:kotlin
SynMenu HIJK.Krl:krl

SynMenu L.Lace:lace
SynMenu L.LambdaProlog:lprolog
SynMenu L.Latte:latte
SynMenu L.LC:lc
SynMenu L.Ld\ script:ld
SynMenu L.LDAP.LDIF:ldif
SynMenu L.LDAP.Configuration:ldapconf
SynMenu L.Leex:leex
SynMenu L.Less:less
SynMenu L.Lex:lex
SynMenu L.Lf:lf
SynMenu L.LFTP\ config:lftp
SynMenu L.Libao:libao
SynMenu L.Lidris2:lidris2
SynMenu L.LifeLines\ script:lifelines
SynMenu L.Lilo:lilo
SynMenu L.Limits\ config:limits
SynMenu L.Linden\ scripting:lsl
SynMenu L.Liquid:liquid
SynMenu L.Lisp:lisp
SynMenu L.Lite:lite
SynMenu L.LiteStep\ RC:litestep
SynMenu L.Livebook:livebook
SynMenu L.LNK:lnk
SynMenu L.LNKMAP:lnkmap
SynMenu L.Locale\ Input:fdcc
SynMenu L.Log:log
SynMenu L.Login\.access:loginaccess
SynMenu L.Login\.defs:logindefs
SynMenu L.Logtalk:logtalk
SynMenu L.LOTOS:lotos
SynMenu L.LotusScript:lscript
SynMenu L.Lout:lout
SynMenu L.LPC:lpc
SynMenu L.Lua:lua
SynMenu L.Luau:luau
SynMenu L.Lyrics:lyrics
SynMenu L.Lynx\ Style:lss
SynMenu L.Lynx\ config:lynx

SynMenu M.M17ndb:m17ndb
SynMenu M.M3build:m3build
SynMenu M.M3quake:m3quake
SynMenu M.M4:m4
SynMenu M.MaGic\ Point:mgp
SynMenu M.Mail:mail
SynMenu M.Mail\ aliases:mailaliases
SynMenu M.Mailcap:mailcap
SynMenu M.Mallard:mallard
SynMenu M.Makefile:make
SynMenu M.MakeIndex:ist
SynMenu M.Man\ page:man
SynMenu M.Man\.conf:manconf
SynMenu M.Maple\ V:maple
SynMenu M.Markdown:markdown
SynMenu M.Markdown\ with\ R\ statements:rmd
SynMenu M.Marko:marko
SynMenu M.Mason:mason
SynMenu M.Mathematica:mma
SynMenu M.Matlab:matlab
SynMenu M.Maxima:maxima
SynMenu M.Mbsync:mbsync
SynMenu M.Mediawiki:mediawiki
SynMenu M.MEL\ (for\ Maya):mel
SynMenu M.Mermaid:mermaid
SynMenu M.Meson:meson
SynMenu M.Messages\ (/var/log):messages
SynMenu M.Metafont:mf
SynMenu M.MetaPost:mp
SynMenu M.MGL:mgl
SynMenu M.MIX:mix
SynMenu M.MMIX:mmix
SynMenu M.Modconf:modconf
SynMenu M.Model:model
SynMenu M.Modsim\ III:modsim3
SynMenu M.Modula-2.R10\ (2010):modula2:r10
SynMenu M.Modula-2.ISO\ (1994):modula2:iso
SynMenu M.Modula-2.PIM\ (1985):modula2:pim
SynMenu M.Modula-3:modula3
SynMenu M.Mojo:mojo
SynMenu M.Monk:monk
SynMenu M.Motorola\ S-Record:srec
SynMenu M.Mplayer\ config:mplayerconf
SynMenu M.MOO:moo
SynMenu M.Mrxvtrc:mrxvtrc
SynMenu M.MS-DOS/Windows.4DOS\ \.bat\ file:btm
SynMenu M.MS-DOS/Windows.\.bat\/\.cmd\ file:dosbatch
SynMenu M.MS-DOS/Windows.\.ini\ file:dosini
SynMenu M.MS-DOS/Windows.Message\ text:msmessages
SynMenu M.MS-DOS/Windows.Module\ Definition:def
SynMenu M.MS-DOS/Windows.Registry:registry
SynMenu M.MS-DOS/Windows.Resource\ file:rc
SynMenu M.Msql:msql
SynMenu M.Mss:mss
SynMenu M.MuPAD:mupad
SynMenu M.Murphi:murphi
SynMenu M.MUSHcode:mush
SynMenu M.Muttrc:muttrc

SynMenu NO.N1QL:n1ql
SynMenu NO.Nanorc:nanorc
SynMenu NO.Nastran\ input/DMAP:nastran
SynMenu NO.Natural:natural
SynMenu NO.NeoMutt.logfile:neomuttlog
SynMenu NO.NeoMutt.neomuttrc:neomuttrc
SynMenu NO.Netrc:netrc
SynMenu NO.Nginx:nginx
SynMenu NO.Ninja:ninja
SynMenu NO.Nix:nix
SynMenu NO.Novell\ NCF\ batch:ncf
SynMenu NO.Not\ Quite\ C\ (LEGO):nqc
SynMenu NO.Nroff:nroff
SynMenu NO.NSIS\ script:nsis
SynMenu NO.Nu:nu
SynMenu NO.Obj\ 3D\ wavefront:obj
SynMenu NO.Objective\ C:objc
SynMenu NO.Objective\ C++:objcpp
SynMenu NO.Obse:obse
SynMenu NO.OCAML:ocaml
SynMenu NO.Occam:occam
SynMenu NO.Odin:odin
SynMenu NO.Omnimark:omnimark
SynMenu NO.Ondir:ondir
SynMenu NO.Opam:opam
SynMenu NO.Opencl:opencl
SynMenu NO.OpenROAD:openroad
SynMenu NO.OpenSCAD:openscad
SynMenu NO.OpenVPN:openvpn
SynMenu NO.Open\ Psion\ Lang:opl
SynMenu NO.Oracle\ config:ora
SynMenu NO.Org:org

SynMenu PQ.Packet\ filter\ conf:pf
SynMenu PQ.Pacmanlog:pacmanlog
SynMenu PQ.Palm\ resource\ compiler:pilrc
SynMenu PQ.Pam\ config:pamconf
SynMenu PQ.Pam\ environment\ config\ file:pamenv
SynMenu PQ.Pandoc:pandoc
SynMenu PQ.PApp:papp
SynMenu PQ.Pascal:pascal
SynMenu PQ.Password\ file:passwd
SynMenu PQ.Pbtxt:pbtxt
SynMenu PQ.PCCTS:pccts
SynMenu PQ.PDF:pdf
SynMenu PQ.Perl.Perl:perl
SynMenu PQ.Perl.Perl\ 6:perl6
SynMenu PQ.Perl.Perl\ POD:pod
SynMenu PQ.Perl.Perl\ XS:xs
SynMenu PQ.Perl.Template\ toolkit:tt2
SynMenu PQ.Perl.Template\ toolkit\ Html:tt2html
SynMenu PQ.Perl.Template\ toolkit\ JS:tt2js
SynMenu PQ.PHP.PHP\ 3-4:php
SynMenu PQ.PHP.Phtml\ (PHP\ 2):phtml
SynMenu PQ.Pike:pike
SynMenu PQ.Pine\ RC:pine
SynMenu PQ.Pinfo\ RC:pinfo
SynMenu PQ.Pkl:pkl
SynMenu PQ.PL/M:plm
SynMenu PQ.PL/SQL:plsql
SynMenu PQ.Pli:pli
SynMenu PQ.PLP:plp
SynMenu PQ.PO\ (GNU\ gettext):po
SynMenu PQ.Poefilter:poefilter
SynMenu PQ.Poke:poke
SynMenu PQ.Postfix\ main\ config:pfmain
SynMenu PQ.PostScript.PostScript:postscr
SynMenu PQ.PostScript.PostScript\ Printer\ Description:ppd
SynMenu PQ.Povray.Povray\ scene\ descr:pov
SynMenu PQ.Povray.Povray\ configuration:povini
SynMenu PQ.Power\ Query\ M:pq
SynMenu PQ.PowerShell.PowerShell:ps1
SynMenu PQ.PowerShell.XML:ps1xml
SynMenu PQ.PPWizard:ppwiz
SynMenu PQ.Prescribe\ (Kyocera):prescribe
SynMenu PQ.Printcap:pcap
SynMenu PQ.Privoxy:privoxy
SynMenu PQ.Procmail:procmail
SynMenu PQ.Product\ Spec\ File:psf
SynMenu PQ.Progress:progress
SynMenu PQ.Prolog:prolog
SynMenu PQ.ProMeLa:promela
SynMenu PQ.Property\ Specification\ Language:psl
SynMenu PQ.Proto:proto
SynMenu PQ.Protocols:protocols
SynMenu PQ.Prql:prql
SynMenu PQ.Ptx:ptx
SynMenu PQ.Purify\ log:purifylog
SynMenu PQ.Pyrex:pyrex
SynMenu PQ.Python:python
SynMenu PQ.Python2:python2
SynMenu PQ.Python\ Manifest:pymanifest
SynMenu PQ.Qb64:qb64
SynMenu PQ.QML:qml
SynMenu PQ.Quake:quake
SynMenu PQ.Quarto:quarto
SynMenu PQ.Quickfix\ window:qf

SynMenu R.R.R:r
SynMenu R.R.R\ help:rhelp
SynMenu R.R.R\ noweb:rnoweb
SynMenu R.Racc\ input:racc
SynMenu R.Racket:racket
SynMenu R.Radiance:radiance
SynMenu R.Raml:raml
SynMenu R.Rapid:rapid
SynMenu R.Rasi:rasi
SynMenu R.Ratpoison:ratpoison
SynMenu R.RCS.RCS\ log\ output:rcslog
SynMenu R.RCS.RCS\ file:rcs
SynMenu R.Readline\ config:readline
SynMenu R.Rebol:rebol
SynMenu R.ReDIF:redif
SynMenu R.Rego:rego
SynMenu R.Relax\ NG:rng
SynMenu R.Remind:remind
SynMenu R.Relax\ NG\ compact:rnc
SynMenu R.Renderman.Renderman\ Shader\ Lang:sl
SynMenu R.Renderman.Renderman\ Interface\ Bytestream:rib
SynMenu R.Requirements:requirements
SynMenu R.Resolv\.conf:resolv
SynMenu R.Reva\ Forth:reva
SynMenu R.Rexx:rexx
SynMenu R.Robots\.txt:robots
SynMenu R.RockLinux\ package\ desc\.:desc
SynMenu R.Rpcgen:rpcgen
SynMenu R.RPL/2:rpl
SynMenu R.ReStructuredText:rst
SynMenu R.ReStructuredText\ with\ R\ statements:rrst
SynMenu R.Routeros:routeros
SynMenu R.RTF:rtf
SynMenu R.Ruby:ruby
SynMenu R.Rust:rust

SynMenu S-Sm.S-Lang:slang
SynMenu S-Sm.Samba\ config:samba
SynMenu S-Sm.SAS:sas
SynMenu S-Sm.Salt:salt
SynMenu S-Sm.Sass:sass
SynMenu S-Sm.Sather:sather
SynMenu S-Sm.Sbt:sbt
SynMenu S-Sm.Scala:scala
SynMenu S-Sm.Scdoc:scdoc
SynMenu S-Sm.Scheme:scheme
SynMenu S-Sm.Scilab:scilab
SynMenu S-Sm.Screen\ RC:screen
SynMenu S-Sm.SCSS:scss
SynMenu S-Sm.SDC\ Synopsys\ Design\ Constraints:sdc
SynMenu S-Sm.SDL:sdl
SynMenu S-Sm.Sed:sed
SynMenu S-Sm.Sendmail\.cf:sm
SynMenu S-Sm.Send-pr:sendpr
SynMenu S-Sm.Sensors\.conf:sensors
SynMenu S-Sm.Service\ Location\ config:slpconf
SynMenu S-Sm.Service\ Location\ registration:slpreg
SynMenu S-Sm.Service\ Location\ SPI:slpspi
SynMenu S-Sm.Services:services
SynMenu S-Sm.Setserial\ config:setserial
SynMenu S-Sm.Sexplib:sexplib
SynMenu S-Sm.SGF:sgf
SynMenu S-Sm.SGML.SGML\ catalog:catalog
SynMenu S-Sm.SGML.SGML\ DTD:sgml
SynMenu S-Sm.SGML.SGML\ Declaration:sgmldecl
SynMenu S-Sm.SGML.SGML-linuxdoc:sgmllnx
SynMenu S-Sm.Shaderslang:shaderslang
SynMenu S-Sm.Shell\ script.sh\ and\ ksh:sh
SynMenu S-Sm.Shell\ script.csh:csh
SynMenu S-Sm.Shell\ script.tcsh:tcsh
SynMenu S-Sm.Shell\ script.zsh:zsh
SynMenu S-Sm.SiCAD:sicad
SynMenu S-Sm.Sieve:sieve
SynMenu S-Sm.Sil:sil
SynMenu S-Sm.Simula:simula
SynMenu S-Sm.Sinda.Sinda\ compare:sindacmp
SynMenu S-Sm.Sinda.Sinda\ input:sinda
SynMenu S-Sm.Sinda.Sinda\ output:sindaout
SynMenu S-Sm.SiSU:sisu
SynMenu S-Sm.Skhd:skhd
SynMenu S-Sm.SKILL.SKILL:skill
SynMenu S-Sm.SKILL.SKILL\ for\ Diva:diva
SynMenu S-Sm.Slice:slice
SynMenu S-Sm.SLRN.Slrn\ rc:slrnrc
SynMenu S-Sm.SLRN.Slrn\ score:slrnsc
SynMenu S-Sm.SmallTalk:st
SynMenu S-Sm.Smarty\ Templates:smarty
SynMenu S-Sm.SMIL:smil
SynMenu S-Sm.SMITH:smith

SynMenu Sn-Sy.SNMP\ MIB:mib
SynMenu Sn-Sy.SNNS.SNNS\ network:snnsnet
SynMenu Sn-Sy.SNNS.SNNS\ pattern:snnspat
SynMenu Sn-Sy.SNNS.SNNS\ result:snnsres
SynMenu Sn-Sy.Snobol4:snobol4
SynMenu Sn-Sy.Snort\ Configuration:hog
SynMenu Sn-Sy.Solidity:solidity
SynMenu Sn-Sy.Spajson:spajson
SynMenu Sn-Sy.SPEC\ (Linux\ RPM):spec
SynMenu Sn-Sy.Specman:specman
SynMenu Sn-Sy.Spice:spice
SynMenu Sn-Sy.Spyce:spyce
SynMenu Sn-Sy.Speedup:spup
SynMenu Sn-Sy.Splint:splint
SynMenu Sn-Sy.Squid\ config:squid
SynMenu Sn-Sy.Squirrel:squirrel
SynMenu Sn-Sy.SQL.SAP\ HANA:sqlhana
SynMenu Sn-Sy.SQL.ESQL-C:esqlc
SynMenu Sn-Sy.SQL.MySQL:mysql
SynMenu Sn-Sy.SQL.PL/SQL:plsql
SynMenu Sn-Sy.SQL.SQL\ Anywhere:sqlanywhere
SynMenu Sn-Sy.SQL.SQL\ (automatic):sql
SynMenu Sn-Sy.SQL.SQL\ (Oracle):sqloracle
SynMenu Sn-Sy.SQL.SQL\ Forms:sqlforms
SynMenu Sn-Sy.SQL.SQLJ:sqlj
SynMenu Sn-Sy.SQL.SQL-Informix:sqlinformix
SynMenu Sn-Sy.SQR:sqr
SynMenu Sn-Sy.Srt:srt
SynMenu Sn-Sy.Ssa:ssa
SynMenu Sn-Sy.Ssh.ssh_allowedsigners:sshallowedsigners
SynMenu Sn-Sy.Ssh.ssh_authorizedkeys:sshauthorizedkeys
SynMenu Sn-Sy.Ssh.ssh_config:sshconfig
SynMenu Sn-Sy.Ssh.sshd_config:sshdconfig
SynMenu Sn-Sy.Ssh.ssh_knownhosts:sshknownhosts
SynMenu Sn-Sy.Ssh.ssh_publickey:sshpublickey
SynMenu Sn-Sy.Standard\ ML:sml
SynMenu Sn-Sy.Stata.SMCL:smcl
SynMenu Sn-Sy.Stata.Stata:stata
SynMenu Sn-Sy.Stored\ Procedures:stp
SynMenu Sn-Sy.Strace:strace
SynMenu Sn-Sy.Streaming\ descriptor\ file:sd
SynMenu Sn-Sy.Structurizr:structurizr
SynMenu Sn-Sy.Stylus:stylus
SynMenu Sn-Sy.Subversion\ commit:svn
SynMenu Sn-Sy.Sudoers:sudoers
SynMenu Sn-Sy.SVG:svg
SynMenu Sn-Sy.Swayconfig:swayconfig
SynMenu Sn-Sy.Swift.Swift:swift
SynMenu Sn-Sy.Swift.GYB:swiftgyb
SynMenu Sn-Sy.Swig:swig
SynMenu Sn-Sy.Symbian\ meta-makefile:mmp
SynMenu Sn-Sy.Sysctl\.conf:sysctl
SynMenu Sn-Sy.Systemd:systemd
SynMenu Sn-Sy.SystemVerilog:systemverilog

SynMenu T.TADS:tads
SynMenu T.Tags:tags
SynMenu T.TAK.TAK\ compare:takcmp
SynMenu T.TAK.TAK\ input:tak
SynMenu T.TAK.TAK\ output:takout
SynMenu T.Tar\ listing:tar
SynMenu T.Task\ data:taskdata
SynMenu T.Task\ 42\ edit:taskedit
SynMenu T.Tcl/Tk:tcl
SynMenu T.TealInfo:tli
SynMenu T.Telix\ Salt:tsalt
SynMenu T.Termcap/Printcap:ptcap
SynMenu T.Terminfo:terminfo
SynMenu T.Tera:tera
SynMenu T.Tera\ Term:teraterm
SynMenu T.Terraform:terraform
SynMenu T.TeX.TeX/LaTeX:tex
SynMenu T.TeX.plain\ TeX:plaintex
SynMenu T.TeX.Initex:initex
SynMenu T.TeX.ConTeXt:context
SynMenu T.TeX.TeX\ configuration:texmf
SynMenu T.TeX.Texinfo:texinfo
SynMenu T.TF\ mud\ client:tf
SynMenu T.Thrift:thrift
SynMenu T.Tiasm:tiasm
SynMenu T.Tidy\ configuration:tidy
SynMenu T.Tilde:tilde
SynMenu T.Tmux\ configuration:tmux
SynMenu T.Tolk:tolk
SynMenu T.TOML:toml
SynMenu T.TPP:tpp
SynMenu T.Trasys\ input:trasys
SynMenu T.Treetop:treetop
SynMenu T.Trustees:trustees
SynMenu T.TSS.Command\ Line:tsscl
SynMenu T.TSS.Geometry:tssgm
SynMenu T.TSS.Optics:tssop
SynMenu T.Typescript:typescript
SynMenu T.TypescriptReact:typescriptreact
SynMenu T.Typst:typst

SynMenu UV.Uci:uci
SynMenu UV.Udev\ config:udevconf
SynMenu UV.Udev\ permissions:udevperm
SynMenu UV.Udev\ rules:udevrules
SynMenu UV.UIT/UIL:uil
SynMenu UV.Unison:unison
SynMenu UV.UnrealScript:uc
SynMenu UV.Updatedb\.conf:updatedb
SynMenu UV.Upstart:upstart
SynMenu UV.URLShortcut:urlshortcut
SynMenu UV.Valgrind:valgrind
SynMenu UV.VDF:vdf
SynMenu UV.Vera:vera
SynMenu UV.Verbose\ TAP\ Output:tap
SynMenu UV.Verilog-AMS\ HDL:verilogams
SynMenu UV.Verilog\ HDL:verilog
SynMenu UV.Vgrindefs:vgrindefs
SynMenu UV.VHDL:vhdl
SynMenu UV.Vim.Vim\ help\ file:help
SynMenu UV.Vim.Vim\ script:vim
SynMenu UV.Vim.Vim\ tutor:tutor
SynMenu UV.Vim.Viminfo\ file:viminfo
SynMenu UV.Virata\ config:virata
SynMenu UV.Visual\ Basic:vb
SynMenu UV.VOS\ CM\ macro:voscm
SynMenu UV.VRML:vrml
SynMenu UV.Vroom:vroom
SynMenu UV.VSE\ JCL:vsejcl

SynMenu WXYZ.WDL:wdl
SynMenu WXYZ.WEB.CWEB:cweb
SynMenu WXYZ.WEB.WEB:web
SynMenu WXYZ.WEB.WEB\ Changes:change
SynMenu WXYZ.WebAssembly:wat
SynMenu WXYZ.Webmacro:webmacro
SynMenu WXYZ.Website\ MetaLanguage:wml
SynMenu WXYZ.wDiff:wdiff
SynMenu WXYZ.Wget\ config:wget
SynMenu WXYZ.Wget2:wget2
SynMenu WXYZ.Whitespace\ (add):whitespace
SynMenu WXYZ.Wks:wks
SynMenu WXYZ.WildPackets\ EtherPeek\ Decoder:dcd
SynMenu WXYZ.WinBatch/Webbatch:winbatch
SynMenu WXYZ.Windows\ Scripting\ Host:wsh
SynMenu WXYZ.WSML:wsml
SynMenu WXYZ.WvDial:wvdial
SynMenu WXYZ.X.Compose:xcompose
SynMenu WXYZ.X.Keyboard\ Extension:xkb
SynMenu WXYZ.X.Pixmap:xpm
SynMenu WXYZ.X.Pixmap\ (2):xpm2
SynMenu WXYZ.X.resources:xdefaults
SynMenu WXYZ.XBL:xbl
SynMenu WXYZ.Xinetd\.conf:xinetd
SynMenu WXYZ.Xmodmap:xmodmap
SynMenu WXYZ.Xmath:xmath
SynMenu WXYZ.XML:xml
SynMenu WXYZ.XML\ Schema\ (XSD):xsd
SynMenu WXYZ.XQuery:xquery
SynMenu WXYZ.Xslt:xslt
SynMenu WXYZ.XFree86\ Config:xf86conf
SynMenu WXYZ.YAML:yaml
SynMenu WXYZ.Yacc:yacc
SynMenu WXYZ.Zathurarc:zathurarc
SynMenu WXYZ.ZIG:zig
SynMenu WXYZ.Zimbu:zimbu
SynMenu WXYZ.Zir:zir
SynMenu WXYZ.Zserio:zserio

call append(s:lnum, "")

wq
