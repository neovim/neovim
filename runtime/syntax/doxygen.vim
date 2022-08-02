" DoxyGen syntax highlighting extension for c/c++/idl/java
" Language:     doxygen on top of c, cpp, idl, java, php
" Maintainer:   Michael Geddes <vimmer@frog.wheelycreek.net>
" Author:       Michael Geddes
" Last Change: December 2020
" Version:      1.30
"
" Copyright 2004-2020 Michael Geddes
" Please feel free to use, modify & distribute all or part of this script,
" providing this copyright message remains.
" I would appreciate being acknowledged in any derived scripts, and would
" appreciate and welcome any updates, modifications or suggestions.

" NOTE:  Comments welcome!
"
" There are two variables that control the syntax highlighting produced by this
" script:
" doxygen_enhanced_colour  - Use the (non-standard) original colours designed
"                            for this highlighting.
" doxygen_my_rendering     - Disable the HTML bold/italic/underline rendering.
"
" A brief description without '.' or '!' will cause the end comment
" character to be marked as an error.  You can define the colour of this using
" the highlight doxygenErrorComment.
" A \link without an \endlink will cause an error highlight on the end-comment.
" This is defined by doxygenLinkError
"
" The variable g:doxygen_codeword_font can be set to the guifont for marking \c
" words - a 'typewriter' like font normally. Spaces must be escaped.  It can
" also be set to any highlight attribute. Alternatively, a highlight for doxygenCodeWord
" can be used to override it.
"
" By default, highlighting is done assuming you have the JAVADOC_AUTOBRIEF
" setting turned on in your Doxygen configuration.  If you don't, you
" can set the variable g:doxygen_javadoc_autobrief to 0 to have the
" highlighting more accurately reflect the way Doxygen will interpret your
" comments.
"
" Support for cpp, c, idl, doxygen and php.
"
" Special thanks to:  Wu Yongwei, Toby Allsopp
"

if exists('b:suppress_doxygen')
  unlet b:suppress_doxygen
  finish
endif

if exists('b:current_syntax') && b:current_syntax =~ 'doxygen' && !exists('doxygen_debug_script')
  finish
endif

let s:cpo_save = &cpo
try
  set cpo&vim

  " Start of Doxygen syntax highlighting:
  "

  " C/C++ Style line comments
  syn match doxygenCommentWhite +\s*\ze/\*\(\*/\)\@![*!]+ containedin=phpRegion
  syn match doxygenCommentWhite +\s*\ze//[/!]+ containedin=phpRegion
  syn match doxygenCommentWhite +\s*\ze/\*\(\*/\)\@![*!]+
  syn match doxygenCommentWhite +\s*\ze//[/!]+ containedin=phpRegion

  syn region doxygenComment start=+/\*\(\*/\)\@![*!]+  end=+\*/+ contains=doxygenSyncStart,doxygenStart,doxygenTODO,doxygenLeadingWhite  keepend fold containedin=phpRegion
  syn region doxygenCommentL start=+//[/!]<\@!+me=e-1 end=+$+ contains=doxygenLeadingLWhite,doxygenStartL,@Spell keepend skipwhite skipnl nextgroup=doxygenCommentWhite2 fold containedin=phpRegion
  syn region doxygenCommentL start=+//[/!]<+me=e-2 end=+$+ contains=doxygenStartL,@Spell keepend skipwhite skipnl fold containedin=phpRegion
  syn region doxygenCommentL start=+//@\ze[{}]+ end=+$+ contains=doxygenGroupDefine,doxygenGroupDefineSpecial,@Spell fold containedin=phpRegion
  syn region doxygenComment start=+/\*@\ze[{}]+ end=+\*/+ contains=doxygenGroupDefine,doxygenGroupDefineSpecial,@Spell fold containedin=phpRegion

  " Single line brief followed by multiline comment.
  syn match doxygenCommentWhite2 +\_s*\ze/\*\(\*/\)\@![*!]+ contained nextgroup=doxygenComment2
  syn region doxygenComment2 start=+/\*\(\*/\)\@![*!]+ end=+\*/+ contained contains=doxygenSyncStart2,doxygenStart2,doxygenTODO keepend fold
  " This helps with sync-ing as for some reason, syncing behaves differently to a normal region, and the start pattern does not get matched.
  syn match doxygenSyncStart2 +[^*/]+ contained nextgroup=doxygenBody,doxygenPrev,doxygenStartSpecial,doxygenSkipComment,doxygenStartSkip2 skipwhite skipnl

  " Skip empty lines at the start for when comments start on the 2nd/3rd line.
  syn match doxygenStartSkip2 +^\s*\*[^/]+me=e-1 contained nextgroup=doxygenBody,doxygenStartSpecial,doxygenStartSkipWhite skipwhite skipnl
  syn match doxygenStartSkip2 +^\s*\*$+ contained nextgroup=doxygenBody,doxygenStartSpecial,doxygenStartSkipWhite skipwhite skipnl
  syn match doxygenStart2 +/\*[*!]+ contained nextgroup=doxygenBody,doxygenPrev,doxygenStartSpecial,doxygenStartSkip2 skipwhite skipnl


  " Match the Starting pattern (effectively creating the start of a BNF)
  if !exists('g:doxygen_javadoc_autobrief') || g:doxygen_javadoc_autobrief
    syn match doxygenStart +/\*[*!]+ contained nextgroup=doxygenBrief,doxygenPrev,doxygenFindBriefSpecial,doxygenStartSpecial,doxygenStartSkipWhite,doxygenPage skipwhite skipnl
    syn match doxygenLeadingLWhite +\s\++ contained nextgroup=doxygenPrevL,doxygenBriefL,doxygenSpecial
    syn match doxygenStartL +//[/!]+ contained nextgroup=doxygenLeaingLWhite,doxygenPrevL,doxygenBriefL,doxygenSpecial
    " Match the first sentence as a brief comment
    if ! exists('g:doxygen_end_punctuation')
      let g:doxygen_end_punctuation='[.]'
    endif

    exe 'syn region doxygenBrief contained start=+[\\@]\([npcbea]\>\|em\>\|ref\>\|link\>\|f\$\|[$\\&<>#]\)\|[^ \t\\@*]+ start=+\(^\s*\)\@<!\*/\@!+ start=+\<\k+ skip=+'.doxygen_end_punctuation.'\S\@=+ end=+'.doxygen_end_punctuation.'+ end=+\(\s*\(\n\s*\*\=\s*\)[@\\]\([npcbea]\>\|em\>\|ref\>\|link\>\|f\$\|[$\\&<>#]\)\@!\)\@=+ contains=doxygenSmallSpecial,doxygenContinueCommentWhite,doxygenLeadingWhite,doxygenBriefEndComment,doxygenFindBriefSpecial,doxygenSmallSpecial,@doxygenHtmlGroup,doxygenTODO,doxygenHyperLink,doxygenHashLink,@Spell  skipnl nextgroup=doxygenBody'

    syn match doxygenBriefEndComment +\*/+ contained

    exe 'syn region doxygenBriefL start=+@\k\@!\|[\\@]\([npcbea]\>\|em\>\|ref\>\|link\>\|f\$\|[$\\&<>#]\)\|[^ \t\\@]+ start=+\<+ skip=+'.doxygen_end_punctuation.'\S+ end=+'.doxygen_end_punctuation.'\|$+ contained contains=doxygenSmallSpecial,doxygenHyperLink,doxygenHashLink,@doxygenHtmlGroup,@Spell keepend'
    syn match doxygenPrevL +<+ contained  nextgroup=doxygenBriefL,doxygenSpecial skipwhite
  else
    syn match doxygenStart +/\*[*!]+ contained nextgroup=doxygenBody,doxygenPrev,doxygenFindBriefSpecial,doxygenStartSpecial,doxygenStartSkipWhite,doxygenPage skipwhite skipnl
    syn match doxygenStartL +//[/!]+ contained nextgroup=doxygenLeadingLWhite,doxygenPrevL,doxygenLine,doxygenSpecial
    syn match doxygenLeadingLWhite +\s\++ contained nextgroup=doxygenPrevL,doxygenLine,doxygenSpecial
    syn region doxygenLine start=+@\k\@!\|[\\@]\([npcbea]\>\|em\>\|ref\>\|link\>\|f\$\|[$\\&<>#]\)\|[^ \t\\@<]+ start=+\<+ end='$' contained contains=doxygenSmallSpecial,doxygenHyperLink,doxygenHashLink,@doxygenHtmlGroup,@Spell keepend
    syn match doxygenPrevL +<+ contained  nextgroup=doxygenLine,doxygenSpecial skipwhite

  endif

  " This helps with sync-ing as for some reason, syncing behaves differently to a normal region, and the start pattern does not get matched.
  syn match doxygenSyncStart +\ze[^*/]+ contained nextgroup=doxygenBrief,doxygenPrev,doxygenStartSpecial,doxygenFindBriefSpecial,doxygenStartSkipWhite,doxygenPage skipwhite skipnl
  " Match an [@\]brief so that it moves to body-mode.
  "
  "
  " syn match doxygenBriefLine  contained
  syn match doxygenBriefSpecial contained +[@\\]+ nextgroup=doxygenBriefWord skipwhite
  " syn region doxygenFindBriefSpecial start=+[@\\]brief\>+ end=+\(\n\s*\*\=\s*\([@\\]\([npcbea]\>\|em\>\|ref\>\|link\>\|f\$\|[$\\&<>#]\)\@!\)\|\s*$\)\@=+ keepend contains=doxygenBriefSpecial nextgroup=doxygenBody keepend skipwhite skipnl contained
  syn region doxygenFindBriefSpecial start=+[@\\]brief\>+ skip=+^\s*\(\*/\@!\s*\)\=\(\<\|[@\\]\<\([npcbea]\>\|em\>\|ref\|link\>\>\|f\$\|[$\\&<>#]\)\|[^ \t\\@*]\)+ end=+^+ keepend contains=doxygenBriefSpecial nextgroup=doxygenBody keepend skipwhite skipnl contained



" end=+\(\n\s*\*\=\s*\([@\\]\([npcbea]\>\|em\>\|ref\>\|link\>\|f\$\|[$\\&<>#]\)\@!\)\|\s*$\)\@=+
"syn region doxygenBriefLine contained start=+\<\k+ skip=+^\s*\(\*/\@!\s*\)\=\(\<\|[@\\]\<\([npcbea]\>\|em\>\|ref\|link\>\>\|f\$\|[$\\&<>#]\)\|[^ \t\\@*]\)+ end=+^+ contains=doxygenContinueCommentWhite,doxygenSmallSpecial,@doxygenHtmlGroup,doxygenTODO,doxygenHyperLink,doxygenHashLink,@Spell  skipwhite keepend matchgroup=xxx
syn region doxygenBriefLine contained start=+\<\k+ skip=+^\s*\(\*/\@!\s*\)\=\(\<\|[@\\]\<\([npcbea]\>\|em\>\|ref\|link\>\>\|f\$\|[$\\&<>#]\)\|[^ \t\\@*]\)+ end=+^+  skipwhite keepend matchgroup=xxx contains=@Spell
" syn region doxygenBriefLine matchgroup=xxxy contained start=+\<\k.\++ skip=+^\s*\k+ end=+end+  skipwhite keepend
"doxygenFindBriefSpecial,
  "" syn region doxygenSpecialMultilineDesc  start=+.\++ contained contains=doxygenSpecialContinueCommentWhite,doxygenSmallSpecial,doxygenHyperLink,doxygenHashLink,@doxygenHtmlGroup,@Spell  skipwhite keepend


  " Match a '<' for applying a comment to the previous element.
  syn match doxygenPrev +<+ contained nextgroup=doxygenBrief,doxygenBody,doxygenSpecial,doxygenStartSkipWhite skipwhite

if exists("c_comment_strings")
  " These are anti-Doxygen comments.  If there are more than two asterisks or 3 '/'s
  " then turn the comments back into normal C comments.
  syn region cComment start="/\*\*\*" end="\*/" contains=@cCommentGroup,cCommentString,cCharacter,cNumbersCom,cSpaceError
  syn region cCommentL start="////" skip="\\$" end="$" contains=@cCommentGroup,cComment2String,cCharacter,cNumbersCom,cSpaceError
else
  syn region cComment start="/\*\*\*" end="\*/" contains=@cCommentGroup,cSpaceError
  syn region cCommentL start="////" skip="\\$" end="$" contains=@cCommentGroup,cSpaceError
endif

  " Special commands at the start of the area:  starting with '@' or '\'
  syn region doxygenStartSpecial contained start=+[@\\]\([npcbea]\>\|em\>\|ref\>\|link\>\|f\$\|[$\\&<>#]\)\@!+ end=+$+ end=+\*/+me=s-1,he=s-1  contains=doxygenSpecial nextgroup=doxygenSkipComment skipnl keepend
  syn match doxygenSkipComment contained +^\s*\*/\@!+ nextgroup=doxygenBrief,doxygenStartSpecial,doxygenFindBriefSpecial,doxygenPage skipwhite

  "syn region doxygenBodyBit contained start=+$+

  " The main body of a doxygen comment.
  syn region doxygenBody contained start=+\(/\*[*!]\)\@<!<\|[^<]\|$+ matchgroup=doxygenEndComment end=+\*/+re=e-2,me=e-2 contains=doxygenContinueCommentWhite,doxygenTODO,doxygenSpecial,doxygenSmallSpecial,doxygenHyperLink,doxygenHashLink,@doxygenHtmlGroup,@Spell

  " These allow the skipping of comment continuation '*' characters.
  syn match doxygenContinueCommentWhite contained +^\s*\ze\*+ nextgroup=doxygenContinueComment
  syn match doxygenContinueComment contained +\*/\@!+

  " Catch a Brief comment without punctuation - flag it as an error but
  " make sure the end comment is picked up also.
  syn match doxygenErrorComment contained +\*/+


  " Skip empty lines at the start for when comments start on the 2nd/3rd line.
  if !exists('g:doxygen_javadoc_autobrief') || g:doxygen_javadoc_autobrief
    syn match doxygenStartSkipWhite +^\s*\ze\*/\@!+ contained nextgroup=doxygenBrief,doxygenStartSpecial,doxygenFindBriefSpecial,doxygenStartSkipWhite,doxygenPage skipwhite skipnl
    "syn match doxygenStartSkipWhite +^\s*\ze\*$+ contained nextgroup=doxygenBrief,doxygenStartSpecial,doxygenFindBriefSpecial,doxygenStartSkipWhite,doxygenPage skipwhite skipnl
  else
    syn match doxygenStartSkipWhite +^\s*\*[^/]+me=e-1 contained nextgroup=doxygenStartSpecial,doxygenFindBriefSpecial,doxygenStartSkipWhite,doxygenPage,doxygenBody skipwhite skipnl
    syn match doxygenStartSkipWhite +^\s*\*$+ contained nextgroup=doxygenStartSpecial,doxygenFindBriefSpecial,doxygenStartSkipWhite,doxygenPage,doxygenBody skipwhite skipnl
  endif

  " Create the single word matching special identifiers.

  fun! s:DxyCreateSmallSpecial( kword, name )

    let mx='[-:0-9A-Za-z_%=&+*/!~>|]\@<!\([-0-9A-Za-z_%=+*/!~>|#]\+[-0-9A-Za-z_%=+*/!~>|]\@!\|\\[\\<>&.]@\|[.,]\w\@=\|::\|([^)]*)\|&[0-9a-zA-Z]\{2,7};\)\+'
    exe 'syn region doxygenSpecial'.a:name.'Word contained start=+'.a:kword.'+ end=+\(\_s\+'.mx.'\)\@<=[-a-zA-Z_0-9+*/^%|~!=&\\]\@!+ skipwhite contains=doxygenContinueCommentWhite,doxygen'.a:name.'Word'
    exe 'syn match doxygen'.a:name.'Word contained "\_s\@<='.mx.'" contains=doxygenHtmlSpecial,@Spell keepend'
  endfun
  call s:DxyCreateSmallSpecial('p', 'Code')
  call s:DxyCreateSmallSpecial('c', 'Code')
  call s:DxyCreateSmallSpecial('b', 'Bold')
  call s:DxyCreateSmallSpecial('e', 'Emphasised')
  call s:DxyCreateSmallSpecial('em', 'Emphasised')
  call s:DxyCreateSmallSpecial('a', 'Argument')
  call s:DxyCreateSmallSpecial('ref', 'Ref')
  delfun s:DxyCreateSmallSpecial

  syn match doxygenSmallSpecial contained +[@\\]\(\<[npcbea]\>\|\<em\>\|\<ref\>\|\<link\>\|f\$\|[$\\&<>#]\)\@=+ nextgroup=doxygenOtherLink,doxygenHyperLink,doxygenHashLink,doxygenFormula,doxygenSymbol,doxygenSpecial.*Word

  " Now for special characters
  syn match doxygenSpecial contained +[@\\]\(\<[npcbea]\>\|\<em\>\|\<ref\|\<link\>\>\|\<f\$\|[$\\&<>#]\)\@!+ nextgroup=doxygenParam,doxygenTParam,doxygenRetval,doxygenBriefWord,doxygenBold,doxygenBOther,doxygenOther,doxygenOtherTODO,doxygenOtherWARN,doxygenOtherBUG,doxygenPage,doxygenGroupDefine,doxygenCodeRegion,doxygenVerbatimRegion,doxygenDotRegion
  " doxygenOtherLink,doxygenSymbol,doxygenFormula,doxygenErrorSpecial,doxygenSpecial.*Word
  "
  syn match doxygenGroupDefine contained +@\@<=[{}]+
  syn match doxygenGroupDefineSpecial contained +@\ze[{}]+

  syn match doxygenErrorSpecial contained +\s+

  " Match parameters and retvals (highlighting the first word as special).
  syn match doxygenParamDirection contained "\v\[(\s*in>((]\s*\[|\s*,\s*)out>)=|out>((]\s*\[|\s*,\s*)in>)=)\]" nextgroup=doxygenParamName skipwhite
  syn keyword doxygenParam contained param nextgroup=doxygenParamName,doxygenParamDirection skipwhite
  syn keyword doxygenTParam contained tparam nextgroup=doxygenParamName skipwhite
  syn match doxygenParamName contained +[A-Za-z0-9_:]\++ nextgroup=doxygenSpecialMultilineDesc skipwhite
  syn keyword doxygenRetval contained retval throw throws exception nextgroup=doxygenReturnValue skipwhite
  syn match doxygenReturnValue contained +\S\++ nextgroup=doxygenSpecialMultilineDesc skipwhite

  " Match one line identifiers.
  syn keyword doxygenOther contained addindex anchor
  \ dontinclude endhtmlonly endlatexonly showinitializer hideinitializer
  \ example htmlonly image include includelineno ingroup latexonly line
  \ overload relates related relatesalso relatedalso sa skip skipline
  \ until verbinclude version addtogroup htmlinclude copydoc dotfile
  \ xmlonly endxmlonly
  \ nextgroup=doxygenSpecialOnelineDesc copybrief copydetails copyright dir extends
  \ implements

  syn region doxygenCodeRegion contained matchgroup=doxygenOther start=+\<code\>+ matchgroup=doxygenOther end=+[\\@]\@<=\<endcode\>+ contains=doxygenCodeRegionSpecial,doxygenContinueCommentWhite,doxygenErrorComment,@NoSpell
  syn match doxygenCodeRegionSpecial contained +[\\@]\(endcode\>\)\@=+

  syn region doxygenVerbatimRegion contained matchgroup=doxygenOther start=+\<verbatim\>+ matchgroup=doxygenOther end=+[\\@]\@<=\<endverbatim\>+ contains=doxygenVerbatimRegionSpecial,doxygenContinueCommentWhite,doxygenErrorComment,@NoSpell
  syn match doxygenVerbatimRegionSpecial contained +[\\@]\(endverbatim\>\)\@=+

  if exists('b:current_syntax')
    let b:doxygen_syntax_save=b:current_syntax
    unlet b:current_syntax
  endif

  syn include @Dotx syntax/dot.vim

  if exists('b:doxygen_syntax_save')
    let b:current_syntax=b:doxygen_syntax_save
    unlet b:doxygen_syntax_save
  else
    unlet b:current_syntax
  endif

  syn region doxygenDotRegion contained matchgroup=doxygenOther start=+\<dot\>+ matchgroup=doxygenOther end=+[\\@]\@<=\<enddot\>+ contains=doxygenDotRegionSpecial,doxygenErrorComment,doxygenContinueCommentWhite,@NoSpell,@Dotx
  syn match doxygenDotRegionSpecial contained +[\\@]\(enddot\>\)\@=+

  " Match single line identifiers.
  syn keyword doxygenBOther contained class enum file fn mainpage interface
  \ namespace struct typedef union var def name
  \ nextgroup=doxygenSpecialTypeOnelineDesc

  syn keyword doxygenOther contained par nextgroup=doxygenHeaderLine
  syn region doxygenHeaderLine start=+.+ end=+^+ contained skipwhite nextgroup=doxygenSpecialMultilineDesc
  " Match the start of other multiline comments.
  syn keyword doxygenOther contained arg author authors date deprecated li return returns result see invariant note post pre remarks since test internal nextgroup=doxygenSpecialMultilineDesc
  syn keyword doxygenOtherTODO contained todo attention nextgroup=doxygenSpecialMultilineDesc
  syn keyword doxygenOtherWARN contained warning nextgroup=doxygenSpecialMultilineDesc
  syn keyword doxygenOtherBUG contained bug nextgroup=doxygenSpecialMultilineDesc

  " Handle \link, \endlink, highlighting the link-to and the link text bits separately.
  syn region doxygenOtherLink matchgroup=doxygenOther start=+\<link\>+ end=+[\@]\@<=endlink\>+ contained contains=doxygenLinkWord,doxygenContinueCommentWhite,doxygenLinkError,doxygenEndlinkSpecial
  syn match doxygenEndlinkSpecial contained +[\\@]\zeendlink\>+

  syn match doxygenLinkWord "[_a-zA-Z:#()][_a-z0-9A-Z:#()]*\>" contained skipnl nextgroup=doxygenLinkRest,doxygenContinueLinkComment
  syn match doxygenLinkRest +[^*@\\]\|\*/\@!\|[@\\]\(endlink\>\)\@!+ contained skipnl nextgroup=doxygenLinkRest,doxygenContinueLinkComment
  syn match doxygenContinueLinkComment contained +^\s*\*\=[^/]+me=e-1 nextgroup=doxygenLinkRest
  syn match doxygenLinkError "\*/" contained
  " #Link highlighting.
  syn match doxygenHashLink /\(\h\w*\)\?#\(\.\w\@=\|\w\+\|::\|()\)\+/ contained contains=doxygenHashSpecial
  syn match doxygenHashSpecial /#/ contained
  syn match doxygenHyperLink /\(\s\|^\s*\*\?\)\@<=\(http\|https\|ftp\):\/\/[-0-9a-zA-Z_?&=+#%/.!':;@~]\+/ contained

  " Handle \page.  This does not use doxygenBrief.
  syn match doxygenPage "[\\@]page\>"me=s+1 contained skipwhite nextgroup=doxygenPagePage
  syn keyword doxygenPagePage page contained skipwhite nextgroup=doxygenPageIdent
  syn region doxygenPageDesc  start=+.\++ end=+$+ contained skipwhite contains=doxygenSmallSpecial,@doxygenHtmlGroup keepend skipwhite skipnl nextgroup=doxygenBody
  syn match doxygenPageIdent "\<\w\+\>" contained nextgroup=doxygenPageDesc

  " Handle section
  syn keyword doxygenOther defgroup section subsection subsubsection weakgroup contained skipwhite nextgroup=doxygenSpecialIdent
  syn region doxygenSpecialSectionDesc  start=+.\++ end=+$+ contained skipwhite contains=doxygenSmallSpecial,@doxygenHtmlGroup keepend skipwhite skipnl nextgroup=doxygenContinueCommentWhite
  syn match doxygenSpecialIdent "\<\w\+\>" contained nextgroup=doxygenSpecialSectionDesc

  " Does the one-line description for the one-line type identifiers.
  syn region doxygenSpecialTypeOnelineDesc  start=+.\++ end=+$+ contained skipwhite contains=doxygenSmallSpecial,@doxygenHtmlGroup keepend
  syn region doxygenSpecialOnelineDesc  start=+.\++ end=+$+ contained skipwhite contains=doxygenSmallSpecial,@doxygenHtmlGroup keepend

  " Handle the multiline description for the multiline type identifiers.
  " Continue until an 'empty' line (can contain a '*' continuation) or until the
  " next whole-line @ command \ command.
  syn region doxygenSpecialMultilineDesc  start=+.\++ skip=+^\s*\(\*/\@!\s*\)\=\(\<\|[@\\]\<\([npcbea]\>\|em\>\|ref\|link\>\>\|f\$\|[$\\&<>#]\)\|[^ \t\\@*]\)+ end=+^+ contained contains=doxygenSpecialContinueCommentWhite,doxygenSmallSpecial,doxygenHyperLink,doxygenHashLink,@doxygenHtmlGroup,@Spell  skipwhite keepend

"  syn match doxygenSpecialContinueComment contained +^\s*\*/\@!\s*+ nextgroup=doxygenSpecial skipwhite
  syn match doxygenSpecialContinueCommentWhite contained +^\s*\ze\*+ nextgroup=doxygenSpecialContinueComment
  syn match doxygenSpecialContinueComment contained +\*/\@!+


  " Handle special cases  'bold' and 'group'
  syn keyword doxygenBold contained bold nextgroup=doxygenSpecialHeading
  syn keyword doxygenBriefWord contained brief nextgroup=doxygenBriefLine skipwhite
  syn match doxygenSpecialHeading +.\++ contained skipwhite
  syn keyword doxygenGroup contained group nextgroup=doxygenGroupName skipwhite
  syn keyword doxygenGroupName contained +\k\++ nextgroup=doxygenSpecialOnelineDesc skipwhite

  " Handle special symbol identifiers  @$, @\, @$ etc
  syn match doxygenSymbol contained +[$\\&<>#n]+

  " Simplistic handling of formula regions
  syn region doxygenFormula contained matchgroup=doxygenFormulaEnds start=+f\$+ end=+[@\\]f\$+ contains=doxygenFormulaSpecial,doxygenFormulaOperator
  syn match doxygenFormulaSpecial contained +[@\\]\(f[^$]\|[^f]\)+me=s+1 nextgroup=doxygenFormulaKeyword,doxygenFormulaEscaped
  syn match doxygenFormulaEscaped contained "."
  syn match doxygenFormulaKeyword contained  "[a-z]\+"
  syn match doxygenFormulaOperator contained +[_^]+

  syn region doxygenFormula contained matchgroup=doxygenFormulaEnds start=+f\[+ end=+[@\\]f]+ contains=doxygenFormulaSpecial,doxygenFormulaOperator,doxygenAtom
  syn region doxygenAtom contained transparent matchgroup=doxygenFormulaOperator start=+{+ end=+}+ contains=doxygenAtom,doxygenFormulaSpecial,doxygenFormulaOperator

  " Add TODO highlighting.
  syn keyword doxygenTODO contained TODO README XXX FIXME

  " Supported HTML subset.  Not perfect, but okay.
  syn case ignore
  syn region doxygenHtmlTag contained matchgroup=doxygenHtmlCh start=+\v\</=\ze([biuap]|em|strong|img|br|center|code|dfn|d[ldt]|hr|h[0-3]|li|[ou]l|pre|small|sub|sup|table|tt|var|caption|src|alt|longdesc|name|height|width|usemap|ismap|href|type)>+ skip=+\\<\|\<\k\+=\("[^"]*"\|'[^']*\)+ end=+>+ contains=doxygenHtmlCmd,doxygenContinueCommentWhite,doxygenHtmlVar
  syn keyword doxygenHtmlCmd contained b i em strong u img a br p center code dfn dl dd dt hr h1 h2 h3 li ol ul pre small sub sup table tt var caption nextgroup=doxygenHtmlVar skipwhite
  syn keyword doxygenHtmlVar contained src alt longdesc name height width usemap ismap href type nextgroup=doxygenHtmlEqu skipwhite
  syn match doxygenHtmlEqu contained +=+ nextgroup=doxygenHtmlExpr skipwhite
  syn match doxygenHtmlExpr contained +"\(\\.\|[^"]\)*"\|'\(\\.\|[^']\)*'+ nextgroup=doxygenHtmlVar skipwhite
  syn case match
  syn match doxygenHtmlSpecial contained "&\(copy\|quot\|[AEIOUYaeiouy]uml\|[AEIOUYaeiouy]acute\|[AEIOUaeiouy]grave\|[AEIOUaeiouy]circ\|[ANOano]tilde\|szlig\|[Aa]ring\|nbsp\|gt\|lt\|amp\);"

  syn cluster doxygenHtmlGroup contains=doxygenHtmlCode,doxygenHtmlBold,doxygenHtmlUnderline,doxygenHtmlItalic,doxygenHtmlSpecial,doxygenHtmlTag,doxygenHtmlLink

  syn cluster doxygenHtmlTop contains=@Spell,doxygenHtmlSpecial,doxygenHtmlTag,doxygenContinueCommentWhite
  " Html Support
  syn region doxygenHtmlLink contained start=+<[aA]\>\s*\(\n\s*\*\s*\)\=\(\(name\|href\)=\("[^"]*"\|'[^']*'\)\)\=\s*>+ end=+</[aA]>+me=e-4 contains=@doxygenHtmlTop
  hi link doxygenHtmlLink Underlined

  syn region doxygenHtmlBold contained start="\c<b\>" end="\c</b>"me=e-4 contains=@doxygenHtmlTop,doxygenHtmlBoldUnderline,doxygenHtmlBoldItalic,@Spell
  syn region doxygenHtmlBold contained start="\c<strong\>" end="\c</strong>"me=e-9 contains=@doxygenHtmlTop,doxygenHtmlBoldUnderline,doxygenHtmlBoldItalic,@Spell
  syn region doxygenHtmlBoldUnderline contained start="\c<u\>" end="\c</u>"me=e-4 contains=@doxygenHtmlTop,doxygenHtmlBoldUnderlineItalic,@Spell
  syn region doxygenHtmlBoldItalic contained start="\c<i\>" end="\c</i>"me=e-4 contains=@doxygenHtmlTop,doxygenHtmlBoldItalicUnderline,@Spell
  syn region doxygenHtmlBoldItalic contained start="\c<em\>" end="\c</em>"me=e-5 contains=@doxygenHtmlTop,doxygenHtmlBoldItalicUnderline,@Spell
  syn region doxygenHtmlBoldUnderlineItalic contained start="\c<i\>" end="\c</i>"me=e-4 contains=@doxygenHtmlTop,@Spell
  syn region doxygenHtmlBoldUnderlineItalic contained start="\c<em\>" end="\c</em>"me=e-5 contains=@doxygenHtmlTop,@Spell
  syn region doxygenHtmlBoldItalicUnderline contained start="\c<u\>" end="\c</u>"me=e-4 contains=@doxygenHtmlTop,doxygenHtmlBoldUnderlineItalic,@Spell

  syn region doxygenHtmlUnderline contained start="\c<u\>" end="\c</u>"me=e-4 contains=@doxygenHtmlTop,doxygenHtmlUnderlineBold,doxygenHtmlUnderlineItalic,@Spell
  syn region doxygenHtmlUnderlineBold contained start="\c<b\>" end="\c</b>"me=e-4 contains=@doxygenHtmlTop,doxygenHtmlUnderlineBoldItalic,@Spell
  syn region doxygenHtmlUnderlineBold contained start="\c<strong\>" end="\c</strong>"me=e-9 contains=@doxygenHtmlTop,doxygenHtmlUnderlineBoldItalic,@Spell
  syn region doxygenHtmlUnderlineItalic contained start="\c<i\>" end="\c</i>"me=e-4 contains=@doxygenHtmlTop,htmUnderlineItalicBold,@Spell
  syn region doxygenHtmlUnderlineItalic contained start="\c<em\>" end="\c</em>"me=e-5 contains=@doxygenHtmlTop,htmUnderlineItalicBold,@Spell
  syn region doxygenHtmlUnderlineItalicBold contained start="\c<b\>" end="\c</b>"me=e-4 contains=@doxygenHtmlTop,@Spell
  syn region doxygenHtmlUnderlineItalicBold contained start="\c<strong\>" end="\c</strong>"me=e-9 contains=@doxygenHtmlTop,@Spell
  syn region doxygenHtmlUnderlineBoldItalic contained start="\c<i\>" end="\c</i>"me=e-4 contains=@doxygenHtmlTop,@Spell
  syn region doxygenHtmlUnderlineBoldItalic contained start="\c<em\>" end="\c</em>"me=e-5 contains=@doxygenHtmlTop,@Spell

  syn region doxygenHtmlItalic contained start="\c<i\>" end="\c</i>"me=e-4 contains=@doxygenHtmlTop,doxygenHtmlItalicBold,doxygenHtmlItalicUnderline,@Spell
  syn region doxygenHtmlItalic contained start="\c<em\>" end="\c</em>"me=e-5 contains=@doxygenHtmlTop,@Spell
  syn region doxygenHtmlItalicBold contained start="\c<b\>" end="\c</b>"me=e-4 contains=@doxygenHtmlTop,doxygenHtmlItalicBoldUnderline,@Spell
  syn region doxygenHtmlItalicBold contained start="\c<strong\>" end="\c</strong>"me=e-9 contains=@doxygenHtmlTop,doxygenHtmlItalicBoldUnderline,@Spell
  syn region doxygenHtmlItalicBoldUnderline contained start="\c<u\>" end="\c</u>"me=e-4 contains=@doxygenHtmlTop,@Spell
  syn region doxygenHtmlItalicUnderline contained start="\c<u\>" end="\c</u>"me=e-4 contains=@doxygenHtmlTop,doxygenHtmlItalicUnderlineBold,@Spell
  syn region doxygenHtmlItalicUnderlineBold contained start="\c<b\>" end="\c</b>"me=e-4 contains=@doxygenHtmlTop,@Spell
  syn region doxygenHtmlItalicUnderlineBold contained start="\c<strong\>" end="\c</strong>"me=e-9 contains=@doxygenHtmlTop,@Spell

  syn region doxygenHtmlCode contained start="\c<code\>" end="\c</code>"me=e-7 contains=@doxygenHtmlTop,@NoSpell

  " Prevent the doxygen contained matches from leaking into the c/rc groups.
  syn cluster cParenGroup add=doxygen.*
  syn cluster cParenGroup remove=doxygenComment,doxygenCommentL
  syn cluster cPreProcGroup add=doxygen.*
  syn cluster cMultiGroup add=doxygen.*
  syn cluster rcParenGroup add=doxygen.*
  syn cluster rcParenGroup remove=doxygenComment,doxygenCommentL
  syn cluster rcGroup add=doxygen.*

  let s:my_syncolor=0
  if !exists(':SynColor')
    command -nargs=+ SynColor hi def <args>
    let s:my_syncolor=1
  endif

  let s:my_synlink=0
  if !exists(':SynLink')
    command -nargs=+ SynLink hi def link <args>
    let s:my_synlink=1
  endif

  try
    "let did_doxygen_syntax_inits = &background
    hi doxygen_Dummy guifg=black

    fun! s:Doxygen_Hilights_Base()
      SynLink doxygenHtmlSpecial Special
      SynLink doxygenHtmlVar Type
      SynLink doxygenHtmlExpr String

      SynLink doxygenSmallSpecial SpecialChar

      SynLink doxygenSpecialCodeWord doxygenSmallSpecial
      SynLink doxygenSpecialBoldWord doxygenSmallSpecial
      SynLink doxygenSpecialEmphasisedWord doxygenSmallSpecial
      SynLink doxygenSpecialArgumentWord doxygenSmallSpecial

      " SynColor doxygenFormulaKeyword cterm=bold ctermfg=DarkMagenta guifg=DarkMagenta gui=bold
      SynLink doxygenFormulaKeyword Keyword
      "SynColor doxygenFormulaEscaped  ctermfg=DarkMagenta guifg=DarkMagenta gui=bold
      SynLink doxygenFormulaEscaped Special
      SynLink doxygenFormulaOperator Operator
      SynLink doxygenFormula Statement
      SynLink doxygenSymbol Constant
      SynLink doxygenSpecial Special
      SynLink doxygenFormulaSpecial Special
      "SynColor doxygenFormulaSpecial ctermfg=DarkBlue guifg=DarkBlue
    endfun
    call s:Doxygen_Hilights_Base()

    fun! s:Doxygen_Hilights()
      " Pick a sensible default for 'codeword'.
      let font=''
      if exists('g:doxygen_codeword_font')
        if g:doxygen_codeword_font !~ '\<\k\+='
          let font='font='.g:doxygen_codeword_font
        else
          let font=g:doxygen_codeword_font
        endif
      else
        " Try and pick a font (only some platforms have been tested).
        if has('gui_running')
          if has('gui_gtk2')
            if &guifont == ''
              let font="font='FreeSerif 12'"
            else
              let font="font='".substitute(&guifont, '^.\{-}\(\d\+\)$', 'FreeSerif \1','')."'"
            endif

          elseif has('gui_win32') || has('gui_win16') || has('gui_win95')

            if exists('g:doxygen_use_bitsream_vera')  && g:doxygen_use_bitsream_vera
              let font_base='Bitstream_Vera_Sans_Mono'
            else
              let font_base='Lucida_Console'
            endif
            if &guifont == ''
              let font='font='.font_base.':h10'
            else
              let font='font='.matchstr(substitute(&guifont, '^[^:]*', font_base,''),'[^,]*')
            endif
          elseif has('gui_athena') || has('gui_gtk') || &guifont=~'^\(-[^-]\+\)\{14}'
            if &guifont == ''
              let font='font=-b&h-lucidatypewriter-medium-r-normal-*-*-140-*-*-m-*-iso8859-1'
            else
            " let font='font='.substitute(&guifont,'^\(-[^-]\+\)\{7}-\([0-9]\+\).*', '-b\&h-lucidatypewriter-medium-r-normal-*-*-\2-*-*-m-*-iso8859-1','')
            " The above line works, but it is hard to expect the combination of
            " the two fonts will look good.
            endif
          elseif has('gui_kde')
            " let font='font=Bitstream\ Vera\ Sans\ Mono/12/-1/5/50/0/0/0/0/0'
          endif
        endif
      endif
      if font=='' | let font='gui=bold' | endif
      exe 'SynColor doxygenCodeWord             term=bold cterm=bold '.font
      if (exists('g:doxygen_enhanced_color') && g:doxygen_enhanced_color) || (exists('g:doxygen_enhanced_colour') && g:doxygen_enhanced_colour)
        if &background=='light'
          SynColor doxygenComment ctermfg=DarkRed guifg=DarkRed
          SynColor doxygenBrief cterm=bold ctermfg=Cyan guifg=DarkBlue gui=bold
          SynColor doxygenBody ctermfg=DarkBlue guifg=DarkBlue
          SynColor doxygenSpecialTypeOnelineDesc cterm=bold ctermfg=DarkRed guifg=firebrick3 gui=bold
          SynColor doxygenBOther cterm=bold ctermfg=DarkMagenta guifg=#aa50aa gui=bold
          SynColor doxygenParam ctermfg=DarkGray guifg=#aa50aa
          SynColor doxygenParamName cterm=italic ctermfg=DarkBlue guifg=DeepSkyBlue4 gui=italic,bold
          SynColor doxygenSpecialOnelineDesc cterm=bold ctermfg=DarkCyan guifg=DodgerBlue3 gui=bold
          SynColor doxygenSpecialHeading cterm=bold ctermfg=DarkBlue guifg=DeepSkyBlue4 gui=bold
          SynColor doxygenPrev ctermfg=DarkGreen guifg=DarkGreen
        else
          SynColor doxygenComment ctermfg=LightRed guifg=LightRed
          SynColor doxygenBrief cterm=bold ctermfg=Cyan ctermbg=darkgrey guifg=LightBlue gui=Bold,Italic
          SynColor doxygenBody ctermfg=Cyan guifg=LightBlue
          SynColor doxygenSpecialTypeOnelineDesc cterm=bold ctermfg=Red guifg=firebrick3 gui=bold
          SynColor doxygenBOther cterm=bold ctermfg=Magenta guifg=#aa50aa gui=bold
          SynColor doxygenParam ctermfg=LightGray guifg=LightGray
          SynColor doxygenParamName cterm=italic ctermfg=LightBlue guifg=LightBlue gui=italic,bold
          SynColor doxygenSpecialOnelineDesc cterm=bold ctermfg=LightCyan guifg=LightCyan gui=bold
          SynColor doxygenSpecialHeading cterm=bold ctermfg=LightBlue guifg=LightBlue gui=bold
          SynColor doxygenPrev ctermfg=LightGreen guifg=LightGreen
        endif
        SynLink  doxygenValue doxygenParamName
      else
        SynLink doxygenComment SpecialComment
        SynLink doxygenBrief Statement
        SynLink doxygenBody Comment
        SynLink doxygenSpecialTypeOnelineDesc Statement
        SynLink doxygenBOther Constant
        SynLink doxygenParam SpecialComment
        SynLink doxygenParamName Underlined
        SynLink doxygenSpecialOnelineDesc Statement
        SynLink doxygenSpecialHeading Statement
        SynLink doxygenPrev SpecialComment
        SynLink doxygenValue Constant
      endif
      SynLink doxygenTParam doxygenParam

    endfun

    call s:Doxygen_Hilights()

    syn match doxygenLeadingWhite +\(^\s*\*\)\@<=\s*+ contained

    " This is still a proposal, but it is probably fine.  However, it doesn't
    " work when 'syntax' is set in a modeline, catch the security error.
    try
      aug doxygengroup
        au!
        au Syntax UserColor_reset nested call s:Doxygen_Hilights_Base()
        au Syntax UserColor_{on,reset,enable} nested call s:Doxygen_Hilights()
      aug END
    catch /E12:/
    endtry


    SynLink doxygenBody                   Comment
    SynLink doxygenLine                   doxygenBody
    SynLink doxygenTODO                   Todo
    SynLink doxygenOtherTODO              Todo
    SynLink doxygenOtherWARN              Todo
    SynLink doxygenOtherBUG               Todo
    SynLink doxygenLeadingLWhite          doxygenBody

    SynLink doxygenErrorSpecial           Error
    SynLink doxygenErrorEnd               Error
    SynLink doxygenErrorComment           Error
    SynLink doxygenLinkError              Error
    SynLink doxygenBriefSpecial           doxygenSpecial
    SynLink doxygenHashSpecial            doxygenSpecial
    SynLink doxygenGroupDefineSpecial     doxygenSpecial
    SynLink doxygenEndlinkSpecial         doxygenSpecial
    SynLink doxygenCodeRegionSpecial      doxygenSpecial
    SynLink doxygenVerbatimRegionSpecial  doxygenSpecial
    SynLink doxygenDotRegionSpecial       doxygenSpecial
    SynLink doxygenGroupDefine            doxygenParam

    SynLink doxygenSpecialMultilineDesc   doxygenSpecialOnelineDesc
    SynLink doxygenFormulaEnds            doxygenSpecial
    SynLink doxygenBold                   doxygenParam
    SynLink doxygenBriefWord              doxygenParam
    SynLink doxygenRetval                 doxygenParam
    SynLink doxygenOther                  doxygenParam
    SynLink doxygenStart                  doxygenComment
    SynLink doxygenStart2                 doxygenStart
    SynLink doxygenComment2               doxygenComment
    SynLink doxygenCommentL               doxygenComment
    SynLink doxygenContinueComment        doxygenComment
    SynLink doxygenSpecialContinueComment doxygenComment
    SynLink doxygenSkipComment            doxygenComment
    SynLink doxygenEndComment             doxygenComment
    SynLink doxygenStartL                 doxygenComment
    SynLink doxygenBriefEndComment        doxygenComment
    SynLink doxygenPrevL                  doxygenPrev
    SynLink doxygenBriefL                 doxygenBrief
    SynLink doxygenBriefLine              doxygenBrief
    SynLink doxygenHeaderLine             doxygenSpecialHeading
    SynLink doxygenCommentWhite           Normal
    SynLink doxygenCommentWhite2          doxygenCommentWhite
    SynLink doxygenContinueCommentWhite   doxygenCommentWhite
    SynLink doxygenStartSkipWhite         doxygenContinueCommentWhite
    SynLink doxygenLinkWord               doxygenParamName
    SynLink doxygenLinkRest               doxygenSpecialMultilineDesc
    SynLink doxygenHyperLink              doxygenLinkWord
    SynLink doxygenHashLink               doxygenLinkWord
    SynLink doxygenReturnValue            doxygenValue

    SynLink doxygenPage                   doxygenSpecial
    SynLink doxygenPagePage               doxygenBOther
    SynLink doxygenPageIdent              doxygenParamName
    SynLink doxygenPageDesc               doxygenSpecialTypeOnelineDesc

    SynLink doxygenSpecialIdent           doxygenPageIdent
    SynLink doxygenSpecialSectionDesc     doxygenSpecialMultilineDesc

    SynLink doxygenSpecialRefWord         doxygenOther
    SynLink doxygenRefWord                doxygenPageIdent
    SynLink doxygenContinueLinkComment    doxygenComment

    SynLink doxygenHtmlCh                 Function
    SynLink doxygenHtmlCmd                Statement
    SynLink doxygenHtmlBoldItalicUnderline     doxygenHtmlBoldUnderlineItalic
    SynLink doxygenHtmlUnderlineBold           doxygenHtmlBoldUnderline
    SynLink doxygenHtmlUnderlineItalicBold     doxygenHtmlBoldUnderlineItalic
    SynLink doxygenHtmlUnderlineBoldItalic     doxygenHtmlBoldUnderlineItalic
    SynLink doxygenHtmlItalicUnderline         doxygenHtmlUnderlineItalic
    SynLink doxygenHtmlItalicBold              doxygenHtmlBoldItalic
    SynLink doxygenHtmlItalicBoldUnderline     doxygenHtmlBoldUnderlineItalic
    SynLink doxygenHtmlItalicUnderlineBold     doxygenHtmlBoldUnderlineItalic
    SynLink doxygenHtmlLink                    Underlined

    SynLink doxygenParamDirection              StorageClass


    if !exists("doxygen_my_rendering") && !exists("html_my_rendering")
      SynColor doxygenBoldWord             term=bold cterm=bold gui=bold
      SynColor doxygenEmphasisedWord       term=italic cterm=italic gui=italic
      SynLink  doxygenArgumentWord         doxygenEmphasisedWord
      SynLink  doxygenHtmlCode             doxygenCodeWord
      SynLink  doxygenHtmlBold             doxygenBoldWord
      SynColor doxygenHtmlBoldUnderline       term=bold,underline cterm=bold,underline gui=bold,underline
      SynColor doxygenHtmlBoldItalic          term=bold,italic cterm=bold,italic gui=bold,italic
      SynColor doxygenHtmlBoldUnderlineItalic term=bold,italic,underline cterm=bold,italic,underline gui=bold,italic,underline
      SynColor doxygenHtmlUnderline        term=underline cterm=underline gui=underline
      SynColor doxygenHtmlUnderlineItalic  term=italic,underline cterm=italic,underline gui=italic,underline
      SynColor doxygenHtmlItalic           term=italic cterm=italic gui=italic
    endif

  finally
    if s:my_synlink | delcommand SynLink | endif
    if s:my_syncolor | delcommand SynColor | endif
  endtry

  if &syntax=='idl'
    syn cluster idlCommentable add=doxygenComment,doxygenCommentL
  endif

  "syn sync clear
  "syn sync maxlines=500
  "syn sync minlines=50
  syn sync match doxygenComment groupthere cComment "/\@<!/\*"
  syn sync match doxygenSyncComment grouphere doxygenComment "/\@<!/\*[*!]"
  "syn sync match doxygenSyncComment grouphere doxygenComment "/\*[*!]" contains=doxygenStart,doxygenTODO keepend
  syn sync match doxygenSyncEndComment groupthere NONE "\*/"

  if !exists('b:current_syntax')
    let b:current_syntax = "doxygen"
  else
    let b:current_syntax = b:current_syntax.'.doxygen'
  endif

finally
  let &cpo = s:cpo_save
  unlet s:cpo_save
endtry
let suppress_doxygen=1
" vim:et sw=2 sts=2
