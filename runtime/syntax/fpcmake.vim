" Vim syntax file
" Language:	Free Pascal Makefile Definition Files
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 Apr 23

if exists("b:current_syntax")
  finish
endif

runtime! syntax/make.vim

" NOTE: using start-of-line anchored syn-match groups is simpler than other
"	alternatives when interacting with the sourced make.vim syntax groups

" Sections
syn region fpcmakeSection matchgroup=fpcmakeSectionDelimiter start="^\s*\[" end="]" contains=fpcmakeSectionName

syn keyword fpcmakeSectionName contained clean compiler default dist install
syn keyword fpcmakeSectionName contained lib package prerules require rules
syn keyword fpcmakeSectionName contained shared target

" [clean]
syn match fpcmakeRule "^\s*\(units\|files\)\>"
" [compiler]
syn match fpcmakeRule "^\s*\(options\|version\|unitdir\|librarydir\|objectdir\)\>"
syn match fpcmakeRule "^\s*\(targetdir\|sourcedir\|unittargetdir\|includedir\)\>"
" [default]
syn match fpcmakeRule "^\s*\(cpu\|dir\|fpcdir\|rule\|target\)\>"
" [dist]
syn match fpcmakeRule "^\s*\(destdir\|zipname\|ziptarget\)\>"
" [install]
syn match fpcmakeRule "^\s*\(basedir\|datadir\|fpcpackage\|files\|prefix\)\>"
syn match fpcmakeRule "^\s*\(units\)\>"
" [package]
syn match fpcmakeRule "^\s*\(name\|version\|main\)\>"
" [requires]
syn match fpcmakeRule "^\s*\(fpcmake\|packages\|libc\|nortl\|unitdir\)\>"
syn match fpcmakeRule "^\s*\(packagedir\|tools\)\>"
" [shared]
syn match fpcmakeRule "^\s*\(build\|libname\|libversion\|libunits\)\>"
" [target]
syn match fpcmakeRule "^\s*\(dirs\|exampledirs\|examples\|loaders\|programs\)\>"
syn match fpcmakeRule "^\s*\(rsts\|units\)\>"

" Comments
syn keyword fpcmakeTodo    TODO FIXME XXX contained
syn match   fpcmakeComment "#.*" contains=fpcmakeTodo,@Spell

" Default highlighting
hi def link fpcmakeSectionDelimiter	Delimiter
hi def link fpcmakeSectionName		Type
hi def link fpcmakeComment		Comment
hi def link fpcmakeTodo			Todo
hi def link fpcmakeRule			Identifier

let b:current_syntax = "fpcmake"

" vim: nowrap sw=2 sts=2 ts=8 noet:
