" Vim syntax file
" Language:	SubStation Alpha
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	*.ass,*.ssa
" Last Change:	2022 Oct 10

if exists('b:current_syntax')
    finish
endif

" Comments
syn keyword ssaTodo TODO FIXME NOTE XXX contained
syn match ssaComment /^\(;\|!:\).*$/ contains=ssaTodo,@Spell
syn match ssaTextComment /{[^}]*}/ contained contains=@Spell

" Sections
syn match ssaSection /^\[[a-zA-Z0-9+ ]\+\]$/

" Headers
syn match ssaHeader /^[^;!:]\+:/ skipwhite nextgroup=ssaField

" Fields
syn match ssaField /[^,]*/ contained skipwhite nextgroup=ssaDelimiter

" Time
syn match ssaTime /\d:\d\d:\d\d\.\d\d/ contained skipwhite nextgroup=ssaDelimiter

" Delimiter
syn match ssaDelimiter /,/ contained skipwhite nextgroup=ssaField,ssaTime,ssaText

" Text
syn match ssaText /\(^Dialogue:\(.*,\)\{9}\)\@<=.*$/ contained contains=@ssaTags,@Spell
syn cluster ssaTags contains=ssaOverrideTag,ssaEscapeChar,ssaTextComment,ssaItalics,ssaBold,ssaUnderline,ssaStrikeout

" Override tags
syn match ssaOverrideTag /{\\[^}]\+}/ contained contains=@NoSpell

" Special characters
syn match ssaEscapeChar /\\[nNh{}]/ contained contains=@NoSpell

" Markup
syn region ssaItalics start=/{\\i1}/ end=/{\\i0}/ matchgroup=ssaOverrideTag keepend oneline contained contains=@ssaTags,@Spell
syn region ssaBold start=/{\\b1}/ end=/{\\b0}/ matchgroup=ssaOverrideTag keepend oneline contained contains=@ssaTags,@Spell
syn region ssaUnderline start=/{\\u1}/ end=/{\\u0}/ matchgroup=ssaOverrideTag keepend oneline contained contains=@ssaTags,@Spell
syn region ssaStrikeout start=/{\\s1}/ end=/{\\s0}/ matchgroup=ssaOverrideTag keepend oneline contained contains=@ssaTags,@Spell

hi def link ssaDelimiter Delimiter
hi def link ssaComment Comment
hi def link ssaEscapeChar SpecialChar
hi def link ssaField String
hi def link ssaHeader Label
hi def link ssaSection StorageClass
hi def link ssaOverrideTag Special
hi def link ssaTextComment Comment
hi def link ssaTime Number
hi def link ssaTodo Todo

hi ssaBold cterm=bold gui=bold
hi ssaItalics cterm=italic gui=italic
hi ssaStrikeout cterm=strikethrough gui=strikethrough
hi ssaUnderline cterm=underline gui=underline

let b:current_syntax = 'srt'
