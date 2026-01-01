" Vim syntax file
" Language:     ChordPro 6 (https://www.chordpro.org)
" Maintainer:   Niels Bo Andersen <niels@niboan.dk>
" Last Change:  2022-04-15
" 2024 Dec 31:  add "keys" as syntax keyword (via: https://groups.google.com/g/vim_dev/c/vP4epus0euM/m/mNoDY6hsCQAJ)

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore

" Include embedded abc syntax
syn include @Abc syntax/abc.vim

" Lilypond and Pango syntaxes could be embedded as well, but they are not
" available in the distribution.

" Directives without arguments
syn keyword chordproDirective contained nextgroup=chordproConditional
  \ new_song ns
  \ start_of_chorus soc
  \ chorus
  \ start_of_verse sov
  \ start_of_bridge sob
  \ start_of_tab sot
  \ start_of_grid sog
  \ start_of_abc
  \ start_of_ly
  \ end_of_chorus eoc
  \ end_of_verse eov
  \ end_of_bridge eob
  \ end_of_tab eot
  \ end_of_grid eog
  \ end_of_abc
  \ end_of_ly
  \ new_page np
  \ new_physical_page npp
  \ column_break cb
  \ grid g
  \ no_grid ng
  \ transpose
  \ chordfont cf chordsize cs chordcolour
  \ footerfont footersize footercolour
  \ gridfont gridsize gridcolour
  \ tabfont tabsize tabcolour
  \ tocfont tocsize toccolour
  \ textfont tf textsize ts textcolour
  \ titlefont titlesize titlecolour

" Directives with arguments. Some directives are in both groups, as they can
" be used both with and without arguments
syn keyword chordproDirWithArg contained nextgroup=chordproConditional
  \ title t
  \ subtitle st
  \ sorttitle
  \ artist
  \ composer
  \ lyricist
  \ arranger
  \ copyright
  \ album
  \ year
  \ key
  \ time
  \ tempo
  \ duration
  \ capo
  \ comment c
  \ highlight
  \ comment_italic ci
  \ comment_box cb
  \ image
  \ start_of_chorus soc
  \ chorus
  \ start_of_verse sov
  \ start_of_bridge sob
  \ start_of_tab sot
  \ start_of_grid sog
  \ start_of_abc
  \ start_of_ly
  \ define
  \ chord
  \ transpose
  \ chordfont cf chordsize cs chordcolour
  \ footerfont footersize footercolour
  \ gridfont gridsize gridcolour
  \ tabfont tabsize tabcolour
  \ tocfont tocsize toccolour
  \ textfont tf textsize ts textcolour
  \ titlefont titlesize titlecolour
  \ pagetype
  \ titles
  \ columns col

syn keyword chordproMetaKeyword contained meta
syn keyword chordproMetadata contained title sorttitle subtitle artist composer lyricist arranger copyright album year key time tempo duration capo
syn keyword chordproStandardMetadata contained songindex page pages pagerange today tuning instrument user
syn match chordproStandardMetadata /instrument\.type/ contained
syn match chordproStandardMetadata /instrument\.description/ contained
syn match chordproStandardMetadata /user\.name/ contained
syn match chordproStandardMetadata /user\.fullname/ contained

syn keyword chordproDefineKeyword contained frets fingers keys
syn match chordproDefineKeyword /base-fret/ contained

syn match chordproArgumentsNumber /\d\+/ contained

syn match chordproCustom /x_\w\+/ contained

syn match chordproDirMatch /{\w\+\(-\w\+\)\?}/ contains=chordproDirective contained transparent
syn match chordproDirArgMatch /{\w\+\(-\w\+\)\?[: ]/ contains=chordproDirWithArg contained transparent
syn match chordproMetaMatch /{meta\(-\w\+\)\?[: ]\+\w\+/ contains=chordproMetaKeyword,chordproMetadata contained transparent
syn match chordproCustomMatch /{x_\w\+\(-\w\+\)\?[: ]/ contains=chordproCustom contained transparent

syn match chordproConditional /-\w\+/ contained

syn match chordproMetaDataOperator /[=|]/ contained
syn match chordproMetaDataValue /%{\w*/ contains=chordproMetaData,chordproStandardMetadata contained transparent
" Handles nested metadata tags, but the end of the containing chordproTag is
" not highlighted correctly, if there are more than two levels of nesting
syn region chordproMetaDataTag start=/%{\w*/ skip=/%{[^}]*}/ end=/}/ contains=chordproMetaDataValue,chordproMetaDataOperator,chordproMetadataTag contained

syn region chordproArguments start=/{\w\+\(-\w\+\)\?[: ]/hs=e+1 skip=/%{[^}]*}/ end=/}/he=s-1 contains=chordproDirArgMatch,chordproArgumentsNumber,chordproMetaDataTag contained
syn region chordproArguments start=/{\(define\|chord\)\(-\w\+\)\?[: ]/hs=e+1 end=/}/he=s-1 contains=chordproDirArgMatch,chordproDefineKeyword,chordproArgumentsNumber contained
syn region chordproArguments start=/{meta\(-\w\+\)\?[: ]/hs=e+1 skip=/%{[^}]*}/ end=/}/he=s-1 contains=chordproMetaMatch,chordproMetaDataTag contained
syn region chordproArguments start=/{x_\w\+\(-\w\+\)\?[: ]/hs=e+1 end=/}/he=s-1 contains=chordproCustomMatch contained

syn region chordproTag start=/{/ skip=/%{[^}]*}/ end=/}/ contains=chordproDirMatch,chordproArguments oneline

syn region chordproChord matchgroup=chordproBracket start=/\[/ end=/]/ oneline

syn region chordproAnnotation matchgroup=chordproBracket start=/\[\*/ end=/]/ oneline

syn region chordproTab start=/{start_of_tab\(-\w\+\)\?\([: ].\+\)\?}\|{sot\(-\w\+\)\?\([: ].\+\)\?}/hs=e+1 end=/{end_of_tab}\|{eot}/me=s-1 contains=chordproTag,chordproComment keepend

syn region chordproChorus start=/{start_of_chorus\(-\w\+\)\?\([: ].\+\)\?}\|{soc\(-\w\+\)\?\([: ].\+\)\?}/hs=e+1 end=/{end_of_chorus}\|{eoc}/me=s-1 contains=chordproTag,chordproChord,chordproAnnotation,chordproComment keepend

syn region chordproBridge start=/{start_of_bridge\(-\w\+\)\?\([: ].\+\)\?}\|{sob\(-\w\+\)\?\([: ].\+\)\?}/hs=e+1 end=/{end_of_bridge}\|{eob}/me=s-1 contains=chordproTag,chordproChord,chordproAnnotation,chordproComment keepend

syn region chordproAbc start=/{start_of_abc\(-\w\+\)\?\([: ].\+\)\?}/hs=e+1 end=/{end_of_abc}/me=s-1 contains=chordproTag,@Abc keepend

syn match chordproComment /^#.*/

" Define the default highlighting.
hi def link chordproDirective Statement
hi def link chordproDirWithArg Statement
hi def link chordproConditional Statement
hi def link chordproCustom Statement
hi def link chordproMetaKeyword Statement
hi def link chordproMetaDataOperator Operator
hi def link chordproMetaDataTag Function
hi def link chordproArguments Special
hi def link chordproArgumentsNumber Number
hi def link chordproChord Type
hi def link chordproAnnotation Identifier
hi def link chordproTag Constant
hi def link chordproTab PreProc
hi def link chordproComment Comment
hi def link chordproBracket Constant
hi def link chordproDefineKeyword Identifier
hi def link chordproMetadata Identifier
hi def link chordproStandardMetadata Identifier
hi def chordproChorus term=bold cterm=bold gui=bold
hi def chordproBridge term=italic cterm=italic gui=italic

let b:current_syntax = "chordpro"

let &cpo = s:cpo_save
unlet s:cpo_save
