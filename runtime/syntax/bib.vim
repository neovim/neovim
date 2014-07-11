" Vim syntax file
" Language:	BibTeX (bibliographic database format for (La)TeX)
" Maintainer:	Bernd Feige <Bernd.Feige@gmx.net>
" Filenames:	*.bib
" Last Change:	2014 Mar 26

" Thanks to those who pointed out problems with this file or supplied fixes!

" Initialization
" ==============
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" Non-standard:
syn keyword bibNSEntryKw contained	abstract isbn issn keywords url
" AMS mref http://www.ams.org/mref
syn keyword bibNSEntryKw contained	mrclass mrnumber mrreviewer fjournal coden

" Clusters
" ========
syn cluster bibVarContents	contains=bibUnescapedSpecial,bibBrace,bibParen
" This cluster is empty but things can be added externally:
"syn cluster bibCommentContents

" Matches
" =======
syn match bibUnescapedSpecial contained /[^\\][%&]/hs=s+1
syn match bibKey contained /\s*[^ \t}="]\+,/hs=s,he=e-1 nextgroup=bibField
syn match bibVariable contained /[^{}," \t=]/
syn region bibComment start=/./ end=/^\s*@/me=e-1 contains=@bibCommentContents nextgroup=bibEntry
syn region bibQuote contained start=/"/ end=/"/ skip=/\(\\"\)/ contains=@bibVarContents
syn region bibBrace contained start=/{/ end=/}/ skip=/\(\\[{}]\)/ contains=@bibVarContents
syn region bibParen contained start=/(/ end=/)/ skip=/\(\\[()]\)/ contains=@bibVarContents
syn region bibField contained start="\S\+\s*=\s*" end=/[}),]/me=e-1 contains=bibEntryKw,bibNSEntryKw,bibBrace,bibParen,bibQuote,bibVariable
syn region bibEntryData contained start=/[{(]/ms=e+1 end=/[})]/me=e-1 contains=bibKey,bibField
" Actually, 5.8 <= Vim < 6.0 would ignore the `fold' keyword anyway, but Vim<5.8 would produce
" an error, so we explicitly distinguish versions with and without folding functionality:
if version < 600
  syn region bibEntry start=/@\S\+\s*[{(]/ end=/^\s*[})]/ transparent contains=bibType,bibEntryData nextgroup=bibComment
else
  syn region bibEntry start=/@\S\+\s*[{(]/ end=/^\s*[})]/ transparent fold contains=bibType,bibEntryData nextgroup=bibComment
endif
syn region bibComment2 start=/@Comment\s*[{(]/ end=/^\s*[})]/me=e-1 contains=@bibCommentContents nextgroup=bibEntry

" Synchronization
" ===============
syn sync match All grouphere bibEntry /^\s*@/
syn sync maxlines=200
syn sync minlines=50

" Highlighting defaults
" =====================
" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_bib_syn_inits")
  if version < 508
    let did_bib_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif
  HiLink bibType	Identifier
  HiLink bibEntryKw	Statement
  HiLink bibNSEntryKw	PreProc
  HiLink bibKey		Special
  HiLink bibVariable	Constant
  HiLink bibUnescapedSpecial	Error
  HiLink bibComment	Comment
  HiLink bibComment2	Comment
  delcommand HiLink
endif

let b:current_syntax = "bib"

let &cpo = s:cpo_save
unlet s:cpo_save
