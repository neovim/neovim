" Vim syntax file
" Language:     WML - Website MetaLanguage
" Maintainer:   Gerfried Fuchs <alfie@ist.org>
" Filenames:    *.wml
" Last Change:  07 Feb 2002
" URL:		http://alfie.ist.org/software/vim/syntax/wml.vim
"
" Original Version: Craig Small <csmall@eye-net.com.au>

" Comments are very welcome - but please make sure that you are commenting on
" the latest version of this file.
" SPAM is _NOT_ welcome - be ready to be reported!

"  If you are looking for the "Wireless Markup Language" syntax file,
"  please take a look at the wap.vim file done by Ralf Schandl, soon in a
"  vim-package around your corner :)


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syn clear
elseif exists("b:current_syntax")
  finish
endif


" A lot of the web stuff looks like HTML so we load that first
if version < 600
  so <sfile>:p:h/html.vim
else
  runtime! syntax/html.vim
endif
unlet b:current_syntax

if !exists("main_syntax")
  let main_syntax = 'wml'
endif

" special character
syn match wmlNextLine	"\\$"

" Redfine htmlTag
syn clear htmlTag
syn region  htmlTag  start=+<[^/<]+ end=+>+  contains=htmlTagN,htmlString,htmlArg,htmlValue,htmlTagError,htmlEvent,htmlCssDefinition

"
" Add in extra Arguments used by wml
syn keyword htmlTagName contained gfont imgbg imgdot lowsrc
syn keyword htmlTagName contained navbar:define navbar:header
syn keyword htmlTagName contained navbar:footer navbar:prolog
syn keyword htmlTagName contained navbar:epilog navbar:button
syn keyword htmlTagName contained navbar:filter navbar:debug
syn keyword htmlTagName contained navbar:render
syn keyword htmlTagName contained preload rollover
syn keyword htmlTagName contained space hspace vspace over
syn keyword htmlTagName contained ps ds pi ein big sc spaced headline
syn keyword htmlTagName contained ue subheadline zwue verbcode
syn keyword htmlTagName contained isolatin pod sdf text url verbatim
syn keyword htmlTagName contained xtable
syn keyword htmlTagName contained csmap fsview import box
syn keyword htmlTagName contained case:upper case:lower
syn keyword htmlTagName contained grid cell info lang: logo page
syn keyword htmlTagName contained set-var restore
syn keyword htmlTagName contained array:push array:show set-var ifdef
syn keyword htmlTagName contained say m4 symbol dump enter divert
syn keyword htmlTagName contained toc
syn keyword htmlTagName contained wml card do refresh oneevent catch spawn

"
" The wml arguments
syn keyword htmlArg contained adjust background base bdcolor bdspace
syn keyword htmlArg contained bdwidth complete copyright created crop
syn keyword htmlArg contained direction description domainname eperlfilter
syn keyword htmlArg contained file hint imgbase imgstar interchar interline
syn keyword htmlArg contained keephr keepindex keywords layout spacing
syn keyword htmlArg contained padding nonetscape noscale notag notypo
syn keyword htmlArg contained onload oversrc pos select slices style
syn keyword htmlArg contained subselected txtcol_select txtcol_normal
syn keyword htmlArg contained txtonly via
syn keyword htmlArg contained mode columns localsrc ordered


" Lines starting with an # are usually comments
syn match   wmlComment     "^\s*#.*"
" The different exceptions to comments
syn match   wmlSharpBang   "^#!.*"
syn match   wmlUsed	   contained "\s\s*[A-Za-z:_-]*"
syn match   wmlUse	   "^\s*#\s*use\s\+" contains=wmlUsed
syn match   wmlInclude	   "^\s*#\s*include.+"

syn region  wmlBody	   contained start=+<<+ end=+>>+

syn match   wmlLocationId  contained "[A-Za-z]\+"
syn region  wmlLocation    start=+<<+ end=+>>+ contains=wmlLocationId
"syn region  wmlLocation    start=+{#+ end=+#}+ contains=wmlLocationId
"syn region  wmlLocationed  contained start=+<<+ end=+>>+ contains=wmlLocationId

syn match   wmlDivert      "\.\.[a-zA-Z_]\+>>"
syn match   wmlDivertEnd   "<<\.\."
" new version
"syn match   wmlDivert      "{#[a-zA-Z_]\+#:"
"syn match   wmlDivertEnd   ":##}"

syn match   wmlDefineName  contained "\s\+[A-Za-z-]\+"
syn region  htmlTagName    start="\<\(define-tag\|define-region\)" end="\>" contains=wmlDefineName

" The perl include stuff
if main_syntax != 'perl'
  " Perl script
  if version < 600
    syn include @wmlPerlScript <sfile>:p:h/perl.vim
  else
    syn include @wmlPerlScript syntax/perl.vim
  endif
  unlet b:current_syntax

  syn region perlScript   start=+<perl>+ keepend end=+</perl>+ contains=@wmlPerlScript,wmlPerlTag
" eperl between '<:' and ':>'  -- Alfie [1999-12-26]
  syn region perlScript   start=+<:+ keepend end=+:>+ contains=@wmlPerlScript,wmlPerlTag
  syn match    wmlPerlTag  contained "</*perl>" contains=wmlPerlTagN
  syn keyword  wmlPerlTagN contained perl

  hi link   wmlPerlTag  htmlTag
  hi link   wmlPerlTagN htmlStatement
endif

" verbatim tags -- don't highlight anything in between  -- Alfie [2002-02-07]
syn region  wmlVerbatimText start=+<verbatim>+ keepend end=+</verbatim>+ contains=wmlVerbatimTag
syn match   wmlVerbatimTag  contained "</*verbatim>" contains=wmlVerbatimTagN
syn keyword wmlVerbatimTagN contained verbatim
hi link     wmlVerbatimTag  htmlTag
hi link     wmlVerbatimTagN htmlStatement

if main_syntax == "html"
  syn sync match wmlHighlight groupthere NONE "</a-zA-Z]"
  syn sync match wmlHighlight groupthere perlScript "<perl>"
  syn sync match wmlHighlightSkip "^.*['\"].*$"
  syn sync minlines=10
endif

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_wml_syn_inits")
  let did_wml_syn_inits = 1
  if version < 508
    let did_wml_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink wmlNextLine	Special
  HiLink wmlUse		Include
  HiLink wmlUsed	String
  HiLink wmlBody	Special
  HiLink wmlDiverted	Label
  HiLink wmlDivert	Delimiter
  HiLink wmlDivertEnd	Delimiter
  HiLink wmlLocationId	Label
  HiLink wmlLocation	Delimiter
" HiLink wmlLocationed	Delimiter
  HiLink wmlDefineName	String
  HiLink wmlComment	Comment
  HiLink wmlInclude	Include
  HiLink wmlSharpBang	PreProc

  delcommand HiLink
endif

let b:current_syntax = "wml"
