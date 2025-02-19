" Vim syntax file
" Language: automake Makefile.am
" Maintainer: Debian Vim Maintainers
" Former Maintainer: John Williams <jrw@pobox.com>
" Last Change: 2023 Jan 16
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/automake.vim
"
" XXX This file is in need of a new maintainer, Debian VIM Maintainers maintain
"     it only because patches have been submitted for it by Debian users and the
"     former maintainer was MIA (Missing In Action), taking over its
"     maintenance was thus the only way to include those patches.
"     If you care about this file, and have time to maintain it please do so!
"
" This script adds support for automake's Makefile.am format. It highlights
" Makefile variables significant to automake as well as highlighting
" autoconf-style @variable@ substitutions . Subsitutions are marked as errors
" when they are used in an inappropriate place, such as in defining
" EXTRA_SOURCES.

" Standard syntax initialization
if exists('b:current_syntax')
  finish
endif

" Read the Makefile syntax to start with
runtime! syntax/make.vim

syn match automakePrimary "^\w\+\(_PROGRAMS\|_LIBRARIES\|_LISP\|_PYTHON\|_JAVA\|_SCRIPTS\|_DATA\|_HEADERS\|_MANS\|_TEXINFOS\|_LTLIBRARIES\)\s*\ze+\=="
syn match automakePrimary "^TESTS\s*\ze+\=="me=e-1
syn match automakeSecondary "^\w\+\(_SOURCES\|_LIBADD\|_LDADD\|_LDFLAGS\|_DEPENDENCIES\|_AR\|_CCASFLAGS\|_CFLAGS\|_CPPFLAGS\|_CXXFLAGS\|_FCFLAGS\|_FFLAGS\|_GCJFLAGS\|_LFLAGS\|_LIBTOOLFLAGS\|OBJCFLAGS\|RFLAGS\|UPCFLAGS\|YFLAGS\)\s*\ze+\=="
syn match automakeSecondary "^\(LDADD\|ARFLAGS\|OMIT_DEPENDENCIES\|AM_MAKEFLAGS\|\(AM_\)\=\(MAKEINFOFLAGS\|RUNTESTDEFAULTFLAGS\|ETAGSFLAGS\|CTAGSFLAGS\|JAVACFLAGS\)\)\s*\ze+\=="
syn match automakeExtra "^EXTRA_\w\+\s*\ze+\=="
syn match automakeOptions "^\(ACLOCAL_AMFLAGS\|AUTOMAKE_OPTIONS\|DISTCHECK_CONFIGURE_FLAGS\|ETAGS_ARGS\|TAGS_DEPENDENCIES\)\s*\ze+\=="
syn match automakeClean "^\(MOSTLY\|DIST\|MAINTAINER\)\=CLEANFILES\s*\ze+\=="
syn match automakeSubdirs "^\(DIST_\)\=SUBDIRS\s*\ze+\=="
syn match automakeConditional "^\(if\s*!\=\w\+\|else\|endif\)\s*$"

syn match automakeSubst     "@\w\+@"
syn match automakeSubst     "^\s*@\w\+@"
syn match automakeComment1 "#.*$" contains=automakeSubst,@Spell
syn match automakeComment2 "##.*$" contains=@Spell

syn match automakeMakeError "$[{(][^})]*[^a-zA-Z0-9_})][^})]*[})]" " GNU make function call
syn match automakeMakeError "^AM_LDADD\s*\ze+\==" " Common mistake

syn region automakeNoSubst start="^EXTRA_\w*\s*+\==" end="$" contains=ALLBUT,automakeNoSubst transparent
syn region automakeNoSubst start="^DIST_SUBDIRS\s*+\==" end="$" contains=ALLBUT,automakeNoSubst transparent
syn region automakeNoSubst start="^\w*_SOURCES\s*+\==" end="$" contains=ALLBUT,automakeNoSubst transparent
syn match automakeBadSubst  "@\(\w*@\=\)\=" contained

syn region  automakeMakeDString start=+"+  skip=+\\"+  end=+"+  contains=makeIdent,automakeSubstitution
syn region  automakeMakeSString start=+'+  skip=+\\'+  end=+'+  contains=makeIdent,automakeSubstitution
syn region  automakeMakeBString start=+`+  skip=+\\`+  end=+`+  contains=makeIdent,makeSString,makeDString,makeNextLine,automakeSubstitution

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link automakePrimary     Statement
hi def link automakeSecondary   Type
hi def link automakeExtra       Special
hi def link automakeOptions     Special
hi def link automakeClean       Special
hi def link automakeSubdirs     Statement
hi def link automakeConditional PreProc
hi def link automakeSubst       PreProc
hi def link automakeComment1    makeComment
hi def link automakeComment2    makeComment
hi def link automakeMakeError   makeError
hi def link automakeBadSubst    makeError
hi def link automakeMakeDString makeDString
hi def link automakeMakeSString makeSString
hi def link automakeMakeBString makeBString


let b:current_syntax = 'automake'

" vi: ts=8 sw=4 sts=4
