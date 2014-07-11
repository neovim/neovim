"----------------------------------------------------------------------------
"  Description: Vim Ada syntax file
"     Language: Ada (2005)
"	   $Id: ada.vim 887 2008-07-08 14:29:01Z krischik $
"    Copyright: Copyright (C) 2006 Martin Krischik
"   Maintainer: Martin Krischik
"		David A. Wheeler <dwheeler@dwheeler.com>
"		Simon Bradley <simon.bradley@pitechnology.com>
" Contributors: Preben Randhol.
"      $Author: krischik $
"	 $Date: 2008-07-08 16:29:01 +0200 (Di, 08 Jul 2008) $
"      Version: 4.6
"    $Revision: 887 $
"     $HeadURL: https://gnuada.svn.sourceforge.net/svnroot/gnuada/trunk/tools/vim/syntax/ada.vim $
"		http://www.dwheeler.com/vim
"      History: 24.05.2006 MK Unified Headers
"		26.05.2006 MK ' should not be in iskeyword.
"		16.07.2006 MK Ada-Mode as vim-ball
"		02.10.2006 MK Better folding.
"		15.10.2006 MK Bram's suggestion for runtime integration
"		05.11.2006 MK Spell check for comments and strings only
"		05.11.2006 MK Bram suggested to save on spaces
"    Help Page: help ft-ada-syntax
"------------------------------------------------------------------------------
" The formal spec of Ada 2005 (ARM) is the "Ada 2005 Reference Manual".
" For more Ada 2005 info, see http://www.gnuada.org and http://www.adapower.com.
"
" This vim syntax file works on vim 7.0 only and makes use of most of Voim 7.0 
" advanced features.
"------------------------------------------------------------------------------

if exists("b:current_syntax") || version < 700
    finish
endif
let s:keepcpo= &cpo
set cpo&vim

let b:current_syntax = "ada"

" Section: Ada is entirely case-insensitive. {{{1
"
syntax   case ignore

" Section: Highlighting commands {{{1
"
" There are 72 reserved words in total in Ada2005. Some keywords are
" used in more than one way. For example:
" 1. "end" is a general keyword, but "end if" ends a Conditional.
" 2. "then" is a conditional, but "and then" is an operator.
"
for b:Item in g:ada#Keywords
   " Standard Exceptions (including I/O).
   " We'll highlight the standard exceptions, similar to vim's Python mode.
   " It's possible to redefine the standard exceptions as something else,
   " but doing so is very bad practice, so simply highlighting them makes sense.
   if b:Item['kind'] == "x"
      execute "syntax keyword adaException " . b:Item['word']
   endif
   if b:Item['kind'] == "a"
      execute 'syntax match adaAttribute "\V' . b:Item['word'] . '"'
   endif
   " We don't normally highlight types in package Standard
   " (Integer, Character, Float, etc.).  I don't think it looks good
   " with the other type keywords, and many Ada programs define
   " so many of their own types that it looks inconsistent.
   " However, if you want this highlighting, turn on "ada_standard_types".
   " For package Standard's definition, see ARM section A.1.
   if b:Item['kind'] == "t" && exists ("g:ada_standard_types")
      execute "syntax keyword adaBuiltinType " . b:Item['word']
   endif
endfor

" Section: others {{{1
"
syntax keyword  adaLabel	others

" Section: Operatoren {{{1
"
syntax keyword  adaOperator abs mod not rem xor
syntax match    adaOperator "\<and\>"
syntax match    adaOperator "\<and\s\+then\>"
syntax match    adaOperator "\<or\>"
syntax match    adaOperator "\<or\s\+else\>"
syntax match    adaOperator "[-+*/<>&]"
syntax keyword  adaOperator **
syntax match    adaOperator "[/<>]="
syntax keyword  adaOperator =>
syntax match    adaOperator "\.\."
syntax match    adaOperator "="

" Section: <> {{{1
"
" Handle the box, <>, specially:
"
syntax keyword  adaSpecial	    <>

" Section: rainbow color {{{1
"
if exists("g:ada_rainbow_color")
    syntax match	adaSpecial	 "[:;.,]"
    call rainbow_parenthsis#LoadRound ()
    call rainbow_parenthsis#Activate ()
else
    syntax match	adaSpecial	 "[:;().,]"
endif

" Section: := {{{1
"
" We won't map "adaAssignment" by default, but we need to map ":=" to
" something or the "=" inside it will be mislabelled as an operator.
" Note that in Ada, assignment (:=) is not considered an operator.
"
syntax match adaAssignment		":="

" Section: Numbers, including floating point, exponents, and alternate bases. {{{1
"
syntax match   adaNumber		"\<\d[0-9_]*\(\.\d[0-9_]*\)\=\([Ee][+-]\=\d[0-9_]*\)\=\>"
syntax match   adaNumber		"\<\d\d\=#\x[0-9A-Fa-f_]*\(\.\x[0-9A-Fa-f_]*\)\=#\([Ee][+-]\=\d[0-9_]*\)\="

" Section: Identify leading numeric signs {{{1
"
" In "A-5" the "-" is an operator, " but in "A:=-5" the "-" is a sign. This
" handles "A3+-5" (etc.) correctly.  " This assumes that if you put a
" don't put a space after +/- when it's used " as an operator, you won't
" put a space before it either -- which is true " in code I've seen.
"
syntax match adaSign "[[:space:]<>=(,|:;&*/+-][+-]\d"lc=1,hs=s+1,he=e-1,me=e-1

" Section: Labels for the goto statement. {{{1
"
syntax region  adaLabel		start="<<"  end=">>"

" Section: Boolean Constants {{{1
" Boolean Constants.
syntax keyword adaBoolean	true false

" Section: Warn C/C++ {{{1
"
" Warn people who try to use C/C++ notation erroneously:
"
syntax match adaError "//"
syntax match adaError "/\*"
syntax match adaError "=="


" Section: Space Errors {{{1
"
if exists("g:ada_space_errors")
   if !exists("g:ada_no_trail_space_error")
       syntax match   adaSpaceError	 excludenl "\s\+$"
   endif
   if !exists("g:ada_no_tab_space_error")
      syntax match   adaSpaceError	 " \+\t"me=e-1
   endif
   if !exists("g:ada_all_tab_usage")
      syntax match   adaSpecial	 "\t"
   endif
endif

" Section: end {{{1
" Unless special ("end loop", "end if", etc.), "end" marks the end of a
" begin, package, task etc. Assiging it to adaEnd.
syntax match    adaEnd	/\<end\>/

syntax keyword  adaPreproc		 pragma

syntax keyword  adaRepeat	 exit for loop reverse while
syntax match    adaRepeat		   "\<end\s\+loop\>"

syntax keyword  adaStatement accept delay goto raise requeue return
syntax keyword  adaStatement terminate
syntax match    adaStatement  "\<abort\>"

" Section: Handle Ada's record keywords. {{{1
"
" 'record' usually starts a structure, but "with null record;" does not,
" and 'end record;' ends a structure.  The ordering here is critical -
" 'record;' matches a "with null record", so make it a keyword (this can
" match when the 'with' or 'null' is on a previous line).
" We see the "end" in "end record" before the word record, so we match that
" pattern as adaStructure (and it won't match the "record;" pattern).
"
syntax match adaStructure   "\<record\>"	contains=adaRecord
syntax match adaStructure   "\<end\s\+record\>"	contains=adaRecord
syntax match adaKeyword	    "\<record;"me=e-1

" Section: type classes {{{1
"
syntax keyword adaStorageClass	abstract access aliased array at constant delta
syntax keyword adaStorageClass	digits limited of private range tagged
syntax keyword adaStorageClass	interface synchronized
syntax keyword adaTypedef	subtype type

" Section: Conditionals {{{1
"
" "abort" after "then" is a conditional of its own.
"
syntax match    adaConditional  "\<then\>"
syntax match    adaConditional	"\<then\s\+abort\>"
syntax match    adaConditional	"\<else\>"
syntax match    adaConditional	"\<end\s\+if\>"
syntax match    adaConditional	"\<end\s\+case\>"
syntax match    adaConditional	"\<end\s\+select\>"
syntax keyword  adaConditional	if case select
syntax keyword  adaConditional	elsif when

" Section: other keywords {{{1
syntax match    adaKeyword	    "\<is\>" contains=adaRecord
syntax keyword  adaKeyword	    all do exception in new null out
syntax keyword  adaKeyword	    separate until overriding

" Section: begin keywords {{{1
"
" These keywords begin various constructs, and you _might_ want to
" highlight them differently.
"
syntax keyword  adaBegin	begin body declare entry generic
syntax keyword  adaBegin	protected renames task

syntax match    adaBegin	"\<function\>" contains=adaFunction
syntax match    adaBegin	"\<procedure\>" contains=adaProcedure
syntax match    adaBegin	"\<package\>" contains=adaPackage

if exists("ada_with_gnat_project_files")
   syntax keyword adaBegin	project
endif

" Section: with, use {{{1
"
if exists("ada_withuse_ordinary")
   " Don't be fancy. Display "with" and "use" as ordinary keywords in all cases.
   syntax keyword adaKeyword		with use
else
   " Highlight "with" and "use" clauses like C's "#include" when they're used
   " to reference other compilation units; otherwise they're ordinary keywords.
   " If we have vim 6.0 or later, we'll use its advanced pattern-matching
   " capabilities so that we won't match leading spaces.
   syntax match adaKeyword	"\<with\>"
   syntax match adaKeyword	"\<use\>"
   syntax match adaBeginWith	"^\s*\zs\(\(with\(\s\+type\)\=\)\|\(use\)\)\>" contains=adaInc
   syntax match adaSemiWith	";\s*\zs\(\(with\(\s\+type\)\=\)\|\(use\)\)\>" contains=adaInc
   syntax match adaInc		"\<with\>" contained contains=NONE
   syntax match adaInc		"\<with\s\+type\>" contained contains=NONE
   syntax match adaInc		"\<use\>" contained contains=NONE
   " Recognize "with null record" as a keyword (even the "record").
   syntax match adaKeyword	"\<with\s\+null\s\+record\>"
   " Consider generic formal parameters of subprograms and packages as keywords.
   syntax match adaKeyword	";\s*\zswith\s\+\(function\|procedure\|package\)\>"
   syntax match adaKeyword	"^\s*\zswith\s\+\(function\|procedure\|package\)\>"
endif

" Section: String and character constants. {{{1
"
syntax region  adaString	contains=@Spell start=+"+ skip=+""+ end=+"+ 
syntax match   adaCharacter "'.'"

" Section: Todo (only highlighted in comments) {{{1
"
syntax keyword adaTodo contained TODO FIXME XXX NOTE

" Section: Comments. {{{1
"
syntax region  adaComment 
    \ oneline 
    \ contains=adaTodo,adaLineError,@Spell
    \ start="--" 
    \ end="$"

" Section: line errors {{{1
"
" Note: Line errors have become quite slow with Vim 7.0
"
if exists("g:ada_line_errors")
    syntax match adaLineError "\(^.\{79}\)\@<=."  contains=ALL containedin=ALL
endif

" Section: syntax folding {{{1
"
"	Syntax folding is very tricky - for now I still suggest to use
"	indent folding
"
if exists("g:ada_folding") && g:ada_folding[0] == 's'
   if stridx (g:ada_folding, 'p') >= 0
      syntax region adaPackage
         \ start="\(\<package\s\+body\>\|\<package\>\)\s*\z(\k*\)"
         \ end="end\s\+\z1\s*;"
         \ keepend extend transparent fold contains=ALL
   endif
   if stridx (g:ada_folding, 'f') >= 0
      syntax region adaProcedure
         \ start="\<procedure\>\s*\z(\k*\)"
         \ end="\<end\>\s\+\z1\s*;"
         \ keepend extend transparent fold contains=ALL
      syntax region adaFunction
         \ start="\<procedure\>\s*\z(\k*\)"
         \ end="end\s\+\z1\s*;"
         \ keepend extend transparent fold contains=ALL
   endif
   if stridx (g:ada_folding, 'f') >= 0
      syntax region adaRecord
         \ start="\<is\s\+record\>"
         \ end="\<end\s\+record\>"
         \ keepend extend transparent fold contains=ALL
   endif
endif

" Section: The default methods for highlighting. Can be overridden later. {{{1
"
highlight def link adaCharacter	    Character
highlight def link adaComment	    Comment
highlight def link adaConditional   Conditional
highlight def link adaKeyword	    Keyword
highlight def link adaLabel	    Label
highlight def link adaNumber	    Number
highlight def link adaSign	    Number
highlight def link adaOperator	    Operator
highlight def link adaPreproc	    PreProc
highlight def link adaRepeat	    Repeat
highlight def link adaSpecial	    Special
highlight def link adaStatement	    Statement
highlight def link adaString	    String
highlight def link adaStructure	    Structure
highlight def link adaTodo	    Todo
highlight def link adaType	    Type
highlight def link adaTypedef	    Typedef
highlight def link adaStorageClass  StorageClass
highlight def link adaBoolean	    Boolean
highlight def link adaException	    Exception
highlight def link adaAttribute	    Tag
highlight def link adaInc	    Include
highlight def link adaError	    Error
highlight def link adaSpaceError    Error
highlight def link adaLineError	    Error
highlight def link adaBuiltinType   Type
highlight def link adaAssignment    Special

" Subsection: Begin, End {{{2
"
if exists ("ada_begin_preproc")
   " This is the old default display:
   highlight def link adaBegin   PreProc
   highlight def link adaEnd     PreProc
else
   " This is the new default display:
   highlight def link adaBegin   Keyword
   highlight def link adaEnd     Keyword
endif



" Section: sync {{{1
"
" We don't need to look backwards to highlight correctly;
" this speeds things up greatly.
syntax sync minlines=1 maxlines=1

let &cpo = s:keepcpo
unlet s:keepcpo

finish " 1}}}

"------------------------------------------------------------------------------
"   Copyright (C) 2006	Martin Krischik
"
"   Vim is Charityware - see ":help license" or uganda.txt for licence details.
"------------------------------------------------------------------------------
"vim: textwidth=78 nowrap tabstop=8 shiftwidth=3 softtabstop=3 noexpandtab
"vim: foldmethod=marker
