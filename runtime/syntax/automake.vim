" Vim syntax file
" Language:	automake Makefile.am
" Maintainer:   Debian VIM Maintainers <pkg-vim-maintainers@lists.alioth.debian.org>
" Former Maintainer:	John Williams <jrw@pobox.com>
" Last Change:	2011-06-13
" URL: http://anonscm.debian.org/hg/pkg-vim/vim/raw-file/unstable/runtime/syntax/automake.vim
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
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Read the Makefile syntax to start with
if version < 600
  source <sfile>:p:h/make.vim
else
  runtime! syntax/make.vim
endif

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
syn match automakeComment1 "#.*$" contains=automakeSubst
syn match automakeComment2 "##.*$"

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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_automake_syntax_inits")
  if version < 508
    let did_automake_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink automakePrimary     Statement
  HiLink automakeSecondary   Type
  HiLink automakeExtra       Special
  HiLink automakeOptions     Special
  HiLink automakeClean       Special
  HiLink automakeSubdirs     Statement
  HiLink automakeConditional PreProc
  HiLink automakeSubst       PreProc
  HiLink automakeComment1    makeComment
  HiLink automakeComment2    makeComment
  HiLink automakeMakeError   makeError
  HiLink automakeBadSubst    makeError
  HiLink automakeMakeDString makeDString
  HiLink automakeMakeSString makeSString
  HiLink automakeMakeBString makeBString

  delcommand HiLink
endif

let b:current_syntax = "automake"

" vi: ts=8 sw=4 sts=4
