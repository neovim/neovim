" Vim syntax file
" Language:	.desktop, .directory files
"		according to freedesktop.org specification 0.9.4
" http://pdx.freedesktop.org/Standards/desktop-entry-spec/desktop-entry-spec-0.9.4.html
" Maintainer:	Mikolaj Machowski ( mikmach AT wp DOT pl )
" Last Change:	2016 Apr 02
" 		(added "Keywords")
" Version Info: desktop.vim 0.9.4-1.2

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

" This syntax file can be used to all *nix configuration files similar to dos
" ini format (eg. .xawtv, .radio, kde rc files) - this is default mode. But
" you can also enforce strict following of freedesktop.org standard for
" .desktop and .directory files . Set (eg. in vimrc)
" let enforce_freedesktop_standard = 1
" and nonstandard extensions not following X- notation will not be highlighted.
if exists("enforce_freedesktop_standard")
	let b:enforce_freedesktop_standard = 1
else
	let b:enforce_freedesktop_standard = 0
endif

" case on
syn case match

" General
if b:enforce_freedesktop_standard == 0
	syn match  dtNotStLabel	"^.\{-}=\@=" nextgroup=dtDelim
endif

syn match  dtGroup	/^\s*\[.*\]/
syn match  dtComment	/^\s*#.*$/
syn match  dtDelim	/=/ contained

" Locale
syn match   dtLocale /^\s*\<\(Name\|GenericName\|Comment\|SwallowTitle\|Icon\|UnmountIcon\)\>.*/ contains=dtLocaleKey,dtLocaleName,dtDelim transparent
syn keyword dtLocaleKey Name GenericName Comment SwallowTitle Icon UnmountIcon nextgroup=dtLocaleName containedin=dtLocale
syn match   dtLocaleName /\(\[.\{-}\]\s*=\@=\|\)/ nextgroup=dtDelim containedin=dtLocale contained

" Numeric
syn match   dtNumeric /^\s*\<Version\>/ contains=dtNumericKey,dtDelim
syn keyword dtNumericKey Version nextgroup=dtDelim containedin=dtNumeric contained

" Boolean
syn match   dtBoolean /^\s*\<\(StartupNotify\|ReadOnly\|Terminal\|Hidden\|NoDisplay\)\>.*/ contains=dtBooleanKey,dtDelim,dtBooleanValue transparent
syn keyword dtBooleanKey StartupNotify ReadOnly Terminal Hidden NoDisplay nextgroup=dtDelim containedin=dtBoolean contained
syn keyword dtBooleanValue true false containedin=dtBoolean contained

" String
syn match   dtString /^\s*\<\(Encoding\|Icon\|Path\|Actions\|FSType\|MountPoint\|UnmountIcon\|URL\|Keywords\|Categories\|OnlyShowIn\|NotShowIn\|StartupWMClass\|FilePattern\|MimeType\)\>.*/ contains=dtStringKey,dtDelim transparent
syn keyword dtStringKey Type Encoding TryExec Exec Path Actions FSType MountPoint URL Keywords Categories OnlyShowIn NotShowIn StartupWMClass FilePattern MimeType nextgroup=dtDelim containedin=dtString contained

" Exec
syn match   dtExec /^\s*\<\(Exec\|TryExec\|SwallowExec\)\>.*/ contains=dtExecKey,dtDelim,dtExecParam transparent
syn keyword dtExecKey Exec TryExec SwallowExec nextgroup=dtDelim containedin=dtExec contained
syn match   dtExecParam  /%[fFuUnNdDickv]/ containedin=dtExec contained

" Type
syn match   dtType /^\s*\<Type\>.*/ contains=dtTypeKey,dtDelim,dtTypeValue transparent
syn keyword dtTypeKey Type nextgroup=dtDelim containedin=dtType contained
syn keyword dtTypeValue Application Link FSDevice Directory containedin=dtType contained

" X-Addition
syn match   dtXAdd    /^\s*X-.*/ contains=dtXAddKey,dtDelim transparent
syn match   dtXAddKey /^\s*X-.\{-}\s*=\@=/ nextgroup=dtDelim containedin=dtXAdd contains=dtXLocale contained

" Locale for X-Addition
syn match   dtXLocale /\[.\{-}\]\s*=\@=/ containedin=dtXAddKey contained

" Locale for all
syn match   dtALocale /\[.\{-}\]\s*=\@=/ containedin=ALL


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link dtGroup		 Special
hi def link dtComment	 Comment
hi def link dtDelim		 String

hi def link dtLocaleKey	 Type
hi def link dtLocaleName	 Identifier
hi def link dtXLocale	 Identifier
hi def link dtALocale	 Identifier

hi def link dtNumericKey	 Type

hi def link dtBooleanKey	 Type
hi def link dtBooleanValue	 Constant

hi def link dtStringKey	 Type

hi def link dtExecKey	 Type
hi def link dtExecParam	 Special
hi def link dtTypeKey	 Type
hi def link dtTypeValue	 Constant
hi def link dtNotStLabel	 Type
hi def link dtXAddKey	 Type


let b:current_syntax = "desktop"

" vim:ts=8
