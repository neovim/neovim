" Vim syntax file
" Language:	abc music notation language
" Maintainer:	James Allwright <J.R.Allwright@westminster.ac.uk>
" URL:		http://perun.hscs.wmin.ac.uk/~jra/vim/syntax/abc.vim
" Last Change:	27th April 2001

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" tags
syn region abcGuitarChord start=+"[A-G]+ end=+"+ contained
syn match abcNote "z[1-9]*[0-9]*" contained
syn match abcNote "z[1-9]*[0-9]*/[248]\=" contained
syn match abcNote "[=_\^]\{,2}[A-G],*[1-9]*[0-9]*" contained
syn match abcNote "[=_\^]\{,2}[A-G],*[1-9]*[0-9]*/[248]\=" contained
syn match abcNote "[=_\^]\{,2}[a-g]'*[1-9]*[0-9]*"  contained
syn match abcNote "[=_\^]\{,2}[a-g]'*[1-9]*[0-9]*/[248]\="  contained
syn match abcBar "|"  contained
syn match abcBar "[:|][:|]"  contained
syn match abcBar ":|2"  contained
syn match abcBar "|1"  contained
syn match abcBar "\[[12]"  contained
syn match abcTuple "([1-9]\+:\=[0-9]*:\=[0-9]*" contained
syn match abcBroken "<\|<<\|<<<\|>\|>>\|>>>" contained
syn match abcTie    "-"
syn match abcHeadField "^[A-EGHIK-TVWXZ]:.*$" contained
syn match abcBodyField "^[KLMPQWVw]:.*$" contained
syn region abcHeader start="^X:" end="^K:.*$" contained contains=abcHeadField,abcComment keepend
syn region abcTune start="^X:" end="^ *$" contains=abcHeader,abcComment,abcBar,abcNote,abcBodyField,abcGuitarChord,abcTuple,abcBroken,abcTie
syn match abcComment "%.*$"


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_abc_syn_inits")
  if version < 508
    let did_abc_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink abcComment		Comment
  HiLink abcHeadField		Type
  HiLink abcBodyField		Special
  HiLink abcBar			Statement
  HiLink abcTuple			Statement
  HiLink abcBroken			Statement
  HiLink abcTie			Statement
  HiLink abcGuitarChord	Identifier
  HiLink abcNote			Constant

  delcommand HiLink
endif

let b:current_syntax = "abc"

" vim: ts=4
