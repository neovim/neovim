" Vim syntax file
" Language:	kimwitu++
" Maintainer:	Michael Piefel <entwurf@piefel.de>
" Last Change:	2 May 2001

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

" Read the C++ syntax to start with
if version < 600
  source <sfile>:p:h/cpp.vim
else
  runtime! syntax/cpp.vim
  unlet b:current_syntax
endif

" kimwitu++ extentions

" Don't stop at eol, messes around with CPP mode, but gives line spanning
" strings in unparse rules
syn region cCppString		start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=cSpecial,cFormat
syn keyword cType		integer real casestring nocasestring voidptr list
syn keyword cType		uview rview uview_enum rview_enum

" avoid unparsing rule sth:view being scanned as label
syn clear   cUserCont
syn match   cUserCont		"^\s*\I\i*\s*:$" contains=cUserLabel contained
syn match   cUserCont		";\s*\I\i*\s*:$" contains=cUserLabel contained
syn match   cUserCont		"^\s*\I\i*\s*:[^:]"me=e-1 contains=cUserLabel contained
syn match   cUserCont		";\s*\I\i*\s*:[^:]"me=e-1 contains=cUserLabel contained

" highlight phylum decls
syn match   kwtPhylum		"^\I\i*:$"
syn match   kwtPhylum		"^\I\i*\s*{\s*\(!\|\I\)\i*\s*}\s*:$"

syn keyword kwtStatement	with foreach afterforeach provided
syn match kwtDecl		"%\(uviewvar\|rviewvar\)"
syn match kwtDecl		"^%\(uview\|rview\|ctor\|dtor\|base\|storageclass\|list\|attr\|member\|option\)"
syn match kwtOption		"no-csgio\|no-unparse\|no-rewrite\|no-printdot\|no-hashtables\|smart-pointer\|weak-pointer"
syn match kwtSep		"^%}$"
syn match kwtSep		"^%{\(\s\+\I\i*\)*$"
syn match kwtCast		"\<phylum_cast\s*<"me=e-1
syn match kwtCast		"\<phylum_cast\s*$"


" match views, remove paren error in brackets
syn clear cErrInBracket
syn match cErrInBracket		contained ")"
syn match kwtViews		"\(\[\|<\)\@<=[ [:alnum:]_]\{-}:"

" match rule bodies
syn region kwtUnpBody		transparent keepend extend fold start="->\s*\[" start="^\s*\[" skip="\$\@<!{\_.\{-}\$\@<!}" end="\s]\s\=;\=$" end="^]\s\=;\=$" end="}]\s\=;\=$"
syn region kwtRewBody		transparent keepend extend fold start="->\s*<" start="^\s*<" end="\s>\s\=;\=$" end="^>\s\=;\=$"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_kwt_syn_inits")
    if version < 508
	let did_kwt_syn_inits = 1
	command -nargs=+ HiLink hi link <args>
    else
	command -nargs=+ HiLink hi def link <args>
    endif

    HiLink kwtStatement	cppStatement
    HiLink kwtDecl	cppStatement
    HiLink kwtCast	cppStatement
    HiLink kwtSep	Delimiter
    HiLink kwtViews	Label
    HiLink kwtPhylum	Type
    HiLink kwtOption	PreProc
    "HiLink cText	Comment

    delcommand HiLink
endif

syn sync lines=300

let b:current_syntax = "kwt"

" vim: ts=8
