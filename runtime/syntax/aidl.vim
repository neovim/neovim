" Vim syntax file
" Language:	aidl (Android Interface Definition Language)
"		https://developer.android.com/guide/components/aidl
" Maintainer:	Dominique Pelle <dominique.pelle@tomtom.com>
" LastChange:	2020/07/25

" Quit when a syntax file was already loaded.
if exists("b:current_syntax")
   finish
endif

source <sfile>:p:h/java.vim

syn keyword aidlParamDir in out inout
syn keyword aidlKeyword oneway parcelable

" Needed for the 'in', 'out', 'inout' keywords to be highlighted.
syn cluster javaTop add=aidlParamDir

hi def link aidlParamDir StorageClass
hi def link aidlKeyword Keyword

let b:current_syntax = "aidl"
