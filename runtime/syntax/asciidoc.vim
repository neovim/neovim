" Vim syntax file
" Language:     AsciiDoc
" Author:       Stuart Rackham <srackham@gmail.com> (inspired by Felix
"               Obenhuber's original asciidoc.vim script).
" URL:          http://asciidoc.org/
" Licence:      GPL (http://www.gnu.org)
" Remarks:      Vim 6 or greater
" Last Update:  2014 Aug 29 (see Issue 240)
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

syn clear
syn sync fromstart
syn sync linebreaks=100

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

" As a damage control measure quoted patterns always terminate at a blank
" line (see 'Limitations' above).
syn match asciidocQuotedAttributeList /\\\@<!\[[a-zA-Z0-9_-][a-zA-Z0-9 _-]*\][+_'`#*]\@=/
syn match asciidocQuotedSubscript /\\\@<!\~\S\_.\{-}\(\~\|\n\s*\n\)/ contains=asciidocEntityRef
syn match asciidocQuotedSuperscript /\\\@<!\^\S\_.\{-}\(\^\|\n\s*\n\)/ contains=asciidocEntityRef

syn match asciidocQuotedMonospaced /\(^\|[| \t([.,=\]]\)\@<=+\([+ \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(+\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedMonospaced2 /\(^\|[| \t([.,=\]]\)\@<=`\([` \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(`\([| \t)[\],.?!;:=]\|$\)\@=\)/
syn match asciidocQuotedUnconstrainedMonospaced /[\\+]\@<!++\S\_.\{-}\(++\|\n\s*\n\)/ contains=asciidocEntityRef

syn match asciidocQuotedEmphasized /\(^\|[| \t([.,=\]]\)\@<=_\([_ \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(_\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedEmphasized2 /\(^\|[| \t([.,=\]]\)\@<='\([' \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\('\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedUnconstrainedEmphasized /\\\@<!__\S\_.\{-}\(__\|\n\s*\n\)/ contains=asciidocEntityRef

syn match asciidocQuotedBold /\(^\|[| \t([.,=\]]\)\@<=\*\([* \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(\*\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef
syn match asciidocQuotedUnconstrainedBold /\\\@<!\*\*\S\_.\{-}\(\*\*\|\n\s*\n\)/ contains=asciidocEntityRef

" Don't allow ` in single quoted (a kludge to stop confusion with `monospaced`).
syn match asciidocQuotedSingleQuoted /\(^\|[| \t([.,=\]]\)\@<=`\([` \n\t]\)\@!\([^`]\|\n\(\s*\n\)\@!\)\{-}[^` \t]\('\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef

syn match asciidocQuotedDoubleQuoted /\(^\|[| \t([.,=\]]\)\@<=``\([` \n\t]\)\@!\(.\|\n\(\s*\n\)\@!\)\{-}\S\(''\([| \t)[\],.?!;:=]\|$\)\@=\)/ contains=asciidocEntityRef

syn match asciidocDoubleDollarPassthrough /\\\@<!\(^\|[^0-9a-zA-Z$]\)\@<=\$\$..\{-}\(\$\$\([^0-9a-zA-Z$]\|$\)\@=\|^$\)/
syn match asciidocTriplePlusPassthrough /\\\@<!\(^\|[^0-9a-zA-Z$]\)\@<=+++..\{-}\(+++\([^0-9a-zA-Z$]\|$\)\@=\|^$\)/

syn match asciidocAdmonition /^\u\{3,15}:\(\s\+.*\)\@=/

syn region asciidocTable_OLD start=/^\([`.']\d*[-~_]*\)\+[-~_]\+\d*$/ end=/^$/
syn match asciidocBlockTitle /^\.[^. \t].*[^-~_]$/ contains=asciidocQuoted.*,asciidocAttributeRef
syn match asciidocTitleUnderline /[-=~^+]\{2,}$/ transparent contained contains=NONE
syn match asciidocOneLineTitle /^=\{1,5}\s\+\S.*$/ contains=asciidocQuoted.*,asciidocMacroAttributes,asciidocAttributeRef,asciidocEntityRef,asciidocEmail,asciidocURL,asciidocBackslash
syn match asciidocTwoLineTitle /^[^. +/].*[^.]\n[-=~^+]\{3,}$/ contains=asciidocQuoted.*,asciidocMacroAttributes,asciidocAttributeRef,asciidocEntityRef,asciidocEmail,asciidocURL,asciidocBackslash,asciidocTitleUnderline

syn match asciidocAttributeList /^\[[^[ \t].*\]$/
syn match asciidocQuoteBlockDelimiter /^_\{4,}$/
syn match asciidocExampleBlockDelimiter /^=\{4,}$/
syn match asciidocSidebarDelimiter /^*\{4,}$/

" See http://vimdoc.sourceforge.net/htmldoc/usr_44.html for excluding region
" contents from highlighting.
syn match asciidocTablePrefix /\(\S\@<!\(\([0-9.]\+\)\([*+]\)\)\?\([<\^>.]\{,3}\)\?\([a-z]\)\?\)\?|/ containedin=asciidocTableBlock contained
syn region asciidocTableBlock matchgroup=asciidocTableDelimiter start=/^|=\{3,}$/ end=/^|=\{3,}$/ keepend contains=ALL
syn match asciidocTablePrefix /\(\S\@<!\(\([0-9.]\+\)\([*+]\)\)\?\([<\^>.]\{,3}\)\?\([a-z]\)\?\)\?!/ containedin=asciidocTableBlock contained
syn region asciidocTableBlock2 matchgroup=asciidocTableDelimiter2 start=/^!=\{3,}$/ end=/^!=\{3,}$/ keepend contains=ALL

syn match asciidocListContinuation /^+$/
syn region asciidocLiteralBlock start=/^\.\{4,}$/ end=/^\.\{4,}$/ contains=asciidocCallout,asciidocToDo keepend
syn region asciidocListingBlock start=/^-\{4,}$/ end=/^-\{4,}$/ contains=asciidocCallout,asciidocToDo keepend
syn region asciidocCommentBlock start="^/\{4,}$" end="^/\{4,}$" contains=asciidocToDo
syn region asciidocPassthroughBlock start="^+\{4,}$" end="^+\{4,}$"

" Allowing leading \w characters in the filter delimiter is to accomodate
" the pre version 8.2.7 syntax and may be removed in future releases.
syn region asciidocFilterBlock start=/^\w*\~\{4,}$/ end=/^\w*\~\{4,}$/

syn region asciidocMacroAttributes matchgroup=asciidocRefMacro start=/\\\@<!<<"\{-}\(\w\|-\|_\|:\|\.\)\+"\?,\?/ end=/\(>>\)\|^$/ contains=asciidocQuoted.* keepend
syn region asciidocMacroAttributes matchgroup=asciidocAnchorMacro start=/\\\@<!\[\{2}\(\w\|-\|_\|:\|\.\)\+,\?/ end=/\]\{2}/ keepend
syn region asciidocMacroAttributes matchgroup=asciidocAnchorMacro start=/\\\@<!\[\{3}\(\w\|-\|_\|:\|\.\)\+/ end=/\]\{3}/ keepend
syn region asciidocMacroAttributes matchgroup=asciidocMacro start=/[\\0-9a-zA-Z]\@<!\w\(\w\|-\)*:\S\{-}\[/ skip=/\\\]/ end=/\]\|^$/ contains=asciidocQuoted.*,asciidocAttributeRef,asciidocEntityRef keepend
" Highlight macro that starts with an attribute reference (a common idiom).
syn region asciidocMacroAttributes matchgroup=asciidocMacro start=/\(\\\@<!{\w\(\w\|[-,+]\)*\([=!@#$%?:].*\)\?}\)\@<=\S\{-}\[/ skip=/\\\]/ end=/\]\|^$/ contains=asciidocQuoted.*,asciidocAttributeRef keepend
syn region asciidocMacroAttributes matchgroup=asciidocIndexTerm start=/\\\@<!(\{2,3}/ end=/)\{2,3}/ contains=asciidocQuoted.*,asciidocAttributeRef keepend

syn match asciidocCommentLine "^//\([^/].*\|\)$" contains=asciidocToDo

syn region asciidocAttributeEntry start=/^:\w/ end=/:\(\s\|$\)/ oneline

" Lists.
syn match asciidocListBullet /^\s*\zs\(-\|\*\{1,5}\)\ze\s/
syn match asciidocListNumber /^\s*\zs\(\(\d\+\.\)\|\.\{1,5}\|\(\a\.\)\|\([ivxIVX]\+)\)\)\ze\s\+/
syn region asciidocListLabel start=/^\s*/ end=/\(:\{2,4}\|;;\)$/ oneline contains=asciidocQuoted.*,asciidocMacroAttributes,asciidocAttributeRef,asciidocEntityRef,asciidocEmail,asciidocURL,asciidocBackslash,asciidocToDo keepend
" DEPRECATED: Horizontal label.
syn region asciidocHLabel start=/^\s*/ end=/\(::\|;;\)\(\s\+\|\\$\)/ oneline contains=asciidocQuoted.*,asciidocMacroAttributes keepend
" Starts with any of the above.
syn region asciidocList start=/^\s*\(-\|\*\{1,5}\)\s/ start=/^\s*\(\(\d\+\.\)\|\.\{1,5}\|\(\a\.\)\|\([ivxIVX]\+)\)\)\s\+/ start=/.\+\(:\{2,4}\|;;\)$/ end=/\(^[=*]\{4,}$\)\@=/ end=/\(^\(+\|--\)\?\s*$\)\@=/ contains=asciidocList.\+,asciidocQuoted.*,asciidocMacroAttributes,asciidocAttributeRef,asciidocEntityRef,asciidocEmail,asciidocURL,asciidocBackslash,asciidocCommentLine,asciidocAttributeList,asciidocToDo

hi def link asciidocAdmonition Special
hi def link asciidocAnchorMacro Macro
hi def link asciidocAttributeEntry Special
hi def link asciidocAttributeList Special
hi def link asciidocAttributeMacro Macro
hi def link asciidocAttributeRef Special
hi def link asciidocBackslash Special
hi def link asciidocBlockTitle Title
hi def link asciidocCallout Label
hi def link asciidocCommentBlock Comment
hi def link asciidocCommentLine Comment
hi def link asciidocDoubleDollarPassthrough Special
hi def link asciidocEmail Macro
hi def link asciidocEntityRef Special
hi def link asciidocExampleBlockDelimiter Type
hi def link asciidocFilterBlock Type
hi def link asciidocHLabel Label
hi def link asciidocIdMarker Special
hi def link asciidocIndexTerm Macro
hi def link asciidocLineBreak Special
hi def link asciidocOpenBlockDelimiter Label
hi def link asciidocListBullet Label
hi def link asciidocListContinuation Label
hi def link asciidocListingBlock Identifier
hi def link asciidocListLabel Label
hi def link asciidocListNumber Label
hi def link asciidocLiteralBlock Identifier
hi def link asciidocLiteralParagraph Identifier
hi def link asciidocMacroAttributes Label
hi def link asciidocMacro Macro
hi def link asciidocOneLineTitle Title
hi def link asciidocPagebreak Type
hi def link asciidocPassthroughBlock Identifier
hi def link asciidocQuoteBlockDelimiter Type
hi def link asciidocQuotedAttributeList Special
hi def link asciidocQuotedBold Special
hi def link asciidocQuotedDoubleQuoted Label
hi def link asciidocQuotedEmphasized2 Type
hi asciidocQuotedEmphasizedItalic term=italic cterm=italic gui=italic
hi def link asciidocQuotedEmphasized asciidocQuotedEmphasizedItalic
hi def link asciidocQuotedMonospaced2 Identifier
hi def link asciidocQuotedMonospaced Identifier
hi def link asciidocQuotedSingleQuoted Label
hi def link asciidocQuotedSubscript Type
hi def link asciidocQuotedSuperscript Type
hi def link asciidocQuotedUnconstrainedBold Special
hi def link asciidocQuotedUnconstrainedEmphasized Type
hi def link asciidocQuotedUnconstrainedMonospaced Identifier
hi def link asciidocRefMacro Macro
hi def link asciidocRuler Type
hi def link asciidocSidebarDelimiter Type
hi def link asciidocTableBlock2 NONE
hi def link asciidocTableBlock NONE
hi def link asciidocTableDelimiter2 Label
hi def link asciidocTableDelimiter Label
hi def link asciidocTable_OLD Type
hi def link asciidocTablePrefix2 Label
hi def link asciidocTablePrefix Label
hi def link asciidocToDo Todo
hi def link asciidocTriplePlusPassthrough Special
hi def link asciidocTwoLineTitle Title
hi def link asciidocURL Macro
let b:current_syntax = "asciidoc"

" vim: wrap et sw=2 sts=2:
