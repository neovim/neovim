" Vim syntax file
" Language:	T2 / ROCK Linux .desc
" Maintainer:	René Rebe <rene@exactcode.de>, Piotr Esden-Tempski <esden@rocklinux.org>
" Last Change:	2006 Aug 14

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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

" For version 5.7 and earlier: only when not done already
" Define the default highlighting.
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_desc_syntax_inits")
  if version < 508
    let did_desc_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink descFlag		Identifier
  HiLink descLicense		Identifier
  HiLink descCategory		Identifier

  HiLink descTag		Type
  HiLink descUrl		Underlined
  HiLink descEmail		Underlined

  " priority tag colors
  HiLink descInstallX		Boolean
  HiLink descInstallO		Type
  HiLink descDash		Operator
  HiLink descDigit		Number
  HiLink descCompilePriority	Number

  " download tag colors
  HiLink descSum		Number
  HiLink descTarball		Underlined

  " tag region colors
  HiLink descText		Comment

  delcommand HiLink
endif

let b:current_syntax = "desc"
