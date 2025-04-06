" Vim syntax file
" Language:	T2 / ROCK Linux .desc
" Maintainer:	René Rebe <rene@exactcode.de>, Piotr Esden-Tempski <esden@rocklinux.org>
" Last Change:	2006 Aug 14

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" syntax definitions

setl iskeyword+=-
syn keyword descFlag DIETLIBC KAFFE JAIL NOPARALLEL FPIC-QUIRK LIBTOOL-WUIRK NO-LIBTOOL-FIX AUTOMAKE-QUIRK NO-AS-NEEDED NO-SSP KERNEL INIT LIBC CC CXX F77 KCC contained
syn keyword descLicense Unknown GPL LGPL FDL MIT BSD OpenSource Free-to-use Commercial contained

" tags
syn match descTag /^\[\(COPY\)\]/
syn match descTag /^\[\(I\|TITLE\)\]/
syn match descTag /^\[\(T\|TEXT\)\]/ contained
syn match descTag /^\[\(U\|URL\)\]/
syn match descTag /^\[\(A\|AUTHOR\)\]/
syn match descTag /^\[\(M\|MAINTAINER\)\]/
syn match descTag /^\[\(C\|CATEGORY\)\]/ contained
syn match descTag /^\[\(F\|FLAG\)\]/ contained
syn match descTag /^\[\(E\|DEP\|DEPENDENCY\)\]/
syn match descTag /^\[\(R\|ARCH\|ARCHITECTURE\)\]/
syn match descTag /^\[\(L\|LICENSE\)\]/ contained
syn match descTag /^\[\(S\|STATUS\)\]/
syn match descTag /^\[\(O\|CONF\)\]/
syn match descTag /^\[\(V\|VER\|VERSION\)\]/
syn match descTag /^\[\(P\|PRI\|PRIORITY\)\]/ nextgroup=descInstall skipwhite
syn match descTag /^\[\(D\|DOWN\|DOWNLOAD\)\]/ nextgroup=descSum skipwhite

" misc
syn match descUrl /\w\+:\/\/\S\+/
syn match descCategory /\w\+\/\w\+/ contained
syn match descEmail /<[\.A-Za-z0-9]\+@[\.A-Za-z0-9]\+>/

" priority tag
syn match descInstallX /X/ contained
syn match descInstallO /O/ contained
syn match descInstall /[OX]/ contained contains=descInstallX,descInstallO nextgroup=descStage skipwhite
syn match descDash /-/ contained
syn match descDigit /\d/ contained
syn match descStage /[\-0][\-1][\-2][\-3][\-4][\-5][\-6][\-7][\-8][\-9]/ contained contains=descDash,descDigit nextgroup=descCompilePriority skipwhite
syn match descCompilePriority /\d\{3}\.\d\{3}/ contained

" download tag
syn match descSum /\d\+/ contained nextgroup=descTarball skipwhite
syn match descTarball /\S\+/ contained nextgroup=descUrl skipwhite


" tag regions
syn region descText start=/^\[\(T\|TEXT\)\]/ end=/$/ contains=descTag,descUrl,descEmail

syn region descTagRegion start=/^\[\(C\|CATEGORY\)\]/ end=/$/ contains=descTag,descCategory

syn region descTagRegion start=/^\[\(F\|FLAG\)\]/ end=/$/ contains=descTag,descFlag

syn region descTagRegion start=/^\[\(L\|LICENSE\)\]/ end=/$/ contains=descTag,descLicense

" Only when an item doesn't have highlighting yet

hi def link descFlag		Identifier
hi def link descLicense		Identifier
hi def link descCategory		Identifier

hi def link descTag		Type
hi def link descUrl		Underlined
hi def link descEmail		Underlined

" priority tag colors
hi def link descInstallX		Boolean
hi def link descInstallO		Type
hi def link descDash		Operator
hi def link descDigit		Number
hi def link descCompilePriority	Number

" download tag colors
hi def link descSum		Number
hi def link descTarball		Underlined

" tag region colors
hi def link descText		Comment


let b:current_syntax = "desc"
