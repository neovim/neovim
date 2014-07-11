" Vim syntax file
" Language:     ChordPro (v. 3.6.2)
" Maintainer:   Niels Bo Andersen <niels@niboan.dk>
" Last Change:	2006 Apr 30
" Remark:       Requires VIM version 6.00 or greater

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-

syn case ignore

syn keyword chordproDirective contained
  \ start_of_chorus soc end_of_chorus eoc new_song ns no_grid ng grid g
  \ new_page np new_physical_page npp start_of_tab sot end_of_tab eot
  \ column_break colb

syn keyword chordproDirWithOpt contained
  \ comment c comment_italic ci comment_box cb title t subtitle st define
  \ textfont textsize chordfont chordsize columns col

syn keyword chordproDefineKeyword contained base-fret frets

syn match chordproDirMatch /{\w*}/ contains=chordproDirective contained transparent
syn match chordproDirOptMatch /{\w*:/ contains=chordproDirWithOpt contained transparent

" Workaround for a bug in VIM 6, which causes incorrect coloring of the first {
if version < 700
  syn region chordproOptions start=/{\w*:/ end=/}/ contains=chordproDirOptMatch contained transparent
  syn region chordproOptions start=/{define:/ end=/}/ contains=chordproDirOptMatch, chordproDefineKeyword contained transparent
else
  syn region chordproOptions start=/{\w*:/hs=e+1 end=/}/he=s-1 contains=chordproDirOptMatch contained
  syn region chordproOptions start=/{define:/hs=e+1 end=/}/he=s-1 contains=chordproDirOptMatch, chordproDefineKeyword contained
endif

syn region chordproTag start=/{/ end=/}/ contains=chordproDirMatch,chordproOptions oneline

syn region chordproChord matchgroup=chordproBracket start=/\[/ end=/]/ oneline

syn region chordproTab start=/{start_of_tab}\|{sot}/hs=e+1 end=/{end_of_tab}\|{eot}/he=s-1 contains=chordproTag,chordproComment keepend

syn region chordproChorus start=/{start_of_chorus}\|{soc}/hs=e+1 end=/{end_of_chorus}\|{eoc}/he=s-1 contains=chordproTag,chordproChord,chordproComment keepend

syn match chordproComment /^#.*/

" Define the default highlighting.
hi def link chordproDirective Statement
hi def link chordproDirWithOpt Statement
hi def link chordproOptions Special
hi def link chordproChord Type
hi def link chordproTag Constant
hi def link chordproTab PreProc
hi def link chordproComment Comment
hi def link chordproBracket Constant
hi def link chordproDefineKeyword Type
hi def chordproChorus term=bold cterm=bold gui=bold

let b:current_syntax = "chordpro"

let &cpo = s:cpo_save
unlet s:cpo_save
