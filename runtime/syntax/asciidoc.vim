" Vim syntax file
" Language:        AsciiDoc
" Maintainer:      @aerostitch on GitHub (tag me in your issue in the
"                  github/vim/vim repository and I'll answer when available)
" Original author: Stuart Rackham <srackham@gmail.com> (inspired by Felix
"                  Obenhuber's original asciidoc.vim script).
" URL:             http://asciidoc.org/
" Licence:         GPL (http://www.gnu.org)
" Remarks:         Vim 6 or greater
" Last Update:     2020 May 03 (see Issue 240)
" Limitations:
"
" - Nested quoted text formatting is highlighted according to the outer
"   format.
" - If a closing Example Block delimiter may be mistaken for a title
"   underline. A workaround is to insert a blank line before the closing
"   delimiter.
" - Lines within a paragraph starting with equals characters are
"   highlighted as single-line titles.
" - Lines within a paragraph beginning with a period are highlighted as
"   block titles.


if exists("b:current_syntax")
  finish
endif

" Conceal Systems
let s:conceal = ''
let s:concealends = ''
let s:concealcode = ''
if has('conceal') && get(g:, 'vim_asciidoc_conceal', 1)
  let s:conceal = ' conceal'
  let s:concealends = ' concealends'
endif
if has('conceal') && get(g:, 'vim_asciidoc_conceal_code_blocks', 1)
  let s:concealcode = ' concealends'
endif

" additions to HTML groups
if get(g:, 'vim_asciidoc_emphasis_multiline', 1)
    let s:oneline = ''
else
    let s:oneline = ' oneline'
endif

" Use the default syntax syncing.

" Run :help syn-priority to review syntax matching priority.
syn keyword asciidocToDo TODO FIXME CHECK TEST XXX ZZZ DEPRECATED
syn match asciidocBackslash /\\/
syn region asciidocIdMarker start=/^\$Id:\s/ end=/\s\$$/
syn match asciidocCallout /\\\@<!<\d\{1,2}>/
syn match asciidocOpenBlockDelimiter /^--$/
syn match asciidocLineBreak /[ \t]+$/ containedin=asciidocList
syn match asciidocRuler /^'\{3,}$/
syn match asciidocPagebreak /^<\{3,}$/
syn match asciidocEntityRef /\\\@<!&[#a-zA-Z]\S\{-};/
syn region asciidocLiteralParagraph start=/\(\%^\|\_^\s*\n\)\@<=\s\+\S\+/ end=/\(^\(+\|--\)\?\s*$\)\@=/ contains=asciidocToDo
syn match asciidocURL /\\\@<!\<\(http\|https\|ftp\|file\|irc\):\/\/[^| \t]*\(\w\|\/\)/
syn match asciidocEmail /[\\.:]\@<!\(\<\|<\)\w\(\w\|[.-]\)*@\(\w\|[.-]\)*\w>\?[0-9A-Za-z_]\@!/
syn match asciidocAttributeRef /\\\@<!{\w\(\w\|[-,+]\)*\([=!@#$%?:].*\)\?}/
hi def link asciidocAttributeRef Special
hi def link asciidocBackslash Special
hi def link asciidocCallout Label
hi def link asciidocEmail Macro
hi def link asciidocEntityRef Special
hi def link asciidocIdMarker Special
hi def link asciidocLineBreak Special
hi def link asciidocOpenBlockDelimiter Label
hi def link asciidocLiteralParagraph Identifier
hi def link asciidocPagebreak Type
hi def link asciidocRuler Type
hi def link asciidocToDo Todo
hi def link asciidocURL Macro

" As a damage control measure quoted patterns always terminate at a blank
" line (see 'Limitations' above).
" Inline Text Formatting:

hi asciidocSymbol guifg=darkgrey

" Bold
syn match asciidocQuotedBold /\(^\|[| \t([.,=\]]\)\@<=\*\([* \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(\*\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedUnconstrainedBold /\\\@<!\*\*\S\_.\{-}\(\*\*\|\n\s*\n\)/ contains=asciidocEntityRef
execute 'syn region asciidocQuotedBold matchgroup=asciidocSymbol start="\%(^\|\s\)\zs\*\ze[^\\\*\t ]" end="[^\\\*\t ]\zs\*\ze\_W" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedUnconstrainedBold matchgroup=asciidocSymbol start="\*\*\ze\S" end="\S\zs\*\*" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
hi asciidocBold term=bold cterm=bold gui=bold
hi def link asciidocQuotedBold asciidocBold
hi def link asciidocQuotedUnconstrainedBold asciidocBold

" Italic
syn match asciidocQuotedEmphasized /\(^\|[| \t([.,=\]]\)\@<=_\([_ \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(_\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedEmphasized2 /\(^\|[| \t([.,=\]]\)\@<='\([' \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\('\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedUnconstrainedEmphasized /\\\@<!__\S\_.\{-}\%(__\|\n\s*\n\)/ contains=asciidocEntityRef
execute 'syn region asciidocQuotedEmphasized matchgroup=asciidocSymbol start="\%(^\|\s\)\zs_\ze[^\\_\t ]" end="[^\\_\t ]\zs_\ze\_W" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedUnconstrainedEmphasized matchgroup=asciidocSymbol start="__\ze\S" end="\S\zs__" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
hi asciidocItalic term=italic cterm=italic gui=italic guifg=cyan
hi def link asciidocQuotedEmphasized asciidocItalic
hi def link asciidocQuotedEmphasized2 asciidocItalic
hi def link asciidocQuotedUnconstrainedEmphasized asciidocItalic

execute 'syn region asciidocQuotedEmphasizedBold matchgroup=asciidocSymbol start="\%(^\|\s\)\zs\%(\*_\|_\*\)\ze[^\\\%(\*_\|_\*\)\t ]" end="[^\\\%(\*_\|_\*\)\t ]\zs\%(\*_\|_\*\)\ze\_W" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedUnconstrainedEmphasizedBold matchgroup=asciidocSymbol start="\%(__\*\*\|\*\*__\)\ze\S" end="\S\zs\%(__\*\*\|\*\*__\)" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
hi asciidocItalicBold gui=bold guifg=cyan
hi def link asciidocQuotedEmphasizedBold asciidocItalicBold
hi def link asciidocQuotedUnconstrainedEmphasizedBold asciidocItalicBold

" Code Block
syn match asciidocQuotedMonospaced /\(^\|[| \t([.,=\]]\)\@<=+\([+ \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(+\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedMonospaced2 /\(^\|[| \t([.,=\]]\)\@<=`\([` \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(`\([| \t)[\],.?!;:=]\|$\)\@=\)/
syn match asciidocQuotedUnconstrainedMonospaced /[\\`]\@<!``\S\_.\{-}\(``\|\n\s*\n\)/ contains=asciidocEntityRef
execute 'syn region asciidocQuotedMonospaced matchgroup=asciidocSymbol start="\%(^\|\s\)\zs+\ze\S" end="\S\zs+" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedMonospaced2 matchgroup=asciidocSymbol start="\%(^\|\s\)\zs`\ze[^\\`\t ]" end="[^\\`\t ]\zs`\ze\_W" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedUnconstrainedMonospaced matchgroup=asciidocSymbol start="``\ze\S" end="\S\zs``" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
hi asciidocMonospaced guibg=gray guifg=black
hi def link asciidocQuotedMonospaced asciidocMonospaced
hi def link asciidocQuotedMonospaced2 asciidocMonospaced
hi def link asciidocQuotedUnconstrainedMonospaced asciidocMonospaced

execute 'syn region asciidocQuotedEmphasizedBoldMonospaced matchgroup=asciidocSymbol start="\%(^\|\s\)\zs\%(\*_+\|_\*+\)\ze[^\\%(\*_+\|_\*+\)\t ]" end="[^\\\%(+\*_\|+_\*\)\t ]\zs\%(+\*_\|+_\*\)\ze\_W" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedEmphasizedBoldMonospaced2 matchgroup=asciidocSymbol start="\%(^\|\s\)\zs\%(\*_`\|_\*`\)\ze[^\\%(\*_`\|_\*`\)\t ]" end="[^\\\%(`\*_\|`_\*\)\t ]\zs\%(`\*_\|`_\*\)\ze\_W" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedUnconstrainedEmphasizedBolMonospaced matchgroup=asciidocSymbol start="\%(__\*\*``\|\*\*__``\)\ze[^\\%(__\*\*``\|\*\*__``\)\t ]" end="[^\\\%(``__\*\*\|``\*\*__\)\t ]\zs\%(``__\*\*\|``\*\*__\)" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
hi asciidocItalicBoldMonospaced gui=bold guifg=cyan guibg=grey
hi def link asciidocQuotedEmphasizedBoldMonospaced asciidocItalicBoldMonospaced
hi def link asciidocQuotedEmphasizedBoldMonospaced2 asciidocItalicBoldMonospaced
hi def link asciidocQuotedUnconstrainedEmphasizedBolMonospaced asciidocItalicBoldMonospaced

" Don't allow ` in single quoted (a kludge to stop confusion with `monospaced`).
syn match asciidocQuotedSingleQuoted /\(^\|[| \t([.,=\]]\)\@<=`\([` \n\t]\)\@!\([^`]\|\n\(\s*\n\)\@!\)\{-}[^` \t]\('\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedDoubleQuoted /\(^\|[| \t([.,=\]]\)\@<=``\([` \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(''\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocDoubleDollarPassthrough /\\\@<!\(^\|[^0-9a-zA-Z$]\)\@<=\$\$..\{-}\(\$\$\([^0-9a-zA-Z$]\|$\)\@=\|^$\)/
execute 'syn region asciidocDoubleDollarPassthrough matchgroup=asciidocSymbol start="\%(^\|\s\)\zs\\$\$\ze\S" end="\S\zs\\$\$" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
syn match asciidocTriplePlusPassthrough /\\\@<!\(^\|[^0-9a-zA-Z$]\)\@<=+++..\{-}\(+++\([^0-9a-zA-Z$]\|$\)\@=\|^$\)/
execute 'syn region asciidocTriplePlusPassthrough matchgroup=asciidocSymbol start="\%(^\|\s\)\zs+++\ze\S" end="\S\zs+++" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
hi def link asciidocQuotedSingleQuoted Label
hi def link asciidocQuotedDoubleQuoted Label
hi def link asciidocDoubleDollarPassthrough Special
hi def link asciidocTriplePlusPassthrough Special

" Highlight
syn match asciidocQuotedHighlight /\(^\|[| \t([.,=\]]\)\@<=#\([# \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(#\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedUnconstrainedHighlight /\\\@<!##\S\_.\{-}\(##\|\n\s*\n\)/ contains=asciidocEntityRef
execute 'syn region asciidocQuotedHighlight matchgroup=asciidocSymbol start="\%(^\|\s\)\zs#\ze[^\\#\t ]" end="[^\\#\t ]\zs#\ze\_W" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedUnconstrainedHighlight matchgroup=asciidocSymbol start="##\ze\S" end="\S\zs##" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedUnconstrainedHighlight matchgroup=asciidocSymbol  start=/[\\0-9a-zA-Z]\@<!\[\(\.\|%\)\=\w\(\w\|-\)*\S\]#/ skip=/\\#    / end=/#\|^$/ keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
hi asciidocHighlight guibg=yellow guifg=black
hi def link asciidocQuotedHighlight asciidocHighlight
hi def link asciidocQuotedUnconstrainedHighlight asciidocHighlight

" Sub Super
syn match asciidocQuotedAttributeList /\\\@<!\[[a-zA-Z0-9_-][a-zA-Z0-9 _-]*\][+_'`#*]\@=/
syn match asciidocQuotedSubscript /\\\@<!\~\S\_.\{-}\(\~\|\n\s*\n\)/ contains=asciidocEntityRef
syn match asciidocQuotedSuperscript /\\\@<!\^\S\_.\{-}\(\^\|\n\s*\n\)/ contains=asciidocEntityRef
execute 'syn region asciidocQuotedSubscript matchgroup=asciidocSymbol start="\%(^\|\s\)\zs\~\ze\S" end="\S\zs\~" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
execute 'syn region asciidocQuotedSuperscript matchgroup=asciidocSymbol start="\%(^\|\s\)\zs\^\ze\S" end="\S\zs\^" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
hi def link asciidocQuotedAttributeList Special
hi asciidocQuotedSubscript gui=underline
hi asciidocQuotedSuperscript gui=underdouble

" Link, Anchor and Crossreference
syn match asciidocAdmonition /^\u\{3,15}:\(\s\+.*\)\@=/
syn match asciidocAttributeList /^\[[^[ \t].*\]$/
execute 'syn region asciidocAttributeList matchgroup=asciidocSymbol start="^\zs\[" end="\S\zs\]$" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
syn region asciidocMacroAttributes matchgroup=asciidocRefMacro start=/\\\@<!<<"\{-}\(\w\|-\|_\|:\|\.\)\+"\?,\?/ end=/\(>>\)\|^$/ contains=asciidocQuoted.* keepend
syn region asciidocMacroAttributes matchgroup=asciidocAnchorMacro start=/\\\@<!\[\{2}\(\w\|-\|_\|:\|\.\)\+,\?/ end=/\]\{2}/ keepend
syn region asciidocMacroAttributes matchgroup=asciidocAnchorMacro start=/\\\@<!\[\{3}\(\w\|-\|_\|:\|\.\)\+/ end=/\]\{3}/ keepend
execute 'syn region asciidocMacroAttributes matchgroup=asciidocSymbol  start=/[\\0-9a-zA-Z]\@<!\w\(\w\|-\)*:\{1,2}\S\{-}\[/ skip=/\\\]/ end=/\]\|^$/ keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
" Highlight macro that starts with an attribute reference (a common idiom).
syn region asciidocMacroAttributes matchgroup=asciidocMacro start=/\(\\\@<!{\w\(\w\|[-,+]\)*\([=!@#$%?:].*\)\?}\)\@<=\S\{-}\[/ skip=/\\\]/ end=/\]\|^$/ contains=asciidocQuoted.*,asciidocAttributeRef keepend
syn region asciidocMacroAttributes matchgroup=asciidocIndexTerm start=/\\\@<!(\{2,3}/ end=/)\{2,3}/ contains=asciidocQuoted.*,asciidocAttributeRef keepend
hi def link asciidocAdmonition Special
hi def link asciidocAttributeList Special
hi def link asciidocMacroAttributes Label
hi def link asciidocAnchorMacro Macro
hi def link asciidocIndexTerm Macro
hi def link asciidocMacro Macro
hi def link asciidocRefMacro Macro

" Tittle and Header
syn region asciidocTable_OLD start=/^\([`.']\d*[-~_]*\)\+[-~_]\+\d*$/ end=/^$/
syn match asciidocBlockTitle /^\.[^. \t].*[^-~_]$/ contains=asciidocQuoted.*,asciidocAttributeRef
syn match asciidocTitleUnderline /[-=~^+]\{2,}$/ transparent contained contains=NONE
syn match asciidocOneLineTitle /^=\{1,6}\s\+\S.*$/ contains=asciidocQuoted.*,asciidocMacroAttributes,asciidocAttributeRef,asciidocEntityRef,asciidocEmail,asciidocURL,asciidocBackslash
syn match asciidocTwoLineTitle /^\[[^. +/].*[^.]\n[-=~^+]\{3,}\]$/ contains=asciidocQuoted.*,asciidocMacroAttributes,asciidocAttributeRef,asciidocEntityRef,asciidocEmail,asciidocURL,asciidocBackslash,asciidocTitleUnderline
hi def link asciidocTable_OLD Type
hi def link asciidocBlockTitle Title
hi def link asciidocOneLineTitle Title
hi def link asciidocTwoLineTitle Title

" Lists.
syn match asciidocListBullet /^\s*\zs\(-\|\*\{1,6}\)\ze\s/
syn match asciidocListNumber /^\s*\zs\(\(\d\+\.\)\|\.\{1,6}\|\(\a\.\)\|\([ivxIVX]\+)\)\)\ze\s\+/
syn region asciidocListLabel start=/^\s*/ end=/\(:\{2,4}\|;;\)$/ oneline contains=asciidocQuoted.*,asciidocMacroAttributes,asciidocAttributeRef,asciidocEntityRef,asciidocEmail,asciidocURL,asciidocBackslash,asciidocToDo keepend
hi def link asciidocListBullet Label
hi def link asciidocListNumber Label
hi def link asciidocListLabel Label

" Joint/ Continuation
syn match asciidocListContinuation /^+$/
execute 'syn region asciidocListContinuation matchgroup=asciidocSymbol start="^\zs+" end="$" keepend contains=NONE' . s:oneline . s:concealends
hi def link asciidocListContinuation Label

" Delimiter
syn region asciidocAttributeEntry start=/^:\w/ end=/:\(\s\|$\)/ oneline
syn match asciidocCommentLine "^//\([^/].*\|\)$" contains=asciidocToDo
syn region asciidocCommentBlock start="^/\{4,}$" end="^/\{4,}$" contains=asciidocToDo
execute 'syn region asciidocCommentBlock matchgroup=asciidocSymbol start="^\zs/\{4,}\ze$" end="^\zs/\{4,}\ze$" keepend contains=asciidocToDo' . s:oneline . s:concealends
syn match asciidocQuoteBlockDelimiter /^_\{4,}$/
execute 'syn region asciidocQuoteBlockDelimiter matchgroup=asciidocSymbol start="^\zs_\{4,}$" end="$" keepend contains=NONE' . s:oneline . s:concealends
syn match asciidocExampleBlockDelimiter /^=\{4,}$/
execute 'syn region asciidocExampleBlockDelimiter matchgroup=asciidocSymbol start="^\zs=\{4,}$" end="$" keepend contains=NONE' . s:oneline . s:concealends
syn match asciidocSidebarDelimiter /^\*\{4,}$/
execute 'syn region asciidocSidebarDelimiter matchgroup=asciidocSymbol start="^\zs\*\{4,}$" end="$" keepend contains=NONE' . s:oneline . s:concealends
syn region asciidocLiteralBlock start=/^\.\{4,}$/ end=/^\.\{4,}$/ contains=asciidocCallout,asciidocToDo keepend
syn region asciidocListingBlock start=/^-\{4,}$/ end=/^-\{4,}$/ contains=asciidocCallout,asciidocToDo keepend
syn region asciidocPassthroughBlock start="^+\{4,}$" end="^+\{4,}$"
execute 'syn region asciidocPassthroughBlock matchgroup=asciidocSymbol start="^\zs\%(+\|\.\|-\)\{4,}\ze$" end="^\zs\%(+\|\.\|-\)\{4,}\ze$" keepend contains=@Spell,asciidocEntityRef,asciidocCallout,asciidocToDo' . s:oneline . s:concealends
" Allowing leading \w characters in the filter delimiter is to accomodate
" the pre version 8.2.7 syntax and may be removed in future releases.
syn region asciidocFilterBlock start=/^\w*\~\{4,}$/ end=/^\w*\~\{4,}$/
execute 'syn region asciidocFilterBlock matchgroup=asciidocSymbol start="^\zs\w*\~\{4,}\ze$" end="^\zs\w*\~\{4,}\ze$" keepend contains=@Spell,asciidocEntityRef' . s:oneline . s:concealends
hi def link asciidocAttributeEntry Special
hi def link asciidocCommentBlock Comment
hi def link asciidocCommentLine Comment
hi def link asciidocExampleBlockDelimiter Type
hi def link asciidocFilterBlock Type
hi def link asciidocListingBlock Identifier
hi def link asciidocLiteralBlock Identifier
hi def link asciidocPassthroughBlock Identifier
hi def link asciidocQuoteBlockDelimiter Type
hi def link asciidocSidebarDelimiter Type

" See http://vimdoc.sourceforge.net/htmldoc/usr_44.html for excluding region
" contents from highlighting.
syn match asciidocTablePrefix /\(\S\@<!\(\([0-9.]\+\)\([*+]\)\)\?\([<\^>.]\{,3}\)\?\([a-z]\)\?\)\?|/ containedin=asciidocTableBlock contained
syn region asciidocTableBlock matchgroup=asciidocTableDelimiter start=/^|=\{3,}$/ end=/^|=\{3,}$/ keepend contains=ALL
syn match asciidocTablePrefix /\(\S\@<!\(\([0-9.]\+\)\([*+]\)\)\?\([<\^>.]\{,3}\)\?\([a-z]\)\?\)\?!/ containedin=asciidocTableBlock contained
syn region asciidocTableBlock2 matchgroup=asciidocTableDelimiter2 start=/^!=\{3,}$/ end=/^!=\{3,}$/ keepend contains=ALL
hi def link asciidocTableBlock2 NONE
hi def link asciidocTableBlock NONE
hi def link asciidocTableDelimiter2 Label
hi def link asciidocTableDelimiter Label
hi def link asciidocTablePrefix Label

" DEPRECATED: Horizontal label.
syn region asciidocHLabel start=/^\s*/ end=/\(::\|;;\)\(\s\+\|\\$\)/ oneline contains=asciidocQuoted.*,asciidocMacroAttributes keepend
" Starts with any of the above.
syn region asciidocList start=/^\s*\(-\|\*\{1,5}\)\s/ start=/^\s*\(\(\d\+\.\)\|\.\{1,5}\|\(\a\.\)\|\([ivxIVX]\+)\)\)\s\+/ start=/.\+\(:\{2,4}\|;;\)$/ end=/\(^[=*]\{4,}$\)\@=/ end=/\(^\(+\|--\)\?\s*$\)\@=/ contains=asciidocList.\+,asciidocQuoted.*,asciidocMacroAttributes,asciidocAttributeRef,asciidocEntityRef,asciidocEmail,asciidocURL,asciidocBackslash,asciidocCommentLine,asciidocAttributeList,asciidocToDo
hi def link asciidocHLabel Label


" hi def link asciidocAttributeMacro Macro
" hi def link asciidocList Label
let b:current_syntax = "asciidoc"

" vim: wrap et sw=2 sts=2:
