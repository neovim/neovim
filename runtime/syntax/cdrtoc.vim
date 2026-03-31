" Vim syntax file
" Language:             cdrdao(1) TOC file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2007-05-10

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword cdrtocTodo
      \ contained
      \ TODO
      \ FIXME
      \ XXX
      \ NOTE

syn cluster cdrtocCommentContents
      \ contains=
      \   cdrtocTodo,
      \   @Spell

syn cluster cdrtocHeaderFollowsInitial
      \ contains=
      \   cdrtocHeaderCommentInitial,
      \   cdrtocHeaderCatalog,
      \   cdrtocHeaderTOCType,
      \   cdrtocHeaderCDText,
      \   cdrtocTrack

syn match   cdrtocHeaderBegin
      \ nextgroup=@cdrtocHeaderFollowsInitial
      \ skipwhite skipempty
      \ '\%^'

let s:mmssff_pattern = '\%([0-5]\d\|\d\):\%([0-5]\d\|\d\):\%([0-6]\d\|7[0-5]\|\d\)\>'
let s:byte_pattern = '\<\%([01]\=\d\{1,2}\|2\%([0-4]\d\|5[0-5]\)\)\>'
let s:length_pattern = '\%(\%([0-5]\d\|\d\):\%([0-5]\d\|\d\):\%([0-6]\d\|7[0-5]\|\d\)\|\d\+\)\>'

function s:def_comment(name, nextgroup)
  execute 'syn match' a:name
        \ 'nextgroup=' . a:nextgroup . ',' . a:name
        \ 'skipwhite skipempty'
        \ 'contains=@cdrtocCommentContents'
        \ 'contained'
        \ "'//.*$'"
  execute 'hi def link' a:name 'cdrtocComment'
endfunction

function s:def_keywords(name, nextgroup, keywords)
  let comment_group = a:name . 'FollowComment'
  execute 'syn keyword' a:name
        \ 'nextgroup=' . a:nextgroup . ',' . comment_group
        \ 'skipwhite skipempty'
        \ 'contained'
        \ join(a:keywords)

  call s:def_comment(comment_group, a:nextgroup)
endfunction

function s:def_keyword(name, nextgroup, keyword)
  call s:def_keywords(a:name, a:nextgroup, [a:keyword])
endfunction

" NOTE: Pattern needs to escape any “@”s.
function s:def_match(name, nextgroup, pattern)
  let comment_group = a:name . 'FollowComment'
  execute 'syn match' a:name
        \ 'nextgroup=' . a:nextgroup . ',' . comment_group
        \ 'skipwhite skipempty'
        \ 'contained'
        \ '@' . a:pattern . '@'

  call s:def_comment(comment_group, a:nextgroup)
endfunction

function s:def_region(name, nextgroup, start, skip, end, matchgroup, contains)
  let comment_group = a:name . 'FollowComment'
  execute 'syn region' a:name
        \ 'nextgroup=' . a:nextgroup . ',' . comment_group
        \ 'skipwhite skipempty'
        \ 'contained'
        \ 'matchgroup=' . a:matchgroup
        \ 'contains=' . a:contains
        \ 'start=@' . a:start . '@'
        \ (a:skip != "" ? ('skip=@' . a:skip . '@') : "")
        \ 'end=@' . a:end . '@'

  call s:def_comment(comment_group, a:nextgroup)
endfunction

call s:def_comment('cdrtocHeaderCommentInitial', '@cdrtocHeaderFollowsInitial')

call s:def_keyword('cdrtocHeaderCatalog', 'cdrtocHeaderCatalogNumber', 'CATALOG')

call s:def_match('cdrtocHeaderCatalogNumber', '@cdrtocHeaderFollowsInitial', '"\d\{13\}"')

call s:def_keywords('cdrtocHeaderTOCType', '@cdrtocHeaderFollowsInitial', ['CD_DA', 'CD_ROM', 'CD_ROM_XA'])

call s:def_keyword('cdrtocHeaderCDText', 'cdrtocHeaderCDTextStart', 'CD_TEXT')

" TODO: Actually, language maps aren’t required by TocParser.g, but let’s keep
" things simple (and in agreement with what the manual page says).
call s:def_match('cdrtocHeaderCDTextStart', 'cdrtocHeaderCDTextLanguageMap', '{')

call s:def_keyword('cdrtocHeaderCDTextLanguageMap', 'cdrtocHeaderLanguageMapStart', 'LANGUAGE_MAP')

call s:def_match('cdrtocHeaderLanguageMapStart', 'cdrtocHeaderLanguageMapLanguageNumber', '{')

call s:def_match('cdrtocHeaderLanguageMapLanguageNumber', 'cdrtocHeaderLanguageMapColon', '\<[0-7]\>')

call s:def_match('cdrtocHeaderLanguageMapColon', 'cdrtocHeaderLanguageMapCountryCode,cdrtocHeaderLanguageMapCountryCodeName', ':')

syn cluster cdrtocHeaderLanguageMapCountryCodeFollow
      \ contains=
      \   cdrtocHeaderLanguageMapLanguageNumber,
      \   cdrtocHeaderLanguageMapEnd

call s:def_match('cdrtocHeaderLanguageMapCountryCode',
               \ '@cdrtocHeaderLanguageMapCountryCodeFollow',
               \ s:byte_pattern)

call s:def_keyword('cdrtocHeaderLanguageMapCountryCodeName',
                 \ '@cdrtocHeaderLanguageMapCountryCodeFollow',
                 \ 'EN')

call s:def_match('cdrtocHeaderLanguageMapEnd',
               \ 'cdrtocHeaderLanguage,cdrtocHeaderCDTextEnd',
               \ '}')

call s:def_keyword('cdrtocHeaderLanguage', 'cdrtocHeaderLanguageNumber', 'LANGUAGE')

call s:def_match('cdrtocHeaderLanguageNumber', 'cdrtocHeaderLanguageStart', '\<[0-7]\>')

call s:def_match('cdrtocHeaderLanguageStart',
               \ 'cdrtocHeaderCDTextItem,cdrtocHeaderLanguageEnd',
               \ '{')

syn cluster cdrtocHeaderCDTextData
      \ contains=
      \   cdrtocHeaderCDTextDataString,
      \   cdrtocHeaderCDTextDataBinaryStart

call s:def_keywords('cdrtocHeaderCDTextItem',
                  \ '@cdrtocHeaderCDTextData',
                  \ ['TITLE', 'PERFORMER', 'SONGWRITER', 'COMPOSER',
                  \  'ARRANGER', 'MESSAGE', 'DISC_ID', 'GENRE', 'TOC_INFO1',
                  \  'TOC_INFO2', 'UPC_EAN', 'ISRC', 'SIZE_INFO'])

call s:def_region('cdrtocHeaderCDTextDataString',
                \ 'cdrtocHeaderCDTextItem,cdrtocHeaderLanguageEnd',
                \ '"',
                \ '\\\\\|\\"',
                \ '"',
                \ 'cdrtocHeaderCDTextDataStringDelimiters',
                \ 'cdrtocHeaderCDTextDataStringSpecialChar')

syn match   cdrtocHeaderCDTextDataStringSpecialChar
      \ contained
      \ display
      \ '\\\%(\o\o\o\|["\\]\)'

call s:def_match('cdrtocHeaderCDTextDataBinaryStart',
               \ 'cdrtocHeaderCDTextDataBinaryInteger',
               \ '{')

call s:def_match('cdrtocHeaderCDTextDataBinaryInteger',
               \ 'cdrtocHeaderCDTextDataBinarySeparator,cdrtocHeaderCDTextDataBinaryEnd',
               \ s:byte_pattern)

call s:def_match('cdrtocHeaderCDTextDataBinarySeparator',
               \ 'cdrtocHeaderCDTextDataBinaryInteger',
               \ ',')

call s:def_match('cdrtocHeaderCDTextDataBinaryEnd',
               \ 'cdrtocHeaderCDTextItem,cdrtocHeaderLanguageEnd',
               \ '}')

call s:def_match('cdrtocHeaderLanguageEnd',
               \ 'cdrtocHeaderLanguage,cdrtocHeaderCDTextEnd',
               \ '}')

call s:def_match('cdrtocHeaderCDTextEnd',
               \ 'cdrtocTrack',
               \ '}')

syn cluster cdrtocTrackFollow
      \ contains=
      \   @cdrtocTrackFlags,
      \   cdrtocTrackCDText,
      \   cdrtocTrackPregap,
      \   @cdrtocTrackContents

call s:def_keyword('cdrtocTrack', 'cdrtocTrackMode', 'TRACK')

call s:def_keywords('cdrtocTrackMode',
                  \ 'cdrtocTrackSubChannelMode,@cdrtocTrackFollow',
                  \ ['AUDIO', 'MODE1', 'MODE1_RAW', 'MODE2', 'MODE2_FORM1',
                  \  'MODE2_FORM2', 'MODE2_FORM_MIX', 'MODE2_RAW'])

call s:def_keywords('cdrtocTrackSubChannelMode',
                  \ '@cdrtocTrackFollow',
                  \ ['RW', 'RW_RAW'])

syn cluster cdrtocTrackFlags
      \ contains=
      \   cdrtocTrackFlagNo,
      \   cdrtocTrackFlagCopy,
      \   cdrtocTrackFlagPreEmphasis,
      \   cdrtocTrackFlag

call s:def_keyword('cdrtocTrackFlagNo',
                 \ 'cdrtocTrackFlagCopy,cdrtocTrackFlagPreEmphasis',
                 \ 'NO')

call s:def_keyword('cdrtocTrackFlagCopy', '@cdrtocTrackFollow', 'COPY')

call s:def_keyword('cdrtocTrackFlagPreEmphasis', '@cdrtocTrackFollow', 'PRE_EMPHASIS')

call s:def_keywords('cdrtocTrackFlag',
                  \ '@cdrtocTrackFollow',
                  \ ['TWO_CHANNEL_AUDIO', 'FOUR_CHANNEL_AUDIO'])

call s:def_keyword('cdrtocTrackFlag', 'cdrtocTrackISRC', 'ISRC')

call s:def_match('cdrtocTrackISRC',
               \ '@cdrtocTrackFollow',
               \ '"[[:upper:][:digit:]]\{5}\d\{7}"')

call s:def_keyword('cdrtocTrackCDText', 'cdrtocTrackCDTextStart', 'CD_TEXT')

call s:def_match('cdrtocTrackCDTextStart', 'cdrtocTrackCDTextLanguage', '{')

call s:def_keyword('cdrtocTrackCDTextLanguage', 'cdrtocTrackCDTextLanguageNumber', 'LANGUAGE')

call s:def_match('cdrtocTrackCDTextLanguageNumber', 'cdrtocTrackCDTextLanguageStart', '\<[0-7]\>')

call s:def_match('cdrtocTrackCDTextLanguageStart',
               \ 'cdrtocTrackCDTextItem,cdrtocTrackCDTextLanguageEnd',
               \ '{')

syn cluster cdrtocTrackCDTextData
      \ contains=
      \   cdrtocTrackCDTextDataString,
      \   cdrtocTrackCDTextDataBinaryStart

call s:def_keywords('cdrtocTrackCDTextItem',
                  \ '@cdrtocTrackCDTextData',
                  \ ['TITLE', 'PERFORMER', 'SONGWRITER', 'COMPOSER', 'ARRANGER',
                  \  'MESSAGE', 'ISRC'])

call s:def_region('cdrtocTrackCDTextDataString',
                \ 'cdrtocTrackCDTextItem,cdrtocTrackCDTextLanguageEnd',
                \ '"',
                \ '\\\\\|\\"',
                \ '"',
                \ 'cdrtocTrackCDTextDataStringDelimiters',
                \ 'cdrtocTrackCDTextDataStringSpecialChar')

syn match   cdrtocTrackCDTextDataStringSpecialChar
      \ contained
      \ display
      \ '\\\%(\o\o\o\|["\\]\)'

call s:def_match('cdrtocTrackCDTextDataBinaryStart',
               \ 'cdrtocTrackCDTextDataBinaryInteger',
               \ '{')

call s:def_match('cdrtocTrackCDTextDataBinaryInteger',
               \ 'cdrtocTrackCDTextDataBinarySeparator,cdrtocTrackCDTextDataBinaryEnd',
               \ s:byte_pattern)

call s:def_match('cdrtocTrackCDTextDataBinarySeparator',
               \ 'cdrtocTrackCDTextDataBinaryInteger',
               \ ',')

call s:def_match('cdrtocTrackCDTextDataBinaryEnd',
               \ 'cdrtocTrackCDTextItem,cdrtocTrackCDTextLanguageEnd',
               \ '}')

call s:def_match('cdrtocTrackCDTextLanguageEnd',
               \ 'cdrtocTrackCDTextLanguage,cdrtocTrackCDTextEnd',
               \ '}')

call s:def_match('cdrtocTrackCDTextEnd',
               \ 'cdrtocTrackPregap,@cdrtocTrackContents',
               \ '}')

call s:def_keyword('cdrtocTrackPregap', 'cdrtocTrackPregapMMSSFF', 'PREGAP')

call s:def_match('cdrtocTrackPregapMMSSFF',
               \ '@cdrtocTrackContents',
               \ s:mmssff_pattern)

syn cluster cdrtocTrackContents
      \ contains=
      \   cdrtocTrackSubTrack,
      \   cdrtocTrackMarker

syn cluster cdrtocTrackContentsFollow
      \ contains=
      \   @cdrtocTrackContents,
      \   cdrtocTrackIndex,
      \   cdrtocTrack

call s:def_keywords('cdrtocTrackSubTrack',
                  \ 'cdrtocTrackSubTrackFileFilename',
                  \ ['FILE', 'AUDIOFILE'])

call s:def_region('cdrtocTrackSubTrackFileFilename',
                \ 'cdrtocTrackSubTrackFileStart',
                \ '"',
                \ '\\\\\|\\"',
                \ '"',
                \ 'cdrtocTrackSubTrackFileFilenameDelimiters',
                \ 'cdrtocTrackSubTrackFileFilenameSpecialChar')

syn match   cdrtocTrackSubTrackFileFilenameSpecialChar
      \ contained
      \ display
      \ '\\\%(\o\o\o\|["\\]\)'

call s:def_match('cdrtocTrackSubTrackFileStart',
               \ 'cdrtocTrackSubTrackFileLength,@cdrtocTrackContentsFollow',
               \ s:length_pattern)

call s:def_match('cdrtocTrackSubTrackFileLength',
               \ '@cdrtocTrackContentsFollow',
               \ s:length_pattern)

call s:def_keyword('cdrtocTrackSubTrack', 'cdrtocTrackContentDatafileFilename', 'DATAFILE')

call s:def_region('cdrtocTrackSubTrackDatafileFilename',
                \ 'cdrtocTrackSubTrackDatafileLength',
                \ '"',
                \ '\\\\\|\\"',
                \ '"',
                \ 'cdrtocTrackSubTrackDatafileFilenameDelimiters',
                \ 'cdrtocTrackSubTrackDatafileFilenameSpecialChar')

syn match   cdrtocTrackSubTrackdatafileFilenameSpecialChar
      \ contained
      \ display
      \ '\\\%(\o\o\o\|["\\]\)'

call s:def_match('cdrtocTrackDatafileLength',
               \ '@cdrtocTrackContentsFollow',
               \ s:length_pattern)

call s:def_keyword('cdrtocTrackSubTrack', 'cdrtocTrackContentFifoFilename', 'DATAFILE')

call s:def_region('cdrtocTrackSubTrackFifoFilename',
                \ 'cdrtocTrackSubTrackFifoLength',
                \ '"',
                \ '\\\\\|\\"',
                \ '"',
                \ 'cdrtocTrackSubTrackFifoFilenameDelimiters',
                \ 'cdrtocTrackSubTrackFifoFilenameSpecialChar')

syn match   cdrtocTrackSubTrackdatafileFilenameSpecialChar
      \ contained
      \ display
      \ '\\\%(\o\o\o\|["\\]\)'

call s:def_match('cdrtocTrackFifoLength',
               \ '@cdrtocTrackContentsFollow',
               \ s:length_pattern)

call s:def_keyword('cdrtocTrackSubTrack', 'cdrtocTrackSilenceLength', 'SILENCE')

call s:def_match('cdrtocTrackSilenceLength',
               \ '@cdrtocTrackContentsFollow',
               \ s:length_pattern)

call s:def_keyword('cdrtocTrackSubTrack',
                 \ 'cdrtocTrackSubTrackZeroDataMode,' .
                 \ 'cdrtocTrackSubTrackZeroDataSubChannelMode,' .
                 \ 'cdrtocTrackSubTrackZeroDataLength',
                 \ 'ZERO')

call s:def_keywords('cdrtocTrackSubTrackZeroDataMode',
                  \ 'cdrtocTrackSubTrackZeroSubChannelMode,cdrtocTrackSubTrackZeroDataLength',
                  \ ['AUDIO', 'MODE1', 'MODE1_RAW', 'MODE2', 'MODE2_FORM1',
                  \  'MODE2_FORM2', 'MODE2_FORM_MIX', 'MODE2_RAW'])

call s:def_keywords('cdrtocTrackSubTrackZeroDataSubChannelMode',
                  \ 'cdrtocTrackSubTrackZeroDataLength',
                  \ ['RW', 'RW_RAW'])

call s:def_match('cdrtocTrackSubTrackZeroDataLength',
               \ '@cdrtocTrackContentsFollow',
               \ s:length_pattern)

call s:def_keyword('cdrtocTrackMarker',
                 \ '@cdrtocTrackContentsFollow,cdrtocTrackMarkerStartMMSSFF',
                 \ 'START')

call s:def_match('cdrtocTrackMarkerStartMMSSFF',
               \ '@cdrtocTrackContentsFollow',
               \ s:mmssff_pattern)

call s:def_keyword('cdrtocTrackMarker',
                 \ '@cdrtocTrackContentsFollow,cdrtocTrackMarkerEndMMSSFF',
                 \ 'END')

call s:def_match('cdrtocTrackMarkerEndMMSSFF',
               \ '@cdrtocTrackContentsFollow',
               \ s:mmssff_pattern)

call s:def_keyword('cdrtocTrackIndex', 'cdrtocTrackIndexMMSSFF', 'INDEX')

call s:def_match('cdrtocTrackIndexMMSSFF',
               \ 'cdrtocTrackIndex,cdrtocTrack',
               \ s:mmssff_pattern)

delfunction s:def_region
delfunction s:def_match
delfunction s:def_keyword
delfunction s:def_keywords
delfunction s:def_comment

syn sync fromstart

hi def link cdrtocKeyword                                  Keyword
hi def link cdrtocHeaderKeyword                            cdrtocKeyword
hi def link cdrtocHeaderCDText                             cdrtocHeaderKeyword
hi def link cdrtocDelimiter                                Delimiter
hi def link cdrtocCDTextDataBinaryEnd                      cdrtocDelimiter
hi def link cdrtocHeaderCDTextDataBinaryEnd                cdrtocHeaderCDTextDataBinaryEnd
hi def link cdrtocNumber                                   Number
hi def link cdrtocCDTextDataBinaryInteger                  cdrtocNumber
hi def link cdrtocHeaderCDTextDataBinaryInteger            cdrtocCDTextDataBinaryInteger
hi def link cdrtocCDTextDataBinarySeparator                cdrtocDelimiter
hi def link cdrtocHeaderCDTextDataBinarySeparator          cdrtocCDTextDataBinarySeparator
hi def link cdrtocCDTextDataBinaryStart                    cdrtocDelimiter
hi def link cdrtocHeaderCDTextDataBinaryStart              cdrtocCDTextDataBinaryStart
hi def link cdrtocString                                   String
hi def link cdrtocCDTextDataString                         cdrtocString
hi def link cdrtocHeaderCDTextDataString                   cdrtocCDTextDataString
hi def link cdrtocCDTextDataStringDelimiters               cdrtocDelimiter
hi def link cdrtocHeaderCDTextDataStringDelimiters         cdrtocCDTextDataStringDelimiters
hi def link cdrtocCDTextDataStringSpecialChar              SpecialChar
hi def link cdrtocHeaderCDTextDataStringSpecialChar        cdrtocCDTextDataStringSpecialChar
hi def link cdrtocCDTextEnd                                cdrtocDelimiter
hi def link cdrtocHeaderCDTextEnd                          cdrtocCDTextEnd
hi def link cdrtocType                                     Type
hi def link cdrtocCDTextItem                               cdrtocType
hi def link cdrtocHeaderCDTextItem                         cdrtocCDTextItem
hi def link cdrtocHeaderCDTextLanguageMap                  cdrtocHeaderKeyword
hi def link cdrtocCDTextStart                              cdrtocDelimiter
hi def link cdrtocHeaderCDTextStart                        cdrtocCDTextStart
hi def link cdrtocHeaderCatalog                            cdrtocHeaderKeyword
hi def link cdrtocHeaderCatalogNumber                      cdrtocString
hi def link cdrtocComment                                  Comment
hi def link cdrtocHeaderCommentInitial                     cdrtocComment
hi def link cdrtocHeaderLanguage                           cdrtocKeyword
hi def link cdrtocLanguageEnd                              cdrtocDelimiter
hi def link cdrtocHeaderLanguageEnd                        cdrtocLanguageEnd
hi def link cdrtocHeaderLanguageMapColon                   cdrtocDelimiter
hi def link cdrtocIdentifier                               Identifier
hi def link cdrtocHeaderLanguageMapCountryCode             cdrtocNumber
hi def link cdrtocHeaderLanguageMapCountryCodeName         cdrtocIdentifier
hi def link cdrtocHeaderLanguageMapEnd                     cdrtocDelimiter
hi def link cdrtocHeaderLanguageMapLanguageNumber          cdrtocNumber
hi def link cdrtocHeaderLanguageMapStart                   cdrtocDelimiter
hi def link cdrtocLanguageNumber                           cdrtocNumber
hi def link cdrtocHeaderLanguageNumber                     cdrtocLanguageNumber
hi def link cdrtocLanguageStart                            cdrtocDelimiter
hi def link cdrtocHeaderLanguageStart                      cdrtocLanguageStart
hi def link cdrtocHeaderTOCType                            cdrtocType
hi def link cdrtocTodo                                     Todo
hi def link cdrtocTrackKeyword                             cdrtocKeyword
hi def link cdrtocTrack                                    cdrtocTrackKeyword
hi def link cdrtocTrackCDText                              cdrtocTrackKeyword
hi def link cdrtocTrackCDTextDataBinaryEnd                 cdrtocHeaderCDTextDataBinaryEnd
hi def link cdrtocTrackCDTextDataBinaryInteger             cdrtocHeaderCDTextDataBinaryInteger
hi def link cdrtocTrackCDTextDataBinarySeparator           cdrtocHeaderCDTextDataBinarySeparator
hi def link cdrtocTrackCDTextDataBinaryStart               cdrtocHeaderCDTextDataBinaryStart
hi def link cdrtocTrackCDTextDataString                    cdrtocHeaderCDTextDataString
hi def link cdrtocTrackCDTextDataStringDelimiters          cdrtocCDTextDataStringDelimiters
hi def link cdrtocTrackCDTextDataStringSpecialChar         cdrtocCDTextDataStringSpecialChar
hi def link cdrtocTrackCDTextEnd                           cdrtocCDTextEnd
hi def link cdrtocTrackCDTextItem                          cdrtocCDTextItem
hi def link cdrtocTrackCDTextStart                         cdrtocCDTextStart
hi def link cdrtocLength                                   cdrtocNumber
hi def link cdrtocTrackDatafileLength                      cdrtocLength
hi def link cdrtocTrackFifoLength                          cdrtocLength
hi def link cdrtocPreProc                                  PreProc
hi def link cdrtocTrackFlag                                cdrtocPreProc
hi def link cdrtocTrackFlagCopy                            cdrtocTrackFlag
hi def link cdrtocSpecial                                  Special
hi def link cdrtocTrackFlagNo                              cdrtocSpecial
hi def link cdrtocTrackFlagPreEmphasis                     cdrtocTrackFlag
hi def link cdrtocTrackISRC                                cdrtocTrackFlag
hi def link cdrtocTrackIndex                               cdrtocTrackKeyword
hi def link cdrtocMMSSFF                                   cdrtocLength
hi def link cdrtocTrackIndexMMSSFF                         cdrtocMMSSFF
hi def link cdrtocTrackCDTextLanguage                      cdrtocTrackKeyword
hi def link cdrtocTrackCDTextLanguageEnd                   cdrtocLanguageEnd
hi def link cdrtocTrackCDTextLanguageNumber                cdrtocLanguageNumber
hi def link cdrtocTrackCDTextLanguageStart                 cdrtocLanguageStart
hi def link cdrtocTrackContents                            StorageClass
hi def link cdrtocTrackMarker                              cdrtocTrackContents
hi def link cdrtocTrackMarkerEndMMSSFF                     cdrtocMMSSFF
hi def link cdrtocTrackMarkerStartMMSSFF                   cdrtocMMSSFF
hi def link cdrtocTrackMode                                Type
hi def link cdrtocTrackPregap                              cdrtocTrackContents
hi def link cdrtocTrackPregapMMSSFF                        cdrtocMMSSFF
hi def link cdrtocTrackSilenceLength                       cdrtocLength
hi def link cdrtocTrackSubChannelMode                      cdrtocPreProc
hi def link cdrtocTrackSubTrack                            cdrtocTrackContents
hi def link cdrtocFilename                                 cdrtocString
hi def link cdrtocTrackSubTrackDatafileFilename            cdrtocFilename
hi def link cdrtocTrackSubTrackDatafileFilenameDelimiters  cdrtocTrackSubTrackDatafileFilename
hi def link cdrtocSpecialChar                              SpecialChar
hi def link cdrtocTrackSubTrackDatafileFilenameSpecialChar cdrtocSpecialChar
hi def link cdrtocTrackSubTrackDatafileLength              cdrtocLength
hi def link cdrtocTrackSubTrackFifoFilename                cdrtocFilename
hi def link cdrtocTrackSubTrackFifoFilenameDelimiters      cdrtocTrackSubTrackFifoFilename
hi def link cdrtocTrackSubTrackFifoFilenameSpecialChar     cdrtocSpecialChar
hi def link cdrtocTrackSubTrackFifoLength                  cdrtocLength
hi def link cdrtocTrackSubTrackFileFilename                cdrtocFilename
hi def link cdrtocTrackSubTrackFileFilenameDelimiters      cdrtocTrackSubTrackFileFilename
hi def link cdrtocTrackSubTrackFileFilenameSpecialChar     cdrtocSpecialChar
hi def link cdrtocTrackSubTrackFileLength                  cdrtocLength
hi def link cdrtocTrackSubTrackFileStart                   cdrtocLength
hi def link cdrtocTrackSubTrackZeroDataLength              cdrtocLength
hi def link cdrtocTrackSubTrackZeroDataMode                Type
hi def link cdrtocTrackSubTrackZeroDataSubChannelMode      cdrtocPreProc
hi def link cdrtocTrackSubTrackdatafileFilenameSpecialChar cdrtocSpecialChar

let b:current_syntax = "cdrtoc"

let &cpo = s:cpo_save
unlet s:cpo_save
