" Vim syntax file
" Language:	XQuery
" Author: René Neumann <necoro@necoro.eu>
" Author: Steve Spigarelli <http://spig.net/>
" Original Author:	Jean-Marc Vanel <http://jmvanel.free.fr/>
" Last Change:	mar jui 12 18:04:05 CEST 2005
" Filenames:	*.xq
" URL:		http://jmvanel.free.fr/vim/xquery.vim

" REFERENCES:
"   [1] http://www.w3.org/TR/xquery/

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

" - is allowed in keywords
setlocal iskeyword+=-

runtime syntax/xml.vim

syn case match

" From XQuery grammar:
syn keyword xqStatement ancestor ancestor-or-self and as ascending at attribute base-uri boundary-space by case cast castable child collation construction declare default descendant descendant-or-self descending div document element else empty encoding eq every except external following following-sibling for function ge greatest gt idiv if import in inherit-namespaces instance intersect is le least let lt mod module namespace ne no of or order ordered ordering parent preceding preceding-sibling preserve return satisfies schema self some stable strip then to treat typeswitch union unordered validate variable version where xmlspace xquery yes

" TODO contains clashes with vim keyword
syn	keyword	xqFunction abs adjust-date-to-timezone adjust-date-to-timezone adjust-dateTime-to-timezone adjust-dateTime-to-timezone adjust-time-to-timezone adjust-time-to-timezone avg base-uri base-uri boolean ceiling codepoint-equal codepoints-to-string collection collection compare concat count current-date current-dateTime current-time data dateTime day-from-date day-from-dateTime days-from-duration deep-equal deep-equal default-collation distinct-values distinct-values doc doc-available document-uri empty ends-with ends-with error error error error escape-uri exactly-one exists false floor hours-from-dateTime hours-from-duration hours-from-time id id idref idref implicit-timezone in-scope-prefixes index-of index-of insert-before lang lang last local-name local-name local-name-from-QName lower-case matches matches max max min min minutes-from-dateTime minutes-from-duration minutes-from-time month-from-date month-from-dateTime months-from-duration name name namespace-uri namespace-uri namespace-uri-for-prefix namespace-uri-from-QName nilled node-name normalize-space normalize-space normalize-unicode normalize-unicode not number number one-or-more position prefix-from-QName QName remove replace replace resolve-QName resolve-uri resolve-uri reverse root root round round-half-to-even round-half-to-even seconds-from-dateTime seconds-from-duration seconds-from-time starts-with starts-with static-base-uri string string string-join string-length string-length string-to-codepoints subsequence subsequence substring substring substring-after substring-after substring-before substring-before sum sum timezone-from-date timezone-from-dateTime timezone-from-time tokenize tokenize trace translate true unordered upper-case year-from-date year-from-dateTime years-from-duration zero-or-one

syn keyword xqOperator add-dayTimeDuration-to-date add-dayTimeDuration-to-dateTime add-dayTimeDuration-to-time add-dayTimeDurations add-yearMonthDuration-to-date add-yearMonthDuration-to-dateTime add-yearMonthDurations base64Binary-equal boolean-equal boolean-greater-than boolean-less-than concatenate date-equal date-greater-than date-less-than dateTime-equal dateTime-greater-than dateTime-less-than dayTimeDuration-equal dayTimeDuration-greater-than dayTimeDuration-less-than divide-dayTimeDuration divide-dayTimeDuration-by-dayTimeDuration divide-yearMonthDuration divide-yearMonthDuration-by-yearMonthDuration except gDay-equal gMonth-equal gMonthDay-equal gYear-equal gYearMonth-equal hexBinary-equal intersect is-same-node multiply-dayTimeDuration multiply-yearMonthDuration node-after node-before NOTATION-equal numeric-add numeric-divide numeric-equal numeric-greater-than numeric-integer-divide numeric-less-than numeric-mod numeric-multiply numeric-subtract numeric-unary-minus numeric-unary-plus QName-equal subtract-dates-yielding-dayTimeDuration subtract-dateTimes-yielding-dayTimeDuration subtract-dayTimeDuration-from-date subtract-dayTimeDuration-from-dateTime subtract-dayTimeDuration-from-time subtract-dayTimeDurations subtract-times subtract-yearMonthDuration-from-date subtract-yearMonthDuration-from-dateTime subtract-yearMonthDurations time-equal time-greater-than time-less-than to union yearMonthDuration-equal yearMonthDuration-greater-than yearMonthDuration-less-than

syn match xqType "xs:\(\|Datatype\|primitive\|string\|boolean\|float\|double\|decimal\|duration\|dateTime\|time\|date\|gYearMonth\|gYear\|gMonthDay\|gDay\|gMonth\|hexBinary\|base64Binary\|anyURI\|QName\|NOTATION\|\|normalizedString\|token\|language\|IDREFS\|ENTITIES\|NMTOKEN\|NMTOKENS\|Name\|NCName\|ID\|IDREF\|ENTITY\|integer\|nonPositiveInteger\|negativeInteger\|long\|int\|short\|byte\|nonNegativeInteger\|unsignedLong\|unsignedInt\|unsignedShort\|unsignedByte\|positiveInteger\)"


" From XPath grammar:
syn keyword xqXPath some every in in satisfies if then else to div idiv mod union intersect except instance of treat castable cast eq ne lt le gt ge is child descendant attribute self descendant-or-self following-sibling following namespace parent ancestor preceding-sibling preceding ancestor-or-self void item node document-node text comment processing-instruction attribute schema-attribute schema-element

" eXist extensions
syn	match xqExist "&="

" XQdoc
syn	match	XQdoc contained "@\(param\|return\|author\)\>" 

" floating point number, with dot, optional exponent
syn match xqFloat   "\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\="
" floating point number, starting with a dot, optional exponent
syn match xqFloat   "\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
" floating point number, without dot, with exponent
syn match xqFloat   "\d\+e[-+]\=\d\+[fl]\=\>"
syn match xqNumber  "0x\x\+\(u\=l\{0,2}\|ll\=u\)\>"
syn match xqNumber  "\<\d\+\>"

syn region xqString  start=+\z(['"]\)+ skip=+\\.+ end=+\z1+
syn region xqComment start='(:' excludenl end=':)' contains=XQdoc

syn match xqVariable "$\<[a-zA-Z:_][-.0-9a-zA-Z0-9:_]*\>"
syn match xqSeparator ",\|;"
syn region xqCode transparent contained start='{' excludenl end='}' contains=xqFunction,xqCode,xmlRegionBis,xqComment,xqStatement,xmlString,xqSeparator,xqNumber,xqVariable,xqString keepend extend

syn region xmlRegionBis start=+<\z([^ /!?<>"']\+\)+ skip=+<!--\_.\{-}-->+ end=+</\z1\_\s\{-}>+ end=+/>+ fold contains=xmlTag,xmlEndTag,xmlCdata,xmlRegionBis,xmlComment,xmlEntity,xmlProcessing,xqCode keepend extend

hi def link xqNumber    Number
hi def link xqFloat     Number
hi def link xqString    String
hi def link xqVariable  Identifier
hi def link xqComment   Comment
hi def link xqSeparator Operator
hi def link xqStatement Statement
hi def link xqFunction  Function
hi def link xqOperator  Operator
hi def link xqType      Type
hi def link xqXPath     Operator
hi def link XQdoc       Special
hi def link xqExist     Operator

" override the xml highlighting
"hi link xmlTag      Structure
"hi link xmlTagName  Structure
"hi link xmlEndTag   Structure

let b:current_syntax = "xquery"
