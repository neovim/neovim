" Vim syntax file
" Language:	.desktop, .directory files
"		according to freedesktop.org specification 0.9.4
" http://pdx.freedesktop.org/Standards/desktop-entry-spec/desktop-entry-spec-0.9.4.html
" Maintainer:	Mikolaj Machowski ( mikmach AT wp DOT pl )
" Last Change:	2004 May 16
" Version Info: desktop.vim 0.9.4-1.2

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
	syntax clear
elseif exists("b:current_syntax")
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
syn match   dtString /^\s*\<\(Encoding\|Icon\|Path\|Actions\|FSType\|MountPoint\|UnmountIcon\|URL\|Categories\|OnlyShowIn\|NotShowIn\|StartupWMClass\|FilePattern\|MimeType\)\>.*/ contains=dtStringKey,dtDelim transparent
syn keyword dtStringKey Type Encoding TryExec Exec Path Actions FSType MountPoint URL Categories OnlyShowIn NotShowIn StartupWMClass FilePattern MimeType nextgroup=dtDelim containedin=dtString contained

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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_desktop_syntax_inits")
	if version < 508
		let did_dosini_syntax_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink dtGroup		 Special
	HiLink dtComment	 Comment
	HiLink dtDelim		 String

	HiLink dtLocaleKey	 Type
	HiLink dtLocaleName	 Identifier
	HiLink dtXLocale	 Identifier
	HiLink dtALocale	 Identifier

	HiLink dtNumericKey	 Type

	HiLink dtBooleanKey	 Type
	HiLink dtBooleanValue	 Constant

	HiLink dtStringKey	 Type

	HiLink dtExecKey	 Type
	HiLink dtExecParam	 Special
	HiLink dtTypeKey	 Type
	HiLink dtTypeValue	 Constant
	HiLink dtNotStLabel	 Type
	HiLink dtXAddKey	 Type

	delcommand HiLink
endif

let b:current_syntax = "desktop"

" vim:ts=8
