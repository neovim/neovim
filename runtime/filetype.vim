" Vim support file to detect file types
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2022 Apr 07

" Listen very carefully, I will say this only once
if exists("did_load_filetypes")
  finish
endif
let did_load_filetypes = 1

" Line continuation is used here, remove 'C' from 'cpoptions'
let s:cpo_save = &cpo
set cpo&vim

augroup filetypedetect

" Ignored extensions
if exists("*fnameescape")
au BufNewFile,BufRead ?\+.orig,?\+.bak,?\+.old,?\+.new,?\+.dpkg-dist,?\+.dpkg-old,?\+.dpkg-new,?\+.dpkg-bak,?\+.rpmsave,?\+.rpmnew,?\+.pacsave,?\+.pacnew
	\ exe "doau filetypedetect BufRead " . fnameescape(expand("<afile>:r"))
au BufNewFile,BufRead *~
	\ let s:name = expand("<afile>") |
	\ let s:short = substitute(s:name, '\~$', '', '') |
	\ if s:name != s:short && s:short != "" |
	\   exe "doau filetypedetect BufRead " . fnameescape(s:short) |
	\ endif |
	\ unlet! s:name s:short
au BufNewFile,BufRead ?\+.in
	\ if expand("<afile>:t") != "configure.in" |
	\   exe "doau filetypedetect BufRead " . fnameescape(expand("<afile>:r")) |
	\ endif
elseif &verbose > 0
  echomsg "Warning: some filetypes will not be recognized because this version of Vim does not have fnameescape()"
endif

" Pattern used to match file names which should not be inspected.
" Currently finds compressed files.
if !exists("g:ft_ignore_pat")
  let g:ft_ignore_pat = '\.\(Z\|gz\|bz2\|zip\|tgz\)$'
endif

" Function used for patterns that end in a star: don't set the filetype if the
" file name matches ft_ignore_pat.
" When using this, the entry should probably be further down below with the
" other StarSetf() calls.
func s:StarSetf(ft)
  if expand("<amatch>") !~ g:ft_ignore_pat
    exe 'setf ' . a:ft
  endif
endfunc

" Vim help file
au BufNewFile,BufRead $VIMRUNTIME/doc/*.txt setf help

" Abaqus or Trasys
au BufNewFile,BufRead *.inp			call dist#ft#Check_inp()

" 8th (Firth-derivative)
au BufNewFile,BufRead *.8th			setf 8th

" A-A-P recipe
au BufNewFile,BufRead *.aap			setf aap

" A2ps printing utility
au BufNewFile,BufRead */etc/a2ps.cfg,*/etc/a2ps/*.cfg,a2psrc,.a2psrc setf a2ps

" ABAB/4
au BufNewFile,BufRead *.abap			setf abap

" ABC music notation
au BufNewFile,BufRead *.abc			setf abc

" ABEL
au BufNewFile,BufRead *.abl			setf abel

" AceDB
au BufNewFile,BufRead *.wrm			setf acedb

" Ada (83, 9X, 95)
au BufNewFile,BufRead *.adb,*.ads,*.ada		setf ada
au BufNewFile,BufRead *.gpr			setf ada

" AHDL
au BufNewFile,BufRead *.tdf			setf ahdl

" AIDL
au BufNewFile,BufRead *.aidl			setf aidl

" AMPL
au BufNewFile,BufRead *.run			setf ampl

" Ant
au BufNewFile,BufRead build.xml			setf ant

" Arduino
au BufNewFile,BufRead *.ino,*.pde		setf arduino

" Apache config file
au BufNewFile,BufRead .htaccess,*/etc/httpd/*.conf		setf apache
au BufNewFile,BufRead */etc/apache2/sites-*/*.com		setf apache

" XA65 MOS6510 cross assembler
au BufNewFile,BufRead *.a65			setf a65

" Applescript
au BufNewFile,BufRead *.scpt			setf applescript

" Applix ELF
au BufNewFile,BufRead *.am
	\ if expand("<afile>") !~? 'Makefile.am\>' | setf elf | endif

" ALSA configuration
au BufNewFile,BufRead .asoundrc,*/usr/share/alsa/alsa.conf,*/etc/asound.conf setf alsaconf

" Arc Macro Language
au BufNewFile,BufRead *.aml			setf aml

" APT config file
au BufNewFile,BufRead apt.conf		       setf aptconf
au BufNewFile,BufRead */.aptitude/config       setf aptconf
" more generic pattern far down

" Arch Inventory file
au BufNewFile,BufRead .arch-inventory,=tagging-method	setf arch

" ART*Enterprise (formerly ART-IM)
au BufNewFile,BufRead *.art			setf art

" AsciiDoc
au BufNewFile,BufRead *.asciidoc,*.adoc		setf asciidoc

" ASN.1
au BufNewFile,BufRead *.asn,*.asn1		setf asn

" Active Server Pages (with Visual Basic Script)
au BufNewFile,BufRead *.asa
	\ if exists("g:filetype_asa") |
	\   exe "setf " . g:filetype_asa |
	\ else |
	\   setf aspvbs |
	\ endif

" Active Server Pages (with Perl or Visual Basic Script)
au BufNewFile,BufRead *.asp
	\ if exists("g:filetype_asp") |
	\   exe "setf " . g:filetype_asp |
	\ elseif getline(1) . getline(2) . getline(3) =~? "perlscript" |
	\   setf aspperl |
	\ else |
	\   setf aspvbs |
	\ endif

" Grub (must be before catch *.lst)
au BufNewFile,BufRead */boot/grub/menu.lst,*/boot/grub/grub.conf,*/etc/grub.conf setf grub

" Assembly (all kinds)
" *.lst is not pure assembly, it has two extra columns (address, byte codes)
au BufNewFile,BufRead *.asm,*.[sS],*.[aA],*.mac,*.lst	call dist#ft#FTasm()

" Macro (VAX)
au BufNewFile,BufRead *.mar			setf vmasm

" Atlas
au BufNewFile,BufRead *.atl,*.as		setf atlas

" Atom is based on XML
au BufNewFile,BufRead *.atom			setf xml

" Autoit v3
au BufNewFile,BufRead *.au3			setf autoit

" Autohotkey
au BufNewFile,BufRead *.ahk			setf autohotkey

" Automake
au BufNewFile,BufRead [mM]akefile.am,GNUmakefile.am	setf automake

" Autotest .at files are actually m4
au BufNewFile,BufRead *.at			setf m4

" Avenue
au BufNewFile,BufRead *.ave			setf ave

" Awk
au BufNewFile,BufRead *.awk,*.gawk		setf awk

" B
au BufNewFile,BufRead *.mch,*.ref,*.imp		setf b

" BASIC or Visual Basic
au BufNewFile,BufRead *.bas			call dist#ft#FTbas()
au BufNewFile,BufRead *.bi,*.bm			call dist#ft#FTbas()

" Visual Basic Script (close to Visual Basic) or Visual Basic .NET
au BufNewFile,BufRead *.vb,*.vbs,*.dsm,*.ctl	setf vb

" IBasic file (similar to QBasic)
au BufNewFile,BufRead *.iba,*.ibi		setf ibasic

" FreeBasic file (similar to QBasic)
au BufNewFile,BufRead *.fb			setf freebasic

" Batch file for MSDOS. See dist#ft#FTsys for *.sys
au BufNewFile,BufRead *.bat			setf dosbatch
" *.cmd is close to a Batch file, but on OS/2 Rexx files also use *.cmd.
au BufNewFile,BufRead *.cmd
	\ if getline(1) =~ '^/\*' | setf rexx | else | setf dosbatch | endif
" ABB RAPID or Batch file for MSDOS.
au BufNewFile,BufRead *.sys\c			call dist#ft#FTsys()

" Batch file for 4DOS
au BufNewFile,BufRead *.btm			call dist#ft#FTbtm()

" BC calculator
au BufNewFile,BufRead *.bc			setf bc

" BDF font
au BufNewFile,BufRead *.bdf			setf bdf

" Beancount
au BufNewFile,BufRead *.beancount		setf beancount

" BibTeX bibliography database file
au BufNewFile,BufRead *.bib			setf bib

" BibTeX Bibliography Style
au BufNewFile,BufRead *.bst			setf bst

" Bicep
au BufNewFile,BufRead *.bicep			setf bicep

" BIND configuration
" sudoedit uses namedXXXX.conf
au BufNewFile,BufRead named*.conf,rndc*.conf,rndc*.key	setf named

" BIND zone
au BufNewFile,BufRead named.root		setf bindzone
au BufNewFile,BufRead *.db			call dist#ft#BindzoneCheck('')

" Blank
au BufNewFile,BufRead *.bl			setf blank

" Blkid cache file
au BufNewFile,BufRead */etc/blkid.tab,*/etc/blkid.tab.old   setf xml

" BSDL
au BufNewFile,BufRead *bsd,*.bsdl		setf bsdl

" Bazel (http://bazel.io)
autocmd BufRead,BufNewFile *.bzl,*.bazel,WORKSPACE	setf bzl
if has("fname_case")
  " There is another check for BUILD further below.
  autocmd BufRead,BufNewFile *.BUILD,BUILD		setf bzl
endif

" C or lpc
au BufNewFile,BufRead *.c			call dist#ft#FTlpc()
au BufNewFile,BufRead *.lpc,*.ulpc		setf lpc

" Calendar
au BufNewFile,BufRead calendar			setf calendar

" C#
au BufNewFile,BufRead *.cs,*.csx		setf cs

" CSDL
au BufNewFile,BufRead *.csdl			setf csdl

" Cabal
au BufNewFile,BufRead *.cabal			setf cabal

" Cdrdao TOC
au BufNewFile,BufRead *.toc			setf cdrtoc

" Cdrdao config
au BufNewFile,BufRead */etc/cdrdao.conf,*/etc/defaults/cdrdao,*/etc/default/cdrdao,.cdrdao	setf cdrdaoconf

" Cfengine
au BufNewFile,BufRead cfengine.conf		setf cfengine

" ChaiScript
au BufRead,BufNewFile *.chai			setf chaiscript

" Comshare Dimension Definition Language
au BufNewFile,BufRead *.cdl			setf cdl

" Conary Recipe
au BufNewFile,BufRead *.recipe			setf conaryrecipe

" Controllable Regex Mutilator
au BufNewFile,BufRead *.crm			setf crm

" Cyn++
au BufNewFile,BufRead *.cyn			setf cynpp

" Cynlib
" .cc and .cpp files can be C++ or Cynlib.
au BufNewFile,BufRead *.cc
	\ if exists("cynlib_syntax_for_cc")|setf cynlib|else|setf cpp|endif
au BufNewFile,BufRead *.cpp
	\ if exists("cynlib_syntax_for_cpp")|setf cynlib|else|setf cpp|endif

" C++
au BufNewFile,BufRead *.cxx,*.c++,*.hh,*.hxx,*.hpp,*.ipp,*.moc,*.tcc,*.inl setf cpp
if has("fname_case")
  au BufNewFile,BufRead *.C,*.H setf cpp
endif

" .h files can be C, Ch C++, ObjC or ObjC++.
" Set c_syntax_for_h if you want C, ch_syntax_for_h if you want Ch. ObjC is
" detected automatically.
au BufNewFile,BufRead *.h			call dist#ft#FTheader()

" Ch (CHscript)
au BufNewFile,BufRead *.chf			setf ch

" TLH files are C++ headers generated by Visual C++'s #import from typelibs
au BufNewFile,BufRead *.tlh			setf cpp

" Cascading Style Sheets
au BufNewFile,BufRead *.css			setf css

" Century Term Command Scripts (*.cmd too)
au BufNewFile,BufRead *.con			setf cterm

" Changelog
au BufNewFile,BufRead changelog.Debian,changelog.dch,NEWS.Debian,NEWS.dch,*/debian/changelog
					\	setf debchangelog

au BufNewFile,BufRead [cC]hange[lL]og
	\  if getline(1) =~ '; urgency='
	\|   setf debchangelog
	\| else
	\|   setf changelog
	\| endif

au BufNewFile,BufRead NEWS
	\  if getline(1) =~ '; urgency='
	\|   setf debchangelog
	\| endif

" CHILL
au BufNewFile,BufRead *..ch			setf chill

" Changes for WEB and CWEB or CHILL
au BufNewFile,BufRead *.ch			call dist#ft#FTchange()

" ChordPro
au BufNewFile,BufRead *.chopro,*.crd,*.cho,*.crdpro,*.chordpro	setf chordpro

" Clean
au BufNewFile,BufRead *.dcl,*.icl		setf clean

" Clever
au BufNewFile,BufRead *.eni			setf cl

" Clever or dtd
au BufNewFile,BufRead *.ent			call dist#ft#FTent()

" Clipper, FoxPro, ABB RAPID or eviews
au BufNewFile,BufRead *.prg\c			call dist#ft#FTprg()

" Clojure
au BufNewFile,BufRead *.clj,*.cljs,*.cljx,*.cljc		setf clojure

" Cmake
au BufNewFile,BufRead CMakeLists.txt,*.cmake,*.cmake.in		setf cmake

" Cmusrc
au BufNewFile,BufRead */.cmus/{autosave,rc,command-history,*.theme} setf cmusrc
au BufNewFile,BufRead */cmus/{rc,*.theme}			setf cmusrc

" Cobol
au BufNewFile,BufRead *.cbl,*.cob,*.lib	setf cobol
"   cobol or zope form controller python script? (heuristic)
au BufNewFile,BufRead *.cpy
	\ if getline(1) =~ '^##' |
	\   setf python |
	\ else |
	\   setf cobol |
	\ endif

" Coco/R
au BufNewFile,BufRead *.atg			setf coco

" Cold Fusion
au BufNewFile,BufRead *.cfm,*.cfi,*.cfc		setf cf

" Configure scripts
au BufNewFile,BufRead configure.in,configure.ac setf config

" Cooklang
au BufNewFile,BufRead *.cook			setf cook

" CUDA Compute Unified Device Architecture
au BufNewFile,BufRead *.cu,*.cuh		setf cuda

" Dockerfile; Podman uses the same syntax with name Containerfile
" Also see Dockerfile.* below.
au BufNewFile,BufRead Containerfile,Dockerfile,*.Dockerfile	setf dockerfile

" WildPackets EtherPeek Decoder
au BufNewFile,BufRead *.dcd			setf dcd

" Enlightenment configuration files
au BufNewFile,BufRead *enlightenment/*.cfg	setf c

" Eterm
au BufNewFile,BufRead *Eterm/*.cfg		setf eterm

" Elixir or Euphoria
au BufNewFile,BufRead *.ex call dist#ft#ExCheck()

" Elixir
au BufRead,BufNewFile mix.lock,*.exs setf elixir
au BufRead,BufNewFile *.eex,*.leex setf eelixir

" Elvish
au BufRead,BufNewFile *.elv setf elvish

" Euphoria 3 or 4
au BufNewFile,BufRead *.eu,*.ew,*.exu,*.exw  call dist#ft#EuphoriaCheck()
if has("fname_case")
   au BufNewFile,BufRead *.EU,*.EW,*.EX,*.EXU,*.EXW  call dist#ft#EuphoriaCheck()
endif

" Lynx config files
au BufNewFile,BufRead lynx.cfg			setf lynx

" Modula-3 configuration language (must be before *.cfg and *makefile)
au BufNewFile,BufRead *.quake,cm3.cfg		setf m3quake
au BufNewFile,BufRead m3makefile,m3overrides	setf m3build

" Quake
au BufNewFile,BufRead *baseq[2-3]/*.cfg,*id1/*.cfg	setf quake
au BufNewFile,BufRead *quake[1-3]/*.cfg			setf quake

" Quake C
au BufNewFile,BufRead *.qc			setf c

" Configure files
au BufNewFile,BufRead *.cfg\c			call dist#ft#FTcfg()

" Cucumber
au BufNewFile,BufRead *.feature			setf cucumber

" Communicating Sequential Processes
au BufNewFile,BufRead *.csp,*.fdr		setf csp

" CUPL logic description and simulation
au BufNewFile,BufRead *.pld			setf cupl
au BufNewFile,BufRead *.si			setf cuplsim

" Dart
au BufRead,BufNewfile *.dart,*.drt		setf dart

" Debian Control
au BufNewFile,BufRead */debian/control		setf debcontrol
au BufNewFile,BufRead control
	\  if getline(1) =~ '^Source:'
	\|   setf debcontrol
	\| endif

" Debian Copyright
au BufNewFile,BufRead */debian/copyright	setf debcopyright
au BufNewFile,BufRead copyright
	\  if getline(1) =~ '^Format:'
	\|   setf debcopyright
	\| endif

" Debian Sources.list
au BufNewFile,BufRead */etc/apt/sources.list		setf debsources
au BufNewFile,BufRead */etc/apt/sources.list.d/*.list	setf debsources

" Deny hosts
au BufNewFile,BufRead denyhosts.conf		setf denyhosts

" dnsmasq(8) configuration files
au BufNewFile,BufRead */etc/dnsmasq.conf	setf dnsmasq

" ROCKLinux package description
au BufNewFile,BufRead *.desc			setf desc

" the D language or dtrace
au BufNewFile,BufRead */dtrace/*.d		setf dtrace
au BufNewFile,BufRead *.d			call dist#ft#DtraceCheck()

" Desktop files
au BufNewFile,BufRead *.desktop,*.directory	setf desktop

" Dict config
au BufNewFile,BufRead dict.conf,.dictrc		setf dictconf

" Dictd config
au BufNewFile,BufRead dictd*.conf		setf dictdconf

" DEP3 formatted patch files
au BufNewFile,BufRead */debian/patches/*	call dist#ft#Dep3patch()

" Diff files
au BufNewFile,BufRead *.diff,*.rej		setf diff
au BufNewFile,BufRead *.patch
	\ if getline(1) =~# '^From [0-9a-f]\{40,\} Mon Sep 17 00:00:00 2001$' |
	\   setf gitsendemail |
	\ else |
	\   setf diff |
	\ endif

" Dircolors
au BufNewFile,BufRead .dir_colors,.dircolors,*/etc/DIR_COLORS	setf dircolors

" Diva (with Skill) or InstallShield
au BufNewFile,BufRead *.rul
	\ if getline(1).getline(2).getline(3).getline(4).getline(5).getline(6) =~? 'InstallShield' |
	\   setf ishd |
	\ else |
	\   setf diva |
	\ endif

" DCL (Digital Command Language - vms) or DNS zone file
au BufNewFile,BufRead *.com			call dist#ft#BindzoneCheck('dcl')

" DOT
au BufNewFile,BufRead *.dot,*.gv		setf dot

" Dune
au BufNewFile,BufRead jbuild,dune,dune-project,dune-workspace setf dune

" Dylan - lid files
au BufNewFile,BufRead *.lid			setf dylanlid

" Dylan - intr files (melange)
au BufNewFile,BufRead *.intr			setf dylanintr

" Dylan
au BufNewFile,BufRead *.dylan			setf dylan

" Microsoft Module Definition
au BufNewFile,BufRead *.def			setf def

" Dracula
au BufNewFile,BufRead *.drac,*.drc,*lvs,*lpe	setf dracula

" Datascript
au BufNewFile,BufRead *.ds			setf datascript

" dsl: DSSSL or Structurizr
au BufNewFile,BufRead *.dsl
	\ if getline(1) =~ '^\s*<\!' |
	\   setf dsl |
	\ else |
	\   setf structurizr |
	\ endif

" DTD (Document Type Definition for XML)
au BufNewFile,BufRead *.dtd			setf dtd

" DTS/DSTI (device tree files)
au BufNewFile,BufRead *.dts,*.dtsi		setf dts

" EDIF (*.edf,*.edif,*.edn,*.edo) or edn
au BufNewFile,BufRead *.ed\(f\|if\|o\)		setf edif
au BufNewFile,BufRead *.edn
	\ if getline(1) =~ '^\s*(\s*edif\>' |
	\   setf edif |
	\ else |
	\   setf clojure |
	\ endif

" EditorConfig (close enough to dosini)
au BufNewFile,BufRead .editorconfig		setf dosini

" Embedix Component Description
au BufNewFile,BufRead *.ecd			setf ecd

" Eiffel or Specman or Euphoria
au BufNewFile,BufRead *.e,*.E			call dist#ft#FTe()

" Elinks configuration
au BufNewFile,BufRead elinks.conf		setf elinks

" ERicsson LANGuage; Yaws is erlang too
au BufNewFile,BufRead *.erl,*.hrl,*.yaws	setf erlang

" Elm
au BufNewFile,BufRead *.elm			setf elm

" Elm Filter Rules file
au BufNewFile,BufRead filter-rules		setf elmfilt

" ESMTP rc file
au BufNewFile,BufRead *esmtprc			setf esmtprc

" ESQL-C
au BufNewFile,BufRead *.ec,*.EC			setf esqlc

" Esterel
au BufNewFile,BufRead *.strl			setf esterel

" Essbase script
au BufNewFile,BufRead *.csc			setf csc

" Exim
au BufNewFile,BufRead exim.conf			setf exim

" Expect
au BufNewFile,BufRead *.exp			setf expect

" Exports
au BufNewFile,BufRead exports			setf exports

" Falcon
au BufNewFile,BufRead *.fal			setf falcon

" Fantom
au BufNewFile,BufRead *.fan,*.fwt		setf fan

" Factor
au BufNewFile,BufRead *.factor			setf factor

" Fennel
autocmd BufRead,BufNewFile *.fnl		setf fennel

" Fetchmail RC file
au BufNewFile,BufRead .fetchmailrc		setf fetchmail

" Fish shell
au BufNewFile,BufRead *.fish			setf fish

" FlexWiki - disabled, because it has side effects when a .wiki file
" is not actually FlexWiki
"au BufNewFile,BufRead *.wiki			setf flexwiki

" Focus Executable
au BufNewFile,BufRead *.fex,*.focexec		setf focexec

" Focus Master file (but not for auto.master)
au BufNewFile,BufRead auto.master		setf conf
au BufNewFile,BufRead *.mas,*.master		setf master

" Forth
au BufNewFile,BufRead *.ft,*.fth		setf forth

" Reva Forth
au BufNewFile,BufRead *.frt			setf reva

" Fortran
if has("fname_case")
  au BufNewFile,BufRead *.F,*.FOR,*.FPP,*.FTN,*.F77,*.F90,*.F95,*.F03,*.F08	 setf fortran
endif
au BufNewFile,BufRead   *.f,*.for,*.fortran,*.fpp,*.ftn,*.f77,*.f90,*.f95,*.f03,*.f08  setf fortran

" Framescript
au BufNewFile,BufRead *.fsl			setf framescript

" FStab
au BufNewFile,BufRead fstab,mtab		setf fstab

" Fusion
au BufRead,BufNewFile *.fusion			setf fusion

" F# or Forth
au BufNewFile,BufRead *.fs			call dist#ft#FTfs()

" F#
au BufNewFile,BufRead *.fsi,*.fsx		setf fsharp

" GDB command files
au BufNewFile,BufRead .gdbinit,gdbinit,.gdbearlyinit,gdbearlyinit,*.gdb		setf gdb

" GDMO
au BufNewFile,BufRead *.mo,*.gdmo		setf gdmo

" GDscript
au BufNewFile,BufRead *.gd			setf gdscript

" Godot resource
au BufRead,BufNewFile *.tscn,*.tres			setf gdresource

" Gedcom
au BufNewFile,BufRead *.ged,lltxxxxx.txt	setf gedcom

" Gemtext
au BufNewFile,BufRead *.gmi,*.gemini		setf gemtext

" Gift (Moodle)
autocmd BufRead,BufNewFile *.gift		setf gift

" Git
au BufNewFile,BufRead COMMIT_EDITMSG,MERGE_MSG,TAG_EDITMSG 	setf gitcommit
au BufNewFile,BufRead NOTES_EDITMSG,EDIT_DESCRIPTION		setf gitcommit
au BufNewFile,BufRead *.git/config,.gitconfig,*/etc/gitconfig 	setf gitconfig
au BufNewFile,BufRead */.config/git/config			setf gitconfig
au BufNewFile,BufRead *.git/config.worktree			setf gitconfig
au BufNewFile,BufRead *.git/worktrees/*/config.worktree		setf gitconfig
au BufNewFile,BufRead .gitmodules,*.git/modules/*/config	setf gitconfig
if !empty($XDG_CONFIG_HOME)
  au BufNewFile,BufRead $XDG_CONFIG_HOME/git/config		setf gitconfig
endif
au BufNewFile,BufRead git-rebase-todo		setf gitrebase
au BufRead,BufNewFile .gitsendemail.msg.??????	setf gitsendemail
au BufNewFile,BufRead *.git/*
      \ if getline(1) =~# '^\x\{40,\}\>\|^ref: ' |
      \   setf git |
      \ endif

" Gkrellmrc
au BufNewFile,BufRead gkrellmrc,gkrellmrc_?	setf gkrellmrc

" GLSL
au BufNewFile,BufRead *.glsl			setf glsl

" GP scripts (2.0 and onward)
au BufNewFile,BufRead *.gp,.gprc		setf gp

" GPG
au BufNewFile,BufRead */.gnupg/options		setf gpg
au BufNewFile,BufRead */.gnupg/gpg.conf		setf gpg
au BufNewFile,BufRead */usr/*/gnupg/options.skel setf gpg
if !empty($GNUPGHOME)
  au BufNewFile,BufRead $GNUPGHOME/options	setf gpg
  au BufNewFile,BufRead $GNUPGHOME/gpg.conf	setf gpg
endif

" gnash(1) configuration files
au BufNewFile,BufRead gnashrc,.gnashrc,gnashpluginrc,.gnashpluginrc setf gnash

" Gitolite
au BufNewFile,BufRead gitolite.conf		setf gitolite
au BufNewFile,BufRead {,.}gitolite.rc,example.gitolite.rc	setf perl

" Glimmer-flavored TypeScript and JavaScript
au BufNewFile,BufRead *.gts	setf typescript.glimmer
au BufNewFile,BufRead *.gjs	setf javascript.glimmer

" Gnuplot scripts
au BufNewFile,BufRead *.gpi,.gnuplot		setf gnuplot

" Go (Google)
au BufNewFile,BufRead *.go			setf go
au BufNewFile,BufRead Gopkg.lock		setf toml
au BufRead,BufNewFile go.work			setf gowork

" GrADS scripts
au BufNewFile,BufRead *.gs			setf grads

" GraphQL
au BufNewFile,BufRead *.graphql,*.graphqls,*.gql			setf graphql

" Gretl
au BufNewFile,BufRead *.gretl			setf gretl

" Groovy
au BufNewFile,BufRead *.gradle,*.groovy		setf groovy

" GNU Server Pages
au BufNewFile,BufRead *.gsp			setf gsp

" Group file
au BufNewFile,BufRead */etc/group,*/etc/group-,*/etc/group.edit,*/etc/gshadow,*/etc/gshadow-,*/etc/gshadow.edit,*/var/backups/group.bak,*/var/backups/gshadow.bak  setf group

" GTK RC
au BufNewFile,BufRead .gtkrc,gtkrc		setf gtkrc

" Hack
au BufRead,BufNewFile *.hack,*.hackpartial			setf hack

" Haml
au BufNewFile,BufRead *.haml			setf haml

" Hamster Classic | Playground files
au BufNewFile,BufRead *.hsm			setf hamster

" Handlebars
au BufNewFile,BufRead *.hbs			setf handlebars

" Haskell
au BufNewFile,BufRead *.hs,*.hsc,*.hs-boot,*.hsig setf haskell
au BufNewFile,BufRead *.lhs			setf lhaskell
au BufNewFile,BufRead *.chs			setf chaskell
au BufNewFile,BufRead cabal.project		setf cabalproject
au BufNewFile,BufRead $HOME/.cabal/config	setf cabalconfig
au BufNewFile,BufRead cabal.config		setf cabalconfig

" Haste
au BufNewFile,BufRead *.ht			setf haste
au BufNewFile,BufRead *.htpp			setf hastepreproc

" HCL
au BufRead,BufNewFile *.hcl			setf hcl

" Hercules
au BufNewFile,BufRead *.vc,*.ev,*.sum,*.errsum	setf hercules

" HEEx
au BufRead,BufNewFile *.heex			setf heex

" HEX (Intel)
au BufNewFile,BufRead *.hex,*.h32		setf hex

" Hjson
au BufNewFile,BufRead *.hjson			setf hjson

" Hollywood
au BufRead,BufNewFile *.hws			setf hollywood

" Tilde (must be before HTML)
au BufNewFile,BufRead *.t.html			setf tilde

" HTML (.shtml and .stm for server side)
au BufNewFile,BufRead *.html,*.htm,*.shtml,*.stm  call dist#ft#FThtml()

" HTML with Ruby - eRuby
au BufNewFile,BufRead *.erb,*.rhtml		setf eruby

" HTML with M4
au BufNewFile,BufRead *.html.m4			setf htmlm4

" Some template.  Used to be HTML Cheetah.
au BufNewFile,BufRead *.tmpl			setf template

" Host config
au BufNewFile,BufRead */etc/host.conf		setf hostconf

" Hosts access
au BufNewFile,BufRead */etc/hosts.allow,*/etc/hosts.deny  setf hostsaccess

" Hyper Builder
au BufNewFile,BufRead *.hb			setf hb

" Httest
au BufNewFile,BufRead *.htt,*.htb		setf httest

" i3 (and sway)
au BufNewFile,BufRead */i3/config,*/sway/config		setf i3config
au BufNewFile,BufRead */.i3/config,*/.sway/config	setf i3config

" Icon
au BufNewFile,BufRead *.icn			setf icon

" IDL (Interface Description Language)
au BufNewFile,BufRead *.idl			call dist#ft#FTidl()

" Microsoft IDL (Interface Description Language)  Also *.idl
" MOF = WMI (Windows Management Instrumentation) Managed Object Format
au BufNewFile,BufRead *.odl,*.mof		setf msidl

" Icewm menu
au BufNewFile,BufRead */.icewm/menu		setf icemenu

" Indent profile (must come before IDL *.pro!)
au BufNewFile,BufRead .indent.pro		setf indent
au BufNewFile,BufRead indent.pro		call dist#ft#ProtoCheck('indent')

" IDL (Interactive Data Language)
au BufNewFile,BufRead *.pro			call dist#ft#ProtoCheck('idlang')

" Indent RC
au BufNewFile,BufRead indentrc			setf indent

" Inform
au BufNewFile,BufRead *.inf,*.INF		setf inform

" Initng
au BufNewFile,BufRead */etc/initng/*/*.i,*.ii	setf initng

" Innovation Data Processing
au BufRead,BufNewFile upstream.dat\c,upstream.*.dat\c,*.upstream.dat\c	setf upstreamdat
au BufRead,BufNewFile fdrupstream.log,upstream.log\c,upstream.*.log\c,*.upstream.log\c,UPSTREAM-*.log\c	setf upstreamlog
au BufRead,BufNewFile upstreaminstall.log\c,upstreaminstall.*.log\c,*.upstreaminstall.log\c setf upstreaminstalllog
au BufRead,BufNewFile usserver.log\c,usserver.*.log\c,*.usserver.log\c	setf usserverlog
au BufRead,BufNewFile usw2kagt.log\c,usw2kagt.*.log\c,*.usw2kagt.log\c	setf usw2kagtlog

" Ipfilter
au BufNewFile,BufRead ipf.conf,ipf6.conf,ipf.rules	setf ipfilter

" Informix 4GL (source - canonical, include file, I4GL+M4 preproc.)
au BufNewFile,BufRead *.4gl,*.4gh,*.m4gl	setf fgl

" .INI file for MSDOS
au BufNewFile,BufRead *.ini			setf dosini

" SysV Inittab
au BufNewFile,BufRead inittab			setf inittab

" Inno Setup
au BufNewFile,BufRead *.iss			setf iss

" J
au BufNewFile,BufRead *.ijs			setf j

" JAL
au BufNewFile,BufRead *.jal,*.JAL		setf jal

" Jam
au BufNewFile,BufRead *.jpl,*.jpr		setf jam

" Java
au BufNewFile,BufRead *.java,*.jav		setf java

" JavaCC
au BufNewFile,BufRead *.jj,*.jjt		setf javacc

" JavaScript, ECMAScript, ES module script, CommonJS script
au BufNewFile,BufRead *.js,*.javascript,*.es,*.mjs,*.cjs   setf javascript

" JavaScript with React
au BufNewFile,BufRead *.jsx			setf javascriptreact

" Java Server Pages
au BufNewFile,BufRead *.jsp			setf jsp

" Java Properties resource file (note: doesn't catch font.properties.pl)
au BufNewFile,BufRead *.properties,*.properties_??,*.properties_??_??	setf jproperties

" Jess
au BufNewFile,BufRead *.clp			setf jess

" Jgraph
au BufNewFile,BufRead *.jgr			setf jgraph

" Jovial
au BufNewFile,BufRead *.jov,*.j73,*.jovial	setf jovial

" JSON
au BufNewFile,BufRead *.json,*.jsonp,*.webmanifest	setf json

" JSON5
au BufNewFile,BufRead *.json5			setf json5

" JSON Patch (RFC 6902)
au BufNewFile,BufRead *.json-patch			setf json

" Jupyter Notebook is also json
au BufNewFile,BufRead *.ipynb				setf json

" Other files that look like json
au BufNewFile,BufRead .babelrc,.eslintrc,.prettierrc,.firebaserc  setf json

" JSONC
au BufNewFile,BufRead *.jsonc			setf jsonc

" Julia
au BufNewFile,BufRead *.jl			setf julia

" Kixtart
au BufNewFile,BufRead *.kix			setf kix

" Kuka Robot Language
au BufNewFile,BufRead *.src\c			call dist#ft#FTsrc()
au BufNewFile,BufRead *.dat\c			call dist#ft#FTdat()
au BufNewFile,BufRead *.sub\c			setf krl

" Kimwitu[++]
au BufNewFile,BufRead *.k			setf kwt

" Kivy
au BufNewFile,BufRead *.kv			setf kivy

" Kotlin
au BufNewFile,BufRead *.kt,*.ktm,*.kts		setf kotlin

" KDE script
au BufNewFile,BufRead *.ks			setf kscript

" Kconfig
au BufNewFile,BufRead Kconfig,Kconfig.debug	setf kconfig

" Lace (ISE)
au BufNewFile,BufRead *.ace,*.ACE		setf lace

" Latte
au BufNewFile,BufRead *.latte,*.lte		setf latte

" Limits
au BufNewFile,BufRead */etc/limits,*/etc/*limits.conf,*/etc/*limits.d/*.conf	setf limits

" LambdaProlog (see dist#ft#FTmod for *.mod)
au BufNewFile,BufRead *.sig			setf lprolog

" LDAP LDIF
au BufNewFile,BufRead *.ldif			setf ldif

" Ld loader
au BufNewFile,BufRead *.ld			setf ld

" Ledger
au BufRead,BufNewFile *.ldg,*.ledger,*.journal			setf ledger

" Less
au BufNewFile,BufRead *.less			setf less

" Lex
au BufNewFile,BufRead *.lex,*.l,*.lxx,*.l++	setf lex

" Libao
au BufNewFile,BufRead */etc/libao.conf,*/.libao	setf libao

" Libsensors
au BufNewFile,BufRead */etc/sensors.conf,*/etc/sensors3.conf	setf sensors

" LFTP
au BufNewFile,BufRead lftp.conf,.lftprc,*lftp/rc	setf lftp

" Lifelines (or Lex for C++!)
au BufNewFile,BufRead *.ll			setf lifelines

" Lilo: Linux loader
au BufNewFile,BufRead lilo.conf			setf lilo

" Lisp (*.el = ELisp, *.cl = Common Lisp)
" *.jl was removed, it's also used for Julia, better skip than guess wrong.
if has("fname_case")
  au BufNewFile,BufRead *.lsp,*.lisp,*.asd,*.el,*.cl,*.L,.emacs,.sawfishrc setf lisp
else
  au BufNewFile,BufRead *.lsp,*.lisp,*.asd,*.el,*.cl,.emacs,.sawfishrc setf lisp
endif

" SBCL implementation of Common Lisp
au BufNewFile,BufRead sbclrc,.sbclrc		setf lisp

" Liquid
au BufNewFile,BufRead *.liquid			setf liquid

" Lite
au BufNewFile,BufRead *.lite,*.lt		setf lite

" LiteStep RC files
au BufNewFile,BufRead */LiteStep/*/*.rc		setf litestep

" Login access
au BufNewFile,BufRead */etc/login.access	setf loginaccess

" Login defs
au BufNewFile,BufRead */etc/login.defs		setf logindefs

" Logtalk
au BufNewFile,BufRead *.lgt			setf logtalk

" LOTOS
au BufNewFile,BufRead *.lot,*.lotos		setf lotos

" Lout (also: *.lt)
au BufNewFile,BufRead *.lou,*.lout		setf lout

" Lua
au BufNewFile,BufRead *.lua			setf lua

" Luarocks
au BufNewFile,BufRead *.rockspec		setf lua

" Linden Scripting Language (Second Life)
au BufNewFile,BufRead *.lsl			setf lsl

" Lynx style file (or LotusScript!)
au BufNewFile,BufRead *.lss			setf lss

" M4
au BufNewFile,BufRead *.m4
	\ if expand("<afile>") !~? 'html.m4$\|fvwm2rc' | setf m4 | endif

" MaGic Point
au BufNewFile,BufRead *.mgp			setf mgp

" Mail (for Elm, trn, mutt, muttng, rn, slrn, neomutt)
au BufNewFile,BufRead snd.\d\+,.letter,.letter.\d\+,.followup,.article,.article.\d\+,pico.\d\+,mutt{ng,}-*-\w\+,mutt[[:alnum:]_-]\\\{6\},neomutt-*-\w\+,neomutt[[:alnum:]_-]\\\{6\},ae\d\+.txt,/tmp/SLRN[0-9A-Z.]\+,*.eml setf mail

" Mail aliases
au BufNewFile,BufRead */etc/mail/aliases,*/etc/aliases	setf mailaliases

" Mailcap configuration file
au BufNewFile,BufRead .mailcap,mailcap		setf mailcap

" Makefile
au BufNewFile,BufRead *[mM]akefile,*.mk,*.mak,*.dsp setf make

" MakeIndex
au BufNewFile,BufRead *.ist,*.mst		setf ist

" Mallard
au BufNewFile,BufRead *.page			setf mallard

" Manpage
au BufNewFile,BufRead *.man			setf nroff

" Man config
au BufNewFile,BufRead */etc/man.conf,man.config	setf manconf

" Maple V
au BufNewFile,BufRead *.mv,*.mpl,*.mws		setf maple

" Map (UMN mapserver config file)
au BufNewFile,BufRead *.map			setf map

" Markdown
au BufNewFile,BufRead *.markdown,*.mdown,*.mkd,*.mkdn,*.mdwn,*.md  setf markdown

" Mason
au BufNewFile,BufRead *.mason,*.mhtml,*.comp	setf mason

" Mathematica, Matlab, Murphi, Objective C or Octave
au BufNewFile,BufRead *.m			call dist#ft#FTm()

" Mathematica notebook
au BufNewFile,BufRead *.nb			setf mma

" Maya Extension Language
au BufNewFile,BufRead *.mel			setf mel

" Mercurial (hg) commit file
au BufNewFile,BufRead hg-editor-*.txt		setf hgcommit

" Mercurial config (looks like generic config file)
au BufNewFile,BufRead *.hgrc,*hgrc		setf cfg

" Meson Build system config
au BufNewFile,BufRead meson.build,meson_options.txt setf meson
au BufNewFile,BufRead *.wrap			setf dosini

" Messages (logs mostly)
au BufNewFile,BufRead */log/{auth,cron,daemon,debug,kern,lpr,mail,messages,news/news,syslog,user}{,.log,.err,.info,.warn,.crit,.notice}{,.[0-9]*,-[0-9]*} setf messages

" Metafont
au BufNewFile,BufRead *.mf			setf mf

" MetaPost
au BufNewFile,BufRead *.mp			setf mp

" MGL
au BufNewFile,BufRead *.mgl			setf mgl

" MIX - Knuth assembly
au BufNewFile,BufRead *.mix,*.mixal		setf mix

" MMIX or VMS makefile
au BufNewFile,BufRead *.mms			call dist#ft#FTmms()

" Symbian meta-makefile definition (MMP)
au BufNewFile,BufRead *.mmp			setf mmp

" ABB Rapid, Modula-2, Modsim III or LambdaProlog
au BufNewFile,BufRead *.mod\c			call dist#ft#FTmod()

" Modula-2  (.md removed in favor of Markdown, see dist#ft#FTmod for *.MOD)
au BufNewFile,BufRead *.m2,*.DEF,*.mi		setf modula2

" Modula-3 (.m3, .i3, .mg, .ig)
au BufNewFile,BufRead *.[mi][3g]		setf modula3

" Monk
au BufNewFile,BufRead *.isc,*.monk,*.ssc,*.tsc	setf monk

" MOO
au BufNewFile,BufRead *.moo			setf moo

" Modconf
au BufNewFile,BufRead */etc/modules.conf,*/etc/modules,*/etc/conf.modules setf modconf

" MPD is based on XML
au BufNewFile,BufRead *.mpd			setf xml

" Mplayer config
au BufNewFile,BufRead mplayer.conf,*/.mplayer/config	setf mplayerconf

" Motorola S record
au BufNewFile,BufRead *.s19,*.s28,*.s37,*.mot,*.srec	setf srec

" Mrxvtrc
au BufNewFile,BufRead mrxvtrc,.mrxvtrc		setf mrxvtrc

" Msql
au BufNewFile,BufRead *.msql			setf msql

" Mysql
au BufNewFile,BufRead *.mysql			setf mysql

" Tcl Shell RC file
au BufNewFile,BufRead tclsh.rc			setf tcl

" M$ Resource files
" /etc/Muttrc.d/file.rc is muttrc
au BufNewFile,BufRead *.rc,*.rch
	\ if expand("<afile>") !~ "/etc/Muttrc.d/" |
	\   setf rc |
	\ endif

" MuPAD source
au BufRead,BufNewFile *.mu			setf mupad

" Mush
au BufNewFile,BufRead *.mush			setf mush

" Mutt setup file (also for Muttng)
au BufNewFile,BufRead Mutt{ng,}rc		setf muttrc

" N1QL
au BufRead,BufNewfile *.n1ql,*.nql		setf n1ql

" Nano
au BufNewFile,BufRead */etc/nanorc,*.nanorc	setf nanorc

" Nastran input/DMAP
"au BufNewFile,BufRead *.dat			setf nastran

" Natural
au BufNewFile,BufRead *.NS[ACGLMNPS]		setf natural

" Noemutt setup file
au BufNewFile,BufRead Neomuttrc			setf neomuttrc

" Netrc
au BufNewFile,BufRead .netrc			setf netrc

" Nginx
au BufNewFile,BufRead *.nginx,nginx*.conf,*nginx.conf,*/etc/nginx/*,*/usr/local/nginx/conf/*,*/nginx/*.conf			setf nginx

" Ninja file
au BufNewFile,BufRead *.ninja			setf ninja

" Nix
au BufRead,BufNewFile *.nix			setf nix

" NPM RC file
au BufNewFile,BufRead npmrc,.npmrc		setf dosini

" Novell netware batch files
au BufNewFile,BufRead *.ncf			setf ncf

" Nroff/Troff (*.ms and *.t are checked below)
au BufNewFile,BufRead *.me
	\ if expand("<afile>") != "read.me" && expand("<afile>") != "click.me" |
	\   setf nroff |
	\ endif
au BufNewFile,BufRead *.tr,*.nr,*.roff,*.tmac,*.mom	setf nroff
au BufNewFile,BufRead *.[1-9]			call dist#ft#FTnroff()

" Nroff or Objective C++
au BufNewFile,BufRead *.mm			call dist#ft#FTmm()

" Not Quite C
au BufNewFile,BufRead *.nqc			setf nqc

" NSE - Nmap Script Engine - uses Lua syntax
au BufNewFile,BufRead *.nse			setf lua

" NSIS
au BufNewFile,BufRead *.nsi,*.nsh		setf nsis

" OCaml
au BufNewFile,BufRead *.ml,*.mli,*.mll,*.mly,.ocamlinit,*.mlt,*.mlp,*.mlip,*.mli.cppo,*.ml.cppo setf ocaml

" Occam
au BufNewFile,BufRead *.occ			setf occam

" Octave
au BufNewFile,BufRead octave.conf,.octaverc,octaverc	setf octave

" Omnimark
au BufNewFile,BufRead *.xom,*.xin		setf omnimark

" OPAM
au BufNewFile,BufRead opam,*.opam,*.opam.template setf opam

" OpenFOAM
au BufNewFile,BufRead [a-zA-Z0-9]*Dict\(.*\)\=,[a-zA-Z]*Properties\(.*\)\=,*Transport\(.*\),fvSchemes,fvSolution,fvConstrains,fvModels,*/constant/g,*/0\(\.orig\)\=/* call dist#ft#FTfoam()

" OpenROAD
au BufNewFile,BufRead *.or			setf openroad

" OPL
au BufNewFile,BufRead *.[Oo][Pp][Ll]		setf opl

" Oracle config file
au BufNewFile,BufRead *.ora			setf ora

" Org
au BufNewFile,BufRead *.org,*.org_archive	setf org

" Packet filter conf
au BufNewFile,BufRead pf.conf			setf pf

" Pacman Config (close enough to dosini)
au BufNewFile,BufRead */etc/pacman.conf		setf dosini

" Pacman hooks
au BufNewFile,BufRead *.hook
	\ if getline(1) == '[Trigger]' |
	\   setf dosini |
	\ endif

" Pam conf
au BufNewFile,BufRead */etc/pam.conf			setf pamconf

" Pam environment
au BufNewFile,BufRead pam_env.conf,.pam_environment	setf pamenv

" PApp
au BufNewFile,BufRead *.papp,*.pxml,*.pxsl	setf papp

" Password file
au BufNewFile,BufRead */etc/passwd,*/etc/passwd-,*/etc/passwd.edit,*/etc/shadow,*/etc/shadow-,*/etc/shadow.edit,*/var/backups/passwd.bak,*/var/backups/shadow.bak setf passwd

" Pascal (also *.p, *.pp, *.inc)
au BufNewFile,BufRead *.pas			setf pascal

" Pascal or Puppet manifest
au BufNewFile,BufRead *.pp			call dist#ft#FTpp()

" Delphi or Lazarus program file
au BufNewFile,BufRead *.dpr,*.lpr		setf pascal

" Free Pascal makefile definition file
au BufNewFile,BufRead *.fpc			setf fpcmake

" PDF
au BufNewFile,BufRead *.pdf			setf pdf

" PCMK - HAE - crm configure edit
au BufNewFile,BufRead *.pcmk			setf pcmk

" Perl
if has("fname_case")
  au BufNewFile,BufRead *.pl,*.PL		call dist#ft#FTpl()
else
  au BufNewFile,BufRead *.pl			call dist#ft#FTpl()
endif
au BufNewFile,BufRead *.plx,*.al,*.psgi		setf perl

" Perl, XPM or XPM2
au BufNewFile,BufRead *.pm
	\ if getline(1) =~ "XPM2" |
	\   setf xpm2 |
	\ elseif getline(1) =~ "XPM" |
	\   setf xpm |
	\ else |
	\   setf perl |
	\ endif

" Perl POD
au BufNewFile,BufRead *.pod			setf pod

" Php, php3, php4, etc.
" Also Phtml (was used for PHP 2 in the past).
" Also .ctp for Cake template file.
" Also .phpt for php tests.
au BufNewFile,BufRead *.php,*.php\d,*.phtml,*.ctp,*.phpt	setf php

" PHP config
au BufNewFile,BufRead php.ini-*			setf dosini

" Pike and Cmod
au BufNewFile,BufRead *.pike,*.pmod		setf pike
au BufNewFile,BufRead *.cmod			setf cmod

" Pinfo config
au BufNewFile,BufRead */etc/pinforc,*/.pinforc	setf pinfo

" Palm Resource compiler
au BufNewFile,BufRead *.rcp			setf pilrc

" Pine config
au BufNewFile,BufRead .pinerc,pinerc,.pinercex,pinercex		setf pine

" Pipenv Pipfiles
au BufNewFile,BufRead Pipfile			setf toml
au BufNewFile,BufRead Pipfile.lock		setf json

" PL/1, PL/I
au BufNewFile,BufRead *.pli,*.pl1		setf pli

" PL/M (also: *.inp)
au BufNewFile,BufRead *.plm,*.p36,*.pac		setf plm

" PL/SQL
au BufNewFile,BufRead *.pls,*.plsql		setf plsql

" PLP
au BufNewFile,BufRead *.plp			setf plp

" PO and PO template (GNU gettext)
au BufNewFile,BufRead *.po,*.pot		setf po

" Postfix main config
au BufNewFile,BufRead main.cf			setf pfmain

" PostScript (+ font files, encapsulated PostScript, Adobe Illustrator)
au BufNewFile,BufRead *.ps,*.pfa,*.afm,*.eps,*.epsf,*.epsi,*.ai	  setf postscr

" PostScript Printer Description
au BufNewFile,BufRead *.ppd			setf ppd

" Povray
au BufNewFile,BufRead *.pov			setf pov

" Povray configuration
au BufNewFile,BufRead .povrayrc			setf povini

" Povray, Pascal, PHP or assembly
au BufNewFile,BufRead *.inc			call dist#ft#FTinc()

" PowerShell
au BufNewFile,BufRead	*.ps1,*.psd1,*.psm1,*.pssc	setf ps1
au BufNewFile,BufRead	*.ps1xml			setf ps1xml
au BufNewFile,BufRead	*.cdxml,*.psc1			setf xml

" Printcap and Termcap
au BufNewFile,BufRead *printcap
	\ let b:ptcap_type = "print" | setf ptcap
au BufNewFile,BufRead *termcap
	\ let b:ptcap_type = "term" | setf ptcap

" Prisma
au BufRead,BufNewFile *.prisma			setf prisma

" PCCTS / ANTLR
"au BufNewFile,BufRead *.g			setf antlr
au BufNewFile,BufRead *.g			setf pccts

" PPWizard
au BufNewFile,BufRead *.it,*.ih			setf ppwiz

" Pug
au BufRead,BufNewFile *.pug			setf pug

" Puppet
au BufNewFile,BufRead Puppetfile		setf ruby

" Embedded Puppet
au BufNewFile,BufRead *.epp			setf epuppet

" Obj 3D file format
" TODO: is there a way to avoid MS-Windows Object files?
au BufNewFile,BufRead *.obj			setf obj

" Oracle Pro*C/C++
au BufNewFile,BufRead *.pc			setf proc

" Privoxy actions file
au BufNewFile,BufRead *.action			setf privoxy

" Procmail
au BufNewFile,BufRead .procmail,.procmailrc	setf procmail

" Progress or CWEB
au BufNewFile,BufRead *.w			call dist#ft#FTprogress_cweb()

" Progress or assembly
au BufNewFile,BufRead *.i			call dist#ft#FTprogress_asm()

" Progress or Pascal
au BufNewFile,BufRead *.p			call dist#ft#FTprogress_pascal()

" Software Distributor Product Specification File (POSIX 1387.2-1995)
au BufNewFile,BufRead *.psf			setf psf
au BufNewFile,BufRead INDEX,INFO
	\ if getline(1) =~ '^\s*\(distribution\|installed_software\|root\|bundle\|product\)\s*$' |
	\   setf psf |
	\ endif

" Prolog
au BufNewFile,BufRead *.pdb			setf prolog

" Promela
au BufNewFile,BufRead *.pml			setf promela

" Property Specification Language (PSL)
au BufNewFile,BufRead *.psl			setf psl

" Google protocol buffers
au BufNewFile,BufRead *.proto			setf proto
au BufNewFile,BufRead *.pbtxt			setf pbtxt

" Poke
au BufNewFile,BufRead *.pk			setf poke

" Protocols
au BufNewFile,BufRead */etc/protocols		setf protocols

" Pyret
au BufNewFile,BufRead *.arr			setf pyret

" Pyrex
au BufNewFile,BufRead *.pyx,*.pxd		setf pyrex

" Python, Python Shell Startup and Python Stub Files
" Quixote (Python-based web framework)
au BufNewFile,BufRead *.py,*.pyw,.pythonstartup,.pythonrc  setf python
au BufNewFile,BufRead *.ptl,*.pyi,SConstruct		   setf python

" QL
au BufRead,BufNewFile *.ql,*.qll		setf ql

" Radiance
au BufNewFile,BufRead *.rad,*.mat		setf radiance

" Raku (formerly Perl6)
au BufNewFile,BufRead *.pm6,*.p6,*.t6,*.pod6,*.raku,*.rakumod,*.rakudoc,*.rakutest  setf raku

" Ratpoison config/command files
au BufNewFile,BufRead .ratpoisonrc,ratpoisonrc	setf ratpoison

" RCS file
au BufNewFile,BufRead *\,v			setf rcs

" Readline
au BufNewFile,BufRead .inputrc,inputrc		setf readline

" Registry for MS-Windows
au BufNewFile,BufRead *.reg
	\ if getline(1) =~? '^REGEDIT[0-9]*\s*$\|^Windows Registry Editor Version \d*\.\d*\s*$' | setf registry | endif

" Renderman Interface Bytestream
au BufNewFile,BufRead *.rib			setf rib

" Rego Policy Language
au BufNewFile,BufRead *.rego			setf rego

" Rexx
au BufNewFile,BufRead *.rex,*.orx,*.rxo,*.rxj,*.jrexx,*.rexxj,*.rexx,*.testGroup,*.testUnit	setf rexx

" R Help file
if has("fname_case")
  au BufNewFile,BufRead *.rd,*.Rd		setf rhelp
else
  au BufNewFile,BufRead *.rd			setf rhelp
endif

" R noweb file
if has("fname_case")
  au BufNewFile,BufRead *.Rnw,*.rnw,*.Snw,*.snw		setf rnoweb
else
  au BufNewFile,BufRead *.rnw,*.snw			setf rnoweb
endif

" R Markdown file
if has("fname_case")
  au BufNewFile,BufRead *.Rmd,*.rmd,*.Smd,*.smd		setf rmd
else
  au BufNewFile,BufRead *.rmd,*.smd			setf rmd
endif

" RSS looks like XML
au BufNewFile,BufRead *.rss				setf xml

" R reStructuredText file
if has("fname_case")
  au BufNewFile,BufRead *.Rrst,*.rrst,*.Srst,*.srst	setf rrst
else
  au BufNewFile,BufRead *.rrst,*.srst			setf rrst
endif

" Rexx, Rebol or R
au BufNewFile,BufRead *.r,*.R				call dist#ft#FTr()

" Remind
au BufNewFile,BufRead .reminders,*.remind,*.rem		setf remind

" ReScript
au BufNewFile,BufRead *.res,*.resi			setf rescript

" Resolv.conf
au BufNewFile,BufRead resolv.conf		setf resolv

" Relax NG Compact
au BufNewFile,BufRead *.rnc			setf rnc

" Relax NG XML
au BufNewFile,BufRead *.rng			setf rng

" RPL/2
au BufNewFile,BufRead *.rpl			setf rpl

" Robots.txt
au BufNewFile,BufRead robots.txt		setf robots

" Rpcgen
au BufNewFile,BufRead *.x			setf rpcgen

" MikroTik RouterOS script
au BufRead,BufNewFile *.rsc			setf routeros

" reStructuredText Documentation Format
au BufNewFile,BufRead *.rst			setf rst

" RTF
au BufNewFile,BufRead *.rtf			setf rtf

" Interactive Ruby shell
au BufNewFile,BufRead .irbrc,irbrc		setf ruby

" Ruby
au BufNewFile,BufRead *.rb,*.rbw		setf ruby

" RubyGems
au BufNewFile,BufRead *.gemspec			setf ruby

" RBS (Ruby Signature)
au BufNewFile,BufRead *.rbs			setf rbs

" Rackup
au BufNewFile,BufRead *.ru			setf ruby

" Bundler
au BufNewFile,BufRead Gemfile			setf ruby

" Ruby on Rails
au BufNewFile,BufRead *.builder,*.rxml,*.rjs	setf ruby

" Rantfile and Rakefile is like Ruby
au BufNewFile,BufRead [rR]antfile,*.rant,[rR]akefile,*.rake	setf ruby

" Rust
au BufNewFile,BufRead *.rs			setf rust
au BufNewFile,BufRead Cargo.lock,*/.cargo/config,*/.cargo/credentials	setf toml

" S-lang (or shader language, or SmallLisp)
au BufNewFile,BufRead *.sl			setf slang

" Samba config
au BufNewFile,BufRead smb.conf			setf samba

" SAS script
au BufNewFile,BufRead *.sas			setf sas

" Sass
au BufNewFile,BufRead *.sass			setf sass

" Sather
au BufNewFile,BufRead *.sa			setf sather

" Scala
au BufNewFile,BufRead *.scala			setf scala

" SBT - Scala Build Tool
au BufNewFile,BufRead *.sbt			setf sbt

" SuperCollider
au BufNewFile,BufRead *.sc			call dist#ft#FTsc()

au BufNewFile,BufRead *.quark			setf supercollider

" scdoc
au BufNewFile,BufRead *.scd			call dist#ft#FTscd()

" Scilab
au BufNewFile,BufRead *.sci,*.sce		setf scilab


" SCSS
au BufNewFile,BufRead *.scss			setf scss

" SD: Streaming Descriptors
au BufNewFile,BufRead *.sd			setf sd

" SDL
au BufNewFile,BufRead *.sdl,*.pr		setf sdl

" sed
au BufNewFile,BufRead *.sed			setf sed

" svelte
au BufNewFile,BufRead *.svelte			setf svelte

" Sieve (RFC 3028, 5228)
au BufNewFile,BufRead *.siv,*.sieve		setf sieve

" Sendmail
au BufNewFile,BufRead sendmail.cf		setf sm

" Sendmail .mc files are actually m4.  Could also be MS Message text file.
au BufNewFile,BufRead *.mc			call dist#ft#McSetf()

" Services
au BufNewFile,BufRead */etc/services		setf services

" Service Location config
au BufNewFile,BufRead */etc/slp.conf		setf slpconf

" Service Location registration
au BufNewFile,BufRead */etc/slp.reg		setf slpreg

" Service Location SPI
au BufNewFile,BufRead */etc/slp.spi		setf slpspi

" Setserial config
au BufNewFile,BufRead */etc/serial.conf		setf setserial

" SGML
au BufNewFile,BufRead *.sgm,*.sgml
	\ if getline(1).getline(2).getline(3).getline(4).getline(5) =~? 'linuxdoc' |
	\   setf sgmllnx |
	\ elseif getline(1) =~ '<!DOCTYPE.*DocBook' || getline(2) =~ '<!DOCTYPE.*DocBook' |
	\   let b:docbk_type = "sgml" |
	\   let b:docbk_ver = 4 |
	\   setf docbk |
	\ else |
	\   setf sgml |
	\ endif

" SGMLDECL
au BufNewFile,BufRead *.decl,*.dcl,*.dec
	\ if getline(1).getline(2).getline(3) =~? '^<!SGML' |
	\    setf sgmldecl |
	\ endif

" SGML catalog file
au BufNewFile,BufRead catalog			setf catalog

" Shell scripts (sh, ksh, bash, bash2, csh); Allow .profile_foo etc.
" Gentoo ebuilds, Arch Linux PKGBUILDs and Alpine Linux APKBUILDs are actually
" bash scripts.
" NOTE: Patterns ending in a star are further down, these have lower priority.
au BufNewFile,BufRead .bashrc,bashrc,bash.bashrc,.bash[_-]profile,.bash[_-]logout,.bash[_-]aliases,bash-fc[-.],*.ebuild,*.bash,*.eclass,PKGBUILD,APKBUILD call dist#ft#SetFileTypeSH("bash")
au BufNewFile,BufRead .kshrc,*.ksh call dist#ft#SetFileTypeSH("ksh")
au BufNewFile,BufRead */etc/profile,.profile,*.sh,*.env call dist#ft#SetFileTypeSH(getline(1))

" Shell script (Arch Linux) or PHP file (Drupal)
au BufNewFile,BufRead *.install
	\ if getline(1) =~ '<?php' |
	\   setf php |
	\ else |
	\   call dist#ft#SetFileTypeSH("bash") |
	\ endif

" tcsh scripts (patterns ending in a star further below)
au BufNewFile,BufRead .tcshrc,*.tcsh,tcsh.tcshrc,tcsh.login	call dist#ft#SetFileTypeShell("tcsh")

" csh scripts, but might also be tcsh scripts (on some systems csh is tcsh)
" (patterns ending in a start further below)
au BufNewFile,BufRead .login,.cshrc,csh.cshrc,csh.login,csh.logout,*.csh,.alias  call dist#ft#CSH()

" Zig
au BufNewFile,BufRead *.zig			setf zig

" Z-Shell script (patterns ending in a star further below)
au BufNewFile,BufRead .zprofile,*/etc/zprofile,.zfbfmarks  setf zsh
au BufNewFile,BufRead .zshrc,.zshenv,.zlogin,.zlogout,.zcompdump setf zsh
au BufNewFile,BufRead *.zsh			setf zsh

" Scheme
au BufNewFile,BufRead *.scm,*.ss,*.sld,*.rkt,*.rktd,*.rktl	setf scheme

" Screen RC
au BufNewFile,BufRead .screenrc,screenrc	setf screen

" Sexplib
au BufNewFile,BufRead *.sexp setf sexplib

" Simula
au BufNewFile,BufRead *.sim			setf simula

" SINDA
au BufNewFile,BufRead *.sin,*.s85		setf sinda

" SiSU
au BufNewFile,BufRead *.sst,*.ssm,*.ssi,*.-sst,*._sst setf sisu
au BufNewFile,BufRead *.sst.meta,*.-sst.meta,*._sst.meta setf sisu

" SKILL
au BufNewFile,BufRead *.il,*.ils,*.cdf		setf skill

" SLRN
au BufNewFile,BufRead .slrnrc			setf slrnrc
au BufNewFile,BufRead *.score			setf slrnsc

" Smalltalk (and TeX)
au BufNewFile,BufRead *.st			setf st
au BufNewFile,BufRead *.cls
	\ if getline(1) =~ '^%' |
	\  setf tex |
	\ elseif getline(1)[0] == '#' && getline(1) =~ 'rexx' |
	\  setf rexx |
	\ else |
	\  setf st |
	\ endif

" Smarty templates
au BufNewFile,BufRead *.tpl			setf smarty

" SMIL or XML
au BufNewFile,BufRead *.smil
	\ if getline(1) =~ '<?\s*xml.*?>' |
	\   setf xml |
	\ else |
	\   setf smil |
	\ endif

" SMIL or SNMP MIB file
au BufNewFile,BufRead *.smi
	\ if getline(1) =~ '\<smil\>' |
	\   setf smil |
	\ else |
	\   setf mib |
	\ endif

" SMITH
au BufNewFile,BufRead *.smt,*.smith		setf smith

" Snobol4 and spitbol
au BufNewFile,BufRead *.sno,*.spt		setf snobol4

" SNMP MIB files
au BufNewFile,BufRead *.mib,*.my		setf mib

" Snort Configuration
au BufNewFile,BufRead *.hog,snort.conf,vision.conf	setf hog
au BufNewFile,BufRead *.rules			call dist#ft#FTRules()

" Solidity
au BufRead,BufNewFile *.sol			setf solidity

" SPARQL queries
au BufNewFile,BufRead *.rq,*.sparql		setf sparql

" Spec (Linux RPM)
au BufNewFile,BufRead *.spec			setf spec

" Speedup (AspenTech plant simulator)
au BufNewFile,BufRead *.speedup,*.spdata,*.spd	setf spup

" Slice
au BufNewFile,BufRead *.ice			setf slice

" Microsoft Visual Studio Solution
au BufNewFile,BufRead *.sln			setf solution
au BufNewFile,BufRead *.slnf			setf json

" Spice
au BufNewFile,BufRead *.sp,*.spice		setf spice

" Spyce
au BufNewFile,BufRead *.spy,*.spi		setf spyce

" Squid
au BufNewFile,BufRead squid.conf		setf squid

" SQL for Oracle Designer
au BufNewFile,BufRead *.tyb,*.typ,*.tyc,*.pkb,*.pks	setf sql

" SQL
au BufNewFile,BufRead *.sql			call dist#ft#SQL()

" SQLJ
au BufNewFile,BufRead *.sqlj			setf sqlj

" SQR
au BufNewFile,BufRead *.sqr,*.sqi		setf sqr

" Squirrel
au BufNewFile,BufRead *.nut			setf squirrel

" OpenSSH configuration
au BufNewFile,BufRead ssh_config,*/.ssh/config,*/.ssh/*.conf	setf sshconfig
au BufNewFile,BufRead */etc/ssh/ssh_config.d/*.conf		setf sshconfig

" OpenSSH server configuration
au BufNewFile,BufRead sshd_config			setf sshdconfig
au BufNewFile,BufRead */etc/ssh/sshd_config.d/*.conf	setf sshdconfig

" Stata
au BufNewFile,BufRead *.ado,*.do,*.imata,*.mata	setf stata
" Also *.class, but not when it's a Java bytecode file
au BufNewFile,BufRead *.class
	\ if getline(1) !~ "^\xca\xfe\xba\xbe" | setf stata | endif

" SMCL
au BufNewFile,BufRead *.hlp,*.ihlp,*.smcl	setf smcl

" Stored Procedures
au BufNewFile,BufRead *.stp			setf stp

" Standard ML
au BufNewFile,BufRead *.sml			setf sml

" Sratus VOS command macro
au BufNewFile,BufRead *.cm			setf voscm

" Swift
au BufNewFile,BufRead *.swift			setf swift
au BufNewFile,BufRead *.swift.gyb		setf swiftgyb

" Swift Intermediate Language
au BufNewFile,BufRead *.sil			setf sil

" Sysctl
au BufNewFile,BufRead */etc/sysctl.conf,*/etc/sysctl.d/*.conf	setf sysctl

" Systemd unit files
au BufNewFile,BufRead */systemd/*.{automount,dnssd,link,mount,netdev,network,nspawn,path,service,slice,socket,swap,target,timer}	setf systemd
" Systemd overrides
au BufNewFile,BufRead */etc/systemd/*.conf.d/*.conf	setf systemd
au BufNewFile,BufRead */etc/systemd/system/*.d/*.conf	setf systemd
au BufNewFile,BufRead */.config/systemd/user/*.d/*.conf	setf systemd
" Systemd temp files
au BufNewFile,BufRead */etc/systemd/system/*.d/.#*	setf systemd
au BufNewFile,BufRead */etc/systemd/system/.#*		setf systemd
au BufNewFile,BufRead */.config/systemd/user/*.d/.#*	setf systemd
au BufNewFile,BufRead */.config/systemd/user/.#*	setf systemd

" Synopsys Design Constraints
au BufNewFile,BufRead *.sdc			setf sdc

" Sudoers
au BufNewFile,BufRead */etc/sudoers,sudoers.tmp	setf sudoers

" SVG (Scalable Vector Graphics)
au BufNewFile,BufRead *.svg			setf svg

" Surface
au BufRead,BufNewFile *.sface			setf surface

" Tads (or Nroff or Perl test file)
au BufNewFile,BufRead *.t
	\ if !dist#ft#FTnroff() && !dist#ft#FTperl() | setf tads | endif

" Tags
au BufNewFile,BufRead tags			setf tags

" TAK
au BufNewFile,BufRead *.tak			setf tak

" Task
au BufRead,BufNewFile {pending,completed,undo}.data  setf taskdata
au BufRead,BufNewFile *.task			setf taskedit

" Tcl (JACL too)
au BufNewFile,BufRead *.tcl,*.tm,*.tk,*.itcl,*.itk,*.jacl,.tclshrc,.wishrc	setf tcl

" Teal
au BufRead,BufNewFile *.tl			setf teal

" TealInfo
au BufNewFile,BufRead *.tli			setf tli

" Telix Salt
au BufNewFile,BufRead *.slt			setf tsalt

" Tera Term Language or Turtle
au BufRead,BufNewFile *.ttl
	\ if getline(1) =~ '^@\?\(prefix\|base\)' |
	\   setf turtle |
	\ else |
	\   setf teraterm |
	\ endif

" Terminfo
au BufNewFile,BufRead *.ti			setf terminfo

" Terraform
au BufRead,BufNewFile *.tfvars			setf terraform

" TeX
au BufNewFile,BufRead *.latex,*.sty,*.dtx,*.ltx,*.bbl	setf tex
au BufNewFile,BufRead *.tex			call dist#ft#FTtex()

" ConTeXt
au BufNewFile,BufRead *.mkii,*.mkiv,*.mkvi,*.mkxl,*.mklx   setf context

" Texinfo
au BufNewFile,BufRead *.texinfo,*.texi,*.txi	setf texinfo

" TeX configuration
au BufNewFile,BufRead texmf.cnf			setf texmf

" Tidy config
au BufNewFile,BufRead .tidyrc,tidyrc,tidy.conf	setf tidy

" TF mud client
au BufNewFile,BufRead .tfrc,tfrc		setf tf

" TF mud client or terraform
au BufNewFile,BufRead *.tf			call dist#ft#FTtf()

" TLA+
au BufNewFile,BufRead *.tla			setf tla

" tmux configuration
au BufNewFile,BufRead {.,}tmux*.conf		setf tmux

" TOML
au BufNewFile,BufRead *.toml			setf toml

" TPP - Text Presentation Program
au BufNewFile,BufRead *.tpp			setf tpp

" Treetop
au BufRead,BufNewFile *.treetop			setf treetop

" Trustees
au BufNewFile,BufRead trustees.conf		setf trustees

" TSS - Geometry
au BufNewFile,BufReadPost *.tssgm		setf tssgm

" TSS - Optics
au BufNewFile,BufReadPost *.tssop		setf tssop

" TSS - Command Line (temporary)
au BufNewFile,BufReadPost *.tsscl		setf tsscl

" Tutor mode
au BufNewFile,BufReadPost *.tutor		setf tutor

" TWIG files
au BufNewFile,BufReadPost *.twig		setf twig

" Typescript or Qt translation file (which is XML)
au BufNewFile,BufReadPost *.ts
	\ if getline(1) =~ '<?xml' |
	\   setf xml |
	\ else |
	\   setf typescript |
	\ endif

" TypeScript with React
au BufNewFile,BufRead *.tsx			setf typescriptreact

" Motif UIT/UIL files
au BufNewFile,BufRead *.uit,*.uil		setf uil

" Udev conf
au BufNewFile,BufRead */etc/udev/udev.conf	setf udevconf

" Udev permissions
au BufNewFile,BufRead */etc/udev/permissions.d/*.permissions setf udevperm
"
" Udev symlinks config
au BufNewFile,BufRead */etc/udev/cdsymlinks.conf	setf sh

" UnrealScript
au BufNewFile,BufRead *.uc			setf uc

" Updatedb
au BufNewFile,BufRead */etc/updatedb.conf	setf updatedb

" Upstart (init(8)) config files
au BufNewFile,BufRead */usr/share/upstart/*.conf	       setf upstart
au BufNewFile,BufRead */usr/share/upstart/*.override	       setf upstart
au BufNewFile,BufRead */etc/init/*.conf,*/etc/init/*.override  setf upstart
au BufNewFile,BufRead */.init/*.conf,*/.init/*.override	       setf upstart
au BufNewFile,BufRead */.config/upstart/*.conf		       setf upstart
au BufNewFile,BufRead */.config/upstart/*.override	       setf upstart

" Vala
au BufNewFile,BufRead *.vala			setf vala

" Vera
au BufNewFile,BufRead *.vr,*.vri,*.vrh		setf vera

" Vagrant (uses Ruby syntax)
au BufNewFile,BufRead Vagrantfile		setf ruby

" Verilog HDL
au BufNewFile,BufRead *.v			setf verilog

" Verilog-AMS HDL
au BufNewFile,BufRead *.va,*.vams		setf verilogams

" SystemVerilog
au BufNewFile,BufRead *.sv,*.svh		setf systemverilog

" VHDL
au BufNewFile,BufRead *.hdl,*.vhd,*.vhdl,*.vbe,*.vst,*.vho  setf vhdl

" Vim script
au BufNewFile,BufRead *.vim,*.vba,.exrc,_exrc	setf vim

" Viminfo file
au BufNewFile,BufRead .viminfo,_viminfo		setf viminfo

" Virata Config Script File or Drupal module
au BufRead,BufNewFile *.hw,*.module,*.pkg
	\ if getline(1) =~ '<?php' |
	\   setf php |
	\ else |
	\   setf virata |
	\ endif

" Visual Basic (also uses *.bas) or FORM
au BufNewFile,BufRead *.frm			call dist#ft#FTfrm()

" SaxBasic is close to Visual Basic
au BufNewFile,BufRead *.sba			setf vb

" Vgrindefs file
au BufNewFile,BufRead vgrindefs			setf vgrindefs

" VRML V1.0c
au BufNewFile,BufRead *.wrl			setf vrml

" Vroom (vim testing and executable documentation)
au BufNewFile,BufRead *.vroom			setf vroom

" Vue.js Single File Component
au BufNewFile,BufRead *.vue			setf vue

" WebAssembly
au BufNewFile,BufRead *.wast,*.wat		setf wast

" Webmacro
au BufNewFile,BufRead *.wm			setf webmacro

" Wget config
au BufNewFile,BufRead .wgetrc,wgetrc		setf wget

" Website MetaLanguage
au BufNewFile,BufRead *.wml			setf wml

" Winbatch
au BufNewFile,BufRead *.wbt			setf winbatch

" WSML
au BufNewFile,BufRead *.wsml			setf wsml

" WPL
au BufNewFile,BufRead *.wpl			setf xml

" WvDial
au BufNewFile,BufRead wvdial.conf,.wvdialrc	setf wvdial

" CVS RC file
au BufNewFile,BufRead .cvsrc			setf cvsrc

" CVS commit file
au BufNewFile,BufRead cvs\d\+			setf cvs

" WEB (*.web is also used for Winbatch: Guess, based on expecting "%" comment
" lines in a WEB file).
au BufNewFile,BufRead *.web
	\ if getline(1)[0].getline(2)[0].getline(3)[0].getline(4)[0].getline(5)[0] =~ "%" |
	\   setf web |
	\ else |
	\   setf winbatch |
	\ endif

" Windows Scripting Host and Windows Script Component
au BufNewFile,BufRead *.ws[fc]			setf wsh

" XHTML
au BufNewFile,BufRead *.xhtml,*.xht		setf xhtml

" X Pixmap (dynamically sets colors, this used to trigger on BufEnter to make
" it work better, but that breaks setting 'filetype' manually)
au BufNewFile,BufRead *.xpm
	\ if getline(1) =~ "XPM2" |
	\   setf xpm2 |
	\ else |
	\   setf xpm |
	\ endif
au BufNewFile,BufRead *.xpm2			setf xpm2

" XFree86 config
au BufNewFile,BufRead XF86Config
	\ if getline(1) =~ '\<XConfigurator\>' |
	\   let b:xf86conf_xfree86_version = 3 |
	\ endif |
	\ setf xf86conf
au BufNewFile,BufRead */xorg.conf.d/*.conf
	\ let b:xf86conf_xfree86_version = 4 |
	\ setf xf86conf

" Xorg config
au BufNewFile,BufRead xorg.conf,xorg.conf-4	let b:xf86conf_xfree86_version = 4 | setf xf86conf

" Xinetd conf
au BufNewFile,BufRead */etc/xinetd.conf		setf xinetd

" XS Perl extension interface language
au BufNewFile,BufRead *.xs			setf xs

" X resources file
au BufNewFile,BufRead .Xdefaults,.Xpdefaults,.Xresources,xdm-config,*.ad setf xdefaults

" Xmath
au BufNewFile,BufRead *.msc,*.msf		setf xmath
au BufNewFile,BufRead *.ms
	\ if !dist#ft#FTnroff() | setf xmath | endif

" XML  specific variants: docbk and xbl
au BufNewFile,BufRead *.xml			call dist#ft#FTxml()

" XMI (holding UML models) is also XML
au BufNewFile,BufRead *.xmi			setf xml

" CSPROJ files are Visual Studio.NET's XML-based C# project config files
au BufNewFile,BufRead *.csproj,*.csproj.user	setf xml

" FSPROJ files are Visual Studio.NET's XML-based F# project config files
au BufNewFile,BufRead *.fsproj,*.fsproj.user	setf xml

" VBPROJ files are Visual Studio.NET's XML-based Visual Basic project config files
au BufNewFile,BufRead *.vbproj,*.vbproj.user	setf xml

" Qt Linguist translation source and Qt User Interface Files are XML
" However, for .ts Typescript is more common.
au BufNewFile,BufRead *.ui			setf xml

" TPM's are RDF-based descriptions of TeX packages (Nikolai Weibull)
au BufNewFile,BufRead *.tpm			setf xml

" Xdg menus
au BufNewFile,BufRead */etc/xdg/menus/*.menu	setf xml

" ATI graphics driver configuration
au BufNewFile,BufRead fglrxrc			setf xml

" Web Services Description Language (WSDL)
au BufNewFile,BufRead *.wsdl			setf xml

" XLIFF (XML Localisation Interchange File Format) is also XML
au BufNewFile,BufRead *.xlf			setf xml
au BufNewFile,BufRead *.xliff			setf xml

" XML User Interface Language
au BufNewFile,BufRead *.xul			setf xml

" X11 xmodmap (also see below)
au BufNewFile,BufRead *Xmodmap			setf xmodmap

" Xquery
au BufNewFile,BufRead *.xq,*.xql,*.xqm,*.xquery,*.xqy	setf xquery

" XSD
au BufNewFile,BufRead *.xsd			setf xsd

" Xslt
au BufNewFile,BufRead *.xsl,*.xslt		setf xslt

" Yacc
au BufNewFile,BufRead *.yy,*.yxx,*.y++		setf yacc

" Yacc or racc
au BufNewFile,BufRead *.y			call dist#ft#FTy()

" Yaml
au BufNewFile,BufRead *.yaml,*.yml		setf yaml

" Raml
au BufNewFile,BufRead *.raml			setf raml

" yum conf (close enough to dosini)
au BufNewFile,BufRead */etc/yum.conf		setf dosini

" YANG
au BufRead,BufNewFile *.yang			setf yang

" Zimbu
au BufNewFile,BufRead *.zu			setf zimbu
" Zimbu Templates
au BufNewFile,BufRead *.zut			setf zimbutempl

" Zope
"   dtml (zope dynamic template markup language), pt (zope page template),
"   cpt (zope form controller page template)
au BufNewFile,BufRead *.dtml,*.pt,*.cpt		call dist#ft#FThtml()
"   zsql (zope sql method)
au BufNewFile,BufRead *.zsql			call dist#ft#SQL()

" Z80 assembler asz80
au BufNewFile,BufRead *.z8a			setf z8a

augroup END


" Source the user-specified filetype file, for backwards compatibility with
" Vim 5.x.
if exists("myfiletypefile") && filereadable(expand(myfiletypefile))
  execute "source " . myfiletypefile
endif


" Check for "*" after loading myfiletypefile, so that scripts.vim is only used
" when there are no matching file name extensions.
" Don't do this for compressed files.
augroup filetypedetect
au BufNewFile,BufRead *
	\ if !did_filetype() && expand("<amatch>") !~ g:ft_ignore_pat
	\ | runtime! scripts.vim | endif
au StdinReadPost * if !did_filetype() | runtime! scripts.vim | endif


" Plain text files, needs to be far down to not override others.  This avoids
" the "conf" type being used if there is a line starting with '#'.
" But before patterns matching everything in a directory.
au BufNewFile,BufRead *.text,README,LICENSE,COPYING,AUTHORS	setf text


" Extra checks for when no filetype has been detected now.  Mostly used for
" patterns that end in "*".  E.g., "zsh*" matches "zsh.vim", but that's a Vim
" script file.
" Most of these should call s:StarSetf() to avoid names ending in .gz and the
" like are used.

" More Apache style config files
au BufNewFile,BufRead */etc/proftpd/*.conf*,*/etc/proftpd/conf.*/*	call s:StarSetf('apachestyle')
au BufNewFile,BufRead proftpd.conf*					call s:StarSetf('apachestyle')

" More Apache config files
au BufNewFile,BufRead access.conf*,apache.conf*,apache2.conf*,httpd.conf*,srm.conf*	call s:StarSetf('apache')
au BufNewFile,BufRead */etc/apache2/*.conf*,*/etc/apache2/conf.*/*,*/etc/apache2/mods-*/*,*/etc/apache2/sites-*/*,*/etc/httpd/conf.*/*,*/etc/httpd/mods-*/*,*/etc/httpd/sites-*/*,*/etc/httpd/conf.d/*.conf*		call s:StarSetf('apache')

" APT config file
au BufNewFile,BufRead */etc/apt/apt.conf.d/{[-_[:alnum:]]\+,[-_.[:alnum:]]\+.conf} call s:StarSetf('aptconf')

" Asterisk config file
au BufNewFile,BufRead *asterisk/*.conf*		call s:StarSetf('asterisk')
au BufNewFile,BufRead *asterisk*/*voicemail.conf* call s:StarSetf('asteriskvm')

" Bazaar version control
au BufNewFile,BufRead bzr_log.*			setf bzr

" Bazel build file
if !has("fname_case")
  au BufNewFile,BufRead *.BUILD,BUILD		setf bzl
endif

" BIND zone
au BufNewFile,BufRead */named/db.*,*/bind/db.*	call s:StarSetf('bindzone')

au BufNewFile,BufRead cabal.project.*		call s:StarSetf('cabalproject')

" Calendar
au BufNewFile,BufRead */.calendar/*,
	\*/share/calendar/*/calendar.*,*/share/calendar/calendar.*
	\					call s:StarSetf('calendar')

" Changelog
au BufNewFile,BufRead [cC]hange[lL]og*
	\ if getline(1) =~ '; urgency='
	\|  call s:StarSetf('debchangelog')
	\|else
	\|  call s:StarSetf('changelog')
	\|endif

" Crontab
au BufNewFile,BufRead crontab,crontab.*,*/etc/cron.d/*		call s:StarSetf('crontab')

" dnsmasq(8) configuration
au BufNewFile,BufRead */etc/dnsmasq.d/*		call s:StarSetf('dnsmasq')

" Dockerfile
au BufNewFile,BufRead Dockerfile.*,Containerfile.*	call s:StarSetf('dockerfile')

" Dracula
au BufNewFile,BufRead drac.*			call s:StarSetf('dracula')

" Fvwm
au BufNewFile,BufRead */.fvwm/*			call s:StarSetf('fvwm')
au BufNewFile,BufRead *fvwmrc*,*fvwm95*.hook
	\ let b:fvwm_version = 1 | call s:StarSetf('fvwm')
au BufNewFile,BufRead *fvwm2rc*
	\ if expand("<afile>:e") == "m4"
	\|  call s:StarSetf('fvwm2m4')
	\|else
	\|  let b:fvwm_version = 2 | call s:StarSetf('fvwm')
	\|endif

" Gedcom
au BufNewFile,BufRead */tmp/lltmp*		call s:StarSetf('gedcom')

" Git
au BufNewFile,BufRead */.gitconfig.d/*,/etc/gitconfig.d/*	call s:StarSetf('gitconfig')

" Gitolite
au BufNewFile,BufRead */gitolite-admin/conf/*	call s:StarSetf('gitolite')

" GTK RC
au BufNewFile,BufRead .gtkrc*,gtkrc*		call s:StarSetf('gtkrc')

" Jam
au BufNewFile,BufRead Prl*.*,JAM*.*		call s:StarSetf('jam')

" Jargon
au! BufNewFile,BufRead *jarg*
	\ if getline(1).getline(2).getline(3).getline(4).getline(5) =~? 'THIS IS THE JARGON FILE'
	\|  call s:StarSetf('jargon')
	\|endif

" Java Properties resource file (note: doesn't catch font.properties.pl)
au BufNewFile,BufRead *.properties_??_??_*	call s:StarSetf('jproperties')

" Kconfig
au BufNewFile,BufRead Kconfig.*			call s:StarSetf('kconfig')

" Lilo: Linux loader
au BufNewFile,BufRead lilo.conf*		call s:StarSetf('lilo')

" Libsensors
au BufNewFile,BufRead */etc/sensors.d/[^.]*	call s:StarSetf('sensors')

" Logcheck
au BufNewFile,BufRead */etc/logcheck/*.d*/*	call s:StarSetf('logcheck')

" Makefile
au BufNewFile,BufRead [mM]akefile*		call s:StarSetf('make')

" Ruby Makefile
au BufNewFile,BufRead [rR]akefile*		call s:StarSetf('ruby')

" Mail (also matches muttrc.vim, so this is below the other checks)
au BufNewFile,BufRead {neo,}mutt[[:alnum:]._-]\\\{6\}	setf mail

au BufNewFile,BufRead reportbug-*		call s:StarSetf('mail')

" Modconf
au BufNewFile,BufRead */etc/modutils/*
	\ if executable(expand("<afile>")) != 1
	\|  call s:StarSetf('modconf')
	\|endif
au BufNewFile,BufRead */etc/modprobe.*		call s:StarSetf('modconf')

" Mutt setup files (must be before catch *.rc)
au BufNewFile,BufRead */etc/Muttrc.d/*		call s:StarSetf('muttrc')

" Mutt setup file
au BufNewFile,BufRead .mutt{ng,}rc*,*/.mutt{ng,}/mutt{ng,}rc*	call s:StarSetf('muttrc')
au BufNewFile,BufRead mutt{ng,}rc*,Mutt{ng,}rc*		call s:StarSetf('muttrc')

" Neomutt setup file
au BufNewFile,BufRead .neomuttrc*,*/.neomutt/neomuttrc*	call s:StarSetf('neomuttrc')
au BufNewFile,BufRead neomuttrc*,Neomuttrc*		call s:StarSetf('neomuttrc')

" Nroff macros
au BufNewFile,BufRead tmac.*			call s:StarSetf('nroff')

" OpenBSD hostname.if
au BufNewFile,BufRead /etc/hostname.*		call s:StarSetf('config')

" Pam conf
au BufNewFile,BufRead */etc/pam.d/*		call s:StarSetf('pamconf')

" Printcap and Termcap
au BufNewFile,BufRead *printcap*
	\ if !did_filetype()
	\|  let b:ptcap_type = "print" | call s:StarSetf('ptcap')
	\|endif
au BufNewFile,BufRead *termcap*
	\ if !did_filetype()
	\|  let b:ptcap_type = "term" | call s:StarSetf('ptcap')
	\|endif

" ReDIF
" Only used when the .rdf file was not detected to be XML.
au BufRead,BufNewFile *.rdf			call dist#ft#Redif()

" Remind
au BufNewFile,BufRead .reminders*		call s:StarSetf('remind')

" SGML catalog file
au BufNewFile,BufRead sgml.catalog*		call s:StarSetf('catalog')

" avoid doc files being recognized a shell files
au BufNewFile,BufRead */doc/{,.}bash[_-]completion{,.d,.sh}{,/*} setf text

" Shell scripts ending in a star
au BufNewFile,BufRead .bashrc*,.bash[_-]profile*,.bash[_-]logout*,.bash[_-]aliases*,bash-fc[-.]*,PKGBUILD*,APKBUILD*,*/{,.}bash[_-]completion{,.d,.sh}{,/*} call dist#ft#SetFileTypeSH("bash")
au BufNewFile,BufRead .kshrc* call dist#ft#SetFileTypeSH("ksh")
au BufNewFile,BufRead .profile* call dist#ft#SetFileTypeSH(getline(1))

" Sudoers
au BufNewFile,BufRead */etc/sudoers.d/*		call s:StarSetf('sudoers')

" tcsh scripts ending in a star
au BufNewFile,BufRead .tcshrc*	call dist#ft#SetFileTypeShell("tcsh")

" csh scripts ending in a star
au BufNewFile,BufRead .login*,.cshrc*  call dist#ft#CSH()

" tmux configuration with arbitrary extension
au BufNewFile,BufRead {.,}tmux*.conf*		setf tmux

" VHDL
au BufNewFile,BufRead *.vhdl_[0-9]*		call s:StarSetf('vhdl')

" Vim script
au BufNewFile,BufRead *vimrc*			call s:StarSetf('vim')

" Subversion commit file
au BufNewFile,BufRead svn-commit*.tmp		setf svn

" X resources file
au BufNewFile,BufRead Xresources*,*/app-defaults/*,*/Xresources/* call s:StarSetf('xdefaults')

" XFree86 config
au BufNewFile,BufRead XF86Config-4*
	\ let b:xf86conf_xfree86_version = 4 | call s:StarSetf('xf86conf')
au BufNewFile,BufRead XF86Config*
	\ if getline(1) =~ '\<XConfigurator\>'
	\|  let b:xf86conf_xfree86_version = 3
	\|endif
	\|call s:StarSetf('xf86conf')

" X11 xmodmap
au BufNewFile,BufRead *xmodmap*			call s:StarSetf('xmodmap')

" Xinetd conf
au BufNewFile,BufRead */etc/xinetd.d/*		call s:StarSetf('xinetd')

" yum conf (close enough to dosini)
au BufNewFile,BufRead */etc/yum.repos.d/*	call s:StarSetf('dosini')

" Z-Shell script ending in a star
au BufNewFile,BufRead .zsh*,.zlog*,.zcompdump*  call s:StarSetf('zsh')
au BufNewFile,BufRead zsh*,zlog*		call s:StarSetf('zsh')


" Help files match *.txt but should have a last line that is a modeline. 
au BufNewFile,BufRead *.txt
        \  if getline('$') !~ 'vim:.*ft=help'
        \|   setf text
        \| endif       

if !exists('g:did_load_ftdetect')
  " Use the filetype detect plugins.  They may overrule any of the previously
  " detected filetypes.
  runtime! ftdetect/*.vim
  runtime! ftdetect/*.lua
endif

" NOTE: The above command could have ended the filetypedetect autocmd group
" and started another one. Let's make sure it has ended to get to a consistent
" state.
augroup END

" Generic configuration file. Use FALLBACK, it's just guessing!
au filetypedetect BufNewFile,BufRead,StdinReadPost *
	\ if !did_filetype() && expand("<amatch>") !~ g:ft_ignore_pat
	\    && (getline(1) =~ '^#' || getline(2) =~ '^#' || getline(3) =~ '^#'
	\	|| getline(4) =~ '^#' || getline(5) =~ '^#') |
	\   setf FALLBACK conf |
	\ endif


" If the GUI is already running, may still need to install the Syntax menu.
" Don't do it when the 'M' flag is included in 'guioptions'.
if has("menu") && has("gui_running")
      \ && !exists("did_install_syntax_menu") && &guioptions !~# "M"
  source <sfile>:p:h/menu.vim
endif

" Function called for testing all functions defined here.  These are
" script-local, thus need to be executed here.
" Returns a string with error messages (hopefully empty).
func TestFiletypeFuncs(testlist)
  let output = ''
  for f in a:testlist
    try
      exe f
    catch
      let output = output . "\n" . f . ": " . v:exception
    endtry
  endfor
  return output
endfunc

" Restore 'cpoptions'
let &cpo = s:cpo_save
unlet s:cpo_save
