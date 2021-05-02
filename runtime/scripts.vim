" Vim support file to detect file types in scripts
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last change:	2021 Jan 22

" This file is called by an autocommand for every file that has just been
" loaded into a buffer.  It checks if the type of file can be recognized by
" the file contents.  The autocommand is in $VIMRUNTIME/filetype.vim.
"
" Note that the pattern matches are done with =~# to avoid the value of the
" 'ignorecase' option making a difference.  Where case is to be ignored use
" =~? instead.  Do not use =~ anywhere.


" Only do the rest when the FileType autocommand has not been triggered yet.
if did_filetype()
  finish
endif

" Load the user defined scripts file first
" Only do this when the FileType autocommand has not been triggered yet
if exists("myscriptsfile") && filereadable(expand(myscriptsfile))
  execute "source " . myscriptsfile
  if did_filetype()
    finish
  endif
endif

" Line continuation is used here, remove 'C' from 'cpoptions'
let s:cpo_save = &cpo
set cpo&vim

let s:line1 = getline(1)

if s:line1 =~# "^#!"
  " A script that starts with "#!".

  " Check for a line like "#!/usr/bin/env {options} bash".  Turn it into
  " "#!/usr/bin/bash" to make matching easier.
  " Recognize only a few {options} that are commonly used.
  if s:line1 =~# '^#!\s*\S*\<env\s'
    let s:line1 = substitute(s:line1, '\S\+=\S\+', '', 'g')
    let s:line1 = substitute(s:line1, '\(-[iS]\|--ignore-environment\|--split-string\)', '', '')
    let s:line1 = substitute(s:line1, '\<env\s\+', '', '')
  endif

  " Get the program name.
  " Only accept spaces in PC style paths: "#!c:/program files/perl [args]".
  " If the word env is used, use the first word after the space:
  " "#!/usr/bin/env perl [path/args]"
  " If there is no path use the first word: "#!perl [path/args]".
  " Otherwise get the last word after a slash: "#!/usr/bin/perl [path/args]".
  if s:line1 =~# '^#!\s*\a:[/\\]'
    let s:name = substitute(s:line1, '^#!.*[/\\]\(\i\+\).*', '\1', '')
  elseif s:line1 =~# '^#!.*\<env\>'
    let s:name = substitute(s:line1, '^#!.*\<env\>\s\+\(\i\+\).*', '\1', '')
  elseif s:line1 =~# '^#!\s*[^/\\ ]*\>\([^/\\]\|$\)'
    let s:name = substitute(s:line1, '^#!\s*\([^/\\ ]*\>\).*', '\1', '')
  else
    let s:name = substitute(s:line1, '^#!\s*\S*[/\\]\(\i\+\).*', '\1', '')
  endif

  " tcl scripts may have #!/bin/sh in the first line and "exec wish" in the
  " third line.  Suggested by Steven Atkinson.
  if getline(3) =~# '^exec wish'
    let s:name = 'wish'
  endif

  " Bourne-like shell scripts: bash bash2 ksh ksh93 sh
  if s:name =~# '^\(bash\d*\|\|ksh\d*\|sh\)\>'
    call dist#ft#SetFileTypeSH(s:line1)	" defined in filetype.vim

    " csh scripts
  elseif s:name =~# '^csh\>'
    if exists("g:filetype_csh")
      call dist#ft#SetFileTypeShell(g:filetype_csh)
    else
      call dist#ft#SetFileTypeShell("csh")
    endif

    " tcsh scripts
  elseif s:name =~# '^tcsh\>'
    call dist#ft#SetFileTypeShell("tcsh")

    " Z shell scripts
  elseif s:name =~# '^zsh\>'
    set ft=zsh

    " TCL scripts
  elseif s:name =~# '^\(tclsh\|wish\|expectk\|itclsh\|itkwish\)\>'
    set ft=tcl

    " Expect scripts
  elseif s:name =~# '^expect\>'
    set ft=expect

    " Gnuplot scripts
  elseif s:name =~# '^gnuplot\>'
    set ft=gnuplot

    " Makefiles
  elseif s:name =~# 'make\>'
    set ft=make

    " Pike
  elseif s:name =~# '^pike\%(\>\|[0-9]\)'
    set ft=pike

    " Lua
  elseif s:name =~# 'lua'
    set ft=lua

    " Perl 6
  elseif s:name =~# 'perl6'
    set ft=perl6

    " Perl
  elseif s:name =~# 'perl'
    set ft=perl

    " PHP
  elseif s:name =~# 'php'
    set ft=php

    " Python
  elseif s:name =~# 'python'
    set ft=python

    " Groovy
  elseif s:name =~# '^groovy\>'
    set ft=groovy

    " Ruby
  elseif s:name =~# 'ruby'
    set ft=ruby

    " JavaScript
  elseif s:name =~# 'node\(js\)\=\>\|js\>' || s:name =~# 'rhino\>'
    set ft=javascript

    " BC calculator
  elseif s:name =~# '^bc\>'
    set ft=bc

    " sed
  elseif s:name =~# 'sed\>'
    set ft=sed

    " OCaml-scripts
  elseif s:name =~# 'ocaml'
    set ft=ocaml

    " Awk scripts; also finds "gawk"
  elseif s:name =~# 'awk\>'
    set ft=awk

    " Website MetaLanguage
  elseif s:name =~# 'wml'
    set ft=wml

    " Scheme scripts
  elseif s:name =~# 'scheme'
    set ft=scheme

    " CFEngine scripts
  elseif s:name =~# 'cfengine'
    set ft=cfengine

    " Erlang scripts
  elseif s:name =~# 'escript'
    set ft=erlang

    " Haskell
  elseif s:name =~# 'haskell'
    set ft=haskell

    " Scala
  elseif s:name =~# 'scala\>'
    set ft=scala

    " Clojure
  elseif s:name =~# 'clojure'
    set ft=clojure

    " Free Pascal
  elseif s:name =~# 'instantfpc\>'
    set ft=pascal

    " Fennel
  elseif s:name =~# 'fennel\>'
    set ft=fennel

  endif
  unlet s:name

else
  " File does not start with "#!".

  let s:line2 = getline(2)
  let s:line3 = getline(3)
  let s:line4 = getline(4)
  let s:line5 = getline(5)

  " Bourne-like shell scripts: sh ksh bash bash2
  if s:line1 =~# '^:$'
    call dist#ft#SetFileTypeSH(s:line1)	" defined in filetype.vim

  " Z shell scripts
  elseif s:line1 =~# '^#compdef\>' || s:line1 =~# '^#autoload\>' ||
        \ "\n".s:line1."\n".s:line2."\n".s:line3."\n".s:line4."\n".s:line5 =~# '\n\s*emulate\s\+\%(-[LR]\s\+\)\=[ckz]\=sh\>'
    set ft=zsh

  " ELM Mail files
  elseif s:line1 =~# '^From \([a-zA-Z][a-zA-Z_0-9\.=-]*\(@[^ ]*\)\=\|-\) .* \(19\|20\)\d\d$'
    set ft=mail

  " Mason
  elseif s:line1 =~# '^<[%&].*>'
    set ft=mason

  " Vim scripts (must have '" vim' as the first line to trigger this)
  elseif s:line1 =~# '^" *[vV]im$'
    set ft=vim

  " libcxx and libstdc++ standard library headers like "iostream" do not have
  " an extension, recognize the Emacs file mode.
  elseif s:line1 =~? '-\*-.*C++.*-\*-'
    set ft=cpp

  " MOO
  elseif s:line1 =~# '^\*\* LambdaMOO Database, Format Version \%([1-3]\>\)\@!\d\+ \*\*$'
    set ft=moo

    " Diff file:
    " - "diff" in first line (context diff)
    " - "Only in " in first line
    " - "--- " in first line and "+++ " in second line (unified diff).
    " - "*** " in first line and "--- " in second line (context diff).
    " - "# It was generated by makepatch " in the second line (makepatch diff).
    " - "Index: <filename>" in the first line (CVS file)
    " - "=== ", line of "=", "---", "+++ " (SVK diff)
    " - "=== ", "--- ", "+++ " (bzr diff, common case)
    " - "=== (removed|added|renamed|modified)" (bzr diff, alternative)
    " - "# HG changeset patch" in first line (Mercurial export format)
  elseif s:line1 =~# '^\(diff\>\|Only in \|\d\+\(,\d\+\)\=[cda]\d\+\>\|# It was generated by makepatch \|Index:\s\+\f\+\r\=$\|===== \f\+ \d\+\.\d\+ vs edited\|==== //\f\+#\d\+\|# HG changeset patch\)'
	\ || (s:line1 =~# '^--- ' && s:line2 =~# '^+++ ')
	\ || (s:line1 =~# '^\* looking for ' && s:line2 =~# '^\* comparing to ')
	\ || (s:line1 =~# '^\*\*\* ' && s:line2 =~# '^--- ')
	\ || (s:line1 =~# '^=== ' && ((s:line2 =~# '^=\{66\}' && s:line3 =~# '^--- ' && s:line4 =~# '^+++') || (s:line2 =~# '^--- ' && s:line3 =~# '^+++ ')))
	\ || (s:line1 =~# '^=== \(removed\|added\|renamed\|modified\)')
    set ft=diff

    " PostScript Files (must have %!PS as the first line, like a2ps output)
  elseif s:line1 =~# '^%![ \t]*PS'
    set ft=postscr

    " M4 scripts: Guess there is a line that starts with "dnl".
  elseif s:line1 =~# '^\s*dnl\>'
	\ || s:line2 =~# '^\s*dnl\>'
	\ || s:line3 =~# '^\s*dnl\>'
	\ || s:line4 =~# '^\s*dnl\>'
	\ || s:line5 =~# '^\s*dnl\>'
    set ft=m4

    " AmigaDos scripts
  elseif $TERM == "amiga"
	\ && (s:line1 =~# "^;" || s:line1 =~? '^\.bra')
    set ft=amiga

    " SiCAD scripts (must have procn or procd as the first line to trigger this)
  elseif s:line1 =~? '^ *proc[nd] *$'
    set ft=sicad

    " Purify log files start with "****  Purify"
  elseif s:line1 =~# '^\*\*\*\*  Purify'
    set ft=purifylog

    " XML
  elseif s:line1 =~# '<?\s*xml.*?>'
    set ft=xml

    " XHTML (e.g.: PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN")
  elseif s:line1 =~# '\<DTD\s\+XHTML\s'
    set ft=xhtml

    " HTML (e.g.: <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN")
    " Avoid "doctype html", used by slim.
  elseif s:line1 =~? '<!DOCTYPE\s\+html\>'
    set ft=html

    " PDF
  elseif s:line1 =~# '^%PDF-'
    set ft=pdf

    " XXD output
  elseif s:line1 =~# '^\x\{7}: \x\{2} \=\x\{2} \=\x\{2} \=\x\{2} '
    set ft=xxd

    " RCS/CVS log output
  elseif s:line1 =~# '^RCS file:' || s:line2 =~# '^RCS file:'
    set ft=rcslog

    " CVS commit
  elseif s:line2 =~# '^CVS:' || getline("$") =~# '^CVS: '
    set ft=cvs

    " Prescribe
  elseif s:line1 =~# '^!R!'
    set ft=prescribe

    " Send-pr
  elseif s:line1 =~# '^SEND-PR:'
    set ft=sendpr

    " SNNS files
  elseif s:line1 =~# '^SNNS network definition file'
    set ft=snnsnet
  elseif s:line1 =~# '^SNNS pattern definition file'
    set ft=snnspat
  elseif s:line1 =~# '^SNNS result file'
    set ft=snnsres

    " Virata
  elseif s:line1 =~# '^%.\{-}[Vv]irata'
	\ || s:line2 =~# '^%.\{-}[Vv]irata'
	\ || s:line3 =~# '^%.\{-}[Vv]irata'
	\ || s:line4 =~# '^%.\{-}[Vv]irata'
	\ || s:line5 =~# '^%.\{-}[Vv]irata'
    set ft=virata

    " Strace
  elseif s:line1 =~# '[0-9:.]* *execve(' || s:line1 =~# '^__libc_start_main'
    set ft=strace

    " VSE JCL
  elseif s:line1 =~# '^\* $$ JOB\>' || s:line1 =~# '^// *JOB\>'
    set ft=vsejcl

    " TAK and SINDA
  elseif s:line4 =~# 'K & K  Associates' || s:line2 =~# 'TAK 2000'
    set ft=takout
  elseif s:line3 =~# 'S Y S T E M S   I M P R O V E D '
    set ft=sindaout
  elseif getline(6) =~# 'Run Date: '
    set ft=takcmp
  elseif getline(9) =~# 'Node    File  1'
    set ft=sindacmp

    " DNS zone files
  elseif s:line1.s:line2.s:line3.s:line4 =~# '^; <<>> DiG [0-9.]\+.* <<>>\|$ORIGIN\|$TTL\|IN\s\+SOA'
    set ft=bindzone

    " BAAN
  elseif s:line1 =~# '|\*\{1,80}' && s:line2 =~# 'VRC '
	\ || s:line2 =~# '|\*\{1,80}' && s:line3 =~# 'VRC '
    set ft=baan

  " Valgrind
  elseif s:line1 =~# '^==\d\+== valgrind' || s:line3 =~# '^==\d\+== Using valgrind'
    set ft=valgrind

  " Go docs
  elseif s:line1 =~# '^PACKAGE DOCUMENTATION$'
    set ft=godoc

  " Renderman Interface Bytestream
  elseif s:line1 =~# '^##RenderMan'
    set ft=rib

  " Scheme scripts
  elseif s:line1 =~# 'exec\s\+\S*scheme' || s:line2 =~# 'exec\s\+\S*scheme'
    set ft=scheme

  " Git output
  elseif s:line1 =~# '^\(commit\|tree\|object\) \x\{40\}\>\|^tag \S\+$'
    set ft=git

   " Gprof (gnu profiler)
   elseif s:line1 == 'Flat profile:'
     \ && s:line2 == ''
     \ && s:line3 =~# '^Each sample counts as .* seconds.$'
     set ft=gprof

  " Erlang terms
  " (See also: http://www.gnu.org/software/emacs/manual/html_node/emacs/Choosing-Modes.html#Choosing-Modes)
  elseif s:line1 =~? '-\*-.*erlang.*-\*-'
    set ft=erlang

  " YAML
  elseif s:line1 =~# '^%YAML'
    set ft=yaml

  " CVS diff
  else
    let s:lnum = 1
    while getline(s:lnum) =~# "^? " && s:lnum < line("$")
      let s:lnum += 1
    endwhile
    if getline(s:lnum) =~# '^Index:\s\+\f\+$'
      set ft=diff

      " locale input files: Formal Definitions of Cultural Conventions
      " filename must be like en_US, fr_FR@euro or en_US.UTF-8
    elseif expand("%") =~# '\a\a_\a\a\($\|[.@]\)\|i18n$\|POSIX$\|translit_'
      let s:lnum = 1
      while s:lnum < 100 && s:lnum < line("$")
	if getline(s:lnum) =~# '^LC_\(IDENTIFICATION\|CTYPE\|COLLATE\|MONETARY\|NUMERIC\|TIME\|MESSAGES\|PAPER\|TELEPHONE\|MEASUREMENT\|NAME\|ADDRESS\)$'
	  setf fdcc
	  break
	endif
	let s:lnum += 1
      endwhile
    endif
    unlet s:lnum

  endif

  unlet s:line2 s:line3 s:line4 s:line5

endif

" Restore 'cpoptions'
let &cpo = s:cpo_save

unlet s:cpo_save s:line1
