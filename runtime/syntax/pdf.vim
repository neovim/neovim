" Vim syntax file
" Language:	PDF
" Maintainer:	Tim Pope <vimNOSPAM@tpope.info>
" Last Change:	2007 Dec 16

if exists("b:current_syntax")
    finish
endif

if !exists("main_syntax")
    let main_syntax = 'pdf'
endif

syn include @pdfXML syntax/xml.vim

syn case match

syn cluster pdfObjects contains=pdfBoolean,pdfConstant,pdfNumber,pdfFloat,pdfName,pdfHexString,pdfString,pdfArray,pdfHash,pdfReference,pdfComment
syn keyword pdfBoolean  true false contained
syn keyword pdfConstant null       contained
syn match   pdfNumber "[+-]\=\<\d\+\>"
syn match   pdfFloat   "[+-]\=\<\%(\d\+\.\|\d*\.\d\+\)\>" contained

syn match   pdfNameError "#\X\|#\x\X\|#00" contained containedin=pdfName
syn match   pdfSpecialChar "#\x\x" contained containedin=pdfName
syn match   pdfName   "/[^[:space:]\[\](){}<>/]*"   contained
syn match   pdfHexError  "[^[:space:][:xdigit:]<>]" contained
"syn match   pdfHexString "<\s*\x[^<>]*\x\s*>"    contained contains=pdfHexError
"syn match   pdfHexString "<\s*\x\=\s*>"          contained
syn region  pdfHexString matchgroup=pdfDelimiter start="<<\@!" end=">" contained contains=pdfHexError
syn match   pdfStringError "\\."      contained containedin=pdfString
syn match   pdfSpecialChar "\\\%(\o\{1,3\}\|[nrtbf()\\]\)"  contained containedin=pdfString
syn region  pdfString matchgroup=pdfDelimiter start="\\\@<!(" end="\\\@<!)" contains=pdfString

syn region  pdfArray  matchgroup=pdfOperator start="\[" end="\]" contains=@pdfObjects contained
syn region  pdfHash   matchgroup=pdfOperator start="<<" end=">>" contains=@pdfObjects contained
syn match   pdfReference "\<\d\+\s\+\d\+\s\+R\>"
"syn keyword pdfOperator R contained containedin=pdfReference

syn region  pdfObject matchgroup=pdfType start="\<obj\>"     end="\<endobj\>" contains=@pdfObjects
syn region  pdfObject matchgroup=pdfType start="\<obj\r\=\n" end="\<endobj\>" contains=@pdfObjects fold

" Do these twice.  The ones with only newlines are foldable
syn region  pdfStream matchgroup=pdfType start="\<stream\r\=\n" end="endstream\s*\%(\r\|\n\|\r\n\)" contained containedin=pdfObject
syn region  pdfXMLStream matchgroup=pdfType start="\<stream\r\=\n\_s*\%(<?\)\@=" end="endstream\s*\%(\r\|\n\|\r\n\)" contained containedin=pdfObject contains=@pdfXML
syn region  pdfStream matchgroup=pdfType start="\<stream\n" end="endstream\s*\%(\r\|\n\|\r\n\)" contained containedin=pdfObject fold
syn region  pdfXMLStream matchgroup=pdfType start="\<stream\n\_s*\%(<?\)\@=" end="endstream\s*\%(\r\|\n\|\r\n\)" contained containedin=pdfObject contains=@pdfXML fold

syn region  pdfPreProc start="\<xref\%(\r\|\n\|\r\n\)" end="^trailer\%(\r\|\n\|\r\n\)" skipwhite skipempty nextgroup=pdfHash contains=pdfNumber fold
syn keyword pdfPreProc startxref
syn match   pdfComment  "%.*\%(\r\|\n\)" contains=pdfPreProc
syn match   pdfPreProc  "^%\%(%EOF\|PDF-\d\.\d\)\(\r\|\n\)"

hi def link pdfOperator     Operator
hi def link pdfNumber       Number
hi def link pdfFloat        Float
hi def link pdfBoolean      Boolean
hi def link pdfConstant     Constant
hi def link pdfName         Identifier
hi def link pdfNameError    pdfStringError
hi def link pdfHexString    pdfString
hi def link pdfHexError     pdfStringError
hi def link pdfString       String
hi def link pdfStringError  Error
hi def link pdfSpecialChar  SpecialChar
hi def link pdfDelimiter    Delimiter
hi def link pdfType         Type
hi def link pdfReference    Tag
hi def link pdfStream       NonText
hi def link pdfPreProc      PreProc
hi def link pdfComment      Comment

let b:current_syntax = "pdf"
