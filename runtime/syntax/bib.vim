" Vim syntax file
" Language:	BibTeX (bibliographic database format for (La)TeX)
" Maintainer:	Bernd Feige <Bernd.Feige@gmx.net>
" Filenames:	*.bib
" Last Change:	2016 Sep 12

" Thanks to those who pointed out problems with this file or supplied fixes!

" Initialization
" ==============
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Ignore case
syn case ignore

" Keywords
" ========
syn keyword bibType contained	article book booklet conference inbook
syn keyword bibType contained	incollection inproceedings manual
syn keyword bibType contained	mastersthesis misc phdthesis
syn keyword bibType contained	proceedings techreport unpublished
syn keyword bibType contained	string preamble

syn keyword bibEntryKw contained	address annote author booktitle chapter
syn keyword bibEntryKw contained	crossref edition editor howpublished
syn keyword bibEntryKw contained	institution journal key month note
syn keyword bibEntryKw contained	number organization pages publisher
syn keyword bibEntryKw contained	school series title type volume year

" biblatex keywords, cf. http://mirrors.ctan.org/macros/latex/contrib/biblatex/doc/biblatex.pdf
syn keyword bibType contained	mvbook bookinbook suppbook collection mvcollection suppcollection
syn keyword bibType contained	online patent periodical suppperiodical mvproceedings reference
syn keyword bibType contained	mvreference inreference report set thesis xdata customa customb
syn keyword bibType contained	customc customd custome customf electronic www artwork audio bibnote
syn keyword bibType contained	commentary image jurisdiction legislation legal letter movie music
syn keyword bibType contained	performance review software standard video

syn keyword bibEntryKw contained	abstract isbn issn keywords url
syn keyword bibEntryKw contained	addendum afterwordannotation annotation annotator authortype
syn keyword bibEntryKw contained	bookauthor bookpagination booksubtitle booktitleaddon
syn keyword bibEntryKw contained	commentator date doi editora editorb editorc editortype
syn keyword bibEntryKw contained	editoratype editorbtype editorctype eid entrysubtype
syn keyword bibEntryKw contained	eprint eprintclass eprinttype eventdate eventtitle
syn keyword bibEntryKw contained	eventtitleaddon file foreword holder indextitle
syn keyword bibEntryKw contained	introduction isan ismn isrn issue issuesubtitle
syn keyword bibEntryKw contained	issuetitle iswc journalsubtitle journaltitle label
syn keyword bibEntryKw contained	language library location mainsubtitle maintitle
syn keyword bibEntryKw contained	maintitleaddon nameaddon origdate origlanguage
syn keyword bibEntryKw contained	origlocation origpublisher origtitle pagetotal
syn keyword bibEntryKw contained	pagination part pubstate reprinttitle shortauthor
syn keyword bibEntryKw contained	shorteditor shorthand shorthandintro shortjournal
syn keyword bibEntryKw contained	shortseries shorttitle subtitle titleaddon translator
syn keyword bibEntryKw contained	urldate venue version volumes entryset execute gender
syn keyword bibEntryKw contained	langid langidopts ids indexsorttitle options presort
syn keyword bibEntryKw contained	related relatedoptions relatedtype relatedstring
syn keyword bibEntryKw contained	sortkey sortname sortshorthand sorttitle sortyear xdata
syn keyword bibEntryKw contained	xref namea nameb namec nameatype namebtype namectype
syn keyword bibEntryKw contained	lista listb listc listd liste listf usera userb userc
syn keyword bibEntryKw contained	userd usere userf verba verbb verbc archiveprefix pdf
syn keyword bibEntryKw contained	primaryclass

" Non-standard:
" AMS mref http://www.ams.org/mref
syn keyword bibNSEntryKw contained	mrclass mrnumber mrreviewer fjournal coden

" Clusters
" ========
syn cluster bibVarContents	contains=bibUnescapedSpecial,bibBrace,bibParen,bibMath
" This cluster is empty but things can be added externally:
"syn cluster bibCommentContents

" Matches
" =======
syn match bibUnescapedSpecial contained /[^\\][%&]/hs=s+1
syn match bibKey contained /\s*[^ \t}="]\+,/hs=s,he=e-1 nextgroup=bibField
syn match bibVariable contained /[^{}," \t=]/
syn region bibComment start=/./ end=/^\s*@/me=e-1 contains=@bibCommentContents nextgroup=bibEntry
syn region bibMath contained start=/\$/ end=/\$/ skip=/\(\\\$\)/
syn region bibQuote contained start=/"/ end=/"/ skip=/\(\\"\)/ contains=@bibVarContents
syn region bibBrace contained start=/{/ end=/}/ skip=/\(\\[{}]\)/ contains=@bibVarContents
syn region bibParen contained start=/(/ end=/)/ skip=/\(\\[()]\)/ contains=@bibVarContents
syn region bibField contained start="\S\+\s*=\s*" end=/[}),]/me=e-1 contains=bibEntryKw,bibNSEntryKw,bibBrace,bibParen,bibQuote,bibVariable
syn region bibEntryData contained start=/[{(]/ms=e+1 end=/[})]/me=e-1 contains=bibKey,bibField
" Actually, 5.8 <= Vim < 6.0 would ignore the `fold' keyword anyway, but Vim<5.8 would produce
" an error, so we explicitly distinguish versions with and without folding functionality:
syn region bibEntry start=/@\S\+\s*[{(]/ end=/^\s*[})]/ transparent fold contains=bibType,bibEntryData nextgroup=bibComment
syn region bibComment2 start=/@Comment\s*[{(]/ end=/^\s*[})]/me=e-1 contains=@bibCommentContents nextgroup=bibEntry

" Synchronization
" ===============
syn sync match All grouphere bibEntry /^\s*@/
syn sync maxlines=200
syn sync minlines=50

" Highlighting defaults
" =====================
" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link bibType	Identifier
hi def link bibEntryKw	Statement
hi def link bibNSEntryKw	PreProc
hi def link bibKey		Special
hi def link bibVariable	Constant
hi def link bibUnescapedSpecial	Error
hi def link bibComment	Comment
hi def link bibComment2	Comment

let b:current_syntax = "bib"

let &cpo = s:cpo_save
unlet s:cpo_save
